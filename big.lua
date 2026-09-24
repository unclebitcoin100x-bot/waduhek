--[[
s
]]

-- ------------------------------------------------------------------------------
-- 01. SINGLETON & CLEANUP GUARD
-- ------------------------------------------------------------------------------
local RUN_ID = os.clock()
getgenv().__BIG_EGG_SESSION = RUN_ID

local CoreGui       = game:GetService("CoreGui")
local Players       = game:GetService("Players")
local HttpService   = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local RunService    = game:GetService("RunService")
local GuiService    = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer   = Players.LocalPlayer or Players.PlayerAdded:Wait()
local PLACE_ID      = game.PlaceId
local GITHUB_LOADER = "https://raw.githubusercontent.com/unclebitcoin100x-bot/waduhek/refs/heads/main/big.lua"

-- Cleanup old GUI if present
pcall(function()
    local oldGui = CoreGui:FindFirstChild("BigEggHunterGui") or (gethui and gethui():FindFirstChild("BigEggHunterGui"))
    if oldGui then oldGui:Destroy() end
end)

-- ------------------------------------------------------------------------------
-- 02. CONFIGURATION & PERSISTENCE
-- ------------------------------------------------------------------------------
local CFG_FOLDER = "BigEgg"
local CFG_FILE   = CFG_FOLDER .. "/config.json"

local Config = {
    MinKg        = 1000000, -- Default 1,000,000 KG
    VpsUrl       = "",      -- Endpoint on VPS e.g. http://123.45.67.89:8080/api/big-egg
    WebhookUrl   = "https://discord.com/api/webhooks/1552819671693009049/pXwUhw1epIWuUD4quqL_1ssajOBAM-HGyFa-_xqHM45NAIaWniV21GYUuW0eXZ3xSpFG",
    AutoHop      = true,    -- Auto hop active
    HopInterval  = 4,      -- 15 seconds per server
    LastKnownEgg = "None",
    TotalFound   = 0,
}

local function saveConfig()
    pcall(function()
        if type(makefolder) == "function" and not isfolder(CFG_FOLDER) then
            pcall(makefolder, CFG_FOLDER)
        end
        if type(writefile) == "function" then
            writefile(CFG_FILE, HttpService:JSONEncode(Config))
        end
    end)
end

local function loadConfig()
    pcall(function()
        if type(readfile) == "function" and isfile(CFG_FILE) then
            local raw = readfile(CFG_FILE)
            if raw and #raw > 0 then
                local data = HttpService:JSONDecode(raw)
                if type(data) == "table" then
                    for k, v in pairs(data) do
                        Config[k] = v
                    end
                end
            end
        end
    end)
    if not Config.WebhookUrl or Config.WebhookUrl == "" then
        Config.WebhookUrl = "https://discord.com/api/webhooks/1552786020947202053/pZSyB3MtrGQHCAy4TO6qL-5gryCWDrmqPCBNphvC_VKD2JuwotbVb7Hm9nsXzhtrWpxB"
    end
end
loadConfig()

-- ------------------------------------------------------------------------------
-- 03. UTILITY HELPERS
-- ------------------------------------------------------------------------------
local function parseKg(input)
    if type(input) == "number" then return input end
    local s = tostring(input or ""):lower():gsub("[%s,%$]", "")
    local _, dots = s:gsub("%.", "")
    if dots > 1 then s = s:gsub("%.", "") end
    if s == "" then return 0 end
    local num, suffix = s:match("^(%-?%d*%.?%d+)([kmbtq]?)$")
    local mults = { k = 1e3, m = 1e6, b = 1e9, t = 1e12, q = 1e15 }
    if not num then return tonumber(s) or 0 end
    return (tonumber(num) or 0) * (mults[suffix] or 1)
end

local function formatKg(val)
    local n = tonumber(val) or 0
    if n >= 1e9 then return string.format("%.2fB KG", n / 1e9) end
    if n >= 1e6 then return string.format("%.2fM KG", n / 1e6) end
    if n >= 1e3 then return string.format("%.1fK KG", n / 1e3) end
    return string.format("%d KG", math.floor(n))
end

local function commaValue(amount)
    local formatted = tostring(math.floor(tonumber(amount) or 0))
    local k
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if k == 0 then break end
    end
    return formatted
end

local function httpRequest(options)
    local fn = request or http_request or (syn and syn.request) or (fluxus and fluxus.request) or (http and http.request)
    if type(fn) == "function" then
        local ok, res = pcall(fn, options)
        if ok and res then return res end
    end
    return nil
end

-- ------------------------------------------------------------------------------
-- 04. GAME DATA & WEIGHT CALCULATOR
-- ------------------------------------------------------------------------------
local AssetsModule = nil
pcall(function()
    local dataFolder = ReplicatedStorage:FindFirstChild("Data")
    local assetsObj = dataFolder and dataFolder:FindFirstChild("Assets")
    if assetsObj then
        local ok, res = pcall(require, assetsObj)
        if ok and res then AssetsModule = res end
    end
end)

local function getEggAssetData(cat)
    if AssetsModule and AssetsModule.Directory and AssetsModule.Directory[cat] then
        return AssetsModule.Directory[cat]
    end
    return nil
end

