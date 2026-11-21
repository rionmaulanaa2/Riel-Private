# Violence District — Complete Architecture & Reverse Engineering Reference Manual
**Target Game**: Violence District (Roblox Place ID: `93978595733734`)  
**Source Dumps**: 
- Dump v1: `the dump.lua` (222,778 lines, 1,636 decompiled scripts)
- Dump v2: `game dump v2.lua` (232,772 lines, 1,665 decompiled scripts)

> [!IMPORTANT]
> **AI ENGINE MANDATE**: This document is the compiled, authoritative single source of truth for *Violence District* mechanics, remotes, attributes, controllers, physics, and input pipelines. **DO NOT read `the dump.lua` or `game dump v2.lua` directly in full** unless explicitly requested by the user. Always use this document as the reference guide before authoring, modifying, or debugging any Lua code for Violence District.

---

## 1. Game Overview & Differences Between Dump v1 & v2

*Violence District* is an asymmetrical 1v4 horror game on Roblox inspired by Dead by Daylight. One player controls the Killer, while four survivors attempt to repair 5 generators, unhook teammates, vault windows, drop/slide pallets, and escape through exit gates or hatch.

### Key Additions & Refactorings in Dump v2:
1. **WallSlide Migration**: `ReplicatedStorage.Modules.Survivors.SurvivorWallSlide` was refactored into the universal vector-math module `ReplicatedStorage.Modules.WallSlide` (projects motion across wall normals using dot products).
2. **KillerCollider**: Introduced `ReplicatedStorage.Modules.Killers.KillerCollider`, which dynamically welds an invisible cylinder part (`Shape = Cylinder`, `Massless = true`, `CustomPhysicalProperties = (0.7, 0, 0, 100, 1)`) to the Killer's root to prevent survivors from phasing through or body-blocking glitching.
3. **SurvivorCameraNet**: New client controller `ReplicatedStorage.Modules.Survivors.SurvivorCameraNet` supervising camera state transitions across round phases (`"lobby"`, `"intro"`, `"action"`, `"spectate"`, `"freecam"`, `"endscreen"`). It monitors `overridelookscript`, `CamAnimLock`, and `Immobile`.
4. **New Skins, Items & Audio**: Added `GhostFlame` beam style for Flashlights, new AudioPreloads (`Blood Vial`, `Spirit Torcher`, `Sweet Tooth`, `Ritual Knife`, `Hollow Jack`, `Witch's Cauldron`), and killer skins.

---

## 2. Complete Remotes Architecture (`ReplicatedStorage.Remotes`)

All game communication takes place through designated remote folders under `ReplicatedStorage:WaitForChild("Remotes")`.

### 2.1 Generator & Repair Remotes (`Remotes.Generator`)
| Remote Name | Type | Direction | Parameters | Purpose |
|---|---|---|---|---|
| `RepairEvent` | RemoteEvent | Client $\to$ Server | `(genPoint: BasePart, isRepairing: boolean, arg3: nil, requestId: string, char: Model)` | Begins or stops repairing a generator. `requestId` is generated via `HttpService:GenerateGUID(false)`. |
| `RepairAnim` | RemoteEvent | Server $\to$ Client | `(arg1, arg2, arg3, arg4, arg5, arg6, requestId: string, arg8)` | Server syncs repair animations to observers. |
| `RepairVFX` | RemoteEvent | Server $\to$ Client | `(generatorInstance, active: boolean)` | Toggles generator repair spark VFX and audio. |
| `BreakGenEvent` | RemoteEvent | Client $\to$ Server | `(genPoint: BasePart, requestId: string, killerChar: Model)` | Killer action to damage a generator (-2.5% progression, starts regression). |
| `BreakGenAnim` | RemoteEvent | Server $\to$ Client | `(killerChar, genPoint)` | Plays killer kicking generator animation. |
| `BreakGenMarker` | RemoteEvent | Server $\to$ Client | `(genModel)` | Replicates gen kick marker visually. |
| `BreakGenCommit` | RemoteEvent | Server $\to$ Client | `(requestId)` | Confirms killer kick interaction server-side. |
| `BreakGenReject` | RemoteEvent | Server $\to$ Client | `(requestId)` | Rejects killer kick if gen is blocked or completed. |
| `SkillCheckResultEvent` | RemoteEvent | Client $\to$ Server | `(result: string ("success" / "fail"), score: number (1 for Great, -10 for fail), genModel: Model, genPoint: BasePart, requestId: string, char: Model (player.Character))` | Reports skillcheck result directly to the server. Server awards +1% progression bonus on Great success (score 1). |
| `SkillCheckFailEvent` | RemoteEvent | Server $\to$ Client | `(animationId: string, genPoint: BasePart)` | Fired to survivor when a skillcheck fails. Triggers explosion VFX, regression, locks walkspeed, and forces failure animation. |
| `Escapetime` | RemoteEvent | Server $\to$ Client | `(timeRemaining: number)` | Updates endgame collapse timer. |

