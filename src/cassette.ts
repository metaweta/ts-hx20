// Virtual cassette drive for HX-20
// Records/plays FSK signal at the bit level
//
// SAVE direction:
//   CAS0: (internal) — FSK via output compare (OLVL → P21), recorded by setOCOutput()
//   CAS1: (external) — FSK via Port 3 bit 3 (P33), recorded by setWriteData()
//   Both record transitions as interleaved [cycle, level, ...] arrays
//
// LOAD direction:
//   We replay stored transitions on P32 — slave CPU reads them
//
// Motor control:
//   Internal microcassette: P42 (cassette controller bit-bang) from Port 4
//   External cassette: P30 (motor remote, active low) from Port 3

export class Cassette {
  // Signal state
  motorOn = false;
  readLevel = true;   // P32 input, default HIGH (idle)

  // Recording state (captures P21 output compare transitions during SAVE)
  private recording = false;
  private recCycles = 0;
  private recData: number[] = [];  // interleaved [cycle, level, ...]
  private lastP21Level = false;  // CAS0: P21 output compare dedup
  private lastP33Level = false;  // CAS1: P33 port toggle dedup

  // Playback state (generates P32 from stored data during LOAD)
  private playing = false;
  private playCycles = 0;
  private playData: number[] = [];
  private playIdx = 0;
  // Saved playback position (persists across motor OFF/ON cycles)
  private savedPlayIdx = 0;
  private savedPlayCycles = 0;

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

  // Debug: playback transition counter (for diagnostics)
  private playTransitions = 0;

  /** Advance cassette timing by N slave CPU cycles */
  advance(cycles: number): void {
    if (!this.motorOn) return;

    if (this.playing && this.playData.length > 0) {
      this.playCycles += cycles;
      // Advance playback index to current cycle position
      while (this.playIdx + 1 < this.playData.length) {
        if (this.playData[this.playIdx] > this.playCycles) break;
        const newLevel = this.playData[this.playIdx + 1] !== 0;
        if (newLevel !== this.readLevel) {
          this.playTransitions++;
        }
        this.readLevel = newLevel;
        this.playIdx += 2;
      }
    }

    if (this.recording) {
      this.recCycles += cycles;
    }
  }

  /** Dump tape data statistics (for debugging) */
  dumpTapeStats(): void {
    if (!this.playData || this.playData.length === 0) {
      console.log('[TAPE] No playback data');
      return;
    }
    const numTransitions = this.playData.length / 2;
    const firstCycle = this.playData[0];
    const lastCycle = this.playData[this.playData.length - 2];
    const durationCycles = lastCycle - firstCycle;

    // Compute half-period statistics
    const halfPeriods: number[] = [];
    for (let i = 2; i < this.playData.length; i += 2) {
      halfPeriods.push(this.playData[i] - this.playData[i - 2]);
    }
    halfPeriods.sort((a, b) => a - b);

    // Find two main frequency clusters (for FSK 1KHz/2KHz)
    const shortPeriods = halfPeriods.filter(p => p < 400);
    const longPeriods = halfPeriods.filter(p => p >= 400);

    console.log(`[TAPE] Playback data: ${numTransitions} transitions, ` +
      `${durationCycles} cycles (${(durationCycles / 614400).toFixed(2)}s)`);
    console.log(`[TAPE] First transition: cycle=${firstCycle}, level=${this.playData[1]}`);
    console.log(`[TAPE] Half-periods: min=${halfPeriods[0]}, max=${halfPeriods[halfPeriods.length-1]}, ` +
      `median=${halfPeriods[Math.floor(halfPeriods.length/2)]}`);
    if (shortPeriods.length > 0 && longPeriods.length > 0) {
      const shortAvg = shortPeriods.reduce((s, v) => s + v, 0) / shortPeriods.length;
      const longAvg = longPeriods.reduce((s, v) => s + v, 0) / longPeriods.length;
      console.log(`[TAPE] Short half-periods (1-bit, 2KHz): ${shortPeriods.length} avg=${shortAvg.toFixed(1)}`);
      console.log(`[TAPE] Long half-periods (0-bit, 1KHz): ${longPeriods.length} avg=${longAvg.toFixed(1)}`);
      console.log(`[TAPE] Full-cycle estimates: short=${(shortAvg*2).toFixed(0)}, long=${(longAvg*2).toFixed(0)}`);
    }

    // Show first 10 transitions
    console.log('[TAPE] First 10 transitions:');
    for (let i = 0; i < Math.min(20, this.playData.length); i += 2) {
      const cycle = this.playData[i];
      const level = this.playData[i + 1];
      const prev = i >= 2 ? this.playData[i - 2] : 0;
      console.log(`  [${i/2}] cycle=${cycle} level=${level} delta=${cycle - prev}`);
    }
  }

