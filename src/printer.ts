// Epson HX-20 Built-in Printer Emulation
// 24-column thermal dot-matrix printer with 144-dot print head
// Renders text and bitmap graphics to a canvas mimicking thermal paper output

// 5×7 bitmap font, column-encoded (5 bytes per character)
// Index: (charCode - 0x20) * 5
// Each byte is one column; bit 0 = top row, bit 6 = bottom row
// Standard dot-matrix ASCII font (0x20–0x7E, 95 characters)
// prettier-ignore
const FONT_5X7 = [
  0x00,0x00,0x00,0x00,0x00, // 0x20 (space)
  0x00,0x00,0x5F,0x00,0x00, // 0x21 !
  0x00,0x07,0x00,0x07,0x00, // 0x22 "
  0x14,0x7F,0x14,0x7F,0x14, // 0x23 #
  0x24,0x2A,0x7F,0x2A,0x12, // 0x24 $
  0x23,0x13,0x08,0x64,0x62, // 0x25 %
  0x36,0x49,0x55,0x22,0x50, // 0x26 &
  0x00,0x05,0x03,0x00,0x00, // 0x27 '
  0x00,0x1C,0x22,0x41,0x00, // 0x28 (
  0x00,0x41,0x22,0x1C,0x00, // 0x29 )
  0x14,0x08,0x3E,0x08,0x14, // 0x2A *
  0x08,0x08,0x3E,0x08,0x08, // 0x2B +
  0x00,0x50,0x30,0x00,0x00, // 0x2C ,
  0x08,0x08,0x08,0x08,0x08, // 0x2D -
  0x00,0x60,0x60,0x00,0x00, // 0x2E .
  0x20,0x10,0x08,0x04,0x02, // 0x2F /
  0x3E,0x51,0x49,0x45,0x3E, // 0x30 0
  0x00,0x42,0x7F,0x40,0x00, // 0x31 1
  0x42,0x61,0x51,0x49,0x46, // 0x32 2
  0x21,0x41,0x45,0x4B,0x31, // 0x33 3
  0x18,0x14,0x12,0x7F,0x10, // 0x34 4
  0x27,0x45,0x45,0x45,0x39, // 0x35 5
  0x3C,0x4A,0x49,0x49,0x30, // 0x36 6
  0x01,0x71,0x09,0x05,0x03, // 0x37 7
  0x36,0x49,0x49,0x49,0x36, // 0x38 8
  0x06,0x49,0x49,0x29,0x1E, // 0x39 9
  0x00,0x36,0x36,0x00,0x00, // 0x3A :
  0x00,0x56,0x36,0x00,0x00, // 0x3B ;
  0x08,0x14,0x22,0x41,0x00, // 0x3C <
  0x14,0x14,0x14,0x14,0x14, // 0x3D =
  0x00,0x41,0x22,0x14,0x08, // 0x3E >
  0x02,0x01,0x51,0x09,0x06, // 0x3F ?
  0x32,0x49,0x79,0x41,0x3E, // 0x40 @
  0x7E,0x11,0x11,0x11,0x7E, // 0x41 A
  0x7F,0x49,0x49,0x49,0x36, // 0x42 B
  0x3E,0x41,0x41,0x41,0x22, // 0x43 C
  0x7F,0x41,0x41,0x22,0x1C, // 0x44 D
  0x7F,0x49,0x49,0x49,0x41, // 0x45 E
  0x7F,0x09,0x09,0x09,0x01, // 0x46 F
  0x3E,0x41,0x49,0x49,0x7A, // 0x47 G
  0x7F,0x08,0x08,0x08,0x7F, // 0x48 H
  0x00,0x41,0x7F,0x41,0x00, // 0x49 I
  0x20,0x40,0x41,0x3F,0x01, // 0x4A J
  0x7F,0x08,0x14,0x22,0x41, // 0x4B K
  0x7F,0x40,0x40,0x40,0x40, // 0x4C L
  0x7F,0x02,0x0C,0x02,0x7F, // 0x4D M
  0x7F,0x04,0x08,0x10,0x7F, // 0x4E N
  0x3E,0x41,0x41,0x41,0x3E, // 0x4F O
  0x7F,0x09,0x09,0x09,0x06, // 0x50 P
  0x3E,0x41,0x51,0x21,0x5E, // 0x51 Q
  0x7F,0x09,0x19,0x29,0x46, // 0x52 R
  0x46,0x49,0x49,0x49,0x31, // 0x53 S
  0x01,0x01,0x7F,0x01,0x01, // 0x54 T
  0x3F,0x40,0x40,0x40,0x3F, // 0x55 U
  0x1F,0x20,0x40,0x20,0x1F, // 0x56 V
  0x3F,0x40,0x38,0x40,0x3F, // 0x57 W
  0x63,0x14,0x08,0x14,0x63, // 0x58 X
  0x07,0x08,0x70,0x08,0x07, // 0x59 Y
  0x61,0x51,0x49,0x45,0x43, // 0x5A Z
  0x00,0x7F,0x41,0x41,0x00, // 0x5B [
  0x02,0x04,0x08,0x10,0x20, // 0x5C backslash
  0x00,0x41,0x41,0x7F,0x00, // 0x5D ]
  0x04,0x02,0x01,0x02,0x04, // 0x5E ^
  0x40,0x40,0x40,0x40,0x40, // 0x5F _
  0x00,0x01,0x02,0x04,0x00, // 0x60 `
  0x20,0x54,0x54,0x54,0x78, // 0x61 a
  0x7F,0x48,0x44,0x44,0x38, // 0x62 b
  0x38,0x44,0x44,0x44,0x20, // 0x63 c
  0x38,0x44,0x44,0x48,0x7F, // 0x64 d
  0x38,0x54,0x54,0x54,0x18, // 0x65 e
  0x08,0x7E,0x09,0x01,0x02, // 0x66 f
  0x0C,0x52,0x52,0x52,0x3E, // 0x67 g
  0x7F,0x08,0x04,0x04,0x78, // 0x68 h
  0x00,0x44,0x7D,0x40,0x00, // 0x69 i
  0x20,0x40,0x44,0x3D,0x00, // 0x6A j
  0x7F,0x10,0x28,0x44,0x00, // 0x6B k
  0x00,0x41,0x7F,0x40,0x00, // 0x6C l
  0x7C,0x04,0x18,0x04,0x78, // 0x6D m
  0x7C,0x08,0x04,0x04,0x78, // 0x6E n
  0x38,0x44,0x44,0x44,0x38, // 0x6F o
  0x7C,0x14,0x14,0x14,0x08, // 0x70 p
  0x08,0x14,0x14,0x18,0x7C, // 0x71 q
  0x7C,0x08,0x04,0x04,0x08, // 0x72 r
  0x48,0x54,0x54,0x54,0x20, // 0x73 s
  0x04,0x3F,0x44,0x40,0x20, // 0x74 t
  0x3C,0x40,0x40,0x20,0x7C, // 0x75 u
  0x1C,0x20,0x40,0x20,0x1C, // 0x76 v
  0x3C,0x40,0x30,0x40,0x3C, // 0x77 w
  0x44,0x28,0x10,0x28,0x44, // 0x78 x
  0x0C,0x50,0x50,0x50,0x3C, // 0x79 y
  0x44,0x64,0x54,0x4C,0x44, // 0x7A z
  0x00,0x08,0x36,0x41,0x00, // 0x7B {
  0x00,0x00,0x7F,0x00,0x00, // 0x7C |
  0x00,0x41,0x36,0x08,0x00, // 0x7D }
  0x10,0x08,0x08,0x10,0x08, // 0x7E ~
];

