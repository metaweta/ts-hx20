// UPD7227 LCD Controller emulation
// Each controller manages a 40x16 pixel region
// 6 controllers arranged in 3x2 grid = 120x32 pixel display

export class UPD7227 {
  ram = new Uint8Array(128); // 7-bit address space
  private ptr = 0;           // 7-bit data pointer
  private ptrop = 0;         // pointer auto-operation: 0=inc, 1=dec, 2/3=hold
  private mode = 0;          // 0=idle, 1=read, 2=write, 3=OR, 4=AND, 5=char
  displayOn = true;
  dirty = true;

  constructor(
    public readonly offsetX: number,
    public readonly offsetY: number
  ) {
    this.reset();
  }

  reset(): void {
    this.ram.fill(0x00);
    this.ptr = 0;
    this.ptrop = 0;
    this.mode = 0;
    this.displayOn = true;
    this.dirty = true;
  }

  command(cmd: number): void {
    if (cmd & 0x80) {
      // LDPI - Load Data Pointer Immediate
      this.ptr = cmd & 0x7F;
    } else if (cmd >= 0x6C && cmd <= 0x6F) {
      // SANDM - Set AND Mode
      this.mode = 4;
      this.ptrop = cmd & 0x03;
    } else if (cmd >= 0x68 && cmd <= 0x6B) {
      // SORM - Set OR Mode
      this.mode = 3;
      this.ptrop = cmd & 0x03;
    } else if (cmd >= 0x64 && cmd <= 0x67) {
      // SWM - Set Write Mode
      this.mode = 2;
      this.ptrop = cmd & 0x03;
    } else if (cmd >= 0x60 && cmd <= 0x63) {
      // SRM - Set Read Mode
      this.mode = 1;
      this.ptrop = cmd & 0x03;
    } else if (cmd >= 0x40 && cmd < 0x60) {
      // BSET - Bit Set
      const bit = (cmd >> 2) & 0x07;
      this.ram[this.ptr] |= (1 << bit);
      this.dirty = true;
      this.advancePtr(cmd & 0x03);
    } else if (cmd >= 0x20 && cmd < 0x40) {
      // BRESET - Bit Reset
      const bit = (cmd >> 2) & 0x07;
      this.ram[this.ptr] &= ~(1 << bit);
      this.dirty = true;
      this.advancePtr(cmd & 0x03);
    } else if (cmd === 0x09) {
      this.displayOn = true;
      this.dirty = true;
    } else if (cmd === 0x08) {
      this.displayOn = false;
      this.dirty = true;
    }
    // SFF (0x10-0x17), SMM (0x18-0x1F), SCM (0x72) - ignored
  }

  writeData(data: number): void {
    switch (this.mode) {
      case 2: this.ram[this.ptr] = data; break;          // Write
      case 3: this.ram[this.ptr] |= data; break;         // OR
      case 4: this.ram[this.ptr] &= data; break;         // AND
      default: return; // Read mode or idle - no write
    }
    this.dirty = true;
    this.advancePtr(this.ptrop);
  }

  private advancePtr(op: number): void {
    switch (op) {
      case 0: this.ptr = (this.ptr + 1) & 0x7F; break;
      case 1: this.ptr = (this.ptr - 1) & 0x7F; break;
      // 2, 3: hold
    }
  }

  // Render this controller's 40x16 region into a pixel buffer
  render(pixels: Uint8Array, stride: number): void {
    if (!this.displayOn) return;
    for (let page = 0; page < 2; page++) {
      const baseAddr = page * 0x40;
      const baseY = this.offsetY + page * 8;
      for (let col = 0; col < 40; col++) {
        const byte = this.ram[baseAddr + col];
        for (let bit = 0; bit < 8; bit++) {
          const x = this.offsetX + col;
          const y = baseY + bit;
          const idx = y * stride + x;
          pixels[idx] = (byte & (1 << bit)) ? 1 : 0;
        }
      }
    }
  }
}

