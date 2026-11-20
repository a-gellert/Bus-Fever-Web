// Procedural SFX generator: node tools/gen_sounds.js -> assets/sounds/*.wav
// 16-bit PCM mono 22050 Hz, no dependencies.
const fs = require('fs');
const path = require('path');
const SR = 22050;
const TAU = Math.PI * 2;
const OUT = path.join(__dirname, '..', 'assets', 'sounds');

let seed = 12345;
const rnd = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296 * 2 - 1; };

const sine = p => Math.sin(TAU * p);
const tri = p => 4 * Math.abs(p - Math.floor(p + 0.5)) - 1;
const sq = p => Math.tanh(4 * Math.sin(TAU * p)); // softened square
const expDecay = (t, k) => Math.exp(-t * k);
const env = (t, a, d) => (t < a ? t / a : Math.exp(-(t - a) * d)); // attack + exp decay
const lerpExp = (a, b, x) => a * Math.pow(b / a, Math.min(1, Math.max(0, x)));

// Render: fn(t) -> sample. Applies fades, soft clip, normalizes to -3 dBFS.
function render(dur, fn) {
  const n = Math.floor(dur * SR);
  const buf = new Float64Array(n);
  for (let i = 0; i < n; i++) buf[i] = fn(i / SR);
  const fi = Math.floor(0.002 * SR), fo = Math.floor(0.006 * SR);
  for (let i = 0; i < n; i++) {
    let g = 1;
    if (i < fi) g *= i / fi;
    if (n - 1 - i < fo) g *= (n - 1 - i) / fo;
    buf[i] = Math.tanh(buf[i] * 1.2) * g;
  }
  let pk = 0;
  for (let i = 0; i < n; i++) pk = Math.max(pk, Math.abs(buf[i]));
  const k = pk > 0 ? 0.708 / pk : 1; // -3 dBFS
  const out = Buffer.alloc(n * 2);
  for (let i = 0; i < n; i++) out.writeInt16LE(Math.round(buf[i] * k * 32767), i * 2);
  return out;
}

// Phase-accumulating oscillator with time-varying frequency.
function osc(wave) { let ph = 0; return f => { ph += f / SR; ph -= Math.floor(ph); return wave(ph); }; }
function lp(c) { let y = 0; return x => (y += c * (x - y)); } // one-pole lowpass

function wav(data) {
  const h = Buffer.alloc(44);
  h.write('RIFF', 0); h.writeUInt32LE(36 + data.length, 4); h.write('WAVE', 8);
  h.write('fmt ', 12); h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(1, 22);
  h.writeUInt32LE(SR, 24); h.writeUInt32LE(SR * 2, 28); h.writeUInt16LE(2, 32); h.writeUInt16LE(16, 34);
  h.write('data', 36); h.writeUInt32LE(data.length, 40);
  return Buffer.concat([h, data]);
}

const sounds = {};

// board: round sine blip, pitch 520->900 Hz, faint octave overtone, 50 ms
sounds['board.wav'] = () => { const o = osc(sine), o2 = osc(tri);
  return render(0.05, t => { const f = lerpExp(520, 900, t / 0.05);
    return (o(f) + 0.25 * o2(f * 2)) * env(t, 0.004, 55); }); };

// go: triangle + soft-square engine up-sweep with filtered noise whoosh, 300 ms
sounds['go.wav'] = () => { const o = osc(tri), o2 = osc(sq), f1 = lp(0.25), D = 0.3;
  return render(D, t => { const x = t / D, f = lerpExp(150, 650, x) * (1 + 0.04 * Math.sin(TAU * 28 * t));
    const a = Math.min(1, t / 0.02) * Math.pow(1 - x, 0.6);
    return (0.7 * o(f) + 0.25 * o2(f * 0.5) + 0.5 * f1(rnd()) * Math.sin(Math.PI * x)) * a; }); };

// vip: staggered rising pentatonic sine sparkles with shimmer, 350 ms
sounds['vip.wav'] = () => { const fr = [1047, 1319, 1568, 1976, 2349, 2637, 3136], os = fr.map(() => osc(sine)), os2 = fr.map(() => osc(sine));
  return render(0.35, t => { let s = 0;
    fr.forEach((f, k) => { const tt = t - k * 0.032; if (tt < 0) return;
      s += (os[k](f) + 0.4 * os2[k](f * 2.005)) * env(tt, 0.003, 14) * (0.6 + 0.4 * Math.sin(TAU * 18 * tt)); });
    return s * 0.4; }); };

