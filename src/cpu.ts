// HD6301/HD6303 CPU Emulator
// Covers both master (HD6303R) and slave (HD6301V1) CPUs

const FLAG_C = 0x01;
const FLAG_V = 0x02;
const FLAG_Z = 0x04;
const FLAG_N = 0x08;
const FLAG_I = 0x10;
const FLAG_H = 0x20;

export class HD6301 {
  // Registers
  A = 0; B = 0; X = 0; SP = 0; PC = 0; CC = 0xD0;

  // State
  halted = false;
  sleeping = false;
  irq1Line = false;
  irq2Line = false;
  nmiLine = false;
  nmiPending = false;
  totalCycles = 0;

  // Internal I/O registers
  private p1ddr = 0; private p2ddr = 0;
  private p1out = 0; private p2out = 0;
  private p3ddr = 0; private p4ddr = 0;
  private p3out = 0; private p4out = 0;
  private tcsr = 0;
  private frc = 0;
  private frcLatch = 0;
  private ocr = 0xFFFF;
  private ocrH = 0xFF;
  private icr = 0;
  private p3csr = 0;
  private rmcr = 0;
  private trcsr = 0x20; // TDRE set
  private rdr = 0;
  private tdr = 0;
  private ramcr = 0x40;
  // TCSR two-step flag clearing: bitmask of flags armed for clearing
  // After reading TCSR with a flag set, the appropriate second step clears it:
  //   ICF (bit 7): read ICR_H    OCF (bit 6): write OCR_L    TOF (bit 5): read FRC_H
  private tcsrArmed = 0;

  // SCI serial receive buffer and RDRF two-step clearing
  private sciRecvBuf: number[] = [];
  private rdrfClearStep = 0;

  // Input capture: P20 level tracking for edge detection
  private lastP20 = true;  // P20 input level (default high = idle)

  // SCI TX timing: TDRE stays clear for sciTxTimer cycles after TDR write,
  // modeling the real ~160-cycle transmission time at 38400 baud.
  // The byte is delivered to the receiver only when the timer expires.
  private sciTxTimer = 0;
  private sciTxPending = false;
  private sciTxByte = 0;
  sciTxWritePC = 0;  // PC when TDR was written (for debug logging)

  // Internal RAM (128 bytes at 0x80-0xFF)
  ram = new Uint8Array(128);  // Internal RAM $0080-$00FF (battery-backed on real hardware)

  // Internal ROM (4KB for HD6301V1, null for HD6303R)
  internalROM: Uint8Array | null = null;

  // Port callbacks
  onReadPort1: () => number = () => 0xFF;
  onReadPort2: () => number = () => 0xFF;
  onReadPort3: () => number = () => 0xFF;
  onReadPort4: () => number = () => 0xFF;
  onWritePort1: (val: number) => void = () => {};
  onWritePort2: (val: number) => void = () => {};
  onWritePort3: (val: number) => void = () => {};
  onWritePort4: (val: number) => void = () => {};

  // External bus
  onRead: (addr: number) => number = () => 0xFF;
  onWrite: (addr: number, val: number) => void = () => {};

  // SCI callback: called when CPU writes to TDR (sends a byte)
  onSerialSend: (data: number) => void = () => {};

  // Debug callback: called when RDR is read (for tracing receive side)
  onSerialRead: (data: number, pc: number) => void = () => {};

  // Output compare callback: called when P21 changes due to OLVL/OCR match
  onOCOutput: (level: boolean) => void = () => {};

  // Receive a serial byte (models real SCI shift register + RDR double buffering)
  // Real SCI has: shift register (1 byte receiving) + RDR (1 byte ready to read)
  // sciRecvBuf models the shift register (max 1 byte).
  // Overrun occurs when shift register has a pending byte OR RDR hasn't been read (RDRF set).
  // On real hardware: shift register completes while RDRF set → ORFE, new byte lost.
  serialRecv(data: number): void {
    if (this.sciRecvBuf.length > 0 || (this.trcsr & 0x80)) {
      // Shift register full or RDR unread — overrun, new byte lost
      this.trcsr |= 0x40; // Set ORFE (bit 6)
      console.warn(`${this.name}: SCI OVERRUN (ORFE) at PC=0x${this.PC.toString(16).padStart(4,'0')}, ` +
        `lost byte=0x${(data & 0xFF).toString(16).padStart(2,'0')}, ` +
        `reason=${this.sciRecvBuf.length > 0 ? 'shift_reg_full(0x' + this.sciRecvBuf[0].toString(16) + ')' : 'RDRF_set'}`);
    } else {
      this.sciRecvBuf.push(data & 0xFF);
    }
  }

  constructor(public name: string = 'CPU') {}

  /** Read internal RAM (0x80-0xFF) for diagnostics. Returns value at given address. */
  readRAM = (addr: number): number => {
    if (addr >= 0x80 && addr < 0x100) return this.ram[addr - 0x80];
    return this.read(addr);
  };

  reset(): void {
    this.CC = 0xD0; // I flag set, bits 6-7 set
    this.halted = false;
    this.sleeping = false;
    this.tcsr = 0;
    this.frc = 0;       // Handbook: "counter is cleared during reset"
    this.ocr = 0xFFFF;
    this.trcsr = 0x20;
    this.rmcr = 0;
    this.sciRecvBuf = [];
    this.rdrfClearStep = 0;
    this.sciTxTimer = 0;
    this.sciTxPending = false;
    this.sciTxByte = 0;
    this.p1ddr = 0; this.p2ddr = 0;
    this.p3ddr = 0; this.p4ddr = 0;
    this.p1out = 0; this.p2out = 0;
    this.p3out = 0; this.p4out = 0;
    this.PC = this.readWord(0xFFFE);
  }

  // --- Memory Access ---

  read(addr: number): number {
    addr &= 0xFFFF;
    if (addr < 0x20) return this.readRegister(addr);
    if (addr >= 0x80 && addr < 0x100) return this.ram[addr - 0x80];
    if (this.internalROM && addr >= 0xF000) return this.internalROM[addr - 0xF000];
    return this.onRead(addr);
  }

  write(addr: number, val: number): void {
    addr &= 0xFFFF;
    val &= 0xFF;
    if (addr < 0x20) { this.writeRegister(addr, val); return; }
    if (addr >= 0x80 && addr < 0x100) { this.ram[addr - 0x80] = val; return; }
    this.onWrite(addr, val);
  }

  readWord(addr: number): number {
    return (this.read(addr) << 8) | this.read((addr + 1) & 0xFFFF);
  }

  writeWord(addr: number, val: number): void {
    this.write(addr, (val >> 8) & 0xFF);
    this.write((addr + 1) & 0xFFFF, val & 0xFF);
  }

  private readRegister(addr: number): number {
    switch (addr) {
      case 0x00: return this.p1ddr;
      case 0x01: return this.p2ddr;
      case 0x02: return (this.p1out & this.p1ddr) | (this.onReadPort1() & ~this.p1ddr);
      case 0x03: return (this.p2out & this.p2ddr) | (this.onReadPort2() & ~this.p2ddr);
      case 0x04: return this.p3ddr;
      case 0x05: return this.p4ddr;
      case 0x06: return (this.p3out & this.p3ddr) | (this.onReadPort3() & ~this.p3ddr);
      case 0x07: return (this.p4out & this.p4ddr) | (this.onReadPort4() & ~this.p4ddr);
      case 0x08: this.tcsrArmed = this.tcsr & 0xE0; return this.tcsr;
      case 0x09:
        if (this.tcsrArmed & 0x20) {
          this.tcsr &= ~0x20; this.tcsrArmed &= ~0x20;
        } // Clear TOF
        this.frcLatch = this.frc; return (this.frc >> 8) & 0xFF;
      case 0x0A: return this.frcLatch & 0xFF;
      case 0x0B: return (this.ocr >> 8) & 0xFF;
      case 0x0C: return this.ocr & 0xFF;
      case 0x0D:
        if (this.tcsrArmed & 0x80) { this.tcsr &= ~0x80; this.tcsrArmed &= ~0x80; } // Clear ICF
        return (this.icr >> 8) & 0xFF;
      case 0x0E: return this.icr & 0xFF;
      case 0x0F: return this.p3csr;
      case 0x10: return this.rmcr;
      case 0x11:
        // RDRF two-step clearing: step 1 - read TRCSR with RDRF set
        if ((this.trcsr & 0x80) && this.rdrfClearStep === 0) {
          this.rdrfClearStep = 1;
        }
        return this.trcsr;
      case 0x12:
        // RDRF two-step clearing: step 2 - read RDR after reading TRCSR with RDRF
        // Clears both RDRF (bit 7) and ORFE (bit 6) per HD6301 handbook
        if (this.rdrfClearStep === 1) {
          this.trcsr &= ~0xC0; // Clear RDRF and ORFE
          this.rdrfClearStep = 0;
          this.onSerialRead(this.rdr, this.PC);
        }
        return this.rdr;
      case 0x13: return this.tdr;
      case 0x14: return this.ramcr;
      default: return 0xFF;
    }
  }

