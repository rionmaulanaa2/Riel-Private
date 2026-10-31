-- ============================================================
-- Riel Private: Universal Roblox Game Code Dumper
-- Reads and decompiles all accessible client-side scripts
-- (LocalScripts and ModuleScripts) across the game into a single file.
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local StarterGui = game:GetService("StarterGui")
local StarterPlayer = game:GetService("StarterPlayer")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local MarketplaceService = game:GetService("MarketplaceService")

local LocalPlayer = Players.LocalPlayer

-- Environment decompiler and file functions
local decompileFunc = decompile or (getscriptbytecode and decompile) or nil
local writeFileFunc = writefile or nil
local appendFileFunc = appendfile or nil
local setClipboardFunc = setclipboard or toclipboard or nil

local function notify(title, text, duration)
    duration = duration or 3
    pcall(function()
        if typeof(WindUI) == "table" and WindUI.Notify then
            WindUI:Notify({ Title = title, Content = text, Duration = duration })
        else
            StarterGui:SetCore("SendNotification", {
                Title = title,
                Text = text,
                Duration = duration
            })
        end
    end)
end

local function getGameName()
    local name = "Game_" .. tostring(game.PlaceId)
    pcall(function()
        local info = MarketplaceService:GetProductInfo(game.PlaceId)
        if info and info.Name then
            name = info.Name:gsub("[^%w%s%-_]", "")
        end
    end)
    return name
end

local function extractScriptSource(inst)
    if decompileFunc then
        local success, result = pcall(decompileFunc, inst)
        if success and type(result) == "string" and #result > 0 then
            return result
        end
    end

    local success, src = pcall(function() return inst.Source end)
    if success and type(src) == "string" and #src > 0 then
        return src
    end

    return "-- [Decompilation unavailable or protected script: " .. inst:GetFullName() .. "]"
end

local function dumpAllGameCode(options)
    options = options or {}
    local copyToClipboard = options.CopyToClipboard or false

    local gameName = getGameName()
    local sanitizedGameName = gameName:gsub("%s+", "_")
    local fileName = string.format("%s_%d_code_dump.lua", sanitizedGameName, game.PlaceId)

    notify("Code Dumper", "Scanning game containers for scripts...", 3)

    local targetContainers = {
        ReplicatedStorage,
        ReplicatedFirst,
        StarterGui,
        StarterPlayer,
        Lighting,
        Workspace
    }

    if LocalPlayer then
        local ps = LocalPlayer:FindFirstChildOfClass("PlayerScripts") or LocalPlayer:FindFirstChild("PlayerScripts")
        if ps then table.insert(targetContainers, ps) end
        local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui") or LocalPlayer:FindFirstChild("PlayerGui")
        if pg then table.insert(targetContainers, pg) end
        local bp = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:FindFirstChild("Backpack")
        if bp then table.insert(targetContainers, bp) end
        if LocalPlayer.Character then
            table.insert(targetContainers, LocalPlayer.Character)
        end
    end

    local scriptList = {}
    local visited = {}

    local function collectScripts(parent)
        if not parent or visited[parent] then return end
        visited[parent] = true

        local descendants = {}
        pcall(function() descendants = parent:GetDescendants() end)

        for _, obj in ipairs(descendants) do
            if not visited[obj] then
                visited[obj] = true
                local isTarget = false
                pcall(function()
                    if obj:IsA("LocalScript") or obj:IsA("ModuleScript") then
                        isTarget = true
                    elseif obj:IsA("Script") and pcall(function() return obj.RunContext end) and obj.RunContext == Enum.RunContext.Client then
                        isTarget = true
                    end
                end)
                if isTarget then
                    table.insert(scriptList, obj)
                end
            end
        end
    end

    for _, container in ipairs(targetContainers) do
        collectScripts(container)
    end

    local totalScripts = #scriptList
    if totalScripts == 0 then
        notify("Code Dumper", "No accessible client scripts found.", 4)
        return
    end

    notify("Code Dumper", string.format("Found %d scripts! Decompiling to file...", totalScripts), 4)

    local dateStr = os.date("%Y-%m-%d %H:%M:%S")
    local header = string.format([[-- ==============================================================================
-- GAME CODE DUMP: %s
-- Place ID: %d | Place Version: %d
-- Generated On: %s
-- Total Scripts Dumped: %d
-- ==============================================================================

]], gameName, game.PlaceId, game.PlaceVersion, dateStr, totalScripts)

    if writeFileFunc then
        pcall(function() writeFileFunc(fileName, header) end)
    end

    local fullDumpBuffer = { header }
    local dumpedCount = 0

    for i, scr in ipairs(scriptList) do
        local scriptPath = "Unknown"
        local scriptClass = scr.ClassName or "Script"

        pcall(function() scriptPath = scr:GetFullName() end)

        local source = extractScriptSource(scr)
        local scriptBanner = string.format([[

-- ==============================================================================
-- [%d/%d] [%s] %s
-- ==============================================================================
]], i, totalScripts, scriptClass, scriptPath)

        local scriptBlock = scriptBanner .. "\n" .. source .. "\n\n"

        if appendFileFunc then
            pcall(function() appendFileFunc(fileName, scriptBlock) end)
        end
        table.insert(fullDumpBuffer, scriptBlock)

        dumpedCount = dumpedCount + 1

        -- Prevent script timeout / game lag
        if i % 5 == 0 then
            task.wait()
        end
    end

    -- Fallback to writing full buffer if appendfile isn't available
    if writeFileFunc and not appendFileFunc then
        local combined = table.concat(fullDumpBuffer, "")
        pcall(function() writeFileFunc(fileName, combined) end)
    end

    if copyToClipboard and setClipboardFunc then
        local combined = table.concat(fullDumpBuffer, "")
        setClipboardFunc(combined)
        notify("Code Dumper", string.format("Copied %d scripts to clipboard!", dumpedCount), 4)
    end

    local successMessage = string.format("Dumped %d scripts into: %s", dumpedCount, fileName)
    if writeFileFunc then
        notify("Code Dumper", "Saved: workspace/" .. fileName, 5)
    else
        notify("Code Dumper", "Decompilation complete (Console Output)", 5)
    end
    print("[Riel Code Dumper] " .. successMessage)

    return fileName
end

-- Export dump function globally for external scripts or execute immediately if standalone
_G.DumpAllGameCode = dumpAllGameCode

if not ... then
    dumpAllGameCode()
end

return dumpAllGameCode
