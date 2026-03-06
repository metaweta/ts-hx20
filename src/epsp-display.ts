// EPSP External Display Controller (Epson H00DC-IA CRT Display)
// Emulates the 40x24 text / 128x96 graphics external CRT connected via SCI
// Protocol: EPSP (Epson Standard Packet Protocol) at 38400 baud

// EPSP protocol constants
const EOT = 0x04;
const ENQ = 0x05;
const ACK = 0x06;
const NAK = 0x15;
const SOH = 0x01;
const STX = 0x02;
const ETX = 0x03;

// Device IDs
const DID_HX20 = 0x20;
const DID_CRT  = 0x30;
const DID_TF20_1 = 0x31;  // TF-20 drive 1
const DID_TF20_2 = 0x32;  // TF-20 drive 2

// Display dimensions
const TEXT_COLS = 40;
const TEXT_ROWS = 24;
const GFX_WIDTH = 128;
const GFX_HEIGHT = 96;

// Canvas dimensions (text mode: 8x8 per cell)
const CANVAS_W = TEXT_COLS * 8;  // 320
const CANVAS_H = TEXT_ROWS * 8;  // 192

// Classic 5x7 ASCII font, column-major format
// Each character is 5 bytes (columns), bit 0 = top row, bit 6 = bottom row
// Covers ASCII 32 (space) through 126 (~)
const FONT_5x7 = new Uint8Array([
  // 32: space
  0x00, 0x00, 0x00, 0x00, 0x00,
  // 33: !
  0x00, 0x00, 0x5F, 0x00, 0x00,
  // 34: "
  0x00, 0x07, 0x00, 0x07, 0x00,
  // 35: #
  0x14, 0x7F, 0x14, 0x7F, 0x14,
  // 36: $
  0x24, 0x2A, 0x7F, 0x2A, 0x12,
  // 37: %
  0x23, 0x13, 0x08, 0x64, 0x62,
  // 38: &
  0x36, 0x49, 0x55, 0x22, 0x50,
  // 39: '
  0x00, 0x05, 0x03, 0x00, 0x00,
  // 40: (
  0x00, 0x1C, 0x22, 0x41, 0x00,
  // 41: )
  0x00, 0x41, 0x22, 0x1C, 0x00,
  // 42: *
  0x14, 0x08, 0x3E, 0x08, 0x14,
  // 43: +
  0x08, 0x08, 0x3E, 0x08, 0x08,
  // 44: ,
  0x00, 0x50, 0x30, 0x00, 0x00,
  // 45: -
  0x08, 0x08, 0x08, 0x08, 0x08,
  // 46: .
  0x00, 0x60, 0x60, 0x00, 0x00,
  // 47: /
  0x20, 0x10, 0x08, 0x04, 0x02,
  // 48: 0
  0x3E, 0x51, 0x49, 0x45, 0x3E,
  // 49: 1
  0x00, 0x42, 0x7F, 0x40, 0x00,
  // 50: 2
  0x42, 0x61, 0x51, 0x49, 0x46,
  // 51: 3
  0x21, 0x41, 0x45, 0x4B, 0x31,
  // 52: 4
  0x18, 0x14, 0x12, 0x7F, 0x10,
  // 53: 5
  0x27, 0x45, 0x45, 0x45, 0x39,
  // 54: 6
  0x3C, 0x4A, 0x49, 0x49, 0x30,
  // 55: 7
  0x01, 0x71, 0x09, 0x05, 0x03,
  // 56: 8
  0x36, 0x49, 0x49, 0x49, 0x36,
  // 57: 9
  0x06, 0x49, 0x49, 0x29, 0x1E,
  // 58: :
  0x00, 0x36, 0x36, 0x00, 0x00,
  // 59: ;
  0x00, 0x56, 0x36, 0x00, 0x00,
  // 60: <
  0x08, 0x14, 0x22, 0x41, 0x00,
  // 61: =
  0x14, 0x14, 0x14, 0x14, 0x14,
  // 62: >
  0x00, 0x41, 0x22, 0x14, 0x08,
  // 63: ?
  0x02, 0x01, 0x51, 0x09, 0x06,
  // 64: @
  0x32, 0x49, 0x79, 0x41, 0x3E,
  // 65: A
  0x7E, 0x11, 0x11, 0x11, 0x7E,
  // 66: B
  0x7F, 0x49, 0x49, 0x49, 0x36,
  // 67: C
  0x3E, 0x41, 0x41, 0x41, 0x22,
  // 68: D
  0x7F, 0x41, 0x41, 0x22, 0x1C,
  // 69: E
  0x7F, 0x49, 0x49, 0x49, 0x41,
  // 70: F
  0x7F, 0x09, 0x09, 0x09, 0x01,
  // 71: G
  0x3E, 0x41, 0x49, 0x49, 0x7A,
  // 72: H
  0x7F, 0x08, 0x08, 0x08, 0x7F,
  // 73: I
  0x00, 0x41, 0x7F, 0x41, 0x00,
  // 74: J
  0x20, 0x40, 0x41, 0x3F, 0x01,
  // 75: K
  0x7F, 0x08, 0x14, 0x22, 0x41,
  // 76: L
  0x7F, 0x40, 0x40, 0x40, 0x40,
  // 77: M
  0x7F, 0x02, 0x0C, 0x02, 0x7F,
  // 78: N
  0x7F, 0x04, 0x08, 0x10, 0x7F,
  // 79: O
  0x3E, 0x41, 0x41, 0x41, 0x3E,
  // 80: P
  0x7F, 0x09, 0x09, 0x09, 0x06,
  // 81: Q
  0x3E, 0x41, 0x51, 0x21, 0x5E,
  // 82: R
  0x7F, 0x09, 0x19, 0x29, 0x46,
  // 83: S
  0x46, 0x49, 0x49, 0x49, 0x31,
  // 84: T
  0x01, 0x01, 0x7F, 0x01, 0x01,
  // 85: U
  0x3F, 0x40, 0x40, 0x40, 0x3F,
  // 86: V
  0x1F, 0x20, 0x40, 0x20, 0x1F,
  // 87: W
  0x3F, 0x40, 0x38, 0x40, 0x3F,
  // 88: X
  0x63, 0x14, 0x08, 0x14, 0x63,
  // 89: Y
  0x07, 0x08, 0x70, 0x08, 0x07,
  // 90: Z
  0x61, 0x51, 0x49, 0x45, 0x43,
  // 91: [
  0x00, 0x7F, 0x41, 0x41, 0x00,
  // 92: backslash
  0x02, 0x04, 0x08, 0x10, 0x20,
  // 93: ]
  0x00, 0x41, 0x41, 0x7F, 0x00,
  // 94: ^
  0x04, 0x02, 0x01, 0x02, 0x04,
  // 95: _
  0x40, 0x40, 0x40, 0x40, 0x40,
  // 96: `
  0x00, 0x01, 0x02, 0x04, 0x00,
  // 97: a
  0x20, 0x54, 0x54, 0x54, 0x78,
  // 98: b
  0x7F, 0x48, 0x44, 0x44, 0x38,
  // 99: c
  0x38, 0x44, 0x44, 0x44, 0x20,
  // 100: d
  0x38, 0x44, 0x44, 0x48, 0x7F,
  // 101: e
  0x38, 0x54, 0x54, 0x54, 0x18,
  // 102: f
  0x08, 0x7E, 0x09, 0x01, 0x02,
  // 103: g
  0x0C, 0x52, 0x52, 0x52, 0x3E,
  // 104: h
  0x7F, 0x08, 0x04, 0x04, 0x78,
  // 105: i
  0x00, 0x44, 0x7D, 0x40, 0x00,
  // 106: j
  0x20, 0x40, 0x44, 0x3D, 0x00,
  // 107: k
  0x7F, 0x10, 0x28, 0x44, 0x00,
  // 108: l
  0x00, 0x41, 0x7F, 0x40, 0x00,
  // 109: m
  0x7C, 0x04, 0x18, 0x04, 0x78,
  // 110: n
  0x7C, 0x08, 0x04, 0x04, 0x78,
  // 111: o
  0x38, 0x44, 0x44, 0x44, 0x38,
  // 112: p
  0x7C, 0x14, 0x14, 0x14, 0x08,
  // 113: q
  0x08, 0x14, 0x14, 0x18, 0x7C,
  // 114: r
  0x7C, 0x08, 0x04, 0x04, 0x08,
  // 115: s
  0x48, 0x54, 0x54, 0x54, 0x20,
  // 116: t
  0x04, 0x3F, 0x44, 0x40, 0x20,
  // 117: u
  0x3C, 0x40, 0x40, 0x20, 0x7C,
  // 118: v
  0x1C, 0x20, 0x40, 0x20, 0x1C,
  // 119: w
  0x3C, 0x40, 0x30, 0x40, 0x3C,
  // 120: x
  0x44, 0x28, 0x10, 0x28, 0x44,
  // 121: y
  0x0C, 0x50, 0x50, 0x50, 0x3C,
  // 122: z
  0x44, 0x64, 0x54, 0x4C, 0x44,
  // 123: {
  0x00, 0x08, 0x36, 0x41, 0x00,
  // 124: |
  0x00, 0x00, 0x7F, 0x00, 0x00,
  // 125: }
  0x00, 0x41, 0x36, 0x08, 0x00,
  // 126: ~
  0x10, 0x08, 0x08, 0x10, 0x08,
]);

