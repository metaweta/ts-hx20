// HX-20 Keyboard Matrix: 8 columns (KSC0-7) x 10 rows (KRTN0-9)
// Active low: 0 = key pressed, 1 = not pressed

// Key matrix layout from MAME:
// [row][col] = key
//        KSC0   KSC1   KSC2   KSC3   KSC4   KSC5   KSC6     KSC7
// Row0:  0      8      @      H      P      X      RETURN   HOME
// Row1:  1      9      A      I      Q      Y      SPACE    SCRN
// Row2:  2      :      B      J      R      Z      TAB      BREAK
// Row3:  3      ;      C      K      S      [      -        PAUSE
// Row4:  4      ,      D      L      T      ]      -        INS/DEL
// Row5:  5      -      E      M      U      \      NUM      MENU
// Row6:  6      .      F      N      V      LEFT   GRPH     -
// Row7:  7      /      G      O      W      RIGHT  CAPS     -
// Row8:  PF1    PF2    PF3    PF4    PF5    FEED   -        -
// Row9:  SW1    SW2    SW3    SW4    -      SHIFT  CTRL     PRINT

interface KeyMapping {
  col: number;
  row: number;
}

// Map PC keyboard codes to HX-20 matrix positions
const KEY_MAP: Record<string, KeyMapping> = {
  // Numbers
  'Digit0': { col: 0, row: 0 }, 'Digit1': { col: 0, row: 1 },
  'Digit2': { col: 0, row: 2 }, 'Digit3': { col: 0, row: 3 },
  'Digit4': { col: 0, row: 4 }, 'Digit5': { col: 0, row: 5 },
  'Digit6': { col: 0, row: 6 }, 'Digit7': { col: 0, row: 7 },
  'Digit8': { col: 1, row: 0 }, 'Digit9': { col: 1, row: 1 },

  // Punctuation
  'Semicolon': { col: 1, row: 3 },   // ; / +
  'Comma': { col: 1, row: 4 },       // , / <
  'Minus': { col: 1, row: 5 },       // - / =
  'Period': { col: 1, row: 6 },      // . / >
  'Slash': { col: 1, row: 7 },       // / / ?
  'Backquote': { col: 1, row: 2 },   // : / * (using backtick as proxy)
  'Equal': { col: 1, row: 5 },       // - / = (alt mapping)

  // Letters
  'KeyA': { col: 2, row: 1 }, 'KeyB': { col: 2, row: 2 },
  'KeyC': { col: 2, row: 3 }, 'KeyD': { col: 2, row: 4 },
  'KeyE': { col: 2, row: 5 }, 'KeyF': { col: 2, row: 6 },
  'KeyG': { col: 2, row: 7 }, 'KeyH': { col: 3, row: 0 },
  'KeyI': { col: 3, row: 1 }, 'KeyJ': { col: 3, row: 2 },
  'KeyK': { col: 3, row: 3 }, 'KeyL': { col: 3, row: 4 },
  'KeyM': { col: 3, row: 5 }, 'KeyN': { col: 3, row: 6 },
  'KeyO': { col: 3, row: 7 }, 'KeyP': { col: 4, row: 0 },
  'KeyQ': { col: 4, row: 1 }, 'KeyR': { col: 4, row: 2 },
  'KeyS': { col: 4, row: 3 }, 'KeyT': { col: 4, row: 4 },
  'KeyU': { col: 4, row: 5 }, 'KeyV': { col: 4, row: 6 },
  'KeyW': { col: 4, row: 7 }, 'KeyX': { col: 5, row: 0 },
  'KeyY': { col: 5, row: 1 }, 'KeyZ': { col: 5, row: 2 },

  // Brackets
  'BracketLeft': { col: 5, row: 3 },
  'BracketRight': { col: 5, row: 4 },
  'Backslash': { col: 5, row: 5 },

  // Special keys
  'Enter': { col: 6, row: 0 },
  'Space': { col: 6, row: 1 },
  'Tab': { col: 6, row: 2 },
  'CapsLock': { col: 6, row: 7 },
  'Home': { col: 7, row: 0 },
  'Escape': { col: 7, row: 2 },    // BREAK
  'Pause': { col: 7, row: 3 },     // PAUSE
  'Backspace': { col: 7, row: 4 }, // INS/DEL
  'Delete': { col: 7, row: 4 },    // INS/DEL
  'Insert': { col: 7, row: 4 },    // INS/DEL
  'End': { col: 7, row: 5 },       // MENU

  // Arrows (LEFT and RIGHT are physical HX-20 keys;
  // UP = Shift+LEFT, DOWN = Shift+RIGHT on the real keyboard)
  'ArrowLeft': { col: 5, row: 7 },
  'ArrowRight': { col: 5, row: 6 },

  // Modifiers
  'ShiftLeft': { col: 5, row: 9 },
  'ShiftRight': { col: 5, row: 9 },
  'ControlLeft': { col: 6, row: 9 },
  'ControlRight': { col: 6, row: 9 },

  // Function keys
  'F1': { col: 0, row: 8 },
  'F2': { col: 1, row: 8 },
  'F3': { col: 2, row: 8 },
  'F4': { col: 3, row: 8 },
  'F5': { col: 4, row: 8 },

  // Extra mappings
  'F10': { col: 6, row: 5 },  // NUM
  'F11': { col: 6, row: 6 },  // GRPH
  'F12': { col: 7, row: 1 },  // SCRN
};

