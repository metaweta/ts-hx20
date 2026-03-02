// Microcassette drive mechanism emulation for HX-20 internal cassette (CAS0:)
//
// The HX-20's internal microcassette connects via a multiplexed cable set.
// The slave CPU sends 8-bit commands via bit-bang (P43=data, P44=clock).
// The drive responds on P46 (multiplexed by P44: CNT when LOW, HSW when HIGH)
// and MI1/P17 (count signal to master CPU).
//
// Signal multiplexing (TRM Table 3-6):
//   P44=0: P46 = CNT (count pulses while motor runs)
//   P44=1: P46 = HSW (head switch: LOW = head engaged)

export enum DriveState {
  IDLE,
  PLAY,
  RECORD,
  REWIND_STEP,
  FORWARD_STEP,
  FAST_FORWARD,
  REWIND,
}

export class MicrocassetteDrive {
  state = DriveState.IDLE;

  // Command acknowledge pulse (P46 LOW for ~5000 cycles)
  private ackActive = false;
  private ackTimer = 0;

  // CNT signal: periodic toggle while motor runs (period: 21845 cycles ≈ 35.6ms)
  private cntLevel = true;    // HIGH when idle
  private cntCounter = 0;

  // MI1 signal to master CPU P17 (same period as CNT)
  private mi1Level = true;    // HIGH when idle (cassette present)
  private mi1Counter = 0;

  // Head engagement (play/record modes)
  private headEngaged = false;

  // Motor state
  private motorOn = false;

  // CNT/MI1 toggle periods (cycles per toggle).
  // Play/record: slow (218450 = 10x real hardware) for usable position counter pace.
  // FF/rewind: fast (21845 = real hardware speed) so transport moves quickly.
  private static readonly CNT_PERIOD_SLOW = 218450;
  private static readonly CNT_PERIOD_FAST = 21845;

  // Active period — set per command
  private cntPeriod = MicrocassetteDrive.CNT_PERIOD_SLOW;

  // Ack pulse duration: ~5000 slave cycles (~8ms). The ROM's retry loop checks P46
  // every ~614 cycles (1ms OCF) and needs 4 consecutive matches.
  private static readonly ACK_DURATION = 5000;

  // Callbacks (wired by hx20.ts)
  onMotorChange: (on: boolean, recordMode: boolean) => void = () => {};
  onRewind: () => void = () => {};
  onFastForward: () => void = () => {};
  onPositionAdjust: (delta: number) => void = () => {};