local function resolveAreaFromPos(pos)
    if not pos then return "Unknown" end
    local x = pos.X
    -- Area boundaries along X axis in Steal An Egg
    if x < 400 then return "Forest"
    elseif x < 750 then return "Lake"
    elseif x < 1150 then return "Desert"
    elseif x < 1550 then return "Jungle"
    elseif x < 1900 then return "Snow"
    elseif x < 2350 then return "Volcano"
    elseif x < 2750 then return "Abyss Ocean"
    elseif x < 3200 then return "Prehistoric"
    elseif x < 3700 then return "Cosmic"
    elseif x < 4300 then return "Cherry Blossom"
    else return "Titan Temple" end
end

local function computeEggWeight(rec)
    local cat = tostring(rec.AssetCategory or "")
    local scale = tonumber(rec.AssetScale) or 1
    local d = getEggAssetData(cat)
    local mw = (d and type(d.ModelWeight) == "number") and d.ModelWeight or (tonumber(rec.ModelWeight) or 1)
    local calculated = mw * (math.max(scale, 0) ^ 3)
    if tonumber(rec.WeightKg) and tonumber(rec.WeightKg) > calculated then
        return tonumber(rec.WeightKg)
    end
    return calculated
end

-- ------------------------------------------------------------------------------
-- 05. QUEUE ON TELEPORT & AUTO EXECUTE RETENTION
-- ------------------------------------------------------------------------------
local function armTeleportQueue()
    local qot = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
    if type(qot) ~= "function" then
        warn("[BigEgg] queue_on_teleport not available on this executor.")
        return
    end

    local code = string.format([[
        if getgenv().__BIG_EGG_BOOTSTRAPPED then return end
        getgenv().__BIG_EGG_BOOTSTRAPPED = true
        task.spawn(function()
            pcall(function()
                if not game:IsLoaded() then game.Loaded:Wait() end
            end)
            task.wait(2.5)
            local url = %q
            local src = nil
            for attempt = 1, 5 do
                local ok, res = pcall(function()
                    return game:HttpGet(url .. "?ts=" .. tostring(os.time()))
                end)
                if ok and type(res) == "string" and #res > 50 then
                    src = res
                    break
                end
                task.wait(2)
            end
            if src then
                local fn, err = loadstring(src)
                if fn then
                    pcall(fn)
                    return
                end
            end
            -- Local fallback
            if type(readfile) == "function" and isfile("BigEgg/big.lua") then
                local localSrc = readfile("BigEgg/big.lua")
                if localSrc and #localSrc > 50 then
                    local fn2 = loadstring(localSrc)
                    if fn2 then pcall(fn2) end
                end
            end
        end)
    ]], GITHUB_LOADER)

    pcall(qot, code)
end

-- ------------------------------------------------------------------------------
-- 06. ANTI-DISCONNECT & AUTO-RECONNECT ENGINE
-- ------------------------------------------------------------------------------
local function initAutoReconnect()
    local reconnecting = false
    local function doReconnect(reason)
        if reconnecting then return end
        reconnecting = true
        warn("[BigEgg-Reconnect] Triggered: " .. tostring(reason))
        armTeleportQueue()

        task.spawn(function()
            task.wait(1.5)
            -- Attempt native button click
            pcall(function()
                local promptOverlay = CoreGui:FindFirstChild("RobloxPromptGui") and CoreGui.RobloxPromptGui:FindFirstChild("promptOverlay")
                local ep = promptOverlay and promptOverlay:FindFirstChild("ErrorPrompt")
                local btnArea = ep and ep:FindFirstChild("MessageArea") and ep.MessageArea:FindFirstChild("ErrorFrame") and ep.MessageArea.ErrorFrame:FindFirstChild("ButtonArea")
                local recBtn = btnArea and btnArea:FindFirstChild("ReconnectButton")
                if recBtn and recBtn:IsA("ImageButton") and recBtn.Visible then
                    if typeof(firesignal) == "function" then
                        firesignal(recBtn.Activated)
                        firesignal(recBtn.MouseButton1Click)
                    end
                end
            end)

            task.wait(2)
            pcall(function()
                TeleportService:Teleport(PLACE_ID, LocalPlayer)
            end)

            task.delay(10, function()
                reconnecting = false
            end)
        end)
    end

    pcall(function()
        GuiService.ErrorMessageChanged:Connect(function(msg)
            if msg and #msg > 0 then
                doReconnect("GuiService: " .. tostring(msg))
            end
        end)
    end)

    pcall(function()
        local rPrompt = CoreGui:FindFirstChild("RobloxPromptGui")
        local function checkOverlay(overlay)
            if not overlay then return end
            overlay.ChildAdded:Connect(function(c)
                if c.Name == "ErrorPrompt" or c:FindFirstChild("MessageArea") or c:FindFirstChild("ErrorTitle") then
                    doReconnect("ErrorPrompt detected")
                end
            end)
            if overlay:FindFirstChild("ErrorPrompt") then
                doReconnect("ErrorPrompt existing")
            end
        end
        if rPrompt then
            checkOverlay(rPrompt:FindFirstChild("promptOverlay"))
            rPrompt.ChildAdded:Connect(function(c)
                if c.Name == "promptOverlay" then checkOverlay(c) end
            end)
        end
    end)
end
initAutoReconnect()

-- ------------------------------------------------------------------------------
-- 07. COMPACT MODERN HUD (MINIMALIST & DRAGGABLE)
-- ------------------------------------------------------------------------------
local function getGuiParent()
    if type(gethui) == "function" then
        local h = gethui()
        if h then return h end
    end
    return CoreGui
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BigEggHunterGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = getGuiParent()

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.fromOffset(270, 310)
MainFrame.Position = UDim2.new(0.02, 0, 0.25, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 17, 23)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner", MainFrame)
UICorner.CornerRadius = UDim.new(0, 10)

