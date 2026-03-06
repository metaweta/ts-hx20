import './style.css';
import { HX20 } from './hx20';
import { Cassette } from './cassette';
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
const ramSelect = document.getElementById('ram-select') as HTMLSelectElement;

// CRT display panel
const btnCrtToggle = document.getElementById('btn-crt-toggle')!;
const crtPanel = document.getElementById('crt-panel')!;
const crtCanvas = document.getElementById('crt-canvas') as HTMLCanvasElement;

// Cassette panel elements are wired below via wireCassettePanel()

// Attach LCD canvas
hx20.lcd.attachCanvas(canvas);

// Attach CRT canvas
hx20.epspDisplay.attachCanvas(crtCanvas);

// Build on-screen keyboard
hx20.keyboard.buildUI(keyboardEl);

// DIP switches are set by the panel restore block (updateDipSW4) below

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
  // Let Cmd/Ctrl+V pass through so the browser paste event fires
  if (e.metaKey) return;
  if (e.ctrlKey && e.code === 'KeyV') return;
  // Escape cancels an in-progress paste
  if (e.code === 'Escape' && hx20.keyboard.isPasting) {
    hx20.keyboard.cancelPaste();
    statusText.textContent = 'Paste cancelled';
    e.preventDefault();
    return;
  }
  hx20.keyboard.keyDown(e.code, e.key);
  e.preventDefault();
});