// LCD display manages all 6 controllers and renders to canvas
export class LCDDisplay {
  controllers: UPD7227[] = [];
  pixels = new Uint8Array(120 * 32);
  private ctx: CanvasRenderingContext2D | null = null;
  private imageData: ImageData | null = null;

  // HX-20 LCD colors
  static readonly BG_R = 0xA5;
  static readonly BG_G = 0xAD;
  static readonly BG_B = 0xA5;
  static readonly FG_R = 0x31;
  static readonly FG_G = 0x39;
  static readonly FG_B = 0x10;

  constructor() {
    for (let row = 0; row < 2; row++) {
      for (let col = 0; col < 3; col++) {
        this.controllers.push(new UPD7227(col * 40, row * 16));
      }
    }
  }

  attachCanvas(canvas: HTMLCanvasElement): void {
    this.ctx = canvas.getContext('2d')!;
    this.imageData = this.ctx.createImageData(120, 32);
  }

  // LCD I/O state
  private lcdCS = 0;        // control register (0x0026)
  private lcdData = 0;      // data latch (0x002A)
  private lcdClkCount = 0;  // serial clock counter

  writeLCDControl(val: number): void {
    this.lcdCS = val;
  }

  writeLCDData(val: number): void {
    this.lcdData = val;
  }

  // Called on reads from 0x002A/0x002B to clock the serial data
  clockLCD(): void {
    this.lcdClkCount++;
    if (this.lcdClkCount >= 8) {
      this.lcdClkCount = 0;
      const sel = this.lcdCS & 0x07;
      if (sel >= 1 && sel <= 6) {
        const ctrl = this.controllers[sel - 1];
        if (this.lcdCS & 0x08) {
          ctrl.command(this.lcdData);
        } else {
          ctrl.writeData(this.lcdData);
        }
      }
    }
  }

  render(): void {
    if (!this.ctx || !this.imageData) return;

    // Check if any controller is dirty
    let anyDirty = false;
    for (const ctrl of this.controllers) {
      if (ctrl.dirty) { anyDirty = true; break; }
    }
    if (!anyDirty) return;

    this.pixels.fill(0);
    for (const ctrl of this.controllers) {
      ctrl.render(this.pixels, 120);
      ctrl.dirty = false;
    }

    // Convert pixel buffer to RGBA image data
    const data = this.imageData.data;
    for (let i = 0; i < 120 * 32; i++) {
      const j = i * 4;
      if (this.pixels[i]) {
        data[j] = LCDDisplay.FG_R;
        data[j + 1] = LCDDisplay.FG_G;
        data[j + 2] = LCDDisplay.FG_B;
      } else {
        data[j] = LCDDisplay.BG_R;
        data[j + 1] = LCDDisplay.BG_G;
        data[j + 2] = LCDDisplay.BG_B;
      }
      data[j + 3] = 255;
    }

    // Scale up: canvas is 480x128, display is 120x32 (4x scale)
    this.ctx.putImageData(this.imageData, 0, 0);
    this.ctx.imageSmoothingEnabled = false;
    // Draw at native size then scale via CSS, or scale manually
    const canvas = this.ctx.canvas;
    const tempCanvas = document.createElement('canvas');
    tempCanvas.width = 120;
    tempCanvas.height = 32;
    const tempCtx = tempCanvas.getContext('2d')!;
    tempCtx.putImageData(this.imageData, 0, 0);
    this.ctx.clearRect(0, 0, canvas.width, canvas.height);
    this.ctx.imageSmoothingEnabled = false;
    this.ctx.drawImage(tempCanvas, 0, 0, canvas.width, canvas.height);
  }

  reset(): void {
    for (const ctrl of this.controllers) ctrl.reset();
    this.lcdCS = 0;
    this.lcdData = 0;
    this.lcdClkCount = 0;
  }
}