### 2.2 Healing Remotes (`Remotes.Healing`)
| Remote Name | Type | Direction | Parameters | Purpose |
|---|---|---|---|---|
| `HealEvent` | RemoteEvent | Client $\to$ Server | `(targetChar: Model, isHealing: boolean, requestId: string, char: Model)` | Begins or stops healing another survivor or self (with Medkit/Bandage). |
| `HealAnim` | RemoteEvent | Server $\to$ Client | `(healerChar, targetChar, requestId)` | Replicates healing animations between players. |
| `Reset` | RemoteEvent | Client $\to$ Server | `(player: Player)` | Resets healing state upon taking damage or interruption. |
| `SkillCheckFailEvent` | RemoteEvent | Server $\to$ Client | `()` | Fired when healing skillcheck fails. Resets healing progress by penalty. |

### 2.3 Exit Gate Remotes (`Remotes.Exit`)
| Remote Name | Type | Direction | Parameters | Purpose |
|---|---|---|---|---|
| `LeverEvent` | RemoteEvent | Client $\to$ Server | `(leverPoint: BasePart, isPulling: boolean, requestId: string, char: Model)` | Begins or stops opening the exit gate switch. |
| `LeverAnim` | RemoteEvent | Server $\to$ Client | `(playerChar, isPulling, requestId)` | Replicates gate opening animation. |

### 2.4 Pallet Remotes (`Remotes.Pallet`)
| Remote Name | Type | Direction | Parameters | Purpose |
|---|---|---|---|---|
| `PalletDropEvent` | RemoteEvent | Client $\to$ Server | `(palletModel: Model, requestId: string, char: Model)` | Drops an upright pallet. If Killer is in range, triggers Killer stun. Also used by Killer to break dropped pallets. |
| `PalletDropAnim` | RemoteEvent | Server $\to$ Client | `(palletModel, char)` | Replicates pallet drop physics and sound. |
| `PalletSlideEvent` | RemoteEvent | Client $\to$ Server | `(palletModel: Model, startPoint: Vector3, endPoint: Vector3)` | Survivor begins sliding over a dropped pallet. |
| `PalletSlideCompleteEvent` | RemoteEvent | Client $\to$ Server | `(palletModel: Model)` | Replicated when survivor slide completes. |
| `Jason.Stun` | RemoteEvent | Server $\to$ Client | `(killerChar: Model, duration: number)` | Replicates killer stun state (head roll, screen shake). |
| `Jason.Stunover` | RemoteEvent | Server $\to$ Client | `(killerChar: Model)` | Replicates killer stun recovery. |
| `Jason.Destroy` | RemoteEvent | Server $\to$ Client | `(palletModel: Model)` | Destroys pallet into splinter debris. |

### 2.5 Window & Vault Remotes (`Remotes.Window`)
| Remote Name | Type | Direction | Parameters | Purpose |
|---|---|---|---|---|
| `VaultEvent` | RemoteEvent | Client $\to$ Server | `(windowPart: BasePart, requestId: string, char: Model, isFast: boolean)` | Survivor or Killer vaults a window. If `isFast = true` (running vault), vault duration is ~0.5s instead of ~0.9s. |
| `fastvault` | RemoteEvent | Client $\to$ Server | `(windowPart: BasePart)` | Validates fast vault qualification based on approach angle and sprint state. |
| `VaultCommit` | RemoteEvent | Server $\to$ Client | `(requestId)` | Server confirms vault authorization. |
| `VaultReject` | RemoteEvent | Server $\to$ Client | `(requestId)` | Rejects vault if entity is blocked, stunned, or desynced. |
| `VaultCompleteEvent` | RemoteEvent | Client $\to$ Server | `(windowPart: BasePart)` | Confirms vault traversal completion. |

