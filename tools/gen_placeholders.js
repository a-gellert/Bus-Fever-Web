// Enhanced procedural art generator matching modern high-polish casual 3D/vector mobile references.
// Generates:
// - 3D-beveled buses with glossy cyan windshields, specular reflections, rounded side windows, headlights, taillights, wheels.
// - Specific colored buses (bus_<size>_<color>) and mystery bus (bus_<size>_hidden).
// - Crisp white 3D roof directional arrows with dark outlines (arrow.png, turn.png).
// - Adorable jelly bean passengers (dot_1..9 and dot) with big white cartoon eyes, dark pupils, sparkle reflections, and feet.
// - Clean modern bay slots: standard (slot), glowing VIP (slot_vip), emerald locked (slot_locked).
// - 3D purple garage with metallic roll-up shutter (garage).
// - Tactile 3D booster icons: VIP crown, crossing shuffle arrows, 3D isometric dice.
// - Polished UI elements, road markings, and environment textures.

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

// paint(x, y) -> [r, g, b, a] in 0..1 or null; 4x4 supersampled
function png(name, w, h, paint) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 4 + 1)] = 0;
    for (let x = 0; x < w; x++) {
      let r = 0, g = 0, b = 0, a = 0;
      for (let sy = 0; sy < 4; sy++) {
        for (let sx = 0; sx < 4; sx++) {
          const c = paint(x + (sx + 0.5) / 4, y + (sy + 0.5) / 4);
          if (c) {
            const ca = c[3] === undefined ? 1 : c[3];
            r += c[0] * ca; g += c[1] * ca; b += c[2] * ca; a += ca;
          }
        }
      }
      const i = y * (w * 4 + 1) + 1 + x * 4;
      if (a > 0) {
        raw[i] = Math.round(255 * r / a);
        raw[i + 1] = Math.round(255 * g / a);
        raw[i + 2] = Math.round(255 * b / a);
      }
      raw[i + 3] = Math.round(255 * a / 16);
    }
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; ihdr[9] = 6;
  const outPath = path.join(OUT, name + '.png');
  const fileData = Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0)),
  ]);
  for (let attempt = 0; attempt < 5; attempt++) {
    try {
      fs.writeFileSync(outPath, fileData);
      break;
    } catch (e) {
      if (attempt === 4) throw e;
      const start = Date.now(); while (Date.now() - start < 100);
    }
  }
  console.log('wrote', name, w + 'x' + h);
}

// Math helpers
function rrect(x, y, x0, y0, x1, y1, r) {
  const cx = (x0 + x1) / 2, cy = (y0 + y1) / 2, hx = (x1 - x0) / 2 - r, hy = (y1 - y0) / 2 - r;
  const qx = Math.abs(x - cx) - hx, qy = Math.abs(y - cy) - hy;
  return Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) + Math.min(Math.max(qx, qy), 0) - r;
}
const circle = (x, y, cx, cy, r) => Math.hypot(x - cx, y - cy) - r;
const ellipse = (x, y, cx, cy, rx, ry) => Math.hypot((x - cx) / rx, (y - cy) / ry) - 1;
const clamp = (v, min, max) => Math.max(min, Math.min(max, v));
const lerp = (a, b, t) => a + (b - a) * t;
const hex = (s) => [parseInt(s.slice(0, 2), 16) / 255, parseInt(s.slice(2, 4), 16) / 255, parseInt(s.slice(4, 6), 16) / 255];
const lerpColor = (c1, c2, t) => [lerp(c1[0], c2[0], t), lerp(c1[1], c2[1], t), lerp(c1[2], c2[2], t)];
const g = (v, a = 1) => [v, v, v, a];

// Theme Colors
const OUTLINE = hex('1c2430');        // Clean dark cartoon outline
const GLASS_BASE = hex('82d4f2');     // Glossy cyan glass
const GLASS_LIGHT = hex('b9ecfa');    // Specular light glass
const GLASS_DARK = hex('4daecf');     // Shaded glass
const TIRE_BLACK = hex('181b22');     // Rubber tire
const HUB_RIM = hex('9aa5b5');        // Silver hubcap
const HEADLIGHT = hex('fff59d');      // Warm yellow headlight
const TAILLIGHT = hex('ff3838');      // Ruby red taillight