export class Keyboard {
  // 8 columns x 10 rows, active low (0xFF = no keys pressed)
  private matrix: Uint8Array = new Uint8Array(8);
  private kbrequest = false;

  // DIP switch settings (row 9, cols 0-3)
  // Default: USA, no TF-20
  private dipSwitches = 0x0F; // all open (not pressed = 1), bits 0-3

  // Keyboard interrupt latch: set when key state changes, cleared by KRTN read
  private irqLatch = false;

  constructor() {
    this.reset();
  }

  reset(): void {
    this.matrix.fill(0xFF);
    this.kbrequest = false;
    this.irqLatch = false;
  }

  // Read keyboard return lines for given column selection
  // ksc: column select byte (active low - 0 = selected)
  readKRTN07(ksc: number): number {
    let result = 0xFF;
    for (let col = 0; col < 8; col++) {
      if (!(ksc & (1 << col))) {
        result &= this.matrix[col];
      }
    }
    // Reading keyboard matrix acknowledges the interrupt
    this.irqLatch = false;
    return result;
  }

  readKRTN89(ksc: number): number {
    let result = 0xFF; // bits 7-2 default high
    // Row 8-9 from each column
    for (let col = 0; col < 8; col++) {
      if (!(ksc & (1 << col))) {
        // Row 8 -> bit 0, Row 9 -> bit 1
        const colData = this.getRow89(col);
        result &= (0xFC | colData); // only affect bits 0-1
      }
    }
    // Bit 7: BUSY (active low) - always not busy
    // Bit 6: PWSW - power switch is ON (always 1 during emulation)
    //   Used by boot code at E061 for cold boot detection, and by
    //   IRQ1 handler at EF2C to route through timer/F580 path
    result &= 0x3F;
    result |= 0x80; // not busy
    result |= 0x40; // PWSW = 1 (power switch ON)
    // Reading keyboard matrix acknowledges the interrupt
    this.irqLatch = false;
    return result;
  }

  private getRow89(col: number): number {
    let bits = 0x03; // both rows not pressed
    switch (col) {
      // Row 9, cols 0-3: DIP switches
      case 0: if (!(this.dipSwitches & 0x01)) bits &= ~0x02; break;
      case 1: if (!(this.dipSwitches & 0x02)) bits &= ~0x02; break;
      case 2: if (!(this.dipSwitches & 0x04)) bits &= ~0x02; break;
      case 3: if (!(this.dipSwitches & 0x08)) bits &= ~0x02; break;
    }
    // Check if SHIFT is pressed (col 5, row 9)
    if (col === 5 && this.isShiftPressed) bits &= ~0x02;
    // Check if CTRL is pressed (col 6, row 9)
    if (col === 6 && this.isCtrlPressed) bits &= ~0x02;
    // Row 8 (function keys, paper feed)
    if (col < 8 && this.row8State[col]) bits &= ~0x01;
    return bits;
  }