// Paste: Cmd+V / Ctrl+V feeds clipboard text into the keyboard matrix
document.addEventListener('paste', (e) => {
  if (e.target instanceof HTMLInputElement || e.target instanceof HTMLTextAreaElement) return;
  e.preventDefault();
  const text = e.clipboardData?.getData('text');
  if (text) {
    hx20.keyboard.typeText(text);
    statusText.textContent = `Pasting ${text.length} chars...`;
    hx20.keyboard.onPasteFinish = () => { statusText.textContent = 'Paste complete'; };
  }
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

// Printer panel
const btnPrinterToggle = document.getElementById('btn-printer-toggle')!;
const printerPanel = document.getElementById('printer-panel')!;
const printerPaper = document.getElementById('printer-paper')!;
const printerCanvas = document.getElementById('printer-canvas') as HTMLCanvasElement;
const btnPrinterFeed = document.getElementById('btn-printer-feed')!;
const btnPrinterTear = document.getElementById('btn-printer-tear')!;
const btnPrinterCopy = document.getElementById('btn-printer-copy')!;

hx20.printer.attachCanvas(printerCanvas, printerPaper);

btnPrinterToggle.addEventListener('click', () => {
  printerPanel.classList.toggle('hidden');
});

btnPrinterFeed.addEventListener('click', () => {
  hx20.printer.feed();
});

btnPrinterTear.addEventListener('click', () => {
  hx20.printer.clear();
  statusText.textContent = 'Paper torn off';
});

btnPrinterCopy.addEventListener('click', async () => {
  try {
    await hx20.printer.copyAsImage();
    statusText.textContent = 'Printer image copied';
  } catch {
    statusText.textContent = 'Clipboard access denied';
  }
});

// DISK panel elements (declared early so updateDipSW4 can reference them)
const btnDiskToggle = document.getElementById('btn-disk-toggle')!;
const diskPanel = document.getElementById('disk-panel')!;
const diskFileListA = document.getElementById('disk-file-list-a')!;
const diskFileListB = document.getElementById('disk-file-list-b')!;
const diskFileInputA = document.getElementById('disk-file-input-a') as HTMLInputElement;
const diskFileInputB = document.getElementById('disk-file-input-b') as HTMLInputElement;

// DIP SW4 management — both CRT and DISK need it enabled
// Persist panel state so DIP switches survive page reload
const PANELS_STORAGE_KEY = 'hx20-panels';
function updateDipSW4(): void {
  const crtOpen = !crtPanel.classList.contains('hidden');
  const diskOpen = !diskPanel.classList.contains('hidden');
  hx20.keyboard.setDipSwitches(0, crtOpen || diskOpen);
  localStorage.setItem(PANELS_STORAGE_KEY, JSON.stringify({ crt: crtOpen, disk: diskOpen }));
}

// Restore panel state from localStorage (before any boot/reset)
try {
  const panels = JSON.parse(localStorage.getItem(PANELS_STORAGE_KEY) || '{}');
  if (panels.crt) crtPanel.classList.remove('hidden');
  if (panels.disk) diskPanel.classList.remove('hidden');
} catch { /* ignore */ }
updateDipSW4();

// CRT toggle — opening the CRT panel enables DIP SW4 (TF-20 mode)
btnCrtToggle.addEventListener('click', () => {
  const wasHidden = crtPanel.classList.contains('hidden');
  crtPanel.classList.toggle('hidden');
  updateDipSW4();
  if (wasHidden && hx20.isROMLoaded()) {
    statusText.textContent = 'CRT enabled — reset required for SCREEN 1';
  }
});

// DISK toggle
btnDiskToggle.addEventListener('click', () => {
  const wasHidden = diskPanel.classList.contains('hidden');
  diskPanel.classList.toggle('hidden');
  updateDipSW4();
  if (wasHidden) {
    renderDiskFileList();
    if (hx20.isROMLoaded()) {
      statusText.textContent = 'TF-20 enabled — reset required for Disk BASIC';
    }
  }
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
  startAutoSave();
  statusText.textContent = 'Running';
  btnPower.classList.add('active');
});

btnPause.addEventListener('click', () => {
  hx20.stop();
  statusText.textContent = 'Paused';
  updateDebugDisplay();
});

// Machine state persistence
const STATE_STORAGE_KEY = 'hx20-state';
let autoSaveTimer: ReturnType<typeof setInterval> | null = null;

function saveSnapshot(): void {
  try {
    localStorage.setItem(STATE_STORAGE_KEY, hx20.saveState());
  } catch (e) {
    console.warn('Failed to save state:', e);
  }
}

function startAutoSave(): void {
  if (autoSaveTimer) return;
  autoSaveTimer = setInterval(saveSnapshot, 5000);
}

function stopAutoSave(): void {
  if (autoSaveTimer) {
    clearInterval(autoSaveTimer);
    autoSaveTimer = null;
  }
}

// --- Save/Load state to file ---
const btnSaveState = document.getElementById('btn-save-state')!;
const btnLoadState = document.getElementById('btn-load-state')!;
const stateFileInput = document.getElementById('state-file-input') as HTMLInputElement;

btnSaveState.addEventListener('click', () => {
  const json = hx20.saveState();
  const blob = new Blob([json], { type: 'application/json' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = `hx20-state-${new Date().toISOString().slice(0, 19).replace(/[T:]/g, '-')}.json`;
  a.click();
  URL.revokeObjectURL(a.href);
  statusText.textContent = 'State saved to file';
});

btnLoadState.addEventListener('click', () => stateFileInput.click());
stateFileInput.addEventListener('change', async () => {
  const file = stateFileInput.files?.[0];
  if (!file) return;
  try {
    const json = await file.text();
    hx20.stop();
    hx20.loadState(json);
    hx20.lcd.render();
    hx20.start();
    startAutoSave();
    statusText.textContent = `State loaded: ${file.name}`;
    btnPower.classList.add('active');
  } catch (e) {
    statusText.textContent = `Failed to load state: ${e}`;
  }
  stateFileInput.value = '';
});

// Speed control
speedSlider.addEventListener('input', () => {
  const val = parseInt(speedSlider.value);
  hx20.speedMultiplier = val;
  speedDisplay.textContent = `${val}x`;
});

// --- GET LIST / PUT LIST ---
const btnGetList = document.getElementById('btn-get-list')!;
const btnPutList = document.getElementById('btn-put-list')!;
const listFileInput = document.getElementById('list-file-input') as HTMLInputElement;

btnGetList.addEventListener('click', () => {
  const listing = hx20.getBasicListing();
  if (!listing) {
    statusText.textContent = 'No BASIC program in memory';
    return;
  }
  const blob = new Blob([listing], { type: 'text/plain' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = 'program.bas';
  a.click();
  URL.revokeObjectURL(a.href);
  statusText.textContent = `Downloaded listing (${listing.split('\n').length - 1} lines)`;
});

btnPutList.addEventListener('click', () => listFileInput.click());
listFileInput.addEventListener('change', async () => {
  const file = listFileInput.files?.[0];
  if (!file) return;
  const text = await file.text();
  if (!text.trim()) {
    statusText.textContent = 'Empty file';
    listFileInput.value = '';
    return;
  }
  hx20.keyboard.typeText('NEW\n' + text);
  statusText.textContent = `Loading ${file.name} (${text.length} chars)...`;
  hx20.keyboard.onPasteFinish = () => { statusText.textContent = `${file.name} loaded`; };
  listFileInput.value = '';
});

// --- Paste button ---
const btnPaste = document.getElementById('btn-paste')!;
btnPaste.addEventListener('click', async () => {
  try {
    const text = await navigator.clipboard.readText();
    if (text) {
      hx20.keyboard.typeText(text);
      statusText.textContent = `Pasting ${text.length} chars...`;
      hx20.keyboard.onPasteFinish = () => { statusText.textContent = 'Paste complete'; };
    }
  } catch {
    statusText.textContent = 'Clipboard access denied — use Cmd+V instead';
  }
});

// --- RAM expansion ---
const RAM_STORAGE_KEY = 'hx20-ram-banks';

function applyRAMConfig(): void {
  const banks = parseInt(ramSelect.value, 10) || 0;
  hx20.setExpansionRAM(banks);
}

// Restore saved RAM config
const savedBanks = localStorage.getItem(RAM_STORAGE_KEY);
if (savedBanks && ramSelect.querySelector(`option[value="${savedBanks}"]`)) {
  ramSelect.value = savedBanks;
}
applyRAMConfig();

ramSelect.addEventListener('change', () => {
  localStorage.setItem(RAM_STORAGE_KEY, ramSelect.value);
  applyRAMConfig();
  if (hx20.isROMLoaded()) {
    hx20.stop();
    updateDipSW4();
    hx20.reset();
    hx20.start();
    startAutoSave();
    statusText.textContent = `RAM: ${ramSelect.options[ramSelect.selectedIndex].text} — Reset`;
  }
});

// --- Cassette UI ---

function wireCassettePanel(cas: Cassette, ids: {
  toggle: string; panel: string; motor: string; current: string;
  tapeList: string; btnNew: string; btnEject: string; btnImport: string;
  fileInput: string; btnRewind?: string;
}): void {
  const toggleBtn = document.getElementById(ids.toggle)!;
  const panel = document.getElementById(ids.panel)!;
  const motorEl = document.getElementById(ids.motor)!;
  const currentEl = document.getElementById(ids.current)!;
  const tapeListEl = document.getElementById(ids.tapeList)!;
  const btnNew = document.getElementById(ids.btnNew)!;
  const btnEject = document.getElementById(ids.btnEject)!;
  const btnImport = document.getElementById(ids.btnImport)!;
  const fileInput = document.getElementById(ids.fileInput) as HTMLInputElement;
  const btnRewind = ids.btnRewind ? document.getElementById(ids.btnRewind) : null;

  toggleBtn.addEventListener('click', () => panel.classList.toggle('hidden'));

  function updateList(): void {
    const names = cas.getTapeNames();
    const current = cas.getCurrentTape();
    currentEl.textContent = current ? `Loaded: ${current}` : 'No tape loaded';

    tapeListEl.innerHTML = '';
    for (const name of names) {
      const row = document.createElement('div');
      row.className = 'tape-entry';

      const btn = document.createElement('button');
      btn.textContent = name;
      btn.className = 'tape-name' + (name === current ? ' tape-active' : '');
      btn.addEventListener('click', () => { cas.insertTape(name); updateList(); });

      const dlBtn = document.createElement('button');
      dlBtn.textContent = 'DL';
      dlBtn.className = 'tape-action';
      dlBtn.title = 'Download tape';
      dlBtn.addEventListener('click', () => {
        const json = cas.exportTape(name);
        if (!json) return;
        const blob = new Blob([json], { type: 'application/json' });
        const a = document.createElement('a');
        a.href = URL.createObjectURL(blob);
        a.download = `${name}.json`;
        a.click();
        URL.revokeObjectURL(a.href);
      });

      const delBtn = document.createElement('button');
      delBtn.textContent = '\u00D7';
      delBtn.className = 'tape-action tape-delete';
      delBtn.title = 'Delete tape';
      delBtn.addEventListener('click', () => cas.deleteTape(name));

      row.appendChild(btn);
      row.appendChild(dlBtn);
      row.appendChild(delBtn);
      tapeListEl.appendChild(row);
    }
  }

  cas.onLibraryChange = updateList;
  cas.onMotorChange = (on: boolean) => { motorEl.textContent = on ? '[MOTOR]' : ''; };

  btnNew.addEventListener('click', () => {
    const name = cas.insertBlank();
    updateList();
    statusText.textContent = `Blank tape: ${name}`;
  });

  btnEject.addEventListener('click', () => { cas.ejectTape(); updateList(); });

  btnImport.addEventListener('click', () => fileInput.click());
  fileInput.addEventListener('change', async () => {
    const file = fileInput.files?.[0];
    if (!file) return;
    const json = await file.text();
    const name = cas.importTape(json);
    if (name) {
      cas.insertTape(name);
      updateList();
      statusText.textContent = `Imported tape: ${name}`;
    } else {
      statusText.textContent = 'Failed to import tape';
    }
    fileInput.value = '';
  });

  if (btnRewind) {
    btnRewind.addEventListener('click', () => { cas.rewind(); statusText.textContent = 'Tape rewound'; });
  }

  updateList();
}

wireCassettePanel(hx20.cas0, {
  toggle: 'btn-cas0-toggle', panel: 'cas0-panel', motor: 'cas0-motor',
  current: 'cas0-current', tapeList: 'cas0-tape-list', btnNew: 'btn-cas0-new',
  btnEject: 'btn-cas0-eject', btnImport: 'btn-cas0-import', fileInput: 'cas0-file-input',
});

wireCassettePanel(hx20.cas1, {
  toggle: 'btn-cas1-toggle', panel: 'cas1-panel', motor: 'cas1-motor',
  current: 'cas1-current', tapeList: 'cas1-tape-list', btnNew: 'btn-cas1-new',
  btnEject: 'btn-cas1-eject', btnImport: 'btn-cas1-import', fileInput: 'cas1-file-input',
  btnRewind: 'btn-cas1-rewind',
});

// --- TF-20 Disk Panel ---

function renderDriveFileList(drive: string, listEl: HTMLElement): void {
  const files = hx20.tf20.getFileList().filter(f => f.drive === drive);
  listEl.innerHTML = '';
  if (files.length === 0) {
    listEl.innerHTML = '<div class="tape-entry">No files</div>';
    return;
  }
  for (const file of files) {
    const entry = document.createElement('div');
    entry.className = 'tape-entry';
    const info = document.createElement('span');
    info.className = 'tape-info';
    info.textContent = `${file.name} (${file.size} bytes)`;
    const actions = document.createElement('span');
    actions.className = 'tape-actions';
    const btnDl = document.createElement('button');
    btnDl.textContent = 'Download';
    btnDl.addEventListener('click', () => {
      const data = hx20.tf20.exportFile(file.name, drive);
      if (data) {
        const blob = new Blob([data.buffer as ArrayBuffer], { type: 'application/octet-stream' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = file.name;
        a.click();
        URL.revokeObjectURL(url);
      }
    });
    const btnDel = document.createElement('button');
    btnDel.textContent = 'Delete';
    btnDel.addEventListener('click', () => {
      hx20.tf20.deleteFileByName(file.name, drive);
      renderDiskFileList();
    });
    actions.append(btnDl, btnDel);
    entry.append(info, actions);
    listEl.appendChild(entry);
  }
}

function renderDiskFileList(): void {
  renderDriveFileList('A', diskFileListA);
  renderDriveFileList('B', diskFileListB);
}

// Auto-refresh disk file list when files change
hx20.tf20.onFileChange = () => {
  if (!diskPanel.classList.contains('hidden')) {
    renderDiskFileList();
  }
};

// Wire import/format for each drive
function wireDiskDrive(drive: string, btnImportId: string, btnFormatId: string, fileInput: HTMLInputElement): void {
  document.getElementById(btnImportId)!.addEventListener('click', () => fileInput.click());
  fileInput.addEventListener('change', () => {
    const files = fileInput.files;
    if (!files) return;
    for (const file of Array.from(files)) {
      file.arrayBuffer().then(buf => {
        hx20.tf20.importFile(file.name, new Uint8Array(buf), drive);
        renderDiskFileList();
      });
    }
    fileInput.value = '';
  });
  document.getElementById(btnFormatId)!.addEventListener('click', () => {
    if (confirm(`Erase all files on drive ${drive}:?`)) {
      hx20.tf20.formatDisk(drive);
      renderDiskFileList();
      statusText.textContent = `Drive ${drive}: formatted`;
    }
  });
}

wireDiskDrive('A', 'btn-disk-import-a', 'btn-disk-format-a', diskFileInputA);
wireDiskDrive('B', 'btn-disk-import-b', 'btn-disk-format-b', diskFileInputB);

// Debug: expose hx20 for console access
(window as any).hx20 = hx20;

// Power button — always cold boots (fresh start)
btnPower.addEventListener('click', () => {
  if (!hx20.isROMLoaded()) {
    statusText.textContent = 'Load ROMs first!';
    return;
  }
  hx20.stop();
  updateDipSW4(); // ensure DIP switches reflect panel state before boot
  hx20.reset();
  hx20.start();
  startAutoSave();
  statusText.textContent = 'Running';
  btnPower.classList.add('active');
});

// Reset button
btnReset.addEventListener('click', () => {
  if (!hx20.isROMLoaded()) return;
  hx20.stop();
  updateDipSW4(); // ensure DIP switches reflect panel state before boot
  hx20.reset();
  hx20.start();
  statusText.textContent = 'Reset - Running';
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
    fetchBinaryROM(import.meta.env.BASE_URL + 'roms/rom0.bin'),
    fetchBinaryROM(import.meta.env.BASE_URL + 'roms/rom1.bin'),
    fetchBinaryROM(import.meta.env.BASE_URL + 'roms/rom2.bin'),
    fetchBinaryROM(import.meta.env.BASE_URL + 'roms/rom3.bin'),
    fetchBinaryROM(import.meta.env.BASE_URL + 'roms/secondary.bin'),
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

// Fresh boot: load ROMs and cold start
function freshBoot(): void {
  statusText.textContent = 'Loading ROMs...';
  loadLocalROMs().then(() => {
    updateDipSW4(); // ensure DIP switches reflect panel state before boot
    hx20.reset();
    hx20.start();
    startAutoSave();
    statusText.textContent = 'Running';
    btnPower.classList.add('active');
  }).catch(() => {
    statusText.textContent = 'Click LOAD ROMs to fetch, or select ROM files manually';
  });
}

// Startup: restore saved state if available, otherwise cold boot
const savedState = localStorage.getItem(STATE_STORAGE_KEY);
if (savedState) {
  // Resume from snapshot — no ROM loading or boot needed
  try {
    hx20.loadState(savedState);
    hx20.lcd.render();
    hx20.start();
    startAutoSave();
    statusText.textContent = 'Resumed';
    btnPower.classList.add('active');
  } catch (e) {
    console.warn('State incompatible or corrupted, fresh boot:', e);
    localStorage.removeItem(STATE_STORAGE_KEY);
    freshBoot();
  }
} else {
  freshBoot();
}