const enum EPSPState {
  IDLE,
  ENQUIRY,
  WAIT_SOH,
  HEADER,
  DATA_STX,
  DATA_BYTES,
  DATA_ETX,
  DATA_CKS,
  RESPONSE_PENDING,          // Command executed, waiting for host's EOT before sending response
  RESPONSE_WAIT_HEADER_ACK,  // Sent response header, waiting for host's ACK
  RESPONSE_WAIT_DATA_ACK,    // Sent response data block, waiting for host's ACK
}

export class EPSPDisplay {
  // Display buffers
  textBuffer = new Uint8Array(TEXT_COLS * TEXT_ROWS);
  graphicsBuffer = new Uint8Array(GFX_WIDTH * GFX_HEIGHT);
  cursorX = 0;
  cursorY = 0;
  cursorVisible = true;
  cursorBlink = false;
  displayMode = 0;  // 0=text, 1=graphics, 2=color graphics
  virtualCols = TEXT_COLS;
  virtualRows = TEXT_ROWS;
  dirty = true;

  // Virtual coordinate origin — the ROM uses $08EB (low byte of line_buf_ptr+2)
  // as the row value in FNC 0xC2. On the LCD, FNC 0x87 sets the virtual origin
  // so the mapping is transparent. On the CRT, FNC 0x87 may not be sent during
  // SCREEN 1 init, so we auto-detect the origin from the first FNC 0xC2.
  private rowOrigin = 0;
  private originDetected = false;
  private hasWrittenChars = false;

  // EPSP protocol state
  private state = EPSPState.IDLE;
  private enquiryBuf: number[] = [];
  private headerBuf: number[] = [];
  private dataBuf: number[] = [];
  private fnc = 0;   // function code from header
  private siz = 0;   // data size from header (actual data length = siz + 1)
  private dataChecksum = 0;