  private isShiftPressed = false;
  private isCtrlPressed = false;
  private row8State = new Array(8).fill(false);

  hasKeyRequest(): boolean {
    return this.kbrequest;
  }

  clearKeyRequest(): void {
    this.kbrequest = false;
  }

  // IRQ latch: set on key change, cleared when firmware reads KRTN
  get irqPending(): boolean {
    return this.irqLatch;
  }

  // Track synthetic shift state from ArrowUp/ArrowDown
  private syntheticShift = false;

  // Process PC keyboard events
  keyDown(code: string): void {
    // ArrowUp = Shift + LEFT, ArrowDown = Shift + RIGHT
    if (code === 'ArrowUp' || code === 'ArrowDown') {
      this.syntheticShift = true;
      this.isShiftPressed = true;
      const arrowCol = 5;
      const arrowRow = code === 'ArrowUp' ? 7 : 6; // LEFT=row7, RIGHT=row6
      this.matrix[arrowCol] &= ~(1 << arrowRow);
      this.kbrequest = true;
      this.irqLatch = true;
      return;
    }

    const mapping = KEY_MAP[code];
    if (!mapping) return;

    if (code === 'ShiftLeft' || code === 'ShiftRight') this.isShiftPressed = true;
    if (code === 'ControlLeft' || code === 'ControlRight') this.isCtrlPressed = true;

    if (mapping.row < 8) {
      this.matrix[mapping.col] &= ~(1 << mapping.row);
      this.kbrequest = true;
      this.irqLatch = true;
    } else if (mapping.row === 8) {
      this.row8State[mapping.col] = true;
      this.kbrequest = true;
      this.irqLatch = true;
    } else if (mapping.row === 9) {
      // Handled via isShiftPressed/isCtrlPressed
      this.kbrequest = true;
      this.irqLatch = true;
    }
  }

  keyUp(code: string): void {
    // ArrowUp = Shift + LEFT, ArrowDown = Shift + RIGHT
    if (code === 'ArrowUp' || code === 'ArrowDown') {
      const arrowRow = code === 'ArrowUp' ? 7 : 6;
      this.matrix[5] |= (1 << arrowRow);
      if (this.syntheticShift) {
        this.syntheticShift = false;
        this.isShiftPressed = false;
      }
      return;
    }

    const mapping = KEY_MAP[code];
    if (!mapping) return;

    if (code === 'ShiftLeft' || code === 'ShiftRight') this.isShiftPressed = false;
    if (code === 'ControlLeft' || code === 'ControlRight') this.isCtrlPressed = false;

    if (mapping.row < 8) {
      this.matrix[mapping.col] |= (1 << mapping.row);
    } else if (mapping.row === 8) {
      this.row8State[mapping.col] = false;
    }
  }

  // Set DIP switch country code (0-7) and TF-20 flag
  setDipSwitches(country: number, tf20: boolean): void {
    // Switches are active low: closed (ON) = 0 in the keyboard matrix
    // Country is 3 bits, TF-20 is 1 bit
    this.dipSwitches = ((tf20 ? 0 : 1) << 3) | (country & 0x07);
  }

