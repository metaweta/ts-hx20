#!/usr/bin/env npx tsx
// Quick script to disassemble regions of the slave ROM
import { readFileSync } from 'fs';
import { disassemble, formatDisasmLine } from '../src/disasm';

const rom = readFileSync('public/roms/secondary.bin');
const BASE = 0xF000;

function read(addr: number): number {
  const offset = addr - BASE;
  if (offset >= 0 && offset < rom.length) return rom[offset];
  return 0xFF;
}

function disasmRange(start: number, end: number, label: string): void {
  console.log(`\n=== ${label} (${start.toString(16).toUpperCase()}-${end.toString(16).toUpperCase()}) ===`);
  let pc = start;
  while (pc < end) {
    const lines = disassemble(read, pc, 1);
    if (lines.length === 0) break;
    console.log(formatDisasmLine(lines[0]));
    pc += lines[0].length;
  }
}

function hexDump(start: number, len: number, label: string): void {
  console.log(`\n=== ${label} (hex dump) ===`);
  const offset = start - BASE;
  let line = '';
  for (let i = 0; i < len; i++) {
    if (i % 16 === 0) {
      if (line) console.log(line);
      line = `${(start + i).toString(16).padStart(4, '0')}: `;
    }
    line += rom[offset + i].toString(16).padStart(2, '0') + ' ';
  }
  if (line) console.log(line);
}

// Main loop after init
disasmRange(0xF040, 0xF0EA, 'F040-F0EA - Main loop and command dispatch');

// Group table at F0AA (raw hex to understand structure)
hexDump(0xF0AA, 48, 'F0AA - Command group table');

// Group 6 handler (for 0x64 command)
disasmRange(0xF9F6, 0xFA40, 'F9F6 - Group 6 dispatch');

// Group 7 handler (for 0x7D command)
disasmRange(0xFA39, 0xFA80, 'FA39 - Group 7 dispatch');

// FB13-FB70: Group 7 handlers (sub 3 through 13)
disasmRange(0xFB13, 0xFB70, 'FB13-FB70 - Group 7 handlers');

// Group 6 sub-command table
hexDump(0xFA17, 32, 'FA17 - Group 6 sub-command table');

// Group 0 handler and dispatch
hexDump(0xF0E9, 32, 'F0E9 - Group 0 sub-command table');
disasmRange(0xF0E9, 0xF130, 'F0E9 - Group 0 handlers');

// FBE6 - cassette controller bit-bang
disasmRange(0xFBE6, 0xFC10, 'FBE6 - Cassette controller bit-bang');

// FC2D-FC90: P46 check and cassette controller wait
disasmRange(0xFC2D, 0xFCA0, 'FC2D - Cassette controller status check');

// FCE8: Command 0x64 handler
disasmRange(0xFCE8, 0xFD70, 'FCE8 - 0x64 handler (SAVE)');

// FD6C-FE00: Data receive loop
disasmRange(0xFD6C, 0xFE00, 'FD6C - Data receive loop');

// FE00-FE50: FSK inner loop
disasmRange(0xFE00, 0xFE50, 'FE00 - FSK inner loop (OLVL/P21)');

// F10A: SCI transact
disasmRange(0xF10A, 0xF155, 'F10A - SCI routines');

// F148: send 0x01
disasmRange(0xF148, 0xF155, 'F148 - Send 0x01 ACK');

// FBD3: cleanup routine called from error path
disasmRange(0xFBD3, 0xFBEA, 'FBD3 - Cleanup routine');

// Interrupt Vectors
console.log('\n=== Interrupt Vectors ===');
const vectors: [number, string][] = [
  [0xFFF0, 'SCI'],
  [0xFFF2, 'TOF'],
  [0xFFF4, 'OCF'],
  [0xFFF6, 'ICF'],
  [0xFFF8, 'IRQ1'],
  [0xFFFA, 'SWI'],
  [0xFFFC, 'NMI'],
  [0xFFFE, 'RESET'],
];
for (const [addr, name] of vectors) {
  const offset = addr - BASE;
  const vec = (rom[offset] << 8) | rom[offset + 1];
  console.log(`  ${name}: $${vec.toString(16).toUpperCase().padStart(4, '0')}`);
}

// Group 7 dispatch table (raw bytes for sub-command addresses)
hexDump(0xFA39, 48, 'FA39 - Group 7 sub-command table (raw)');

// Group 4 dispatch (for 0x48 command)
hexDump(0xF8C9, 48, 'F8C9 - Group 4 dispatch table');
disasmRange(0xF8C9, 0xF920, 'F8C9 - Group 4 handlers');

// Slave init (reset vector → F000)
disasmRange(0xF000, 0xF040, 'F000 - Slave init');

// Look for FSK timing init — search for writes to $A6, $A8, $AA
// These are typically set by a subroutine called during cassette setup
disasmRange(0xF700, 0xF780, 'F700 - FSK timing setup (candidate)');
disasmRange(0xFCA0, 0xFCE8, 'FCA0 - Pre-SAVE setup (candidate)');

// F4AC - called from FDC6 error path
disasmRange(0xF4A0, 0xF4C0, 'F4A0 - Error handler (called at FDC6)');

// F09D - SCI error exit
disasmRange(0xF09D, 0xF0AA, 'F09D - SCI error/overrun exit');

// F00C - reinit jump target
disasmRange(0xF00C, 0xF040, 'F00C - Reinit after error');

// FC17 - wait subroutine used by cassette controller
disasmRange(0xFC17, 0xFC2D, 'FC17 - Wait subroutine');

// Search ROM for writes to $A6, $A8, $AA (FSK timing constants)
console.log('\n=== Searching for FSK timing constant writes ===');
for (let addr = 0xF000; addr < 0xFFF0; addr++) {
  const b0 = rom[addr - BASE];
  const b1 = rom[addr - BASE + 1];
  // Look for STAA/STAB/STD to $A6, $A8, $AA (direct addressing)
  if ((b0 === 0x97 || b0 === 0xD7 || b0 === 0xDD) &&
      (b1 === 0xA6 || b1 === 0xA7 || b1 === 0xA8 || b1 === 0xA9 || b1 === 0xAA || b1 === 0xAB)) {
    const mnemonic = b0 === 0x97 ? 'STAA' : b0 === 0xD7 ? 'STAB' : 'STD';
    console.log(`  ${addr.toString(16)}: ${mnemonic} $${b1.toString(16)} — context:`);
    // Show surrounding code
    const lines = disassemble(read, addr - 4, 5);
    for (const l of lines) console.log('    ' + formatDisasmLine(l));
  }
}
