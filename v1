-- ============================================================
-- RIEL PRIVATE: OFFICIALLY RESTORED WINDUI ARCHITECTURE (MONTH 10)
-- 100% Pure Lua 5.1 & Delta Executor Android Compatibility
-- ============================================================

print("==================================================")
print("🛡️ [Riel Private] Initializing Script on Delta Executor...")
print("🛡️ [Riel Private] Place ID: " .. tostring(game.PlaceId))
print("==================================================")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local weathers = {"Cloudy", "Snow", "Storm", "Radiant", "SharkHunt", "Wind"}

-- Non-blocking LocalPlayer resolution
local player = Players.LocalPlayer
local waitStart = tick()
while not player and (tick() - waitStart) < 8 do
    task.wait(0.1)
    player = Players.LocalPlayer
end

local character = player and player.Character
local humanoid = character and character:FindFirstChildOfClass("Humanoid")

if player then
    player.CharacterAdded:Connect(function(newChar)
        character = newChar
        humanoid = newChar:WaitForChild("Humanoid", 5)
    end)
end

-- ============================================================
-- GUI CONTAINER RESOLUTION (DELTA HUI -> COREGUI -> PLAYERGUI)
-- ============================================================
local function getGuiContainer()
    local ok_hui, hui = pcall(function() return gethui() end)
    if ok_hui and hui and typeof(hui) == "Instance" then
        return hui
    end

    if player then
        local pg = player:FindFirstChildOfClass("PlayerGui") or player:FindFirstChild("PlayerGui")
        if pg then return pg end
        local okWait, waitedPg = pcall(function() return player:WaitForChild("PlayerGui", 5) end)
        if okWait and waitedPg then return waitedPg end
    end

    local okCg, cg = pcall(function() return game:GetService("CoreGui") end)
    if okCg and cg then
        local canWrite = pcall(function()
            local test = Instance.new("Folder")
            test.Parent = cg
            test:Destroy()
        end)
        if canWrite then return cg end
    end

    return game:GetService("CoreGui")
end

-- Master script running state
local scriptRunning = true
local charAddedConn = nil
local killerAimConn = nil
-- floating button handled natively by WindUI OpenButton

-- Master Automation Session Counters
local repairSession = 0
local saveSession = 0
local catchSession = 0
local palletSession = 0
local parrySession = 0
local dodgeSession = 0

-- Master Automation Toggle States (Shared across all features)
local autoRepairEnabled = false
local autoSkillCheckEnabled = true    -- Default ON
local autoPalletEnabled = false
local autoParryEnabled = false
local autoSaveEnabled = false
local killerESPEnabled = false
local genESPEnabled = false
local survivorESPEnabled = false
local autoCatchEnabled = false
local autoAimSurvivorEnabled = false
local autoHitSurvivorEnabled = false
local autoHookSurvivorEnabled = false
local autoDodgeEnabled = false
local autoRoleAdaptEnabled = true     -- Default ON
local flyEnabled = false
local didEnabled = false
local noClipEnabled = false
local currentRepairPoint = nil
local currentKillerTarget = nil

-- Thread handles
local autoFarmSpeedThread = nil
local autoMountAnehThread = nil
local autoMountBotakThread = nil
local autoFarmGemsThread = nil
local autoFarmXPThread = nil
local autoRebirthThread = nil
local autoFishingThread = nil
local autoEggThread = nil
local selectedEgg = "Red Crystal"

-- Forward declaration of Window & StopScript
local Window = nil
local stopScript = nil
-- ============================================================
-- FORWARD DECLARATIONS FOR REGISTER SCOPING & STOP SCRIPT
-- ============================================================
local updateNoClip = nil
local stopFly = nil
local cleanKillerESP = nil
local cleanGenESP = nil
local cleanSurvivorESP = nil
local getVDRemotes = nil
local isPlayerKiller = nil


-- ============================================================
-- GLOBAL CLEAN SHUTDOWN & SCRIPT STOPPER
-- ============================================================
stopScript = function()
    if not scriptRunning then return end
    scriptRunning = false

    print("[Riel Private] Stopping all automations and closing UI...")

    -- 1. Disable all automation toggles
    autoRepairEnabled = false
    autoSkillCheckEnabled = false
    autoPalletEnabled = false
    autoParryEnabled = false
    autoSaveEnabled = false
    killerESPEnabled = false
    genESPEnabled = false
    survivorESPEnabled = false
    autoCatchEnabled = false
    autoAimSurvivorEnabled = false
    autoHitSurvivorEnabled = false
    autoHookSurvivorEnabled = false
    autoDodgeEnabled = false
    autoRoleAdaptEnabled = true
    flyEnabled = false
    didEnabled = false
    noClipEnabled = false

    -- Invalidate sessions
    repairSession = (repairSession or 0) + 1
    saveSession = (saveSession or 0) + 1
    catchSession = (catchSession or 0) + 1
    palletSession = (palletSession or 0) + 1
    parrySession = (parrySession or 0) + 1
    dodgeSession = (dodgeSession or 0) + 1

    -- 2. Restore character state
    pcall(function()
        if updateNoClip then updateNoClip(false) end
    end)
    pcall(function()
        if stopFly then stopFly() end
    end)
    if currentRepairPoint then
        pcall(function()
            local remotes = getVDRemotes and getVDRemotes()
            if remotes and remotes.Generator and remotes.Generator:FindFirstChild("RepairEvent") then
                remotes.Generator.RepairEvent:FireServer(currentRepairPoint, false, nil, HttpService:GenerateGUID(false), player and player.Character)
            end
        end)
        currentRepairPoint = nil
    end

    -- 3. Cancel background threads
    local threadList = {
        autoFarmSpeedThread,
        autoMountAnehThread,
        autoMountBotakThread,
        autoFarmGemsThread,
        autoFarmXPThread,
        autoRebirthThread,
        autoFishingThread,
        autoEggThread
    }
    for _, th in ipairs(threadList) do
        if th and typeof(th) == "thread" then
            pcall(function() task.cancel(th) end)
        end
    end

    -- 4. Disconnect connections
    if killerAimConn then
        pcall(function() killerAimConn:Disconnect() end)
        killerAimConn = nil
    end
    if charAddedConn then
        pcall(function() charAddedConn:Disconnect() end)
        charAddedConn = nil
    end

    -- 5. Clean up ESP visuals
    if cleanKillerESP then pcall(cleanKillerESP) end
    if cleanGenESP then pcall(cleanGenESP) end
    if cleanSurvivorESP then pcall(cleanSurvivorESP) end

    -- 6. Destroy WindUI Window & ScreenGuis
    pcall(function()
        if Window and not Window.Destroyed and typeof(Window.Destroy) == "function" then
            Window:Destroy()
        end
    end)
    pcall(function()
        if WindUI then
            WindUI.Window = nil
        end
    end)
    pcall(function()
        local coreGui = game:GetService("CoreGui")
        local playerGui = player and player:FindFirstChild("PlayerGui")
        for _, parent in ipairs({coreGui, playerGui}) do
            if parent then
                for _, child in ipairs(parent:GetChildren()) do
                    if child.Name:lower():find("windui") or child.Name:lower():find("riel") then
                        pcall(function() child:Destroy() end)
                    end
                end
            end
        end
    end)

    print("[Riel Private] Script stopped and UI closed successfully.")
end

-- ============================================================
-- BULLETPROOF WINDUI LOADER (MONTH 10 ORIGINAL ENGINE)
-- ============================================================
local WindUI = nil

-- Clean up any existing WindUI Window singleton if already loaded
if getgenv and getgenv().WindUI then
    pcall(function()
        if getgenv().WindUI.Window and typeof(getgenv().WindUI.Window.Destroy) == "function" then
            getgenv().WindUI.Window:Destroy()
        end
    end)
    getgenv().WindUI.Window = nil
    WindUI = getgenv().WindUI
elseif _G.WindUI then
    pcall(function()
        if _G.WindUI.Window and typeof(_G.WindUI.Window.Destroy) == "function" then
            _G.WindUI.Window:Destroy()
        end
    end)
    _G.WindUI.Window = nil
    WindUI = _G.WindUI
end

if not WindUI or type(WindUI.CreateWindow) ~= "function" then
    -- Try local file first (if executor supports readfile)
    pcall(function()
        if readfile and isfile and isfile("windui.lua") then
            local raw = readfile("windui.lua")
            if raw and #raw > 100000 then
                local fn = loadstring(raw)
                if fn then
                    local lib = fn()
                    if lib and type(lib.CreateWindow) == "function" then
                        WindUI = lib
                        print("[Riel Private] WindUI loaded from local file windui.lua")
                    end
                end
            end
        end
    end)
end

if not WindUI or type(WindUI.CreateWindow) ~= "function" then
    local urls = {
        "https://raw.githubusercontent.com/rionmaulanaa2/Riel-Private/main/windui.lua?v=" .. tick(),
        "https://raw.githubusercontent.com/rionmaulanaa2/Riel-Private/main/windui.lua",
        "https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua",
        "https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"
    }

    for _, url in ipairs(urls) do
        local ok_http, raw = pcall(function()
            return game:HttpGet(url, true)
        end)
        if ok_http and raw and #raw > 100000 then
            -- Sanitize any Luau-specific compound assignment operators for 100% pure Lua 5.1 compatibility
            raw = raw:gsub("ao%.Camera%.CFrame%+=ao%.Camera%.CFrame%.LookVector%*aw", "ao.Camera.CFrame=ao.Camera.CFrame+(ao.Camera.CFrame.LookVector*aw)")
            raw = raw:gsub("ao%.Camera%.CFrame%+=ao%.Camera%.CFrame%.LookVector%*aA", "ao.Camera.CFrame=ao.Camera.CFrame+(ao.Camera.CFrame.LookVector*aA)")
            -- Sanitize Luau type annotations on the fly for pure Lua 5.1 / Delta compatibility
            raw = raw:gsub("type%s+ConfigType__DARKLUA_TYPE_a%s*=%s*%{[^%}]*%}", "")
            raw = raw:gsub("function%s+am%.GetGlassFrame%s*%(%s*an%s*,%s*ao%s*:%s*number%s*%)%s*:%s*%([^%)]*%)", "function am.GetGlassFrame(an,ao)")
            raw = raw:gsub("local%s+aq%s*:%s*number", "local aq")
            raw = raw:gsub("function%s*%(%s*aA%s*:%s*InputObject%s*%)", "function(aA)")
            raw = raw:gsub("function%s+al%.New%s*%(%s*am%s*,%s*an%s*:%s*ConfigType__DARKLUA_TYPE_a%s*%)", "function al.New(am,an)")
            raw = raw:gsub("function%s+aw%.Topbar%.Button%s*%(%s*z%s*,%s*A%s*:%s*%{[^%}]*%}%s*%)", "function aw.Topbar.Button(z,A)")

            local ok_load, fn = pcall(function()
                return loadstring(raw)
            end)
            if ok_load and fn then
                local ok_run, lib = pcall(fn)
                if ok_run and lib and type(lib.CreateWindow) == "function" then
                    WindUI = lib
                    print("[Riel Private] WindUI successfully loaded from: " .. url:sub(1, 40) .. "...")
                    break
                end
            end
        end
    end
end

if not WindUI or type(WindUI.CreateWindow) ~= "function" then
    warn("[Riel Private] CRITICAL: Could not load WindUI! Script cannot initialize UI.")
    return
end

-- Cache globally
if getgenv then getgenv().WindUI = WindUI end
_G.WindUI = WindUI

-- Guarantee previous window instance is cleared
pcall(function()
    if WindUI.Window and typeof(WindUI.Window.Destroy) == "function" then
        WindUI.Window:Destroy()
    end
end)
WindUI.Window = nil

