export function parseIntelHex(hexString: string): { address: number; data: Uint8Array }[] {
  const records: { address: number; data: Uint8Array }[] = [];
  const lines = hexString.split(/\r?\n/);

  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed.startsWith(':')) continue;

    const hex = trimmed.slice(1);
    const byteCount = parseInt(hex.slice(0, 2), 16);
    const address = parseInt(hex.slice(2, 6), 16);
    const recordType = parseInt(hex.slice(6, 8), 16);

    if (recordType === 0x01) break; // EOF
    if (recordType !== 0x00) continue; // Only process data records

    const data = new Uint8Array(byteCount);
    for (let i = 0; i < byteCount; i++) {
      data[i] = parseInt(hex.slice(8 + i * 2, 10 + i * 2), 16);
    }

    records.push({ address, data });
  }

  return records;
}

export function loadIntelHexIntoBuffer(hexString: string, buffer: Uint8Array, baseAddress: number): void {
  const records = parseIntelHex(hexString);
  for (const record of records) {
    const offset = record.address - baseAddress;
    if (offset >= 0 && offset + record.data.length <= buffer.length) {
      buffer.set(record.data, offset);
    }
  }
}

export function loadBinaryIntoBuffer(data: Uint8Array, buffer: Uint8Array, offset: number): void {
  const len = Math.min(data.length, buffer.length - offset);
  buffer.set(data.subarray(0, len), offset);
}

export async function fetchROM(url: string): Promise<string> {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`Failed to fetch ROM: ${url} (${response.status})`);
  return response.text();
}

export async function fetchBinaryROM(url: string): Promise<Uint8Array> {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`Failed to fetch ROM: ${url} (${response.status})`);
  return new Uint8Array(await response.arrayBuffer());
}

const ROM_BASE_URL = 'https://electrickery.hosting.philpem.me.uk/comp/hx20/';

export const ROM_FILES = {
  rom0: { url: ROM_BASE_URL + 'HX20ROM_E000-FFFF.hex', address: 0xE000, size: 0x2000 },
  rom1: { url: ROM_BASE_URL + 'HX20ROM_C000-DFFF.hex', address: 0xC000, size: 0x2000 },
  rom2: { url: ROM_BASE_URL + 'HX20ROM_A000-BFFF.hex', address: 0xA000, size: 0x2000 },
  rom3: { url: ROM_BASE_URL + 'HX20ROM_8000-9FFF.hex', address: 0x8000, size: 0x2000 },
};
