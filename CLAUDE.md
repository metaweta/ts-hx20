# HX-20 Emulator — Cassette SAVE/LOAD Work In Progress

## Current Task: Fix LOAD "CAS1:" — Data Corruption

SAVE "CAS1:" now records FSK data and creates tape entries. LOAD finds the tape and completes without error, but the loaded data is corrupt (LIST shows wrong program). The FSK decode/playback path needs debugging.

### Two Cassette Interfaces

**CAS0: Internal Microcassette**
- Motor: controlled via cassette controller IC (bit-bang P43/P44, ack P46, status P40)
- FSK write: output compare on P21 (OLVL toggle), recorded by setOCOutput()
- FSK read: P32 (Port 3 bit 2)
- Cassette detect: P20 (Port 2 bit 0) — currently hardcoded to 1 (present)
- Slave command: 0x64 → FCE8 (mode $81=0) — uses FDF6/FE00 FSK encode

**CAS1: External Cassette**
- Motor: P30 (Port 3 bit 0) LOW = on — wired to cassette.setMotor()
- FSK write: **P33** (Port 3 bit 3), toggled by F709 subroutine, timed by OCR — recorded by setWriteData()
- FSK read: P32 (Port 3 bit 2)
- Slave command: **0x24** (group 2, sub 4) → **F643** — NOT 0x6A/FCDC as previously thought
- Motor OFF between blocks; multi-segment recording appends to existing tape

### What Works
- Boot sequence completes with real slave CPU (FakeSecondary removed)
- Keyboard and LCD work through slave CPU
- SCI serial between CPUs: proper TX timing (160-cycle delay), SCI overrun model
- SIO bus: sel=7 dispatches bytes from master → slave via slaveCPU.serialRecv()
- Cassette controller bit-bang protocol: P43/P44 commands, P46 ack, P40 motor status
- CAS1: SAVE completes without IO Error, tape entry created in library
- CAS1: LOAD finds tape entry, completes without IO Error
- P30 motor control wired → cassette.setMotor()
- P33 FSK output wired → cassette.setWriteData()
- Multi-segment recording: motor stop/start between blocks appends data
- Tape library with localStorage persistence

### What's Broken
- **CAS1: data corruption**: SAVE "CAS1:HI" + LOAD "CAS1:HI" completes but LIST shows wrong data. FSK recording or playback is incorrect — either the P33 transitions aren't capturing the right timing, or the P32 playback isn't reproducing them correctly.
- **CAS0: IO Error**: SAVE "CAS0:TEST" returns IO Error (lower priority, different code path)

### CAS1: SAVE Protocol — Actual Flow (from console trace)

The master does NOT use the SIO bus for CAS1:. Everything goes via SCI.

**Slave command 0x24 (F643) — the REAL CAS1: SAVE handler:**
```
F643: CLRA; STAA $87        ; mode = 0
F646: BSR $F613             ; ACK + motor ON (P30 LOW via AIM #$e6, $06)
F64C: LDAA #$21; JSR $F10A  ; double transact → $b5/$b6 (tape position?)
F653: LDAA #$21; JSR $F10A  ; double transact → $b7/$b8 (byte count)
F65A: init timer from FRC → OCR
F660: LDX #$0271            ; leader count = 625
F66F-F67A: Leader loop — 625×$FF via F709 (FSK encode on P33)
F682-F695: Sync — 9×$00, 0x00/0xFF/0xAA marker, clear CRC
F69B-F6CE: Data loop — poll RDRF+P40+OCF, ACK with 0x21, FSK-encode via F70E
F6D2-F6DF: Trailer — CRC×2, 0xAA, 0x00
F6E1-F6FA: Trailer leader — 625×$FF
F6FC-F708: Clear P33, conditional motor OFF, CLC RTS (success)
```

**F709/F70E: FSK Encode (P33 toggle, NOT P21)**
```
F709: entry with CRC update ($84=0xFF)
F70E: entry without CRC update ($84=0x00)
F712: store byte to $82, 8 bits per byte
F71B: load FSK timing: $9F/$A0 (0-bit) or $9D/$9E (1-bit)
F726: add timing to OCR ($0B)
F72C: wait OCF (BITA #$40, $08)
F730: AIM #$f7, $06 → P33 LOW (clear bit 3 of Port 3)
F735: add second half-cycle timing to OCR
F74D: wait OCF again
F752: OIM #$08, $06 → P33 HIGH (set bit 3 of Port 3)
F755: DEC bit counter, loop for 8 bits
```

**Console trace summary (SAVE "CAS1:HI"):**
- 7 slave dispatches: 6× cmd 0x24, 1× cmd 0x23 (cleanup/motor OFF)
- 6 IRQ block completions (EE81)
- All ACKs pass (expected=0x21, got=0x21)
- Motor OFF/ON between blocks 2→3 (single gap)
- Final cmd 0x23 turns motor OFF, cleanup complete

### Slave Dispatch Table — Hierarchical (F0AA)