  // Response TX queue
  private txQueue: number[] = [];
  private txCycleCounter = 0;
  private static readonly TX_BYTE_SPACING = 200;  // min cycles between TX bytes

  // EPSP response state (for commands that require a response packet)
  private responseFnc = 0;
  private responseData: number[] = [];
  private savedCharUnderCursor = 0x20;  // char at cursor before command execution
  private savedPixelColor = 0;          // pixel color for FNC 0x8F response
  private savedScreenLine: number[] = [];  // screen text for FNC 0x97 response

  // Callbacks
  onSendByte: ((data: number) => void) | null = null;

  // Canvas rendering
  private ctx: CanvasRenderingContext2D | null = null;
  private imageData: ImageData | null = null;

  constructor() {
    this.reset();
  }

  reset(): void {
    this.textBuffer.fill(0x20);  // fill with spaces
    this.graphicsBuffer.fill(0);
    this.cursorX = 0;
    this.cursorY = 0;
    this.cursorVisible = true;
    this.cursorBlink = false;
    this.displayMode = 0;
    this.virtualCols = TEXT_COLS;
    this.virtualRows = TEXT_ROWS;
    this.dirty = true;
    this.state = EPSPState.IDLE;
    this.enquiryBuf = [];
    this.headerBuf = [];
    this.dataBuf = [];
    this.fnc = 0;
    this.siz = 0;
    this.txQueue = [];
    this.txCycleCounter = 0;
    this.responseFnc = 0;
    this.responseData = [];
    this.savedScreenLine = [];
    this.rowOrigin = 0;
    this.originDetected = false;
    this.hasWrittenChars = false;
  }

  attachCanvas(canvas: HTMLCanvasElement): void {
    this.ctx = canvas.getContext('2d')!;
    this.imageData = this.ctx.createImageData(CANVAS_W, CANVAS_H);
    this.dirty = true;
  }

  // Called from HX20 serial routing when slaveSio=0
  recvByte(byte: number): void {
    switch (this.state) {
      case EPSPState.IDLE:
        if (byte === EOT) {
          this.enquiryBuf = [];
          this.state = EPSPState.ENQUIRY;
        } else {
          console.log(`[EPSP] IDLE: ignored byte 0x${byte.toString(16).padStart(2, '0')}`);
        }
        break;

      case EPSPState.ENQUIRY:
        this.enquiryBuf.push(byte);
        if (this.enquiryBuf.length === 4) {
          // enquiryBuf = [P1, DID, SID, ENQ]
          const did = this.enquiryBuf[1];
          const enq = this.enquiryBuf[3];
          if (did === DID_CRT && enq === ENQ) {
            console.log(`[EPSP] Enquiry OK: P1=0x${this.enquiryBuf[0].toString(16)} DID=0x${did.toString(16)} SID=0x${this.enquiryBuf[2].toString(16)} → ACK`);
            this.queueByte(ACK);
            this.state = EPSPState.WAIT_SOH;
          } else {
            console.log(`[EPSP] Enquiry rejected: DID=0x${did.toString(16)} ENQ=0x${enq.toString(16)}`);
            this.state = EPSPState.IDLE;
          }
        }
        break;

      case EPSPState.WAIT_SOH:
        if (byte === SOH) {
          this.headerBuf = [SOH];  // include SOH in checksum calculation
          this.state = EPSPState.HEADER;
        } else if (byte === EOT) {
          // Retry: new enquiry starting
          this.enquiryBuf = [];
          this.state = EPSPState.ENQUIRY;
        }
        break;

      case EPSPState.HEADER:
        this.headerBuf.push(byte);
        if (this.headerBuf.length === 7) {
          // headerBuf = [SOH, FMT, DID, SID, FNC, SIZ, HCS]
          let sum = 0;
          for (const b of this.headerBuf) sum += b;
          if ((sum & 0xFF) === 0) {
            // Checksum valid
            this.fnc = this.headerBuf[4];
            this.siz = this.headerBuf[5];
            console.log(`[EPSP] Header OK: FNC=0x${this.fnc.toString(16).padStart(2, '0')} SIZ=${this.siz} → ACK`);
            this.queueByte(ACK);
            // Host always sends a data block (SIZ+1 bytes), even for SIZ=0
            this.dataBuf = [];
            this.dataChecksum = 0;
            this.state = EPSPState.DATA_STX;
          } else {
            console.warn(`[EPSP] Header checksum error: sum=0x${(sum & 0xFF).toString(16)}`);
            this.queueByte(NAK);
            this.state = EPSPState.IDLE;
          }
        }
        break;

      case EPSPState.DATA_STX:
        if (byte === STX) {
          this.dataChecksum = STX;
          this.state = EPSPState.DATA_BYTES;
        } else {
          console.warn(`[EPSP] Expected STX, got 0x${byte.toString(16)}`);
          this.state = EPSPState.IDLE;
        }
        break;

      case EPSPState.DATA_BYTES:
        this.dataBuf.push(byte);
        this.dataChecksum = (this.dataChecksum + byte) & 0xFF;
        if (this.dataBuf.length >= this.siz + 1) {
          this.state = EPSPState.DATA_ETX;
        }
        break;

      case EPSPState.DATA_ETX:
        if (byte === ETX) {
          this.dataChecksum = (this.dataChecksum + ETX) & 0xFF;
          this.state = EPSPState.DATA_CKS;
        } else {
          console.warn(`[EPSP] Expected ETX, got 0x${byte.toString(16)}`);
          this.state = EPSPState.IDLE;
        }
        break;

      case EPSPState.DATA_CKS:
        if (((this.dataChecksum + byte) & 0xFF) === 0) {
          console.log(`[EPSP] Data OK: ${this.dataBuf.length} bytes → ACK → execute FNC=0x${this.fnc.toString(16).padStart(2, '0')}`);
          this.queueByte(ACK);
          this.executeCommand(this.fnc, this.dataBuf);
          // Commands with bit 6 clear (0x80-0xBF) require a response packet
          if (this.needsResponse(this.fnc)) {
            this.responseFnc = this.fnc;
            this.responseData = this.getResponseData(this.fnc);
            this.state = EPSPState.RESPONSE_PENDING;
          } else {
            this.state = EPSPState.IDLE;
          }
        } else {
          console.warn(`[EPSP] Data checksum error: sum=0x${((this.dataChecksum + byte) & 0xFF).toString(16)}`);
          this.queueByte(NAK);
          this.state = EPSPState.IDLE;
        }
        break;

      case EPSPState.RESPONSE_PENDING:
        // Host sends EOT after command exchange, then waits for our response
        if (byte === EOT) {
          console.log(`[EPSP] Response: sending header for FNC=0x${this.responseFnc.toString(16).padStart(2, '0')}`);
          this.queueResponseHeader();
          this.state = EPSPState.RESPONSE_WAIT_HEADER_ACK;
        }
        break;

      case EPSPState.RESPONSE_WAIT_HEADER_ACK:
        if (byte === ACK) {
          console.log(`[EPSP] Response: header ACK'd, sending data [${this.responseData.map(b => '0x' + b.toString(16).padStart(2, '0')).join(',')}]`);
          this.queueResponseDataBlock();
          this.state = EPSPState.RESPONSE_WAIT_DATA_ACK;
        } else if (byte === NAK) {
          // Retry header
          this.queueResponseHeader();
        }
        break;

      case EPSPState.RESPONSE_WAIT_DATA_ACK:
        if (byte === ACK) {
          console.log(`[EPSP] Response: data ACK'd, done`);
          // Send a status byte so the host's tf20_close_session receives it
          // immediately instead of timing out (~840K cycles = 1.37s per command).
          // Must NOT be EOT (0x04) — host would echo it back, corrupting state.
          // Must NOT be ENQ (0x05) — host would ACK and re-enter close loop.
          // Must NOT be DLE (0x10) — filtered by tf20_rx_response.
          // Any other byte → host exits via session_ok immediately.
          this.queueByte(0x00);
          this.state = EPSPState.IDLE;
        } else if (byte === NAK) {
          // Retry data
          this.queueResponseDataBlock();
        }
        break;
    }
  }

