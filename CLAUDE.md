# HX-20 Emulator

## Architecture Notes
- Main CPU: HD6303R, 32KB ROM (0x8000-0xFFFF), 16KB RAM
- Slave CPU: HD6301V1, 4KB internal ROM (0xF000-0xFFFF)
- SCI: 38400 baud (E clock / 16 = 614400/16 ~ 38400), ~160 cycles per byte
- Cassette FSK: 1KHz = ON (1), 2KHz = OFF (0), ~1300 bps
  - CAS0: via P21 output compare (OLVL toggle) — FDF6/FE00
  - CAS1: via P33 port toggle — F709/F70E, timed by OCR
- Cassette controller: bit-bang serial on P43(data)/P44(clock), ack on P46, status on P40
- Address $03 on HD6301 = Port 2 data register; bit 2 = P22 = slaveSio

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
- Slave command: **0x24** (group 2, sub 4) → **F643**
- Motor OFF between blocks; multi-segment recording appends to existing tape

### Key Protocol Discovery: Two Communication Channels

The master CPU communicates with the slave via TWO separate paths:
1. **SCI serial** ($13 = TDR): Used by E403 (polled transact), E3F8, E466, E3EF for protocol commands and IRQ-driven data transfer
2. **SIO bus** ($2A = LCD data latch): Used by F493/F50D for device-specific commands (0x64 = CAS0: SAVE)

**CAS1: uses SCI only** — command 0x24 is sent via E403. The SIO bus is NOT used for CAS1:.
CAS0: uses SIO bus for the initial 0x64 command, then SCI for data transfer.

### Slave Dispatch Table — Hierarchical (F0AA)

Dispatch at F061 uses upper nibble as group index, lower nibble as sub-command:
```
Group 0 (0x0_): F0E9    Group 5 (0x5_): F9EB
Group 1 (0x1_): F22E    Group 6 (0x6_): FA18
Group 2 (0x2_): F5E2    Group 7 (0x7_): FA39
Group 3 (0x3_): F472    Group 8 (0x8_): F1E9
Group 4 (0x4_): F8C9
```

### Key ROM Addresses
- **Master**: E403 (SCI polled transact), E466 (fire-and-forget), E3EF (raw SCI send), E3F8 (two-byte transact), E4E8 (start IRQ transfer), EE26 (SCI IRQ handler), F493 (SIO bus CAS0: cmd), EBCB (SAVE entry), E122 (session cleanup)
- **Slave**: F059 (command dispatcher), F10A (double SCI transact), F148 (send 0x01 ACK), F613 (motor ON), F61A (motor OFF), **F643 (CAS1: SAVE)**, F709/F70E (P33 FSK encode), FBEA (cassette controller cmd), FC2D (cassette init), FCE8 (CAS0: SAVE), FDF6/FE00 (P21 FSK encode)
- **Slave dispatch**: F0AA (hierarchical by upper/lower nibble), see table above

### BASIC Program Format
- Keyword table in ROM at 0x80B1: MSB-terminated strings, token 0x80 = first entry
- Single-byte tokens 0x80-0xFE (127 entries), 0xFF-prefixed function tokens (0xFF 0x80+)
- HeadPointer at RAM 0x009C-0x009D (CPU internal RAM, big-endian)
- Line format: [next_ptr (2B BE)] [line_num (2B BE)] [tokenized body...] [0x00]
- End of program: next_ptr = 0x0000
- ' (apostrophe REM) stored as 0x3A 0x8D; ELSE stored as 0x3A 0x8F

### Debug Tools
- `hx20.sciDebug = true` in browser console enables SCI/SIO trace logging
- `window.hx20` exposed for console access
- Diagnostic breakpoints fire automatically when sciDebug=true

### ROM Disassemblies
- `disassemblies/main-rom-disasm.s` — fully commented main ROM disassembly
- `disassemblies/slave-rom-disasm.s` — slave CPU ROM (4KB)
- `disassemblies/tf20-rom-disasm.s` — TF-20 EPSP controller ROM (Z80, 8KB)
- `disassemblies/boot80-disasm.s` — BOOT80.SYS disk boot loader (256B, runs on HX-20)
- `disassemblies/dbasic-disasm.s` — DBASIC.SYS Disk BASIC V-1.0 extension (4.7KB PRL)

### Expansion System
- Expansion selector: Standard / TF-20 Disk / FORTH ROM
- Option ROM at $6000-$7FFF: detected at boot, diverts to Forth instead of BASIC
- FORTH ROM: Martin Hepperle's Japan V1.1 build (matches our Basic ROMs)
- ROM version: Japan V1.1 (D760=43 D4, E2EF=E2 3F) — FORTH ROM must match
- All expansion ROMs stored as binary files in `public/roms/` (boot80.bin, dbasic.bin, forth.bin)
- TF20 boot ROMs loaded via `tf20.loadBootROMs()` at startup

### Power / Reset Semantics
- Power toggle: preserves all RAM (mainRAM, CPU internal RAM, RTC NVRAM) — like real battery-backed CMOS
- Reset: clears all RAM (cold start) — gated behind confirmation dialog
- RTC NVRAM ($004E-$007F): MC146818 registers $0E-$3F used by ROM for system variables (ext_rom_flags, system_mode, etc.)
- `coldStart()`: clears mainRAM, expansion banks, CPU internal RAM, RTC NVRAM, then calls `reset()`
- `reset()`: restarts CPUs and peripherals only, RAM untouched
- Page loads in powered-off state; ROM and state restored silently

### TF-20 Floppy Disk
- EPSP protocol: DID $31-$34, broadcast serial to both EPSPDisplay and TF20
- BOOT80.SYS (256B) sent via FN_DISK_BOOT ($80), then DBASIC.SYS via FN_LOAD_OPEN/FN_READ_BLOCK
- DBASIC.SYS uses CP/M PRL format: 4158 bytes code (base page $60) + 520 bytes relocation bitmap
- Relocation: reads MEMTOP from $04B2, computes target page, applies bitmap-guided delta to high address bytes
- Two independent drives (A: and B:) as separate in-memory CP/M filesystems
- ROM bug fix: DBASIC $6878 ORAA #$37 ($8A) → ADDA #$37 ($8B) so A: ($0A+$37=$41) and B: ($0B+$37=$42) produce distinct drive codes

### Deployment
- Hosted on GitHub Pages at https://metaweta.github.io/ts-hx20/
- Source: `gh-pages` branch, built from `dist/`
- Build: `npx vite build --base=/ts-hx20/`
- Deploy: `npx gh-pages -d dist` (pushes dist/ to gh-pages branch)
- Do NOT use wrangler/Cloudflare — there is no API token configured

## TODO

1. Automated testing.
2. Fix "The CJS build of Vite's Node API is deprecated" warning from `npx vite`.
