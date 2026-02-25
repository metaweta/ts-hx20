// HD6301/HD6303 Disassembler

type AddrMode = 'INH' | 'IMM8' | 'IMM16' | 'DIR' | 'EXT' | 'IDX' | 'REL'
  | 'AIM_IDX' | 'AIM_DIR' | 'OIM_IDX' | 'OIM_DIR' | 'EIM_IDX' | 'EIM_DIR'
  | 'TIM_IDX' | 'TIM_DIR';

interface OpInfo {
  name: string;
  mode: AddrMode;
}

// Instruction table: opcode → { name, addressing mode }
const OPS: Record<number, OpInfo> = {
  // 0x0_
  0x01: { name: 'NOP',  mode: 'INH' },
  0x04: { name: 'LSRD', mode: 'INH' },
  0x05: { name: 'ASLD', mode: 'INH' },
  0x06: { name: 'TAP',  mode: 'INH' },
  0x07: { name: 'TPA',  mode: 'INH' },
  0x08: { name: 'INX',  mode: 'INH' },
  0x09: { name: 'DEX',  mode: 'INH' },
  0x0A: { name: 'CLV',  mode: 'INH' },
  0x0B: { name: 'SEV',  mode: 'INH' },
  0x0C: { name: 'CLC',  mode: 'INH' },
  0x0D: { name: 'SEC',  mode: 'INH' },
  0x0E: { name: 'CLI',  mode: 'INH' },
  0x0F: { name: 'SEI',  mode: 'INH' },
  // 0x1_
  0x10: { name: 'SBA',  mode: 'INH' },
  0x11: { name: 'CBA',  mode: 'INH' },
  0x16: { name: 'TAB',  mode: 'INH' },
  0x17: { name: 'TBA',  mode: 'INH' },
  0x18: { name: 'XGDX', mode: 'INH' },
  0x19: { name: 'DAA',  mode: 'INH' },
  0x1A: { name: 'SLP',  mode: 'INH' },
  0x1B: { name: 'ABA',  mode: 'INH' },
  // 0x2_ Branches
  0x20: { name: 'BRA',  mode: 'REL' },
  0x21: { name: 'BRN',  mode: 'REL' },
  0x22: { name: 'BHI',  mode: 'REL' },
  0x23: { name: 'BLS',  mode: 'REL' },
  0x24: { name: 'BCC',  mode: 'REL' },
  0x25: { name: 'BCS',  mode: 'REL' },
  0x26: { name: 'BNE',  mode: 'REL' },
  0x27: { name: 'BEQ',  mode: 'REL' },
  0x28: { name: 'BVC',  mode: 'REL' },
  0x29: { name: 'BVS',  mode: 'REL' },
  0x2A: { name: 'BPL',  mode: 'REL' },
  0x2B: { name: 'BMI',  mode: 'REL' },
  0x2C: { name: 'BGE',  mode: 'REL' },
  0x2D: { name: 'BLT',  mode: 'REL' },
  0x2E: { name: 'BGT',  mode: 'REL' },
  0x2F: { name: 'BLE',  mode: 'REL' },
  // 0x3_
  0x30: { name: 'TSX',  mode: 'INH' },
  0x31: { name: 'INS',  mode: 'INH' },
  0x32: { name: 'PULA', mode: 'INH' },
  0x33: { name: 'PULB', mode: 'INH' },
  0x34: { name: 'DES',  mode: 'INH' },
  0x35: { name: 'TXS',  mode: 'INH' },
  0x36: { name: 'PSHA', mode: 'INH' },
  0x37: { name: 'PSHB', mode: 'INH' },
  0x38: { name: 'PULX', mode: 'INH' },
  0x39: { name: 'RTS',  mode: 'INH' },
  0x3A: { name: 'ABX',  mode: 'INH' },
  0x3B: { name: 'RTI',  mode: 'INH' },
  0x3C: { name: 'PSHX', mode: 'INH' },
  0x3D: { name: 'MUL',  mode: 'INH' },
  0x3E: { name: 'WAI',  mode: 'INH' },
  0x3F: { name: 'SWI',  mode: 'INH' },
  // 0x4_ Accumulator A
  0x40: { name: 'NEGA', mode: 'INH' },
  0x43: { name: 'COMA', mode: 'INH' },
  0x44: { name: 'LSRA', mode: 'INH' },
  0x46: { name: 'RORA', mode: 'INH' },
  0x47: { name: 'ASRA', mode: 'INH' },
  0x48: { name: 'ASLA', mode: 'INH' },
  0x49: { name: 'ROLA', mode: 'INH' },
  0x4A: { name: 'DECA', mode: 'INH' },
  0x4C: { name: 'INCA', mode: 'INH' },
  0x4D: { name: 'TSTA', mode: 'INH' },
  0x4F: { name: 'CLRA', mode: 'INH' },
  // 0x5_ Accumulator B
  0x50: { name: 'NEGB', mode: 'INH' },
  0x53: { name: 'COMB', mode: 'INH' },
  0x54: { name: 'LSRB', mode: 'INH' },
  0x56: { name: 'RORB', mode: 'INH' },
  0x57: { name: 'ASRB', mode: 'INH' },
  0x58: { name: 'ASLB', mode: 'INH' },
  0x59: { name: 'ROLB', mode: 'INH' },
  0x5A: { name: 'DECB', mode: 'INH' },
  0x5C: { name: 'INCB', mode: 'INH' },
  0x5D: { name: 'TSTB', mode: 'INH' },
  0x5F: { name: 'CLRB', mode: 'INH' },
  // 0x6_ Indexed + 6301 bit ops (indexed)
  0x60: { name: 'NEG',  mode: 'IDX' },
  0x61: { name: 'AIM',  mode: 'AIM_IDX' },
  0x62: { name: 'OIM',  mode: 'OIM_IDX' },
  0x63: { name: 'COM',  mode: 'IDX' },
  0x64: { name: 'LSR',  mode: 'IDX' },
  0x65: { name: 'EIM',  mode: 'EIM_IDX' },
  0x66: { name: 'ROR',  mode: 'IDX' },
  0x67: { name: 'ASR',  mode: 'IDX' },
  0x68: { name: 'ASL',  mode: 'IDX' },
  0x69: { name: 'ROL',  mode: 'IDX' },
  0x6A: { name: 'DEC',  mode: 'IDX' },
  0x6B: { name: 'TIM',  mode: 'TIM_IDX' },
  0x6C: { name: 'INC',  mode: 'IDX' },
  0x6D: { name: 'TST',  mode: 'IDX' },
  0x6E: { name: 'JMP',  mode: 'IDX' },
  0x6F: { name: 'CLR',  mode: 'IDX' },
  // 0x7_ Extended + 6301 bit ops (direct)
  0x70: { name: 'NEG',  mode: 'EXT' },
  0x71: { name: 'AIM',  mode: 'AIM_DIR' },
  0x72: { name: 'OIM',  mode: 'OIM_DIR' },
  0x73: { name: 'COM',  mode: 'EXT' },
  0x74: { name: 'LSR',  mode: 'EXT' },
  0x75: { name: 'EIM',  mode: 'EIM_DIR' },
  0x76: { name: 'ROR',  mode: 'EXT' },
  0x77: { name: 'ASR',  mode: 'EXT' },
  0x78: { name: 'ASL',  mode: 'EXT' },
  0x79: { name: 'ROL',  mode: 'EXT' },
  0x7A: { name: 'DEC',  mode: 'EXT' },
  0x7B: { name: 'TIM',  mode: 'TIM_DIR' },
  0x7C: { name: 'INC',  mode: 'EXT' },
  0x7D: { name: 'TST',  mode: 'EXT' },
  0x7E: { name: 'JMP',  mode: 'EXT' },
  0x7F: { name: 'CLR',  mode: 'EXT' },
  // 0x8_ Immediate A / 16-bit
  0x80: { name: 'SUBA', mode: 'IMM8' },
  0x81: { name: 'CMPA', mode: 'IMM8' },
  0x82: { name: 'SBCA', mode: 'IMM8' },
  0x83: { name: 'SUBD', mode: 'IMM16' },
  0x84: { name: 'ANDA', mode: 'IMM8' },
  0x85: { name: 'BITA', mode: 'IMM8' },
  0x86: { name: 'LDAA', mode: 'IMM8' },
  0x88: { name: 'EORA', mode: 'IMM8' },
  0x89: { name: 'ADCA', mode: 'IMM8' },
  0x8A: { name: 'ORAA', mode: 'IMM8' },
  0x8B: { name: 'ADDA', mode: 'IMM8' },
  0x8C: { name: 'CPX',  mode: 'IMM16' },
  0x8D: { name: 'BSR',  mode: 'REL' },
  0x8E: { name: 'LDS',  mode: 'IMM16' },
  // 0x9_ Direct A / 16-bit
  0x90: { name: 'SUBA', mode: 'DIR' },
  0x91: { name: 'CMPA', mode: 'DIR' },
  0x92: { name: 'SBCA', mode: 'DIR' },
  0x93: { name: 'SUBD', mode: 'DIR' },
  0x94: { name: 'ANDA', mode: 'DIR' },
  0x95: { name: 'BITA', mode: 'DIR' },
  0x96: { name: 'LDAA', mode: 'DIR' },
  0x97: { name: 'STAA', mode: 'DIR' },
  0x98: { name: 'EORA', mode: 'DIR' },
  0x99: { name: 'ADCA', mode: 'DIR' },
  0x9A: { name: 'ORAA', mode: 'DIR' },
  0x9B: { name: 'ADDA', mode: 'DIR' },
  0x9C: { name: 'CPX',  mode: 'DIR' },
  0x9D: { name: 'JSR',  mode: 'DIR' },
  0x9E: { name: 'LDS',  mode: 'DIR' },
  0x9F: { name: 'STS',  mode: 'DIR' },
  // 0xA_ Indexed A / 16-bit
  0xA0: { name: 'SUBA', mode: 'IDX' },
  0xA1: { name: 'CMPA', mode: 'IDX' },
  0xA2: { name: 'SBCA', mode: 'IDX' },
  0xA3: { name: 'SUBD', mode: 'IDX' },
  0xA4: { name: 'ANDA', mode: 'IDX' },
  0xA5: { name: 'BITA', mode: 'IDX' },
  0xA6: { name: 'LDAA', mode: 'IDX' },
  0xA7: { name: 'STAA', mode: 'IDX' },
  0xA8: { name: 'EORA', mode: 'IDX' },
  0xA9: { name: 'ADCA', mode: 'IDX' },
  0xAA: { name: 'ORAA', mode: 'IDX' },
  0xAB: { name: 'ADDA', mode: 'IDX' },
  0xAC: { name: 'CPX',  mode: 'IDX' },
  0xAD: { name: 'JSR',  mode: 'IDX' },
  0xAE: { name: 'LDS',  mode: 'IDX' },
  0xAF: { name: 'STS',  mode: 'IDX' },
  // 0xB_ Extended A / 16-bit
  0xB0: { name: 'SUBA', mode: 'EXT' },
  0xB1: { name: 'CMPA', mode: 'EXT' },
  0xB2: { name: 'SBCA', mode: 'EXT' },
  0xB3: { name: 'SUBD', mode: 'EXT' },
  0xB4: { name: 'ANDA', mode: 'EXT' },
  0xB5: { name: 'BITA', mode: 'EXT' },
  0xB6: { name: 'LDAA', mode: 'EXT' },
  0xB7: { name: 'STAA', mode: 'EXT' },
  0xB8: { name: 'EORA', mode: 'EXT' },
  0xB9: { name: 'ADCA', mode: 'EXT' },
  0xBA: { name: 'ORAA', mode: 'EXT' },
  0xBB: { name: 'ADDA', mode: 'EXT' },
  0xBC: { name: 'CPX',  mode: 'EXT' },
  0xBD: { name: 'JSR',  mode: 'EXT' },
  0xBE: { name: 'LDS',  mode: 'EXT' },
  0xBF: { name: 'STS',  mode: 'EXT' },
  // 0xC_ Immediate B / 16-bit
  0xC0: { name: 'SUBB', mode: 'IMM8' },
  0xC1: { name: 'CMPB', mode: 'IMM8' },
  0xC2: { name: 'SBCB', mode: 'IMM8' },
  0xC3: { name: 'ADDD', mode: 'IMM16' },
  0xC4: { name: 'ANDB', mode: 'IMM8' },
  0xC5: { name: 'BITB', mode: 'IMM8' },
  0xC6: { name: 'LDAB', mode: 'IMM8' },
  0xC8: { name: 'EORB', mode: 'IMM8' },
  0xC9: { name: 'ADCB', mode: 'IMM8' },
  0xCA: { name: 'ORAB', mode: 'IMM8' },
  0xCB: { name: 'ADDB', mode: 'IMM8' },
  0xCC: { name: 'LDD',  mode: 'IMM16' },
  0xCE: { name: 'LDX',  mode: 'IMM16' },
  // 0xD_ Direct B / 16-bit
  0xD0: { name: 'SUBB', mode: 'DIR' },
  0xD1: { name: 'CMPB', mode: 'DIR' },
  0xD2: { name: 'SBCB', mode: 'DIR' },
  0xD3: { name: 'ADDD', mode: 'DIR' },
  0xD4: { name: 'ANDB', mode: 'DIR' },
  0xD5: { name: 'BITB', mode: 'DIR' },
  0xD6: { name: 'LDAB', mode: 'DIR' },
  0xD7: { name: 'STAB', mode: 'DIR' },
  0xD8: { name: 'EORB', mode: 'DIR' },
  0xD9: { name: 'ADCB', mode: 'DIR' },
  0xDA: { name: 'ORAB', mode: 'DIR' },
  0xDB: { name: 'ADDB', mode: 'DIR' },
  0xDC: { name: 'LDD',  mode: 'DIR' },
  0xDD: { name: 'STD',  mode: 'DIR' },
  0xDE: { name: 'LDX',  mode: 'DIR' },
  0xDF: { name: 'STX',  mode: 'DIR' },
  // 0xE_ Indexed B / 16-bit
  0xE0: { name: 'SUBB', mode: 'IDX' },
  0xE1: { name: 'CMPB', mode: 'IDX' },
  0xE2: { name: 'SBCB', mode: 'IDX' },
  0xE3: { name: 'ADDD', mode: 'IDX' },
  0xE4: { name: 'ANDB', mode: 'IDX' },
  0xE5: { name: 'BITB', mode: 'IDX' },
  0xE6: { name: 'LDAB', mode: 'IDX' },
  0xE7: { name: 'STAB', mode: 'IDX' },
  0xE8: { name: 'EORB', mode: 'IDX' },
  0xE9: { name: 'ADCB', mode: 'IDX' },
  0xEA: { name: 'ORAB', mode: 'IDX' },
  0xEB: { name: 'ADDB', mode: 'IDX' },
  0xEC: { name: 'LDD',  mode: 'IDX' },
  0xED: { name: 'STD',  mode: 'IDX' },
  0xEE: { name: 'LDX',  mode: 'IDX' },
  0xEF: { name: 'STX',  mode: 'IDX' },
  // 0xF_ Extended B / 16-bit
  0xF0: { name: 'SUBB', mode: 'EXT' },
  0xF1: { name: 'CMPB', mode: 'EXT' },
  0xF2: { name: 'SBCB', mode: 'EXT' },
  0xF3: { name: 'ADDD', mode: 'EXT' },
  0xF4: { name: 'ANDB', mode: 'EXT' },
  0xF5: { name: 'BITB', mode: 'EXT' },
  0xF6: { name: 'LDAB', mode: 'EXT' },
  0xF7: { name: 'STAB', mode: 'EXT' },
  0xF8: { name: 'EORB', mode: 'EXT' },
  0xF9: { name: 'ADCB', mode: 'EXT' },
  0xFA: { name: 'ORAB', mode: 'EXT' },
  0xFB: { name: 'ADDB', mode: 'EXT' },
  0xFC: { name: 'LDD',  mode: 'EXT' },
  0xFD: { name: 'STD',  mode: 'EXT' },
  0xFE: { name: 'LDX',  mode: 'EXT' },
  0xFF: { name: 'STX',  mode: 'EXT' },
};

