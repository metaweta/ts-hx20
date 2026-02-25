#!/usr/bin/env npx ts-node
// Disassemble HX-20 ROMs into annotated listing
// Usage: npx ts-node tools/disassemble-roms.ts > disasm.txt

import * as fs from 'fs';
import * as path from 'path';

// ---- Instruction table ----

type AddrMode = 'INH' | 'IMM8' | 'IMM16' | 'DIR' | 'EXT' | 'IDX' | 'REL'
  | 'BIT_DIR' | 'BIT_IDX';

interface OpInfo {
  name: string;
  mode: AddrMode;
  bytes: number;
}

function op(name: string, mode: AddrMode): OpInfo {
  const bytes: Record<AddrMode, number> = {
    'INH': 1, 'IMM8': 2, 'IMM16': 3, 'DIR': 2, 'EXT': 3, 'IDX': 2, 'REL': 2,
    'BIT_DIR': 3, 'BIT_IDX': 3,
  };
  return { name, mode, bytes: bytes[mode] };
}

const OPS: Record<number, OpInfo> = {
  0x01: op('NOP','INH'), 0x04: op('LSRD','INH'), 0x05: op('ASLD','INH'),
  0x06: op('TAP','INH'), 0x07: op('TPA','INH'), 0x08: op('INX','INH'),
  0x09: op('DEX','INH'), 0x0A: op('CLV','INH'), 0x0B: op('SEV','INH'),
  0x0C: op('CLC','INH'), 0x0D: op('SEC','INH'), 0x0E: op('CLI','INH'),
  0x0F: op('SEI','INH'),
  0x10: op('SBA','INH'), 0x11: op('CBA','INH'), 0x16: op('TAB','INH'),
  0x17: op('TBA','INH'), 0x18: op('XGDX','INH'), 0x19: op('DAA','INH'),
  0x1A: op('SLP','INH'), 0x1B: op('ABA','INH'),
  0x20: op('BRA','REL'), 0x21: op('BRN','REL'), 0x22: op('BHI','REL'),
  0x23: op('BLS','REL'), 0x24: op('BCC','REL'), 0x25: op('BCS','REL'),
  0x26: op('BNE','REL'), 0x27: op('BEQ','REL'), 0x28: op('BVC','REL'),
  0x29: op('BVS','REL'), 0x2A: op('BPL','REL'), 0x2B: op('BMI','REL'),
  0x2C: op('BGE','REL'), 0x2D: op('BLT','REL'), 0x2E: op('BGT','REL'),
  0x2F: op('BLE','REL'),
  0x30: op('TSX','INH'), 0x31: op('INS','INH'), 0x32: op('PULA','INH'),
  0x33: op('PULB','INH'), 0x34: op('DES','INH'), 0x35: op('TXS','INH'),
  0x36: op('PSHA','INH'), 0x37: op('PSHB','INH'), 0x38: op('PULX','INH'),
  0x39: op('RTS','INH'), 0x3A: op('ABX','INH'), 0x3B: op('RTI','INH'),
  0x3C: op('PSHX','INH'), 0x3D: op('MUL','INH'), 0x3E: op('WAI','INH'),
  0x3F: op('SWI','INH'),
  0x40: op('NEGA','INH'), 0x43: op('COMA','INH'), 0x44: op('LSRA','INH'),
  0x46: op('RORA','INH'), 0x47: op('ASRA','INH'), 0x48: op('ASLA','INH'),
  0x49: op('ROLA','INH'), 0x4A: op('DECA','INH'), 0x4C: op('INCA','INH'),
  0x4D: op('TSTA','INH'), 0x4F: op('CLRA','INH'),
  0x50: op('NEGB','INH'), 0x53: op('COMB','INH'), 0x54: op('LSRB','INH'),
  0x56: op('RORB','INH'), 0x57: op('ASRB','INH'), 0x58: op('ASLB','INH'),
  0x59: op('ROLB','INH'), 0x5A: op('DECB','INH'), 0x5C: op('INCB','INH'),
  0x5D: op('TSTB','INH'), 0x5F: op('CLRB','INH'),
  // Indexed
  0x60: op('NEG','IDX'), 0x61: op('AIM','BIT_IDX'), 0x62: op('OIM','BIT_IDX'),
  0x63: op('COM','IDX'), 0x64: op('LSR','IDX'), 0x65: op('EIM','BIT_IDX'),
  0x66: op('ROR','IDX'), 0x67: op('ASR','IDX'), 0x68: op('ASL','IDX'),
  0x69: op('ROL','IDX'), 0x6A: op('DEC','IDX'), 0x6B: op('TIM','BIT_IDX'),
  0x6C: op('INC','IDX'), 0x6D: op('TST','IDX'), 0x6E: op('JMP','IDX'),
  0x6F: op('CLR','IDX'),
  // Extended + 6301 direct bit ops
  0x70: op('NEG','EXT'), 0x71: op('AIM','BIT_DIR'), 0x72: op('OIM','BIT_DIR'),
  0x73: op('COM','EXT'), 0x74: op('LSR','EXT'), 0x75: op('EIM','BIT_DIR'),
  0x76: op('ROR','EXT'), 0x77: op('ASR','EXT'), 0x78: op('ASL','EXT'),
  0x79: op('ROL','EXT'), 0x7A: op('DEC','EXT'), 0x7B: op('TIM','BIT_DIR'),
  0x7C: op('INC','EXT'), 0x7D: op('TST','EXT'), 0x7E: op('JMP','EXT'),
  0x7F: op('CLR','EXT'),
  // Immediate A / 16-bit
  0x80: op('SUBA','IMM8'), 0x81: op('CMPA','IMM8'), 0x82: op('SBCA','IMM8'),
  0x83: op('SUBD','IMM16'), 0x84: op('ANDA','IMM8'), 0x85: op('BITA','IMM8'),
  0x86: op('LDAA','IMM8'), 0x88: op('EORA','IMM8'), 0x89: op('ADCA','IMM8'),
  0x8A: op('ORAA','IMM8'), 0x8B: op('ADDA','IMM8'), 0x8C: op('CPX','IMM16'),
  0x8D: op('BSR','REL'), 0x8E: op('LDS','IMM16'),
  // Direct A / 16-bit
  0x90: op('SUBA','DIR'), 0x91: op('CMPA','DIR'), 0x92: op('SBCA','DIR'),
  0x93: op('SUBD','DIR'), 0x94: op('ANDA','DIR'), 0x95: op('BITA','DIR'),
  0x96: op('LDAA','DIR'), 0x97: op('STAA','DIR'), 0x98: op('EORA','DIR'),
  0x99: op('ADCA','DIR'), 0x9A: op('ORAA','DIR'), 0x9B: op('ADDA','DIR'),
  0x9C: op('CPX','DIR'), 0x9D: op('JSR','DIR'), 0x9E: op('LDS','DIR'),
  0x9F: op('STS','DIR'),
  // Indexed A / 16-bit
  0xA0: op('SUBA','IDX'), 0xA1: op('CMPA','IDX'), 0xA2: op('SBCA','IDX'),
  0xA3: op('SUBD','IDX'), 0xA4: op('ANDA','IDX'), 0xA5: op('BITA','IDX'),
  0xA6: op('LDAA','IDX'), 0xA7: op('STAA','IDX'), 0xA8: op('EORA','IDX'),
  0xA9: op('ADCA','IDX'), 0xAA: op('ORAA','IDX'), 0xAB: op('ADDA','IDX'),
  0xAC: op('CPX','IDX'), 0xAD: op('JSR','IDX'), 0xAE: op('LDS','IDX'),
  0xAF: op('STS','IDX'),
  // Extended A / 16-bit
  0xB0: op('SUBA','EXT'), 0xB1: op('CMPA','EXT'), 0xB2: op('SBCA','EXT'),
  0xB3: op('SUBD','EXT'), 0xB4: op('ANDA','EXT'), 0xB5: op('BITA','EXT'),
  0xB6: op('LDAA','EXT'), 0xB7: op('STAA','EXT'), 0xB8: op('EORA','EXT'),
  0xB9: op('ADCA','EXT'), 0xBA: op('ORAA','EXT'), 0xBB: op('ADDA','EXT'),
  0xBC: op('CPX','EXT'), 0xBD: op('JSR','EXT'), 0xBE: op('LDS','EXT'),
  0xBF: op('STS','EXT'),
  // Immediate B / 16-bit
  0xC0: op('SUBB','IMM8'), 0xC1: op('CMPB','IMM8'), 0xC2: op('SBCB','IMM8'),
  0xC3: op('ADDD','IMM16'), 0xC4: op('ANDB','IMM8'), 0xC5: op('BITB','IMM8'),
  0xC6: op('LDAB','IMM8'), 0xC8: op('EORB','IMM8'), 0xC9: op('ADCB','IMM8'),
  0xCA: op('ORAB','IMM8'), 0xCB: op('ADDB','IMM8'), 0xCC: op('LDD','IMM16'),
  0xCE: op('LDX','IMM16'),
  // Direct B / 16-bit
  0xD0: op('SUBB','DIR'), 0xD1: op('CMPB','DIR'), 0xD2: op('SBCB','DIR'),
  0xD3: op('ADDD','DIR'), 0xD4: op('ANDB','DIR'), 0xD5: op('BITB','DIR'),
  0xD6: op('LDAB','DIR'), 0xD7: op('STAB','DIR'), 0xD8: op('EORB','DIR'),
  0xD9: op('ADCB','DIR'), 0xDA: op('ORAB','DIR'), 0xDB: op('ADDB','DIR'),
  0xDC: op('LDD','DIR'), 0xDD: op('STD','DIR'), 0xDE: op('LDX','DIR'),
  0xDF: op('STX','DIR'),
  // Indexed B / 16-bit
  0xE0: op('SUBB','IDX'), 0xE1: op('CMPB','IDX'), 0xE2: op('SBCB','IDX'),
  0xE3: op('ADDD','IDX'), 0xE4: op('ANDB','IDX'), 0xE5: op('BITB','IDX'),
  0xE6: op('LDAB','IDX'), 0xE7: op('STAB','IDX'), 0xE8: op('EORB','IDX'),
  0xE9: op('ADCB','IDX'), 0xEA: op('ORAB','IDX'), 0xEB: op('ADDB','IDX'),
  0xEC: op('LDD','IDX'), 0xED: op('STD','IDX'), 0xEE: op('LDX','IDX'),
  0xEF: op('STX','IDX'),
  // Extended B / 16-bit
  0xF0: op('SUBB','EXT'), 0xF1: op('CMPB','EXT'), 0xF2: op('SBCB','EXT'),
  0xF3: op('ADDD','EXT'), 0xF4: op('ANDB','EXT'), 0xF5: op('BITB','EXT'),
  0xF6: op('LDAB','EXT'), 0xF7: op('STAB','EXT'), 0xF8: op('EORB','EXT'),
  0xF9: op('ADCB','EXT'), 0xFA: op('ORAB','EXT'), 0xFB: op('ADDB','EXT'),
  0xFC: op('LDD','EXT'), 0xFD: op('STD','EXT'), 0xFE: op('LDX','EXT'),
  0xFF: op('STX','EXT'),
};