  // Debug counters
  private ocTransitions = 0;
  private p33Transitions = 0;

  /** Called when P21 changes due to output compare (OLVL → P21) during SAVE */
  setOCOutput(level: boolean): void {
    if (!this.motorOn) return;
    if (level === this.lastP21Level) return;
    // Auto-start recording on first real transition
    if (!this.recording) {
      this.recording = true;
      this.recData = [];
      this.recCycles = 0;
      // If appending to existing tape, copy existing data
      if (this.currentTape && this.library.has(this.currentTape)) {
        const existing = this.library.get(this.currentTape)!;
        if (existing.length > 0) {
          this.recData = [...existing];
          this.recCycles = existing[existing.length - 2] + 1;
        }
      }
    }
    this.recData.push(this.recCycles, level ? 1 : 0);
    this.lastP21Level = level;
    this.ocTransitions++;
  }

  /** Called when slave CPU writes P33 (FSK output to tape) — CAS1: external cassette */
  setWriteData(level: boolean): void {
    if (!this.motorOn) return;
    if (level === this.lastP33Level) return;
    // Auto-start recording on first real transition
    if (!this.recording) {
      this.recording = true;
      this.recData = [];
      this.recCycles = 0;
      // If appending to existing tape, copy existing data
      if (this.currentTape && this.library.has(this.currentTape)) {
        const existing = this.library.get(this.currentTape)!;
        if (existing.length > 0) {
          this.recData = [...existing];
          this.recCycles = existing[existing.length - 2] + 1;
        }
      }
    }
    this.recData.push(this.recCycles, level ? 1 : 0);
    this.lastP33Level = level;
    this.p33Transitions++;
  }

  /** Motor control — called when slave CPU drives P30 or P42 */
  setMotor(on: boolean): void {
    if (on === this.motorOn) return;
    this.motorOn = on;

    if (on) {
      // Motor starting — recording is NOT started here; it auto-starts on
      // first setWriteData()/setOCOutput() call (so LOAD doesn't record)
      this.recording = false;
      this.lastP21Level = false;
      this.lastP33Level = false;

      if (this.currentTape && this.library.has(this.currentTape)) {
        // Start playback on P32 (for LOAD), restoring saved position
        const existing = this.library.get(this.currentTape)!;
        this.playing = true;
        this.playData = existing;
        this.playIdx = this.savedPlayIdx;
        this.playCycles = this.savedPlayCycles;
        this.readLevel = true;
        console.log(`[TAPE] Motor ON: resuming playback at idx=${this.playIdx/2} cycle=${this.playCycles}`);
      } else {
        // No tape — playback not possible, recording will auto-start if writes happen
        this.playing = false;
        this.readLevel = true;
        this.recData = [];
        this.recCycles = 0;
      }
    } else {
      // Motor stopping — save playback position for next motor cycle
      this.savedPlayIdx = this.playIdx;
      this.savedPlayCycles = this.playCycles;

      // Log playback/recording summary
      console.log(`[TAPE] Motor OFF: playTransitions=${this.playTransitions} ` +
        `ocTransitions=${this.ocTransitions} p33Transitions=${this.p33Transitions} ` +
        `recData=${this.recData.length/2} entries, playCycles=${this.playCycles} playIdx=${this.playIdx/2}`);
      this.playTransitions = 0;
      this.ocTransitions = 0;
      this.p33Transitions = 0;

      // Save recording only if actual FSK transitions were captured
      if (this.recording && this.recData.length > 20) {
        if (this.currentTape) {
          this.library.set(this.currentTape, this.recData);
        } else {
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
    this.savedPlayIdx = 0;
    this.savedPlayCycles = 0;
    this.saveToStorage();
    this.onLibraryChange();
    return name;
  }

  insertTape(name: string): void {
    if (this.library.has(name)) {
      this.currentTape = name;
      this.savedPlayIdx = 0;
      this.savedPlayCycles = 0;
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