Dispatch at F061 uses upper nibble as group index, lower nibble as sub-command:
```
Group 0 (0x0_): F0E9    Group 5 (0x5_): F9EB
Group 1 (0x1_): F22E    Group 6 (0x6_): FA18
Group 2 (0x2_): F5E2    Group 7 (0x7_): FA39
Group 3 (0x3_): F472    Group 8 (0x8_): F1E9
Group 4 (0x4_): F8C9
```

**Group 2 sub-commands (F5E2):**
- 0x20→F5FB, 0x21→F624, 0x22→F613 (motor ON), 0x23→F61A (motor OFF)
- **0x24→F643 (CAS1: SAVE)**, 0x25→F637, 0x26→F76A, 0x27→F766
- 0x28→F772, 0x29→F76E, 0x2A→F63F, 0x2B→F600

**Group 6 sub-commands (FA18) — CAS0: path:**
- 0x64→FCE8 (CAS0: SAVE), 0x65→FCE0, 0x6A→FCDC (unused for CAS1:)
- 0x6B→FDF1, 0x6C→FB62, 0x6D→FA82, 0x6E→FA8A, 0x6F→FA8E

### Key Protocol Discovery: Two Communication Channels

The master CPU communicates with the slave via TWO separate paths:
1. **SCI serial** ($13 = TDR): Used by E403 (polled transact), E3F8, E466, E3EF for protocol commands and IRQ-driven data transfer
2. **SIO bus** ($2A = LCD data latch): Used by F493/F50D for device-specific commands (0x64 = CAS0: SAVE)

**CAS1: uses SCI only** — command 0x24 is sent via E403. The SIO bus is NOT used for CAS1:.
CAS0: uses SIO bus for the initial 0x64 command, then SCI for data transfer.

### F10A: Double SCI Transact (Critical)

```
F10A: TAB                ; B = ACK value (from caller's A)
      wait RDRF → A = byte1 from RDR
      wait TDRE → send B (ACK #1)
      wait RDRF → check ORFE
      send B (ACK #2) → B = byte2 from RDR
      RTS              ; returns A=byte1, B=byte2
```
Each F10A call exchanges 2 bytes. Two calls at F64C+F653 = 4 bytes total.
$b7/$b8 (from 2nd F10A) = data byte count.

### CAS0: Slave SAVE Handler (FCE8-FDE5) — Reference for Later

CAS0: uses a completely different code path from CAS1:. Preserving full disassembly for when we tackle CAS0: IO Error.

```
FCE8: CLRA; STAA $81          ; mode 0 (CAS0: internal)
FCEB: OIM #$30, $07           ; set P44/P45
FCF0: TIM #$01, $03           ; test P20 (Port 2 bit 0: cassette mechanism ready)
FCF3: BNE $FCF8               ; ready → continue
FCF5: JMP $FDE6               ; not ready → error
FCF8: JSR $FC2D               ; cassette controller init (checks P46)
FCFF: JSR $F148               ; send 0x01 handshake ACK
FD07: LDAA #$61; JSR $F10A    ; double transact → $84/$85
FD10: LDAA #$61; JSR $F10A    ; double transact → $b8/$b9 (byte count)
FD15: LDAA #$81; JSR $FBEA    ; motor RECORD command (cassette controller)
FD1A-FD29: FSK init (set OLVL, arm first OC event)
FD2B-FD46: Leader loop — 625×$FF via FDF6, checks ORFE only (NOT RDRF)
FD48-FD6A: Sync phase — 9×$00, $00/$FF/$AA marker, clear CRC, reload X from $b8
FD6C-FD8E: Data loop — poll P40+RDRF+OCF, ACK with 0x61, FSK-encode via FDF6, DEX
```

**Key differences from CAS1: (F643):**
- Uses 0x61 ACK (not 0x21)
- FSK via FDF6/FE00 (P21 output compare toggle) instead of F709 (P33 port toggle)
- Motor via cassette controller IC (FBEA cmd 0x81) instead of P30
- Cassette controller init (FC2D) required
- Mode variable at $81 (CAS1: uses $87)

**Data loop exit paths:**
- DEX=0 (all bytes received) → FD90: write trailer (checksum×2, 0xAA, 0x00) + leader → FDC4 CLC RTS (SUCCESS)
- P40=LOW (motor stopped) → FDD2: varies by mode
- OCF timeout → FDC6: send 0x6F error → cleanup
- ORFE (SCI overrun) → FD7C: motor stop → F09D error handler

### Master SAVE Protocol (EBCB) — Reference for CAS0:

The SAVE handler at EBCB manages the high-level block transfer. This may be common to both CAS0: and CAS1: (CAS1: setup commands happen before sciDebug captures them).

**Phase 1: Device Setup** (before EBCB, via EB47/EB5A)
- 0x50 → status query (via E403 SCI polled transact)
- 0x7C → set mode/device (via E403 SCI) — parameter selects CAS0: vs CAS1:
- 0x50 → status query again

