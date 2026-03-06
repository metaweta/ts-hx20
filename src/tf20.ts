// TF-20 Floppy Disk Emulator
// Emulates the Epson TF-20 dual floppy disk drive unit via EPSP protocol
// Serves embedded BOOT80.SYS and DBASIC.SYS on boot, then provides
// in-memory CP/M filesystem for SAVE/LOAD/FILES/KILL.

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
const DID_TF20_MIN = 0x31;
const DID_TF20_MAX = 0x34;

// BDOS function codes
const FN_DISK_RESET    = 0x0D;
const FN_DISK_SELECT   = 0x0E;
const FN_OPEN_FILE     = 0x0F;
const FN_CLOSE_FILE    = 0x10;
const FN_FIND_FIRST    = 0x11;
const FN_FIND_NEXT     = 0x12;
const FN_DELETE_FILE   = 0x13;
const FN_CREATE_FILE   = 0x16;
const FN_RANDOM_READ   = 0x21;
const FN_RANDOM_WRITE  = 0x22;
const FN_COMPUTE_FS    = 0x23;
const FN_DISK_BOOT     = 0x80;
const FN_LOAD_OPEN     = 0x81;
const FN_READ_BLOCK    = 0x83;

const enum TF20State {
  IDLE,
  ENQUIRY,
  WAIT_SOH,
  HEADER,
  DATA_STX,
  DATA_BYTES,
  DATA_ETX,
  DATA_CKS,
  RESPONSE_PENDING,
  RESPONSE_WAIT_HEADER_ACK,
  RESPONSE_WAIT_DATA_ACK,
}

// Embedded BOOT80.SYS (256 bytes) — HD6301 boot loader
const BOOT80_B64 = '/gSy/wkyzgQ1xhG9BB5sBSdp/ASyowYlEV83NrME/iUJ3Y+DAnMlApOeJWv8BaLdyvME/t3G3I/9BaK9vLF6ANXexN/Z/AknNzZPX/0JJs4ERsYFjUqmhyYhzgko34/ej4wJqCfppgAI34/exKcACN/EOAk8Jug4OG4AltUnHtzK/QWi3sjfyt7Z38a9vLG9t0/OBFkgA84ESr2Rfn6zgzzOCSHfjzi9s6TOCSGGAb3/cCXHJsU5ADEggQ1EQkFTSUMgIFNZUwIAMSCDAU9VVCBPRiBNRU1PUlkNCkNBTiBOT1QgTE9BRA0KAB7rDhbNBQCAxKztoKMAlFQAeQG0Ew==';

// Embedded DBASIC.SYS — Disk BASIC V-1.0 extension
// PRL format: code (4158 bytes, base $6000) + relocation bitmap (520 bytes) + 59 zero padding
const DBASIC_CODE_SIZE = 4158;  // $103E bytes of code, assembled at base page $60
const DBASIC_BASE_PAGE = 0x60;  // Code references $6000-$70xx
const DBASIC_B64 = '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';

function base64ToBytes(b64: string): Uint8Array {
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = '';
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  return btoa(binary);
}

export class TF20 {
  // In-memory filesystem: two drives (A: and B:), each "FILENAME.EXT" → data
  private drives = [new Map<string, Uint8Array>(), new Map<string, Uint8Array>()];

  // Current operation state
  private currentFilename = '';
  private currentDriveIdx = 0;  // 0=A, 1=B
  private block = 0;
  private blocks = 0;
  private lastBlockBytes = 128;

  // Search state
  private searchResults: string[] = [];
  private searchIndex = 0;
  private searchUnit = 1;

  // EPSP protocol state machine
  private state = TF20State.IDLE;
  private enquiryBuf: number[] = [];
  private headerBuf: number[] = [];
  private dataBuf: number[] = [];
  private fnc = 0;
  private siz = 0;
  private dataChecksum = 0;
  private myDid = 0x31;

  // TX queue
  private txQueue: number[] = [];
  private txCycleCounter = 0;
  private static readonly TX_BYTE_SPACING = 200;