  // Build the on-screen keyboard
  buildUI(container: HTMLElement): void {
    container.innerHTML = '';
    const rows = [
      [
        { label: 'PF1', code: 'F1', cls: 'fn-key' },
        { label: 'PF2', code: 'F2', cls: 'fn-key' },
        { label: 'PF3', code: 'F3', cls: 'fn-key' },
        { label: 'PF4', code: 'F4', cls: 'fn-key' },
        { label: 'PF5', code: 'F5', cls: 'fn-key' },
        null,
        { label: 'NUM', code: 'F10', cls: 'fn-key' },
        { label: 'GRPH', code: 'F11', cls: 'fn-key' },
        { label: 'SCRN', code: 'F12', cls: 'fn-key' },
        null,
        { label: 'HOME', code: 'Home' },
        { label: 'BRK', code: 'Escape' },
        { label: 'PAUSE', code: 'Pause' },
        { label: 'INS/DEL', code: 'Backspace' },
        { label: 'MENU', code: 'End' },
      ],
      [
        { label: '1', code: 'Digit1' }, { label: '2', code: 'Digit2' },
        { label: '3', code: 'Digit3' }, { label: '4', code: 'Digit4' },
        { label: '5', code: 'Digit5' }, { label: '6', code: 'Digit6' },
        { label: '7', code: 'Digit7' }, { label: '8', code: 'Digit8' },
        { label: '9', code: 'Digit9' }, { label: '0', code: 'Digit0' },
        { label: ': *', code: 'Backquote' }, { label: '; +', code: 'Semicolon' },
        { label: '- =', code: 'Minus' }, { label: 'RETURN', code: 'Enter', cls: 'wide' },
      ],
      [
        { label: 'TAB', code: 'Tab' },
        { label: 'Q', code: 'KeyQ' }, { label: 'W', code: 'KeyW' },
        { label: 'E', code: 'KeyE' }, { label: 'R', code: 'KeyR' },
        { label: 'T', code: 'KeyT' }, { label: 'Y', code: 'KeyY' },
        { label: 'U', code: 'KeyU' }, { label: 'I', code: 'KeyI' },
        { label: 'O', code: 'KeyO' }, { label: 'P', code: 'KeyP' },
        { label: '@ ^', code: 'Backquote' },
        { label: '[ {', code: 'BracketLeft' },
        { label: '] }', code: 'BracketRight' },
      ],
      [
        { label: 'CTRL', code: 'ControlLeft', cls: 'mod-key' },
        { label: 'CAPS', code: 'CapsLock' },
        { label: 'A', code: 'KeyA' }, { label: 'S', code: 'KeyS' },
        { label: 'D', code: 'KeyD' }, { label: 'F', code: 'KeyF' },
        { label: 'G', code: 'KeyG' }, { label: 'H', code: 'KeyH' },
        { label: 'J', code: 'KeyJ' }, { label: 'K', code: 'KeyK' },
        { label: 'L', code: 'KeyL' },
        { label: ', <', code: 'Comma' }, { label: '. >', code: 'Period' },
        { label: '/ ?', code: 'Slash' },
      ],
      [
        { label: 'SHIFT', code: 'ShiftLeft', cls: 'mod-key wide' },
        { label: 'Z', code: 'KeyZ' }, { label: 'X', code: 'KeyX' },
        { label: 'C', code: 'KeyC' }, { label: 'V', code: 'KeyV' },
        { label: 'B', code: 'KeyB' }, { label: 'N', code: 'KeyN' },
        { label: 'M', code: 'KeyM' },
        { label: '\\ |', code: 'Backslash' },
        null,
        { label: 'SPACE', code: 'Space', cls: 'wide' },
        null,
        { label: '\u2190\u2191', code: 'ArrowLeft' },
        { label: '\u2192\u2193', code: 'ArrowRight' },
      ],
    ];

    for (const row of rows) {
      for (const key of row) {
        if (!key) {
          const spacer = document.createElement('div');
          container.appendChild(spacer);
          continue;
        }
        const btn = document.createElement('div');
        btn.className = 'key' + (key.cls ? ' ' + key.cls : '');
        btn.textContent = key.label;
        btn.dataset.code = key.code;
        btn.addEventListener('mousedown', (e) => {
          e.preventDefault();
          this.keyDown(key.code);
          btn.classList.add('pressed');
        });
        btn.addEventListener('mouseup', () => {
          this.keyUp(key.code);
          btn.classList.remove('pressed');
        });
        btn.addEventListener('mouseleave', () => {
          this.keyUp(key.code);
          btn.classList.remove('pressed');
        });
        container.appendChild(btn);
      }
    }
  }
}