### 2.6 Carry & Hook Remotes (`Remotes.Carry`)
| Remote Name | Type | Direction | Parameters | Purpose |
|---|---|---|---|---|
| `CarrySurvivorEvent` | RemoteEvent | Client $\to$ Server | `(downedSurvivorChar: Model)` | Killer picks up a dying (`Knocked = true`) survivor onto their shoulder. |
| `DropSurvivorEvent` | RemoteEvent | Client $\to$ Server | `()` | Killer drops the carried survivor back to the ground. |
| `HookEvent` | RemoteEvent | Client $\to$ Server | `(hookPart: BasePart, requestId: string, killerChar: Model)` | Killer hooks the carried survivor onto a meat hook. |
| `HookCommit` | RemoteEvent | Server $\to$ Client | `(requestId)` | Server confirms hook placement. |
| `HookReject` | RemoteEvent | Server $\to$ Client | `(requestId)` | Server rejects hook placement. |
| `HookPhase` | RemoteEvent | Server $\to$ Client | `(survivorChar: Model, phase: number)` | Updates survivor hook stage: 1 (normal), 2 (struggle skillchecks), 3 (sacrifice/death). |
| `UnHookEvent` | RemoteEvent | Client $\to$ Server | `(hookedSurvivorChar: Model)` | Another survivor unhooks a teammate (takes ~1.5s). |
| `SelfUnHookEvent` | RemoteEvent | Client $\to$ Server | `()` | Hooked survivor attempts self-unhook (4% default chance, 100% with certain perks/mechanics). |
| `GetCarriedAnim` | RemoteEvent | Server $\to$ Client | `(survivorChar, killerChar)` | Binds survivor character to killer shoulder socket. |
| `CarryDropAnim` | RemoteEvent | Server $\to$ Client | `(survivorChar)` | Plays drop/wriggle free animation. |

### 2.7 Attacks & Combat Remotes (`Remotes.Attacks` & `Remotes.Killers`)
| Remote Name | Type | Direction | Parameters | Purpose |
|---|---|---|---|---|
| `BasicAttack` | RemoteEvent | Client $\to$ Server | `(...)` | Killer triggers basic attack swing. |
| `Lunge` | RemoteEvent | Client $\to$ Server | `(...)` | Killer charges forward in extended lunge attack. |
| `LungeDetect` | RemoteEvent | Client $\to$ Server | `(hitPart: BasePart, hitPoint: Vector3)` | Reports melee blade collision with survivor hitbox. |
| `AfterAttack` | RemoteEvent | Server $\to$ Client | `(isHit: boolean)` | Triggers blade wipe animation on hit (~2.7s cooldown) or miss recovery (~1.5s). |
| `AttackLock` | RemoteEvent | Server $\to$ Client | `(locked: boolean)` | Enforces attack cooldown lock on client. |
| `SlowAttack` | RemoteEvent | Server $\to$ Client | `()` | Applies slow movement penalty during attack windup. |
| `Damageviz` | RemoteEvent | Server $\to$ Client | `(damageAmount, hitLocation)` | Replicates blood spray and hit indicators. |

