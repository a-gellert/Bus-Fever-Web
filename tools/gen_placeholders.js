// Procedural sprites for the "night city" look. Run: node tools/gen_placeholders.js
// White/grey parts are tinted in code (tint multiplies), dark parts stay dark on any colour.
// Keep names and sizes: view code scales by these sizes (see IMG_* constants in modules/view).
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

// paint(x, y) -> [r, g, b, a] in 0..1 or null; 4x4 supersampled, y grows downwards
function png(name, w, h, paint) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 4 + 1)] = 0;
    for (let x = 0; x < w; x++) {
      let r = 0, g = 0, b = 0, a = 0;
      for (let sy = 0; sy < 4; sy++) for (let sx = 0; sx < 4; sx++) {
        const c = paint(x + (sx + 0.5) / 4, y + (sy + 0.5) / 4);
        if (c) { const ca = c[3] === undefined ? 1 : c[3]; r += c[0] * ca; g += c[1] * ca; b += c[2] * ca; a += ca; }
      }
      const i = y * (w * 4 + 1) + 1 + x * 4;
      if (a > 0) { raw[i] = Math.round(255 * r / a); raw[i + 1] = Math.round(255 * g / a); raw[i + 2] = Math.round(255 * b / a); }
      raw[i + 3] = Math.round(255 * a / 16);
    }
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; ihdr[9] = 6;
  fs.writeFileSync(path.join(OUT, name + '.png'), Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0)),
  ]));
  console.log('wrote', name, w + 'x' + h);
}

// signed distance to a rounded rect (x0,y0)-(x1,y1), negative inside
function rrect(x, y, x0, y0, x1, y1, r) {
  const cx = (x0 + x1) / 2, cy = (y0 + y1) / 2, hx = (x1 - x0) / 2 - r, hy = (y1 - y0) / 2 - r;
  const qx = Math.abs(x - cx) - hx, qy = Math.abs(y - cy) - hy;
  return Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) + Math.min(Math.max(qx, qy), 0) - r;
}
const circle = (x, y, cx, cy, r) => Math.hypot(x - cx, y - cy) - r;
const hex = (s) => [parseInt(s.slice(0, 2), 16) / 255, parseInt(s.slice(2, 4), 16) / 255, parseInt(s.slice(4, 6), 16) / 255];
const g = (v, a = 1) => [v, v, v, a];
const NAVY = hex('1b2238'), GLASS = hex('2a3a5c'), TIRE = hex('15181f');

fs.mkdirSync(OUT, { recursive: true });

// Buses: one sprite per length (32 px per lot unit), so nothing is stretched. Front = +x.
// Body tinted; outline, glass and tyres stay dark. More windows and a second rear axle on long ones.
for (const [name, len] of [['s', 2], ['m', 3], ['l', 4], ['xl', 6], ['limo', 5]]) {
  const W = 32 * len;
  const wheels = len >= 6 ? [17, Math.round(W * 0.36), Math.round(W * 0.68), W - 19]
    : len >= 4 ? [17, 31, W - 19] : [17, W - 19];
  const nwin = len * 2 - 1;
  const span = (W - 21) - 13;
  const step = span / nwin;
  png('bus_' + name, W, 36, (x, y) => {
    for (const wx of wheels) {
      if (rrect(x, y, wx - 5, 0.5, wx + 5, 35.5, 2) < 0 && (y < 5 || y > 31)) return [...TIRE, 1];
    }
    const d = rrect(x, y, 1, 3, W - 1, 33, 8);
    if (d > 0) return null;
    if (d > -2) return [...NAVY, 1];                                        // outline
    if (rrect(x, y, W - 17, 7, W - 8, 29, 3) < 0) return [...GLASS, 1];      // windshield
    if (rrect(x, y, 4, 9, 8, 27, 2) < 0) return [...GLASS, 1];               // rear window
    for (let i = 0; i < nwin; i++) {                                         // side windows
      const wx = 13 + i * step;
      if (rrect(x, y, wx, 20.5, wx + step - 2.5, 28, 2) < 0) return [...GLASS, 1];
    }
    if (len >= 3 && rrect(x, y, W * 0.38, 6, W * 0.58, 12, 2) < 0) return g(0.8); // roof hatch
    if (x > W - 8 && (Math.abs(y - 9) < 2.2 || Math.abs(y - 27) < 2.2)) return g(1); // headlights
    if (y < 11) return g(1);                                                 // lit top bevel
    if (y > 27) return g(0.72);                                              // shaded side
    return g(0.9);
  });
  // soft shadow under the bus (tinted black, alpha in code)
  png('shadow_' + name, W, 36, (x, y) => {
    const d = rrect(x, y, 4, 5, W - 4, 31, 10);
    return d < 0 ? g(0, Math.min(1, -d / 5)) : null;
  });
}
// roof direction badge: white disc, navy arrow pointing +x
png('arrow', 32, 32, (x, y) => {
  const d = circle(x, y, 16, 16, 15);
  if (d > 0) return null;
  if (d > -1.5) return [...NAVY, 0.6];
  const cy = Math.abs(y - 16);
  if (x >= 15 && x <= 26 && cy <= (26 - x) * 0.95) return [...NAVY, 1]; // head
  if (x >= 7 && x < 16 && cy <= 3.2) return [...NAVY, 1];               // shaft
  return g(1);
});
// switching bus badge: white disc with a circular arrow (changes direction on every move)
png('turn', 32, 32, (x, y) => {
  const d = circle(x, y, 16, 16, 15);
  if (d > 0) return null;
  if (d > -1.5) return [...NAVY, 0.6];
  const rd = Math.abs(Math.hypot(x - 16, y - 17) - 8.5);
  const ang = Math.atan2(y - 17, x - 16);
  if (rd < 2.2 && !(ang > -2.1 && ang < -1.0)) return [...NAVY, 1];
  const hx = 22, hy = 8;
  if (y >= hy - 5 && y <= hy + 5 && x >= hx - 7 && x <= hx + 2 && (x - (hx - 7)) >= Math.abs(y - hy) * 0.8) return [...NAVY, 1];
  return g(1);
});