// Vehicle & Passenger Palettes (Matching Reference)
const PALETTES = {
  1: { name: 'red',    base: hex('ff4757'), light: hex('ff6b81'), dark: hex('d63031') }, // Coral Red
  2: { name: 'cyan',   base: hex('1e90ff'), light: hex('4da3ff'), dark: hex('0968c9') }, // Sky Cyan/Blue
  3: { name: 'yellow', base: hex('ffa502'), light: hex('ffbe3b'), dark: hex('e58e00') }, // Warm Yellow
  4: { name: 'green',  base: hex('2ed573'), light: hex('4fe08b'), dark: hex('1fb55c') }, // Lime Green
  5: { name: 'purple', base: hex('9c88ff'), light: hex('b3a3ff'), dark: hex('7d67eb') }, // Cheerful Purple
  6: { name: 'pink',   base: hex('ff70a6'), light: hex('ff94be'), dark: hex('eb4b87') }, // Bubblegum Pink
  7: { name: 'orange', base: hex('ff7f50'), light: hex('ff9870'), dark: hex('e05c2a') }, // Tangerine Orange
  8: { name: 'blue',   base: hex('3742fa'), light: hex('5a64fb'), dark: hex('242ed1') }, // Deep Cobalt
  9: { name: 'pearl',  base: hex('f1f2f6'), light: hex('ffffff'), dark: hex('ced6e0') }, // Pearl White
  hidden: { name: 'hidden', base: hex('353b48'), light: hex('4c5566'), dark: hex('222731') }, // Mystery Charcoal
  neutral: { name: 'neutral', base: hex('e4e7eb'), light: hex('ffffff'), dark: hex('c4c9d1') },
};

fs.mkdirSync(OUT, { recursive: true });

// ==========================================
// 1. BUS SPRITES (bus_s, bus_m, bus_l, bus_xl, bus_limo)
// With full color variants: bus_<size>_<color>
// ==========================================
const SIZES = [['s', 2], ['m', 3], ['l', 4], ['xl', 6], ['limo', 5]];

function drawBus(W, H, len, pal, isHidden = false) {
  const wheels = len >= 6 ? [16, Math.round(W * 0.36), Math.round(W * 0.68), W - 17]
    : len >= 4 ? [16, 29, W - 17] : [16, W - 17];
  const nwin = len * 2 - 1;
  const span = (W - 20) - 13;
  const step = span / nwin;

  return (x, y) => {
    // Wheels (sticking out top and bottom)
    for (const wx of wheels) {
      if (Math.abs(x - wx) <= 5 && (y < 4.5 || y > 31.5)) {
        if (Math.abs(x - wx) <= 2 && ((y > 1 && y < 4) || (y > 32 && y < 35))) {
          return [...HUB_RIM, 1]; // Hubcap
        }
        return [...TIRE_BLACK, 1]; // Rubber
      }
    }

    // Bus chassis
    const bodyD = rrect(x, y, 1.5, 3.5, W - 1.5, 32.5, 7.5);
    if (bodyD > 0) return null;

    // Dark cartoon outline
    if (bodyD > -2.0) return [...OUTLINE, 1];

    // Front windshield (+X is front)
    const wsD = rrect(x, y, W - 17, 7, W - 7.5, 29, 3.5);
    if (wsD < 0) {
      if (wsD > -1.5) return [...OUTLINE, 1]; // Glass frame
      if (isHidden) return [...pal.dark, 1];
      // Specular highlight stripe across glass
      const diag = (x - (W - 14)) + (y - 18) * 0.6;
      if (Math.abs(diag) < 2.0) return [1, 1, 1, 0.95];
      if (diag > -6 && diag < 5) return [...GLASS_LIGHT, 1];
      return [...GLASS_BASE, 1];
    }

    // Rear window
    const rwD = rrect(x, y, 4, 8, 8, 28, 2.5);
    if (rwD < 0) {
      if (rwD > -1.2) return [...OUTLINE, 1];
      return isHidden ? [...pal.dark, 1] : [...GLASS_DARK, 1];
    }

    // Side windows (bottom side, facing player)
    for (let i = 0; i < nwin; i++) {
      const wx = 12 + i * step;
      const winD = rrect(x, y, wx, 21.0, wx + step - 2.5, 28.5, 2.0);
      if (winD < 0) {
        if (winD > -1.2) return [...OUTLINE, 1];
        if (isHidden) return [...pal.dark, 1];
        if (x - wx < 2.5) return [...GLASS_LIGHT, 1];
        return [...GLASS_BASE, 1];
      }
    }

    // Headlights (front right)
    if (x > W - 6.5 && (Math.abs(y - 8.5) < 2.8 || Math.abs(y - 27.5) < 2.8)) {
      if (x > W - 3.2) return [...HEADLIGHT, 1];
      return [HEADLIGHT[0] * 0.9, HEADLIGHT[1] * 0.9, HEADLIGHT[2] * 0.9, 1];
    }

    // Taillights (rear left)
    if (x < 4.5 && (Math.abs(y - 8.5) < 2.5 || Math.abs(y - 27.5) < 2.5)) {
      return [...TAILLIGHT, 1];
    }

    // Roof details on mystery bus: embossed question mark
    if (isHidden) {
      const cx = W * 0.48, cy = 18;
      const qd = Math.hypot(x - cx, y - (cy - 3));
      if (qd < 5.5 && qd > 2.5 && y < cy) return [...OUTLINE, 1];
      if (Math.abs(x - (cx + 1)) < 1.5 && y >= cy && y <= cy + 3.5) return [...OUTLINE, 1];
      if (Math.hypot(x - (cx + 1), y - (cy + 6.5)) < 1.4) return [...OUTLINE, 1];
    }

    // 3D Lighting & Bevel
    // Top roof highlight
    if (y < 8.0) {
      const t = (y - 3.5) / 4.5;
      return lerpColor([1, 1, 1], pal.light, t);
    }
    // Main roof area
    if (y < 16.0) {
      const t = (y - 8.0) / 8.0;
      return lerpColor(pal.light, pal.base, t);
    }
    // Lower body shadow
    if (y > 27.0) {
      const t = (y - 27.0) / 5.5;
      return lerpColor(pal.base, pal.dark, t);
    }
    return [...pal.base, 1];
  };
}

