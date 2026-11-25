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
function mix(c1, c2, t) { return [lerp(c1[0], c2[0], t), lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t)]; }

// Helper: 64x64 9-slice 3D beveled button/card (16px margins safe for slice9!)
function make3DButton(name, topHex, botHex, lipHex, rimHex, splitFooterHex) {
  const topC = hex(topHex), botC = hex(botHex), lipC = hex(lipHex), rimC = hex(rimHex);
  const footC = splitFooterHex ? hex(splitFooterHex) : null;
  png(name, 64, 64, (x, y) => {
    const outer = rrect(x, y, 2, 2, 62, 62, 13);
    if (outer > 0) {
      // Soft drop shadow underneath
      const sh = rrect(x, y - 2, 2, 2, 62, 62, 13);
      if (sh < 2.5) return [0.05, 0.08, 0.14, (2.5 - Math.max(0, sh)) / 2.5 * 0.22];
      return null;
    }
    // Bottom 3D bevel lip (y > 53)
    const face = rrect(x, y, 2, 2, 62, 55, 13);
    if (face > 0) return [...lipC, 1];
    // Crisp outer white/light rim (2.5px)
    if (face > -2.6) return [...rimC, 1];
    // Optional glossy blue/colored bottom label ribbon inside card (y > 44)
    if (footC && y > 44) {
      const k = (y - 44) / 12;
      return [...mix(footC, lipC, k * 0.45), 1];
    }
    // Top subtle highlight sheen (y < 14)
    const grad = mix(topC, botC, (y - 4) / 50);
    if (y < 12) return [...mix(grad, [1, 1, 1], (12 - y) / 8 * 0.25), 1];
    return [...grad, 1];
  });
}

// 1. Booster pill card (unlocked): icy white/blue top + glossy white rim + rich sky-blue footer band & 3D lip!
make3DButton('ui_card', 'f7fbff', 'e1efff', '247ae0', 'ffffff', '3d98ff');
// 2. Booster pill card (locked): soft cool silver-grey with clean slate footer & lip
make3DButton('ui_card_off', 'e8edf2', 'd2dbe4', '7c8b9c', 'f4f7fa', '94a3b8');
// 3. Green primary action button (GOT IT / RESUME)
make3DButton('ui_btn_green', '3fe07d', '22c55e', '15803d', 'dcfce7', null);
// 4. Gold VIP / Watch Ad button
make3DButton('ui_btn_gold', 'ffd233', 'f59e0b', 'b45309', 'fef3c7', null);
// 5. Neutral slate secondary button
make3DButton('ui_btn_grey', '7c8ba1', '5b6779', '334155', 'cbd5e1', null);

// 6. Sleek frosted dark-navy pill for header & icon buttons
png('ui_pill', 64, 64, (x, y) => {
  const outer = rrect(x, y, 2, 2, 62, 62, 14);
  if (outer > 0) {
    const sh = rrect(x, y - 1.5, 2, 2, 62, 62, 14);
    if (sh < 2) return [0.04, 0.07, 0.12, 0.25];
    return null;
  }
  if (outer > -2.2) return [1, 1, 1, 0.42];
  return [...mix(hex('46556b'), hex('2e3a4c'), y / 64), 0.90];
});

// 7. Sleek creamy-white 3D Modal Card
png('ui_modal', 64, 64, (x, y) => {
  const outer = rrect(x, y, 2, 2, 62, 62, 14);
  if (outer > 0) {
    const sh = rrect(x, y - 2, 2, 2, 62, 62, 14);
    if (sh < 3) return [0.04, 0.07, 0.12, (3 - Math.max(0, sh)) / 3 * 0.35];
    return null;
  }
  const face = rrect(x, y, 2, 2, 62, 57, 14);
  if (face > 0) return [...hex('cbd5e1'), 1];
  if (face > -2.5) return [1, 1, 1, 1];
  return [...mix(hex('ffffff'), hex('eef4fb'), y / 60), 1];
});

// 8. Curved vibrant sky/indigo modal header ribbon
make3DButton('ui_modal_head', '4fa3ff', '2980e8', '1d5fb8', 'bae6fd', null);

// 9. Crisp glossy badge circle with white border (tintable fill or coral red)
png('ui_badge', 64, 64, (x, y) => {
  const d = circle(x, y, 32, 32, 29);
  if (d > 0) return d < 2.5 ? [0.05, 0.08, 0.14, 0.22] : null;
  if (d > -4.2) return [1, 1, 1, 1]; // Clean crisp white rim
  return [1, 1, 1, 1];
});

// 10. Smooth glossy rounded bar (zero harsh black borders)
png('ui_bar', 64, 16, (x, y) => {
  const d = rrect(x, y, 1, 1, 63, 15, 7);
  if (d > 0) return null;
  if (y < 6) return [1, 1, 1, 0.96];
  return [0.90, 0.94, 0.98, 0.96];
});

// Rebuild assets/game.atlas cleanly (UTF-8 without BOM) from all PNGs in assets/images EXCEPT palette_3d.png
const imgs = fs.readdirSync(OUT)
  .filter(f => f.endsWith('.png') && f !== 'palette_3d.png')
  .sort();
const atlas = imgs.map(f => `images {\n  image: "/assets/images/${f}"\n}`).join('\n') +
  '\nmargin: 0\nextrude_borders: 2\ninner_padding: 0\n';
fs.writeFileSync(path.join(__dirname, '..', 'assets', 'game.atlas'), atlas, 'utf8');
console.log(`Generated 10 glossy 9-slice UI sprites and updated game.atlas (${imgs.length} images).`);