// passenger seen from above: body + head, dark rim, tinted
png('dot', 32, 32, (x, y) => {
  const head = circle(x, y, 16, 10, 7);
  const body = Math.hypot((x - 16) / 12, (y - 21) / 9.5) - 1;
  if (head < 0) return head > -1.4 ? [...NAVY, 1] : g(y < 8 ? 1 : 0.92);
  if (body < 0) return body > -0.12 ? [...NAVY, 1] : g(0.8);
  return null;
});

// generic rounded tile (bays, buttons, panels, lot)
png('round', 64, 64, (x, y) => (rrect(x, y, 0.5, 0.5, 63.5, 63.5, 14) < 0 ? g(1) : null));

// framed slot: rim + darker inset (empty bays)
png('slot', 32, 96, (x, y) => {
  const d = rrect(x, y, 0.5, 0.5, 31.5, 95.5, 9);
  if (d > 0) return null;
  if (d > -2.5) return g(1);
  if (y > 84) return g(0.95, 1);              // entrance stripe
  return g(0.55);
});

// garage: roller door with slats
png('garage', 64, 64, (x, y) => {
  const d = rrect(x, y, 0.5, 0.5, 63.5, 63.5, 10);
  if (d > 0) return null;
  if (d > -4) return g(1);
  return g(Math.floor((y - 4) / 7) % 2 === 0 ? 0.62 : 0.5);
});

// static barrier: dark body with diagonal hazard stripes (white parts are tinted gold in code)
png('barrier', 64, 64, (x, y) => {
  const d = rrect(x, y, 1, 8, 63, 56, 5);
  if (d > 0) return null;
  if (d > -3) return [...NAVY, 1];
  const stripe = ((x + y) % 22) < 9;
  return stripe ? g(1) : g(0.35);
});

// conveyor belt: dark track with white chevrons (tinted in code)
png('belt', 64, 32, (x, y) => {
  const d = rrect(x, y, 0.5, 1.5, 63.5, 30.5, 6);
  if (d > 0) return null;
  if (d > -2) return [...NAVY, 1];
  const cx = ((x - y * 0.8) % 20 + 20) % 20;
  if (cx > 7 && cx < 12) return g(1);
  return g(0.28);
});

// coin: white disc, navy ring and slot (tinted gold in code)
png('coin', 64, 64, (x, y) => {
  const d = circle(x, y, 32, 32, 29);
  if (d > 0) return null;
  if (d > -2.5) return [...NAVY, 1];
  const inner = Math.abs(circle(x, y, 32, 32, 20));
  if (inner < 2) return [...NAVY, 1];
  if (Math.abs(x - 32) < 3 && y > 20 && y < 44) return [...NAVY, 1];
  return g(1);
});

// full-screen vertical gradient, already coloured (night sky over the city)
png('backdrop', 4, 256, (x, y) => {
  const t = y / 255, a = hex('1e4466'), b = hex('0d1a2e');
  return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, 1];
});

// lot markings: dashed lane stripe tile (tiled by scaling a few copies)
png('ring', 64, 64, (x, y) => {
  const d = Math.abs(circle(x, y, 32, 32, 26));
  return d < 4 ? g(1, Math.min(1, (4 - d) / 1.5)) : null;
});

