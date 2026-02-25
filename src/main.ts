import './style.css';
import { HX20 } from './hx20';
import { fetchROM, fetchBinaryROM, ROM_FILES } from './rom-loader';
import { disassemble, formatDisasmLine } from './disasm';

const hx20 = new HX20();

// DOM elements
const canvas = document.getElementById('lcd') as HTMLCanvasElement;
const statusText = document.getElementById('status-text')!;
const cpuInfo = document.getElementById('cpu-info')!;
const registersEl = document.getElementById('registers')!;
const disasmEl = document.getElementById('disasm')!;
const keyboardEl = document.getElementById('keyboard')!;

// Debug panel elements
const btnDebugToggle = document.getElementById('btn-debug-toggle')!;
const debugPanel = document.getElementById('debug-panel')!;
const btnStep = document.getElementById('btn-step')!;
const btnRun = document.getElementById('btn-run')!;
const btnPause = document.getElementById('btn-pause')!;

// Control elements
const btnPower = document.getElementById('btn-power')!;
const btnReset = document.getElementById('btn-reset')!;
const btnLoadRom = document.getElementById('btn-load-rom')!;
const romFileInput = document.getElementById('rom-file-input') as HTMLInputElement;
const speedSlider = document.getElementById('speed-slider') as HTMLInputElement;
const speedDisplay = document.getElementById('speed-display')!;

// Attach LCD canvas
hx20.lcd.attachCanvas(canvas);

// Build on-screen keyboard
hx20.keyboard.buildUI(keyboardEl);

// Set DIP switches: USA/English (country=0), no TF-20
hx20.keyboard.setDipSwitches(0, false);

// Status callbacks
hx20.onStatusUpdate = (text: string) => {
  cpuInfo.textContent = text;
};
hx20.onRegistersUpdate = (text: string) => {
  registersEl.textContent = text;
};

// Keyboard input from physical keyboard
document.addEventListener('keydown', (e) => {
  if (e.target instanceof HTMLInputElement) return;
  hx20.keyboard.keyDown(e.code, e.key);
  e.preventDefault();
});

document.addEventListener('keyup', (e) => {
  if (e.target instanceof HTMLInputElement) return;
  hx20.keyboard.keyUp(e.code, e.key);
});

// Debug toggle
btnDebugToggle.addEventListener('click', () => {
  debugPanel.classList.toggle('hidden');
  btnDebugToggle.textContent = debugPanel.classList.contains('hidden') ? 'Show Debug' : 'Hide Debug';
});

// Debug controls
btnStep.addEventListener('click', () => {
  if (hx20.running) hx20.stop();
  hx20.stepOne();
  updateDebugDisplay();
  statusText.textContent = 'Step';
});

// Step N: run N instructions then pause
const stepNInput = document.getElementById('step-n-input') as HTMLInputElement;
const btnStepN = document.getElementById('btn-step-n')!;
if (btnStepN) {
  btnStepN.addEventListener('click', () => {
    if (hx20.running) hx20.stop();
    const n = parseInt(stepNInput?.value || '100') || 100;
    for (let i = 0; i < n; i++) hx20.stepOne();
    updateDebugDisplay();
    statusText.textContent = `Stepped ${n}`;
  });
}

// Breakpoint
const bpInput = document.getElementById('bp-input') as HTMLInputElement;
const btnRunToBP = document.getElementById('btn-run-to-bp')!;
let breakpointAddr = -1;
if (btnRunToBP) {
  btnRunToBP.addEventListener('click', () => {
    if (hx20.running) hx20.stop();
    const val = bpInput?.value?.trim() || '';
    breakpointAddr = parseInt(val, 16);
    if (isNaN(breakpointAddr)) {
      statusText.textContent = 'Invalid breakpoint address';
      return;
    }
    statusText.textContent = `Running to $${breakpointAddr.toString(16).padStart(4, '0')}...`;
    // Run up to 10M instructions looking for breakpoint
    const maxSteps = 10_000_000;
    for (let i = 0; i < maxSteps; i++) {
      if (hx20.mainCPU.PC === breakpointAddr) {
        statusText.textContent = `BP hit at $${breakpointAddr.toString(16).padStart(4, '0')} after ${i} steps`;
        updateDebugDisplay();
        return;
      }
      hx20.stepOne();
    }
    statusText.textContent = `BP $${breakpointAddr.toString(16).padStart(4, '0')} not hit in ${maxSteps} steps`;
    updateDebugDisplay();
  });
}

