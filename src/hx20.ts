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
  cas0: Cassette;  // Internal microcassette (CAS0:)
  cas1: Cassette;  // External cassette (CAS1:)

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
  private extMotorOn = false;      // External cassette motor (P30, active low)

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
    this.cas0 = new Cassette('hx20-tapes-cas0', 'CAS0');
    this.cas1 = new Cassette('hx20-tapes-cas1', 'CAS1');

    this.wireMainCPU();
    this.wireSlaveCPU();
    this.wireRTC();
    this.wireSerial();
    this.wireSIO();
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
      this.cas0.setOCOutput(level);
    };

    // Port 3: cassette I/O + slave flag
    cpu.onReadPort3 = (): number => {
      let val = 0xFF;
      // P32 (bit 2): cassette read data input
      if (!this.cas1.readLevel) val &= ~0x04;
      return val;
    };

    cpu.onWritePort3 = (val: number): void => {
      // P30 (bit 0): motor remote — for external cassette (CAS1:)
      // LOW = motor on, HIGH = motor off (active low)
      const motorOn = !(val & 0x01);
      if (motorOn !== this.extMotorOn) {
        this.extMotorOn = motorOn;
        if (this.sciDebug) {
          console.log(`[CAS] External motor P30: ${motorOn ? 'ON' : 'OFF'} sPC=${this.slaveCPU.PC.toString(16)}`);
        }
        this.cas1.setMotor(motorOn);
      }
      // P33 (bit 3): cassette write data — external cassette FSK output
      // CAS1: FSK encoding (F709) toggles P33 for the tape signal, timed by OCR
      const p33 = !!(val & 0x08);
      this.cas1.setWriteData(p33);
      // P34 (bit 4): slave flag → master P12
      this.slaveFlag = (val >> 4) & 1;
    };

    // Port 4: cassette power/command, RS-232 select
    cpu.onReadPort4 = (): number => {
      // P40 (bit 0): tape running indicator (1 = motor on and tape moving)
      // P46 (bit 6): cassette controller status (LOW = command acknowledged)
      // P47 (bit 7): CD (carrier detect) — HIGH = no carrier
      let val = 0x80; // P47 high (no carrier)
      if (this.casCtrlMotorOn || this.extMotorOn) val |= 0x01;   // P40: tape running (either motor)
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
          this.cas0.setMotor(false);
        }
        break;
      case 0x81: // Record
        this.casCtrlMotorOn = true;
        this.cas0.setMotor(true);
        break;
      case 0x82: // Play (for LOAD)
        this.casCtrlMotorOn = true;
        this.cas0.setMotor(true);
        break;
      case 0x84: // Fast forward
        this.casCtrlMotorOn = true;
        this.cas0.fastForward();
        break;
      case 0x88: // Rewind
        this.casCtrlMotorOn = true;
        this.cas0.rewind();
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
        const phase = (this as any)._leaderStarted && !(this as any)._dataLoopLogged ? ' [DURING LEADER]' : '';
        console.log(`[SCI] M→S: 0x${data.toString(16).padStart(2,'0')} sio=${this.slaveSio} mPC=${this.mainCPU.PC.toString(16)} writePC=${this.mainCPU.sciTxWritePC.toString(16)}${phase}`);
        if (phase) {
          (this as any)._leaderByteCount = ((this as any)._leaderByteCount || 0) + 1;
        }
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

  private wireSIO(): void {
    // SIO bus: when the LCD clock counter completes 8 clocks with sel=7 or sel=0
    // (no LCD controller selected), the byte is destined for the slave CPU.
    // The real HX-20 routes SIO bus output to the slave's SCI RX.
    this.lcd.onSIODispatch = (data: number) => {
      if (this.sciDebug) {
        console.log(`[SIO] M→S: 0x${data.toString(16).padStart(2,'0')} mPC=${this.mainCPU.PC.toString(16)}`);
      }
      this.slaveCPU.serialRecv(data);
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
    this.extMotorOn = false;

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
      // Master-side diagnostics (before step)
      if (this.sciDebug) {
        const mPC = this.mainCPU.PC;
        if (mPC === 0xEE6A) {
          // IRQ handler ACK mismatch check
          const expected = this.mainCPU.A;
          const rdr = this.mainCPU.readRAM(0x12);
          console.log(`[MASTER] EE6A: IRQ ACK check expected=0x${expected.toString(16).padStart(2,'0')} got=0x${rdr.toString(16).padStart(2,'0')} ${expected !== rdr ? '*** MISMATCH ***' : 'OK'}`);
        } else if (mPC === 0xEE7E) {
          console.log(`[MASTER] EE7E: IRQ error flag SET (ACK mismatch)`);
        } else if (mPC === 0xEE81) {
          console.log(`[MASTER] EE81: IRQ block completion`);
        } else if (mPC === 0xEF15) {
          console.log(`[MASTER] EF15: Sending 0x7B (more blocks) via E403`);
        } else if (mPC === 0xEF1A) {
          console.log(`[MASTER] EF1A: Sending cleanup cmd=0x${this.mainCPU.A.toString(16).padStart(2,'0')} via E403`);
        } else if (mPC === 0xE4F5) {
          console.log(`[MASTER] E4F5: Enabling RIE (IRQ-driven data transfer starts)`);
        }
      }
      mainCycles += this.mainCPU.step();

      // Run slave CPU to keep in sync with main
      if (this.slaveROM) {
        while (slaveCycles < mainCycles) {
          // Diagnostic breakpoints for SAVE debugging (only when sciDebug is on)
          if (this.sciDebug) {
            const sPC = this.slaveCPU.PC;
            if (sPC === 0xFA5C) {
              console.log('[SAVE] Slave entered FA5C (0x61 timing init handler)');
            } else if (sPC === 0xFCE8) {
              // Dump FSK timing values when SAVE handler starts
              const ram = this.slaveCPU.readRAM;
              console.log(`[SAVE] Slave entered FCE8 (SAVE handler). FSK timing: ` +
                `$A6=${(ram(0xA6)<<8|ram(0xA7)).toString(16)} ` +
                `$A8=${(ram(0xA8)<<8|ram(0xA9)).toString(16)} ` +
                `$AA=${(ram(0xAA)<<8|ram(0xAB)).toString(16)}`);
              (this as any)._saveStartCycles = this.slaveCPU.totalCycles;
              (this as any)._fskLogged = false;
              (this as any)._dataLoopLogged = false;
              (this as any)._leaderStarted = false;
              (this as any)._leaderByteCount = 0;
            } else if (sPC === 0xFDC4) {
              const elapsed = this.slaveCPU.totalCycles - ((this as any)._saveStartCycles || 0);
              const seconds = elapsed / 614400;
              const ss = this.slaveCPU.saveState();
              console.log(`[SAVE] Slave at FDC4 — SAVE success! elapsed=${elapsed} cycles (${seconds.toFixed(2)}s)`);
              console.log(`[SAVE] FRC=${(ss.frc as number).toString(16)} OCR=${(ss.ocr as number).toString(16)} TCSR=${(ss.tcsr as number).toString(16)}`);
            } else if (sPC === 0xFD6C) {
              // First entry to data receive loop — log byte count (X register)
              if (!(this as any)._dataLoopLogged) {
                (this as any)._dataLoopLogged = true;
                (this as any)._dataLoopByteNum = 0;
                const ss = this.slaveCPU.saveState();
                const trcsr = ss.trcsr as number;
                const recvBuf = ss.sciRecvBuf as number[];
                console.log(`[SAVE] Data loop entry at FD6C: X=${this.slaveCPU.X} (0x${this.slaveCPU.X.toString(16)}) bytes to receive` +
                  ` RDRF=${(trcsr & 0x80) ? 'SET' : 'clear'} RDR=0x${(ss.rdr as number).toString(16).padStart(2,'0')}` +
                  ` sciRecvBuf=[${recvBuf.map((b: number) => '0x'+b.toString(16).padStart(2,'0')).join(',')}]` +
                  ` cycles=${this.slaveCPU.totalCycles}`);
              }
            } else if (sPC === 0xFD85) {
              // Byte received in data loop — log first 10 + any non-data
              const byteNum = ((this as any)._dataLoopByteNum || 0);
              (this as any)._dataLoopByteNum = byteNum + 1;
              const ss = this.slaveCPU.saveState();
              if (byteNum < 10 || byteNum >= (this.slaveCPU.X + byteNum - 3)) {
                console.log(`[SAVE] FD85 byte #${byteNum}: RDR=0x${(ss.rdr as number).toString(16).padStart(2,'0')} X=${this.slaveCPU.X} cycles=${this.slaveCPU.totalCycles}`);
              }
            } else if (sPC === 0xFD90) {
              // Post-data loop — slave exited the data loop
              const byteNum = (this as any)._dataLoopByteNum || 0;
              console.log(`[SAVE] Data loop exited at FD90: processed ${byteNum} bytes, cycles=${this.slaveCPU.totalCycles}`);
            } else if (sPC === 0xFE00) {
              // First entry to FSK inner loop — log FRC/OCR/OCF state
              if (!(this as any)._fskLogged) {
                (this as any)._fskLogged = true;
                const ss = this.slaveCPU.saveState();
                const tcsr = ss.tcsr as number;
                console.log(`[FSK] First FE00 entry: FRC=${(ss.frc as number).toString(16)} ` +
                  `OCR=${(ss.ocr as number).toString(16)} TCSR=${tcsr.toString(16)} ` +
                  `OCF=${(tcsr & 0x40) ? 'SET' : 'clear'} ` +
                  `totalCycles=${this.slaveCPU.totalCycles}`);
              }
            } else if (sPC === 0xFD2B && !(this as any)._leaderStarted) {
              (this as any)._leaderStarted = true;
              console.log(`[SAVE] Leader started at FD2B: cycles=${this.slaveCPU.totalCycles}`);
            } else if (sPC === 0xF061) {
              // Command dispatch: slave reads RDR at F061 (LDAA $12)
              // At this point TRCSR was already read at F059 (RDRF check passed)
              // The next instruction reads RDR, so let's peek at what's coming
              const ss = this.slaveCPU.saveState();
              const rdr = ss.rdr as number;
              console.log(`[SLAVE] F061: Command dispatch, RDR=0x${rdr.toString(16).padStart(2,'0')} cycles=${this.slaveCPU.totalCycles}`);
            } else if (sPC === 0xFD0C) {
              // After first F10A: STD $84 — log the byte count parameters
              console.log(`[SAVE] FD0C: F10A#1 result: A=0x${this.slaveCPU.A.toString(16).padStart(2,'0')} B=0x${this.slaveCPU.B.toString(16).padStart(2,'0')} → $84/$85`);
            } else if (sPC === 0xFD13) {
              // After second F10A: STD $b8 — this is the DATA BYTE COUNT
              const count = (this.slaveCPU.A << 8) | this.slaveCPU.B;
              console.log(`[SAVE] FD13: F10A#2 result: A=0x${this.slaveCPU.A.toString(16).padStart(2,'0')} B=0x${this.slaveCPU.B.toString(16).padStart(2,'0')} → $b8/$b9 = byte count ${count} (0x${count.toString(16)})`);
            } else if (sPC === 0xFDD2) {
              // Data loop exit via P40=LOW (motor stopped)
              const byteNum = (this as any)._dataLoopByteNum || 0;
              console.log(`[SAVE] FDD2: Data loop exit via P40=LOW after ${byteNum} bytes, mode=$81=${this.slaveCPU.readRAM(0x81)}`);
            } else if (sPC === 0xFD7C) {
              console.log(`[SAVE] FD7C: Error path (ORFE during trailer OR abort)`);
            } else if (sPC === 0xF09D) {
              console.log(`[SAVE] Slave entered F09D (ERROR exit — sends 0x02)`);
            } else if (sPC === 0xFDC6) {
              console.log(`[SAVE] Slave entered FDC6 (OCF timeout — sends 0x6F)`);
            } else if (sPC === 0xFDE1) {
              console.log(`[SAVE] Slave at FDE1 — cleanup path`);
            }

            // --- LOAD diagnostic breakpoints ---
            if (sPC === 0xF773) {
              // LOAD handler entry
              const ram = this.slaveCPU.readRAM;
              console.log(`[LOAD] F773: LOAD handler entry, mode=0x${this.slaveCPU.A.toString(16).padStart(2,'0')}`);
              console.log(`[LOAD] FSK timing: $9D/${(ram(0x9D)<<8|ram(0x9E)).toString(16)} ` +
                `$9F/${(ram(0x9F)<<8|ram(0xA0)).toString(16)} ` +
                `$A1/${(ram(0xA1)<<8|ram(0xA2)).toString(16)} ` +
                `$A3/${(ram(0xA3)<<8|ram(0xA4)).toString(16)} ` +
                `$A5=0x${ram(0xA5).toString(16).padStart(2,'0')}`);
              console.log(`[LOAD] CAS0: timing: $A8/${(ram(0xA8)<<8|ram(0xA9)).toString(16)} ` +
                `$AA/${(ram(0xAA)<<8|ram(0xAB)).toString(16)}`);
              (this as any)._loadStartCycles = this.slaveCPU.totalCycles;
              (this as any)._loadBytesDecoded = 0;
              (this as any)._loadBytesSent = 0;
              (this as any)._loadSyncFound = false;
              (this as any)._loadLeaderRestarts = 0;
              (this as any)._loadSyncAttempts = 0;
              (this as any)._loadLeaderStarted = false;
            } else if (sPC === 0xF784) {
              // After F10A: byte count stored
              const count = (this.slaveCPU.A << 8) | this.slaveCPU.B;
              console.log(`[LOAD] F784: byte count from master: ${count} (0x${count.toString(16)})`);
            } else if (sPC === 0xF78F) {
              // Leader search start
              if (!(this as any)._loadLeaderStarted) {
                (this as any)._loadLeaderStarted = true;
                console.log(`[LOAD] F78F: Starting leader search. $A5=0x${this.slaveCPU.readRAM(0xA5).toString(16).padStart(2,'0')} ` +
                  `P32=${this.cas1.readLevel ? 'HIGH' : 'LOW'} ` +
                  `playIdx=${Math.floor((this.cas1 as any).playIdx/2)}/${Math.floor((this.cas1 as any).playData.length/2)}`);
                this.cas1.dumpTapeStats();
              }
            } else if (sPC === 0xF7D2) {
              // Trying 7-bit sync byte decode (found a "0" bit after leader)
              const attempts = ((this as any)._loadSyncAttempts || 0) + 1;
              (this as any)._loadSyncAttempts = attempts;
              if (attempts <= 20) {
                console.log(`[LOAD] F7D2: Sync attempt #${attempts} — trying 7-bit decode`);
              }
            } else if (sPC === 0xF7D6) {
              // After F833 returns: A = decoded 7-bit byte, about to INCA
              const attempts = (this as any)._loadSyncAttempts || 0;
              if (attempts <= 20) {
                console.log(`[LOAD] F7D6: 7-bit result A=0x${this.slaveCPU.A.toString(16).padStart(2,'0')} ` +
                  `(need 0xFF). INCA→0x${((this.slaveCPU.A + 1) & 0xFF).toString(16).padStart(2,'0')}`);
              }
            } else if (sPC === 0xF7D9) {
              // 7-bit matched 0xFF! Now trying 8-bit decode for $AA marker
              console.log(`[LOAD] F7D9: 7-bit sync OK (was 0xFF). Trying 8-bit decode for 0xAA`);
            } else if (sPC === 0xF7DD) {
              // After F838 returns: A = decoded 8-bit byte, about to EORA #$AA
              console.log(`[LOAD] F7DD: 8-bit result A=0x${this.slaveCPU.A.toString(16).padStart(2,'0')} ` +
                `(need 0xAA). XOR=0x${(this.slaveCPU.A ^ 0xAA).toString(16).padStart(2,'0')} ` +
                `$82=0x${this.slaveCPU.readRAM(0x82).toString(16).padStart(2,'0')}`);
            } else if (sPC === 0xF7E1) {
              // Sync verified, CRC cleared — about to read data
              const ram = this.slaveCPU.readRAM;
              const elapsed = this.slaveCPU.totalCycles - ((this as any)._loadStartCycles || 0);
              console.log(`[LOAD] F7E1: Sync found! $A5=0x${ram(0xA5).toString(16).padStart(2,'0')} ` +
                `elapsed=${elapsed} (${(elapsed/614400).toFixed(2)}s) ` +
                `restarts=${(this as any)._loadLeaderRestarts || 0} syncAttempts=${(this as any)._loadSyncAttempts || 0}`);
            } else if (sPC === 0xF7E6) {
              // First data byte read — also log X (byte count)
              console.log(`[LOAD] F7E6: Reading first data byte, X=${this.slaveCPU.X} (byte count)`);
            } else if (sPC === 0xF88C) {
              // F838 byte decode returned — A = decoded byte
              const n = ((this as any)._loadBytesDecoded || 0);
              (this as any)._loadBytesDecoded = n + 1;
              if (n < 20 || (n % 50 === 0)) {
                console.log(`[LOAD] FSK decoded byte #${n}: 0x${this.slaveCPU.A.toString(16).padStart(2,'0')} ` +
                  `(${this.slaveCPU.A >= 0x20 && this.slaveCPU.A < 0x7F ? String.fromCharCode(this.slaveCPU.A) : '.'}) ` +
                  `playIdx=${Math.floor((this.cas1 as any).playIdx/2)}/${Math.floor((this.cas1 as any).playData.length/2)}`);
              }
            } else if (sPC === 0xF80C) {
              // Byte sent to master via F14B
              const n = ((this as any)._loadBytesSent || 0);
              (this as any)._loadBytesSent = n + 1;
              if (n < 20 || (n % 50 === 0)) {
                console.log(`[LOAD] F80C: Sending byte #${n}: 0x${this.slaveCPU.A.toString(16).padStart(2,'0')}`);
              }
            } else if (sPC === 0xF82C) {
              // LOAD success
              const elapsed = this.slaveCPU.totalCycles - ((this as any)._loadStartCycles || 0);
              console.log(`[LOAD] F82C: LOAD success! ${(this as any)._loadBytesDecoded} bytes decoded, ` +
                `${(this as any)._loadBytesSent} bytes sent, ${elapsed} cycles (${(elapsed/614400).toFixed(2)}s)`);
              (this as any)._loadLeaderStarted = false;
            } else if (sPC === 0xF82E) {
              // LOAD error exit
              console.log(`[LOAD] F82E: Error exit. restarts=${(this as any)._loadLeaderRestarts || 0} ` +
                `syncAttempts=${(this as any)._loadSyncAttempts || 0}`);
              (this as any)._loadLeaderStarted = false;
            } else if (sPC === 0xF793) {
              // Leader search restart
              const restarts = ((this as any)._loadLeaderRestarts || 0) + 1;
              (this as any)._loadLeaderRestarts = restarts;
              if (restarts <= 10 || restarts % 100 === 0) {
                const elapsed = this.slaveCPU.totalCycles - ((this as any)._loadStartCycles || 0);
                console.log(`[LOAD] F793: Restart #${restarts} at ${(elapsed/614400).toFixed(2)}s ` +
                  `playIdx=${Math.floor((this.cas1 as any).playIdx/2)}/${Math.floor((this.cas1 as any).playData.length/2)}`);
              }
            }
          }
          const sc = this.slaveCPU.step();
          slaveCycles += sc;
          this.cas0.advance(sc);
          this.cas1.advance(sc);
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
      this.cas0.advance(sc);
      this.cas1.advance(sc);
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
