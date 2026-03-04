# Epson HX-20 Emulator

A browser-based emulator of the [Epson HX-20](https://en.wikipedia.org/wiki/Epson_HX-20), the world's first laptop computer (1981). Emulates the full dual-CPU system including LCD display, keyboard, cassette storage, real-time clock, and external CRT display.

## Features

- **Dual HD6301/HD6303 CPUs** — main (32KB ROM, 16KB RAM) and slave (4KB internal ROM) running in lockstep with cycle-accurate SCI serial communication at 38400 baud
- **120x32 LCD** — 6 UPD7227 controllers arranged in a 3x2 grid, rendered to canvas with 4x upscaling
- **External CRT display** — 40x24 text / 128x96 graphics via EPSP protocol (`SCREEN 1`), 8-color (3-bit RGB) palette
- **Full keyboard** — on-screen clickable keyboard with physical keyboard mapping, GRPH character support, and clipboard paste (Cmd+V)
- **Two cassette interfaces**
  - CAS0: internal microcassette with bit-bang controller protocol
  - CAS1: external cassette with FSK recording/playback
  - Tape library with localStorage persistence, JSON import/export
- **RAM expansion** — bank-switched 16/32/64/128 KB
- **MC146818 RTC** — real-time clock synced from browser
- **Built-in printer** — thermal printer emulation with bitmap rendering, feed/tear/copy controls
- **BASIC listing transfer** — download detokenized listings as `.bas` files (GET LIST), upload and enter them automatically (PUT LIST)
- **State persistence** — auto-saves to localStorage; save/load full machine state as JSON files
- **Debug tools** — register display, disassembly view, step/run/breakpoint controls, `sciDebug` console tracing

## Quick Start

```bash
npm install
npm run dev
```

Open `http://localhost:5173` in your browser. The emulator will attempt to load ROMs automatically from `public/roms/`.

### ROM Files

Place these binary ROM dumps in `public/roms/`:

| File | Size | Address Range |
|------|------|---------------|
| `rom0.bin` | 8 KB | 0xE000–0xFFFF |
| `rom1.bin` | 8 KB | 0xC000–0xDFFF |
| `rom2.bin` | 8 KB | 0xA000–0xBFFF |
| `rom3.bin` | 8 KB | 0x8000–0x9FFF |
| `secondary.bin` | 4 KB | Slave CPU ROM |

If local ROMs aren't found, the emulator falls back to fetching Intel HEX files from the web. You can also load `.hex`, `.bin`, or `.rom` files manually via the LOAD ROMs button.

## Building

```bash
npm run build     # TypeScript check + Vite production build → dist/
npm run preview   # Preview the production build
```

## Usage

### Controls

| Button | Action |
|--------|--------|
| **POWER** | Cold boot (resets machine) |
| **RESET** | Warm reset |
| **PASTE** | Paste clipboard text into keyboard |
| **Speed** | 1x–10x emulation speed |
| **RAM** | Select RAM expansion (requires reset) |
| **SAVE STATE** | Download full machine state as JSON file |
| **LOAD STATE** | Restore machine state from a saved JSON file |
| **CAS0:/CAS1:** | Open cassette tape management panels |
| **CRT** | Toggle external CRT display (enables DIP SW4) |
| **PRINTER** | Toggle printer output panel |
| **GET LIST** | Download current BASIC program as a `.bas` text file |
| **PUT LIST** | Upload a `.bas` text file (clears program first, then types it in) |
| **Show Debug** | Register dump, disassembly, step/breakpoint controls |

### Cassette Storage

Each cassette interface has a tape library panel where you can create blank tapes, load/eject tapes, and import/export tape images as JSON files. CAS1 includes a rewind button. Tapes persist in localStorage.

```basic
SAVE "CAS1:HELLO"
LOAD "CAS1:HELLO"
```

### BASIC Listing Transfer

**GET LIST** reads the tokenized BASIC program directly from RAM, detokenizes it using the keyword table in ROM, and downloads the result as `program.bas`.

**PUT LIST** uploads a `.bas` text file, issues `NEW` to clear the current program, then types each line through the keyboard matrix so BASIC tokenizes it normally. The emulator must be running at the BASIC prompt.

### External CRT Display

Click the **CRT** button to open the external display panel. This sets DIP switch 4 (TF-20 mode). After a reset, use `SCREEN 1` in BASIC to switch output to the CRT.

### Debug Console

Access the emulator object in the browser console:

```javascript
window.hx20                    // Full machine access
window.hx20.sciDebug = true    // Enable SCI/EPSP protocol tracing
```

## Architecture

```
┌─────────────────┐     SCI 38400     ┌─────────────────┐
│   Main CPU      │◄────────────────►│   Slave CPU     │
│   HD6303R       │   (slaveSio=1)    │   HD6301V1      │
│   32KB ROM      │                   │   4KB ROM        │
│   16KB+ RAM     │   SIO bus         │                  │
│                 ├──────────────────►│   Keyboard       │
│                 │   (LCD data)      │   Cassettes      │
└────────┬────────┘                   │   RTC            │
         │ SCI (slaveSio=0)           └──────────────────┘
         ▼
┌─────────────────┐
│  EPSP Display   │
│  40x24 / 128x96 │
└─────────────────┘
```

### Source Files

| File | Description |
|------|-------------|
| `src/cpu.ts` | HD6301/HD6303 CPU emulator — registers, instructions, I/O ports, SCI serial |
| `src/hx20.ts` | System integration — wires CPUs, memory, LCD, keyboard, cassettes, peripherals |
| `src/main.ts` | UI wiring — canvas, buttons, panels, ROM loading, state persistence |
| `src/lcd.ts` | UPD7227 LCD controller emulation and canvas rendering |
| `src/epsp-display.ts` | External CRT display — EPSP protocol state machine, text/graphics rendering |
| `src/keyboard.ts` | Keyboard matrix (8x10), key mapping, DIP switches, text paste |
| `src/cassette.ts` | Virtual cassette — FSK recording/playback, tape library |
| `src/microcassette-drive.ts` | CAS0 internal drive — bit-bang protocol, motor/transport control |
| `src/rtc.ts` | MC146818 real-time clock — BCD registers, alarm, periodic interrupt |
| `src/printer.ts` | Built-in thermal printer — bitmap rendering, feed/tear/copy |
| `src/disasm.ts` | HD6301/HD6303 disassembler for the debug panel |
| `src/rom-loader.ts` | Intel HEX parser and binary ROM loading |
| `src/style.css` | UI styling |

## Tech Stack

- **TypeScript 5.7** — type-safe emulation core
- **Vite 6** — dev server with HMR and production bundling
- **Canvas API** — LCD and CRT pixel rendering
- **localStorage** — tape library and machine state persistence
