# HX-20 Emulator — Microcassette SAVE/LOAD Work In Progress

## Current Task: Fix SAVE "CAS0:TEST" — IO Error

The emulator now runs both real CPUs (main HD6303R + slave HD6301V1) with SCI serial communication between them. The slave CPU ROM handles all protocols natively. The cassette hardware (motor, FSK recording via output compare on P21, cassette controller IC bit-bang protocol) is wired up.

### What Works
- Boot sequence completes with real slave CPU (FakeSecondary removed)
- Keyboard and LCD work through slave CPU
- SCI serial between CPUs: proper TX timing (160-cycle delay), SCI overrun model (shift register + RDR double buffering), RDRF two-step clearing
- Cassette controller bit-bang protocol: slave sends 8-bit commands via P43/P44, we decode and acknowledge via P46
- Motor control: 0x81 (record) / 0x82 (play) / 0x00 (stop) commands handled
- FSK recording: P21 output compare transitions captured as [cycle, level] pairs
- Tape library with localStorage persistence

### What's Broken
- `SAVE "CAS0:TEST"` returns IO Error after completing the data transfer phase
- The SAVE protocol runs much further than before: command setup (0x50, 0x7c, 0x64), cassette motor start (0x81), data transfer (bytes sent at e7da/e7dd, slave ACKs with 0x61), cleanup (0x48, 0x7d, 0x77)
- After data transfer, the slave enters a loop at FE03 sending 0x61 ACKs for every byte the master sends
- Eventually the slave sends 0x01 (completion?), then IO Error appears

### Key Observations from Latest Trace
1. The data phase works — master sends program bytes (ASCII: `0x48 0x44 0x52 0x31` = "HDR1", filename, size, etc.), slave ACKs each with 0x61
2. After data, master sends many 0x00 bytes, slave keeps ACKing with 0x61
3. Then master sends 0x48 (fire-and-forget) + 0x7d (cleanup), gets 0x61 ACK
4. Then 0x77 cleanup, gets 0x61 ACK
5. Slave continues in loop at FE03 sending 0x61 for every incoming byte
6. Eventually slave sends 0x01 from F059 — this may be the session end signal
7. IO Error occurs after this

### Likely Root Causes to Investigate
- **FSK data not actually being written to tape**: The slave may check that data was written correctly. Need to verify the output compare (P21) FSK transitions are being generated at correct frequency
- **Cassette controller timing**: The P46 acknowledgment timing may be wrong — too fast or too slow
- **Missing tape status feedback**: P40 (tape running) or other status bits may not match what the ROM expects
- **Data phase protocol mismatch**: The slave at FE03 may be expecting different data framing than what the master sends

### Architecture Notes
- Main CPU: HD6303R, 32KB ROM (0x8000-0xFFFF), 16KB RAM
- Slave CPU: HD6301V1, 4KB internal ROM (0xF000-0xFFFF)
- SCI: 38400 baud (E clock / 16 = 614400/16 ≈ 38400), ~160 cycles per byte
- Cassette FSK: 1KHz = ON (1), 2KHz = OFF (0), ~1300 bps via output compare on P21
- Cassette controller: bit-bang serial on P43(data)/P44(clock), ack on P46, status on P40

### Key ROM Addresses
- **Master**: E403 (SCI send-receive), E466 (fire-and-forget send), E7DA/E7DD (data send loop), EE7D (SCI write within data loop), EE2A (RDR read)
- **Slave**: F059 (command dispatcher), F10A (SCI transact), F148/F14B (SCI send), FBFA (bit-bang controller), FCE8 (SAVE handler), FD89 (data phase), FE03 (data receive loop)

### Debug Tools
- `hx20.sciDebug = true` in browser console enables SCI trace logging
- `window.hx20` exposed for console access
- `scripts/disasm-rom.ts` for offline ROM disassembly