  // Response state
  private responseFnc = 0;
  private responseData: number[] = [];

  // Boot binaries
  private boot80: Uint8Array;
  private dbasicRaw: Uint8Array;           // Original code section (un-relocated)
  private dbasicBitmap: Uint8Array;        // PRL relocation bitmap
  private dbasicRelocated: Uint8Array | null = null;  // Relocated copy for current boot

  // Callbacks
  onSendByte: ((data: number) => void) | null = null;
  onFileChange: (() => void) | null = null;
  readMemory: ((addr: number) => number) | null = null;  // Read HX-20 main CPU memory

  constructor() {
    this.boot80 = base64ToBytes(BOOT80_B64);
    const full = base64ToBytes(DBASIC_B64);
    this.dbasicRaw = full.slice(0, DBASIC_CODE_SIZE);
    this.dbasicBitmap = full.slice(DBASIC_CODE_SIZE, DBASIC_CODE_SIZE + Math.ceil(DBASIC_CODE_SIZE / 8));

    // Patch DBASIC ROM bug: at $6878, ORAA #$37 ($8A) should be ADDA #$37 ($8B).
    // The OR merges the single-bit difference between device codes $0A (A:) and $0B (B:),
    // making both drives produce the same FCB drive byte ($3F). ADDA correctly yields
    // $41 (A:) and $42 (B:), which then map to drive codes 1 and 2 downstream.
    const patchOffset = 0x878; // $6878 - $6000
    if (this.dbasicRaw[patchOffset] === 0x8A) {
      this.dbasicRaw[patchOffset] = 0x8B;  // ORAA → ADDA
    }

    this.loadFromStorage();
  }

  reset(): void {
    this.state = TF20State.IDLE;
    this.enquiryBuf = [];
    this.headerBuf = [];
    this.dataBuf = [];
    this.fnc = 0;
    this.siz = 0;
    this.txQueue = [];
    this.txCycleCounter = 0;
    this.responseFnc = 0;
    this.responseData = [];
    this.currentFilename = '';
    this.currentDriveIdx = 0;
    this.block = 0;
    this.blocks = 0;
    this.lastBlockBytes = 128;
    this.searchResults = [];
    this.searchIndex = 0;
  }

  // --- EPSP state machine (same pattern as EPSPDisplay) ---

