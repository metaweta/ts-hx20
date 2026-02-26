// Epson HX-20 System Integration
// Wires together dual CPUs, memory, LCD, keyboard, RTC, cassette

import { HD6301 } from './cpu';
import { LCDDisplay } from './lcd';
import { Keyboard } from './keyboard';
import { MC146818 } from './rtc';
import { Cassette } from './cassette';
import { loadIntelHexIntoBuffer, loadBinaryIntoBuffer } from './rom-loader';

export class HX20 {
  mainCPU: HD6301;
  slaveCPU: HD6301;
  lcd: LCDDisplay;
  keyboard: Keyboard;
  rtc: MC146818;
  cassette: Cassette;

  // Main CPU memory
  mainRAM = new Uint8Array(0x4000);    // 16KB at 0x0100-0x3FFF
  mainROM = new Uint8Array(0x8000);    // 32KB at 0x8000-0xFFFF
  optionROM = new Uint8Array(0x2000);  // 8KB at 0x6000-0x7FFF
  hasOptionROM = false;

  // Slave CPU memory (internal 4KB ROM loaded separately)
  slaveROM: Uint8Array | null = null;

  // Inter-CPU serial communication
  private slaveTx = 1;   // slave → main (Port 2 bit 4)
  private slaveRx = 1;   // main → slave
  private slaveFlag = 1;  // slave P34 → main P12
  private slaveSio = 0;  // main P22: 0 = SIO bus, 1 = slave CPU

  // I/O state
  private ksc = 0;           // keyboard scan column
  private rtcIrq = false;

  // Cassette controller state (emulates the cassette mechanism controller IC)
  // The slave CPU bit-bangs commands via P43 (data) and P44 (clock)
  // The controller responds on P46 (LOW = acknowledged)
  private casCtrlP46 = true;       // P46 status: HIGH=idle, LOW=acknowledged
  private casCtrlTimer = 0;        // Slave cycles until P46 returns to HIGH
  private casCtrlBitCount = 0;     // Bit counter for bit-bang receive
  private casCtrlData = 0;         // Accumulated command byte
  private casCtrlLastP44 = false;  // P44 state for rising-edge detection
  private casCtrlArmed = false;    // true after AIM #$E3 clears P42/P43/P44 (bit-bang start)
  private casCtrlMotorOn = false;  // Motor running (after 0x81 record command)

  // Running state
  running = false;
  private animFrameId = 0;
  speedMultiplier = 1;

  // Timing
  static readonly CRYSTAL = 2457600;  // 2.4576 MHz
  static readonly E_CLOCK = HX20.CRYSTAL / 4; // 614.4 KHz
  static readonly FRAME_RATE = 60;
  static readonly CYCLES_PER_FRAME = Math.floor(HX20.E_CLOCK / HX20.FRAME_RATE);

  // State format version (increment when save format changes)
  static readonly STATE_VERSION = 3;

  onStatusUpdate: (text: string) => void = () => {};
  onRegistersUpdate: (text: string) => void = () => {};

  constructor() {
    this.mainCPU = new HD6301('Main');
    this.slaveCPU = new HD6301('Slave');
    this.lcd = new LCDDisplay();
    this.keyboard = new Keyboard();
    this.rtc = new MC146818();
    this.cassette = new Cassette();

    this.wireMainCPU();
    this.wireSlaveCPU();
    this.wireRTC();
    this.wireSerial();
  }

