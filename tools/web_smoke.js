// Headless browser smoke test of the HTML5 bundle: no window on the desktop.
// Serves the bundle locally, opens it in headless Chrome/Edge (puppeteer-core, installed browser),
// runs scenarios (level, window size, dev flags), saves screenshots, fails on console errors
// or when autoplay doesn't clear the expected number of levels.
//
// Usage: node tools/web_smoke.js <bundle dir (with index.html)> <out dir> [scenario names...]
const http = require('http');
const fs = require('fs');
const path = require('path');
const puppeteer = require('puppeteer-core');

const BROWSERS = [
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe',
  'C:/Program Files/Microsoft/Edge/Application/msedge.exe',
];

// name, viewport, engine args, seconds to run, min levels autoplay must clear
const SCENARIOS = [
  { name: 'portrait-l1', w: 540, h: 960, args: ['--config=bus.start_level=1'], wait: 6 },
  { name: 'portrait-l26', w: 540, h: 960, args: ['--config=bus.start_level=26'], wait: 6 },
  { name: 'phone-l11', w: 360, h: 640, args: ['--config=bus.start_level=11'], wait: 6 },
  { name: 'landscape-l18', w: 1100, h: 620, args: ['--config=bus.start_level=18'], wait: 6 },
  { name: 'desktop-l34', w: 1600, h: 900, args: ['--config=bus.start_level=34'], wait: 6 },
  { name: 'popup-stuck', w: 540, h: 960, args: ['--config=bus.start_level=9', '--config=bus.dev_popup=1'], wait: 6 },
  { name: 'popup-offer', w: 360, h: 640, args: ['--config=bus.start_level=3', '--config=bus.dev_popup=2'], wait: 6 },
  { name: 'autoplay-1-3', w: 540, h: 960, args: ['--config=bus.start_level=1', '--config=bus.autoplay=1'], wait: 30, minLevels: 2, shots: [1.5, 2.5, 4] },
  { name: 'autoplay-landscape-18', w: 1280, h: 720, args: ['--config=bus.start_level=18', '--config=bus.autoplay=1'], wait: 20, minLevels: 1, shots: [2, 3] },
];

const MIME = { '.html': 'text/html', '.js': 'application/javascript', '.wasm': 'application/wasm', '.json': 'application/json',
  '.png': 'image/png', '.ico': 'image/x-icon', '.css': 'text/css' };

function serve(dir) {
  const server = http.createServer((req, res) => {
    const url = new URL(req.url, 'http://x');
    let file = path.join(dir, decodeURIComponent(url.pathname));
    if (url.pathname === '/') file = path.join(dir, 'index.html');
    if (!file.startsWith(dir) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) {
      res.writeHead(404); res.end(); return;
    }
    let body = fs.readFileSync(file);
    if (file.endsWith('index.html')) {
      // engine arguments from ?arg=... (Defold reads CUSTOM_PARAMETERS.engine_arguments)
      body = body.toString().replace('// From here you can configure game startup parameters',
        'CUSTOM_PARAMETERS.engine_arguments = CUSTOM_PARAMETERS.engine_arguments.concat(new URLSearchParams(location.search).getAll("arg"));\n// From here you can configure game startup parameters');
    }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] || 'application/octet-stream' });
    res.end(body);
  });
  return new Promise((ok) => server.listen(0, '127.0.0.1', () => ok(server)));
}

(async () => {
  const [bundleArg, outArg, ...only] = process.argv.slice(2);
  if (!bundleArg || !outArg) { console.error('usage: node tools/web_smoke.js <bundle dir> <out dir> [scenario...]'); process.exit(2); }
  const dir = path.resolve(bundleArg);
  const out = path.resolve(outArg);
  fs.mkdirSync(out, { recursive: true });
  const server = await serve(dir);
  const port = server.address().port;
  const executablePath = BROWSERS.find((b) => fs.existsSync(b));
  const browser = await puppeteer.launch({
    executablePath, headless: true,
    args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--mute-audio', '--autoplay-policy=no-user-gesture-required'],
  });
  let failed = 0;
  for (const sc of SCENARIOS.filter((s) => !only.length || only.includes(s.name))) {
    const page = await browser.newPage();
    await page.setViewport({ width: sc.w, height: sc.h, deviceScaleFactor: 1 });
    const errors = [], game = [];
    page.on('console', (m) => {
      const t = m.text();
      if (t.includes('[game]')) game.push(t.replace(/^.*\[game\] /, '').trim());
      if (m.type() === 'error' || /ERROR:|FATAL|stack traceback/.test(t)) errors.push(t);
    });
    page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
    const q = sc.args.map((a) => 'arg=' + encodeURIComponent(a)).join('&');
    await page.goto(`http://127.0.0.1:${port}/index.html?${q}`, { waitUntil: 'load' });
    // the clock starts when the game reports it is running (wasm compile time varies)
    const until = Date.now() + 60000;
    while (!game.includes('ready') && Date.now() < until) await new Promise((r) => setTimeout(r, 200));
    if (!game.includes('ready')) errors.push('game never reported ready');
    const t0 = Date.now();
    for (const s of sc.shots || []) {
      await new Promise((r) => setTimeout(r, Math.max(0, s * 1000 - (Date.now() - t0))));
      await page.screenshot({ path: path.join(out, `${sc.name}-t${s}.png`) });
    }
    await new Promise((r) => setTimeout(r, Math.max(0, sc.wait * 1000 - (Date.now() - t0))));
    await page.screenshot({ path: path.join(out, `${sc.name}.png`) });
    const cleared = game.filter((g) => g.startsWith('level_complete')).length;
    // the Poki SDK can't reach its servers from a local page: ignore its network noise
    const real = errors.filter((e) => !/poki|Failed to load resource|net::ERR/i.test(e));
    const ok = real.length === 0 && cleared >= (sc.minLevels || 0);
    if (!ok) failed++;
    console.log(`${ok ? 'ok  ' : 'FAIL'} ${sc.name.padEnd(24)} levels cleared ${cleared}` +
      `${game.length ? ' | ' + game.join(', ') : ''}${real.length ? '\n     ' + real.slice(0, 5).join('\n     ') : ''}`);
    await page.close();
  }
  await browser.close();
  server.close();
  process.exit(failed ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