### 2.8 Character Mechanics & Network Remotes (`Remotes.Mechanics` & `Remotes.Game`)
| Remote Name | Type | Direction | Parameters | Purpose |
|---|---|---|---|---|
| `ChangeAttribute` | RemoteEvent | Client $\to$ Server | `(attrName: string, value: any)` | Replicates specific client state (e.g. `"Crouchingserver", true/false`). |
| `TraversalRemote` | RemoteEvent | Client $\to$ Server | `(...)` | Network validation for vault/slide position checkpoints. |
| `Teleport` | RemoteEvent | Server $\to$ Client | `(targetCFrame: CFrame)` | Server-side teleport positioning. |
| `getlookvector` | RemoteFunction | Server $\to$ Client | `()` | Server queries client's Camera LookVector for rotation validation. |
| `InterruptActions` | RemoteEvent | Server $\to$ Client | `()` | Forces cancellation of repairing, healing, or vaulting. |
| `Runevent` (in Chase) | RemoteEvent | Client $\to$ Server | `(char: Model, isSprinting: boolean)` | Synchronizes survivor sprinting state with server. |
| `PlaySFX` | RemoteEvent | Server $\to$ Client | `(soundId, parentPart, volume)` | Plays 3D spatial audio globally or locally. |
| `ReplicateCharacterLook`| RemoteEvent | Client $\to$ Server | `(headPitch: number)` | Replicates character head/torso aim pitch. |

---

## 3. Comprehensive Attributes Dictionary

### 3.1 Survivor Attributes (on Character `char`)
- `isRepairing` (`boolean`): True while actively channeling generator repair.
- `isHealing` (`boolean`): True while actively healing another survivor or self.
- `isVaulting` (`boolean`): True while traversing a window vault.
- `isSliding` (`boolean`): True while vaulting/sliding across a dropped pallet.
- `isDroppingPallet` (`boolean`): True during pallet pull-down animation.
- `isUnhooking` (`boolean`): True while rescuing a teammate from a hook.
- `isExiting` (`boolean`): True while pulling the exit gate lever.
- `Sprinting` (`boolean`): True while survivor is in active sprint mode (speeds up to ~16–22 stud/s).
- `Crouching` (`boolean`): True when crouching (lowers profile, reduces footsteps).
- `Trapped` (`boolean`): True when caught in a Killer bear trap or immobilization skill.
- `Rooted` (`boolean`): True when movement is forcibly locked by game mechanics.
- `Knocked` (`boolean`): True when survivor health drops to 0 (crawling state, dying).
- `IsHooked` (`boolean`): True when survivor is hung on a sacrificial hook.
- `IsCarried` (`boolean`): True when survivor is on Killer's shoulder.
- `HookCount` (`number`): Number of times hooked (0, 1, 2; at 3, survivor is dead).
- `Health` (`number` on Humanoid): Max 100. 100 = Healthy, 50 = Injured, 0 = Dying/Knocked.
- `speedboost` (`number`): Speed multiplier (default 1.0, sprints/perks increase to 1.5–1.75).
- `walkboost` (`number`): Walking speed modifier.
- `RepairRequestId` (`string`): Unique GUID identifying active generator repair session.
- `HealRequestId` (`string`): Unique GUID identifying active healing session.
- `ExitRequestId` (`string`): Unique GUID identifying active gate opening session.

### 3.2 Killer Attributes (on Character `char`)
- `SelectedKiller` (`string`): The internal codename of the active killer (e.g. `"Butcher"`, `"Slasher"`, `"Jason"`, `"Abysswalker"`, `"Cure"`, `"Veil"`, `"Hidden"`, `"Stalker"`).
- `isAttacking` (`boolean`): True while basic attack is winding up or swinging.
- `isLunging` (`boolean`): True while executing extended lunge dash.
- `isStunned` / `IsStunned` (`boolean`): True while incapacitated by pallet, flashlight, or perk stun.
- `IsCarrying` (`boolean`): True while carrying a survivor on shoulder.
- `ChainBusy` (`boolean`): Butcher specific: true when chainsaw rev/dash is active.
- `Butcher` (`boolean`): Flag indicating Butcher killer class.
- `Frenzy` (`boolean`): Slasher/Frenzy specific sprint mode.
- `Pursuit` (`boolean`): Chase speed acceleration attribute.
- `Hidden` (`boolean`): Stalker/Hidden stealth mode attribute.
- `ChainLungeMultiplier` (`number`): Butcher chainsaw lunge distance multiplier.
- `lungeboost` (`number`): Multiplier for lunge hold duration and reach.
- `RedStain` (`Instance`): Reference to Killer's red light projector part.

