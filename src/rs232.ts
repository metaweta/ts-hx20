// RS-232C peer attached to the HX-20's high-speed serial / SIO bus.
//
// The HX-20 multiplexes its master CPU's SCI between three things via P22 (slaveSio):
//   slaveSio=0 → external SIO bus (TF-20 + EPSP display + RS-232C devices)
//   slaveSio=1 → slave CPU (cassette controller path)
//
// When slaveSio=0, every byte the firmware writes to TDR appears on the bus and is
// broadcast to all attached devices. Bytes this device wants to deliver to the host
// are pushed back via mainCPU.serialRecv (also gated on slaveSio=0 in the wiring).
//
// In addition, the firmware can bit-bang TX on Port 2 bit 1 for slow baud rates
// (110-9600). Those raw bit-level edges are recorded here as well; we sample them
// at the firmware-configured baud period to recover bytes.

export interface RS232Frame {
  byte: number;
  source: 'sci' | 'bitbang';
  cycle: number;
}

export class RS232 {
  // Captured TX (host → device) frames. Most recent at end.
  txLog: RS232FrameLog[] = [];
  // Capacity for the in-memory log; UI may render fewer.
  maxLog = 4096;

  // Handshake / modem-control inputs (device → host). True means the peer is
  // asserting the line (positive RS-232C voltage on the wire); the wiring in
  // HX20 inverts these to drive PORT1 bits 0/1, since the firmware (per
  // serial_write_byte at $E5E5) treats PORT1 bit clear as "asserted".
  //
  // Default to *not asserted* — i.e., no peer connected. With these defaults,
  // PORT1 bits 0/1 read as 1, matching an unwired (pulled-up) connector. Option
  // ROMs that probe PORT1 to detect a connected device (e.g. the Epson Link
  // ROM) see "no peer" by default and behave as if no cable were attached. The
  // UI checkboxes let the user assert the lines once they want to interact.
  cts = false;  // Port 1 bit 1 (CTS) — clear-to-send
  dsr = false;  // Port 1 bit 0 (DSR) — data-set-ready
  // CD/RI are not currently surfaced on master Port 1 in this emulator,
  // but kept here for UI completeness so a future wiring change can use them.
  cd = false;   // carrier detect
  ri = false;   // ring indicator

  // External hooks
  onTx: ((frame: RS232FrameLog) => void) | null = null;
  onRx: ((byte: number) => void) | null = null;

  // --- TX (host → device) ---

  /** Called when the firmware transmits a byte over the SCI to the SIO bus. */
  recvFromSCI(byte: number, cycle: number): void {
    this.appendTx({ byte: byte & 0xFF, source: 'sci', cycle });
  }

  /** Called when the firmware bit-bangs a complete byte on Port 2 bit 1. */
  recvFromBitbang(byte: number, cycle: number): void {
    this.appendTx({ byte: byte & 0xFF, source: 'bitbang', cycle });
  }

  private appendTx(frame: RS232FrameLog): void {
    this.txLog.push(frame);
    if (this.txLog.length > this.maxLog) {
      this.txLog.splice(0, this.txLog.length - this.maxLog);
    }
    if (this.onTx) this.onTx(frame);
  }

  /** Clear the captured TX log. */
  clearTxLog(): void {
    this.txLog = [];
  }

  // --- RX (device → host) ---

  /** Send a byte from this peer into the host's serial input. */
  sendByte(byte: number): void {
    if (this.onRx) this.onRx(byte & 0xFF);
  }

  /** Send a sequence of bytes (queued one-shot; no inter-byte pacing). */
  sendBytes(bytes: ArrayLike<number>): void {
    for (let i = 0; i < bytes.length; i++) this.sendByte(bytes[i]);
  }
}

export interface RS232FrameLog {
  byte: number;
  source: 'sci' | 'bitbang';
  cycle: number;
}

// Decoder for the firmware's bit-bang TXD line (master Port 2 bit 1).
//
// The firmware uses output-compare timing with sci_baud_period ($01AF) cycles per
// bit. We watch the TXD line for a HIGH→LOW transition (start bit), then sample the
// configured number of data bits at the configured period, optionally consume a
// parity bit, then re-arm on the next start bit.
//
// This decoder is deliberately tolerant: if the firmware hasn't initialised the
// baud period yet, it stays idle.
export class BitBangDecoder {
  private level = 1;             // current TXD line state (1 = idle/mark)
  private nextSampleCycle = 0;   // cycle at which to take the next sample
  private bitsCollected = 0;
  private dataBits = 8;
  private wantParity = false;
  private acc = 0;
  private inFrame = false;

  /** Called every CPU cycle's TXD level change. Pass the current cycle counter. */
  setLevel(level: number, cycle: number, period: number, dataBits: number, parity: boolean): void {
    level &= 1;
    if (level === this.level) return;
    const prev = this.level;
    this.level = level;
    if (!this.inFrame && prev === 1 && level === 0 && period > 0) {
      // start bit — sample center of first data bit
      this.inFrame = true;
      this.bitsCollected = 0;
      this.acc = 0;
      this.dataBits = Math.max(5, Math.min(8, dataBits | 0));
      this.wantParity = !!parity;
      this.nextSampleCycle = cycle + Math.floor(period * 1.5);
    }
  }

  /**
   * Drive the decoder forward in time. Call after instructions execute, passing the
   * current cycle and the currently configured period. Emits completed bytes via
   * the callback.
   */
  tick(cycle: number, period: number, emit: (byte: number) => void): void {
    if (!this.inFrame || period <= 0) return;
    while (this.inFrame && cycle >= this.nextSampleCycle) {
      if (this.bitsCollected < this.dataBits) {
        // LSB-first per RS-232 framing
        this.acc |= (this.level & 1) << this.bitsCollected;
        this.bitsCollected++;
        this.nextSampleCycle += period;
      } else if (this.wantParity) {
        this.wantParity = false;             // consume parity bit, ignore
        this.nextSampleCycle += period;
      } else {
        // stop bit window — emit and disarm
        emit(this.acc & ((1 << this.dataBits) - 1));
        this.inFrame = false;
      }
    }
  }

  reset(): void {
    this.inFrame = false;
    this.level = 1;
    this.bitsCollected = 0;
    this.acc = 0;
  }
}