const CHAR_W = 6;    // 5 pixel columns + 1 spacing
const CHAR_H = 8;    // 7 pixel rows + 1 spacing
const COLS = 24;      // 24-column printer
const DOT_W = COLS * CHAR_W; // 144 dots wide
const SCALE = 3;      // display scale factor

const PAPER_R = 0xF5, PAPER_G = 0xF0, PAPER_B = 0xE0;
const INK_R = 0x33, INK_G = 0x33, INK_B = 0x33;

type TextItem = { type: 'text'; lines: string[] };
type BitmapItem = { type: 'bitmap'; width: number; height: number; pixels: number[] };
type PrinterItem = TextItem | BitmapItem;

export class Printer {
  private items: PrinterItem[] = [];
  private currentLine: string[] = [];
  private column = 0;
  private dirty = false;

  private canvas: HTMLCanvasElement | null = null;
  private container: HTMLElement | null = null;

  onUpdate: (() => void) | null = null;

  readonly WIDTH = COLS;

  printChar(ch: number): void {
    if (ch === 0x0D) {
      this.flushLine();
      this.column = 0;
    } else if (ch === 0x0A) {
      this.flushLine();
      this.column = 0;
    } else if (ch === 0x08) {
      if (this.column > 0) this.column--;
    } else if (ch === 0x09) {
      this.column = Math.min(COLS - 1, (this.column & ~7) + 8);
    } else if (ch >= 0x20 && ch <= 0x7E) {
      if (this.column >= COLS) {
        this.flushLine();
        this.column = 0;
      }
      this.currentLine[this.column] = String.fromCharCode(ch);
      this.column++;
    }
    this.dirty = true;
  }