  private writeRegister(addr: number, val: number): void {
    switch (addr) {
      case 0x00: this.p1ddr = val; break;
      case 0x01: this.p2ddr = val; this.onWritePort2(this.p2out & val); break;
      case 0x02: this.p1out = val; this.onWritePort1(val & this.p1ddr); break;
      case 0x03: this.p2out = val; this.onWritePort2(val & this.p2ddr); break;
      case 0x04: this.p3ddr = val; break;
      case 0x05: this.p4ddr = val; break;
      case 0x06: this.p3out = val; this.onWritePort3(val & this.p3ddr); break;
      case 0x07: this.p4out = val; this.onWritePort4(val & this.p4ddr); break;
      case 0x08: this.tcsr = (this.tcsr & 0xE0) | (val & 0x1F); break;
      case 0x09: this.frc = (val << 8) | (this.frc & 0xFF); break;
      case 0x0A: this.frc = (this.frc & 0xFF00) | val; break;
      case 0x0B: this.ocrH = val; break;
      case 0x0C:
        this.ocr = (this.ocrH << 8) | val;
        if (this.tcsrArmed & 0x40) { this.tcsr &= ~0x40; this.tcsrArmed &= ~0x40; } // Clear OCF
        break;
      case 0x0F: this.p3csr = val; break;
      case 0x10: this.rmcr = val & 0x0F; break;
      case 0x11: this.trcsr = (this.trcsr & 0xE0) | (val & 0x1F); break;
      case 0x13:
        this.tdr = val;
        this.trcsr &= ~0x20; // Clear TDRE (transmitting)
        this.sciTxTimer = 160; // ~160 cycles per byte at 38400 baud (E/16)
        this.sciTxPending = true;
        this.sciTxByte = val;  // Byte delivered when timer expires (models real TX time)
        this.sciTxWritePC = this.PC;
        break;
      case 0x14: this.ramcr = val; break;
    }
  }

  // --- Addressing Helpers ---

  private fetchByte(): number {
    const v = this.read(this.PC);
    this.PC = (this.PC + 1) & 0xFFFF;
    return v;
  }

  private fetchWord(): number {
    const h = this.read(this.PC);
    this.PC = (this.PC + 1) & 0xFFFF;
    const l = this.read(this.PC);
    this.PC = (this.PC + 1) & 0xFFFF;
    return (h << 8) | l;
  }

  private addrDir(): number { return this.fetchByte(); }
  private addrExt(): number { return this.fetchWord(); }
  private addrIdx(): number { return (this.X + this.fetchByte()) & 0xFFFF; }

  // --- Stack ---

  private pushByte(val: number): void {
    this.write(this.SP, val & 0xFF);
    this.SP = (this.SP - 1) & 0xFFFF;
  }

  private pushWord(val: number): void {
    this.pushByte(val & 0xFF);
    this.pushByte((val >> 8) & 0xFF);
  }

  private pullByte(): number {
    this.SP = (this.SP + 1) & 0xFFFF;
    return this.read(this.SP);
  }

  private pullWord(): number {
    const h = this.pullByte();
    const l = this.pullByte();
    return (h << 8) | l;
  }

  // --- Flag Helpers ---

  private setNZ8(val: number): void {
    this.CC = (this.CC & ~(FLAG_N | FLAG_Z)) |
      ((val & 0x80) ? FLAG_N : 0) |
      ((val & 0xFF) === 0 ? FLAG_Z : 0);
  }

  private setNZ16(val: number): void {
    this.CC = (this.CC & ~(FLAG_N | FLAG_Z)) |
      ((val & 0x8000) ? FLAG_N : 0) |
      ((val & 0xFFFF) === 0 ? FLAG_Z : 0);
  }

  // --- 8-bit ALU Operations ---

  private opADD(a: number, b: number): number {
    const r = a + b;
    const r8 = r & 0xFF;
    this.CC = (this.CC & FLAG_I) |
      (((a ^ b ^ r8) & 0x10) ? FLAG_H : 0) |
      ((r8 & 0x80) ? FLAG_N : 0) |
      (r8 === 0 ? FLAG_Z : 0) |
      (((a ^ r8) & (b ^ r8) & 0x80) ? FLAG_V : 0) |
      (r > 0xFF ? FLAG_C : 0);
    return r8;
  }

  private opADC(a: number, b: number): number {
    const c = this.CC & FLAG_C;
    const r = a + b + c;
    const r8 = r & 0xFF;
    this.CC = (this.CC & FLAG_I) |
      (((a ^ b ^ r8) & 0x10) ? FLAG_H : 0) |
      ((r8 & 0x80) ? FLAG_N : 0) |
      (r8 === 0 ? FLAG_Z : 0) |
      (((a ^ r8) & (b ^ r8) & 0x80) ? FLAG_V : 0) |
      (r > 0xFF ? FLAG_C : 0);
    return r8;
  }

  private opSUB(a: number, b: number): number {
    const r = a - b;
    const r8 = r & 0xFF;
    this.CC = (this.CC & (FLAG_I | FLAG_H)) |
      ((r8 & 0x80) ? FLAG_N : 0) |
      (r8 === 0 ? FLAG_Z : 0) |
      (((a ^ b) & (a ^ r8) & 0x80) ? FLAG_V : 0) |
      (r < 0 ? FLAG_C : 0);
    return r8;
  }

  private opSBC(a: number, b: number): number {
    const c = this.CC & FLAG_C;
    const r = a - b - c;
    const r8 = r & 0xFF;
    this.CC = (this.CC & (FLAG_I | FLAG_H)) |
      ((r8 & 0x80) ? FLAG_N : 0) |
      (r8 === 0 ? FLAG_Z : 0) |
      (((a ^ b) & (a ^ r8) & 0x80) ? FLAG_V : 0) |
      (r < 0 ? FLAG_C : 0);
    return r8;
  }

  private opCMP(a: number, b: number): void { this.opSUB(a, b); }

  private opAND(a: number, b: number): number {
    const r = a & b;
    this.CC = (this.CC & ~(FLAG_N | FLAG_Z | FLAG_V)) |
      ((r & 0x80) ? FLAG_N : 0) |
      (r === 0 ? FLAG_Z : 0);
    return r;
  }

  private opOR(a: number, b: number): number {
    const r = (a | b) & 0xFF;
    this.CC = (this.CC & ~(FLAG_N | FLAG_Z | FLAG_V)) |
      ((r & 0x80) ? FLAG_N : 0) |
      (r === 0 ? FLAG_Z : 0);
    return r;
  }

  private opEOR(a: number, b: number): number {
    const r = (a ^ b) & 0xFF;
    this.CC = (this.CC & ~(FLAG_N | FLAG_Z | FLAG_V)) |
      ((r & 0x80) ? FLAG_N : 0) |
      (r === 0 ? FLAG_Z : 0);
    return r;
  }

  private opBIT(a: number, b: number): void { this.opAND(a, b); }

