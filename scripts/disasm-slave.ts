// Disassemble specific ranges of the slave CPU ROM (secondary.bin)
// Usage: npx tsx scripts/disasm-slave.ts

import { readFileSync } from 'fs';
import { disassemble, formatDisasmLine } from '../src/disasm';

const ROM_BASE = 0xF000;
const rom = readFileSync('public/roms/secondary.bin');

function read(addr: number): number {
  const offset = addr - ROM_BASE;
  if (offset < 0 || offset >= rom.length) return 0xFF;
  return rom[offset];
}

// --- Raw hex bytes FD10-FD30 ---
console.log('=== Raw hex bytes 0xFD10 - 0xFD30 ===');
for (let off = 0xD10; off < 0xD30; off += 16) {
  const addr = 0xF000 + off;
  const bytes: string[] = [];
  for (let i = 0; i < 16 && off + i < 0xD30; i++) {
    bytes.push(rom[off + i].toString(16).padStart(2, '0'));
  }
  console.log(`${addr.toString(16).padStart(4, '0')}: ${bytes.join(' ')}`);
}

// --- Disassembly FD10 - ~FD2B (15 instructions) ---
console.log('\n=== Disassembly FD10 - FD2B (15 instructions) ===');
const lines1 = disassemble(read, 0xFD10, 15);
for (const line of lines1) {
  console.log(formatDisasmLine(line));
}

// --- Disassembly FD38 - FD50 (8 instructions) ---
console.log('\n=== Disassembly FD38 - FD50 (8 instructions) ===');
const lines2 = disassemble(read, 0xFD38, 8);
for (const line of lines2) {
  console.log(formatDisasmLine(line));
}