  printBitmap(width: number, height: number, pixels: Uint8Array): void {
    this.flushPendingText();
    this.items.push({
      type: 'bitmap',
      width,
      height,
      pixels: Array.from(pixels),
    });
    this.dirty = true;
  }

  private flushLine(): void {
    let line = '';
    for (let i = 0; i < COLS; i++) {
      line += this.currentLine[i] || ' ';
    }
    this.appendTextLine(line.trimEnd());
    this.currentLine = [];
  }

  private appendTextLine(line: string): void {
    const last = this.items[this.items.length - 1];
    if (last && last.type === 'text') {
      last.lines.push(line);
    } else {
      this.items.push({ type: 'text', lines: [line] });
    }
  }

  private flushPendingText(): void {
    if (this.currentLine.length > 0 || this.column > 0) {
      this.flushLine();
      this.column = 0;
    }
  }

  private buildCurrentLine(): string {
    let line = '';
    for (let i = 0; i < COLS; i++) {
      line += this.currentLine[i] || ' ';
    }
    return line.trimEnd();
  }

  attachCanvas(canvas: HTMLCanvasElement, container: HTMLElement): void {
    this.canvas = canvas;
    this.container = container;
    this.dirty = true;
    this.render();
  }

  render(): void {
    if (!this.canvas || !this.dirty) return;
    this.dirty = false;

    // Calculate total height in dots
    let totalH = 0;
    for (const item of this.items) {
      if (item.type === 'text') totalH += item.lines.length * CHAR_H;
      else totalH += item.height;
    }
    const partial = this.buildCurrentLine();
    if (partial.length > 0) totalH += CHAR_H;

    // Minimum height for empty paper
    const minH = Math.ceil(50 / SCALE);
    totalH = Math.max(totalH, minH);

    // Resize canvas
    this.canvas.width = DOT_W * SCALE;
    this.canvas.height = totalH * SCALE;

    const ctx = this.canvas.getContext('2d')!;
    ctx.imageSmoothingEnabled = false;

    // Fill paper background
    const imgData = ctx.createImageData(this.canvas.width, this.canvas.height);
    const data = imgData.data;
    for (let i = 0; i < data.length; i += 4) {
      data[i] = PAPER_R;
      data[i + 1] = PAPER_G;
      data[i + 2] = PAPER_B;
      data[i + 3] = 255;
    }

    // Render items
    let y = 0;
    for (const item of this.items) {
      if (item.type === 'text') {
        for (const line of item.lines) {
          this.renderTextLine(data, line, y);
          y += CHAR_H;
        }
      } else {
        this.renderBitmapItem(data, item, y);
        y += item.height;
      }
    }

    // Render partial current line
    if (partial.length > 0) {
      this.renderTextLine(data, partial, y);
    }

    ctx.putImageData(imgData, 0, 0);

    // Auto-scroll
    if (this.container) {
      this.container.scrollTop = this.container.scrollHeight;
    }

    if (this.onUpdate) this.onUpdate();
  }