// ---- Known addresses for annotations ----

const IO_NAMES: Record<number, string> = {
  0x00: 'P1DDR', 0x01: 'P2DDR', 0x02: 'PORT1', 0x03: 'PORT2',
  0x04: 'P3DDR', 0x05: 'P4DDR', 0x06: 'PORT3', 0x07: 'PORT4',
  0x08: 'TCSR', 0x09: 'FRCH', 0x0A: 'FRCL', 0x0B: 'OCRH', 0x0C: 'OCRL',
  0x0D: 'ICRH', 0x0E: 'ICRL', 0x0F: 'P3CSR', 0x10: 'RMCR',
  0x11: 'TRCSR', 0x12: 'RDR', 0x13: 'TDR', 0x14: 'RAMCR',
  // External I/O
  0x20: 'KSC', 0x22: 'KRTN07', 0x26: 'LCDCTL', 0x28: 'KRTN89',
  0x2A: 'LCDDATA', 0x2B: 'LCDCLK', 0x2C: 'INTMASK',
  0x30: 'BANK0', 0x31: 'BANK1', 0x32: 'BANK2', 0x33: 'BANK3',
};

// RTC registers
for (let i = 0; i < 0x40; i++) {
  const addr = 0x40 + i;
  const rtcNames: Record<number, string> = {
    0x00: 'RTC_SEC', 0x01: 'RTC_SECALM', 0x02: 'RTC_MIN', 0x03: 'RTC_MINALM',
    0x04: 'RTC_HR', 0x05: 'RTC_HRALM', 0x06: 'RTC_DOW', 0x07: 'RTC_DOM',
    0x08: 'RTC_MON', 0x09: 'RTC_YR', 0x0A: 'RTC_REGA', 0x0B: 'RTC_REGB',
    0x0C: 'RTC_REGC', 0x0D: 'RTC_REGD',
  };
  if (rtcNames[i]) IO_NAMES[addr] = rtcNames[i];
  else if (i >= 0x0E) IO_NAMES[addr] = `RTC_RAM_${i.toString(16).padStart(2,'0')}`;
}

