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
  shift?: boolean;  // true = HX-20 shift must be pressed, false = must not be
}

// Character-based map: maps e.key values to HX-20 matrix positions.
// shift: true means the HX-20 SHIFT key must be held for this character;
//        false means it must NOT be held (override PC shift state).
//        undefined means don't change the current shift state.
const CHAR_MAP: Record<string, KeyMapping> = {
  // Digits
  '0': { col: 0, row: 0 },
  '1': { col: 0, row: 1 },
  '2': { col: 0, row: 2 },
  '3': { col: 0, row: 3 },
  '4': { col: 0, row: 4 },
  '5': { col: 0, row: 5 },
  '6': { col: 0, row: 6 },
  '7': { col: 0, row: 7 },
  '8': { col: 1, row: 0 },
  '9': { col: 1, row: 1 },

  // Letters (shift state passed through for upper/lowercase)
  'a': { col: 2, row: 1 }, 'b': { col: 2, row: 2 },
  'c': { col: 2, row: 3 }, 'd': { col: 2, row: 4 },
  'e': { col: 2, row: 5 }, 'f': { col: 2, row: 6 },
  'g': { col: 2, row: 7 }, 'h': { col: 3, row: 0 },
  'i': { col: 3, row: 1 }, 'j': { col: 3, row: 2 },
  'k': { col: 3, row: 3 }, 'l': { col: 3, row: 4 },
  'm': { col: 3, row: 5 }, 'n': { col: 3, row: 6 },
  'o': { col: 3, row: 7 }, 'p': { col: 4, row: 0 },
  'q': { col: 4, row: 1 }, 'r': { col: 4, row: 2 },
  's': { col: 4, row: 3 }, 't': { col: 4, row: 4 },
  'u': { col: 4, row: 5 }, 'v': { col: 4, row: 6 },
  'w': { col: 4, row: 7 }, 'x': { col: 5, row: 0 },
  'y': { col: 5, row: 1 }, 'z': { col: 5, row: 2 },
  'A': { col: 2, row: 1, shift: true }, 'B': { col: 2, row: 2, shift: true },
  'C': { col: 2, row: 3, shift: true }, 'D': { col: 2, row: 4, shift: true },
  'E': { col: 2, row: 5, shift: true }, 'F': { col: 2, row: 6, shift: true },
  'G': { col: 2, row: 7, shift: true }, 'H': { col: 3, row: 0, shift: true },
  'I': { col: 3, row: 1, shift: true }, 'J': { col: 3, row: 2, shift: true },
  'K': { col: 3, row: 3, shift: true }, 'L': { col: 3, row: 4, shift: true },
  'M': { col: 3, row: 5, shift: true }, 'N': { col: 3, row: 6, shift: true },
  'O': { col: 3, row: 7, shift: true }, 'P': { col: 4, row: 0, shift: true },
  'Q': { col: 4, row: 1, shift: true }, 'R': { col: 4, row: 2, shift: true },
  'S': { col: 4, row: 3, shift: true }, 'T': { col: 4, row: 4, shift: true },
  'U': { col: 4, row: 5, shift: true }, 'V': { col: 4, row: 6, shift: true },
  'W': { col: 4, row: 7, shift: true }, 'X': { col: 5, row: 0, shift: true },
  'Y': { col: 5, row: 1, shift: true }, 'Z': { col: 5, row: 2, shift: true },

  // HX-20 unshifted punctuation (shift: false only where PC sends with shift)
  '@': { col: 2, row: 0, shift: false },  // PC: Shift+2
  ':': { col: 1, row: 2, shift: false },  // PC: Shift+;
  ';': { col: 1, row: 3 },
  ',': { col: 1, row: 4 },
  '-': { col: 1, row: 5 },
  '.': { col: 1, row: 6 },
  '/': { col: 1, row: 7 },
  '[': { col: 5, row: 3 },
  ']': { col: 5, row: 4 },
  '\\': { col: 5, row: 5 },
  ' ': { col: 6, row: 1 },

  // HX-20 shifted punctuation (Shift+key on HX-20)
  '^': { col: 2, row: 0, shift: true },   // Shift+@
  '*': { col: 1, row: 2, shift: true },   // Shift+:
  '+': { col: 1, row: 3, shift: true },   // Shift+;
  '<': { col: 1, row: 4, shift: true },   // Shift+,
  '=': { col: 1, row: 5, shift: true },   // Shift+-
  '>': { col: 1, row: 6, shift: true },   // Shift+.
  '?': { col: 1, row: 7, shift: true },   // Shift+/
  '{': { col: 5, row: 3, shift: true },   // Shift+[
  '}': { col: 5, row: 4, shift: true },   // Shift+]
  '|': { col: 5, row: 5, shift: true },   // Shift+\

  // PC symbols with no direct HX-20 equivalent — map to closest match
  '!': { col: 0, row: 1, shift: true },   // Shift+1 (HX-20 may differ)
  '#': { col: 0, row: 3, shift: true },   // Shift+3
  '$': { col: 0, row: 4, shift: true },   // Shift+4
  '%': { col: 0, row: 5, shift: true },   // Shift+5
  '&': { col: 0, row: 6, shift: true },   // Shift+6
  '\'': { col: 0, row: 7, shift: true },  // Shift+7
  '(': { col: 1, row: 0, shift: true },   // Shift+8
  ')': { col: 1, row: 1, shift: true },   // Shift+9
  '"': { col: 0, row: 2, shift: true },   // Shift+2
  '_': { col: 0, row: 0, shift: true },   // Shift+0 on HX-20
  '`': { col: 2, row: 0 },  // → mapped to @
  '~': { col: 2, row: 0, shift: true },   // → mapped to Shift+@ (^)
};