local UIStroke = Instance.new("UIStroke", MainFrame)
UIStroke.Color = Color3.fromRGB(35, 42, 56)
UIStroke.Thickness = 1.2

-- Dragging Functionality
do
    local dragging, dragStart, startPos
    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- Header
local Header = Instance.new("Frame", MainFrame)
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 32)
Header.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
Header.BorderSizePixel = 0

local HeaderCorner = Instance.new("UICorner", Header)
HeaderCorner.CornerRadius = UDim.new(0, 10)

local Dot = Instance.new("Frame", Header)
Dot.Size = UDim2.fromOffset(7, 7)
Dot.Position = UDim2.new(0, 10, 0.5, -3)
Dot.BackgroundColor3 = Color3.fromRGB(72, 199, 116)
Dot.BorderSizePixel = 0
local DotCorner = Instance.new("UICorner", Dot)
DotCorner.CornerRadius = UDim.new(1, 0)

local TitleLbl = Instance.new("TextLabel", Header)
TitleLbl.Size = UDim2.new(1, -65, 1, 0)
TitleLbl.Position = UDim2.new(0, 24, 0, 0)
TitleLbl.BackgroundTransparency = 1
TitleLbl.Text = "BIG EGG SCANNER"
TitleLbl.TextColor3 = Color3.fromRGB(240, 243, 246)
TitleLbl.TextSize = 11
TitleLbl.Font = Enum.Font.GothamBold
TitleLbl.TextXAlignment = Enum.TextXAlignment.Left

-- Minimize button
local MinBtn = Instance.new("TextButton", Header)
MinBtn.Size = UDim2.fromOffset(24, 24)
MinBtn.Position = UDim2.new(1, -28, 0.5, -12)
MinBtn.BackgroundColor3 = Color3.fromRGB(28, 33, 46)
MinBtn.BorderSizePixel = 0
MinBtn.Text = "—"
MinBtn.TextColor3 = Color3.fromRGB(180, 190, 205)
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 12
local MinCorner = Instance.new("UICorner", MinBtn)
MinCorner.CornerRadius = UDim.new(0, 6)

-- Collapsed Pill View
local Pill = Instance.new("TextButton", ScreenGui)
Pill.Name = "CollapsedPill"
Pill.Size = UDim2.fromOffset(160, 30)
Pill.Position = MainFrame.Position
Pill.BackgroundColor3 = Color3.fromRGB(15, 17, 23)
Pill.BorderSizePixel = 0
Pill.Text = "🥚 BIG SCAN  15s"
Pill.TextColor3 = Color3.fromRGB(240, 243, 246)
Pill.Font = Enum.Font.GothamBold
Pill.TextSize = 11
Pill.Visible = false
local PillCorner = Instance.new("UICorner", Pill)
PillCorner.CornerRadius = UDim.new(0, 15)
local PillStroke = Instance.new("UIStroke", Pill)
PillStroke.Color = Color3.fromRGB(56, 139, 253)
PillStroke.Thickness = 1.2

local isMinimized = false
local function toggleMinimize()
    isMinimized = not isMinimized
    if isMinimized then
        Pill.Position = MainFrame.Position
        MainFrame.Visible = false
        Pill.Visible = true
    else
        MainFrame.Position = Pill.Position
        MainFrame.Visible = true
        Pill.Visible = false
    end
end
MinBtn.MouseButton1Click:Connect(toggleMinimize)
Pill.MouseButton1Click:Connect(toggleMinimize)

-- Content Container
local Content = Instance.new("Frame", MainFrame)
Content.Name = "Content"
Content.Size = UDim2.new(1, -16, 1, -40)
Content.Position = UDim2.new(0, 8, 0, 36)
Content.BackgroundTransparency = 1

local UIList = Instance.new("UIListLayout", Content)
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Padding = UDim.new(0, 6)

-- 1. Status Bar Card
local StatusCard = Instance.new("Frame", Content)
StatusCard.Size = UDim2.new(1, 0, 0, 26)
StatusCard.BackgroundColor3 = Color3.fromRGB(22, 27, 38)
StatusCard.BorderSizePixel = 0
StatusCard.LayoutOrder = 1
local ScCorner = Instance.new("UICorner", StatusCard)
ScCorner.CornerRadius = UDim.new(0, 6)

local StatusText = Instance.new("TextLabel", StatusCard)
StatusText.Size = UDim2.new(1, -12, 1, 0)
StatusText.Position = UDim2.new(0, 8, 0, 0)
StatusText.BackgroundTransparency = 1
StatusText.Text = "STATUS: INITIALIZING..."
StatusText.TextColor3 = Color3.fromRGB(88, 166, 255)
StatusText.Font = Enum.Font.GothamBold
StatusText.TextSize = 10
StatusText.TextXAlignment = Enum.TextXAlignment.Left

-- 2. Target Minimum KG Input
local InputRow1 = Instance.new("Frame", Content)
InputRow1.Size = UDim2.new(1, 0, 0, 26)
InputRow1.BackgroundColor3 = Color3.fromRGB(22, 27, 38)
InputRow1.BorderSizePixel = 0
InputRow1.LayoutOrder = 2
local Ir1Corner = Instance.new("UICorner", InputRow1)
Ir1Corner.CornerRadius = UDim.new(0, 6)