// --- icons 64x64, white (tinted in code) ---
png('icon_vip', 64, 64, (x, y) => {           // crown
  if (rrect(x, y, 12, 42, 52, 50, 2) < 0) return g(1);
  if (y >= 18 && y <= 43 && x >= 12 && x <= 52) {
    const peaks = [12, 32, 52];
    for (const p of peaks) if (y >= 18 + Math.abs(x - p) * 1.2 - 2 && Math.abs(x - p) < 10) return g(1);
    if (y > 34) return g(1);
  }
  for (const p of [12, 32, 52]) if (circle(x, y, p, 15, 4) < 0) return g(1);
  return null;
});
png('icon_arrange', 64, 64, (x, y) => {       // bars sorted ascending + arrow
  const bars = [[10, 40], [24, 30], [38, 20]];
  for (const [bx, top] of bars) if (rrect(x, y, bx, top, bx + 10, 52, 2) < 0) return g(1);
  if (x >= 50 && x <= 56 && y >= 18 && y <= 50) return g(1);
  if (y >= 10 && y <= 20 && Math.abs(x - 53) <= (y - 10) * 0.9) return g(1);
  return null;
});
png('icon_jumble', 64, 64, (x, y) => {        // die
  const d = rrect(x, y, 10, 10, 54, 54, 9);
  if (d > 0) return null;
  for (const [px, py] of [[21, 21], [43, 21], [32, 32], [21, 43], [43, 43]]) if (circle(x, y, px, py, 4.5) < 0) return null;
  return g(1);
});
png('icon_restart', 64, 64, (x, y) => {       // circular arrow
  const d = Math.abs(circle(x, y, 32, 34, 18));
  const ang = Math.atan2(y - 34, x - 32);
  if (d < 4.5 && !(ang > -1.9 && ang < -0.9)) return g(1);
  // arrow head at the top right end of the arc
  const hx = 40, hy = 13;
  if (y >= hy - 8 && y <= hy + 9 && x >= hx - 10 && x <= hx + 4 && (x - (hx - 10)) >= Math.abs(y - hy) * 0.8) return g(1);
  return null;
});
png('icon_lock', 64, 64, (x, y) => {
  if (rrect(x, y, 14, 28, 50, 56, 6) < 0) return circle(x, y, 32, 40, 4) < 0 || (Math.abs(x - 32) < 2 && y > 40 && y < 48) ? null : g(1);
  const d = Math.abs(circle(x, y, 32, 28, 12));
  if (d < 3.5 && y < 30) return g(1);
  return null;
});
png('icon_ad', 64, 64, (x, y) => {            // play triangle in a rounded box ("watch video")
  const d = rrect(x, y, 6, 12, 58, 52, 10);
  if (d > 0) return null;
  if (x >= 24 && x <= 44 && Math.abs(y - 32) <= (44 - x) * 0.6) return null;
  return g(1);
});
png('hand', 64, 64, (x, y) => {               // tutorial pointer: finger + palm, navy rim
  const finger = rrect(x, y, 24, 2, 36, 34, 6);
  const palm = rrect(x, y, 16, 26, 50, 62, 12);
  const d = Math.min(finger, palm);
  if (d > 0) return null;
  return d > -2.5 ? [...NAVY, 1] : g(1);
});
png('spark', 16, 16, (x, y) => (rrect(x, y, 2, 2, 14, 14, 3) < 0 ? g(1) : null));
// filled disc with a soft rim (badges)
png('disc', 64, 64, (x, y) => (circle(x, y, 32, 32, 30.5) < 0 ? g(1) : null));

// speaker (sound on / off)
const speaker = (x, y) => (x >= 12 && x <= 22 && y >= 24 && y <= 40) ||
  (x > 22 && x <= 36 && Math.abs(y - 32) <= 8 + (x - 22) * 0.9);
png('icon_sound', 64, 64, (x, y) => {
  if (speaker(x, y)) return g(1);
  for (const r of [10, 18]) {
    const d = Math.abs(Math.hypot(x - 36, y - 32) - r);
    if (d < 2.6 && x > 38 && Math.abs(y - 32) < r * 0.8) return g(1);
  }
  return null;
});
png('icon_mute', 64, 64, (x, y) => {
  if (speaker(x, y)) return g(1);
  const a = Math.abs((x - 49) - (y - 32)), b = Math.abs((x - 49) + (y - 32));
  if (Math.abs(x - 49) < 9 && Math.abs(y - 32) < 9 && (a < 3.2 || b < 3.2)) return g(1);
  return null;
});

// bus stop sign: pole + board with a bus silhouette (board tinted in code, pole stays light)
png('stop', 48, 64, (x, y) => {
  if (Math.abs(x - 24) < 2.5 && y > 30) return g(0.85);
  const d = rrect(x, y, 4, 2, 44, 34, 7);
  if (d > 0) return null;
  if (d > -2.5) return [...NAVY, 1];
  if (rrect(x, y, 12, 10, 36, 24, 3) < 0) return [...NAVY, 1];                  // bus body
  if (circle(x, y, 17, 26, 3) < 0 || circle(x, y, 31, 26, 3) < 0) return [...NAVY, 1]; // wheels
  return g(1);
});

// five-point star (bursts, praise)
png('star', 64, 64, (x, y) => {
  const a = Math.atan2(y - 33, x - 32), r = Math.hypot(x - 32, y - 33);
  const k = Math.cos(((a + Math.PI / 2) * 5) % (2 * Math.PI) - Math.PI) ; // 1 at tips
  const lim = 13 + 16 * Math.pow(Math.max(0, (k + 1) / 2), 2.2);
  return r < lim ? g(1) : null;
});

// thin rounded bar (progress), drawn as an image: 9-slice panels can't go thinner than their corners
png('bar', 64, 16, (x, y) => (rrect(x, y, 0.5, 0.5, 63.5, 15.5, 7.5) < 0 ? g(1) : null));