### 3.3 Camera & Anti-Cheat Supervision Attributes
- `overridelookscript` (`boolean`): When `true`, overrides default Roblox camera control to lock view onto an objective or animation. **If stuck on `true`, the user CANNOT rotate the camera!**
- `CamAnimLock` (`boolean`): True during fixed cinematic sequences. Must be `false` in normal play.
- `previewfreezelook` (`boolean`): Freeze flag used during UI previews. Must be `false`.
- `Immobile` (`boolean`): Character-level flag preventing movement input.
- `AC_ServerAnchor` (`boolean` / `Part`): Server-side anti-fly/anti-speed anchor. If client moves too fast or rubberbands, the game anchors `HumanoidRootPart`. **Never enable client-side!**

### 3.4 Player Attributes (on `player`)
- `kb_skillcheck` (`string`): Keybind for skillcheck (Default: `"Space"`).
- `kb_action` (`string`): Keybind for action/vault/repair (Default: `"Space"`).
- `kb_sprint` (`string`): Keybind for sprint (Default: `"LeftShift"`).
- `pad_skillcheck` (`string`): Console gamepad button for skillcheck (Default: `"ButtonL1"`).
- `platform` (`string`): Detected client platform (`"PC"`, `"Mobile"`, `"Console"`).
- `IsKiller` / `Role` (`boolean` / `string`): Assigned role for the current match.

---

## 4. CollectionService Tags

| Tag Name | Applied To | Purpose |
|---|---|---|
| `"Survivor"` | Character Model | Identifies active survivor entities. |
| `"SurvivorBot"`| Character Model | Identifies AI bot survivors. |
| `"Killer"` | Character Model | Identifies active killer entity. |
| `"doing action"` | `HumanoidRootPart` | Added while repairing, healing, or failing skillchecks. Blocks other interactions. |
| `"Knocked"` | Character Model | Downed survivor crawling on the ground. |
| `"pallet"` | Model / BasePart | Usable wooden pallets in workspace. |
| `"VaultPoint"` | BasePart | Valid window or obstacle vault coordinates. |
| `"window"` | Model / BasePart | Window obstacle structures. |
| `"Blocked"` | BasePart / Model | Pallet or window temporarily blocked by killer perks. |
| `"Undetectable"`| Character Model | Killer has zero terror radius and no red stain. |
| `"Silenced"` | Character Model | Survivor or killer unable to activate item/perk abilities. |
| `"Pestilence"` | Character Model | Afflicted by poison/disease slowdown. |
| `"Antiheal"` | Character Model | Survivor cannot be healed past injured state. |
| `"TrueInvis"` | Character Model | Complete invisibility active. |
| `"PlayingRound"`| Character Model | Confirms entity is a participant in active match. |

---

## 5. Skill Check Architecture & Mechanics

### 5.1 UI Hierarchy
```
PlayerGui
└── SkillCheckPromptGui (or SkillCheckPromptGui-con)
    └── Check (Frame / ImageLabel — AbsoluteSize > 2x2)
        ├── Space (ImageLabel showing key icon on PC; Visible=false on Mobile)
        │   └── key (TextLabel showing key text "Space", "Ctrl", etc.)
        ├── Needle / Pointer / Indicator (GuiObject or UIGradient — rotates dynamically)
        └── GreatZone / Success / Zone (GuiObject or UIGradient — static success sector)
```

### 5.2 Mechanics & Timing:
1. When a skill check triggers, `SkillCheckPromptGui.Enabled` becomes `true`.
2. The `Needle` begins rotating clockwise. Angular velocity is approximately $360^\circ$ per 0.9s–1.2s (~$6^\circ$/frame at 60 FPS, ~$12^\circ$/frame at 30 FPS).
3. The success sector consists of:
   - **Great Zone** (white slice, awards +1% bonus generator progress, 0 bonus on heal).
   - **Good Zone** (white/clear slice, continues repair without explosion).
   - Miss / Failure (outside zones, triggers `SkillCheckFailEvent`).
4. **All-Time Great Zone Snapping**:
   - Because the game client checks if the needle angle is aligned with the Great Zone when input is delivered, setting `needle.Rotation = targetRot` (and child `UIGradient.Rotation = targetRot`) snaps the needle directly into the Great Zone.