  private opLD8(val: number): number {
    this.CC = (this.CC & ~(FLAG_N | FLAG_Z | FLAG_V)) |
      ((val & 0x80) ? FLAG_N : 0) |
      ((val & 0xFF) === 0 ? FLAG_Z : 0);
    return val & 0xFF;
  }

  private opST8(val: number): number {
    this.CC = (this.CC & ~(FLAG_N | FLAG_Z | FLAG_V)) |
      ((val & 0x80) ? FLAG_N : 0) |
      ((val & 0xFF) === 0 ? FLAG_Z : 0);
    return val & 0xFF;
  }

  // --- 16-bit ALU Operations ---

  private get D(): number { return (this.A << 8) | this.B; }
  private set D(val: number) { this.A = (val >> 8) & 0xFF; this.B = val & 0xFF; }

  private opADDD(d: number, val: number): number {
    const r = d + val;
    const r16 = r & 0xFFFF;
    this.CC = (this.CC & (FLAG_I | FLAG_H)) |
      ((r16 & 0x8000) ? FLAG_N : 0) |
      (r16 === 0 ? FLAG_Z : 0) |
      (((d ^ r16) & (val ^ r16) & 0x8000) ? FLAG_V : 0) |
      (r > 0xFFFF ? FLAG_C : 0);
    return r16;
  }

  private opSUBD(d: number, val: number): number {
    const r = d - val;
    const r16 = r & 0xFFFF;
    this.CC = (this.CC & (FLAG_I | FLAG_H)) |
      ((r16 & 0x8000) ? FLAG_N : 0) |
      (r16 === 0 ? FLAG_Z : 0) |
      (((d ^ val) & (d ^ r16) & 0x8000) ? FLAG_V : 0) |
      (r < 0 ? FLAG_C : 0);
    return r16;
  }

  private opCPX(x: number, val: number): void {
    const r = x - val;
    const r16 = r & 0xFFFF;
    this.CC = (this.CC & (FLAG_I | FLAG_H)) |
      ((r16 & 0x8000) ? FLAG_N : 0) |
      (r16 === 0 ? FLAG_Z : 0) |
      (((x ^ val) & (x ^ r16) & 0x8000) ? FLAG_V : 0) |
      (r < 0 ? FLAG_C : 0);
  }

  private opLD16(val: number): number {
    this.CC = (this.CC & ~(FLAG_N | FLAG_Z | FLAG_V)) |
      ((val & 0x8000) ? FLAG_N : 0) |
      ((val & 0xFFFF) === 0 ? FLAG_Z : 0);
    return val & 0xFFFF;
  }

  private opST16(val: number): number {
    this.CC = (this.CC & ~(FLAG_N | FLAG_Z | FLAG_V)) |
      ((val & 0x8000) ? FLAG_N : 0) |
      ((val & 0xFFFF) === 0 ? FLAG_Z : 0);
    return val & 0xFFFF;
  }

  // --- Memory RMW Operations ---

  private opNEG(val: number): number {
    const r = (-val) & 0xFF;
    this.CC = (this.CC & (FLAG_I | FLAG_H)) |
      ((r & 0x80) ? FLAG_N : 0) |
      (r === 0 ? FLAG_Z : 0) |
      (r === 0x80 ? FLAG_V : 0) |
      (r !== 0 ? FLAG_C : 0);
    return r;
  }

  private opCOM(val: number): number {
    const r = (~val) & 0xFF;
    this.CC = (this.CC & (FLAG_I | FLAG_H)) |
      ((r & 0x80) ? FLAG_N : 0) |
      (r === 0 ? FLAG_Z : 0) |
      FLAG_C; // V=0, C=1
    return r;
  }

  private opLSR(val: number): number {
    const c = val & 1;
    const r = (val >> 1) & 0x7F;
    this.CC = (this.CC & (FLAG_I | FLAG_H)) |
      (r === 0 ? FLAG_Z : 0) |
      (c ? FLAG_V : 0) | // V = N ^ C = 0 ^ C
      (c ? FLAG_C : 0);
    return r;
  }

  private opROR(val: number): number {
    const c = val & 1;
    const r = ((val >> 1) | ((this.CC & FLAG_C) ? 0x80 : 0)) & 0xFF;
    const n = r & 0x80;
    this.CC = (this.CC & (FLAG_I | FLAG_H)) |
      (n ? FLAG_N : 0) |
      (r === 0 ? FLAG_Z : 0) |
      ((n ? 1 : 0) ^ c ? FLAG_V : 0) |
      (c ? FLAG_C : 0);
    return r;
  }

  private opASR(val: number): number {
    const c = val & 1;
    const r = ((val >> 1) | (val & 0x80)) & 0xFF;
    const n = r & 0x80;
    this.CC = (this.CC & (FLAG_I | FLAG_H)) |
      (n ? FLAG_N : 0) |
      (r === 0 ? FLAG_Z : 0) |
      ((n ? 1 : 0) ^ c ? FLAG_V : 0) |
      (c ? FLAG_C : 0);
    return r;
  }

  private opASL(val: number): number {
    const c = (val >> 7) & 1;
    const r = (val << 1) & 0xFF;
    const n = r & 0x80;
    this.CC = (this.CC & (FLAG_I | FLAG_H)) |
      (n ? FLAG_N : 0) |
      (r === 0 ? FLAG_Z : 0) |
      ((n ? 1 : 0) ^ c ? FLAG_V : 0) |
      (c ? FLAG_C : 0);
    return r;
  }

  private opROL(val: number): number {
    const c = (val >> 7) & 1;
    const r = ((val << 1) | (this.CC & FLAG_C)) & 0xFF;
    const n = r & 0x80;
    this.CC = (this.CC & (FLAG_I | FLAG_H)) |
      (n ? FLAG_N : 0) |
      (r === 0 ? FLAG_Z : 0) |
      ((n ? 1 : 0) ^ c ? FLAG_V : 0) |
      (c ? FLAG_C : 0);
    return r;
  }

  private opINC(val: number): number {
    const r = (val + 1) & 0xFF;
    this.CC = (this.CC & ~(FLAG_N | FLAG_Z | FLAG_V)) |
      ((r & 0x80) ? FLAG_N : 0) |
      (r === 0 ? FLAG_Z : 0) |
      (val === 0x7F ? FLAG_V : 0);
    return r;
  }

  private opDEC(val: number): number {
    const r = (val - 1) & 0xFF;
    this.CC = (this.CC & ~(FLAG_N | FLAG_Z | FLAG_V)) |
      ((r & 0x80) ? FLAG_N : 0) |
      (r === 0 ? FLAG_Z : 0) |
      (val === 0x80 ? FLAG_V : 0);
    return r;
  }

  private opTST(val: number): void {
    this.CC = (this.CC & (FLAG_I | FLAG_H)) |
      ((val & 0x80) ? FLAG_N : 0) |
      ((val & 0xFF) === 0 ? FLAG_Z : 0);
  }

  private opCLR(): number {
    this.CC = (this.CC & (FLAG_I | FLAG_H)) | FLAG_Z;
    return 0;
  }

  // --- Branch ---

  private branch(cond: boolean): number {
    const offset = this.fetchByte();
    if (cond) {
      const signed = offset > 127 ? offset - 256 : offset;
      this.PC = (this.PC + signed) & 0xFFFF;
    }
    return 3;
  }

  // --- Interrupt ---

  private pushAll(): void {
    this.pushWord(this.PC);
    this.pushWord(this.X);
    this.pushByte(this.A);
    this.pushByte(this.B);
    this.pushByte(this.CC);
  }