  private wireMainCPU(): void {
    const cpu = this.mainCPU;

    // External bus read
    cpu.onRead = (addr: number): number => {
      if (addr >= 0x8000) return this.mainROM[addr - 0x8000];
      if (addr >= 0x6000 && addr < 0x8000) {
        return this.hasOptionROM ? this.optionROM[addr - 0x6000] : 0x00;
      }
      if (addr >= 0x0100 && addr < 0x4000) return this.mainRAM[addr - 0x0100];

      // I/O registers (0x20-0x7F)
      if (addr >= 0x0040 && addr < 0x0080) return this.rtc.read(addr - 0x0040);

      switch (addr) {
        case 0x0020: return this.ksc; // KSC (write-only, but reads return last written)
        case 0x0022: {
          const val = this.keyboard.readKRTN07(this.ksc);
          this.updateMainIRQ(); // KRTN read clears keyboard IRQ latch
          return val;
        }
        case 0x0026: return 0xFF;
        case 0x0028: {
          const val = this.keyboard.readKRTN89(this.ksc);
          this.updateMainIRQ(); // KRTN read clears keyboard IRQ latch
          return val;
        }
        case 0x002A:
          this.lcd.clockLCD();
          return 0xFF;
        case 0x002B:
          this.lcd.clockLCD();
          return 0xFF;
        case 0x002C: return 0xFF; // interrupt mask
        case 0x0030: case 0x0031: case 0x0032: case 0x0033:
          return 0xFF; // bank switching
      }

      return 0xFF;
    };

    // External bus write
    cpu.onWrite = (addr: number, val: number): void => {
      if (addr >= 0x0100 && addr < 0x4000) {
        this.mainRAM[addr - 0x0100] = val;
        return;
      }
      if (addr >= 0x0040 && addr < 0x0080) {
        this.rtc.write(addr - 0x0040, val);
        return;
      }

      switch (addr) {
        case 0x0020: this.ksc = val; break;
        case 0x0026:
          this.lcd.writeLCDControl(val);
          break;
        case 0x002A:
          this.lcd.writeLCDData(val);
          break;
        case 0x002C: break; // interrupt mask sleep mode
        case 0x0030: case 0x0031: case 0x0032: case 0x0033:
          break; // bank switching
      }
    };

    // Port 1 read: various status inputs
    cpu.onReadPort1 = (): number => {
      let val = 0x98; // defaults: bit 4 (PWA)=1, bit 3 (INT_EX)=1
      // Bit 7: cartridge MI1 (1 = microcassette present)
      val |= 0x80;
      // Bit 5: keyboard request (active low: 0 = request pending)
      if (!this.keyboard.irqPending) val |= 0x20;
      // Bit 2: slave flag (slave P34 → master P12)
      if (this.slaveFlag) val |= 0x04;
      // Bits 1,0: RS-232 CTS, DSR (both high = ready)
      val |= 0x03;
      return val;
    };

    // Port 2 read
    cpu.onReadPort2 = (): number => {
      let val = 0x00;
      // Bit 3: RX data (from slave or SIO)
      if (this.slaveSio) val |= (this.slaveTx ? 0x08 : 0);
      else val |= 0x08; // SIO RX default high
      return val;
    };

    // Port 2 write
    cpu.onWritePort2 = (val: number): void => {
      // Bit 4: TX (to slave or SIO)
      if (this.slaveSio) {
        this.slaveRx = (val >> 4) & 1;
      }
      // Bit 2: serial select (0=SIO, 1=slave)
      this.slaveSio = (val >> 2) & 1;
      // Bit 1: RS-232 TXD
    };

    cpu.onReadPort3 = () => 0xFF;
    cpu.onReadPort4 = () => 0xFF;
    cpu.onWritePort1 = () => {};
    cpu.onWritePort3 = () => {};
    cpu.onWritePort4 = () => {};
  }