  private queueByte(byte: number): void {
    this.txQueue.push(byte);
  }

  // Check if command FNC requires a response packet (bit 6 clear = needs response)
  private needsResponse(fnc: number): boolean {
    return (fnc & 0x40) === 0;
  }

  // Get response data bytes for a given command
  private getResponseData(fnc: number): number[] {
    switch (fnc) {
      case 0x85: // CRT init → status
      case 0x88: // Set line width → status
      case 0x8C: // Set scroll mode → status
        return [0x00];
      case 0x89: // Get physical screen size → [cols-1, rows-1]
        return [TEXT_COLS - 1, TEXT_ROWS - 1];
      case 0x8F: // Read pixel at position → pixel color
        return [this.savedPixelColor];
      case 0x91: // Clear to end of line → return char that was at cursor before clear
      case 0x92: // Write character → return char that was at cursor before write
      case 0x98: // Echo input character → return char that was at cursor
        return [this.savedCharUnderCursor];
      case 0x97: // Read screen line → return text buffer contents
        return this.savedScreenLine;
      default:   // Most commands → single status byte (0x00 = success)
        return [0x00];
    }
  }

  // Queue response header: SOH + FMT + DID + SID + FNC + SIZ + HCS
  private queueResponseHeader(): void {
    const siz = this.responseData.length - 1;  // SIZ = data_length - 1
    const hdrBytes = [SOH, 0x00, DID_HX20, DID_CRT, this.responseFnc, siz];
    let sum = 0;
    for (const b of hdrBytes) sum += b;
    const hcs = (-sum) & 0xFF;
    for (const b of hdrBytes) this.txQueue.push(b);
    this.txQueue.push(hcs);
  }

  // Queue response data block: STX + data + ETX + CKS
  private queueResponseDataBlock(): void {
    let sum = STX;
    this.txQueue.push(STX);
    for (const b of this.responseData) {
      this.txQueue.push(b);
      sum = (sum + b) & 0xFF;
    }
    sum = (sum + ETX) & 0xFF;
    const cks = (-sum) & 0xFF;
    this.txQueue.push(ETX, cks);
  }

  // Drain TX queue, delivering bytes to main CPU via SCI
  advance(cycles: number): void {
    if (this.txQueue.length === 0) return;
    this.txCycleCounter += cycles;
    while (this.txQueue.length > 0 && this.txCycleCounter >= EPSPDisplay.TX_BYTE_SPACING) {
      this.txCycleCounter -= EPSPDisplay.TX_BYTE_SPACING;
      const byte = this.txQueue.shift()!;
      if (this.onSendByte) {
        this.onSendByte(byte);
      }
    }
  }

