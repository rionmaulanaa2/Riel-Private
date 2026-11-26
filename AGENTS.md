# Agent Engine Rules

## Background Task & Execution Timeout Rule
- **Minimum Execution Timer**: Whenever deploying background tasks (`run_command` async), launching scripts, or scheduling timers, ALWAYS specify a minimum execution/wait time of at least 1 second (1000 ms `WaitMsBeforeAsync` or `DurationSeconds >= 1` on `schedule`). Never deploy polling or async tasks with 0 ms or no wait duration.
- **Optimized Fast Downloads**: For all download operations (such as downloading Ghidra, JDK, binaries), use `$ProgressPreference = 'SilentlyContinue'` in PowerShell or `curl.exe -L` to prevent memory buffering and download throttling, ensuring high-speed transfers.

## Riel-Private Lua Script Code Updates
- **Instant Direct File Updates & GitHub Push**: For any requested changes, additions, features, or fixes for the Riel-Private Lua script, ALWAYS directly write and apply all changes immediately to the target script file (`v1` in `c:\Users\Admin\Downloads\rielv2\v1` or the active `Riel-Private` repository), and ALWAYS immediately stage, commit, and push the changes directly to GitHub (`git push origin main`) so that the remote GitHub repository is always updated instantly. Never output code solely as chat snippets without applying it to the file and pushing to GitHub.

## Riel-Private Versioning & Tracking Rule
- **Current Version**: `1.15`
- **Baseline & Persistent Memory**: Riel-Private versioning strictly starts at `1.00`. Always persist and remember the current version number both here (`Current Version` in workspace `c:\Users\Admin\Downloads\rielv2\AGENTS.md` and global `C:\Users\Admin\.gemini\config\AGENTS.md`) and inside `v1` / `v1.lua` (`local RIEL_VERSION = "1.00"`).
- **Mandatory `+0.01` Increment on Every Update**: On EVERY update, feature addition, bugfix, or script modification to Riel-Private (`v1`, `v1.lua`, or `violence_district.lua`), you MUST:
  1. Read the current version number from `local RIEL_VERSION` in `v1` and `Current Version` above.
  2. Increment it strictly by `+0.01` formatted to two decimal places (`1.00` -> `1.01` -> `1.02` -> ... -> `1.09` -> `1.10`).
  3. Update `-- Version:` and `local RIEL_VERSION` in `v1` (synchronized identically to `v1.lua`), update `Current Version` in BOTH `c:\Users\Admin\Downloads\rielv2\AGENTS.md` and `C:\Users\Admin\.gemini\config\AGENTS.md` (or run `node scripts/bump_version.js` to bump all 4 files automatically), verify with `node scripts/validate.js`, and include `[vX.XX]` in the Git commit message before pushing to GitHub.
- **Consistent Version Display on Riel**: Always render `"v" .. RIEL_VERSION` in `WindUI:CreateWindow` `Title` (`" Riel Private v" .. RIEL_VERSION`), `OpenButton.Title` (`"Riel Private v" .. RIEL_VERSION`), the startup `WindUI:Notify` message, and startup/loaded console `print` logs.

