// Runs tools/tune_levels.lua under fengari and writes modules/meta/level_seeds.lua.
// Usage: node tools/tune_levels.js [levels=100]
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const root = path.join(__dirname, '..');
const out = execFileSync(process.execPath, [path.join(__dirname, 'run_tests.js'), 'tools/tune_levels.lua'], {
  cwd: root, env: { ...process.env, LEVELS: process.argv[2] || '100' }, encoding: 'utf8', maxBuffer: 1 << 26,
});
const [log, file] = out.split('----FILE----\n');
process.stdout.write(log);
if (!file) { console.error('tuner failed'); process.exit(1); }
fs.writeFileSync(path.join(root, 'modules/meta/level_seeds.lua'), file.replace(/\nok .*\n?$/s, '\n'));
console.log('wrote modules/meta/level_seeds.lua');