  // Command dispatch
  private executeCommand(fnc: number, data: number[]): void {
    // Save character at cursor before execution (used for 0x92/0x98 response)
    if (this.cursorX < TEXT_COLS && this.cursorY < TEXT_ROWS) {
      this.savedCharUnderCursor = this.textBuffer[this.cursorY * TEXT_COLS + this.cursorX];
    } else {
      this.savedCharUnderCursor = 0x20;
    }
    // Debug: log character write commands with response info
    if (fnc === 0x92 || fnc === 0x98) {
      const ch = data[0] ?? -1;
      const chStr = ch >= 0x20 && ch < 0x7F ? `'${String.fromCharCode(ch)}'` : `0x${ch.toString(16).padStart(2, '0')}`;
      console.log(`[EPSP] FNC 0x${fnc.toString(16)}: write ${chStr} at (${this.cursorX},${this.cursorY}), old='${String.fromCharCode(this.savedCharUnderCursor)}' (0x${this.savedCharUnderCursor.toString(16).padStart(2, '0')})`);
    }
    switch (fnc) {
      case 0x84: this.cmdDeviceSelect(data); break;
      case 0x85: this.cmdCrtInit(); break;
      case 0x87: this.cmdSetVirtualScreen(data); break;
      case 0x88: this.cmdSetLineWidth(data); break;
      case 0x89: this.cmdGetScreenSize(); break;
      case 0x8C: this.cmdSetScrollMode(data); break;
      case 0x91: this.cmdClearToEndOfLine(data); break;
      case 0x92: this.cmdWriteCharacter(data); break;
      case 0x93: this.cmdSetDisplayMode(data); break;
      case 0x97: this.cmdReadScreenLine(data); break;
      case 0x98: this.cmdWriteCharacter(data); break;  // echo input character (same as 0x92)
      case 0xC0: this.cmdSetPhysicalPointer(data); break;
      case 0xC2: this.cmdSetCursorPosition(data); break;
      case 0xC5: this.cmdSetAttribute(data); break;
      case 0xC6: this.cmdSetCharAttribute(data); break;
      case 0x8F: this.cmdReadPixel(data); break;
      case 0xC7: this.cmdSetPixel(data); break;
      case 0xC8: this.cmdDrawLine(data); break;
      case 0xC9: this.cmdSetScrollRegion(data); break;
      case 0xCA: this.cmdClearGraphics(); break;
      case 0xD0: this.cmdSetCursorMode(data); break;
      case 0xD4: this.cmdSetDisplayAttribute(data); break;
      default:
        console.log(`[EPSP] Unimplemented FNC: 0x${fnc.toString(16).padStart(2, '0')} data=[${data.map(b => '0x' + b.toString(16).padStart(2, '0')).join(',')}]`);
        break;
    }
  }

  // --- Command handlers ---

  // 0x84: Device select
  private cmdDeviceSelect(data: number[]): void {
    // data[0] = device type (0x30 = CRT)
    // Just acknowledge — we are the CRT
  }

  // 0x85: CRT init — clear screen, reset cursor
  private cmdCrtInit(): void {
    this.textBuffer.fill(0x20);
    this.graphicsBuffer.fill(0);
    this.cursorX = 0;
    this.cursorY = 0;
    this.displayMode = 0;
    this.rowOrigin = 0;
    this.originDetected = false;
    this.hasWrittenChars = false;
    this.dirty = true;
  }

  // 0x87: Set virtual screen size and origin
  // Data: [cols-1, rows-1, origin_hi, origin_lo]
  // The origin is a 16-bit address from the LCD's VRAM perspective.
  // The low byte ($08EB = line_buf_ptr+2 low) is used by the ROM as the
  // virtual row in FNC 0xC2, so we use it directly as rowOrigin.
  private cmdSetVirtualScreen(data: number[]): void {
    if (data.length >= 2) {
      this.virtualCols = data[0] || TEXT_COLS;
      this.virtualRows = data[1] || TEXT_ROWS;
    }
    if (data.length >= 4) {
      this.rowOrigin = data[3];
      this.originDetected = true;
      console.log(`[EPSP] FNC 0x87: virtual screen ${data[0]+1}x${data[1]+1}, origin=0x${((data[2]<<8)|data[3]).toString(16).padStart(4,'0')}, rowOrigin=${this.rowOrigin}`);
    }
  }

  // 0x89: Get physical screen size (response data set by getResponseData)
  private cmdGetScreenSize(): void {
    // No-op here — response [cols-1, rows-1] is sent via the response state machine
  }