  checkInterrupts(): number {
    if (this.nmiPending) {
      this.nmiPending = false;
      this.halted = false;
      this.sleeping = false;
      this.pushAll();
      this.CC |= FLAG_I;
      this.PC = this.readWord(0xFFFC);
      return 12;
    }

    // Check if any maskable interrupt is pending (for SLP/WAI wakeup)
    const anyMaskableIRQ =
      ((this.tcsr & 0x80) && (this.tcsr & 0x10)) || // ICF & EICI
      ((this.tcsr & 0x40) && (this.tcsr & 0x08)) || // OCF & EOCI
      ((this.tcsr & 0x20) && (this.tcsr & 0x04)) || // TOF & ETOI
      this.irq1Line ||
      ((this.trcsr & 0x80) && (this.trcsr & 0x10)) || // RDRF & RIE
      ((this.trcsr & 0x20) && (this.trcsr & 0x04));    // TDRE & TIE

    // SLP/WAI wake on any interrupt request, even if I flag is set
    if ((this.sleeping || this.halted) && anyMaskableIRQ) {
      this.sleeping = false;
      this.halted = false;
    }

    if (!(this.CC & FLAG_I)) {
      // Timer interrupts
      if ((this.tcsr & 0x80) && (this.tcsr & 0x10)) { // ICF & EICI
        this.pushAll();
        this.CC |= FLAG_I;
        this.PC = this.readWord(0xFFF6);
        return 12;
      }
      if ((this.tcsr & 0x40) && (this.tcsr & 0x08)) { // OCF & EOCI
        this.pushAll();
        this.CC |= FLAG_I;
        this.PC = this.readWord(0xFFF4);
        return 12;
      }
      if ((this.tcsr & 0x20) && (this.tcsr & 0x04)) { // TOF & ETOI
        this.pushAll();
        this.CC |= FLAG_I;
        this.PC = this.readWord(0xFFF2);
        return 12;
      }
      // External IRQ1
      if (this.irq1Line) {
        this.pushAll();
        this.CC |= FLAG_I;
        this.PC = this.readWord(0xFFF8);
        return 12;
      }
      // SCI interrupt
      if (((this.trcsr & 0x80) && (this.trcsr & 0x10)) || // RDRF & RIE
          ((this.trcsr & 0x20) && (this.trcsr & 0x04))) {  // TDRE & TIE
        this.pushAll();
        this.CC |= FLAG_I;
        this.PC = this.readWord(0xFFF0);
        return 12;
      }
    }
    return 0;
  }

  updateTimer(cycles: number): void {
    const oldFrc = this.frc;
    this.frc = (this.frc + cycles) & 0xFFFF;
    // Timer overflow
    if (this.frc < oldFrc) {
      this.tcsr |= 0x20; // TOF
    }
    // Output compare match
    if ((oldFrc < this.ocr && this.frc >= this.ocr) ||
        (this.frc < oldFrc && this.ocr >= oldFrc) ||
        (this.frc < oldFrc && this.ocr <= this.frc)) {
      this.tcsr |= 0x40; // OCF
      // Drive P21 to OLVL level (output compare output)
      const olvl = this.tcsr & 0x01;
      const oldP21 = this.p2out & 0x02;
      if (olvl) this.p2out |= 0x02; else this.p2out &= ~0x02;
      if ((olvl ? 0x02 : 0) !== oldP21) {
        this.onOCOutput(!!olvl);
      }
    }
  }

  setNMI(state: boolean): void {
    if (!this.nmiLine && state) this.nmiPending = true;
    this.nmiLine = state;
  }

  /** Update P20 input level for input capture edge detection.
   *  When an edge matching IEDG polarity is detected, captures FRC→ICR and sets ICF. */
  setP20Input(level: boolean): void {
    if (level === this.lastP20) return;
    const iedg = this.tcsr & 0x02;  // IEDG bit: 1=rising, 0=falling
    const rising = level && !this.lastP20;
    if ((iedg && rising) || (!iedg && !rising)) {
      this.icr = this.frc;    // Capture FRC value
      this.tcsr |= 0x80;      // Set ICF
    }
    this.lastP20 = level;
  }

  // --- Step ---