  private wireSlaveCPU(): void {
    const cpu = this.slaveCPU;

    // Slave has only internal ROM and RAM; external bus returns 0xFF
    cpu.onRead = () => 0xFF;
    cpu.onWrite = () => {};

    // Port 1: printer control + speaker
    cpu.onReadPort1 = () => 0xC0; // timing + reset pulses high
    cpu.onWritePort1 = (_val: number): void => {
      // Bit 5: speaker
      // Bits 0-4: printer head/motor control
    };

    // Port 2
    cpu.onReadPort2 = (): number => {
      let val = 0xE0; // mode pins (P25-P27)
      val |= 0x08; // Bit 3: SCI RX line (high idle)
      val |= 0x01; // Bit 0: cassette mechanism ready (checked by ROM before cassette ops)
      return val;
    };

    cpu.onWritePort2 = (val: number): void => {
      // Bit 4: RX line to main CPU
      this.slaveTx = (val >> 4) & 1;
    };

    // Output compare output: P21 driven by OLVL when OCR matches FRC
    // This is the FSK waveform for cassette recording
    cpu.onOCOutput = (level: boolean): void => {
      this.cassette.setOCOutput(level);
    };

    // Port 3: cassette I/O + slave flag
    cpu.onReadPort3 = (): number => {
      let val = 0xFF;
      // P32 (bit 2): cassette read data input
      if (!this.cassette.readLevel) val &= ~0x04;
      return val;
    };

    cpu.onWritePort3 = (val: number): void => {
      // P30 (bit 0): motor remote — for external cassette (CAS1:), not used for internal
      // P33 (bit 3): cassette write data — external cassette FSK output
      // Internal microcassette uses P21 (output compare) for FSK and P42 for motor
      // P34 (bit 4): slave flag → master P12
      this.slaveFlag = (val >> 4) & 1;
    };

    // Port 4: cassette power/command, RS-232 select
    cpu.onReadPort4 = (): number => {
      // P40 (bit 0): tape running indicator (1 = motor on and tape moving)
      // P46 (bit 6): cassette controller status (LOW = command acknowledged)
      // P47 (bit 7): CD (carrier detect) — HIGH = no carrier
      let val = 0x80; // P47 high (no carrier)
      if (this.casCtrlMotorOn) val |= 0x01;   // P40: tape running
      if (this.casCtrlP46) val |= 0x40;        // P46: HIGH = idle
      return val;
    };
    cpu.onWritePort4 = (val: number): void => {
      // P42 (bit 2): microcassette power
      // P43 (bit 3): cassette controller data (bit-bang serial)
      // P44 (bit 4): cassette controller clock (bit-bang serial)
      // P45 (bit 5): cassette/RS-232 select
      const p44 = !!(val & 0x10);

      // The bit-bang routine (FBFA) starts each iteration with AIM #$E3, $07
      // which clears P42, P43, P44 simultaneously. Detect this pattern to
      // distinguish real bit-bang clocks from other P44 writes (e.g. OIM #$30).
      if ((val & 0x1C) === 0) {
        // P42/P43/P44 all low — this is the AIM #$E3 pattern
        this.casCtrlArmed = true;
      }

      // Only count P44 rising edges that follow the AIM #$E3 clear pattern
      if (p44 && !this.casCtrlLastP44 && this.casCtrlArmed) {
        this.casCtrlArmed = false;
        const dataBit = (val >> 3) & 1;
        this.casCtrlData = (this.casCtrlData << 1) | dataBit;
        this.casCtrlBitCount++;

        if (this.sciDebug) {
          console.log(`[CAS] P44↑ bit${this.casCtrlBitCount}: d=${dataBit} acc=0x${(this.casCtrlData & 0xFF).toString(16)} sPC=${this.slaveCPU.PC.toString(16)}`);
        }

        if (this.casCtrlBitCount >= 8) {
          // Complete command byte received
          const cmd = this.casCtrlData & 0xFF;
          if (this.sciDebug) {
            console.log(`[CAS] Controller cmd: 0x${cmd.toString(16).padStart(2,'0')} sPC=${this.slaveCPU.PC.toString(16)}`);
          }
          this.processCasCtrlCommand(cmd);
          this.casCtrlBitCount = 0;
          this.casCtrlData = 0;
        }
      }
      this.casCtrlLastP44 = p44;
    };
  }

  /** Process a complete command byte received by the cassette controller IC */
  private processCasCtrlCommand(cmd: number): void {
    // Pull P46 LOW to acknowledge receipt
    this.casCtrlP46 = false;

    // Timer: how long P46 stays LOW before returning to HIGH (idle).
    // The ROM's retry loop checks P46 every ~614 cycles (1ms OCF) and needs
    // 4 consecutive matches. Use 5000 cycles (~8ms) so the first check succeeds,
    // and the retry mechanism handles edge cases.
    this.casCtrlTimer = 5000;

    switch (cmd) {
      case 0x00: // Stop
      case 0x18: // Stop (alternate)
        if (this.casCtrlMotorOn) {
          this.casCtrlMotorOn = false;
          this.cassette.setMotor(false);
        }
        break;
      case 0x81: // Record
        this.casCtrlMotorOn = true;
        this.cassette.setMotor(true);
        break;
      case 0x82: // Play (for LOAD)
        this.casCtrlMotorOn = true;
        this.cassette.setMotor(true);
        break;
      case 0x84: // Fast forward
      case 0x88: // Rewind
        this.casCtrlMotorOn = true;
        break;
      default:
        // Unknown command — still acknowledge
        break;
    }
  }

  /** Advance cassette controller timer (called each slave CPU step) */
  advanceCasCtrlTimer(cycles: number): void {
    if (this.casCtrlTimer > 0) {
      this.casCtrlTimer -= cycles;
      if (this.casCtrlTimer <= 0) {
        this.casCtrlTimer = 0;
        this.casCtrlP46 = true; // Return P46 to HIGH (idle)
      }
    }
  }

  // Debug: set to true to log SCI traffic
  sciDebug = false;