const VECTOR_NAMES: Record<number, string> = {
  0xFFF0: 'VEC_SCI', 0xFFF2: 'VEC_TOF', 0xFFF4: 'VEC_OCF',
  0xFFF6: 'VEC_ICF', 0xFFF8: 'VEC_IRQ1', 0xFFFA: 'VEC_SWI',
  0xFFFC: 'VEC_NMI', 0xFFFE: 'VEC_RESET',
};

function h2(v: number): string { return v.toString(16).padStart(2, '0').toUpperCase(); }
function h4(v: number): string { return v.toString(16).padStart(4, '0').toUpperCase(); }

function annotateAddr(addr: number): string {
  if (IO_NAMES[addr]) return IO_NAMES[addr];
  if (addr >= 0x0080 && addr <= 0x00FF) return `IRAM_${h2(addr)}`;
  if (addr >= 0x0100 && addr <= 0x3FFF) return `RAM`;
  if (addr >= 0x6000 && addr <= 0x7FFF) return `OPTROM`;
  if (addr >= 0x8000 && addr <= 0xFFFF) return `ROM`;
  return '';
}

// ---- Disassembler ----

function disassembleROM(rom: Uint8Array, baseAddr: number): string[] {
  const lines: string[] = [];
  let pc = 0;
  // Collect branch/call targets for labeling
  const targets = new Set<number>();

  // First pass: find branch targets
  let tmpPc = 0;
  while (tmpPc < rom.length) {
    const opc = rom[tmpPc];
    const info = OPS[opc];
    if (!info) { tmpPc++; continue; }

    const instrAddr = baseAddr + tmpPc;

    if (info.mode === 'REL' && tmpPc + 1 < rom.length) {
      const off = rom[tmpPc + 1];
      const signed = off > 127 ? off - 256 : off;
      const target = instrAddr + 2 + signed;
      targets.add(target);
    } else if (info.mode === 'EXT' && tmpPc + 2 < rom.length) {
      if (opc === 0xBD || opc === 0x7E) { // JSR ext, JMP ext
        const target = (rom[tmpPc + 1] << 8) | rom[tmpPc + 2];
        targets.add(target);
      }
    }
    tmpPc += info.bytes;
  }

  // Also add vector targets
  if (baseAddr + rom.length >= 0x10000) {
    for (let v = 0xFFF0; v <= 0xFFFE; v += 2) {
      const off = v - baseAddr;
      if (off >= 0 && off + 1 < rom.length) {
        const target = (rom[off] << 8) | rom[off + 1];
        targets.add(target);
      }
    }
  }

  // Second pass: disassemble
  pc = 0;
  while (pc < rom.length) {
    const addr = baseAddr + pc;

    // Check for vector table
    if (VECTOR_NAMES[addr]) {
      const vec = (rom[pc] << 8) | rom[pc + 1];
      lines.push(`                           ; ---- ${VECTOR_NAMES[addr]} ----`);
      lines.push(`${h4(addr)}: ${h2(rom[pc])} ${h2(rom[pc+1])}          .dw  $${h4(vec)}       ; ${VECTOR_NAMES[addr]}`);
      pc += 2;
      continue;
    }

    // Label if this is a branch target
    if (targets.has(addr)) {
      lines.push(`                    L_${h4(addr)}:`);
    }

    const opc = rom[pc];
    const info = OPS[opc];

    if (!info) {
      // Data byte or unknown opcode
      lines.push(`${h4(addr)}: ${h2(opc)}             .db  $${h2(opc)}`);
      pc++;
      continue;
    }

    // Check we have enough bytes
    if (pc + info.bytes > rom.length) {
      lines.push(`${h4(addr)}: ${h2(opc)}             .db  $${h2(opc)}        ; truncated`);
      pc++;
      continue;
    }

    const bytes = [];
    for (let i = 0; i < info.bytes; i++) bytes.push(rom[pc + i]);

    let operand = '';
    let comment = '';

    switch (info.mode) {
      case 'INH':
        break;
      case 'IMM8': {
        const val = bytes[1];
        operand = `#$${h2(val)}`;
        break;
      }
      case 'IMM16': {
        const val = (bytes[1] << 8) | bytes[2];
        operand = `#$${h4(val)}`;
        break;
      }
      case 'DIR': {
        const val = bytes[1];
        operand = `$${h2(val)}`;
        const name = IO_NAMES[val];
        if (name) comment = name;
        break;
      }
      case 'EXT': {
        const val = (bytes[1] << 8) | bytes[2];
        operand = `$${h4(val)}`;
        const ann = annotateAddr(val);
        if (ann) comment = ann;
        break;
      }
      case 'IDX': {
        const val = bytes[1];
        operand = val === 0 ? ',X' : `$${h2(val)},X`;
        break;
      }
      case 'REL': {
        const off = bytes[1];
        const signed = off > 127 ? off - 256 : off;
        const target = addr + 2 + signed;
        operand = `L_${h4(target)}`;
        comment = `$${h4(target)}`;
        break;
      }
      case 'BIT_DIR': {
        const imm = bytes[1];
        const dir = bytes[2];
        operand = `#$${h2(imm)}, $${h2(dir)}`;
        const name = IO_NAMES[dir];
        if (name) comment = name;
        break;
      }
      case 'BIT_IDX': {
        const imm = bytes[1];
        const off = bytes[2];
        operand = off === 0 ? `#$${h2(imm)}, ,X` : `#$${h2(imm)}, $${h2(off)},X`;
        break;
      }
    }

    const bytesStr = bytes.map(b => h2(b)).join(' ');
    const pad = 14 - bytesStr.length;
    const instrStr = `${info.name.padEnd(5)} ${operand}`;
    const commentStr = comment ? `; ${comment}` : '';

    lines.push(`${h4(addr)}: ${bytesStr}${' '.repeat(Math.max(1, pad))}${instrStr.padEnd(20)} ${commentStr}`);

    pc += info.bytes;
  }

  return lines;
}