// Generate all buses (neutral, hidden, and per-color)
for (const [sizeName, len] of SIZES) {
  const W = 32 * len;
  // Neutral template (for tinted fallback)
  png(`bus_${sizeName}`, W, 36, drawBus(W, 36, len, PALETTES.neutral));

  // Mystery bus
  png(`bus_${sizeName}_hidden`, W, 36, drawBus(W, 36, len, PALETTES.hidden, true));

  // Colored buses
  for (let c = 1; c <= 9; c++) {
    png(`bus_${sizeName}_${c}`, W, 36, drawBus(W, 36, len, PALETTES[c]));
  }

  // Realistic directional soft shadow
  png(`shadow_${sizeName}`, W, 36, (x, y) => {
    const d = rrect(x, y, 4, 6, W - 2, 33, 9);
    if (d > 0) return null;
    const a = Math.min(1.0, (-d) / 5.5) * 0.42;
    return [0, 0, 0, a];
  });
}

// ==========================================
// 2. ROOF BADGES (arrow.png, turn.png)
// Crisp white 3D badges with dark cartoon outlines
// ==========================================
png('arrow', 32, 32, (x, y) => {
  const dDisc = circle(x, y, 16, 16, 14.5);
  if (dDisc > 0) return null;

  // Arrow pointing +X:
  // Shaft: rectangle x from 6 to 15.5, y from 12.5 to 19.5
  const cy = Math.abs(y - 16);
  const shaftDx = Math.abs(x - 10.75) - 4.75;
  const shaftDy = cy - 3.5;
  const dShaft = Math.max(shaftDx, shaftDy);

  // Head: triangle from x=15 to x=25.5, cy <= (25.5 - x) * 0.95
  const dHyp = (x - 25.5) * 0.69 + cy * 0.72;
  const dHead = Math.max(14.5 - x, dHyp);

  const dArrow = Math.min(dShaft, dHead);

  if (dArrow <= 0) {
    if (dArrow > -1.5) return [...OUTLINE, 1]; // Dark border
    return [1, 1, 1, 1];                       // Solid pure white fill
  }

  if (dDisc > -1.6) return [...OUTLINE, 0.8];
  if (y < 9) return [1, 1, 1, 0.95];
  if (y > 23) return [0.86, 0.89, 0.93, 0.95];
  return [0.94, 0.96, 0.98, 0.95];
});

