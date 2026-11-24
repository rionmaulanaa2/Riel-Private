const fs = require('fs');
const os = require('os');
const path = require('path');

const v1Path = path.resolve('v1');
const v1LuaPath = path.resolve('v1.lua');
const localAgentsPath = path.resolve('AGENTS.md');
const globalAgentsPath = path.join(os.homedir(), '.gemini', 'config', 'AGENTS.md');

const v1Text = fs.readFileSync(v1Path, 'utf8');
const match = v1Text.match(/local\s+RIEL_VERSION\s*=\s*"(\d+\.\d{2})"/);
if (!match) {
  console.error('Could not find local RIEL_VERSION = "X.XX" in v1');
  process.exit(1);
}

const currentVer = match[1];
const argVer = process.argv[2];
if (argVer && !/^\d+\.\d{2}$/.test(argVer)) {
  console.error(`Invalid version format "${argVer}". Expected X.XX (e.g. 1.01).`);
  process.exit(1);
}

const nextVer = argVer
  ? argVer
  : ((Math.round(parseFloat(currentVer) * 100) + 1) / 100).toFixed(2);

const updatedV1 = v1Text
  .replace(/^(--\s*Version:\s*)\d+\.\d{2}/m, `$1${nextVer}`)
  .replace(/(local\s+RIEL_VERSION\s*=\s*")\d+\.\d{2}(")/, `$1${nextVer}$2`);

fs.writeFileSync(v1Path, updatedV1, 'utf8');
fs.writeFileSync(v1LuaPath, updatedV1, 'utf8');

[localAgentsPath, globalAgentsPath].forEach((p) => {
  if (fs.existsSync(p)) {
    const content = fs.readFileSync(p, 'utf8');
    const updated = content.replace(
      /(\*\*Current Version\*\*:\s*`)\d+\.\d{2}(`)/g,
      `$1${nextVer}$2`
    );
    fs.writeFileSync(p, updated, 'utf8');
  }
});

console.log(`Riel Private version updated: v${currentVer} -> v${nextVer}`);