function h2(v: number): string { return v.toString(16).padStart(2, '0'); }
function h4(v: number): string { return v.toString(16).padStart(4, '0'); }

export interface DisasmLine {
  addr: number;
  bytes: number[];
  text: string;
  length: number;
}

export function disassemble(read: (addr: number) => number, startAddr: number, count: number): DisasmLine[] {
  const lines: DisasmLine[] = [];
  let pc = startAddr;

  for (let i = 0; i < count; i++) {
    const addr = pc;
    const opcode = read(pc); pc = (pc + 1) & 0xFFFF;
    const info = OPS[opcode];

    if (!info) {
      lines.push({ addr, bytes: [opcode], text: `???  ($${h2(opcode)})`, length: 1 });
      continue;
    }

    const bytes = [opcode];
    let operand = '';

    switch (info.mode) {
      case 'INH':
        break;
      case 'IMM8': {
        const val = read(pc); pc = (pc + 1) & 0xFFFF;
        bytes.push(val);
        operand = ` #$${h2(val)}`;
        break;
      }
      case 'IMM16': {
        const hi = read(pc); pc = (pc + 1) & 0xFFFF;
        const lo = read(pc); pc = (pc + 1) & 0xFFFF;
        bytes.push(hi, lo);
        operand = ` #$${h4((hi << 8) | lo)}`;
        break;
      }
      case 'DIR': {
        const val = read(pc); pc = (pc + 1) & 0xFFFF;
        bytes.push(val);
        operand = ` $${h2(val)}`;
        break;
      }
      case 'EXT': {
        const hi = read(pc); pc = (pc + 1) & 0xFFFF;
        const lo = read(pc); pc = (pc + 1) & 0xFFFF;
        bytes.push(hi, lo);
        operand = ` $${h4((hi << 8) | lo)}`;
        break;
      }
      case 'IDX': {
        const val = read(pc); pc = (pc + 1) & 0xFFFF;
        bytes.push(val);
        operand = val === 0 ? ' ,X' : ` $${h2(val)},X`;
        break;
      }
      case 'REL': {
        const off = read(pc); pc = (pc + 1) & 0xFFFF;
        bytes.push(off);
        const signed = off > 127 ? off - 256 : off;
        const target = (pc + signed) & 0xFFFF;
        operand = ` $${h4(target)}`;
        break;
      }
      case 'AIM_DIR': case 'OIM_DIR': case 'EIM_DIR': case 'TIM_DIR': {
        const imm = read(pc); pc = (pc + 1) & 0xFFFF;
        const dir = read(pc); pc = (pc + 1) & 0xFFFF;
        bytes.push(imm, dir);
        operand = ` #$${h2(imm)}, $${h2(dir)}`;
        break;
      }
      case 'AIM_IDX': case 'OIM_IDX': case 'EIM_IDX': case 'TIM_IDX': {
        const imm = read(pc); pc = (pc + 1) & 0xFFFF;
        const off = read(pc); pc = (pc + 1) & 0xFFFF;
        bytes.push(imm, off);
        operand = off === 0 ? ` #$${h2(imm)}, ,X` : ` #$${h2(imm)}, $${h2(off)},X`;
        break;
      }
    }

    const bytesStr = bytes.map(b => h2(b)).join(' ');
    const text = `${info.name}${operand}`;
    lines.push({ addr, bytes, text, length: bytes.length });
  }

  return lines;
}

// Format a disassembly line for display
export function formatDisasmLine(line: DisasmLine, marker: string = ''): string {
  const addrStr = h4(line.addr);
  const bytesStr = line.bytes.map(b => h2(b)).join(' ').padEnd(11);
  return `${marker}${addrStr}: ${bytesStr} ${line.text}`;
}