-- ============================================================
-- CREATE MAIN WINDOW (MONTH 10 ORIGINAL THEME & OPEN BUTTON)
-- ============================================================
local winOk, winResult = pcall(function()
    return WindUI:CreateWindow({
        Title = " Riel Private",
        Icon = "shield",
        Size = UDim2.fromOffset(500, 450),
        Transparent = false,
        Theme = "Dark",
        Folder = "RielPrivate",
        OpenButton = {
            Enabled = true,
            OnlyMobile = false,
            Title = "Riel Private",
            Icon = "shield",
            Position = UDim2.new(0, 20, 0.45, 0),
            Draggable = true,
            OnlyIcon = false
        }
    })
end)

if not winOk or not winResult then
    warn("[Riel Private] CreateWindow error: " .. tostring(winResult))
    -- Fallback simple window
    winOk, winResult = pcall(function()
        return WindUI:CreateWindow({
            Title = " Riel Private",
            Size = UDim2.fromOffset(500, 450),
            Transparent = false,
            Theme = "Dark"
        })
    end)
end

if not winResult then
    warn("[Riel Private] CRITICAL: Failed to create Window.")
    return
end

Window = winResult

-- Ensure mobile floating OpenButton is active
Window.IsPC = false
Window.IsOpenButtonEnabled = true

-- Ensure Window is OPEN and visible on start
pcall(function()
    if Window and typeof(Window.Open) == "function" then
        Window:Open()
    end
end)

-- Connect Window Destroy Event
pcall(function()
    Window:OnDestroy(function()
        stopScript()
    end)
end)

-- Topbar direct close button hook
task.spawn(function()
    task.wait(0.2)
    pcall(function()
        if Window and Window.TopBarButtons then
            for _, btn in pairs(Window.TopBarButtons) do
                if btn and btn.Name == "Close" and btn.Object then
                    local b = btn.Object:FindFirstChildWhichIsA("GuiButton", true)
                    if b then
                        b.MouseButton1Click:Connect(function()
                            stopScript()
                        end)
                    end
                end
            end
        end
    end)
end)

WindUI:Notify({
    Title = "Script Loaded",
    Content = "Riel Private by Noirrr!",
    Duration = 5
})

do
local MainTab = Window:Tab({
    Title = "Main",
    Icon = "home"
})

local MainSection = MainTab:Section({
    Title = "Auto Farm"
})

MainSection:Button({
    Title = "❌ Close UI & Stop Script",
    Description = "Safely close the UI and terminate all running features & loops",
    Callback = function()
        stopScript()
    end
})

MainSection:Button({
    Title = "Private Server",
    Description = "Move to Private Server",
    Callback = function()
        loadstring(game:HttpGet("https://pastebin.com/raw/SKSDCPhJ"))()
        WindUI:Notify({
            Title = "Private Server",
            Content = "Moving",
            Duration = 2
        })
    end
})

MainSection:Button({
    Title = "Private Server V2",
    Description = "Move to Private Server",
    Callback = function()
        loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-Free-Private-Server-Universal-Joshzz-56303"))()
        WindUI:Notify({
            Title = "Private Server",
            Content = "Moving",
            Duration = 2
        })
    end
})


MainSection:Button({
    Title = "Show Stats",
    Description = "Display your Money, Rebirths, Summits, etc.",
    Callback = function()
        local player = game.Players.LocalPlayer
        local leaderstats = player:FindFirstChild("leaderstats")
        local content = ""

        if leaderstats then
            for _, stat in pairs(leaderstats:GetChildren()) do
                content = content .. stat.Name .. ": " .. tostring(stat.Value) .. "\n"
            end
        else
            content = "No leaderstats found for this player."
        end

        WindUI:Notify({
            Title = "📊 Your Stats",
            Content = content,
            Duration = 6
        })
    end
})

MainSection:Button({
    Title = "Toggle Complete Void",
    Description = "Hide everything except your character (terrain, map, lighting, effects gone)",
    Callback = function()
        local Players = game:GetService("Players")
        local Workspace = game:GetService("Workspace")
        local Lighting = game:GetService("Lighting")
        local LocalPlayer = Players.LocalPlayer

        _G.VoidMode = not _G.VoidMode
        _G._ModifiedObjects = _G._ModifiedObjects or {}

        local function markModified(inst, key, val)
            if not _G._ModifiedObjects[inst] then _G._ModifiedObjects[inst] = {} end
            _G._ModifiedObjects[inst][key] = val
        end

        local function hideAll()
            -- Hide terrain completely
            if Workspace:FindFirstChildOfClass("Terrain") then
                local terrain = Workspace:FindFirstChildOfClass("Terrain")
                pcall(function() terrain:Clear() end)
                pcall(function() terrain.Transparency = 1 end)
            end

            -- Hide all parts except character
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("BasePart") and not obj:IsDescendantOf(LocalPlayer.Character) then
                    markModified(obj, "Transparency", obj.Transparency)
                    markModified(obj, "CanCollide", obj.CanCollide)
                    obj.Transparency = 1
                    obj.CanCollide = false
                elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") then
                    markModified(obj, "Enabled", obj.Enabled)
                    obj.Enabled = false
                elseif obj:IsA("Decal") or obj:IsA("Texture") then
                    markModified(obj, "Transparency", obj.Transparency)
                    obj.Transparency = 1
                elseif obj:IsA("Sound") then
                    markModified(obj, "Volume", obj.Volume)
                    obj.Volume = 0
                    obj:Stop()
                end
            end

            -- Clear environment visuals
            for _, eff in ipairs(Lighting:GetChildren()) do
                markModified(eff, "Parent", eff.Parent)
                eff.Parent = nil
            end

            -- Darken lighting to void black
            Lighting.Brightness = 0
            Lighting.ClockTime = 0
            Lighting.FogEnd = 0
            Lighting.Ambient = Color3.new(0,0,0)

            -- Listen for new parts and auto-hide
            if not _G._VoidConn then
                _G._VoidConn = Workspace.DescendantAdded:Connect(function(d)
                    task.defer(function()
                        if _G.VoidMode and d and d.Parent then
                            pcall(function()
                                if d:IsA("BasePart") and not d:IsDescendantOf(LocalPlayer.Character) then
                                    d.Transparency = 1
                                    d.CanCollide = false
                                end
                            end)
                        end
                    end)
                end)
            end
        end

        local function restoreAll()
            if _G._VoidConn then
                _G._VoidConn:Disconnect()
                _G._VoidConn = nil
            end

            for inst, props in pairs(_G._ModifiedObjects) do
                if inst and inst.Parent then
                    for k, v in pairs(props) do
                        pcall(function() inst[k] = v end)
                    end
                end
            end

            _G._ModifiedObjects = {}
            -- Restore basic lighting
            Lighting.Brightness = 2
            Lighting.FogEnd = 100000
            Lighting.Ambient = Color3.new(1,1,1)
        end

        if _G.VoidMode then
            hideAll()
            WindUI:Notify({
                Title = "Process",
                Content = "☠️ Entered complete void mode",
                Duration = 3
            })
        else
            restoreAll()
            WindUI:Notify({
                Title = "Process",
                Content = "🌍 World restored from void",
                Duration = 3
            })
        end
    end
})




MainSection:Toggle({
    Title = "Auto Summit Mount Limau",
    Description = "Teleports to Summit repeatedly (shows loop count)",
    Default = false,
    Callback = function(v)
        if autoFarmSpeedThread then
            task.cancel(autoFarmSpeedThread)
            autoFarmSpeedThread = nil
        end

        if v then
            local loopCount = 0
            WindUI:Notify({
                Title = "Auto Summit Mount Limau",
                Content = "Started teleport loop!",
                Duration = 3
            })

            autoFarmSpeedThread = task.spawn(function()
                while task.wait(2) do
                    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    pcall(function()
                        player.Character.HumanoidRootPart.CFrame = CFrame.new(1527, 2589, -987)
						local player = game.Players.LocalPlayer
						local leaderstats = player:FindFirstChild("leaderstats")
						local content = ""

						if leaderstats then
							for _, stat in pairs(leaderstats:GetChildren()) do
								content = content .. stat.Name .. ": " .. tostring(stat.Value) .. "\n"
							end
						else
							content = "No leaderstats found for this player."
						end
                        loopCount = (loopCount or 0) + 1
                        if loopCount % 20 == 0 then -- show every 20 loops to avoid spam
                            WindUI:Notify({
                                Title = "📊 Your Stats",
                                Content = content,
                                Duration = 2
                            })
                        end
                    end)
                    end
                end
            end)
        else
            WindUI:Notify({
                Title = "Auto Summit Mount Limau",
                Content = "Teleport loop stopped!",
                Duration = 3
            })
        end
    end
})

MainSection:Toggle({
    Title = "Auto Summit Mount Aneh",
    Description = "Teleports based on current checkpoint stat (loops automatically)",
    Default = false,
    Callback = function(v)
        if autoMountAnehThread then
            task.cancel(autoMountAnehThread)
            autoMountAnehThread = nil
        end

        if v then
            local player = game.Players.LocalPlayer
            local loopCount = 0

            local teleports = {
                [0] = CFrame.new(-76, 527, 936),   -- checkpoint 0
                [1] = CFrame.new(-91, 526, 892),   -- checkpoint 1
                [2] = CFrame.new(-22, 597, 505),   -- checkpoint 2
                [3] = CFrame.new(473, 604, 444),   -- checkpoint 3
                [4] = CFrame.new(1170, 649, 668),  -- checkpoint 4
                [5] = CFrame.new(2124, 790, 1024), -- checkpoint 5
                [6] = CFrame.new(2727, 917, 1194), -- checkpoint 6
                [7] = CFrame.new(3449, 1312, 1772),-- checkpoint 7
                [8] = CFrame.new(3162, 1615, 2780) -- finish
            }

            local maxCheckpoint = 8

            WindUI:Notify({
                Title = "Auto Summit Mount Aneh",
                Content = "Started teleport loop!",
                Duration = 3
            })

            autoMountAnehThread = task.spawn(function()
                while task.wait(2) do
                    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    pcall(function()
                        local hrp = player.Character.HumanoidRootPart
                        local leaderstats = player:FindFirstChild("leaderstats")

                        local currentCheckpoint = 0

                        -- 🧭 Read current checkpoint stat safely
                        if leaderstats then
                            local checkpointStat = leaderstats:FindFirstChild("checkpoint") or leaderstats:FindFirstChild("Checkpoint")
                            if checkpointStat then
                                currentCheckpoint = tonumber(checkpointStat.Value) or 0
                            end
                        end

                        -- 🧩 Calculate next checkpoint
                        local nextCheckpoint = currentCheckpoint + 1
                        if nextCheckpoint > maxCheckpoint then
                            nextCheckpoint = 0
                        end

                        -- 🚀 Teleport to next checkpoint
                        if teleports[nextCheckpoint] then
                            hrp.CFrame = teleports[nextCheckpoint]
                            
                        else
                            WindUI:Notify({
                                Title = "Error",
                                Content = "Invalid checkpoint index: " .. tostring(nextCheckpoint),
                                Duration = 2
                            })
                        end

                        loopCount = (loopCount or 0) + 1

                        -- 📊 Show stats every 20 loops
                        if loopCount % 20 == 0 then
                            local content = ""
                            if leaderstats then
                                for _, stat in pairs(leaderstats:GetChildren()) do
                                    content = content .. stat.Name .. ": " .. tostring(stat.Value) .. "\n"
                                end
                            else
                                content = "No leaderstats found."
                            end
                            WindUI:Notify({
                                Title = "📊 Your Stats",
                                Content = content,
                                Duration = 3
                            })
                        end
                    end)
                    end
                end
            end)
        else
            WindUI:Notify({
                Title = "Auto Summit Mount Aneh",
                Content = "Teleport loop stopped!",
                Duration = 3
            })
        end
    end
})