btnRun.addEventListener('click', () => {
  if (!hx20.isROMLoaded()) {
    statusText.textContent = 'Load ROMs first!';
    return;
  }
  hx20.start();
  statusText.textContent = 'Running';
  btnPower.classList.add('active');
});

btnPause.addEventListener('click', () => {
  hx20.stop();
  statusText.textContent = 'Paused';
  updateDebugDisplay();
});

// Battery-backed RAM persistence
const RAM_STORAGE_KEY = 'hx20-ram';
let ramSaveTimer: ReturnType<typeof setInterval> | null = null;

function saveRAM(): void {
  const binary = String.fromCharCode(...hx20.mainRAM);
  localStorage.setItem(RAM_STORAGE_KEY, btoa(binary));
}

function restoreRAM(): boolean {
  const data = localStorage.getItem(RAM_STORAGE_KEY);
  if (!data) return false;
  const binary = atob(data);
  for (let i = 0; i < binary.length; i++) {
    hx20.mainRAM[i] = binary.charCodeAt(i);
  }
  return true;
}

function startAutoSave(): void {
  if (ramSaveTimer) return;
  ramSaveTimer = setInterval(saveRAM, 5000);
}

function stopAutoSave(): void {
  if (ramSaveTimer) {
    clearInterval(ramSaveTimer);
    ramSaveTimer = null;
  }
}

const btnSave = document.getElementById('btn-save')!;
const btnLoad = document.getElementById('btn-load')!;

btnSave.addEventListener('click', () => {
  if (!powered) {
    statusText.textContent = 'Power on first';
    return;
  }
  saveRAM();
  statusText.textContent = 'RAM saved';
});

btnLoad.addEventListener('click', () => {
  if (!powered) {
    statusText.textContent = 'Power on first';
    return;
  }
  if (restoreRAM()) {
    statusText.textContent = 'RAM loaded';
  } else {
    statusText.textContent = 'No saved RAM found';
  }
});

// Speed control
speedSlider.addEventListener('input', () => {
  const val = parseInt(speedSlider.value);
  hx20.speedMultiplier = val;
  speedDisplay.textContent = `${val}x`;
});

// Power button
let powered = false;
btnPower.addEventListener('click', () => {
  if (!powered) {
    if (!hx20.isROMLoaded()) {
      statusText.textContent = 'Load ROMs first!';
      return;
    }
    powered = true;
    // Warm boot if saved RAM exists (emulates battery-backed RAM)
    const warm = restoreRAM();
    hx20.reset(!warm);
    hx20.start();
    startAutoSave();
    statusText.textContent = warm ? 'Running (RAM restored)' : 'Running';
    btnPower.classList.add('active');
  } else {
    powered = false;
    stopAutoSave();
    saveRAM();
    hx20.stop();
    statusText.textContent = 'Power Off (RAM saved)';
    btnPower.classList.remove('active');
  }
});

// Reset button (warm reset — preserves RAM like real hardware)
btnReset.addEventListener('click', () => {
  if (powered) {
    hx20.stop();
    hx20.reset(false);
    hx20.start();
    statusText.textContent = 'Reset - Running';
  }
});

// Load ROM button
btnLoadRom.addEventListener('click', async () => {
  statusText.textContent = 'Loading ROMs...';
  try {
    await loadLocalROMs();
    statusText.textContent = 'ROMs loaded! Press POWER to start';
  } catch (e) {
    console.warn('Local ROMs not found, trying web fetch...', e);
    try {
      await loadROMsFromWeb();
      statusText.textContent = 'ROMs loaded from web! Press POWER to start';
    } catch (e2) {
      console.error('All ROM loading failed:', e2);
      statusText.textContent = 'Auto-load failed - select ROM files manually';
      romFileInput.click();
    }
  }
});