  // 0x92/0x98: Write character at cursor, advance cursor
  private cmdWriteCharacter(data: number[]): void {
    this.hasWrittenChars = true;
    for (const ch of data) {
      if (ch === 0x0D) {
        // Carriage return
        this.cursorX = 0;
      } else if (ch === 0x0A) {
        // Line feed
        this.cursorY++;
        if (this.cursorY >= TEXT_ROWS) {
          this.scrollUp();
          this.cursorY = TEXT_ROWS - 1;
        }
      } else if (ch === 0x08) {
        // Backspace — move left and erase character
        if (this.cursorX > 0) {
          this.cursorX--;
          this.textBuffer[this.cursorY * TEXT_COLS + this.cursorX] = 0x20;
        }
      } else if (ch === 0x1D) {
        // Cursor left — move without erasing
        if (this.cursorX > 0) this.cursorX--;
      } else if (ch === 0x1C) {
        // Cursor right
        if (this.cursorX < TEXT_COLS - 1) this.cursorX++;
      } else if (ch === 0x0B || ch === 0x1E) {
        // Cursor up
        if (this.cursorY > 0) this.cursorY--;
      } else if (ch === 0x1F) {
        // Cursor down
        if (this.cursorY < TEXT_ROWS - 1) this.cursorY++;
      } else if (ch === 0x0C) {
        // Form feed — clear screen
        this.textBuffer.fill(0x20);
        this.cursorX = 0;
        this.cursorY = 0;
      } else if (ch === 0x01 || ch === 0x16 || ch === 0x17) {
        // 0x01: cursor home/mode, 0x16: show cursor, 0x17: hide cursor
        // These are display control codes — no text buffer effect
      } else if (ch < 0x20) {
        // Other control characters — log for debugging
        console.log(`[EPSP] WriteChar: unhandled ctrl 0x${ch.toString(16).padStart(2, '0')} at (${this.cursorX},${this.cursorY})`);
      } else if (ch === 0x7F) {
        // DEL — erase character at cursor (write space, don't advance)
        if (this.cursorX < TEXT_COLS && this.cursorY < TEXT_ROWS) {
          this.textBuffer[this.cursorY * TEXT_COLS + this.cursorX] = 0x20;
        }
      } else {
        // Printable character (0x20-0x7E, 0x80-0xFF)
        if (this.cursorX < TEXT_COLS && this.cursorY < TEXT_ROWS) {
          this.textBuffer[this.cursorY * TEXT_COLS + this.cursorX] = ch;
        }
        this.cursorX++;
        if (this.cursorX >= TEXT_COLS) {
          this.cursorX = 0;
          this.cursorY++;
          if (this.cursorY >= TEXT_ROWS) {
            this.scrollUp();
            this.cursorY = TEXT_ROWS - 1;
          }
        }
      }
    }
    this.dirty = true;
  }

  // 0x93: Set display mode (0=text, 1=graphics mono, 2=graphics color)
  private cmdSetDisplayMode(data: number[]): void {
    if (data.length >= 1) {
      this.displayMode = data[0];
      // Reset origin tracking on mode switch — new SCREEN command starts fresh
      this.rowOrigin = 0;
      this.originDetected = false;
      this.hasWrittenChars = false;
      this.dirty = true;
    }
  }

  // 0xC0: Set physical pointer (for direct VRAM access)
  private cmdSetPhysicalPointer(data: number[]): void {
    if (data.length >= 2) {
      const addr = (data[0] << 8) | data[1];
      this.cursorX = addr % TEXT_COLS;
      this.cursorY = Math.floor(addr / TEXT_COLS);
    }
  }

  // 0xC2: Set cursor position (virtual coordinates)
  // The ROM always sends row = $08EB (a constant from boot) to mean "go to current
  // prompt line." On the LCD, circular VRAM + scrolling origin makes this work
  // automatically. On the CRT, we keep the cursor on its current row (the prompt row)
  // when we see the "home" row value, and apply static origin mapping otherwise.
  private cmdSetCursorPosition(data: number[]): void {
    if (data.length >= 2) {
      this.cursorX = data[0];

      // Auto-detect origin: the first FNC 0xC2 with row > 0 after characters
      // have been written reveals the ROM's $08EB value
      if (!this.originDetected && this.hasWrittenChars && data[1] > 0) {
        this.rowOrigin = data[1];
        this.originDetected = true;
        console.log(`[EPSP] FNC 0xC2: auto-detected rowOrigin=${this.rowOrigin}`);
      }

      if (this.originDetected && data[1] === this.rowOrigin) {
        // "Go home" — keep cursor on current row, just update column.
        // The ROM follows this with CR+LF to advance to the output line.
      } else if (this.originDetected) {
        // Non-home positioning — apply static origin mapping
        this.cursorY = (data[1] - this.rowOrigin + TEXT_ROWS) % TEXT_ROWS;
      } else {
        // Origin not yet detected — use raw value
        this.cursorY = data[1];
      }

      if (this.cursorX >= TEXT_COLS) this.cursorX = TEXT_COLS - 1;
      if (this.cursorY >= TEXT_ROWS) this.cursorY = TEXT_ROWS - 1;
    }
  }

  // 0x8F: Read pixel at position (POINT function)
  // Data: [X_hi, X_lo, Y_hi, Y_lo] — 4 bytes, 16-bit big-endian coords
  // Response: pixel color at that position
  private cmdReadPixel(data: number[]): void {
    if (data.length >= 4) {
      const x = (data[0] << 8) | data[1];
      const y = (data[2] << 8) | data[3];
      if (x < GFX_WIDTH && y < GFX_HEIGHT) {
        this.savedPixelColor = this.graphicsBuffer[y * GFX_WIDTH + x] & 0x07;
      } else {
        this.savedPixelColor = 0;
      }
    }
  }

  // 0xC7: Set pixel in graphics mode
  // Data: [X_hi, X_lo, Y_hi, Y_lo, color] — 5 bytes, 16-bit big-endian coords
  private cmdSetPixel(data: number[]): void {
    if (data.length >= 5) {
      const x = (data[0] << 8) | data[1];
      const y = (data[2] << 8) | data[3];
      const color = data[4];
      if (x < GFX_WIDTH && y < GFX_HEIGHT) {
        this.graphicsBuffer[y * GFX_WIDTH + x] = color & 0x07;
        this.dirty = true;
      }
    }
  }