MainSection:Toggle({
    Title = "Auto Summit Mount Botak",
    Description = "Teleports to the next Stage based on your current Stage stat",
    Default = false,
    Callback = function(v)
        if autoMountBotakThread then
            task.cancel(autoMountBotakThread)
            autoMountBotakThread = nil
        end

        if v then
            local player = game.Players.LocalPlayer
            local loopCount = 0

            -- Stage 1–17 coordinates
            local teleports = {
                [1]  = CFrame.new(456, 315, -629),
                [2]  = CFrame.new(625, 414, -94),
                [3]  = CFrame.new(584, 463, 249),
                [4]  = CFrame.new(557, 504, 465),
                [5]  = CFrame.new(287, 620, 818),
                [6]  = CFrame.new(198, 777, 582),
                [7]  = CFrame.new(50, 1033, -399),
                [8]  = CFrame.new(-243, 1176, -785),
                [9]  = CFrame.new(-117, 1185, -1119),
                [10] = CFrame.new(203, 1285, -1510),
                [11] = CFrame.new(733, 1398, -1596),
                [12] = CFrame.new(739, 1345, -835),
                [13] = CFrame.new(758, 1309, -360),
                [14] = CFrame.new(1109, 1643, 381),
                [15] = CFrame.new(1438, 1747, 526),
                [16] = CFrame.new(1731, 1754, 472),
                [17] = CFrame.new(1913, 2057, -345)
            }

            local maxStage = 17

            WindUI:Notify({
                Title = "Auto Summit Mount Botak",
                Content = "Started teleport loop (teleporting to next Stage)...",
                Duration = 3
            })

            autoMountBotakThread = task.spawn(function()
                while task.wait(2) do
                    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    pcall(function()
                        local hrp = player.Character.HumanoidRootPart
                        local leaderstats = player:FindFirstChild("leaderstats")
                        if not leaderstats then return end

                        local stageStat = leaderstats:FindFirstChild("Stage")
                        if not stageStat then return end

                        local currentStage = tonumber(stageStat.Value) or 0

                        -- Calculate next stage (wrap to 1 after 17)
                        local nextStage = currentStage + 1
                        if nextStage > maxStage then
                            nextStage = 1
                        end

                        -- Teleport to next stage
                        local target = teleports[nextStage]
                        if target then
                            hrp.CFrame = target
                            WindUI:Notify({
                                Title = "Teleporting...",
                                Content = "Moved to Stage " .. tostring(nextStage),
                                Duration = 2
                            })
                        else
                            WindUI:Notify({
                                Title = "Error",
                                Content = "No coordinate for Stage " .. tostring(nextStage),
                                Duration = 2
                            })
                        end

                        loopCount = (loopCount or 0) + 1

                        -- Show stats every 20 loops
                        if loopCount % 20 == 0 then
                            local content = ""
                            for _, stat in pairs(leaderstats:GetChildren()) do
                                content = content .. stat.Name .. ": " .. tostring(stat.Value) .. "\n"
                            end
                            WindUI:Notify({
                                Title = "📊 Your Stats",
                                Content = content,
                                Duration = 3
                            })
                        end
                    end)
                    end
                end
            end)
        else
            WindUI:Notify({
                Title = "Auto Summit Mount Botak",
                Content = "Teleport loop stopped!",
                Duration = 3
            })
        end
    end
})






MainSection:Toggle({
    Title = "Auto Farm Gems",
    Description = "Collects Gems",
    Default = false,
    Callback = function(v)
        if autoFarmGemsThread then
            task.cancel(autoFarmGemsThread)
            autoFarmGemsThread = nil
        end
        
        if v then
            autoFarmGemsThread = task.spawn(function()
                while task.wait(0.01) do
                    pcall(function()
                        local orbEvent = ReplicatedStorage.rEvents.orbEvent
                        orbEvent:FireServer("collectOrb", "Gem", "City")
                    end)
                end
            end)
        end
    end
})

MainSection:Toggle({
    Title = "Auto Farm XP-Level",
    Description = "Collects Yellow Orbs",
    Default = false,
    Callback = function(v)
        if autoFarmXPThread then
            task.cancel(autoFarmXPThread)
            autoFarmXPThread = nil
        end
        
        if v then
            autoFarmXPThread = task.spawn(function()
                while task.wait(0.01) do
                    pcall(function()
                        local orbEvent = ReplicatedStorage.rEvents.orbEvent
                        orbEvent:FireServer("collectOrb", "Yellow Orb", "City")
                    end)
                end
            end)
        end
    end
})

MainSection:Toggle({
    Title = "Auto Rebirth",
    Description = "Auto Rebirth",
    Default = false,
    Callback = function(v)
        if autoRebirthThread then
            pcall(function()
                task.cancel(autoRebirthThread)
            end)
            autoRebirthThread = nil
        end
        
        if v then
            autoRebirthThread = task.spawn(function()
                while task.wait(0.01) do
                    if not autoRebirthThread then break end
                    pcall(function()
                        local rebirthEvent = ReplicatedStorage.rEvents.rebirthEvent
                        rebirthEvent:FireServer("rebirthRequest")
                    end)
                end
            end)
        end
    end
})


end

do
local FishTab = Window:Tab({
    Title = "Fishing",
    Icon = "home"
})


local FishSection = FishTab:Section({
    Title = "Menu"
})

-- Auto Sell buttons
FishSection:Button({
    Title = "Sell All",
    Description = "Sell all fish",
    Callback = function()
        pcall(function()
				local RFSellAllItems = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net["RF/SellAllItems"]
                RFSellAllItems:InvokeServer()
            end)
        WindUI:Notify({
            Title = "Process",
            Content = "Selling All Fish",
            Duration = 2
        })
    end
})




local delayBetweenSteps = 2 -- adjust delay between fishing steps
-- autoFishingThread declared at top level

FishSection:Toggle({
    Title = "Auto Fishing",
    Description = "Automatically perform fishing steps in loop",
    Default = false,
    Callback = function(v)
        -- fetch remotes once
        local Net = ReplicatedStorage:WaitForChild("Packages")
            :WaitForChild("_Index")
            :WaitForChild("sleitnick_net@0.2.0")
            :WaitForChild("net")

        local RF_ChargeFishingRod = Net:WaitForChild("RF/ChargeFishingRod")
        local RF_RequestFishingMinigameStarted = Net:WaitForChild("RF/RequestFishingMinigameStarted")
        local RE_FishingCompleted = Net:WaitForChild("RE/FishingCompleted")

        -- stop previous thread if toggle turned off
        if autoFishingThread then
            task.cancel(autoFishingThread)
            autoFishingThread = nil
        end

        if v then
            autoFishingThread = task.spawn(function()
                while true do
                    pcall(function()
                        -- ✅ Step 1: Charge Fishing Rod
						local args1 = {1759600647.429451}
						RF_ChargeFishingRod:InvokeServer()

                        task.wait(0.27)

                        -- ✅ Step 2: Start Fishing Minigame
                        local args2 = {-1.233184814453125, 0.9544006849697018,tick()}
						RF_RequestFishingMinigameStarted:InvokeServer(unpack(args2))

                        task.wait(delayBetweenSteps)

                        -- ✅ Step 3: Complete Fishing
                        RE_FishingCompleted:FireServer()

						

                       
                    end)

                    if not autoFishingThread then break end
                end
            end)

            WindUI:Notify({
                Title = "Auto Fishing",
                Content = "🎣 Auto fishing started!",
                Duration = 2
            })
        else
            WindUI:Notify({
                Title = "Auto Fishing",
                Content = "🛑 Auto fishing stopped.",
                Duration = 2
            })
        end
    end
})

FishSection:Button({
    Title = "🕵️ Sniff Al Remotes 2 (Fishing)",
    Description = "Log all remote calls while fishing to find the right one.",
    Callback = function()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local HttpService = game:GetService("HttpService")
        local Players = game:GetService("Players")
        local LocalPlayer = Players.LocalPlayer

        WindUI:Notify({
            Title = "🕵️ Remote Sniffer",
            Content = "Started sniffing! Try charging and throwing your rod.",
            Duration = 5
        })

        -- Safe event connect
        local function safeConnect(remote)
            if remote:IsA("RemoteEvent") then
                remote.OnClientEvent:Connect(function(...)
                    WindUI:Notify({
                        Title = "📡 RemoteEvent Triggered",
                        Content = remote:GetFullName() .. "\nArgs: " .. HttpService:JSONEncode({...}),
                        Duration = 4
                    })
                end)
            elseif remote:IsA("RemoteFunction") then
                local old = remote.InvokeServer
                remote.InvokeServer = function(self, ...)
                    WindUI:Notify({
                        Title = "⚙️ RemoteFunction Invoked",
                        Content = self:GetFullName() .. "\nArgs: " .. HttpService:JSONEncode({...}),
                        Duration = 4
                    })
                    return old(self, ...)
                end
            end
        end

        -- Hook every remote in ReplicatedStorage
        for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
            if v:IsA("RemoteEvent") or v:IsA("RemoteFunction") then
                safeConnect(v)
            end
        end

        WindUI:Notify({
            Title = "✅ Remote Sniffer Active",
            Content = "Sniffing all remotes under ReplicatedStorage...",
            Duration = 5
        })
    end
})



FishSection:Button({
    Title = "🎣 Auto Amazing Charge",
    Description = "Automatically casts when charge ≥ 0.9 for guaranteed Amazing throws.",
    Callback = function()
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local RunService = game:GetService("RunService")

        -- ✅ Load required modules
        local Net = ReplicatedStorage:WaitForChild("Packages")
            :WaitForChild("_Index")
            :WaitForChild("sleitnick_net@0.2.0")
            :WaitForChild("net")

        local RF_RequestFishingMinigameStarted = Net:WaitForChild("RF/RequestFishingMinigameStarted")
        local FishingController = require(ReplicatedStorage.Controllers.FishingController)

        -- 🧠 State
        local autoAmazing = not _G.AutoAmazingActive
        _G.AutoAmazingActive = autoAmazing

        if not autoAmazing then
            WindUI:Notify({
                Title = "🎣 Auto Amazing Charge",
                Content = "Stopped auto cast.",
                Duration = 3
            })
            return
        end

        WindUI:Notify({
            Title = "🎣 Auto Amazing Charge",
            Content = "Started! Will cast automatically when charge ≥ 0.9",
            Duration = 4
        })

        local debounce = false

        -- Try to hook into UpdateChargeState
        local oldUpdate = FishingController.UpdateChargeState
        FishingController.UpdateChargeState = function(self, dt, ...)
            local result = oldUpdate(self, dt, ...)

            if not _G.AutoAmazingActive then
                return result
            end

            local power = 0
            pcall(function()
                power = self:_getPower() or 0
            end)

            if not debounce and power >= 0.9 then
                debounce = true

                WindUI:Notify({
                    Title = "🌟 Auto Cast Triggered!",
                    Content = string.format("Power: %.2f — Casting now!", power),
                    Duration = 2
                })

                -- Call the remote to cast
                pcall(function()
                    local args2 = {-1.233184814453125, 0.9544006849697018, tick()}
                    RF_RequestFishingMinigameStarted:InvokeServer(unpack(args2))
                end)

                task.delay(2, function()
                    debounce = false
                end)
            end

            return result
        end
    end
})





