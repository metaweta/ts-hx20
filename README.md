# Epson HX-20 Emulator

A browser-based emulator of the [Epson HX-20](https://en.wikipedia.org/wiki/Epson_HX-20), the world's first laptop computer (1981). Emulates the full dual-CPU system including LCD display, keyboard, cassette storage, real-time clock, and external CRT display.  Written by Claude, but see the Acknowledgements section below.

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

### Getting Data In and Out

There are several ways to transfer programs and data between the emulator and your host computer, each with different trade-offs.

#### BASIC Listing Transfer (GET LIST / PUT LIST)

The simplest way to work with BASIC programs.

- **GET LIST** reads the tokenized program directly from RAM, detokenizes it using the keyword table in ROM, and downloads the result as a `.bas` text file. Instantaneous — doesn't require the emulator to be running.
- **PUT LIST** uploads a `.bas` file, issues `NEW`, then types each line through the keyboard matrix so BASIC tokenizes it normally. Requires the emulator to be running at the BASIC prompt. Speed depends on the emulation speed setting.

*Pros:* Human-readable format, easy to edit in any text editor, works with programs from other sources (books, websites).
*Cons:* PUT LIST is slow (simulates typing). Only transfers BASIC program text — not variables, machine code, or binary data.

#### Machine State (SAVE STATE / LOAD STATE)

A complete snapshot of the entire machine: both CPUs, all RAM (including expansion banks), ROM, LCD, RTC, and peripheral state.

- **SAVE STATE** downloads a JSON file. **LOAD STATE** restores from one.
- The emulator also auto-saves to localStorage every 5 seconds and resumes on page reload.

*Pros:* Captures everything — program, variables, machine code, screen contents, mid-execution state. Instant save and restore.
*Cons:* Large files (~100KB+). Opaque binary format — not human-editable. Tied to the emulator's internal state layout.

#### Cassette Tapes (CAS0: / CAS1:)

The authentic HX-20 storage mechanism. Programs are saved and loaded using BASIC's built-in cassette commands.

```basic
SAVE "CAS1:HELLO"       ' save current program to tape
LOAD "CAS1:HELLO"       ' load program from tape
```

Each cassette panel provides a tape library where you can create blank tapes, insert/eject tapes, and import/export tape images as JSON files. CAS1 also has a rewind button. Tapes persist in localStorage between sessions.

Tape images use a compact binary format (delta-encoded FSK transitions, deflate-compressed, base64-encoded) so exported JSON files are small despite storing the full analog waveform.

*Pros:* Authentic to the real hardware. Handles any data the real cassette could store (BASIC programs, machine code via `SAVEM`/`LOADM`, sequential data files). Tape images are portable and small.
*Cons:* Slow — runs at real cassette speed (~1300 bps). Requires the emulator to be running.

#### Clipboard Paste (PASTE / Cmd+V)

Pastes text from the clipboard into the keyboard matrix, as if typing. Useful for entering short programs or commands without a file.

*Pros:* No file management needed, works with any text source.
*Cons:* Same speed limitation as PUT LIST. No way to extract data (one-way).

#### Printer Output (LLIST / LPRINT)

The built-in printer captures output from `LLIST` (list program to printer) and `LPRINT` (print to printer). The printer panel has a **Copy** button that copies the output as an image to the clipboard.

```basic
LLIST                    ' print program listing to printer
LPRINT "HELLO"           ' print text to printer
```

*Pros:* Produces a visual copy of output, including GRPH characters and graphics. Copy button makes it easy to paste into documents.
*Cons:* Image only — not editable text. One-way (output only). Graphics screen dumps via CTRL+PF2 are also supported.

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

## Acknowledgements

While ts-hx20 is not a port of anyone else's emulator (it did a full annotated disassembly of the ROMs provided by Electrickery and worked from there; see the docs folder), Claude did refer to any existing emulators and documentation it could find, particularly

* Electrickery's [HX-20 documentation](https://electrickery.nl/comp/hx20/index.html) and [ROMs](https://electrickery.nl/comp/hx20/ROMdump.html)
* Frigolit's [HXEmu](https://frigolit.net/projects/hxemu/)
* Martin Hepperle's [MH-20](https://www.mh-aerotools.de/hp/hx-20/)
* Norbert Kehrer's [flashx20](https://norbertkehrer.github.io/flashx20.html)
* Kobolt's [hex20](https://github.com/kobolt/hex20)
* [The MAME project](https://www.mamedev.org/)
* nerdprojects' [hxlink](https://github.com/nerdprojects/hxlink)

It made heavy use of Benschop and Seib's [A09](https://github.com/Arakula/A09) assembler and Salmi, Seib, Bourassa, and Buchty's [f9dasm](https://github.com/Arakula/f9dasm) disassembler when understanding the ROMs.