local Ir1Lbl = Instance.new("TextLabel", InputRow1)
Ir1Lbl.Size = UDim2.new(0, 75, 1, 0)
Ir1Lbl.Position = UDim2.new(0, 8, 0, 0)
Ir1Lbl.BackgroundTransparency = 1
Ir1Lbl.Text = "MIN WEIGHT:"
Ir1Lbl.TextColor3 = Color3.fromRGB(150, 160, 175)
Ir1Lbl.Font = Enum.Font.GothamSemibold
Ir1Lbl.TextSize = 9.5
Ir1Lbl.TextXAlignment = Enum.TextXAlignment.Left

local KgInput = Instance.new("TextBox", InputRow1)
KgInput.Size = UDim2.new(1, -90, 1, -6)
KgInput.Position = UDim2.new(0, 84, 0, 3)
KgInput.BackgroundColor3 = Color3.fromRGB(15, 17, 23)
KgInput.BorderSizePixel = 0
KgInput.Text = commaValue(Config.MinKg)
KgInput.TextColor3 = Color3.fromRGB(255, 203, 107)
KgInput.Font = Enum.Font.GothamBold
KgInput.TextSize = 10
KgInput.PlaceholderText = "1M / 1,000,000"
local KgCorner = Instance.new("UICorner", KgInput)
KgCorner.CornerRadius = UDim.new(0, 4)

KgInput.FocusLost:Connect(function()
    local parsed = parseKg(KgInput.Text)
    if parsed > 0 then
        Config.MinKg = parsed
        KgInput.Text = commaValue(parsed)
        saveConfig()
    else
        KgInput.Text = commaValue(Config.MinKg)
    end
end)

-- 3. VPS URL Input
local InputRow2 = Instance.new("Frame", Content)
InputRow2.Size = UDim2.new(1, 0, 0, 26)
InputRow2.BackgroundColor3 = Color3.fromRGB(22, 27, 38)
InputRow2.BorderSizePixel = 0
InputRow2.LayoutOrder = 3
local Ir2Corner = Instance.new("UICorner", InputRow2)
Ir2Corner.CornerRadius = UDim.new(0, 6)

local Ir2Lbl = Instance.new("TextLabel", InputRow2)
Ir2Lbl.Size = UDim2.new(0, 75, 1, 0)
Ir2Lbl.Position = UDim2.new(0, 8, 0, 0)
Ir2Lbl.BackgroundTransparency = 1
Ir2Lbl.Text = "VPS ENDPOINT:"
Ir2Lbl.TextColor3 = Color3.fromRGB(150, 160, 175)
Ir2Lbl.Font = Enum.Font.GothamSemibold
Ir2Lbl.TextSize = 9.5
Ir2Lbl.TextXAlignment = Enum.TextXAlignment.Left

local VpsInput = Instance.new("TextBox", InputRow2)
VpsInput.Size = UDim2.new(1, -90, 1, -6)
VpsInput.Position = UDim2.new(0, 84, 0, 3)
VpsInput.BackgroundColor3 = Color3.fromRGB(15, 17, 23)
VpsInput.BorderSizePixel = 0
VpsInput.Text = Config.VpsUrl or ""
VpsInput.TextColor3 = Color3.fromRGB(240, 243, 246)
VpsInput.Font = Enum.Font.Code
VpsInput.TextSize = 9
VpsInput.ClearTextOnFocus = false
VpsInput.PlaceholderText = "http://ip:port/api/egg"
local VpsCorner = Instance.new("UICorner", VpsInput)
VpsCorner.CornerRadius = UDim.new(0, 4)

VpsInput.FocusLost:Connect(function()
    Config.VpsUrl = string.gsub(VpsInput.Text, "%s+", "")
    saveConfig()
end)

-- 4. Latest Egg Alert Card
local AlertCard = Instance.new("Frame", Content)
AlertCard.Size = UDim2.new(1, 0, 0, 74)
AlertCard.BackgroundColor3 = Color3.fromRGB(22, 27, 38)
AlertCard.BorderSizePixel = 0
AlertCard.LayoutOrder = 4
local AcCorner = Instance.new("UICorner", AlertCard)
AcCorner.CornerRadius = UDim.new(0, 6)
local AcStroke = Instance.new("UIStroke", AlertCard)
AcStroke.Color = Color3.fromRGB(45, 55, 75)
AcStroke.Thickness = 1

local AcHead = Instance.new("TextLabel", AlertCard)
AcHead.Size = UDim2.new(1, -12, 0, 16)
AcHead.Position = UDim2.new(0, 8, 0, 4)
AcHead.BackgroundTransparency = 1
AcHead.Text = "LATEST BIG EGG:"
AcHead.TextColor3 = Color3.fromRGB(130, 140, 155)
AcHead.Font = Enum.Font.GothamBold
AcHead.TextSize = 9
AcHead.TextXAlignment = Enum.TextXAlignment.Left

local AcEggName = Instance.new("TextLabel", AlertCard)
AcEggName.Size = UDim2.new(1, -12, 0, 18)
AcEggName.Position = UDim2.new(0, 8, 0, 20)
AcEggName.BackgroundTransparency = 1
AcEggName.Text = Config.LastKnownEgg or "None Found Yet"
AcEggName.TextColor3 = Color3.fromRGB(255, 215, 0)
AcEggName.Font = Enum.Font.GothamBold
AcEggName.TextSize = 11.5
AcEggName.TextXAlignment = Enum.TextXAlignment.Left