FishSection:Button({
    Title = "Add Friend All",
    Description = "Add all players in the server as friends",
    Callback = function()
        local Players = game:GetService("Players")
        local LocalPlayer = Players.LocalPlayer

        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                pcall(function()
                    LocalPlayer:RequestFriendship(player)
                end)
            end
        end

        WindUI:Notify({
            Title = "Process Complete",
            Content = "Sent friend requests to all players!",
            Duration = 2
        })
    end
})

FishSection:Button({
    Title = "Teleport Sisipus",
    Description = "Teleport Sisipus",
    Callback = function()
        local player = game:GetService("Players").LocalPlayer
        if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            player.Character.HumanoidRootPart.CFrame = CFrame.new(-3697,-135,-1009)
            WindUI:Notify({
                Title = "Process Complete",
                Content = "Teleported to Sisipus",
                Duration = 2
            })
        else
            WindUI:Notify({
                Title = "Error",
                Content = "Character not found!",
                Duration = 2
            })
        end
    end
})





end

do
local WeatherTab = Window:Tab({
    Title = "Weather",
    Icon = "egg"
})

local WeatherSection = WeatherTab:Section({
    Title = "Weather Selection"
})

-- Weather buttons
WeatherSection:Button({
    Title = "Storm",
    Description = "Select Storm",
    Callback = function()
        local RFPurchaseWeatherEvent = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net["RF/PurchaseWeatherEvent"]
		weather = "Storm"
        RFPurchaseWeatherEvent:InvokeServer(weather)
        WindUI:Notify({
            Title = "Storm",
            Content = "Storm",
            Duration = 2
        })
    end
})

WeatherSection:Button({
    Title = "Cloudy",
    Description = "Select Cloudy",
    Callback = function()
        local RFPurchaseWeatherEvent = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net["RF/PurchaseWeatherEvent"]
		weather = "Cloudy"
        RFPurchaseWeatherEvent:InvokeServer(weather)
        WindUI:Notify({
            Title = "Cloudy",
            Content = "Cloudy",
            Duration = 2
        })
    end
})

WeatherSection:Button({
    Title = "Wind",
    Description = "Select Wind",
    Callback = function()
        local RFPurchaseWeatherEvent = ReplicatedStorage.Packages._Index["sleitnick_net@0.2.0"].net["RF/PurchaseWeatherEvent"]
		weather = "Wind"
        RFPurchaseWeatherEvent:InvokeServer(weather)
        WindUI:Notify({
            Title = "Wind",
            Content = "Wind",
            Duration = 2
        })
    end
})

WeatherSection:Button({
    Title = "Yellow Crystal",
    Description = "Select Yellow Crystal",
    Callback = function()
        selectedEgg = "Yellow Crystal"
        WindUI:Notify({
            Title = "Egg Selected",
            Content = "Selected: Yellow Crystal",
            Duration = 2
        })
    end
})

WeatherSection:Button({
    Title = "Lightning Crystal",
    Description = "Select Lightning Crystal",
    Callback = function()
        selectedEgg = "Lightning Crystal"
        WindUI:Notify({
            Title = "Egg Selected",
            Content = "Selected: Lightning Crystal",
            Duration = 2
        })
    end
})

WeatherSection:Button({
    Title = "Snow Crystal",
    Description = "Select Snow Crystal",
    Callback = function()
        selectedEgg = "Snow Crystal"
        WindUI:Notify({
            Title = "Egg Selected",
            Content = "Selected: Snow Crystal",
            Duration = 2
        })
    end
})

WeatherSection:Button({
    Title = "Lava Crystal",
    Description = "Select Lava Crystal",
    Callback = function()
        selectedEgg = "Lava Crystal"
        WindUI:Notify({
            Title = "Egg Selected",
            Content = "Selected: Lava Crystal",
            Duration = 2
        })
    end
})

WeatherSection:Button({
    Title = "Inferno Crystal",
    Description = "Select Inferno Crystal",
    Callback = function()
        selectedEgg = "Inferno Crystal"
        WindUI:Notify({
            Title = "Egg Selected",
            Content = "Selected: Inferno Crystal",
            Duration = 2
        })
    end
})

WeatherSection:Button({
    Title = "Electro Legends Crystal",
    Description = "Select Electro Legends Crystal",
    Callback = function()
        selectedEgg = "Electro Legends Crystal"
        WindUI:Notify({
            Title = "Egg Selected",
            Content = "Selected: Electro Legends Crystal",
            Duration = 2
        })
    end
})

WeatherSection:Button({
    Title = "Jungle Crystal",
    Description = "Select Jungle Crystal",
    Callback = function()
        selectedEgg = "Jungle Crystal"
        WindUI:Notify({
            Title = "Egg Selected",
            Content = "Selected: Jungle Crystal",
            Duration = 2
        })
    end
})

WeatherSection:Toggle({
    Title = "Auto Buy Selected Egg",
    Description = "Currently: " .. selectedEgg,
    Default = false,
    Callback = function(v)
        if autoEggThread then
            pcall(function()
                task.cancel(autoEggThread)
            end)
            autoEggThread = nil
        end
        
        if v then
            autoEggThread = task.spawn(function()
                while task.wait(0.01) do
                    if not autoEggThread then break end
                    pcall(function()
                        local openCrystalRemote = ReplicatedStorage.rEvents.openCrystalRemote
                        openCrystalRemote:InvokeServer("openCrystal", selectedEgg)
                    end)
                end
            end)
        end
    end
})


end

do
local MovementTab = Window:Tab({
    Title = "Movement",
    Icon = "wind"
})

local MovementSection = MovementTab:Section({
    Title = "Flight"
})

local flySpeed = 50
local flyControl = {f = 0, b = 0, l = 0, r = 0}
local flyConnection
local bodyVelocity
local bodyGyro

local function startFly()
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
    bodyVelocity.Parent = humanoidRootPart
    
    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    bodyGyro.CFrame = humanoidRootPart.CFrame
    bodyGyro.Parent = humanoidRootPart
    
    flyConnection = RunService.Heartbeat:Connect(function()
        if not flyEnabled then return end
        
        local camera = workspace.CurrentCamera
        local moveDirection = Vector3.new(
            flyControl.r - flyControl.l,
            0,
            flyControl.f - flyControl.b
        )
        
        if moveDirection:Dot(moveDirection) > 0 then
            moveDirection = moveDirection.Unit
        end
        
        local velocity = (camera.CFrame.RightVector * moveDirection.X + camera.CFrame.LookVector * moveDirection.Z) * flySpeed
        bodyVelocity.Velocity = velocity
        bodyGyro.CFrame = camera.CFrame
    end)
end

stopFly = function()
    if bodyVelocity then bodyVelocity:Destroy() bodyVelocity = nil end
    if bodyGyro then bodyGyro:Destroy() bodyGyro = nil end
    if flyConnection then flyConnection:Disconnect() flyConnection = nil end
    flyControl = {f = 0, b = 0, l = 0, r = 0}
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or not flyEnabled then return end
    
    if input.KeyCode == Enum.KeyCode.W then
        flyControl.f = 1
    elseif input.KeyCode == Enum.KeyCode.S then
        flyControl.b = 1
    elseif input.KeyCode == Enum.KeyCode.A then
        flyControl.l = 1
    elseif input.KeyCode == Enum.KeyCode.D then
        flyControl.r = 1
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if not flyEnabled then return end
    
    if input.KeyCode == Enum.KeyCode.W then
        flyControl.f = 0
    elseif input.KeyCode == Enum.KeyCode.S then
        flyControl.b = 0
    elseif input.KeyCode == Enum.KeyCode.A then
        flyControl.l = 0
    elseif input.KeyCode == Enum.KeyCode.D then
        flyControl.r = 0
    end
end)

MovementSection:Toggle({
    Title = "Fly",
    Description = "Enable flight with WASD",
    Default = false,
    Callback = function(v)
        flyEnabled = v
        if flyEnabled then
            startFly()
        else
            stopFly()
        end
    end
})

local noFallEnabled = false
local fallConnection

local function enableNoFall()
    if fallConnection then fallConnection:Disconnect() end
    if not humanoid then return end

    fallConnection = humanoid.StateChanged:Connect(function(_, newState)
        if noFallEnabled and (newState == Enum.HumanoidStateType.Freefall or newState == Enum.HumanoidStateType.Landed) then
            -- Stop any possible fall damage
            -- task.wait(0.1)
            -- humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Freefall, false)
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Landed, false)
        end
    end)
end

local function disableNoFall()
    if fallConnection then
        fallConnection:Disconnect()
        fallConnection = nil
    end
end

MovementSection:Toggle({
    Title = "No Fall Damage",
    Description = "Prevents taking damage after falling",
    Default = false,
    Callback = function(v)
        noFallEnabled = v
        if v then
            enableNoFall()
            WindUI:Notify({
                Title = "No Fall Damage",
                Content = "No fall damage enabled!",
                Duration = 3
            })
        else
            disableNoFall()
            WindUI:Notify({
                Title = "No Fall Damage",
                Content = "No fall damage disabled!",
                Duration = 3
            })
        end
    end
})


end

do
local DeveloperTab = Window:Tab({
    Title = "Developer",
    Icon = "code"
})

local DeveloperSection = DeveloperTab:Section({
    Title = "Game Code Extractor"
})

local function runCodeDump(copyClipboard)
    local decompileFunc = decompile or (getscriptbytecode and decompile) or nil
    local writeFileFunc = writefile or nil
    local appendFileFunc = appendfile or nil
    local setClipboardFunc = setclipboard or toclipboard or nil
    local MarketplaceService = game:GetService("MarketplaceService")

    local gameName = "Game_" .. tostring(game.PlaceId)
    pcall(function()
        local info = MarketplaceService:GetProductInfo(game.PlaceId)
        if info and info.Name then
            gameName = info.Name:gsub("[^%w%s%-_]", "")
        end
    end)

    local sanitized = gameName:gsub("%s+", "_")
    local fileName = string.format("%s_%d_code_dump.lua", sanitized, game.PlaceId)

    WindUI:Notify({
        Title = "Code Dumper",
        Content = "Scanning game for scripts...",
        Duration = 3
    })

    local targetContainers = {
        ReplicatedStorage,
        game:GetService("ReplicatedFirst"),
        game:GetService("StarterGui"),
        game:GetService("StarterPlayer"),
        game:GetService("Lighting"),
        workspace
    }

    if player then
        local ps = player:FindFirstChildOfClass("PlayerScripts") or player:FindFirstChild("PlayerScripts")
        if ps then table.insert(targetContainers, ps) end
        local pg = player:FindFirstChildOfClass("PlayerGui") or player:FindFirstChild("PlayerGui")
        if pg then table.insert(targetContainers, pg) end
        local bp = player:FindFirstChildOfClass("Backpack") or player:FindFirstChild("Backpack")
        if bp then table.insert(targetContainers, bp) end
        if player.Character then table.insert(targetContainers, player.Character) end
    end

    local scriptList = {}
    local visited = {}

    for _, container in ipairs(targetContainers) do
        if container and not visited[container] then
            visited[container] = true
            local descendants = {}
            pcall(function() descendants = container:GetDescendants() end)
            for _, obj in ipairs(descendants) do
                if not visited[obj] then
                    visited[obj] = true
                    local isScript = false
                    pcall(function()
                        if obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                            isScript = true
                        elseif obj:IsA("Script") and pcall(function() return obj.RunContext end) and obj.RunContext == Enum.RunContext.Client then
                            isScript = true
                        end
                    end)
                    if isScript then
                        table.insert(scriptList, obj)
                    end
                end
            end
        end
    end

    local total = #scriptList
    if total == 0 then
        WindUI:Notify({
            Title = "Code Dumper",
            Content = "No client scripts found.",
            Duration = 3
        })
        return
    end

    WindUI:Notify({
        Title = "Code Dumper",
        Content = string.format("Found %d scripts! Dumping...", total),
        Duration = 3
    })

    local dateStr = os.date("%Y-%m-%d %H:%M:%S")
    local header = string.format([[-- ==============================================================================
-- GAME CODE DUMP: %s
-- Place ID: %d | Place Version: %d
-- Generated: %s | Total Scripts: %d
-- ==============================================================================

]], gameName, game.PlaceId, game.PlaceVersion, dateStr, total)

    if writeFileFunc then
        pcall(function() writeFileFunc(fileName, header) end)
    end

    local buffer = { header }
    local count = 0

    task.spawn(function()
        for i, scr in ipairs(scriptList) do
            local path = "Unknown"
            local class = scr.ClassName or "Script"
            pcall(function() path = scr:GetFullName() end)

            local src = "-- [Decompilation unavailable]"
            if decompileFunc then
                local s, res = pcall(decompileFunc, scr)
                if s and type(res) == "string" and #res > 0 then
                    src = res
                end
            end
            if src == "-- [Decompilation unavailable]" then
                pcall(function()
                    if scr.Source and #scr.Source > 0 then
                        src = scr.Source
                    end
                end)
            end

            local block = string.format("\n-- [%d/%d] [%s] %s\n%s\n\n", i, total, class, path, src)
            if appendFileFunc then
                pcall(function() appendFileFunc(fileName, block) end)
            end
            table.insert(buffer, block)
            count = count + 1

            if i % 5 == 0 then
                task.wait()
            end
        end

        if writeFileFunc and not appendFileFunc then
            pcall(function() writeFileFunc(fileName, table.concat(buffer, "")) end)
        end

        if copyClipboard and setClipboardFunc then
            setClipboardFunc(table.concat(buffer, ""))
            WindUI:Notify({
                Title = "Code Dumper",
                Content = string.format("Copied all %d scripts to clipboard!", count),
                Duration = 4
            })
        end

        if writeFileFunc then
            WindUI:Notify({
                Title = "Code Dumper Complete",
                Content = string.format("Saved %d scripts to workspace/%s", count, fileName),
                Duration = 5
            })
        else
            WindUI:Notify({
                Title = "Code Dumper Complete",
                Content = string.format("Dumped %d scripts (Console / Buffer)", count),
                Duration = 5
            })
        end
    end)