png('turn', 32, 32, (x, y) => {
  const dDisc = circle(x, y, 16, 16, 14.5);
  if (dDisc > 0) return null;

  const r = Math.hypot(x - 16, y - 16);
  const ang = Math.atan2(y - 16, x - 16);

  const inArc1 = (ang > 0.4 && ang < 2.5);
  const inArc2 = (ang < -0.7 && ang > -2.75);
  const dRing = Math.abs(r - 8.5) - 2.2;
  const isBody = dRing <= 0 && (inArc1 || inArc2);

  const h1 = circle(x, y, 23.5, 18.5, 4.2) <= 0 && (y - 15.5) > Math.abs(x - 23.5) * 0.8;
  const h2 = circle(x, y, 8.5, 13.5, 4.2) <= 0 && (16.5 - y) > Math.abs(x - 8.5) * 0.8;

  if (isBody || h1 || h2) {
    if (dRing > -1.2) return [...OUTLINE, 1];
    return [1, 1, 1, 1];
  }

  if (dDisc > -1.6) return [...OUTLINE, 0.8];
  if (y < 9) return [1, 1, 1, 0.95];
  if (y > 23) return [0.86, 0.89, 0.93, 0.95];
  return [0.94, 0.96, 0.98, 0.95];
});

// ==========================================
// 3. PASSENGERS (dot.png, dot_1..9)
// Adorable chubby jelly-beans with big cartoon eyes!
// ==========================================
function drawPassenger(pal) {
  return (x, y) => {
    // Little feet at the bottom
    const leftFoot = circle(x, y, 11, 26.5, 3.2);
    const rightFoot = circle(x, y, 21, 26.5, 3.2);
    const feetD = Math.min(leftFoot, rightFoot);

    // Chubby jelly-bean body: dome head + wide plump belly
    const headD = circle(x, y, 16, 12, 8.8);
    const bodyD = ellipse(x, y, 16, 19.5, 9.8, 8.2);
    const shapeD = Math.min(feetD, Math.min(headD, bodyD * 8.0));

    if (shapeD > 0) return null;

    // Outer dark cartoon outline
    if (shapeD > -1.8) return [...OUTLINE, 1];

    // Big expressive cartoon eyes!
    // Left eye (oval)
    const e1 = ellipse(x, y, 12.2, 13.5, 2.6, 3.8);
    // Right eye (oval)
    const e2 = ellipse(x, y, 19.8, 13.5, 2.6, 3.8);

    if (e1 < 0 || e2 < 0) {
      const eD = Math.min(e1, e2);
      if (eD > -0.15) return [...OUTLINE, 1]; // Eye outline

      // Pupils (large black pupils looking slightly up/center)
      const p1 = circle(x, y, 12.6, 13.3, 1.8);
      const p2 = circle(x, y, 19.4, 13.3, 1.8);

      // White sparkle reflections
      const g1 = circle(x, y, 11.9, 12.2, 0.7);
      const g2 = circle(x, y, 18.7, 12.2, 0.7);
      if (g1 < 0 || g2 < 0) return [1, 1, 1, 1];

      if (p1 < 0 || p2 < 0) return [...OUTLINE, 1];

      // Sclera: pure white eyeballs!
      return [1, 1, 1, 1];
    }

    // Feet shading
    if (y > 25.5) {
      return [...pal.dark, 1];
    }

    // 3D Gumdrop Lighting
    // Forehead shiny highlight
    if (y < 8.5 && Math.abs(x - 16) < 6) {
      const t = (y - 4.5) / 4.0;
      return lerpColor([1, 1, 1], pal.light, t);
    }
    if (y < 15.0) {
      const t = (y - 8.5) / 6.5;
      return lerpColor(pal.light, pal.base, t);
    }
    // Bottom shadow
    if (y > 21.0) {
      const t = (y - 21.0) / 5.5;
      return lerpColor(pal.base, pal.dark, t);
    }
    return [...pal.base, 1];
  };
}

// Default passenger
png('dot', 32, 32, drawPassenger(PALETTES.neutral));
// Color-coded passengers
for (let c = 1; c <= 9; c++) {
  png(`dot_${c}`, 32, 32, drawPassenger(PALETTES[c]));
}

