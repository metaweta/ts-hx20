// MC146818 Real-Time Clock (simplified)
// Mapped at 0x0040-0x007F on the main CPU (direct access to 64 registers)

export class MC146818 {
  private regs = new Uint8Array(64);
  irqCallback: (state: boolean) => void = () => {};

  constructor() {
    this.reset();
  }

  reset(): void {
    this.regs.fill(0);
    // Set reasonable defaults
    this.regs[0x0A] = 0x26; // DV=010 (32.768kHz), RS=0110 (1024Hz)
    this.regs[0x0B] = 0x02; // 24-hour mode, BCD
    this.regs[0x0D] = 0x80; // VRT = 1 (valid RAM and time)
    this.updateTime();
  }

  read(addr: number): number {
    addr &= 0x3F;
    if (addr === 0x0C) {
      // Status Register C - clear interrupt flags on read
      const val = this.regs[0x0C];
      this.regs[0x0C] = 0;
      this.irqCallback(false);
      return val;
    }
    if (addr <= 0x09) {
      this.updateTime();
    }
    return this.regs[addr];
  }

  write(addr: number, val: number): void {
    addr &= 0x3F;
    if (addr === 0x0C || addr === 0x0D) return; // read-only
    this.regs[addr] = val;
  }

  private toBCD(val: number): number {
    return ((Math.floor(val / 10) & 0x0F) << 4) | (val % 10);
  }

  private updateTime(): void {
    const now = new Date();
    const bcd = !(this.regs[0x0B] & 0x04); // bit 2: 0=BCD, 1=binary
    const h24 = !!(this.regs[0x0B] & 0x02); // bit 1: 1=24hr, 0=12hr

    const encode = (v: number) => bcd ? this.toBCD(v) : v;

    this.regs[0] = encode(now.getSeconds());
    this.regs[2] = encode(now.getMinutes());

    let hours = now.getHours();
    if (!h24) {
      const pm = hours >= 12;
      hours = hours % 12;
      if (hours === 0) hours = 12;
      this.regs[4] = encode(hours) | (pm ? 0x80 : 0);
    } else {
      this.regs[4] = encode(hours);
    }

    this.regs[6] = encode(now.getDay() + 1); // 1-7
    this.regs[7] = encode(now.getDate());
    this.regs[8] = encode(now.getMonth() + 1);
    this.regs[9] = encode(now.getFullYear() % 100);
  }

  // Called periodically to check for alarms/periodic interrupts
  tick(): void {
    // Periodic flag: PF is set whenever periodic rate is non-zero,
    // regardless of PIE (per MC146818 datasheet)
    const rs = this.regs[0x0A] & 0x0F;
    if (rs) {
      this.regs[0x0C] |= 0x40; // PF - always set when rate active
      // IRQF and hardware IRQ only fire when PIE is enabled
      if (this.regs[0x0B] & 0x40) { // PIE
        this.regs[0x0C] |= 0x80; // IRQF
        this.irqCallback(true);
      }
    }
  }
}