end

DeveloperSection:Button({
    Title = "Dump All Game Code to File",
    Description = "Decompiles all LocalScripts & ModuleScripts into one .lua file",
    Callback = function()
        runCodeDump(false)
    end
})

DeveloperSection:Button({
    Title = "Dump & Copy to Clipboard",
    Description = "Dumps all game code and copies it to your clipboard",
    Callback = function()
        runCodeDump(true)
    end
})

-- ============================================================
-- VIOLENCE DISTRICT SUITE
-- Features: Auto Repair, Perfect Skillcheck, Killer ESP,
-- Generator ESP, Auto Pallet Stun, Auto Save Survivor,
-- Auto Aim, Auto Parry.
-- ============================================================


end

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

autoRoleAdaptEnabled = true
local lastDetectedRole = nil

V_RoleSection:Toggle({
    Title = "Auto Role Adapt",
    Description = "Automatically detects Killer/Survivor role and auto-disables opposing features",
    Default = true,
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
                local isKiller = isPlayerKiller and isPlayerKiller()
                local currentRole = isKiller and "Killer" or "Survivor"

                if currentRole ~= lastDetectedRole then
                    lastDetectedRole = currentRole
                    if currentRole == "Killer" then
                        -- Invalidate all survivor automation sessions immediately
                        repairSession = (repairSession or 0) + 1
                        saveSession = (saveSession or 0) + 1
                        palletSession = (palletSession or 0) + 1
                        parrySession = (parrySession or 0) + 1
                        dodgeSession = (dodgeSession or 0) + 1

                        -- Disable all survivor-only automation features
                        if autoRepairEnabled then
                            autoRepairEnabled = false
                            if currentRepairPoint then
                                local remotes = getVDRemotes()
                                if remotes.Generator and remotes.Generator:FindFirstChild("RepairEvent") then
                                    pcall(function()
                                        remotes.Generator.RepairEvent:FireServer(currentRepairPoint, false, nil, HttpService:GenerateGUID(false), player.Character)
                                    end)
                                end
                                currentRepairPoint = nil
                            end
                        end
                        autoDodgeEnabled = false
                        autoPalletEnabled = false
                        autoParryEnabled = false
                        autoSaveEnabled = false
                        WindUI:Notify({ Title = "👹 Role: KILLER", Content = "Detected Killer role. Survivor automation auto-disabled.", Duration = 2.5 })

                    elseif currentRole == "Survivor" then
                        -- Invalidate killer automation sessions immediately
                        catchSession = (catchSession or 0) + 1

                        -- Disable all killer-only automation features
                        autoCatchEnabled = false
                        autoHookSurvivorEnabled = false
                        autoAimSurvivorEnabled = false
                        autoHitSurvivorEnabled = false
                        currentKillerTarget = nil
                        updateKillerAim()
                        WindUI:Notify({ Title = "🏃 Role: SURVIVOR", Content = "Detected Survivor role. Killer automation auto-disabled.", Duration = 2.5 })
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
        if plr:GetAttribute("IsDead") == true or plr:GetAttribute("HasEscaped") == true then
            return true
        end
        local team = plr.Team
        if team then
            local tName = team.Name:lower()
            if tName:find("lobby") or tName:find("choos") or tName:find("spectat") or tName:find("intermission") then
                return true
            end
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
        if char:FindFirstAncestor("Lobby") then
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
    if char:GetAttribute("Knocked") == true or char:GetAttribute("isKnocked") == true
        or char:GetAttribute("Downed") == true or char:GetAttribute("isDowned") == true
        or char:GetAttribute("isBleeding") == true then
        return true
    end
    if CollectionService and CollectionService:HasTag(char, "Knocked") then return true end
    if char:FindFirstChild("downed") or char:FindFirstChild("Knocked") then return true end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum and hum.Health > 0 and hum.Health < 30 then
        return true
    end
    return false
end

-- ============================================================
-- AUTHORITATIVE ROLE IDENTIFICATION (KILLER & SURVIVOR)
-- ============================================================
local isPlayerKiller

local function checkPlayerKillerStatus()
    local myChar = player.Character
    if not myChar then return false end

    -- 1. Check PlayerGui for Killer HUD (Slasher-mob, Slasher, Slasher-con)
    -- In Violence District, only the Killer possesses these unique controller GUIs
    local pg = player:FindFirstChild("PlayerGui")
    if pg then
        if pg:FindFirstChild("Slasher-mob") or pg:FindFirstChild("Slasher") or pg:FindFirstChild("Slasher-con") then
            return true
        end
        for _, gui in ipairs(pg:GetChildren()) do
            local gName = gui.Name:lower()
            if gName:find("slasher") or gName:find("killer") then
                return true
            end
        end
    end

    -- 2. Check Backpack for Killer weapons
    local bp = player:FindFirstChild("Backpack")
    if bp then
        for _, item in ipairs(bp:GetChildren()) do
            if item:IsA("Tool") then
                local iName = item.Name:lower()
                if iName:find("cleaver") or iName:find("machete") or iName:find("chainsaw") 
                    or iName:find("killerweapon") or iName:find("beartrap") or iName:find("slasher")
                    or iName:find("axe") or iName:find("blade") then
                    return true
                end
            end
        end
    end

    -- 3. Explicit Team verification
    if player.Team then
        local tName = player.Team.Name:lower()
        if tName:find("killer") or tName:find("slasher") then
            return true
        end
        if tName:find("survivor") then
            return false
        end
    end

    -- 4. CollectionService & Attributes
    if CollectionService:HasTag(myChar, "Killer") or CollectionService:HasTag(player, "Killer") then
        return true
    end
    if myChar:GetAttribute("Butcher") == true 
        or myChar:GetAttribute("IsKiller") == true 
        or myChar:GetAttribute("KillerName") ~= nil 
        or myChar:GetAttribute("ChainBusy") ~= nil 
        or player:GetAttribute("IsKiller") == true 
        or player:GetAttribute("Role") == "Killer" then
        return true
    end

    -- 5. Killer weapons / tools equipped in character
    for _, item in ipairs(myChar:GetChildren()) do
        if item:IsA("Tool") or item:IsA("BasePart") or item:IsA("Model") then
            local iName = item.Name:lower()
            if iName:find("cleaver") or iName:find("machete") or iName:find("chainsaw") 
                or iName:find("killerweapon") or iName:find("beartrap") or iName:find("slasher")
                or iName:find("axe") or iName:find("blade") then
                return true
            end
        end
    end

    return false
end

isPlayerKiller = checkPlayerKillerStatus

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
    end

    -- 2. Survivor interaction state attributes (Killer cannot repair, heal, vault-slide pallet)
    if char:GetAttribute("isRepairing") == true 
        or char:GetAttribute("isHealing") == true 
        or char:GetAttribute("isVaulting") == true 
        or char:GetAttribute("isSliding") == true 
        or char:GetAttribute("isDroppingPallet") == true 
        or char:GetAttribute("isUnhooking") == true 
        or char:GetAttribute("isExiting") == true then
        return false
    end

    -- 3. CollectionService "Killer" tag (Applied by server to active killer character)
    if CollectionService:HasTag(char, "Killer") then
        return true
    end
    if plr and CollectionService:HasTag(plr, "Killer") then
        return true
    end

    -- 4. Killer-specific attributes on CURRENT character instance
    if char:GetAttribute("Butcher") == true 
        or char:GetAttribute("IsKiller") == true 
        or char:GetAttribute("KillerName") ~= nil 
        or char:GetAttribute("ChainBusy") == true then
        return true
    end

    -- 5. Active Killer combat states
    if char:GetAttribute("isAttacking") == true 
        or char:GetAttribute("isLunging") == true then
        return true
    end

    -- 6. Killer weapons / tools held
    for _, item in ipairs(char:GetChildren()) do
        if item:IsA("Tool") or item:IsA("BasePart") or item:IsA("Model") then
            local iName = item.Name:lower()
            if iName:find("cleaver") or iName:find("machete") or iName:find("chainsaw") 
                or iName:find("killerweapon") or iName:find("beartrap") or iName:find("slasher")
                or iName:find("axe") or iName:find("blade") then
                return true
            end
        end
    end

    -- 7. Known killer model names in workspace (Only for unlinked NPC killers)
    if not plr then
        local cName = char.Name:lower()
        if cName:find("butcher") or cName:find("slasher") or cName:find("jason") 
            or cName:find("abysswalker") or cName:find("masked") then
            return true
        end
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

    -- Active survivor status attributes
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

    -- Valid player character in workspace not on killer/lobby team
    if plr and plr ~= player then
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
end

-- Connect local player respawn
player.CharacterAdded:Connect(function(newChar)
    task.wait(0.4)
    onMatchOrCharacterReset()
end)

-- Connect other players' character respawns and team changes
local function setupPlayerListeners(plr)
    if not plr or plr == player then return end
    plr.CharacterAdded:Connect(function(newChar)
        task.wait(0.4)
        onMatchOrCharacterReset()
    end)
    plr:GetPropertyChangedSignal("Team"):Connect(function()
        task.wait(0.3)
        onMatchOrCharacterReset()
    end)
end

for _, plr in ipairs(Players:GetPlayers()) do
    setupPlayerListeners(plr)
end
Players.PlayerAdded:Connect(setupPlayerListeners)

-- ============================================================
-- 1. KILLER ESP
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
end

V_ESPSection:Toggle({
    Title = "Killer ESP",
    Description = "Highlights the Killer in Red with distance & status",
    Default = false,
    Callback = function(v)
        killerESPEnabled = v
        if not v then
            cleanKillerESP()
            WindUI:Notify({ Title = "Killer ESP", Content = "Killer ESP disabled.", Duration = 2 })
            return
        end

        WindUI:Notify({ Title = "Killer ESP", Content = "Killer ESP enabled!", Duration = 2 })

        task.spawn(function()
            while killerESPEnabled do
                local killer = getKiller()
                local myChar = player.Character
                local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")

                if killer and killer.Parent and killer:IsDescendantOf(workspace) and killer:FindFirstChild("HumanoidRootPart") and myHrp then
                    local kHrp = killer.HumanoidRootPart
                    local dist = (myHrp.Position - kHrp.Position).Magnitude

                    -- Strip any accidental Survivor ESP that may have attached to killer
                    local sHl = killer:FindFirstChild("SurvivorESPHighlight")
                    if sHl then pcall(function() sHl:Destroy() end) end
                    local sBb = kHrp:FindFirstChild("SurvivorESPBillboard")
                    if sBb then pcall(function() sBb:Destroy() end) end

                    -- Rebind if killer instance changed (new round or different player)
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
                        killerESPBillboard.Size = UDim2.fromOffset(180, 50)
                        killerESPBillboard.StudsOffset = Vector3.new(0, 3.5, 0)
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
                        if killer:GetAttribute("isAttacking") then
                            status = "ATTACKING"
                        elseif killer:GetAttribute("isLunging") then
                            status = "LUNGING"
                        elseif killer:GetAttribute("isStunned") then
                            status = "STUNNED"
                        end
                        killerESPBillboard.Label.Text = string.format("👹 KILLER [%s]\n%.0f studs", status, dist)
                    end
                else
                    cleanKillerESP()
                end
                task.wait(0.2)
            end
            cleanKillerESP()
        end)
    end
})

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
-- SURVIVOR DETECTOR (ESP)
-- ============================================================
local survivorESPEnabled = false
local survivorESPObjects = {}

cleanSurvivorESP = function()
    for _, item in ipairs(survivorESPObjects) do
        pcall(function() item:Destroy() end)
    end
    survivorESPObjects = {}
end

V_ESPSection:Toggle({
    Title = "Survivor Detector (ESP)",
    Description = "Highlights all Survivors with health status, knocked/hooked state & distance",
    Default = false,
    Callback = function(v)
        survivorESPEnabled = v
        if not v then
            cleanSurvivorESP()
            WindUI:Notify({ Title = "Survivor ESP", Content = "Survivor Detector disabled.", Duration = 2 })
            return
        end

        WindUI:Notify({ Title = "Survivor ESP", Content = "Survivor Detector active!", Duration = 2 })

        task.spawn(function()
            while survivorESPEnabled do
                cleanSurvivorESP()
                local myChar = player.Character
                local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                local isKiller = isPlayerKiller()
                local killerChar = isKiller and myChar or getKiller()

                local candidateChars = {}
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= player and plr.Character and plr.Character ~= myChar and plr.Character ~= killerChar then
                        if isKiller then
                            -- When local player is Killer, every other alive player in workspace is an enemy survivor!
                            local valid, hum, hrp = isValidCharacter(plr.Character)
                            if valid and not isEntityInLobbyOrSpectating(plr.Character, plr) then
                                table.insert(candidateChars, { char = plr.Character, name = plr.DisplayName or plr.Name, plr = plr })
                            end
                        else
                            if isCharacterSurvivor(plr.Character, plr) and not isCharacterKiller(plr.Character, plr) then
                                table.insert(candidateChars, { char = plr.Character, name = plr.DisplayName or plr.Name, plr = plr })
                            end
                        end
                    end
                end

                -- Also search potential survivor containers in workspace (Survivors, Players, Match, Characters)
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
                                if isKiller then
                                    if not isEntityInLobbyOrSpectating(obj) then
                                        local alreadyAdded = false
                                        for _, c in ipairs(candidateChars) do
                                            if c.char == obj then alreadyAdded = true break end
                                        end
                                        if not alreadyAdded then
                                            table.insert(candidateChars, { char = obj, name = obj.Name, plr = nil })
                                        end
                                    end
                                else
                                    if isCharacterSurvivor(obj) and not isCharacterKiller(obj) then
                                        local alreadyAdded = false
                                        for _, c in ipairs(candidateChars) do
                                            if c.char == obj then alreadyAdded = true break end
                                        end
                                        if not alreadyAdded then
                                            table.insert(candidateChars, { char = obj, name = obj.Name, plr = nil })
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                for _, item in ipairs(candidateChars) do
                    if not survivorESPEnabled then break end
                    local c = item.char
                    local hum = c:FindFirstChildOfClass("Humanoid")
                    local hrp = c:FindFirstChild("HumanoidRootPart")

                    if hum and hrp and hum.Health > 0 and myHrp and c:IsDescendantOf(workspace) and c ~= killerChar and not isCharacterKiller(c, item.plr) then
                        local dist = (myHrp.Position - hrp.Position).Magnitude

                        -- Determine status & color using unified functions
                        local status = "HEALTHY"
                        local fillColor = Color3.fromRGB(50, 255, 50)

                        local isHooked = isCharacterHooked(c)
                        local isKnocked = isCharacterKnocked(c)
                        local isCarried = c:GetAttribute("IsCarried") or c:GetAttribute("isCarried") or c:GetAttribute("BeingCarried")

                        if isHooked then
                            status = "HOOKED"
                            fillColor = Color3.fromRGB(180, 50, 255)
                        elseif isCarried then
                            status = "CARRIED"
                            fillColor = Color3.fromRGB(255, 120, 0)
                        elseif isKnocked then
                            status = "KNOCKED DOWN"
                            fillColor = Color3.fromRGB(255, 60, 60)
                        elseif hum.Health < 70 then
                            status = string.format("INJURED (%.0f HP)", hum.Health)
                            fillColor = Color3.fromRGB(255, 220, 30)
                        else
                            status = string.format("HEALTHY (%.0f HP)", hum.Health)
                        end

                        local hl = Instance.new("Highlight")
                        hl.Name = "SurvivorESPHighlight"
                        hl.FillColor = fillColor
                        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                        hl.FillTransparency = 0.5
                        hl.OutlineTransparency = 0.2
                        hl.Parent = c
                        table.insert(survivorESPObjects, hl)

                        local bb = Instance.new("BillboardGui")
                        bb.Name = "SurvivorESPBillboard"
                        bb.Adornee = hrp
                        bb.Size = UDim2.fromOffset(160, 45)
                        bb.StudsOffset = Vector3.new(0, 3.5, 0)
                        bb.AlwaysOnTop = true

                        local lbl = Instance.new("TextLabel")
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
                        table.insert(survivorESPObjects, bb)
                    end
                end
                task.wait(1.5)
            end
            cleanSurvivorESP()
        end)
    end
})

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
-- 3. PERFECT SKILLCHECK (STANDALONE ZERO-LATENCY FRAME ENGINE)
-- ============================================================
local perfectSkillcheckEnabled = true
autoSkillCheckEnabled = true
local skillcheckConn = nil
local skillcheckHooked = false
local lastSkillCheckSolvedTime = 0

-- Helper to find active SkillCheck Gui in PlayerGui (strictly excluding ProgressPromptGui)
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
            if gui:IsA("ScreenGui") and not gui.Enabled then
                -- disabled ScreenGui, skip
            else
                local check = gui:FindFirstChild("Check", true)
                if check and check:IsA("GuiObject") and check.Visible then
                    return gui, check
                end
                local frame = gui:FindFirstChild("Frame", true)
                if frame and frame:IsA("GuiObject") and frame.Visible and frame.Name ~= "smoothedbar" and frame.Name ~= "fullbar" then
                    return gui, frame
                end
            end
        end
    end

    for _, gui in ipairs(pg:GetChildren()) do
        if gui:IsA("ScreenGui") and gui.Enabled then
            local gName = gui.Name:lower()
            if (gName:find("skill") or gName:find("qte")) and not gName:find("progress") then
                local check = gui:FindFirstChild("Check", true) or gui:FindFirstChild("Frame", true)
                if check and check:IsA("GuiObject") and check.Visible then
                    return gui, check
                end
            end
        end
    end

    return nil, nil
end

-- Helper to inspect Check frame and locate dynamic needle & great zone
local function evaluateSkillCheckFrame(check, lastRotTable)
    if not check then return nil, nil, {} end

    local needle = nil
    local greatZone = nil
    local candidates = {}

    for _, child in ipairs(check:GetDescendants()) do
        if child:IsA("GuiObject") then
            local low = child.Name:lower()
            if low:find("needle") or low:find("pointer") or low:find("line") or low:find("indicator") or low:find("arrow") or low:find("cursor") or low:find("bar") then
                needle = child
            elseif low:find("great") or low:find("perfect") or low:find("sweet") or low:find("target") or low:find("white") or low:find("zone") or low:find("bonus") or low:find("success") then
                greatZone = child
            end
            table.insert(candidates, child)
        end
    end

    -- If no explicit needle found by name, detect any child whose rotation is actively moving
    if not needle and lastRotTable then
        for _, elem in ipairs(candidates) do
            local curRot = elem.Rotation % 360
            local prevRot = lastRotTable[elem]
            if prevRot ~= nil and math.abs(curRot - prevRot) > 0.5 then
                needle = elem
                break
            end
        end
    end

    -- Secondary fallback for needle: any element with non-zero rotation
    if not needle then
        for _, elem in ipairs(candidates) do
            if elem.Rotation ~= 0 then
                needle = elem
                break
            end
        end
    end

    return needle, greatZone, candidates
end

-- Standalone skillcheck trigger execution (Full Multi-Method PC & Delta Mobile Dispatch)
local function triggerPerfectHit()
    pcall(function()
        local boundKeyName = player:GetAttribute("kb_skillcheck") or "Space"
        local boundKeyCode = Enum.KeyCode[boundKeyName] or Enum.KeyCode.Space

        -- 1. VirtualInputManager key event (Universal PC & Executor)
        VirtualInputManager:SendKeyEvent(true, boundKeyCode, false, game)
        task.wait(0.02)
        VirtualInputManager:SendKeyEvent(false, boundKeyCode, false, game)

        -- 2. Space fallback as guaranteed secondary event
        if boundKeyCode ~= Enum.KeyCode.Space then
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
            task.wait(0.02)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        end

        -- 3. Executor native keypress / keyrelease (Delta Android & PC)
        if typeof(keypress) == "function" and typeof(keyrelease) == "function" then
            pcall(keypress, 0x20)
            task.wait(0.02)
            pcall(keyrelease, 0x20)
        end

        -- 4. VirtualUser fallback
        pcall(function()
            local vu = game:GetService("VirtualUser")
            vu:CaptureController()
            vu:SetKeyDown("0x20")
            task.wait(0.02)
            vu:SetKeyUp("0x20")
        end)

        -- 5. Mobile touch / button activation (Delta Mobile)
        local pg = player:FindFirstChild("PlayerGui")
        if pg then
            for _, scName in ipairs({"SkillCheckPromptGui", "SkillCheckPromptGui-con", "Survivor-mob", "SkillCheckGui", "SkillCheck"}) do
                local sc = pg:FindFirstChild(scName)
                if sc then
                    for _, elem in ipairs(sc:GetDescendants()) do
                        if elem:IsA("GuiButton") and elem.Visible then
                            if typeof(firesignal) == "function" then
                                pcall(firesignal, elem.MouseButton1Down)
                                pcall(firesignal, elem.Activated)
                                pcall(firesignal, elem.MouseButton1Click)
                            end
                            pcall(function()
                                local pos = elem.AbsolutePosition + (elem.AbsoluteSize / 2)
                                VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
                                task.wait(0.02)
                                VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
                            end)
                        end
                    end
                end
            end
        end
    end)
end

-- Anti-Fail Safety Hook: blocks failure animation on client side
local function hookSkillCheckFailPrevention()
    if skillcheckHooked then return end
    skillcheckHooked = true

    pcall(function()
        local remotes = getVDRemotes()
        if remotes.Generator and remotes.Generator:FindFirstChild("SkillCheckFailEvent") then
            pcall(function()
                remotes.Generator.SkillCheckFailEvent.OnClientEvent:Connect(function()
                    -- Intercept failure alert
                end)
            end)
        end
        if remotes.Healing and remotes.Healing:FindFirstChild("SkillCheckFailEvent") then
            pcall(function()
                remotes.Healing.SkillCheckFailEvent.OnClientEvent:Connect(function()
                    -- Intercept healing failure alert
                end)
            end)
        end
    end)
end

local function startSkillcheckWatcher()
    if skillcheckConn then
        pcall(function() skillcheckConn:Disconnect() end)
        skillcheckConn = nil
    end

    hookSkillCheckFailPrevention()

    local promptOpenTick = 0
    local promptHandled = false
    local rotHistory = {}

    -- RenderStepped 60FPS+ high-precision watcher
    skillcheckConn = RunService.RenderStepped:Connect(function()
        if not perfectSkillcheckEnabled then return end

        local gui, check = getActiveSkillCheckGui()
        if check and check.Visible then
            if not promptHandled then
                if promptOpenTick == 0 then
                    promptOpenTick = os.clock()
                end

                local needle, greatZone, candidates = evaluateSkillCheckFrame(check, rotHistory)

                -- Update rotHistory for dynamic needle motion detection
                if candidates then
                    for _, elem in ipairs(candidates) do
                        rotHistory[elem] = elem.Rotation % 360
                    end
                end

                local shouldHit = false
                local elapsed = os.clock() - promptOpenTick

                if needle and greatZone then
                    local nRot = needle.Rotation % 360
                    local gRot = greatZone.Rotation % 360
                    local diff = (gRot - nRot) % 360
                    if diff <= 15 or (diff >= 345 and diff <= 360) then
                        shouldHit = true
                    end
                elseif needle then
                    local nRot = needle.Rotation % 360
                    if (nRot >= 75 and nRot <= 135) or (elapsed >= 0.25 and elapsed <= 0.35) then
                        shouldHit = true
                    end
                else
                    -- Timed fallback: in DbD / Violence District, the sweet spot for great hit is ~0.25s - 0.28s
                    if elapsed >= 0.26 and elapsed <= 0.38 then
                        shouldHit = true
                    end
                end

                if shouldHit and (tick() - lastSkillCheckSolvedTime > 0.4) then
                    promptHandled = true
                    lastSkillCheckSolvedTime = tick()
                    triggerPerfectHit()
                end
            end
        else
            promptOpenTick = 0
            promptHandled = false
            rotHistory = {}
        end
    end)
end

V_ObjectiveSection:Toggle({
    Title = "Perfect Skillcheck",
    Description = "100% Perfect/Great skillchecks active standalone (works on repair, self-heal, & team heal)",
    Default = true,
    Callback = function(v)
        perfectSkillcheckEnabled = v
        if not v then
            if skillcheckConn then
                pcall(function() skillcheckConn:Disconnect() end)
                skillcheckConn = nil
            end
            WindUI:Notify({ Title = "Skillcheck", Content = "Perfect Skillcheck disabled.", Duration = 2 })
            return
        end

        startSkillcheckWatcher()
        WindUI:Notify({ Title = "Skillcheck", Content = "Perfect Skillcheck active! (Zero-latency standalone)", Duration = 2 })
    end
})

-- Auto-activate Perfect Skillcheck on script initialization
if perfectSkillcheckEnabled then
    startSkillcheckWatcher()
end

-- ============================================================
-- 4. AUTO REPAIR GENERATOR (AUTO SEARCH, TRAVEL & ACCURATE FIX DETECTION)
-- ============================================================
-- Unified autoRepairEnabled & currentRepairPoint
currentRepairPoint = nil
local repairSafeDistance = 25
local travelMode = "Safe Teleport"
local safeTeleportStep = 3.5
local isTraveling = false
local completedGenerators = {}

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
            char:SetAttribute("AC_ServerAnchor", true)
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
                c:SetAttribute("AC_ServerAnchor", true)
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
                char:SetAttribute("AC_ServerAnchor", false)
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
            char:SetAttribute("AC_ServerAnchor", state)
        end)
    end

    -- Server Collision sync (p_u_310.disableCollisionEvent:FireServer())
    if state then
        fireDisableCollision()
    else
        if not serverDisableCollisionEnabled then
            fireEnableCollision()
        end
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
                c:SetAttribute("AC_ServerAnchor", true)
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
local antiImmobileEnabled = false

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
    Title = "Anti-Immobile / Anti-Root (Immobile)",
    Description = "Fires Mechanics.ChangeAttribute('Immobile', false) to unlock movement from bear traps & hits",
    Default = false,
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

            -- 1. Server collision maintenance
            if serverDisableCollisionEnabled or noClipEnabled then
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

-- Helper to detect if Killer is currently stunned, parried, shot, or recovering (e.g. Flare/Revolver/Dagger/Shield)
local function isKillerStunnedOrLocked(char)
    if not char or not char.Parent then return false end

    -- 1. Game attributes set by Violence District on stun/parry/shot
    if char:GetAttribute("isStunned") == true 
        or char:GetAttribute("IsStunned") == true 
        or char:GetAttribute("Stunned") == true 
        or char:GetAttribute("AttackLock") == true 
        or char:GetAttribute("Immobile") == true 
        or char:GetAttribute("Blinded") == true 
        or char:GetAttribute("Stun") == true 
        or char:GetAttribute("ChainBusy") == true then
        return true
    end

    -- 2. CollectionService stun tags
    if CollectionService and (CollectionService:HasTag(char, "Stunned") or CollectionService:HasTag(char, "Stun")) then
        return true
    end

    -- 3. Stun child marker instances
    if char:FindFirstChild("Stunned") or char:FindFirstChild("Stun") or char:FindFirstChild("AttackLock") then
        return true
    end

    -- 4. Humanoid physical states during stun / parry recovery
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        if hum.WalkSpeed == 0 or hum.PlatformStand or hum.Sit then
            return true
        end
        local animator = hum:FindFirstChildOfClass("Animator")
        if animator then
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                local tName = track.Name:lower()
                if tName:find("stun") or tName:find("parried") or tName:find("hitreact") or tName:find("flinch") or tName:find("blind") then
                    return true
                end
            end
        end
    end

    return false
end

-- Helper to detect if target survivor is currently parrying (ParryingDagger) or blocking (RiotShield)
local function isSurvivorParryingOrShielded(sChar)
    if not sChar or not sChar.Parent then return false end

    -- Violence District adds "doing action" tag to survivors during active parry frames
    if CollectionService and CollectionService:HasTag(sChar, "doing action") then
        return true
    end

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

    -- Check playing parry/shield animations
    local hum = sChar:FindFirstChildOfClass("Humanoid")
    if hum then
        local animator = hum:FindFirstChildOfClass("Animator")
        if animator then
            for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                local tName = track.Name:lower()
                if tName:find("parry") or tName:find("shield") or tName:find("block") or tName:find("deflect") then
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
    if not isCharacterSurvivor(c) then return false end
    if isCharacterKiller(c) or c == getKiller() then return false end
    
    local hum = c:FindFirstChildOfClass("Humanoid")
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then return false end

    -- Exclude Lobby/Spectating
    if isEntityInLobbyOrSpectating(c) then
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

    return true
end

-- Validates that target is a Downed/Knocked Survivor eligible for pickup & hooking
local function isSurvivorDowned(c)
    if not c or not c.Parent then return false end
    if c == player.Character then return false end
    if not isCharacterSurvivor(c) then return false end
    if isCharacterKiller(c) or c == getKiller() then return false end
    
    local hum = c:FindFirstChildOfClass("Humanoid")
    local hrp = c:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then return false end

    -- Exclude Lobby/Spectating
    if isEntityInLobbyOrSpectating(c) then return false end

    -- Exclude Hooked survivors
    if isCharacterHooked(c) then return false end

    -- Exclude Carried survivors
    local isCarried = c:GetAttribute("IsCarried") == true
        or c:GetAttribute("isCarried") == true
        or c:GetAttribute("BeingCarried") == true
        or c:FindFirstChild("Carried") ~= nil
    if isCarried then return false end

    return isCharacterKnocked(c)
end

local function findNearestSurvivor()
    local myChar = player.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return nil end

    local bestTarget = nil
    local bestDist = math.huge

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and plr.Character ~= myChar then
            local c = plr.Character
            if isSurvivorValidTarget(c) then
                local hrp = c:FindFirstChild("HumanoidRootPart")
                local dist = (myHrp.Position - hrp.Position).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    bestTarget = c
                end
            end
        end
    end

    if not bestTarget then
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") and obj ~= myChar and obj:FindFirstChildOfClass("Humanoid") and obj:FindFirstChild("HumanoidRootPart") then
                if isSurvivorValidTarget(obj) then
                    local hrp = obj.HumanoidRootPart
                    local dist = (myHrp.Position - hrp.Position).Magnitude
                    if dist < bestDist then
                        bestDist = dist
                        bestTarget = obj
                    end
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

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and plr.Character ~= myChar then
            local c = plr.Character
            if isSurvivorDowned(c) then
                local hrp = c:FindFirstChild("HumanoidRootPart")
                local dist = (myHrp.Position - hrp.Position).Magnitude
                if dist < bestDist then
                    bestDist = dist
                    bestDowned = c
                end
            end
        end
    end

    if not bestDowned then
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") and obj ~= myChar and obj:FindFirstChildOfClass("Humanoid") and obj:FindFirstChild("HumanoidRootPart") then
                if isSurvivorDowned(obj) then
                    local hrp = obj.HumanoidRootPart
                    local dist = (myHrp.Position - hrp.Position).Magnitude
                    if dist < bestDist then
                        bestDist = dist
                        bestDowned = obj
                    end
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

    -- DO NOT swing if killer is currently stunned, shot, parried, or in recovery lock
    if isKillerStunnedOrLocked(myChar) then
        return
    end

    -- DO NOT swing directly into active survivor parry or riot shield frames
    if targetChar and isSurvivorParryingOrShielded(targetChar) then
        return
    end

    local remotes = getVDRemotes()
    local myHrp = myChar:FindFirstChild("HumanoidRootPart")
    if not myHrp then return end

    local sHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
    if sHrp then
        -- 1. Snap Killer body directly towards survivor
        local lookTarget = Vector3.new(sHrp.Position.X, myHrp.Position.Y, sHrp.Position.Z)
        myHrp.CFrame = CFrame.lookAt(myHrp.Position, lookTarget)

        -- 2. Melee Range Step: If slightly far (> 3.2 studs), nudge into physical weapon reach
        local curDist = (myHrp.Position - sHrp.Position).Magnitude
        if curDist > 3.2 and curDist <= 6.0 then
            local toSurvivor = (sHrp.Position - myHrp.Position).Unit
            myHrp.CFrame = CFrame.lookAt(myHrp.Position + toSurvivor * 1.2, lookTarget)
        end
    end

    -- 3. Fire Official Violence District Attack Remotes
    if remotes.Attacks then
        if remotes.Attacks:FindFirstChild("BasicAttack") then
            pcall(function() remotes.Attacks.BasicAttack:FireServer() end)
        end
        if remotes.Attacks:FindFirstChild("Lunge") then
            pcall(function() remotes.Attacks.Lunge:FireServer() end)
        end
    end

    -- 4. Fire Mobile Attack GUI Button (Slasher-mob / Slasher Controls.attack)
    pcall(function()
        local pg = player:FindFirstChild("PlayerGui")
        if pg then
            for _, guiName in ipairs({"Slasher-mob", "Slasher", "Slasher-con", "MobileGui"}) do
                local g = pg:FindFirstChild(guiName)
                if g then
                    for _, btn in ipairs(g:GetDescendants()) do
                        if btn:IsA("GuiButton") and (btn.Name:lower() == "attack" or btn.Name:lower():find("slash")) then
                            if typeof(firesignal) == "function" then
                                firesignal(btn.MouseButton1Down)
                                firesignal(btn.Activated)
                                firesignal(btn.MouseButton1Click)
                            end
                        end
                    end
                end
            end
            for _, btn in ipairs(pg:GetDescendants()) do
                if btn:IsA("GuiButton") and (btn.Name:lower() == "attack" or btn.Name:lower():find("basicattack")) then
                    if typeof(firesignal) == "function" then
                        firesignal(btn.MouseButton1Down)
                        firesignal(btn.Activated)
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
                    task.wait(0.01)
                    firetouchinterest(part, sHrp, 1)
                end
            end
            if rightArm then
                firetouchinterest(rightArm, sHrp, 0)
                task.wait(0.01)
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

    -- 7. PC Mouse Click Fallback
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        task.wait(0.02)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end)
end

-- Continuous frame-locked Auto Aim for Killer (Works whether Auto Catch is ON or OFF)
local function updateKillerAim()
    if killerAimConn then
        pcall(function() killerAimConn:Disconnect() end)
        killerAimConn = nil
    end

    if not autoAimSurvivorEnabled then return end

    killerAimConn = RunService.RenderStepped:Connect(function()
        if not autoAimSurvivorEnabled then return end
        if not isPlayerKiller() then return end

        pcall(function()
            local myChar = player.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if not myHrp then return end

            local target = currentKillerTarget
            if not target or not target.Parent or not isSurvivorValidTarget(target) then
                local nearest, nDist = findNearestSurvivor()
                if nearest and nDist <= (hitReachDistance + 6) then
                    target = nearest
                    currentKillerTarget = nearest
                else
                    return
                end
            end

            local sHrp = target:FindFirstChild("HumanoidRootPart")
            if not sHrp then return end

            local cam = workspace.CurrentCamera
            local aimPos = sHrp.Position + Vector3.new(0, 1.2, 0)

            -- Lock Camera smoothly directly at Survivor
            cam.CFrame = CFrame.lookAt(cam.CFrame.Position, aimPos)

            -- Lock Killer body towards Survivor for server hit validation
            local lookTarget = Vector3.new(sHrp.Position.X, myHrp.Position.Y, sHrp.Position.Z)
            myHrp.CFrame = CFrame.lookAt(myHrp.Position, lookTarget)
        end)
    end)
end

-- Standalone Killer Combat Loop (Runs when Auto Aim or Auto Hit is ON, even if Auto Catch is OFF!)
task.spawn(function()
    while scriptRunning do
        pcall(function()
            if not scriptRunning then return end
            if (autoAimSurvivorEnabled or autoHitSurvivorEnabled) and isPlayerKiller() then
                local myChar = player.Character
                if isKillerStunnedOrLocked(myChar) then return end
                local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                if myHrp then
                    local targetSurvivor, dist = findNearestSurvivor()
                    if targetSurvivor and dist <= (hitReachDistance + 4) then
                        currentKillerTarget = targetSurvivor

                        -- Auto Hit trigger when within melee striking distance (<= 4.8 studs) and survivor not parrying
                        if autoHitSurvivorEnabled and dist <= 4.8 and not isSurvivorParryingOrShielded(targetSurvivor) then
                            if (tick() - lastKillerHitTime) > 0.45 then
                                lastKillerHitTime = tick()
                                executeKillerHit(targetSurvivor)
                            end
                        end
                    else
                        if not autoCatchEnabled then
                            currentKillerTarget = nil
                        end
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
    if dist <= 2.8 then return true end

    -- 1. INSTANT TELEPORT (ALWAYS BEHIND SURVIVOR AT 2.5 STUDS FACING THEIR BACK)
    if killerTravelMode == "Instant Teleport" then
        local behindPos = targetPos - (targetHrp.CFrame.LookVector * 2.5) + Vector3.new(0, 0.2, 0)
        local behindCF = CFrame.lookAt(behindPos, targetPos)
        myHrp.CFrame = behindCF
        myHrp.AssemblyLinearVelocity = Vector3.zero
        myHrp.AssemblyAngularVelocity = Vector3.zero
        task.wait(0.04)
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
            if autoHookSurvivorEnabled and isPlayerKiller() and not isHookActionActive then
                local myChar = player.Character
                local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                if not myHrp then return end

                local isCarrying = myChar:GetAttribute("IsCarrying") == true
                    or myChar:FindFirstChild("CarriedSurvivor") ~= nil
                    or myChar:GetAttribute("BeingCarried") ~= nil

                if isCarrying then
                    -- --------------------------------------------------------
                    -- STAGE 2: CARRYING SURVIVOR -> TRANSPORT TO NEAREST HOOK
                    -- --------------------------------------------------------
                    local hookPart, hookDist = findNearestAvailableHook()
                    if hookPart then
                        isHookActionActive = true

                        -- Move to hook if not in reach
                        if hookDist > 6 then
                            travelToTargetLocation(hookPart.Position, 5, function()
                                return autoHookSurvivorEnabled and (myChar:GetAttribute("IsCarrying") == true)
                            end)
                        end

                        -- When at hook (<= 8.5 studs): execute hang
                        local currentDist = (myHrp.Position - hookPart.Position).Magnitude
                        if currentDist <= 8.5 then
                            local lookTarget = Vector3.new(hookPart.Position.X, myHrp.Position.Y, hookPart.Position.Z)
                            myHrp.CFrame = CFrame.lookAt(myHrp.Position, lookTarget)
                            myHrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                            myHrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)

                            local reqId = HttpService:GenerateGUID(false)
                            local remotes = getVDRemotes()

                            -- Fire Hook remotes from the dump.lua
                            if remotes.Carry then
                                if remotes.Carry:FindFirstChild("HookEvent") then
                                    pcall(function() remotes.Carry.HookEvent:FireServer(hookPart, reqId, myChar) end)
                                end
                                if remotes.Carry:FindFirstChild("HookCommit") then
                                    pcall(function() remotes.Carry.HookCommit:FireServer(hookPart, reqId, myChar) end)
                                end
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
                            while tick() < waitTimeout and (myChar:GetAttribute("IsCarrying") == true) do
                                task.wait(0.1)
                            end
                            WindUI:Notify({ Title = "🪝 Survivor Hooked!", Content = "Target successfully hung on hook.", Duration = 2.5 })
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
                        if downedDist > 6 then
                            travelToTargetLocation(dHrp.Position, 5, function()
                                return autoHookSurvivorEnabled and not (myChar:GetAttribute("IsCarrying") == true) and isSurvivorDowned(downedSurvivor)
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
                            while tick() < waitTimeout and not (myChar:GetAttribute("IsCarrying") == true) do
                                task.wait(0.1)
                            end
                            if myChar:GetAttribute("IsCarrying") == true then
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
    Description = "Locks onto nearest active Survivor, pursues them, auto aims & strikes",
    Default = false,
    Callback = function(v)
        autoCatchEnabled = v
        catchSession = catchSession + 1
        local thisSession = catchSession

        if not v then
            currentKillerTarget = nil
            -- Immediately shut off aim & hit if not independently enabled by the user
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

        -- Activate aim & hit during Auto Catch pursuit
        autoAimSurvivorEnabled = true
        autoHitSurvivorEnabled = true
        updateKillerAim()

        if not isPlayerKiller() then
            WindUI:Notify({ Title = "⚠️ Role Warning", Content = "You are currently not the Killer!", Duration = 3 })
        end

        WindUI:Notify({ Title = "Auto Catch", Content = "Hunting nearest active Survivor...", Duration = 2.5 })

        local function checkCatchActive()
            return autoCatchEnabled and (catchSession == thisSession) and scriptRunning
        end

        task.spawn(function()
            while checkCatchActive() do
                local ok, err = pcall(function()
                    local myChar = player.Character
                    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                    if not myHrp then task.wait(0.5) return end

                    -- 1. STUN & SHOT RECOVERY CHECK
                    -- If killer was shot (revolver/flare) or parried (parrying dagger/riot shield),
                    -- pause pursuit and DO NOT swing or force teleport until stun clears!
                    if isKillerStunnedOrLocked(myChar) then
                        task.wait(0.15)
                        return
                    end

                    -- 2. ACQUIRE TARGET SURVIVOR
                    local survivor, dist = findNearestSurvivor()
                    if not survivor or not survivor:FindFirstChild("HumanoidRootPart") then
                        currentKillerTarget = nil
                        task.wait(0.3)
                        return
                    end

                    currentKillerTarget = survivor
                    local sHrp = survivor.HumanoidRootPart

                    -- 3. PURSUE SURVIVOR
                    local curDist = (myHrp.Position - sHrp.Position).Magnitude
                    if curDist > 2.8 then
                        if checkCatchActive() then travelToSurvivor(survivor) end
                    end

                    -- Re-verify killer is not stunned after travel
                    if isKillerStunnedOrLocked(myChar) then
                        task.wait(0.15)
                        return
                    end

                    -- 4. PARRY EVASION CHECK
                    -- If target survivor is actively parrying or blocking with shield, hold off swing!
                    if isSurvivorParryingOrShielded(survivor) then
                        -- Wait for survivor's parry active frames to drop (~0.35s) so they waste their parry!
                        task.wait(0.35)
                    end

                    -- 5. EXECUTE HIT WHEN IN RANGE
                    local finalDist = (myHrp.Position - sHrp.Position).Magnitude
                    if checkCatchActive() and finalDist <= 4.8 and not isKillerStunnedOrLocked(myChar) and not isSurvivorParryingOrShielded(survivor) then
                        if (tick() - lastKillerHitTime) > 0.45 then
                            lastKillerHitTime = tick()
                            executeKillerHit(survivor)
                        end
                    end
                end)
                if not ok then
                    task.wait(0.2)
                end
                task.wait(0.05)
            end
            currentKillerTarget = nil
        end)
    end
})



end

do
local DiscordTab = Window:Tab({
    Title = "Discord",
    Icon = "message-circle"
})

local DiscordSection = DiscordTab:Section({
    Title = "Community"
})

DiscordSection:Button({
    Title = "Join our discord for more (Copy)",
    Description = "Click to copy Discord link",
    Callback = function()
        setclipboard("https://discord.gg/AYYfZVCRZG")
        WindUI:Notify({
            Title = "Discord Link Copied",
            Content = "Discord link copied to clipboard!",
            Duration = 3
        })
    end
})

DiscordSection:Button({
    Title = "❌ Unload Script & Close UI",
    Description = "Stops all automation, clears visuals, and closes UI",
    Callback = function()
        stopScript()
    end
})

charAddedConn = player.CharacterAdded:Connect(function(char)
    character = char
    humanoid = char:WaitForChild("Humanoid")
    if flyEnabled then
        task.wait(1)
        stopFly()
        startFly()
    end
end)


print("==================================================")
print("✅ [Riel Private] All tabs and automations loaded successfully!")
print("✅ [Riel Private] UI is active and ready.")
print("==================================================")

end