  private setPixel(data: Uint8ClampedArray, canvasW: number, sx: number, sy: number): void {
    // Draw a SCALE×SCALE block at scaled coordinates
    for (let dy = 0; dy < SCALE; dy++) {
      for (let dx = 0; dx < SCALE; dx++) {
        const px = sx + dx;
        const py = sy + dy;
        const i = (py * canvasW + px) * 4;
        data[i] = INK_R;
        data[i + 1] = INK_G;
        data[i + 2] = INK_B;
        // alpha already 255
      }
    }
  }

  private renderTextLine(data: Uint8ClampedArray, line: string, dotY: number): void {
    const canvasW = DOT_W * SCALE;
    for (let i = 0; i < line.length; i++) {
      const ch = line.charCodeAt(i);
      if (ch < 0x20 || ch > 0x7E) continue;
      const fontIdx = (ch - 0x20) * 5;
      const dotX = i * CHAR_W;
      for (let col = 0; col < 5; col++) {
        const bits = FONT_5X7[fontIdx + col];
        for (let row = 0; row < 7; row++) {
          if (bits & (1 << row)) {
            this.setPixel(data, canvasW, (dotX + col) * SCALE, (dotY + row) * SCALE);
          }
        }
      }
    }
  }

  private renderBitmapItem(data: Uint8ClampedArray, item: BitmapItem, dotY: number): void {
    const canvasW = DOT_W * SCALE;
    const xOff = Math.floor((DOT_W - item.width) / 2); // center horizontally
    for (let py = 0; py < item.height; py++) {
      for (let px = 0; px < item.width; px++) {
        if (item.pixels[py * item.width + px]) {
          this.setPixel(data, canvasW, (xOff + px) * SCALE, (dotY + py) * SCALE);
        }
      }
    }
  }

  feed(): void {
    this.appendTextLine('');
    this.appendTextLine('');
    this.appendTextLine('');
    this.dirty = true;
    this.render();
  }

  clear(): void {
    this.items = [];
    this.currentLine = [];
    this.column = 0;
    this.dirty = true;
    this.render();
  }

  getText(): string {
    const lines: string[] = [];
    for (const item of this.items) {
      if (item.type === 'text') lines.push(...item.lines);
    }
    const partial = this.buildCurrentLine();
    if (partial.length > 0) lines.push(partial);
    return lines.join('\n');
  }

  async copyAsImage(): Promise<void> {
    this.dirty = true;
    this.render();
    if (!this.canvas) throw new Error('No canvas');

    const blob = await new Promise<Blob | null>(resolve =>
      this.canvas!.toBlob(resolve, 'image/png')
    );
    if (!blob) throw new Error('Failed to create image');

    await navigator.clipboard.write([
      new ClipboardItem({ 'image/png': blob })
    ]);
  }

  reset(): void {
    this.currentLine = [];
    this.column = 0;
    // Preserve printed items (like paper already printed)
    this.dirty = true;
  }

  saveState(): object {
    return {
      items: this.items.map(item => {
        if (item.type === 'text') return item;
        return {
          type: 'bitmap',
          width: item.width,
          height: item.height,
          pixels: btoa(String.fromCharCode(...item.pixels)),
        };
      }),
      currentLine: this.currentLine,
      column: this.column,
    };
  }

  loadState(s: any): void {
    if (!s) return;

    // Handle old format (paperLines from previous implementation)
    if (s.paperLines) {
      this.items = s.paperLines.length > 0
        ? [{ type: 'text' as const, lines: s.paperLines }]
        : [];
      this.currentLine = s.currentLine || [];
      this.column = s.column || 0;
      this.dirty = true;
      return;
    }

    // New format with items array
    this.items = (s.items || []).map((item: any) => {
      if (item.type === 'text') return item;
      const binStr = atob(item.pixels);
      const pixels = new Array(binStr.length);
      for (let i = 0; i < binStr.length; i++) pixels[i] = binStr.charCodeAt(i);
      return { type: 'bitmap', width: item.width, height: item.height, pixels };
    });
    this.currentLine = s.currentLine || [];
    this.column = s.column || 0;
    this.dirty = true;
  }
}