5. **Universal Multi-Platform Input Delivery**:
   - **PC**: `VirtualInputManager:SendKeyEvent(true, Space, false, game)` + instant key up.
   - **Mobile (Delta/Fluxus/Hydrogen)**: Must send immediate sequential tap:
     `VirtualInputManager:SendTouchEvent(0, 0, cx, cy)` immediately followed by `VirtualInputManager:SendTouchEvent(0, 2, cx, cy)` in the **exact same frame**. Holding touch down across frames causes `CameraModule.CameraInput` to steal finger 0 and lock camera rotation!
   - **Direct UI Signals**: `firesignal(check.InputBegan, mockInput, false)` with valid mock `InputObject` table (`UserInputType.Touch`, `UserInputState.Begin`, `Position`).
   - **ContextActionService**: `cas:CallFunction("skillcheck", Enum.UserInputState.Begin, dummyInput)` and `"action"`.

---

## 6. Items & Perk Systems

### 6.1 Survivor Items
1. **Twist of Fate** (`TwistoffateClient`): Reverses killer aura / movement perception.
2. **Gate** (`GateClient`): Portable portal/gateway teleportation.
3. **Adrenaline Shot** (`AdrenalineClient`): Instant +50 health heal and 3-second sprint burst.
4. **Riot Shield** (`RiotShieldClient`): Blocks one frontal killer melee hit.
5. **Holy Water** (`HolyWaterClient`): Throws consecrated vial; blinds killer and clears status ailments.
6. **Bandage** (`BandageClient`): Self-healing or teammate patch up item.
7. **Parrying Dagger** (`ParryClient`): Timing-based weapon to deflect killer basic attack.
8. **Motion Tracker** (`MotionTrackerClient`): Beeps and highlights killer position within 24 studs.
9. **Flashlight** (`FlashlightClient`): Light beam that blinds killer when aimed at face for 1.2s (causes carried survivor drop).
10. **Shadow Clone** (`ShadowCloneClient`): Deploys running decoy survivor to trigger killer red stain.
11. **Monkey's Paw** (`MonkeyPawClient`): Grants emergency teleport/escape at cost of severe debuff.
12. **WaxBound Candle**: Wards against terror radius and aura revelation.

---

## 7. Movement & Collision Architecture

### 7.1 WallSlide Algorithm (`ReplicatedStorage.Modules.WallSlide`)
- Project velocity vector $P$ across $N$ boundary planes defined by normals $v_i$ and minimum dot products $d_i$:
  $$\text{allowed}(P) = \forall i, P \cdot v_i \ge d_i - 10^{-5}$$
- If obstructed, calculates projection along intersecting normals:
  $$P_{\text{slide}} = P + v_i (d_i - P \cdot v_i)$$
- Prevents players from clipping into wall corners while maintaining smooth lateral sliding speed.

### 7.2 Anti-Stuck & Rubberband Recovery
- When moving at high speeds (NoClip / Speedhack / Teleport), server verifies position continuity.
- If rejected, server teleports character to last valid position and applies `AC_ServerAnchor`.
- **Recovery rule**: To move instantly after rubberbanding:
  1. Detect if `HumanoidRootPart.Anchored == true` or `myChar:GetAttribute("Immobile") == true`.
  2. Set `HumanoidRootPart.Anchored = false`.
  3. Set `myChar:SetAttribute("Immobile", false)`.
  4. Reset `Humanoid.WalkSpeed = 16` (or current speed setting).

---

## 8. Mandatory Rules for Violence District Script Authoring

1. **Never Read Full Dump Files in Runtime Turns**: Always consult this reference manual first.
2. **Synchronize Production Files**: Any modification to `violence_district.lua` must immediately be synchronized to `v1` and `v1.lua` (`node scripts/sync_vd.js`), verified via `node scripts/validate.js`, and pushed to GitHub (`git push origin main`).
3. **Multi-Platform Mobile Resilience**: Never dispatch touch events with delays (`task.wait`) between down and up. Always use instant-release (`state 0` then `state 2` in same frame) to protect camera panning and scrolling frames.
4. **Camera Attribute Hygiene**: Always verify that `overridelookscript`, `CamAnimLock`, and `previewfreezelook` are cleared (`false`) when character is not in active cinematic/repair/heal channel.