// File input for manual ROM loading
romFileInput.addEventListener('change', async () => {
  const files = romFileInput.files;
  if (!files || files.length === 0) return;

  statusText.textContent = 'Loading ROM files...';
  let loaded = 0;

  for (const file of Array.from(files)) {
    const name = file.name.toLowerCase();

    if (name.endsWith('.hex')) {
      const text = await file.text();
      if (name.includes('e000') || name.includes('ffff') || name.includes('15e')) {
        hx20.loadROMHex(text, 0xE000); loaded++;
      } else if (name.includes('c000') || name.includes('dfff') || name.includes('14e')) {
        hx20.loadROMHex(text, 0xC000); loaded++;
      } else if (name.includes('a000') || name.includes('bfff') || name.includes('13e')) {
        hx20.loadROMHex(text, 0xA000); loaded++;
      } else if (name.includes('8000') || name.includes('9fff') || name.includes('12e')) {
        hx20.loadROMHex(text, 0x8000); loaded++;
      }
    } else if (name.endsWith('.bin') || name.endsWith('.rom')) {
      const data = new Uint8Array(await file.arrayBuffer());
      if (data.length === 0x1000 || name.includes('slave') || name.includes('secondary') || name.includes('6301')) {
        hx20.loadSlaveROM(data); loaded++;
      } else if (data.length === 0x8000) {
        hx20.mainROM.set(data); loaded++;
      } else if (data.length === 0x2000) {
        // Try to determine position from filename
        if (name.includes('rom0') || name.includes('e000')) {
          hx20.loadMainROMBinary(data, 0x6000); loaded++;
        } else if (name.includes('rom1') || name.includes('c000')) {
          hx20.loadMainROMBinary(data, 0x4000); loaded++;
        } else if (name.includes('rom2') || name.includes('a000')) {
          hx20.loadMainROMBinary(data, 0x2000); loaded++;
        } else if (name.includes('rom3') || name.includes('8000')) {
          hx20.loadMainROMBinary(data, 0x0000); loaded++;
        }
      }
    }
  }

  statusText.textContent = `Loaded ${loaded} ROM file(s). Press POWER to start`;
  romFileInput.value = '';
});

// Load binary ROMs from local public/roms/ directory
async function loadLocalROMs(): Promise<void> {
  const [rom0, rom1, rom2, rom3, slave] = await Promise.all([
    fetchBinaryROM('/roms/rom0.bin'),
    fetchBinaryROM('/roms/rom1.bin'),
    fetchBinaryROM('/roms/rom2.bin'),
    fetchBinaryROM('/roms/rom3.bin'),
    fetchBinaryROM('/roms/secondary.bin'),
  ]);

  // ROM layout in mainROM buffer (0x8000 bytes for addresses 0x8000-0xFFFF):
  // rom3 = 0x8000-0x9FFF → offset 0x0000
  // rom2 = 0xA000-0xBFFF → offset 0x2000
  // rom1 = 0xC000-0xDFFF → offset 0x4000
  // rom0 = 0xE000-0xFFFF → offset 0x6000
  hx20.loadMainROMBinary(rom3, 0x0000);
  hx20.loadMainROMBinary(rom2, 0x2000);
  hx20.loadMainROMBinary(rom1, 0x4000);
  hx20.loadMainROMBinary(rom0, 0x6000);
  hx20.loadSlaveROM(slave);

  console.log('Local ROMs loaded. Reset vector:',
    hx20.mainROM[0x7FFE].toString(16).padStart(2, '0') +
    hx20.mainROM[0x7FFF].toString(16).padStart(2, '0'));
}

// Load Intel HEX ROMs from electrickery website
async function loadROMsFromWeb(): Promise<void> {
  const entries = Object.entries(ROM_FILES) as [string, { url: string; address: number; size: number }][];
  const results = await Promise.all(
    entries.map(async ([_name, info]) => {
      const hex = await fetchROM(info.url);
      return { hex, address: info.address };
    })
  );
  for (const { hex, address } of results) {
    hx20.loadROMHex(hex, address);
  }
}

function updateDebugDisplay(): void {
  registersEl.textContent = hx20.mainCPU.dumpRegisters();

  const lines = disassemble(
    (addr: number) => hx20.mainCPU.read(addr),
    hx20.mainCPU.PC,
    16
  );
  disasmEl.textContent = lines.map((line, i) =>
    formatDisasmLine(line, i === 0 ? '> ' : '  ')
  ).join('\n');
}

// Auto-load local ROMs on startup
statusText.textContent = 'Loading ROMs...';
loadLocalROMs().then(() => {
  statusText.textContent = 'ROMs loaded! Press POWER to start';
}).catch(() => {
  statusText.textContent = 'Click LOAD ROMs to fetch, or select ROM files manually';
});