// ==========================================
// 4. BAYS (slot, slot_vip, slot_locked)
// ==========================================
// Regular bay: rounded slot with clean border and recessed floor
png('slot', 32, 96, (x, y) => {
  const d = rrect(x, y, 1.5, 1.5, 30.5, 94.5, 8.5);
  if (d > 0) return null;
  // Outer frame
  if (d > -2.8) return [0.78, 0.85, 0.92, 1]; // Clean light blue-grey border
  // Entrance guide marker at bottom
  if (y > 83) return [0.86, 0.91, 0.96, 1];
  // Inner recessed floor
  const t = y / 96;
  return [lerp(0.52, 0.60, t), lerp(0.58, 0.66, t), lerp(0.66, 0.74, t), 1];
});

// VIP bay: radiant glowing orange border with "VIP"
png('slot_vip', 32, 96, (x, y) => {
  const d = rrect(x, y, 1.5, 1.5, 30.5, 94.5, 8.5);
  if (d > 0) {
    // Outer neon glow
    if (d < 3.5) return [1.0, 0.65, 0.15, (3.5 - d) / 3.5 * 0.7];
    return null;
  }
  if (d > -3.2) return [1.0, 0.72, 0.22, 1]; // Radiant gold-orange border
  if (y > 83) return [1.0, 0.82, 0.35, 1];
  // Warm dark amber recessed floor
  return [0.38, 0.24, 0.14, 1];
});

// Locked bay: emerald green with padlock icon
png('slot_locked', 32, 96, (x, y) => {
  const d = rrect(x, y, 1.5, 1.5, 30.5, 94.5, 8.5);
  if (d > 0) return null;
  if (d > -2.8) return [0.22, 0.78, 0.48, 1]; // Emerald green border

  // Padlock icon in center
  const px = x - 16, py = y - 48;
  // Shackle
  const shackleD = Math.abs(circle(px, py, 0, -4, 6)) - 1.8;
  if (shackleD < 0 && py < -3) return [0.9, 0.95, 0.9, 1];
  // Lock body
  const lockBodyD = rrect(px, py, -8, -3, 8, 8, 2.5);
  if (lockBodyD < 0) {
    if (lockBodyD > -1.2) return [0.15, 0.45, 0.25, 1];
    // Keyhole
    if (circle(px, py, 0, 1.5, 1.8) < 0 || (Math.abs(px) < 1.0 && py >= 1.5 && py <= 4.5)) {
      return [0.15, 0.45, 0.25, 1];
    }
    return [0.95, 0.98, 0.95, 1];
  }

  // Green inner floor
  return [0.16, 0.58, 0.35, 1];
});

// ==========================================
// 5. GARAGE (garage.png, 64x64)
// 3D purple portal with metallic roll-up door and badge
// ==========================================
png('garage', 64, 64, (x, y) => {
  // Portal frame
  const outerD = rrect(x, y, 2.5, 6.5, 61.5, 61.5, 8.5);
  if (outerD > 0) {
    // Top pediment / badge "5"
    if (x >= 22 && x <= 42 && y >= 1.5 && y <= 9.5) {
      if (Math.abs(x - 32) > 9 || y < 2.5) return [...OUTLINE, 1];
      return [0.65, 0.52, 0.95, 1]; // Badge background
    }
    return null;
  }
  if (outerD > -2.5) return [...OUTLINE, 1]; // Outer outline

  // Portal opening for roll-up door
  const innerD = rrect(x, y, 10.5, 16.5, 53.5, 61.5, 4.0);
  if (innerD < 0) {
    if (innerD > -1.5) return [...OUTLINE, 1];
    // Roller shutter slats (silver metallic with dark grooves)
    const slat = (y - 17) % 6;
    if (slat < 1.4) return [0.35, 0.38, 0.45, 1]; // Slat groove
    if (slat < 3.2) return [0.85, 0.88, 0.92, 1]; // Slat light
    return [0.68, 0.72, 0.78, 1];                 // Slat base
  }

  // Violet/purple 3D frame
  if (y < 16.0) return [0.72, 0.58, 0.98, 1]; // Top arch
  if (x < 11.0) return [0.65, 0.52, 0.92, 1]; // Left pillar
  return [0.52, 0.40, 0.82, 1];               // Right pillar (shadow)
});

// ==========================================
// 6. BOOSTER BUTTONS & ICONS (64x64)
// Tactile 3D rounded icons matching Image 1
// ==========================================

