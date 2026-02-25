// Epson HX-20 System Integration
// Wires together dual CPUs, memory, LCD, keyboard, RTC

import { HD6301 } from './cpu';
import { LCDDisplay } from './lcd';
import { Keyboard } from './keyboard';
import { MC146818 } from './rtc';
import { loadIntelHexIntoBuffer, loadBinaryIntoBuffer } from './rom-loader';

// FakeSecondary: responds to slave CPU boot protocol commands
// This replaces the real slave CPU for serial communication during boot
class FakeSecondary {
  private inBuf: number[] = [];
  private outBuf: number[] = [];
  private state = 0;

  reset(): void {
    this.inBuf = [];
    this.outBuf = [];
    this.state = 0;
  }

  send(data: number): void {
    this.inBuf.push(data & 0xFF);
  }

  recv(): number | undefined {
    return this.outBuf.shift();
  }

  step(): void {
    while (this.inBuf.length > 0) {
      const c = this.inBuf.shift()!;
      if (this.state === 0) {
        if (c === 0x00 || c === 0x02 || c === 0x03 || c === 0x04) {
          this.outBuf.push(0x01);
        } else if (c === 0x0c) {
          this.outBuf.push(0x02);
        } else if (c === 0x0d) {
          this.outBuf.push(0x01);
          this.state = 1;
        } else if (c === 0x50) {
          this.outBuf.push(0x00);
        } else if (c === 0x46) {
          // Handshake ping - ROM sends this before some commands
          this.outBuf.push(0x01);
        } else {
          // Unknown command - respond with 0x01 (ACK) to avoid hangs
          console.warn(`FakeSecondary: unknown cmd 0x${c.toString(16).padStart(2, '0')}, responding 0x01`);
          this.outBuf.push(0x01);
        }
      } else if (this.state === 1) {
        this.state = 0;
        if (c === 0xaa) {
          this.outBuf.push(0x01);
        } else {
          console.warn(`FakeSecondary: state=1 unexpected 0x${c.toString(16).padStart(2, '0')}`);
          this.outBuf.push(0x01);
        }
      }
    }
  }
}

export class HX20 {
  mainCPU: HD6301;
  slaveCPU: HD6301;
  lcd: LCDDisplay;
  keyboard: Keyboard;
  rtc: MC146818;

  // Main CPU memory
  mainRAM = new Uint8Array(0x4000);    // 16KB at 0x0100-0x3FFF
  mainROM = new Uint8Array(0x8000);    // 32KB at 0x8000-0xFFFF
  optionROM = new Uint8Array(0x2000);  // 8KB at 0x6000-0x7FFF
  hasOptionROM = false;

  // Slave CPU memory (internal 4KB ROM loaded separately)
  slaveROM: Uint8Array | null = null;

  // Inter-CPU serial communication
  private slaveTx = 1;   // slave → main
  private slaveRx = 1;   // main → slave
  private slaveFlag = 1; // slave status flag
  private slaveSio = 0;  // 0 = SIO bus, 1 = slave CPU

  // FakeSecondary for SCI serial boot protocol
  private fakeSecondary = new FakeSecondary();

  // I/O state
  private ksc = 0;           // keyboard scan column
  private rtcIrq = false;

  // Running state
  running = false;
  private animFrameId = 0;
  speedMultiplier = 1;

  // Timing
  static readonly CRYSTAL = 2457600;  // 2.4576 MHz
  static readonly E_CLOCK = HX20.CRYSTAL / 4; // 614.4 KHz
  static readonly FRAME_RATE = 60;
  static readonly CYCLES_PER_FRAME = Math.floor(HX20.E_CLOCK / HX20.FRAME_RATE);

  onStatusUpdate: (text: string) => void = () => {};
  onRegistersUpdate: (text: string) => void = () => {};

  constructor() {
    this.mainCPU = new HD6301('Main');
    this.slaveCPU = new HD6301('Slave');
    this.lcd = new LCDDisplay();
    this.keyboard = new Keyboard();
    this.rtc = new MC146818();

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
      // Bit 7: cartridge MI1 (1 = no cartridge/microcassette)
      val |= 0x80;
      // Bit 6: serial PIN
      // Bit 5: keyboard request (active low: 0 = request pending)
      if (!this.keyboard.irqPending) val |= 0x20;
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
      // Bit 2: slave flag (inverted)
      if (!this.slaveFlag) val |= 0x04;
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
      let val = 0xE0; // mode pins
      // Bit 3: reads slaveTx (our own TX, for loopback check)
      val |= (this.slaveRx ? 0 : 0) | 0x08; // Simplified: always high
      return val;
    };

    cpu.onWritePort2 = (val: number): void => {
      // Bit 4: RX line to main CPU
      this.slaveTx = (val >> 4) & 1;
    };

    // Port 3
    cpu.onReadPort3 = (): number => {
      return 0xFF; // cassette read data etc
    };

    cpu.onWritePort3 = (val: number): void => {
      // Bit 7: program power
      // Bit 4: slave flag
      this.slaveFlag = (val >> 4) & 1;
    };

    // Port 4
    cpu.onReadPort4 = (): number => {
      return 0x7F; // bit 7 (CD) high = no carrier
    };
    cpu.onWritePort4 = () => {};
  }

  private wireSerial(): void {
    // When main CPU sends a byte via SCI TDR, route to FakeSecondary
    this.mainCPU.onSerialSend = (data: number) => {
      console.log(`SCI TX: 0x${data.toString(16).padStart(2, '0')} (PC=${this.mainCPU.PC.toString(16).padStart(4, '0')})`);
      this.fakeSecondary.send(data);
      // Immediately process and feed responses back
      this.fakeSecondary.step();
      let response: number | undefined;
      while ((response = this.fakeSecondary.recv()) !== undefined) {
        console.log(`SCI RX: 0x${response.toString(16).padStart(2, '0')}`);
        this.mainCPU.serialRecv(response);
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
    // Not gated by keyIntEnable — LCDCTL bit 4 controls the SLP wakeup circuit,
    // but the keyboard always drives IRQ1 until acknowledged.
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
    // On real hardware, the RAM sizing routine (E19D) runs once during initial
    // setup and stores the end-of-RAM address in $0134/$012C. This value
    // persists in battery-backed RAM across power cycles. Since we clear RAM
    // on reset, we must pre-initialize it here.
    // $0134/$012C = end of RAM address (one past last byte)
    // For 16KB: RAM extends from $004E to $3FFF, so end = $4000
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

    this.lcd.reset();
    this.keyboard.reset();
    this.rtc.reset();
    this.fakeSecondary.reset();
    this.mainCPU.reset();
    if (this.slaveROM) {
      this.slaveCPU.reset();
    }
  }

  // Run one frame's worth of CPU cycles
  runFrame(): void {
    const targetCycles = HX20.CYCLES_PER_FRAME * this.speedMultiplier;

    // Transfer any pending key events to the IRQ latch
    if (this.keyboard.hasKeyRequest()) {
      this.keyboard.clearKeyRequest();
    }
    this.updateMainIRQ();

    // Run main CPU
    let mainCyclesRun = 0;
    while (mainCyclesRun < targetCycles) {
      mainCyclesRun += this.mainCPU.step();
    }

    // Run slave CPU in lockstep (if ROM loaded)
    if (this.slaveROM) {
      let slaveCyclesRun = 0;
      while (slaveCyclesRun < targetCycles) {
        slaveCyclesRun += this.slaveCPU.step();
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
    if (this.slaveROM) this.slaveCPU.step();
    this.lcd.render();
    this.onRegistersUpdate(this.mainCPU.dumpRegisters());
  }
}