  /** Process a decoded 8-bit command from the bit-bang protocol */
  processCommand(cmd: number): void {
    // Start ack pulse (P46 LOW)
    this.ackActive = true;
    this.ackTimer = MicrocassetteDrive.ACK_DURATION;

    switch (cmd) {
      case 0x00: // Stop
      case 0x18: // Stop (alternate)
        if (this.motorOn) {
          this.motorOn = false;
          this.headEngaged = false;
          this.cntLevel = true;
          this.cntCounter = 0;
          this.mi1Level = true;
          this.mi1Counter = 0;
          this.onMotorChange(false, false);
        }
        this.state = DriveState.IDLE;
        break;

      case 0x01: // Play (for LOAD — sent at FE62)
        this.motorOn = true;
        this.headEngaged = true;
        this.cntPeriod = MicrocassetteDrive.CNT_PERIOD_SLOW;
        this.cntCounter = 0;
        this.mi1Counter = 0;
        this.state = DriveState.PLAY;
        this.onMotorChange(true, false);
        break;

      case 0x81: // Record (for SAVE — sent at FD15)
        this.motorOn = true;
        this.headEngaged = true;
        this.cntPeriod = MicrocassetteDrive.CNT_PERIOD_SLOW;
        this.cntCounter = 0;
        this.mi1Counter = 0;
        this.state = DriveState.RECORD;
        this.onMotorChange(true, true);
        break;

      case 0x0A: // Rewind step (used by slave cmd_73)
        this.motorOn = true;
        this.headEngaged = false;
        this.cntPeriod = MicrocassetteDrive.CNT_PERIOD_FAST;
        this.cntCounter = 0;
        this.mi1Counter = 0;
        this.state = DriveState.REWIND_STEP;
        this.onPositionAdjust(-100);
        break;

      case 0x11: // Forward step (used by slave cmd_71)
        this.motorOn = true;
        this.headEngaged = false;
        this.cntPeriod = MicrocassetteDrive.CNT_PERIOD_FAST;
        this.cntCounter = 0;
        this.mi1Counter = 0;
        this.state = DriveState.FORWARD_STEP;
        this.onPositionAdjust(+100);
        break;

      case 0x84: // Fast forward
        this.motorOn = true;
        this.headEngaged = false;
        this.cntPeriod = MicrocassetteDrive.CNT_PERIOD_FAST;
        this.cntCounter = 0;
        this.mi1Counter = 0;
        this.state = DriveState.FAST_FORWARD;
        this.onFastForward();
        break;

      case 0x88: // Rewind
        this.motorOn = true;
        this.headEngaged = false;
        this.cntPeriod = MicrocassetteDrive.CNT_PERIOD_FAST;
        this.cntCounter = 0;
        this.mi1Counter = 0;
        this.state = DriveState.REWIND;
        this.onRewind();
        break;

      default:
        // Unknown command — still acknowledge
        break;
    }
  }

  /** Advance drive timing by N slave CPU cycles */
  advance(cycles: number): void {
    // Advance ack timer
    if (this.ackActive) {
      this.ackTimer -= cycles;
      if (this.ackTimer <= 0) {
        this.ackTimer = 0;
        this.ackActive = false;
      }
    }

    // Generate CNT and MI1 pulses while motor runs
    if (this.motorOn) {
      this.cntCounter += cycles;
      while (this.cntCounter >= this.cntPeriod) {
        this.cntCounter -= this.cntPeriod;
        this.cntLevel = !this.cntLevel;
      }

      this.mi1Counter += cycles;
      while (this.mi1Counter >= this.cntPeriod) {
        this.mi1Counter -= this.cntPeriod;
        this.mi1Level = !this.mi1Level;
      }
    }
  }

  /** Get P46 output, multiplexed by P44 level
   *  P44 LOW: CNT (count pulses) — toggles while motor runs
   *  P44 HIGH: HSW (head switch) — LOW during ack, HIGH otherwise */
  getP46(p44High: boolean): boolean {
    if (p44High) {
      // HSW channel: reflects command ack only.
      // LOW during ack pulse (cas_ctrl_check/FC31 reads this right after motor cmd).
      // HIGH when idle (cas_ctrl_init/FC2D expects this before/between blocks).
      // We don't model continuous head engagement on HSW because the ROM's
      // multi-block SAVE calls FC2D between blocks without stopping the motor,
      // expecting P46 = HIGH even though the head was previously engaged.
      return !this.ackActive;
    } else {
      // CNT channel: count pulses only — ack does NOT appear here
      // (P44 mux physically separates HSW and CNT on the cable set)
      return this.motorOn ? this.cntLevel : true;
    }
  }

  /** P40: motor running indicator (1 = motor on) */
  getP40(): boolean {
    return this.motorOn;
  }

  /** MI1: count signal to master CPU P17
   *  Toggles while motor runs, HIGH when idle */
  getMI1(): boolean {
    return this.motorOn ? this.mi1Level : true;
  }

  /** Reset all state */
  reset(): void {
    this.state = DriveState.IDLE;
    this.ackActive = false;
    this.ackTimer = 0;
    this.cntLevel = true;
    this.cntCounter = 0;
    this.mi1Level = true;
    this.mi1Counter = 0;
    this.headEngaged = false;
    this.motorOn = false;
  }
}