  step(): number {
    // Check for incoming serial data (load into RDR if RDRF is clear)
    if (this.sciRecvBuf.length > 0 && !(this.trcsr & 0x80)) {
      this.trcsr |= 0x80; // Set RDRF
      this.rdr = this.sciRecvBuf.shift()!;
      this.rdrfClearStep = 0;
    }

    // Check interrupts
    const irqCycles = this.checkInterrupts();
    if (irqCycles) {
      this.updateTimer(irqCycles);
      this.totalCycles += irqCycles;
      this.advanceSciTx(irqCycles);
      return irqCycles;
    }

    if (this.halted || this.sleeping) {
      this.updateTimer(1);
      this.totalCycles += 1;
      this.advanceSciTx(1);
      return 1;
    }

    const opcode = this.fetchByte();
    let cycles = 1;

    switch (opcode) {
      // --- Row 0x0_: Inherent ---
      case 0x00: { // TRAP (HD6301/HD6303 only)
        this.pushAll();
        this.CC |= FLAG_I;
        this.PC = this.readWord(0xFFEE);
        cycles = 12; break;
      }
      case 0x01: cycles = 1; break; // NOP
      case 0x04: { // LSRD
        const d = this.D;
        const c = d & 1;
        const r = (d >> 1) & 0x7FFF;
        this.D = r;
        this.CC = (this.CC & (FLAG_I | FLAG_H)) |
          (r === 0 ? FLAG_Z : 0) |
          (c ? FLAG_C : 0) |
          (c ? FLAG_V : 0); // V = N ^ C = 0 ^ C
        cycles = 1; break;
      }
      case 0x05: { // ASLD
        const d = this.D;
        const c = (d >> 15) & 1;
        const r = (d << 1) & 0xFFFF;
        this.D = r;
        const n = (r >> 15) & 1;
        this.CC = (this.CC & (FLAG_I | FLAG_H)) |
          (n ? FLAG_N : 0) |
          (r === 0 ? FLAG_Z : 0) |
          (n ^ c ? FLAG_V : 0) |
          (c ? FLAG_C : 0);
        cycles = 1; break;
      }
      case 0x06: this.CC = (this.A & 0x3F) | 0xC0; cycles = 1; break; // TAP
      case 0x07: this.A = this.CC | 0xC0; cycles = 1; break; // TPA
      case 0x08: // INX
        this.X = (this.X + 1) & 0xFFFF;
        this.CC = (this.CC & ~FLAG_Z) | (this.X === 0 ? FLAG_Z : 0);
        cycles = 1; break;
      case 0x09: // DEX
        this.X = (this.X - 1) & 0xFFFF;
        this.CC = (this.CC & ~FLAG_Z) | (this.X === 0 ? FLAG_Z : 0);
        cycles = 1; break;
      case 0x0A: this.CC &= ~FLAG_V; cycles = 1; break; // CLV
      case 0x0B: this.CC |= FLAG_V; cycles = 1; break; // SEV
      case 0x0C: this.CC &= ~FLAG_C; cycles = 1; break; // CLC
      case 0x0D: this.CC |= FLAG_C; cycles = 1; break; // SEC
      case 0x0E: this.CC &= ~FLAG_I; cycles = 1; break; // CLI
      case 0x0F: this.CC |= FLAG_I; cycles = 1; break; // SEI

      // --- Row 0x1_: Inherent ---
      case 0x10: this.A = this.opSUB(this.A, this.B); cycles = 1; break; // SBA
      case 0x11: this.opCMP(this.A, this.B); cycles = 1; break; // CBA
      case 0x16: this.B = this.opLD8(this.A); cycles = 1; break; // TAB
      case 0x17: this.A = this.opLD8(this.B); cycles = 1; break; // TBA
      case 0x18: { // XGDX (6301)
        const d = this.D; this.D = this.X; this.X = d;
        cycles = 2; break;
      }
      case 0x19: { // DAA
        let cf = 0, correction = 0;
        const lsn = this.A & 0x0F;
        const msn = (this.A >> 4) & 0x0F;
        if ((this.CC & FLAG_H) || lsn > 9) correction |= 0x06;
        if ((this.CC & FLAG_C) || msn > 9 || (msn >= 9 && lsn > 9)) { correction |= 0x60; cf = 1; }
        this.A = (this.A + correction) & 0xFF;
        this.setNZ8(this.A);
        if (cf) this.CC |= FLAG_C;
        cycles = 2; break;
      }
      case 0x1A: this.sleeping = true; cycles = 1; break; // SLP (6301)
      case 0x1B: this.A = this.opADD(this.A, this.B); cycles = 1; break; // ABA

      // --- Row 0x2_: Branches ---
      case 0x20: cycles = this.branch(true); break; // BRA
      case 0x21: cycles = this.branch(false); break; // BRN
      case 0x22: cycles = this.branch(!(this.CC & FLAG_C) && !(this.CC & FLAG_Z)); break; // BHI
      case 0x23: cycles = this.branch(!!(this.CC & FLAG_C) || !!(this.CC & FLAG_Z)); break; // BLS
      case 0x24: cycles = this.branch(!(this.CC & FLAG_C)); break; // BCC
      case 0x25: cycles = this.branch(!!(this.CC & FLAG_C)); break; // BCS
      case 0x26: cycles = this.branch(!(this.CC & FLAG_Z)); break; // BNE
      case 0x27: cycles = this.branch(!!(this.CC & FLAG_Z)); break; // BEQ
      case 0x28: cycles = this.branch(!(this.CC & FLAG_V)); break; // BVC
      case 0x29: cycles = this.branch(!!(this.CC & FLAG_V)); break; // BVS
      case 0x2A: cycles = this.branch(!(this.CC & FLAG_N)); break; // BPL
      case 0x2B: cycles = this.branch(!!(this.CC & FLAG_N)); break; // BMI
      case 0x2C: { // BGE: N^V == 0
        const n = (this.CC & FLAG_N) ? 1 : 0;
        const v = (this.CC & FLAG_V) ? 1 : 0;
        cycles = this.branch((n ^ v) === 0); break;
      }
      case 0x2D: { // BLT: N^V == 1
        const n = (this.CC & FLAG_N) ? 1 : 0;
        const v = (this.CC & FLAG_V) ? 1 : 0;
        cycles = this.branch((n ^ v) === 1); break;
      }
      case 0x2E: { // BGT: Z=0 AND N^V=0
        const n = (this.CC & FLAG_N) ? 1 : 0;
        const v = (this.CC & FLAG_V) ? 1 : 0;
        cycles = this.branch(!(this.CC & FLAG_Z) && (n ^ v) === 0); break;
      }
      case 0x2F: { // BLE: Z=1 OR N^V=1
        const n = (this.CC & FLAG_N) ? 1 : 0;
        const v = (this.CC & FLAG_V) ? 1 : 0;
        cycles = this.branch(!!(this.CC & FLAG_Z) || (n ^ v) === 1); break;
      }

      // --- Row 0x3_: Stack/Register ---
      case 0x30: this.X = (this.SP + 1) & 0xFFFF; cycles = 1; break; // TSX
      case 0x31: this.SP = (this.SP + 1) & 0xFFFF; cycles = 1; break; // INS
      case 0x32: this.A = this.pullByte(); cycles = 3; break; // PULA
      case 0x33: this.B = this.pullByte(); cycles = 3; break; // PULB
      case 0x34: this.SP = (this.SP - 1) & 0xFFFF; cycles = 1; break; // DES
      case 0x35: this.SP = (this.X - 1) & 0xFFFF; cycles = 1; break; // TXS
      case 0x36: this.pushByte(this.A); cycles = 4; break; // PSHA
      case 0x37: this.pushByte(this.B); cycles = 4; break; // PSHB
      case 0x38: this.X = this.pullWord(); cycles = 4; break; // PULX
      case 0x39: this.PC = this.pullWord(); cycles = 5; break; // RTS
      case 0x3A: this.X = (this.X + this.B) & 0xFFFF; cycles = 1; break; // ABX
      case 0x3B: { // RTI
        this.CC = this.pullByte() | 0xC0;
        this.B = this.pullByte();
        this.A = this.pullByte();
        this.X = this.pullWord();
        this.PC = this.pullWord();
        cycles = 10; break;
      }
      case 0x3C: this.pushWord(this.X); cycles = 5; break; // PSHX
      case 0x3D: { // MUL
        const r = this.A * this.B;
        this.A = (r >> 8) & 0xFF;
        this.B = r & 0xFF;
        this.CC = (this.CC & ~FLAG_C) | ((this.B & 0x80) ? FLAG_C : 0);
        cycles = 7; break;
      }
      case 0x3E: // WAI
        this.pushAll();
        this.halted = true;
        cycles = 9; break;
      case 0x3F: // SWI
        this.pushAll();
        this.CC |= FLAG_I;
        this.PC = this.readWord(0xFFFA);
        cycles = 12; break;

      // --- Row 0x4_: Accumulator A ops ---
      case 0x40: this.A = this.opNEG(this.A); cycles = 1; break;
      case 0x43: this.A = this.opCOM(this.A); cycles = 1; break;
      case 0x44: this.A = this.opLSR(this.A); cycles = 1; break;
      case 0x46: this.A = this.opROR(this.A); cycles = 1; break;
      case 0x47: this.A = this.opASR(this.A); cycles = 1; break;
      case 0x48: this.A = this.opASL(this.A); cycles = 1; break;
      case 0x49: this.A = this.opROL(this.A); cycles = 1; break;
      case 0x4A: this.A = this.opDEC(this.A); cycles = 1; break;
      case 0x4C: this.A = this.opINC(this.A); cycles = 1; break;
      case 0x4D: this.opTST(this.A); cycles = 1; break;
      case 0x4F: this.A = this.opCLR(); cycles = 1; break;

      // --- Row 0x5_: Accumulator B ops ---
      case 0x50: this.B = this.opNEG(this.B); cycles = 1; break;
      case 0x53: this.B = this.opCOM(this.B); cycles = 1; break;
      case 0x54: this.B = this.opLSR(this.B); cycles = 1; break;
      case 0x56: this.B = this.opROR(this.B); cycles = 1; break;
      case 0x57: this.B = this.opASR(this.B); cycles = 1; break;
      case 0x58: this.B = this.opASL(this.B); cycles = 1; break;
      case 0x59: this.B = this.opROL(this.B); cycles = 1; break;
      case 0x5A: this.B = this.opDEC(this.B); cycles = 1; break;
      case 0x5C: this.B = this.opINC(this.B); cycles = 1; break;
      case 0x5D: this.opTST(this.B); cycles = 1; break;
      case 0x5F: this.B = this.opCLR(); cycles = 1; break;

      // --- Row 0x6_: Indexed + 6301 bit ops ---
      case 0x60: { const a = this.addrIdx(); this.write(a, this.opNEG(this.read(a))); cycles = 6; break; }
      case 0x61: { // AIM #imm, idx (6301)
        const imm = this.fetchByte(); const a = this.addrIdx();
        const r = this.read(a) & imm;
        this.setNZ8(r); this.CC &= ~FLAG_V;
        this.write(a, r); cycles = 7; break;
      }
      case 0x62: { // OIM #imm, idx (6301)
        const imm = this.fetchByte(); const a = this.addrIdx();
        const r = (this.read(a) | imm) & 0xFF;
        this.setNZ8(r); this.CC &= ~FLAG_V;
        this.write(a, r); cycles = 7; break;
      }
      case 0x63: { const a = this.addrIdx(); this.write(a, this.opCOM(this.read(a))); cycles = 6; break; }
      case 0x64: { const a = this.addrIdx(); this.write(a, this.opLSR(this.read(a))); cycles = 6; break; }
      case 0x65: { // EIM #imm, idx (6301)
        const imm = this.fetchByte(); const a = this.addrIdx();
        const r = (this.read(a) ^ imm) & 0xFF;
        this.setNZ8(r); this.CC &= ~FLAG_V;
        this.write(a, r); cycles = 7; break;
      }
      case 0x66: { const a = this.addrIdx(); this.write(a, this.opROR(this.read(a))); cycles = 6; break; }
      case 0x67: { const a = this.addrIdx(); this.write(a, this.opASR(this.read(a))); cycles = 6; break; }
      case 0x68: { const a = this.addrIdx(); this.write(a, this.opASL(this.read(a))); cycles = 6; break; }
      case 0x69: { const a = this.addrIdx(); this.write(a, this.opROL(this.read(a))); cycles = 6; break; }
      case 0x6A: { const a = this.addrIdx(); this.write(a, this.opDEC(this.read(a))); cycles = 6; break; }
      case 0x6B: { // TIM #imm, idx (6301)
        const imm = this.fetchByte(); const a = this.addrIdx();
        const r = this.read(a) & imm;
        this.setNZ8(r); this.CC &= ~FLAG_V;
        cycles = 7; break;
      }
      case 0x6C: { const a = this.addrIdx(); this.write(a, this.opINC(this.read(a))); cycles = 6; break; }
      case 0x6D: { const a = this.addrIdx(); this.opTST(this.read(a)); cycles = 4; break; }
      case 0x6E: this.PC = this.addrIdx(); cycles = 3; break; // JMP idx
      case 0x6F: { const a = this.addrIdx(); this.write(a, this.opCLR()); cycles = 5; break; }

      // --- Row 0x7_: Extended + 6301 bit ops (dir) ---
      case 0x70: { const a = this.addrExt(); this.write(a, this.opNEG(this.read(a))); cycles = 6; break; }
      case 0x71: { // AIM #imm, dir (6301)
        const imm = this.fetchByte(); const a = this.addrDir();
        const r = this.read(a) & imm;
        this.setNZ8(r); this.CC &= ~FLAG_V;
        this.write(a, r); cycles = 6; break;
      }
      case 0x72: { // OIM #imm, dir (6301)
        const imm = this.fetchByte(); const a = this.addrDir();
        const r = (this.read(a) | imm) & 0xFF;
        this.setNZ8(r); this.CC &= ~FLAG_V;
        this.write(a, r); cycles = 6; break;
      }
      case 0x73: { const a = this.addrExt(); this.write(a, this.opCOM(this.read(a))); cycles = 6; break; }
      case 0x74: { const a = this.addrExt(); this.write(a, this.opLSR(this.read(a))); cycles = 6; break; }
      case 0x75: { // EIM #imm, dir (6301)
        const imm = this.fetchByte(); const a = this.addrDir();
        const r = (this.read(a) ^ imm) & 0xFF;
        this.setNZ8(r); this.CC &= ~FLAG_V;
        this.write(a, r); cycles = 6; break;
      }
      case 0x76: { const a = this.addrExt(); this.write(a, this.opROR(this.read(a))); cycles = 6; break; }
      case 0x77: { const a = this.addrExt(); this.write(a, this.opASR(this.read(a))); cycles = 6; break; }
      case 0x78: { const a = this.addrExt(); this.write(a, this.opASL(this.read(a))); cycles = 6; break; }
      case 0x79: { const a = this.addrExt(); this.write(a, this.opROL(this.read(a))); cycles = 6; break; }
      case 0x7A: { const a = this.addrExt(); this.write(a, this.opDEC(this.read(a))); cycles = 6; break; }
      case 0x7B: { // TIM #imm, dir (6301)
        const imm = this.fetchByte(); const a = this.addrDir();
        const r = this.read(a) & imm;
        this.setNZ8(r); this.CC &= ~FLAG_V;
        cycles = 6; break;
      }
      case 0x7C: { const a = this.addrExt(); this.write(a, this.opINC(this.read(a))); cycles = 6; break; }
      case 0x7D: { const a = this.addrExt(); this.opTST(this.read(a)); cycles = 4; break; }
      case 0x7E: this.PC = this.addrExt(); cycles = 3; break; // JMP ext
      case 0x7F: { const a = this.addrExt(); this.write(a, this.opCLR()); cycles = 5; break; }

      // --- Row 0x8_: Immediate A + 16-bit ---
      case 0x80: this.A = this.opSUB(this.A, this.fetchByte()); cycles = 2; break;
      case 0x81: this.opCMP(this.A, this.fetchByte()); cycles = 2; break;
      case 0x82: this.A = this.opSBC(this.A, this.fetchByte()); cycles = 2; break;
      case 0x83: this.D = this.opSUBD(this.D, this.fetchWord()); cycles = 4; break;
      case 0x84: this.A = this.opAND(this.A, this.fetchByte()); cycles = 2; break;
      case 0x85: this.opBIT(this.A, this.fetchByte()); cycles = 2; break;
      case 0x86: this.A = this.opLD8(this.fetchByte()); cycles = 2; break;
      case 0x88: this.A = this.opEOR(this.A, this.fetchByte()); cycles = 2; break;
      case 0x89: this.A = this.opADC(this.A, this.fetchByte()); cycles = 2; break;
      case 0x8A: this.A = this.opOR(this.A, this.fetchByte()); cycles = 2; break;
      case 0x8B: this.A = this.opADD(this.A, this.fetchByte()); cycles = 2; break;
      case 0x8C: this.opCPX(this.X, this.fetchWord()); cycles = 4; break;
      case 0x8D: { // BSR
        const off = this.fetchByte();
        this.pushWord(this.PC);
        const signed = off > 127 ? off - 256 : off;
        this.PC = (this.PC + signed) & 0xFFFF;
        cycles = 6; break;
      }
      case 0x8E: this.SP = this.opLD16(this.fetchWord()); cycles = 3; break;
      // Undocumented: STAA/STS immediate — consume operand bytes, set flags, no write
      case 0x87: { this.fetchByte(); this.opST8(this.A); cycles = 2; break; }
      case 0x8F: { this.fetchWord(); this.opST16(this.SP); cycles = 2; break; }

      // --- Row 0x9_: Direct A + 16-bit ---
      case 0x90: this.A = this.opSUB(this.A, this.read(this.addrDir())); cycles = 3; break;
      case 0x91: this.opCMP(this.A, this.read(this.addrDir())); cycles = 3; break;
      case 0x92: this.A = this.opSBC(this.A, this.read(this.addrDir())); cycles = 3; break;
      case 0x93: { const a = this.addrDir(); this.D = this.opSUBD(this.D, this.readWord(a)); cycles = 5; break; }
      case 0x94: this.A = this.opAND(this.A, this.read(this.addrDir())); cycles = 3; break;
      case 0x95: this.opBIT(this.A, this.read(this.addrDir())); cycles = 3; break;
      case 0x96: this.A = this.opLD8(this.read(this.addrDir())); cycles = 3; break;
      case 0x97: { const a = this.addrDir(); this.write(a, this.opST8(this.A)); cycles = 3; break; }
      case 0x98: this.A = this.opEOR(this.A, this.read(this.addrDir())); cycles = 3; break;
      case 0x99: this.A = this.opADC(this.A, this.read(this.addrDir())); cycles = 3; break;
      case 0x9A: this.A = this.opOR(this.A, this.read(this.addrDir())); cycles = 3; break;
      case 0x9B: this.A = this.opADD(this.A, this.read(this.addrDir())); cycles = 3; break;
      case 0x9C: { const a = this.addrDir(); this.opCPX(this.X, this.readWord(a)); cycles = 5; break; }
      case 0x9D: { // JSR direct
        const a = this.addrDir();
        this.pushWord(this.PC);
        this.PC = a;
        cycles = 5; break;
      }
      case 0x9E: { const a = this.addrDir(); this.SP = this.opLD16(this.readWord(a)); cycles = 4; break; }
      case 0x9F: { const a = this.addrDir(); this.opST16(this.SP); this.writeWord(a, this.SP); cycles = 4; break; }

      // --- Row 0xA_: Indexed A + 16-bit ---
      case 0xA0: this.A = this.opSUB(this.A, this.read(this.addrIdx())); cycles = 4; break;
      case 0xA1: this.opCMP(this.A, this.read(this.addrIdx())); cycles = 4; break;
      case 0xA2: this.A = this.opSBC(this.A, this.read(this.addrIdx())); cycles = 4; break;
      case 0xA3: { const a = this.addrIdx(); this.D = this.opSUBD(this.D, this.readWord(a)); cycles = 6; break; }
      case 0xA4: this.A = this.opAND(this.A, this.read(this.addrIdx())); cycles = 4; break;
      case 0xA5: this.opBIT(this.A, this.read(this.addrIdx())); cycles = 4; break;
      case 0xA6: this.A = this.opLD8(this.read(this.addrIdx())); cycles = 4; break;
      case 0xA7: { const a = this.addrIdx(); this.write(a, this.opST8(this.A)); cycles = 4; break; }
      case 0xA8: this.A = this.opEOR(this.A, this.read(this.addrIdx())); cycles = 4; break;
      case 0xA9: this.A = this.opADC(this.A, this.read(this.addrIdx())); cycles = 4; break;
      case 0xAA: this.A = this.opOR(this.A, this.read(this.addrIdx())); cycles = 4; break;
      case 0xAB: this.A = this.opADD(this.A, this.read(this.addrIdx())); cycles = 4; break;
      case 0xAC: { const a = this.addrIdx(); this.opCPX(this.X, this.readWord(a)); cycles = 6; break; }
      case 0xAD: { // JSR indexed
        const a = this.addrIdx();
        this.pushWord(this.PC);
        this.PC = a;
        cycles = 5; break;
      }
      case 0xAE: { const a = this.addrIdx(); this.SP = this.opLD16(this.readWord(a)); cycles = 5; break; }
      case 0xAF: { const a = this.addrIdx(); this.opST16(this.SP); this.writeWord(a, this.SP); cycles = 5; break; }

      // --- Row 0xB_: Extended A + 16-bit ---
      case 0xB0: this.A = this.opSUB(this.A, this.read(this.addrExt())); cycles = 4; break;
      case 0xB1: this.opCMP(this.A, this.read(this.addrExt())); cycles = 4; break;
      case 0xB2: this.A = this.opSBC(this.A, this.read(this.addrExt())); cycles = 4; break;
      case 0xB3: { const a = this.addrExt(); this.D = this.opSUBD(this.D, this.readWord(a)); cycles = 6; break; }
      case 0xB4: this.A = this.opAND(this.A, this.read(this.addrExt())); cycles = 4; break;
      case 0xB5: this.opBIT(this.A, this.read(this.addrExt())); cycles = 4; break;
      case 0xB6: this.A = this.opLD8(this.read(this.addrExt())); cycles = 4; break;
      case 0xB7: { const a = this.addrExt(); this.write(a, this.opST8(this.A)); cycles = 4; break; }
      case 0xB8: this.A = this.opEOR(this.A, this.read(this.addrExt())); cycles = 4; break;
      case 0xB9: this.A = this.opADC(this.A, this.read(this.addrExt())); cycles = 4; break;
      case 0xBA: this.A = this.opOR(this.A, this.read(this.addrExt())); cycles = 4; break;
      case 0xBB: this.A = this.opADD(this.A, this.read(this.addrExt())); cycles = 4; break;
      case 0xBC: { const a = this.addrExt(); this.opCPX(this.X, this.readWord(a)); cycles = 6; break; }
      case 0xBD: { // JSR extended
        const a = this.addrExt();
        this.pushWord(this.PC);
        this.PC = a;
        cycles = 6; break;
      }
      case 0xBE: { const a = this.addrExt(); this.SP = this.opLD16(this.readWord(a)); cycles = 5; break; }
      case 0xBF: { const a = this.addrExt(); this.opST16(this.SP); this.writeWord(a, this.SP); cycles = 5; break; }

      // --- Row 0xC_: Immediate B + 16-bit ---
      case 0xC0: this.B = this.opSUB(this.B, this.fetchByte()); cycles = 2; break;
      case 0xC1: this.opCMP(this.B, this.fetchByte()); cycles = 2; break;
      case 0xC2: this.B = this.opSBC(this.B, this.fetchByte()); cycles = 2; break;
      case 0xC3: this.D = this.opADDD(this.D, this.fetchWord()); cycles = 4; break;
      case 0xC4: this.B = this.opAND(this.B, this.fetchByte()); cycles = 2; break;
      case 0xC5: this.opBIT(this.B, this.fetchByte()); cycles = 2; break;
      case 0xC6: this.B = this.opLD8(this.fetchByte()); cycles = 2; break;
      case 0xC8: this.B = this.opEOR(this.B, this.fetchByte()); cycles = 2; break;
      case 0xC9: this.B = this.opADC(this.B, this.fetchByte()); cycles = 2; break;
      case 0xCA: this.B = this.opOR(this.B, this.fetchByte()); cycles = 2; break;
      case 0xCB: this.B = this.opADD(this.B, this.fetchByte()); cycles = 2; break;
      case 0xCC: this.D = this.opLD16(this.fetchWord()); cycles = 3; break;
      case 0xCE: this.X = this.opLD16(this.fetchWord()); cycles = 3; break;
      // Undocumented: STAB/STD/STX immediate — consume operand bytes, set flags, no write
      case 0xC7: { this.fetchByte(); this.opST8(this.B); cycles = 2; break; }
      case 0xCD: { this.fetchWord(); this.opST16(this.D); cycles = 2; break; }
      case 0xCF: { this.fetchWord(); this.opST16(this.X); cycles = 2; break; }

      // --- Row 0xD_: Direct B + 16-bit ---
      case 0xD0: this.B = this.opSUB(this.B, this.read(this.addrDir())); cycles = 3; break;
      case 0xD1: this.opCMP(this.B, this.read(this.addrDir())); cycles = 3; break;
      case 0xD2: this.B = this.opSBC(this.B, this.read(this.addrDir())); cycles = 3; break;
      case 0xD3: { const a = this.addrDir(); this.D = this.opADDD(this.D, this.readWord(a)); cycles = 5; break; }
      case 0xD4: this.B = this.opAND(this.B, this.read(this.addrDir())); cycles = 3; break;
      case 0xD5: this.opBIT(this.B, this.read(this.addrDir())); cycles = 3; break;
      case 0xD6: this.B = this.opLD8(this.read(this.addrDir())); cycles = 3; break;
      case 0xD7: { const a = this.addrDir(); this.write(a, this.opST8(this.B)); cycles = 3; break; }
      case 0xD8: this.B = this.opEOR(this.B, this.read(this.addrDir())); cycles = 3; break;
      case 0xD9: this.B = this.opADC(this.B, this.read(this.addrDir())); cycles = 3; break;
      case 0xDA: this.B = this.opOR(this.B, this.read(this.addrDir())); cycles = 3; break;
      case 0xDB: this.B = this.opADD(this.B, this.read(this.addrDir())); cycles = 3; break;
      case 0xDC: { const a = this.addrDir(); this.D = this.opLD16(this.readWord(a)); cycles = 4; break; }
      case 0xDD: { const a = this.addrDir(); this.opST16(this.D); this.writeWord(a, this.D); cycles = 4; break; }
      case 0xDE: { const a = this.addrDir(); this.X = this.opLD16(this.readWord(a)); cycles = 4; break; }
      case 0xDF: { const a = this.addrDir(); this.opST16(this.X); this.writeWord(a, this.X); cycles = 4; break; }

      // --- Row 0xE_: Indexed B + 16-bit ---
      case 0xE0: this.B = this.opSUB(this.B, this.read(this.addrIdx())); cycles = 4; break;
      case 0xE1: this.opCMP(this.B, this.read(this.addrIdx())); cycles = 4; break;
      case 0xE2: this.B = this.opSBC(this.B, this.read(this.addrIdx())); cycles = 4; break;
      case 0xE3: { const a = this.addrIdx(); this.D = this.opADDD(this.D, this.readWord(a)); cycles = 6; break; }
      case 0xE4: this.B = this.opAND(this.B, this.read(this.addrIdx())); cycles = 4; break;
      case 0xE5: this.opBIT(this.B, this.read(this.addrIdx())); cycles = 4; break;
      case 0xE6: this.B = this.opLD8(this.read(this.addrIdx())); cycles = 4; break;
      case 0xE7: { const a = this.addrIdx(); this.write(a, this.opST8(this.B)); cycles = 4; break; }
      case 0xE8: this.B = this.opEOR(this.B, this.read(this.addrIdx())); cycles = 4; break;
      case 0xE9: this.B = this.opADC(this.B, this.read(this.addrIdx())); cycles = 4; break;
      case 0xEA: this.B = this.opOR(this.B, this.read(this.addrIdx())); cycles = 4; break;
      case 0xEB: this.B = this.opADD(this.B, this.read(this.addrIdx())); cycles = 4; break;
      case 0xEC: { const a = this.addrIdx(); this.D = this.opLD16(this.readWord(a)); cycles = 5; break; }
      case 0xED: { const a = this.addrIdx(); this.opST16(this.D); this.writeWord(a, this.D); cycles = 5; break; }
      case 0xEE: { const a = this.addrIdx(); this.X = this.opLD16(this.readWord(a)); cycles = 5; break; }
      case 0xEF: { const a = this.addrIdx(); this.opST16(this.X); this.writeWord(a, this.X); cycles = 5; break; }

      // --- Row 0xF_: Extended B + 16-bit ---
      case 0xF0: this.B = this.opSUB(this.B, this.read(this.addrExt())); cycles = 4; break;
      case 0xF1: this.opCMP(this.B, this.read(this.addrExt())); cycles = 4; break;
      case 0xF2: this.B = this.opSBC(this.B, this.read(this.addrExt())); cycles = 4; break;
      case 0xF3: { const a = this.addrExt(); this.D = this.opADDD(this.D, this.readWord(a)); cycles = 6; break; }
      case 0xF4: this.B = this.opAND(this.B, this.read(this.addrExt())); cycles = 4; break;
      case 0xF5: this.opBIT(this.B, this.read(this.addrExt())); cycles = 4; break;
      case 0xF6: this.B = this.opLD8(this.read(this.addrExt())); cycles = 4; break;
      case 0xF7: { const a = this.addrExt(); this.write(a, this.opST8(this.B)); cycles = 4; break; }
      case 0xF8: this.B = this.opEOR(this.B, this.read(this.addrExt())); cycles = 4; break;
      case 0xF9: this.B = this.opADC(this.B, this.read(this.addrExt())); cycles = 4; break;
      case 0xFA: this.B = this.opOR(this.B, this.read(this.addrExt())); cycles = 4; break;
      case 0xFB: this.B = this.opADD(this.B, this.read(this.addrExt())); cycles = 4; break;
      case 0xFC: { const a = this.addrExt(); this.D = this.opLD16(this.readWord(a)); cycles = 5; break; }
      case 0xFD: { const a = this.addrExt(); this.opST16(this.D); this.writeWord(a, this.D); cycles = 5; break; }
      case 0xFE: { const a = this.addrExt(); this.X = this.opLD16(this.readWord(a)); cycles = 5; break; }
      case 0xFF: { const a = this.addrExt(); this.opST16(this.X); this.writeWord(a, this.X); cycles = 5; break; }

      default: // Illegal opcode - treat as NOP
        console.warn(`${this.name}: illegal opcode 0x${opcode.toString(16).padStart(2, '0')} at 0x${((this.PC - 1) & 0xFFFF).toString(16).padStart(4, '0')}`);
        cycles = 1;
        break;
    }

    this.updateTimer(cycles);
    this.totalCycles += cycles;

    this.advanceSciTx(cycles);
    return cycles;
  }

