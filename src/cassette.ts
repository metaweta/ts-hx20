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

  // Instance identity
  private storageKey: string;
  private label: string;

  // Auto-rewind after SAVE completes (CAS1 yes, CAS0 no — has position counter UI)
  autoRewindAfterSave = true;

  // Invert playback levels (CAS0: cassette mechanism inverts signal between P21 write and P20 read)
  invertPlayback = false;

  // Callbacks
  onLibraryChange: () => void = () => {};
  onMotorChange: (on: boolean) => void = () => {};

  constructor(storageKey = 'hx20-tapes', label = 'TAPE') {
    this.storageKey = storageKey;
    this.label = label;
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
        let newLevel = this.playData[this.playIdx + 1] !== 0;
        if (this.invertPlayback) newLevel = !newLevel;
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
      console.log(`[${this.label}] No playback data`);
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

    console.log(`[${this.label}] Playback data: ${numTransitions} transitions, ` +
      `${durationCycles} cycles (${(durationCycles / 614400).toFixed(2)}s)`);
    console.log(`[${this.label}] First transition: cycle=${firstCycle}, level=${this.playData[1]}`);
    console.log(`[${this.label}] Half-periods: min=${halfPeriods[0]}, max=${halfPeriods[halfPeriods.length-1]}, ` +
      `median=${halfPeriods[Math.floor(halfPeriods.length/2)]}`);
    if (shortPeriods.length > 0 && longPeriods.length > 0) {
      const shortAvg = shortPeriods.reduce((s, v) => s + v, 0) / shortPeriods.length;
      const longAvg = longPeriods.reduce((s, v) => s + v, 0) / longPeriods.length;
      console.log(`[${this.label}] Short half-periods (1-bit, 2KHz): ${shortPeriods.length} avg=${shortAvg.toFixed(1)}`);
      console.log(`[${this.label}] Long half-periods (0-bit, 1KHz): ${longPeriods.length} avg=${longAvg.toFixed(1)}`);
      console.log(`[${this.label}] Full-cycle estimates: short=${(shortAvg*2).toFixed(0)}, long=${(longAvg*2).toFixed(0)}`);
    }

    // Show first 10 transitions
    console.log(`[${this.label}] First 10 transitions:`);
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

  /** Motor control — called when slave CPU drives P30 or P42
   *  recordMode: true for SAVE (cmd 0x81) — suppresses playback readLevel updates
   *  since the real cassette mechanism disables the read amplifier during record */
  setMotor(on: boolean, recordMode = false): void {
    if (on === this.motorOn) {
      console.log(`[${this.label}] setMotor(${on}) — already ${on ? 'ON' : 'OFF'}, skipping`);
      return;
    }
    this.motorOn = on;

    if (on) {
      // Motor starting — recording is NOT started here; it auto-starts on
      // first setWriteData()/setOCOutput() call (so LOAD doesn't record)
      this.recording = false;
      this.lastP21Level = false;
      this.lastP33Level = false;

      if (recordMode) {
        // Record mode: don't start playback (read amplifier is disabled on real hardware)
        this.playing = false;
        this.readLevel = true;
        this.recData = [];
        this.recCycles = 0;
        console.log(`[${this.label}] Motor ON (record mode)`);
      } else if (this.currentTape && this.library.has(this.currentTape)) {
        // Start playback on P32 (for LOAD), restoring saved position
        const existing = this.library.get(this.currentTape)!;
        this.playing = true;
        this.playData = existing;
        this.playIdx = this.savedPlayIdx;
        this.playCycles = this.savedPlayCycles;
        this.readLevel = true;
        console.log(`[${this.label}] Motor ON: resuming playback at idx=${this.playIdx/2} cycle=${this.playCycles}`);
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
      console.log(`[${this.label}] Motor OFF: playTransitions=${this.playTransitions} ` +
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
        if (this.autoRewindAfterSave) {
          // Auto-rewind after recording so next LOAD starts from beginning
          this.savedPlayIdx = 0;
          this.savedPlayCycles = 0;
          console.log(`[${this.label}] Recording saved, auto-rewound for LOAD`);
        } else {
          console.log(`[${this.label}] Recording saved (no auto-rewind)`);
        }
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

  /** Rewind tape to beginning (cassette controller command 0x88) */
  rewind(): void {
    this.savedPlayIdx = 0;
    this.savedPlayCycles = 0;
    console.log(`[${this.label}] Rewind to start`);
  }

  /** Fast-forward to end of tape (cassette controller command 0x84) */
  fastForward(): void {
    if (this.currentTape && this.library.has(this.currentTape)) {
      const data = this.library.get(this.currentTape)!;
      this.savedPlayIdx = data.length;
      this.savedPlayCycles = data.length >= 2 ? data[data.length - 2] + 1 : 0;
      console.log(`[${this.label}] Fast-forward to end: idx=${this.savedPlayIdx / 2}`);
    }
  }

  /** Adjust tape position by delta entries (positive = forward, negative = rewind).
   *  Used by emulator transport controls for continuous FF/REW. */
  adjustPosition(delta: number): void {
    if (!this.currentTape || !this.library.has(this.currentTape)) return;
    const data = this.library.get(this.currentTape)!;
    if (data.length < 2) return;
    // Move by delta pairs (each entry is 2 elements: cycle + level)
    const newIdx = Math.max(0, Math.min(this.savedPlayIdx + delta * 2, data.length));
    this.savedPlayIdx = newIdx;
    this.savedPlayCycles = newIdx >= 2 ? data[newIdx - 2] : 0;
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

  /** Pack transition data: delta-encode cycles, drop alternating levels, base64 */
  private static packTransitions(data: number[]): { initLevel: number; data: string } {
    if (data.length < 2) return { initLevel: 1, data: '' };
    const initLevel = data[1];
    // Collect cycle values (every other element starting at 0)
    const cycles: number[] = [];
    for (let i = 0; i < data.length; i += 2) cycles.push(data[i]);
    // Delta-encode: first value stored as-is (4 bytes), then deltas
    // Delta encoding: <2 bytes Uint16 LE> if < 0xFF00, else <0xFF 0xFF> + <4 bytes Uint32 LE>
    const buf = new ArrayBuffer(4 + cycles.length * 6); // max possible size
    const view = new DataView(buf);
    let off = 0;
    view.setUint32(off, cycles[0], true); off += 4;
    for (let i = 1; i < cycles.length; i++) {
      const delta = cycles[i] - cycles[i - 1];
      if (delta < 0xFF00) {
        view.setUint16(off, delta, true); off += 2;
      } else {
        view.setUint16(off, 0xFFFF, true); off += 2;
        view.setUint32(off, delta, true); off += 4;
      }
    }
    // Convert to base64
    const bytes = new Uint8Array(buf, 0, off);
    let bin = '';
    for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
    return { initLevel, data: btoa(bin) };
  }

  /** Unpack base64 delta-encoded transition data back to interleaved [cycle, level, ...] */
  private static unpackTransitions(initLevel: number, packed: string): number[] {
    if (!packed) return [];
    const bin = atob(packed);
    const bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    const view = new DataView(bytes.buffer);
    const result: number[] = [];
    let off = 0;
    let cycle = view.getUint32(off, true); off += 4;
    let level = initLevel;
    result.push(cycle, level);
    while (off < bytes.length) {
      const d = view.getUint16(off, true); off += 2;
      let delta: number;
      if (d === 0xFFFF) {
        delta = view.getUint32(off, true); off += 4;
      } else {
        delta = d;
      }
      cycle += delta;
      level = level ? 0 : 1;
      result.push(cycle, level);
    }
    return result;
  }

  exportTape(name: string): string | null {
    const data = this.library.get(name);
    if (!data) return null;
    const p = Cassette.packTransitions(data);
    return JSON.stringify({ name, v: 2, initLevel: p.initLevel, data: p.data });
  }

  importTape(json: string): string | null {
    try {
      const obj = JSON.parse(json);
      if (!obj.name) return null;
      if (obj.v !== 2 || typeof obj.data !== 'string') return null;
      const data = Cassette.unpackTransitions(obj.initLevel ?? 1, obj.data);
      this.library.set(obj.name as string, data);
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
      const tapes: Record<string, { initLevel: number; data: string }> = {};
      for (const [k, v] of this.library) {
        tapes[k] = Cassette.packTransitions(v);
      }
      localStorage.setItem(this.storageKey, JSON.stringify({
        v: 2,
        tapes,
        currentTape: this.currentTape,
        counter: this.tapeCounter,
      }));
    } catch (e) {
      console.warn('Cassette: failed to save library:', e);
    }
  }

  loadFromStorage(): void {
    try {
      const json = localStorage.getItem(this.storageKey);
      if (!json) return;
      const s = JSON.parse(json);
      this.library.clear();
      if (s.tapes) {
        for (const [k, v] of Object.entries(s.tapes) as [string, any][]) {
          this.library.set(k, Cassette.unpackTransitions(v.initLevel ?? 1, v.data ?? ''));
        }
      }
      this.currentTape = s.currentTape || null;
      this.tapeCounter = s.counter || 0;
    } catch (e) {
      console.warn('Cassette: failed to load library:', e);
    }
  }
}
