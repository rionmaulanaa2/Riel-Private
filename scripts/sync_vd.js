const fs = require('fs');

const vd = fs.readFileSync('violence_district.lua', 'utf8');
const v1 = fs.readFileSync('v1', 'utf8');

// Find lines in v1
const v1Lines = v1.split('\n');
const vdLines = vd.split('\n');

const vdModuleStartInV1 = v1Lines.findIndex(l => l.trim() === 'local ViolenceTab = nil');
const vdModuleEndInV1 = v1Lines.findIndex((l, i) => i > vdModuleStartInV1 && l.trim() === 'do' && v1Lines[i+1] && v1Lines[i+1].includes('DiscordTab'));

console.log('vdModuleStartInV1:', vdModuleStartInV1 + 1);
console.log('vdModuleEndInV1:', vdModuleEndInV1 + 1);

if (vdModuleStartInV1 === -1 || vdModuleEndInV1 === -1) {
  console.error('Failed to locate boundaries in v1!');
  process.exit(1);
}

// Lines 8 to 5100 of violence_district.lua
const vdStartIdx = vdLines.findIndex(l => l.trim() === 'local ViolenceTab = nil');
const vdToEmbed = vdLines.slice(vdStartIdx).join('\n');

const newV1 = v1Lines.slice(0, vdModuleStartInV1).join('\n') + '\n' + vdToEmbed + '\n\n' + v1Lines.slice(vdModuleEndInV1).join('\n');

fs.writeFileSync('v1', newV1, 'utf8');
fs.writeFileSync('v1.lua', newV1, 'utf8');

console.log('Successfully synchronized violence_district.lua into v1 and v1.lua!');