**Phase 2: Block Transfer** (EBCB loop)
- 0x6D → cassette setup + [pos_hi, pos_lo] tape position (via E403 + E3F8 SCI)
- 0x7B → SAVE begin / start block (via E403 SCI)
- 0x6E, 0x6F → block size negotiation (via E3F8 SCI) → stored at $0203/$0204
- 0x6E → verify (via E403, retry if mismatch)

**Phase 3: IRQ Data Transfer** (E4E8 → EE26)
- E4E8: sends 0x45 via E3EF (raw SCI), enables RIE (receive interrupt)
- EE26 IRQ handler: reads slave ACK, compares with expected (0x61 for CAS0:, 0x21 for CAS1:)
  - Match → sends next data byte via STAA $13
  - Mismatch (EE7E) → sets error flag in control block
  - Block complete → expects 0x62, sends 0x4A/0x4B completion handshake

**Phase 4: Post-Block** (EF07-EF1D, still in IRQ handler)
- No error: sends 0x7B (more blocks) via E403
- Error: skips 0x7B
- Then sends 0x77 (cleanup) via E403
- RTI → main code at EC1D reads response via F9B5

**Phase 5: Response Loop** (EC1D-EC46)
- Waits for 0xFE + status byte from slave
- Status 0xF6: new byte count, loop back
- Status 0xF5/0xF3: retry block
- Block count = 0 → done (EC48)

### CAS0: IO Error Analysis (Lower Priority)

**Symptom**: `SAVE "CAS0:TEST"` returns IO Error after data transfer phase completes.

**Root cause hypothesis**: The slave exits the data loop (FD6C) before the master finishes sending data. The slave returns to command dispatch (F059) and responds with wrong ACK values (0x01 via F148 instead of 0x61). The master's IRQ handler at EE68 detects the mismatch → error flag → IO Error.

**Why the slave exits early**: The data byte count in X (from $b8/$b9) may not match the number of bytes the master actually sends via IRQ. This could be due to:
1. Phantom bytes consumed during leader phase (3 bytes observed in RDR at data loop entry)
2. Byte count alignment issue between master and slave
3. Protocol timing difference causing extra bytes to arrive

**Diagnostics already in place** (hx20.ts, active when sciDebug=true):
- F061: Every command byte received by slave dispatch
- FD0C/FD13: F10A result values ($84/$85 and $b8/$b9 byte count)
- FD6C: Data loop entry (X register, RDRF state, sciRecvBuf contents)
- FD85: First 10 bytes received in data loop (byte value, X register)
- FD90: Data loop exit (total bytes processed)
- FDD2: Data loop exit via P40=LOW
- FD7C: Error path entry
- FDC4: SAVE success / FDC6: OCF timeout
- Master EE6A/EE7E/EE81/EF15/EF1A/E4F5: IRQ handler diagnostics

### Architecture Notes
- Main CPU: HD6303R, 32KB ROM (0x8000-0xFFFF), 16KB RAM
- Slave CPU: HD6301V1, 4KB internal ROM (0xF000-0xFFFF)
- SCI: 38400 baud (E clock / 16 = 614400/16 ≈ 38400), ~160 cycles per byte
- Cassette FSK: 1KHz = ON (1), 2KHz = OFF (0), ~1300 bps
  - CAS0: via P21 output compare (OLVL toggle) — FDF6/FE00
  - CAS1: via P33 port toggle — F709/F70E, timed by OCR
- Cassette controller: bit-bang serial on P43(data)/P44(clock), ack on P46, status on P40
- Address $03 on HD6301 = Port 2 data register; bit 2 = P22 = slaveSio

### Key ROM Addresses
- **Master**: E403 (SCI polled transact), E466 (fire-and-forget), E3EF (raw SCI send), E3F8 (two-byte transact), E4E8 (start IRQ transfer), EE26 (SCI IRQ handler), F493 (SIO bus CAS0: cmd), EBCB (SAVE entry), E122 (session cleanup)
- **Slave**: F059 (command dispatcher), F10A (double SCI transact), F148 (send 0x01 ACK), F613 (motor ON), F61A (motor OFF), **F643 (CAS1: SAVE)**, F709/F70E (P33 FSK encode), FBEA (cassette controller cmd), FC2D (cassette init), FCE8 (CAS0: SAVE), FDF6/FE00 (P21 FSK encode)
- **Slave dispatch**: F0AA (hierarchical by upper/lower nibble), see table above

### Debug Tools
- `hx20.sciDebug = true` in browser console enables SCI/SIO trace logging
- `window.hx20` exposed for console access
- Diagnostic breakpoints fire automatically when sciDebug=true
- `scripts/disasm-rom.ts` for offline ROM disassembly

### Next Steps
1. Debug CAS1: LOAD data corruption — compare recorded P33 transitions with expected FSK waveform
2. Check P32 playback timing — verify transitions are reproduced at correct cycle offsets
3. Check FSK decode path in slave ROM (where P32 is read during LOAD)
4. After CAS1: round-trips work, tackle CAS0: IO Error