// Code-based map: maps e.code values for non-character keys
const CODE_MAP: Record<string, KeyMapping> = {
  // Special keys
  'Enter': { col: 6, row: 0 },
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
  // UP = Shift+LEFT, DOWN = Shift+RIGHT — handled specially)
  'ArrowLeft': { col: 5, row: 7 },
  'ArrowRight': { col: 5, row: 6 },

  // Modifiers
  'ShiftLeft': { col: 5, row: 9 },
  'ShiftRight': { col: 5, row: 9 },
  'ControlLeft': { col: 6, row: 9 },
  'ControlRight': { col: 6, row: 9 },

  // Virtual keyboard only (no physical F-key bindings)
  'HX_PF1': { col: 0, row: 8 },
  'HX_PF2': { col: 1, row: 8 },
  'HX_PF3': { col: 2, row: 8 },
  'HX_PF4': { col: 3, row: 8 },
  'HX_PF5': { col: 4, row: 8 },
  'HX_Num': { col: 6, row: 5 },   // NUM
  'HX_Grph': { col: 6, row: 6 },  // GRPH
  'HX_Scrn': { col: 7, row: 1 },  // SCRN

  // Physical key positions (digits) — used by virtual keyboard
  'Digit0': { col: 0, row: 0 },
  'Digit1': { col: 0, row: 1 },
  'Digit2': { col: 0, row: 2 },
  'Digit3': { col: 0, row: 3 },
  'Digit4': { col: 0, row: 4 },
  'Digit5': { col: 0, row: 5 },
  'Digit6': { col: 0, row: 6 },
  'Digit7': { col: 0, row: 7 },
  'Digit8': { col: 1, row: 0 },
  'Digit9': { col: 1, row: 1 },

  // Physical key positions (letters)
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

  // Physical key positions (punctuation)
  'Backquote': { col: 2, row: 0 },   // @ on HX-20
  'HX_Colon': { col: 1, row: 2 },    // : on HX-20 (virtual keyboard only)
  'Semicolon': { col: 1, row: 3 },
  'Comma': { col: 1, row: 4 },
  'Minus': { col: 1, row: 5 },
  'Period': { col: 1, row: 6 },
  'Slash': { col: 1, row: 7 },
  'BracketLeft': { col: 5, row: 3 },
  'BracketRight': { col: 5, row: 4 },
  'Backslash': { col: 5, row: 5 },
  'Space': { col: 6, row: 1 },
};