  recvByte(byte: number): void {
    switch (this.state) {
      case TF20State.IDLE:
        if (byte === EOT) {
          this.enquiryBuf = [];
          this.state = TF20State.ENQUIRY;
        }
        break;

      case TF20State.ENQUIRY:
        this.enquiryBuf.push(byte);
        if (this.enquiryBuf.length === 4) {
          const did = this.enquiryBuf[1];
          const enq = this.enquiryBuf[3];
          if (did >= DID_TF20_MIN && did <= DID_TF20_MAX && enq === ENQ) {
            this.myDid = did;
            this.queueByte(ACK);
            this.state = TF20State.WAIT_SOH;
          } else {
            this.state = TF20State.IDLE;
          }
        }
        break;

      case TF20State.WAIT_SOH:
        if (byte === SOH) {
          this.headerBuf = [SOH];
          this.state = TF20State.HEADER;
        } else if (byte === EOT) {
          this.enquiryBuf = [];
          this.state = TF20State.ENQUIRY;
        }
        break;

      case TF20State.HEADER:
        this.headerBuf.push(byte);
        if (this.headerBuf.length === 7) {
          let sum = 0;
          for (const b of this.headerBuf) sum += b;
          if ((sum & 0xFF) === 0) {
            this.fnc = this.headerBuf[4];
            this.siz = this.headerBuf[5];
            this.queueByte(ACK);
            this.dataBuf = [];
            this.dataChecksum = 0;
            this.state = TF20State.DATA_STX;
          } else {
            this.queueByte(NAK);
            this.state = TF20State.IDLE;
          }
        }
        break;

      case TF20State.DATA_STX:
        if (byte === STX) {
          this.dataChecksum = STX;
          this.state = TF20State.DATA_BYTES;
        } else {
          this.state = TF20State.IDLE;
        }
        break;

      case TF20State.DATA_BYTES:
        this.dataBuf.push(byte);
        this.dataChecksum = (this.dataChecksum + byte) & 0xFF;
        if (this.dataBuf.length >= this.siz + 1) {
          this.state = TF20State.DATA_ETX;
        }
        break;

      case TF20State.DATA_ETX:
        if (byte === ETX) {
          this.dataChecksum = (this.dataChecksum + ETX) & 0xFF;
          this.state = TF20State.DATA_CKS;
        } else {
          this.state = TF20State.IDLE;
        }
        break;

      case TF20State.DATA_CKS:
        if (((this.dataChecksum + byte) & 0xFF) === 0) {
          this.queueByte(ACK);
          this.responseData = this.executeFunction(this.fnc, this.dataBuf);
          this.responseFnc = this.fnc;
          this.state = TF20State.RESPONSE_PENDING;
        } else {
          this.queueByte(NAK);
          this.state = TF20State.IDLE;
        }
        break;

      case TF20State.RESPONSE_PENDING:
        if (byte === EOT) {
          this.queueResponseHeader();
          this.state = TF20State.RESPONSE_WAIT_HEADER_ACK;
        }
        break;

      case TF20State.RESPONSE_WAIT_HEADER_ACK:
        if (byte === ACK) {
          this.queueResponseDataBlock();
          this.state = TF20State.RESPONSE_WAIT_DATA_ACK;
        } else if (byte === NAK) {
          this.queueResponseHeader();
        }
        break;

      case TF20State.RESPONSE_WAIT_DATA_ACK:
        if (byte === ACK) {
          this.queueByte(0x00); // session close byte
          this.state = TF20State.IDLE;
        } else if (byte === NAK) {
          this.queueResponseDataBlock();
        }
        break;
    }
  }

  private queueByte(byte: number): void {
    this.txQueue.push(byte);
  }

  private queueResponseHeader(): void {
    const siz = this.responseData.length - 1;
    const hdrBytes = [SOH, 0x00, DID_HX20, this.myDid, this.responseFnc, siz];
    let sum = 0;
    for (const b of hdrBytes) sum += b;
    const hcs = (-sum) & 0xFF;
    for (const b of hdrBytes) this.txQueue.push(b);
    this.txQueue.push(hcs);
  }

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

  advance(cycles: number): void {
    if (this.txQueue.length === 0) return;
    this.txCycleCounter += cycles;
    while (this.txQueue.length > 0 && this.txCycleCounter >= TF20.TX_BYTE_SPACING) {
      this.txCycleCounter -= TF20.TX_BYTE_SPACING;
      const byte = this.txQueue.shift()!;
      if (this.onSendByte) this.onSendByte(byte);
    }
  }

  // --- Function dispatch ---

  private executeFunction(fnc: number, data: number[]): number[] {
    switch (fnc) {
      case FN_DISK_RESET:   return [0x00];
      case FN_DISK_SELECT:  return [0x00];
      case FN_OPEN_FILE:    return this.fnOpenFile(data);
      case FN_CLOSE_FILE:   return [0x00];
      case FN_FIND_FIRST:   return this.fnFindFirst(data);
      case FN_FIND_NEXT:    return this.fnFindNext();
      case FN_DELETE_FILE:  return this.fnDeleteFile(data);
      case FN_CREATE_FILE:  return this.fnCreateFile(data);
      case FN_RANDOM_READ:  return this.fnRandomRead();
      case FN_RANDOM_WRITE: return this.fnRandomWrite(data);
      case FN_COMPUTE_FS:   return this.fnComputeFS();
      case FN_DISK_BOOT:    return this.fnDiskBoot();
      case FN_LOAD_OPEN:    return this.fnLoadOpen(data);
      case FN_READ_BLOCK:   return this.fnReadBlock();
      default:
        return [0x00];
    }
  }

  // --- Boot protocol ---