local AcEggMeta = Instance.new("TextLabel", AlertCard)
AcEggMeta.Size = UDim2.new(1, -12, 0, 16)
AcEggMeta.Position = UDim2.new(0, 8, 0, 38)
AcEggMeta.BackgroundTransparency = 1
AcEggMeta.Text = string.format("Job: %s... | Plrs: %d", string.sub(game.JobId, 1, 8), #Players:GetPlayers())
AcEggMeta.TextColor3 = Color3.fromRGB(160, 170, 185)
AcEggMeta.Font = Enum.Font.Code
AcEggMeta.TextSize = 9
AcEggMeta.TextXAlignment = Enum.TextXAlignment.Left

local AcVpsStatus = Instance.new("TextLabel", AlertCard)
AcVpsStatus.Size = UDim2.new(1, -12, 0, 14)
AcVpsStatus.Position = UDim2.new(0, 8, 0, 54)
AcVpsStatus.BackgroundTransparency = 1
AcVpsStatus.Text = "VPS Dispatch: Idle"
AcVpsStatus.TextColor3 = Color3.fromRGB(120, 130, 145)
AcVpsStatus.Font = Enum.Font.Gotham
AcVpsStatus.TextSize = 8.5
AcVpsStatus.TextXAlignment = Enum.TextXAlignment.Left

-- 5. Toggle Row (Auto Hop)
local ToggleRow = Instance.new("Frame", Content)
ToggleRow.Size = UDim2.new(1, 0, 0, 28)
ToggleRow.BackgroundColor3 = Color3.fromRGB(22, 27, 38)
ToggleRow.BorderSizePixel = 0
ToggleRow.LayoutOrder = 5
local TrCorner = Instance.new("UICorner", ToggleRow)
TrCorner.CornerRadius = UDim.new(0, 6)

local TrLbl = Instance.new("TextLabel", ToggleRow)
TrLbl.Size = UDim2.new(1, -65, 1, 0)
TrLbl.Position = UDim2.new(0, 8, 0, 0)
TrLbl.BackgroundTransparency = 1
TrLbl.Text = "AUTO SERVER HOP (15s)"
TrLbl.TextColor3 = Color3.fromRGB(240, 243, 246)
TrLbl.Font = Enum.Font.GothamBold
TrLbl.TextSize = 9.5
TrLbl.TextXAlignment = Enum.TextXAlignment.Left

local ToggleBtn = Instance.new("TextButton", ToggleRow)
ToggleBtn.Size = UDim2.fromOffset(46, 20)
ToggleBtn.Position = UDim2.new(1, -52, 0.5, -10)
ToggleBtn.BackgroundColor3 = Config.AutoHop and Color3.fromRGB(35, 134, 54) or Color3.fromRGB(48, 54, 61)
ToggleBtn.BorderSizePixel = 0
ToggleBtn.Text = Config.AutoHop and "ON" or "OFF"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.TextSize = 9.5
local TbCorner = Instance.new("UICorner", ToggleBtn)
TbCorner.CornerRadius = UDim.new(0, 10)

ToggleBtn.MouseButton1Click:Connect(function()
    Config.AutoHop = not Config.AutoHop
    ToggleBtn.BackgroundColor3 = Config.AutoHop and Color3.fromRGB(35, 134, 54) or Color3.fromRGB(48, 54, 61)
    ToggleBtn.Text = Config.AutoHop and "ON" or "OFF"
    saveConfig()
end)

-- 6. Action Buttons Row (Scan Now & Hop Now)
local BtnRow = Instance.new("Frame", Content)
BtnRow.Size = UDim2.new(1, 0, 0, 28)
BtnRow.BackgroundTransparency = 1
BtnRow.BorderSizePixel = 0
BtnRow.LayoutOrder = 6

local ScanBtn = Instance.new("TextButton", BtnRow)
ScanBtn.Size = UDim2.new(0.48, 0, 1, 0)
ScanBtn.BackgroundColor3 = Color3.fromRGB(31, 111, 235)
ScanBtn.BorderSizePixel = 0
ScanBtn.Text = "SCAN NOW"
ScanBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ScanBtn.Font = Enum.Font.GothamBold
ScanBtn.TextSize = 9.5
local SbCorner = Instance.new("UICorner", ScanBtn)
SbCorner.CornerRadius = UDim.new(0, 6)

local HopBtn = Instance.new("TextButton", BtnRow)
HopBtn.Size = UDim2.new(0.48, 0, 1, 0)
HopBtn.Position = UDim2.new(0.52, 0, 0, 0)
HopBtn.BackgroundColor3 = Color3.fromRGB(137, 87, 229)
HopBtn.BorderSizePixel = 0
HopBtn.Text = "HOP NOW"
HopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
HopBtn.Font = Enum.Font.GothamBold
HopBtn.TextSize = 9.5
local HbCorner = Instance.new("UICorner", HopBtn)
HbCorner.CornerRadius = UDim.new(0, 6)

-- ------------------------------------------------------------------------------
-- 08. VPS DISPATCHER
-- ------------------------------------------------------------------------------
local function dispatchToVps(eggInfo)
    if not Config.VpsUrl or Config.VpsUrl == "" then
        AcVpsStatus.Text = "VPS Dispatch: Skipped (No URL)"
        AcVpsStatus.TextColor3 = Color3.fromRGB(150, 160, 175)
        return
    end

    AcVpsStatus.Text = "VPS Dispatch: Sending POST..."
    AcVpsStatus.TextColor3 = Color3.fromRGB(88, 166, 255)

    local payload = {
        event           = "BIG_EGG_DISCOVERED",
        placeId         = PLACE_ID,
        jobId           = game.JobId,
        serverPlayers   = #Players:GetPlayers(),
        timestamp       = os.time(),
        isoTime         = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        egg = {
            name            = eggInfo.name,
            weightKg        = eggInfo.weightKg,
            weightFormatted = eggInfo.weightFormatted,
            area            = eggInfo.area,
            rarity          = eggInfo.rarity,
            scale           = eggInfo.scale,
            uid             = eggInfo.uid,
        },
        joinScript = string.format("game:GetService('TeleportService'):TeleportToPlaceInstance(%d, %q, game.Players.LocalPlayer)", PLACE_ID, game.JobId)
    }

    local encoded = HttpService:JSONEncode(payload)
    task.spawn(function()
        local res = httpRequest({
            Url = Config.VpsUrl,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = encoded
        })

        if res and (res.StatusCode == 200 or res.StatusCode == 201 or res.StatusCode == 204 or res.Success) then
            AcVpsStatus.Text = string.format("VPS: Sent (%d OK)", res.StatusCode or 200)
            AcVpsStatus.TextColor3 = Color3.fromRGB(72, 199, 116)
        else
            local code = res and res.StatusCode or "Err"
            AcVpsStatus.Text = string.format("VPS: Failed (%s)", tostring(code))
            AcVpsStatus.TextColor3 = Color3.fromRGB(248, 81, 73)
        end
    end)
end

-- ------------------------------------------------------------------------------
-- 08B. DISCORD WEBHOOK CONTAINER DISPATCHER
-- ------------------------------------------------------------------------------
local DEFAULT_WEBHOOK_URL = "https://discord.com/api/webhooks/1552786020947202053/pZSyB3MtrGQHCAy4TO6qL-5gryCWDrmqPCBNphvC_VKD2JuwotbVb7Hm9nsXzhtrWpxB"
local sentEggAlerts = {}

local function sendDiscordWebhook(eggInfo)
    local targetUrl = (Config.WebhookUrl and #Config.WebhookUrl > 10) and Config.WebhookUrl or DEFAULT_WEBHOOK_URL
    if not targetUrl or #targetUrl < 15 then return end

    local alertKey = tostring(eggInfo.uid) .. "_" .. tostring(game.JobId)
    if sentEggAlerts[alertKey] then return end
    sentEggAlerts[alertKey] = true

    task.spawn(function()
        local tpCmd = string.format("game:GetService('TeleportService'):TeleportToPlaceInstance(%d, %q, game.Players.LocalPlayer)", PLACE_ID, game.JobId)
        local webJoinUrl = string.format("https://www.roblox.com/games/start?placeId=%d&gameInstanceId=%s", PLACE_ID, game.JobId)

        local embed = {
            title = "🦖 MASSIVE EGG DETECTED!",
            url = webJoinUrl, -- Clicking the title also opens the server directly
            description = string.format("A giant egg exceeding **%s** threshold has been discovered in this server!", formatKg(Config.MinKg)),
            color = 16753920, -- Gold / Orange Accent Container
            timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            fields = {
                {
                    name = "🥚 Egg Category",
                    value = string.format("```yaml\n%s\n```", tostring(eggInfo.name)),
                    inline = true
                },
                {
                    name = "⚖️ Weight",
                    value = string.format("```fix\n%s\n```", tostring(eggInfo.weightFormatted)),
                    inline = true
                },
                {
                    name = "🗺️ Location Area",
                    value = string.format("```ini\n[%s]\n```", tostring(eggInfo.area)),
                    inline = true
                },
                {
                    name = "🌟 Rarity",
                    value = string.format("`%s`", tostring(eggInfo.rarity or "Unknown")),
                    inline = true
                },
                {
                    name = "👥 Server Players",
                    value = string.format("`%d / %d`", #Players:GetPlayers(), Players.MaxPlayers or 8),
                    inline = true
                },
                {
                    name = "🔍 Model Scale",
                    value = string.format("`x%.2f`", tonumber(eggInfo.scale) or 1),
                    inline = true
                },
                {
                    name = "🆔 Server JobId",
                    value = string.format("`%s`", tostring(game.JobId)),
                    inline = false
                },
                {
                    name = "🌐 Web Join Link",
                    value = string.format("[👉 **Click Here to Join Game Server (Browser)**](%s)", webJoinUrl),
                    inline = false
                },
                {
                    name = "🚀 Direct Teleport Script (Volt / Potassium / Syn)",
                    value = string.format("```lua\n%s\n```", tpCmd),
                    inline = false
                }
            },
            footer = {
                text = "Steal An Egg • Big Egg Scanner v1.0"
            }
        }

        local payload = {
            content = string.format("🚨 **BIG EGG ALERT:** **%s** (%s) in **%s**! @here", tostring(eggInfo.name), tostring(eggInfo.weightFormatted), tostring(eggInfo.area)),
            embeds = { embed },
            components = {
                {
                    type = 1, -- Action Row
                    components = {
                        {
                            type = 2, -- Button
                            style = 5, -- Link Style
                            label = "🎮 Join Server (Roblox)",
                            url = webJoinUrl
                        }
                    }
                }
            }
        }

        local encoded = HttpService:JSONEncode(payload)
        local res = httpRequest({
            Url = targetUrl,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = encoded
        })

        if res and (res.StatusCode == 200 or res.StatusCode == 204 or res.Success) then
            AcVpsStatus.Text = "Alert: Webhook Sent (204 OK)"
            AcVpsStatus.TextColor3 = Color3.fromRGB(72, 199, 116)
            print(string.format("[BigEgg] Webhook Embed dispatched successfully for %s (%s)", tostring(eggInfo.name), tostring(eggInfo.weightFormatted)))
        else
            local code = res and res.StatusCode or "Err"
            AcVpsStatus.Text = string.format("Alert: Webhook Fail (%s)", tostring(code))
            AcVpsStatus.TextColor3 = Color3.fromRGB(248, 81, 73)
            warn(string.format("[BigEgg] Webhook delivery failed with code: %s", tostring(code)))
        end
    end)
end

-- ------------------------------------------------------------------------------
-- 09. EGG SCANNER ENGINE
-- ------------------------------------------------------------------------------
local function fetchEggSnapshot()
    -- 1. Try Packages.Networking
    local packages = ReplicatedStorage:FindFirstChild("Packages")
    local networking = packages and packages:FindFirstChild("Networking")
    local rf = networking and (networking:FindFirstChild("RF/EggWorld/AskFieldEggSnapshot") or networking:FindFirstChild("Eggs: GetAreaEggSnapshot"))
    if rf and rf:IsA("RemoteFunction") then
        local ok, res = pcall(function() return rf:InvokeServer() end)
        if ok and type(res) == "table" and type(res.Records) == "table" then
            return res.Records
        end
    end

    -- 2. Try Shared.Remotes
    local shared = ReplicatedStorage:FindFirstChild("Shared")
    local remotes = shared and shared:FindFirstChild("Remotes")
    local eggWorld = remotes and remotes:FindFirstChild("EggWorld")
    local askSnap = eggWorld and eggWorld:FindFirstChild("AskFieldEggSnapshot")
    if askSnap and askSnap:IsA("RemoteFunction") then
        local ok, res = pcall(function() return askSnap:InvokeServer() end)
        if ok and type(res) == "table" and type(res.Records) == "table" then
            return res.Records
        end
    end

    return {}
end

local function scanFieldEggs()
    StatusText.Text = "STATUS: SCANNING EGGS..."
    StatusText.TextColor3 = Color3.fromRGB(88, 166, 255)

    local records = fetchEggSnapshot()
    local foundMatch = false
    local biggestInServer = nil
    local maxWeightInServer = 0

    for _, rec in pairs(records) do
        local cat = tostring(rec.AssetCategory or "Unknown")
        local weight = computeEggWeight(rec)
        local d = getEggAssetData(cat)
        local pos = (typeof(rec.BottomCFrame) == "CFrame" and rec.BottomCFrame.Position) or Vector3.zero
        local area = tostring(rec.AreaId or (d and (d.Area or d.AreaId)) or resolveAreaFromPos(pos))
        local rarity = tostring(d and d.Rarity and (d.Rarity._id or d.Rarity.Rank) or "Unknown")

        if weight > maxWeightInServer then
            maxWeightInServer = weight
            biggestInServer = {
                name = cat,
                weightKg = weight,
                weightFormatted = formatKg(weight),
                area = string.upper(area),
                rarity = rarity,
                scale = tonumber(rec.AssetScale) or 1,
                uid = tostring(rec.Uid or ""),
            }
        end

        if weight >= Config.MinKg then
            foundMatch = true
            Config.TotalFound = (Config.TotalFound or 0) + 1
            local summary = string.format("%s - %s - %s", cat, formatKg(weight), string.upper(area))
            Config.LastKnownEgg = summary
            saveConfig()

            AcEggName.Text = summary
            AcEggName.TextColor3 = Color3.fromRGB(255, 215, 0)
            AcEggMeta.Text = string.format("Job: %s... | Plrs: %d", string.sub(game.JobId, 1, 8), #Players:GetPlayers())
            StatusText.Text = "STATUS: MATCH FOUND! DISPATCHING..."
            StatusText.TextColor3 = Color3.fromRGB(72, 199, 116)

            print(string.format("[BigEgg] MATCH: %s (Weight: %s) in Area %s! Server JobId: %s", cat, formatKg(weight), area, game.JobId))
            local matchData = {
                name = cat,
                weightKg = weight,
                weightFormatted = formatKg(weight),
                area = string.upper(area),
                rarity = rarity,
                scale = tonumber(rec.AssetScale) or 1,
                uid = tostring(rec.Uid or "")
            }
            dispatchToVps(matchData)
            sendDiscordWebhook(matchData)
            break
        end
    end

    if not foundMatch then
        if biggestInServer then
            StatusText.Text = string.format("STATUS: HIGHEST %s", formatKg(maxWeightInServer))
            StatusText.TextColor3 = Color3.fromRGB(255, 203, 107)
        else
            StatusText.Text = "STATUS: NO EGGS IN SNAPSHOT"
            StatusText.TextColor3 = Color3.fromRGB(150, 160, 175)
        end
    end
end
ScanBtn.MouseButton1Click:Connect(scanFieldEggs)

-- ------------------------------------------------------------------------------
-- 10. RESILIENT SERVER HOP ENGINE (FEWEST PLAYERS)
-- ------------------------------------------------------------------------------
local hopping = false
local serverCache = {}
local lastServerFetch = 0

local function fetchEmptiestServers()
    local now = os.clock()
    if #serverCache > 0 and (now - lastServerFetch) < 15 then
        return serverCache
    end

    local function getRaw(url)
        local fn = request or http_request or (syn and syn.request) or (fluxus and fluxus.request)
        if type(fn) == "function" then
            local ok, res = pcall(fn, { Url = url, Method = "GET" })
            if ok and res and type(res.Body) == "string" and #res.Body > 0 then
                return res.Body
            end
        end
        local ok2, res2 = pcall(game.HttpGet, game, url)
        if ok2 and type(res2) == "string" and #res2 > 0 then
            return res2
        end
        return nil
    end

    local list = {}
    local cursor = ""
    for _ = 1, 6 do
        local url = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100%s",
            PLACE_ID, cursor ~= "" and ("&cursor=" .. HttpService:UrlEncode(cursor)) or "")
        local body = getRaw(url)
        if not body then break end

        local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
        if not ok or type(data) ~= "table" or type(data.data) ~= "table" then break end

        for _, s in ipairs(data.data) do
            if s.id and s.id ~= game.JobId and type(s.playing) == "number" and s.playing > 0 and s.playing < (s.maxPlayers or 999) then
                table.insert(list, s)
            end
        end

        if #list >= 40 then break end
        if type(data.nextPageCursor) == "string" and data.nextPageCursor ~= "" then
            cursor = data.nextPageCursor
        else
            break
        end
    end

    -- Sort strictly ascending by playing count (fewest players first)
    table.sort(list, function(a, b)
        if a.playing == b.playing then
            return (a.ping or 999) < (b.ping or 999)
        end
        return a.playing < b.playing
    end)

    lastServerFetch = now
    serverCache = list
    return list
end

local function executeServerHop()
    if hopping then return end
    hopping = true
    StatusText.Text = "STATUS: PREPARING HOP..."
    StatusText.TextColor3 = Color3.fromRGB(187, 128, 255)

    -- Arm auto-execute retention before teleport
    armTeleportQueue()

    local servers = fetchEmptiestServers()
    if #servers == 0 then
        StatusText.Text = "STATUS: NO SERVERS FOUND (RETRYING)"
        StatusText.TextColor3 = Color3.fromRGB(248, 81, 73)
        hopping = false
        lastServerFetch = 0
        return
    end

    -- Group the lowest player count tier
    local lowestPlaying = servers[1].playing
    local candidates = {}
    for _, s in ipairs(servers) do
        if s.playing <= (lowestPlaying + 1) then
            table.insert(candidates, s)
        end
    end
    if #candidates == 0 then candidates = servers end

    -- Shuffle slightly within the lowest tier to avoid colliding on identical stale server
    for i = #candidates, 2, -1 do
        local j = math.random(i)
        candidates[i], candidates[j] = candidates[j], candidates[i]
    end

    local idx = 0
    local conn = nil

    local function tryNextCandidate()
        idx = idx + 1
        local target = candidates[idx]
        if not target then
            if conn then conn:Disconnect() end
            hopping = false
            lastServerFetch = 0
            StatusText.Text = "STATUS: ALL TARGETS EXHAUSTED"
            return
        end

        StatusText.Text = string.format("HOPPING -> %d PLAYERS...", target.playing)
        StatusText.TextColor3 = Color3.fromRGB(137, 87, 229)
        getgenv().__SAE_ALLOW_TP = true

        pcall(function()
            TeleportService:TeleportToPlaceInstance(PLACE_ID, target.id, LocalPlayer)
        end)
    end

    conn = TeleportService.TeleportInitFailed:Connect(function(plr)
        if plr == LocalPlayer then
            warn("[BigEgg] Teleport failed, attempting next lowest player server...")
            tryNextCandidate()
        end
    end)

    tryNextCandidate()

    -- 25s timeout watchdog: reset hopping flag if teleport hung
    task.delay(25, function()
        if hopping then
            hopping = false
            lastServerFetch = 0
            if conn then pcall(function() conn:Disconnect() end) end
            StatusText.Text = "STATUS: HOP TIMED OUT, RETRYING"
        end
    end)
end
HopBtn.MouseButton1Click:Connect(executeServerHop)

-- ------------------------------------------------------------------------------
-- 11. MAIN AUTOMATION CYCLE (15s COUNTDOWN)
-- ------------------------------------------------------------------------------
task.spawn(function()
    -- Allow initial game streaming to load
    task.wait(2.5)
    scanFieldEggs()

    local countdown = Config.HopInterval or 15

    while getgenv().__BIG_EGG_SESSION == RUN_ID do
        task.wait(1)

        if Config.AutoHop and not hopping then
            countdown = countdown - 1

            if countdown <= 0 then
                countdown = Config.HopInterval or 15
                executeServerHop()
            else
                StatusText.Text = string.format("STATUS: NEXT HOP IN %ds", countdown)
                Pill.Text = string.format("🥚 BIG SCAN  %ds", countdown)
            end
        elseif not Config.AutoHop then
            countdown = Config.HopInterval or 15
            Pill.Text = "🥚 BIG SCAN  OFF"
        end
    end
end)

print(string.format("[BigEgg] Initialized v1.0 | MinKg: %s | AutoHop: %s | Place: %d",
    formatKg(Config.MinKg), tostring(Config.AutoHop), PLACE_ID))