// VIP Crown Icon (Golden royal crown with jewels)
png('icon_vip', 64, 64, (x, y) => {
  // Crown base band
  const baseD = rrect(x, y, 10, 42, 54, 52, 3);
  if (baseD < 0) {
    if (baseD > -1.8) return [...OUTLINE, 1];
    // Ruby jewel in center
    if (circle(x, y, 32, 47, 2.8) < 0) return [0.95, 0.2, 0.3, 1];
    return [1.0, 0.88, 0.3, 1];
  }

  // Crown peaks (left, center, right)
  if (y >= 16 && y <= 43 && x >= 10 && x <= 54) {
    const peaks = [14, 32, 50];
    for (const px of peaks) {
      const topY = px === 32 ? 18 : 22;
      const slope = px === 32 ? 1.3 : 1.1;
      if (y >= topY + Math.abs(x - px) * slope && Math.abs(x - px) < 11) {
        if (Math.abs(y - (topY + Math.abs(x - px) * slope)) < 2.0 || Math.abs(x - px) > 9) {
          return [...OUTLINE, 1];
        }
        return [1.0, 0.82 + (px === 32 ? 0.08 : 0), 0.25, 1];
      }
    }
  }

  // Pearls on the 3 tips
  for (const [px, py] of [[14, 20], [32, 16], [50, 20]]) {
    const pearlD = circle(x, y, px, py, 4.2);
    if (pearlD < 0) {
      if (pearlD > -1.5) return [...OUTLINE, 1];
      return [1, 1, 1, 1];
    }
  }
  return null;
});

// Crossing Shuffle / Arrange Arrows (Yellow & Cyan crossing arrows like Image 1)
png('icon_arrange', 64, 64, (x, y) => {
  // Arrow 1: curving from top-left to bottom-right (Yellow)
  // Arrow 2: curving from bottom-left to top-right (Cyan)
  const drawCrossingArrow = (x, y, flipY, color) => {
    const ny = flipY ? 64 - y : y;
    // Curved path
    const targetY = 22 + (x - 14) * 0.45;
    const dist = Math.abs(ny - targetY);
    if (x >= 12 && x <= 46 && dist <= 4.2) {
      if (dist > 2.8 || x < 13.5) return [...OUTLINE, 1];
      return color;
    }
    // Arrow head at right end
    if (x >= 42 && x <= 52 && Math.abs(ny - 36.5) <= (52 - x) * 1.1) {
      if (x > 50.5 || Math.abs(ny - 36.5) > (52 - x) * 1.1 - 1.6) return [...OUTLINE, 1];
      return color;
    }
    return null;
  };

  const a1 = drawCrossingArrow(x, y, false, [1.0, 0.85, 0.2, 1]); // Yellow
  const a2 = drawCrossingArrow(x, y, true, [0.2, 0.8, 1.0, 1]);   // Cyan
  return a2 || a1;
});

// 3D Isometric White Dice (Image 1 Jumble Button)
png('icon_jumble', 64, 64, (x, y) => {
  // 3D Isometric Cube / Die
  // Top face, left face, right face
  const cx = 32, cy = 32;
  const dx = x - cx, dy = y - cy;

  // Outer die rounded box
  const boxD = rrect(x, y, 12, 12, 52, 52, 9);
  if (boxD > 0) return null;
  if (boxD > -2.2) return [...OUTLINE, 1];

  // Dots / pips on die (5 pips pattern)
  const pips = [[22, 22], [42, 22], [32, 32], [22, 42], [42, 42]];
  for (const [px, py] of pips) {
    const pipD = circle(x, y, px, py, 4.2);
    if (pipD < 0) return [...OUTLINE, 1];
  }

  // 3D White Bevel
  if (y < 20) return [1, 1, 1, 1];
  if (y > 44) return [0.82, 0.85, 0.90, 1];
  return [0.94, 0.96, 0.98, 1];
});