  /** Advance the SCI TX timer by N cycles; delivers byte and sets TDRE when done */
  private advanceSciTx(cycles: number): void {
    if (this.sciTxTimer > 0) {
      this.sciTxTimer -= cycles;
      if (this.sciTxTimer <= 0) {
        this.sciTxTimer = 0;
        this.trcsr |= 0x20; // TDRE set — ready for next byte
        if (this.sciTxPending) {
          this.sciTxPending = false;
          this.onSerialSend(this.sciTxByte);
        }
      }
    }
  }

  // --- Debug ---

  saveState(): Record<string, unknown> {
    return {
      A: this.A, B: this.B, X: this.X, SP: this.SP, PC: this.PC, CC: this.CC,
      halted: this.halted, sleeping: this.sleeping,
      irq1Line: this.irq1Line, irq2Line: this.irq2Line,
      nmiLine: this.nmiLine, nmiPending: this.nmiPending,
      totalCycles: this.totalCycles,
      p1ddr: this.p1ddr, p2ddr: this.p2ddr, p1out: this.p1out, p2out: this.p2out,
      p3ddr: this.p3ddr, p4ddr: this.p4ddr, p3out: this.p3out, p4out: this.p4out,
      tcsr: this.tcsr, frc: this.frc, frcLatch: this.frcLatch,
      ocr: this.ocr, ocrH: this.ocrH, icr: this.icr,
      p3csr: this.p3csr, rmcr: this.rmcr, trcsr: this.trcsr,
      rdr: this.rdr, tdr: this.tdr, ramcr: this.ramcr, tcsrArmed: this.tcsrArmed,
      sciRecvBuf: this.sciRecvBuf.slice(),
      rdrfClearStep: this.rdrfClearStep,
      sciTxTimer: this.sciTxTimer,
      sciTxPending: this.sciTxPending,
      sciTxByte: this.sciTxByte,
      lastP20: this.lastP20,
      ram: btoa(String.fromCharCode(...this.ram)),
    };
  }

