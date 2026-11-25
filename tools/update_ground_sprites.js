const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const OUT = path.join(__dirname, '..', 'assets', 'images');

function crc32(buf) {
  let c, crc = 0xffffffff;
  for (let n = 0; n < buf.length; n++) {
    c = (crc ^ buf[n]) & 0xff;
    for (let k = 0; k < 8; k++) c = (c >>> 1) ^ (c & 1 ? 0xedb88320 : 0);
    crc = (crc >>> 8) ^ c;
  }
  return (crc ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const b = Buffer.alloc(12 + data.length);
  b.writeUInt32BE(data.length, 0);
  b.write(type, 4, 4, 'ascii');
  data.copy(b, 8);
  b.writeUInt32BE(crc32(b.slice(4, 8 + data.length)), 8 + data.length);
  return b;
}
function png(name, w, h, pixelFn) {
  const rows = [];
  for (let y = 0; y < h; y++) {
    const row = Buffer.alloc(1 + w * 4);
    for (let x = 0; x < w; x++) {
      const c = pixelFn(x + 0.5, y + 0.5);
      if (c && c[3] > 0) {
        const i = 1 + x * 4;
        row[i] = Math.round(Math.max(0, Math.min(1, c[0])) * 255);
        row[i + 1] = Math.round(Math.max(0, Math.min(1, c[1])) * 255);
        row[i + 2] = Math.round(Math.max(0, Math.min(1, c[2])) * 255);
        row[i + 3] = Math.round(Math.max(0, Math.min(1, c[3])) * 255);
      }
    }
    rows.push(row);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; ihdr[9] = 6;
  const raw = Buffer.concat(rows);
  const idat = zlib.deflateSync(raw, { level: 9 });
  fs.writeFileSync(path.join(OUT, name + '.png'), Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr), chunk('IDAT', idat), chunk('IEND', Buffer.alloc(0))
  ]));
}
function rrect(x, y, x0, y0, x1, y1, r) {
  const cx = Math.max(x0 + r, Math.min(x1 - r, x));
  const cy = Math.max(y0 + r, Math.min(y1 - r, y));
  return Math.hypot(x - cx, y - cy) - r;
}
function circle(x, y, cx, cy, r) { return Math.hypot(x - cx, y - cy) - r; }
function lerp(a, b, t) { return a + (b - a) * Math.max(0, Math.min(1, t)); }
function hex(s) {
  return [parseInt(s.slice(0, 2), 16) / 255, parseInt(s.slice(2, 4), 16) / 255, parseInt(s.slice(4, 6), 16) / 255];
}
function lerpColor(c1, c2, t) { return [lerp(c1[0], c2[0], t), lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t), 1]; }

// 1. Clean outlined bays matching Bus Fever Party reference
png('slot', 32, 96, (x, y) => {
  const d = rrect(x, y, 2, 2, 30, 94, 7);
  if (d > 0) return null;
  if (y > 89 && Math.abs(x - 16) < 6) return null; // open entry gate at bottom
  if (d > -2.4) return [0.90, 0.94, 0.98, 0.92];
  return [0.30, 0.35, 0.42, 0.25];
});

png('slot_vip', 32, 96, (x, y) => {
  const d = rrect(x, y, 2, 2, 30, 94, 7);
  if (d > 0) return d < 3 ? [1.0, 0.72, 0.05, (3 - d) / 3 * 0.45] : null;
  if (y > 89 && Math.abs(x - 16) < 6) return null;
  if (d > -2.8) return [1.0, 0.75, 0.12, 1.0];
  return [1.0, 0.72, 0.10, 0.18];
});

png('slot_locked', 32, 96, (x, y) => {
  const d = rrect(x, y, 2, 2, 30, 94, 7);
  if (d > 0) return null;
  if (d > -2.5) return [0.22, 0.85, 0.52, 0.95];
  // Clean '+' symbol in center
  const px = Math.abs(x - 16), py = Math.abs(y - 48);
  if ((px < 2.1 && py < 7.5) || (py < 2.1 && px < 7.5)) return [0.22, 0.88, 0.54, 1.0];
  return [0.14, 0.55, 0.34, 0.20];
});

// 2. Backdrop: cheerful lush grass park at top, bright clean ice-blue horizon below
png('backdrop', 4, 256, (x, y) => {
  const t = y / 255;
  const grassTop = hex('95da62');
  const grassBot = hex('86cc53');
  const lotTop   = hex('cfdbe8');
  const lotBot   = hex('dee7f1');
  if (t < 0.36) return [...lerpColor(grassTop, grassBot, t / 0.36).slice(0, 3), 1];
  if (t < 0.44) return [...lerpColor(grassBot, lotTop, (t - 0.36) / 0.08).slice(0, 3), 1];
  return [...lerpColor(lotTop, lotBot, (t - 0.44) / 0.56).slice(0, 3), 1];
});

// 3. Soft pill ground shadows for 3D buses
for (const [sz, len] of [['s', 2], ['m', 3], ['l', 4], ['limo', 5], ['xl', 6]]) {
  const W = 32 * len;
  png(`shadow_${sz}`, W, 36, (x, y) => {
    const d = rrect(x, y, 2, 4, W - 2, 32, 10);
    if (d > 0) return null;
    const a = Math.min(1.0, (-d) / 7.0) * 0.48;
    return [0.08, 0.12, 0.18, a];
  });
}

// 4. Clean circle disc (no harsh black border so red badges look crisp!)
png('disc', 64, 64, (x, y) => {
  const d = circle(x, y, 32, 32, 29);
  if (d > 0) return null;
  if (d > -2.0) return [1, 1, 1, 1];
  return [1, 1, 1, 1];
});

console.log('Updated ground, bay, shadow, and disc sprites!');