  private wireSerial(): void {
    // CPU-to-CPU SCI routing: main ↔ slave via SCI TDR/RDR
    // Gated by slaveSio (main Port 2 bit 2): 1 = route to slave, 0 = SIO bus

    this.mainCPU.onSerialSend = (data: number) => {
      if (this.sciDebug) {
        console.log(`[SCI] M→S: 0x${data.toString(16).padStart(2,'0')} sio=${this.slaveSio} mPC=${this.mainCPU.PC.toString(16)} writePC=${this.mainCPU.sciTxWritePC.toString(16)}`);
      }
      if (this.slaveSio) {
        // Main CPU TX → Slave CPU RX
        this.slaveCPU.serialRecv(data);
      }
      // else: data goes to external SIO bus (not implemented)
    };

    this.slaveCPU.onSerialSend = (data: number) => {
      if (this.sciDebug) {
        console.log(`[SCI] S→M: 0x${data.toString(16).padStart(2,'0')} sPC=${this.slaveCPU.PC.toString(16)} writePC=${this.slaveCPU.sciTxWritePC.toString(16)}`);
      }
      // Slave CPU TX → Main CPU RX (always)
      this.mainCPU.serialRecv(data);
    };

    // Debug: log when master reads RDR (clears RDRF)
    this.mainCPU.onSerialRead = (data: number, pc: number) => {
      if (this.sciDebug) {
        console.log(`[SCI] M←RDR: 0x${data.toString(16).padStart(2,'0')} mPC=${pc.toString(16)}`);
      }
    };
  }

  private wireRTC(): void {
    this.rtc.irqCallback = (state: boolean) => {
      this.rtcIrq = state;
      this.updateMainIRQ();
    };
  }

  private updateMainIRQ(): void {
    // Keyboard IRQ is latched: set on key press, cleared when firmware reads KRTN.
    const irq = this.rtcIrq || this.keyboard.irqPending;
    this.mainCPU.irq1Line = irq;
  }

  // Load ROMs from Intel HEX strings
  loadMainROM(hexData: string): void {
    loadIntelHexIntoBuffer(hexData, this.mainROM, 0x8000);
  }

  loadMainROMBinary(data: Uint8Array, offset: number): void {
    loadBinaryIntoBuffer(data, this.mainROM, offset);
  }

  loadSlaveROM(data: Uint8Array): void {
    this.slaveROM = new Uint8Array(0x1000);
    loadBinaryIntoBuffer(data, this.slaveROM, 0);
    this.slaveCPU.internalROM = this.slaveROM;
  }

  loadROMHex(hexString: string, baseAddress: number): void {
    const offset = baseAddress - 0x8000;
    if (offset >= 0 && offset < this.mainROM.length) {
      loadIntelHexIntoBuffer(hexString, this.mainROM, baseAddress);
    }
  }

  isROMLoaded(): boolean {
    // Check if reset vector is valid (not 0xFFFF)
    const resetVec = (this.mainROM[0x7FFE] << 8) | this.mainROM[0x7FFF];
    return resetVec !== 0xFFFF && resetVec !== 0x0000;
  }

  reset(): void {
    this.mainRAM.fill(0);

    // Pre-initialize battery-backed RAM values that the ROM expects.
    const ramEnd = 0x4000;
    this.mainRAM[0x0134 - 0x0100] = (ramEnd >> 8) & 0xFF;
    this.mainRAM[0x0135 - 0x0100] = ramEnd & 0xFF;
    this.mainRAM[0x012C - 0x0100] = (ramEnd >> 8) & 0xFF;
    this.mainRAM[0x012D - 0x0100] = ramEnd & 0xFF;

    this.slaveTx = 1;
    this.slaveRx = 1;
    this.slaveFlag = 1;
    this.slaveSio = 0;
    this.ksc = 0;
    this.rtcIrq = false;

    // Reset cassette controller state
    this.casCtrlP46 = true;
    this.casCtrlTimer = 0;
    this.casCtrlBitCount = 0;
    this.casCtrlData = 0;
    this.casCtrlLastP44 = false;
    this.casCtrlArmed = false;
    this.casCtrlMotorOn = false;

    this.lcd.reset();
    this.keyboard.reset();
    this.rtc.reset();
    this.mainCPU.reset();
    if (this.slaveROM) {
      this.slaveCPU.reset();
    }
  }

  // Run one frame's worth of CPU cycles — both CPUs interleaved
  runFrame(): void {
    const targetCycles = HX20.CYCLES_PER_FRAME * this.speedMultiplier;

    // Transfer any pending key events to the IRQ latch
    if (this.keyboard.hasKeyRequest()) {
      this.keyboard.clearKeyRequest();
    }
    this.updateMainIRQ();

    // Run both CPUs interleaved (like hex20: one instruction each, alternating)
    let mainCycles = 0;
    let slaveCycles = 0;

    while (mainCycles < targetCycles) {
      mainCycles += this.mainCPU.step();

      // Run slave CPU to keep in sync with main
      if (this.slaveROM) {
        while (slaveCycles < mainCycles) {
          const sc = this.slaveCPU.step();
          slaveCycles += sc;
          this.cassette.advance(sc);
          this.advanceCasCtrlTimer(sc);
        }
      }
    }

    // Periodic RTC tick
    this.rtc.tick();

    // Render LCD
    this.lcd.render();
  }

