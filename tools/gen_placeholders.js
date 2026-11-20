// Generates white placeholder sprites (tinted in code) into assets/images/.
// Run: node tools/gen_placeholders.js   — replace with real art later, keep names and sizes.
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const OUT = path.join(__dirname, '..', 'assets', 'images');

function crc32(buf) {
  let c, crc = 0xffffffff;
  for (let n = 0; n < buf.length; n++) {
    c = (crc ^ buf[n]) & 0xff;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    crc = (crc >>> 8) ^ c;
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}

// alpha(x, y) -> 0..1 coverage, shade(x, y) -> 0..1 brightness
function png(name, w, h, alpha, shade = () => 1) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 4 + 1)] = 0;
    for (let x = 0; x < w; x++) {
      const i = y * (w * 4 + 1) + 1 + x * 4;
      // 4x supersampling for soft edges
      let a = 0;
      for (let sy = 0; sy < 4; sy++) for (let sx = 0; sx < 4; sx++) a += alpha(x + (sx + 0.5) / 4, y + (sy + 0.5) / 4);
      const v = Math.round(255 * shade(x + 0.5, y + 0.5));
      raw[i] = raw[i + 1] = raw[i + 2] = v;
      raw[i + 3] = Math.round((a / 16) * 255);
    }
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; ihdr[9] = 6; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  const file = Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0)),
  ]);
  fs.writeFileSync(path.join(OUT, name + '.png'), file);
  console.log('wrote', name, w + 'x' + h);
}

const roundRect = (w, h, r) => (x, y) => {
  const dx = Math.max(r - x, 0, x - (w - r)), dy = Math.max(r - y, 0, y - (h - r));
  return dx * dx + dy * dy <= r * r ? 1 : 0;
};

fs.mkdirSync(OUT, { recursive: true });

// bus body, facing +x (right): rounded box, darker windshield band at the front
png('bus', 64, 32, roundRect(64, 32, 7), (x) => (x > 50 && x < 56 ? 0.75 : 1));
// roof arrow pointing +x
png('arrow', 32, 32, (x, y) => {
  const cy = Math.abs(y - 16);
  if (x >= 16 && x <= 28) return cy <= (28 - x) * 0.9 ? 1 : 0; // head
  return x >= 5 && x < 16 && cy <= 4 ? 1 : 0;                 // shaft
}, () => 0.95);
// passenger: circle with a lighter top
png('dot', 32, 32, (x, y) => ((x - 16) ** 2 + (y - 16) ** 2 <= 14 * 14 ? 1 : 0), (x, y) => (y < 12 ? 1 : 0.88));
// tiles: lot background, bays, buttons, popups
png('round', 64, 64, roundRect(64, 64, 14));
