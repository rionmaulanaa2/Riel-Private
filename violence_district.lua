-- ============================================================
-- VIOLENCE DISTRICT ISOLATED MODULE (violence_district.lua)
-- Roblox Place ID: 93978595733734
-- Features: Role Detection, ESP & Visuals, Objectives & Skillcheck,
-- Combat & Defense, Rescue & Team, Killer Automation.
-- ============================================================

local ViolenceTab = nil
local V_ESPSection = nil
local V_ObjectiveSection = nil
local V_CombatSection = nil
local V_RescueSection = nil
local V_RoleSection = nil
local V_ServerRemotesSection = nil
local V_KillerSection = nil

do
ViolenceTab = Window:Tab({
    Title = "Violence District",
    Icon = "swords"
})

V_ESPSection = ViolenceTab:Section({
    Title = "ESP & Visuals"
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
isPlayerKiller = nil

local function checkPlayerKillerStatus()
    -- If user has enabled any killer automation feature, they are intentionally playing the Killer
    if autoCatchEnabled or autoAimSurvivorEnabled or autoHitSurvivorEnabled or autoHookSurvivorEnabled then
        return true
    end

    local myChar = player.Character
    if not myChar then return false end

    -- Authoritative SelectedKiller attributes from game dump
    if player:GetAttribute("SelectedKiller") ~= nil or myChar:GetAttribute("SelectedKiller") ~= nil
        or player:GetAttribute("Killer") ~= nil or myChar:GetAttribute("Killer") ~= nil
        or player:GetAttribute("IsKiller") == true or player:GetAttribute("Role") == "Killer"
        or player:GetAttribute("killer") == true or myChar:GetAttribute("IsKiller") == true then
        return true
    end

    -- 1. Explicit Team verification (Authoritative in Violence District)
    if player.Team then
        local tName = player.Team.Name:lower()
        if tName:find("killer") or tName:find("slasher") then
            return true
        end
        if tName:find("survivor") then
            return false
        end
    end

    -- 2. Killer-specific player attributes assigned by server
    if player:GetAttribute("IsKiller") == true or player:GetAttribute("Role") == "Killer" or player:GetAttribute("killer") == true then
        return true
    end

    -- 3. Check PlayerGui for Killer HUD (Slasher-mob, Slasher, Slasher-con)
    -- EXCLUDE 'KillerPerks' because it is present in PlayerGui for ALL players by default!
    local pg = player:FindFirstChild("PlayerGui")
    if pg then
        if pg:FindFirstChild("Slasher-mob") or pg:FindFirstChild("Slasher") or pg:FindFirstChild("Slasher-con") then
            return true
        end
        for _, gui in ipairs(pg:GetChildren()) do
            local gName = gui.Name:lower()
            if gName ~= "killerperks" and (gName == "slasher" or gName:find("slasher-") or gName == "killergui" or gName == "killerhud") then
                return true
            end
        end
    end

    -- 4. CollectionService & Attributes on character
    if CollectionService:HasTag(myChar, "Killer") or CollectionService:HasTag(player, "Killer") then
        return true
    end
    if myChar:GetAttribute("Butcher") == true 
        or myChar:GetAttribute("IsKiller") == true 
        or myChar:GetAttribute("KillerName") ~= nil 
        or myChar:GetAttribute("killercarry") ~= nil then
        return true
    end

    -- 5. Killer weapons equipped in character
    for _, item in ipairs(myChar:GetChildren()) do
        if item:IsA("Tool") or item:IsA("BasePart") or item:IsA("Model") then
            local iName = item.Name:lower()
            if iName:find("cleaver") or iName:find("machete") or iName:find("chainsaw") 
                or iName:find("killerweapon") or iName:find("beartrap") or iName:find("slasher")
                or iName:find("axe") or (iName:find("blade") and not iName:find("parry")) then
                return true
            end
        end
    end

    -- 6. Check Backpack for Killer weapons
    local bp = player:FindFirstChild("Backpack")
    if bp then
        for _, item in ipairs(bp:GetChildren()) do
            if item:IsA("Tool") then
                local iName = item.Name:lower()
                if iName:find("cleaver") or iName:find("machete") or iName:find("chainsaw") 
                    or iName:find("killerweapon") or iName:find("beartrap") or iName:find("slasher")
                    or iName:find("axe") or (iName:find("blade") and not iName:find("parry")) then
                    return true
                end
            end
        end
    end

    -- 7. Killer specific child objects/scripts
    if myChar:FindFirstChild("CancelVault") or myChar:FindFirstChild("Damageviz") or myChar:FindFirstChild("RedStain") or myChar:FindFirstChild("KillerHitbox") then
        return true
    end

    return false
end

isPlayerKiller = checkPlayerKillerStatus

autoRoleAdaptEnabled = false -- Default to false so it NEVER disables active user toggles
local lastDetectedRole = nil

V_RoleSection:Toggle({
    Title = "Auto Role Adapt",
    Description = "Automatically detects Killer/Survivor role and auto-disables opposing features",
    Default = false,
    Callback = function(v)
        autoRoleAdaptEnabled = v
        WindUI:Notify({ Title = "Role Adapt", Content = v and "Auto Role Adapt active!" or "Auto Role Adapt disabled.", Duration = 2 })
    end
})

-- Background Auto-Role Monitor Thread (runs every 1 second)
task.spawn(function()
    while scriptRunning do
        pcall(function()
            if not scriptRunning then return end
            if autoRoleAdaptEnabled then
                -- NEVER override or shut down active features manually enabled by the user!
                if autoCatchEnabled or autoAimSurvivorEnabled or autoHitSurvivorEnabled or autoHookSurvivorEnabled then
                    -- Killer automation is actively in use
                    lastDetectedRole = "Killer"
                elseif autoRepairEnabled or ghostRepairEnabled or autoPalletEnabled or autoParryEnabled or autoDodgeEnabled or autoSaveEnabled then
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
                            saveSession = (saveSession or 0) + 1
                            palletSession = (palletSession or 0) + 1
                            parrySession = (parrySession or 0) + 1
                            dodgeSession = (dodgeSession or 0) + 1
                            if ghostRepairEnabled then ghostRepairEnabled = false if stopGhostRepair then pcall(stopGhostRepair) end end
                            autoRepairEnabled = false
                            autoDodgeEnabled = false
                            autoPalletEnabled = false
                            autoParryEnabled = false
                            autoSaveEnabled = false
                            WindUI:Notify({ Title = "👹 Role: KILLER", Content = "Detected Killer role.", Duration = 2 })
                        elseif currentRole == "Survivor" then
                            catchSession = (catchSession or 0) + 1
                            autoCatchEnabled = false
                            autoHookSurvivorEnabled = false
                            autoAimSurvivorEnabled = false
                            autoHitSurvivorEnabled = false
                            currentKillerTarget = nil
                            if updateKillerAim then updateKillerAim() end
                            WindUI:Notify({ Title = "🏃 Role: SURVIVOR", Content = "Detected Survivor role.", Duration = 2 })
                        end
                    end
                end
            end
        end)
        task.wait(1)
    end
end)


local HttpService = game:GetService("HttpService")
local VirtualInputManager = game:GetService("VirtualInputManager")

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

local function isValidCharacter(char)
    if not char or not char.Parent then return false end
    if not char:IsDescendantOf(workspace) then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then return false end
    return true, hum, hrp
end

local function isEntityInLobbyOrSpectating(char, plr)
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

local function isCharacterHooked(char)
    if not char or not char.Parent then return false end

    -- Direct attributes
    if char:GetAttribute("isHooked") == true or char:GetAttribute("Hooked") == true or char:GetAttribute("IsHooked") == true then
        return true
    end
    local phase = char:GetAttribute("HookPhase")
    if phase ~= nil and tonumber(phase) ~= nil and tonumber(phase) > 0 then
        return true
    end

    -- Child marker objects
    if char:FindFirstChild("Hooked") or char:FindFirstChild("HookPhase") or char:FindFirstChild("HookWeld") then
        return true
    end

    -- Model parent or ancestry
    local pName = char.Parent.Name:lower()
    if pName:find("hook") or pName:find("meathook") then
        return true
    end

    -- Joints/Welds connecting HumanoidRootPart to MeatHooks
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        for _, joint in ipairs(hrp:GetJoints()) do
            local other = (joint.Part0 == hrp) and joint.Part1 or joint.Part0
            if other and other.Parent then
                local oName = other.Name:lower()
                local opName = other.Parent.Name:lower()
                if oName:find("hook") or opName:find("hook") then
                    return true
                end
            end
        end
    end

    return false
end

local function isCharacterKnocked(char)
    if not char or not char.Parent then return false end
    -- Authoritative game attributes set on downed crawling survivors
    if char:GetAttribute("Knocked") == true or char:GetAttribute("isKnocked") == true
        or char:GetAttribute("Downed") == true or char:GetAttribute("isDowned") == true then
        return true
    end
    if CollectionService and (CollectionService:HasTag(char, "Knocked") or CollectionService:HasTag(char, "Downed")) then
        return true
    end
    if char:FindFirstChild("downed") or char:FindFirstChild("Knocked") or char:FindFirstChild("Downed") then
        return true
    end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and (hum.PlatformStand or (hum.Sit and not char:GetAttribute("isRepairing"))) then
        if not char:GetAttribute("isSliding") and not char:GetAttribute("isVaulting") then
            return true
        end
    end
    return false
end

local function isCharacterKiller(char, plr)
    local valid, hum, hrp = isValidCharacter(char)
    if not valid then return false end
    plr = plr or Players:GetPlayerFromCharacter(char)

    -- If entity is in Lobby or Spectating, they are not an active Killer in match
    if isEntityInLobbyOrSpectating(char, plr) then
        return false
    end

    -- If checking local player, use comprehensive killer check
    if char == player.Character then
        return isPlayerKiller()
    end

    -- RANKED MODE & MATCH GUARANTEE:
    -- In a 1v4 match, if the local player IS the Killer, NO other character can be the Killer!
    if isPlayerKiller() then
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

    -- 2. Survivor-exclusive interaction state attributes (Killers never repair/heal/unhook/exit/slide)
    if char:GetAttribute("isRepairing") == true 
        or char:GetAttribute("isHealing") == true 
        or char:GetAttribute("isDroppingPallet") == true 
        or char:GetAttribute("isUnhooking") == true 
        or char:GetAttribute("isExiting") == true
        or char:GetAttribute("isSliding") == true
        or isCharacterHooked(char)
        or isCharacterKnocked(char) then
        return false
    end

    -- 3. Player-level killer role tags assigned by server
    if plr then
        if plr:GetAttribute("IsKiller") == true 
            or plr:GetAttribute("Role") == "Killer" 
            or plr:GetAttribute("killer") == true then
            return true
        end
        if CollectionService:HasTag(plr, "Killer") then
            return true
        end
    end

    -- 4. CollectionService "Killer" tag (Applied by server to active killer character)
    if CollectionService:HasTag(char, "Killer") then
        return true
    end

    -- 5. Killer-specific attributes on character instance
    if char:GetAttribute("Butcher") == true 
        or char:GetAttribute("IsKiller") == true 
        or char:GetAttribute("KillerName") ~= nil 
        or char:GetAttribute("ChainBusy") == true 
        or char:GetAttribute("killercarry") ~= nil 
        or char:GetAttribute("killercarryidle") ~= nil 
        or char:GetAttribute("Hidden") == true 
        or char:GetAttribute("Stalker") == true then
        return true
    end

    -- 6. Active Killer combat states
    if char:GetAttribute("isAttacking") == true 
        or char:GetAttribute("isLunging") == true then
        return true
    end

    -- 7. Killer weapons / tools held (Chainsaw, Cleaver, Machete, BearTrap, KillerWeapon)
    for _, item in ipairs(char:GetChildren()) do
        if item:IsA("Tool") or item:IsA("BasePart") or item:IsA("Model") then
            local iName = item.Name:lower()
            if iName:find("cleaver") or iName:find("machete") or iName:find("chainsaw") 
                or iName:find("killerweapon") or iName:find("beartrap") or iName:find("slasher")
                or iName:find("axe") or (iName:find("blade") and not iName:find("parry")) or iName:find("spear") then
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

-- Authoritative survivor verification: Strictly excludes Killer, Lobby, and Spectators.
local function isCharacterSurvivor(char, plr)
    local valid, hum, hrp = isValidCharacter(char)
    if not valid then return false end
    if char == player.Character then return false end
    plr = plr or Players:GetPlayerFromCharacter(char)

    -- Under no circumstance can the Killer be classified as a Survivor
    if isCharacterKiller(char, plr) then
        return false
    end
    local currentKiller = getKiller()
    if currentKiller and (char == currentKiller or (plr and Players:GetPlayerFromCharacter(currentKiller) == plr)) then
        return false
    end

    -- Exclude Lobby/Spectator
    if isEntityInLobbyOrSpectating(char, plr) then
        return false
    end

    -- RANKED MODE GUARANTEE:
    -- If local player is the Killer, any other living character in workspace not in lobby IS a Survivor!
    if isPlayerKiller() then
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

local function getKiller()
    local myChar = player.Character

    -- If local player is the Killer, return their character directly!
    if isPlayerKiller() then
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

-- ============================================================
-- GLOBAL MATCH RESET & ESP CLEANUP HANDLER
-- ============================================================
-- Whenever a round finishes or a player respawns, wipes all stale
-- BillboardGuis and Highlights across the entire workspace to prevent
-- old roles from lingering into subsequent games.

local trackedSurvivors = {}
local cleanKillerESP = nil
local cleanSurvivorESP = nil
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

    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj.Name == "KillerESPHighlight" or obj.Name == "KillerESPBillboard"
                or obj.Name == "SurvivorESPHighlight" or obj.Name == "SurvivorESPBillboard"
                or obj.Name == "GenESPHighlight" or obj.Name == "GenESPBillboard" then
                obj:Destroy()
            end
        end
    end)
end

local function onMatchOrCharacterReset()
    cleanAllESPs()
    currentKillerTarget = nil
    currentRepairPoint = nil
    lastDetectedRole = nil
    lastCapturedRepairRequestId = nil
    lastCapturedGenModel = nil
    lastCapturedGenPoint = nil
    lastCapturedHealRequestId = nil
    unlockCameraAndMovement()
end

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

V_ESPSection:Toggle({
    Title = "Killer ESP",
    Description = "Highlights the Killer with real-time status & distance (Persists seamlessly across matches)",
    Default = false,
    Callback = function(v)
        killerESPEnabled = v
        if not v then
            cleanKillerESP()
            WindUI:Notify({ Title = "Killer ESP", Content = "Killer ESP disabled.", Duration = 2 })
            return
        end
        WindUI:Notify({ Title = "Killer ESP", Content = "Killer ESP enabled!", Duration = 2 })
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
                        elseif killer:GetAttribute("IsCarrying") == true or killer:GetAttribute("killercarry") ~= nil or killer:FindFirstChild("CarriedSurvivor") then
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

V_ESPSection:Toggle({
    Title = "Generator ESP",
    Description = "Highlights Generators with live progress & completion status",
    Default = false,
    Callback = function(v)
        genESPEnabled = v
        if not v then
            cleanGenESP()
            WindUI:Notify({ Title = "Generator ESP", Content = "Generator ESP disabled.", Duration = 2 })
            return
        end

        WindUI:Notify({ Title = "Generator ESP", Content = "Generator ESP enabled!", Duration = 2 })

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

                            local hlColor = isCompleted and Color3.fromRGB(50, 255, 80) or Color3.fromRGB(0, 210, 255)
                            local statusText = isCompleted and "⚡ GENERATOR [FIXED 100%]" or string.format("⚡ GENERATOR [%.0f%%]", progress)

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
trackedSurvivors = {}

cleanSurvivorESP = function()
    for _, item in ipairs(survivorESPObjects) do
        pcall(function() item:Destroy() end)
    end
    survivorESPObjects = {}
    if trackedSurvivors then
        for c, data in pairs(trackedSurvivors) do
            if data then
                if data.hl then pcall(function() data.hl:Destroy() end) end
                if data.bb then pcall(function() data.bb:Destroy() end) end
            end
        end
        trackedSurvivors = {}
    end
    pcall(function()
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj.Name == "SurvivorESPHighlight" or obj.Name == "SurvivorESPBillboard" then
                pcall(function() obj:Destroy() end)
            end
        end
    end)
end

V_ESPSection:Toggle({
    Title = "Survivor Detector (ESP)",
    Description = "Highlights all Survivors with health, knocked/hooked state & distance (Persists across matches)",
    Default = false,
    Callback = function(v)
        survivorESPEnabled = v
        if not v then
            cleanSurvivorESP()
            WindUI:Notify({ Title = "Survivor ESP", Content = "Survivor Detector disabled.", Duration = 2 })
            return
        end
        WindUI:Notify({ Title = "Survivor ESP", Content = "Survivor Detector active!", Duration = 2 })
    end
})

-- Permanent Autonomous Background Supervisor (Never crashes, automatically re-attaches across new matches)
task.spawn(function()
    while scriptRunning do
        if survivorESPEnabled then
            pcall(function()
                local myChar = player.Character
                local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                local isKiller = isPlayerKiller and isPlayerKiller()
                local killerChar = isKiller and myChar or getKiller()

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

                -- Also search potential survivor containers in workspace
                local searchContainers = { workspace }
                for _, fName in ipairs({ "Survivors", "Players", "Characters", "Match", "Entities" }) do
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

                local activeSet = {}
                for _, item in ipairs(currentSurvivors) do
                    if not survivorESPEnabled then break end
                    local c = item.char
                    local hum = c:FindFirstChildOfClass("Humanoid")
                    local hrp = c:FindFirstChild("HumanoidRootPart")

                    if hum and hrp and hum.Health > 0 and myHrp and c:IsDescendantOf(workspace) and c ~= killerChar then
                        activeSet[c] = true
                        local dist = (myHrp.Position - hrp.Position).Magnitude

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
                            if phase then
                                status = string.format("HOOKED (STAGE %s)", tostring(phase))
                            else
                                status = "HOOKED"
                            end
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
                        if not record or not record.hl or record.hl.Parent ~= c or not record.bb or record.bb.Parent ~= hrp then
                            -- Clean old if broken
                            if record then
                                if record.hl then pcall(function() record.hl:Destroy() end) end
                                if record.bb then pcall(function() record.bb:Destroy() end) end
                            end

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

                            trackedSurvivors[c] = { hl = hl, bb = bb, lbl = lbl }
                        else
                            -- Smooth in-place update! Zero flicker!
                            record.hl.FillColor = fillColor
                            record.lbl.TextColor3 = fillColor
                            record.lbl.Text = string.format("👤 %s\n[%s] - %.0f studs", item.name, status, dist)
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
        else
            cleanSurvivorESP()
        end
        task.wait(0.25)
    end
end)
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
                WindUI:Notify({ Title = "Wall Remover", Content = "All walls & obstacles restored.", Duration = 2 })
                return
            end

            WindUI:Notify({ Title = "Wall Remover", Content = "Walls removed! (Generators & floor preserved)", Duration = 2 })
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
            WindUI:Notify({ Title = "Skillcheck", Content = "Automatic Perfect Skill Check disabled.", Duration = 2 })
            return
        end

        startSkillcheckWatcher()
        WindUI:Notify({ Title = "Skillcheck", Content = "Automatic Perfect Skill Check active!", Duration = 2 })
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
            WindUI:Notify({ Title = "No Skill Check", Content = "No Skill Check active: pop-ups hidden & auto-solved!", Duration = 2 })
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
            WindUI:Notify({ Title = "No Skill Check", Content = "No Skill Check disabled: normal UI restored.", Duration = 2 })
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
        if pVal >= 99.5 or (pVal >= 1 and pVal <= 1.01 and pVal > 0) then
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

    local nearestPoint = nil
    local minDist = 16

    -- 1. Check CollectionService tagged UnhookPoint
    if CollectionService then
        for _, pt in ipairs(CollectionService:GetTagged("UnhookPoint")) do
            if pt:IsA("BasePart") then
                local d = (pt.Position - hrp.Position).Magnitude
                if d < minDist then
                    minDist = d
                    nearestPoint = pt
                end
            end
        end
    end
    if nearestPoint then return nearestPoint end

    -- 2. Check hook models in workspace
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and (obj.Name == "UnhookPoint" or obj.Name:lower():find("unhook")) then
            local d = (obj.Position - hrp.Position).Magnitude
            if d < minDist then
                minDist = d
                nearestPoint = obj
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

local function checkWallCollision(fromPos, toPos, ignoreModel)
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
local function startTravelNoClip()
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

local function stopTravelNoClip()
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
local function computeSmartWaypoints(startPos, endPos, targetPart, avoidKillerPos, killerSafeDist)
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
            WindUI:Notify({ Title = "Auto Repair", Content = "Auto repair stopped immediately.", Duration = 2 })
            return
        end

        completedGenerators = {}
        WindUI:Notify({ Title = "Auto Repair", Content = "Auto repair active! (Auto-avoids Killer)", Duration = 2 })

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
                        myHrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
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
                    myHrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    myHrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
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

                    -- Anchor underground and freeze physics to prevent falling into the void
                    if myHrp then
                        local desiredPos = targetPoint.Position - Vector3.new(0, ghostDepthOffset, 0)
                        if (myHrp.Position - desiredPos).Magnitude > 2 then
                            myHrp.CFrame = CFrame.new(desiredPos)
                        end
                        myHrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        myHrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
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
            ghostOriginalCFrame = nil
            completedGenerators = {}
            startGhostRepairThread()
            WindUI:Notify({ Title = "Ghost Gen", Content = "Underground Ghost Repair enabled!", Duration = 2.5 })
        else
            ghostRepairSession = ghostRepairSession + 1
            stopGhostRepair()
            WindUI:Notify({ Title = "Ghost Gen", Content = "Underground Ghost Repair stopped.", Duration = 2 })
        end
    end
})

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
            WindUI:Notify({ Title = "Pallet Stun", Content = "Auto Pallet Stun disabled immediately.", Duration = 2 })
            return
        end

        WindUI:Notify({ Title = "Pallet Stun", Content = "Auto Pallet Stun active!", Duration = 2 })

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
            WindUI:Notify({ Title = "Auto Parry", Content = "Auto Parry disabled immediately.", Duration = 2 })
            return
        end

        WindUI:Notify({ Title = "Auto Parry", Content = "Auto Parry active! (Directional snap + item defense)", Duration = 2 })

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
                                VirtualInputManager:SendMouseButtonEvent(0, 0, 1, true, game, 0)
                                task.wait(0.02)
                                VirtualInputManager:SendMouseButtonEvent(0, 0, 1, false, game, 0)
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
            WindUI:Notify({ Title = "Auto Aim", Content = "Auto Aim disabled.", Duration = 2 })
            return
        end

        WindUI:Notify({ Title = "Auto Aim", Content = "Auto Aim enabled!", Duration = 2 })

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
            WindUI:Notify({ Title = "Auto Dodge", Content = "Auto Dodge disabled immediately.", Duration = 2 })
            return
        end

        WindUI:Notify({ Title = "Auto Dodge", Content = "Auto Dodge active! (Always 17 studs behind Killer)", Duration = 2 })

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
            pcall(function()
                myChar:SetAttribute("isUnhooking", true)
                if unhookPt then
                    remotes.Carry.UnHookEvent:FireServer(unhookPt, myChar)
                end
                remotes.Carry.UnHookEvent:FireServer(targetChar, myChar)
            end)

            -- Fire ProximityPrompts for instant prompt completion
            pcall(function()
                for _, prompt in ipairs(targetChar:GetDescendants()) do
                    if prompt:IsA("ProximityPrompt") then
                        fireproximityprompt(prompt)
                    end
                end
                if unhookPt and unhookPt.Parent then
                    for _, prompt in ipairs(unhookPt.Parent:GetDescendants()) do
                        if prompt:IsA("ProximityPrompt") then
                            fireproximityprompt(prompt)
                        end
                    end
                end
            end)

            local rescueTimeout = tick() + 3.0
            while isCharacterHooked(targetChar) and tick() < rescueTimeout and scriptRunning do
                task.wait(0.15)
                if unhookPt then
                    pcall(function() remotes.Carry.UnHookEvent:FireServer(unhookPt, myChar) end)
                end
                pcall(function() remotes.Carry.UnHookEvent:FireServer(targetChar, myChar) end)
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
            WindUI:Notify({ Title = "Auto Save", Content = "Auto Save disabled immediately.", Duration = 2 })
            return
        end

        WindUI:Notify({ Title = "Auto Save", Content = string.format("Auto Save active! (Travel: %s)", rescueTravelMode), Duration = 2.5 })

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
                                pcall(function()
                                    myChar:SetAttribute("isUnhooking", true)
                                    if unhookPt then
                                        remotes.Carry.UnHookEvent:FireServer(unhookPt, myChar)
                                    end
                                    remotes.Carry.UnHookEvent:FireServer(targetChar, myChar)
                                end)

                                pcall(function()
                                    for _, prompt in ipairs(targetChar:GetDescendants()) do
                                        if prompt:IsA("ProximityPrompt") then
                                            fireproximityprompt(prompt)
                                        end
                                    end
                                    if unhookPt and unhookPt.Parent then
                                        for _, prompt in ipairs(unhookPt.Parent:GetDescendants()) do
                                            if prompt:IsA("ProximityPrompt") then
                                                fireproximityprompt(prompt)
                                            end
                                        end
                                    end
                                end)

                                local rescueTimeout = tick() + 2.8
                                while isCharacterHooked(targetChar) and tick() < rescueTimeout and checkSaveActive() do
                                    task.wait(0.15)
                                    if unhookPt then
                                        pcall(function() remotes.Carry.UnHookEvent:FireServer(unhookPt, myChar) end)
                                    end
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
            WindUI:Notify({ Title = "Server Collision", Content = "Server-side collision disabled!", Duration = 2 })
        else
            if not noClipEnabled then
                fireEnableCollision()
            end
            WindUI:Notify({ Title = "Server Collision", Content = "Server-side collision restored.", Duration = 2 })
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
        WindUI:Notify({ Title = "Server Crouch", Content = v and "Server Crouch active (Crouchingserver = true)!" or "Server Crouch disabled.", Duration = 2 })
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
            WindUI:Notify({ Title = "Server Speedboost", Content = string.format("Speedboost active (%.1fx multiplier)!", speedboostMultiplier), Duration = 2 })
        else
            fireChangeAttribute("speedboost", 1)
            WindUI:Notify({ Title = "Server Speedboost", Content = "Speedboost reset to normal (1.0x).", Duration = 2 })
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
            WindUI:Notify({ Title = "Server No-Stun", Content = "No-Stun active (nostun = true)!", Duration = 2 })
        else
            fireChangeAttribute("nostun", false)
            WindUI:Notify({ Title = "Server No-Stun", Content = "Server No-Stun disabled.", Duration = 2 })
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
            WindUI:Notify({ Title = "Anti-Carry Active", Content = "Will force drop immediately if picked up by Killer!", Duration = 2.5 })
        else
            WindUI:Notify({ Title = "Anti-Carry Disabled", Content = "Anti-Carry disabled.", Duration = 2 })
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
            WindUI:Notify({ Title = "Anti-Immobile Active", Content = "Movement freeze locks automatically bypassed!", Duration = 2.5 })
        else
            WindUI:Notify({ Title = "Anti-Immobile Disabled", Content = "Anti-Immobile disabled.", Duration = 2 })
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

            -- 6. Anti-Immobile / Anti-Root maintenance
            if antiImmobileEnabled then
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

    -- Safe exclusions: Never interfere if character is actively on a meat hook or carried by killer
    local isHooked = char:GetAttribute("IsHooked") == true or (char:GetAttribute("HookedProgress") ~= nil and char:GetAttribute("HookedProgress") > 0)
    local isCarried = char:GetAttribute("IsCarried") == true or char:GetAttribute("BeingCarried") == true or char:GetAttribute("IsCarrying") == true
    if isHooked or isCarried then return end

    -- 1. Anti-Anchor: When server rubberbands or anti-cheat triggers, it pins HumanoidRootPart.Anchored = true
    if hrp.Anchored then
        hrp.Anchored = false
    end

    -- 2. Clear server anti-cheat anchor attribute immediately
    if char:GetAttribute("AC_ServerAnchor") ~= nil then
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
    Title = "Killer Automation (Catch, Hit & Hook)"
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

-- Helper to detect if Killer is currently carrying a survivor on shoulder
local function isKillerCarrying(char)
    char = char or player.Character
    if not char then return false end
    return char:GetAttribute("IsCarrying") == true
        or char:GetAttribute("isCarrying") == true
        or char:GetAttribute("killercarry") ~= nil
        or char:FindFirstChild("CarriedSurvivor") ~= nil
        or char:FindFirstChild("Carry") ~= nil
        or char:GetAttribute("BeingCarried") ~= nil
end

-- Helper to detect if Killer is currently stunned, blinded, or immobilized by survivor items/pallets
local function isKillerStunnedOrLocked(char)
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
local function isSurvivorParryingOrShielded(sChar)
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
    if autoCatchEnabled or autoAimSurvivorEnabled or autoHitSurvivorEnabled or autoHookSurvivorEnabled or (isPlayerKiller and isPlayerKiller()) then
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
    if not (autoCatchEnabled or autoAimSurvivorEnabled or autoHitSurvivorEnabled or autoHookSurvivorEnabled or (isPlayerKiller and isPlayerKiller())) then
        if isCharacterKiller(c, plr) or c == getKiller() then return false end
    end

    return isCharacterKnocked(c)
end

local function findNearestSurvivor()
    local myChar = player.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return nil end

    local bestTarget = nil
    local bestDist = math.huge
    local candidateModels = {}

    -- 1. Check Players
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and plr.Character ~= myChar then
            table.insert(candidateModels, plr.Character)
        end
    end

    -- 2. Check workspace subfolders (Survivors, Characters, Match, Entities)
    local searchContainers = { workspace }
    for _, fName in ipairs({ "Survivors", "Players", "Characters", "Match", "Entities" }) do
        local folder = workspace:FindFirstChild(fName)
        if folder and (folder:IsA("Folder") or folder:IsA("Model")) then
            table.insert(searchContainers, folder)
        end
    end

    for _, container in ipairs(searchContainers) do
        for _, obj in ipairs(container:GetChildren()) do
            if obj:IsA("Model") and obj ~= myChar and not Players:GetPlayerFromCharacter(obj) then
                table.insert(candidateModels, obj)
            end
        end
    end

    for _, c in ipairs(candidateModels) do
        if isSurvivorValidTarget(c) then
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
local function findNearestDownedSurvivor()
    local myChar = player.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return nil end

    local bestDowned = nil
    local bestDist = math.huge
    local candidateModels = {}

    -- 1. Check Players
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and plr.Character ~= myChar then
            table.insert(candidateModels, plr.Character)
        end
    end

    -- 2. Check workspace subfolders
    local searchContainers = { workspace }
    for _, fName in ipairs({ "Survivors", "Players", "Characters", "Match", "Entities" }) do
        local folder = workspace:FindFirstChild(fName)
        if folder and (folder:IsA("Folder") or folder:IsA("Model")) then
            table.insert(searchContainers, folder)
        end
    end

    for _, container in ipairs(searchContainers) do
        for _, obj in ipairs(container:GetChildren()) do
            if obj:IsA("Model") and obj ~= myChar and not Players:GetPlayerFromCharacter(obj) then
                table.insert(candidateModels, obj)
            end
        end
    end

    for _, c in ipairs(candidateModels) do
        if isSurvivorDowned(c) then
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

-- Locates nearest unoccupied meat hook in the map
local function findNearestAvailableHook()
    local myChar = player.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return nil end

    local bestHook = nil
    local bestDist = math.huge
    local candidates = {}

    -- 1. CollectionService tagged HookPoint (from the dump.lua)
    if CollectionService then
        for _, p in ipairs(CollectionService:GetTagged("HookPoint")) do
            if p:IsA("BasePart") then
                table.insert(candidates, p)
            end
        end
    end

    -- 2. Fallback search by object name in workspace
    if #candidates == 0 then
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") and (obj.Name == "HookPoint" or (obj.Name:lower():find("hook") and obj.Name:lower():find("point"))) then
                table.insert(candidates, obj)
            end
        end
    end

    -- 3. Additional fallback: Hook models HitBox/PrimaryPart
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
            if CollectionService and CollectionService:HasTag(hookPart, "doing action") then
                isOccupied = true
            end
            if hookPart:GetAttribute("Occupied") == true or (hookPart.Parent and hookPart.Parent:GetAttribute("Occupied") == true) then
                isOccupied = true
            end

            -- Check if any survivor is currently attached to this hook (within 5.5 studs)
            if not isOccupied then
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr.Character and plr.Character ~= myChar then
                        local sHrp = plr.Character:FindFirstChild("HumanoidRootPart")
                        if sHrp and (sHrp.Position - hookPart.Position).Magnitude <= 5.5 then
                            if plr.Character:GetAttribute("IsHooked") or plr.Character:GetAttribute("HookPhase") ~= nil or plr.Character:FindFirstChild("Hooked") ~= nil then
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

-- Comprehensive Auto Hit execution across Android executors and PC (Guaranteed Hit Delivery)
local function executeKillerHit(targetChar)
    local myChar = player.Character
    if not myChar then return end

    local myHrp = myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end

    local sHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
    if sHrp then
        -- 1. Snap Killer body directly towards survivor
        local lookTarget = Vector3.new(sHrp.Position.X, myHrp.Position.Y, sHrp.Position.Z)
        myHrp.CFrame = CFrame.lookAt(myHrp.Position, lookTarget)

        -- 2. Melee Range Step: ensure close physical proximity (< 2.5 studs)
        local curDist = (myHrp.Position - sHrp.Position).Magnitude
        if curDist > 2.5 then
            local behindPos = sHrp.Position - (sHrp.CFrame.LookVector * 1.8) + Vector3.new(0, 0.2, 0)
            myHrp.CFrame = CFrame.lookAt(behindPos, sHrp.Position)
        end
    end

    local remotes = getVDRemotes()

    -- 3. Fire Official Violence District Attack Remotes
    if remotes.Attacks then
        if remotes.Attacks:FindFirstChild("BasicAttack") then
            pcall(function() remotes.Attacks.BasicAttack:FireServer() end)
        end
        if remotes.Attacks:FindFirstChild("Lunge") then
            pcall(function() remotes.Attacks.Lunge:FireServer() end)
        end
    end

    -- 4. Fire Mobile Attack GUI Button (Slasher-mob / Slasher / Controls.attack)
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
                                VirtualInputManager:SendTouchEvent(3, 0, bPos.X, bPos.Y)
                                VirtualInputManager:SendTouchEvent(3, 2, bPos.X, bPos.Y)
                            end)
                        end
                    end
                end
            end
        end
    end)

    -- 5. Physical Weapon & Arm Hitbox Collision Simulation (firetouchinterest)
    if typeof(firetouchinterest) == "function" and sHrp then
        pcall(function()
            local rightArm = myChar:FindFirstChild("Right Arm") or myChar:FindFirstChild("RightHand")
            for _, part in ipairs(myChar:GetDescendants()) do
                if part:IsA("BasePart") and (part.Name:lower():find("weapon") or part.Name:lower():find("blade") or part.Name:lower():find("knife") or part.Name:lower():find("machete") or part.Name:lower():find("axe") or part.Name:lower():find("cleaver") or part == rightArm) then
                    firetouchinterest(part, sHrp, 0)
                    firetouchinterest(part, sHrp, 1)
                end
            end
            if rightArm then
                firetouchinterest(rightArm, sHrp, 0)
                firetouchinterest(rightArm, sHrp, 1)
            end
        end)
    end

    -- 6. Equipped Tool Activation
    for _, item in ipairs(myChar:GetChildren()) do
        if item:IsA("Tool") then
            pcall(function() item:Activate() end)
        end
    end

    -- 7. PC/Mobile Screen Center Click/Tap (Triggers viewport melee raycast in game)
    pcall(function()
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(800, 600)
        local cx = vp.X / 2
        local cy = vp.Y / 2
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
        VirtualInputManager:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
        VirtualInputManager:SendTouchEvent(3, 0, cx, cy)
        VirtualInputManager:SendTouchEvent(3, 2, cx, cy)
    end)
end

-- Continuous frame-locked Auto Aim for Killer (Works whether Auto Catch is ON or OFF)
local function updateKillerAim()
    pcall(function()
        RunService:UnbindFromRenderStep("KillerAutoAim")
    end)
    if killerAimConn then
        pcall(function() killerAimConn:Disconnect() end)
        killerAimConn = nil
    end

    if not autoAimSurvivorEnabled then return end

    local function performAim()
        if not autoAimSurvivorEnabled then return end

        local myChar = player.Character
        local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myHrp then return end

        local target = currentKillerTarget
        if not target or not target.Parent or not isSurvivorValidTarget(target) then
            local nearest, nDist = findNearestSurvivor()
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

        local aimPos = sHrp.Position + Vector3.new(0, 1.2, 0)

        -- Lock Camera directly at Survivor
        cam.CFrame = CFrame.lookAt(cam.CFrame.Position, aimPos)

        -- Lock Killer body towards Survivor for server hit validation
        local lookTarget = Vector3.new(sHrp.Position.X, myHrp.Position.Y, sHrp.Position.Z)
        myHrp.CFrame = CFrame.lookAt(myHrp.Position, lookTarget)
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
            if (autoAimSurvivorEnabled or autoHitSurvivorEnabled) and not autoCatchEnabled then
                local myChar = player.Character
                local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                if myHrp then
                    local targetSurvivor, dist = findNearestSurvivor()
                    if targetSurvivor then
                        currentKillerTarget = targetSurvivor

                        -- Auto Hit trigger when within hit reach distance (slider: 6 - 20 studs, default 10)
                        if autoHitSurvivorEnabled and dist <= hitReachDistance then
                            if (tick() - lastKillerHitTime) >= 0.35 then
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
        task.wait(0.03)
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
            task.wait(0.04)
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
        task.wait(0.03)
        return (myHrp.Position - targetPos).Magnitude <= 3.8

    -- 2. SAFE TELEPORT (WAYPOINTS CLOSING IN TO 2.8 STUDS)
    elseif killerTravelMode == "Safe Teleport" then
        return travelToTargetLocation(targetHrp.Position, 2.8, function()
            return autoCatchEnabled and targetChar.Parent and isSurvivorValidTarget(targetChar) and not isKillerStunnedOrLocked(myChar)
        end)

    -- 3. RUN NORMALLY (WAYPOINTS CLOSING IN TO 3.2 STUDS)
    elseif killerTravelMode == "Run Normally" then
        return travelToTargetLocation(targetHrp.Position, 3.2, function()
            return autoCatchEnabled and targetChar.Parent and isSurvivorValidTarget(targetChar) and not isKillerStunnedOrLocked(myChar)
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
            if autoHookSurvivorEnabled and not autoCatchEnabled and not isHookActionActive then
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
                                return autoHookSurvivorEnabled and not autoCatchEnabled and isKillerCarrying(myChar)
                            end)
                        end

                        -- When at hook (<= 8.5 studs): execute hang
                        local currentDist = (myHrp.Position - hookPart.Position).Magnitude
                        if currentDist <= 8.5 then
                            local lookTarget = Vector3.new(hookPart.Position.X, myHrp.Position.Y, hookPart.Position.Z)
                            myHrp.CFrame = CFrame.lookAt(myHrp.Position, lookTarget)
                            myHrp.AssemblyLinearVelocity = Vector3.zero
                            myHrp.AssemblyAngularVelocity = Vector3.zero

                            local reqId = HttpService:GenerateGUID(false)
                            local remotes = getVDRemotes()

                            -- Fire Hook remote (HookEvent is Client -> Server)
                            if remotes.Carry and remotes.Carry:FindFirstChild("HookEvent") then
                                pcall(function() remotes.Carry.HookEvent:FireServer(hookPart, reqId, myChar) end)
                            end

                            -- Fire ProximityPrompts on the hook
                            pcall(function()
                                local hookModel = hookPart:FindFirstAncestorOfClass("Model") or hookPart.Parent
                                if hookModel then
                                    for _, prompt in ipairs(hookModel:GetDescendants()) do
                                        if prompt:IsA("ProximityPrompt") then
                                            fireproximityprompt(prompt)
                                        end
                                    end
                                end
                            end)

                            -- Wait for hook animation/server sync
                            local waitTimeout = tick() + 2.5
                            while tick() < waitTimeout and isKillerCarrying(myChar) do
                                task.wait(0.1)
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
                                return autoHookSurvivorEnabled and not autoCatchEnabled and not isKillerCarrying(myChar) and isSurvivorDowned(downedSurvivor)
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
                                        fireproximityprompt(prompt)
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

V_ObjectiveSection:Toggle({
    Title = "NoClip (Pass Through Walls)",
    Description = "Phases through all map walls, obstacles & doors",
    Default = false,
    Callback = function(v)
        updateNoClip(v)
        WindUI:Notify({ Title = "NoClip", Content = v and "NoClip enabled!" or "NoClip disabled.", Duration = 2 })
    end
})

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
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and plr.Character ~= myChar then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if hum and hrp and hum.Health > 0 and plr.Character:IsDescendantOf(workspace) then
                local label = string.format("%s (@%s)", plr.DisplayName or plr.Name, plr.Name)
                table.insert(result, {
                    label = label,
                    player = plr,
                    character = plr.Character,
                    name = plr.Name
                })
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
            if survivorDropdownRef and survivorDropdownRef.SetValues then
                survivorDropdownRef:SetValues(newLabels)
            elseif survivorDropdownRef and survivorDropdownRef.Refresh then
                survivorDropdownRef:Refresh(newLabels)
            end
        end)
        local count = (newLabels[1] == "No Survivors Found") and 0 or #newLabels
        WindUI:Notify({ Title = "Survivor List Refreshed", Content = string.format("Found %d active survivor(s).", count), Duration = 2.5 })
    end
})

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

        local survivors = getAliveSurvivorList()
        if #survivors == 0 then
            WindUI:Notify({ Title = "Teleport Failed", Content = "No alive survivors detected in the match!", Duration = 2.5 })
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
            task.wait(0.03)
        end

        currentKillerTarget = tChar

        WindUI:Notify({
            Title = "⚡ Teleported to Survivor",
            Content = string.format("Warped behind %s!", targetEntry.player.DisplayName or targetEntry.name),
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
        autoAimSurvivorEnabled = v or autoCatchEnabled
        updateKillerAim()
        WindUI:Notify({ Title = "Auto Aim", Content = v and "Killer Auto Aim active!" or "Killer Auto Aim disabled.", Duration = 2 })
    end
})