// Restart circular arrow
png('icon_restart', 64, 64, (x, y) => {
  const d = Math.abs(circle(x, y, 32, 34, 18.5));
  const ang = Math.atan2(y - 34, x - 32);
  const isArc = (d < 5.0 && !(ang > -1.9 && ang < -0.9));
  if (isArc) {
    if (d > 3.2) return [...OUTLINE, 1];
    return [1, 1, 1, 1];
  }
  // Arrow head
  const hx = 42, hy = 12;
  if (y >= hy - 8 && y <= hy + 9 && x >= hx - 11 && x <= hx + 5 && (x - (hx - 11)) >= Math.abs(y - hy) * 0.9) {
    if (Math.abs((x - (hx - 11)) - Math.abs(y - hy) * 0.9) < 1.8 || x > hx + 3.5) return [...OUTLINE, 1];
    return [1, 1, 1, 1];
  }
  return null;
});

// Sound On / Off
const speakerShape = (x, y) => (x >= 12 && x <= 22 && y >= 24 && y <= 40) ||
  (x > 22 && x <= 36 && Math.abs(y - 32) <= 8 + (x - 22) * 0.9);

png('icon_sound', 64, 64, (x, y) => {
  if (speakerShape(x, y)) return [1, 1, 1, 1];
  for (const r of [11, 19]) {
    const d = Math.abs(Math.hypot(x - 36, y - 32) - r);
    if (d < 3.0 && x > 38 && Math.abs(y - 32) < r * 0.8) return [1, 1, 1, 1];
  }
  return null;
});

png('icon_mute', 64, 64, (x, y) => {
  if (speakerShape(x, y)) return [0.7, 0.75, 0.8, 1];
  const a = Math.abs((x - 48) - (y - 32)), b = Math.abs((x - 48) + (y - 32));
  if (Math.abs(x - 48) < 10 && Math.abs(y - 32) < 10 && (a < 3.5 || b < 3.5)) {
    return [1.0, 0.3, 0.3, 1]; // Red mute cross
  }
  return null;
});

// Padlock icon
png('icon_lock', 64, 64, (x, y) => {
  // Shackle
  const shackle = Math.abs(circle(x, y, 32, 27, 12)) - 3.5;
  if (shackle < 0 && y < 30) return [0.92, 0.95, 0.98, 1];
  // Lock body
  const body = rrect(x, y, 13, 27, 51, 57, 7);
  if (body < 0) {
    if (body > -2.0) return [...OUTLINE, 1];
    // Keyhole
    if (circle(x, y, 32, 39, 4.2) < 0 || (Math.abs(x - 32) < 2.2 && y > 39 && y < 48)) return [...OUTLINE, 1];
    return [1.0, 0.85, 0.25, 1]; // Gold padlock body
  }
  return null;
});

// Video Ad Icon
png('icon_ad', 64, 64, (x, y) => {
  const d = rrect(x, y, 6, 12, 58, 52, 10);
  if (d > 0) return null;
  if (d > -2.5) return [...OUTLINE, 1];
  // Play triangle
  if (x >= 24 && x <= 44 && Math.abs(y - 32) <= (44 - x) * 0.65) return [...OUTLINE, 1];
  return [1.0, 0.85, 0.25, 1];
});

// 3D Golden Coin
png('coin', 64, 64, (x, y) => {
  const d = circle(x, y, 32, 32, 29);
  if (d > 0) return null;
  if (d > -2.5) return [...OUTLINE, 1];
  // Inner stamped ring
  const inner = Math.abs(circle(x, y, 32, 32, 21));
  if (inner < 2.2) return [0.85, 0.65, 0.1, 1];
  // Center star
  const a = Math.atan2(y - 32, x - 32), r = Math.hypot(x - 32, y - 32);
  const k = Math.cos(((a + Math.PI / 2) * 5) % (2 * Math.PI) - Math.PI);
  if (r < 7 + 7 * Math.pow(Math.max(0, (k + 1) / 2), 2)) {
    return [1.0, 0.95, 0.6, 1];
  }
  // Coin gold gradient
  return y < 24 ? [1.0, 0.90, 0.35, 1] : [0.95, 0.75, 0.15, 1];
});

// 3D Praise Star
png('star', 64, 64, (x, y) => {
  const a = Math.atan2(y - 32, x - 32), r = Math.hypot(x - 32, y - 32);
  const k = Math.cos(((a + Math.PI / 2) * 5) % (2 * Math.PI) - Math.PI);
  const lim = 13 + 17 * Math.pow(Math.max(0, (k + 1) / 2), 2.2);
  if (r > lim) return null;
  if (r > lim - 2.2) return [...OUTLINE, 1];
  return y < 26 ? [1.0, 0.92, 0.45, 1] : [1.0, 0.78, 0.15, 1];
});