## Violence District Master Reference & Dump Anti-Reread Rule
- **Mandatory Master Reference (`VIOLENCE_DISTRICT_REFERENCE.md`)**: All AI assistants working on *Violence District* (Roblox Place ID: `93978595733734`) features, auto-farms, ESP, combat, killer automation, or skillcheck MUST consult and reference [VIOLENCE_DISTRICT_REFERENCE.md](file:///c:/Users/Admin/Downloads/rielv2/VIOLENCE_DISTRICT_REFERENCE.md) as the authoritative, comprehensive single source of truth for all game architecture:
  - **Generator Remotes**: `ReplicatedStorage.Remotes.Generator` (`RepairEvent`, `RepairAnim`, `RepairVFX`, `BreakGenEvent`, `BreakGenAnim`, `BreakGenCommit`, `BreakGenMarker`, `BreakGenReject`, `SkillCheckFailEvent`, `Escapetime`).
  - **Healing & Exit Remotes**: `ReplicatedStorage.Remotes.Healing` (`HealEvent`, `HealAnim`, `HealAnimRec`, `Reset`, `SkillCheckFailEvent`), `ReplicatedStorage.Remotes.Exit` (`LeverEvent`, `LeverAnim`).
  - **Pallet & Window Remotes**: `ReplicatedStorage.Remotes.Pallet` (`PalletDropEvent`, `PalletDropAnim`, `PalletSlideEvent`, `PalletSlideCompleteEvent`, `Jason.Stun`, `Jason.Stunover`, `Jason.Destroy`), `ReplicatedStorage.Remotes.Window` (`VaultEvent`, `fastvault`, `VaultCommit`, `VaultCompleteEvent`, `VaultReject`).
  - **Hook & Carry Remotes**: `ReplicatedStorage.Remotes.Carry` (`CarrySurvivorEvent`, `DropSurvivorEvent`, `CarryAnim`, `CarryAnimDone`, `CarryDropAnim`, `GetCarriedAnim`, `RegisterCarryAnims`, `HookEvent`, `HookCommit`, `HookReject`, `HookPhase`, `UnHookEvent`, `SelfUnHookEvent`).
  - **Attacks & Killer Systems**: `ReplicatedStorage.Remotes.Attacks` (`BasicAttack`, `Lunge`, `LungeDetect`, `AfterAttack`, `AttackLock`), `ReplicatedStorage.Remotes.Killers` (`SlowAttack`, `Damageviz`, `Butcher.CancelVault`, `KillerCollider`).
  - **Key Attributes**: Survivors track `isRepairing`, `isHealing`, `isVaulting`, `isSliding`, `isDroppingPallet`, `isUnhooking`, `isExiting`, `Sprinting`, `Crouching`, `Trapped`, `Rooted`, `Knocked`, `IsHooked`, `IsCarried`, `HookCount`. Killers track `Butcher`, `ChainBusy`, `isAttacking`, `isLunging`, `isStunned`, `IsCarrying`, `Frenzy`, `Pursuit`, `Hidden`.
  - **Anti-Cheat & Camera Attributes**: `overridelookscript`, `CamAnimLock`, `previewfreezelook`, `Immobile`, `doing action` tag, `AC_ServerAnchor`.
- **Strict Prohibition on Raw Dump Re-Reading**: AI assistants are **STRICTLY FORBIDDEN from reading `the dump.lua` or `game dump v2.lua` in full** or performing repetitive, token-heavy scans on raw dump files. All reverse-engineered game architecture, signatures, and formulas have been extracted and synthesized into `VIOLENCE_DISTRICT_REFERENCE.md`. Only read raw dump files if the user explicitly commands: *"read the game dump"*, *"check dump v1/v2 directly"*, or similar.
- **Pre-Coding Architecture Verification**: Always learn and verify controller signatures and timing windows from `VIOLENCE_DISTRICT_REFERENCE.md` before writing or fixing Lua code.

## Violence District Modular Development & Isolation Rule
- **Isolated Violence District File (`violence_district.lua`)**: Whenever analyzing, developing, editing, or fixing *Violence District* features (ESP, Generator/Objectives, Combat & Defense, Rescue & Team, Killer Automation, Skillcheck), maintain and develop them in an isolated dedicated file (`violence_district.lua`). Perform full deep analysis, learning, syntax validation, and review in that isolated file first. Once completed and fully verified, seamlessly integrate and synchronize the code into the unified Riel-Private production files (`v1` and `v1.lua`), verify full compiler compatibility (0 errors with `luau-compile.exe` and `luaparse`), and immediately push to GitHub (`git push origin main`).

## Zero-Tolerance Multi-Pass Lua Compilation & Deep Static Audit Rule
- **Mandatory 4-Phase Validation Pipeline**: Before finalizing any Lua modification, committing, or pushing to GitHub, you MUST execute `node scripts/validate.js` (or equivalent multi-pass compiler script) verifying ALL 4 target files (`windui.lua`, `v1`, `v1.lua`, `violence_district.lua`):
  1. **Phase 1 (Synchronization)**: `v1` and `v1.lua` must be 100% byte-for-byte identical.
  2. **Phase 2 (Luau Bytecode Compilation)**: `luau-compile.exe` must compile all files with 0 bytecode errors.
  3. **Phase 3 (AST Syntax Parse)**: `luaparse` (Lua 5.1/Luau AST) must parse all files with 0 syntax errors.
  4. **Phase 4 (Deep Static Audit)**:
     - Zero foreign library method calls (no `:AddToggle`, `:AddSlider`, `:AddDropdown`, `:AddButton`, `:AddParagraph`, `:CreateToggle`, `Tabs.<Name>`, etc.).
     - Zero unhandled global/table nil accesses at top level.
     - All section callers must be explicitly declared and instantiated before any child elements are registered.

## WindUI & Roblox Mobile UI Architecture Rule
- **Strict UI Library Context**: WindUI syntax is strictly `:Section({ Title = "..." })`, `:Toggle({ Title = "...", Callback = ... })`, `:Slider({ ... })`, `:Dropdown({ ... })`, `:Button({ ... })`. Never mix Fluent, Rayfield, or Orion APIs.
- **Debounced Toggle & Touch Protection**: Any interactive UI button or accordion header that binds to both `MouseButton1Click` and `Activated` MUST implement a 0.20s–0.25s debounce (`os.clock() - lastToggle < 0.25`) to prevent double-firing and instant open-close reversal.
- **Touchscreen Coordinate Resolution**: Dropdown boundary and touch tracking must always prioritize `InputObject.Position` for touch devices over `Mouse.X`/`Mouse.Y` to prevent immediate unintended auto-closing.
- **Dropdown & Popup Z-Index Supremacy**:
  - `DropdownGui.DisplayOrder` must be set to `2147483647` (highest 32-bit integer) with `ZIndexBehavior = Enum.ZIndexBehavior.Sibling`.
  - All popup canvases (`MenuCanvas`, `Menu`) must have explicit high `ZIndex` (`1000000+`) to ensure they render in front of the main window on all mobile executors (Delta, Hydrogen, Fluxus).
  - Positioning must dynamically query `workspace.CurrentCamera` on every update (with fallback to `ScreenGui.AbsoluteSize`) and clamp cleanly adjacent to the trigger button without stale camera coordinates or arbitrary large gaps.
- **Accordion Container Height Minimums**: Sections must calculate target heights using `math.max(HeaderSize, Top.AbsoluteSize.Y)` and `math.max(Content.AbsoluteSize.Y, UIListLayout.AbsoluteContentSize.Y)` to prevent collapsing to 0 height or clipping behind `ClipsDescendants`.

## Dynamic Character Lifecycle & Cross-Match Resilience Rule
- **Clean Cross-Match State Transitions**: Never maintain static cached references to player characters or previous round roles.
- **Session Token Invalidation**: Whenever the player character dies, respawns, or the map changes, immediately increment automation session counters (`repairSession = repairSession + 1`, `palletSession = palletSession + 1`, `catchSession = catchSession + 1`) to terminate previous loops safely.
- **Dynamic Role Verification**: In Violence District, re-verify Killer vs Survivor status on every loop cycle using live character items, equipped weapons, animations, and killer attributes (`Butcher`, `ChainBusy`, `isStunned`).

## First-Principles Deep Learning & Error Prevention Rule
- When debugging reported errors, do not guess or apply superficial surface edits. Formulate hypotheses, trace complete dependency trees from line 1 to the end of the file, write diagnostic node scripts to test hypotheses against the raw file, verify the exact root cause, and apply systemic fixes across the entire codebase.