  private fnDiskBoot(): number[] {
    // Response: [return_code, boot80[0..254]] = 256 bytes, SIZ=0xFF
    const resp = new Array(256);
    resp[0] = 0x00; // success
    for (let i = 0; i < 255; i++) {
      resp[i + 1] = i < this.boot80.length ? this.boot80[i] : 0;
    }
    return resp;
  }

  private fnLoadOpen(data: number[]): number[] {
    // Request: filename(8) + ext(3) + reloc(1) + addr(1)
    // Response: [return_code, size_hi, size_lo] = 3 bytes, SIZ=0x02
    const size = DBASIC_CODE_SIZE;

    // Perform page relocation: read MEMTOP from HX-20 and compute target page
    this.dbasicRelocated = new Uint8Array(this.dbasicRaw);  // copy
    if (this.readMemory) {
      const memtopHi = this.readMemory(0x04B2);
      const memtopLo = this.readMemory(0x04B3);
      const memtop = (memtopHi << 8) | memtopLo;
      const loadAddr = (memtop - size) & 0xFF00;  // page-aligned down
      const targetPage = (loadAddr >> 8) & 0xFF;
      const delta = (targetPage - DBASIC_BASE_PAGE) & 0xFF;

      // Apply relocation: for each set bit in bitmap, add delta to the code byte
      for (let i = 0; i < this.dbasicBitmap.length; i++) {
        const bmpByte = this.dbasicBitmap[i];
        if (bmpByte === 0) continue;  // fast skip
        for (let bit = 7; bit >= 0; bit--) {
          if (bmpByte & (1 << bit)) {
            const codeOffset = i * 8 + (7 - bit);
            if (codeOffset < DBASIC_CODE_SIZE) {
              this.dbasicRelocated[codeOffset] = (this.dbasicRelocated[codeOffset] + delta) & 0xFF;
            }
          }
        }
      }
    } else {
    }

    this.block = 0;
    this.blocks = Math.ceil(size / 128);
    return [0x00, (size >> 8) & 0xFF, size & 0xFF];
  }

  private fnReadBlock(): number[] {
    // Response: [return_code, block_num, data(128), trailing_status] = 131 bytes, SIZ=0x82
    const src = this.dbasicRelocated || this.dbasicRaw;
    const offset = this.block * 128;
    const resp: number[] = [0x00, 1 + this.block];
    for (let i = 0; i < 128; i++) {
      const idx = offset + i;
      resp.push(idx < src.length ? src[idx] : 0);
    }
    resp.push(0x00); // trailing status
    this.block++;
    if (this.block >= this.blocks) {
      this.block = 0;
      this.blocks = 0;
    }
    return resp;
  }

  // --- File operations ---

  /** Map EPSP drive code to array index: 0=default→0, 1=A→0, 2=B→1 */
  private driveIdx(unit: number): number {
    return unit === 2 ? 1 : 0;
  }

  private driveLetter(idx: number): string {
    return idx === 1 ? 'B' : 'A';
  }

  private fnOpenFile(data: number[]): number[] {
    // Request: FCB_hi(1) + FCB_lo(1) + drive(1) + filename(8) + ext(3) + extent(1)
    // Response: [0x00] found, [0xFF] not found — SIZ=0x00
    const unit = data.length >= 3 ? data[2] : 0;
    this.currentDriveIdx = this.driveIdx(unit);
    const drive = this.drives[this.currentDriveIdx];
    const name = this.parseFilenameFromFCB(data);
    this.currentFilename = name;
    return [drive.has(name) ? 0x00 : 0xFF];
  }

  private fnCreateFile(_data: number[]): number[] {
    // Uses currentFilename/currentDriveIdx set by previous OPEN_FILE
    // Response: [0x00] — SIZ=0x00
    const drive = this.drives[this.currentDriveIdx];
    if (!drive.has(this.currentFilename)) {
      drive.set(this.currentFilename, new Uint8Array(0));
      this.saveToStorage();
      if (this.onFileChange) this.onFileChange();
    }
    return [0x00];
  }