// GRPH character map: HX-20 byte value (0x80-0x9F) → matrix position.
// From the HX-20 user manual. GRPH key (col 6, row 6) must be held simultaneously.
// GRPH+digits produce 0xE0-0xE9, not listed here (those are above 0x9F).
const GRPH_MAP: Record<number, { col: number; row: number }> = {
  0x80: { col: 4, row: 3 }, // GRPH+S
  0x81: { col: 5, row: 0 }, // GRPH+X
  0x82: { col: 4, row: 7 }, // GRPH+W
  0x83: { col: 2, row: 4 }, // GRPH+D
  0x84: { col: 2, row: 1 }, // GRPH+A
  0x85: { col: 4, row: 4 }, // GRPH+T
  0x86: { col: 4, row: 2 }, // GRPH+R
  0x87: { col: 4, row: 1 }, // GRPH+Q
  0x88: { col: 2, row: 5 }, // GRPH+E
  0x89: { col: 5, row: 2 }, // GRPH+Z
  0x8A: { col: 2, row: 3 }, // GRPH+C
  0x8B: { col: 3, row: 2 }, // GRPH+J
  0x8C: { col: 2, row: 6 }, // GRPH+F
  0x8D: { col: 2, row: 7 }, // GRPH+G
  0x8E: { col: 3, row: 0 }, // GRPH+H
  0x8F: { col: 5, row: 1 }, // GRPH+Y
  0x90: { col: 4, row: 5 }, // GRPH+U
  0x91: { col: 3, row: 1 }, // GRPH+I
  0x92: { col: 3, row: 7 }, // GRPH+O
  0x93: { col: 4, row: 0 }, // GRPH+P
  0x94: { col: 2, row: 0 }, // GRPH+@
  0x95: { col: 3, row: 3 }, // GRPH+K
  0x96: { col: 4, row: 6 }, // GRPH+V
  0x97: { col: 1, row: 4 }, // GRPH+,
  0x98: { col: 3, row: 5 }, // GRPH+M
  0x99: { col: 3, row: 6 }, // GRPH+N
  0x9A: { col: 2, row: 2 }, // GRPH+B
  0x9B: { col: 1, row: 3 }, // GRPH+;
  0x9C: { col: 1, row: 6 }, // GRPH+.
  0x9D: { col: 1, row: 2 }, // GRPH+:
  0x9E: { col: 1, row: 7 }, // GRPH+/
  0x9F: { col: 3, row: 4 }, // GRPH+L
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

  // Track firmware CAPS state for paste shift-inversion.
  // HX-20 defaults to CAPS ON: unshifted=uppercase, shifted=lowercase.
  private capsLockOn = true;

  constructor() {
    this.reset();
  }

  reset(): void {
    this.matrix.fill(0xFF);
    this.kbrequest = false;
    this.irqLatch = false;
    this.capsLockOn = true;
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
    // irqLatch clearing is handled by the caller (hx20.ts) based on CPU context
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
    // irqLatch clearing is handled by the caller (hx20.ts) based on CPU context
    return result;
  }

  clearIrqLatch(): void {
    this.irqLatch = false;
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

  // Track synthetic shift state from character mapping or ArrowUp/ArrowDown
  private syntheticShift = false;
  // Track which matrix key was resolved for a given code (for keyUp matching)
  private activeKeys = new Map<string, KeyMapping>();

  // Resolve a key event to an HX-20 matrix mapping.
  // Tries CHAR_MAP (by e.key) first, then CODE_MAP (by e.code).
  private resolve(key: string, code: string): KeyMapping | null {
    return CHAR_MAP[key] || CODE_MAP[code] || null;
  }

  // Process PC keyboard events (key = e.key, code = e.code)
  // virtual=true for on-screen keyboard buttons (PF keys are sticky toggles)
  keyDown(code: string, key?: string, virtual = false): void {
    const k = key ?? code;

    // ArrowUp = Shift + LEFT, ArrowDown = Shift + RIGHT
    if (code === 'ArrowUp' || code === 'ArrowDown') {
      this.syntheticShift = true;
      this.isShiftPressed = true;
      const arrowRow = code === 'ArrowUp' ? 7 : 6;
      this.matrix[5] &= ~(1 << arrowRow);
      this.kbrequest = true;
      this.irqLatch = true;
      return;
    }

    // Modifier keys
    if (code === 'ShiftLeft' || code === 'ShiftRight') { this.isShiftPressed = true; this.kbrequest = true; this.irqLatch = true; return; }
    if (code === 'ControlLeft' || code === 'ControlRight') { this.isCtrlPressed = true; this.kbrequest = true; this.irqLatch = true; return; }

    // Track CAPS state (firmware toggle) for paste shift-inversion
    if (code === 'CapsLock') this.capsLockOn = !this.capsLockOn;

    const mapping = this.resolve(k, code);
    if (!mapping) return;

    // Apply HX-20 shift override if the character map specifies one
    if (mapping.shift === true) {
      this.syntheticShift = true;
      this.isShiftPressed = true;
    } else if (mapping.shift === false) {
      this.syntheticShift = true;
      this.isShiftPressed = false;
    }

    // Remember which matrix position this code activated (for keyUp)
    this.activeKeys.set(code, mapping);

    if (mapping.row < 8) {
      this.matrix[mapping.col] &= ~(1 << mapping.row);
      this.kbrequest = true;
      this.irqLatch = true;
    } else if (mapping.row === 8) {
      // CTRL+PF1: toggle Manual Microcassette Mode
      if (this.isCtrlPressed && code === 'HX_PF1') {
        this.setMMCM(!this.mmcmActive);
        return;  // setMMCM sends CTRL+PF1 / PF5 pulse to ROM
      }
      // PF5 in MMCM: exit (also sends PF5 pulse to ROM)
      if (this.mmcmActive && code === 'HX_PF5') {
        this.setMMCM(false);
        return;
      }
      // All PF keys: pass to ROM keyboard matrix (same in normal and MMCM mode)
      this.row8State[mapping.col] = true;
      this.kbrequest = true;
      this.irqLatch = true;
    }
  }

  keyUp(code: string, _key?: string): void {
    // ArrowUp = Shift + LEFT, ArrowDown = Shift + RIGHT
    if (code === 'ArrowUp' || code === 'ArrowDown') {
      const arrowRow = code === 'ArrowUp' ? 7 : 6;
      this.matrix[5] |= (1 << arrowRow);
      if (this.syntheticShift) { this.syntheticShift = false; this.isShiftPressed = false; }
      return;
    }

    // Modifier keys
    if (code === 'ShiftLeft' || code === 'ShiftRight') { this.isShiftPressed = false; return; }
    if (code === 'ControlLeft' || code === 'ControlRight') { this.isCtrlPressed = false; return; }

    // Use the mapping we stored on keyDown (since e.key may differ on keyUp)
    const mapping = this.activeKeys.get(code);
    if (!mapping) return;
    this.activeKeys.delete(code);

    // Release synthetic shift
    if (this.syntheticShift) { this.syntheticShift = false; this.isShiftPressed = false; }

    if (mapping.row < 8) {
      this.matrix[mapping.col] |= (1 << mapping.row);
    } else if (mapping.row === 8) {
      this.row8State[mapping.col] = false;
    }
  }

  // Get raw DIP switch state (for diagnostics)
  getDipSwitches(): number { return this.dipSwitches; }

  // Set DIP switch country code (0-7) and TF-20 flag
  setDipSwitches(country: number, tf20: boolean): void {
    // Switches are active low: closed (ON) = 0 in the keyboard matrix
    // Country is 3 bits, TF-20 is 1 bit
    this.dipSwitches = ((tf20 ? 0 : 1) << 3) | (country & 0x07);
  }

  // Sticky modifier state for on-screen keyboard
  private stickyCtrl = false;
  private stickyShift = false;
  private stickyGrph = false;
  private stickyCtrlBtn: HTMLElement | null = null;
  private stickyShiftBtns: HTMLElement[] = [];
  private stickyGrphBtn: HTMLElement | null = null;

  // --- Manual Microcassette Mode (MMCM) ---
  // Entered via CTRL+PF1. Swaps PF button labels to show transport functions:
  // PF1=FF, PF2=PLAY, PF3=STOP, PF4=REW, PF5=EXIT.
  // All PF keys are momentary pulses — the ROM handles motor engagement/disengagement.
  // CTRL+PF1 sends the keystroke to the ROM which enters its own cassette control mode.
  mmcmActive = false;
  private pfButtons = new Map<string, HTMLElement>();  // PF button refs for label swap

  private static readonly MMCM_LABELS: Record<string, string> = {
    'HX_PF1': 'FF', 'HX_PF2': 'PLAY', 'HX_PF3': 'STOP', 'HX_PF4': 'REW', 'HX_PF5': 'EXIT'
  };

  private setMMCM(active: boolean): void {
    const debug = (globalThis as any).hx20?.sciDebug;
    this.mmcmActive = active;
    // Update virtual keyboard button labels
    for (const [code, btn] of this.pfButtons) {
      if (active) {
        if (!btn.dataset.originalLabel) {
          btn.dataset.originalLabel = btn.textContent || '';
        }
        btn.textContent = Keyboard.MMCM_LABELS[code] || btn.textContent;
      } else {
        btn.textContent = btn.dataset.originalLabel || btn.textContent;
      }
    }
    if (active) {
      // Send CTRL+PF1 to ROM so it enters cassette control mode
      // isCtrlPressed is already true from the sticky CTRL or physical CTRL
      this.row8State[0] = true;  // PF1
      this.kbrequest = true;
      this.irqLatch = true;
      // Release PF1 and modifiers after ROM has scanned (~60ms = 3 OCF cycles)
      setTimeout(() => {
        this.row8State[0] = false;
        this.releaseStickyModifiers();
      }, 60);
    } else {
      // Send PF5 to ROM to exit cassette control mode
      this.row8State[4] = true;  // PF5
      this.kbrequest = true;
      this.irqLatch = true;
      setTimeout(() => { this.row8State[4] = false; }, 60);
      this.releaseStickyModifiers();
    }
    if (debug) console.log(`[MMCM] ${active ? 'ENTER' : 'EXIT'}`);
  }

  // Release sticky modifiers after a non-modifier key is pressed on the virtual keyboard
  private releaseStickyModifiers(): void {
    if (this.stickyCtrl) {
      this.stickyCtrl = false;
      this.isCtrlPressed = false;
      this.stickyCtrlBtn?.classList.remove('pressed');
    }
    if (this.stickyShift) {
      this.stickyShift = false;
      this.isShiftPressed = false;
      this.stickyShiftBtns.forEach(b => b.classList.remove('pressed'));
    }
    if (this.stickyGrph) {
      this.stickyGrph = false;
      this.matrix[6] |= (1 << 6); // release GRPH (col 6, row 6)
      this.stickyGrphBtn?.classList.remove('pressed');
    }
  }

  // --- Paste / type-in support (direct FIFO injection) ---
  // Instead of pressing keys in the matrix and relying on the firmware's
  // IRQ1 → scan → debounce pipeline (which has many timing pitfalls),
  // paste injects ASCII characters directly into the keyboard FIFO in RAM.
  private pasteQueue: string[] = [];
  private pasteActive = false;
  private pasteWaitFrames = 0;
  onPasteFinish: (() => void) | null = null;

  // Callback set by hx20.ts to write directly to kbd_fifo in main RAM.
  // Returns true if the character was injected, false if FIFO is full.
  injectToFifo: ((code: number) => boolean) | null = null;

  /** Feed a string into the keyboard FIFO one character at a time. */
  typeText(text: string): void {
    const normalized = text.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
    this.pasteQueue.push(...normalized);
    if (!this.pasteActive) {
      this.pasteActive = true;
      this.pasteWaitFrames = 0;
    }
  }

  cancelPaste(): void {
    this.pasteQueue.length = 0;
    this.pasteActive = false;
    this.pasteWaitFrames = 0;
  }

  get isPasting(): boolean {
    return this.pasteActive;
  }

  /** Called each frame from runFrame(). Injects next character into FIFO. */
  pasteUpdate(): void {
    if (!this.pasteActive || !this.injectToFifo) return;

    // Wait after Enter for line processing
    if (this.pasteWaitFrames > 0) {
      this.pasteWaitFrames--;
      return;
    }

    // Skip unmappable characters, inject next valid one
    while (this.pasteQueue.length > 0) {
      const ch = this.pasteQueue.shift()!;
      const code = ch.charCodeAt(0);

      // Map character to HX-20 FIFO byte
      let fifoCode: number | null = null;
      if (ch === '\n') {
        fifoCode = 0x0D; // Enter/CR
      } else if (code >= 0x20 && code <= 0x7E) {
        fifoCode = code; // Printable ASCII
      } else if (code >= 0x80 && code <= 0x9F) {
        fifoCode = code; // GRPH characters
      } else if (code === 0x09) {
        fifoCode = 0x09; // Tab
      }

      if (fifoCode === null) continue; // skip unmappable

      if (!this.injectToFifo(fifoCode)) {
        // FIFO full — put character back and retry next frame
        this.pasteQueue.unshift(ch);
        return;
      }

      // Wake the CPU from SLP/WAI — BASIC's input routine sleeps
      // waiting for a keyboard interrupt when the FIFO is empty.
      this.irqLatch = true;

      // After Enter, wait for BASIC to process the line
      if (fifoCode === 0x0D) {
        this.pasteWaitFrames = 12;
        return;
      }

      // One character per frame to let the firmware echo and process
      return;
    }

    // Queue empty — paste complete
    this.pasteActive = false;
    this.onPasteFinish?.();
  }

  // Build the on-screen keyboard
  buildUI(container: HTMLElement): void {
    container.innerHTML = '';
    this.stickyShiftBtns = [];
    const rows = [
      // Row 1: Function/special keys
      [
        { label: 'PAUSE', code: 'Pause', cls: 'key-light' },
        { label: 'MENU', code: 'End', cls: 'key-light' },
        { label: 'BREAK', code: 'Escape', cls: 'key-red' },
        { label: 'PF1', code: 'HX_PF1', cls: 'key-light' },
        { label: 'PF2', code: 'HX_PF2', cls: 'key-light' },
        { label: 'PF3', code: 'HX_PF3', cls: 'key-light' },
        { label: 'PF4', code: 'HX_PF4', cls: 'key-light' },
        { label: 'PF5', code: 'HX_PF5', cls: 'key-light' },
        null,
        { label: 'NUM', code: 'HX_Num', cls: 'key-light' },
        { label: 'HOME', code: 'Home', cls: 'key-light' },
        { label: 'SCRN', code: 'HX_Scrn', cls: 'key-light' },
        { label: 'DEL', code: 'Backspace', cls: 'key-light' },
      ],
      // Row 2: Number/symbol row
      [
        { label: '1 !', code: 'Digit1' },
        { label: '2 "', code: 'Digit2' },
        { label: '3 #', code: 'Digit3' },
        { label: '4 $', code: 'Digit4' },
        { label: '5 %', code: 'Digit5' },
        { label: '6 &', code: 'Digit6' },
        { label: '7 \'', code: 'Digit7' },
        { label: '8 (', code: 'Digit8' },
        { label: '9 )', code: 'Digit9' },
        { label: '0 _', code: 'Digit0' },
        { label: '- =', code: 'Minus' },
        { label: '[ {', code: 'BracketLeft' },
        { label: '] }', code: 'BracketRight' },
        { label: '\\ |', code: 'Backslash' },
      ],
      // Row 3: QWERTY row (offset left)
      [
        { label: 'TAB', code: 'Tab', cls: 'key-light' },
        { label: 'Q', code: 'KeyQ' }, { label: 'W', code: 'KeyW' },
        { label: 'E', code: 'KeyE' }, { label: 'R', code: 'KeyR' },
        { label: 'T', code: 'KeyT' }, { label: 'Y', code: 'KeyY' },
        { label: 'U', code: 'KeyU' }, { label: 'I', code: 'KeyI' },
        { label: 'O', code: 'KeyO' }, { label: 'P', code: 'KeyP' },
        { label: '@ ^', code: 'Backquote' },
        { label: '\u2190\u2191', code: 'ArrowLeft', cls: 'key-light' },
        { label: '\u2192\u2193', code: 'ArrowRight', cls: 'key-light' },
      ],
      // Row 4: Home row (CTRL=light, RETURN=red wide)
      [
        { label: 'CTRL', code: 'ControlLeft', cls: 'key-light' },
        { label: 'A', code: 'KeyA' }, { label: 'S', code: 'KeyS' },
        { label: 'D', code: 'KeyD' }, { label: 'F', code: 'KeyF' },
        { label: 'G', code: 'KeyG' }, { label: 'H', code: 'KeyH' },
        { label: 'J', code: 'KeyJ' }, { label: 'K', code: 'KeyK' },
        { label: 'L', code: 'KeyL' },
        { label: '; +', code: 'Semicolon' },
        { label: ': *', code: 'HX_Colon' },
        { label: 'RETURN', code: 'Enter', cls: 'key-red wide' },
      ],
      // Row 5: Bottom letter row (offset right)
      [
        { label: 'SHIFT', code: 'ShiftLeft', cls: 'key-light' },
        { label: 'Z', code: 'KeyZ' }, { label: 'X', code: 'KeyX' },
        { label: 'C', code: 'KeyC' }, { label: 'V', code: 'KeyV' },
        { label: 'B', code: 'KeyB' }, { label: 'N', code: 'KeyN' },
        { label: 'M', code: 'KeyM' },
        { label: ', <', code: 'Comma' }, { label: '. >', code: 'Period' },
        { label: '/ ?', code: 'Slash' },
        { label: 'SHIFT', code: 'ShiftRight', cls: 'key-light' },
        { label: 'GRPH', code: 'HX_Grph', cls: 'key-light' },
      ],
      // Row 6: Space row (centered)
      [
        { label: 'CAPS', code: 'CapsLock', cls: 'key-caps' },
        { label: 'SPACE', code: 'Space', cls: 'key-dark spacebar' },
      ],
    ];

    const rowClasses = ['', '', 'kb-row-offset-left', '', 'kb-row-offset-right', 'kb-row-center'];

    rows.forEach((row, rowIndex) => {
      const rowDiv = document.createElement('div');
      rowDiv.className = 'kb-row' + (rowClasses[rowIndex] ? ' ' + rowClasses[rowIndex] : '');

      for (const key of row) {
        if (!key) {
          const spacer = document.createElement('div');
          rowDiv.appendChild(spacer);
          continue;
        }
        const btn = document.createElement('div');
        btn.className = 'key' + (key.cls ? ' ' + key.cls : '');
        btn.textContent = key.label;
        btn.dataset.code = key.code;

        const isModifier = key.code === 'ControlLeft' || key.code === 'ControlRight' ||
                           key.code === 'ShiftLeft' || key.code === 'ShiftRight';
        const isGrph = key.code === 'HX_Grph';
        const isPFKey = /^HX_PF[1-5]$/.test(key.code);

        if (isGrph) {
          // GRPH: sticky toggle (hold-modifier behavior via click)
          this.stickyGrphBtn = btn;
          btn.addEventListener('mousedown', (e) => {
            e.preventDefault();
            this.stickyGrph = !this.stickyGrph;
            if (this.stickyGrph) {
              this.matrix[6] &= ~(1 << 6); // press GRPH (col 6, row 6)
            } else {
              this.matrix[6] |= (1 << 6);  // release GRPH
            }
            btn.classList.toggle('pressed', this.stickyGrph);
            this.kbrequest = true;
            this.irqLatch = true;
          });
        } else if (isPFKey) {
          // PF keys: pass to ROM keyboard matrix (labels swap in MMCM)
          this.pfButtons.set(key.code, btn);
          btn.addEventListener('mousedown', (e) => {
            e.preventDefault();
            this.keyDown(key.code, undefined, true);
            btn.classList.add('pressed');
          });
          btn.addEventListener('mouseup', () => {
            this.keyUp(key.code);
            btn.classList.remove('pressed');
            this.releaseStickyModifiers();
          });
          btn.addEventListener('mouseleave', () => {
            this.keyUp(key.code);
            btn.classList.remove('pressed');
          });
        } else if (isModifier) {
          // Track button references for sticky visual feedback
          if (key.code === 'ControlLeft' || key.code === 'ControlRight') this.stickyCtrlBtn = btn;
          if (key.code === 'ShiftLeft' || key.code === 'ShiftRight') this.stickyShiftBtns.push(btn);

          // Sticky toggle: click to activate, click again or press another key to release
          btn.addEventListener('mousedown', (e) => {
            e.preventDefault();
            if (key.code === 'ControlLeft' || key.code === 'ControlRight') {
              this.stickyCtrl = !this.stickyCtrl;
              this.isCtrlPressed = this.stickyCtrl;
              btn.classList.toggle('pressed', this.stickyCtrl);
            } else {
              this.stickyShift = !this.stickyShift;
              this.isShiftPressed = this.stickyShift;
              this.stickyShiftBtns.forEach(b => b.classList.toggle('pressed', this.stickyShift));
            }
            this.kbrequest = true;
            this.irqLatch = true;
          });
        } else {
          // Normal key: press on mousedown, release on mouseup/mouseleave,
          // and release any sticky modifiers on mouseup
          btn.addEventListener('mousedown', (e) => {
            e.preventDefault();
            this.keyDown(key.code);
            btn.classList.add('pressed');
          });
          btn.addEventListener('mouseup', () => {
            this.keyUp(key.code);
            btn.classList.remove('pressed');
            this.releaseStickyModifiers();
          });
          btn.addEventListener('mouseleave', () => {
            this.keyUp(key.code);
            btn.classList.remove('pressed');
          });
        }
        rowDiv.appendChild(btn);
      }

      container.appendChild(rowDiv);
    });
  }
}