  // 0xC8: Draw line (Bresenham's algorithm)
  // Data: [X0_hi, X0_lo, Y0_hi, Y0_lo, X1_hi, X1_lo, Y1_hi, Y1_lo, draw_mode] — 9 bytes
  private cmdDrawLine(data: number[]): void {
    if (data.length >= 9) {
      let x0 = (data[0] << 8) | data[1];
      let y0 = (data[2] << 8) | data[3];
      const x1 = (data[4] << 8) | data[5];
      const y1 = (data[6] << 8) | data[7];
      const color = data[8] & 0x07;
      // Bresenham
      const dx = Math.abs(x1 - x0);
      const dy = -Math.abs(y1 - y0);
      const sx = x0 < x1 ? 1 : -1;
      const sy = y0 < y1 ? 1 : -1;
      let err = dx + dy;
      for (;;) {
        if (x0 >= 0 && x0 < GFX_WIDTH && y0 >= 0 && y0 < GFX_HEIGHT) {
          this.graphicsBuffer[y0 * GFX_WIDTH + x0] = color;
        }
        if (x0 === x1 && y0 === y1) break;
        const e2 = 2 * err;
        if (e2 >= dy) { err += dy; x0 += sx; }
        if (e2 <= dx) { err += dx; y0 += sy; }
      }
      this.dirty = true;
    }
  }

  // 0xCA: Clear graphics screen
  private cmdClearGraphics(): void {
    this.graphicsBuffer.fill(0);
    this.dirty = true;
  }

  // 0x88: Set line width / right margin
  private cmdSetLineWidth(data: number[]): void {
    if (data.length >= 1) {
      // data[0] = line width (e.g., 0x27 = 39 → 40 columns)
      this.virtualCols = Math.min(data[0] + 1, TEXT_COLS);
    }
  }

  // 0x8C: Set scroll/wrap mode
  private cmdSetScrollMode(_data: number[]): void {
    // data[0] = mode flags — accept silently
  }

  // 0x91: Clear from cursor to end of line with fill character
  // Response: character that was at cursor before clearing
  private cmdClearToEndOfLine(data: number[]): void {
    const fill = data.length > 0 ? data[0] : 0x20;
    if (this.cursorY < TEXT_ROWS) {
      for (let x = this.cursorX; x < TEXT_COLS; x++) {
        this.textBuffer[this.cursorY * TEXT_COLS + x] = fill;
      }
      this.dirty = true;
    }
  }

  // 0x97: Read screen line (line read-back for BASIC input)
  // data[2] = byte count; response = text buffer contents starting from cursor row
  private cmdReadScreenLine(data: number[]): void {
    const byteCount = data.length >= 3 ? data[2] + 1 : TEXT_COLS;
    // Read from the beginning of the cursor's row
    const startPos = this.cursorY * TEXT_COLS;
    const result: number[] = [];
    for (let i = 0; i < byteCount; i++) {
      const pos = startPos + i;
      if (pos < this.textBuffer.length) {
        result.push(this.textBuffer[pos]);
      } else {
        result.push(0x20);  // pad with spaces beyond buffer
      }
    }
    console.log(`[EPSP] FNC 0x97: read ${byteCount} bytes from row ${this.cursorY}, first 40: [${result.slice(0, 40).map(b => b >= 0x20 && b < 0x7F ? String.fromCharCode(b) : '.').join('')}]`);
    this.savedScreenLine = result;
  }

  // 0xC5: Set display attribute / line parameter
  private cmdSetAttribute(_data: number[]): void {
    // data[0] = attribute value — accept silently
  }

  // 0xC6: Set character attribute
  private cmdSetCharAttribute(_data: number[]): void {
    // data[0] = character attribute — accept silently
  }

  // 0xC9: Set scroll region bottom
  private cmdSetScrollRegion(_data: number[]): void {
    // data[0] = bottom row (e.g., 0x17 = 23) — accept silently
  }

  // 0xD0: Set cursor mode
  private cmdSetCursorMode(data: number[]): void {
    if (data.length >= 1) {
      this.cursorVisible = (data[0] & 0x01) !== 0;
      this.cursorBlink = (data[0] & 0x02) !== 0;
    }
  }

  // 0xD4: Set display attribute (color/style)
  private cmdSetDisplayAttribute(_data: number[]): void {
    // data[0] = attribute (e.g., 0x07 = white/normal) — accept silently
  }

  // Scroll text buffer up by one line
  private scrollUp(): void {
    this.textBuffer.copyWithin(0, TEXT_COLS);
    this.textBuffer.fill(0x20, TEXT_COLS * (TEXT_ROWS - 1));
  }

  // --- Canvas rendering ---

  render(): void {
    if (!this.ctx || !this.imageData || !this.dirty) return;
    this.dirty = false;

    const pixels = this.imageData.data;

    // Render text as base layer, then overlay graphics pixels.
    // SCREEN 0,1 sends graphics commands to the CRT without changing display mode,
    // so we always composite both layers (text buffer is spaces when unused).
    this.renderText(pixels);
    this.overlayGraphics(pixels);

    this.ctx.putImageData(this.imageData, 0, 0);
  }

  private renderText(pixels: Uint8ClampedArray): void {
    // Green-on-black CRT: background #001100, text #33FF33
    const bgR = 0x00, bgG = 0x11, bgB = 0x00;
    const fgR = 0x33, fgG = 0xFF, fgB = 0x33;

    // Fill background
    for (let i = 0; i < CANVAS_W * CANVAS_H; i++) {
      const p = i * 4;
      pixels[p] = bgR; pixels[p + 1] = bgG; pixels[p + 2] = bgB; pixels[p + 3] = 0xFF;
    }

    // Render characters
    for (let row = 0; row < TEXT_ROWS; row++) {
      for (let col = 0; col < TEXT_COLS; col++) {
        const ch = this.textBuffer[row * TEXT_COLS + col];
        this.drawChar(pixels, col * 8, row * 8, ch, fgR, fgG, fgB);
      }
    }

    // Render cursor
    if (this.cursorVisible && this.cursorX < TEXT_COLS && this.cursorY < TEXT_ROWS) {
      const cx = this.cursorX * 8;
      const cy = this.cursorY * 8 + 7;  // bottom row of cell
      for (let x = 0; x < 6; x++) {
        const p = (cy * CANVAS_W + cx + x) * 4;
        pixels[p] = fgR; pixels[p + 1] = fgG; pixels[p + 2] = fgB;
      }
    }
  }

