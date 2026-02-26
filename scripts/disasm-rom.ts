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

// Check the hex20 reference for command table structure
// Look for the master ROM's SAVE handler too
console.log('\n=== Key FSK timing values ===');
// Check what's at RAM addresses $9D, $9F, $A6, $A8, $AA used by FSK loops
// These are set up during init. Let's check what the F6F0 area uses.
console.log('FSK loop uses: $A6 (1KHz half), $A8 (low period?), $AA (2KHz half)');
console.log('F709 routine uses: $9D, $9F for period values');