// Barrier: 3D hazard block
png('barrier', 64, 64, (x, y) => {
  const d = rrect(x, y, 2, 8, 62, 56, 6);
  if (d > 0) return null;
  if (d > -2.5) return [...OUTLINE, 1];
  const stripe = ((x + y) % 20) < 10;
  return stripe ? [1.0, 0.85, 0.15, 1] : [...OUTLINE, 1];
});

// Conveyor belt with modern glowing chevrons
png('belt', 64, 32, (x, y) => {
  const d = rrect(x, y, 1, 2, 63, 30, 6);
  if (d > 0) return null;
  if (d > -2.2) return [...OUTLINE, 1];
  const cx = ((x - y * 0.8) % 20 + 20) % 20;
  if (cx > 7 && cx < 13) return [0.35, 0.92, 0.75, 1]; // Vibrant mint chevron
  return [0.22, 0.26, 0.34, 1];                        // Dark track
});

// Dashed road lane marking (curved dashed arc)
png('ring', 64, 64, (x, y) => {
  const d = Math.abs(circle(x, y, 32, 32, 26));
  if (d > 3.5) return null;
  const ang = Math.atan2(y - 32, x - 32);
  const dash = (ang + Math.PI) % (Math.PI / 4);
  if (dash > Math.PI / 8) return null;
  return [1, 1, 1, Math.min(1.0, (3.5 - d) / 1.2) * 0.85];
});

// Generic rounded tile (pure white for seamless 9-slice panel and path merging)
png('round', 64, 64, (x, y) => (rrect(x, y, 0.5, 0.5, 63.5, 63.5, 14) < 0 ? [1, 1, 1, 1] : null));

// Clean modern backdrop: pastel meadow top, soft slate road bottom
png('backdrop', 4, 256, (x, y) => {
  const t = y / 255;
  // Top: cheerful park mint green; Bottom: soft periwinkle road grey
  const top = hex('9fe5c1'); // Park lawn
  const mid = hex('a8b9cc'); // Transition
  const bot = hex('94a6bc'); // Soft slate road
  if (t < 0.35) return [...top, 1];
  if (t < 0.55) {
    const k = (t - 0.35) / 0.20;
    return [...lerpColor(top, mid, k), 1];
  }
  const k = (t - 0.55) / 0.45;
  return [...lerpColor(mid, bot, k), 1];
});

// Tutorial Hand
png('hand', 64, 64, (x, y) => {
  const finger = rrect(x, y, 24, 2, 36, 34, 6);
  const palm = rrect(x, y, 16, 26, 50, 62, 12);
  const d = Math.min(finger, palm);
  if (d > 0) return null;
  if (d > -2.5) return [...OUTLINE, 1];
  return [1, 1, 1, 1];
});

// Sparkle particle
png('spark', 16, 16, (x, y) => (rrect(x, y, 2, 2, 14, 14, 3) < 0 ? [1, 1, 1, 1] : null));

// Disc with soft rim
png('disc', 64, 64, (x, y) => {
  const d = circle(x, y, 32, 32, 30);
  if (d > 0) return null;
  if (d > -2.0) return [...OUTLINE, 1];
  return [1, 1, 1, 1];
});

// Stop Sign
png('stop', 48, 64, (x, y) => {
  if (Math.abs(x - 24) < 2.8 && y > 30) return [0.85, 0.88, 0.92, 1]; // Silver pole
  const d = rrect(x, y, 4, 2, 44, 34, 7);
  if (d > 0) return null;
  if (d > -2.5) return [...OUTLINE, 1];
  // Bus icon on sign
  if (rrect(x, y, 12, 10, 36, 24, 3) < 0) return [...OUTLINE, 1];
  if (circle(x, y, 17, 26, 3) < 0 || circle(x, y, 31, 26, 3) < 0) return [...OUTLINE, 1];
  return [1.0, 0.85, 0.25, 1]; // Yellow stop sign
});

// Progress Bar
png('bar', 64, 16, (x, y) => {
  const d = rrect(x, y, 1, 1, 63, 15, 7);
  if (d > 0) return null;
  if (d > -1.8) return [...OUTLINE, 1];
  return [1, 1, 1, 1];
});

console.log('Finished generating all high-polish assets!');