// ---- Main ----

const romsDir = path.join(__dirname, '..', 'public', 'roms');
const romFiles = [
  { name: 'rom3.bin', base: 0x8000 },
  { name: 'rom2.bin', base: 0xA000 },
  { name: 'rom1.bin', base: 0xC000 },
  { name: 'rom0.bin', base: 0xE000 },
];

const output: string[] = [];
output.push('; =============================================');
output.push('; Epson HX-20 ROM Disassembly (unknown-012905)');
output.push('; HD6301/HD6303 instruction set');
output.push('; =============================================');
output.push('');
output.push('; I/O Register Map:');
output.push('; $00-$14: HD6301 internal registers');
output.push(';   $00: P1DDR  $01: P2DDR  $02: PORT1  $03: PORT2');
output.push(';   $04: P3DDR  $05: P4DDR  $06: PORT3  $07: PORT4');
output.push(';   $08: TCSR   $09: FRCH   $0A: FRCL   $0B: OCRH');
output.push(';   $0C: OCRL   $0D: ICRH   $0E: ICRL   $0F: P3CSR');
output.push(';   $10: RMCR   $11: TRCSR  $12: RDR    $13: TDR');
output.push(';   $14: RAMCR');
output.push('; $20: KSC (keyboard scan)  $22: KRTN07  $26: LCD control');
output.push('; $28: KRTN89  $2A: LCD data  $2C: INT mask');
output.push('; $40-$7F: MC146818 RTC');
output.push(';   $4A: RTC_REGA  $4B: RTC_REGB  $4C: RTC_REGC  $4D: RTC_REGD');
output.push('; $80-$FF: Internal RAM');
output.push('; $0100-$3FFF: External RAM (16KB)');
output.push('; $8000-$FFFF: ROM (32KB)');
output.push('');

for (const { name, base } of romFiles) {
  const filePath = path.join(romsDir, name);
  if (!fs.existsSync(filePath)) {
    output.push(`; *** ${name} not found at ${filePath} ***`);
    continue;
  }
  const data = new Uint8Array(fs.readFileSync(filePath));
  output.push('');
  output.push(`; ===========================================`);
  output.push(`; ${name}: $${h4(base)}-$${h4(base + data.length - 1)} (${data.length} bytes)`);
  output.push(`; ===========================================`);
  output.push('');

  const lines = disassembleROM(data, base);
  output.push(...lines);
}

// Write to stdout and also to file
const text = output.join('\n');
process.stdout.write(text + '\n');

// Also write to file
const outPath = path.join(__dirname, '..', 'disasm.txt');
fs.writeFileSync(outPath, text + '\n');
process.stderr.write(`Written to ${outPath}\n`);