  loadState(s: Record<string, unknown>): void {
    this.A = s.A as number; this.B = s.B as number;
    this.X = s.X as number; this.SP = s.SP as number;
    this.PC = s.PC as number; this.CC = s.CC as number;
    this.halted = s.halted as boolean; this.sleeping = s.sleeping as boolean;
    this.irq1Line = s.irq1Line as boolean; this.irq2Line = s.irq2Line as boolean;
    this.nmiLine = s.nmiLine as boolean; this.nmiPending = s.nmiPending as boolean;
    this.totalCycles = s.totalCycles as number;
    this.p1ddr = s.p1ddr as number; this.p2ddr = s.p2ddr as number;
    this.p1out = s.p1out as number; this.p2out = s.p2out as number;
    this.p3ddr = s.p3ddr as number; this.p4ddr = s.p4ddr as number;
    this.p3out = s.p3out as number; this.p4out = s.p4out as number;
    this.tcsr = s.tcsr as number; this.frc = s.frc as number;
    this.frcLatch = s.frcLatch as number;
    this.ocr = s.ocr as number; this.ocrH = s.ocrH as number;
    this.icr = s.icr as number; this.p3csr = s.p3csr as number;
    this.rmcr = s.rmcr as number; this.trcsr = s.trcsr as number;
    this.rdr = s.rdr as number; this.tdr = s.tdr as number;
    this.ramcr = s.ramcr as number;
    this.tcsrArmed = (s.tcsrArmed as number) ?? (s.tcsrRead ? (this.tcsr & 0xE0) : 0);
    this.sciRecvBuf = (s.sciRecvBuf as number[]).slice();
    this.rdrfClearStep = s.rdrfClearStep as number;
    this.sciTxTimer = (s.sciTxTimer as number) || 0;
    this.sciTxPending = (s.sciTxPending as boolean) || false;
    this.sciTxByte = (s.sciTxByte as number) || 0;
    this.lastP20 = (s.lastP20 as boolean) ?? true;
    const ramStr = atob(s.ram as string);
    for (let i = 0; i < ramStr.length; i++) this.ram[i] = ramStr.charCodeAt(i);
  }

  dumpRegisters(): string {
    return `PC=${this.PC.toString(16).padStart(4,'0')} ` +
      `A=${this.A.toString(16).padStart(2,'0')} B=${this.B.toString(16).padStart(2,'0')} ` +
      `X=${this.X.toString(16).padStart(4,'0')} SP=${this.SP.toString(16).padStart(4,'0')} ` +
      `CC=${this.CC.toString(2).padStart(8,'0')} ` +
      `[${this.CC & FLAG_H ? 'H' : '-'}${this.CC & FLAG_I ? 'I' : '-'}` +
      `${this.CC & FLAG_N ? 'N' : '-'}${this.CC & FLAG_Z ? 'Z' : '-'}` +
      `${this.CC & FLAG_V ? 'V' : '-'}${this.CC & FLAG_C ? 'C' : '-'}]`;
  }
}
