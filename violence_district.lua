-- ============================================================
-- VIOLENCE DISTRICT ISOLATED MODULE (violence_district.lua)
-- Roblox Place ID: 93978595733734
-- Features: Role Detection, ESP & Visuals, Objectives & Skillcheck,
-- Combat & Defense, Rescue & Team, Killer Automation.
-- ============================================================

local ViolenceTab = nil
local V_ESPSection = nil
local V_SurvivorEXSection = nil
local V_ObjectiveSection = nil
local V_CombatSection = nil
local V_RescueSection = nil
local V_RoleSection = nil
local V_ServerRemotesSection = nil
local V_KillerSection = nil

-- Shared Cross-Block Entity Detection, Roles & Navigation State
local trackedSurvivors = {}
local isEntityInLobbyOrSpectating = nil
local isCharacterKnocked = nil
local isCharacterHooked = nil
local isCharacterSurvivor = nil
local isCharacterKiller = nil
local getKiller = nil
local isPlayerKiller = nil
local isKillerCarrying = nil
local isKillerStunnedOrLocked = nil
local isSurvivorParryingOrShielded = nil
local updateKillerAim = nil
local cleanSurvivorESP = nil
local isValidCharacter = nil
local checkWallCollision = nil
local startTravelNoClip = nil
local stopTravelNoClip = nil
local computeSmartWaypoints = nil
local autoCatchEXEnabled = false
local exFailPauseDuration = 2
local exFailPauseActive = false
local exPostKnockWaitDuration = 3
local exPostKnockPauseActive = false
local ghostRepairEXEnabled = false
local ghostRepairEXSession = 0
local currentGhostEXPoint = nil
local currentGhostEXModel = nil
local ghostEXHoldPos = nil
local stopGhostRepairEX = nil
local vdESPState = {
    killerToggle = nil,
    genToggle = nil,
    survivorToggle = nil,
    hookToggle = nil,
    ghostRepairEXToggle = nil,
    autoRoleESPEnabled = true,
    autoSurvivorEXEnabled = true,
    hookESPEnabled = false,
    cleanHookESP = nil,
    lastAppliedRole = nil,
    lastAppliedEXRole = nil,
    autoFleeEnabled = false,
    autoFleeDistance = 100,
    autoFleeSession = 0,
    autoFleePauseUntil = 0,
    autoFleeBlocking = false,
    autoFleeHoldPos = nil,
    autoFleeToggle = nil,
    fleeKnockEXEnabled = false,
    fleeKnockEXSession = 0,
    fleeKnockEXBlocking = false,
    fleeKnockHoldPos = nil,
    fleeKnockEXToggle = nil,
    rescueEXEnabled = false,
    rescueEXSession = 0,
    rescueEXHoldPos = nil,
    rescueEXPaused = false,
    rescueEXWantsPriority = false,
    rescueEXSafeDist = 100,
    rescueEXToggle = nil,
    ghostEXPaused = false,
    autoLeverEXEnabled = false,
    autoLeverEXSession = 0,
    autoLeverEXHoldPos = nil,
    autoLeverEXPaused = false,
    autoLeverEXWantsPriority = false,
    autoLeverEXToggle = nil,
    isLocalCaptured = nil,
    setMovementBypass = nil,
    microTransitTo = nil,
    findFloorYBelow = nil,
    findFurthestSafeGround = nil,
    computeGenUndergroundPoint = nil,
    bigJumpTimestamps = {},
    lastServerAnchorTick = 0,
    lastACAnchorTick = 0
}

do
ViolenceTab = Window:Tab({
    Title = "Violence District",
    Icon = "swords"
})

V_ESPSection = ViolenceTab:Section({
    Title = "ESP & Visuals"
})

V_SurvivorEXSection = ViolenceTab:Section({
    Title = "Survivor EX"
})

V_ObjectiveSection = ViolenceTab:Section({
    Title = "Objectives & Skillcheck"
})

V_CombatSection = ViolenceTab:Section({
    Title = "Combat & Defense"
})

V_RescueSection = ViolenceTab:Section({
    Title = "Rescue & Team"
})

V_RoleSection = ViolenceTab:Section({
    Title = "Role Detection & Mode Switcher"
})

-- ============================================================
-- AUTHORITATIVE ROLE IDENTIFICATION (KILLER & SURVIVOR)
-- ============================================================
-- Authoritative role identification variables initialized at top level

local function isScreenGuiActive(gui)
    if not gui then return false end
    if gui:IsA("ScreenGui") then
        return gui.Enabled == true
    end
    if gui:IsA("GuiObject") then
        return gui.Visible == true
    end
    return true
end

vdESPState.isActualKiller = function()
    local myChar = player.Character
    if not myChar then return false end

    -- 1. Explicit Team verification (Authoritative in Violence District)
    if player.Team then
        local tName = player.Team.Name:lower()
        if tName:find("killer") or tName:find("slasher") then
            return true
        end
        if tName:find("survivor") or tName:find("lobby") or tName:find("spectat") then
            return false
        end
    end

    -- 2. Authoritative CollectionService Role Tags
    if CollectionService then
        if CollectionService:HasTag(myChar, "Killer") or CollectionService:HasTag(myChar, "Killers")
            or CollectionService:HasTag(player, "Killer") or CollectionService:HasTag(player, "Killers") then
            return true
        end
        if CollectionService:HasTag(myChar, "Survivor") or CollectionService:HasTag(myChar, "Survivors")
            or CollectionService:HasTag(player, "Survivor") or CollectionService:HasTag(player, "Survivors") then
            return false
        end
    end

    -- 3. Authoritative explicit Role / boolean IsKiller attributes (NEVER check SelectedKiller or `~= nil`, since Survivors also store SelectedKiller and false attrs!)
    if player:GetAttribute("IsKiller") == true or myChar:GetAttribute("IsKiller") == true
        or player:GetAttribute("Killer") == true or myChar:GetAttribute("Killer") == true
        or player:GetAttribute("killer") == true or myChar:GetAttribute("killer") == true then
        return true
    end
    local pRole = player:GetAttribute("Role") or myChar:GetAttribute("Role")
    if type(pRole) == "string" then
        local rLower = pRole:lower()
        if rLower == "killer" or rLower == "slasher" then
            return true
        end
        if rLower:find("survivor") or rLower == "lobby" or rLower:find("spectat") then
            return false
        end
    end

    -- 4. Survivor-exclusive gameplay attributes & hooked/knocked states
    if (isCharacterHooked and isCharacterHooked(myChar))
        or (isCharacterKnocked and isCharacterKnocked(myChar))
        or myChar:GetAttribute("HookCount") ~= nil
        or myChar:GetAttribute("isRepairing") == true
        or myChar:GetAttribute("isHealing") == true
        or myChar:GetAttribute("isDroppingPallet") == true
        or myChar:GetAttribute("isUnhooking") == true
        or myChar:GetAttribute("isExiting") == true
        or myChar:GetAttribute("isSliding") == true then
        return false
    end

    -- 5. Active visible PlayerGui HUD (require Enabled == true on ScreenGui; never match disabled/preloaded templates!)
    local pg = player:FindFirstChild("PlayerGui")
    if pg then
        local killerHudActive = false
        local survivorHudActive = false
        for _, gui in ipairs(pg:GetChildren()) do
            local gName = gui.Name:lower()
            if gName ~= "killerperks" then
                if (gName == "slasher" or gName:find("slasher-") or gName == "killergui" or gName == "killerhud") and isScreenGuiActive(gui) then
                    killerHudActive = true
                elseif (gName == "survivor" or gName:find("survivor-")) and isScreenGuiActive(gui) then
                    survivorHudActive = true
                end
            end
        end
        if killerHudActive and not survivorHudActive then
            return true
        end
        if survivorHudActive and not killerHudActive then
            return false
        end
    end

    -- 6. Strict boolean Killer gameplay attributes & exclusive Killer components
    local kCarry = myChar:GetAttribute("killercarry")
    if myChar:GetAttribute("Butcher") == true
        or myChar:GetAttribute("ChainBusy") == true
        or myChar:GetAttribute("Frenzy") == true
        or myChar:GetAttribute("Pursuit") == true
        or myChar:GetAttribute("Stalker") == true
        or myChar:GetAttribute("Hidden") == true
        or myChar:GetAttribute("isAttacking") == true
        or myChar:GetAttribute("isLunging") == true
        or kCarry == true or (type(kCarry) == "string" and #kCarry > 0) then
        return true
    end
    if myChar:FindFirstChild("CancelVault") or myChar:FindFirstChild("RedStain")
        or myChar:FindFirstChild("KillerHitbox") or myChar:FindFirstChild("KillerCollider") then
        return true
    end

    -- 7. Equipped or Backpack Killer Tool weapons (exclude Survivor tools)
    local function isKillerToolItem(item)
        if not item:IsA("Tool") then return false end
        local iName = item.Name:lower()
        if iName:find("parry") or iName:find("dagger") or iName:find("shield") or iName:find("medkit")
            or iName:find("bandage") or iName:find("toolbox") or iName:find("flashlight") then
            return false
        end
        return iName:find("cleaver") or iName:find("machete") or iName:find("chainsaw")
            or iName:find("killerweapon") or iName:find("beartrap") or iName:find("slasher")
            or iName:find("axe") or iName:find("blade")
    end

    for _, item in ipairs(myChar:GetChildren()) do
        if isKillerToolItem(item) then
            return true
        end
    end
    local bp = player:FindFirstChild("Backpack")
    if bp then
        for _, item in ipairs(bp:GetChildren()) do
            if isKillerToolItem(item) then
                return true
            end
        end
    end

    return false
end

local function checkPlayerKillerStatus()
    -- If user has enabled any killer automation feature, treat as Killer for combat/aim
    if autoCatchEnabled or autoCatchEXEnabled or autoAimSurvivorEnabled or autoHitSurvivorEnabled or autoHookSurvivorEnabled then
        return true
    end
    return vdESPState.isActualKiller()
end

isPlayerKiller = checkPlayerKillerStatus

autoRoleAdaptEnabled = false -- Default to false so it NEVER disables active user toggles
local lastDetectedRole = nil

vdESPState.detectRole = function()
    local myChar = player.Character
    if not myChar or not myChar.Parent or not myChar:FindFirstChild("HumanoidRootPart") then
        return "Lobby"
    end
    if isEntityInLobbyOrSpectating and isEntityInLobbyOrSpectating(myChar, player) then
        return "Lobby"
    end
    if player.Team then
        local tName = player.Team.Name:lower()
        if tName:find("lobby") or tName:find("spectat") then
            return "Lobby"
        end
    end
    local pRole = player:GetAttribute("Role") or myChar:GetAttribute("Role")
    if type(pRole) == "string" then
        local rLower = pRole:lower()
        if rLower == "lobby" or rLower:find("spectat") then
            return "Lobby"
        end
    end

    -- Use pure game-state Killer check so ESP never gets tricked by stray toggles or SelectedKiller
    if vdESPState.isActualKiller() then
        return "Killer"
    end

    -- Confirm player is actively in match as Survivor (not standing in pre-match Lobby)
    if player.Team and player.Team.Name:lower():find("survivor") then
        return "Survivor"
    end
    if type(pRole) == "string" and pRole:lower():find("survivor") then
        return "Survivor"
    end
    if CollectionService and (CollectionService:HasTag(myChar, "Survivor") or CollectionService:HasTag(player, "Survivor")) then
        return "Survivor"
    end
    local pg = player:FindFirstChild("PlayerGui")
    if pg and (isScreenGuiActive(pg:FindFirstChild("Survivor-mob")) or isScreenGuiActive(pg:FindFirstChild("Survivor")) or isScreenGuiActive(pg:FindFirstChild("Survivor-con"))) then
        return "Survivor"
    end
    if myChar:GetAttribute("isRepairing") ~= nil or myChar:GetAttribute("isHealing") ~= nil or myChar:GetAttribute("HookCount") ~= nil then
        return "Survivor"
    end
    if workspace:FindFirstChild("Map") or workspace:FindFirstChild("map") then
        return "Survivor"
    end
    if CollectionService and #CollectionService:GetTagged("GeneratorPoint") > 0 then
        return "Survivor"
    end

    return "Lobby"
end

vdESPState.setToggleSafe = function(toggleObj, desired)
    if not toggleObj then return end
    if toggleObj.Value ~= desired and toggleObj.Set then
        pcall(function() toggleObj:Set(desired) end)
    end
end

vdESPState.applyRoleESPs = function(role)
    if not (vdESPState.killerToggle and vdESPState.genToggle and vdESPState.survivorToggle and vdESPState.hookToggle) then
        return false
    end
    if role == "Survivor" then
        vdESPState.setToggleSafe(vdESPState.survivorToggle, true)
        vdESPState.setToggleSafe(vdESPState.genToggle, true)
        vdESPState.setToggleSafe(vdESPState.killerToggle, true)
        vdESPState.setToggleSafe(vdESPState.hookToggle, false)
        return true
    elseif role == "Killer" then
        vdESPState.setToggleSafe(vdESPState.hookToggle, true)
        vdESPState.setToggleSafe(vdESPState.survivorToggle, true)
        vdESPState.setToggleSafe(vdESPState.genToggle, false)
        vdESPState.setToggleSafe(vdESPState.killerToggle, false)
        return true
    end
    return false
end

vdESPState.applyRoleSurvivorEX = function(role)
    if not (vdESPState.fleeKnockEXToggle and vdESPState.autoFleeToggle and vdESPState.rescueEXToggle and vdESPState.autoLeverEXToggle and vdESPState.ghostRepairEXToggle) then
        return false
    end
    if role == "Survivor" then
        vdESPState.setToggleSafe(vdESPState.fleeKnockEXToggle, true)
        vdESPState.setToggleSafe(vdESPState.autoFleeToggle, true)
        vdESPState.setToggleSafe(vdESPState.rescueEXToggle, true)
        vdESPState.setToggleSafe(vdESPState.autoLeverEXToggle, true)
        vdESPState.setToggleSafe(vdESPState.ghostRepairEXToggle, true)
        return true
    elseif role == "Killer" then
        vdESPState.setToggleSafe(vdESPState.ghostRepairEXToggle, false)
        vdESPState.setToggleSafe(vdESPState.autoLeverEXToggle, false)
        vdESPState.setToggleSafe(vdESPState.rescueEXToggle, false)
        vdESPState.setToggleSafe(vdESPState.autoFleeToggle, false)
        vdESPState.setToggleSafe(vdESPState.fleeKnockEXToggle, false)
        return true
    end
    return false
end

V_RoleSection:Toggle({
    Title = "Auto Role ESP",
    Description = "Auto-detects Killer/Survivor role: enables Survivor, Generator & Killer ESP for Survivor; Hook & Survivor ESP for Killer",
    Default = true,
    Callback = function(v)
        vdESPState.autoRoleESPEnabled = v
        if v then
            vdESPState.lastAppliedRole = nil
        end
    end
})

V_RoleSection:Toggle({
    Title = "Auto Survivor EX",
    Description = "Automatically activates all Survivor EX features when role is Survivor (disables when Killer)",
    Default = true,
    Callback = function(v)
        vdESPState.autoSurvivorEXEnabled = v
        if v then
            vdESPState.lastAppliedEXRole = nil
        end
    end
})

V_RoleSection:Toggle({
    Title = "Auto Role Adapt",
    Description = "Automatically detects Killer/Survivor role and auto-disables opposing features",
    Default = false,
    Callback = function(v)
        autoRoleAdaptEnabled = v
    end
})

-- Background Auto-Role & Auto-ESP Monitor Thread (runs every 0.5 seconds)
task.spawn(function()
    while scriptRunning do
        pcall(function()
            if not scriptRunning then return end

            if vdESPState.autoRoleESPEnabled or vdESPState.autoSurvivorEXEnabled then
                local matchRole = vdESPState.detectRole()
                if matchRole == "Lobby" then
                    if vdESPState.autoRoleESPEnabled then
                        vdESPState.lastAppliedRole = nil
                    end
                    if vdESPState.autoSurvivorEXEnabled then
                        vdESPState.lastAppliedEXRole = nil
                    end
                else
                    if vdESPState.autoRoleESPEnabled and matchRole ~= vdESPState.lastAppliedRole then
                        if vdESPState.applyRoleESPs(matchRole) then
                            vdESPState.lastAppliedRole = matchRole
                        end
                    end
                    if vdESPState.autoSurvivorEXEnabled and matchRole ~= vdESPState.lastAppliedEXRole then
                        if vdESPState.applyRoleSurvivorEX(matchRole) then
                            vdESPState.lastAppliedEXRole = matchRole
                        end
                    end
                end
            end

            if autoRoleAdaptEnabled then
                -- NEVER override or shut down active features manually enabled by the user!
                if autoCatchEnabled or autoCatchEXEnabled or autoAimSurvivorEnabled or autoHitSurvivorEnabled or autoHookSurvivorEnabled then
                    -- Killer automation is actively in use
                    lastDetectedRole = "Killer"
                elseif autoRepairEnabled or ghostRepairEnabled or ghostRepairEXEnabled or autoPalletEnabled or autoParryEnabled or autoDodgeEnabled or autoSaveEnabled or (vdESPState and (vdESPState.autoFleeEnabled or vdESPState.rescueEXEnabled or vdESPState.fleeKnockEXEnabled or vdESPState.autoLeverEXEnabled)) then
                    -- Survivor automation is actively in use
                    lastDetectedRole = "Survivor"
                else
                    local isKiller = isPlayerKiller and isPlayerKiller()
                    local currentRole = isKiller and "Killer" or "Survivor"

                    if currentRole ~= lastDetectedRole then
                        lastDetectedRole = currentRole
                        if currentRole == "Killer" then
                            repairSession = (repairSession or 0) + 1
                            ghostRepairSession = (ghostRepairSession or 0) + 1
                            ghostRepairEXSession = (ghostRepairEXSession or 0) + 1
                            saveSession = (saveSession or 0) + 1
                            palletSession = (palletSession or 0) + 1
                            parrySession = (parrySession or 0) + 1
                            dodgeSession = (dodgeSession or 0) + 1
                            if ghostRepairEnabled then ghostRepairEnabled = false if stopGhostRepair then pcall(stopGhostRepair) end end
                            if ghostRepairEXEnabled then ghostRepairEXEnabled = false if stopGhostRepairEX then pcall(stopGhostRepairEX) end end
                            autoRepairEnabled = false
                            autoDodgeEnabled = false
                            autoPalletEnabled = false
                            autoParryEnabled = false
                            autoSaveEnabled = false
                            if vdESPState then
                                vdESPState.autoFleeEnabled = false
                                vdESPState.autoFleeBlocking = false
                                vdESPState.autoFleePauseUntil = 0
                                vdESPState.autoFleeSession = (vdESPState.autoFleeSession or 0) + 1
                                vdESPState.fleeKnockEXEnabled = false
                                vdESPState.fleeKnockEXBlocking = false
                                vdESPState.fleeKnockEXSession = (vdESPState.fleeKnockEXSession or 0) + 1
                                vdESPState.rescueEXEnabled = false
                                vdESPState.rescueEXHoldPos = nil
                                vdESPState.rescueEXPaused = false
                                vdESPState.rescueEXWantsPriority = false
                                vdESPState.rescueEXSession = (vdESPState.rescueEXSession or 0) + 1
                                vdESPState.autoLeverEXEnabled = false
                                vdESPState.autoLeverEXHoldPos = nil
                                vdESPState.autoLeverEXPaused = false
                                vdESPState.autoLeverEXWantsPriority = false
                                vdESPState.autoLeverEXSession = (vdESPState.autoLeverEXSession or 0) + 1
                            end
                        elseif currentRole == "Survivor" then
                            catchSession = (catchSession or 0) + 1
                            autoCatchEnabled = false
                            autoCatchEXEnabled = false
                            autoHookSurvivorEnabled = false
                            autoAimSurvivorEnabled = false
                            autoHitSurvivorEnabled = false
                            currentKillerTarget = nil
                            if updateKillerAim then updateKillerAim() end
                        end
                    end
                end
            end
        end)
        task.wait(0.5)
    end
end)


local HttpService = game:GetService("HttpService")
local VirtualInputManager = nil
pcall(function()
    VirtualInputManager = game:GetService("VirtualInputManager")
end)

-- Remote access helper (Expanded with Collision & Mechanics from the dump.lua)
getVDRemotes = function()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not remotes then return {} end
    return {
        Generator = remotes:FindFirstChild("Generator"),
        Healing = remotes:FindFirstChild("Healing"),
        Pallet = remotes:FindFirstChild("Pallet"),
        Window = remotes:FindFirstChild("Window"),
        Carry = remotes:FindFirstChild("Carry"),
        Attacks = remotes:FindFirstChild("Attacks"),
        Killers = remotes:FindFirstChild("Killers"),
        Exit = remotes:FindFirstChild("Exit"),
        Collision = remotes:FindFirstChild("Collision"),
        Mechanics = remotes:FindFirstChild("Mechanics"),
        Chase = remotes:FindFirstChild("Chase")
    }
end

-- Resilient helper to locate DisableCollision remote
local function getDisableCollisionRemote()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local col = remotes:FindFirstChild("Collision")
        if col and col:FindFirstChild("DisableCollision") then
            return col.DisableCollision
        end
    end
    for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
        if desc.Name == "DisableCollision" and (desc:IsA("RemoteEvent") or desc:IsA("UnreliableRemoteEvent")) then
            return desc
        end
    end
    return nil
end

-- Resilient helper to locate EnableCollision remote
local function getEnableCollisionRemote()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local col = remotes:FindFirstChild("Collision")
        if col and col:FindFirstChild("EnableCollision") then
            return col.EnableCollision
        end
    end
    for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
        if desc.Name == "EnableCollision" and (desc:IsA("RemoteEvent") or desc:IsA("UnreliableRemoteEvent")) then
            return desc
        end
    end
    return nil
end

-- Resilient helper to locate Mechanics.ChangeAttribute remote
local function getChangeAttributeRemote()
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        local mech = remotes:FindFirstChild("Mechanics")
        if mech and mech:FindFirstChild("ChangeAttribute") then
            return mech.ChangeAttribute
        end
    end
    for _, desc in ipairs(ReplicatedStorage:GetDescendants()) do
        if desc.Name == "ChangeAttribute" and (desc:IsA("RemoteEvent") or desc:IsA("UnreliableRemoteEvent")) then
            return desc
        end
    end
    return nil
end

local function fireDisableCollision()
    local r = getDisableCollisionRemote()
    if r then
        pcall(function() r:FireServer() end)
    end
end

local function fireEnableCollision()
    local r = getEnableCollisionRemote()
    if r then
        pcall(function() r:FireServer() end)
    end
end

local function fireChangeAttribute(attrName, val)
    local r = getChangeAttributeRemote()
    if r then
        pcall(function() r:FireServer(attrName, val) end)
    end
end

-- ============================================================
-- CORE MATCH, ROLE & ENTITY RECOGNITION ENGINE
-- ============================================================
-- Unified authoritative system ensuring 100% accurate role, team,
-- and entity detection across rounds, respawns, and lobby transitions.

isValidCharacter = function(char)
    if not char or not char.Parent then return false end
    if not char:IsDescendantOf(workspace) then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then return false end
    return true, hum, hrp
end

isEntityInLobbyOrSpectating = function(char, plr)
    if not char and not plr then return true end
    plr = plr or (char and Players:GetPlayerFromCharacter(char))

    if plr then
        if plr:GetAttribute("InLobby") == true or plr:GetAttribute("Lobby") == true then
            return true
        end
        if plr:GetAttribute("IsDead") == true or plr:GetAttribute("HasEscaped") == true or plr:GetAttribute("Escaped") == true then
            return true
        end
    end

    if char then
        if char:GetAttribute("InLobby") == true or char:GetAttribute("Lobby") == true then
            return true
        end
        local lobby = workspace:FindFirstChild("Lobby")
        if lobby and char:IsDescendantOf(lobby) then
            return true
        end
    end

    return false
end
local isSurvivorInLobby = isEntityInLobbyOrSpectating

isCharacterHooked = function(char)
    if not char or not char.Parent then return false end

    -- 1. Direct authoritative game attribute set by server when survivor is hung on a hook
    if char:GetAttribute("IsHooked") == true or char:GetAttribute("isHooked") == true or char:GetAttribute("Hooked") == true then
        return true
    end

    -- 2. Physical MeatHook Weld verification:
    -- HumanoidRootPart welded to a HookPoint inside workspace.Map.Hooks
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        for _, joint in ipairs(hrp:GetJoints()) do
            local other = (joint.Part0 == hrp) and joint.Part1 or joint.Part0
            if other and other:IsA("BasePart") then
                local hookModel = other:FindFirstAncestorOfClass("Model")
                if hookModel and (hookModel.Name:lower():find("hook") or (hookModel.Parent and hookModel.Parent.Name:lower() == "hooks")) then
                    if (hrp.Position - other.Position).Magnitude <= 5.0 then
                        return true
                    end
                end
            end
        end
    end

    -- 3. Model parented directly inside a Hook model in Map.Hooks
    local p = char.Parent
    if p and p:IsA("Model") and p.Name:lower():find("hook") then
        local grandParent = p.Parent
        if grandParent and grandParent.Name:lower() == "hooks" then
            return true
        end
    end

    return false
end

isCharacterKnocked = function(char)
    if not char or not char.Parent then return false end

    -- 1. Direct authoritative game attributes set by server on downed crawling survivors
    if char:GetAttribute("Knocked") == true or char:GetAttribute("isKnocked") == true
        or char:GetAttribute("Downed") == true or char:GetAttribute("isDowned") == true
        or char:GetAttribute("Down") == true or char:GetAttribute("Crawling") == true
        or char:GetAttribute("BleedingOut") == true then
        return true
    end

    -- 2. CollectionService tags
    if CollectionService and (CollectionService:HasTag(char, "Knocked") or CollectionService:HasTag(char, "Downed")) then
        return true
    end

    -- 3. ValueObject children (strictly verify BoolValue.Value == true)
    local kChild = char:FindFirstChild("Knocked") or char:FindFirstChild("Downed") or char:FindFirstChild("downed")
    if kChild then
        if kChild:IsA("BoolValue") then
            if kChild.Value == true then return true end
        end
    end

    -- 4. Health threshold from game dump v2 (SURVIVOR_HEALTH_THRESHOLD = 20)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health > 0 and hum.Health <= 20 then
        return true
    end

    -- 5. PlatformStand / Physics state when ragdolled or crawling on floor (only if damaged)
    if hum and hum.Health > 0 and hum.Health <= 50 and (hum.PlatformStand or hum:GetState() == Enum.HumanoidStateType.Physics) then
        return true
    end

    return false
end

-- Helper to detect if Killer is currently carrying a survivor on shoulder
isKillerCarrying = (function()
    local function isCarryFlagTruthy(val)
        if val == true then return true end
        if type(val) == "string" then
            local trimmed = val:gsub("^%s+", ""):gsub("%s+$", ""):lower()
            return trimmed ~= "" and trimmed ~= "false" and trimmed ~= "none" and trimmed ~= "nil" and trimmed ~= "0"
        end
        if typeof(val) == "Instance" then
            return true
        end
        return false
    end

    local function hasNonEmptyCarryChild(char)
        for _, cname in ipairs({ "CarriedSurvivor", "Carry" }) do
            local ch = char:FindFirstChild(cname)
            if ch then
                if ch:IsA("ObjectValue") then
                    if ch.Value ~= nil then return true end
                elseif ch:IsA("BoolValue") then
                    if ch.Value == true then return true end
                elseif ch:IsA("StringValue") then
                    if isCarryFlagTruthy(ch.Value) then return true end
                elseif ch:IsA("Model") and ch:FindFirstChildOfClass("Humanoid") then
                    return true
                end
            end
        end
        return false
    end

    local function isSurvivorCarriedFlag(sChar)
        return sChar:GetAttribute("IsCarried") == true
            or sChar:GetAttribute("isCarried") == true
            or sChar:GetAttribute("BeingCarried") == true
    end

    return function(char)
        char = char or player.Character
        if not char or not char.Parent then return false end
        if char:GetAttribute("IsCarrying") == true
            or char:GetAttribute("isCarrying") == true
            or isCarryFlagTruthy(char:GetAttribute("killercarry"))
            or isCarryFlagTruthy(char:GetAttribute("BeingCarried"))
            or hasNonEmptyCarryChild(char) then
            return true
        end

        local kHrp = char:FindFirstChild("HumanoidRootPart")
        for _, plr in ipairs(Players:GetPlayers()) do
            local sChar = plr.Character
            if sChar and sChar ~= char and sChar.Parent and isSurvivorCarriedFlag(sChar) then
                local sHrp = sChar:FindFirstChild("HumanoidRootPart")
                if not kHrp or not sHrp or (sHrp.Position - kHrp.Position).Magnitude <= 12 then
                    return true
                end
            end
        end

        if trackedSurvivors then
            for sChar, _ in pairs(trackedSurvivors) do
                if sChar and sChar.Parent and sChar ~= char and isSurvivorCarriedFlag(sChar) then
                    local sHrp = sChar:FindFirstChild("HumanoidRootPart")
                    if not kHrp or not sHrp or (sHrp.Position - kHrp.Position).Magnitude <= 12 then
                        return true
                    end
                end
            end
        end

        return false
    end
end)()

-- Helper to detect if Killer is currently stunned, blinded, or immobilized by survivor items/pallets
isKillerStunnedOrLocked = function(char)
    if not char or not char.Parent then return false end

    -- 1. Game attributes set by Violence District on actual stun/blind/shot
    if char:GetAttribute("isStunned") == true 
        or char:GetAttribute("IsStunned") == true 
        or char:GetAttribute("Stunned") == true 
        or char:GetAttribute("Blinded") == true 
        or char:GetAttribute("Stun") == true then
        return true
    end

    -- 2. CollectionService stun tags
    if CollectionService and (CollectionService:HasTag(char, "Stunned") or CollectionService:HasTag(char, "Stun")) then
        return true
    end

    -- 3. Stun child marker instances
    if char:FindFirstChild("Stunned") or char:FindFirstChild("Stun") then
        return true
    end

    -- 4. Humanoid physical states during knockdown/stun
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and (hum.PlatformStand or hum.Sit) then
        return true
    end

    return false
end

-- Helper to detect if target survivor is currently parrying (ParryingDagger) or blocking (RiotShield)
isSurvivorParryingOrShielded = function(sChar)
    if not sChar or not sChar.Parent then return false end

    if sChar:GetAttribute("isParrying") == true 
        or sChar:GetAttribute("Parrying") == true 
        or sChar:GetAttribute("IsParrying") == true 
        or sChar:GetAttribute("ShieldActive") == true 
        or sChar:GetAttribute("Blocking") == true then
        return true
    end

    -- Check equipped parry/shield tools
    for _, item in ipairs(sChar:GetChildren()) do
        if item:IsA("Tool") then
            local iName = item.Name:lower()
            if iName:find("parry") or iName:find("dagger") or iName:find("shield") or iName:find("riot") then
                if item:GetAttribute("Active") == true or item:GetAttribute("Blocking") == true or item:GetAttribute("Parrying") == true then
                    return true
                end
            end
        end
    end

    return false
end

isCharacterKiller = function(char, plr)
    local valid, hum, hrp = isValidCharacter(char)
    if not valid then return false end
    plr = plr or Players:GetPlayerFromCharacter(char)

    -- If entity is in Lobby or Spectating, they are not an active Killer in match
    if isEntityInLobbyOrSpectating(char, plr) then
        return false
    end

    -- If checking local player, use comprehensive killer check
    if char == player.Character then
        return (isPlayerKiller and isPlayerKiller()) or false
    end

    -- RANKED MODE & MATCH GUARANTEE:
    -- In a 1v4 match, if the local player IS the Killer, NO other character can be the Killer!
    if isPlayerKiller and isPlayerKiller() then
        return false
    end

    -- 1. Explicit Team verification
    if plr and plr.Team then
        local tName = plr.Team.Name:lower()
        if tName == "survivors" or tName:find("survivor") then
            return false
        end
        if tName == "killer" or tName:find("killer") or tName:find("slasher") then
            return true
        end
        if tName:find("spectat") or tName:find("lobby") then
            return false
        end
    end

    -- 2. Survivor-exclusive Role, Tags, & interaction state attributes
    local sRole = (plr and plr:GetAttribute("Role")) or char:GetAttribute("Role")
    if type(sRole) == "string" and sRole:lower():find("survivor") then
        return false
    end
    if CollectionService and (CollectionService:HasTag(char, "Survivor") or CollectionService:HasTag(char, "Survivors")
        or (plr and (CollectionService:HasTag(plr, "Survivor") or CollectionService:HasTag(plr, "Survivors")))) then
        return false
    end
    if char:GetAttribute("isRepairing") == true 
        or char:GetAttribute("isHealing") == true 
        or char:GetAttribute("isDroppingPallet") == true 
        or char:GetAttribute("isUnhooking") == true 
        or char:GetAttribute("isExiting") == true 
        or char:GetAttribute("isSliding") == true 
        or char:GetAttribute("HookCount") ~= nil
        or isCharacterHooked(char) 
        or isCharacterKnocked(char) then
        return false
    end

    -- 3. Dedicated Killer Attributes (strict boolean == true, never ~= nil on false defaults)
    if char:GetAttribute("Butcher") == true 
        or char:GetAttribute("ChainBusy") == true 
        or char:GetAttribute("Frenzy") == true 
        or char:GetAttribute("Pursuit") == true 
        or char:GetAttribute("Stalker") == true 
        or char:GetAttribute("Hidden") == true 
        or char:GetAttribute("Stealth") == true 
        or char:GetAttribute("Veil") == true 
        or char:GetAttribute("isAttacking") == true 
        or char:GetAttribute("isLunging") == true 
        or char:GetAttribute("Killer") == true 
        or char:GetAttribute("IsKiller") == true then
        return true
    end

    -- 4. CollectionService tags
    if CollectionService:HasTag(char, "Killer") or CollectionService:HasTag(char, "Killers") then
        return true
    end
    if plr and (CollectionService:HasTag(plr, "Killer") or CollectionService:HasTag(plr, "Killers")) then
        return true
    end

    -- 5. Equipped weapons / tools characteristic of Killers (exclude Survivor items)
    for _, item in ipairs(char:GetChildren()) do
        if item:IsA("Tool") then
            local iName = item.Name:lower()
            local isSurvivorTool = iName:find("parry") or iName:find("dagger") or iName:find("shield")
                or iName:find("medkit") or iName:find("bandage") or iName:find("toolbox") or iName:find("flashlight")
            if not isSurvivorTool and (iName:find("cleaver") or iName:find("machete") or iName:find("chainsaw") or iName:find("knife") or iName:find("killerweapon") or iName:find("beartrap") or iName:find("axe") or iName:find("blade")) then
                return true
            end
        end
    end

    -- 6. Playing Killer attack animations
    local animator = hum:FindFirstChildOfClass("Animator")
    if animator then
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            local animName = track.Name:lower()
            if animName:find("attack") or animName:find("slash") or animName:find("lunge") or animName:find("machete") or animName:find("chainsaw") then
                return true
            end
        end
    end

    -- 7. Held items in hand or back
    for _, desc in ipairs(char:GetDescendants()) do
        if desc:IsA("BasePart") then
            local dName = desc.Name:lower()
            if dName == "cleaver" or dName == "machete" or dName == "chainsaw" or dName == "killerweapon" or dName:find("slasherknife") then
                return true
            end
        end
    end

    -- 8. Known killer model names in workspace (ONLY for NPC models where plr is nil!)
    if not plr then
        local cName = char.Name:lower()
        local killerModelNames = { "butcher", "slasher", "jason", "abysswalker", "cure", "veil", "stalker", "hidden", "masked", "killer" }
        for _, kName in ipairs(killerModelNames) do
            if cName == kName or cName:find(kName) then
                return true
            end
        end
    end

    -- 9. Killer specific child objects/scripts
    if char:FindFirstChild("CancelVault") or char:FindFirstChild("Damageviz") or char:FindFirstChild("RedStain") or char:FindFirstChild("KillerHitbox") then
        return true
    end

    return false
end

getKiller = function()
    local myChar = player.Character

    -- If local player is the Killer, return their character directly!
    if isPlayerKiller and isPlayerKiller() then
        return myChar
    end

    -- 1. Check all other players in Players
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and plr.Character ~= myChar then
            if isCharacterKiller(plr.Character, plr) then
                return plr.Character
            end
        end
    end

    -- 2. Check CollectionService "Killer" tagged objects (models in workspace)
    local taggedKiller = nil
    pcall(function()
        for _, obj in ipairs(CollectionService:GetTagged("Killer")) do
            if obj and obj:IsA("Model") and obj ~= myChar and obj:IsDescendantOf(workspace) then
                if isCharacterKiller(obj) then
                    taggedKiller = obj
                    break
                end
            end
        end
    end)
    if taggedKiller then return taggedKiller end

    -- 3. Check workspace top-level models
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") and obj ~= myChar and obj:IsDescendantOf(workspace) and not Players:GetPlayerFromCharacter(obj) then
            if isCharacterKiller(obj) then
                return obj
            end
        end
    end

    return nil
end

-- Authoritative survivor verification: Strictly excludes Killer, Lobby, and Spectators.
isCharacterSurvivor = function(char, plr)
    local valid, hum, hrp = isValidCharacter(char)
    if not valid then return false end
    if char == player.Character then return false end
    plr = plr or Players:GetPlayerFromCharacter(char)

    -- Under no circumstance can the Killer be classified as a Survivor
    if isCharacterKiller(char, plr) then
        return false
    end
    local currentKiller = getKiller and getKiller()
    if currentKiller and (char == currentKiller or (plr and Players:GetPlayerFromCharacter(currentKiller) == plr)) then
        return false
    end

    -- Exclude Lobby/Spectator
    if isEntityInLobbyOrSpectating(char, plr) then
        return false
    end

    -- RANKED MODE GUARANTEE:
    -- If local player is the Killer, any other living character in workspace not in lobby IS a Survivor!
    if isPlayerKiller and isPlayerKiller() then
        return true
    end

    -- If player is on Killer team
    if plr and plr.Team then
        local tName = plr.Team.Name:lower()
        if tName == "killer" or tName:find("killer") or tName:find("slasher") then
            return false
        end
        if tName == "survivors" or tName:find("survivor") then
            return true
        end
    end

    -- CollectionService tags
    if CollectionService:HasTag(char, "Survivor") or CollectionService:HasTag(char, "Survivors") then
        return true
    end
    if plr and (CollectionService:HasTag(plr, "Survivor") or CollectionService:HasTag(plr, "Survivors")) then
        return true
    end

    -- Any other living player character in workspace not in lobby/spectator and not the killer IS a survivor!
    if plr and plr ~= player then
        return true
    end

    -- Characteristic survivor interaction attributes for non-player models
    if char:GetAttribute("isRepairing") ~= nil 
        or char:GetAttribute("isHealing") ~= nil 
        or char:GetAttribute("isVaulting") ~= nil 
        or char:GetAttribute("isSliding") ~= nil 
        or char:GetAttribute("isDroppingPallet") ~= nil 
        or char:GetAttribute("isUnhooking") ~= nil 
        or char:GetAttribute("isExiting") ~= nil 
        or char:GetAttribute("Sprinting") ~= nil 
        or isCharacterHooked(char) 
        or isCharacterKnocked(char) then
        return true
    end

    return false
end

-- ============================================================
-- GLOBAL MATCH RESET & ESP CLEANUP HANDLER
-- ============================================================
-- Whenever a round finishes or a player respawns, wipes all stale
-- BillboardGuis and Highlights across the entire workspace to prevent
-- old roles from lingering into subsequent games.

-- trackedSurvivors and cleanSurvivorESP initialized at top level
local cleanKillerESP = nil
local cleanGenESP = nil
local lastCapturedRepairRequestId = nil
local lastCapturedGenModel = nil
local lastCapturedGenPoint = nil
local lastCapturedHealRequestId = nil

-- Standalone camera and movement unlocker
local function unlockCameraAndMovement()
    pcall(function()
        local myChar = player.Character
        if myChar then
            myChar:SetAttribute("overridelookscript", false)
            myChar:SetAttribute("CamAnimLock", false)
            myChar:SetAttribute("previewfreezelook", false)
            myChar:SetAttribute("Immobile", false)
            local hum = myChar:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.AutoRotate = true
                if hum.WalkSpeed < 8 and not myChar:GetAttribute("Knocked") and not isCharacterKnocked(myChar) and not isCharacterHooked(myChar) then
                    hum.WalkSpeed = 16
                end
            end
            local hrp = myChar:FindFirstChild("HumanoidRootPart")
            if hrp and CollectionService then
                pcall(function() CollectionService:RemoveTag(hrp, "doing action") end)
            end
        end
        pcall(function()
            player:SetAttribute("overridelookscript", false)
            player:SetAttribute("CamAnimLock", false)
            player:SetAttribute("previewfreezelook", false)
            UserInputService.ModalEnabled = false
        end)
        local cam = workspace.CurrentCamera
        if cam then
            local myChar = player.Character
            if myChar and not myChar:GetAttribute("Knocked") and not isCharacterHooked(myChar) then
                if cam.CameraType == Enum.CameraType.Scriptable then
                    cam.CameraType = Enum.CameraType.Custom
                end
                local hum = myChar:FindFirstChildOfClass("Humanoid")
                if hum and cam.CameraSubject ~= hum then
                    cam.CameraSubject = hum
                end
            end
        end
    end)
end

local function cleanAllESPs()
    if cleanKillerESP then pcall(cleanKillerESP) end
    if cleanSurvivorESP then pcall(cleanSurvivorESP) end
    if cleanGenESP then pcall(cleanGenESP) end
    if vdESPState and vdESPState.cleanHookESP then pcall(vdESPState.cleanHookESP) end

    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj.Name == "KillerESPHighlight" or obj.Name == "KillerESPBillboard"
                or obj.Name == "SurvivorESPHighlight" or obj.Name == "SurvivorESPBillboard"
                or obj.Name == "GenESPHighlight" or obj.Name == "GenESPBillboard"
                or obj.Name == "HookESPHighlight" or obj.Name == "HookESPBillboard"
                or obj.Name == "GhostEXGenHighlight"
                or obj.Name == "AutoLeverEXHighlight" then
                obj:Destroy()
            end
        end
    end)
end

local function onMatchOrCharacterReset()
    cleanAllESPs()
    currentKillerTarget = nil
    currentRepairPoint = nil
    currentGhostEXPoint = nil
    currentGhostEXModel = nil
    ghostEXHoldPos = nil
    lastDetectedRole = nil
    if vdESPState then
        vdESPState.lastAppliedRole = nil
        vdESPState.lastAppliedEXRole = nil
        vdESPState.autoFleeBlocking = false
        vdESPState.autoFleePauseUntil = 0
        vdESPState.autoFleeHoldPos = nil
        vdESPState.fleeKnockEXBlocking = false
        vdESPState.fleeKnockHoldPos = nil
        vdESPState.rescueEXHoldPos = nil
        vdESPState.rescueEXPaused = false
        vdESPState.rescueEXWantsPriority = false
        vdESPState.ghostEXPaused = false
        vdESPState.autoLeverEXHoldPos = nil
        vdESPState.autoLeverEXPaused = false
        vdESPState.autoLeverEXWantsPriority = false
        vdESPState.bigJumpTimestamps = {}
        vdESPState.lastServerAnchorTick = 0
        vdESPState.lastACAnchorTick = 0
    end
    lastCapturedRepairRequestId = nil
    lastCapturedGenModel = nil
    lastCapturedGenPoint = nil
    lastCapturedHealRequestId = nil
    unlockCameraAndMovement()
end

-- Shared Anti-Cheat Bypass, Underground Micro-Transit & Safe Map Ground Utilities
pcall(function()
    local CollectionService = game:GetService("CollectionService")

    vdESPState.isLocalCaptured = function(myChar)
        if not myChar or not myChar.Parent then return false end
        if isCharacterHooked and isCharacterHooked(myChar) then
            return true
        end
        local capturedAttrs = {
            "IsHooked", "isHooked", "Hooked",
            "IsCarried", "isCarried", "BeingCarried",
            "Chained", "isChained", "IsChained",
            "ChainGrabbed", "ChainHit", "Grabbed", "Captured", "Pulled"
        }
        for _, attr in ipairs(capturedAttrs) do
            if myChar:GetAttribute(attr) == true then
                return true
            end
        end
        if CollectionService then
            for _, tagName in ipairs({ "Hooked", "Chained", "Carried", "Grabbed", "Captured" }) do
                if CollectionService:HasTag(myChar, tagName) then
                    return true
                end
            end
        end
        local killer = getKiller and getKiller()
        local hrp = myChar:FindFirstChild("HumanoidRootPart")
        if hrp then
            for _, joint in ipairs(hrp:GetJoints()) do
                local other = (joint.Part0 == hrp) and joint.Part1 or joint.Part0
                if other and other:IsA("BasePart") and not other:IsDescendantOf(myChar) then
                    if killer and other:IsDescendantOf(killer) then
                        return true
                    end
                    local m = other:FindFirstAncestorOfClass("Model")
                    local nm = ((m and m.Name or "") .. " " .. other.Name):lower()
                    if nm:find("hook") or nm:find("chain") then
                        return true
                    end
                end
            end
        end
        for _, desc in ipairs(myChar:GetDescendants()) do
            if desc:IsA("RopeConstraint") or desc:IsA("AlignPosition") or desc:IsA("SpringConstraint") or desc:IsA("RodConstraint") then
                local hitBound = false
                pcall(function()
                    for _, att in ipairs({ desc.Attachment0, desc.Attachment1 }) do
                        if att and att.Parent and not att:IsDescendantOf(myChar) then
                            if killer and att:IsDescendantOf(killer) then
                                hitBound = true
                                break
                            end
                            local an = att.Parent.Name:lower()
                            if an:find("chain") or an:find("hook") then
                                hitBound = true
                                break
                            end
                        end
                    end
                end)
                if hitBound then
                    return true
                end
            end
        end
        return false
    end

    local function buildExcludeList(extraExclude)
        local exclude = {}
        local lobby = workspace:FindFirstChild("Lobby")
        if lobby then table.insert(exclude, lobby) end
        local cam = workspace.CurrentCamera
        if cam then table.insert(exclude, cam) end
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then
                table.insert(exclude, p.Character)
            end
        end
        if extraExclude then
            if typeof(extraExclude) == "Instance" then
                table.insert(exclude, extraExclude)
            elseif type(extraExclude) == "table" then
                for _, item in ipairs(extraExclude) do
                    if typeof(item) == "Instance" then
                        table.insert(exclude, item)
                    end
                end
            end
        end
        return exclude
    end

    vdESPState.setMovementBypass = function(char, enabled)
        if not char or not char.Parent then return end
        pcall(function()
            if enabled then
                if char:GetAttribute("BypassNoclipAntiCheat") ~= true then
                    char:SetAttribute("BypassNoclipAntiCheat", true)
                end
                if char:GetAttribute("donttrack") ~= true then
                    char:SetAttribute("donttrack", true)
                end
                if (char:GetAttribute("NetTraversalUntil") or 0) < 999999999 then
                    char:SetAttribute("NetTraversalUntil", 999999999)
                end
                if char:GetAttribute("AC_ServerAnchor") ~= nil then
                    char:SetAttribute("AC_ServerAnchor", nil)
                end
            else
                local stillNeeded = noClipEnabled
                    or (ghostRepairEXEnabled and not vdESPState.ghostEXPaused)
                    or (vdESPState.rescueEXEnabled and not vdESPState.rescueEXPaused)
                    or (vdESPState.autoLeverEXEnabled and not vdESPState.autoLeverEXPaused)
                    or (vdESPState.autoFleeHoldPos ~= nil)
                    or (vdESPState.fleeKnockHoldPos ~= nil)
                if not stillNeeded then
                    if char:GetAttribute("BypassNoclipAntiCheat") == true then
                        char:SetAttribute("BypassNoclipAntiCheat", false)
                    end
                    if char:GetAttribute("donttrack") == true then
                        char:SetAttribute("donttrack", false)
                    end
                    if char:GetAttribute("NetTraversalUntil") ~= nil then
                        char:SetAttribute("NetTraversalUntil", nil)
                    end
                end
            end
        end)
    end

    vdESPState.findFloorYBelow = function(x, yStart, z, extraExclude)
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        rp.FilterDescendantsInstances = buildExcludeList(extraExclude)
        rp.IgnoreWater = true

        local curOrigin = Vector3.new(x, yStart + 3, z)
        for _ = 1, 4 do
            local hit = workspace:Raycast(curOrigin, Vector3.new(0, -45, 0), rp)
            if not hit or not hit.Instance then break end
            if hit.Instance.CanCollide and not hit.Instance:FindFirstAncestor("Lobby") then
                return hit.Position.Y
            end
            curOrigin = hit.Position + Vector3.new(0, -0.5, 0)
        end
        return nil
    end

    vdESPState.computeGenUndergroundPoint = function(pt, genModel, desiredBelowPt, cachedFloorY)
        if not pt or not pt.Parent then return nil, nil end
        local floorY = cachedFloorY
        if not floorY and vdESPState.findFloorYBelow then
            floorY = vdESPState.findFloorYBelow(pt.Position.X, pt.Position.Y, pt.Position.Z, genModel)
        end
        local depth = desiredBelowPt or math.clamp(tonumber(ghostDepthOffset) or 7.0, 5.6, 7.6)
        local desiredY = pt.Position.Y - depth
        -- Only apply floorY burial clamp when floorY is the actual floor under the generator (not a lower basement/void raycast hit)
        if floorY and floorY <= (pt.Position.Y - 0.5) and floorY >= (pt.Position.Y - 4.6) then
            local maxSafeBuriedY = floorY - 3.3
            if desiredY > maxSafeBuriedY then
                desiredY = maxSafeBuriedY
            end
        end
        -- Strictly preserve server RepairEvent vertical range (<= 7.8 studs below RepairPoint)
        local maxReachMinY = pt.Position.Y - 7.8
        if desiredY < maxReachMinY then
            desiredY = maxReachMinY
        end
        return Vector3.new(pt.Position.X, desiredY, pt.Position.Z), floorY
    end

    vdESPState.microTransitTo = function(myChar, myHrp, targetPos, checkFn, setCollisionFalse, verifyTol)
        if not myChar or not myHrp or not myHrp.Parent then return false end
        local RS = game:GetService("RunService")

        local function isServerAnchored()
            if not myHrp or not myHrp.Parent or not myChar or not myChar.Parent then return false end
            return myHrp.Anchored or (myChar:GetAttribute("AC_ServerAnchor") ~= nil)
        end

        local function pruneBurstTimestamps(now)
            if type(vdESPState.bigJumpTimestamps) ~= "table" then
                vdESPState.bigJumpTimestamps = {}
                return 0
            end
            local kept = {}
            for _, ts in ipairs(vdESPState.bigJumpTimestamps) do
                if (now - ts) < 55.0 then
                    table.insert(kept, ts)
                end
            end
            vdESPState.bigJumpTimestamps = kept
            return #kept
        end

        local function prepTransit()
            vdESPState.setMovementBypass(myChar, true)
            if myHrp.Anchored then
                vdESPState.lastServerAnchorTick = tick()
                myHrp.Anchored = false
            end
            if myChar:GetAttribute("AC_ServerAnchor") ~= nil then
                vdESPState.lastACAnchorTick = tick()
                vdESPState.lastServerAnchorTick = tick()
            end
            pcall(function()
                if myChar:GetAttribute("Rooted") == true then myChar:SetAttribute("Rooted", false) end
                if myChar:GetAttribute("Immobile") == true then myChar:SetAttribute("Immobile", false) end
                if myChar:GetAttribute("AC_ServerAnchor") ~= nil then myChar:SetAttribute("AC_ServerAnchor", nil) end
                if myChar:GetAttribute("isRepairing") == true then myChar:SetAttribute("isRepairing", false) end
                if CollectionService then
                    CollectionService:RemoveTag(myHrp, "doing action")
                    CollectionService:RemoveTag(myChar, "doing action")
                end
            end)
            local hum = myChar:FindFirstChildOfClass("Humanoid")
            if hum then
                if hum.PlatformStand then hum.PlatformStand = false end
                if hum.Sit then hum.Sit = false end
            end
            if setCollisionFalse then
                for _, part in ipairs(myChar:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end

        local tol = verifyTol or 6.5
        local curPos = myHrp.Position
        local totalDist = (targetPos - curPos).Magnitude

        -- Tier 1: Short distance (<= 22 studs) - instant 1-frame snap, 0 burst tokens spent
        if totalDist <= 22.0 then
            prepTransit()
            myHrp.AssemblyLinearVelocity = Vector3.zero
            myHrp.AssemblyAngularVelocity = Vector3.zero
            myHrp.CFrame = CFrame.new(targetPos)
            for _ = 1, 2 do
                RS.Heartbeat:Wait()
                if checkFn and not checkFn() then return false end
                if not myHrp or not myHrp.Parent then return false end
                if isServerAnchored() then
                    vdESPState.lastServerAnchorTick = tick()
                    return false
                end
            end
            if (myHrp.Position - targetPos).Magnitude <= math.max(tol, 10.0) then
                if (myHrp.Position - targetPos).Magnitude > tol then
                    myHrp.CFrame = CFrame.new(targetPos)
                    myHrp.AssemblyLinearVelocity = Vector3.zero
                    myHrp.AssemblyAngularVelocity = Vector3.zero
                end
                return (myHrp.Position - targetPos).Magnitude <= tol
            end
            vdESPState.lastServerAnchorTick = tick()
            return false
        end

        -- Tier 2: Burst budget available (< 2 big jumps in 55s & no recent AC anchor) -> instant <1ms jump + server sync check
        local now = tick()
        local activeBursts = pruneBurstTimestamps(now)
        local sinceAnchor = now - math.max(vdESPState.lastServerAnchorTick or 0, vdESPState.lastACAnchorTick or 0)
        if activeBursts < 2 and sinceAnchor > 12.0 then
            table.insert(vdESPState.bigJumpTimestamps, now)
            local jumpStartedAt = tick()
            prepTransit()
            myHrp.AssemblyLinearVelocity = Vector3.zero
            myHrp.AssemblyAngularVelocity = Vector3.zero
            myHrp.CFrame = CFrame.new(targetPos)

            local serverAccepted = true
            for _ = 1, 2 do
                RS.Heartbeat:Wait()
                if checkFn and not checkFn() then return false end
                if not myHrp or not myHrp.Parent then return false end
                if isServerAnchored() or (vdESPState.lastACAnchorTick or 0) >= jumpStartedAt then
                    vdESPState.lastServerAnchorTick = tick()
                    serverAccepted = false
                    break
                end
                if (myHrp.Position - targetPos).Magnitude > math.max(tol, 12.0) then
                    vdESPState.lastServerAnchorTick = tick()
                    serverAccepted = false
                    break
                end
            end

            if serverAccepted and (myHrp.Position - targetPos).Magnitude <= math.max(tol, 8.0) then
                myHrp.AssemblyLinearVelocity = Vector3.zero
                myHrp.AssemblyAngularVelocity = Vector3.zero
                return true
            end
            -- Server rejected burst jump: accept server position calmly instead of creating client/server desync
            task.wait(0.20)
            if checkFn and not checkFn() then return false end
            if not myHrp or not myHrp.Parent then return false end
        end

        -- Tier 3: Discrete 17-stud server-synced hops (0 continuous 185-studs/s void-glide anti-fly triggers)
        curPos = myHrp.Position
        local startTime = tick()
        local rollbackHits = 0
        local lockHits = 0

        while (tick() - startTime) < 4.5 do
            if checkFn and not checkFn() then return false end
            if not myHrp or not myHrp.Parent then return false end

            curPos = myHrp.Position
            local remVec = targetPos - curPos
            local remDist = remVec.Magnitude
            if remDist <= 17.5 then
                local finalStart = tick()
                prepTransit()
                myHrp.AssemblyLinearVelocity = Vector3.zero
                myHrp.AssemblyAngularVelocity = Vector3.zero
                myHrp.CFrame = CFrame.new(targetPos)
                for _ = 1, 2 do
                    RS.Heartbeat:Wait()
                    if checkFn and not checkFn() then return false end
                    if not myHrp or not myHrp.Parent then return false end
                    if isServerAnchored() or (vdESPState.lastACAnchorTick or 0) >= finalStart then
                        vdESPState.lastServerAnchorTick = tick()
                        return false
                    end
                end
                return (myHrp.Position - targetPos).Magnitude <= math.max(tol, 8.0)
            end

            local hopLen = (rollbackHits > 0) and 11.5 or 17.0
            local hopXZ
            local flatVec = Vector3.new(remVec.X, 0, remVec.Z)
            if flatVec.Magnitude >= 0.2 then
                local flatDir = flatVec.Unit
                local flatStep = math.min(hopLen, flatVec.Magnitude)
                hopXZ = Vector3.new(curPos.X + flatDir.X * flatStep, 0, curPos.Z + flatDir.Z * flatStep)
            else
                local stepVec = curPos + (remVec.Unit * math.min(hopLen, remDist))
                hopXZ = Vector3.new(stepVec.X, 0, stepVec.Z)
            end

            local hopY = targetPos.Y
            if setCollisionFalse and vdESPState.findFloorYBelow then
                local hopFloorY = vdESPState.findFloorYBelow(hopXZ.X, math.max(curPos.Y, targetPos.Y) + 10, hopXZ.Z, nil)
                if hopFloorY then
                    hopY = hopFloorY - 4.0
                else
                    local frac = math.clamp(hopLen / math.max(remDist, 1), 0, 1)
                    hopY = curPos.Y + (targetPos.Y - curPos.Y) * frac
                end
            else
                local frac = math.clamp(hopLen / math.max(remDist, 1), 0, 1)
                hopY = curPos.Y + (targetPos.Y - curPos.Y) * frac
            end

            local nextPos = Vector3.new(hopXZ.X, hopY, hopXZ.Z)
            local hopStart = tick()
            prepTransit()
            myHrp.AssemblyLinearVelocity = Vector3.zero
            myHrp.AssemblyAngularVelocity = Vector3.zero
            myHrp.CFrame = CFrame.new(nextPos)

            -- Pace discrete hops (~0.24s) while verifying server accepts X/Z (no fake client-only drifting)
            local settleTime = (rollbackHits > 0) and 0.30 or 0.24
            local settleEnd = tick() + settleTime
            local hopRejected = false
            while tick() < settleEnd do
                RS.Heartbeat:Wait()
                if checkFn and not checkFn() then return false end
                if not myHrp or not myHrp.Parent then return false end

                local actualPos = myHrp.Position
                if isServerAnchored() or (vdESPState.lastACAnchorTick or 0) >= hopStart then
                    vdESPState.lastServerAnchorTick = tick()
                    lockHits = lockHits + 1
                    hopRejected = true
                    break
                end

                local horizErr = Vector3.new(actualPos.X - nextPos.X, 0, actualPos.Z - nextPos.Z).Magnitude
                if horizErr > 10.5 then
                    vdESPState.lastServerAnchorTick = tick()
                    rollbackHits = rollbackHits + 1
                    hopRejected = true
                    break
                end

                -- Keep Y from falling into void while preserving server-accepted X/Z cleanly
                if setCollisionFalse and math.abs(actualPos.Y - nextPos.Y) > 0.7 then
                    myHrp.AssemblyLinearVelocity = Vector3.zero
                    myHrp.AssemblyAngularVelocity = Vector3.zero
                    myHrp.CFrame = CFrame.new(actualPos.X, nextPos.Y, actualPos.Z)
                end
            end

            if hopRejected then
                if lockHits >= 2 or rollbackHits >= 3 then
                    return false
                end
                task.wait(0.25)
            end
        end

        return (myHrp.Position - targetPos).Magnitude <= tol
    end

    vdESPState.findFurthestSafeGround = function(myChar, myPos, kPos)
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        rp.FilterDescendantsInstances = buildExcludeList(nil)
        rp.IgnoreWater = true

        local anchors = {}
        local minY, maxY = math.huge, -math.huge
        local function pushAnchor(pos)
            table.insert(anchors, pos)
            if pos.Y < minY then minY = pos.Y end
            if pos.Y > maxY then maxY = pos.Y end
        end

        pcall(function()
            for _, pt in ipairs(CollectionService:GetTagged("GeneratorPoint")) do
                if pt:IsA("BasePart") and pt:IsDescendantOf(workspace) and not pt:FindFirstAncestor("Lobby") then
                    pushAnchor(pt.Position)
                end
            end
            for _, pt in ipairs(CollectionService:GetTagged("UnhookPoint")) do
                if pt:IsA("BasePart") and pt:IsDescendantOf(workspace) and not pt:FindFirstAncestor("Lobby") then
                    pushAnchor(pt.Position)
                end
            end
            local map = workspace:FindFirstChild("Map") or workspace:FindFirstChild("map")
            if map then
                for _, folderName in ipairs({ "Generators", "new Generators", "generators", "Hooks", "Exits", "ExitGates", "Gates" }) do
                    local f = map:FindFirstChild(folderName)
                    if f then
                        for _, child in ipairs(f:GetChildren()) do
                            local p = child:IsA("BasePart") and child or (child:IsA("Model") and (child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")))
                            if p then pushAnchor(p.Position) end
                        end
                    end
                end
            end
        end)

        if minY == math.huge then
            minY = myPos.Y - 35
            maxY = myPos.Y + 35
        end

        local function tryFloor(x, yHint, z)
            local hit = workspace:Raycast(Vector3.new(x, yHint + 28, z), Vector3.new(0, -85, 0), rp)
            if not hit or not hit.Instance then return nil end
            if not hit.Instance.CanCollide or hit.Instance:FindFirstAncestor("Lobby") then return nil end
            if hit.Normal.Y < 0.65 then return nil end
            if hit.Position.Y < (minY - 18) or hit.Position.Y > (maxY + 38) then return nil end
            local upHit = workspace:Raycast(hit.Position + Vector3.new(0, 1.5, 0), Vector3.new(0, 4.2, 0), rp)
            if upHit and upHit.Instance and upHit.Instance.CanCollide then return nil end
            return hit.Position + Vector3.new(0, 3.0, 0)
        end

        local bestPos, bestKDist = nil, -1
        for i = 1, math.min(#anchors, 36) do
            local a = anchors[i]
            local gp = tryFloor(a.X + 3.0, a.Y, a.Z + 3.0)
            if gp then
                local kd = (gp - kPos).Magnitude
                if kd > bestKDist then
                    bestKDist = kd
                    bestPos = gp
                end
            end
        end

        local flatAway = Vector3.new(myPos.X - kPos.X, 0, myPos.Z - kPos.Z)
        flatAway = (flatAway.Magnitude >= 0.1) and flatAway.Unit or Vector3.new(1, 0, 0)
        local baseAngle = math.atan2(flatAway.Z, flatAway.X)
        for _, rad in ipairs({ 120, 180, 240, 290 }) do
            for _, angOff in ipairs({ 0, 0.55, -0.55, 1.15, -1.15, 2.0, -2.0 }) do
                local ang = baseAngle + angOff
                local gp = tryFloor(kPos.X + math.cos(ang) * rad, myPos.Y, kPos.Z + math.sin(ang) * rad)
                if gp then
                    local kd = (gp - kPos).Magnitude
                    if kd > bestKDist then
                        bestKDist = kd
                        bestPos = gp
                    end
                end
            end
        end

        return bestPos, bestKDist
    end
end)

-- Connect local player respawn
player.CharacterAdded:Connect(function(newChar)
    task.wait(0.4)
    onMatchOrCharacterReset()
end)

-- Connect other players' character respawns and team changes (cleans only that specific player's tracking)
local function setupPlayerListeners(plr)
    if not plr or plr == player then return end
    plr.CharacterAdded:Connect(function(newChar)
        task.wait(0.3)
        if trackedSurvivors then
            for c, data in pairs(trackedSurvivors) do
                if c == newChar or (plr and Players:GetPlayerFromCharacter(c) == plr) then
                    if data.hl then pcall(function() data.hl:Destroy() end) end
                    if data.bb then pcall(function() data.bb:Destroy() end) end
                    trackedSurvivors[c] = nil
                end
            end
        end
    end)
end

for _, plr in ipairs(Players:GetPlayers()) do
    setupPlayerListeners(plr)
end
Players.PlayerAdded:Connect(setupPlayerListeners)

-- ============================================================
-- 1. KILLER ESP (CROSS-MATCH PERSISTENT & REAL-TIME STATUS)
-- ============================================================
local killerESPEnabled = false
local killerESPHighlight = nil
local killerESPBillboard = nil
local lastTrackedKiller = nil

cleanKillerESP = function()
    if killerESPHighlight then
        pcall(function() killerESPHighlight:Destroy() end)
        killerESPHighlight = nil
    end
    if killerESPBillboard then
        pcall(function() killerESPBillboard:Destroy() end)
        killerESPBillboard = nil
    end
    lastTrackedKiller = nil
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj.Name == "KillerESPHighlight" or obj.Name == "KillerESPBillboard" then
                pcall(function() obj:Destroy() end)
            end
        end
    end)
end

vdESPState.killerToggle = V_ESPSection:Toggle({
    Title = "Killer ESP",
    Description = "Highlights the Killer with real-time status & distance (Persists seamlessly across matches)",
    Default = false,
    Callback = function(v)
        killerESPEnabled = v
        if not v then
            cleanKillerESP()
            return
        end
    end
})

-- Permanent Autonomous Background Supervisor (Never crashes, automatically re-attaches across new matches)
task.spawn(function()
    while scriptRunning do
        if killerESPEnabled then
            pcall(function()
                local myChar = player.Character
                local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                local isLocalKiller = isPlayerKiller and isPlayerKiller()

                -- If local player is Killer, Killer ESP is not needed
                if isLocalKiller then
                    cleanKillerESP()
                    return
                end

                local killer = getKiller()
                if killer and killer.Parent and killer:IsDescendantOf(workspace) and killer:FindFirstChild("HumanoidRootPart") and myHrp then
                    local kHrp = killer.HumanoidRootPart
                    local dist = (myHrp.Position - kHrp.Position).Magnitude

                    -- Strip any stray Survivor ESP that may have attached to killer
                    local sHl = killer:FindFirstChild("SurvivorESPHighlight")
                    if sHl then pcall(function() sHl:Destroy() end) end
                    local sBb = kHrp:FindFirstChild("SurvivorESPBillboard")
                    if sBb then pcall(function() sBb:Destroy() end) end

                    -- Rebind if killer instance changed (new match / new killer)
                    if lastTrackedKiller ~= killer then
                        cleanKillerESP()
                        lastTrackedKiller = killer
                    end

                    -- Highlight
                    if not killerESPHighlight or killerESPHighlight.Parent ~= killer then
                        pcall(function() if killerESPHighlight then killerESPHighlight:Destroy() end end)
                        killerESPHighlight = Instance.new("Highlight")
                        killerESPHighlight.Name = "KillerESPHighlight"
                        killerESPHighlight.FillColor = Color3.fromRGB(255, 30, 30)
                        killerESPHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                        killerESPHighlight.FillTransparency = 0.4
                        killerESPHighlight.OutlineTransparency = 0.1
                        killerESPHighlight.Parent = killer
                    end

                    -- Billboard
                    if not killerESPBillboard or killerESPBillboard.Parent ~= kHrp then
                        pcall(function() if killerESPBillboard then killerESPBillboard:Destroy() end end)
                        killerESPBillboard = Instance.new("BillboardGui")
                        killerESPBillboard.Name = "KillerESPBillboard"
                        killerESPBillboard.Adornee = kHrp
                        killerESPBillboard.Size = UDim2.fromOffset(190, 52)
                        killerESPBillboard.StudsOffset = Vector3.new(0, 3.8, 0)
                        killerESPBillboard.AlwaysOnTop = true

                        local label = Instance.new("TextLabel")
                        label.Name = "Label"
                        label.Size = UDim2.fromScale(1, 1)
                        label.BackgroundTransparency = 1
                        label.TextColor3 = Color3.fromRGB(255, 60, 60)
                        label.TextStrokeTransparency = 0.2
                        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                        label.Font = Enum.Font.GothamBold
                        label.TextScaled = true
                        label.Parent = killerESPBillboard

                        killerESPBillboard.Parent = kHrp
                    end

                    if killerESPBillboard and killerESPBillboard:FindFirstChild("Label") then
                        local status = "STALKING"
                        local statusColor = Color3.fromRGB(255, 60, 60)

                        if killer:GetAttribute("isStunned") == true or isKillerStunnedOrLocked(killer) then
                            status = "STUNNED"
                            statusColor = Color3.fromRGB(255, 220, 0)
                        elseif isKillerCarrying and isKillerCarrying(killer) then
                            status = "CARRYING SURVIVOR"
                            statusColor = Color3.fromRGB(255, 140, 0)
                        elseif killer:GetAttribute("isAttacking") == true then
                            status = "ATTACKING"
                            statusColor = Color3.fromRGB(255, 0, 0)
                        elseif killer:GetAttribute("isLunging") == true then
                            status = "LUNGING"
                            statusColor = Color3.fromRGB(255, 0, 0)
                        elseif killer:GetAttribute("Frenzy") == true then
                            status = "FRENZY"
                            statusColor = Color3.fromRGB(255, 50, 150)
                        elseif killer:GetAttribute("Hidden") == true then
                            status = "STEALTH"
                            statusColor = Color3.fromRGB(150, 50, 255)
                        end

                        killerESPBillboard.Label.Text = string.format("👹 KILLER [%s]\n%.0f studs", status, dist)
                        killerESPBillboard.Label.TextColor3 = statusColor
                        if killerESPHighlight then
                            killerESPHighlight.FillColor = statusColor
                        end
                    end
                else
                    cleanKillerESP()
                end
            end)
        else
            cleanKillerESP()
        end
        task.wait(0.2)
    end
end)
-- ============================================================
-- 2. GENERATOR ESP
-- ============================================================
local genESPEnabled = false
local genESPObjects = {}

cleanGenESP = function()
    for _, item in ipairs(genESPObjects) do
        pcall(function() item:Destroy() end)
    end
    genESPObjects = {}
end

local function isGeneratorModel(model)
    if not model or not model:IsA("Model") or not model:IsDescendantOf(workspace) then return false end
    if model:FindFirstAncestor("Lobby") then return false end
    if model.Name:lower():find("gen") or model:FindFirstChild("GeneratorBody") or model:FindFirstChild("RepairPoint") or model:FindFirstChildWhichIsA("ProximityPrompt", true) then
        return true
    end
    return false
end

vdESPState.genToggle = V_ESPSection:Toggle({
    Title = "Generator ESP",
    Description = "Highlights Generators with live progress & completion status",
    Default = false,
    Callback = function(v)
        genESPEnabled = v
        if not v then
            cleanGenESP()
            return
        end

        task.spawn(function()
            while genESPEnabled do
                cleanGenESP()
                local myChar = player.Character
                local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                local CollectionService = game:GetService("CollectionService")

                local processedModels = {}

                for _, obj in ipairs(workspace:GetDescendants()) do
                    if not genESPEnabled then break end
                    if isGeneratorModel(obj) and not processedModels[obj] then
                        processedModels[obj] = true
                        local primary = obj.PrimaryPart or obj:FindFirstChild("GeneratorBody") or obj:FindFirstChildWhichIsA("BasePart")
                        if primary and myHrp then
                            local dist = (myHrp.Position - primary.Position).Magnitude

                            -- Determine progress and completed status
                            local isCompleted = false
                            local progress = 0

                            local rawProg = obj:GetAttribute("RepairProgress") or obj:GetAttribute("Progress")
                            if rawProg and tonumber(rawProg) then
                                progress = tonumber(rawProg)
                                if progress >= 99.5 then isCompleted = true end
                            end

                            if CollectionService:HasTag(obj, "Blocked") or CollectionService:HasTag(obj, "Repaired") or CollectionService:HasTag(obj, "Completed") or obj:GetAttribute("Completed") == true or obj:GetAttribute("Repaired") == true then
                                isCompleted = true
                            end

                            local isEXTarget = ghostRepairEXEnabled and currentGhostEXModel and (obj == currentGhostEXModel)
                            local hlColor = isEXTarget and Color3.fromRGB(170, 0, 255)
                                or (isCompleted and Color3.fromRGB(50, 255, 80) or Color3.fromRGB(0, 210, 255))
                            local statusText = isEXTarget and string.format("⚡ GENERATOR [%.0f%% EX TARGET]", progress)
                                or (isCompleted and "⚡ GENERATOR [FIXED 100%]" or string.format("⚡ GENERATOR [%.0f%%]", progress))

                            local hl = Instance.new("Highlight")
                            hl.Name = "GenESPHighlight"
                            hl.FillColor = hlColor
                            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                            hl.FillTransparency = 0.5
                            hl.OutlineTransparency = 0.2
                            hl.Parent = obj
                            table.insert(genESPObjects, hl)

                            local bb = Instance.new("BillboardGui")
                            bb.Name = "GenESPBillboard"
                            bb.Adornee = primary
                            bb.Size = UDim2.fromOffset(150, 42)
                            bb.StudsOffset = Vector3.new(0, 3.2, 0)
                            bb.AlwaysOnTop = true

                            local lbl = Instance.new("TextLabel")
                            lbl.Size = UDim2.fromScale(1, 1)
                            lbl.BackgroundTransparency = 1
                            lbl.TextColor3 = hlColor
                            lbl.TextStrokeTransparency = 0.2
                            lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                            lbl.Font = Enum.Font.GothamBold
                            lbl.TextScaled = true
                            lbl.Text = string.format("%s\n%.0f studs", statusText, dist)
                            lbl.Parent = bb

                            bb.Parent = primary
                            table.insert(genESPObjects, bb)
                        end
                    end
                end
                task.wait(2)
            end
            cleanGenESP()
        end)
    end
})

-- ============================================================
-- SURVIVOR DETECTOR (ESP) (CROSS-MATCH PERSISTENT & FULL STATUS)
-- ============================================================
local survivorESPEnabled = false
local survivorESPObjects = {}

cleanSurvivorESP = function()
    for _, item in ipairs(survivorESPObjects) do
        pcall(function() item:Destroy() end)
    end
    survivorESPObjects = {}
    if trackedSurvivors then
        for c, data in pairs(trackedSurvivors) do
            if data then
                if data.hl then pcall(function() data.hl:Destroy() end) data.hl = nil end
                if data.bb then pcall(function() data.bb:Destroy() end) data.bb = nil end
            end
        end
    end
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj.Name == "SurvivorESPHighlight" or obj.Name == "SurvivorESPBillboard" then
                pcall(function() obj:Destroy() end)
            end
        end
    end)
end

vdESPState.survivorToggle = V_ESPSection:Toggle({
    Title = "Survivor Detector (ESP)",
    Description = "Highlights all Survivors with health, knocked/hooked state & distance (Persists across matches)",
    Default = false,
    Callback = function(v)
        survivorESPEnabled = v
        if not v then
            cleanSurvivorESP()
            return
        end
    end
})

-- Permanent Autonomous Background Supervisor (Always tracks all players & bots; renders ESP when enabled)
task.spawn(function()
    while scriptRunning do
        pcall(function()
            local myChar = player.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            local isKiller = isPlayerKiller and isPlayerKiller()
            local killerChar = isKiller and myChar or (getKiller and getKiller())

            -- Force-clean any stray survivor ESP objects attached to the Killer
            if killerChar then
                local badHl = killerChar:FindFirstChild("SurvivorESPHighlight")
                if badHl then pcall(function() badHl:Destroy() end) end
                local badBb = killerChar:FindFirstChild("SurvivorESPBillboard", true)
                if badBb then pcall(function() badBb:Destroy() end) end
                if trackedSurvivors[killerChar] then
                    pcall(function() if trackedSurvivors[killerChar].hl then trackedSurvivors[killerChar].hl:Destroy() end end)
                    pcall(function() if trackedSurvivors[killerChar].bb then trackedSurvivors[killerChar].bb:Destroy() end end)
                    trackedSurvivors[killerChar] = nil
                end
            end

            local currentSurvivors = {}
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= player and plr.Character and plr.Character ~= myChar and plr.Character ~= killerChar then
                    if isKiller then
                        local valid, hum, hrp = isValidCharacter(plr.Character)
                        if valid and not isEntityInLobbyOrSpectating(plr.Character, plr) then
                            table.insert(currentSurvivors, { char = plr.Character, name = plr.DisplayName or plr.Name, plr = plr })
                        end
                    else
                        if isCharacterSurvivor(plr.Character, plr) and not isCharacterKiller(plr.Character, plr) then
                            table.insert(currentSurvivors, { char = plr.Character, name = plr.DisplayName or plr.Name, plr = plr })
                        end
                    end
                end
            end

            -- Also search potential survivor containers in workspace for bots / NPCs
            local searchContainers = { workspace }
            for _, fName in ipairs({ "Bots", "NPCs", "Survivors", "Players", "Characters", "Match", "Entities", "Map" }) do
                local folder = workspace:FindFirstChild(fName)
                if folder and (folder:IsA("Folder") or folder:IsA("Model")) then
                    table.insert(searchContainers, folder)
                end
            end

            for _, container in ipairs(searchContainers) do
                for _, obj in ipairs(container:GetChildren()) do
                    if obj:IsA("Model") and obj ~= myChar and obj ~= killerChar and not Players:GetPlayerFromCharacter(obj) then
                        local valid, hum, hrp = isValidCharacter(obj)
                        if valid then
                            local isSurv = isKiller and not isEntityInLobbyOrSpectating(obj) or (isCharacterSurvivor(obj) and not isCharacterKiller(obj))
                            if isSurv then
                                local alreadyAdded = false
                                for _, c in ipairs(currentSurvivors) do
                                    if c.char == obj then alreadyAdded = true break end
                                end
                                if not alreadyAdded then
                                    table.insert(currentSurvivors, { char = obj, name = obj.Name, plr = nil })
                                end
                            end
                        end
                    end
                end
            end

            -- Also search CollectionService tagged survivors / bots
            if CollectionService then
                for _, tag in ipairs({ "Survivor", "Survivors", "Bot", "NPC", "SurvivorBot", "CarryTestDummy" }) do
                    for _, obj in ipairs(CollectionService:GetTagged(tag)) do
                        if obj:IsA("Model") and obj ~= myChar and obj ~= killerChar and not Players:GetPlayerFromCharacter(obj) then
                            local valid, hum, hrp = isValidCharacter(obj)
                            if valid and not isEntityInLobbyOrSpectating(obj) then
                                local alreadyAdded = false
                                for _, c in ipairs(currentSurvivors) do
                                    if c.char == obj then alreadyAdded = true break end
                                end
                                if not alreadyAdded then
                                    table.insert(currentSurvivors, { char = obj, name = obj.Name, plr = nil })
                                end
                            end
                        end
                    end
                end
            end

            local activeSet = {}
            for _, item in ipairs(currentSurvivors) do
                local c = item.char
                local hum = c:FindFirstChildOfClass("Humanoid")
                local hrp = c:FindFirstChild("HumanoidRootPart")

                if hum and hrp and hum.Health > 0 and c:IsDescendantOf(workspace) and c ~= killerChar then
                    activeSet[c] = true
                    local dist = myHrp and (myHrp.Position - hrp.Position).Magnitude or 0

                    -- Determine detailed status & color
                    local status = "HEALTHY"
                    local fillColor = Color3.fromRGB(50, 255, 50)

                    local isHooked = isCharacterHooked(c)
                    local isKnocked = isCharacterKnocked(c)
                    local isCarried = c:GetAttribute("IsCarrying") == true or c:GetAttribute("isCarried") == true or c:GetAttribute("BeingCarried") == true or c:FindFirstChild("Carried") ~= nil
                    local isRep = c:GetAttribute("isRepairing") == true
                    local isHeal = c:GetAttribute("isHealing") == true
                    local isVault = c:GetAttribute("isVaulting") == true or c:GetAttribute("isSliding") == true
                    local isUnhook = c:GetAttribute("isUnhooking") == true

                    if isHooked then
                        local phase = c:GetAttribute("HookPhase") or c:GetAttribute("HookCount")
                        status = phase and string.format("HOOKED (STAGE %s)", tostring(phase)) or "HOOKED"
                        fillColor = Color3.fromRGB(180, 50, 255)
                    elseif isCarried then
                        status = "BEING CARRIED"
                        fillColor = Color3.fromRGB(255, 120, 0)
                    elseif isKnocked then
                        status = "KNOCKED DOWN"
                        fillColor = Color3.fromRGB(255, 40, 40)
                    elseif isRep then
                        status = "REPAIRING GEN"
                        fillColor = Color3.fromRGB(0, 200, 255)
                    elseif isHeal then
                        status = "HEALING"
                        fillColor = Color3.fromRGB(0, 255, 180)
                    elseif isUnhook then
                        status = "UNHOOKING"
                        fillColor = Color3.fromRGB(255, 200, 0)
                    elseif hum.Health < hum.MaxHealth then
                        status = string.format("INJURED (%.0f HP)", hum.Health)
                        fillColor = Color3.fromRGB(255, 200, 30)
                    else
                        status = string.format("HEALTHY (%.0f HP)", hum.Health)
                        fillColor = Color3.fromRGB(50, 255, 50)
                    end

                    local record = trackedSurvivors[c]
                    if not record then
                        record = { character = c, name = item.name, player = item.plr, status = status, dist = dist }
                        trackedSurvivors[c] = record
                    else
                        record.character = c
                        record.name = item.name
                        record.player = item.plr
                        record.status = status
                        record.dist = dist
                    end

                    -- Handle Visual ESP (only when survivorESPEnabled is true)
                    if survivorESPEnabled then
                        if not record.hl or record.hl.Parent ~= c or not record.bb or record.bb.Parent ~= hrp then
                            if record.hl then pcall(function() record.hl:Destroy() end) end
                            if record.bb then pcall(function() record.bb:Destroy() end) end

                            local hl = Instance.new("Highlight")
                            hl.Name = "SurvivorESPHighlight"
                            hl.FillColor = fillColor
                            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                            hl.FillTransparency = 0.5
                            hl.OutlineTransparency = 0.2
                            hl.Parent = c

                            local bb = Instance.new("BillboardGui")
                            bb.Name = "SurvivorESPBillboard"
                            bb.Adornee = hrp
                            bb.Size = UDim2.fromOffset(170, 48)
                            bb.StudsOffset = Vector3.new(0, 3.8, 0)
                            bb.AlwaysOnTop = true

                            local lbl = Instance.new("TextLabel")
                            lbl.Name = "Label"
                            lbl.Size = UDim2.fromScale(1, 1)
                            lbl.BackgroundTransparency = 1
                            lbl.TextColor3 = fillColor
                            lbl.TextStrokeTransparency = 0.2
                            lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                            lbl.Font = Enum.Font.GothamBold
                            lbl.TextScaled = true
                            lbl.Text = string.format("👤 %s\n[%s] - %.0f studs", item.name, status, dist)
                            lbl.Parent = bb
                            bb.Parent = hrp

                            record.hl = hl
                            record.bb = bb
                            record.lbl = lbl
                        else
                            record.hl.FillColor = fillColor
                            if record.lbl then
                                record.lbl.TextColor3 = fillColor
                                record.lbl.Text = string.format("👤 %s\n[%s] - %.0f studs", item.name, status, dist)
                            end
                        end
                    else
                        -- ESP visuals disabled: destroy visual instances if they exist, but preserve tracking record!
                        if record.hl then pcall(function() record.hl:Destroy() end) record.hl = nil end
                        if record.bb then pcall(function() record.bb:Destroy() end) record.bb = nil end
                    end
                end
            end

            -- Remove dead / despawned / invalid survivors from trackedSurvivors
            for c, data in pairs(trackedSurvivors) do
                if not activeSet[c] then
                    if data.hl then pcall(function() data.hl:Destroy() end) end
                    if data.bb then pcall(function() data.bb:Destroy() end) end
                    trackedSurvivors[c] = nil
                end
            end
        end)
        task.wait(0.3)
    end
end)

-- ============================================================
-- 2.5 HOOK PLACE ESP (ALL HOOK LOCATIONS & LIVE STATUS)
-- ============================================================
do
    local hookESPObjects = {}

    local function cleanHookESP()
        for _, item in ipairs(hookESPObjects) do
            pcall(function() item:Destroy() end)
        end
        hookESPObjects = {}
        pcall(function()
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj.Name == "HookESPHighlight" or obj.Name == "HookESPBillboard" then
                    pcall(function() obj:Destroy() end)
                end
            end
        end)
    end
    vdESPState.cleanHookESP = cleanHookESP

    local function collectAllHooksForESP()
        local myChar = player.Character
        local results = {}
        local seenModels = {}

        local function registerHook(hookPart)
            if not hookPart or not hookPart:IsA("BasePart") or not hookPart:IsDescendantOf(workspace) then return end
            if hookPart:FindFirstAncestor("Lobby") then return end
            if myChar and hookPart:IsDescendantOf(myChar) then return end
            if hookPart:FindFirstAncestorOfClass("Tool") or hookPart:FindFirstAncestorOfClass("Backpack") then return end
            -- Skip character-owned accessories/weapons
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr.Character and hookPart:IsDescendantOf(plr.Character) then
                    return
                end
            end

            local hookModel = hookPart:FindFirstAncestorOfClass("Model")
            if hookModel == workspace or (hookModel and hookModel.Name:lower() == "hooks") or (hookModel and hookModel.Name:lower() == "map") then
                hookModel = nil
            end
            local dedupKey = hookModel or hookPart
            if seenModels[dedupKey] then return end
            seenModels[dedupKey] = true

            table.insert(results, {
                part = hookPart,
                model = hookModel or hookPart
            })
        end

        local mapFolder = workspace:FindFirstChild("Map") or workspace:FindFirstChild("map")
        local hooksFolder = mapFolder and (mapFolder:FindFirstChild("Hooks") or mapFolder:FindFirstChild("hooks"))
            or workspace:FindFirstChild("Hooks") or workspace:FindFirstChild("hooks")
        if hooksFolder then
            for _, hookModel in ipairs(hooksFolder:GetChildren()) do
                local hp = hookModel:FindFirstChild("HookPoint") or hookModel:FindFirstChild("HitBox") or (hookModel:IsA("Model") and hookModel.PrimaryPart) or hookModel:FindFirstChildWhichIsA("BasePart")
                if hp then registerHook(hp) end
            end
        end

        if CollectionService then
            pcall(function()
                for _, p in ipairs(CollectionService:GetTagged("HookPoint")) do
                    registerHook(p)
                end
            end)
        end

        if #results == 0 then
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and (obj.Name == "HookPoint" or (obj.Name:lower():find("hook") and obj.Name:lower():find("point"))) then
                    registerHook(obj)
                elseif obj:IsA("Model") and obj.Name:lower():find("hook") and not obj:FindFirstChildOfClass("Humanoid") then
                    local p = obj:FindFirstChild("HookPoint") or obj:FindFirstChild("HitBox") or obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                    if p then registerHook(p) end
                end
            end
        end

        return results
    end

    local function isHookPointOccupiedOrBroken(hookPart, hookModel, myChar)
        local broken = (CollectionService and CollectionService:HasTag(hookPart, "Broken"))
            or hookPart:GetAttribute("Broken") == true or hookPart:GetAttribute("Sabotaged") == true
            or (hookModel and hookModel ~= hookPart and (hookModel:GetAttribute("Broken") == true or hookModel:GetAttribute("Sabotaged") == true or (CollectionService and CollectionService:HasTag(hookModel, "Broken"))))
        if broken then
            return "BROKEN", Color3.fromRGB(160, 160, 160)
        end

        local occupied = (CollectionService and (CollectionService:HasTag(hookPart, "doing action") or CollectionService:HasTag(hookPart, "Occupied")))
            or hookPart:GetAttribute("Occupied") == true or hookPart:GetAttribute("IsHooked") == true
            or (hookModel and hookModel ~= hookPart and (hookModel:GetAttribute("Occupied") == true or hookModel:GetAttribute("IsHooked") == true or (CollectionService and CollectionService:HasTag(hookModel, "Occupied"))))

        if not occupied then
            if trackedSurvivors then
                for sChar, _ in pairs(trackedSurvivors) do
                    if sChar and sChar.Parent and sChar ~= myChar and isCharacterHooked(sChar) then
                        local sHrp = sChar:FindFirstChild("HumanoidRootPart")
                        if sHrp and (sHrp.Position - hookPart.Position).Magnitude <= 5.5 then
                            occupied = true
                            break
                        end
                    end
                end
            end
            if not occupied then
                for _, plr in ipairs(Players:GetPlayers()) do
                    local sChar = plr.Character
                    if sChar and sChar ~= myChar and isCharacterHooked(sChar) then
                        local sHrp = sChar:FindFirstChild("HumanoidRootPart")
                        if sHrp and (sHrp.Position - hookPart.Position).Magnitude <= 5.5 then
                            occupied = true
                            break
                        end
                    end
                end
            end
        end

        if occupied then
            return "OCCUPIED", Color3.fromRGB(255, 70, 180)
        end
        return "READY", Color3.fromRGB(255, 165, 30)
    end

    vdESPState.hookToggle = V_ESPSection:Toggle({
        Title = "Hook Place ESP",
        Description = "Highlights all Hook places on the map with live status & distance",
        Default = false,
        Callback = function(v)
            vdESPState.hookESPEnabled = v
            if not v then
                cleanHookESP()
                return
            end

            task.spawn(function()
                while vdESPState.hookESPEnabled and scriptRunning do
                    pcall(function()
                        cleanHookESP()
                        local myChar = player.Character
                        local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                        if not myHrp then return end

                        for _, entry in ipairs(collectAllHooksForESP()) do
                            if not vdESPState.hookESPEnabled or not scriptRunning then break end
                            local hp = entry.part
                            local hm = entry.model
                            if hp and hp.Parent and hm and hm.Parent then
                                local dist = (myHrp.Position - hp.Position).Magnitude
                                local status, hlColor = isHookPointOccupiedOrBroken(hp, hm, myChar)

                                local hl = Instance.new("Highlight")
                                hl.Name = "HookESPHighlight"
                                hl.FillColor = hlColor
                                hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                                hl.FillTransparency = 0.45
                                hl.OutlineTransparency = 0.15
                                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                                hl.Adornee = hm
                                hl.Parent = hm
                                table.insert(hookESPObjects, hl)

                                local bb = Instance.new("BillboardGui")
                                bb.Name = "HookESPBillboard"
                                bb.Adornee = hp
                                bb.Size = UDim2.fromOffset(155, 42)
                                bb.StudsOffset = Vector3.new(0, 3.0, 0)
                                bb.AlwaysOnTop = true

                                local lbl = Instance.new("TextLabel")
                                lbl.Size = UDim2.fromScale(1, 1)
                                lbl.BackgroundTransparency = 1
                                lbl.TextColor3 = hlColor
                                lbl.TextStrokeTransparency = 0.2
                                lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                                lbl.Font = Enum.Font.GothamBold
                                lbl.TextScaled = true
                                lbl.Text = string.format("🪝 HOOK [%s]\n%.0f studs", status, dist)
                                lbl.Parent = bb

                                bb.Parent = hp
                                table.insert(hookESPObjects, bb)
                            end
                        end
                    end)
                    task.wait(1.5)
                end
                cleanHookESP()
            end)
        end
    })

    -- Immediately sync role-based ESP on load if already in an active match
    task.defer(function()
        if vdESPState.autoRoleESPEnabled then
            local initRole = vdESPState.detectRole()
            if initRole ~= "Lobby" and vdESPState.applyRoleESPs(initRole) then
                vdESPState.lastAppliedRole = initRole
            end
        end
    end)
end

-- ============================================================
-- WALL & OBSTACLE REMOVER (KEEPS GENERATORS & FLOORS 100% INTACT)
-- ============================================================
do
    local removeWallsEnabled = false
    local removedWallParts = {}
    local wallStreamConn = nil

    local function isProtectedObject(part)
        if not part:IsA("BasePart") then return true end
        if part:IsA("Terrain") then return true end

        -- 1. Check Character / Player / NPC protection
        local model = part:FindFirstAncestorOfClass("Model")
        if model then
            if model:FindFirstChildOfClass("Humanoid") then return true end
            if model.Name == "Character" or model.Name == "Player" then return true end
        end

        local name = string.lower(part.Name)
        local pName = part.Parent and string.lower(part.Parent.Name) or ""

        -- 2. Generators (100% Protected - Never Remove)
        if string.find(name, "gen") or string.find(name, "repair") or string.find(name, "motor") or string.find(name, "engine") then
            return true
        end
        if string.find(pName, "gen") or string.find(pName, "repair") or string.find(pName, "motor") or string.find(pName, "engine") then
            return true
        end
        if part:FindFirstChild("RepairPoint") or part:FindFirstChild("RepairPrompt") or (part.Parent and part.Parent:FindFirstChild("RepairPoint")) then
            return true
        end

        -- 3. Floor / Ground / Walkable surfaces (100% Protected to prevent void falling)
        local floorKeywords = {
            "floor", "ground", "base", "baseplate", "road", "path", "grass",
            "terrain", "sidewalk", "pavement", "soil", "dirt", "plate",
            "bottom", "foundation", "surface", "walkable", "stair", "ramp"
        }
        for _, kw in ipairs(floorKeywords) do
            if string.find(name, kw) or string.find(pName, kw) then
                return true
            end
        end

        -- Horizontal slab detection: low vertical thickness (Y <= 3.5) with broad horizontal area (X >= 8 and Z >= 8)
        local sz = part.Size
        if sz.Y <= 3.5 and sz.X >= 8 and sz.Z >= 8 then
            return true
        end

        -- 4. Interactive game objectives & escape routes
        if string.find(name, "hook") or string.find(pName, "hook")
            or string.find(name, "lever") or string.find(pName, "lever")
            or string.find(name, "exit") or string.find(pName, "exit")
            or string.find(name, "gate") or string.find(pName, "gate")
            or string.find(name, "pallet") or string.find(pName, "pallet")
            or string.find(name, "window") or string.find(pName, "window")
            or string.find(name, "vault") or string.find(pName, "vault")
            or string.find(name, "spawn") or string.find(pName, "spawn") then
            return true
        end

        return false
    end

    local function applyWallRemoval(part)
        if not part:IsA("BasePart") then return end
        if isProtectedObject(part) then return end
        if not part.CanCollide and part.Transparency >= 0.95 then return end

        if not removedWallParts[part] then
            local savedDecals = {}
            for _, child in ipairs(part:GetChildren()) do
                if child:IsA("Decal") or child:IsA("Texture") then
                    savedDecals[child] = child.Transparency
                end
            end

            removedWallParts[part] = {
                CanCollide = part.CanCollide,
                Transparency = part.Transparency,
                CastShadow = part.CastShadow,
                Decals = savedDecals
            }
        end

        part.CanCollide = false
        part.Transparency = 1
        part.CastShadow = false
        for _, child in ipairs(part:GetChildren()) do
            if child:IsA("Decal") or child:IsA("Texture") then
                child.Transparency = 1
            end
        end
    end

    local function restoreAllWalls()
        if wallStreamConn then
            pcall(function() wallStreamConn:Disconnect() end)
            wallStreamConn = nil
        end

        for part, saved in pairs(removedWallParts) do
            if part and part.Parent then
                pcall(function()
                    part.CanCollide = saved.CanCollide
                    part.Transparency = saved.Transparency
                    part.CastShadow = saved.CastShadow
                    if saved.Decals then
                        for decal, trans in pairs(saved.Decals) do
                            if decal and decal.Parent then
                                decal.Transparency = trans
                            end
                        end
                    end
                end)
            end
        end
        removedWallParts = {}
    end

    local function executeWallRemoval()
        local descendants = workspace:GetDescendants()
        local count = 0
        for i = 1, #descendants do
            if not removeWallsEnabled then break end
            local obj = descendants[i]
            if obj and obj:IsA("BasePart") then
                applyWallRemoval(obj)
                count = count + 1
                if count % 300 == 0 then
                    task.wait()
                end
            end
        end

        if not wallStreamConn and removeWallsEnabled then
            wallStreamConn = workspace.DescendantAdded:Connect(function(descendant)
                if not removeWallsEnabled then return end
                if descendant and descendant:IsA("BasePart") then
                    task.defer(function()
                        if removeWallsEnabled and descendant and descendant.Parent then
                            applyWallRemoval(descendant)
                        end
                    end)
                end
            end)
        end
    end

    V_ESPSection:Toggle({
        Title = "Remove All Walls & Obstacles",
        Description = "Removes all walls & obstacles client-side (generators & floor remain 100% intact)",
        Default = false,
        Callback = function(v)
            removeWallsEnabled = v
            if not v then
                restoreAllWalls()
                return
            end

            task.spawn(executeWallRemoval)
        end
    })
end

-- ============================================================
-- 3. AUTOMATIC PERFECT SKILL CHECK & NO SKILL CHECK ENGINE
-- ============================================================
local perfectSkillcheckEnabled = true
autoSkillCheckEnabled = true
local noSkillCheckEnabled = false
local hiddenElements = {}
local skillcheckConn = nil
local skillcheckManualConn = nil
local skillcheckHooked = false
local skillcheckHiderHooked = false
local skillcheckRemoteHooked = false
local lastSkillCheckSolvedTime = 0

-- Visual stealth suppressor for "No Skill Check": hides UI cleanly via transparency without moving off-screen
local function applyStealthHider(check, gui)
    if not check then return end
    pcall(function()
        if check:IsA("GuiObject") then
            if not hiddenElements[check] then
                hiddenElements[check] = {
                    bg = check.BackgroundTransparency,
                    img = check:IsA("ImageLabel") and check.ImageTransparency or nil
                }
            end
            check.BackgroundTransparency = 1
            if check:IsA("ImageLabel") then
                check.ImageTransparency = 1
            end
        end

        for _, desc in ipairs(check:GetDescendants()) do
            if not hiddenElements[desc] then
                hiddenElements[desc] = {
                    bg = desc:IsA("GuiObject") and desc.BackgroundTransparency or nil,
                    img = desc:IsA("ImageLabel") and desc.ImageTransparency or nil,
                    txt = desc:IsA("TextLabel") and desc.TextTransparency or nil,
                    vol = desc:IsA("Sound") and desc.Volume or nil
                }
            end
            if desc:IsA("ImageLabel") or desc:IsA("ImageButton") then
                desc.ImageTransparency = 1
                desc.BackgroundTransparency = 1
            elseif desc:IsA("TextLabel") or desc:IsA("TextButton") then
                desc.TextTransparency = 1
                desc.BackgroundTransparency = 1
            elseif desc:IsA("Frame") then
                desc.BackgroundTransparency = 1
            elseif desc:IsA("UIGradient") then
                desc.Transparency = NumberSequence.new(1)
            elseif desc:IsA("Sound") then
                desc.Volume = 0
                if desc.Playing then desc:Stop() end
            end
        end

        if gui then
            for _, s in ipairs(gui:GetDescendants()) do
                if s:IsA("Sound") and s.Playing then
                    s.Volume = 0
                    s:Stop()
                end
            end
        end
    end)
end

local function restoreCheckVisuals()
    pcall(function()
        for elem, orig in pairs(hiddenElements) do
            if elem and elem.Parent then
                pcall(function()
                    if orig.bg ~= nil and elem:IsA("GuiObject") then
                        elem.BackgroundTransparency = orig.bg
                    end
                    if orig.img ~= nil and (elem:IsA("ImageLabel") or elem:IsA("ImageButton")) then
                        elem.ImageTransparency = orig.img
                    end
                    if orig.txt ~= nil and (elem:IsA("TextLabel") or elem:IsA("TextButton")) then
                        elem.TextTransparency = orig.txt
                    end
                    if orig.vol ~= nil and elem:IsA("Sound") then
                        elem.Volume = orig.vol
                    end
                    if elem:IsA("UIGradient") then
                        elem.Transparency = NumberSequence.new(0)
                    end
                end)
            end
        end
        hiddenElements = {}
    end)
end

-- Helper to check if a GuiObject is truly active, rendered and visible on screen
local function isGuiElementTrulyVisible(elem, rootGui)
    if not elem or not elem:IsA("GuiObject") or not elem.Visible then return false end
    if elem.AbsoluteSize.X < 5 or elem.AbsoluteSize.Y < 5 then return false end
    local cur = elem.Parent
    while cur and cur ~= rootGui and cur:IsA("GuiObject") do
        if not cur.Visible then return false end
        if cur:IsA("CanvasGroup") and cur.GroupTransparency >= 0.95 then return false end
        cur = cur.Parent
    end
    return true
end

-- Helper to find active SkillCheck Gui in PlayerGui (Universal PC, Console, & Delta/Fluxus Mobile)
local function getActiveSkillCheckGui()
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return nil, nil end

    local candidateGuiNames = {
        "SkillCheckPromptGui",
        "SkillCheckPromptGui-con",
        "SkillCheckGui",
        "SkillCheck",
        "QTEPromptGui",
        "QTEGui",
        "QTE"
    }

    for _, name in ipairs(candidateGuiNames) do
        local gui = pg:FindFirstChild(name)
        if gui and (gui:IsA("ScreenGui") or gui:IsA("BillboardGui")) then
            if not gui:IsA("ScreenGui") or gui.Enabled then
                local check = gui:FindFirstChild("Check", true) or gui:FindFirstChild("Wheel", true) or gui:FindFirstChild("SkillCheck", true)
                if check and isGuiElementTrulyVisible(check, gui) then
                    return gui, check
                end
            end
        end
    end

    -- Dynamic fallback: search all enabled ScreenGuis with "skill" or "qte" in their name (excluding player controls / HUD)
    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            local gName = gui.Name:lower()
            if (gName:find("skill") or gName:find("qte")) and not gName:find("mob") and not gName:find("hud") and not gName:find("control") and not gName:find("progress") then
                local check = gui:FindFirstChild("Check", true) or gui:FindFirstChild("Wheel", true) or gui:FindFirstChild("SkillCheck", true)
                if check and isGuiElementTrulyVisible(check, gui) then
                    return gui, check
                end
            end
        end
    end

    return nil, nil
end

-- Helper to inspect Check frame and locate dynamic needle & target zone (Great / Good)
local function evaluateSkillCheckFrame(check, lastRotTable)
    if not check then return nil, nil, nil, {} end

    local needle = nil
    local greatZone = nil
    local goodZone = nil
    local rotatingCandidates = {}
    local staticRotatedElements = {}
    local allCandidates = {}

    for _, child in ipairs(check:GetDescendants()) do
        if child:IsA("GuiObject") or child:IsA("UIGradient") then
            local low = child.Name:lower()
            local curRot = (child:IsA("UIGradient") and child.Rotation or child.Rotation) % 360
            table.insert(allCandidates, child)

            if low:find("needle") or low:find("pointer") or low:find("indicator") or low:find("arrow") or low:find("cursor") or low:find("rotator") or low:find("spinner") or low:find("hand") or low:find("bar") or low:find("line") then
                needle = child
            elseif low:find("great") or low:find("perfect") or low:find("bonus") or low:find("sweet") or low:find("white") or low:find("zone2") then
                greatZone = child
            elseif low:find("good") or low:find("success") or low:find("target") or low:find("zone") or low:find("hit") or low:find("area") or low:find("slice") or low:find("arc") then
                goodZone = child
            end

            -- Detect white-colored sector (Great Zone in Violence District / DbD)
            if not greatZone and child:IsA("GuiObject") and curRot ~= 0 then
                local col = child:IsA("ImageLabel") and child.ImageColor3 or child.BackgroundColor3
                if col.R > 0.88 and col.G > 0.88 and col.B > 0.88 then
                    greatZone = child
                end
            end

            if lastRotTable then
                local prevRot = lastRotTable[child]
                if prevRot ~= nil then
                    local delta = math.abs((curRot - prevRot + 180) % 360 - 180)
                    if delta > 0.05 then
                        table.insert(rotatingCandidates, { elem = child, delta = delta })
                    end
                end
            end

            if curRot ~= 0 and child.Name ~= "Space" and child.Name ~= "key" and not low:find("bg") and not low:find("back") and not low:find("border") then
                table.insert(staticRotatedElements, { elem = child, rot = curRot })
            end
        end
    end

    if not needle and #rotatingCandidates > 0 then
        table.sort(rotatingCandidates, function(a, b) return a.delta > b.delta end)
        needle = rotatingCandidates[1].elem
    end

    if not needle then
        for _, child in ipairs(allCandidates) do
            if child:IsA("GuiObject") and child.Name ~= "Space" and child.Name ~= "key" then
                local sz = child.AbsoluteSize
                if (sz.X > 0 and sz.Y > 0) and (sz.X / sz.Y > 4 or sz.Y / sz.X > 4) then
                    needle = child
                    break
                end
            end
        end
    end

    local targetZone = greatZone or goodZone
    if not targetZone and #staticRotatedElements > 0 then
        for _, item in ipairs(staticRotatedElements) do
            if item.elem ~= needle and not item.elem:IsDescendantOf(needle) then
                targetZone = item.elem
                break
            end
        end
    end

    return needle, targetZone, greatZone, allCandidates
end

-- Resolve target rotation angle for guaranteed Great / Perfect hit
local function resolveTargetRotation(targetZone, greatZone, check)
    if greatZone then
        local r = (greatZone:IsA("UIGradient") and greatZone.Rotation or greatZone.Rotation) % 360
        if r ~= 0 then return r end
    end
    if targetZone then
        local r = (targetZone:IsA("UIGradient") and targetZone.Rotation or targetZone.Rotation) % 360
        if r ~= 0 then return r end
    end
    if check then
        local targetVal = check:GetAttribute("TargetAngle") or check:GetAttribute("SuccessAngle") or check:GetAttribute("GreatAngle")
        if typeof(targetVal) == "number" then return targetVal % 360 end
        for _, ch in ipairs(check:GetChildren()) do
            if ch:IsA("NumberValue") or ch:IsA("IntValue") then
                local low = ch.Name:lower()
                if low:find("target") or low:find("angle") or low:find("great") or low:find("rot") then
                    return ch.Value % 360
                end
            end
        end
    end
    return 130
end

-- Snap needle directly onto Great Zone (Turns skillcheck into an All-Time Great Zone!)
local function snapNeedleToGreatZone(needle, targetRot)
    if not needle then return end
    pcall(function()
        if needle:IsA("UIGradient") then
            needle.Rotation = targetRot
        else
            needle.Rotation = targetRot
            local grad = needle:FindFirstChildOfClass("UIGradient")
            if grad then
                grad.Rotation = targetRot
            end
            for _, ch in ipairs(needle:GetChildren()) do
                if ch:IsA("GuiObject") or ch:IsA("UIGradient") then
                    pcall(function() ch.Rotation = targetRot end)
                end
            end
        end
    end)
end

-- Helper to resolve the true Generator model instance expected by the server
local function resolveGeneratorInstance(point, fallbackModel)
    -- 1. If point is provided, inspect point's immediate hierarchy
    if point and typeof(point) == "Instance" then
        if point.Parent and point.Parent.Name == "Generator" then
            return point.Parent
        end
        local genAncestor = point:FindFirstAncestor("Generator")
        if genAncestor then
            return genAncestor
        end
        if point.Parent then
            local childGen = point.Parent:FindFirstChild("Generator")
            if childGen and (childGen:IsA("Model") or childGen:IsA("Folder") or childGen:IsA("BasePart")) then
                return childGen
            end
        end
    end

    -- 2. Check fallbackModel if provided
    if fallbackModel and typeof(fallbackModel) == "Instance" then
        if fallbackModel.Name == "Generator" then
            return fallbackModel
        end
        local childGen = fallbackModel:FindFirstChild("Generator")
        if childGen and (childGen:IsA("Model") or childGen:IsA("Folder") or childGen:IsA("BasePart")) then
            return childGen
        end
    end

    -- 3. Search getnilinstances() if available for an unparented/nil Generator instance
    if typeof(getnilinstances) == "function" then
        local success, nilList = pcall(getnilinstances)
        if success and typeof(nilList) == "table" then
            if point and typeof(point) == "Instance" then
                for _, inst in ipairs(nilList) do
                    if typeof(inst) == "Instance" and inst.Name == "Generator" then
                        if point.Parent == inst or point:IsDescendantOf(inst) then
                            return inst
                        end
                    end
                end
                local pPos = nil
                pcall(function() pPos = point.Position end)
                if pPos then
                    local bestInst = nil
                    local bestDist = 25
                    for _, inst in ipairs(nilList) do
                        if typeof(inst) == "Instance" and inst.Name == "Generator" then
                            local body = inst:FindFirstChild("GeneratorBody") or inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")
                            if body and body.Position then
                                local d = (body.Position - pPos).Magnitude
                                if d < bestDist then
                                    bestDist = d
                                    bestInst = inst
                                end
                            end
                        end
                    end
                    if bestInst then
                        return bestInst
                    end
                end
            end
            for _, inst in ipairs(nilList) do
                if typeof(inst) == "Instance" and inst.Name == "Generator" then
                    return inst
                end
            end
        end
    end

    -- 4. Fallback: direct parent if it's a Model
    if point and typeof(point) == "Instance" and point.Parent and point.Parent:IsA("Model") then
        return point.Parent
    end

    return fallbackModel or (point and point.Parent)
end

-- Helper to locate active Generator and GeneratorPoint context
local function findActiveRepairContext()
    local myChar = player.Character
    if not myChar then return nil, nil, nil end
    local hrp = myChar:FindFirstChild("HumanoidRootPart")

    local genModel = lastCapturedGenModel
    local targetPoint = lastCapturedGenPoint

    if not targetPoint or not targetPoint.Parent then
        targetPoint = currentRepairPoint
    end

    if not targetPoint or not targetPoint.Parent then
        if hrp then
            local pPos = hrp.Position
            local closestDist = 25

            -- 1. Check workspace.Map.Generators and workspace.Map["new Generators"]
            pcall(function()
                local map = workspace:FindFirstChild("Map")
                local gens = map and (map:FindFirstChild("Generators") or map:FindFirstChild("new Generators"))
                if gens then
                    for _, gen in ipairs(gens:GetChildren()) do
                        for _, child in ipairs(gen:GetChildren()) do
                            if child:IsA("BasePart") and child.Name:find("GeneratorPoint") then
                                local d = (child.Position - pPos).Magnitude
                                if d < closestDist then
                                    closestDist = d
                                    targetPoint = child
                                    genModel = gen
                                end
                            end
                        end
                    end
                end
            end)

            -- 2. CollectionService tagged points
            if not targetPoint and CollectionService then
                for _, pt in ipairs(CollectionService:GetTagged("GeneratorPoint")) do
                    if pt:IsA("BasePart") then
                        local d = (pt.Position - pPos).Magnitude
                        if d < closestDist then
                            closestDist = d
                            targetPoint = pt
                        end
                    end
                end
            end

            -- 3. General workspace fallback
            if not targetPoint then
                for _, desc in ipairs(workspace:GetDescendants()) do
                    if desc:IsA("BasePart") and desc.Name:find("GeneratorPoint") then
                        local d = (desc.Position - pPos).Magnitude
                        if d < closestDist then
                            closestDist = d
                            targetPoint = desc
                        end
                    end
                end
            end
        end
    end

    if targetPoint then
        genModel = resolveGeneratorInstance(targetPoint, genModel)
    end

    local ms = myChar:FindFirstChild("CheckInterractable") or myChar:FindFirstChild("motherscript")
    local requestId = lastCapturedRepairRequestId
        or (ms and (ms:GetAttribute("RepairRequestId") or ms:GetAttribute("requestId") or ms:GetAttribute("SessionId")))
        or myChar:GetAttribute("RepairRequestId")
        or player:GetAttribute("RepairRequestId")
        or HttpService:GenerateGUID(false)

    return genModel, targetPoint, requestId
end

-- Primary Network Remote: Directly fires SkillCheckResultEvent to Server (100% Guaranteed Perfect Server-Side)
local function fireSkillCheckSuccessRemote()
    pcall(function()
        local remotes = getVDRemotes()
        local myChar = player.Character
        if not myChar then return end

        if remotes.Generator and remotes.Generator:FindFirstChild("SkillCheckResultEvent") then
            local genModel, genPoint, requestId = findActiveRepairContext()
            local actualGenModel = resolveGeneratorInstance(genPoint, genModel)
            if actualGenModel and genPoint then
                pcall(function()
                    remotes.Generator.SkillCheckResultEvent:FireServer(
                        "success",
                        1,
                        actualGenModel,
                        genPoint,
                        requestId,
                        { player.Name }
                    )
                end)
            end
        end
        if remotes.Healing and remotes.Healing:FindFirstChild("SkillCheckResultEvent") then
            if myChar:GetAttribute("isHealing") then
                local healRequestId = lastCapturedHealRequestId
                    or myChar:GetAttribute("HealRequestId")
                    or HttpService:GenerateGUID(false)
                pcall(function()
                    remotes.Healing.SkillCheckResultEvent:FireServer(
                        "success",
                        1,
                        myChar,
                        healRequestId,
                        myChar
                    )
                end)
            end
        end
    end)
end

-- Metamethod & Function Interception Hook: Intercepts game remotes to capture live context and mutate any "fail" packet into "success"
local function hookSkillCheckRemotes()
    if skillcheckRemoteHooked then return end
    skillcheckRemoteHooked = true

    local newc = (typeof(newcclosure) == "function") and newcclosure or function(f) return f end
    local upk = unpack or table.unpack

    -- 1. Metamethod Hook (__namecall)
    pcall(function()
        if typeof(hookmetamethod) == "function" then
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", newc(function(self, ...)
                local method = (typeof(getnamecallmethod) == "function" and getnamecallmethod()) or (typeof(get_namecall_method) == "function" and get_namecall_method())
                if method and (method == "FireServer" or method == "fireServer") and typeof(self) == "Instance" then
                    local sName = self.Name
                    if sName == "SkillCheckResultEvent" then
                        local args = { ... }
                        local parentName = self.Parent and self.Parent.Name or ""
                        if parentName == "Generator" or parentName == "Remotes" or parentName == "" then
                            if args[4] and typeof(args[4]) == "Instance" then
                                lastCapturedGenPoint = args[4]
                            end
                            if args[3] and typeof(args[3]) == "Instance" then
                                lastCapturedGenModel = resolveGeneratorInstance(args[4], args[3])
                            end
                            if typeof(args[5]) == "string" and args[5] ~= "" then
                                lastCapturedRepairRequestId = args[5]
                            end

                            if perfectSkillcheckEnabled or noSkillCheckEnabled then
                                args[1] = "success"
                                args[2] = 1
                                if not args[4] or typeof(args[4]) ~= "Instance" then
                                    args[4] = lastCapturedGenPoint
                                end
                                local resolvedGen = resolveGeneratorInstance(args[4], args[3] or lastCapturedGenModel)
                                args[3] = resolvedGen or lastCapturedGenModel or args[3]
                                if not args[5] or typeof(args[5]) ~= "string" or args[5] == "" then
                                    args[5] = lastCapturedRepairRequestId or HttpService:GenerateGUID(false)
                                end
                                args[6] = { player.Name }
                                unlockCameraAndMovement()
                                task.delay(0.05, unlockCameraAndMovement)
                                return oldNamecall(self, upk(args))
                            end
                        elseif parentName == "Healing" then
                            if typeof(args[4]) == "string" and args[4] ~= "" then
                                lastCapturedHealRequestId = args[4]
                            end
                            if perfectSkillcheckEnabled or noSkillCheckEnabled then
                                args[1] = "success"
                                args[2] = 1
                                if not args[3] or typeof(args[3]) ~= "Instance" then
                                    args[3] = player.Character
                                end
                                if not args[5] or typeof(args[5]) ~= "Instance" then
                                    args[5] = player.Character
                                end
                                unlockCameraAndMovement()
                                task.delay(0.05, unlockCameraAndMovement)
                                return oldNamecall(self, upk(args))
                            end
                        end
                    elseif sName == "RepairEvent" then
                        local args = { ... }
                        if args[1] and typeof(args[1]) == "Instance" then
                            lastCapturedGenPoint = args[1]
                            lastCapturedGenModel = resolveGeneratorInstance(args[1], args[1].Parent)
                        end
                        if typeof(args[4]) == "string" and args[4] ~= "" then
                            lastCapturedRepairRequestId = args[4]
                        end
                    elseif sName == "HealEvent" then
                        local args = { ... }
                        if typeof(args[3]) == "string" and args[3] ~= "" then
                            lastCapturedHealRequestId = args[3]
                        end
                    end
                end
                return oldNamecall(self, ...)
            end))
        end
    end)

    -- 2. Direct Function Hook (targetRemote.FireServer)
    pcall(function()
        if typeof(hookfunction) == "function" then
            local remotes = getVDRemotes()
            if remotes.Generator and remotes.Generator:FindFirstChild("SkillCheckResultEvent") then
                local remoteObj = remotes.Generator.SkillCheckResultEvent
                local oldFireServer
                oldFireServer = hookfunction(remoteObj.FireServer, newc(function(self, ...)
                    local args = { ... }
                    if args[4] and typeof(args[4]) == "Instance" then
                        lastCapturedGenPoint = args[4]
                    end
                    if args[3] and typeof(args[3]) == "Instance" then
                        lastCapturedGenModel = resolveGeneratorInstance(args[4], args[3])
                    end
                    if typeof(args[5]) == "string" and args[5] ~= "" then
                        lastCapturedRepairRequestId = args[5]
                    end

                    if perfectSkillcheckEnabled or noSkillCheckEnabled then
                        args[1] = "success"
                        args[2] = 1
                        if not args[4] or typeof(args[4]) ~= "Instance" then
                            args[4] = lastCapturedGenPoint
                        end
                        local resolvedGen = resolveGeneratorInstance(args[4], args[3] or lastCapturedGenModel)
                        args[3] = resolvedGen or lastCapturedGenModel or args[3]
                        if not args[5] or typeof(args[5]) ~= "string" or args[5] == "" then
                            args[5] = lastCapturedRepairRequestId or HttpService:GenerateGUID(false)
                        end
                        args[6] = { player.Name }
                        unlockCameraAndMovement()
                        task.delay(0.05, unlockCameraAndMovement)
                        return oldFireServer(self, upk(args))
                    end
                    return oldFireServer(self, ...)
                end))
            end
            if remotes.Generator and remotes.Generator:FindFirstChild("RepairEvent") then
                local repRemote = remotes.Generator.RepairEvent
                local oldRepFire
                oldRepFire = hookfunction(repRemote.FireServer, newc(function(self, ...)
                    local args = { ... }
                    if args[1] and typeof(args[1]) == "Instance" then
                        lastCapturedGenPoint = args[1]
                        lastCapturedGenModel = resolveGeneratorInstance(args[1], args[1].Parent)
                    end
                    if typeof(args[4]) == "string" and args[4] ~= "" then
                        lastCapturedRepairRequestId = args[4]
                    end
                    return oldRepFire(self, ...)
                end))
            end
            if remotes.Healing and remotes.Healing:FindFirstChild("SkillCheckResultEvent") then
                local healRemote = remotes.Healing.SkillCheckResultEvent
                local oldHealFire
                oldHealFire = hookfunction(healRemote.FireServer, newc(function(self, ...)
                    local args = { ... }
                    if typeof(args[4]) == "string" and args[4] ~= "" then
                        lastCapturedHealRequestId = args[4]
                    end
                    if perfectSkillcheckEnabled or noSkillCheckEnabled then
                        args[1] = "success"
                        args[2] = 1
                        if not args[3] or typeof(args[3]) ~= "Instance" then
                            args[3] = player.Character
                        end
                        if not args[5] or typeof(args[5]) ~= "Instance" then
                            args[5] = player.Character
                        end
                        unlockCameraAndMovement()
                        task.delay(0.05, unlockCameraAndMovement)
                        return oldHealFire(self, upk(args))
                    end
                    return oldHealFire(self, ...)
                end))
            end
        end
    end)
end

-- Standalone skillcheck trigger execution (Pure Network Remote & Needle Sync, Zero Tap Interference)
local function triggerPerfectHit(check, gui, needle, targetRot)
    task.spawn(function()
        pcall(function()
            -- 0. Direct server remote confirmation (Guaranteed Server-Side Great: "success", 1, genModel, genPoint, requestId, { player.Name })
            fireSkillCheckSuccessRemote()

            -- 1. Snap needle directly onto Great Zone for perfect visual alignment
            if needle then
                snapNeedleToGreatZone(needle, targetRot)
            end

            -- Maintain needle lock for next 3 frames to defeat script race condition
            for i = 1, 3 do
                task.wait(0.016)
                if needle then
                    snapNeedleToGreatZone(needle, targetRot)
                end
            end

            -- Clean camera and movement unlock
            unlockCameraAndMovement()
            task.delay(0.08, unlockCameraAndMovement)
        end)
    end)
end

-- Anti-Fail Safety Hook: blocks failure animation on client side & resets camera
local function hookSkillCheckFailPrevention()
    if skillcheckHooked then return end
    skillcheckHooked = true

    pcall(function()
        local remotes = getVDRemotes()
        if remotes.Generator and remotes.Generator:FindFirstChild("SkillCheckFailEvent") then
            pcall(function()
                remotes.Generator.SkillCheckFailEvent.OnClientEvent:Connect(function()
                    task.spawn(function()
                        unlockCameraAndMovement()
                        task.wait(0.1)
                        unlockCameraAndMovement()
                        task.wait(0.3)
                        unlockCameraAndMovement()
                        task.wait(0.7)
                        unlockCameraAndMovement()
                    end)
                end)
            end)
        end
        if remotes.Healing and remotes.Healing:FindFirstChild("SkillCheckFailEvent") then
            pcall(function()
                remotes.Healing.SkillCheckFailEvent.OnClientEvent:Connect(function()
                    task.spawn(function()
                        unlockCameraAndMovement()
                        task.wait(0.1)
                        unlockCameraAndMovement()
                        task.wait(0.3)
                        unlockCameraAndMovement()
                        task.wait(0.7)
                        unlockCameraAndMovement()
                    end)
                end)
            end)
        end
    end)
end

-- Instant Popup Suppressor for "No Skill Check"
local function hookSkillCheckHider()
    if skillcheckHiderHooked then return end
    skillcheckHiderHooked = true

    pcall(function()
        local pg = player:FindFirstChild("PlayerGui")
        if not pg then return end

        local function watchGui(gui)
            if not gui or not (gui:IsA("ScreenGui") or gui:IsA("BillboardGui")) then return end
            local gName = gui.Name:lower()
            if gName:find("skill") or gName:find("qte") then
                local check = gui:FindFirstChild("Check", true) or gui:FindFirstChild("Wheel", true) or gui:FindFirstChild("SkillCheck", true)
                if check and check:IsA("GuiObject") then
                    check:GetPropertyChangedSignal("Visible"):Connect(function()
                        if noSkillCheckEnabled and check.Visible then
                            applyStealthHider(check, gui)
                        elseif not noSkillCheckEnabled then
                            restoreCheckVisuals()
                        end
                    end)
                end
                if gui:IsA("ScreenGui") then
                    gui:GetPropertyChangedSignal("Enabled"):Connect(function()
                        if noSkillCheckEnabled and gui.Enabled then
                            local c = gui:FindFirstChild("Check", true) or gui:FindFirstChild("Wheel", true) or gui:FindFirstChild("SkillCheck", true)
                            if c and c:IsA("GuiObject") then
                                applyStealthHider(c, gui)
                            end
                        elseif not noSkillCheckEnabled then
                            restoreCheckVisuals()
                        end
                    end)
                end
            end
        end

        for _, g in ipairs(pg:GetChildren()) do
            watchGui(g)
        end
        pg.ChildAdded:Connect(watchGui)
    end)
end

local function startSkillcheckWatcher()
    if skillcheckConn then
        pcall(function() skillcheckConn:Disconnect() end)
        skillcheckConn = nil
    end
    if skillcheckManualConn then
        pcall(function() skillcheckManualConn:Disconnect() end)
        skillcheckManualConn = nil
    end

    hookSkillCheckRemotes()
    hookSkillCheckFailPrevention()
    hookSkillCheckHider()

    local promptOpenTick = 0
    local promptHandled = false
    local promptHandledTick = 0
    local rotHistory = {}

    -- Manual Tap / Key Hook: If user taps/presses manually at ANY time, snap needle to Great Zone and solve instantly!
    skillcheckManualConn = UserInputService.InputBegan:Connect(function(input, processed)
        if not perfectSkillcheckEnabled and not noSkillCheckEnabled then return end
        local isTriggerInput = (input.UserInputType == Enum.UserInputType.Keyboard and (input.KeyCode == Enum.KeyCode.Space or input.KeyCode == (Enum.KeyCode[player:GetAttribute("kb_skillcheck") or "Space"] or Enum.KeyCode.Space)))
            or (input.UserInputType == Enum.UserInputType.Touch)
            or (input.UserInputType == Enum.UserInputType.MouseButton1)
            or (input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.ButtonL1)

        if isTriggerInput then
            local gui, check = getActiveSkillCheckGui()
            if check and check.Visible then
                local needle, targetZone, greatZone = evaluateSkillCheckFrame(check, rotHistory)
                local targetRot = resolveTargetRotation(targetZone, greatZone, check)
                if needle then
                    snapNeedleToGreatZone(needle, targetRot)
                end
                if not promptHandled and (tick() - lastSkillCheckSolvedTime > 0.15) then
                    promptHandled = true
                    promptHandledTick = os.clock()
                    lastSkillCheckSolvedTime = tick()
                    triggerPerfectHit(check, gui, needle, targetRot)
                end
            end
        end
    end)

    -- RenderStepped 60FPS+ high-precision autonomous watcher & instant Great execution
    skillcheckConn = RunService.RenderStepped:Connect(function()
        if not perfectSkillcheckEnabled and not noSkillCheckEnabled then return end

        local gui, check = getActiveSkillCheckGui()
        if check and check.Visible and check.AbsoluteSize.X > 5 and check.AbsoluteSize.Y > 5 then
            -- If No Skill Check is enabled, cleanly hide visual elements via transparency and solve immediately
            if noSkillCheckEnabled and check:IsA("GuiObject") then
                applyStealthHider(check, gui)
                if not promptHandled and (tick() - lastSkillCheckSolvedTime > 0.10) then
                    promptHandled = true
                    promptHandledTick = os.clock()
                    lastSkillCheckSolvedTime = tick()
                    fireSkillCheckSuccessRemote()
                    triggerPerfectHit(check, gui, nil, 130)
                end
            end

            -- Safety: auto-reset if prompt remained open after 0.80s so subsequent skill checks re-trigger
            if promptHandled and (os.clock() - promptHandledTick > 0.80) then
                promptHandled = false
                promptOpenTick = os.clock()
            end

            if not promptHandled then
                if promptOpenTick == 0 then
                    promptOpenTick = os.clock()
                end

                local needle, targetZone, greatZone, candidates = evaluateSkillCheckFrame(check, rotHistory)

                -- Update rotHistory for dynamic needle motion detection
                if candidates then
                    for _, elem in ipairs(candidates) do
                        local rot = (elem:IsA("UIGradient") and elem.Rotation or elem.Rotation) % 360
                        rotHistory[elem] = rot
                    end
                end

                local targetRot = resolveTargetRotation(targetZone, greatZone, check)
                local elapsed = os.clock() - promptOpenTick

                -- Precision Great Zone timing logic:
                -- 1. If needle rotation is active, hit when needle arrives in Great Zone (distToZone <= 15 or distToZone >= 345, elapsed >= 0.12)
                -- 2. Fallback: standard physical arrival of Great Zone is between 0.28s and 0.40s
                local shouldHit = false

                if needle then
                    local curRot = (needle:IsA("UIGradient") and needle.Rotation or needle.Rotation) % 360
                    local distToZone = (targetRot - curRot + 360) % 360
                    if (distToZone <= 15 or distToZone >= 345) and elapsed >= 0.12 then
                        shouldHit = true
                    elseif elapsed >= 0.28 then
                        shouldHit = true
                    end
                elseif elapsed >= 0.28 then
                    shouldHit = true
                end

                if shouldHit and (tick() - lastSkillCheckSolvedTime > 0.18) then
                    promptHandled = true
                    promptHandledTick = os.clock()
                    lastSkillCheckSolvedTime = tick()
                    triggerPerfectHit(check, gui, needle, targetRot)
                end
            end
        else
            -- Prompt closed / finished: restore original visual transparency
            restoreCheckVisuals()

            if promptHandled or promptOpenTick > 0 then
                unlockCameraAndMovement()
            end
            promptOpenTick = 0
            promptHandled = false
            promptHandledTick = 0
            rotHistory = {}
        end
    end)
end

-- Background Camera & Movement Supervisor
task.spawn(function()
    while true do
        task.wait(0.25)
        pcall(function()
            local myChar = player.Character
            if myChar and myChar:IsDescendantOf(workspace) then
                local isRep = myChar:GetAttribute("isRepairing") == true
                local isHeal = myChar:GetAttribute("isHealing") == true
                local isVault = myChar:GetAttribute("isVaulting") == true
                local isHook = isCharacterHooked(myChar)
                local isKnock = isCharacterKnocked(myChar)

                if not isHook and not isKnock then
                    if myChar:GetAttribute("overridelookscript") == true 
                        or myChar:GetAttribute("CamAnimLock") == true 
                        or myChar:GetAttribute("previewfreezelook") == true
                        or player:GetAttribute("overridelookscript") == true 
                        or player:GetAttribute("CamAnimLock") == true 
                        or player:GetAttribute("previewfreezelook") == true then
                        unlockCameraAndMovement()
                    end

                    -- Prevent camera stuck in Scriptable mode when character is active
                    local cam = workspace.CurrentCamera
                    if cam and cam.CameraType == Enum.CameraType.Scriptable and not isHook and not isKnock then
                        cam.CameraType = Enum.CameraType.Custom
                    end

                    -- Prevent AutoRotate stuck false outside of active repair
                    local hum = myChar:FindFirstChildOfClass("Humanoid")
                    if hum and not hum.AutoRotate and not isRep and not isHook and not isKnock then
                        hum.AutoRotate = true
                    end
                end
            end
        end)
    end
end)

-- Objectives & Skillcheck UI Toggles Configuration
local autoSkillcheckToggle = V_ObjectiveSection:Toggle({
    Title = "Automatic Perfect Skill Check",
    Description = "100% Autonomous Perfect/Great skillchecks: automatically hits Great on every generator/heal skillcheck.",
    Default = perfectSkillcheckEnabled,
    Callback = function(v)
        perfectSkillcheckEnabled = v
        autoSkillCheckEnabled = v
        if not v and not noSkillCheckEnabled then
            if skillcheckConn then
                pcall(function() skillcheckConn:Disconnect() end)
                skillcheckConn = nil
            end
            if skillcheckManualConn then
                pcall(function() skillcheckManualConn:Disconnect() end)
                skillcheckManualConn = nil
            end
            unlockCameraAndMovement()
            return
        end

        startSkillcheckWatcher()
    end
})

local noSkillcheckToggle = V_ObjectiveSection:Toggle({
    Title = "No Skill Check",
    Description = "Prevents skill check wheels from popping up on screen and automatically solves them invisibly.",
    Default = noSkillCheckEnabled,
    Callback = function(v)
        noSkillCheckEnabled = v
        if v then
            if not perfectSkillcheckEnabled then
                perfectSkillcheckEnabled = true
                autoSkillCheckEnabled = true
            end
            startSkillcheckWatcher()
        else
            restoreCheckVisuals()
            if not perfectSkillcheckEnabled then
                if skillcheckConn then
                    pcall(function() skillcheckConn:Disconnect() end)
                    skillcheckConn = nil
                end
                if skillcheckManualConn then
                    pcall(function() skillcheckManualConn:Disconnect() end)
                    skillcheckManualConn = nil
                end
            end
        end
    end
})

-- Auto-activate watchers and remote interception hooks on script initialization
hookSkillCheckRemotes()
if perfectSkillcheckEnabled or noSkillCheckEnabled then
    startSkillcheckWatcher()
end


-- ============================================================
-- 4. AUTO REPAIR GENERATOR (AUTO SEARCH, SAFE FAR TRAVEL & RETRY LOGIC)
-- ============================================================
autoRepairEnabled = false
local currentRepairPoint = nil
local repairSafeDistance = 25
local travelMode = "Safe Teleport"
local safeTeleportStep = 3.5
local isTraveling = false
local completedGenerators = {}

-- Resolves the true Generator Model from any point or child part
local function getGeneratorModel(part)
    if not part then return nil end
    local curr = part.Parent
    while curr and curr ~= workspace do
        if curr:IsA("Model") and (curr.Name:lower():find("gen") or curr:FindFirstChild("GeneratorBody") or curr:GetAttribute("RepairProgress") ~= nil or curr:GetAttribute("Progress") ~= nil) then
            return curr
        end
        curr = curr.Parent
    end
    return part:FindFirstAncestorOfClass("Model") or part.Parent
end

-- Comprehensive generator completion validator for Violence District
local function isGeneratorCompleted(point)
    if not point or not point.Parent then return true end
    local CollectionService = game:GetService("CollectionService")
    local genModel = getGeneratorModel(point) or point.Parent

    -- Check session completed blacklist
    if completedGenerators[point] or (genModel and completedGenerators[genModel]) then
        return true, 100
    end

    -- 1. Check CollectionService Tags (Official Violence District: "Blocked" tag marks finished generator)
    if CollectionService:HasTag(point, "Blocked") or CollectionService:HasTag(point, "Repaired") or CollectionService:HasTag(point, "Completed") then
        return true, 100
    end
    if genModel and (CollectionService:HasTag(genModel, "Blocked") or CollectionService:HasTag(genModel, "Repaired") or CollectionService:HasTag(genModel, "Completed")) then
        return true, 100
    end
    if point.Parent and CollectionService:HasTag(point.Parent, "Blocked") then
        return true, 100
    end

    -- 2. Check Violence District "RepairProgress" attribute (0 to 100)
    local rawProgress = (genModel and genModel:GetAttribute("RepairProgress"))
        or (point.Parent and point.Parent:GetAttribute("RepairProgress"))
        or point:GetAttribute("RepairProgress")
        or (genModel and genModel:GetAttribute("Progress"))
        or (point.Parent and point.Parent:GetAttribute("Progress"))
        or point:GetAttribute("Progress")

    if rawProgress and tonumber(rawProgress) then
        local pVal = tonumber(rawProgress)
        if pVal >= 99.5 then
            return true, 100
        else
            return false, pVal
        end
    end

    -- 3. Check Boolean completion attributes
    local boolAttrs = {"Completed", "completed", "Repaired", "repaired", "Fixed", "fixed", "Blocked", "Done", "done"}
    for _, attr in ipairs(boolAttrs) do
        if (genModel and genModel:GetAttribute(attr) == true)
            or (point.Parent and point.Parent:GetAttribute(attr) == true)
            or (point:GetAttribute(attr) == true) then
            return true, 100
        end
    end

    -- 4. Check NumberValue or BoolValue children
    for _, obj in ipairs({genModel, point.Parent, point}) do
        if obj then
            local rpVal = obj:FindFirstChild("RepairProgress") or obj:FindFirstChild("Progress")
            if rpVal and (rpVal:IsA("NumberValue") or rpVal:IsA("IntValue")) then
                if rpVal.Value >= 99.5 then
                    return true, 100
                else
                    return false, rpVal.Value
                end
            end
            local compVal = obj:FindFirstChild("Completed") or obj:FindFirstChild("Repaired") or obj:FindFirstChild("Fixed")
            if compVal and compVal:IsA("BoolValue") and compVal.Value == true then
                return true, 100
            end
        end
    end

    return false, 0
end

-- Finds the next unfinished generator, actively avoiding generators near the Killer
-- Finds the next unfinished generator, actively avoiding generators near the Killer
local function findNextUnfinishedGenerator(killer)
    local myChar = player.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return nil end

    local CollectionService = game:GetService("CollectionService")
    local candidatePoints = {}
    local processedGenerators = {}

    local function addPoint(pt)
        if pt:IsA("BasePart") and not pt:IsDescendantOf(myChar) then
            local genModel = getGeneratorModel(pt) or pt.Parent
            if not processedGenerators[genModel] then
                local isCompleted = isGeneratorCompleted(pt)
                if not isCompleted then
                    table.insert(candidatePoints, pt)
                    processedGenerators[genModel] = true
                end
            end
        end
    end

    -- 1. Check CollectionService "GeneratorPoint"
    pcall(function()
        for _, point in ipairs(CollectionService:GetTagged("GeneratorPoint")) do
            addPoint(point)
        end
    end)

    -- 2. Fallback check for parts named RepairPoint / GeneratorPoint in Workspace
    if #candidatePoints == 0 then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and (obj.Name == "RepairPoint" or obj.Name == "GeneratorPoint") then
                addPoint(obj)
            end
        end
    end

    if #candidatePoints == 0 then return nil, math.huge end

    local kHrp = killer and killer:FindFirstChild("HumanoidRootPart")
    local isThreatened = kHrp and ((myHrp.Position - kHrp.Position).Magnitude < (repairSafeDistance + 5))

    -- High-Intelligence Killer Avoidance & Safe Generator Selection
    if kHrp then
        local safeCandidates = {}
        -- Absolute minimum safe distance: at least 60 studs away from Killer
        local minSafeDistance = math.max(repairSafeDistance + 25, 60)

        for _, pt in ipairs(candidatePoints) do
            local kDist = (kHrp.Position - pt.Position).Magnitude
            local myDist = (myHrp.Position - pt.Position).Magnitude

            -- Strictly only consider generator safe if Killer is sufficiently far away
            if kDist >= minSafeDistance then
                table.insert(safeCandidates, { point = pt, myDist = myDist, kDist = kDist })
            end
        end

        if #safeCandidates > 0 then
            -- Sort safe candidates: balance safety from Killer (high kDist) with proximity to player (low myDist)
            table.sort(safeCandidates, function(a, b)
                if isThreatened then
                    -- When in immediate danger, pick the one furthest from Killer
                    return a.kDist > b.kDist
                else
                    local scoreA = (a.kDist * 2.0) - a.myDist
                    local scoreB = (b.kDist * 2.0) - b.myDist
                    return scoreA > scoreB
                end
            end)
            return safeCandidates[1].point, safeCandidates[1].myDist
        else
            -- If all unfinished generators are within minimum safe range of Killer,
            -- choose the generator that is the ABSOLUTE FURTHEST from the Killer on the map
            local furthestPt = nil
            local maxKDist = -1
            for _, pt in ipairs(candidatePoints) do
                local kDist = (kHrp.Position - pt.Position).Magnitude
                if kDist > maxKDist then
                    maxKDist = kDist
                    furthestPt = pt
                end
            end
            if furthestPt then
                return furthestPt, (myHrp.Position - furthestPt.Position).Magnitude
            end
        end
    end

    -- No killer detected: choose closest unfinished generator
    local bestPoint = nil
    local bestDist = math.huge
    for _, pt in ipairs(candidatePoints) do
        local dist = (myHrp.Position - pt.Position).Magnitude
        if dist < bestDist then
            bestDist = dist
            bestPoint = pt
        end
    end

    return bestPoint, bestDist
end

-- ============================================================
-- SMART PATHFINDING, WALL & COLLISION DETECTION (FOR SURVIVORS & KILLER)
-- ============================================================
local PathfindingService = game:GetService("PathfindingService")

-- Hooked Survivor Detection & Priority Rescue Engine
-- (Note: isCharacterHooked and isCharacterKnocked are anchored in Core Entity Engine)

local function isTeammateRescuable(plr)
    if not plr or plr == player then return false end
    local char = plr.Character
    if not char or not char.Parent then return false end
    if not isCharacterSurvivor(char, plr) then return false end
    if isCharacterKiller(char, plr) then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return false end

    -- Exclude players in Lobby or Spectator mode
    if isEntityInLobbyOrSpectating(char, plr) then
        return false
    end

    return isCharacterHooked(char) or isCharacterKnocked(char)
end

local function findUnhookPointForTeammate(teammateChar)
    if not teammateChar then return nil end
    local hrp = teammateChar:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local CS = game:GetService("CollectionService")
    local nearestPoint = nil
    local minDist = 16

    -- 1. Direct Weld / WeldConstraint binding hooked survivor to HookPoint / Hook Model
    for _, inst in ipairs(teammateChar:GetDescendants()) do
        if inst:IsA("Weld") or inst:IsA("WeldConstraint") or inst:IsA("Motor6D") then
            local other = (inst.Part0 and not inst.Part0:IsDescendantOf(teammateChar)) and inst.Part0
                or ((inst.Part1 and not inst.Part1:IsDescendantOf(teammateChar)) and inst.Part1)
            if other and other:IsA("BasePart") then
                local m = other:FindFirstAncestorOfClass("Model")
                if (other.Name:lower():find("hook")) or (m and (m.Name:lower():find("hook") or (m.Parent and m.Parent.Name:lower() == "hooks"))) then
                    return other
                end
            end
        end
    end

    -- 2. Check CollectionService tagged UnhookPoint / HookPoint
    if CS then
        for _, tagName in ipairs({ "UnhookPoint", "HookPoint" }) do
            for _, pt in ipairs(CS:GetTagged(tagName)) do
                if pt:IsA("BasePart") and not pt:FindFirstAncestor("Lobby") then
                    local d = (pt.Position - hrp.Position).Magnitude
                    if d < minDist then
                        minDist = d
                        nearestPoint = pt
                    end
                end
            end
        end
    end
    if nearestPoint then return nearestPoint end

    -- 3. Check Hooks folders directly
    local mapFolder = workspace:FindFirstChild("Map") or workspace:FindFirstChild("map")
    local hooksFolder = (mapFolder and (mapFolder:FindFirstChild("Hooks") or mapFolder:FindFirstChild("hooks")))
        or workspace:FindFirstChild("Hooks") or workspace:FindFirstChild("hooks")
    if hooksFolder then
        for _, obj in ipairs(hooksFolder:GetDescendants()) do
            if obj:IsA("BasePart") then
                local low = obj.Name:lower()
                if low == "unhookpoint" or low == "hookpoint" or low:find("unhook") or low == "hitbox" then
                    local d = (obj.Position - hrp.Position).Magnitude
                    if d < minDist then
                        minDist = d
                        nearestPoint = obj
                    end
                end
            end
        end
    end
    if nearestPoint then return nearestPoint end

    -- 4. Workspace fallback
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and not obj:FindFirstAncestor("Lobby") then
            local low = obj.Name:lower()
            if obj.Name == "UnhookPoint" or obj.Name == "HookPoint" or low:find("unhook") then
                local d = (obj.Position - hrp.Position).Magnitude
                if d < minDist then
                    minDist = d
                    nearestPoint = obj
                end
            end
        end
    end

    return nearestPoint or hrp
end

local function findNearestRescuableTeammate()
    local myChar = player.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return nil, nil, math.huge, nil end

    local nearestChar, nearestPlr = nil, nil
    local shortestDist = math.huge
    local rescueType = nil -- "hooked" or "knocked"

    -- Priority 1: Hooked teammates
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and isTeammateRescuable(plr) and isCharacterHooked(plr.Character) then
            local dist = (myHrp.Position - plr.Character.HumanoidRootPart.Position).Magnitude
            if dist < shortestDist then
                shortestDist = dist
                nearestChar = plr.Character
                nearestPlr = plr
                rescueType = "hooked"
            end
        end
    end

    if nearestChar then
        return nearestChar, nearestPlr, shortestDist, rescueType
    end

    -- Priority 2: Knocked teammates needing revival/heal
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and isTeammateRescuable(plr) and isCharacterKnocked(plr.Character) then
            local dist = (myHrp.Position - plr.Character.HumanoidRootPart.Position).Magnitude
            if dist < shortestDist then
                shortestDist = dist
                nearestChar = plr.Character
                nearestPlr = plr
                rescueType = "knocked"
            end
        end
    end

    return nearestChar, nearestPlr, shortestDist, rescueType
end

local function findNearestHookedTeammate()
    local c, p, d, t = findNearestRescuableTeammate()
    return c, p, d
end

local function hasTeammatesNeedingRescue()
    if not autoSaveEnabled then return false end
    local char = findNearestRescuableTeammate()
    return char ~= nil
end

local hasHookedTeammates = hasTeammatesNeedingRescue

checkWallCollision = function(fromPos, toPos, ignoreModel)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    local filterList = {}
    if ignoreModel then
        table.insert(filterList, ignoreModel)
    end
    if player.Character then
        table.insert(filterList, player.Character)
    end
    raycastParams.FilterDescendantsInstances = filterList
    raycastParams.IgnoreWater = true

    -- Raycast at waist height (+1.2 studs) to avoid floor/terrain collisions
    local rayOrigin = fromPos + Vector3.new(0, 1.2, 0)
    local rayTarget = toPos + Vector3.new(0, 1.2, 0)
    local rayDir = rayTarget - rayOrigin

    if rayDir.Magnitude < 0.05 then return false end

    local hit = workspace:Raycast(rayOrigin, rayDir, raycastParams)
    if hit and hit.Instance and hit.Instance.CanCollide then
        if hit.Instance.Transparency < 0.95 and not hit.Instance:IsA("Terrain") then
            return true, hit.Instance, hit.Position, hit.Normal
        end
    end
    return false
end

-- Calculates clear standing coordinates beside a target to prevent clipping/physics pushback
local function getSafeInteractPosition(targetPart, customPos)
    local targetPos = customPos or (targetPart and targetPart.Position) or Vector3.zero
    local parentModel = (targetPart and targetPart:FindFirstAncestorOfClass("Model")) or (targetPart and targetPart.Parent)

    -- 6 radial test positions (radius 2.8 studs) around target
    local offsets = {
        Vector3.new(2.8, 0, 0),
        Vector3.new(-2.8, 0, 0),
        Vector3.new(0, 0, 2.8),
        Vector3.new(0, 0, -2.8),
        Vector3.new(2.0, 0, 2.0),
        Vector3.new(-2.0, 0, -2.0)
    }

    if targetPart and targetPart:IsA("BasePart") then
        local look = targetPart.CFrame.LookVector * 2.8
        local right = targetPart.CFrame.RightVector * 2.8
        table.insert(offsets, 1, look)
        table.insert(offsets, 2, -look)
        table.insert(offsets, 3, right)
        table.insert(offsets, 4, -right)
    end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local fList = { player.Character }
    if parentModel then table.insert(fList, parentModel) end
    if targetPart then table.insert(fList, targetPart) end
    rayParams.FilterDescendantsInstances = fList

    for _, off in ipairs(offsets) do
        local testPos = targetPos + off
        -- Raycast down to find ground level
        local groundRay = workspace:Raycast(testPos + Vector3.new(0, 3, 0), Vector3.new(0, -7, 0), rayParams)
        if groundRay and groundRay.Position then
            local floorPos = groundRay.Position + Vector3.new(0, 2.0, 0)
            local hasWall = checkWallCollision(targetPos, floorPos, parentModel)
            if not hasWall then
                return floorPos
            end
        end
    end

    return targetPos + Vector3.new(0, 1.2, 0)
end

local function hasCeilingAbove(pos, checkHeight, ignoreChar)
    local height = checkHeight or 24
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local filter = {}
    if ignoreChar then table.insert(filter, ignoreChar) end
    if player.Character then table.insert(filter, player.Character) end
    rayParams.FilterDescendantsInstances = filter
    rayParams.IgnoreWater = true

    local rayOrigin = pos + Vector3.new(0, 1.5, 0)
    local rayDir = Vector3.new(0, height, 0)
    local hit = workspace:Raycast(rayOrigin, rayDir, rayParams)
    if hit and hit.Instance and hit.Instance.CanCollide and hit.Instance.Transparency < 0.95 and not hit.Instance:IsA("Terrain") then
        return true, hit.Position.Y
    end
    return false, nil
end

-- Measures the vertical height of a wall obstacle ahead to determine if it can be flown over
local function getWallObstacleHeight(hitPos, hitNormal, maxCheckHeight)
    local maxHeight = maxCheckHeight or 18
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local filterList = {}
    if player.Character then table.insert(filterList, player.Character) end
    rayParams.FilterDescendantsInstances = filterList
    rayParams.IgnoreWater = true

    local normal = hitNormal or Vector3.new(0, 0, 1)
    for h = 2, maxHeight, 1.5 do
        local testOrigin = hitPos + Vector3.new(0, h, 0) + normal * 0.8
        local testDir = -normal * 2.2
        local hit = workspace:Raycast(testOrigin, testDir, rayParams)
        if not hit then
            return h, hitPos.Y + h
        end
    end
    return nil, nil
end

-- Active travel noclip manager: Directly bypasses the game's resolveBodyStep & worldSafe anti-noclip blockcast
local travelNoClipConn = nil
startTravelNoClip = function()
    local char = player.Character
    if char then
        pcall(function()
            -- Verified bypass attributes from the dump.lua (lines 29208 & 32043)
            char:SetAttribute("BypassNoclipAntiCheat", true)
            char:SetAttribute("donttrack", true)
            char:SetAttribute("NetTraversalUntil", 999999999)
            if char:GetAttribute("AC_ServerAnchor") ~= nil then
                char:SetAttribute("AC_ServerAnchor", nil)
            end
        end)
    end
    if travelNoClipConn then return end
    travelNoClipConn = RunService.Stepped:Connect(function()
        local c = player.Character
        if c then
            pcall(function()
                c:SetAttribute("BypassNoclipAntiCheat", true)
                c:SetAttribute("donttrack", true)
                c:SetAttribute("NetTraversalUntil", 999999999)
                if c:GetAttribute("AC_ServerAnchor") ~= nil then
                    c:SetAttribute("AC_ServerAnchor", nil)
                end
            end)
            for _, part in ipairs(c:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
end

stopTravelNoClip = function()
    if travelNoClipConn then
        pcall(function() travelNoClipConn:Disconnect() end)
        travelNoClipConn = nil
    end
    local char = player.Character
    if char then
        if not noClipEnabled then
            pcall(function()
                char:SetAttribute("BypassNoclipAntiCheat", false)
                char:SetAttribute("donttrack", false)
                char:SetAttribute("NetTraversalUntil", nil)
                if char:GetAttribute("AC_ServerAnchor") ~= nil then
                    char:SetAttribute("AC_ServerAnchor", nil)
                end
            end)
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        else
            -- Maintain bypass attributes while user has global NoClip toggle ON
            pcall(function()
                char:SetAttribute("BypassNoclipAntiCheat", true)
                char:SetAttribute("donttrack", true)
                if char:GetAttribute("AC_ServerAnchor") ~= nil then
                    char:SetAttribute("AC_ServerAnchor", nil)
                end
            end)
        end
    end
end

-- High-intelligence path calculator with doorway sizing, Killer danger-zone avoidance, and 3D Flying support
computeSmartWaypoints = function(startPos, endPos, targetPart, avoidKillerPos, killerSafeDist)
    local hasWallDirect, hitPart, hitPos, hitNormal = checkWallCollision(startPos, endPos, player.Character)

    -- If no wall is blocking direct line of sight, return direct path
    if not hasWallDirect then
        return { { Position = startPos }, { Position = endPos } }, "direct"
    end

    -- 1. Check if we can Fly over obstacles (if there is NO ceiling above)
    local hasCeilStart, ceilStartY = hasCeilingAbove(startPos, 22, player.Character)
    local hasCeilEnd, ceilEndY = hasCeilingAbove(endPos, 22, player.Character)
    local midPos = (startPos + endPos) * 0.5
    local hasCeilMid, ceilMidY = hasCeilingAbove(midPos, 22, player.Character)

    if not hasCeilStart and not hasCeilEnd and not hasCeilMid then
        -- Sky is completely open! Fly up and over the obstacles obstacle-free!
        local flyAltitude = math.max(startPos.Y, endPos.Y) + 14
        local airStart = Vector3.new(startPos.X, flyAltitude, startPos.Z)
        local airEnd = Vector3.new(endPos.X, flyAltitude, endPos.Z)
        return {
            { Position = startPos },
            { Position = airStart },
            { Position = airEnd },
            { Position = endPos }
        }, "flying"
    end

    -- 2. Try NavMesh PathfindingService (for indoor / under-ceiling areas)
    local path = PathfindingService:CreatePath({
        AgentRadius = 1.6,
        AgentHeight = 4.8,
        AgentCanJump = true,
        AgentCanClimb = false,
        WaypointSpacing = 2.5,
        Costs = {
            Water = 100
        }
    })

    local success = pcall(function()
        path:ComputeAsync(startPos, endPos)
    end)

    if success and path.Status == Enum.PathStatus.Success then
        local rawWaypoints = path:GetWaypoints()
        if rawWaypoints and #rawWaypoints > 0 then
            if avoidKillerPos and killerSafeDist then
                for _, wp in ipairs(rawWaypoints) do
                    local distToKiller = (wp.Position - avoidKillerPos).Magnitude
                    if distToKiller < (killerSafeDist + 4) then
                        return nil, "killer_near_path"
                    end
                end
            end
            return rawWaypoints, "pathfinding"
        end
    end

    -- 3. Smart Tangent Detour around wall (when under ceiling or navmesh fails)
    local normal = hitNormal or (startPos - hitPos).Unit
    local tangent = Vector3.new(-normal.Z, 0, normal.X).Unit
    for d = 3, 14, 3 do
        local cand1 = hitPos + tangent * d + normal * 2.0
        local cand2 = hitPos - tangent * d + normal * 2.0
        if not checkWallCollision(startPos, cand1, player.Character) and not checkWallCollision(cand1, endPos, player.Character) then
            return { { Position = startPos }, { Position = cand1 }, { Position = endPos } }, "detour"
        elseif not checkWallCollision(startPos, cand2, player.Character) and not checkWallCollision(cand2, endPos, player.Character) then
            return { { Position = startPos }, { Position = cand2 }, { Position = endPos } }, "detour"
        end
    end

    -- 4. If partial ceiling allows, low fly-hop (hop over low obstacles up to ceiling)
    if ceilStartY and (ceilStartY - startPos.Y) >= 8 then
        local hopY = math.min(startPos.Y + 6, ceilStartY - 2)
        local hopStart = Vector3.new(startPos.X, hopY, startPos.Z)
        local hopEnd = Vector3.new(endPos.X, hopY, endPos.Z)
        if not checkWallCollision(hopStart, hopEnd, player.Character) then
            return {
                { Position = startPos },
                { Position = hopStart },
                { Position = hopEnd },
                { Position = endPos }
            }, "flying"
        end
    end

    return { { Position = startPos }, { Position = endPos } }, "fallback"
end

local function travelToPoint(targetPartOrPos, stopReach, activeCheck, avoidKiller, customSafeDist, specificTravelMode)
    local myChar = player.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local hum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    if not myHrp or not targetPartOrPos then return false end

    -- Resolve target position & target part
    local targetPos
    local targetPart = nil
    if typeof(targetPartOrPos) == "Vector3" then
        targetPos = targetPartOrPos
    elseif targetPartOrPos:IsA("BasePart") then
        targetPart = targetPartOrPos
        targetPos = targetPartOrPos.Position
    elseif targetPartOrPos:IsA("Model") then
        targetPart = targetPartOrPos.PrimaryPart or targetPartOrPos:FindFirstChild("HumanoidRootPart") or targetPartOrPos:FindFirstChildWhichIsA("BasePart")
        targetPos = targetPart and targetPart.Position or targetPartOrPos:GetPivot().Position
    else
        return false
    end

    local reach = stopReach or 4.5
    local dist = (myHrp.Position - targetPos).Magnitude
    if dist <= reach then return true end

    local checkActive = activeCheck or function()
        return scriptRunning
    end
    local shouldAvoidKiller = (avoidKiller ~= false)
    local safeDist = customSafeDist or repairSafeDistance or 25
    local activeMode = specificTravelMode or travelMode
    if activeMode ~= "Instant Teleport" and activeMode ~= "Run Normally" then
        activeMode = "Safe Teleport"
    end

    isTraveling = true

    -- 1. SMART INSTANT TELEPORT (MICRO-BURST & ANTI-SETBACK WITH VERIFIED DUMP BYPASSES)
    if activeMode == "Instant Teleport" then
        startTravelNoClip()
        local safeStandPos = getSafeInteractPosition(targetPart, targetPos)

        -- Precise ground raycast alignment to eliminate floor mesh clipping
        local groundRayParams = RaycastParams.new()
        groundRayParams.FilterType = Enum.RaycastFilterType.Exclude
        groundRayParams.FilterDescendantsInstances = { player.Character }
        groundRayParams.IgnoreWater = true
        local groundHit = workspace:Raycast(safeStandPos + Vector3.new(0, 5, 0), Vector3.new(0, -14, 0), groundRayParams)
        if groundHit and groundHit.Position then
            safeStandPos = groundHit.Position + Vector3.new(0, 1.8, 0)
        end

        local fromPos = myHrp.Position
        local totalDist = (safeStandPos - fromPos).Magnitude

        -- Rapid micro-burst over 3-5 frames (0.02s) with dump bypass attributes active
        local burstSteps = math.clamp(math.ceil(totalDist / 14), 2, 6)
        for s = 1, burstSteps do
            if not checkActive() or not scriptRunning then break end
            local frac = s / burstSteps
            local stepPos = fromPos:Lerp(safeStandPos, frac)

            pcall(function()
                myChar:SetAttribute("BypassNoclipAntiCheat", true)
                myChar:SetAttribute("donttrack", true)
                myChar:SetAttribute("NetTraversalUntil", 999999999)
                myHrp.AssemblyLinearVelocity = Vector3.zero
                myHrp.AssemblyAngularVelocity = Vector3.zero
                myHrp.CFrame = CFrame.lookAt(stepPos, targetPos)
            end)
            task.wait(0.008)
        end

        -- Final lock & settling at target position
        pcall(function()
            myHrp.CFrame = CFrame.lookAt(safeStandPos, targetPos)
            myHrp.AssemblyLinearVelocity = Vector3.zero
            myHrp.AssemblyAngularVelocity = Vector3.zero
        end)
        task.wait(0.03)

        local realDist = (myHrp.Position - targetPos).Magnitude
        local success = realDist <= (reach + 2.0)

        if not success then
            pcall(function()
                myHrp.CFrame = CFrame.lookAt(safeStandPos, targetPos)
                myHrp.AssemblyLinearVelocity = Vector3.zero
            end)
            task.wait(0.03)
            success = (myHrp.Position - targetPos).Magnitude <= (reach + 2.5)
        end

        stopTravelNoClip()
        isTraveling = false
        return success

    -- 2. HIGH-SPEED SMOOTH SAFE TELEPORT (DIRECT LINE-OF-SIGHT THROUGH ALL WALLS, 0% SNAP-BACK)
    elseif activeMode == "Safe Teleport" then
        startTravelNoClip()
        local step = math.clamp(safeTeleportStep or 3.5, 1.0, 6.0)
        local safeEndPos = getSafeInteractPosition(targetPart, targetPos)

        local fromPos = myHrp.Position
        local toDest = (safeEndPos - fromPos)
        local totalDist = toDest.Magnitude

        if totalDist <= reach then
            stopTravelNoClip()
            isTraveling = false
            return true
        end

        local dir = (totalDist > 0.001) and toDest.Unit or Vector3.new(0, 0, 1)
        local numSteps = math.max(1, math.ceil(totalDist / step))

        for s = 1, numSteps do
            if not checkActive() or not scriptRunning then break end

            -- Real-time Killer proximity guard
            if shouldAvoidKiller then
                local curK = getKiller()
                if curK and curK:FindFirstChild("HumanoidRootPart") then
                    local curKDist = (myHrp.Position - curK.HumanoidRootPart.Position).Magnitude
                    if curKDist < safeDist then
                        stopTravelNoClip()
                        if hum then pcall(function() hum:Move(Vector3.zero) end) end
                        isTraveling = false
                        return false -- Safely abort & reroute away from Killer
                    end
                end
            end

            -- Target completion check (e.g. generator finished while traveling)
            if targetPart and isGeneratorCompleted and isGeneratorCompleted(targetPart) then
                stopTravelNoClip()
                if hum then pcall(function() hum:Move(Vector3.zero) end) end
                isTraveling = false
                return false
            end

            local frac = math.min(1.0, s / numSteps)
            -- Direct smooth interpolation in 3D space straight through all walls & obstacles
            local nextPos = fromPos:Lerp(safeEndPos, frac)

            -- Keep character facing forward along travel direction with zero velocities
            myHrp.CFrame = CFrame.lookAt(nextPos, nextPos + dir)
            myHrp.AssemblyLinearVelocity = Vector3.zero
            myHrp.AssemblyAngularVelocity = Vector3.zero

            -- High-speed smooth step: ~0.015s per step (glides ~230 studs/sec directly through walls)
            task.wait(0.015)

            if (myHrp.Position - targetPos).Magnitude <= reach then
                break
            end
        end

        -- Final Ground Surface Alignment: Raycast only upon arrival at target point
        pcall(function()
            local groundRayParams = RaycastParams.new()
            groundRayParams.FilterType = Enum.RaycastFilterType.Exclude
            groundRayParams.FilterDescendantsInstances = { player.Character }
            groundRayParams.IgnoreWater = true
            local groundHit = workspace:Raycast(safeEndPos + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), groundRayParams)
            local finalPos = safeEndPos
            if groundHit and groundHit.Position then
                finalPos = groundHit.Position + Vector3.new(0, 1.8, 0)
            end
            myHrp.CFrame = CFrame.lookAt(finalPos, targetPos)
            myHrp.AssemblyLinearVelocity = Vector3.zero
            myHrp.AssemblyAngularVelocity = Vector3.zero
        end)
        task.wait(0.03)

        stopTravelNoClip()
        if hum then pcall(function() hum:Move(Vector3.zero) end) end
        isTraveling = false
        return (myHrp.Position - targetPos).Magnitude <= (reach + 1.8)

    -- 3. SMART RUN NORMALLY (PATHFINDING WITH WALL & STUCK WATCHDOG)
    elseif activeMode == "Run Normally" then
        local killer = getKiller()
        local kHrp = killer and killer:FindFirstChild("HumanoidRootPart")
        local avoidKPos = (shouldAvoidKiller and kHrp) and kHrp.Position or nil

        local safeEndPos = getSafeInteractPosition(targetPart, targetPos)
        local waypoints, status = computeSmartWaypoints(myHrp.Position, safeEndPos, targetPart, avoidKPos, safeDist)

        if not waypoints or #waypoints == 0 then
            isTraveling = false
            return false
        end

        pcall(function() myChar:SetAttribute("Sprinting", true) end)

        for wpIdx, wp in ipairs(waypoints) do
            if not checkActive() or not scriptRunning then break end

            -- Real-time Killer check
            if shouldAvoidKiller then
                local curK = getKiller()
                if curK and curK:FindFirstChild("HumanoidRootPart") then
                    local curKDist = (myHrp.Position - curK.HumanoidRootPart.Position).Magnitude
                    if curKDist < safeDist then
                        if hum then hum:MoveTo(myHrp.Position) end
                        isTraveling = false
                        return false
                    end
                end
            end

            if (myHrp.Position - targetPos).Magnitude <= reach then
                break
            end

            if targetPart and isGeneratorCompleted and isGeneratorCompleted(targetPart) then
                if hum then hum:MoveTo(myHrp.Position) end
                isTraveling = false
                return false
            end

            if wp.Action == Enum.PathWaypointAction.Jump and hum then
                hum.Jump = true
            end

            if hum then
                hum:MoveTo(wp.Position)

                local wpStartTime = tick()
                local lastPos = myHrp.Position
                local lastCheckTime = tick()
                local stuckCounter = 0

                while checkActive() and scriptRunning and (myHrp.Position - wp.Position).Magnitude > 2.8 and (tick() - wpStartTime) < 3.5 do
                    if (tick() - lastCheckTime) >= 0.15 then
                        local distMoved = (myHrp.Position - lastPos).Magnitude
                        lastPos = myHrp.Position
                        lastCheckTime = tick()

                        if distMoved < 0.25 then
                            stuckCounter = stuckCounter + 1
                            if stuckCounter >= 2 then
                                hum.Jump = true
                                local hasWall, _, hitPos, hitNormal = checkWallCollision(myHrp.Position, wp.Position, myChar)
                                if hasWall and hitNormal then
                                    local sideDeflect = Vector3.new(-hitNormal.Z, 0, hitNormal.X).Unit * 3.0
                                    hum:MoveTo(myHrp.Position + sideDeflect)
                                    task.wait(0.18)
                                end
                                hum:MoveTo(wp.Position)
                                stuckCounter = 0
                            end
                        else
                            stuckCounter = 0
                        end
                    end
                    task.wait(0.04)
                end
            end
        end

        if hum then hum:MoveTo(myHrp.Position) end
        pcall(function() myChar:SetAttribute("Sprinting", false) end)
        isTraveling = false
        return (myHrp.Position - targetPos).Magnitude <= (reach + 2.5)
    end

    isTraveling = false
    return false
end

V_ObjectiveSection:Dropdown({
    Title = "Generator Travel Mode",
    Description = "Method used to travel to nearby generators (Safe Teleport, Instant, or Normal Run)",
    Values = { "Safe Teleport", "Instant Teleport", "Run Normally" },
    Value = "Safe Teleport",
    Callback = function(v)
        travelMode = v
    end
})

V_ObjectiveSection:Slider({
    Title = "Safe Teleport Step",
    Description = "Step distance for Safe Teleport (1.0 - 6.0 studs per step for smooth through-wall travel)",
    Step = 0.5,
    Value = {
        Min = 1.0,
        Max = 6.0,
        Default = 3.5,
    },
    Callback = function(val)
        safeTeleportStep = tonumber(val) or 3.5
    end
})

V_ObjectiveSection:Slider({
    Title = "Proximity Safe Guard",
    Description = "Cancel repair/travel if Killer is within this distance (studs)",
    Step = 1,
    Value = {
        Min = 25,
        Max = 200,
        Default = 25,
    },
    Callback = function(val)
        repairSafeDistance = tonumber(val) or 25
    end
})

V_ObjectiveSection:Toggle({
    Title = "Auto Repair Generator",
    Description = "Auto searches, travels to, and repairs generators with live fix detection",
    Default = false,
    Callback = function(v)
        autoRepairEnabled = v
        repairSession = repairSession + 1
        local thisSession = repairSession
        local remotes = getVDRemotes()

        if not v then
            -- Immediately cancel any ongoing repair on server & clear local state
            if currentRepairPoint and remotes.Generator and remotes.Generator:FindFirstChild("RepairEvent") then
                pcall(function()
                    remotes.Generator.RepairEvent:FireServer(currentRepairPoint, false, nil, HttpService:GenerateGUID(false), player.Character)
                end)
            end
            currentRepairPoint = nil
            pcall(function()
                if player.Character then
                    player.Character:SetAttribute("isRepairing", false)
                end
            end)
            return
        end

        completedGenerators = {}

        local function checkRepairActive()
            return autoRepairEnabled and (repairSession == thisSession) and scriptRunning
        end

        -- 1. High-frequency independent Proximity Safe Guard thread (runs every 0.12s)
        task.spawn(function()
            while checkRepairActive() do
                pcall(function()
                    local myChar = player.Character
                    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                    if myHrp then
                        local killer = getKiller()
                        if killer and killer:FindFirstChild("HumanoidRootPart") then
                            local kDist = (myHrp.Position - killer.HumanoidRootPart.Position).Magnitude
                            if kDist < repairSafeDistance then
                                if currentRepairPoint then
                                    if remotes.Generator and remotes.Generator:FindFirstChild("RepairEvent") then
                                        remotes.Generator.RepairEvent:FireServer(currentRepairPoint, false, nil, HttpService:GenerateGUID(false), myChar)
                                    end
                                    currentRepairPoint = nil
                                end
                            end
                        end
                    end
                end)
                task.wait(0.12)
            end
        end)

        -- 2. Main Auto Repair execution loop
        task.spawn(function()
            while checkRepairActive() do
                pcall(function()
                    local myChar = player.Character
                    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                    if not myHrp then task.wait(0.5) return end

                    -- PRIORITY CHECK: SAVE TEAMMATE > FIX GENERATOR
                    if autoSaveEnabled and hasHookedTeammates() then
                        if currentRepairPoint and remotes.Generator and remotes.Generator:FindFirstChild("RepairEvent") then
                            pcall(function()
                                remotes.Generator.RepairEvent:FireServer(currentRepairPoint, false, nil, HttpService:GenerateGUID(false), myChar)
                            end)
                            currentRepairPoint = nil
                        end
                        task.wait(0.5)
                        return
                    end

                    local killer = getKiller()

                    -- If Killer is nearby, IMMEDIATELY find and travel to a far, safe generator!
                    if killer and killer:FindFirstChild("HumanoidRootPart") then
                        local killerDist = (myHrp.Position - killer.HumanoidRootPart.Position).Magnitude
                        if killerDist < repairSafeDistance then
                            if currentRepairPoint and remotes.Generator and remotes.Generator:FindFirstChild("RepairEvent") then
                                remotes.Generator.RepairEvent:FireServer(currentRepairPoint, false, nil, HttpService:GenerateGUID(false), myChar)
                                currentRepairPoint = nil
                            end

                            -- Find safe generator far away from the killer
                            local safeTarget, safeDist = findNextUnfinishedGenerator(killer)
                            if safeTarget and checkRepairActive() then
                                travelToPoint(safeTarget, nil, checkRepairActive)
                            end
                            task.wait(0.5)
                            return
                        end
                    end

                    -- Search for next unfinished generator (safe from killer)
                    local targetPoint, dist = findNextUnfinishedGenerator(killer)
                    if not targetPoint or not checkRepairActive() then
                        task.wait(1.5)
                        return
                    end

                    -- Travel if not yet in repair range
                    local curDist = (myHrp.Position - targetPoint.Position).Magnitude
                    if curDist > 4.5 then
                        local arrived = travelToPoint(targetPoint, nil, checkRepairActive)
                        if not checkRepairActive() then return end
                        if not arrived or (myHrp.Position - targetPoint.Position).Magnitude > 4.5 then
                            task.wait(0.15)
                            if not checkRepairActive() then return end
                            travelToPoint(targetPoint, nil, checkRepairActive)
                        end
                    end

                    if not checkRepairActive() then return end

                    -- Verify we actually reached the generator (within 5.2 studs) before initiating repair
                    if (myHrp.Position - targetPoint.Position).Magnitude > 5.2 then
                        task.wait(0.3)
                        return
                    end

                    -- Verify generator is still unfinished upon arrival
                    local isDone, _ = isGeneratorCompleted(targetPoint)
                    if isDone then
                        completedGenerators[targetPoint] = true
                        local gm = getGeneratorModel(targetPoint)
                        if gm then completedGenerators[gm] = true end
                        task.wait(0.3)
                        return
                    end

                    -- In range: initiate active repair & monitor until finished or interrupted
                    if targetPoint and remotes.Generator and remotes.Generator:FindFirstChild("RepairEvent") and checkRepairActive() then
                        currentRepairPoint = targetPoint
                        local guid = HttpService:GenerateGUID(false)
                        local actualGenModel = resolveGeneratorInstance(targetPoint, getGeneratorModel(targetPoint))
                        lastCapturedGenModel = actualGenModel
                        lastCapturedGenPoint = targetPoint
                        lastCapturedRepairRequestId = guid
                        remotes.Generator.RepairEvent:FireServer(targetPoint, true, nil, guid, myChar)

                        local repairTimeout = tick() + 60
                        while checkRepairActive() and currentRepairPoint == targetPoint and tick() < repairTimeout do
                            -- Priority Interrupt: Teammate was hooked, immediately drop repair to rescue!
                            if autoSaveEnabled and hasHookedTeammates() then
                                remotes.Generator.RepairEvent:FireServer(targetPoint, false, nil, guid, myChar)
                                currentRepairPoint = nil
                                task.wait(0.2)
                                break
                            end
                            -- Real-time killer check: break and flee to far generator if killer approaches
                            local k = getKiller()
                            if k and k:FindFirstChild("HumanoidRootPart") then
                                local kDist = (myHrp.Position - k.HumanoidRootPart.Position).Magnitude
                                if kDist < repairSafeDistance then
                                    remotes.Generator.RepairEvent:FireServer(targetPoint, false, nil, guid, myChar)
                                    currentRepairPoint = nil
                                    -- Immediately flee to a safe far generator
                                    local fleeTarget = findNextUnfinishedGenerator(k)
                                    if fleeTarget and checkRepairActive() then
                                        travelToPoint(fleeTarget, nil, checkRepairActive)
                                    end
                                    task.wait(0.5)
                                    break
                                end
                            end

                            -- Real-time completion check
                            local doneNow, _ = isGeneratorCompleted(targetPoint)
                            if doneNow then
                                completedGenerators[targetPoint] = true
                                local gm = getGeneratorModel(targetPoint)
                                if gm then completedGenerators[gm] = true end
                                remotes.Generator.RepairEvent:FireServer(targetPoint, false, nil, guid, myChar)
                                currentRepairPoint = nil
                                task.wait(0.4)
                                break
                            end

                            -- Keep repair pulse active
                            remotes.Generator.RepairEvent:FireServer(targetPoint, true, nil, guid, myChar)
                            task.wait(0.8)
                        end

                        if not checkRepairActive() and currentRepairPoint == targetPoint then
                            remotes.Generator.RepairEvent:FireServer(targetPoint, false, nil, guid, myChar)
                            currentRepairPoint = nil
                        end
                    end
                end)
                task.wait(0.15)
            end
        end)
    end
})

-- ============================================================
-- 4.1 UNDERGROUND GHOST REPAIR (SUBTERRANEAN PROXIMITY AUTO REPAIR)
-- ============================================================
local ghostRepairEnabled = false
local ghostDepthOffset = 7.0
local ghostRepairPulseInterval = 0.8
local ghostAutoReturn = true
local ghostRepairSession = 0
local currentGhostGenPoint = nil
local currentGhostGenModel = nil
local ghostOriginalCFrame = nil

local function stopGhostRepair()
    pcall(function()
        local remotes = getVDRemotes()
        if currentGhostGenPoint and remotes.Generator and remotes.Generator:FindFirstChild("RepairEvent") then
            remotes.Generator.RepairEvent:FireServer(currentGhostGenPoint, false, nil, HttpService:GenerateGUID(false), player.Character)
        end
    end)
    pcall(function()
        if ghostAutoReturn and ghostOriginalCFrame then
            local myChar = player.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if myHrp then
                myHrp.CFrame = ghostOriginalCFrame
                myHrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                myHrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            end
        end
    end)
    ghostOriginalCFrame = nil
    currentGhostGenPoint = nil
    currentGhostGenModel = nil
    pcall(function()
        if player.Character then
            player.Character:SetAttribute("isRepairing", false)
            for _, part in ipairs(player.Character:GetDescendants()) do
                if part:IsA("BasePart") and (part.Name == "HumanoidRootPart" or part.Name == "Torso" or part.Name == "UpperTorso" or part.Name == "LowerTorso" or part.Name == "Head") then
                    part.CanCollide = true
                end
            end
        end
    end)
    unlockCameraAndMovement()
end

local function findNextUnfinishedGeneratorGhost()
    local myChar = player.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myPos = myHrp and myHrp.Position or Vector3.new(0, 0, 0)
    local candidatePoints = {}
    local processedGenerators = {}

    local function addPoint(pt)
        if pt and pt:IsA("BasePart") and not (myChar and pt:IsDescendantOf(myChar)) then
            local genModel = getGeneratorModel(pt) or pt.Parent
            if genModel and not processedGenerators[genModel] then
                local isCompleted, prog = isGeneratorCompleted(pt)
                if not isCompleted and prog < 99.5 then
                    table.insert(candidatePoints, { point = pt, model = genModel, progress = prog })
                    processedGenerators[genModel] = true
                end
            end
        end
    end

    pcall(function()
        local CollectionService = game:GetService("CollectionService")
        for _, pt in ipairs(CollectionService:GetTagged("GeneratorPoint")) do
            addPoint(pt)
        end
    end)

    pcall(function()
        local map = workspace:FindFirstChild("Map")
        local mapGens = map and (map:FindFirstChild("Generators") or map:FindFirstChild("new Generators"))
        if mapGens then
            for _, gen in ipairs(mapGens:GetChildren()) do
                for _, desc in ipairs(gen:GetDescendants()) do
                    if desc:IsA("BasePart") and (desc.Name:find("GeneratorPoint") or desc.Name == "RepairPoint") then
                        addPoint(desc)
                    end
                end
            end
        end
    end)

    if #candidatePoints == 0 then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and (obj.Name == "RepairPoint" or obj.Name == "GeneratorPoint") then
                addPoint(obj)
            end
        end
    end

    if #candidatePoints == 0 then return nil, nil end

    table.sort(candidatePoints, function(a, b)
        if math.abs(a.progress - b.progress) > 1 then
            return a.progress > b.progress
        end
        local distA = (myPos - a.point.Position).Magnitude
        local distB = (myPos - b.point.Position).Magnitude
        return distA < distB
    end)

    return candidatePoints[1].point, candidatePoints[1].model
end

local function startGhostRepairThread()
    ghostRepairSession = ghostRepairSession + 1
    local thisSession = ghostRepairSession

    -- Capture surface original CFrame immediately before going underground
    local initialChar = player.Character
    local initialHrp = initialChar and initialChar:FindFirstChild("HumanoidRootPart")
    if not ghostOriginalCFrame and initialHrp then
        ghostOriginalCFrame = initialHrp.CFrame
    end

    -- 1. High-frequency dedicated subterranean position lock thread:
    -- Constantly spam-enforces the teleport to designated target underground every 0.1s
    task.spawn(function()
        while ghostRepairEnabled and (ghostRepairSession == thisSession) and scriptRunning do
            pcall(function()
                local c = player.Character
                local hrp = c and c:FindFirstChild("HumanoidRootPart")
                local hum = c and c:FindFirstChildOfClass("Humanoid")
                if hrp and hum and hum.Health > 0 and not isCharacterHooked(c) and not isCharacterKnocked(c) then
                    local pt = currentGhostGenPoint
                    if pt and pt.Parent and pt:IsA("BasePart") then
                        local desiredPos = pt.Position - Vector3.new(0, ghostDepthOffset, 0)
                        hrp.CFrame = CFrame.new(desiredPos)
                        hrp.AssemblyLinearVelocity = Vector3.zero
                        hrp.AssemblyAngularVelocity = Vector3.zero

                        -- Disable collisions on character parts so terrain/floor geometry cannot pop body above ground
                        for _, part in ipairs(c:GetDescendants()) do
                            if part:IsA("BasePart") and part.CanCollide then
                                part.CanCollide = false
                            end
                        end
                    end
                end
            end)
            task.wait(0.1)
        end
    end)

    -- 2. Main Ghost Repair orchestration thread
    task.spawn(function()
        while ghostRepairEnabled and (ghostRepairSession == thisSession) and scriptRunning do
            local iterSuccess, iterErr = pcall(function()
                local myChar = player.Character
                if not myChar or not myChar:IsDescendantOf(workspace) then
                    task.wait(0.5)
                    return
                end
                local hum = myChar:FindFirstChildOfClass("Humanoid")
                local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                if not myHrp or not hum or hum.Health <= 0 then
                    task.wait(0.5)
                    return
                end
                if isCharacterHooked(myChar) or isCharacterKnocked(myChar) then
                    task.wait(0.5)
                    return
                end

                local targetPoint, genModel = findNextUnfinishedGeneratorGhost()
                if not targetPoint or not genModel then
                    WindUI:Notify({ Title = "Ghost Gen", Content = "All generators 100% completed!", Duration = 3 })
                    if ghostAutoReturn and ghostOriginalCFrame and myHrp then
                        myHrp.CFrame = ghostOriginalCFrame
                        myHrp.AssemblyLinearVelocity = Vector3.zero
                        ghostOriginalCFrame = nil
                    end
                    task.wait(2.5)
                    return
                end

                currentGhostGenPoint = targetPoint
                currentGhostGenModel = genModel

                local remotes = getVDRemotes()
                if not remotes.Generator or not remotes.Generator:FindFirstChild("RepairEvent") then
                    task.wait(1)
                    return
                end

                local genName = genModel.Name or "Generator"
                local isDone, currentProg = isGeneratorCompleted(targetPoint)
                WindUI:Notify({
                    Title = "👻 Ghost Repair",
                    Content = string.format("Subterranean fixing %s [%.0f%%]", genName, currentProg or 0),
                    Duration = 2
                })

                -- Save surface CFrame if not already captured
                if not ghostOriginalCFrame and myHrp then
                    ghostOriginalCFrame = myHrp.CFrame
                end

                -- Position character directly under targetPoint (bypasses server X/Z horizontal distance check invisibly)
                local safeUndergroundCFrame = CFrame.new(targetPoint.Position - Vector3.new(0, ghostDepthOffset, 0))
                if myHrp then
                    myHrp.CFrame = safeUndergroundCFrame
                    myHrp.AssemblyLinearVelocity = Vector3.zero
                    myHrp.AssemblyAngularVelocity = Vector3.zero
                end

                local requestId = HttpService:GenerateGUID(false)
                local actualGenModel = resolveGeneratorInstance(targetPoint, genModel)
                lastCapturedGenModel = actualGenModel
                lastCapturedGenPoint = targetPoint
                lastCapturedRepairRequestId = requestId

                -- Begin Repair on server
                pcall(function()
                    remotes.Generator.RepairEvent:FireServer(targetPoint, true, nil, requestId, myChar)
                    myChar:SetAttribute("isRepairing", true)
                end)

                local genTimeout = tick() + 75
                while ghostRepairEnabled and (ghostRepairSession == thisSession) and scriptRunning and tick() < genTimeout do
                    local doneNow, progNow = isGeneratorCompleted(targetPoint)
                    if doneNow or (progNow and progNow >= 99.5) then
                        completedGenerators[targetPoint] = true
                        completedGenerators[genModel] = true
                        pcall(function()
                            remotes.Generator.RepairEvent:FireServer(targetPoint, false, nil, requestId, myChar)
                        end)
                        currentGhostGenPoint = nil
                        currentGhostGenModel = nil
                        WindUI:Notify({ Title = "👻 Ghost Repair", Content = "⚡ " .. genName .. " Fixed 100%! Next...", Duration = 2 })
                        task.wait(0.4)
                        break
                    end

                    -- Keep repair pulse active
                    pcall(function()
                        remotes.Generator.RepairEvent:FireServer(targetPoint, true, nil, requestId, myChar)
                    end)

                    -- Send Great Skill Check Progression Boost (+1% per pulse directly with { player.Name })
                    if remotes.Generator:FindFirstChild("SkillCheckResultEvent") then
                        local sendGenModel = resolveGeneratorInstance(targetPoint, actualGenModel or genModel)
                        pcall(function()
                            remotes.Generator.SkillCheckResultEvent:FireServer(
                                "success",
                                1,
                                sendGenModel,
                                targetPoint,
                                requestId,
                                { player.Name }
                            )
                        end)
                    end

                    -- Constantly anchor underground and freeze physics to prevent falling into the void
                    if myHrp then
                        local desiredPos = targetPoint.Position - Vector3.new(0, ghostDepthOffset, 0)
                        myHrp.CFrame = CFrame.new(desiredPos)
                        myHrp.AssemblyLinearVelocity = Vector3.zero
                        myHrp.AssemblyAngularVelocity = Vector3.zero
                    end

                    task.wait(ghostRepairPulseInterval)
                end

                if currentGhostGenPoint == targetPoint then
                    pcall(function()
                        remotes.Generator.RepairEvent:FireServer(targetPoint, false, nil, requestId, myChar)
                    end)
                    currentGhostGenPoint = nil
                    currentGhostGenModel = nil
                end
            end)

            if not iterSuccess then
                task.wait(0.5)
            end
            task.wait(0.2)
        end

        stopGhostRepair()
    end)
end

V_ObjectiveSection:Toggle({
    Title = "Underground Ghost Repair",
    Description = "Repairs generators 7 studs underground, bypassing server distance checks while 100% safe from killer.",
    Default = false,
    Callback = function(v)
        ghostRepairEnabled = v
        if v then
            if ghostRepairEXEnabled then
                ghostRepairEXEnabled = false
                ghostRepairEXSession = ghostRepairEXSession + 1
                if stopGhostRepairEX then pcall(stopGhostRepairEX) end
            end
            ghostOriginalCFrame = nil
            completedGenerators = {}
            startGhostRepairThread()
        else
            ghostRepairSession = ghostRepairSession + 1
            stopGhostRepair()
        end
    end
})

-- ============================================================
-- 4.2 UNDERGROUND REPAIR GENERATOR EX (0.0001s REAL-POS LOCK & PURPLE TARGET)
-- ============================================================
pcall(function()
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ghostEXOriginalCFrame = nil
local ghostEXSteppedConn = nil
local ghostEXHeartbeatConn = nil
local ghostEXHighlight = nil
local ghostEXHighlightModel = nil
local ghostEXRepairRequestId = nil
local ghostEXActiveDepth = nil
local ghostEXTransiting = false
local ghostEXCurrentFloorY = nil
local ghostEXRetryDepthStep = 0

local function clearGhostEXGenMarker()
    if ghostEXHighlight then
        pcall(function() ghostEXHighlight:Destroy() end)
        ghostEXHighlight = nil
    end
    ghostEXHighlightModel = nil
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj.Name == "GhostEXGenHighlight" then
                obj:Destroy()
            end
        end
    end)
end

local function setGhostEXGenMarker(genModel, targetPoint)
    local adorneeObj = (genModel and genModel.Parent) and genModel or targetPoint
    if not adorneeObj or not adorneeObj.Parent then
        clearGhostEXGenMarker()
        return
    end
    local existingGenHl = adorneeObj:FindFirstChild("GenESPHighlight")
    if existingGenHl and existingGenHl:IsA("Highlight") then
        existingGenHl.FillColor = Color3.fromRGB(170, 0, 255)
        existingGenHl.OutlineColor = Color3.fromRGB(235, 150, 255)
    end
    if ghostEXHighlight and ghostEXHighlight.Parent and ghostEXHighlightModel == adorneeObj then
        ghostEXHighlight.FillColor = Color3.fromRGB(170, 0, 255)
        ghostEXHighlight.OutlineColor = Color3.fromRGB(235, 150, 255)
        return
    end
    clearGhostEXGenMarker()
    pcall(function()
        local hl = Instance.new("Highlight")
        hl.Name = "GhostEXGenHighlight"
        hl.FillColor = Color3.fromRGB(170, 0, 255)
        hl.OutlineColor = Color3.fromRGB(235, 150, 255)
        hl.FillTransparency = 0.25
        hl.OutlineTransparency = 0.0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Adornee = adorneeObj
        hl.Parent = adorneeObj
        ghostEXHighlight = hl
        ghostEXHighlightModel = adorneeObj
    end)
end

local function unlockGhostEXMotion(char, hrp, clearAttributes, restoreCollision)
    if hrp and hrp.Anchored then
        pcall(function() hrp.Anchored = false end)
    end
    if char then
        if clearAttributes then
            pcall(function()
                if char:GetAttribute("Immobile") == true then char:SetAttribute("Immobile", false) end
                if char:GetAttribute("AC_ServerAnchor") ~= nil then char:SetAttribute("AC_ServerAnchor", nil) end
                if char:GetAttribute("Rooted") == true then char:SetAttribute("Rooted", false) end
            end)
        end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                if restoreCollision then
                    if part.Name == "HumanoidRootPart" or part.Name == "Torso" or part.Name == "UpperTorso" or part.Name == "LowerTorso" then
                        part.CanCollide = true
                    end
                elseif part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end
end


local function isGenSlotBusy(pt, myChar)
    if not pt or not pt.Parent then return true end
    if CollectionService and (CollectionService:HasTag(pt, "Occupied") or CollectionService:HasTag(pt, "Blocked")) then
        return true
    end
    if pt:GetAttribute("Occupied") == true or pt:GetAttribute("InUse") == true then
        return true
    end
    local slotPrompt = pt:FindFirstChildOfClass("ProximityPrompt")
    if slotPrompt and not slotPrompt.Enabled then
        return true
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and plr.Character ~= myChar then
            local oHrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if oHrp then
                local dist = (oHrp.Position - pt.Position).Magnitude
                if (dist <= 6.8 and plr.Character:GetAttribute("isRepairing") == true) or dist <= 3.8 then
                    return true
                end
            end
        end
    end
    return false
end

local function findNearestGeneratorSlotsEX(excludeModel)
    local myChar = player.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local myPos = myHrp and myHrp.Position or Vector3.new(0, 0, 0)
    local killer = getKiller and getKiller()
    local kHrp = killer and killer:FindFirstChild("HumanoidRootPart")
    local kPos = kHrp and kHrp.Position or nil
    local genBuckets = {}
    local seenPoints = {}

    local function addPoint(pt)
        if pt and pt:IsA("BasePart") and pt:IsDescendantOf(workspace) and not (myChar and pt:IsDescendantOf(myChar)) then
            if pt:FindFirstAncestor("Lobby") or seenPoints[pt] then return end
            seenPoints[pt] = true
            local genModel = getGeneratorModel(pt) or pt.Parent
            if genModel and genModel:IsDescendantOf(workspace) then
                local isCompleted, prog = isGeneratorCompleted(pt)
                if not isCompleted and (prog or 0) < 99.5 then
                    local bucket = genBuckets[genModel]
                    local myD = (myPos - pt.Position).Magnitude
                    local kD = kPos and (kPos - pt.Position).Magnitude or math.huge
                    if not bucket then
                        bucket = {
                            model = genModel,
                            progress = prog or 0,
                            dist = myD,
                            killerDist = kD,
                            points = {}
                        }
                        genBuckets[genModel] = bucket
                    else
                        if myD < bucket.dist then
                            bucket.dist = myD
                        end
                        if kD < bucket.killerDist then
                            bucket.killerDist = kD
                        end
                    end
                    table.insert(bucket.points, pt)
                end
            end
        end
    end

    pcall(function()
        for _, pt in ipairs(CollectionService:GetTagged("GeneratorPoint")) do
            addPoint(pt)
        end
    end)

    pcall(function()
        local map = workspace:FindFirstChild("Map") or workspace:FindFirstChild("map")
        local mapGens = map and (map:FindFirstChild("Generators") or map:FindFirstChild("new Generators") or map:FindFirstChild("generators"))
        if mapGens then
            for _, gen in ipairs(mapGens:GetChildren()) do
                for _, desc in ipairs(gen:GetDescendants()) do
                    if desc:IsA("BasePart") and (desc.Name:find("GeneratorPoint") or desc.Name == "RepairPoint") then
                        addPoint(desc)
                    end
                end
            end
        end
    end)

    if not next(genBuckets) then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and (obj.Name == "RepairPoint" or obj.Name == "GeneratorPoint") then
                addPoint(obj)
            end
        end
    end

    local candidates = {}
    for _, bucket in pairs(genBuckets) do
        -- Prefer unoccupied slots first within this generator
        table.sort(bucket.points, function(a, b)
            local busyA = isGenSlotBusy(a, myChar) and 1 or 0
            local busyB = isGenSlotBusy(b, myChar) and 1 or 0
            if busyA ~= busyB then
                return busyA < busyB
            end
            if kPos then
                return (kPos - a.Position).Magnitude > (kPos - b.Position).Magnitude
            end
            return (myPos - a.Position).Magnitude < (myPos - b.Position).Magnitude
        end)
        table.insert(candidates, bucket)
    end

    if #candidates == 0 then return nil, nil, nil end

    if excludeModel and #candidates > 1 then
        local filtered = {}
        for _, c in ipairs(candidates) do
            if c.model ~= excludeModel then
                table.insert(filtered, c)
            end
        end
        if #filtered > 0 then
            candidates = filtered
        end
    end

    if kPos then
        -- Always choose generator furthest away from Killer (break very close ties by higher progress / closer distance)
        table.sort(candidates, function(a, b)
            if math.abs(a.killerDist - b.killerDist) > 10 then
                return a.killerDist > b.killerDist
            end
            if math.abs(a.progress - b.progress) > 2 then
                return a.progress > b.progress
            end
            return a.dist < b.dist
        end)
    else
        table.sort(candidates, function(a, b)
            return a.dist < b.dist
        end)
    end
    return candidates[1].points[1], candidates[1].model, candidates[1].points, false
end

stopGhostRepairEX = function()
    vdESPState.ghostEXPaused = false
    ghostEXTransiting = false
    if ghostEXSteppedConn then
        pcall(function() ghostEXSteppedConn:Disconnect() end)
        ghostEXSteppedConn = nil
    end
    if ghostEXHeartbeatConn then
        pcall(function() ghostEXHeartbeatConn:Disconnect() end)
        ghostEXHeartbeatConn = nil
    end
    pcall(function()
        local remotes = getVDRemotes()
        if currentGhostEXPoint and remotes.Generator and remotes.Generator:FindFirstChild("RepairEvent") then
            local reqId = ghostEXRepairRequestId or HttpService:GenerateGUID(false)
            remotes.Generator.RepairEvent:FireServer(currentGhostEXPoint, false, nil, reqId, player.Character)
        end
    end)
    clearGhostEXGenMarker()
    pcall(function()
        local myChar = player.Character
        local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if ghostAutoReturn and ghostEXOriginalCFrame and myHrp then
            if vdESPState.microTransitTo then
                vdESPState.microTransitTo(myChar, myHrp, ghostEXOriginalCFrame.Position, nil, false)
            end
            myHrp.Anchored = false
            myHrp.CFrame = ghostEXOriginalCFrame
            myHrp.AssemblyLinearVelocity = Vector3.zero
            myHrp.AssemblyAngularVelocity = Vector3.zero
        end
    end)
    ghostEXOriginalCFrame = nil
    ghostEXRepairRequestId = nil
    ghostEXHoldPos = nil
    ghostEXActiveDepth = nil
    ghostEXCurrentFloorY = nil
    ghostEXRetryDepthStep = 0
    currentGhostEXPoint = nil
    currentGhostEXModel = nil
    pcall(function()
        if player.Character then
            player.Character:SetAttribute("isRepairing", false)
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            if hrp and CollectionService then
                pcall(function() CollectionService:RemoveTag(hrp, "doing action") end)
            end
            for _, part in ipairs(player.Character:GetDescendants()) do
                if part:IsA("BasePart") and (part.Name == "HumanoidRootPart" or part.Name == "Torso" or part.Name == "UpperTorso" or part.Name == "LowerTorso" or part.Name == "Head") then
                    part.CanCollide = true
                end
            end
            if vdESPState.setMovementBypass then
                vdESPState.setMovementBypass(player.Character, false)
            end
        end
    end)
    unlockCameraAndMovement()
end

local function startGhostRepairEXThread()
    ghostRepairEXSession = ghostRepairEXSession + 1
    local thisSession = ghostRepairEXSession
    vdESPState.ghostEXPaused = false
    ghostEXTransiting = false
    ghostEXRetryDepthStep = 0

    local function checkEXActive()
        return ghostRepairEXEnabled and (ghostRepairEXSession == thisSession) and scriptRunning
    end

    local initialChar = player.Character
    local initialHrp = initialChar and initialChar:FindFirstChild("HumanoidRootPart")
    if not ghostEXOriginalCFrame and initialHrp then
        ghostEXOriginalCFrame = initialHrp.CFrame
    end

    local function computeTrueUndergroundGenPos(pt, genModel)
        local sliderDepth = math.clamp(tonumber(ghostEXActiveDepth or ghostDepthOffset) or 7.0, 5.2, 8.2)
        local depthSteps = { math.clamp(sliderDepth, 5.6, 7.6), 6.4, 5.8 }
        local desiredBelowPt = depthSteps[(ghostEXRetryDepthStep % 3) + 1] or 7.0
        if vdESPState.computeGenUndergroundPoint then
            local pos, fy = vdESPState.computeGenUndergroundPoint(pt, genModel, desiredBelowPt, ghostEXCurrentFloorY)
            if fy and not ghostEXCurrentFloorY then
                ghostEXCurrentFloorY = fy
            end
            return pos
        end
        return Vector3.new(pt.Position.X, pt.Position.Y - math.clamp(desiredBelowPt, 5.6, 7.6), pt.Position.Z)
    end

    local function enforceEXUndergroundPos(maxDistTolerance)
        if ghostEXTransiting or vdESPState.ghostEXPaused then return false end
        local c = player.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        local pt = currentGhostEXPoint
        if not hrp or not hum or hum.Health <= 0 then
            return false
        end
        if isCharacterHooked(c) or isCharacterKnocked(c) or (vdESPState.isLocalCaptured and vdESPState.isLocalCaptured(c)) then
            return false
        end

        local desiredPos = (pt and pt.Parent) and computeTrueUndergroundGenPos(pt, currentGhostEXModel) or ghostEXHoldPos
        if not desiredPos then
            return false
        end
        ghostEXHoldPos = desiredPos

        if hrp.Anchored or c:GetAttribute("AC_ServerAnchor") ~= nil then
            vdESPState.lastServerAnchorTick = tick()
            if c:GetAttribute("AC_ServerAnchor") ~= nil then
                vdESPState.lastACAnchorTick = tick()
            end
        end

        local horizDrift = Vector3.new(hrp.Position.X - desiredPos.X, 0, hrp.Position.Z - desiredPos.Z).Magnitude
        local recentAnchor = (tick() - math.max(vdESPState.lastServerAnchorTick or 0, vdESPState.lastACAnchorTick or 0)) < 1.2
        if horizDrift > 10.5 and recentAnchor then
            -- Never fake-teleport Client POV while server rejected/anchored real body elsewhere
            ghostEXHoldPos = nil
            return false
        end

        if vdESPState.setMovementBypass then
            vdESPState.setMovementBypass(c, true)
        end

        local tol = maxDistTolerance or 0.25
        local realDist = (hrp.Position - desiredPos).Magnitude
        if hrp.CanCollide then
            unlockGhostEXMotion(c, hrp, false, false)
        end
        if realDist > tol or hrp.Anchored then
            unlockGhostEXMotion(c, hrp, true, false)
            hrp.CFrame = CFrame.new(desiredPos)
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            return false
        end
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        return true
    end

    if ghostEXSteppedConn then
        pcall(function() ghostEXSteppedConn:Disconnect() end)
        ghostEXSteppedConn = nil
    end
    if ghostEXHeartbeatConn then
        pcall(function() ghostEXHeartbeatConn:Disconnect() end)
        ghostEXHeartbeatConn = nil
    end

    local function isPosYieldedByOtherFeature()
        if not vdESPState then return false end
        if vdESPState.fleeKnockEXEnabled and vdESPState.fleeKnockEXBlocking then return true end
        if vdESPState.autoFleeEnabled and vdESPState.autoFleeBlocking then return true end
        if vdESPState.rescueEXEnabled and (vdESPState.rescueEXWantsPriority or (not vdESPState.rescueEXPaused and vdESPState.rescueEXHoldPos ~= nil)) then
            return true
        end
        if vdESPState.autoLeverEXEnabled and (vdESPState.autoLeverEXWantsPriority or (not vdESPState.autoLeverEXPaused and vdESPState.autoLeverEXHoldPos ~= nil)) then
            return true
        end
        return false
    end

    -- 1a. Pre-simulation Stepped physics override + NoClip bypass (guarantees Killer POV sees underground)
    ghostEXSteppedConn = RunService.Stepped:Connect(function()
        if not checkEXActive() then
            if ghostEXSteppedConn then
                pcall(function() ghostEXSteppedConn:Disconnect() end)
                ghostEXSteppedConn = nil
            end
            return
        end
        if not isPosYieldedByOtherFeature() then
            pcall(function()
                enforceEXUndergroundPos(0.25)
            end)
        end
    end)

    -- 1b. Post-simulation Heartbeat underground tether
    ghostEXHeartbeatConn = RunService.Heartbeat:Connect(function()
        if not checkEXActive() then
            if ghostEXHeartbeatConn then
                pcall(function() ghostEXHeartbeatConn:Disconnect() end)
                ghostEXHeartbeatConn = nil
            end
            return
        end
        if not isPosYieldedByOtherFeature() then
            pcall(function()
                enforceEXUndergroundPos(0.25)
            end)
        end
    end)

    -- 2. Ultra-fast 0.0001s Real-Position Checker & Spam Teleport Loop
    task.spawn(function()
        while checkEXActive() do
            if not isPosYieldedByOtherFeature() then
                pcall(function()
                    enforceEXUndergroundPos(0.25)
                end)
            end
            task.wait(0.0001)
        end
    end)

    -- 3. Main EX Generator Lock, Purple Marker & Repair Thread
    task.spawn(function()
        local trackedEXChar = nil
        local currentGenSlots = nil
        local currentSlotIdx = 1
        local repairFailCount = 0
        local teleportFailCount = 0

        local function isYieldingHoldOnly()
            if not vdESPState then return false end
            return (vdESPState.fleeKnockEXEnabled and vdESPState.fleeKnockEXBlocking)
                or (vdESPState.autoFleeEnabled and (vdESPState.autoFleeBlocking or vdESPState.autoFleeHoldPos ~= nil))
                or (vdESPState.rescueEXEnabled and (vdESPState.rescueEXWantsPriority or (not vdESPState.rescueEXPaused and vdESPState.rescueEXHoldPos ~= nil)))
                or (vdESPState.autoLeverEXEnabled and (vdESPState.autoLeverEXWantsPriority or (not vdESPState.autoLeverEXPaused and vdESPState.autoLeverEXHoldPos ~= nil)))
        end

        local function isBlockedByStandaloneAutoFlee(pt, myHrpRef, extraMargin)
            if isYieldingHoldOnly() then return true end
            if not vdESPState then return false end
            if vdESPState.autoFleeEnabled and vdESPState.autoFleePauseUntil and tick() < vdESPState.autoFleePauseUntil then
                return true
            end
            local safeDist = (tonumber(vdESPState.autoFleeDistance) or 100) + (extraMargin or 0)
            local killer = getKiller and getKiller()
            local kHrp = killer and killer:FindFirstChild("HumanoidRootPart")
            if kHrp then
                if pt and pt.Parent and (kHrp.Position - pt.Position).Magnitude <= safeDist then
                    return true
                end
                if myHrpRef and myHrpRef.Parent and (kHrp.Position - myHrpRef.Position).Magnitude <= (tonumber(vdESPState.autoFleeDistance) or 100) then
                    return true
                end
            end
            return false
        end

        while checkEXActive() do
            local iterOk = pcall(function()
                local myChar = player.Character
                if not myChar or not myChar:IsDescendantOf(workspace) then
                    ghostEXTransiting = true
                    currentGhostEXPoint = nil
                    currentGhostEXModel = nil
                    currentGenSlots = nil
                    ghostEXHoldPos = nil
                    ghostEXActiveDepth = nil
                    ghostEXCurrentFloorY = nil
                    repairFailCount = 0
                    teleportFailCount = 0
                    clearGhostEXGenMarker()
                    task.wait(0.2)
                    return
                end

                if trackedEXChar ~= myChar then
                    trackedEXChar = myChar
                    ghostEXTransiting = false
                    vdESPState.ghostEXPaused = false
                    ghostEXOriginalCFrame = nil
                    ghostEXHoldPos = nil
                    ghostEXActiveDepth = nil
                    ghostEXCurrentFloorY = nil
                    ghostEXRetryDepthStep = 0
                    repairFailCount = 0
                    teleportFailCount = 0
                    currentGhostEXPoint = nil
                    currentGhostEXModel = nil
                    currentGenSlots = nil
                    currentSlotIdx = 1
                    ghostEXRepairRequestId = nil
                    clearGhostEXGenMarker()
                end

                local hum = myChar:FindFirstChildOfClass("Humanoid")
                local myHrp = myChar:FindFirstChild("HumanoidRootPart")
                if not myHrp or not hum or hum.Health <= 0 then
                    ghostEXTransiting = true
                    ghostEXHoldPos = nil
                    ghostEXActiveDepth = nil
                    ghostEXCurrentFloorY = nil
                    currentGhostEXPoint = nil
                    currentGhostEXModel = nil
                    currentGenSlots = nil
                    repairFailCount = 0
                    teleportFailCount = 0
                    clearGhostEXGenMarker()
                    task.wait(0.2)
                    return
                end

                if isCharacterHooked(myChar) or isCharacterKnocked(myChar) or (vdESPState.isLocalCaptured and vdESPState.isLocalCaptured(myChar)) then
                    ghostEXTransiting = true
                    ghostEXHoldPos = nil
                    ghostEXActiveDepth = nil
                    ghostEXCurrentFloorY = nil
                    currentGhostEXPoint = nil
                    currentGhostEXModel = nil
                    currentGenSlots = nil
                    clearGhostEXGenMarker()
                    unlockGhostEXMotion(myChar, myHrp, false, true)
                    if vdESPState.setMovementBypass then
                        vdESPState.setMovementBypass(myChar, false)
                    end
                    task.wait(0.2)
                    return
                end

                if not ghostEXOriginalCFrame then
                    ghostEXOriginalCFrame = myHrp.CFrame
                end

                -- Pick nearest unfinished generator only when not already locked onto one
                if not currentGhostEXPoint or not currentGhostEXPoint.Parent or isGeneratorCompleted(currentGhostEXPoint) then
                    ghostEXActiveDepth = nil
                    ghostEXCurrentFloorY = nil
                    ghostEXRetryDepthStep = 0
                    repairFailCount = 0
                    local nextPt, nextModel, nextSlots = findNearestGeneratorSlotsEX()
                    if not nextPt or not nextModel then
                        ghostEXTransiting = false
                        clearGhostEXGenMarker()
                        currentGhostEXPoint = nil
                        currentGhostEXModel = nil
                        currentGenSlots = nil
                        ghostEXHoldPos = nil
                        WindUI:Notify({ Title = "⚡ Ghost Gen EX", Content = "All generators 100% completed!", Duration = 3 })
                        if ghostAutoReturn and ghostEXOriginalCFrame and myHrp then
                            if vdESPState.microTransitTo then
                                vdESPState.microTransitTo(myChar, myHrp, ghostEXOriginalCFrame.Position, checkEXActive, false)
                            end
                            unlockGhostEXMotion(myChar, myHrp, true, true)
                            myHrp.CFrame = ghostEXOriginalCFrame
                            myHrp.AssemblyLinearVelocity = Vector3.zero
                            myHrp.AssemblyAngularVelocity = Vector3.zero
                            ghostEXOriginalCFrame = nil
                        else
                            unlockGhostEXMotion(myChar, myHrp, true, true)
                        end
                        if vdESPState.setMovementBypass then
                            vdESPState.setMovementBypass(myChar, false)
                        end
                        task.wait(2.0)
                        return
                    end

                    if isBlockedByStandaloneAutoFlee(nextPt, myHrp, 6) then
                        ghostEXTransiting = false
                        ghostEXHoldPos = nil
                        currentGhostEXPoint = nil
                        currentGhostEXModel = nil
                        currentGenSlots = nil
                        clearGhostEXGenMarker()
                        if not isYieldingHoldOnly() then
                            unlockGhostEXMotion(myChar, myHrp, false, true)
                        end
                        task.wait(0.10)
                        return
                    end

                    -- Compute floor-buried underground destination & micro-transit BEFORE turning on position lock
                    ghostEXTransiting = true
                    currentGhostEXPoint = nil
                    ghostEXHoldPos = nil
                    ghostEXCurrentFloorY = vdESPState.findFloorYBelow and vdESPState.findFloorYBelow(nextPt.Position.X, nextPt.Position.Y, nextPt.Position.Z, nextModel) or nil
                    local initDestPos = computeTrueUndergroundGenPos(nextPt, nextModel)

                    local arrived = true
                    if vdESPState.microTransitTo then
                        arrived = vdESPState.microTransitTo(myChar, myHrp, initDestPos, function()
                            return checkEXActive()
                                and nextPt.Parent
                                and not isBlockedByStandaloneAutoFlee(nextPt, myHrp)
                                and not isCharacterKnocked(myChar)
                                and not isCharacterHooked(myChar)
                                and not (vdESPState.isLocalCaptured and vdESPState.isLocalCaptured(myChar))
                        end, true, 6.5)
                    end
                    if not checkEXActive() or not nextPt.Parent or isBlockedByStandaloneAutoFlee(nextPt, myHrp) or isCharacterKnocked(myChar) or isCharacterHooked(myChar) or (vdESPState.isLocalCaptured and vdESPState.isLocalCaptured(myChar)) then
                        ghostEXTransiting = false
                        return
                    end
                    if not arrived or (myHrp.Position - initDestPos).Magnitude > 6.5 then
                        ghostEXTransiting = false
                        ghostEXHoldPos = nil
                        teleportFailCount = teleportFailCount + 1
                        unlockGhostEXMotion(myChar, myHrp, true, not isYieldingHoldOnly())
                        if vdESPState.setMovementBypass then
                            vdESPState.setMovementBypass(myChar, false)
                        end
                        if teleportFailCount >= 2 then
                            vdESPState.ghostEXPaused = true
                            local pauseEnd = tick() + 2.0
                            while tick() < pauseEnd and checkEXActive() and not isCharacterKnocked(myChar) and not isCharacterHooked(myChar) and not (vdESPState.isLocalCaptured and vdESPState.isLocalCaptured(myChar)) do
                                task.wait(0.05)
                            end
                            teleportFailCount = 0
                            ghostEXRetryDepthStep = 0
                            vdESPState.ghostEXPaused = false
                        else
                            ghostEXRetryDepthStep = (ghostEXRetryDepthStep + 1) % 3
                            task.wait(0.12)
                        end
                        return
                    end

                    teleportFailCount = 0
                    currentGhostEXPoint = nextPt
                    currentGhostEXModel = nextModel
                    currentGenSlots = nextSlots or { nextPt }
                    currentSlotIdx = 1
                    ghostEXHoldPos = initDestPos
                    ghostEXTransiting = false
                end

                if isBlockedByStandaloneAutoFlee(currentGhostEXPoint, myHrp) then
                    local oldModel = currentGhostEXModel
                    ghostEXHoldPos = nil
                    currentGhostEXPoint = nil
                    currentGhostEXModel = nil
                    currentGenSlots = nil
                    clearGhostEXGenMarker()
                    if not isYieldingHoldOnly() then
                        local altPt = findNearestGeneratorSlotsEX(oldModel)
                        local safeRange = tonumber(vdESPState and vdESPState.autoFleeDistance) or 100
                        local kNow = getKiller and getKiller()
                        local kHrpNow = kNow and kNow:FindFirstChild("HumanoidRootPart")
                        if altPt and (not kHrpNow or (altPt.Position - kHrpNow.Position).Magnitude > safeRange + 5) then
                            unlockGhostEXMotion(myChar, myHrp, true, false)
                            return
                        end
                        unlockGhostEXMotion(myChar, myHrp, false, true)
                    end
                    task.wait(0.08)
                    return
                end

                local targetPoint = currentGhostEXPoint
                local genModel = currentGhostEXModel
                setGhostEXGenMarker(genModel, targetPoint)

                local remotes = getVDRemotes()
                if not remotes.Generator or not remotes.Generator:FindFirstChild("RepairEvent") then
                    task.wait(0.5)
                    return
                end

                local genName = (genModel and genModel.Name) or "Generator"
                local _, currentProg = isGeneratorCompleted(targetPoint)
                WindUI:Notify({
                    Title = "🟣 Ghost Gen EX",
                    Content = string.format("Locked onto safest %s [%.0f%%] (Purple Marker)", genName, currentProg or 0),
                    Duration = 2
                })

                -- Wait underground until real position matches AND server position replication settles (~0.12s)
                local function settleUndergroundForServer(pt)
                    ghostEXCurrentFloorY = vdESPState.findFloorYBelow and vdESPState.findFloorYBelow(pt.Position.X, pt.Position.Y, pt.Position.Z, genModel) or ghostEXCurrentFloorY
                    local dPos = computeTrueUndergroundGenPos(pt, genModel)
                    ghostEXHoldPos = dPos
                    local okTransit = true
                    if myHrp and (myHrp.Position - dPos).Magnitude > 6.5 and vdESPState.microTransitTo then
                        ghostEXTransiting = true
                        okTransit = vdESPState.microTransitTo(myChar, myHrp, dPos, function()
                            return checkEXActive()
                                and pt.Parent
                                and not isBlockedByStandaloneAutoFlee(pt, myHrp)
                                and not isCharacterKnocked(myChar)
                                and not isCharacterHooked(myChar)
                                and not (vdESPState.isLocalCaptured and vdESPState.isLocalCaptured(myChar))
                        end, true, 6.5)
                        ghostEXTransiting = false
                    else
                        for _ = 1, 15 do
                            if not checkEXActive() or not pt.Parent then break end
                            if enforceEXUndergroundPos(0.25) then break end
                            task.wait(0.0001)
                        end
                    end
                    if not okTransit or not checkEXActive() or not pt.Parent or not myHrp or myHrp.Anchored or myChar:GetAttribute("AC_ServerAnchor") ~= nil or (myHrp.Position - dPos).Magnitude > 6.5 then
                        return false
                    end
                    -- Hold pinned underground for 0.14s so server receives updated CFrame BEFORE RepairEvent fires
                    local settleEnd = tick() + 0.14
                    while tick() < settleEnd and checkEXActive() and pt.Parent do
                        enforceEXUndergroundPos(0.20)
                        task.wait(0.0001)
                    end
                    return myHrp and not myHrp.Anchored and (myHrp.Position - dPos).Magnitude <= 6.5
                end

                local function beginEXRepairOnSlot(pt, curReqId)
                    if CollectionService then
                        if myHrp then pcall(function() CollectionService:RemoveTag(myHrp, "doing action") end) end
                        if myChar then pcall(function() CollectionService:RemoveTag(myChar, "doing action") end) end
                    end
                    local actualModel = resolveGeneratorInstance(pt, genModel)
                    lastCapturedGenModel = actualModel
                    lastCapturedGenPoint = pt
                    lastCapturedRepairRequestId = curReqId

                    pcall(function()
                        remotes.Generator.RepairEvent:FireServer(pt, true, nil, curReqId, myChar)
                        myChar:SetAttribute("isRepairing", true)
                    end)
                    return actualModel
                end

                if not settleUndergroundForServer(targetPoint) then
                    if not checkEXActive() or not targetPoint.Parent then return end
                    teleportFailCount = teleportFailCount + 1
                    ghostEXHoldPos = nil
                    unlockGhostEXMotion(myChar, myHrp, true, not isYieldingHoldOnly())
                    if vdESPState.setMovementBypass then
                        vdESPState.setMovementBypass(myChar, false)
                    end
                    if teleportFailCount >= 2 then
                        vdESPState.ghostEXPaused = true
                        local pauseEnd = tick() + 2.0
                        while tick() < pauseEnd and checkEXActive() and not isCharacterHooked(myChar) and not isCharacterKnocked(myChar) and not (vdESPState.isLocalCaptured and vdESPState.isLocalCaptured(myChar)) do
                            task.wait(0.05)
                        end
                        teleportFailCount = 0
                        ghostEXRetryDepthStep = 0
                        vdESPState.ghostEXPaused = false
                    else
                        ghostEXRetryDepthStep = (ghostEXRetryDepthStep + 1) % 3
                        task.wait(0.12)
                    end
                    return
                end
                teleportFailCount = 0
                if not checkEXActive() or not targetPoint.Parent or isBlockedByStandaloneAutoFlee(targetPoint, myHrp) then return end

                local requestId = HttpService:GenerateGUID(false)
                ghostEXRepairRequestId = requestId
                local actualGenModel = beginEXRepairOnSlot(targetPoint, requestId)

                local lastPulseSent = 0
                local lastObservedProg = currentProg or 0
                local lastProgressTime = tick()

                -- Stay STRICTLY locked on current generator until 100% done
                while checkEXActive() and currentGhostEXPoint == targetPoint and targetPoint.Parent do
                    if isCharacterHooked(myChar) or isCharacterKnocked(myChar) or (vdESPState.isLocalCaptured and vdESPState.isLocalCaptured(myChar)) then
                        break
                    end

                    if isBlockedByStandaloneAutoFlee(targetPoint, myHrp) then
                        pcall(function()
                            remotes.Generator.RepairEvent:FireServer(targetPoint, false, nil, requestId, myChar)
                            if myHrp then CollectionService:RemoveTag(myHrp, "doing action") end
                            CollectionService:RemoveTag(myChar, "doing action")
                        end)
                        myChar:SetAttribute("isRepairing", false)
                        clearGhostEXGenMarker()
                        currentGhostEXPoint = nil
                        currentGhostEXModel = nil
                        currentGenSlots = nil
                        ghostEXHoldPos = nil
                        if not isYieldingHoldOnly() then
                            local altPt = findNearestGeneratorSlotsEX(genModel)
                            local safeRange = tonumber(vdESPState and vdESPState.autoFleeDistance) or 100
                            local kNow = getKiller and getKiller()
                            local kHrpNow = kNow and kNow:FindFirstChild("HumanoidRootPart")
                            local hasSafeAlt = altPt and (not kHrpNow or (altPt.Position - kHrpNow.Position).Magnitude > safeRange + 5)
                            unlockGhostEXMotion(myChar, myHrp, true, not hasSafeAlt)
                            if hasSafeAlt then
                                task.wait(0.05)
                            end
                        end
                        break
                    end

                    -- Condition 1: Generator Completed
                    local doneNow, progNow = isGeneratorCompleted(targetPoint)
                    progNow = progNow or 0
                    if doneNow or progNow >= 99.5 then
                        ghostEXTransiting = true
                        completedGenerators[targetPoint] = true
                        if genModel then completedGenerators[genModel] = true end
                        if actualGenModel then completedGenerators[actualGenModel] = true end
                        if currentGenSlots then
                            for _, sp in ipairs(currentGenSlots) do
                                completedGenerators[sp] = true
                            end
                        end
                        pcall(function()
                            remotes.Generator.RepairEvent:FireServer(targetPoint, false, nil, requestId, myChar)
                        end)
                        myChar:SetAttribute("isRepairing", false)
                        clearGhostEXGenMarker()
                        currentGhostEXPoint = nil
                        currentGhostEXModel = nil
                        currentGenSlots = nil
                        ghostEXHoldPos = nil
                        ghostEXRepairRequestId = nil
                        ghostEXActiveDepth = nil
                        ghostEXCurrentFloorY = nil
                        ghostEXRetryDepthStep = 0
                        repairFailCount = 0
                        teleportFailCount = 0
                        WindUI:Notify({ Title = "🟣 Ghost Gen EX", Content = "✅ " .. genName .. " Fixed 100%! Picking next nearest...", Duration = 2 })
                        task.wait(0.08)
                        break
                    end

                    -- Watchdog & 2-Fail -> 2s Cooldown Pause System
                    if progNow > (lastObservedProg + 0.01) then
                        lastObservedProg = progNow
                        lastProgressTime = tick()
                        repairFailCount = 0
                    elseif (tick() - lastProgressTime) >= 4.8 then
                        repairFailCount = repairFailCount + 1
                        pcall(function()
                            remotes.Generator.RepairEvent:FireServer(targetPoint, false, nil, requestId, myChar)
                        end)
                        myChar:SetAttribute("isRepairing", false)
                        task.wait(0.05)
                        if not checkEXActive() or currentGhostEXPoint ~= targetPoint or not targetPoint.Parent then break end

                        if repairFailCount >= 2 then
                            -- Turn off underground teleport & repair for 2 seconds after 2 failed repair attempts, then retry
                            vdESPState.ghostEXPaused = true
                            ghostEXHoldPos = nil
                            unlockGhostEXMotion(myChar, myHrp, true, true)
                            if vdESPState.setMovementBypass then
                                vdESPState.setMovementBypass(myChar, false)
                            end
                            local pauseEnd = tick() + 2.0
                            while tick() < pauseEnd and checkEXActive() and not isCharacterHooked(myChar) and not isCharacterKnocked(myChar) and not (vdESPState.isLocalCaptured and vdESPState.isLocalCaptured(myChar)) do
                                task.wait(0.05)
                            end
                            repairFailCount = 0
                            ghostEXRetryDepthStep = 0
                            ghostEXActiveDepth = nil
                            vdESPState.ghostEXPaused = false
                            if not checkEXActive() or currentGhostEXPoint ~= targetPoint or not targetPoint.Parent or isGeneratorCompleted(targetPoint) then
                                break
                            end
                        else
                            -- Rotate to an unoccupied slot on the SAME locked generator model & step depth margin safely
                            if currentGenSlots and #currentGenSlots > 1 then
                                local chosenSlot = nil
                                for offset = 1, #currentGenSlots do
                                    local tryIdx = ((currentSlotIdx - 1 + offset) % #currentGenSlots) + 1
                                    local candSlot = currentGenSlots[tryIdx]
                                    if candSlot and candSlot.Parent and not isGenSlotBusy(candSlot, myChar) then
                                        currentSlotIdx = tryIdx
                                        chosenSlot = candSlot
                                        break
                                    end
                                end
                                if not chosenSlot then
                                    currentSlotIdx = (currentSlotIdx % #currentGenSlots) + 1
                                    chosenSlot = currentGenSlots[currentSlotIdx]
                                end
                                if chosenSlot and chosenSlot.Parent then
                                    targetPoint = chosenSlot
                                    currentGhostEXPoint = chosenSlot
                                end
                            end
                            ghostEXRetryDepthStep = (ghostEXRetryDepthStep + 1) % 3
                        end

                        if not settleUndergroundForServer(targetPoint) then
                            teleportFailCount = teleportFailCount + 1
                            if teleportFailCount >= 2 then
                                vdESPState.ghostEXPaused = true
                                ghostEXHoldPos = nil
                                unlockGhostEXMotion(myChar, myHrp, true, true)
                                if vdESPState.setMovementBypass then
                                    vdESPState.setMovementBypass(myChar, false)
                                end
                                local pauseEnd = tick() + 2.0
                                while tick() < pauseEnd and checkEXActive() and not isCharacterHooked(myChar) and not isCharacterKnocked(myChar) and not (vdESPState.isLocalCaptured and vdESPState.isLocalCaptured(myChar)) do
                                    task.wait(0.05)
                                end
                                teleportFailCount = 0
                                vdESPState.ghostEXPaused = false
                            end
                            break
                        end
                        teleportFailCount = 0
                        requestId = HttpService:GenerateGUID(false)
                        ghostEXRepairRequestId = requestId
                        actualGenModel = beginEXRepairOnSlot(targetPoint, requestId)
                        lastProgressTime = tick()
                        lastPulseSent = 0
                    end

                    -- Maintain purple highlight & fire periodic repair + Great skillcheck progression pulses
                    if not checkEXActive() or isBlockedByStandaloneAutoFlee(targetPoint, myHrp) then
                        pcall(function()
                            remotes.Generator.RepairEvent:FireServer(targetPoint, false, nil, requestId, myChar)
                            if myHrp then CollectionService:RemoveTag(myHrp, "doing action") end
                            CollectionService:RemoveTag(myChar, "doing action")
                        end)
                        myChar:SetAttribute("isRepairing", false)
                        clearGhostEXGenMarker()
                        currentGhostEXPoint = nil
                        currentGhostEXModel = nil
                        currentGenSlots = nil
                        ghostEXHoldPos = nil
                        if not isYieldingHoldOnly() then
                            local altPt = findNearestGeneratorSlotsEX(genModel)
                            local safeRange = tonumber(vdESPState and vdESPState.autoFleeDistance) or 100
                            local kNow = getKiller and getKiller()
                            local kHrpNow = kNow and kNow:FindFirstChild("HumanoidRootPart")
                            local hasSafeAlt = altPt and (not kHrpNow or (altPt.Position - kHrpNow.Position).Magnitude > safeRange + 5)
                            unlockGhostEXMotion(myChar, myHrp, true, not hasSafeAlt)
                            if hasSafeAlt then
                                task.wait(0.05)
                            end
                        end
                        break
                    end
                    setGhostEXGenMarker(genModel, targetPoint)
                    if (tick() - lastPulseSent) >= ghostRepairPulseInterval then
                        lastPulseSent = tick()
                        pcall(function()
                            remotes.Generator.RepairEvent:FireServer(targetPoint, true, nil, requestId, myChar)
                            myChar:SetAttribute("isRepairing", true)
                        end)
                        if remotes.Generator:FindFirstChild("SkillCheckResultEvent") then
                            local sendGenModel = resolveGeneratorInstance(targetPoint, actualGenModel or genModel)
                            pcall(function()
                                remotes.Generator.SkillCheckResultEvent:FireServer(
                                    "success",
                                    1,
                                    sendGenModel,
                                    targetPoint,
                                    requestId,
                                    { player.Name }
                                )
                            end)
                        end
                    end

                    task.wait(0.02)
                end

                if currentGhostEXPoint == targetPoint then
                    pcall(function()
                        remotes.Generator.RepairEvent:FireServer(targetPoint, false, nil, requestId, myChar)
                        myChar:SetAttribute("isRepairing", false)
                    end)
                end
            end)

            if not iterOk then
                task.wait(0.05)
            end
            task.wait(0.0001)
        end

        stopGhostRepairEX()
    end)
end

vdESPState.ghostRepairEXToggle = V_SurvivorEXSection:Toggle({
    Title = "Underground Repair Generator EX",
    Description = "0.0001s floor-buried lock, micro-burst transit, purple target & 2s reset after 2 fails",
    Default = false,
    Callback = function(v)
        ghostRepairEXEnabled = v
        if v then
            if ghostRepairEnabled then
                ghostRepairEnabled = false
                ghostRepairSession = ghostRepairSession + 1
                if stopGhostRepair then pcall(stopGhostRepair) end
            end
            if autoRepairEnabled then
                autoRepairEnabled = false
                repairSession = repairSession + 1
            end
            ghostEXOriginalCFrame = nil
            completedGenerators = {}
            startGhostRepairEXThread()
        else
            ghostRepairEXSession = ghostRepairEXSession + 1
            stopGhostRepairEX()
        end
    end
})
end)

-- ============================================================
-- 4C. AUTO LEVER EX (Priority Underground Exit Gate Opener)
-- ============================================================
pcall(function()
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local CollectionService = game:GetService("CollectionService")
    local HttpService = game:GetService("HttpService")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local localPlayer = Players.LocalPlayer or player

    local autoLeverOrigCFrame = nil
    local autoLeverHoldPos = nil
    local autoLeverPoint = nil
    local autoLeverModel = nil
    local autoLeverFloorY = nil
    local autoLeverRetryStep = 0
    local autoLeverTransiting = false
    local autoLeverSteppedConn = nil
    local autoLeverHeartbeatConn = nil
    local autoLeverAnimConn = nil
    local lastServerLeverConfirm = 0
    local sessionCompletedLevers = {}
    local unreadyLockout = false
    local sawMultiGensLeft = false

    local function checkActive()
        return vdESPState and vdESPState.autoLeverEXEnabled and scriptRunning
    end

    local function clearMarker()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Highlight") and obj.Name == "AutoLeverEXHighlight" then
                pcall(function() obj:Destroy() end)
            end
        end
    end

    local function setMarker(gateModel, targetPart)
        local adornee = (gateModel and gateModel:IsA("Model") and gateModel) or targetPart
        if not adornee or not adornee.Parent then return end
        local hl = adornee:FindFirstChild("AutoLeverEXHighlight")
        if not hl then
            clearMarker()
            hl = Instance.new("Highlight")
            hl.Name = "AutoLeverEXHighlight"
            hl.FillColor = Color3.fromRGB(0, 220, 255)
            hl.OutlineColor = Color3.fromRGB(160, 245, 255)
            hl.FillTransparency = 0.25
            hl.OutlineTransparency = 0
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Adornee = adornee
            hl.Parent = adornee
        end
    end

    local function setLeverCollisionState(char, canCollideVal)
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = canCollideVal
            end
        end
    end

    local function unlockMotion(char, hrp, restoreReturn, restoreCollision)
        autoLeverHoldPos = nil
        if vdESPState then vdESPState.autoLeverEXHoldPos = nil end
        if char then
            char:SetAttribute("isExiting", false)
            if restoreCollision ~= false then
                setLeverCollisionState(char, true)
                if vdESPState and vdESPState.setMovementBypass then
                    vdESPState.setMovementBypass(char, false)
                end
            end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.PlatformStand = false
                if hum.Sit then hum.Sit = false end
            end
        end
        if hrp and hrp.Parent then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            if restoreReturn and autoLeverFloorY and hrp.Position.Y < (autoLeverFloorY - 0.5) then
                hrp.CFrame = CFrame.new(hrp.Position.X, autoLeverFloorY + 3.2, hrp.Position.Z)
            elseif restoreReturn and ghostAutoReturn and autoLeverOrigCFrame then
                hrp.CFrame = autoLeverOrigCFrame
            end
        end
        if restoreReturn then
            autoLeverOrigCFrame = nil
            autoLeverFloorY = nil
        end
    end

    local function isYieldedByOtherFeatures(myChar, leverPt)
        if not myChar or not myChar:IsDescendantOf(workspace) then return true end
        if isEntityInLobbyOrSpectating and isEntityInLobbyOrSpectating(myChar, localPlayer) then return true end
        if isPlayerKiller and isPlayerKiller() then return true end
        if isCharacterHooked and isCharacterHooked(myChar) then return true end
        if isCharacterKnocked and isCharacterKnocked(myChar) then return true end
        if vdESPState then
            if vdESPState.isLocalCaptured and vdESPState.isLocalCaptured(myChar) then return true end
            if vdESPState.fleeKnockEXEnabled and vdESPState.fleeKnockEXBlocking then return true end
            if vdESPState.autoFleeEnabled and vdESPState.autoFleeBlocking then return true end
            if vdESPState.rescueEXEnabled and (vdESPState.rescueEXWantsPriority or (not vdESPState.rescueEXPaused and vdESPState.rescueEXHoldPos ~= nil)) then
                return true
            end
            if vdESPState.autoFleeEnabled and leverPt and leverPt.Parent and getKiller then
                local killer = getKiller()
                local kHrp = killer and killer:FindFirstChild("HumanoidRootPart")
                if kHrp and (kHrp.Position - leverPt.Position).Magnitude <= (vdESPState.autoFleeDistance or 100) then
                    return true
                end
            end
        end
        return false
    end

    local function getFixedGeneratorStatus(myChar)
        local uniqueGens = {}
        local genList = {}
        local function addGen(obj)
            if not obj or not obj.Parent then return end
            if myChar and obj:IsDescendantOf(myChar) then return end
            if obj:FindFirstAncestor("Lobby") then return end
            local repPt = obj
            local genModel = nil
            if obj:IsA("Model") then
                genModel = obj
                repPt = obj:FindFirstChild("RepairPoint") or obj:FindFirstChild("GeneratorPoint") or obj:FindFirstChildWhichIsA("BasePart")
            elseif obj:IsA("BasePart") then
                genModel = (getGeneratorModel and getGeneratorModel(obj)) or obj.Parent
            end
            if not genModel or uniqueGens[genModel] then return end
            uniqueGens[genModel] = true
            table.insert(genList, { model = genModel, point = repPt })
        end

        pcall(function()
            for _, pt in ipairs(CollectionService:GetTagged("GeneratorPoint")) do
                addGen(pt)
            end
        end)

        local map = workspace:FindFirstChild("Map") or workspace:FindFirstChild("map")
        if map then
            for _, folderName in ipairs({ "Generators", "new Generators", "generators" }) do
                local f = map:FindFirstChild(folderName)
                if f then
                    for _, child in ipairs(f:GetChildren()) do
                        addGen(child)
                    end
                end
            end
        end

        if #genList == 0 then
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and (obj.Name == "RepairPoint" or obj.Name == "GeneratorPoint") then
                    addGen(obj)
                end
            end
        end

        local fixed = 0
        for _, g in ipairs(genList) do
            local done = false
            if g.point and isGeneratorCompleted then
                local okDone = isGeneratorCompleted(g.point)
                if okDone then done = true end
            end
            if not done and g.model then
                if CollectionService:HasTag(g.model, "Blocked") or CollectionService:HasTag(g.model, "Repaired") or CollectionService:HasTag(g.model, "Completed") then
                    done = true
                elseif tonumber(g.model:GetAttribute("RepairProgress") or g.model:GetAttribute("Progress") or 0) >= 99.5 then
                    done = true
                elseif g.model:GetAttribute("Completed") == true or g.model:GetAttribute("Repaired") == true or g.model:GetAttribute("Fixed") == true then
                    done = true
                end
            end
            if done then fixed = fixed + 1 end
        end

        local remAttr = workspace:GetAttribute("GeneratorsLeft")
            or workspace:GetAttribute("GensLeft")
            or workspace:GetAttribute("GeneratorsRemaining")
            or ReplicatedStorage:GetAttribute("GeneratorsLeft")
            or ReplicatedStorage:GetAttribute("GensLeft")
        if remAttr ~= nil and tonumber(remAttr) then
            local rNum = tonumber(remAttr)
            if rNum >= 2 then
                sawMultiGensLeft = true
            elseif sawMultiGensLeft and rNum >= 0 and rNum <= 1 then
                fixed = math.max(fixed, 5 - rNum)
            end
        end

        return fixed, #genList
    end

    local function readLeverProgress(gate)
        local objs = { gate.model, gate.point and gate.point.Parent, gate.point }
        local attrs = { "LeverProgress", "ExitProgress", "GateProgress", "OpenProgress", "Progress" }
        local bestProg = 0
        for _, obj in ipairs(objs) do
            if obj and obj.Parent then
                for _, attr in ipairs(attrs) do
                    local v = obj:GetAttribute(attr)
                    if v ~= nil and tonumber(v) then
                        local num = tonumber(v)
                        if num > bestProg then bestProg = num end
                    end
                    local childVal = obj:FindFirstChild(attr)
                    if childVal and (childVal:IsA("NumberValue") or childVal:IsA("IntValue")) then
                        if childVal.Value > bestProg then bestProg = childVal.Value end
                    end
                end
            end
        end
        return bestProg
    end

    local function isGateCompleted(gate)
        if not gate or not gate.point or not gate.point.Parent then return true, 100 end
        if sessionCompletedLevers[gate.point] or (gate.model and sessionCompletedLevers[gate.model]) then
            return true, 100
        end
        local prog = readLeverProgress(gate)
        if prog >= 99.5 then return true, 100 end

        local boolAttrs = { "Opened", "Open", "IsOpen", "Completed", "Activated", "Done", "Unlocked" }
        local objs = { gate.model, gate.point.Parent, gate.point }
        for _, obj in ipairs(objs) do
            if obj and obj.Parent then
                if CollectionService:HasTag(obj, "Opened") or CollectionService:HasTag(obj, "Open") or CollectionService:HasTag(obj, "Completed") then
                    return true, 100
                end
                for _, attr in ipairs(boolAttrs) do
                    if obj:GetAttribute(attr) == true then return true, 100 end
                    local bv = obj:FindFirstChild(attr)
                    if bv and bv:IsA("BoolValue") and bv.Value == true then return true, 100 end
                end
            end
        end
        return false, prog
    end

    local function isGateAccessible(gate)
        local done, prog = isGateCompleted(gate)
        if done then return false end
        if prog > 0.1 then return true end

        local objs = { gate.model, gate.point and gate.point.Parent, gate.point, workspace, ReplicatedStorage }
        local posAttrs = { "Powered", "IsPowered", "CanExit", "CanPull", "CanInteract", "LeverActive", "ExitActive", "ExitsPowered", "GatesPowered", "ExitPowered", "Ready", "Accessible", "Available" }
        for _, obj in ipairs(objs) do
            if obj then
                for _, attr in ipairs(posAttrs) do
                    if obj:GetAttribute(attr) == true then return true end
                end
            end
        end

        local explicitlyLocked = (gate.model and (gate.model:GetAttribute("Locked") == true or gate.model:GetAttribute("Powered") == false or CollectionService:HasTag(gate.model, "Locked")))
            or (gate.point and (gate.point:GetAttribute("Locked") == true or CollectionService:HasTag(gate.point, "Locked")))
        if explicitlyLocked then return false end

        for _, p in ipairs(gate.prompts) do
            if p and p.Parent and p.Enabled == true then
                return true
            end
        end
        return false
    end

    local function isExcludedObject(obj, myChar)
        if not obj or not obj.Parent then return true end
        if myChar and obj:IsDescendantOf(myChar) then return true end
        if obj:FindFirstAncestor("Lobby") then return true end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character and obj:IsDescendantOf(plr.Character) then return true end
        end
        local curr = obj
        while curr and curr ~= workspace do
            local low = curr.Name:lower()
            if low:find("gen") or low:find("repair") or low:find("hook") or low:find("pallet") or low:find("locker") or low:find("chest") or low:find("window") or low:find("vault") or low:find("trap") then
                return true
            end
            curr = curr.Parent
        end
        return false
    end

    local function collectExitLevers(myChar)
        local byModel = {}
        local ordered = {}

        local function registerGate(candidate)
            if isExcludedObject(candidate, myChar) then return end
            local gateModel = nil
            if candidate:IsA("Model") then
                gateModel = candidate
            else
                local curr = candidate.Parent
                while curr and curr ~= workspace do
                    local low = curr.Name:lower()
                    if curr:IsA("Model") and (low:find("exit") or low:find("gate") or low:find("lever") or (curr.Parent and (curr.Parent.Name:lower():find("exit") or curr.Parent.Name:lower():find("gate")))) then
                        gateModel = curr
                        break
                    end
                    curr = curr.Parent
                end
                gateModel = gateModel or candidate:FindFirstAncestorOfClass("Model") or candidate.Parent or candidate
            end
            if not gateModel or byModel[gateModel] then return end

            local bestPart = nil
            local bestScore = -999
            local prompts = {}
            local searchScope = gateModel:GetDescendants()
            if candidate:IsA("BasePart") then table.insert(searchScope, candidate) end

            for _, desc in ipairs(searchScope) do
                if desc:IsA("ProximityPrompt") then
                    table.insert(prompts, desc)
                elseif desc:IsA("BasePart") then
                    local low = desc.Name:lower()
                    local sc = 0
                    if desc == candidate then sc = sc + 10 end
                    if desc:FindFirstChildWhichIsA("ProximityPrompt") then sc = sc + 60 end
                    if low == "leverpoint" or low == "exitpoint" or low == "lever" or low == "switch" then sc = sc + 50 end
                    if low:find("lever") or low:find("switch") or low:find("handle") or low:find("pull") or low:find("button") then sc = sc + 25 end
                    if low:find("door") or low:find("wall") or low:find("frame") or low:find("pillar") then sc = sc - 15 end
                    if sc > bestScore then
                        bestScore = sc
                        bestPart = desc
                    end
                end
            end

            if not bestPart and candidate:IsA("BasePart") then
                bestPart = candidate
            elseif not bestPart and gateModel:IsA("Model") then
                bestPart = gateModel.PrimaryPart or gateModel:FindFirstChildWhichIsA("BasePart")
            end

            if bestPart and bestPart:IsA("BasePart") then
                local entry = { model = gateModel, point = bestPart, prompts = prompts }
                byModel[gateModel] = entry
                table.insert(ordered, entry)
            end
        end

        for _, tagName in ipairs({ "ExitLever", "LeverPoint", "ExitPoint", "GateLever", "ExitGate", "ExitSwitch", "Lever" }) do
            pcall(function()
                for _, obj in ipairs(CollectionService:GetTagged(tagName)) do
                    registerGate(obj)
                end
            end)
        end

        local map = workspace:FindFirstChild("Map") or workspace:FindFirstChild("map")
        if map then
            for _, folderName in ipairs({ "Exits", "ExitGates", "Gates", "Levers", "Exit" }) do
                local f = map:FindFirstChild(folderName)
                if f then
                    for _, child in ipairs(f:GetChildren()) do
                        registerGate(child)
                    end
                end
            end
        end

        if #ordered == 0 then
            for _, desc in ipairs(workspace:GetDescendants()) do
                if desc:IsA("ProximityPrompt") then
                    local txt = ((desc.ObjectText or "") .. " " .. (desc.ActionText or "") .. " " .. (desc.Parent and desc.Parent.Name or "")):lower()
                    if txt:find("lever") or txt:find("exit") or txt:find("gate") or txt:find("switch") or txt:find("power") then
                        registerGate(desc.Parent)
                    end
                elseif desc:IsA("BasePart") or desc:IsA("Model") then
                    local low = desc.Name:lower()
                    if low == "exitlever" or low == "leverpoint" or low == "exitpoint" or low == "gatelever" or low == "exitgate" then
                        registerGate(desc)
                    end
                end
            end
        end

        return ordered
    end

    local function computeUndergroundLeverPos(leverPt, gateModel)
        local floorY = autoLeverFloorY
        if not floorY and vdESPState and vdESPState.findFloorYBelow then
            floorY = vdESPState.findFloorYBelow(leverPt.Position.X, leverPt.Position.Y, leverPt.Position.Z, gateModel)
            autoLeverFloorY = floorY
        end
        local stepDepths = { 5.4, 4.5, 3.7 }
        local baseDepth = stepDepths[(autoLeverRetryStep % 3) + 1] or 5.4
        local desiredDepth = math.min(baseDepth, math.max(3.6, ghostDepthOffset or 5.4))
        local destY
        if floorY then
            destY = math.min(floorY - 3.6, floorY - desiredDepth)
        else
            destY = leverPt.Position.Y - math.clamp(ghostDepthOffset or 7.0, 5.5, 8.2)
        end
        return Vector3.new(leverPt.Position.X, destY, leverPt.Position.Z)
    end

    local function enforcePos(tolerance)
        local myChar = localPlayer.Character
        if not myChar or not myChar:IsDescendantOf(workspace) then return false end
        local myHrp = myChar:FindFirstChild("HumanoidRootPart")
        if not myHrp or not autoLeverHoldPos or autoLeverTransiting then return false end
        if isYieldedByOtherFeatures(myChar, autoLeverPoint) then return false end

        local hum = myChar:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.PlatformStand = false
            if hum.Sit then hum.Sit = false end
        end

        setLeverCollisionState(myChar, false)
        if vdESPState and vdESPState.setMovementBypass then
            vdESPState.setMovementBypass(myChar, true)
        end

        local curPos = myHrp.Position
        if (curPos - autoLeverHoldPos).Magnitude > (tolerance or 0.25) then
            myHrp.CFrame = CFrame.new(autoLeverHoldPos)
            myHrp.AssemblyLinearVelocity = Vector3.zero
            myHrp.AssemblyAngularVelocity = Vector3.zero
            return false
        end
        myHrp.AssemblyLinearVelocity = Vector3.zero
        myHrp.AssemblyAngularVelocity = Vector3.zero
        return true
    end

    local function stopAutoLeverEX()
        autoLeverHoldPos = nil
        autoLeverPoint = nil
        autoLeverModel = nil
        autoLeverFloorY = nil
        autoLeverTransiting = false
        clearMarker()
        if vdESPState then
            vdESPState.autoLeverEXHoldPos = nil
            vdESPState.autoLeverEXPaused = false
            vdESPState.autoLeverEXWantsPriority = false
        end
        if autoLeverSteppedConn then pcall(function() autoLeverSteppedConn:Disconnect() end) autoLeverSteppedConn = nil end
        if autoLeverHeartbeatConn then pcall(function() autoLeverHeartbeatConn:Disconnect() end) autoLeverHeartbeatConn = nil end
        if autoLeverAnimConn then pcall(function() autoLeverAnimConn:Disconnect() end) autoLeverAnimConn = nil end

        local myChar = localPlayer and localPlayer.Character
        local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local yielding = vdESPState and (
            (vdESPState.fleeKnockEXEnabled and vdESPState.fleeKnockEXBlocking)
            or (vdESPState.autoFleeEnabled and vdESPState.autoFleeBlocking)
            or (vdESPState.rescueEXEnabled and vdESPState.rescueEXWantsPriority)
        )
        unlockMotion(myChar, myHrp, not yielding and ghostAutoReturn, not yielding)
        autoLeverOrigCFrame = nil
    end

    local function triggerLeverPrompts(gate)
        if not gate or not gate.prompts then return end
        for _, p in ipairs(gate.prompts) do
            if p and p.Parent then
                pcall(function()
                    p.RequiresLineOfSight = false
                    if (p.MaxActivationDistance or 0) < 25 then p.MaxActivationDistance = 25 end
                end)
                if p.Enabled then
                    pcall(function()
                        if fireproximityprompt then
                            fireproximityprompt(p)
                        else
                            p:InputHoldBegin()
                        end
                    end)
                end
            end
        end
    end

    local function endLeverPrompts(gate)
        if not gate or not gate.prompts then return end
        for _, p in ipairs(gate.prompts) do
            if p and p.Parent then
                pcall(function() p:InputHoldEnd() end)
            end
        end
    end

    local function startAutoLeverEX()
        stopAutoLeverEX()
        if not vdESPState then return end
        vdESPState.autoLeverEXSession = (vdESPState.autoLeverEXSession or 0) + 1
        local thisSession = vdESPState.autoLeverEXSession

        local function isStillRunning()
            return checkActive() and vdESPState.autoLeverEXSession == thisSession
        end

        local remotes = getVDRemotes and getVDRemotes()
        if remotes and remotes.Exit and remotes.Exit:FindFirstChild("LeverAnim") then
            pcall(function()
                autoLeverAnimConn = remotes.Exit.LeverAnim.OnClientEvent:Connect(function(animChar, isPulling)
                    if not isStillRunning() then return end
                    if animChar == localPlayer.Character and isPulling == true then
                        lastServerLeverConfirm = tick()
                    end
                end)
            end)
        end

        autoLeverSteppedConn = RunService.Stepped:Connect(function()
            if not isStillRunning() then
                if autoLeverSteppedConn then pcall(function() autoLeverSteppedConn:Disconnect() end) autoLeverSteppedConn = nil end
                return
            end
            pcall(function() enforcePos(0.25) end)
        end)

        autoLeverHeartbeatConn = RunService.Heartbeat:Connect(function()
            if not isStillRunning() then
                if autoLeverHeartbeatConn then pcall(function() autoLeverHeartbeatConn:Disconnect() end) autoLeverHeartbeatConn = nil end
                return
            end
            pcall(function() enforcePos(0.25) end)
        end)

        -- Ultra-fast 0.0001s real-position checker
        task.spawn(function()
            while isStillRunning() do
                pcall(function() enforcePos(0.25) end)
                task.wait(0.0001)
            end
        end)

        -- Main Auto Lever EX Priority & Pull Thread
        task.spawn(function()
            local trackedChar = nil
            local failCount = 0
            local lastSawFour = false

            while isStillRunning() do
                local ok = pcall(function()
                    local myChar = localPlayer.Character
                    if not myChar or not myChar:IsDescendantOf(workspace) then
                        vdESPState.autoLeverEXWantsPriority = false
                        autoLeverHoldPos = nil
                        vdESPState.autoLeverEXHoldPos = nil
                        autoLeverPoint = nil
                        autoLeverModel = nil
                        autoLeverFloorY = nil
                        clearMarker()
                        task.wait(0.2)
                        return
                    end

                    if trackedChar ~= myChar then
                        trackedChar = myChar
                        sessionCompletedLevers = {}
                        unreadyLockout = false
                        sawMultiGensLeft = false
                        lastSawFour = false
                        failCount = 0
                        autoLeverRetryStep = 0
                        autoLeverOrigCFrame = nil
                        autoLeverHoldPos = nil
                        autoLeverPoint = nil
                        autoLeverModel = nil
                        autoLeverFloorY = nil
                        vdESPState.autoLeverEXPaused = false
                        vdESPState.autoLeverEXWantsPriority = false
                        vdESPState.autoLeverEXHoldPos = nil
                        clearMarker()
                    end

                    local hum = myChar:FindFirstChildOfClass("Humanoid")
                    local myHrp = myChar:FindFirstChild("HumanoidRootPart")
                    if not myHrp or not hum or hum.Health <= 0 then
                        vdESPState.autoLeverEXWantsPriority = false
                        autoLeverHoldPos = nil
                        vdESPState.autoLeverEXHoldPos = nil
                        clearMarker()
                        task.wait(0.2)
                        return
                    end

                    if isYieldedByOtherFeatures(myChar, nil) then
                        vdESPState.autoLeverEXWantsPriority = false
                        autoLeverHoldPos = nil
                        vdESPState.autoLeverEXHoldPos = nil
                        clearMarker()
                        task.wait(0.15)
                        return
                    end

                    local fixedGens, _ = getFixedGeneratorStatus(myChar)
                    local allGates = collectExitLevers(myChar)
                    local anyAccessible = false
                    local bestGate = nil
                    local bestDist = math.huge

                    for _, g in ipairs(allGates) do
                        local done = isGateCompleted(g)
                        if not done then
                            if isGateAccessible(g) then
                                anyAccessible = true
                            end
                            local d = (myHrp.Position - g.point.Position).Magnitude
                            if d < bestDist then
                                bestDist = d
                                bestGate = g
                            end
                        end
                    end

                    -- If server progressed to 5 gens or any lever became explicitly accessible, clear 4-gen early lockout
                    if fixedGens >= 5 or anyAccessible then
                        unreadyLockout = false
                    end
                    if fixedGens >= 4 and not lastSawFour then
                        lastSawFour = true
                        unreadyLockout = false
                    end

                    if #allGates > 0 and not bestGate then
                        -- All detected exit gates are already opened
                        vdESPState.autoLeverEXWantsPriority = false
                        autoLeverHoldPos = nil
                        vdESPState.autoLeverEXHoldPos = nil
                        if autoLeverPoint or autoLeverModel or (autoLeverFloorY and myHrp.Position.Y < (autoLeverFloorY - 0.5)) then
                            local isCurrentlyUnderground = autoLeverFloorY ~= nil and myHrp.Position.Y < (autoLeverFloorY - 0.5)
                            autoLeverPoint = nil
                            autoLeverModel = nil
                            clearMarker()
                            unlockMotion(myChar, myHrp, isCurrentlyUnderground, true)
                        end
                        task.wait(0.5)
                        return
                    end

                    local conditionMet = bestGate and (anyAccessible or (fixedGens >= 4 and not unreadyLockout))
                    if not conditionMet then
                        vdESPState.autoLeverEXWantsPriority = false
                        autoLeverHoldPos = nil
                        vdESPState.autoLeverEXHoldPos = nil
                        clearMarker()
                        task.wait(0.25)
                        return
                    end

                    -- Check if Killer is camping the target lever while Auto Flee is active
                    if isYieldedByOtherFeatures(myChar, bestGate.point) then
                        vdESPState.autoLeverEXWantsPriority = false
                        autoLeverHoldPos = nil
                        vdESPState.autoLeverEXHoldPos = nil
                        clearMarker()
                        task.wait(0.2)
                        return
                    end

                    -- Prioritize Auto Lever EX above Underground Repair Generator EX
                    vdESPState.autoLeverEXWantsPriority = true
                    if not autoLeverOrigCFrame then
                        autoLeverOrigCFrame = myHrp.CFrame
                    end

                    local targetPt = bestGate.point
                    local targetModel = bestGate.model
                    autoLeverPoint = targetPt
                    autoLeverModel = targetModel
                    autoLeverFloorY = vdESPState.findFloorYBelow and vdESPState.findFloorYBelow(targetPt.Position.X, targetPt.Position.Y, targetPt.Position.Z, targetModel) or nil

                    local destPos = computeUndergroundLeverPos(targetPt, targetModel)
                    autoLeverTransiting = true
                    autoLeverHoldPos = nil
                    vdESPState.autoLeverEXHoldPos = nil
                    local arrivedLever = true
                    if vdESPState.microTransitTo then
                        arrivedLever = vdESPState.microTransitTo(myChar, myHrp, destPos, function()
                            return isStillRunning() and targetPt.Parent and not isYieldedByOtherFeatures(myChar, targetPt)
                        end, true, 6.5)
                    end
                    if not isStillRunning() or not targetPt.Parent or isYieldedByOtherFeatures(myChar, targetPt) then
                        autoLeverTransiting = false
                        return
                    end
                    if not arrivedLever or (myHrp.Position - destPos).Magnitude > 6.5 then
                        autoLeverTransiting = false
                        autoLeverHoldPos = nil
                        vdESPState.autoLeverEXHoldPos = nil
                        failCount = failCount + 1
                        unlockMotion(myChar, myHrp, false, true)
                        if failCount >= 2 then
                            vdESPState.autoLeverEXPaused = true
                            local pauseEnd = tick() + 2.0
                            while tick() < pauseEnd and isStillRunning() and not isYieldedByOtherFeatures(myChar, targetPt) do
                                task.wait(0.05)
                            end
                            failCount = 0
                            vdESPState.autoLeverEXPaused = false
                        else
                            task.wait(0.12)
                        end
                        return
                    end

                    autoLeverHoldPos = destPos
                    vdESPState.autoLeverEXHoldPos = destPos
                    autoLeverTransiting = false
                    setMarker(targetModel, targetPt)

                    -- Hold buried underground for 0.12s so server receives underground CFrame before LeverEvent
                    local settleEnd = tick() + 0.12
                    while tick() < settleEnd and isStillRunning() and targetPt.Parent do
                        enforcePos(0.20)
                        task.wait(0.0001)
                    end

                    local rmt = getVDRemotes and getVDRemotes()
                    local hasLeverRemote = rmt and rmt.Exit and rmt.Exit:FindFirstChild("LeverEvent")
                    if not hasLeverRemote and #bestGate.prompts == 0 then
                        task.wait(0.3)
                        return
                    end

                    local attemptStart = tick()
                    local lastProgressTime = attemptStart
                    local _, lastObservedProg = isGateCompleted(bestGate)
                    local lastPulseSent = 0
                    local requestId = HttpService:GenerateGUID(false)

                    local function startPullAttempt()
                        pcall(function()
                            if myHrp then CollectionService:RemoveTag(myHrp, "doing action") end
                            if myChar then CollectionService:RemoveTag(myChar, "doing action") end
                        end)
                        requestId = HttpService:GenerateGUID(false)
                        if hasLeverRemote then
                            pcall(function()
                                rmt.Exit.LeverEvent:FireServer(targetPt, true, requestId, myChar)
                                myChar:SetAttribute("isExiting", true)
                            end)
                        end
                        if (autoLeverRetryStep % 3) >= 1 or not hasLeverRemote then
                            triggerLeverPrompts(bestGate)
                        end
                    end

                    startPullAttempt()

                    while isStillRunning() and targetPt.Parent and vdESPState.autoLeverEXWantsPriority do
                        if isYieldedByOtherFeatures(myChar, targetPt) then
                            if hasLeverRemote then
                                pcall(function() rmt.Exit.LeverEvent:FireServer(targetPt, false, requestId, myChar) end)
                            end
                            myChar:SetAttribute("isExiting", false)
                            endLeverPrompts(bestGate)
                            vdESPState.autoLeverEXWantsPriority = false
                            autoLeverHoldPos = nil
                            vdESPState.autoLeverEXHoldPos = nil
                            clearMarker()
                            return
                        end

                        local doneNow, progNow = isGateCompleted(bestGate)
                        if doneNow or progNow >= 99.5 then
                            sessionCompletedLevers[targetPt] = true
                            if targetModel then sessionCompletedLevers[targetModel] = true end
                            if hasLeverRemote then
                                pcall(function() rmt.Exit.LeverEvent:FireServer(targetPt, false, requestId, myChar) end)
                            end
                            myChar:SetAttribute("isExiting", false)
                            endLeverPrompts(bestGate)
                            clearMarker()
                            failCount = 0
                            autoLeverRetryStep = 0
                            break
                        end

                        -- Keepalive pull pulse
                        if (tick() - lastPulseSent) >= 0.65 then
                            lastPulseSent = tick()
                            autoLeverHoldPos = computeUndergroundLeverPos(targetPt, targetModel)
                            vdESPState.autoLeverEXHoldPos = autoLeverHoldPos
                            setMarker(targetModel, targetPt)
                            if hasLeverRemote then
                                pcall(function()
                                    rmt.Exit.LeverEvent:FireServer(targetPt, true, requestId, myChar)
                                    myChar:SetAttribute("isExiting", true)
                                end)
                            end
                            if #bestGate.prompts > 0 and (tick() - lastServerLeverConfirm) > 1.2 then
                                triggerLeverPrompts(bestGate)
                            end
                        end

                        -- Check progress OR server LeverAnim confirmation before flagging stall
                        if progNow > (lastObservedProg + 0.01) then
                            lastObservedProg = progNow
                            lastProgressTime = tick()
                            failCount = 0
                        elseif lastServerLeverConfirm >= attemptStart and (tick() - lastServerLeverConfirm) <= 3.5 then
                            lastProgressTime = tick()
                            failCount = 0
                        elseif (tick() - lastProgressTime) >= 3.5 then
                            failCount = failCount + 1
                            if hasLeverRemote then
                                pcall(function() rmt.Exit.LeverEvent:FireServer(targetPt, false, requestId, myChar) end)
                            end
                            myChar:SetAttribute("isExiting", false)
                            endLeverPrompts(bestGate)
                            task.wait(0.05)

                            if not isStillRunning() or not targetPt.Parent or isGateCompleted(bestGate) then
                                break
                            end

                            if failCount >= 3 then
                                local curFixed, _ = getFixedGeneratorStatus(myChar)
                                local curAccessible = isGateAccessible(bestGate)
                                local hasGenAutomation = ghostRepairEXEnabled or ghostRepairEnabled or autoRepairEnabled
                                if curFixed < 5 and not curAccessible and hasGenAutomation then
                                    -- 5-gen match not yet unlocked at 4 gens: hand back to Generator Repair until 5th gen finishes or gate unlocks
                                    unreadyLockout = true
                                    failCount = 0
                                    autoLeverRetryStep = 0
                                    vdESPState.autoLeverEXWantsPriority = false
                                    autoLeverHoldPos = nil
                                    vdESPState.autoLeverEXHoldPos = nil
                                    clearMarker()
                                    task.wait(0.2)
                                    return
                                end

                                -- 3 fail attempts -> 2 second reset pause, then retry
                                vdESPState.autoLeverEXPaused = true
                                autoLeverHoldPos = nil
                                vdESPState.autoLeverEXHoldPos = nil
                                unlockMotion(myChar, myHrp, false, true)
                                local pauseEnd = tick() + 2.0
                                while tick() < pauseEnd and isStillRunning() and not isYieldedByOtherFeatures(myChar, targetPt) do
                                    task.wait(0.05)
                                end
                                failCount = 0
                                autoLeverRetryStep = 0
                                vdESPState.autoLeverEXPaused = false
                                break
                            else
                                autoLeverRetryStep = (autoLeverRetryStep + 1) % 3
                                autoLeverHoldPos = computeUndergroundLeverPos(targetPt, targetModel)
                                vdESPState.autoLeverEXHoldPos = autoLeverHoldPos
                                attemptStart = tick()
                                lastProgressTime = attemptStart
                                startPullAttempt()
                            end
                        end

                        task.wait(0.05)
                    end
                end)

                if not ok then
                    task.wait(0.1)
                end
                task.wait(0.05)
            end

            stopAutoLeverEX()
        end)
    end

    if vdESPState then
        vdESPState.autoLeverEXToggle = V_SurvivorEXSection:Toggle({
            Title = "Auto Lever EX",
            Description = "0.0001s underground Exit Gate opener with priority over Ghost Gen EX when accessible or >= 4 gens fixed",
            Default = false,
            Callback = function(v)
                if not vdESPState then return end
                vdESPState.autoLeverEXEnabled = v
                if v then
                    autoLeverOrigCFrame = nil
                    sessionCompletedLevers = {}
                    unreadyLockout = false
                    startAutoLeverEX()
                else
                    vdESPState.autoLeverEXSession = (vdESPState.autoLeverEXSession or 0) + 1
                    stopAutoLeverEX()
                end
            end
        })
    end
end)

V_ObjectiveSection:Slider({
    Title = "Ghost Depth Offset",
    Description = "Depth in studs below generator floor (4.5 to 10.0 studs, default 7.0)",
    Step = 0.5,
    Value = {
        Min = 4.5,
        Max = 10.0,
        Default = 7.0,
    },
    Callback = function(v)
        ghostDepthOffset = tonumber(v) or 7.0
    end
})

V_ObjectiveSection:Slider({
    Title = "Ghost Repair Speed",
    Description = "Interval between skillcheck progression boosts (0.3s Fast - 2.0s Legit)",
    Step = 0.1,
    Value = {
        Min = 0.3,
        Max = 2.0,
        Default = 0.8,
    },
    Callback = function(v)
        ghostRepairPulseInterval = tonumber(v) or 0.8
    end
})

V_ObjectiveSection:Toggle({
    Title = "Auto Return to Surface",
    Description = "Safely teleports you back to your starting spot once generators are completed or feature is turned off.",
    Default = true,
    Callback = function(v)
        ghostAutoReturn = v
    end
})


-- ============================================================
-- 5. AUTO PALLET STUN
-- ============================================================
-- Unified autoPalletEnabled
pcall(function()
local function findNearbyPallets()
    local myChar = player.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return {} end

    local pallets = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name:lower():find("pallet") and (obj:FindFirstChild("DropPoint") or obj:FindFirstChildWhichIsA("BasePart")) then
            local part = obj:FindFirstChild("DropPoint") or obj:FindFirstChildWhichIsA("BasePart")
            if part and (myHrp.Position - part.Position).Magnitude <= 16 then
                table.insert(pallets, { model = obj, dropPoint = part })
            end
        end
    end
    return pallets
end

V_CombatSection:Toggle({
    Title = "Auto Pallet Stun",
    Description = "Drops pallet when killer steps into the stun radius",
    Default = false,
    Callback = function(v)
        autoPalletEnabled = v
        palletSession = palletSession + 1
        local thisSession = palletSession
        local remotes = getVDRemotes()

        if not v then
            return
        end

        task.spawn(function()
            while autoPalletEnabled and (palletSession == thisSession) and scriptRunning do
                pcall(function()
                    local killer = getKiller()
                    local myChar = player.Character
                    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")

                    if killer and killer:FindFirstChild("HumanoidRootPart") and myHrp then
                        local kHrp = killer.HumanoidRootPart
                        local pallets = findNearbyPallets()

                        for _, p in ipairs(pallets) do
                            local killerToPallet = (kHrp.Position - p.dropPoint.Position).Magnitude
                            if killerToPallet <= 12 and remotes.Pallet and remotes.Pallet:FindFirstChild("PalletDropEvent") then
                                local guid = HttpService:GenerateGUID(false)
                                remotes.Pallet.PalletDropEvent:FireServer(p.dropPoint, myHrp.Position, myHrp.CFrame.LookVector, guid, myChar)
                                WindUI:Notify({ Title = "🪵 Pallet Stun!", Content = "Dropped pallet on Killer!", Duration = 2 })
                                task.wait(1.5)
                                break
                            end
                        end
                    end
                end)
                task.wait(0.1)
            end
        end)
    end
})

-- ============================================================
-- 6. AUTO PARRY (PERFECT DIRECTIONAL COUNTER & DEFENSE)
-- ============================================================
-- Unified autoParryEnabled
local lastParryTime = 0

local function isKillerAttackingState(killer, myHrp)
    if not killer then return false end
    local kHrp = killer:FindFirstChild("HumanoidRootPart")
    if not kHrp or not myHrp then return false end

    local dist = (myHrp.Position - kHrp.Position).Magnitude
    if dist > 14.5 then return false end

    -- 1. Check Killer's Humanoid Playing Animation Tracks
    -- In Violence District, attacks, lunges, and weapon swings use Action or higher AnimationPriority!
    local hum = killer:FindFirstChildOfClass("Humanoid")
    local anim = hum and hum:FindFirstChildOfClass("Animator")
    if anim then
        for _, track in ipairs(anim:GetPlayingAnimationTracks()) do
            local priority = track.Priority
            local prioVal = (typeof(priority) == "EnumItem") and priority.Value or 0
            -- Enum.AnimationPriority.Action is 2 (Action2=3, Action3=4, Action4=5, Idle=0, Movement=1)
            if prioVal >= 2 then
                if track.WeightCurrent > 0.05 and track.TimePosition < (track.Length > 0 and track.Length * 0.85 or 0.7) then
                    return true
                end
            end

            -- Track name fallback (in case named track asset is replicated)
            local name = (track.Name or ""):lower()
            if name:find("attack") or name:find("slash") or name:find("swing")
                or name:find("lunge") or name:find("hit") or name:find("strike")
                or name:find("machete") or name:find("cleaver") or name:find("axe") then
                return true
            end
        end
    end

    -- 2. Killer Lunging / Sprint-Strike Check (High Velocity Facing Me)
    local kLook = kHrp.CFrame.LookVector
    local toMe = (myHrp.Position - kHrp.Position)
    if toMe.Magnitude > 0 then
        local toMeDir = toMe.Unit
        local facingDot = kLook:Dot(toMeDir)
        local vel = kHrp.AssemblyLinearVelocity
        local speedTowardsMe = vel:Dot(toMeDir)

        -- If killer is facing survivor (dot > 0.4) and surging forward at attack speed within 10.5 studs
        if facingDot > 0.4 and speedTowardsMe > 14.5 and dist <= 10.5 then
            return true
        end
    end

    -- 3. Killer Weapon Motion / Right Arm Angle Swing
    local rightArm = killer:FindFirstChild("Right Arm") or killer:FindFirstChild("RightHand")
    if rightArm and dist <= 11.5 then
        local kForward = kHrp.CFrame.LookVector
        local armForward = rightArm.CFrame.LookVector
        if kForward:Dot(armForward) > 0.6 and (kHrp.Position - rightArm.Position).Magnitude > 1.2 then
            local toMeDir = (myHrp.Position - kHrp.Position).Unit
            if kForward:Dot(toMeDir) > 0.35 then
                return true
            end
        end
    end

    return false
end

local function findParryDefensiveTool()
    local myChar = player.Character
    local backpack = player:FindFirstChild("Backpack")
    local candidateNames = {
        "Parrying Dagger", "ParryingDagger", "Dagger",
        "Riot Shield", "RiotShield", "Shield",
        "Flashlight"
    }

    if myChar then
        for _, name in ipairs(candidateNames) do
            local t = myChar:FindFirstChild(name)
            if t and t:IsA("Tool") then return t, "char" end
        end
        for _, item in ipairs(myChar:GetChildren()) do
            if item:IsA("Tool") then
                local low = item.Name:lower()
                if low:find("parry") or low:find("dagger") or low:find("shield") or low:find("flashlight") then
                    return item, "char"
                end
            end
        end
    end

    if backpack then
        for _, name in ipairs(candidateNames) do
            local t = backpack:FindFirstChild(name)
            if t and t:IsA("Tool") then return t, "backpack" end
        end
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") then
                local low = item.Name:lower()
                if low:find("parry") or low:find("dagger") or low:find("shield") or low:find("flashlight") then
                    return item, "backpack"
                end
            end
        end
    end

    return nil, nil
end

V_CombatSection:Toggle({
    Title = "Auto Parry",
    Description = "Automatically snaps direction & parries incoming killer attacks, lunges, & swings",
    Default = false,
    Callback = function(v)
        autoParryEnabled = v
        parrySession = parrySession + 1
        local thisSession = parrySession
        local remotes = getVDRemotes()

        if not v then
            return
        end

        task.spawn(function()
            while autoParryEnabled and (parrySession == thisSession) and scriptRunning do
                pcall(function()
                    if isPlayerKiller and isPlayerKiller() then
                        task.wait(1)
                        return
                    end

                    local killer = getKiller()
                    local myChar = player.Character
                    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")

                    if killer and killer:FindFirstChild("HumanoidRootPart") and myHrp then
                        local kHrp = killer.HumanoidRootPart
                        local dist = (myHrp.Position - kHrp.Position).Magnitude
                        local attacking = isKillerAttackingState(killer, myHrp)

                        -- Trigger parry ONLY when killer is actively attacking within reach (<= 13 studs)
                        -- and cooldown has passed (at least 1.4s matching weapon recharge)
                        if attacking and dist <= 13.0 and (tick() - lastParryTime > 1.4) then
                            lastParryTime = tick()

                            -- 1. Face directly toward the Killer (Mandatory for parry in Violence District)
                            local targetLook = Vector3.new(kHrp.Position.X, myHrp.Position.Y, kHrp.Position.Z)
                            myHrp.CFrame = CFrame.lookAt(myHrp.Position, targetLook)

                            -- Also snap camera look at killer
                            pcall(function()
                                local cam = workspace.CurrentCamera
                                if cam then
                                    cam.CFrame = CFrame.lookAt(cam.CFrame.Position, kHrp.Position + Vector3.new(0, 1.2, 0))
                                end
                            end)

                            -- 2. Equip defensive parrying tool
                            local parryTool, location = findParryDefensiveTool()
                            if parryTool and location == "backpack" then
                                parryTool.Parent = myChar
                            end

                            -- 3. Fire Official Violence District Parrying Remotes
                            pcall(function()
                                if remotes.Items then
                                    -- Parrying Dagger Remote
                                    local daggerFolder = remotes.Items:FindFirstChild("Parrying Dagger") or remotes.Items:FindFirstChild("ParryingDagger")
                                    if daggerFolder and daggerFolder:FindFirstChild("parry") then
                                        daggerFolder.parry:FireServer(myChar)
                                    end

                                    -- Riot Shield Remote
                                    local shieldFolder = remotes.Items:FindFirstChild("Riot Shield") or remotes.Items:FindFirstChild("RiotShield")
                                    if shieldFolder and shieldFolder:FindFirstChild("Rush") then
                                        shieldFolder.Rush:FireServer(myChar)
                                    end

                                    -- Flashlight Stun Remote
                                    if remotes.Items:FindFirstChild("Flashlight") and remotes.Items.Flashlight:FindFirstChild("Activate") then
                                        remotes.Items.Flashlight.Activate:FireServer(true, kHrp.Position)
                                    end
                                end
                            end)

                            -- 4. Native Keybind & Mouse Item Trigger (ParryClient listener: MouseButton2 / Item)
                            pcall(function()
                                if VirtualInputManager and typeof(VirtualInputManager.SendMouseButtonEvent) == "function" then
                                    VirtualInputManager:SendMouseButtonEvent(0, 0, 1, true, game, 0)
                                    task.wait(0.02)
                                    VirtualInputManager:SendMouseButtonEvent(0, 0, 1, false, game, 0)
                                end
                            end)

                            -- 5. Tool:Activate() call
                            if parryTool then
                                pcall(function() parryTool:Activate() end)
                            end

                            -- 6. Mobile GUI Button trigger (ItemFrame / Survivor-mob item action)
                            pcall(function()
                                local pg = player:FindFirstChild("PlayerGui")
                                if pg then
                                    for _, guiName in ipairs({"Survivor-mob", "Survivor", "MobileGui"}) do
                                        local g = pg:FindFirstChild(guiName)
                                        if g then
                                            for _, btn in ipairs(g:GetDescendants()) do
                                                if btn:IsA("GuiButton") and (btn.Name:lower():find("item") or btn.Name:lower():find("parry") or btn.Name:lower():find("use")) then
                                                    if typeof(firesignal) == "function" then
                                                        firesignal(btn.MouseButton1Down)
                                                        firesignal(btn.Activated)
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end)

                            WindUI:Notify({ Title = "Auto Parry!", Content = "Parried Killer attack (" .. string.format("%.1f", dist) .. " studs)!", Duration = 2 })
                        end
                    end
                end)
                task.wait(0.015)
            end
        end)
    end
})

-- ============================================================
-- 7. AUTO AIM (AIM AT KILLER)
-- ============================================================
local autoAimEnabled = false
local aimConn

V_CombatSection:Toggle({
    Title = "Auto Aim (Killer)",
    Description = "Locks camera directly at the Killer (for items/flashlight)",
    Default = false,
    Callback = function(v)
        autoAimEnabled = v
        if aimConn then
            pcall(function() aimConn:Disconnect() end)
            aimConn = nil
        end

        if not v then
            return
        end

        aimConn = RunService.RenderStepped:Connect(function()
            if not autoAimEnabled then return end
            pcall(function()
                local killer = getKiller()
                if killer and killer:FindFirstChild("HumanoidRootPart") then
                    local cam = workspace.CurrentCamera
                    local targetPos = killer.HumanoidRootPart.Position + Vector3.new(0, 1.5, 0)
                    cam.CFrame = CFrame.new(cam.CFrame.Position, targetPos)
                end
            end)
        end)
    end
})

-- ============================================================
-- AUTO DODGE KILLER (INSTANT TELEPORT 17 STUDS BEHIND KILLER)
-- ============================================================
-- Unified autoDodgeEnabled
local autoDodgeDistance = 18
local autoDodgeCooldown = 0.35
local lastDodgeTime = 0

V_CombatSection:Toggle({
    Title = "Auto Dodge Killer",
    Description = "Instantly teleports always 17 studs behind Killer when detected nearby",
    Default = false,
    Callback = function(v)
        autoDodgeEnabled = v
        dodgeSession = dodgeSession + 1
        local thisSession = dodgeSession

        if not v then
            return
        end

        task.spawn(function()
            while autoDodgeEnabled and (dodgeSession == thisSession) and scriptRunning do
                pcall(function()
                    if not scriptRunning or not autoDodgeEnabled then return end
                    local myChar = player.Character
                    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                    local hum = myChar and myChar:FindFirstChildOfClass("Humanoid")
                    if not myHrp or not hum or hum.Health <= 0 then return end

                    -- Do not dodge if player is currently the Killer
                    if isPlayerKiller and isPlayerKiller() then return end

                    local killer = getKiller()
                    if killer and killer:FindFirstChild("HumanoidRootPart") and killer ~= myChar then
                        local kHrp = killer.HumanoidRootPart
                        local dist = (myHrp.Position - kHrp.Position).Magnitude

                        if dist <= autoDodgeDistance and (tick() - lastDodgeTime >= autoDodgeCooldown) then
                            -- Target position: always 17 studs directly behind Killer
                            local behindDir = -kHrp.CFrame.LookVector
                            local targetBehind = kHrp.Position + (behindDir * 17)

                            local rayParams = RaycastParams.new()
                            rayParams.FilterType = Enum.RaycastFilterType.Exclude
                            rayParams.FilterDescendantsInstances = { killer, myChar }
                            rayParams.IgnoreWater = true

                            -- Wall & Obstacle detection behind killer to prevent clipping into walls
                            if not noClipEnabled then
                                local hit = workspace:Raycast(kHrp.Position, behindDir * 17.5, rayParams)
                                if hit and hit.Instance and hit.Instance.CanCollide and hit.Instance.Transparency < 0.95 and not hit.Instance:IsA("Terrain") then
                                    targetBehind = hit.Position + (hit.Normal * 2.0)
                                end
                            end

                            -- Ground check to ensure valid floor height
                            local groundRay = workspace:Raycast(targetBehind + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), rayParams)
                            if groundRay and groundRay.Position then
                                targetBehind = groundRay.Position + Vector3.new(0, 1.8, 0)
                            end

                            local distToBehind = (myHrp.Position - targetBehind).Magnitude
                            local isFacingMe = kHrp.CFrame.LookVector:Dot((myHrp.Position - kHrp.Position).Unit) > -0.2

                            if distToBehind > 2.0 or isFacingMe then
                                lastDodgeTime = tick()
                                -- Reset linear and angular velocities to stop forward momentum
                                myHrp.AssemblyLinearVelocity = Vector3.zero
                                myHrp.AssemblyAngularVelocity = Vector3.zero
                                -- Instantly teleport 17 studs behind killer facing killer's back
                                myHrp.CFrame = CFrame.lookAt(targetBehind, kHrp.Position)
                            end
                        end
                    end
                end)
                task.wait(0.03)
            end
        end)
    end
})

V_CombatSection:Slider({
    Title = "Dodge Trigger Distance",
    Description = "Distance in studs to trigger auto dodge behind Killer (1 - 40 studs)",
    Step = 1,
    Value = {
        Min = 1,
        Max = 40,
        Default = 15,
    },
    Callback = function(val)
        autoDodgeDistance = tonumber(val) or 15
    end
})
end)

-- ============================================================
-- AUTO FLEE KILLER (1 - 300 STUDS STANDALONE SAFE ESCAPE)
-- ============================================================
pcall(function()
    local CollectionService = game:GetService("CollectionService")

    local fleeSteppedConn = nil
    local fleeHeartbeatConn = nil
    local fleeTransiting = false
    local fleePaused = false
    local fleeGroundY = nil

    local function unlockFleeConstraints(myChar, myHrp, restoreCollision)
        pcall(function()
            if myHrp then
                if myHrp.Anchored then
                    vdESPState.lastServerAnchorTick = tick()
                    myHrp.Anchored = false
                end
                myHrp.AssemblyLinearVelocity = Vector3.zero
                myHrp.AssemblyAngularVelocity = Vector3.zero
                pcall(function() CollectionService:RemoveTag(myHrp, "doing action") end)
            end
            if myChar then
                if myChar:GetAttribute("AC_ServerAnchor") ~= nil then
                    vdESPState.lastACAnchorTick = tick()
                    vdESPState.lastServerAnchorTick = tick()
                end
                myChar:SetAttribute("isRepairing", false)
                myChar:SetAttribute("isHealing", false)
                myChar:SetAttribute("isUnhooking", false)
                myChar:SetAttribute("isExiting", false)
                myChar:SetAttribute("Rooted", false)
                myChar:SetAttribute("Immobile", false)
                myChar:SetAttribute("AC_ServerAnchor", nil)
                pcall(function() CollectionService:RemoveTag(myChar, "doing action") end)
                local hum = myChar:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.PlatformStand = false
                end
                for _, part in ipairs(myChar:GetDescendants()) do
                    if part:IsA("BasePart") then
                        if restoreCollision ~= false then
                            if part.Name == "HumanoidRootPart" or part.Name == "Torso" or part.Name == "UpperTorso" or part.Name == "LowerTorso" then
                                part.CanCollide = true
                            end
                        elseif part.CanCollide then
                            part.CanCollide = false
                        end
                    end
                end
            end
        end)
    end

    local function enforceFleeUndergroundPos(tol)
        if not vdESPState.autoFleeEnabled or fleeTransiting or fleePaused then return false end
        local holdPos = vdESPState.autoFleeHoldPos
        if not holdPos then return false end
        local myChar = player.Character
        local hum = myChar and myChar:FindFirstChildOfClass("Humanoid")
        local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myChar or not myHrp or not hum or hum.Health <= 0 then return false end
        if isCharacterKnocked(myChar) or isCharacterHooked(myChar) or (vdESPState.isLocalCaptured and vdESPState.isLocalCaptured(myChar)) then
            return false
        end
        if vdESPState.fleeKnockEXEnabled and vdESPState.fleeKnockEXBlocking then
            return false
        end

        if myHrp.Anchored or myChar:GetAttribute("AC_ServerAnchor") ~= nil then
            vdESPState.lastServerAnchorTick = tick()
            if myChar:GetAttribute("AC_ServerAnchor") ~= nil then
                vdESPState.lastACAnchorTick = tick()
            end
        end

        local horizDrift = Vector3.new(myHrp.Position.X - holdPos.X, 0, myHrp.Position.Z - holdPos.Z).Magnitude
        local recentAnchor = (tick() - math.max(vdESPState.lastServerAnchorTick or 0, vdESPState.lastACAnchorTick or 0)) < 1.2
        if horizDrift > 10.5 and recentAnchor then
            -- Release stale local hold if server anchored/rejected real body so Survivor POV matches Killer POV & retries cleanly
            vdESPState.autoFleeHoldPos = nil
            return false
        end

        if vdESPState.setMovementBypass then
            vdESPState.setMovementBypass(myChar, true)
        end
        if myHrp.CanCollide or myHrp.Anchored then
            unlockFleeConstraints(myChar, myHrp, false)
        end
        local realDist = (myHrp.Position - holdPos).Magnitude
        if realDist > (tol or 0.25) or myHrp.Anchored then
            myHrp.Anchored = false
            myHrp.AssemblyLinearVelocity = Vector3.zero
            myHrp.AssemblyAngularVelocity = Vector3.zero
            myHrp.CFrame = CFrame.new(holdPos)
            return false
        end
        myHrp.AssemblyLinearVelocity = Vector3.zero
        myHrp.AssemblyAngularVelocity = Vector3.zero
        return true
    end

    local function stopAutoFleeEngine(restoreSurface)
        vdESPState.autoFleeBlocking = false
        vdESPState.autoFleePauseUntil = 0
        vdESPState.autoFleeHoldPos = nil
        fleeTransiting = false
        fleePaused = false
        if fleeSteppedConn then pcall(function() fleeSteppedConn:Disconnect() end) fleeSteppedConn = nil end
        if fleeHeartbeatConn then pcall(function() fleeHeartbeatConn:Disconnect() end) fleeHeartbeatConn = nil end
        pcall(function()
            local myChar = player.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            local captured = myChar and ((vdESPState.isLocalCaptured and vdESPState.isLocalCaptured(myChar)) or isCharacterHooked(myChar))
            local otherHolding = ghostEXHoldPos ~= nil
                or vdESPState.rescueEXHoldPos ~= nil
                or vdESPState.autoLeverEXHoldPos ~= nil
                or vdESPState.fleeKnockHoldPos ~= nil
            if myChar and myHrp and not captured and not otherHolding then
                if restoreSurface and fleeGroundY and myHrp.Position.Y < (fleeGroundY - 0.5) then
                    myHrp.CFrame = CFrame.new(myHrp.Position.X, fleeGroundY + 3.2, myHrp.Position.Z)
                end
                unlockFleeConstraints(myChar, myHrp, true)
                if vdESPState.setMovementBypass then
                    vdESPState.setMovementBypass(myChar, false)
                end
                if unlockCameraAndMovement then
                    unlockCameraAndMovement()
                end
            end
        end)
        fleeGroundY = nil
    end

    local cachedSafeNodes = {}
    local cachedGenFloors = setmetatable({}, { __mode = "k" })
    local lastCacheRefreshAt = 0
    local cachedCharRef = nil

    local function buildMapRayParams()
        local exclude = {}
        local lobby = workspace:FindFirstChild("Lobby")
        if lobby then table.insert(exclude, lobby) end
        local cam = workspace.CurrentCamera
        if cam then table.insert(exclude, cam) end
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then
                table.insert(exclude, p.Character)
            end
        end
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude
        rp.FilterDescendantsInstances = exclude
        rp.IgnoreWater = true
        return rp
    end

    local function getCachedUndergroundDepth()
        return math.clamp(math.max(tonumber(ghostDepthOffset) or 7.0, 5.2), 5.2, 10.0)
    end

    local function computeGenUndergroundPoint(pt)
        local gm = (getGeneratorModel and getGeneratorModel(pt)) or pt.Parent
        local pos, floorY = vdESPState.computeGenUndergroundPoint(pt, gm, math.clamp(tonumber(ghostDepthOffset) or 7.0, 5.6, 7.6), cachedGenFloors[pt])
        if floorY and not cachedGenFloors[pt] then
            cachedGenFloors[pt] = floorY
        end
        return pos, floorY or (pt.Position.Y - 3.5)
    end

    local function refreshSafeNodeCache(refPos)
        local rp = buildMapRayParams()
        local anchors = {}
        local minY, maxY = math.huge, -math.huge

        local function pushAnchor(pos)
            table.insert(anchors, pos)
            if pos.Y < minY then minY = pos.Y end
            if pos.Y > maxY then maxY = pos.Y end
        end

        pcall(function()
            for _, pt in ipairs(CollectionService:GetTagged("GeneratorPoint")) do
                if pt:IsA("BasePart") and pt:IsDescendantOf(workspace) and not pt:FindFirstAncestor("Lobby") then
                    pushAnchor(pt.Position)
                    if not cachedGenFloors[pt] and vdESPState.findFloorYBelow then
                        local gm = (getGeneratorModel and getGeneratorModel(pt)) or pt.Parent
                        local fy = vdESPState.findFloorYBelow(pt.Position.X, pt.Position.Y, pt.Position.Z, gm)
                        if fy then cachedGenFloors[pt] = fy end
                    end
                end
            end
            for _, pt in ipairs(CollectionService:GetTagged("UnhookPoint")) do
                if pt:IsA("BasePart") and pt:IsDescendantOf(workspace) and not pt:FindFirstAncestor("Lobby") then
                    pushAnchor(pt.Position)
                end
            end
            local map = workspace:FindFirstChild("Map") or workspace:FindFirstChild("map")
            if map then
                for _, folderName in ipairs({ "Generators", "new Generators", "generators", "Hooks", "Exits", "ExitGates", "Gates" }) do
                    local f = map:FindFirstChild(folderName)
                    if f then
                        for _, child in ipairs(f:GetChildren()) do
                            local p = child:IsA("BasePart") and child or (child:IsA("Model") and (child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")))
                            if p then pushAnchor(p.Position) end
                        end
                    end
                end
            end
        end)

        if minY == math.huge then
            local baseY = refPos and refPos.Y or 0
            minY = baseY - 35
            maxY = baseY + 35
        end

        local nodes = {}
        local function sampleNode(x, yHint, z)
            local hit = workspace:Raycast(Vector3.new(x, yHint + 28, z), Vector3.new(0, -85, 0), rp)
            if not hit or not hit.Instance then return end
            if not hit.Instance.CanCollide or hit.Instance:FindFirstAncestor("Lobby") then return end
            if hit.Normal.Y < 0.65 then return end
            if hit.Position.Y < (minY - 18) or hit.Position.Y > (maxY + 38) then return end
            local upHit = workspace:Raycast(hit.Position + Vector3.new(0, 1.5, 0), Vector3.new(0, 4.2, 0), rp)
            if upHit and upHit.Instance and upHit.Instance.CanCollide then return end
            table.insert(nodes, {
                groundPos = hit.Position + Vector3.new(0, 3.2, 0),
                floorY = hit.Position.Y
            })
        end

        for i = 1, math.min(#anchors, 32) do
            local a = anchors[i]
            sampleNode(a.X + 2.5, a.Y, a.Z + 2.5)
        end

        local center = refPos or (anchors[1] or Vector3.new(0, 10, 0))
        for _, rad in ipairs({ 75, 130, 195, 260 }) do
            for aIdx = 0, 7 do
                local ang = aIdx * (math.pi / 4)
                sampleNode(center.X + math.cos(ang) * rad, center.Y, center.Z + math.sin(ang) * rad)
            end
        end

        if #nodes > 0 then
            cachedSafeNodes = nodes
            lastCacheRefreshAt = tick()
        end
    end

    local function pickFastUndergroundTarget(myChar, myPos, kPos, minSafeDist)
        -- 1. If Underground Repair Generator EX is active, prefer an unfinished generator strictly far from Killer
        if ghostRepairEXEnabled and not vdESPState.ghostEXPaused then
            local bestGenPos, bestGenFloorY, bestGenKDist = nil, nil, -1
            pcall(function()
                for _, pt in ipairs(CollectionService:GetTagged("GeneratorPoint")) do
                    if pt:IsA("BasePart") and pt:IsDescendantOf(workspace) and not pt:IsDescendantOf(myChar) and not pt:FindFirstAncestor("Lobby") then
                        local done = isGeneratorCompleted and isGeneratorCompleted(pt)
                        if not done then
                            local kd = (pt.Position - kPos).Magnitude
                            if kd > bestGenKDist then
                                bestGenKDist = kd
                                bestGenPos, bestGenFloorY = computeGenUndergroundPoint(pt)
                            end
                        end
                    end
                end
            end)
            if bestGenPos and bestGenKDist >= (minSafeDist + 16) then
                return bestGenPos, bestGenKDist, bestGenFloorY
            end
        end

        -- 2. Otherwise use pre-cached floor nodes in < 0.05ms (refresh once only if completely empty)
        if #cachedSafeNodes == 0 then
            refreshSafeNodeCache(myPos)
        end

        local depth = getCachedUndergroundDepth()
        local bestNode, bestKDist = nil, -1
        for _, node in ipairs(cachedSafeNodes) do
            local kd = (node.groundPos - kPos).Magnitude
            if kd > bestKDist then
                bestKDist = kd
                bestNode = node
            end
        end

        if bestNode then
            local targetPos = Vector3.new(bestNode.groundPos.X, bestNode.floorY - depth, bestNode.groundPos.Z)
            return targetPos, bestKDist, bestNode.floorY
        end

        -- 3. Emergency radial geometric fallback (zero raycast fail-safe)
        local flatAway = Vector3.new(myPos.X - kPos.X, 0, myPos.Z - kPos.Z)
        flatAway = (flatAway.Magnitude >= 0.1) and flatAway.Unit or Vector3.new(1, 0, 0)
        local escapeDist = math.max(minSafeDist + 35, 135)
        local fallbackXZ = Vector3.new(kPos.X + flatAway.X * escapeDist, myPos.Y, kPos.Z + flatAway.Z * escapeDist)
        local floorY = (vdESPState.findFloorYBelow and vdESPState.findFloorYBelow(fallbackXZ.X, myPos.Y, fallbackXZ.Z, nil)) or (myPos.Y - 3.0)
        local targetPos = Vector3.new(fallbackXZ.X, floorY - depth, fallbackXZ.Z)
        return targetPos, (targetPos - kPos).Magnitude, floorY
    end

    local function cancelActiveRepairImmediately(myChar)
        local wasRepairing = false
        pcall(function()
            if myChar:GetAttribute("isRepairing") == true then
                wasRepairing = true
                myChar:SetAttribute("isRepairing", false)
            end
            local hrp = myChar:FindFirstChild("HumanoidRootPart")
            if hrp and CollectionService:HasTag(hrp, "doing action") then
                wasRepairing = true
            end
            if hrp then CollectionService:RemoveTag(hrp, "doing action") end
            CollectionService:RemoveTag(myChar, "doing action")
            local remotes = getVDRemotes and getVDRemotes()
            if lastCapturedGenPoint and remotes and remotes.Generator and remotes.Generator:FindFirstChild("RepairEvent") then
                wasRepairing = true
                remotes.Generator.RepairEvent:FireServer(lastCapturedGenPoint, false, nil, lastCapturedRepairRequestId or HttpService:GenerateGUID(false), myChar)
            end
        end)
        return wasRepairing
    end

    local fleePendingGlide = false

    local function buryLocallyOnDangerFrame(myChar, myHrp, kHrp)
        local wasRepairing = cancelActiveRepairImmediately(myChar)
        vdESPState.autoFleeBlocking = true
        vdESPState.autoFleePauseUntil = tick() + 1.5
        ghostEXHoldPos = nil
        fleePendingGlide = true

        local curPos = myHrp.Position
        local localFloorY = (vdESPState.findFloorYBelow and vdESPState.findFloorYBelow(curPos.X, curPos.Y + 4, curPos.Z, nil)) or (curPos.Y - 3.0)
        fleeGroundY = localFloorY
        if vdESPState.setMovementBypass then
            vdESPState.setMovementBypass(myChar, true)
        end
        unlockFleeConstraints(myChar, myHrp, false)

        -- Only do immediate emergency step if Killer is in melee danger, NOT actively stuck in server Repair lock, and above ground or close
        local recentAnchor = (tick() - math.max(vdESPState.lastServerAnchorTick or 0, vdESPState.lastACAnchorTick or 0)) < 2.0
        if not wasRepairing and not recentAnchor and kHrp and kHrp.Parent then
            local kPos = kHrp.Position
            local curKDist = (curPos - kPos).Magnitude
            if curKDist <= 26 then
                local awayXZ = Vector3.new(curPos.X - kPos.X, 0, curPos.Z - kPos.Z)
                if awayXZ.Magnitude < 0.8 then
                    local backVec = -kHrp.CFrame.LookVector
                    awayXZ = Vector3.new(backVec.X, 0, backVec.Z)
                end
                if awayXZ.Magnitude >= 0.05 then
                    local evadeDir = awayXZ.Unit
                    local stepOut = math.clamp(22 - curKDist, 14, 19)
                    local evadeX = curPos.X + evadeDir.X * stepOut
                    local evadeZ = curPos.Z + evadeDir.Z * stepOut
                    local evadeFY = (vdESPState.findFloorYBelow and vdESPState.findFloorYBelow(evadeX, curPos.Y + 4, evadeZ, nil)) or localFloorY
                    local depth = getCachedUndergroundDepth()
                    local buriedY = math.min(curPos.Y, evadeFY - depth)
                    if (curPos.Y - buriedY) > 6.5 then buriedY = curPos.Y - 6.5 end
                    myHrp.Anchored = false
                    myHrp.AssemblyLinearVelocity = Vector3.zero
                    myHrp.AssemblyAngularVelocity = Vector3.zero
                    myHrp.CFrame = CFrame.new(evadeX, buriedY, evadeZ)
                end
            elseif curPos.Y > (localFloorY - 2.2) then
                -- Drop cleanly below surface without pinning autoFleeHoldPos at old generator
                local depth = getCachedUndergroundDepth()
                local buriedY = math.max(curPos.Y - 5.5, localFloorY - depth)
                myHrp.Anchored = false
                myHrp.AssemblyLinearVelocity = Vector3.zero
                myHrp.AssemblyAngularVelocity = Vector3.zero
                myHrp.CFrame = CFrame.new(curPos.X, buriedY, curPos.Z)
            end
        end
    end

    local function startAutoFleeThread()
        stopAutoFleeEngine(false)
        fleePendingGlide = false
        vdESPState.autoFleeSession = (vdESPState.autoFleeSession or 0) + 1
        local mySession = vdESPState.autoFleeSession
        local function isFleeValid()
            return vdESPState.autoFleeEnabled == true and mySession == vdESPState.autoFleeSession and scriptRunning
        end

        fleeSteppedConn = RunService.Stepped:Connect(function()
            if not isFleeValid() then
                if fleeSteppedConn then pcall(function() fleeSteppedConn:Disconnect() end) fleeSteppedConn = nil end
                return
            end
            pcall(function() enforceFleeUndergroundPos(0.25) end)
        end)

        -- Zero-latency per-frame danger detector: cancels repair & drops/evades immediately without tripping 60s server lockout
        fleeHeartbeatConn = RunService.Heartbeat:Connect(function()
            if not isFleeValid() then
                if fleeHeartbeatConn then pcall(function() fleeHeartbeatConn:Disconnect() end) fleeHeartbeatConn = nil end
                return
            end
            pcall(function()
                enforceFleeUndergroundPos(0.25)
                if fleePaused or fleeTransiting or vdESPState.autoFleeBlocking then return end
                if isPlayerKiller and isPlayerKiller() then return end
                local myChar = player.Character
                local hum = myChar and myChar:FindFirstChildOfClass("Humanoid")
                local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                if not myChar or not myHrp or not hum or hum.Health <= 0 then return end
                if (isEntityInLobbyOrSpectating and isEntityInLobbyOrSpectating(myChar, player))
                    or isCharacterHooked(myChar)
                    or isCharacterKnocked(myChar)
                    or (vdESPState.isLocalCaptured and vdESPState.isLocalCaptured(myChar)) then
                    return
                end
                local killer = getKiller and getKiller()
                local kHrp = killer and killer:FindFirstChild("HumanoidRootPart")
                if not kHrp then return end

                local targetDist = vdESPState.autoFleeDistance or 100
                if (myHrp.Position - kHrp.Position).Magnitude <= targetDist then
                    buryLocallyOnDangerFrame(myChar, myHrp, kHrp)
                end
            end)
        end)

        -- 0.0001s real-position underground checker while fleeing/hiding stationary
        task.spawn(function()
            while isFleeValid() do
                pcall(function() enforceFleeUndergroundPos(0.25) end)
                task.wait(0.0001)
            end
        end)

        -- Background cache & anti-rollback smooth underground glide manager
        task.spawn(function()
            local lastFleeAt = 0
            local stayUndergroundUntil = 0
            local fleeFailCount = 0

            while isFleeValid() do
                local ok = pcall(function()
                    if isPlayerKiller and isPlayerKiller() then
                        vdESPState.autoFleeBlocking = false
                        vdESPState.autoFleeHoldPos = nil
                        fleePendingGlide = false
                        fleeGroundY = nil
                        fleeFailCount = 0
                        task.wait(0.25)
                        return
                    end

                    local myChar = player.Character
                    local hum = myChar and myChar:FindFirstChildOfClass("Humanoid")
                    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                    if not myChar or not myHrp or not hum or hum.Health <= 0 then
                        vdESPState.autoFleeBlocking = false
                        vdESPState.autoFleeHoldPos = nil
                        fleePendingGlide = false
                        fleeGroundY = nil
                        fleeFailCount = 0
                        task.wait(0.15)
                        return
                    end

                    if cachedCharRef ~= myChar then
                        cachedCharRef = myChar
                        cachedSafeNodes = {}
                        cachedGenFloors = setmetatable({}, { __mode = "k" })
                    end

                    if (isEntityInLobbyOrSpectating and isEntityInLobbyOrSpectating(myChar, player))
                        or isCharacterHooked(myChar)
                        or isCharacterKnocked(myChar)
                        or (vdESPState.isLocalCaptured and vdESPState.isLocalCaptured(myChar)) then
                        vdESPState.autoFleeBlocking = false
                        vdESPState.autoFleeHoldPos = nil
                        fleePendingGlide = false
                        fleeGroundY = nil
                        fleeFailCount = 0
                        task.wait(0.15)
                        return
                    end

                    if (#cachedSafeNodes == 0 or (tick() - lastCacheRefreshAt) >= 2.0) and not vdESPState.autoFleeBlocking then
                        refreshSafeNodeCache(myHrp.Position)
                    end

                    local killer = getKiller and getKiller()
                    local kHrp = killer and killer:FindFirstChild("HumanoidRootPart")
                    if not kHrp then
                        vdESPState.autoFleeBlocking = false
                        fleePendingGlide = false
                        if vdESPState.autoFleeHoldPos then
                            local holdGY = fleeGroundY
                            vdESPState.autoFleeHoldPos = nil
                            fleeGroundY = nil
                            if holdGY and myHrp.Position.Y < (holdGY - 0.5) and not ghostEXHoldPos and not vdESPState.rescueEXHoldPos and not vdESPState.autoLeverEXHoldPos then
                                myHrp.CFrame = CFrame.new(myHrp.Position.X, holdGY + 3.2, myHrp.Position.Z)
                                unlockFleeConstraints(myChar, myHrp, true)
                                if vdESPState.setMovementBypass then vdESPState.setMovementBypass(myChar, false) end
                            end
                        end
                        task.wait(0.10)
                        return
                    end

                    local targetDist = vdESPState.autoFleeDistance or 100
                    local curDist = (myHrp.Position - kHrp.Position).Magnitude

                    if curDist <= targetDist then
                        vdESPState.autoFleeBlocking = true
                        vdESPState.autoFleePauseUntil = tick() + 1.5
                        ghostEXHoldPos = nil

                        local now = tick()
                        local holdPos = vdESPState.autoFleeHoldPos
                        local drifted = (not holdPos) or ((myHrp.Position - holdPos).Magnitude > 6.5)

                        local shouldMove = fleePendingGlide or drifted
                        if not shouldMove and (now - lastFleeAt) >= 0.85 then
                            local candPos, candDist = pickFastUndergroundTarget(myChar, myHrp.Position, kHrp.Position, targetDist)
                            if candPos and candDist > (curDist + 28) and (holdPos - candPos).Magnitude > 22 then
                                shouldMove = true
                            end
                        end

                        if shouldMove then
                            local exitedRepair = cancelActiveRepairImmediately(myChar)
                            if exitedRepair then
                                -- Clear RepairEvent / doing-action server lock before moving so server never rejects flee
                                task.wait(0.05)
                                cancelActiveRepairImmediately(myChar)
                            end
                            if not isFleeValid() or isCharacterKnocked(myChar) or (vdESPState.isLocalCaptured and vdESPState.isLocalCaptured(myChar)) then
                                return
                            end

                            local kNow = getKiller and getKiller()
                            local kHrpNow = kNow and kNow:FindFirstChild("HumanoidRootPart") or kHrp
                            local undergroundPos, safeKDist, floorY = pickFastUndergroundTarget(myChar, myHrp.Position, kHrpNow.Position, targetDist)
                            if not undergroundPos then
                                fleeFailCount = fleeFailCount + 1
                            else
                                fleePendingGlide = false
                                fleeTransiting = true
                                vdESPState.autoFleeHoldPos = nil
                                local landed = true
                                if vdESPState.microTransitTo then
                                    landed = vdESPState.microTransitTo(myChar, myHrp, undergroundPos, function()
                                        return isFleeValid() and not isCharacterKnocked(myChar) and not (vdESPState.isLocalCaptured and vdESPState.isLocalCaptured(myChar))
                                    end, true, 6.5)
                                end
                                fleeTransiting = false

                                if not isFleeValid() or isCharacterKnocked(myChar) or (vdESPState.isLocalCaptured and vdESPState.isLocalCaptured(myChar)) then
                                    return
                                end

                                if landed and myHrp.Parent and (myHrp.Position - undergroundPos).Magnitude <= 6.5 then
                                    fleeGroundY = floorY
                                    vdESPState.autoFleeHoldPos = undergroundPos
                                    fleeFailCount = 0
                                    lastFleeAt = tick()
                                    stayUndergroundUntil = tick() + 0.30
                                    vdESPState.autoFleePauseUntil = tick() + 0.8
                                else
                                    fleeFailCount = fleeFailCount + 1
                                    vdESPState.autoFleeHoldPos = nil
                                    fleeGroundY = nil
                                    if fleeFailCount >= 2 then
                                        fleePaused = true
                                        -- Safely lift above local floor if partially buried before restoring collisions (prevents void falls!)
                                        local curP = myHrp.Position
                                        local curFY = vdESPState.findFloorYBelow and vdESPState.findFloorYBelow(curP.X, curP.Y + 14, curP.Z, nil)
                                        if curFY and curP.Y < (curFY - 0.5) then
                                            myHrp.CFrame = CFrame.new(curP.X, curFY + 3.2, curP.Z)
                                        end
                                        unlockFleeConstraints(myChar, myHrp, true)
                                        if vdESPState.setMovementBypass then vdESPState.setMovementBypass(myChar, false) end
                                        local pauseEnd = tick() + 2.0
                                        while tick() < pauseEnd and isFleeValid() and not isCharacterKnocked(myChar) and not (vdESPState.isLocalCaptured and vdESPState.isLocalCaptured(myChar)) do
                                            task.wait(0.05)
                                        end
                                        fleeFailCount = 0
                                        fleePaused = false
                                        lastFleeAt = tick()
                                    else
                                        -- Keep CanCollide = false and retry glide calmly without triggering 60s lock
                                        unlockFleeConstraints(myChar, myHrp, false)
                                        task.wait(0.08)
                                    end
                                end
                            end
                        end
                    elseif curDist > (targetDist + 5) then
                        fleePendingGlide = false
                        if tick() >= stayUndergroundUntil then
                            vdESPState.autoFleeBlocking = false
                            if vdESPState.autoFleeHoldPos ~= nil then
                                -- Hold underground briefly so Repair EX / Lever EX / Rescue EX can take over seamlessly
                                local handoffWait = tick() + 0.25
                                local handedOff = false
                                while tick() < handoffWait and isFleeValid() do
                                    local kNow = getKiller and getKiller()
                                    local kHrpNow = kNow and kNow:FindFirstChild("HumanoidRootPart")
                                    if kHrpNow and (myHrp.Position - kHrpNow.Position).Magnitude <= targetDist then
                                        vdESPState.autoFleeBlocking = true
                                        return
                                    end
                                    if ghostEXHoldPos ~= nil or vdESPState.rescueEXHoldPos ~= nil or vdESPState.autoLeverEXHoldPos ~= nil or vdESPState.fleeKnockHoldPos ~= nil then
                                        handedOff = true
                                        break
                                    end
                                    task.wait(0.03)
                                end
                                local savedGY = fleeGroundY
                                vdESPState.autoFleeHoldPos = nil
                                fleeGroundY = nil
                                if not handedOff then
                                    if savedGY and myHrp.Position.Y < (savedGY - 0.5) then
                                        myHrp.CFrame = CFrame.new(myHrp.Position.X, savedGY + 3.2, myHrp.Position.Z)
                                    end
                                    unlockFleeConstraints(myChar, myHrp, true)
                                    if vdESPState.setMovementBypass then
                                        vdESPState.setMovementBypass(myChar, false)
                                    end
                                    if unlockCameraAndMovement then
                                        pcall(unlockCameraAndMovement)
                                    end
                                end
                            end
                        end
                    end
                end)
                task.wait(ok and 0.015 or 0.05)
            end
            stopAutoFleeEngine(true)
        end)
    end

    vdESPState.autoFleeToggle = V_SurvivorEXSection:Toggle({
        Title = "Auto Flee EX",
        Description = "Flees underground whenever Killer is within range (100 studs default, 2s reset after 2 fails)",
        Default = false,
        Callback = function(v)
            vdESPState.autoFleeEnabled = v
            if v then
                startAutoFleeThread()
            else
                vdESPState.autoFleeSession = (vdESPState.autoFleeSession or 0) + 1
                stopAutoFleeEngine(true)
            end
        end
    })

    V_SurvivorEXSection:Slider({
        Title = "Auto Flee Distance",
        Description = "Trigger distance in studs to automatically flee from Killer (1 - 300 studs, default 100)",
        Step = 1,
        Value = {
            Min = 1,
            Max = 300,
            Default = 100,
        },
        Callback = function(val)
            vdESPState.autoFleeDistance = tonumber(val) or 100
        end
    })
end)

-- ============================================================
-- FLEE KNOCK EX (FLEE FAR FROM KILLER ON KNOCKDOWN + SELF RESCUE)
-- ============================================================
pcall(function()
    local CollectionService = game:GetService("CollectionService")
    local fleeKnockSteppedConn = nil
    local fleeKnockHeartbeatConn = nil
    local fleeKnockTransiting = false
    local fleeKnockPaused = false
    local fleeKnockGroundY = nil

    local function unlockFleeKnockMotion(myChar, myHrp, restoreCollision)
        pcall(function()
            if myHrp then
                if myHrp.Anchored then myHrp.Anchored = false end
                myHrp.AssemblyLinearVelocity = Vector3.zero
                myHrp.AssemblyAngularVelocity = Vector3.zero
                pcall(function() CollectionService:RemoveTag(myHrp, "doing action") end)
            end
            if myChar then
                if myChar:GetAttribute("isRepairing") == true then myChar:SetAttribute("isRepairing", false) end
                if myChar:GetAttribute("isUnhooking") == true then myChar:SetAttribute("isUnhooking", false) end
                if myChar:GetAttribute("isExiting") == true then myChar:SetAttribute("isExiting", false) end
                if myChar:GetAttribute("Rooted") == true then myChar:SetAttribute("Rooted", false) end
                if myChar:GetAttribute("Immobile") == true then myChar:SetAttribute("Immobile", false) end
                if myChar:GetAttribute("AC_ServerAnchor") ~= nil then myChar:SetAttribute("AC_ServerAnchor", nil) end
                pcall(function() CollectionService:RemoveTag(myChar, "doing action") end)
                for _, part in ipairs(myChar:GetDescendants()) do
                    if part:IsA("BasePart") then
                        if restoreCollision ~= false then
                            if part.Name == "HumanoidRootPart" or part.Name == "Torso" or part.Name == "UpperTorso" or part.Name == "LowerTorso" then
                                part.CanCollide = true
                            end
                        elseif part.CanCollide then
                            part.CanCollide = false
                        end
                    end
                end
            end
        end)
    end

    local function enforceFleeKnockUndergroundPos(tol)
        if not vdESPState.fleeKnockEXEnabled or fleeKnockTransiting or fleeKnockPaused then return false end
        local holdPos = vdESPState.fleeKnockHoldPos
        if not holdPos then return false end
        local myChar = player.Character
        local hum = myChar and myChar:FindFirstChildOfClass("Humanoid")
        local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myChar or not myHrp or not hum then return false end
        if isCharacterHooked(myChar) or (vdESPState.isLocalCaptured and vdESPState.isLocalCaptured(myChar)) then
            return false
        end
        if not (isCharacterKnocked and isCharacterKnocked(myChar)) then
            return false
        end

        if vdESPState.setMovementBypass then
            vdESPState.setMovementBypass(myChar, true)
        end
        if myHrp.CanCollide or myHrp.Anchored then
            unlockFleeKnockMotion(myChar, myHrp, false)
        end
        if (myHrp.Position - holdPos).Magnitude > (tol or 0.25) or myHrp.Anchored then
            myHrp.Anchored = false
            myHrp.AssemblyLinearVelocity = Vector3.zero
            myHrp.AssemblyAngularVelocity = Vector3.zero
            myHrp.CFrame = CFrame.new(holdPos)
            return false
        end
        myHrp.AssemblyLinearVelocity = Vector3.zero
        myHrp.AssemblyAngularVelocity = Vector3.zero
        return true
    end

    local function releaseFleeKnockUnderground(restoreSurface)
        local holdGY = fleeKnockGroundY
        local wasHolding = vdESPState.fleeKnockHoldPos ~= nil
        vdESPState.fleeKnockHoldPos = nil
        fleeKnockGroundY = nil
        fleeKnockTransiting = false
        fleeKnockPaused = false
        if not wasHolding then return end
        pcall(function()
            local myChar = player.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            local captured = myChar and ((vdESPState.isLocalCaptured and vdESPState.isLocalCaptured(myChar)) or isCharacterHooked(myChar))
            local otherHolding = ghostEXHoldPos ~= nil
                or vdESPState.autoFleeHoldPos ~= nil
                or vdESPState.rescueEXHoldPos ~= nil
                or vdESPState.autoLeverEXHoldPos ~= nil
            if myChar and myHrp and not captured and not otherHolding then
                if restoreSurface and holdGY and myHrp.Position.Y < (holdGY - 0.5) then
                    myHrp.CFrame = CFrame.new(myHrp.Position.X, holdGY + 3.2, myHrp.Position.Z)
                end
                unlockFleeKnockMotion(myChar, myHrp, true)
                if vdESPState.setMovementBypass then
                    vdESPState.setMovementBypass(myChar, false)
                end
            end
        end)
    end

    local function stopFleeKnockEngine(restoreSurface)
        vdESPState.fleeKnockEXBlocking = false
        if fleeKnockSteppedConn then pcall(function() fleeKnockSteppedConn:Disconnect() end) fleeKnockSteppedConn = nil end
        if fleeKnockHeartbeatConn then pcall(function() fleeKnockHeartbeatConn:Disconnect() end) fleeKnockHeartbeatConn = nil end
        releaseFleeKnockUnderground(restoreSurface)
    end

    local function fleeFarUndergroundNow(myChar, myHrp, kHrp, minCooldown, lastFleeAt, requireImprovement, isSessionValid)
        if not myChar or not myHrp or not kHrp or not vdESPState.findFurthestSafeGround then
            return "skip", lastFleeAt
        end
        local now = tick()
        if (now - lastFleeAt) < (minCooldown or 0.4) then
            return "skip", lastFleeAt
        end

        local curDist = (myHrp.Position - kHrp.Position).Magnitude
        local farPos, farDist = vdESPState.findFurthestSafeGround(myChar, myHrp.Position, kHrp.Position)
        if not farPos then
            return "fail", lastFleeAt
        end
        if requireImprovement and farDist <= (curDist + 12) then
            return "skip", lastFleeAt
        end

        local floorY = (vdESPState.findFloorYBelow and vdESPState.findFloorYBelow(farPos.X, farPos.Y, farPos.Z, nil)) or (farPos.Y - 3.0)
        local depth = math.clamp(math.max(tonumber(ghostDepthOffset) or 7.0, 5.2), 5.2, 9.5)
        local undergroundFarPos = Vector3.new(farPos.X, floorY - depth, farPos.Z)

        fleeKnockTransiting = true
        vdESPState.fleeKnockHoldPos = nil
        unlockFleeKnockMotion(myChar, myHrp, false)
        local arrived = true
        if vdESPState.microTransitTo then
            arrived = vdESPState.microTransitTo(myChar, myHrp, undergroundFarPos, function()
                return isSessionValid()
                    and not isCharacterHooked(myChar)
                    and not (vdESPState.isLocalCaptured and vdESPState.isLocalCaptured(myChar))
            end, true, 6.5)
        else
            myHrp.CFrame = CFrame.new(undergroundFarPos)
        end

        if not isSessionValid() or isCharacterHooked(myChar) or (vdESPState.isLocalCaptured and vdESPState.isLocalCaptured(myChar)) then
            fleeKnockTransiting = false
            return "skip", now
        end

        fleeKnockGroundY = floorY
        vdESPState.fleeKnockHoldPos = undergroundFarPos
        fleeKnockTransiting = false

        local settleEnd = tick() + 0.06
        while tick() < settleEnd and isSessionValid() do
            enforceFleeKnockUndergroundPos(0.25)
            task.wait(0.0001)
        end

        if arrived and myHrp.Parent and (myHrp.Position - undergroundFarPos).Magnitude <= 6.5 then
            return "ok", tick()
        end

        vdESPState.fleeKnockHoldPos = nil
        fleeKnockGroundY = nil
        unlockFleeKnockMotion(myChar, myHrp, true)
        if vdESPState.setMovementBypass then
            vdESPState.setMovementBypass(myChar, false)
        end
        return "fail", tick()
    end

    local function startFleeKnockEXThread()
        stopFleeKnockEngine(false)
        vdESPState.fleeKnockEXSession = (vdESPState.fleeKnockEXSession or 0) + 1
        local mySession = vdESPState.fleeKnockEXSession
        local function isSessionValid()
            return vdESPState.fleeKnockEXEnabled == true and mySession == vdESPState.fleeKnockEXSession and scriptRunning
        end

        fleeKnockSteppedConn = RunService.Stepped:Connect(function()
            if not isSessionValid() then
                if fleeKnockSteppedConn then pcall(function() fleeKnockSteppedConn:Disconnect() end) fleeKnockSteppedConn = nil end
                return
            end
            pcall(function() enforceFleeKnockUndergroundPos(0.25) end)
        end)

        fleeKnockHeartbeatConn = RunService.Heartbeat:Connect(function()
            if not isSessionValid() then
                if fleeKnockHeartbeatConn then pcall(function() fleeKnockHeartbeatConn:Disconnect() end) fleeKnockHeartbeatConn = nil end
                return
            end
            pcall(function() enforceFleeKnockUndergroundPos(0.25) end)
        end)

        task.spawn(function()
            while isSessionValid() do
                pcall(function() enforceFleeKnockUndergroundPos(0.25) end)
                task.wait(0.0001)
            end
        end)

        task.spawn(function()
            local healGuid = nil
            local wasSelfHealing = false
            local fledThisKnock = false
            local lastFleeAt = 0
            local lastHealPulse = 0
            local knockTeleportFails = 0

            local function stopSelfHealState(myChar, remotes)
                if not wasSelfHealing then return end
                wasSelfHealing = false
                pcall(function()
                    if myChar and myChar.Parent then
                        myChar:SetAttribute("isHealing", false)
                        local hrp = myChar:FindFirstChild("HumanoidRootPart")
                        if remotes and remotes.Healing then
                            if remotes.Healing:FindFirstChild("HealEvent") then
                                if hrp then
                                    remotes.Healing.HealEvent:FireServer(hrp, false, healGuid or HttpService:GenerateGUID(false), myChar)
                                end
                                remotes.Healing.HealEvent:FireServer(myChar, false, healGuid or HttpService:GenerateGUID(false), myChar)
                            end
                            if remotes.Healing:FindFirstChild("Reset") then
                                remotes.Healing.Reset:FireServer(myChar)
                            end
                        end
                    end
                end)
                healGuid = nil
            end

            while isSessionValid() do
                local ok = pcall(function()
                    if isPlayerKiller and isPlayerKiller() then
                        vdESPState.fleeKnockEXBlocking = false
                        releaseFleeKnockUnderground(true)
                        task.wait(0.3)
                        return
                    end

                    local myChar = player.Character
                    local hum = myChar and myChar:FindFirstChildOfClass("Humanoid")
                    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                    if not myChar or not myHrp or not hum then
                        vdESPState.fleeKnockEXBlocking = false
                        vdESPState.fleeKnockHoldPos = nil
                        fleeKnockGroundY = nil
                        wasSelfHealing = false
                        fledThisKnock = false
                        knockTeleportFails = 0
                        healGuid = nil
                        task.wait(0.2)
                        return
                    end

                    if isEntityInLobbyOrSpectating and isEntityInLobbyOrSpectating(myChar, player) then
                        vdESPState.fleeKnockEXBlocking = false
                        releaseFleeKnockUnderground(false)
                        wasSelfHealing = false
                        fledThisKnock = false
                        knockTeleportFails = 0
                        task.wait(0.25)
                        return
                    end

                    local remotes = getVDRemotes and getVDRemotes()
                    local captured = (vdESPState.isLocalCaptured and vdESPState.isLocalCaptured(myChar))
                        or (isCharacterHooked and isCharacterHooked(myChar))
                        or myChar:GetAttribute("IsCarried") == true
                        or myChar:GetAttribute("BeingCarried") == true

                    if captured then
                        -- Chained, hooked, or carried by Killer: DO NOT try to self-unhook or escape; wait for teammates to rescue
                        vdESPState.fleeKnockEXBlocking = true
                        ghostEXHoldPos = nil
                        vdESPState.autoFleeHoldPos = nil
                        vdESPState.rescueEXHoldPos = nil
                        vdESPState.rescueEXWantsPriority = false
                        vdESPState.autoLeverEXHoldPos = nil
                        vdESPState.autoLeverEXWantsPriority = false
                        vdESPState.fleeKnockHoldPos = nil
                        fleeKnockGroundY = nil
                        fledThisKnock = false
                        knockTeleportFails = 0
                        stopSelfHealState(myChar, remotes)
                        task.wait(0.15)
                        return
                    end

                    local knocked = isCharacterKnocked and isCharacterKnocked(myChar) and (hum.Health >= 0)
                    local killer = getKiller and getKiller()
                    local kHrp = killer and killer:FindFirstChild("HumanoidRootPart")

                    if knocked then
                        vdESPState.fleeKnockEXBlocking = true
                        ghostEXHoldPos = nil
                        vdESPState.autoFleeHoldPos = nil
                        vdESPState.rescueEXHoldPos = nil
                        vdESPState.rescueEXWantsPriority = false
                        vdESPState.autoLeverEXHoldPos = nil
                        vdESPState.autoLeverEXWantsPriority = false

                        -- 1. Flee underground far away from Killer on knockdown (and re-flee underground if Killer closes within safe range)
                        if kHrp then
                            local curDist = (myHrp.Position - kHrp.Position).Magnitude
                            local safeKnockDist = math.max(vdESPState.autoFleeDistance or 100, 65)
                            local lostUnderground = vdESPState.fleeKnockHoldPos == nil or (myHrp.Position - vdESPState.fleeKnockHoldPos).Magnitude > 6.5
                            if (not fledThisKnock) or curDist <= safeKnockDist or lostUnderground then
                                local cooldown = fledThisKnock and ((curDist <= 40) and 0.4 or 0.9) or 0.1
                                local status, newTime = fleeFarUndergroundNow(myChar, myHrp, kHrp, cooldown, lastFleeAt, fledThisKnock and not lostUnderground, isSessionValid)
                                if status == "ok" then
                                    lastFleeAt = newTime
                                    fledThisKnock = true
                                    knockTeleportFails = 0
                                elseif status == "fail" then
                                    lastFleeAt = newTime
                                    knockTeleportFails = knockTeleportFails + 1
                                    if knockTeleportFails >= 2 then
                                        fleeKnockPaused = true
                                        local pauseEnd = tick() + 2.0
                                        while tick() < pauseEnd and isSessionValid() and isCharacterKnocked(myChar) and not (vdESPState.isLocalCaptured and vdESPState.isLocalCaptured(myChar)) do
                                            task.wait(0.05)
                                        end
                                        knockTeleportFails = 0
                                        fleeKnockPaused = false
                                    end
                                end
                            end
                        end

                        -- 2. Self-Rescue: self-heal / recover while knocked down underground
                        if (tick() - lastHealPulse) >= 0.65 then
                            lastHealPulse = tick()
                            healGuid = healGuid or HttpService:GenerateGUID(false)
                            wasSelfHealing = true
                            lastCapturedHealRequestId = healGuid
                            pcall(function()
                                myChar:SetAttribute("isHealing", true)
                                CollectionService:RemoveTag(myHrp, "doing action")
                                CollectionService:RemoveTag(myChar, "doing action")
                            end)

                            if remotes and remotes.Healing then
                                if remotes.Healing:FindFirstChild("HealEvent") then
                                    pcall(function()
                                        remotes.Healing.HealEvent:FireServer(myHrp, true, healGuid, myChar)
                                        remotes.Healing.HealEvent:FireServer(myChar, true, healGuid, myChar)
                                    end)
                                end
                                if remotes.Healing:FindFirstChild("SkillCheckResultEvent") then
                                    pcall(function()
                                        remotes.Healing.SkillCheckResultEvent:FireServer("success", 1, myChar, healGuid, myChar)
                                    end)
                                end
                            end

                            if typeof(fireproximityprompt) == "function" then
                                pcall(function()
                                    for _, desc in ipairs(myChar:GetDescendants()) do
                                        if desc:IsA("ProximityPrompt") and desc.Enabled then
                                            pcall(fireproximityprompt, desc)
                                        end
                                    end
                                end)
                            end
                        end
                    else
                        -- Recovered cleanly (only surface once, handing off if another EX claims underground)
                        stopSelfHealState(myChar, remotes)
                        fledThisKnock = false
                        knockTeleportFails = 0
                        releaseFleeKnockUnderground(true)
                        vdESPState.fleeKnockEXBlocking = false
                    end
                end)
                task.wait(ok and 0.05 or 0.15)
            end

            stopFleeKnockEngine(true)
        end)
    end

    vdESPState.fleeKnockEXToggle = V_SurvivorEXSection:Toggle({
        Title = "Flee Knock EX",
        Description = "Flees underground on knockdown & self-heals (waits passively if hooked or chained)",
        Default = false,
        Callback = function(v)
            vdESPState.fleeKnockEXEnabled = v
            if v then
                startFleeKnockEXThread()
            else
                vdESPState.fleeKnockEXSession = (vdESPState.fleeKnockEXSession or 0) + 1
                stopFleeKnockEngine(true)
                pcall(function()
                    local myChar = player.Character
                    local remotes = getVDRemotes and getVDRemotes()
                    if myChar then
                        myChar:SetAttribute("isHealing", false)
                        if remotes and remotes.Healing and remotes.Healing:FindFirstChild("Reset") then
                            remotes.Healing.Reset:FireServer(myChar)
                        end
                    end
                end)
            end
        end
    })
end)

-- ============================================================
-- 8. AUTO SAVE SURVIVOR & RESCUE TEAM ENGINE
-- ============================================================
autoSaveEnabled = false
local rescueTravelMode = "Safe Teleport"
local selectedHookedTeammateLabel = nil
local rescueDropdownRef = nil

-- Helper to list all currently hooked teammates
local function getHookedTeammatesList()
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and isCharacterHooked(plr.Character) then
            local label = string.format("🪝 %s (@%s)", plr.DisplayName or plr.Name, plr.Name)
            table.insert(list, {
                label = label,
                player = plr,
                character = plr.Character,
                name = plr.Name
            })
        end
    end
    return list
end

local function getHookedTeammateLabels()
    local list = getHookedTeammatesList()
    local labels = {}
    for _, item in ipairs(list) do
        table.insert(labels, item.label)
    end
    if #labels == 0 then
        table.insert(labels, "No Hooked Teammates")
    end
    return labels
end

-- Core function to travel to and unhook a specific hooked teammate
local function executeTeammateUnhook(targetChar, targetPlrName)
    local myChar = player.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp or not targetChar then return false end

    local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
    if not targetHrp then return false end

    local unhookPt = findUnhookPointForTeammate(targetChar)
    local travelDest = unhookPt or targetHrp

    WindUI:Notify({
        Title = "🪝 Rescuing Teammate",
        Content = string.format("Traveling to %s via %s...", targetPlrName or targetChar.Name, rescueTravelMode),
        Duration = 2.5
    })

    -- Travel using user's chosen Rescue Travel Mode (Instant Teleport, Safe Teleport, or Run Normally)
    local arrived = travelToPoint(travelDest, 4.8, function()
        return isCharacterHooked(targetChar) and scriptRunning
    end, true, 12, rescueTravelMode)

    local finalDist = (myHrp.Position - travelDest.Position).Magnitude
    if finalDist <= 7.5 and isCharacterHooked(targetChar) then
        local remotes = getVDRemotes()
        if remotes.Carry and remotes.Carry:FindFirstChild("UnHookEvent") then
            local CS = game:GetService("CollectionService")
            pcall(function() CS:RemoveTag(myHrp, "doing action") end)
            pcall(function() CS:RemoveTag(myChar, "doing action") end)
            pcall(function()
                myChar:SetAttribute("isUnhooking", true)
                remotes.Carry.UnHookEvent:FireServer(targetChar, myChar)
                if unhookPt and unhookPt ~= targetHrp then
                    remotes.Carry.UnHookEvent:FireServer(unhookPt, myChar)
                end
            end)

            local heldPrompts = {}
            pcall(function()
                local seen = {}
                local function addPrompt(prompt)
                    if prompt and prompt:IsA("ProximityPrompt") and not seen[prompt] and not prompt:IsDescendantOf(myChar) then
                        seen[prompt] = true
                        local origDist = prompt.MaxActivationDistance
                        local origLOS = prompt.RequiresLineOfSight
                        pcall(function()
                            prompt.Enabled = true
                            prompt.RequiresLineOfSight = false
                            if prompt.MaxActivationDistance < 25 then prompt.MaxActivationDistance = 25 end
                        end)
                        pcall(function() prompt:InputHoldBegin() end)
                        if typeof(fireproximityprompt) == "function" then
                            pcall(fireproximityprompt, prompt)
                        end
                        table.insert(heldPrompts, { prompt = prompt, origDist = origDist, origLOS = origLOS })
                    end
                end
                for _, d in ipairs(targetChar:GetDescendants()) do
                    if d:IsA("ProximityPrompt") then addPrompt(d) end
                end
                if unhookPt and unhookPt.Parent then
                    local hookModel = unhookPt:FindFirstAncestorOfClass("Model")
                    local root = (hookModel and hookModel ~= workspace and hookModel ~= targetChar) and hookModel or unhookPt.Parent
                    for _, d in ipairs(root:GetDescendants()) do
                        if d:IsA("ProximityPrompt") then addPrompt(d) end
                    end
                end
            end)

            local rescueTimeout = tick() + 2.4
            while isCharacterHooked(targetChar) and tick() < rescueTimeout and scriptRunning do
                task.wait(0.1)
            end

            for _, item in ipairs(heldPrompts) do
                pcall(function() item.prompt:InputHoldEnd() end)
                pcall(function()
                    item.prompt.MaxActivationDistance = item.origDist
                    item.prompt.RequiresLineOfSight = item.origLOS
                end)
            end
            pcall(function() myChar:SetAttribute("isUnhooking", false) end)

            if not isCharacterHooked(targetChar) then
                WindUI:Notify({ Title = "🎉 Teammate Rescued!", Content = string.format("Successfully unhooked %s!", targetPlrName or targetChar.Name), Duration = 3 })
                return true
            end
        end
    end
    return false
end

-- Dropdown to choose travel mode specifically for rescuing
V_RescueSection:Dropdown({
    Title = "Rescue Travel Mode",
    Description = "Method used to reach hooked and knocked teammates (Instant, Safe, or Normal Run)",
    Values = { "Safe Teleport", "Run Normally", "Instant Teleport" },
    Value = "Safe Teleport",
    Callback = function(v)
        rescueTravelMode = v
    end
})

-- Dynamic dropdown of hooked teammates
do
    local initialHookedLabels = getHookedTeammateLabels()
    rescueDropdownRef = V_RescueSection:Dropdown({
        Title = "Select Hooked Teammate",
        Description = "Choose a specific hooked teammate to rescue",
        Values = initialHookedLabels,
        Value = initialHookedLabels[1],
        Callback = function(v)
            selectedHookedTeammateLabel = v
        end
    })
end

V_RescueSection:Button({
    Title = "🔄 Refresh Hooked List",
    Description = "Scans match and updates hooked teammate dropdown",
    Callback = function()
        local newLabels = getHookedTeammateLabels()
        pcall(function()
            if rescueDropdownRef and rescueDropdownRef.SetValues then
                rescueDropdownRef:SetValues(newLabels)
            elseif rescueDropdownRef and rescueDropdownRef.Refresh then
                rescueDropdownRef:Refresh(newLabels)
            end
        end)
        local count = (newLabels[1] == "No Hooked Teammates") and 0 or #newLabels
        WindUI:Notify({ Title = "Hooked Teammates", Content = string.format("Found %d hooked teammate(s).", count), Duration = 2.5 })
    end
})

V_RescueSection:Button({
    Title = "⚡ Go & Rescue Selected Teammate",
    Description = "Travels to selected hooked friend using chosen travel mode and unhooks them",
    Callback = function()
        local hookedList = getHookedTeammatesList()
        if #hookedList == 0 then
            WindUI:Notify({ Title = "Rescue Notice", Content = "No hooked teammates currently found!", Duration = 2.5 })
            return
        end

        local target = nil
        if selectedHookedTeammateLabel and selectedHookedTeammateLabel ~= "No Hooked Teammates" then
            for _, item in ipairs(hookedList) do
                if item.label == selectedHookedTeammateLabel or item.name == selectedHookedTeammateLabel or item.label:find(selectedHookedTeammateLabel, 1, true) then
                    target = item
                    break
                end
            end
        end

        if not target then
            target = hookedList[1]
        end

        task.spawn(function()
            executeTeammateUnhook(target.character, target.player.DisplayName or target.name)
        end)
    end
})

V_RescueSection:Button({
    Title = "⚡ Instant Rescue Nearest Hooked Friend",
    Description = "Finds nearest hooked friend, travels via chosen travel mode and unhooks them immediately",
    Callback = function()
        local targetChar, targetPlr = nil, nil
        local shortestDist = math.huge
        local myChar = player.Character
        local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myHrp then return end

        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character and isCharacterHooked(plr.Character) then
                local sHrp = plr.Character:FindFirstChild("HumanoidRootPart")
                if sHrp then
                    local d = (myHrp.Position - sHrp.Position).Magnitude
                    if d < shortestDist then
                        shortestDist = d
                        targetChar = plr.Character
                        targetPlr = plr
                    end
                end
            end
        end

        if not targetChar then
            WindUI:Notify({ Title = "Rescue Notice", Content = "No hooked teammates detected!", Duration = 2.5 })
            return
        end

        task.spawn(function()
            executeTeammateUnhook(targetChar, targetPlr.DisplayName or targetPlr.Name)
        end)
    end
})

V_RescueSection:Toggle({
    Title = "Auto Save Teammate (Continuous)",
    Description = "Continuously rescues hooked teammates & revives knocked teammates using chosen travel mode",
    Default = false,
    Callback = function(v)
        autoSaveEnabled = v
        saveSession = saveSession + 1
        local thisSession = saveSession
        local remotes = getVDRemotes()

        if not v then
            pcall(function()
                if player.Character then
                    player.Character:SetAttribute("isUnhooking", false)
                    player.Character:SetAttribute("isHealing", false)
                end
                if remotes.Healing and remotes.Healing:FindFirstChild("Reset") then
                    remotes.Healing.Reset:FireServer(player.Character)
                end
            end)
            return
        end

        local function checkSaveActive()
            return autoSaveEnabled and (saveSession == thisSession) and scriptRunning
        end

        task.spawn(function()
            local lastNoticeTime = 0
            while checkSaveActive() do
                pcall(function()
                    if isPlayerKiller and isPlayerKiller() then
                        task.wait(1)
                        return
                    end

                    local myChar = player.Character
                    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                    if not myHrp then task.wait(0.5) return end

                    local targetChar, targetPlr, targetDist, rescueType = findNearestRescuableTeammate()
                    if not targetChar or not targetPlr or not checkSaveActive() then
                        task.wait(0.4)
                        return
                    end

                    local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
                    if not targetHrp then task.wait(0.4) return end

                    -- Rate-limited notice of rescue attempt
                    if (tick() - lastNoticeTime) > 6 then
                        lastNoticeTime = tick()
                        local actionWord = (rescueType == "hooked") and "Unhooking" or "Reviving"
                        local emoji = (rescueType == "hooked") and "🪝" or "🩹"
                        WindUI:Notify({ Title = emoji .. " Priority Rescue", Content = string.format("%s teammate: %s (via %s)", actionWord, targetPlr.Name, rescueTravelMode), Duration = 2.5 })
                    end

                    -- 1. RESCUE HOOKED TEAMMATE
                    if rescueType == "hooked" then
                        local unhookPt = findUnhookPointForTeammate(targetChar)
                        local travelDest = unhookPt or targetHrp

                        local dist = (myHrp.Position - travelDest.Position).Magnitude
                        if dist > 5.2 then
                            travelToPoint(travelDest, 4.8, function()
                                return checkSaveActive() and isCharacterHooked(targetChar)
                            end, true, 12, rescueTravelMode)
                        end

                        if not checkSaveActive() then return end

                        local finalDist = (myHrp.Position - travelDest.Position).Magnitude
                        if finalDist <= 7.5 and isCharacterHooked(targetChar) then
                            if remotes.Carry and remotes.Carry:FindFirstChild("UnHookEvent") then
                                local CS = game:GetService("CollectionService")
                                pcall(function() CS:RemoveTag(myHrp, "doing action") end)
                                pcall(function() CS:RemoveTag(myChar, "doing action") end)
                                pcall(function()
                                    myChar:SetAttribute("isUnhooking", true)
                                    remotes.Carry.UnHookEvent:FireServer(targetChar, myChar)
                                    if unhookPt and unhookPt ~= targetHrp then
                                        remotes.Carry.UnHookEvent:FireServer(unhookPt, myChar)
                                    end
                                end)

                                local heldPrompts = {}
                                pcall(function()
                                    local seen = {}
                                    local function addPrompt(prompt)
                                        if prompt and prompt:IsA("ProximityPrompt") and not seen[prompt] and not prompt:IsDescendantOf(myChar) then
                                            seen[prompt] = true
                                            local origDist = prompt.MaxActivationDistance
                                            local origLOS = prompt.RequiresLineOfSight
                                            pcall(function()
                                                prompt.Enabled = true
                                                prompt.RequiresLineOfSight = false
                                                if prompt.MaxActivationDistance < 25 then prompt.MaxActivationDistance = 25 end
                                            end)
                                            pcall(function() prompt:InputHoldBegin() end)
                                            if typeof(fireproximityprompt) == "function" then
                                                pcall(fireproximityprompt, prompt)
                                            end
                                            table.insert(heldPrompts, { prompt = prompt, origDist = origDist, origLOS = origLOS })
                                        end
                                    end
                                    for _, prompt in ipairs(targetChar:GetDescendants()) do
                                        if prompt:IsA("ProximityPrompt") then addPrompt(prompt) end
                                    end
                                    if unhookPt and unhookPt.Parent then
                                        local hookModel = unhookPt:FindFirstAncestorOfClass("Model")
                                        local root = (hookModel and hookModel ~= workspace and hookModel ~= targetChar) and hookModel or unhookPt.Parent
                                        for _, prompt in ipairs(root:GetDescendants()) do
                                            if prompt:IsA("ProximityPrompt") then addPrompt(prompt) end
                                        end
                                    end
                                end)

                                local rescueTimeout = tick() + 2.4
                                while isCharacterHooked(targetChar) and tick() < rescueTimeout and checkSaveActive() do
                                    task.wait(0.1)
                                end

                                for _, item in ipairs(heldPrompts) do
                                    pcall(function() item.prompt:InputHoldEnd() end)
                                    pcall(function()
                                        item.prompt.MaxActivationDistance = item.origDist
                                        item.prompt.RequiresLineOfSight = item.origLOS
                                    end)
                                end
                                pcall(function() myChar:SetAttribute("isUnhooking", false) end)

                                if not isCharacterHooked(targetChar) then
                                    WindUI:Notify({ Title = "🪝 Saved Teammate!", Content = "Unhooked " .. targetPlr.Name .. "!", Duration = 2.5 })
                                    task.wait(0.4)
                                end
                            end
                        end

                    -- 2. REVIVE / HEAL KNOCKED DOWN TEAMMATE
                    elseif rescueType == "knocked" then
                        local dist = (myHrp.Position - targetHrp.Position).Magnitude
                        if dist > 4.5 then
                            travelToPoint(targetHrp, 4.0, function()
                                return checkSaveActive() and isCharacterKnocked(targetChar)
                            end, true, 12, rescueTravelMode)
                        end

                        if not checkSaveActive() then return end

                        local finalDist = (myHrp.Position - targetHrp.Position).Magnitude
                        if finalDist <= 6.0 and isCharacterKnocked(targetChar) then
                            if remotes.Healing and remotes.Healing:FindFirstChild("HealEvent") then
                                local healGuid = HttpService:GenerateGUID(false)
                                pcall(function()
                                    myChar:SetAttribute("isHealing", true)
                                    remotes.Healing.HealEvent:FireServer(targetHrp, true, healGuid, myChar)
                                end)

                                local healTimeout = tick() + 8.0
                                while isCharacterKnocked(targetChar) and tick() < healTimeout and checkSaveActive() do
                                    pcall(function()
                                        remotes.Healing.HealEvent:FireServer(targetHrp, true, healGuid, myChar)
                                    end)
                                    -- Real-time killer interrupt check
                                    local k = getKiller()
                                    if k and k:FindFirstChild("HumanoidRootPart") and (myHrp.Position - k.HumanoidRootPart.Position).Magnitude < 14 then
                                        break
                                    end
                                    task.wait(0.4)
                                end

                                pcall(function()
                                    myChar:SetAttribute("isHealing", false)
                                    if remotes.Healing:FindFirstChild("Reset") then
                                        remotes.Healing.Reset:FireServer(myChar)
                                    end
                                end)

                                if not isCharacterKnocked(targetChar) then
                                    WindUI:Notify({ Title = "🩹 Revived Teammate!", Content = "Healed & revived " .. targetPlr.Name .. "!", Duration = 2.5 })
                                    task.wait(0.3)
                                end
                            end
                        end
                    end
                end)
                task.wait(0.2)
            end
        end)
    end
})

-- ============================================================
-- RESCUE FRIEND EX (INSTANT UNDERGROUND UNHOOK SYSTEM)
-- ============================================================
pcall(function()
    local RunService = game:GetService("RunService")
    local CollectionService = game:GetService("CollectionService")

    local rescueEXSteppedConn = nil
    local rescueEXHeartbeatConn = nil
    local rescueEXOriginalCFrame = nil
    local currentRescueTargetChar = nil
    local rescueEXAnchorPart = nil
    local rescueEXGroundY = nil
    local rescueEXDepthStage = 1
    local rescueEXTransiting = false

    local function unlockRescueEXMotion(myChar, myHrp, restoreCollision)
        pcall(function()
            if myHrp then
                if myHrp.Anchored then myHrp.Anchored = false end
                myHrp.AssemblyLinearVelocity = Vector3.zero
                myHrp.AssemblyAngularVelocity = Vector3.zero
                pcall(function() CollectionService:RemoveTag(myHrp, "doing action") end)
            end
            if myChar then
                if myChar:GetAttribute("Rooted") == true then myChar:SetAttribute("Rooted", false) end
                if myChar:GetAttribute("Immobile") == true then myChar:SetAttribute("Immobile", false) end
                if myChar:GetAttribute("AC_ServerAnchor") ~= nil then myChar:SetAttribute("AC_ServerAnchor", nil) end
                pcall(function() CollectionService:RemoveTag(myChar, "doing action") end)
                local hum = myChar:FindFirstChildOfClass("Humanoid")
                if hum and hum.PlatformStand then
                    hum.PlatformStand = false
                end
                if restoreCollision then
                    for _, part in ipairs(myChar:GetDescendants()) do
                        if part:IsA("BasePart") then
                            if part.Name == "HumanoidRootPart" or part.Name == "Torso" or part.Name == "UpperTorso" or part.Name == "LowerTorso" then
                                part.CanCollide = true
                            end
                        end
                    end
                end
            end
        end)
    end

    local function stopRescueEX(restorePosition)
        vdESPState.rescueEXSession = (vdESPState.rescueEXSession or 0) + 1
        vdESPState.rescueEXHoldPos = nil
        vdESPState.rescueEXPaused = false
        vdESPState.rescueEXWantsPriority = false
        rescueEXTransiting = false
        currentRescueTargetChar = nil
        rescueEXAnchorPart = nil
        rescueEXGroundY = nil
        rescueEXDepthStage = 1

        if rescueEXSteppedConn then
            pcall(function() rescueEXSteppedConn:Disconnect() end)
            rescueEXSteppedConn = nil
        end
        if rescueEXHeartbeatConn then
            pcall(function() rescueEXHeartbeatConn:Disconnect() end)
            rescueEXHeartbeatConn = nil
        end

        pcall(function()
            local myChar = player.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if myChar then
                myChar:SetAttribute("isUnhooking", false)
                unlockRescueEXMotion(myChar, myHrp, true)
                if vdESPState.setMovementBypass then
                    vdESPState.setMovementBypass(myChar, false)
                end
            end
            if restorePosition and rescueEXOriginalCFrame and myHrp and not ghostRepairEXEnabled and not ghostRepairEnabled then
                if vdESPState.microTransitTo then
                    vdESPState.microTransitTo(myChar, myHrp, rescueEXOriginalCFrame.Position, nil, false)
                end
                myHrp.CFrame = rescueEXOriginalCFrame
                myHrp.AssemblyLinearVelocity = Vector3.zero
                myHrp.AssemblyAngularVelocity = Vector3.zero
                rescueEXOriginalCFrame = nil
            else
                rescueEXOriginalCFrame = nil
            end
            if unlockCameraAndMovement then
                unlockCameraAndMovement()
            end
        end)
    end

    local function getDesiredRescuePos(anchorPos, targetPos, groundY, depthStage)
        local offsetsGround = { 3.2, 2.7, 2.1 }
        local offsetsRaw = { 5.4, 4.6, 3.8 }
        local idx = math.clamp(depthStage or 1, 1, 3)

        local refPos = anchorPos or targetPos
        local minTargetAnchorY = targetPos and math.min(refPos.Y, targetPos.Y) or refPos.Y
        local maxTargetAnchorY = targetPos and math.max(refPos.Y, targetPos.Y) or refPos.Y

        local desiredY
        if groundY then
            desiredY = groundY - offsetsGround[idx]
            -- Guarantee distance to BOTH hook anchor and hooked survivor stays within server UnHook reach (<= ~6.6 - 7.3 studs)
            local minReachY = math.max(minTargetAnchorY - 6.3, maxTargetAnchorY - 7.2)
            if desiredY < minReachY then
                desiredY = math.min(groundY - 1.8, minReachY)
            end
        else
            desiredY = minTargetAnchorY - offsetsRaw[idx]
        end

        return Vector3.new(refPos.X, desiredY, refPos.Z)
    end

    local function findHookGroundY(anchorPart, anchorPos, targetChar)
        local hookModel = anchorPart and anchorPart:FindFirstAncestorOfClass("Model")
        if hookModel == workspace or hookModel == targetChar then
            hookModel = nil
        end
        if vdESPState.findFloorYBelow then
            return vdESPState.findFloorYBelow(anchorPos.X, anchorPos.Y, anchorPos.Z, hookModel)
        end
        return nil
    end

    local function getEffectiveRescueSafeDist()
        local userSafe = tonumber(vdESPState.rescueEXSafeDist)
        if userSafe == nil then userSafe = 100 end
        if vdESPState.autoFleeEnabled then
            local fleeMin = math.min(tonumber(vdESPState.autoFleeDistance) or 100, 120)
            return math.max(userSafe, fleeMin)
        end
        return userSafe
    end

    local function isKillerNearHookTarget(targetChar, anchorPart, safeDist)
        if (safeDist or 0) <= 0 then return false end
        local killer = getKiller and getKiller()
        local kHrp = killer and killer:FindFirstChild("HumanoidRootPart")
        if not kHrp then return false end
        local tHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
        if tHrp and (kHrp.Position - tHrp.Position).Magnitude <= safeDist then
            return true
        end
        if anchorPart and anchorPart.Parent and (kHrp.Position - anchorPart.Position).Magnitude <= safeDist then
            return true
        end
        return false
    end

    local function enforceRescueEXUndergroundPos(threshold)
        if not vdESPState.rescueEXEnabled or vdESPState.rescueEXPaused or rescueEXTransiting then return end
        if vdESPState.fleeKnockEXEnabled and vdESPState.fleeKnockEXBlocking then return end
        if vdESPState.autoFleeEnabled and vdESPState.autoFleeBlocking then return end

        local myChar = player.Character
        local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myChar or not myHrp or isCharacterKnocked(myChar) or isCharacterHooked(myChar) or (vdESPState.isLocalCaptured and vdESPState.isLocalCaptured(myChar)) then return end

        if vdESPState.setMovementBypass then
            vdESPState.setMovementBypass(myChar, true)
        end

        -- Keep live coordinates tightly synchronized with hook anchor & hooked teammate
        local liveAnchorPos = (rescueEXAnchorPart and rescueEXAnchorPart.Parent) and rescueEXAnchorPart.Position or nil
        local liveTargetHrp = (currentRescueTargetChar and currentRescueTargetChar.Parent) and currentRescueTargetChar:FindFirstChild("HumanoidRootPart") or nil
        local liveTargetPos = liveTargetHrp and liveTargetHrp.Position or nil
        if liveAnchorPos or liveTargetPos then
            vdESPState.rescueEXHoldPos = getDesiredRescuePos(liveAnchorPos, liveTargetPos, rescueEXGroundY, rescueEXDepthStage)
        end

        local targetPos = vdESPState.rescueEXHoldPos
        if not targetPos then return end

        if myHrp.CanCollide then
            for _, part in ipairs(myChar:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end

        local wasAnchored = myHrp.Anchored
        if wasAnchored then
            myHrp.Anchored = false
        end
        myHrp.AssemblyLinearVelocity = Vector3.zero
        myHrp.AssemblyAngularVelocity = Vector3.zero

        local realDist = (myHrp.Position - targetPos).Magnitude
        if realDist > (threshold or 0.25) or wasAnchored then
            if myChar:GetAttribute("Rooted") == true then myChar:SetAttribute("Rooted", false) end
            if myChar:GetAttribute("Immobile") == true then myChar:SetAttribute("Immobile", false) end
            if myChar:GetAttribute("AC_ServerAnchor") ~= nil then myChar:SetAttribute("AC_ServerAnchor", nil) end
            for _, part in ipairs(myChar:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
            myHrp.CFrame = CFrame.new(targetPos)
        end
    end

    local function findNearestHookedTeammateEX(myHrp)
        local bestChar, bestPlr, bestDist = nil, nil, math.huge
        local safeDist = getEffectiveRescueSafeDist()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character and plr.Character:IsDescendantOf(workspace) then
                if (not isTeammateRescuable or isTeammateRescuable(plr)) and isCharacterHooked(plr.Character) then
                    local tHrp = plr.Character:FindFirstChild("HumanoidRootPart")
                    if tHrp then
                        local unhookPt = findUnhookPointForTeammate and findUnhookPointForTeammate(plr.Character)
                        if not isKillerNearHookTarget(plr.Character, unhookPt, safeDist) then
                            local d = (myHrp.Position - tHrp.Position).Magnitude
                            if d < bestDist then
                                bestDist = d
                                bestChar = plr.Character
                                bestPlr = plr
                            end
                        end
                    end
                end
            end
        end
        return bestChar, bestPlr, bestDist
    end

    local function collectHookPrompts(targetChar, unhookPt, myChar)
        local collected = {}
        local seen = {}

        local function tryAddPrompt(p)
            if not p or not p:IsA("ProximityPrompt") or seen[p] or p:IsDescendantOf(myChar) then return end
            local act = (p.ActionText or ""):lower()
            local nm = (p.Name or ""):lower()
            if act:find("heal") or nm:find("sabotage") or act:find("sabotage") then return end
            if p.Enabled or act:find("unhook") or act:find("rescue") or act:find("save") or nm:find("unhook") then
                seen[p] = true
                table.insert(collected, p)
            end
        end

        local function scanRoot(root)
            if not root then return end
            for _, desc in ipairs(root:GetDescendants()) do
                if desc:IsA("ProximityPrompt") then
                    tryAddPrompt(desc)
                end
            end
        end

        scanRoot(targetChar)
        if unhookPt then
            scanRoot(unhookPt)
            local hookModel = unhookPt:FindFirstAncestorOfClass("Model")
            if hookModel and hookModel ~= workspace and hookModel ~= targetChar then
                scanRoot(hookModel)
            elseif unhookPt.Parent then
                scanRoot(unhookPt.Parent)
            end
        end

        local refPos = (unhookPt and unhookPt.Position) or (targetChar:FindFirstChild("HumanoidRootPart") and targetChar.HumanoidRootPart.Position)
        if refPos then
            pcall(function()
                local map = workspace:FindFirstChild("Map") or workspace:FindFirstChild("map")
                local hooksFolder = (map and (map:FindFirstChild("Hooks") or map:FindFirstChild("hooks")))
                    or workspace:FindFirstChild("Hooks") or workspace:FindFirstChild("hooks")
                if hooksFolder then
                    for _, obj in ipairs(hooksFolder:GetDescendants()) do
                        if obj:IsA("ProximityPrompt") then
                            local pPart = (obj.Parent and obj.Parent:IsA("BasePart")) and obj.Parent or nil
                            if pPart and (pPart.Position - refPos).Magnitude <= 18 then
                                tryAddPrompt(obj)
                            end
                        end
                    end
                end
            end)
            pcall(function()
                local op = OverlapParams.new()
                op.FilterType = Enum.RaycastFilterType.Exclude
                op.FilterDescendantsInstances = { myChar }
                for _, part in ipairs(workspace:GetPartBoundsInRadius(refPos, 18, op)) do
                    for _, desc in ipairs(part:GetDescendants()) do
                        if desc:IsA("ProximityPrompt") then
                            tryAddPrompt(desc)
                        end
                    end
                end
            end)
        end

        return collected
    end

    local function beginUnhookAttempt(remotes, targetChar, unhookPt, myChar, stage)
        pcall(function()
            local myHrp = myChar:FindFirstChild("HumanoidRootPart")
            if myHrp then
                pcall(function() CollectionService:RemoveTag(myHrp, "doing action") end)
            end
            pcall(function() CollectionService:RemoveTag(myChar, "doing action") end)
            myChar:SetAttribute("isRepairing", false)
            myChar:SetAttribute("isHealing", false)
            myChar:SetAttribute("isExiting", false)
            if myChar:GetAttribute("Rooted") == true then myChar:SetAttribute("Rooted", false) end
            if myChar:GetAttribute("Immobile") == true then myChar:SetAttribute("Immobile", false) end
            myChar:SetAttribute("isUnhooking", true)

            if remotes and remotes.Carry and remotes.Carry:FindFirstChild("UnHookEvent") then
                if stage == 1 then
                    remotes.Carry.UnHookEvent:FireServer(targetChar, myChar)
                elseif stage == 2 then
                    remotes.Carry.UnHookEvent:FireServer(targetChar)
                    if unhookPt and unhookPt:IsA("BasePart") and unhookPt ~= targetChar:FindFirstChild("HumanoidRootPart") then
                        remotes.Carry.UnHookEvent:FireServer(unhookPt, myChar)
                    end
                else
                    if unhookPt and unhookPt:IsA("BasePart") and unhookPt ~= targetChar:FindFirstChild("HumanoidRootPart") then
                        remotes.Carry.UnHookEvent:FireServer(unhookPt, myChar)
                    end
                    remotes.Carry.UnHookEvent:FireServer(targetChar, myChar)
                end
            end
        end)

        local prompts = collectHookPrompts(targetChar, unhookPt, myChar)
        local heldState = {}
        for _, prompt in ipairs(prompts) do
            local origHold = prompt.HoldDuration
            local origDist = prompt.MaxActivationDistance
            local origLOS = prompt.RequiresLineOfSight
            pcall(function()
                prompt.Enabled = true
                prompt.RequiresLineOfSight = false
                if prompt.MaxActivationDistance < 25 then
                    prompt.MaxActivationDistance = 25
                end
                if stage == 2 and prompt.HoldDuration > 0 then
                    prompt.HoldDuration = 0
                end
            end)
            pcall(function() prompt:InputHoldBegin() end)
            if typeof(fireproximityprompt) == "function" then
                pcall(fireproximityprompt, prompt)
            end
            table.insert(heldState, { prompt = prompt, origHold = origHold, origDist = origDist, origLOS = origLOS })
        end
        return heldState
    end

    local function endUnhookAttempt(heldState)
        if not heldState then return end
        for _, item in ipairs(heldState) do
            local p = item.prompt
            if p and p.Parent then
                pcall(function() p:InputHoldEnd() end)
                pcall(function()
                    p.HoldDuration = item.origHold
                    p.MaxActivationDistance = item.origDist
                    p.RequiresLineOfSight = item.origLOS
                end)
            end
        end
    end

    local function startRescueEXThread()
        vdESPState.rescueEXSession = (vdESPState.rescueEXSession or 0) + 1
        local mySession = vdESPState.rescueEXSession
        local function isSessionValid()
            return vdESPState.rescueEXEnabled == true and mySession == vdESPState.rescueEXSession and scriptRunning
        end

        if rescueEXSteppedConn then
            pcall(function() rescueEXSteppedConn:Disconnect() end)
            rescueEXSteppedConn = nil
        end
        if rescueEXHeartbeatConn then
            pcall(function() rescueEXHeartbeatConn:Disconnect() end)
            rescueEXHeartbeatConn = nil
        end

        -- 1a. Pre-simulation Stepped physics override + NoClip bypass (prevents floor push-back on Killer POV)
        rescueEXSteppedConn = RunService.Stepped:Connect(function()
            if not isSessionValid() then
                if rescueEXSteppedConn then
                    pcall(function() rescueEXSteppedConn:Disconnect() end)
                    rescueEXSteppedConn = nil
                end
                return
            end
            pcall(function()
                enforceRescueEXUndergroundPos(0.25)
            end)
        end)

        -- 1b. Post-simulation Heartbeat underground lock
        rescueEXHeartbeatConn = RunService.Heartbeat:Connect(function()
            if not isSessionValid() then
                if rescueEXHeartbeatConn then
                    pcall(function() rescueEXHeartbeatConn:Disconnect() end)
                    rescueEXHeartbeatConn = nil
                end
                return
            end
            pcall(function()
                enforceRescueEXUndergroundPos(0.25)
            end)
        end)

        -- 2. Ultra-fast 0.0001s Real-Position Checker & Spam Underground Teleport Loop
        task.spawn(function()
            while isSessionValid() do
                pcall(function()
                    enforceRescueEXUndergroundPos(0.25)
                end)
                task.wait(0.0001)
            end
        end)

        -- 3. Main Hooked Teammate Detector & 3-Fail -> 2s Pause Anti-Stall Unhook Thread
        task.spawn(function()
            local trackedChar = nil
            local rescueFailCount = 0

            while isSessionValid() do
                local ok = pcall(function()
                    if isPlayerKiller and isPlayerKiller() then
                        vdESPState.rescueEXHoldPos = nil
                        vdESPState.rescueEXWantsPriority = false
                        currentRescueTargetChar = nil
                        rescueEXAnchorPart = nil
                        rescueFailCount = 0
                        task.wait(0.3)
                        return
                    end

                    local myChar = player.Character
                    local hum = myChar and myChar:FindFirstChildOfClass("Humanoid")
                    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                    if not myChar or not myHrp or not hum or hum.Health <= 0 then
                        vdESPState.rescueEXHoldPos = nil
                        vdESPState.rescueEXWantsPriority = false
                        currentRescueTargetChar = nil
                        rescueEXAnchorPart = nil
                        rescueEXOriginalCFrame = nil
                        rescueFailCount = 0
                        task.wait(0.2)
                        return
                    end

                    if trackedChar ~= myChar then
                        trackedChar = myChar
                        rescueEXOriginalCFrame = nil
                        vdESPState.rescueEXHoldPos = nil
                        vdESPState.rescueEXWantsPriority = false
                        currentRescueTargetChar = nil
                        rescueEXAnchorPart = nil
                        rescueFailCount = 0
                    end

                    if (isEntityInLobbyOrSpectating and isEntityInLobbyOrSpectating(myChar, player))
                        or isCharacterHooked(myChar)
                        or isCharacterKnocked(myChar)
                        or (vdESPState.isLocalCaptured and vdESPState.isLocalCaptured(myChar))
                        or (vdESPState.fleeKnockEXEnabled and vdESPState.fleeKnockEXBlocking)
                        or myChar:GetAttribute("IsCarried") == true then
                        vdESPState.rescueEXHoldPos = nil
                        vdESPState.rescueEXWantsPriority = false
                        currentRescueTargetChar = nil
                        rescueEXAnchorPart = nil
                        myChar:SetAttribute("isUnhooking", false)
                        rescueFailCount = 0
                        task.wait(0.15)
                        return
                    end

                    if vdESPState.autoFleeEnabled and vdESPState.autoFleeBlocking then
                        vdESPState.rescueEXHoldPos = nil
                        vdESPState.rescueEXWantsPriority = false
                        myChar:SetAttribute("isUnhooking", false)
                        unlockRescueEXMotion(myChar, myHrp, true)
                        task.wait(0.15)
                        return
                    end

                    local targetChar, targetPlr = findNearestHookedTeammateEX(myHrp)
                    if not targetChar or not targetPlr then
                        local wasRescuing = (vdESPState.rescueEXHoldPos ~= nil or currentRescueTargetChar ~= nil or vdESPState.rescueEXWantsPriority)
                        vdESPState.rescueEXHoldPos = nil
                        vdESPState.rescueEXWantsPriority = false
                        currentRescueTargetChar = nil
                        rescueEXAnchorPart = nil
                        rescueEXGroundY = nil
                        rescueEXDepthStage = 1
                        rescueFailCount = 0
                        myChar:SetAttribute("isUnhooking", false)
                        if wasRescuing then
                            unlockRescueEXMotion(myChar, myHrp, true)
                            if vdESPState.setMovementBypass then
                                vdESPState.setMovementBypass(myChar, false)
                            end
                            local hasNextPriorityEX = ghostRepairEXEnabled or ghostRepairEnabled or (vdESPState.autoLeverEXEnabled and vdESPState.autoLeverEXWantsPriority)
                            if ghostAutoReturn and rescueEXOriginalCFrame and not hasNextPriorityEX then
                                if vdESPState.microTransitTo then
                                    vdESPState.microTransitTo(myChar, myHrp, rescueEXOriginalCFrame.Position, isSessionValid, false)
                                end
                                myHrp.CFrame = rescueEXOriginalCFrame
                                myHrp.AssemblyLinearVelocity = Vector3.zero
                                myHrp.AssemblyAngularVelocity = Vector3.zero
                                rescueEXOriginalCFrame = nil
                            else
                                rescueEXOriginalCFrame = nil
                            end
                            if unlockCameraAndMovement then
                                pcall(unlockCameraAndMovement)
                            end
                        end
                        task.wait(0.20)
                        return
                    end

                    local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
                    if not targetHrp then
                        vdESPState.rescueEXWantsPriority = false
                        task.wait(0.1)
                        return
                    end

                    if not rescueEXOriginalCFrame then
                        rescueEXOriginalCFrame = myHrp.CFrame
                    end

                    -- Claim top rescue priority over Lever EX & Generator EX immediately when a safe hooked friend exists
                    vdESPState.rescueEXWantsPriority = true

                    local unhookPt = findUnhookPointForTeammate and findUnhookPointForTeammate(targetChar) or targetHrp
                    local anchorPart = (unhookPt and unhookPt.Parent) and unhookPt or targetHrp
                    local groundY = findHookGroundY(anchorPart, anchorPart.Position, targetChar)
                    local destPos = getDesiredRescuePos(anchorPart.Position, targetHrp.Position, groundY, rescueEXDepthStage)
                    local safeDist = getEffectiveRescueSafeDist()

                    -- Micro-burst transit underground FIRST (prevents server anti-cheat rollback on >22 stud teleports)
                    rescueEXTransiting = true
                    vdESPState.rescueEXHoldPos = nil
                    currentRescueTargetChar = nil
                    rescueEXAnchorPart = nil
                    rescueEXGroundY = groundY

                    if vdESPState.microTransitTo then
                        vdESPState.microTransitTo(myChar, myHrp, destPos, function()
                            return isSessionValid()
                                and targetChar.Parent
                                and isCharacterHooked(targetChar)
                                and not isCharacterKnocked(myChar)
                                and not isCharacterHooked(myChar)
                                and not (vdESPState.fleeKnockEXEnabled and vdESPState.fleeKnockEXBlocking)
                                and not isKillerNearHookTarget(targetChar, anchorPart, safeDist)
                        end, true)
                    end
                    if not isSessionValid()
                        or not targetChar.Parent
                        or not isCharacterHooked(targetChar)
                        or isCharacterKnocked(myChar)
                        or (vdESPState.fleeKnockEXEnabled and vdESPState.fleeKnockEXBlocking)
                        or isKillerNearHookTarget(targetChar, anchorPart, safeDist) then
                        rescueEXTransiting = false
                        vdESPState.rescueEXHoldPos = nil
                        vdESPState.rescueEXWantsPriority = false
                        return
                    end

                    currentRescueTargetChar = targetChar
                    rescueEXAnchorPart = anchorPart
                    vdESPState.rescueEXHoldPos = destPos
                    rescueEXTransiting = false

                    -- Settle pinned underground 0.12s so server commits underground location before UnHook fires
                    local settleEnd = tick() + 0.12
                    while tick() < settleEnd
                        and isSessionValid()
                        and targetChar.Parent
                        and isCharacterHooked(targetChar)
                        and not isCharacterKnocked(myChar)
                        and not isKillerNearHookTarget(targetChar, anchorPart, safeDist) do
                        enforceRescueEXUndergroundPos(0.15)
                        task.wait(0.0001)
                    end

                    if not isSessionValid()
                        or not targetChar.Parent
                        or not isCharacterHooked(targetChar)
                        or isCharacterKnocked(myChar)
                        or (vdESPState.fleeKnockEXEnabled and vdESPState.fleeKnockEXBlocking)
                        or isKillerNearHookTarget(targetChar, anchorPart, safeDist) then
                        vdESPState.rescueEXHoldPos = nil
                        vdESPState.rescueEXWantsPriority = false
                        return
                    end

                    local remotes = getVDRemotes and getVDRemotes()
                    local heldPrompts = beginUnhookAttempt(remotes, targetChar, unhookPt, myChar, rescueEXDepthStage)

                    local attemptStart = tick()
                    local lastFallbackPulse = tick()
                    local abortedBySafety = false

                    -- Hold uninterrupted for full ~1.85s channel window (no mid-hold fireproximityprompt resets!)
                    while isSessionValid()
                        and targetChar.Parent
                        and isCharacterHooked(targetChar)
                        and not isCharacterHooked(myChar)
                        and not isCharacterKnocked(myChar)
                        and not (vdESPState.fleeKnockEXEnabled and vdESPState.fleeKnockEXBlocking)
                        and not (vdESPState.autoFleeEnabled and vdESPState.autoFleeBlocking) do

                        if isKillerNearHookTarget(targetChar, anchorPart, safeDist) then
                            abortedBySafety = true
                            break
                        end

                        if rescueEXDepthStage == 3 and (tick() - lastFallbackPulse) >= 0.45 then
                            lastFallbackPulse = tick()
                            if remotes and remotes.Carry and remotes.Carry:FindFirstChild("UnHookEvent") then
                                pcall(function()
                                    if unhookPt and unhookPt:IsA("BasePart") and unhookPt ~= targetHrp then
                                        remotes.Carry.UnHookEvent:FireServer(unhookPt, myChar)
                                    end
                                    remotes.Carry.UnHookEvent:FireServer(targetChar, myChar)
                                end)
                            end
                        end

                        if (tick() - attemptStart) >= 1.85 then
                            break
                        end

                        task.wait(0.05)
                    end

                    endUnhookAttempt(heldPrompts)

                    -- Clean up current attempt state
                    pcall(function()
                        if myChar and myChar.Parent then
                            myChar:SetAttribute("isUnhooking", false)
                            CollectionService:RemoveTag(myHrp, "doing action")
                            CollectionService:RemoveTag(myChar, "doing action")
                        end
                    end)

                    if abortedBySafety
                        or isCharacterKnocked(myChar)
                        or isCharacterHooked(myChar)
                        or (vdESPState.fleeKnockEXEnabled and vdESPState.fleeKnockEXBlocking) then
                        vdESPState.rescueEXHoldPos = nil
                        vdESPState.rescueEXWantsPriority = false
                        currentRescueTargetChar = nil
                        rescueEXAnchorPart = nil
                        unlockRescueEXMotion(myChar, myHrp, true)
                        if vdESPState.setMovementBypass then
                            vdESPState.setMovementBypass(myChar, false)
                        end
                        task.wait(0.15)
                        return
                    end

                    -- Check whether rescue succeeded or failed
                    if not targetChar.Parent or not isCharacterHooked(targetChar) then
                        rescueFailCount = 0
                        rescueEXDepthStage = 1
                        vdESPState.rescueEXHoldPos = nil
                        currentRescueTargetChar = nil
                        rescueEXAnchorPart = nil
                    elseif isSessionValid()
                        and not isCharacterHooked(myChar)
                        and not isCharacterKnocked(myChar)
                        and not (vdESPState.autoFleeEnabled and vdESPState.autoFleeBlocking) then
                        rescueFailCount = rescueFailCount + 1
                        if rescueFailCount >= 3 then
                            -- Turn off instant underground teleport & unhook for 2s after 3 consecutive fails, then retry
                            vdESPState.rescueEXPaused = true
                            vdESPState.rescueEXHoldPos = nil
                            currentRescueTargetChar = nil
                            rescueEXAnchorPart = nil
                            unlockRescueEXMotion(myChar, myHrp, true)
                            if vdESPState.setMovementBypass then
                                vdESPState.setMovementBypass(myChar, false)
                            end
                            local pauseEnd = tick() + 2.0
                            while tick() < pauseEnd
                                and isSessionValid()
                                and not isCharacterKnocked(myChar)
                                and not (vdESPState.fleeKnockEXEnabled and vdESPState.fleeKnockEXBlocking) do
                                task.wait(0.05)
                            end
                            rescueFailCount = 0
                            rescueEXDepthStage = 1
                            vdESPState.rescueEXPaused = false
                        else
                            rescueEXDepthStage = (rescueEXDepthStage % 3) + 1
                            task.wait(0.08)
                        end
                    end
                end)
                task.wait(ok and 0.05 or 0.15)
            end

            stopRescueEX(true)
        end)
    end

    vdESPState.rescueEXToggle = V_SurvivorEXSection:Toggle({
        Title = "Rescue Friend EX",
        Description = "Priority underground rescue when no Killer is near hook (pauses Gen EX, 2s reset after 3 fails)",
        Default = false,
        Callback = function(v)
            vdESPState.rescueEXEnabled = v
            if v then
                startRescueEXThread()
            else
                stopRescueEX(true)
            end
        end
    })

    V_SurvivorEXSection:Slider({
        Title = "Rescue Safe Distance (Killer)",
        Description = "Only rescue hooked teammate when Killer is farther than this distance (0 - 150 studs, default 100)",
        Step = 5,
        Value = {
            Min = 0,
            Max = 150,
            Default = 100,
        },
        Callback = function(val)
            vdESPState.rescueEXSafeDist = tonumber(val) or 100
        end
    })
end)

-- ============================================================
-- NOCLIP SYSTEM (FOR AUTO REPAIR & AUTO CATCH)
-- ============================================================
-- Unified noClipEnabled
local noClipConn

local function updateNoClip(state)
    noClipEnabled = state
    if noClipConn then
        pcall(function() noClipConn:Disconnect() end)
        noClipConn = nil
    end

    local char = player.Character
    if char then
        pcall(function()
            char:SetAttribute("BypassNoclipAntiCheat", state)
            char:SetAttribute("donttrack", state)
            char:SetAttribute("NetTraversalUntil", state and 999999999 or nil)
            if char:GetAttribute("AC_ServerAnchor") ~= nil then
                char:SetAttribute("AC_ServerAnchor", nil)
            end
        end)
    end

    if not state then
        if player.Character then
            for _, part in ipairs(player.Character:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.CanCollide = true
                end
            end
        end
        return
    end

    noClipConn = RunService.Stepped:Connect(function()
        if not noClipEnabled then return end
        local c = player.Character
        if c then
            pcall(function()
                c:SetAttribute("BypassNoclipAntiCheat", true)
                c:SetAttribute("donttrack", true)
                c:SetAttribute("NetTraversalUntil", 999999999)
                if c:GetAttribute("AC_ServerAnchor") ~= nil then
                    c:SetAttribute("AC_ServerAnchor", nil)
                end
            end)
            for _, part in ipairs(c:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
end

V_ObjectiveSection:Toggle({
    Title = "NoClip (Pass Through Walls)",
    Description = "Phases through all map walls, obstacles & doors",
    Default = false,
    Callback = function(v)
        updateNoClip(v)
    end
})

-- ============================================================
-- SERVER REMOTES & ATTRIBUTE EXPLOITS (MECHANICS & COLLISION)
-- ============================================================

end

do
V_ServerRemotesSection = ViolenceTab:Section({
    Title = "Server Remotes & Attribute Exploits"
})

local serverDisableCollisionEnabled = false
local serverCrouchEnabled = false
local serverSpeedboostEnabled = false
local speedboostMultiplier = 2.0
local serverNoStunEnabled = false
local antiCarryEnabled = false
local antiImmobileEnabled = true

-- 1. Server Disable Collision (p_u_310.disableCollisionEvent:FireServer())
V_ServerRemotesSection:Toggle({
    Title = "Server Disable Collision (Ghost Mode)",
    Description = "Fires Collision.DisableCollision to disable character collisions on the server",
    Default = false,
    Callback = function(v)
        serverDisableCollisionEnabled = v
        if v then
            fireDisableCollision()
        else
            if not noClipEnabled then
                fireEnableCollision()
            end
        end
    end
})

V_ServerRemotesSection:Button({
    Title = "⚡ Fire Disable Collision (Once)",
    Description = "Directly invokes p_u_310.disableCollisionEvent:FireServer() once",
    Callback = function()
        fireDisableCollision()
        WindUI:Notify({ Title = "Remote Executed", Content = "Collision.DisableCollision:FireServer() fired!", Duration = 2 })
    end
})

-- 2. Server Stealth Crouch (Crouchingserver)
V_ServerRemotesSection:Toggle({
    Title = "Server Stealth Crouch (Crouchingserver)",
    Description = "Fires Mechanics.ChangeAttribute('Crouchingserver', boolean) for reduced hitbox & stealth",
    Default = false,
    Callback = function(v)
        serverCrouchEnabled = v
        fireChangeAttribute("Crouchingserver", v)
    end
})

-- 3. Server Speedboost (speedboost)
V_ServerRemotesSection:Toggle({
    Title = "Server Speedboost (speedboost)",
    Description = "Fires Mechanics.ChangeAttribute('speedboost', value) to multiply movement speed",
    Default = false,
    Callback = function(v)
        serverSpeedboostEnabled = v
        if v then
            fireChangeAttribute("speedboost", speedboostMultiplier)
        else
            fireChangeAttribute("speedboost", 1)
        end
    end
})

V_ServerRemotesSection:Slider({
    Title = "Speedboost Multiplier",
    Description = "Server-side speed multiplier attribute (1.0x - 5.0x)",
    Step = 0.5,
    Value = {
        Min = 1.0,
        Max = 5.0,
        Default = 2.0,
    },
    Callback = function(val)
        speedboostMultiplier = tonumber(val) or 2.0
        if serverSpeedboostEnabled then
            fireChangeAttribute("speedboost", speedboostMultiplier)
        end
    end
})

-- 4. Server No-Stun (nostun)
V_ServerRemotesSection:Toggle({
    Title = "Server No-Stun (nostun)",
    Description = "Fires Mechanics.ChangeAttribute('nostun', true) to prevent all stun penalties",
    Default = false,
    Callback = function(v)
        serverNoStunEnabled = v
        if v then
            fireChangeAttribute("nostun", true)
            fireChangeAttribute("isStunned", false)
            fireChangeAttribute("IsStunned", false)
            fireChangeAttribute("Stunned", false)
        else
            fireChangeAttribute("nostun", false)
        end
    end
})

-- 5. Anti-Carry / Instant Force Drop (IsCarried)
V_ServerRemotesSection:Toggle({
    Title = "Anti-Carry / Force Drop (IsCarried)",
    Description = "Fires Mechanics.ChangeAttribute('IsCarried', false) to break free from Killer carry instantly",
    Default = false,
    Callback = function(v)
        antiCarryEnabled = v
        if v then
            fireChangeAttribute("IsCarried", false)
            fireChangeAttribute("isCarried", false)
            fireChangeAttribute("BeingCarried", false)
        end
    end
})

V_ServerRemotesSection:Button({
    Title = "⚡ Force Drop / Break Carry Now",
    Description = "Immediately fires ChangeAttribute('IsCarried', false) to escape current carry",
    Callback = function()
        fireChangeAttribute("IsCarried", false)
        fireChangeAttribute("isCarried", false)
        fireChangeAttribute("BeingCarried", false)
        WindUI:Notify({ Title = "Carry Escape Fired", Content = "Fired ChangeAttribute('IsCarried', false)!", Duration = 2 })
    end
})

-- 6. Anti-Immobile / Anti-Root (Immobile)
V_ServerRemotesSection:Toggle({
    Title = "Anti-Immobile / Anti-Root (Anti-Freeze)",
    Description = "Automatically unfreezes movement, un-anchors, and clears locks from rubberbands, traps & hits",
    Default = true,
    Callback = function(v)
        antiImmobileEnabled = v
        if v then
            fireChangeAttribute("Immobile", false)
            fireChangeAttribute("Rooted", false)
            fireChangeAttribute("Trapped", false)
        end
    end
})

V_ServerRemotesSection:Button({
    Title = "⚡ Clear Immobile / Unfreeze Now",
    Description = "Immediately fires ChangeAttribute('Immobile', false) to restore movement",
    Callback = function()
        fireChangeAttribute("Immobile", false)
        fireChangeAttribute("Rooted", false)
        fireChangeAttribute("Trapped", false)
        WindUI:Notify({ Title = "Movement Unlocked", Content = "Fired ChangeAttribute('Immobile', false)!", Duration = 2 })
    end
})

-- Continuous Server Attribute & Collision Maintenance Loop
task.spawn(function()
    while scriptRunning do
        pcall(function()
            local myChar = player.Character
            if not myChar then return end

            -- 1. Server collision maintenance (strictly manual toggle)
            if serverDisableCollisionEnabled then
                fireDisableCollision()
            end

            -- 2. Server Crouch maintenance
            if serverCrouchEnabled then
                if myChar:GetAttribute("Crouchingserver") ~= true then
                    fireChangeAttribute("Crouchingserver", true)
                end
            end

            -- 3. Speedboost maintenance
            if serverSpeedboostEnabled then
                local currentBoost = myChar:GetAttribute("speedboost")
                if currentBoost ~= speedboostMultiplier then
                    fireChangeAttribute("speedboost", speedboostMultiplier)
                end
            end

            -- 4. No-Stun maintenance
            if serverNoStunEnabled then
                if myChar:GetAttribute("nostun") ~= true then
                    fireChangeAttribute("nostun", true)
                end
                if myChar:GetAttribute("isStunned") == true or myChar:GetAttribute("IsStunned") == true or myChar:GetAttribute("Stunned") == true then
                    fireChangeAttribute("isStunned", false)
                    fireChangeAttribute("IsStunned", false)
                    fireChangeAttribute("Stunned", false)
                    fireChangeAttribute("nostun", true)
                end
            end

            -- 5. Anti-Carry maintenance
            if antiCarryEnabled then
                if myChar:GetAttribute("IsCarried") == true or myChar:GetAttribute("isCarried") == true or myChar:GetAttribute("BeingCarried") == true then
                    fireChangeAttribute("IsCarried", false)
                    fireChangeAttribute("isCarried", false)
                    fireChangeAttribute("BeingCarried", false)
                end
            end

            -- 6. Anti-Immobile / Anti-Root maintenance (never fire when chained, hooked, or carried)
            local isCapturedNow = (isCharacterHooked and isCharacterHooked(myChar))
                or (vdESPState and vdESPState.isLocalCaptured and vdESPState.isLocalCaptured(myChar))
                or myChar:GetAttribute("IsHooked") == true
                or myChar:GetAttribute("IsCarried") == true
                or myChar:GetAttribute("BeingCarried") == true
            if antiImmobileEnabled and not isCapturedNow then
                if myChar:GetAttribute("Immobile") == true or myChar:GetAttribute("Rooted") == true or myChar:GetAttribute("Trapped") == true then
                    fireChangeAttribute("Immobile", false)
                    fireChangeAttribute("Rooted", false)
                    fireChangeAttribute("Trapped", false)
                end
            end
        end)
        task.wait(0.25)
    end
end)

-- ============================================================
-- HIGH-FREQUENCY INSTANT ANTI-STUCK & MOVEMENT RECOVERY ENGINE
-- ============================================================
local lastServerUnfreezeTick = 0

local function performInstantUnfreeze()
    if not scriptRunning then return end
    local char = player.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then return end

    -- Safe exclusions: Never interfere if character is actively chained, on a meat hook, or carried by killer
    local isHooked = (isCharacterHooked and isCharacterHooked(char))
        or char:GetAttribute("IsHooked") == true
        or (char:GetAttribute("HookedProgress") ~= nil and char:GetAttribute("HookedProgress") > 0)
    local isCarried = char:GetAttribute("IsCarried") == true or char:GetAttribute("BeingCarried") == true or char:GetAttribute("IsCarrying") == true
    local isCaptured = vdESPState and vdESPState.isLocalCaptured and vdESPState.isLocalCaptured(char)
    if isHooked or isCarried or isCaptured then return end

    -- 1. Anti-Anchor: When server rubberbands or anti-cheat triggers, it pins HumanoidRootPart.Anchored = true
    if hrp.Anchored then
        if vdESPState then
            vdESPState.lastServerAnchorTick = tick()
        end
        hrp.Anchored = false
    end

    -- 2. Clear server anti-cheat anchor attribute immediately
    if char:GetAttribute("AC_ServerAnchor") ~= nil then
        if vdESPState then
            vdESPState.lastACAnchorTick = tick()
            vdESPState.lastServerAnchorTick = tick()
        end
        pcall(function() char:SetAttribute("AC_ServerAnchor", nil) end)
    end

    -- 3. Clear all immobilizing / rooting / movement-locking attributes immediately
    local attributesCleared = false
    if char:GetAttribute("Rooted") == true then
        pcall(function() char:SetAttribute("Rooted", false) end)
        attributesCleared = true
    end
    if char:GetAttribute("Immobile") == true then
        pcall(function() char:SetAttribute("Immobile", false) end)
        attributesCleared = true
    end
    if char:GetAttribute("MovementLocked") == true then
        pcall(function() char:SetAttribute("MovementLocked", false) end)
        attributesCleared = true
    end
    if char:GetAttribute("Trapped") == true then
        pcall(function() char:SetAttribute("Trapped", false) end)
        attributesCleared = true
    end
    if char:GetAttribute("cantupdatespeed") == true then
        pcall(function() char:SetAttribute("cantupdatespeed", false) end)
        attributesCleared = true
    end

    -- Server sync: fire remote to clear server-authoritative locks if flagged
    if attributesCleared and antiImmobileEnabled and (os.clock() - lastServerUnfreezeTick >= 0.15) then
        lastServerUnfreezeTick = os.clock()
        pcall(function()
            fireChangeAttribute("Rooted", false)
            fireChangeAttribute("Immobile", false)
            fireChangeAttribute("Trapped", false)
        end)
    end

    -- 4. Instant WalkSpeed & Mobility Unfreeze (for healthy character)
    if hum.Health > 50 then
        -- Clear ragdoll / falling disable flags
        if hum.PlatformStand then
            hum.PlatformStand = false
        end
        if hum.Sit then
            hum.Sit = false
        end

        -- Calculate desired movement speed
        local targetBaseSpeed = 10
        if isCharacterKiller(char) then
            targetBaseSpeed = tonumber(char:GetAttribute("Speed")) or 14
        else
            local isSprinting = char:GetAttribute("Sprinting") == true
            if isSprinting then
                targetBaseSpeed = 16
            end
        end
        if serverSpeedboostEnabled and speedboostMultiplier > 1 then
            targetBaseSpeed = targetBaseSpeed * speedboostMultiplier
        end

        -- If WalkSpeed is locked at 0 or suppressed following rubberband rollback:
        if hum.WalkSpeed < 8 then
            hum.WalkSpeed = targetBaseSpeed
        end

        -- 5. Physics Inertia & Velocity Unstick:
        -- Following a server CFrame snapback, AssemblyLinearVelocity is pinned to zero,
        -- creating a multi-second physics dead-zone. Re-inject directional momentum if user is moving.
        if hum.MoveDirection.Magnitude > 0.05 then
            local horizVel = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z)
            if horizVel.Magnitude < 0.25 then
                hrp.AssemblyLinearVelocity = Vector3.new(
                    hum.MoveDirection.X * hum.WalkSpeed,
                    hrp.AssemblyLinearVelocity.Y,
                    hum.MoveDirection.Z * hum.WalkSpeed
                )
            end
        end
    end
end

-- Connect to Stepped (pre-simulation) and Heartbeat (post-simulation)
RunService.Stepped:Connect(function()
    if scriptRunning then
        pcall(performInstantUnfreeze)
    end
end)

RunService.Heartbeat:Connect(function()
    if scriptRunning then
        pcall(performInstantUnfreeze)
    end
end)

-- Dynamic Attribute Listeners for Zero-Latency Trigger
local function bindCharacterUnfreezeListeners(char)
    if not char then return end
    local unfreezeAttrs = { "Rooted", "Immobile", "MovementLocked", "Trapped", "AC_ServerAnchor", "cantupdatespeed" }
    for _, attrName in ipairs(unfreezeAttrs) do
        pcall(function()
            char:GetAttributeChangedSignal(attrName):Connect(function()
                if attrName == "AC_ServerAnchor" and char:GetAttribute("AC_ServerAnchor") ~= nil and vdESPState then
                    vdESPState.lastACAnchorTick = tick()
                    vdESPState.lastServerAnchorTick = tick()
                end
                if scriptRunning then
                    performInstantUnfreeze()
                end
            end)
        end)
    end
end

-- Bind for current character and future respawns
if player.Character then
    bindCharacterUnfreezeListeners(player.Character)
end

player.CharacterAdded:Connect(function(newChar)
    task.wait(0.2)
    bindCharacterUnfreezeListeners(newChar)
end)

-- ============================================================
-- KILLER AUTOMATION (AUTO CATCH, STANDALONE AIM/HIT & AUTO HOOK)
-- ============================================================

end

do
V_KillerSection = ViolenceTab:Section({
    Title = "Killer Automation (Catch, Hit & Hook)",
    Opened = true
})

-- Unified Killer Automation states (referencing top-level variables)
autoCatchEnabled = false
autoAimSurvivorEnabled = false
autoHitSurvivorEnabled = false
autoHookSurvivorEnabled = false
local isHookActionActive = false
local killerTravelMode = "Instant Teleport"
local hitReachDistance = 10
local lastKillerHitTime = 0
local currentKillerTarget = nil
local killerAimConn = nil
local catchBotsIgnoredActive = false

-- (Helpers isKillerCarrying, isKillerStunnedOrLocked, and isSurvivorParryingOrShielded defined globally at top)

-- Validates that target is an active upright Survivor (EXCLUDES Killer, Lobby players, knocked down, hooked & carried)
local function isSurvivorValidTarget(c)
    if not c or not c.Parent then return false end
    if c == player.Character then return false end
    
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    -- Exclude Dead, Sacrificed, Escaped
    if c:GetAttribute("IsDead") == true or c:GetAttribute("Sacrificed") == true or c:GetAttribute("Escaped") == true or c:GetAttribute("HasEscaped") == true then
        return false
    end
    local plr = Players:GetPlayerFromCharacter(c)
    if plr and (plr:GetAttribute("IsDead") == true or plr:GetAttribute("Sacrificed") == true or plr:GetAttribute("Escaped") == true or plr:GetAttribute("HasEscaped") == true) then
        return false
    end

    -- Exclude Lobby/Spectating
    if isEntityInLobbyOrSpectating(c, plr) then
        return false
    end

    -- Exclude Knocked Down / Downed survivors
    if isCharacterKnocked(c) then return false end

    -- Exclude Hooked survivors
    if isCharacterHooked(c) then return false end

    -- Exclude Carried survivors
    local isCarried = c:GetAttribute("IsCarried") == true
        or c:GetAttribute("isCarried") == true
        or c:GetAttribute("BeingCarried") == true
        or c:FindFirstChild("Carried") ~= nil
    if isCarried then return false end

    -- In 1v4 match: if local player is Killer or killer automation is active, every other upright alive character is a Survivor!
    if autoCatchEnabled or autoCatchEXEnabled or autoAimSurvivorEnabled or autoHitSurvivorEnabled or autoHookSurvivorEnabled or (isPlayerKiller and isPlayerKiller()) then
        return true
    end

    if not isCharacterSurvivor(c, plr) then return false end
    if isCharacterKiller(c, plr) or c == getKiller() then return false end

    return true
end

-- Validates that target is a Downed/Knocked Survivor eligible for pickup & hooking
local function isSurvivorDowned(c)
    if not c or not c.Parent then return false end
    if c == player.Character then return false end
    
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    -- Exclude Dead, Sacrificed, Escaped
    if c:GetAttribute("IsDead") == true or c:GetAttribute("Sacrificed") == true or c:GetAttribute("Escaped") == true or c:GetAttribute("HasEscaped") == true then
        return false
    end
    local plr = Players:GetPlayerFromCharacter(c)
    if plr and (plr:GetAttribute("IsDead") == true or plr:GetAttribute("Sacrificed") == true or plr:GetAttribute("Escaped") == true or plr:GetAttribute("HasEscaped") == true) then
        return false
    end

    -- Exclude Lobby/Spectating
    if isEntityInLobbyOrSpectating(c, plr) then return false end

    -- Exclude Hooked survivors
    if isCharacterHooked(c) then return false end

    -- Exclude Carried survivors
    local isCarried = c:GetAttribute("IsCarried") == true
        or c:GetAttribute("isCarried") == true
        or c:GetAttribute("BeingCarried") == true
        or c:FindFirstChild("Carried") ~= nil
    if isCarried then return false end

    -- Exclude Killer
    if not (autoCatchEnabled or autoCatchEXEnabled or autoAimSurvivorEnabled or autoHitSurvivorEnabled or autoHookSurvivorEnabled or (isPlayerKiller and isPlayerKiller())) then
        if isCharacterKiller(c, plr) or c == getKiller() then return false end
    end

    return isCharacterKnocked(c)
end

-- Detects whether a character model is an AI bot / NPC / dummy / clone rather than a human player
local function isSurvivorBot(c)
    if not c or not c.Parent then return false end
    local plr = Players:GetPlayerFromCharacter(c)
    if not plr then
        return true
    end
    if c:GetAttribute("IsBot") == true
        or c:GetAttribute("isBot") == true
        or c:GetAttribute("Bot") == true
        or c:GetAttribute("IsNPC") == true
        or c:GetAttribute("IsClone") == true
        or c:GetAttribute("Clone") == true
        or plr:GetAttribute("IsBot") == true
        or plr:GetAttribute("Bot") == true then
        return true
    end
    if CollectionService then
        for _, tag in ipairs({ "Bot", "NPC", "SurvivorBot", "CarryTestDummy", "ShadowClone", "Clone" }) do
            if CollectionService:HasTag(c, tag) then
                return true
            end
        end
    end
    return false
end

-- Collects all unique candidate character models across ESP tracker, Players, workspace, and tags
local function collectSurvivorCandidateModels(myChar)
    local candidateModels = {}
    local seen = {}

    local function tryAdd(obj)
        if obj and obj.Parent and obj:IsA("Model") and obj ~= myChar and not seen[obj] then
            seen[obj] = true
            table.insert(candidateModels, obj)
        end
    end

    -- 1. Check all survivors currently tracked by ESP
    if trackedSurvivors then
        for c, _ in pairs(trackedSurvivors) do
            tryAdd(c)
        end
    end

    -- 2. Check Players
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character then
            tryAdd(plr.Character)
        end
    end

    -- 3. Check workspace subfolders & workspace children for bot/NPC survivors
    local searchContainers = { workspace }
    for _, fName in ipairs({ "Bots", "NPCs", "Survivors", "Players", "Characters", "Match", "Entities", "Map" }) do
        local folder = workspace:FindFirstChild(fName)
        if folder and (folder:IsA("Folder") or folder:IsA("Model")) then
            table.insert(searchContainers, folder)
        end
    end

    for _, container in ipairs(searchContainers) do
        for _, obj in ipairs(container:GetChildren()) do
            if obj:IsA("Model") then
                tryAdd(obj)
            end
        end
    end

    -- 4. Check CollectionService tags for survivors / bots
    if CollectionService then
        for _, tag in ipairs({ "Survivor", "Survivors", "Bot", "NPC", "SurvivorBot", "CarryTestDummy" }) do
            for _, obj in ipairs(CollectionService:GetTagged(tag)) do
                tryAdd(obj)
            end
        end
    end

    return candidateModels
end

-- Checks if Auto Catch detects >= 5 active match targets where at least one is a bot (and real players exist)
local function evaluateCatchBotIgnore(myChar)
    local totalCount = 0
    local botCount = 0
    local humanCount = 0
    local killerChar = (not (isPlayerKiller and isPlayerKiller())) and (getKiller and getKiller()) or nil

    for _, c in ipairs(collectSurvivorCandidateModels(myChar)) do
        if c ~= myChar and c ~= killerChar then
            local hrp = c:FindFirstChild("HumanoidRootPart")
            local hum = c:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local plr = Players:GetPlayerFromCharacter(c)
                if not isEntityInLobbyOrSpectating(c, plr) then
                    totalCount = totalCount + 1
                    if isSurvivorBot(c) then
                        botCount = botCount + 1
                    else
                        humanCount = humanCount + 1
                    end
                end
            end
        end
    end

    local shouldIgnore = (totalCount >= 5) and (botCount >= 1) and (humanCount >= 1)
    return shouldIgnore, totalCount, botCount, humanCount
end

local function findNearestSurvivor(ignoreBots)
    local myChar = player.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return nil end

    local bestTarget = nil
    local bestDist = math.huge

    for _, c in ipairs(collectSurvivorCandidateModels(myChar)) do
        if not (ignoreBots and isSurvivorBot(c)) and isSurvivorValidTarget(c) then
            local hrp = c:FindFirstChild("HumanoidRootPart")
            if hrp then
                local dist = (myHrp.Position - hrp.Position).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    bestTarget = c
                end
            end
        end
    end

    return bestTarget, bestDist
end

-- Locates nearest downed/knocked survivor awaiting carry/hook
local function findNearestDownedSurvivor(ignoreBots)
    local myChar = player.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return nil end

    local bestDowned = nil
    local bestDist = math.huge

    for _, c in ipairs(collectSurvivorCandidateModels(myChar)) do
        if not (ignoreBots and isSurvivorBot(c)) and isSurvivorDowned(c) then
            local hrp = c:FindFirstChild("HumanoidRootPart")
            if hrp then
                local dist = (myHrp.Position - hrp.Position).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    bestDowned = c
                end
            end
        end
    end

    return bestDowned, bestDist
end

-- Shared hook discovery helper (checkSabotaged=false for exact v1.02 Standard behavior; true for EX)
local function findNearestAvailableHookCore(checkSabotaged)
    local myChar = player.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return nil end

    local bestHook = nil
    local bestDist = math.huge
    local candidates = {}

    -- 1. Direct authoritative check in workspace.Map.Hooks (as verified in Cobalt network captures)
    local mapFolder = workspace:FindFirstChild("Map") or workspace:FindFirstChild("map")
    local hooksFolder = mapFolder and (mapFolder:FindFirstChild("Hooks") or mapFolder:FindFirstChild("hooks"))
        or workspace:FindFirstChild("Hooks") or workspace:FindFirstChild("hooks")
    if hooksFolder then
        for _, hookModel in ipairs(hooksFolder:GetChildren()) do
            local hp = hookModel:FindFirstChild("HookPoint") or hookModel:FindFirstChildWhichIsA("BasePart")
            if hp and hp:IsA("BasePart") then
                table.insert(candidates, hp)
            end
        end
    end

    -- 2. CollectionService tagged HookPoint (from the dump.lua)
    if #candidates == 0 and CollectionService then
        for _, p in ipairs(CollectionService:GetTagged("HookPoint")) do
            if p:IsA("BasePart") then
                table.insert(candidates, p)
            end
        end
    end

    -- 3. Fallback search by object name in workspace
    if #candidates == 0 then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and (obj.Name == "HookPoint" or (obj.Name:lower():find("hook") and obj.Name:lower():find("point"))) then
                table.insert(candidates, obj)
            end
        end
    end

    -- 4. Additional fallback: Hook models HitBox/PrimaryPart
    if #candidates == 0 then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and obj.Name:lower():find("hook") then
                local p = obj:FindFirstChild("HookPoint") or obj:FindFirstChild("HitBox") or obj.PrimaryPart
                if p and p:IsA("BasePart") then
                    table.insert(candidates, p)
                end
            end
        end
    end

    for _, hookPart in ipairs(candidates) do
        if hookPart and hookPart.Parent and not hookPart:IsDescendantOf(myChar) then
            local isOccupied = false

            -- Check if hook is tagged or attributed as occupied
            if CollectionService and (CollectionService:HasTag(hookPart, "doing action") or CollectionService:HasTag(hookPart, "Occupied")) then
                isOccupied = true
            end
            if hookPart:GetAttribute("Occupied") == true or (hookPart.Parent and hookPart.Parent:GetAttribute("Occupied") == true) then
                isOccupied = true
            end
            if hookPart:GetAttribute("IsHooked") == true or (hookPart.Parent and hookPart.Parent:GetAttribute("IsHooked") == true) then
                isOccupied = true
            end
            if checkSabotaged then
                if CollectionService and CollectionService:HasTag(hookPart, "Broken") then
                    isOccupied = true
                end
                if hookPart:GetAttribute("Broken") == true or hookPart:GetAttribute("Sabotaged") == true
                    or (hookPart.Parent and (hookPart.Parent:GetAttribute("Broken") == true or hookPart.Parent:GetAttribute("Sabotaged") == true)) then
                    isOccupied = true
                end
            end

            -- Check if any survivor (player or bot) is currently attached to this hook (within 5.5 studs)
            if not isOccupied then
                if trackedSurvivors then
                    for sChar, _ in pairs(trackedSurvivors) do
                        if sChar and sChar.Parent and sChar ~= myChar and isCharacterHooked(sChar) then
                            local sHrp = sChar:FindFirstChild("HumanoidRootPart")
                            if sHrp and (sHrp.Position - hookPart.Position).Magnitude <= 5.5 then
                                isOccupied = true
                                break
                            end
                        end
                    end
                end
                if not isOccupied then
                    for _, plr in ipairs(Players:GetPlayers()) do
                        local sChar = plr.Character
                        if sChar and sChar ~= myChar and isCharacterHooked(sChar) then
                            local sHrp = sChar:FindFirstChild("HumanoidRootPart")
                            if sHrp and (sHrp.Position - hookPart.Position).Magnitude <= 5.5 then
                                isOccupied = true
                                break
                            end
                        end
                    end
                end
            end

            if not isOccupied then
                local dist = (myHrp.Position - hookPart.Position).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    bestHook = hookPart
                end
            end
        end
    end

    return bestHook, bestDist
end

-- Locates nearest unoccupied meat hook in the map (Standard v1.02)
local function findNearestAvailableHook()
    return findNearestAvailableHookCore(false)
end

-- Locates nearest unoccupied & unbroken meat hook (Auto Catch EX)
local function findNearestAvailableHookEX()
    return findNearestAvailableHookCore(true)
end

-- Calculates authoritative ground-level CFrame facing the hook (Standard v1.02)
local function getHookStandCFrame(hookPart)
    local hookModel = hookPart:FindFirstAncestorOfClass("Model") or hookPart.Parent
    local baseCF = hookPart.CFrame
    if hookModel and hookModel.PrimaryPart then
        baseCF = hookModel.PrimaryPart.CFrame
    end

    -- Determine ground level below hookPart via raycast
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local filterList = { hookModel }
    if player.Character then table.insert(filterList, player.Character) end
    rayParams.FilterDescendantsInstances = filterList

    local groundHit = workspace:Raycast(hookPart.Position, Vector3.new(0, -25, 0), rayParams)
    local groundY = groundHit and groundHit.Position.Y or (hookPart.Position.Y - 5.5)

    -- Stand on ground 2.2 studs in front of hook facing it
    local forwardDir = baseCF.LookVector
    if forwardDir.Magnitude < 0.1 then
        forwardDir = Vector3.new(0, 0, 1)
    end
    local standPos = Vector3.new(hookPart.Position.X, groundY + 3.0, hookPart.Position.Z) + (forwardDir * 2.2)
    local lookTarget = Vector3.new(hookPart.Position.X, standPos.Y, hookPart.Position.Z)
    return CFrame.lookAt(standPos, lookTarget)
end

-- Calculates unobstructed ground-level CFrame facing the hook (Auto Catch EX)
local function getHookStandCFrameEX(hookPart)
    local hookModel = hookPart:FindFirstAncestorOfClass("Model") or hookPart.Parent
    local baseCF = hookPart.CFrame
    if hookModel and hookModel.PrimaryPart then
        baseCF = hookModel.PrimaryPart.CFrame
    end

    -- Determine ground level below hookPart via raycast (ignoring non-solid trigger volumes)
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.RespectCanCollide = true
    local filterList = {}
    if hookModel then table.insert(filterList, hookModel) end
    if player.Character then table.insert(filterList, player.Character) end
    rayParams.FilterDescendantsInstances = filterList

    local groundHit = workspace:Raycast(hookPart.Position, Vector3.new(0, -25, 0), rayParams)
    local groundY = groundHit and groundHit.Position.Y or (hookPart.Position.Y - 5.5)

    local forwardDir = Vector3.new(baseCF.LookVector.X, 0, baseCF.LookVector.Z)
    forwardDir = (forwardDir.Magnitude > 0.1) and forwardDir.Unit or Vector3.new(0, 0, 1)
    local rightDir = Vector3.new(-forwardDir.Z, 0, forwardDir.X)

    local origin = Vector3.new(hookPart.Position.X, groundY + 2.9, hookPart.Position.Z)
    local standPos = origin + (forwardDir * 2.0)
    for _, dir in ipairs({ forwardDir, -forwardDir, rightDir, -rightDir }) do
        local wallCheck = workspace:Raycast(origin, dir * 2.3, rayParams)
        if not wallCheck then
            standPos = origin + (dir * 2.0)
            break
        end
    end

    local lookTarget = Vector3.new(hookPart.Position.X, standPos.Y, hookPart.Position.Z)
    return CFrame.lookAt(standPos, lookTarget)
end

-- Strict knockdown validator for EX target locking (ignores transient <=50 HP stumbles/PlatformStand)
local function isEXTargetTrulyKnocked(char)
    if not char or not char.Parent then return false end
    if char:GetAttribute("Knocked") == true or char:GetAttribute("isKnocked") == true
        or char:GetAttribute("Downed") == true or char:GetAttribute("isDowned") == true
        or char:GetAttribute("Down") == true or char:GetAttribute("Crawling") == true
        or char:GetAttribute("BleedingOut") == true then
        return true
    end
    if CollectionService and (CollectionService:HasTag(char, "Knocked") or CollectionService:HasTag(char, "Downed")) then
        return true
    end
    local kChild = char:FindFirstChild("Knocked") or char:FindFirstChild("Downed") or char:FindFirstChild("downed")
    if kChild and kChild:IsA("BoolValue") and kChild.Value == true then
        return true
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health > 0 and hum.Health <= 20 then
        return true
    end
    return false
end

-- Strict out-of-play check for EX target locking (hooked, carried, dead, escaped, or lobby)
local function isEXTargetOutOfPlay(char)
    if not char or not char.Parent then return true end
    if char == player.Character then return true end
    if not char:FindFirstChild("HumanoidRootPart") then return true end

    if char:GetAttribute("IsDead") == true or char:GetAttribute("Sacrificed") == true
        or char:GetAttribute("Escaped") == true or char:GetAttribute("HasEscaped") == true then
        return true
    end
    local plr = Players:GetPlayerFromCharacter(char)
    if plr and (plr:GetAttribute("IsDead") == true or plr:GetAttribute("Sacrificed") == true
        or plr:GetAttribute("Escaped") == true or plr:GetAttribute("HasEscaped") == true) then
        return true
    end
    if isEntityInLobbyOrSpectating(char, plr) then
        return true
    end
    if isCharacterHooked(char) then
        return true
    end
    if char:GetAttribute("IsCarried") == true or char:GetAttribute("isCarried") == true
        or char:GetAttribute("BeingCarried") == true or char:FindFirstChild("Carried") ~= nil then
        return true
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health <= 0 then
        return true
    end
    return false
end

-- Suppresses KillerCollider & torso collision during EX overlap so survivors cannot bounce the Killer away
local function setKillerChaseCollision(myChar, enabled)
    if not myChar then return end
    pcall(function()
        for _, obj in ipairs(myChar:GetChildren()) do
            if obj:IsA("BasePart") then
                local n = obj.Name
                if n == "KillerCollider" or n == "Torso" or n == "UpperTorso" or n == "LowerTorso" then
                    obj.CanCollide = enabled
                end
            end
        end
    end)
end

-- Cached unobstructed stand offset for stationary survivors (eliminates wall/generator occlusion misses)
local cachedClearTarget = nil
local cachedClearPos = nil
local cachedClearAngleIdx = -1
local cachedClearOffset = nil

local function getClearStationaryOffset(myChar, targetChar, sHrp, angleIdx)
    local idx = tonumber(angleIdx) or 0
    if cachedClearTarget == targetChar
        and cachedClearAngleIdx == idx
        and cachedClearPos
        and (sHrp.Position - cachedClearPos).Magnitude <= 0.35
        and cachedClearOffset then
        return cachedClearOffset
    end

    local back = -Vector3.new(sHrp.CFrame.LookVector.X, 0, sHrp.CFrame.LookVector.Z)
    if back.Magnitude < 0.1 then back = Vector3.new(0, 0, -1) else back = back.Unit end
    local right = Vector3.new(-back.Z, 0, back.X)

    local dirs = {
        back,
        right,
        -right,
        -back,
        (back + right).Unit,
        (back - right).Unit,
        (-back + right).Unit,
        (-back - right).Unit
    }

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.RespectCanCollide = true
    local filterList = {}
    if targetChar then table.insert(filterList, targetChar) end
    if myChar then table.insert(filterList, myChar) end
    rayParams.FilterDescendantsInstances = filterList

    -- Rotate radius slightly closer on retries to break stubborn prop occlusion
    local radius = (idx >= 4) and 0.72 or ((idx >= 1) and 0.90 or 1.05)
    local chosenOffset = dirs[1] * radius

    for step = 0, #dirs - 1 do
        local d = dirs[((idx + step) % #dirs) + 1]
        local obsHit = workspace:Raycast(sHrp.Position, d * (radius + 0.55), rayParams)
        if not obsHit then
            local candPos = sHrp.Position + (d * radius)
            local floorHit = workspace:Raycast(candPos + Vector3.new(0, 0.5, 0), Vector3.new(0, -10, 0), rayParams)
            if floorHit then
                chosenOffset = d * radius
                break
            end
        end
    end

    -- Fallback: ultra-close 0.55 stud overlap if boxed tightly in a corner
    if idx > 0 and workspace:Raycast(sHrp.Position, chosenOffset.Unit * (chosenOffset.Magnitude + 0.3), rayParams) then
        chosenOffset = dirs[(idx % #dirs) + 1] * 0.55
    end

    cachedClearTarget = targetChar
    cachedClearPos = sHrp.Position
    cachedClearAngleIdx = idx
    cachedClearOffset = chosenOffset
    return chosenOffset
end

-- Calculates velocity-predicted intercept CFrame (moving) or obstacle-clear sweet-spot CFrame (stationary)
local function computeInterceptCFrame(sHrp, frameVel, targetChar, stationaryAngleIdx)
    local rawVel = sHrp.AssemblyLinearVelocity
    local horizRaw = Vector3.new(rawVel.X, 0, rawVel.Z)
    local horizVel = horizRaw
    if frameVel then
        local horizFrame = Vector3.new(frameVel.X, 0, frameVel.Z)
        if horizFrame.Magnitude > horizRaw.Magnitude and horizFrame.Magnitude <= 35 then
            horizVel = horizFrame
        end
    end
    local speed = horizVel.Magnitude
    local interceptPos
    if speed > 1.5 then
        local moveDir = horizVel.Unit
        local leadDist = math.clamp(speed * 0.11, 0.9, 2.6)
        interceptPos = sHrp.Position + (moveDir * leadDist) + Vector3.new(0, 0.1, 0)
    else
        local offset = getClearStationaryOffset(player.Character, targetChar, sHrp, stationaryAngleIdx or 0)
        interceptPos = sHrp.Position + offset + Vector3.new(0, 0.05, 0)
    end
    local lookTarget = Vector3.new(sHrp.Position.X, interceptPos.Y, sHrp.Position.Z)
    return CFrame.lookAt(interceptPos, lookTarget), speed
end

-- Comprehensive Auto Hit execution across Android executors and PC (Shared core for Standard & EX)
local lastGuiInputHitTime = 0
local cachedHitChar = nil
local cachedWeaponParts = {}
local lastWeaponScanTime = 0

local function refreshCachedWeaponParts(myChar)
    local now = tick()
    if cachedHitChar == myChar and (now - lastWeaponScanTime) < 1.0 then
        return
    end
    cachedHitChar = myChar
    lastWeaponScanTime = now
    cachedWeaponParts = {}
    local rightArm = myChar:FindFirstChild("Right Arm") or myChar:FindFirstChild("RightHand")
    if rightArm and rightArm:IsA("BasePart") then
        table.insert(cachedWeaponParts, rightArm)
    end
    for _, part in ipairs(myChar:GetDescendants()) do
        if part:IsA("BasePart") and part ~= rightArm then
            local pLower = part.Name:lower()
            if pLower:find("weapon") or pLower:find("blade") or pLower:find("knife") or pLower:find("machete") or pLower:find("axe") or pLower:find("cleaver") then
                table.insert(cachedWeaponParts, part)
            end
        end
    end
end

local function executeKillerHitCore(targetChar, useIntercept, fireSwingRemotes, frameVel, stationaryAngleIdx, includeLunge)
    local myChar = player.Character
    if not myChar then return end

    local myHrp = myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end

    local sHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
    if sHrp then
        if useIntercept then
            local targetCF = computeInterceptCFrame(sHrp, frameVel, targetChar, stationaryAngleIdx)
            myHrp.CFrame = targetCF
            myHrp.AssemblyLinearVelocity = Vector3.zero
            myHrp.AssemblyAngularVelocity = Vector3.zero
        else
            -- Snap Killer body directly towards survivor
            local lookTarget = Vector3.new(sHrp.Position.X, myHrp.Position.Y, sHrp.Position.Z)
            myHrp.CFrame = CFrame.lookAt(myHrp.Position, lookTarget)

            -- Melee Range Step: ensure close physical proximity (< 2.5 studs)
            local curDist = (myHrp.Position - sHrp.Position).Magnitude
            if curDist > 2.5 then
                local behindPos = sHrp.Position - (sHrp.CFrame.LookVector * 1.8) + Vector3.new(0, 0.2, 0)
                myHrp.CFrame = CFrame.lookAt(behindPos, sHrp.Position)
            end
        end
    end

    local remotes = getVDRemotes()

    -- Official Violence District Attack Remotes
    if fireSwingRemotes and remotes.Attacks then
        if remotes.Attacks:FindFirstChild("BasicAttack") then
            pcall(function() remotes.Attacks.BasicAttack:FireServer() end)
        end
        if includeLunge ~= false and remotes.Attacks:FindFirstChild("Lunge") then
            pcall(function() remotes.Attacks.Lunge:FireServer() end)
        end
    end

    -- Multi-limb target parts (HumanoidRootPart + Torso + Head) for LungeDetect & firetouchinterest
    local hitParts = {}
    if sHrp then table.insert(hitParts, sHrp) end
    local torsoPart = targetChar and (targetChar:FindFirstChild("UpperTorso") or targetChar:FindFirstChild("Torso"))
    if torsoPart and torsoPart:IsA("BasePart") then
        table.insert(hitParts, torsoPart)
    end
    if useIntercept then
        local headPart = targetChar and targetChar:FindFirstChild("Head")
        if headPart and headPart:IsA("BasePart") then
            table.insert(hitParts, headPart)
        end
    end

    -- Official LungeDetect blade collision report (essential for hitting moving & crouched/stationary targets in EX mode)
    if useIntercept and #hitParts > 0 and remotes.Attacks and remotes.Attacks:FindFirstChild("LungeDetect") then
        for _, hp in ipairs(hitParts) do
            pcall(function() remotes.Attacks.LungeDetect:FireServer(hp, hp.Position) end)
        end
    end

    -- Physical Weapon & Arm Hitbox Collision Simulation (cached for zero-lag 0.001s spam)
    if typeof(firetouchinterest) == "function" and #hitParts > 0 then
        pcall(function()
            refreshCachedWeaponParts(myChar)
            local touchTargets = useIntercept and hitParts or { hitParts[1] }
            for _, part in ipairs(cachedWeaponParts) do
                if part and part.Parent then
                    for _, tp in ipairs(touchTargets) do
                        firetouchinterest(part, tp, 0)
                        firetouchinterest(part, tp, 1)
                    end
                end
            end
        end)
    end

    if not fireSwingRemotes then return end

    -- Equipped Tool Activation
    for _, item in ipairs(myChar:GetChildren()) do
        if item:IsA("Tool") then
            pcall(function() item:Activate() end)
        end
    end

    -- Mobile Attack GUI Button + Center Tap (throttled to 0.12s to prevent Android touch queue lockup)
    if (tick() - lastGuiInputHitTime) >= 0.12 then
        lastGuiInputHitTime = tick()
        pcall(function()
            local pg = player:FindFirstChild("PlayerGui")
            if pg then
                for _, guiName in ipairs({"Slasher-mob", "Slasher", "Slasher-con", "Killer-mob", "KillerGui", "MobileGui"}) do
                    local g = pg:FindFirstChild(guiName)
                    if g then
                        for _, btn in ipairs(g:GetDescendants()) do
                            if btn:IsA("GuiButton") and (btn.Name:lower() == "attack" or btn.Name:lower():find("slash") or btn.Name:lower():find("punch") or btn.Name:lower():find("hit")) then
                                if typeof(firesignal) == "function" then
                                    pcall(firesignal, btn.MouseButton1Down)
                                    pcall(firesignal, btn.Activated)
                                    pcall(firesignal, btn.MouseButton1Up)
                                    pcall(firesignal, btn.MouseButton1Click)
                                end
                                local bPos = btn.AbsolutePosition + (btn.AbsoluteSize / 2)
                                pcall(function()
                                    if VirtualInputManager and typeof(VirtualInputManager.SendTouchEvent) == "function" then
                                        VirtualInputManager:SendTouchEvent(3, 0, bPos.X, bPos.Y)
                                        VirtualInputManager:SendTouchEvent(3, 2, bPos.X, bPos.Y)
                                    end
                                end)
                            end
                        end
                    end
                end
            end
        end)

        pcall(function()
            local cam = workspace.CurrentCamera
            local vp = cam and cam.ViewportSize or Vector2.new(800, 600)
            local cx = vp.X / 2
            local cy = vp.Y / 2
            if VirtualInputManager then
                if typeof(VirtualInputManager.SendMouseButtonEvent) == "function" then
                    VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
                    VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
                end
                if typeof(VirtualInputManager.SendTouchEvent) == "function" then
                    VirtualInputManager:SendTouchEvent(3, 0, cx, cy)
                    VirtualInputManager:SendTouchEvent(3, 2, cx, cy)
                end
            end
        end)
    end
end

local function executeKillerHit(targetChar)
    executeKillerHitCore(targetChar, false, true, nil, 0, true)
end

local function executeKillerHitEX(targetChar, fireSwingRemotes, frameVel, stationaryAngleIdx, includeLunge)
    executeKillerHitCore(targetChar, true, fireSwingRemotes, frameVel, stationaryAngleIdx, includeLunge)
end

-- Continuous frame-locked Auto Aim for Killer (Works whether Auto Catch is ON or OFF)
updateKillerAim = function()
    pcall(function()
        RunService:UnbindFromRenderStep("KillerAutoAim")
    end)
    if killerAimConn then
        pcall(function() killerAimConn:Disconnect() end)
        killerAimConn = nil
    end

    if not autoAimSurvivorEnabled then return end

    local function performAim()
        pcall(function()
            if not autoAimSurvivorEnabled then return end
            if autoCatchEXEnabled and (exFailPauseActive or exPostKnockPauseActive) then return end

            local myChar = player.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if not myHrp then return end

            local ignoreBots = (autoCatchEnabled or autoCatchEXEnabled) and catchBotsIgnoredActive
            local target = currentKillerTarget
            if target and ignoreBots and isSurvivorBot(target) then
                target = nil
            end
            local targetLockedEX = autoCatchEXEnabled
                and target
                and target.Parent
                and not isEXTargetOutOfPlay(target)
                and not isEXTargetTrulyKnocked(target)
            if not target or not target.Parent or (not targetLockedEX and not isSurvivorValidTarget(target)) then
                local nearest, nDist = findNearestSurvivor(ignoreBots)
                if nearest then
                    target = nearest
                    currentKillerTarget = nearest
                else
                    return
                end
            end

            local sHrp = target:FindFirstChild("HumanoidRootPart")
            if not sHrp then return end

            local cam = workspace.CurrentCamera
            if not cam then return end

            local aimYOffset = autoCatchEXEnabled and 0.25 or 1.2
            local aimPos = sHrp.Position + Vector3.new(0, aimYOffset, 0)

            -- Lock Camera directly at Survivor
            cam.CFrame = CFrame.lookAt(cam.CFrame.Position, aimPos)

            -- Lock Killer body towards Survivor for server hit validation
            local lookTarget = Vector3.new(sHrp.Position.X, myHrp.Position.Y, sHrp.Position.Z)
            myHrp.CFrame = CFrame.lookAt(myHrp.Position, lookTarget)
        end)
    end

    local ok = pcall(function()
        RunService:BindToRenderStep("KillerAutoAim", 201, performAim)
    end)
    if not ok then
        killerAimConn = RunService.RenderStepped:Connect(performAim)
    end
end

-- Standalone Killer Combat Loop (Runs when Auto Aim or Auto Hit is ON, even if Auto Catch is OFF!)
task.spawn(function()
    while scriptRunning do
        pcall(function()
            if not scriptRunning then return end
            if (autoAimSurvivorEnabled or autoHitSurvivorEnabled) and not autoCatchEnabled and not autoCatchEXEnabled then
                local myChar = player.Character
                local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                if myHrp then
                    local targetSurvivor, dist = findNearestSurvivor()
                    if targetSurvivor then
                        currentKillerTarget = targetSurvivor

                        -- Auto Hit trigger when within hit reach distance (slider: 6 - 20 studs, default 10)
                        if autoHitSurvivorEnabled and dist <= hitReachDistance then
                            if (tick() - lastKillerHitTime) >= 0.08 then
                                lastKillerHitTime = tick()
                                executeKillerHit(targetSurvivor)
                            end
                        end
                    else
                        currentKillerTarget = nil
                    end
                end
            end
        end)
        task.wait(0.001)
    end
end)

-- Unified travel function to reach any 3D world coordinate
local function travelToTargetLocation(targetPos, stopReach, activeCheck)
    local myChar = player.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local hum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    if not myHrp or not targetPos then return false end

    local reach = stopReach or 5.0
    local dist = (myHrp.Position - targetPos).Magnitude
    if dist <= reach then return true end

    local checkActive = activeCheck or function() return true end

    if killerTravelMode == "Instant Teleport" then
        local fromPos = myHrp.Position
        local dir = (targetPos - fromPos)
        local horiz = Vector3.new(dir.X, 0, dir.Z)
        local standPos
        if horiz.Magnitude > 0.5 then
            standPos = targetPos - horiz.Unit * 2.5 + Vector3.new(0, 0.5, 0)
        else
            standPos = targetPos + Vector3.new(0, 0.5, 2.5)
        end
        local targetCF = CFrame.lookAt(standPos, Vector3.new(targetPos.X, standPos.Y, targetPos.Z))
        for attempt = 1, 3 do
            myHrp.CFrame = targetCF
            myHrp.AssemblyLinearVelocity = Vector3.zero
            myHrp.AssemblyAngularVelocity = Vector3.zero
            task.wait(0.001)
            if (myHrp.Position - targetPos).Magnitude <= (reach + 1.5) then
                break
            end
        end
        return (myHrp.Position - targetPos).Magnitude <= (reach + 2.0)

    elseif killerTravelMode == "Safe Teleport" then
        startTravelNoClip()
        local step = math.clamp(safeTeleportStep or 3.5, 1.0, 6.0)
        local fromPos = myHrp.Position
        local toDest = (targetPos - fromPos)
        local totalDist = toDest.Magnitude

        if totalDist <= reach then
            stopTravelNoClip()
            return true
        end

        local dir = (totalDist > 0.001) and toDest.Unit or Vector3.new(0, 0, 1)
        local numSteps = math.max(1, math.ceil(totalDist / step))

        for s = 1, numSteps do
            if not checkActive() or not scriptRunning then break end

            local frac = math.min(1.0, s / numSteps)
            local nextPos = fromPos:Lerp(targetPos, frac)

            myHrp.CFrame = CFrame.lookAt(nextPos, nextPos + dir)
            myHrp.AssemblyLinearVelocity = Vector3.zero
            myHrp.AssemblyAngularVelocity = Vector3.zero

            task.wait(0.015)

            if (myHrp.Position - targetPos).Magnitude <= reach then
                break
            end
        end

        pcall(function()
            myHrp.CFrame = CFrame.lookAt(targetPos, targetPos + dir)
            myHrp.AssemblyLinearVelocity = Vector3.zero
            myHrp.AssemblyAngularVelocity = Vector3.zero
        end)
        task.wait(0.02)

        stopTravelNoClip()
        return (myHrp.Position - targetPos).Magnitude <= (reach + 2.0)

    elseif killerTravelMode == "Run Normally" then
        local waypoints = computeSmartWaypoints(myHrp.Position, targetPos, nil, nil, nil)
        if not waypoints or #waypoints == 0 then
            waypoints = { { Position = myHrp.Position }, { Position = targetPos } }
        end

        pcall(function() myChar:SetAttribute("Sprinting", true) end)

        for wpIdx, wp in ipairs(waypoints) do
            if not checkActive() then break end
            if (myHrp.Position - targetPos).Magnitude <= reach then break end

            if wp.Action == Enum.PathWaypointAction.Jump and hum then
                hum.Jump = true
            end

            if hum then
                hum:MoveTo(wp.Position)

                local wpStartTime = tick()
                local lastPos = myHrp.Position
                local lastCheckTime = tick()
                local stuckCounter = 0

                while checkActive() and (myHrp.Position - wp.Position).Magnitude > 2.8 and (tick() - wpStartTime) < 3.5 do
                    if (tick() - lastCheckTime) >= 0.15 then
                        local distMoved = (myHrp.Position - lastPos).Magnitude
                        lastPos = myHrp.Position
                        lastCheckTime = tick()

                        if distMoved < 0.25 then
                            stuckCounter = stuckCounter + 1
                            if stuckCounter >= 2 then
                                hum.Jump = true
                                local hasWall, _, hitPos, hitNormal = checkWallCollision(myHrp.Position, wp.Position, myChar)
                                if hasWall and hitNormal then
                                    local sideDeflect = Vector3.new(-hitNormal.Z, 0, hitNormal.X).Unit * 3.0
                                    hum:MoveTo(myHrp.Position + sideDeflect)
                                    task.wait(0.18)
                                end
                                hum:MoveTo(wp.Position)
                                stuckCounter = 0
                            end
                        else
                            stuckCounter = 0
                        end
                    end
                    task.wait(0.04)
                end
            end
        end
        return (myHrp.Position - targetPos).Magnitude <= (reach + 2.5)
    end

    return false
end

local function travelToSurvivor(targetChar)
    local myChar = player.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local hum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    if not myHrp or not targetChar then return false end

    local targetHrp = targetChar:FindFirstChild("HumanoidRootPart")
    if not targetHrp then return false end

    local targetPos = targetHrp.Position
    local dist = (myHrp.Position - targetPos).Magnitude
    if dist <= 2.2 then return true end

    -- 1. INSTANT TELEPORT (ALWAYS BEHIND SURVIVOR AT 2.2 STUDS FACING THEIR BACK)
    if killerTravelMode == "Instant Teleport" then
        local behindPos = targetPos - (targetHrp.CFrame.LookVector * 2.2) + Vector3.new(0, 0.2, 0)
        local behindCF = CFrame.lookAt(behindPos, targetPos)
        myHrp.CFrame = behindCF
        myHrp.AssemblyLinearVelocity = Vector3.zero
        myHrp.AssemblyAngularVelocity = Vector3.zero
        task.wait(0.001)
        return (myHrp.Position - targetPos).Magnitude <= 3.8

    -- 2. SAFE TELEPORT (WAYPOINTS CLOSING IN TO 2.8 STUDS)
    elseif killerTravelMode == "Safe Teleport" then
        return travelToTargetLocation(targetHrp.Position, 2.8, function()
            return (autoCatchEnabled or autoCatchEXEnabled) and targetChar.Parent and isSurvivorValidTarget(targetChar) and not isKillerStunnedOrLocked(myChar)
        end)

    -- 3. RUN NORMALLY (WAYPOINTS CLOSING IN TO 3.2 STUDS)
    elseif killerTravelMode == "Run Normally" then
        return travelToTargetLocation(targetHrp.Position, 3.2, function()
            return (autoCatchEnabled or autoCatchEXEnabled) and targetChar.Parent and isSurvivorValidTarget(targetChar) and not isKillerStunnedOrLocked(myChar)
        end)
    end

    return false
end

-- ============================================================
-- AUTO HOOK SURVIVOR BACKGROUND LOOP
-- ============================================================
task.spawn(function()
    while scriptRunning do
        pcall(function()
            if not scriptRunning then return end
            if autoHookSurvivorEnabled and not autoCatchEnabled and not autoCatchEXEnabled and not isHookActionActive then
                local myChar = player.Character
                local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                if not myHrp then return end

                local carrying = isKillerCarrying(myChar)

                if carrying then
                    -- --------------------------------------------------------
                    -- STAGE 2: CARRYING SURVIVOR -> TRANSPORT TO NEAREST HOOK
                    -- --------------------------------------------------------
                    local hookPart, hookDist = findNearestAvailableHook()
                    if hookPart then
                        isHookActionActive = true

                        -- Move to hook if not in reach
                        if hookDist > 4.5 then
                            travelToTargetLocation(hookPart.Position, 4.0, function()
                                return autoHookSurvivorEnabled and not autoCatchEnabled and not autoCatchEXEnabled and isKillerCarrying(myChar)
                            end)
                        end

                        -- When at hook (<= 8.5 studs): execute hang
                        local currentDist = (myHrp.Position - hookPart.Position).Magnitude
                        if currentDist <= 8.5 then
                            local standCF = getHookStandCFrame(hookPart)
                            myHrp.CFrame = standCF
                            myHrp.AssemblyLinearVelocity = Vector3.zero
                            myHrp.AssemblyAngularVelocity = Vector3.zero

                            local reqId = HttpService:GenerateGUID(false)
                            local remotes = getVDRemotes()

                            -- 1. Fire HookEvent (Client -> Server initiation)
                            if remotes.Carry and remotes.Carry:FindFirstChild("HookEvent") then
                                pcall(function() remotes.Carry.HookEvent:FireServer(hookPart, reqId, myChar) end)
                            end

                            -- 2. Fire ProximityPrompts on the hook
                            pcall(function()
                                local hookModel = hookPart:FindFirstAncestorOfClass("Model") or hookPart.Parent
                                if hookModel then
                                    for _, prompt in ipairs(hookModel:GetDescendants()) do
                                        if prompt:IsA("ProximityPrompt") then
                                            if typeof(fireproximityprompt) == "function" then
                                                pcall(function() fireproximityprompt(prompt) end)
                                            end
                                        end
                                    end
                                end
                            end)

                            -- 3. Small delay matching native game interaction cycle before HookCommit
                            task.wait(0.08)

                            -- 4. Fire HookCommit (Client -> Server confirmation)
                            if remotes.Carry and remotes.Carry:FindFirstChild("HookCommit") then
                                pcall(function() remotes.Carry.HookCommit:FireServer(hookPart, reqId, myChar) end)
                            end

                            -- Wait for hook animation/server sync with fallback re-commit
                            local waitTimeout = tick() + 2.5
                            while tick() < waitTimeout and isKillerCarrying(myChar) do
                                task.wait(0.1)
                                if isKillerCarrying(myChar) and remotes.Carry and remotes.Carry:FindFirstChild("HookCommit") then
                                    pcall(function() remotes.Carry.HookCommit:FireServer(hookPart, reqId, myChar) end)
                                end
                            end
                            if not isKillerCarrying(myChar) then
                                WindUI:Notify({ Title = "🪝 Survivor Hooked!", Content = "Target successfully hung on hook.", Duration = 2.5 })
                            end
                        end

                        isHookActionActive = false
                    end

                else
                    -- --------------------------------------------------------
                    -- STAGE 1: NOT CARRYING -> FIND DOWNED SURVIVOR & PICK UP
                    -- --------------------------------------------------------
                    local downedSurvivor, downedDist = findNearestDownedSurvivor()
                    if downedSurvivor and downedSurvivor:FindFirstChild("HumanoidRootPart") then
                        isHookActionActive = true
                        local dHrp = downedSurvivor.HumanoidRootPart

                        -- Move to downed survivor if not in reach
                        if downedDist > 4.5 then
                            travelToTargetLocation(dHrp.Position, 4.0, function()
                                return autoHookSurvivorEnabled and not autoCatchEnabled and not autoCatchEXEnabled and not isKillerCarrying(myChar) and isSurvivorDowned(downedSurvivor)
                            end)
                        end

                        -- When at survivor (<= 8.5 studs): pick up / carry
                        local currentDist = (myHrp.Position - dHrp.Position).Magnitude
                        if currentDist <= 8.5 and isSurvivorDowned(downedSurvivor) then
                            local lookTarget = Vector3.new(dHrp.Position.X, myHrp.Position.Y, dHrp.Position.Z)
                            myHrp.CFrame = CFrame.lookAt(myHrp.Position, lookTarget)

                            local remotes = getVDRemotes()

                            -- Fire Carry remote from the dump.lua
                            if remotes.Carry and remotes.Carry:FindFirstChild("CarrySurvivorEvent") then
                                pcall(function() remotes.Carry.CarrySurvivorEvent:FireServer(downedSurvivor) end)
                            end

                            -- Trigger ProximityPrompts on downed survivor
                            pcall(function()
                                for _, prompt in ipairs(downedSurvivor:GetDescendants()) do
                                    if prompt:IsA("ProximityPrompt") then
                                        if typeof(fireproximityprompt) == "function" then
                                            pcall(function() fireproximityprompt(prompt) end)
                                        end
                                    end
                                end
                            end)

                            -- Wait briefly for pickup to register
                            local waitTimeout = tick() + 2.0
                            while tick() < waitTimeout and not isKillerCarrying(myChar) do
                                task.wait(0.1)
                            end
                            if isKillerCarrying(myChar) then
                                WindUI:Notify({ Title = "🎒 Survivor Picked Up", Content = "Carrying survivor to nearest hook...", Duration = 2 })
                            end
                        end

                        isHookActionActive = false
                    end
                end
            end
        end)
        task.wait(0.1)
    end
end)

V_KillerSection:Dropdown({
    Title = "Killer Travel Mode",
    Description = "Method used to catch up to survivors & transport to hooks",
    Values = { "Instant Teleport", "Safe Teleport", "Run Normally" },
    Value = "Instant Teleport",
    Callback = function(v)
        killerTravelMode = v
    end
})

-- ============================================================
-- TELEPORT TO SPECIFIC SURVIVOR (CHOOSE FROM LIST)
-- ============================================================
local selectedTeleportSurvivor = nil
local survivorDropdownRef = nil

local function getAliveSurvivorList()
    local result = {}
    local myChar = player.Character
    local seen = {}

    -- 1. Check all survivors currently detected & tracked by autonomous supervisor!
    if trackedSurvivors then
        for c, data in pairs(trackedSurvivors) do
            if c and c.Parent and c ~= myChar and not seen[c] then
                local hrp = c:FindFirstChild("HumanoidRootPart")
                if hrp and c:IsDescendantOf(workspace) then
                    seen[c] = true
                    local plr = (typeof(data) == "table" and data.player) or Players:GetPlayerFromCharacter(c)
                    local pName = (typeof(data) == "table" and data.name) or (plr and (plr.DisplayName or plr.Name)) or c.Name
                    local isBot = (plr == nil)
                    local status = (isCharacterKnocked and isCharacterKnocked(c)) and " [Downed]" or ((isCharacterHooked and isCharacterHooked(c)) and " [Hooked]" or "")
                    local botTag = isBot and " [Bot]" or ""
                    local label = string.format("%s%s%s", pName, botTag, status)
                    table.insert(result, {
                        label = label,
                        player = plr,
                        character = c,
                        name = pName
                    })
                end
            end
        end
    end

    -- 2. Check Players
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and plr.Character ~= myChar and not seen[plr.Character] then
            local c = plr.Character
            local hrp = c:FindFirstChild("HumanoidRootPart")
            if hrp and c:IsDescendantOf(workspace) and not isEntityInLobbyOrSpectating(c, plr) then
                local isKiller = isCharacterKiller(c, plr) or (getKiller and c == getKiller())
                if not isKiller then
                    seen[c] = true
                    local pName = plr.DisplayName or plr.Name
                    local status = isCharacterKnocked(c) and " [Downed]" or (isCharacterHooked(c) and " [Hooked]" or "")
                    local label = string.format("%s (@%s)%s", pName, plr.Name, status)
                    table.insert(result, {
                        label = label,
                        player = plr,
                        character = c,
                        name = plr.Name
                    })
                end
            end
        end
    end

    -- 3. Check workspace subfolders & top-level models for bot/NPC survivors
    local searchContainers = { workspace }
    for _, fName in ipairs({ "Bots", "NPCs", "Survivors", "Players", "Characters", "Match", "Entities", "Map" }) do
        local folder = workspace:FindFirstChild(fName)
        if folder and (folder:IsA("Folder") or folder:IsA("Model")) then
            table.insert(searchContainers, folder)
        end
    end

    for _, container in ipairs(searchContainers) do
        for _, obj in ipairs(container:GetChildren()) do
            if obj:IsA("Model") and obj ~= myChar and not seen[obj] then
                local hrp = obj:FindFirstChild("HumanoidRootPart")
                local hum = obj:FindFirstChildOfClass("Humanoid")
                if hrp and hum and obj:IsDescendantOf(workspace) and not isEntityInLobbyOrSpectating(obj) then
                    local plr = Players:GetPlayerFromCharacter(obj)
                    local isKiller = isCharacterKiller(obj, plr) or (getKiller and obj == getKiller())
                    if not isKiller then
                        seen[obj] = true
                        local pName = plr and (plr.DisplayName or plr.Name) or obj.Name
                        local isBot = (plr == nil)
                        local status = isCharacterKnocked(obj) and " [Downed]" or (isCharacterHooked(obj) and " [Hooked]" or "")
                        local botTag = isBot and " [Bot]" or ""
                        local label = string.format("%s%s%s", pName, botTag, status)
                        table.insert(result, {
                            label = label,
                            player = plr,
                            character = obj,
                            name = pName
                        })
                    end
                end
            end
        end
    end

    -- 4. Check CollectionService tagged survivors/bots
    if CollectionService then
        for _, tag in ipairs({ "Survivor", "Survivors", "Bot", "NPC", "SurvivorBot", "CarryTestDummy" }) do
            for _, obj in ipairs(CollectionService:GetTagged(tag)) do
                if obj:IsA("Model") and obj ~= myChar and not seen[obj] then
                    local hrp = obj:FindFirstChild("HumanoidRootPart")
                    local hum = obj:FindFirstChildOfClass("Humanoid")
                    if hrp and hum and obj:IsDescendantOf(workspace) and not isEntityInLobbyOrSpectating(obj) then
                        local plr = Players:GetPlayerFromCharacter(obj)
                        local isKiller = isCharacterKiller(obj, plr) or (getKiller and obj == getKiller())
                        if not isKiller then
                            seen[obj] = true
                            local pName = plr and (plr.DisplayName or plr.Name) or obj.Name
                            local isBot = (plr == nil)
                            local status = isCharacterKnocked(obj) and " [Downed]" or (isCharacterHooked(obj) and " [Hooked]" or "")
                            local botTag = isBot and " [Bot]" or ""
                            local label = string.format("%s%s%s", pName, botTag, status)
                            table.insert(result, {
                                label = label,
                                player = plr,
                                character = obj,
                                name = pName
                            })
                        end
                    end
                end
            end
        end
    end

    return result
end

local function getAliveSurvivorLabels()
    local list = getAliveSurvivorList()
    local labels = {}
    for _, s in ipairs(list) do
        table.insert(labels, s.label)
    end
    if #labels == 0 then
        table.insert(labels, "No Survivors Found")
    end
    return labels
end

local initialSurvivorLabels = getAliveSurvivorLabels()
survivorDropdownRef = V_KillerSection:Dropdown({
    Title = "Select Survivor (Teleport Target)",
    Description = "Choose an active survivor from the match to teleport to",
    Values = initialSurvivorLabels,
    Value = initialSurvivorLabels[1],
    Callback = function(v)
        selectedTeleportSurvivor = v
    end
})

V_KillerSection:Button({
    Title = "🔄 Refresh Survivor List",
    Description = "Scans match and refreshes the survivor list in the dropdown above",
    Callback = function()
        local newLabels = getAliveSurvivorLabels()
        pcall(function()
            if survivorDropdownRef and survivorDropdownRef.Refresh then
                survivorDropdownRef:Refresh(newLabels)
            elseif survivorDropdownRef and survivorDropdownRef.SetValues then
                survivorDropdownRef:SetValues(newLabels)
            end
            if survivorDropdownRef then
                survivorDropdownRef.Values = newLabels
            end
        end)
        local count = (newLabels[1] == "No Survivors Found") and 0 or #newLabels
        WindUI:Notify({ Title = "Survivor List Refreshed", Content = string.format("Found %d active survivor(s).", count), Duration = 2.5 })
    end
})

-- Dynamic Auto-Refresher for Survivor Dropdown (Refreshes automatically every 1.5s during match)
task.spawn(function()
    while scriptRunning do
        pcall(function()
            if survivorDropdownRef then
                local liveList = getAliveSurvivorList()
                local newLabels = {}
                for _, s in ipairs(liveList) do
                    table.insert(newLabels, s.label)
                end
                if #newLabels == 0 then
                    table.insert(newLabels, "No Survivors Found")
                end

                local currentVals = survivorDropdownRef.Values or {}
                local changed = (#currentVals ~= #newLabels)
                if not changed then
                    for i, lbl in ipairs(newLabels) do
                        local curItem = typeof(currentVals[i]) == "table" and currentVals[i].Title or currentVals[i]
                        if curItem ~= lbl then
                            changed = true
                            break
                        end
                    end
                end

                if changed then
                    if survivorDropdownRef.Refresh then
                        survivorDropdownRef:Refresh(newLabels)
                    elseif survivorDropdownRef.SetValues then
                        survivorDropdownRef:SetValues(newLabels)
                    end
                    survivorDropdownRef.Values = newLabels

                    -- Auto-select first survivor if current selection is invalid or "No Survivors Found"
                    local validSelection = false
                    if selectedTeleportSurvivor and selectedTeleportSurvivor ~= "No Survivors Found" then
                        for _, lbl in ipairs(newLabels) do
                            if lbl == selectedTeleportSurvivor then
                                validSelection = true
                                break
                            end
                        end
                    end
                    if not validSelection and newLabels[1] ~= "No Survivors Found" then
                        selectedTeleportSurvivor = newLabels[1]
                        if survivorDropdownRef.Select then
                            pcall(function() survivorDropdownRef:Select(newLabels[1]) end)
                        end
                    end
                end
            end
        end)
        task.wait(1.5)
    end
end)

V_KillerSection:Button({
    Title = "⚡ Teleport to Chosen Survivor",
    Description = "Instantly teleports 2.5 studs directly behind the selected survivor facing their back",
    Callback = function()
        local myChar = player.Character
        local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myHrp then
            WindUI:Notify({ Title = "Teleport Failed", Content = "Your character is not available!", Duration = 2 })
            return
        end

        -- Fetch live survivor list
        local survivors = getAliveSurvivorList()

        -- Robust fallbacks if getAliveSurvivorList had 0 entries
        if #survivors == 0 then
            local nearest, nDist = findNearestSurvivor()
            if nearest and nearest:FindFirstChild("HumanoidRootPart") then
                table.insert(survivors, {
                    label = nearest.Name,
                    character = nearest,
                    name = nearest.Name
                })
            end
        end

        if #survivors == 0 then
            local downed, dDist = findNearestDownedSurvivor()
            if downed and downed:FindFirstChild("HumanoidRootPart") then
                table.insert(survivors, {
                    label = downed.Name .. " [Downed]",
                    character = downed,
                    name = downed.Name
                })
            end
        end

        if #survivors == 0 and trackedSurvivors then
            for c, _ in pairs(trackedSurvivors) do
                if c and c.Parent and c ~= myChar and c:FindFirstChild("HumanoidRootPart") then
                    table.insert(survivors, {
                        label = c.Name,
                        character = c,
                        name = c.Name
                    })
                end
            end
        end

        if #survivors == 0 then
            WindUI:Notify({ Title = "Teleport Failed", Content = "No survivors detected in the match!", Duration = 2.5 })
            return
        end

        local targetEntry = nil
        if selectedTeleportSurvivor and selectedTeleportSurvivor ~= "No Survivors Found" then
            for _, s in ipairs(survivors) do
                if s.label == selectedTeleportSurvivor or s.name == selectedTeleportSurvivor or s.label:find(selectedTeleportSurvivor, 1, true) then
                    targetEntry = s
                    break
                end
            end
        end

        -- If none selected or selection not found, default to first available survivor
        if not targetEntry then
            targetEntry = survivors[1]
        end

        if not targetEntry or not targetEntry.character or not targetEntry.character:FindFirstChild("HumanoidRootPart") then
            WindUI:Notify({ Title = "Teleport Failed", Content = "Target survivor character not found!", Duration = 2.5 })
            return
        end

        local tChar = targetEntry.character
        local tHrp = tChar.HumanoidRootPart

        -- Teleport 2.5 studs behind survivor facing their back
        local behindPos = tHrp.Position - (tHrp.CFrame.LookVector * 2.5) + Vector3.new(0, 0.2, 0)
        local behindCF = CFrame.lookAt(behindPos, tHrp.Position)

        for attempt = 1, 3 do
            myHrp.CFrame = behindCF
            myHrp.AssemblyLinearVelocity = Vector3.zero
            myHrp.AssemblyAngularVelocity = Vector3.zero
            task.wait(0.001)
        end

        currentKillerTarget = tChar

        local tName = targetEntry.player and (targetEntry.player.DisplayName or targetEntry.player.Name) or targetEntry.name or "Survivor"
        WindUI:Notify({
            Title = "⚡ Teleported to Survivor",
            Content = string.format("Warped behind %s!", tName),
            Duration = 2.5
        })
    end
})

V_KillerSection:Slider({
    Title = "Hit Reach Distance",
    Description = "Distance in studs to trigger Auto Aim & Auto Hit (6 - 20 studs)",
    Step = 1,
    Value = {
        Min = 6,
        Max = 20,
        Default = 10,
    },
    Callback = function(val)
        hitReachDistance = tonumber(val) or 10
    end
})

local standaloneAimUserSetting = false
local standaloneHitUserSetting = false

V_KillerSection:Toggle({
    Title = "Auto Aim to Survivor",
    Description = "Locks camera directly at target Survivor when in reach (Active even without Auto Catch)",
    Default = false,
    Callback = function(v)
        standaloneAimUserSetting = v
        autoAimSurvivorEnabled = v or autoCatchEnabled or autoCatchEXEnabled
        updateKillerAim()
    end
})

V_KillerSection:Toggle({
    Title = "Auto Hit Survivor",
    Description = "Automatically executes attack when survivor is in reach (Active even without Auto Catch)",
    Default = false,
    Callback = function(v)
        standaloneHitUserSetting = v
        autoHitSurvivorEnabled = v or autoCatchEnabled or autoCatchEXEnabled
    end
})

V_KillerSection:Toggle({
    Title = "Auto Hook Survivor",
    Description = "Picks up knocked survivors and transports them to the nearest hook to hang them",
    Default = false,
    Callback = function(v)
        autoHookSurvivorEnabled = v
    end
})

-- Unfreezes Killer root part and clears anti-cheat / server-anchor lock flags
local function unlockKillerMotion(myChar, myHrp)
    if myHrp and myHrp.Anchored then
        pcall(function() myHrp.Anchored = false end)
    end
    if myChar then
        pcall(function()
            myChar:SetAttribute("Immobile", false)
            myChar:SetAttribute("AC_ServerAnchor", false)
            myChar:SetAttribute("Rooted", false)
        end)
    end
end

-- Computes upright unobstructed stand CFrame 1.2 studs adjacent to knocked body (Auto Catch EX only)
local function getBodyPickupCFrameEX(myChar, bodyChar)
    local dHrp = bodyChar and bodyChar:FindFirstChild("HumanoidRootPart")
    if not dHrp then return nil end

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.RespectCanCollide = true
    local filterList = { bodyChar }
    if myChar then table.insert(filterList, myChar) end
    rayParams.FilterDescendantsInstances = filterList

    local groundRay = workspace:Raycast(dHrp.Position + Vector3.new(0, 1.2, 0), Vector3.new(0, -10, 0), rayParams)
    local groundY = groundRay and groundRay.Position.Y or (dHrp.Position.Y - 0.5)
    local clampedY = math.clamp(groundY + 2.6, dHrp.Position.Y + 0.4, dHrp.Position.Y + 3.0)

    local back = -Vector3.new(dHrp.CFrame.LookVector.X, 0, dHrp.CFrame.LookVector.Z)
    back = (back.Magnitude > 0.1) and back.Unit or Vector3.new(0, 0, -1)
    local right = Vector3.new(-back.Z, 0, back.X)

    local horizOffset = back * 1.2
    for _, dir in ipairs({ back, right, -right, -back }) do
        if not workspace:Raycast(dHrp.Position, dir * 1.6, rayParams) then
            horizOffset = dir * 1.2
            break
        end
    end

    local standPos = Vector3.new(dHrp.Position.X + horizOffset.X, clampedY, dHrp.Position.Z + horizOffset.Z)
    local levelLookTarget = Vector3.new(dHrp.Position.X, standPos.Y, dHrp.Position.Z)
    return CFrame.lookAt(standPos, levelLookTarget)
end

-- Real-position verifier for Auto Catch EX: checks actual HRP position vs target, retrying every 0.0001s until arrived
local function teleportVerifyEX(myChar, myHrp, getTargetCF, tolerance, maxAttempts)
    if not myHrp or not myHrp.Parent then return false, nil end
    local tol = tolerance or 3.0
    local tries = maxAttempts or 12
    local lastCF = nil

    for attempt = 1, tries do
        unlockKillerMotion(myChar, myHrp)
        local targetCF = getTargetCF()
        if not targetCF then return false, nil end
        lastCF = targetCF

        myHrp.CFrame = targetCF
        myHrp.AssemblyLinearVelocity = Vector3.zero
        myHrp.AssemblyAngularVelocity = Vector3.zero

        task.wait(0.0001)

        if not myHrp or not myHrp.Parent then return false, targetCF end
        unlockKillerMotion(myChar, myHrp)
        local freshCF = getTargetCF() or targetCF
        lastCF = freshCF
        local realDist = (myHrp.Position - freshCF.Position).Magnitude
        if realDist <= tol and not myHrp.Anchored then
            myHrp.CFrame = freshCF
            myHrp.AssemblyLinearVelocity = Vector3.zero
            myHrp.AssemblyAngularVelocity = Vector3.zero
            return true, freshCF
        end
    end

    return false, lastCF
end

-- Holds EX Killer real position within drift tolerance using 0.0001s checks without fighting carry/hook animations
local function holdVerifyPositionEX(myChar, myHrp, getTargetCF, holdSeconds, maxDrift, interruptFn)
    local endTime = tick() + (holdSeconds or 0.05)
    local driftLimit = maxDrift or 3.0
    while tick() < endTime and scriptRunning do
        if interruptFn and interruptFn() then
            return false
        end
        local targetCF = getTargetCF()
        if not targetCF or not myHrp or not myHrp.Parent then
            return false
        end
        if (myHrp.Position - targetCF.Position).Magnitude > driftLimit or myHrp.Anchored then
            unlockKillerMotion(myChar, myHrp)
            myHrp.CFrame = targetCF
            myHrp.AssemblyLinearVelocity = Vector3.zero
            myHrp.AssemblyAngularVelocity = Vector3.zero
        end
        task.wait(0.0001)
    end
    return true
end

-- Dedicated Auto Catch EX State Machine (Strict Target & Hook Lock + Heartbeat Velocity-Intercept + 0.0001s Real-Position Verify + LungeDetect Sure-Hit)
local function runAutoCatchEXSession(thisSession)
    local function checkCatchActive()
        return autoCatchEXEnabled and (catchSession == thisSession) and scriptRunning
    end

    task.spawn(function()
        local lockedCatchSurvivor = nil
        local lockedHookPart = nil
        local lockedHookCF = nil
        local currentCarryTarget = nil
        local pickupAttempts = 0
        local lastNotificationPhase = nil
        local trackedCatchChar = nil
        local botsIgnoredThisRound = false
        local lastBotCheckTime = 0
        local exSawUprightThisWave = false
        local exPostKnockPauseDone = false
        local exPostKnockPauseStart = 0
        local exPostKnockPauseUntil = 0

        -- EX Heartbeat Velocity-Intercept & Carry/Hook Tracking State
        local exHeartbeatConn = nil
        local exAfterAttackConn = nil
        local exAttackLockConn = nil
        local exActiveTarget = nil
        local exHoldHookPart = nil
        local exHoldHookCF = nil
        local exHoldBodyChar = nil
        local exGluedStartTime = 0
        local exLastSwingStartTime = 0
        local exLastSamplePos = nil
        local exLastSampleTime = 0
        local exMeasuredFrameVel = nil
        local exStationaryAngleIdx = 0
        local exTargetLockHP = nil
        local exLastDamageTime = 0

        -- EX 3-Failed-Hit Pause & Same-Target Retry State
        local exTargetFailHits = 0
        local exFailPauseUntil = 0
        local exFailPauseStart = 0
        local exLastCountedHitTime = 0
        local exAfterAttackCooldownUntil = 0
        local exServerAttackLock = false
        local exServerAttackLockUntil = 0
        local exPendingFallbackSwingAt = 0
        local exPrevIsAttacking = false
        local exCurSwingCounted = false
        local exSwingEndedAt = 0

        local function resetExTargetHitTracking(targetModel)
            exTargetFailHits = 0
            exFailPauseActive = false
            exFailPauseUntil = 0
            exFailPauseStart = 0
            exLastCountedHitTime = 0
            exAfterAttackCooldownUntil = 0
            exPendingFallbackSwingAt = 0
            exPrevIsAttacking = false
            exCurSwingCounted = false
            exSwingEndedAt = 0
            local sHumInit = targetModel and targetModel:FindFirstChildOfClass("Humanoid")
            exTargetLockHP = sHumInit and sHumInit.Health or 100
            exLastDamageTime = tick()
        end

        local function triggerExFailPause()
            if exFailPauseActive then return end
            if not lockedCatchSurvivor or isEXTargetOutOfPlay(lockedCatchSurvivor) or isEXTargetTrulyKnocked(lockedCatchSurvivor) then
                return
            end
            local dur = math.clamp(tonumber(exFailPauseDuration) or 0, 0, 3)
            if dur <= 0 then
                exTargetFailHits = 0
                exPendingFallbackSwingAt = 0
                return
            end
            exFailPauseActive = true
            exFailPauseStart = tick()
            exFailPauseUntil = exFailPauseStart + dur
            exActiveTarget = nil
            exGluedStartTime = 0
            exLastSamplePos = nil
            exMeasuredFrameVel = nil
            exPendingFallbackSwingAt = 0
            exCurSwingCounted = false
            exSwingEndedAt = 0
            exTargetFailHits = 0
            if player.Character then
                setKillerChaseCollision(player.Character, true)
            end
            WindUI:Notify({
                Title = "⏸️ EX Cooldown Pause",
                Content = string.format("3 hits failed to knock target — pausing teleport & hit for %.1fs (same target locked).", dur),
                Duration = math.clamp(dur, 1.2, 2.5)
            })
        end

        local function registerExHitAttempt(dedupGap, cooldownExt)
            if not checkCatchActive() or exFailPauseActive then return end
            if not lockedCatchSurvivor or isEXTargetOutOfPlay(lockedCatchSurvivor) or isEXTargetTrulyKnocked(lockedCatchSurvivor) then
                return
            end
            local now = tick()
            if exCurSwingCounted and (now - exLastCountedHitTime) < (dedupGap or 0.90) then
                if cooldownExt and cooldownExt > 0 then
                    exAfterAttackCooldownUntil = math.max(exAfterAttackCooldownUntil, now + cooldownExt)
                end
                return
            end
            exCurSwingCounted = true
            exSwingEndedAt = 0
            exLastCountedHitTime = now
            exPendingFallbackSwingAt = 0
            if cooldownExt and cooldownExt > 0 then
                exAfterAttackCooldownUntil = math.max(exAfterAttackCooldownUntil, now + cooldownExt)
            end
            exTargetFailHits = exTargetFailHits + 1
            if exTargetFailHits >= 3 then
                triggerExFailPause()
            end
        end

        local function stopExHeartbeat()
            if exHeartbeatConn then
                pcall(function() exHeartbeatConn:Disconnect() end)
                exHeartbeatConn = nil
            end
            if exAfterAttackConn then
                pcall(function() exAfterAttackConn:Disconnect() end)
                exAfterAttackConn = nil
            end
            if exAttackLockConn then
                pcall(function() exAttackLockConn:Disconnect() end)
                exAttackLockConn = nil
            end
            exActiveTarget = nil
            exHoldHookPart = nil
            exHoldHookCF = nil
            exHoldBodyChar = nil
            exGluedStartTime = 0
            exLastSamplePos = nil
            exMeasuredFrameVel = nil
            exStationaryAngleIdx = 0
            exTargetLockHP = nil
            exFailPauseActive = false
            exFailPauseUntil = 0
            exTargetFailHits = 0
            exPostKnockPauseActive = false
            exPostKnockPauseStart = 0
            exPostKnockPauseUntil = 0
            exPostKnockPauseDone = false
            exSawUprightThisWave = false
            if player.Character then
                setKillerChaseCollision(player.Character, true)
            end
        end

        pcall(function()
            local remotes = getVDRemotes()
            if remotes and remotes.Attacks then
                local afterAttackRemote = remotes.Attacks:FindFirstChild("AfterAttack")
                if afterAttackRemote and afterAttackRemote:IsA("RemoteEvent") then
                    exAfterAttackConn = afterAttackRemote.OnClientEvent:Connect(function(isHit)
                        if not checkCatchActive() or exFailPauseActive then return end
                        if not lockedCatchSurvivor or isEXTargetOutOfPlay(lockedCatchSurvivor) or isEXTargetTrulyKnocked(lockedCatchSurvivor) then
                            return
                        end
                        if exGluedStartTime == 0 and (tick() - exLastSwingStartTime) > 1.5 then
                            return
                        end
                        registerExHitAttempt(0.35, (isHit == true) and 2.5 or 1.3)
                    end)
                end
                local attackLockRemote = remotes.Attacks:FindFirstChild("AttackLock")
                if attackLockRemote and attackLockRemote:IsA("RemoteEvent") then
                    exAttackLockConn = attackLockRemote.OnClientEvent:Connect(function(locked)
                        if type(locked) == "boolean" then
                            exServerAttackLock = locked
                            exServerAttackLockUntil = locked and (tick() + 3.2) or 0
                        end
                    end)
                end
            end
        end)

        exHeartbeatConn = RunService.Heartbeat:Connect(function()
            if not checkCatchActive() then
                stopExHeartbeat()
                return
            end
            local myChar = player.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if not myHrp then
                exGluedStartTime = 0
                return
            end

            -- 0. EX Cooldown Pauses: disable teleport & chase lock while waiting out fail or post-knockdown cooldown
            if exFailPauseActive or exPostKnockPauseActive then
                exGluedStartTime = 0
                exLastSamplePos = nil
                exMeasuredFrameVel = nil
                setKillerChaseCollision(myChar, true)
                return
            end

            -- 1. EX Hooking Hold Guard (only corrects position if drifted > 3.2 studs, allowing Hook animation to complete)
            if exHoldHookPart and exHoldHookPart.Parent then
                unlockKillerMotion(myChar, myHrp)
                local standCF = exHoldHookCF or getHookStandCFrameEX(exHoldHookPart)
                if (myHrp.Position - standCF.Position).Magnitude > 3.2 then
                    myHrp.CFrame = standCF
                    myHrp.AssemblyLinearVelocity = Vector3.zero
                    myHrp.AssemblyAngularVelocity = Vector3.zero
                end
                return
            end

            -- 2. EX Body Pickup Hold Guard (corrects position if body crawled or Killer drifted > 3.0 studs)
            if exHoldBodyChar and exHoldBodyChar.Parent then
                local dHrp = exHoldBodyChar:FindFirstChild("HumanoidRootPart")
                if dHrp then
                    unlockKillerMotion(myChar, myHrp)
                    local pickupCF = getBodyPickupCFrameEX(myChar, exHoldBodyChar)
                    if pickupCF and (myHrp.Position - pickupCF.Position).Magnitude > 3.0 then
                        myHrp.CFrame = pickupCF
                        myHrp.AssemblyLinearVelocity = Vector3.zero
                        myHrp.AssemblyAngularVelocity = Vector3.zero
                    end
                end
                return
            end

            -- 3. EX Upright Target Velocity-Intercept Lock (strict: stays glued until genuinely knocked down or out of play)
            local target = exActiveTarget
            if not target or not target.Parent or isEXTargetOutOfPlay(target) or isEXTargetTrulyKnocked(target) or isKillerCarrying(myChar) then
                exGluedStartTime = 0
                exLastSamplePos = nil
                exMeasuredFrameVel = nil
                setKillerChaseCollision(myChar, true)
                return
            end

            local sHrp = target:FindFirstChild("HumanoidRootPart")
            if not sHrp then
                exGluedStartTime = 0
                return
            end

            local now = tick()
            if exLastSamplePos and exLastSampleTime > 0 then
                local dt = now - exLastSampleTime
                if dt > 0.0001 and dt < 0.25 then
                    exMeasuredFrameVel = (sHrp.Position - exLastSamplePos) / dt
                end
            end
            exLastSamplePos = sHrp.Position
            exLastSampleTime = now

            unlockKillerMotion(myChar, myHrp)
            setKillerChaseCollision(myChar, false)
            myHrp.CFrame = computeInterceptCFrame(sHrp, exMeasuredFrameVel, target, exStationaryAngleIdx)
            myHrp.AssemblyLinearVelocity = Vector3.zero
            myHrp.AssemblyAngularVelocity = Vector3.zero

            local cam = workspace.CurrentCamera
            if cam then
                cam.CFrame = CFrame.lookAt(cam.CFrame.Position, sHrp.Position + Vector3.new(0, 0.25, 0))
            end

            local dist = (myHrp.Position - sHrp.Position).Magnitude
            if dist <= 4.8 then
                if exGluedStartTime == 0 then
                    exGluedStartTime = now
                end
            else
                exGluedStartTime = 0
            end
        end)

        while checkCatchActive() do
            local ok, err = pcall(function()
                local myChar = player.Character
                local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                if not myHrp then
                    exActiveTarget = nil
                    exHoldHookPart = nil
                    exHoldBodyChar = nil
                    task.wait(0.0001)
                    return
                end

                -- Reset per-round latches whenever Killer character respawns / changes match
                if trackedCatchChar ~= myChar then
                    trackedCatchChar = myChar
                    botsIgnoredThisRound = false
                    catchBotsIgnoredActive = false
                    lastBotCheckTime = 0
                    lockedCatchSurvivor = nil
                    lockedHookPart = nil
                    lockedHookCF = nil
                    currentCarryTarget = nil
                    exSawUprightThisWave = false
                    exPostKnockPauseDone = false
                    exPostKnockPauseActive = false
                    exPostKnockPauseStart = 0
                    exPostKnockPauseUntil = 0
                end

                -- Check if 5+ targets are detected with at least one bot (if so, ignore all bots this round)
                if not botsIgnoredThisRound and (tick() - lastBotCheckTime) >= 0.25 then
                    lastBotCheckTime = tick()
                    local shouldIgnore, totalCount, botCount = evaluateCatchBotIgnore(myChar)
                    if shouldIgnore then
                        botsIgnoredThisRound = true
                        catchBotsIgnoredActive = true
                        if lockedCatchSurvivor and isSurvivorBot(lockedCatchSurvivor) then
                            lockedCatchSurvivor = nil
                        end
                        if currentCarryTarget and isSurvivorBot(currentCarryTarget) then
                            currentCarryTarget = nil
                        end
                        WindUI:Notify({
                            Title = "🤖 Bot Ignored",
                            Content = string.format("Detected %d targets (%d bot) — focusing real players only.", totalCount, botCount),
                            Duration = 2.5
                        })
                    end
                end

                -- ====================================================
                -- PRIORITY 1: KNOCK DOWN ALL SURVIVORS FIRST
                -- Strict Target Lock: never switches away until lockedCatchSurvivor is truly knocked down (or out of play)
                -- ====================================================
                if lockedCatchSurvivor then
                    if (botsIgnoredThisRound and isSurvivorBot(lockedCatchSurvivor))
                        or isEXTargetOutOfPlay(lockedCatchSurvivor)
                        or isEXTargetTrulyKnocked(lockedCatchSurvivor) then
                        lockedCatchSurvivor = nil
                        resetExTargetHitTracking(nil)
                    end
                end

                if not lockedCatchSurvivor then
                    local uprightSurvivor = findNearestSurvivor(botsIgnoredThisRound)
                    if uprightSurvivor then
                        lockedCatchSurvivor = uprightSurvivor
                        exGluedStartTime = 0
                        exLastSamplePos = nil
                        exMeasuredFrameVel = nil
                        exStationaryAngleIdx = 0
                        resetExTargetHitTracking(lockedCatchSurvivor)
                    end
                end

                if lockedCatchSurvivor and lockedCatchSurvivor:FindFirstChild("HumanoidRootPart") then
                    exSawUprightThisWave = true
                    exPostKnockPauseDone = false
                    exPostKnockPauseActive = false
                    exPostKnockPauseStart = 0
                    exPostKnockPauseUntil = 0
                    exHoldHookPart = nil
                    exHoldBodyChar = nil

                    -- If currently in 3-failed-hits cooldown pause: hold off instant teleport & auto-hit until pause finishes, keeping SAME locked target
                    if exFailPauseActive then
                        local now = tick()
                        local liveDur = math.clamp(tonumber(exFailPauseDuration) or 0, 0, 3)
                        local effectiveUntil = math.min(exFailPauseUntil, exFailPauseStart + liveDur)
                        if liveDur <= 0 or now >= effectiveUntil then
                            exFailPauseActive = false
                            exFailPauseUntil = 0
                            exFailPauseStart = 0
                            exTargetFailHits = 0
                            exPendingFallbackSwingAt = 0
                            exCurSwingCounted = false
                            exSwingEndedAt = 0
                            exAfterAttackCooldownUntil = 0
                            exServerAttackLock = false
                            exGluedStartTime = 0
                            exLastSamplePos = nil
                            exMeasuredFrameVel = nil
                            exLastDamageTime = tick()
                        else
                            exActiveTarget = nil
                            exGluedStartTime = 0
                            setKillerChaseCollision(myChar, true)
                            task.wait(0.01)
                            return
                        end
                    end

                    -- Revived / active survivor detected! Prioritize knocking down all survivors first.
                    if isKillerCarrying(myChar) then
                        exActiveTarget = nil
                        local quickHook = (lockedHookPart and lockedHookPart.Parent) and lockedHookPart or findNearestAvailableHookEX()
                        local hookDist = quickHook and (myHrp.Position - quickHook.Position).Magnitude or math.huge
                        if quickHook and hookDist <= 5.5 then
                            exHoldHookPart = quickHook
                            exHoldHookCF = lockedHookCF or getHookStandCFrameEX(quickHook)
                            teleportVerifyEX(myChar, myHrp, function() return exHoldHookCF end, 3.2, 8)
                            local reqId = HttpService:GenerateGUID(false)
                            local remotes = getVDRemotes()
                            if remotes.Carry and remotes.Carry:FindFirstChild("HookEvent") then
                                pcall(function() remotes.Carry.HookEvent:FireServer(quickHook, reqId, myChar) end)
                            end
                            task.wait(0.05)
                            if remotes.Carry and remotes.Carry:FindFirstChild("HookCommit") then
                                pcall(function() remotes.Carry.HookCommit:FireServer(quickHook, reqId, myChar) end)
                            end
                            exHoldHookPart = nil
                            if not isKillerCarrying(myChar) then
                                lockedHookPart = nil
                                lockedHookCF = nil
                            end
                        else
                            local remotes = getVDRemotes()
                            if remotes.Carry and remotes.Carry:FindFirstChild("DropSurvivorEvent") then
                                pcall(function() remotes.Carry.DropSurvivorEvent:FireServer() end)
                            end
                            task.wait(0.0001)
                            if not isKillerCarrying(myChar) then
                                lockedHookPart = nil
                                lockedHookCF = nil
                            end
                        end
                    else
                        lockedHookPart = nil
                        lockedHookCF = nil
                    end

                    currentCarryTarget = nil
                    pickupAttempts = 0

                    unlockKillerMotion(myChar, myHrp)

                    if lastNotificationPhase ~= "hunting" then
                        lastNotificationPhase = "hunting"
                        WindUI:Notify({
                            Title = "⚡ EX Sure-Hit Hunting",
                            Content = "Velocity-intercept lock active on target until knockdown...",
                            Duration = 1.8
                        })
                    end

                    currentKillerTarget = lockedCatchSurvivor
                    local sHrp = lockedCatchSurvivor.HumanoidRootPart

                    -- Track damage progress on stationary targets & count landed damage hits cleanly
                    local sHum = lockedCatchSurvivor:FindFirstChildOfClass("Humanoid")
                    local curHP = sHum and sHum.Health or 100
                    if exTargetLockHP == nil then
                        exTargetLockHP = curHP
                        exLastDamageTime = tick()
                    elseif curHP < exTargetLockHP then
                        exTargetLockHP = curHP
                        exLastDamageTime = tick()
                        exStationaryAngleIdx = 0
                        registerExHitAttempt(0.40, 2.3)
                        if exFailPauseActive then
                            return
                        end
                    end

                    -- EX Mode: Real-position verify + 0.0001s retry + Heartbeat intercept/stationary lock
                    exActiveTarget = lockedCatchSurvivor
                    setKillerChaseCollision(myChar, false)
                    local targetCF, targetSpeed = computeInterceptCFrame(sHrp, exMeasuredFrameVel, lockedCatchSurvivor, exStationaryAngleIdx)
                    local isStationary = (targetSpeed or 0) <= 1.5
                    local realDist = (myHrp.Position - targetCF.Position).Magnitude
                    if realDist > 3.5 or myHrp.Anchored then
                        teleportVerifyEX(myChar, myHrp, function()
                            if sHrp and sHrp.Parent then
                                local cf = computeInterceptCFrame(sHrp, exMeasuredFrameVel, lockedCatchSurvivor, exStationaryAngleIdx)
                                return cf
                            end
                            return nil
                        end, 3.5, 10)
                    else
                        myHrp.CFrame = targetCF
                        myHrp.AssemblyLinearVelocity = Vector3.zero
                        myHrp.AssemblyAngularVelocity = Vector3.zero
                    end

                    -- Rotate angle & step closer if stationary target took no damage after 0.28s
                    if isStationary and exGluedStartTime > 0 and (tick() - exGluedStartTime) >= 0.065 and (tick() - exLastDamageTime) >= 0.28 then
                        exStationaryAngleIdx = (exStationaryAngleIdx + 1) % 8
                        exLastDamageTime = tick()
                        local rotCF = computeInterceptCFrame(sHrp, exMeasuredFrameVel, lockedCatchSurvivor, exStationaryAngleIdx)
                        myHrp.CFrame = rotCF
                        myHrp.AssemblyLinearVelocity = Vector3.zero
                        myHrp.AssemblyAngularVelocity = Vector3.zero
                    end

                    -- Wait >= 60ms of real-position replication before swinging so stationary hits don't misfire into miss lock
                    local settleThreshold = isStationary and 0.06 or 0.045
                    if exGluedStartTime > 0 and (tick() - exGluedStartTime) >= settleThreshold then
                        if not isKillerStunnedOrLocked(myChar) then
                            local now = tick()
                            if exServerAttackLock and exServerAttackLockUntil > 0 and now > exServerAttackLockUntil then
                                exServerAttackLock = false
                            end

                            local isAttackingNow = myChar:GetAttribute("isAttacking") == true or myChar:GetAttribute("isLunging") == true
                            if isAttackingNow and not exPrevIsAttacking then
                                exCurSwingCounted = false
                                exSwingEndedAt = 0
                            elseif not isAttackingNow and exPrevIsAttacking then
                                if not exCurSwingCounted then
                                    exSwingEndedAt = now
                                end
                            elseif not isAttackingNow and exSwingEndedAt > 0 and (now - exSwingEndedAt) >= 0.10 then
                                registerExHitAttempt(0.45, 0.9)
                                exSwingEndedAt = 0
                                if exFailPauseActive then
                                    exPrevIsAttacking = false
                                    return
                                end
                            end
                            exPrevIsAttacking = isAttackingNow

                            local includeLunge = (not isStationary) or (exStationaryAngleIdx % 2 == 1)
                            if (now - lastKillerHitTime) >= 0.12 then
                                executeKillerHitEX(lockedCatchSurvivor, true, exMeasuredFrameVel, exStationaryAngleIdx, includeLunge)
                                lastKillerHitTime = now
                                exLastSwingStartTime = now
                                if exPendingFallbackSwingAt == 0 then
                                    exPendingFallbackSwingAt = now
                                elseif not exServerAttackLock and not isAttackingNow and exSwingEndedAt == 0 and now >= exAfterAttackCooldownUntil and (now - exPendingFallbackSwingAt) >= 0.60 then
                                    registerExHitAttempt(0.55, 0)
                                    exPendingFallbackSwingAt = now
                                    if exFailPauseActive then
                                        return
                                    end
                                end
                            elseif (now - exLastSwingStartTime) <= 0.12 or isAttackingNow then
                                executeKillerHitEX(lockedCatchSurvivor, false, exMeasuredFrameVel, exStationaryAngleIdx, includeLunge)
                            end
                        end
                    end
                    return
                end

                -- ====================================================
                -- PRIORITY 2: ALL SURVIVORS ARE KNOCKED DOWN (0 UPRIGHT)
                -- SEQUENTIAL PICKUP & HOOK PIPELINE WITH STRICT LOCKING
                -- ====================================================
                lockedCatchSurvivor = nil
                exActiveTarget = nil
                exGluedStartTime = 0
                setKillerChaseCollision(myChar, true)

                -- Post-All-Knockdown Stop (0 - 6s configurable via slider, default 3s) before picking up & hooking
                if exSawUprightThisWave and not exPostKnockPauseDone then
                    local liveDur = math.clamp(tonumber(exPostKnockWaitDuration) or 0, 0, 6)
                    local hasTargetToHook = isKillerCarrying(myChar) or (findNearestDownedSurvivor(botsIgnoredThisRound) ~= nil)
                    if liveDur > 0 and hasTargetToHook then
                        local now = tick()
                        if not exPostKnockPauseActive then
                            exPostKnockPauseActive = true
                            exPostKnockPauseStart = now
                            exPostKnockPauseUntil = now + liveDur
                            WindUI:Notify({
                                Title = "⏸️ All Survivors Knocked",
                                Content = string.format("Stopping %.1fs before picking up & hooking survivors...", liveDur),
                                Duration = math.clamp(liveDur, 1.2, 3.0)
                            })
                        end
                        local effectiveUntil = math.min(exPostKnockPauseUntil, exPostKnockPauseStart + liveDur)
                        if now < effectiveUntil then
                            task.wait(0.01)
                            return
                        end
                    end
                    exPostKnockPauseActive = false
                    exPostKnockPauseDone = true
                    exPostKnockPauseStart = 0
                    exPostKnockPauseUntil = 0
                end

                -- ----------------------------------------------------
                -- STEP A: IF CARRYING SURVIVOR -> TRANSPORT TO LOCKED HOOK & HANG
                -- Strict Hook Lock: NEVER change lockedHookPart unless carried survivor is hooked!
                -- ----------------------------------------------------
                local carrying = isKillerCarrying(myChar)
                if carrying then
                    exHoldBodyChar = nil
                    if not lockedHookPart or not lockedHookPart.Parent then
                        lockedHookPart = findNearestAvailableHookEX()
                        lockedHookCF = lockedHookPart and getHookStandCFrameEX(lockedHookPart) or nil
                    end

                    local hookPart = lockedHookPart
                    if hookPart and hookPart.Parent then
                        if lastNotificationPhase ~= "hooking" then
                            lastNotificationPhase = "hooking"
                            WindUI:Notify({ Title = "🪝 Hooking Survivor", Content = "Locked onto hook — hanging carried survivor...", Duration = 1.5 })
                        end

                        local standCF = lockedHookCF or getHookStandCFrameEX(hookPart)
                        lockedHookCF = standCF
                        exHoldHookCF = standCF
                        exHoldHookPart = hookPart
                        local function getCurHookCF()
                            return (hookPart and hookPart.Parent) and standCF or nil
                        end
                        local lastHookReviveCheck = 0
                        local function hasRevivedDuringHook()
                            if (tick() - lastHookReviveCheck) >= 0.04 then
                                lastHookReviveCheck = tick()
                                return findNearestSurvivor(botsIgnoredThisRound) ~= nil
                            end
                            return false
                        end
                        local function isHookInterrupted()
                            return not checkCatchActive() or not isKillerCarrying(myChar) or hasRevivedDuringHook()
                        end

                        -- EX Real Position Verification: retry every 0.0001s until Killer is confirmed at hook
                        teleportVerifyEX(myChar, myHrp, getCurHookCF, 2.8, 15)
                        -- Allow 50ms server-replication settle at hook before firing HookEvent so server never rejects by distance
                        holdVerifyPositionEX(myChar, myHrp, getCurHookCF, 0.05, 3.0, isHookInterrupted)
                        if isHookInterrupted() then
                            exHoldHookPart = nil
                            exHoldHookCF = nil
                            if not isKillerCarrying(myChar) then
                                lockedHookPart = nil
                                lockedHookCF = nil
                            end
                            return
                        end

                        local reqId = HttpService:GenerateGUID(false)
                        local remotes = getVDRemotes()

                        local function fireHookSequence(curReqId)
                            if remotes.Carry and remotes.Carry:FindFirstChild("HookEvent") then
                                pcall(function() remotes.Carry.HookEvent:FireServer(hookPart, curReqId, myChar) end)
                            end
                            local hookModel = hookPart:FindFirstAncestorOfClass("Model") or hookPart.Parent
                            if hookModel then
                                for _, prompt in ipairs(hookModel:GetDescendants()) do
                                    if prompt:IsA("ProximityPrompt") and typeof(fireproximityprompt) == "function" then
                                        pcall(function() fireproximityprompt(prompt) end)
                                    end
                                end
                            end
                            holdVerifyPositionEX(myChar, myHrp, getCurHookCF, 0.08, 3.0, isHookInterrupted)
                            if isKillerCarrying(myChar) and remotes.Carry and remotes.Carry:FindFirstChild("HookCommit") then
                                pcall(function() remotes.Carry.HookCommit:FireServer(hookPart, curReqId, myChar) end)
                            end
                        end

                        fireHookSequence(reqId)

                        -- Status verification: wait and check if target survivor is successfully hooked
                        local hookWaitTimeout = tick() + 0.75
                        local lastCommitRetry = tick()
                        local didFullHookRetry = false
                        while tick() < hookWaitTimeout and isKillerCarrying(myChar) and checkCatchActive() do
                            if hasRevivedDuringHook() then
                                break
                            end
                            if (myHrp.Position - standCF.Position).Magnitude > 3.2 or myHrp.Anchored then
                                unlockKillerMotion(myChar, myHrp)
                                myHrp.CFrame = standCF
                                myHrp.AssemblyLinearVelocity = Vector3.zero
                                myHrp.AssemblyAngularVelocity = Vector3.zero
                            end
                            if not didFullHookRetry and (hookWaitTimeout - tick()) <= 0.40 then
                                didFullHookRetry = true
                                reqId = HttpService:GenerateGUID(false)
                                fireHookSequence(reqId)
                            elseif (tick() - lastCommitRetry) >= 0.08 then
                                lastCommitRetry = tick()
                                if remotes.Carry and remotes.Carry:FindFirstChild("HookCommit") then
                                    pcall(function() remotes.Carry.HookCommit:FireServer(hookPart, reqId, myChar) end)
                                end
                            end
                            task.wait(0.0001)
                        end

                        exHoldHookPart = nil
                        exHoldHookCF = nil

                        local isHooked = false
                        if currentCarryTarget and isCharacterHooked(currentCarryTarget) then
                            isHooked = true
                        elseif not isKillerCarrying(myChar) then
                            isHooked = true
                        end

                        if isHooked then
                            WindUI:Notify({ Title = "🪝 Survivor Hooked!", Content = "Target successfully hung. Moving to next knocked survivor...", Duration = 1.8 })
                            currentCarryTarget = nil
                            lockedHookPart = nil
                            lockedHookCF = nil
                        end
                        -- If not yet hooked: keep lockedHookPart & lockedHookCF intact and retry same hook!
                    end
                    return
                end

                exHoldHookPart = nil
                lockedHookPart = nil
                lockedHookCF = nil

                -- ----------------------------------------------------
                -- STEP B: NOT CARRYING -> PICK UP KNOCKED SURVIVOR WITH STATUS CHECK
                -- ----------------------------------------------------
                if not currentCarryTarget or (botsIgnoredThisRound and isSurvivorBot(currentCarryTarget)) or not isSurvivorDowned(currentCarryTarget) then
                    currentCarryTarget = findNearestDownedSurvivor(botsIgnoredThisRound)
                end

                if currentCarryTarget and currentCarryTarget:FindFirstChild("HumanoidRootPart") then
                    currentKillerTarget = currentCarryTarget
                    local dHrp = currentCarryTarget.HumanoidRootPart

                    if lastNotificationPhase ~= "pickup" then
                        lastNotificationPhase = "pickup"
                        WindUI:Notify({ Title = "🎒 Picking Up Survivor", Content = "Approaching knocked body to carry...", Duration = 1.5 })
                    end

                    local function getCurBodyCF()
                        if currentCarryTarget and currentCarryTarget.Parent then
                            return getBodyPickupCFrameEX(myChar, currentCarryTarget)
                        end
                        return nil
                    end
                    local lastPickupReviveCheck = 0
                    local function hasRevivedDuringPickup()
                        if (tick() - lastPickupReviveCheck) >= 0.04 then
                            lastPickupReviveCheck = tick()
                            return findNearestSurvivor(botsIgnoredThisRound) ~= nil
                        end
                        return false
                    end
                    local function isPickupInterrupted()
                        return not checkCatchActive() or isKillerCarrying(myChar) or hasRevivedDuringPickup()
                    end

                    exHoldBodyChar = currentCarryTarget
                    setKillerChaseCollision(myChar, true)
                    -- EX Real Position Verification: retry every 0.0001s until Killer is confirmed upright on the body
                    teleportVerifyEX(myChar, myHrp, getCurBodyCF, 2.8, 15)
                    -- Brief 40ms replication settle so server confirms proximity before CarrySurvivorEvent
                    holdVerifyPositionEX(myChar, myHrp, getCurBodyCF, 0.04, 2.8, isPickupInterrupted)
                    if isPickupInterrupted() then
                        exHoldBodyChar = nil
                        return
                    end

                    local cam = workspace.CurrentCamera
                    if cam and dHrp and dHrp.Parent then
                        cam.CFrame = CFrame.lookAt(cam.CFrame.Position, dHrp.Position)
                    end

                    local remotes = getVDRemotes()
                    local function fireCarryAttempt()
                        if remotes.Carry and remotes.Carry:FindFirstChild("CarrySurvivorEvent") then
                            pcall(function() remotes.Carry.CarrySurvivorEvent:FireServer(currentCarryTarget) end)
                        end
                        for _, prompt in ipairs(currentCarryTarget:GetDescendants()) do
                            if prompt:IsA("ProximityPrompt") and typeof(fireproximityprompt) == "function" then
                                pcall(function() fireproximityprompt(prompt) end)
                            end
                        end
                    end

                    fireCarryAttempt()

                    -- Status verification: ultra-fast polling & continuous drift-only enforcement while pickup confirms
                    local pickupWaitTimeout = tick() + 0.45
                    local lastPickupReFire = tick()
                    while tick() < pickupWaitTimeout and not isKillerCarrying(myChar) and checkCatchActive() do
                        if hasRevivedDuringPickup() then
                            break
                        end
                        local liveCF = getCurBodyCF()
                        if liveCF and ((myHrp.Position - liveCF.Position).Magnitude > 3.0 or myHrp.Anchored) then
                            unlockKillerMotion(myChar, myHrp)
                            myHrp.CFrame = liveCF
                            myHrp.AssemblyLinearVelocity = Vector3.zero
                            myHrp.AssemblyAngularVelocity = Vector3.zero
                        end
                        if (tick() - lastPickupReFire) >= 0.14 then
                            lastPickupReFire = tick()
                            fireCarryAttempt()
                        end
                        task.wait(0.0001)
                    end

                    exHoldBodyChar = nil

                    local isPickedUp = isKillerCarrying(myChar)
                        or (currentCarryTarget:GetAttribute("IsCarried") == true)
                        or (currentCarryTarget:GetAttribute("isCarried") == true)
                        or (currentCarryTarget:GetAttribute("BeingCarried") == true)

                    if isPickedUp then
                        WindUI:Notify({ Title = "🎒 Body Picked Up!", Content = "Confirmed! Transporting to nearest hook...", Duration = 1.5 })
                        pickupAttempts = 0
                    elseif not isKillerStunnedOrLocked(myChar) then
                        pickupAttempts = pickupAttempts + 1
                    end
                    return
                end

                exHoldBodyChar = nil

                -- ----------------------------------------------------
                -- ALL SURVIVORS HOOKED / DEAD / ESCAPED
                -- ----------------------------------------------------
                currentKillerTarget = nil
                lockedCatchSurvivor = nil
                lockedHookPart = nil
                lockedHookCF = nil
                currentCarryTarget = nil
                exSawUprightThisWave = false
                exPostKnockPauseDone = false
                exPostKnockPauseActive = false
                exPostKnockPauseStart = 0
                exPostKnockPauseUntil = 0
                if lastNotificationPhase ~= "complete" then
                    lastNotificationPhase = "complete"
                    WindUI:Notify({ Title = "✅ All Survivors Secured", Content = "All survivors knocked down & hooked! Monitoring for revives...", Duration = 2.5 })
                end
                task.wait(0.01)
            end)
            if not ok then
                task.wait(0.0001)
            end
            task.wait(0.0001)
        end

        stopExHeartbeat()
        currentKillerTarget = nil
        lockedCatchSurvivor = nil
        lockedHookPart = nil
        lockedHookCF = nil
        currentCarryTarget = nil
        if not (autoCatchEnabled or autoCatchEXEnabled) then
            catchBotsIgnoredActive = false
        end
    end)
end

-- Standard Auto Catch Survivor (Reverted cleanly to v1.02 baseline)
V_KillerSection:Toggle({
    Title = "Auto Catch Survivor",
    Description = "Lock spam teleport to survivor & hit, take body immediately, and put on hook",
    Default = false,
    Callback = function(v)
        autoCatchEnabled = v
        if v then
            autoCatchEXEnabled = false
            exFailPauseActive = false
            exPostKnockPauseActive = false
        end
        catchSession = catchSession + 1
        local thisSession = catchSession

        if not v then
            if not autoCatchEXEnabled then
                currentKillerTarget = nil
                catchBotsIgnoredActive = false
                if not standaloneAimUserSetting then
                    autoAimSurvivorEnabled = false
                    updateKillerAim()
                end
                if not standaloneHitUserSetting then
                    autoHitSurvivorEnabled = false
                end
            end
            return
        end

        autoAimSurvivorEnabled = true
        autoHitSurvivorEnabled = true
        updateKillerAim()

        local function checkCatchActive()
            return autoCatchEnabled and (catchSession == thisSession) and scriptRunning
        end

        task.spawn(function()
            local lockedCatchSurvivor = nil
            local currentCarryTarget = nil
            local pickupAttempts = 0
            local hookAttempts = 0
            local lastNotificationPhase = nil
            local trackedCatchChar = nil
            local botsIgnoredThisRound = false
            local lastBotCheckTime = 0

            while checkCatchActive() do
                local ok, err = pcall(function()
                    local myChar = player.Character
                    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                    if not myHrp then task.wait(0.1) return end

                    -- Reset per-round bot-ignore latch whenever Killer character respawns / changes match
                    if trackedCatchChar ~= myChar then
                        trackedCatchChar = myChar
                        botsIgnoredThisRound = false
                        catchBotsIgnoredActive = false
                        lastBotCheckTime = 0
                    end

                    -- Check if 5+ targets are detected with at least one bot (if so, ignore all bots this round)
                    if not botsIgnoredThisRound and (tick() - lastBotCheckTime) >= 0.25 then
                        lastBotCheckTime = tick()
                        local shouldIgnore, totalCount, botCount = evaluateCatchBotIgnore(myChar)
                        if shouldIgnore then
                            botsIgnoredThisRound = true
                            catchBotsIgnoredActive = true
                            if lockedCatchSurvivor and isSurvivorBot(lockedCatchSurvivor) then
                                lockedCatchSurvivor = nil
                            end
                            if currentCarryTarget and isSurvivorBot(currentCarryTarget) then
                                currentCarryTarget = nil
                            end
                            WindUI:Notify({
                                Title = "🤖 Bot Ignored",
                                Content = string.format("Detected %d targets (%d bot) — focusing real players only.", totalCount, botCount),
                                Duration = 2.5
                            })
                        end
                    end

                    -- ====================================================
                    -- PRIORITY 1: KNOCK DOWN ALL SURVIVORS FIRST
                    -- (Continuous check: if ANY survivor is upright/revived/unhooked)
                    -- ====================================================
                    local uprightSurvivor = findNearestSurvivor(botsIgnoredThisRound)
                    if uprightSurvivor then
                        -- Revived / active survivor detected! Prioritize knocking down all survivors first.
                        -- If killer is currently carrying, handle carry drop or rapid hook if already adjacent
                        if isKillerCarrying(myChar) then
                            local hookPart, hookDist = findNearestAvailableHook()
                            if hookPart and hookDist <= 5.5 then
                                -- Already right in front of the hook! Quick hang to not waste carry
                                local standCF = getHookStandCFrame(hookPart)
                                myHrp.CFrame = standCF
                                local reqId = HttpService:GenerateGUID(false)
                                local remotes = getVDRemotes()
                                if remotes.Carry and remotes.Carry:FindFirstChild("HookEvent") then
                                    pcall(function() remotes.Carry.HookEvent:FireServer(hookPart, reqId, myChar) end)
                                end
                                task.wait(0.05)
                                if remotes.Carry and remotes.Carry:FindFirstChild("HookCommit") then
                                    pcall(function() remotes.Carry.HookCommit:FireServer(hookPart, reqId, myChar) end)
                                end
                            else
                                -- Drop survivor immediately so killer moves at full speed and can attack!
                                local remotes = getVDRemotes()
                                if remotes.Carry and remotes.Carry:FindFirstChild("DropSurvivorEvent") then
                                    pcall(function() remotes.Carry.DropSurvivorEvent:FireServer() end)
                                end
                                task.wait(0.01)
                            end
                        end

                        currentCarryTarget = nil
                        pickupAttempts = 0
                        hookAttempts = 0

                        -- Unfreeze movement if anchored or immobile during hunting
                        if myHrp.Anchored then
                            pcall(function() myHrp.Anchored = false end)
                        end
                        pcall(function()
                            myChar:SetAttribute("Immobile", false)
                            myChar:SetAttribute("AC_ServerAnchor", false)
                        end)

                        -- Retain lock on target until they are knocked down (skipping ignored bots)
                        if not lockedCatchSurvivor or (botsIgnoredThisRound and isSurvivorBot(lockedCatchSurvivor)) or not isSurvivorValidTarget(lockedCatchSurvivor) then
                            lockedCatchSurvivor = uprightSurvivor
                        end

                        if lockedCatchSurvivor and lockedCatchSurvivor:FindFirstChild("HumanoidRootPart") then
                            if lastNotificationPhase ~= "hunting" then
                                lastNotificationPhase = "hunting"
                                WindUI:Notify({ Title = "⚔️ Knocking Down Survivors", Content = "Hunting upright survivors until all are downed...", Duration = 1.8 })
                            end

                            currentKillerTarget = lockedCatchSurvivor
                            local sHrp = lockedCatchSurvivor.HumanoidRootPart

                            -- Ultra-fast 0.001s instant teleport directly behind survivor (1.8 studs behind, facing back)
                            local behindPos = sHrp.Position - (sHrp.CFrame.LookVector * 1.8) + Vector3.new(0, 0.2, 0)
                            local behindCF = CFrame.lookAt(behindPos, sHrp.Position)
                            myHrp.CFrame = behindCF
                            myHrp.AssemblyLinearVelocity = Vector3.zero
                            myHrp.AssemblyAngularVelocity = Vector3.zero
                            task.wait(0.001)
                            if sHrp and sHrp.Parent then
                                local refreshBehindPos = sHrp.Position - (sHrp.CFrame.LookVector * 1.8) + Vector3.new(0, 0.2, 0)
                                behindCF = CFrame.lookAt(refreshBehindPos, sHrp.Position)
                                myHrp.CFrame = behindCF
                                myHrp.AssemblyLinearVelocity = Vector3.zero
                                myHrp.AssemblyAngularVelocity = Vector3.zero
                            end

                            -- Lock camera at survivor
                            local cam = workspace.CurrentCamera
                            if cam and sHrp and sHrp.Parent then
                                cam.CFrame = CFrame.lookAt(cam.CFrame.Position, sHrp.Position + Vector3.new(0, 1.2, 0))
                            end

                            -- Execute attack at ultra-fast 0.001s cycle
                            if (tick() - lastKillerHitTime) >= 0.001 then
                                executeKillerHit(lockedCatchSurvivor)
                                lastKillerHitTime = tick()
                            end
                            return
                        end
                    end

                    -- ====================================================
                    -- PRIORITY 2: ALL SURVIVORS ARE KNOCKED DOWN (0 UPRIGHT)
                    -- SEQUENTIAL PICKUP & HOOK PIPELINE WITH STATUS VERIFICATION
                    -- ====================================================
                    lockedCatchSurvivor = nil

                    -- ----------------------------------------------------
                    -- STEP A: IF CARRYING SURVIVOR -> TRANSPORT TO HOOK & HANG
                    -- ----------------------------------------------------
                    local carrying = isKillerCarrying(myChar)
                    if carrying then
                        local hookPart, hookDist = findNearestAvailableHook()
                        if hookPart then
                            if lastNotificationPhase ~= "hooking" then
                                lastNotificationPhase = "hooking"
                                WindUI:Notify({ Title = "🪝 Hooking Survivor", Content = "Transporting carried survivor to hook...", Duration = 1.5 })
                            end

                            local standCF = getHookStandCFrame(hookPart)
                            for attempt = 1, 2 do
                                myHrp.CFrame = standCF
                                myHrp.AssemblyLinearVelocity = Vector3.zero
                                myHrp.AssemblyAngularVelocity = Vector3.zero
                                task.wait(0.001)
                            end

                            local reqId = HttpService:GenerateGUID(false)
                            local remotes = getVDRemotes()

                            -- 1. Fire HookEvent (Client -> Server initiation)
                            if remotes.Carry and remotes.Carry:FindFirstChild("HookEvent") then
                                pcall(function() remotes.Carry.HookEvent:FireServer(hookPart, reqId, myChar) end)
                            end

                            -- 2. Fire ProximityPrompts on the hook
                            local hookModel = hookPart:FindFirstAncestorOfClass("Model") or hookPart.Parent
                            if hookModel then
                                for _, prompt in ipairs(hookModel:GetDescendants()) do
                                    if prompt:IsA("ProximityPrompt") and typeof(fireproximityprompt) == "function" then
                                        pcall(function() fireproximityprompt(prompt) end)
                                    end
                                end
                            end

                            -- 3. Delay matching native game interaction cycle before HookCommit
                            task.wait(0.05)

                            -- 4. Fire HookCommit (Client -> Server confirmation)
                            if remotes.Carry and remotes.Carry:FindFirstChild("HookCommit") then
                                pcall(function() remotes.Carry.HookCommit:FireServer(hookPart, reqId, myChar) end)
                            end

                            -- Status verification: wait and check if target survivor is successfully hooked
                            local hookWaitTimeout = tick() + 0.45
                            while tick() < hookWaitTimeout and isKillerCarrying(myChar) and checkCatchActive() do
                                -- Interruption check: did any survivor revive while hooking?
                                if findNearestSurvivor(botsIgnoredThisRound) ~= nil then
                                    break
                                end
                                task.wait(0.01)
                                if isKillerCarrying(myChar) and remotes.Carry and remotes.Carry:FindFirstChild("HookCommit") then
                                    pcall(function() remotes.Carry.HookCommit:FireServer(hookPart, reqId, myChar) end)
                                end
                            end

                            local isHooked = false
                            if currentCarryTarget and isCharacterHooked(currentCarryTarget) then
                                isHooked = true
                            elseif not isKillerCarrying(myChar) then
                                isHooked = true
                            end

                            if isHooked then
                                WindUI:Notify({ Title = "🪝 Survivor Hooked!", Content = "Target successfully hung. Moving to next knocked survivor...", Duration = 1.8 })
                                currentCarryTarget = nil
                                hookAttempts = 0
                            else
                                hookAttempts = hookAttempts + 1
                            end
                        end
                        return
                    end

                    -- ----------------------------------------------------
                    -- STEP B: NOT CARRYING -> PICK UP KNOCKED SURVIVOR WITH STATUS CHECK
                    -- ----------------------------------------------------
                    if not currentCarryTarget or (botsIgnoredThisRound and isSurvivorBot(currentCarryTarget)) or not isSurvivorDowned(currentCarryTarget) then
                        currentCarryTarget = findNearestDownedSurvivor(botsIgnoredThisRound)
                    end

                    if currentCarryTarget and currentCarryTarget:FindFirstChild("HumanoidRootPart") then
                        currentKillerTarget = currentCarryTarget
                        local dHrp = currentCarryTarget.HumanoidRootPart

                        if lastNotificationPhase ~= "pickup" then
                            lastNotificationPhase = "pickup"
                            WindUI:Notify({ Title = "🎒 Picking Up Survivor", Content = "Approaching knocked body to carry...", Duration = 1.5 })
                        end

                        -- Calculate floor stand position directly over / adjacent to downed body
                        local rayParams = RaycastParams.new()
                        rayParams.FilterType = Enum.RaycastFilterType.Exclude
                        local filterList = { currentCarryTarget }
                        if myChar then table.insert(filterList, myChar) end
                        rayParams.FilterDescendantsInstances = filterList

                        local groundRay = workspace:Raycast(dHrp.Position + Vector3.new(0, 3, 0), Vector3.new(0, -15, 0), rayParams)
                        local groundY = groundRay and groundRay.Position.Y or (dHrp.Position.Y - 0.5)
                        local standPos = Vector3.new(dHrp.Position.X, groundY + 2.2, dHrp.Position.Z)
                        local targetCF = CFrame.lookAt(standPos, dHrp.Position)

                        for attempt = 1, 2 do
                            myHrp.CFrame = targetCF
                            myHrp.AssemblyLinearVelocity = Vector3.zero
                            myHrp.AssemblyAngularVelocity = Vector3.zero
                            task.wait(0.001)
                        end

                        -- Lock camera at the downed body
                        local cam = workspace.CurrentCamera
                        if cam then
                            cam.CFrame = CFrame.lookAt(cam.CFrame.Position, dHrp.Position)
                        end

                        -- Execute Carry / Pick Up via Remote
                        local remotes = getVDRemotes()
                        if remotes.Carry and remotes.Carry:FindFirstChild("CarrySurvivorEvent") then
                            pcall(function() remotes.Carry.CarrySurvivorEvent:FireServer(currentCarryTarget) end)
                        end

                        -- Trigger any ProximityPrompts on the survivor
                        for _, prompt in ipairs(currentCarryTarget:GetDescendants()) do
                            if prompt:IsA("ProximityPrompt") and typeof(fireproximityprompt) == "function" then
                                pcall(function() fireproximityprompt(prompt) end)
                            end
                        end

                        -- Status verification: 0.001s polling check if target survivor is picked up
                        local pickupWaitTimeout = tick() + 0.25
                        while tick() < pickupWaitTimeout and not isKillerCarrying(myChar) and checkCatchActive() do
                            -- Interruption check: did any survivor revive while picking up?
                            if findNearestSurvivor(botsIgnoredThisRound) ~= nil then
                                break
                            end
                            task.wait(0.001)
                        end

                        local isPickedUp = isKillerCarrying(myChar)
                            or (currentCarryTarget:GetAttribute("IsCarried") == true)
                            or (currentCarryTarget:GetAttribute("isCarried") == true)
                            or (currentCarryTarget:GetAttribute("BeingCarried") == true)

                        if isPickedUp then
                            WindUI:Notify({ Title = "🎒 Body Picked Up!", Content = "Confirmed! Transporting to nearest hook...", Duration = 1.5 })
                            pickupAttempts = 0
                        else
                            pickupAttempts = pickupAttempts + 1
                        end
                        return
                    end

                    -- ----------------------------------------------------
                    -- ALL SURVIVORS HOOKED / DEAD / ESCAPED
                    -- ----------------------------------------------------
                    currentKillerTarget = nil
                    lockedCatchSurvivor = nil
                    currentCarryTarget = nil
                    if lastNotificationPhase ~= "complete" then
                        lastNotificationPhase = "complete"
                        WindUI:Notify({ Title = "✅ All Survivors Secured", Content = "All survivors knocked down & hooked! Monitoring for revives...", Duration = 2.5 })
                    end
                    task.wait(0.05)
                end)
                if not ok then
                    task.wait(0.01)
                end
                task.wait(0.001)
            end
            currentKillerTarget = nil
            lockedCatchSurvivor = nil
            currentCarryTarget = nil
            if not autoCatchEXEnabled then
                catchBotsIgnoredActive = false
            end
        end)
    end
})

V_KillerSection:Toggle({
    Title = "Auto Catch EX",
    Description = "Experimental: Heartbeat velocity-intercept & LungeDetect sure-hit + strict target & hook lock",
    Default = false,
    Callback = function(v)
        autoCatchEXEnabled = v
        exFailPauseActive = false
        exPostKnockPauseActive = false
        if v then
            autoCatchEnabled = false
        end
        catchSession = catchSession + 1
        local thisSession = catchSession

        if not v then
            exFailPauseActive = false
            exPostKnockPauseActive = false
            if not autoCatchEnabled then
                currentKillerTarget = nil
                catchBotsIgnoredActive = false
                if not standaloneAimUserSetting then
                    autoAimSurvivorEnabled = false
                    updateKillerAim()
                end
                if not standaloneHitUserSetting then
                    autoHitSurvivorEnabled = false
                end
            end
            return
        end

        autoAimSurvivorEnabled = true
        autoHitSurvivorEnabled = true
        updateKillerAim()

        runAutoCatchEXSession(thisSession)
    end
})

V_KillerSection:Slider({
    Title = "EX Fail Hit Cooldown (s)",
    Description = "Pause teleport & auto hit (seconds) after 3 hits fail to knock current target (0 - 3s, default 2s)",
    Step = 0.1,
    Value = {
        Min = 0,
        Max = 3,
        Default = 2,
    },
    Callback = function(val)
        exFailPauseDuration = math.clamp(tonumber(val) or 2, 0, 3)
    end
})

V_KillerSection:Slider({
    Title = "EX Post-Knockdown Delay (s)",
    Description = "Stop after knocking down all survivors before picking up & hooking (0 - 6s, default 3s)",
    Step = 0.1,
    Value = {
        Min = 0,
        Max = 6,
        Default = 3,
    },
    Callback = function(val)
        exPostKnockWaitDuration = math.clamp(tonumber(val) or 3, 0, 6)
    end
})

end