V_KillerSection:Toggle({
    Title = "Auto Hit Survivor",
    Description = "Automatically executes attack when survivor is in reach (Active even without Auto Catch)",
    Default = false,
    Callback = function(v)
        standaloneHitUserSetting = v
        autoHitSurvivorEnabled = v or autoCatchEnabled
        WindUI:Notify({ Title = "Auto Hit", Content = v and "Killer Auto Hit active!" or "Killer Auto Hit disabled.", Duration = 2 })
    end
})

V_KillerSection:Toggle({
    Title = "Auto Hook Survivor",
    Description = "Picks up knocked survivors and transports them to the nearest hook to hang them",
    Default = false,
    Callback = function(v)
        autoHookSurvivorEnabled = v
        WindUI:Notify({ Title = "Auto Hook", Content = v and "Auto Hook Survivor active!" or "Auto Hook disabled.", Duration = 2 })
    end
})

V_KillerSection:Toggle({
    Title = "Auto Catch Survivor",
    Description = "Instant teleport to unknocked survivors & hit, then auto-hook when all knocked down",
    Default = false,
    Callback = function(v)
        autoCatchEnabled = v
        catchSession = catchSession + 1
        local thisSession = catchSession

        if not v then
            currentKillerTarget = nil
            if not standaloneAimUserSetting then
                autoAimSurvivorEnabled = false
                updateKillerAim()
            end
            if not standaloneHitUserSetting then
                autoHitSurvivorEnabled = false
            end
            WindUI:Notify({ Title = "Auto Catch", Content = "Auto Catch disabled immediately.", Duration = 2 })
            return
        end

        autoAimSurvivorEnabled = true
        autoHitSurvivorEnabled = true
        updateKillerAim()

        WindUI:Notify({ Title = "Auto Catch", Content = "Hunting unknocked Survivors (Instant Teleport, Hit & Hook)...", Duration = 2.5 })

        local function checkCatchActive()
            return autoCatchEnabled and (catchSession == thisSession) and scriptRunning
        end

        task.spawn(function()
            while checkCatchActive() do
                local ok, err = pcall(function()
                    local myChar = player.Character
                    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                    if not myHrp then task.wait(0.3) return end

                    -- Unfreeze if anchored or immobile
                    if myHrp.Anchored then
                        pcall(function() myHrp.Anchored = false end)
                    end
                    pcall(function()
                        myChar:SetAttribute("Immobile", false)
                        myChar:SetAttribute("AC_ServerAnchor", false)
                    end)

                    -- ====================================================
                    -- CHECK 1: CARRYING SURVIVOR -> TRANSPORT TO HOOK & HANG
                    -- ====================================================
                    local carrying = isKillerCarrying(myChar)
                    if carrying then
                        local hookPart, hookDist = findNearestAvailableHook()
                        if hookPart then
                            local hookPos = hookPart.Position
                            local hookCF = CFrame.lookAt(hookPos + Vector3.new(0, 0.5, 2.2), hookPos)
                            for attempt = 1, 3 do
                                myHrp.CFrame = hookCF
                                myHrp.AssemblyLinearVelocity = Vector3.zero
                                myHrp.AssemblyAngularVelocity = Vector3.zero
                                task.wait(0.015)
                            end

                            local reqId = HttpService:GenerateGUID(false)
                            local remotes = getVDRemotes()
                            if remotes.Carry and remotes.Carry:FindFirstChild("HookEvent") then
                                pcall(function() remotes.Carry.HookEvent:FireServer(hookPart, reqId, myChar) end)
                            end

                            local hookModel = hookPart:FindFirstAncestorOfClass("Model") or hookPart.Parent
                            if hookModel then
                                for _, prompt in ipairs(hookModel:GetDescendants()) do
                                    if prompt:IsA("ProximityPrompt") then
                                        pcall(function() fireproximityprompt(prompt) end)
                                    end
                                end
                            end

                            local hookWaitTimeout = tick() + 1.2
                            while tick() < hookWaitTimeout and isKillerCarrying(myChar) and checkCatchActive() do
                                task.wait(0.05)
                            end
                            WindUI:Notify({ Title = "🪝 Survivor Hooked!", Content = "Target successfully hung on hook.", Duration = 2.0 })
                        end
                        return
                    end

                    -- ====================================================
                    -- PRIORITY 1: HUNT UNKNOCKED SURVIVORS (INSTANT TELEPORT & HIT)
                    -- ====================================================
                    -- We hunt and hit all active upright survivors FIRST!
                    local unknockedSurvivor, dist = findNearestSurvivor()
                    if unknockedSurvivor and unknockedSurvivor:FindFirstChild("HumanoidRootPart") then
                        currentKillerTarget = unknockedSurvivor
                        local sHrp = unknockedSurvivor.HumanoidRootPart

                        -- Instant teleport directly behind unknocked survivor (2.0 studs behind, facing their back)
                        local behindPos = sHrp.Position - (sHrp.CFrame.LookVector * 2.0) + Vector3.new(0, 0.2, 0)
                        local behindCF = CFrame.lookAt(behindPos, sHrp.Position)
                        for attempt = 1, 2 do
                            myHrp.CFrame = behindCF
                            myHrp.AssemblyLinearVelocity = Vector3.zero
                            myHrp.AssemblyAngularVelocity = Vector3.zero
                            task.wait(0.015)
                        end

                        -- Lock camera at survivor
                        local cam = workspace.CurrentCamera
                        if cam then
                            cam.CFrame = CFrame.lookAt(cam.CFrame.Position, sHrp.Position + Vector3.new(0, 1.2, 0))
                        end

                        -- Execute attack
                        if (tick() - lastKillerHitTime) >= 0.25 then
                            executeKillerHit(unknockedSurvivor)
                            lastKillerHitTime = tick()
                        end
                        return
                    end

                    -- ====================================================
                    -- PRIORITY 2: ALL SURVIVORS KNOCKED DOWN -> AUTO HOOK THEM!
                    -- ====================================================
                    -- Only reached when there are ZERO unknocked survivors left!
                    local downedSurvivor, downedDist = findNearestDownedSurvivor()
                    if downedSurvivor and downedSurvivor:FindFirstChild("HumanoidRootPart") then
                        currentKillerTarget = downedSurvivor
                        local dHrp = downedSurvivor.HumanoidRootPart

                        -- Instant teleport directly on top of the downed survivor
                        local standPos = dHrp.Position + Vector3.new(0, 0.5, 1.8)
                        local targetCF = CFrame.lookAt(standPos, dHrp.Position)
                        for attempt = 1, 2 do
                            myHrp.CFrame = targetCF
                            myHrp.AssemblyLinearVelocity = Vector3.zero
                            myHrp.AssemblyAngularVelocity = Vector3.zero
                            task.wait(0.015)
                        end

                        -- Execute Carry / Pick Up
                        local remotes = getVDRemotes()
                        if remotes.Carry and remotes.Carry:FindFirstChild("CarrySurvivorEvent") then
                            pcall(function() remotes.Carry.CarrySurvivorEvent:FireServer(downedSurvivor) end)
                        end

                        for _, prompt in ipairs(downedSurvivor:GetDescendants()) do
                            if prompt:IsA("ProximityPrompt") then
                                pcall(function() fireproximityprompt(prompt) end)
                            end
                        end

                        local pickupTimeout = tick() + 1.0
                        while tick() < pickupTimeout and not isKillerCarrying(myChar) and checkCatchActive() do
                            task.wait(0.05)
                        end
                        if isKillerCarrying(myChar) then
                            WindUI:Notify({ Title = "🎒 Survivor Picked Up", Content = "Transporting survivor to hook...", Duration = 1.5 })
                        end
                        return
                    end

                    -- If no unknocked and no downed survivors (all hooked or escaped)
                    currentKillerTarget = nil
                    task.wait(0.2)
                end)
                if not ok then
                    -- Log error if any occurs in loop
                    task.wait(0.1)
                end
                task.wait(0.04)
            end
            currentKillerTarget = nil
        end)
    end
})

end
