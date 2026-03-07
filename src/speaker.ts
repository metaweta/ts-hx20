// Speaker audio output via Web Audio API
// Monitors slave CPU Port 1 bit 5 transitions to produce square wave tones

const E_CLOCK = 614400; // HD6301 E clock frequency
const MIN_HALF_PERIOD = 10;   // reject glitches
const MAX_HALF_PERIOD = 10000; // reject implausibly low frequencies

export class Speaker {
  private audioCtx: AudioContext | null = null;
  private oscillator: OscillatorNode | null = null;
  private gain: GainNode | null = null;
  private muted = false;

  // Transition tracking
  private lastBit5 = 0;
  private lastTransitionCycle = 0;
  private hadTransition = false;
  private playing = false;

  /** Called from onWritePort1 with the full port value and slave CPU totalCycles */
  updatePort1(val: number, totalCycles: number): void {
    const bit5 = (val >> 5) & 1;
    if (bit5 === this.lastBit5) return;
    this.lastBit5 = bit5;
    this.hadTransition = true;

    if (this.lastTransitionCycle === 0) {
      // First transition — just record the time
      this.lastTransitionCycle = totalCycles;
      return;
    }

    const halfPeriod = totalCycles - this.lastTransitionCycle;
    this.lastTransitionCycle = totalCycles;

    if (halfPeriod < MIN_HALF_PERIOD || halfPeriod > MAX_HALF_PERIOD) return;

    const freq = E_CLOCK / (2 * halfPeriod);
    this.setFrequency(freq);
  }

  /** Call at end of each frame — silence if no transitions occurred */
  endFrame(): void {
    if (!this.hadTransition && this.playing) {
      this.silence();
    }
    this.hadTransition = false;
  }

  /** Immediately stop sound (power-off) */
  stop(): void {
    this.silence();
    this.lastBit5 = 0;
    this.lastTransitionCycle = 0;
    this.hadTransition = false;
  }

  /** Toggle mute, returns new muted state */
  toggleMute(): boolean {
    this.muted = !this.muted;
    if (this.gain) {
      this.gain.gain.value = this.muted ? 0 : 0.10;
    }
    return this.muted;
  }

  private ensureAudioCtx(): void {
    if (this.audioCtx) return;
    this.audioCtx = new AudioContext();
    this.gain = this.audioCtx.createGain();
    this.gain.gain.value = this.muted ? 0 : 0.10;
    this.gain.connect(this.audioCtx.destination);
  }

  private setFrequency(freq: number): void {
    this.ensureAudioCtx();
    if (!this.oscillator) {
      this.oscillator = this.audioCtx!.createOscillator();
      this.oscillator.type = 'square';
      this.oscillator.frequency.value = freq;
      this.oscillator.connect(this.gain!);
      this.oscillator.start();
      this.playing = true;
    } else {
      this.oscillator.frequency.value = freq;
    }
  }

  private silence(): void {
    if (this.oscillator) {
      this.oscillator.stop();
      this.oscillator.disconnect();
      this.oscillator = null;
    }
    this.playing = false;
    this.lastTransitionCycle = 0;
  }
}
