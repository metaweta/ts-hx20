// Epson HX-20 Built-in Printer Emulation
// 24-column thermal dot-matrix printer — captures characters and renders to a scrollable paper panel

export class Printer {
  private paperLines: string[] = [];
  private currentLine: string[] = [];
  private column = 0;
  private readonly WIDTH = 24;
  private dirty = false;
  private el: HTMLPreElement | null = null;

  onUpdate: (() => void) | null = null;

  printChar(ch: number): void {
    if (ch === 0x0D) {
      // CR: flush current line, reset column
      this.flushLine();
      this.column = 0;
    } else if (ch === 0x0A) {
      // LF: flush current line, start new line
      this.flushLine();
      this.column = 0;
    } else if (ch === 0x08) {
      // BS: move column left
      if (this.column > 0) this.column--;
    } else if (ch === 0x09) {
      // TAB: advance to next tab stop (every 8 columns)
      this.column = Math.min(this.WIDTH - 1, (this.column & ~7) + 8);
    } else if (ch >= 0x20 && ch <= 0x7E) {
      // Printable character
      if (this.column >= this.WIDTH) {
        this.flushLine();
        this.column = 0;
      }
      this.currentLine[this.column] = String.fromCharCode(ch);
      this.column++;
    }
    // Ignore BEL (0x07) and other control chars

    this.dirty = true;
  }

  private flushLine(): void {
    // Build line string from sparse array, filling gaps with spaces
    let line = '';
    for (let i = 0; i < this.WIDTH; i++) {
      line += this.currentLine[i] || ' ';
    }
    this.paperLines.push(line.trimEnd());
    this.currentLine = [];
  }

  attachElement(el: HTMLPreElement): void {
    this.el = el;
    this.render();
  }

  render(): void {
    if (!this.el) return;
    if (!this.dirty) return;
    this.dirty = false;

    // Build display: all flushed lines + current partial line
    let text = this.paperLines.join('\n');
    const partial = this.buildCurrentLine();
    if (partial.length > 0) {
      if (text.length > 0) text += '\n';
      text += partial;
    }

    this.el.textContent = text;
    this.el.scrollTop = this.el.scrollHeight;
    if (this.onUpdate) this.onUpdate();
  }

  private buildCurrentLine(): string {
    let line = '';
    for (let i = 0; i < this.WIDTH; i++) {
      line += this.currentLine[i] || ' ';
    }
    return line.trimEnd();
  }

  feed(): void {
    this.paperLines.push('');
    this.paperLines.push('');
    this.paperLines.push('');
    this.dirty = true;
    this.render();
  }

  clear(): void {
    this.paperLines = [];
    this.currentLine = [];
    this.column = 0;
    this.dirty = true;
    this.render();
  }

  getText(): string {
    let text = this.paperLines.join('\n');
    const partial = this.buildCurrentLine();
    if (partial.length > 0) {
      if (text.length > 0) text += '\n';
      text += partial;
    }
    return text;
  }

  reset(): void {
    this.currentLine = [];
    this.column = 0;
    // Preserve paperLines (like paper already printed)
    this.dirty = true;
  }

  saveState(): object {
    return {
      paperLines: this.paperLines,
      currentLine: this.currentLine,
      column: this.column,
    };
  }

  loadState(s: any): void {
    if (!s) return;
    this.paperLines = s.paperLines || [];
    this.currentLine = s.currentLine || [];
    this.column = s.column || 0;
    this.dirty = true;
  }
}
