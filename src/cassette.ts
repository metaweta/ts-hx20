// Virtual microcassette drive for HX-20
// Records/plays FSK signal at the bit level
//
// SAVE direction:
//   Slave CPU outputs FSK via output compare (OLVL → P21)
//   We record P21 transitions as interleaved [cycle, level, ...] arrays
//
// LOAD direction:
//   We replay stored transitions on P32 — slave CPU reads them
//
// Motor control:
//   Internal microcassette: P42 (microcassette power) from Port 4
//   External cassette: P30 (motor remote) from Port 3

export class Cassette {
  // Signal state
  motorOn = false;
  readLevel = true;   // P32 input, default HIGH (idle)

  // Recording state (captures P21 output compare transitions during SAVE)
  private recording = false;
  private recCycles = 0;
  private recData: number[] = [];  // interleaved [cycle, level, ...]
  private lastOCLevel = false;

  // Playback state (generates P32 from stored data during LOAD)
  private playing = false;
  private playCycles = 0;
  private playData: number[] = [];
  private playIdx = 0;

  // Tape library (persisted to localStorage)
  private library = new Map<string, number[]>();
  private currentTape: string | null = null;
  private tapeCounter = 0;

  // Callbacks
  onLibraryChange: () => void = () => {};
  onMotorChange: (on: boolean) => void = () => {};

  constructor() {
    this.loadFromStorage();
  }

  /** Advance cassette timing by N slave CPU cycles */
  advance(cycles: number): void {
    if (!this.motorOn) return;

    if (this.playing && this.playData.length > 0) {
      this.playCycles += cycles;
      // Advance playback index to current cycle position
      while (this.playIdx + 1 < this.playData.length) {
        if (this.playData[this.playIdx] > this.playCycles) break;
        this.readLevel = this.playData[this.playIdx + 1] !== 0;
        this.playIdx += 2;
      }
    }

    if (this.recording) {
      this.recCycles += cycles;
    }
  }

  /** Called when P21 changes due to output compare (OLVL → P21) during SAVE */
  setOCOutput(level: boolean): void {
    if (!this.recording) return;
    if (level === this.lastOCLevel) return;
    this.recData.push(this.recCycles, level ? 1 : 0);
    this.lastOCLevel = level;
  }

  /** Called when slave CPU writes P33 (FSK output to tape) — legacy path */
  setWriteData(level: boolean): void {
    // P33 is used for external cassette; internal uses P21 via output compare
    // Keep as fallback but primary recording is via setOCOutput
  }

  /** Motor control — called when slave CPU drives P30 or P42 */
  setMotor(on: boolean): void {
    if (on === this.motorOn) return;
    this.motorOn = on;

    if (on) {
      // Motor starting — begin recording and optionally playback
      this.recording = true;
      this.recCycles = 0;
      this.recData = [];
      this.lastOCLevel = false;

      if (this.currentTape && this.library.has(this.currentTape)) {
        // Tape loaded → start playback on P32
        this.playing = true;
        this.playData = this.library.get(this.currentTape)!;
        this.playIdx = 0;
        this.playCycles = 0;
        this.readLevel = true;
      } else {
        this.playing = false;
        this.readLevel = true;
      }
    } else {
      // Motor stopping — save recording if meaningful data was captured
      if (this.recording && this.recData.length > 20) {
        if (this.currentTape) {
          // Overwrite current tape with new recording
          this.library.set(this.currentTape, this.recData);
        } else {
          // No tape inserted — auto-create one
          this.tapeCounter++;
          const name = `tape-${this.tapeCounter}`;
          this.library.set(name, this.recData);
          this.currentTape = name;
        }
        this.saveToStorage();
        this.onLibraryChange();
      }
      this.recording = false;
      this.playing = false;
    }

    this.onMotorChange(on);
  }

  // --- Tape library API ---

  /** Insert a blank tape for recording (SAVE) */
  insertBlank(): string {
    this.tapeCounter++;
    const name = `tape-${this.tapeCounter}`;
    this.library.set(name, []);
    this.currentTape = name;
    this.saveToStorage();
    this.onLibraryChange();
    return name;
  }

  insertTape(name: string): void {
    if (this.library.has(name)) {
      this.currentTape = name;
    }
  }

  ejectTape(): void {
    this.currentTape = null;
  }

  getTapeNames(): string[] {
    return [...this.library.keys()];
  }

  getCurrentTape(): string | null {
    return this.currentTape;
  }

  deleteTape(name: string): void {
    this.library.delete(name);
    if (this.currentTape === name) this.currentTape = null;
    this.saveToStorage();
    this.onLibraryChange();
  }

  exportTape(name: string): string | null {
    const data = this.library.get(name);
    if (!data) return null;
    return JSON.stringify({ name, transitions: data });
  }

  importTape(json: string): string | null {
    try {
      const obj = JSON.parse(json);
      if (!obj.name || !Array.isArray(obj.transitions)) return null;
      this.library.set(obj.name as string, obj.transitions as number[]);
      this.saveToStorage();
      this.onLibraryChange();
      return obj.name as string;
    } catch {
      return null;
    }
  }

  // --- Persistence ---

  saveToStorage(): void {
    try {
      const data: Record<string, number[]> = {};
      for (const [k, v] of this.library) data[k] = v;
      localStorage.setItem('hx20-tapes', JSON.stringify({
        tapes: data,
        currentTape: this.currentTape,
        counter: this.tapeCounter,
      }));
    } catch (e) {
      console.warn('Cassette: failed to save library:', e);
    }
  }

  loadFromStorage(): void {
    try {
      const json = localStorage.getItem('hx20-tapes');
      if (!json) return;
      const s = JSON.parse(json);
      this.library.clear();
      if (s.tapes) {
        for (const [k, v] of Object.entries(s.tapes)) {
          this.library.set(k, v as number[]);
        }
      }
      this.currentTape = s.currentTape || null;
      this.tapeCounter = s.counter || 0;
    } catch (e) {
      console.warn('Cassette: failed to load library:', e);
    }
  }
}