  private fnDeleteFile(data: number[]): number[] {
    // Request: drive(1) + filename(8) + ext(3) = 12 bytes (same format as FIND_FIRST)
    // Response: [0x00] deleted, [0xFF] not found — SIZ=0x00
    const idx = this.driveIdx(data[0] || 0);
    const drv = this.drives[idx];
    const pattern = this.extractName(data, 1, 8) + '.' + this.extractName(data, 9, 3);
    const toDelete: string[] = [];
    for (const name of drv.keys()) {
      if (this.matchesPattern(name, pattern)) {
        toDelete.push(name);
      }
    }
    if (toDelete.length > 0) {
      for (const name of toDelete) drv.delete(name);
      this.saveToStorage();
      if (this.onFileChange) this.onFileChange();
      return [0x00];
    }
    return [0xFF];
  }

  private fnComputeFS(): number[] {
    // Response: [return_code, blocks_hi, blocks_lo, 0, 0, 0] = 6 bytes, SIZ=0x05
    const drive = this.drives[this.currentDriveIdx];
    const fileData = drive.get(this.currentFilename);
    if (fileData) {
      const size = fileData.length;
      this.blocks = Math.ceil(size / 128) || 0;
      const fullBlocks = Math.floor(size / 128);
      this.lastBlockBytes = size - fullBlocks * 128;
      if (this.lastBlockBytes === 0) this.lastBlockBytes = 128;
      this.block = 0;
      return [0x00, 0x00, this.blocks & 0xFF, 0x00, 0x00, 0x00];
    }
    // New/empty file
    this.blocks = 0;
    this.block = 0;
    this.lastBlockBytes = 128;
    return [0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
  }

  private fnRandomRead(): number[] {
    // Response: [return_code, block, data(128), trailing_status] = 131 bytes, SIZ=0x82
    const drive = this.drives[this.currentDriveIdx];
    const fileData = drive.get(this.currentFilename);
    if (!fileData) {
      return [0xFF]; // error — short response
    }
    const offset = this.block * 128;
    const resp: number[] = [0x00, this.block];
    for (let i = 0; i < 128; i++) {
      const idx = offset + i;
      if (this.block === this.blocks - 1 && i >= this.lastBlockBytes) {
        resp.push(0x00); // pad partial last block
      } else {
        resp.push(idx < fileData.length ? fileData[idx] : 0x00);
      }
    }
    resp.push(0x00); // trailing status
    this.block++;
    if (this.block >= this.blocks) {
      this.block = 0;
      this.blocks = 0;
    }
    return resp;
  }

  private fnRandomWrite(data: number[]): number[] {
    // Request: record_info(2) + data(128) = 130 bytes
    // Response: [return_code, block+1, 0x00] = 3 bytes, SIZ=0x02
    const drive = this.drives[this.currentDriveIdx];
    const writeData = data.slice(2, 130);
    const fileData = drive.get(this.currentFilename) || new Uint8Array(0);

    // Extend file if needed
    const offset = this.block * 128;
    const needed = offset + 128;
    let newData: Uint8Array;
    if (needed > fileData.length) {
      newData = new Uint8Array(needed);
      newData.set(fileData);
    } else {
      newData = new Uint8Array(fileData);
    }

    // Write the 128-byte record
    for (let i = 0; i < 128 && i < writeData.length; i++) {
      newData[offset + i] = writeData[i];
    }

    drive.set(this.currentFilename, newData);
    this.block++;
    this.saveToStorage();
    if (this.onFileChange) this.onFileChange();
    return [0x00, this.block, 0x00];
  }

  private fnFindFirst(data: number[]): number[] {
    // Request: drive(1) + filename_pattern(8) + ext_pattern(3) = 12 bytes
    // Response: [rc, unit, name(8), ext(3), zeros(24)] = 37 bytes, SIZ=0x24
    const unit = data[0] || 1;
    this.searchUnit = unit;
    const drv = this.drives[this.driveIdx(unit)];

    // Build search pattern from request
    const pattern = this.extractName(data, 1, 8) + '.' + this.extractName(data, 9, 3);

    // Find matching files on the requested drive
    this.searchResults = [];
    for (const name of drv.keys()) {
      if (this.matchesPattern(name, pattern)) {
        this.searchResults.push(name);
      }
    }
    this.searchIndex = 0;

    return this.buildSearchResponse();
  }

  private fnFindNext(): number[] {
    // Response: same format as FIND_FIRST — 37 bytes, SIZ=0x24
    return this.buildSearchResponse();
  }

  private buildSearchResponse(): number[] {
    const resp = new Array(37).fill(0);
    if (this.searchIndex < this.searchResults.length) {
      const name = this.searchResults[this.searchIndex++];
      resp[0] = 0x00; // found
      resp[1] = this.searchUnit;
      const parts = this.splitFilename(name);
      for (let i = 0; i < 8; i++) resp[2 + i] = i < parts.name.length ? parts.name.charCodeAt(i) : 0x20;
      for (let i = 0; i < 3; i++) resp[10 + i] = i < parts.ext.length ? parts.ext.charCodeAt(i) : 0x20;
      // bytes 13-36 are zeros (already filled)
    } else {
      resp[0] = 0xFF; // not found
      resp[1] = this.searchUnit;
      for (let i = 2; i < 13; i++) resp[i] = 0x20; // spaces for name+ext
      // bytes 13-36 are zeros
    }
    return resp;
  }

  // --- Filename utilities ---

  /** Parse "FILENAME.EXT" from FCB-format request data */
  private parseFilenameFromFCB(data: number[]): string {
    // FCB format: [FCB_hi, FCB_lo, drive, name(8), ext(3), ...]
    if (data.length < 14) {
      // Short data — try parsing from offset 0
      return this.extractName(data, 0, 8) + '.' + this.extractName(data, 8, 3);
    }
    return this.extractName(data, 3, 8) + '.' + this.extractName(data, 11, 3);
  }

  /** Extract a space-padded name field, trimming trailing spaces */
  private extractName(data: number[], offset: number, length: number): string {
    let name = '';
    for (let i = 0; i < length; i++) {
      const ch = data[offset + i];
      if (ch !== undefined && ch !== 0x20 && ch > 0) {
        name += String.fromCharCode(ch & 0x7F);
      }
    }
    return name.toUpperCase();
  }

  /** Split "FILENAME.EXT" into { name, ext } */
  private splitFilename(fullname: string): { name: string; ext: string } {
    const dot = fullname.lastIndexOf('.');
    if (dot >= 0) {
      return { name: fullname.substring(0, dot), ext: fullname.substring(dot + 1) };
    }
    return { name: fullname, ext: '' };
  }

  /** Match filename against CP/M pattern (? = any char) */
  private matchesPattern(filename: string, pattern: string): boolean {
    const fp = this.splitFilename(filename);
    const pp = this.splitFilename(pattern);

    // Pad both to fixed width for comparison
    const fn = fp.name.padEnd(8, ' ');
    const fe = fp.ext.padEnd(3, ' ');
    const pn = pp.name.padEnd(8, ' ');
    const pe = pp.ext.padEnd(3, ' ');

    // Empty pattern name means match all
    if (pp.name === '' && pp.ext === '') return true;

    for (let i = 0; i < 8; i++) {
      if (pn[i] !== '?' && pn[i] !== fn[i]) return false;
    }
    for (let i = 0; i < 3; i++) {
      if (pe[i] !== '?' && pe[i] !== fe[i]) return false;
    }
    return true;
  }

  // --- localStorage persistence ---

  private serializeDrive(drive: Map<string, Uint8Array>): Record<string, string> {
    const obj: Record<string, string> = {};
    for (const [name, data] of drive) obj[name] = bytesToBase64(data);
    return obj;
  }

  private deserializeDrive(obj: Record<string, string>, drive: Map<string, Uint8Array>, merge: boolean): void {
    if (!merge) drive.clear();
    for (const [name, b64] of Object.entries(obj)) {
      drive.set(name, base64ToBytes(b64 as string));
    }
  }

  private saveToStorage(): void {
    try {
      localStorage.setItem('tf20-files', JSON.stringify({
        A: this.serializeDrive(this.drives[0]),
        B: this.serializeDrive(this.drives[1]),
      }));
    } catch (e) {
      console.warn('[TF20] Failed to save to localStorage:', e);
    }
  }

  private loadFromStorage(merge = false): void {
    try {
      const json = localStorage.getItem('tf20-files');
      if (json) {
        const obj = JSON.parse(json);
        if (obj.A || obj.B) {
          // New two-drive format
          if (obj.A) this.deserializeDrive(obj.A, this.drives[0], merge);
          if (obj.B) this.deserializeDrive(obj.B, this.drives[1], merge);
        } else {
          // Old single-drive format — migrate all files to A:
          this.deserializeDrive(obj, this.drives[0], merge);
        }
      }
    } catch (e) {
      console.warn('[TF20] Failed to load from localStorage:', e);
    }
  }

  // --- Public API for UI ---

  getFileList(): { name: string; size: number; drive: string }[] {
    const list: { name: string; size: number; drive: string }[] = [];
    for (const [idx, drv] of this.drives.entries()) {
      const letter = this.driveLetter(idx);
      for (const [name, data] of drv) {
        list.push({ name, size: data.length, drive: letter });
      }
    }
    return list.sort((a, b) => a.drive.localeCompare(b.drive) || a.name.localeCompare(b.name));
  }

  deleteFileByName(name: string, drive = 'A'): void {
    this.drives[drive === 'B' ? 1 : 0].delete(name);
    this.saveToStorage();
    if (this.onFileChange) this.onFileChange();
  }

  importFile(name: string, data: Uint8Array, drive = 'A'): void {
    const normalized = this.normalizeFilename(name);
    this.drives[drive === 'B' ? 1 : 0].set(normalized, data);
    this.saveToStorage();
    if (this.onFileChange) this.onFileChange();
  }

  exportFile(name: string, drive = 'A'): Uint8Array | null {
    return this.drives[drive === 'B' ? 1 : 0].get(name) || null;
  }

  formatDisk(drive?: string): void {
    if (drive === 'A' || drive === undefined) this.drives[0].clear();
    if (drive === 'B' || drive === undefined) this.drives[1].clear();
    this.saveToStorage();
    if (this.onFileChange) this.onFileChange();
  }

  /** Normalize a host filename to CP/M 8.3 uppercase format */
  private normalizeFilename(name: string): string {
    const parts = name.toUpperCase().split('.');
    const base = (parts[0] || 'FILE').replace(/[^A-Z0-9]/g, '').substring(0, 8);
    const ext = (parts[1] || 'BAS').replace(/[^A-Z0-9]/g, '').substring(0, 3);
    return base + '.' + ext;
  }

  // --- State persistence ---

  saveState(): object {
    return {
      drives: [
        this.serializeDrive(this.drives[0]),
        this.serializeDrive(this.drives[1]),
      ],
      currentFilename: this.currentFilename,
      currentDriveIdx: this.currentDriveIdx,
      block: this.block,
      blocks: this.blocks,
    };
  }

  loadState(s: any): void {
    if (s.drives) {
      // New two-drive format
      this.deserializeDrive(s.drives[0] || {}, this.drives[0], false);
      this.deserializeDrive(s.drives[1] || {}, this.drives[1], false);
      this.loadFromStorage(true);
    } else if (s.files) {
      // Old single-drive format — migrate to A:
      this.deserializeDrive(s.files, this.drives[0], false);
      this.drives[1].clear();
      this.loadFromStorage(true);
    }
    this.currentFilename = s.currentFilename || '';
    this.currentDriveIdx = s.currentDriveIdx || 0;
    this.block = s.block || 0;
    this.blocks = s.blocks || 0;
    // Reset protocol state on load
    this.state = TF20State.IDLE;
    this.txQueue = [];
    this.txCycleCounter = 0;
    this.responseFnc = 0;
    this.responseData = [];
  }
}
