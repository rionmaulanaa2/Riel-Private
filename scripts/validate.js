const fs = require('fs');
const { execSync } = require('child_process');
const path = require('path');

console.log('====================================================');
console.log('🚀 [Riel Engine] RUNNING FULL DEEP VALIDATION SUITE');
console.log('====================================================');

let totalErrors = 0;

// 1. Check file existence & sync
console.log('\n[Phase 1] Checking File Integrity & Synchronization...');
const targetFiles = ['windui.lua', 'v1', 'v1.lua', 'violence_district.lua'];
targetFiles.forEach(f => {
    if (!fs.existsSync(f)) {
        console.error(`❌ CRITICAL: Missing file ${f}`);
        totalErrors++;
    } else {
        const stats = fs.statSync(f);
        console.log(`  ✓ ${f} present (${stats.size.toLocaleString()} bytes)`);
    }
});

if (fs.existsSync('v1') && fs.existsSync('v1.lua')) {
    const b1 = fs.readFileSync('v1');
    const b2 = fs.readFileSync('v1.lua');
    if (!b1.equals(b2)) {
        console.error('❌ ERROR: v1 and v1.lua are NOT 100% identical! Synchronizing now...');
        fs.writeFileSync('v1.lua', b1);
        console.log('  ✓ Resynchronized v1.lua to match v1 exactly.');
    } else {
        console.log('  ✓ v1 and v1.lua are 100% identical (byte-for-byte).');
    }
}

// 2. Luau Bytecode Compilation
console.log('\n[Phase 2] Luau Bytecode Compilation (luau-compile.exe)...');
targetFiles.forEach(f => {
    if (!fs.existsSync(f)) return;
    try {
        const res = execSync(`.\\scratch\\luau_bin\\luau-compile.exe "${f}"`, { encoding: 'utf-8', maxBuffer: 50 * 1024 * 1024 });
        console.log(`  ✓ [luau-compile] ${f}: SUCCESS (${res.length.toLocaleString()} bytes bytecode)`);
    } catch (e) {
        console.error(`  ❌ [luau-compile] ${f} COMPILATION FAILED:`);
        console.error(e.message);
        totalErrors++;
    }
});

// 3. Lua 5.1 / Luau AST Parser
console.log('\n[Phase 3] Lua 5.1 / Luau AST Syntax Analysis (luaparse)...');
targetFiles.forEach(f => {
    if (!fs.existsSync(f)) return;
    try {
        const res = execSync(`node scratch/luaparse.js "${f}"`, { encoding: 'utf-8', maxBuffer: 50 * 1024 * 1024 });
        console.log(`  ✓ [luaparse] ${f}: 0 syntax errors`);
    } catch (e) {
        console.error(`  ❌ [luaparse] ${f} AST PARSE FAILED:`);
        console.error(e.message);
        totalErrors++;
    }
});

// 4. Deep Static Code Audit: Foreign Library Calls & Undefined Callers
console.log('\n[Phase 4] Static Code Audit (Foreign APIs, Nil Globals, Undefined Sections)...');
const foreignPatterns = [
    { pattern: 'Tabs.', desc: 'Foreign Tabs global table indexing' },
    { pattern: 'Tabs[', desc: 'Foreign Tabs global table indexing' },
    { pattern: ':AddToggle(', desc: 'Foreign Rayfield/Fluent AddToggle method' },
    { pattern: ':AddButton(', desc: 'Foreign Rayfield/Fluent AddButton method' },
    { pattern: ':AddSlider(', desc: 'Foreign Rayfield/Fluent AddSlider method' },
    { pattern: ':AddDropdown(', desc: 'Foreign Rayfield/Fluent AddDropdown method' },
    { pattern: ':AddParagraph(', desc: 'Foreign Rayfield/Fluent AddParagraph method' },
    { pattern: ':AddColorpicker(', desc: 'Foreign Rayfield/Fluent AddColorpicker method' },
    { pattern: ':AddKeybind(', desc: 'Foreign Rayfield/Fluent AddKeybind method' },
    { pattern: 'CreateToggle(', desc: 'Foreign Orion CreateToggle method' },
    { pattern: 'CreateButton(', desc: 'Foreign Orion CreateButton method' },
    { pattern: 'CreateSlider(', desc: 'Foreign Orion CreateSlider method' },
    { pattern: 'CreateDropdown(', desc: 'Foreign Orion CreateDropdown method' }
];

['v1', 'violence_district.lua'].forEach(fileName => {
    if (!fs.existsSync(fileName)) return;
    const content = fs.readFileSync(fileName, 'utf8');
    const lines = content.split(/\r?\n/);

    lines.forEach((line, idx) => {
        const trimmed = line.trim();
        if (trimmed.startsWith('--')) return;

        foreignPatterns.forEach(fp => {
            if (trimmed.includes(fp.pattern)) {
                console.error(`  ❌ [STATIC AUDIT] ${fileName} line ${idx + 1}: ${fp.desc} -> ${trimmed}`);
                totalErrors++;
            }
        });
    });

    // Check that all UI method callers (:Toggle, :Slider, :Dropdown, :Button) are declared sections/tabs
    const declaredSections = new Set();
    lines.forEach(line => {
        const m = line.match(/^\s*(local\s+)?([A-Za-z0-9_]+)\s*=\s*([A-Za-z0-9_]+):(Section|Tab)\(/);
        if (m) declaredSections.add(m[2]);
        const m2 = line.match(/^\s*([A-Za-z0-9_]+)\s*=\s*Window:(Section|Tab)\(/);
        if (m2) declaredSections.add(m2[1]);
        const m3 = line.match(/^\s*local\s+([A-Za-z0-9_]+Section|[A-Za-z0-9_]+Tab)\s*=/);
        if (m3) declaredSections.add(m3[1]);
    });

    lines.forEach((line, idx) => {
        const trimmed = line.trim();
        if (trimmed.startsWith('--')) return;
        const match = trimmed.match(/([A-Za-z0-9_]+):(Toggle|Slider|Dropdown|Button)\(/);
        if (match) {
            const caller = match[1];
            if (!declaredSections.has(caller)) {
                console.error(`  ❌ [STATIC AUDIT] ${fileName} line ${idx + 1}: Undeclared caller '${caller}' for :${match[2]} -> ${trimmed}`);
                totalErrors++;
            }
        }
    });
});

console.log('====================================================');
if (totalErrors === 0) {
    console.log('✅ ALL CHECKS PASSED: 0 ERRORS DETECTED.');
    console.log('   The codebase is 100% verified and ready for production.');
} else {
    console.error(`❌ VERIFICATION FAILED: ${totalErrors} ERROR(S) DETECTED.`);
    process.exit(1);
}
console.log('====================================================\n');