  private drawChar(pixels: Uint8ClampedArray, px: number, py: number,
                   ch: number, fgR: number, fgG: number, fgB: number): void {
    if (ch < 32 || ch > 126) return;
    const fontIdx = (ch - 32) * 5;

    for (let col = 0; col < 5; col++) {
      const colData = FONT_5x7[fontIdx + col];
      for (let row = 0; row < 7; row++) {
        if (colData & (1 << row)) {
          const x = px + col + 1;  // +1 for 1px left margin in 8px cell
          const y = py + row;
          if (x < CANVAS_W && y < CANVAS_H) {
            const p = (y * CANVAS_W + x) * 4;
            pixels[p] = fgR; pixels[p + 1] = fgG; pixels[p + 2] = fgB;
          }
        }
      }
    }
  }

  private overlayGraphics(pixels: Uint8ClampedArray): void {
    // Overlay non-zero graphics pixels on top of the text layer.
    // Scale: GFX_WIDTH=128 → CANVAS_W=320 (2.5x), GFX_HEIGHT=96 → CANVAS_H=192 (2x)
    // 3-bit RGB palette: R=bit2, G=bit1, B=bit0
    const palette: ([number, number, number] | null)[] = [
      null,                    // 0 = black (transparent, don't overlay)
      [0x33, 0x33, 0xFF],     // 1 = blue
      [0x33, 0xFF, 0x33],     // 2 = green
      [0x33, 0xFF, 0xFF],     // 3 = cyan
      [0xFF, 0x33, 0x33],     // 4 = red
      [0xFF, 0x33, 0xFF],     // 5 = magenta
      [0xFF, 0xFF, 0x33],     // 6 = yellow
      [0xFF, 0xFF, 0xFF],     // 7 = white
    ];

    for (let cy = 0; cy < CANVAS_H; cy++) {
      const gy = Math.floor(cy * GFX_HEIGHT / CANVAS_H);
      for (let cx = 0; cx < CANVAS_W; cx++) {
        const gx = Math.floor(cx * GFX_WIDTH / CANVAS_W);
        const colorIdx = this.graphicsBuffer[gy * GFX_WIDTH + gx] & 0x07;
        if (colorIdx !== 0) {
          const [r, g, b] = palette[colorIdx]!;
          const p = (cy * CANVAS_W + cx) * 4;
          pixels[p] = r; pixels[p + 1] = g; pixels[p + 2] = b; pixels[p + 3] = 0xFF;
        }
      }
    }
  }

  private renderGraphics(pixels: Uint8ClampedArray): void {
    // 3-bit RGB palette: R=bit2, G=bit1, B=bit0
    const palette: [number, number, number][] = [
      [0x00, 0x11, 0x00],  // 0 = black (dark bg)
      [0x33, 0x33, 0xFF],  // 1 = blue
      [0x33, 0xFF, 0x33],  // 2 = green
      [0x33, 0xFF, 0xFF],  // 3 = cyan
      [0xFF, 0x33, 0x33],  // 4 = red
      [0xFF, 0x33, 0xFF],  // 5 = magenta
      [0xFF, 0xFF, 0x33],  // 6 = yellow
      [0xFF, 0xFF, 0xFF],  // 7 = white
    ];

    // Scale graphics buffer to canvas
    // GFX_WIDTH=128, GFX_HEIGHT=96, CANVAS_W=320, CANVAS_H=192
    // Scale: 2.5x horizontal, 2x vertical — use nearest-neighbor
    for (let cy = 0; cy < CANVAS_H; cy++) {
      const gy = Math.floor(cy * GFX_HEIGHT / CANVAS_H);
      for (let cx = 0; cx < CANVAS_W; cx++) {
        const gx = Math.floor(cx * GFX_WIDTH / CANVAS_W);
        const colorIdx = this.graphicsBuffer[gy * GFX_WIDTH + gx] & 0x07;
        const [r, g, b] = palette[colorIdx];
        const p = (cy * CANVAS_W + cx) * 4;
        pixels[p] = r; pixels[p + 1] = g; pixels[p + 2] = b; pixels[p + 3] = 0xFF;
      }
    }
  }

  // --- State persistence ---

  saveState(): object {
    return {
      textBuffer: Array.from(this.textBuffer),
      cursorX: this.cursorX,
      cursorY: this.cursorY,
      cursorVisible: this.cursorVisible,
      displayMode: this.displayMode,
      rowOrigin: this.rowOrigin,
      originDetected: this.originDetected,
    };
  }

  loadState(s: any): void {
    if (s.textBuffer) {
      const arr = s.textBuffer;
      for (let i = 0; i < arr.length && i < this.textBuffer.length; i++) {
        this.textBuffer[i] = arr[i];
      }
    }
    this.cursorX = s.cursorX || 0;
    this.cursorY = s.cursorY || 0;
    this.cursorVisible = s.cursorVisible !== undefined ? s.cursorVisible : true;
    this.displayMode = s.displayMode || 0;
    this.rowOrigin = s.rowOrigin || 0;
    this.originDetected = s.originDetected || false;
    this.hasWrittenChars = true;  // assume chars were written before save
    this.dirty = true;
    // Reset protocol state on load
    this.state = EPSPState.IDLE;
    this.txQueue = [];
    this.txCycleCounter = 0;
    this.responseFnc = 0;
    this.responseData = [];
  }
}