// honk: two softened-square beeps (392 then 523 Hz), lowpassed, 300 ms
sounds['honk.wav'] = () => { const a = osc(sq), b = osc(sq), l = lp(0.28);
  return render(0.3, t => { let f, tt;
    if (t < 0.13) { f = 392; tt = t; } else if (t >= 0.17) { f = 523; tt = t - 0.17; } else return l(0);
    const e = Math.min(1, tt / 0.008) * Math.min(1, (0.13 - tt) / 0.015);
    return l(a(f) + 0.7 * b(f * 1.03)) * Math.max(0, e); }); };

// deny: low bonk, 150 ms
sounds['deny.wav'] = () => { const o = osc(sine), o2 = osc(tri), n = lp(0.15);
  return render(0.15, t => { const f = lerpExp(170, 65, t / 0.07);
    return (o(f) + 0.3 * o2(f * 2)) * env(t, 0.003, 22) + 0.3 * n(rnd()) * expDecay(t, 120); }); };

// depart: down-to-up triangle whoosh with noise + chime, 450 ms
sounds['depart.wav'] = () => { const o = osc(tri), c1 = osc(sine), c2 = osc(sine), n = lp(0.2), D = 0.45;
  return render(D, t => { const x = t / 0.3, f = x < 0.4 ? lerpExp(600, 260, x / 0.4) : lerpExp(260, 800, (x - 0.4) / 0.6);
    const w = t < 0.3 ? Math.min(1, t / 0.02) * Math.sin(Math.PI * Math.min(1, x) * 0.9 + 0.2) : 0;
    const ct = t - 0.25, ch = ct > 0 ? (c1(1568) + 0.5 * c2(2349)) * env(ct, 0.003, 16) * 0.5 : 0;
    return (0.7 * o(f) + 0.35 * n(rnd())) * Math.max(0, w) + ch; }); };

// win: major arpeggio jingle + sparkle tail, 1.0 s
sounds['win.wav'] = () => { const fr = [523.25, 659.25, 783.99, 1046.5, 1318.5], os = fr.map(() => osc(sine)), ot = fr.map(() => osc(tri)),
    spf = [2093, 2637, 3136], sp = spf.map(() => osc(sine));
  return render(1.0, t => { let s = 0;
    fr.forEach((f, k) => { const tt = t - k * 0.13; if (tt < 0) return; const last = k === fr.length - 1;
      s += (os[k](f) + 0.3 * ot[k](f)) * env(tt, 0.005, last ? 3.2 : 9) * (last ? 1.1 : 0.8); });
    spf.forEach((f, k) => { const tt = t - 0.55 - k * 0.07; if (tt < 0) return; s += sp[k](f) * env(tt, 0.003, 12) * 0.18; });
    return s * 0.5; }); };

// stuck: "uh-oh", G4 -> D#4 with slight droop, 400 ms
sounds['stuck.wav'] = () => { const a = osc(tri), b = osc(sine);
  return render(0.4, t => { const first = t < 0.18; if (!first && t < 0.2) return 0;
    const tt = first ? t : t - 0.2;
    const f = (first ? 392 : 311) * (1 - 0.04 * tt / 0.2), e = Math.min(1, tt / 0.01) * (first ? Math.min(1, (0.18 - tt) / 0.02) : Math.exp(-tt * 9));
    return (a(f) * 0.6 + b(f) * 0.6) * Math.max(0, e); }); };

// unlock: bright bell ding, 300 ms
sounds['unlock.wav'] = () => { const a = osc(sine), b = osc(sine), c = osc(sine);
  return render(0.3, t => (a(1319) + 0.45 * b(2637) * expDecay(t, 6) + 0.2 * c(3951) * expDecay(t, 10)) * env(t, 0.002, 13)); };

// tap: UI tick, 40 ms
sounds['tap.wav'] = () => { const o = osc(sine), n = lp(0.4);
  return render(0.04, t => o(lerpExp(1000, 600, t / 0.03)) * env(t, 0.002, 90) + 0.15 * n(rnd()) * expDecay(t, 300)); };

fs.mkdirSync(OUT, { recursive: true });
let total = 0;
for (const name of Object.keys(sounds)) {
  const data = sounds[name](), file = wav(data);
  fs.writeFileSync(path.join(OUT, name), file);
  total += file.length;
  console.log(name.padEnd(12), String(file.length).padStart(6), 'B', (data.length / 2 / SR * 1000).toFixed(0).padStart(5), 'ms');
}
console.log('total', total, 'bytes');