  start(): void {
    if (this.running) return;
    this.running = true;

    const frameLoop = () => {
      if (!this.running) return;
      this.runFrame();
      this.onStatusUpdate(
        `PC=${this.mainCPU.PC.toString(16).padStart(4, '0')} ` +
        `cyc=${this.mainCPU.totalCycles}`
      );
      this.onRegistersUpdate(this.mainCPU.dumpRegisters());
      this.animFrameId = requestAnimationFrame(frameLoop);
    };

    this.animFrameId = requestAnimationFrame(frameLoop);
  }

  stop(): void {
    this.running = false;
    if (this.animFrameId) {
      cancelAnimationFrame(this.animFrameId);
      this.animFrameId = 0;
    }
  }

  stepOne(): void {
    this.mainCPU.step();
    if (this.slaveROM) {
      const sc = this.slaveCPU.step();
      this.cassette.advance(sc);
      this.advanceCasCtrlTimer(sc);
    }
    this.lcd.render();
    this.onRegistersUpdate(this.mainCPU.dumpRegisters());
  }

  // Snapshot the entire machine state for persistence
  saveState(): string {
    const lcdControllers = this.lcd.controllers.map(c => ({
      ram: btoa(String.fromCharCode(...c.ram)),
      displayOn: c.displayOn,
    }));
    const state = {
      version: HX20.STATE_VERSION,
      mainCPU: this.mainCPU.saveState(),
      slaveCPU: this.slaveROM ? this.slaveCPU.saveState() : null,
      mainRAM: btoa(String.fromCharCode(...this.mainRAM)),
      mainROM: btoa(String.fromCharCode(...this.mainROM)),
      slaveROM: this.slaveROM ? btoa(String.fromCharCode(...this.slaveROM)) : null,
      lcd: lcdControllers,
      rtc: this.rtc.saveState(),
      slaveTx: this.slaveTx,
      slaveRx: this.slaveRx,
      slaveFlag: this.slaveFlag,
      slaveSio: this.slaveSio,
      ksc: this.ksc,
    };
    return JSON.stringify(state);
  }

  // Restore entire machine state from a snapshot
  loadState(json: string): void {
    const s = JSON.parse(json);

    // Version check — old states without slave CPU can't be resumed
    if (!s.version || s.version < HX20.STATE_VERSION) {
      throw new Error('Incompatible state format (pre-v2) — fresh boot required');
    }

    // Restore ROMs
    const romStr = atob(s.mainROM);
    for (let i = 0; i < romStr.length; i++) this.mainROM[i] = romStr.charCodeAt(i);

    // Restore RAM
    const ramStr = atob(s.mainRAM);
    for (let i = 0; i < ramStr.length; i++) this.mainRAM[i] = ramStr.charCodeAt(i);

    // Restore slave ROM (must happen before slave CPU restore)
    if (s.slaveROM) {
      const slaveStr = atob(s.slaveROM);
      this.slaveROM = new Uint8Array(slaveStr.length);
      for (let i = 0; i < slaveStr.length; i++) this.slaveROM[i] = slaveStr.charCodeAt(i);
      this.slaveCPU.internalROM = this.slaveROM;
    }

    // Restore main CPU (wiring is already set up from constructor)
    this.mainCPU.loadState(s.mainCPU);

    // Restore slave CPU
    if (s.slaveCPU && this.slaveROM) {
      this.slaveCPU.loadState(s.slaveCPU);
    }

    // Restore LCD controller RAM
    for (let i = 0; i < s.lcd.length && i < this.lcd.controllers.length; i++) {
      const ctrl = this.lcd.controllers[i];
      const data = atob(s.lcd[i].ram);
      for (let j = 0; j < data.length; j++) ctrl.ram[j] = data.charCodeAt(j);
      ctrl.displayOn = s.lcd[i].displayOn;
      ctrl.dirty = true;
    }

    // Restore I/O state
    this.slaveTx = s.slaveTx;
    this.slaveRx = s.slaveRx;
    this.slaveFlag = s.slaveFlag;
    this.slaveSio = s.slaveSio;
    this.ksc = s.ksc;

    // Restore RTC NVRAM (contains TITLE directory etc.), or reset if absent
    if (s.rtc) {
      this.rtc.loadState(s.rtc);
    } else {
      this.rtc.reset();
    }

    // Reset transient subsystems
    this.keyboard.reset();
  }
}
