-- =========================================================================
-- NASI RENDANG PREMIUM - ADMIN ABUSE MODULE (AA)
-- Modul Eksternal Admin Abuse untuk Steal an Egg
-- GitHub Source: https://raw.githubusercontent.com/unclebitcoin100x-bot/waduhek/refs/heads/main/aa.lua
--
-- FITUR:
-- 1. Infinite Jump (Bisa loncat spasi berkali-kali ke langit + Collision Barrier setinggi 3000 stud di area)
-- 2. Real Godmode (Kloningan menu Real Godmode, kontrol langsung ST.realGodmode)
-- 3. Instant Carry (Fast Grab Proximity & Remote Carry di dekat telur, filter eksklusif Divine, Eternal, Secret, Cosmic)
-- 4. Rare Egg ESP (Highlight & Billboard ESP khusus Rare Eggs: Cosmic, Secret, Eternal, Divine & di atasnya)
-- =========================================================================

local ctx = ... or (getgenv and getgenv() or _G).__ADMIN_ABUSE_CTX or (getgenv and getgenv() or _G).__RIDE_GUARD_CTX
if type(ctx) ~= "table" then
    warn("[AdminAbuse] Error: Context table tidak ditemukan!")
    return
end

local UI = ctx.UI
local UIX = ctx.UIX or (UI and UI.UIX) or {}
local ST = ctx.ST or {}
local Theme = ctx.Theme or {
    Window = Color3.fromRGB(15, 17, 22),
    Panel  = Color3.fromRGB(20, 24, 32),
    Border = Color3.fromRGB(38, 45, 60),
    Text   = Color3.fromRGB(240, 242, 248),
    Muted  = Color3.fromRGB(140, 148, 168),
    Accent = Color3.fromRGB(65, 140, 255),
    Green  = Color3.fromRGB(45, 200, 110),
    Red    = Color3.fromRGB(255, 75, 75),
}
local Icons = ctx.Icons or {}
local FONT = ctx.FONT or Enum.Font.Gotham
local FONT_BOLD = ctx.FONT_BOLD or Enum.Font.GothamBold
local showToast = ctx.showToast or function(msg) print("[AdminAbuse]", msg) end
local saveConfig = ctx.saveConfig or function() end
local hrp = ctx.hrp or function()
    local lp = game:GetService("Players").LocalPlayer
    local c = lp and lp.Character
    return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("RootPart") or c.PrimaryPart)
end
local alive = ctx.alive or function()
    local lp = game:GetService("Players").LocalPlayer
    local c = lp and lp.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    return (h and h.Health > 0)
end
local EggCmds = ctx.EggCmds
local RemotesMod = ctx.RemotesMod
local AssetsDir = ctx.AssetsDir
local RarityMod = ctx.RarityMod
local trackConn = ctx.trackConn or function(c) return c end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local LP = Players.LocalPlayer

-- UI Builders dari UI table
local makePage = UI.makePage
local sectionLabel = UI.sectionLabel
local toggleRow = UI.toggleRow
local toggleDual = UI.toggleDual
local dropdownMulti = UI.dropdownMulti
local buttonRow = UI.buttonRow

if not makePage then
    warn("[AdminAbuse] Error: UI.makePage tidak tersedia!")
    return
end

-- Inisialisasi State ST jika belum ada
ST.infiniteJump = ST.infiniteJump or false
ST.instantCarry = ST.instantCarry or false
ST.rareEggESP = ST.rareEggESP or false

-- Default 4 filter rarity Instant Carry
if type(ST.instantCarryRarities) ~= "table" then
    ST.instantCarryRarities = {
        ["Divine"]  = true,
        ["Eternal"] = true,
        ["Secret"]  = true,
        ["Cosmic"]  = true,
    }
end

-- =========================================================================
-- FITUR 1: INFINITE JUMP + SKY-HIGH AREA COLLISION BARRIER
-- =========================================================================
local infJumpConn = nil
local touchJumpConn = nil
local barrierFolder = nil

local function cleanupBarriers()
    if barrierFolder and barrierFolder.Parent then
        pcall(function() barrierFolder:Destroy() end)
    end
    barrierFolder = nil
    local old = Workspace:FindFirstChild("__AdminAbuseBarriers")
    if old then pcall(function() old:Destroy() end) end
end

local function spawnBarriers()
    cleanupBarriers()
    barrierFolder = Instance.new("Folder")
    barrierFolder.Name = "__AdminAbuseBarriers"
    barrierFolder.Parent = Workspace

    -- Area Steal an Egg:
    -- X: 548 (SeparationLine) s/d 4900 (Ujung Titan Temple). Panjang = 4352, Center X = 2724
    -- Z: -450 s/d 450. Lebar = 900, Center Z = 0
    -- Y: Ground ~60 s/d 3000 stud (Setinggi mungkin!). Center Y = 1530, Tinggi = 3000
    local function createWall(name, cf, sz)
        local p = Instance.new("Part")
        p.Name = name
        p.Anchored = true
        p.CanCollide = true
        p.CanTouch = false
        p.CanQuery = false
        p.CastShadow = false
        p.Transparency = 1 -- Invisible solid wall
        p.Material = Enum.Material.SmoothPlastic
        p.Size = sz
        p.CFrame = cf
        p.Parent = barrierFolder
        return p
    end

    -- 1. Tembok Samping Utara (Z = 450)
    createWall("NorthBarrierWall", CFrame.new(2724, 1530, 450), Vector3.new(4352, 3000, 8))
    -- 2. Tembok Samping Selatan (Z = -450)
    createWall("SouthBarrierWall", CFrame.new(2724, 1530, -450), Vector3.new(4352, 3000, 8))
    -- 3. Tembok Belakang Titan Temple (X = 4900)
    createWall("EastBarrierWall", CFrame.new(4900, 1530, 0), Vector3.new(8, 3000, 900))
    -- 4. Tembok Batas Safe Zone (X = 548)
    createWall("WestBarrierWall", CFrame.new(548, 1530, 0), Vector3.new(8, 3000, 900))
    -- 5. Lantai Pengaman Void (Bawah map di Y = 48 agar tidak pernah tembus jatuh ke void dan mati)
    createWall("AntiVoidFloor", CFrame.new(2724, 48, 0), Vector3.new(4400, 6, 950))

    print("[AdminAbuse] Area Collision Containment Barrier aktif (Setinggi 3000 stud)!")
end

local function applyInfiniteJump(enabled)
    if infJumpConn then
        pcall(function() infJumpConn:Disconnect() end)
        infJumpConn = nil
    end
    if touchJumpConn then
        pcall(function() touchJumpConn:Disconnect() end)
        touchJumpConn = nil
    end

    if enabled then
        spawnBarriers()

        -- PC Spacebar Jump Hook
        infJumpConn = UserInputService.JumpRequest:Connect(function()
            if not ST.infiniteJump then return end
            local c = LP.Character
            local hum = c and c:FindFirstChildOfClass("Humanoid")
            local r = c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("RootPart") or c.PrimaryPart)
            if hum and r and hum.Health > 0 then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
                local pwr = (hum.JumpPower and hum.JumpPower > 0) and hum.JumpPower or 50
                r.AssemblyLinearVelocity = Vector3.new(r.AssemblyLinearVelocity.X, math.max(r.AssemblyLinearVelocity.Y, pwr), r.AssemblyLinearVelocity.Z)
            end
        end)

        -- Mobile Touch Jump Hook
        pcall(function()
            local pGui = LP:FindFirstChildOfClass("PlayerGui")
            local touchGui = pGui and pGui:FindFirstChild("TouchGui")
            local jumpBtn = touchGui and touchGui:FindFirstChild("TouchControlFrame") and touchGui.TouchControlFrame:FindFirstChild("JumpButton")
            if jumpBtn and jumpBtn:IsA("GuiButton") then
                touchJumpConn = jumpBtn.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch and ST.infiniteJump then
                        local c = LP.Character
                        local hum = c and c:FindFirstChildOfClass("Humanoid")
                        local r = c and (c:FindFirstChild("HumanoidRootPart") or c.PrimaryPart)
                        if hum and r and hum.Health > 0 then
                            hum:ChangeState(Enum.HumanoidStateType.Jumping)
                            local pwr = (hum.JumpPower and hum.JumpPower > 0) and hum.JumpPower or 50
                            r.AssemblyLinearVelocity = Vector3.new(r.AssemblyLinearVelocity.X, math.max(r.AssemblyLinearVelocity.Y, pwr), r.AssemblyLinearVelocity.Z)
                        end
                    end
                end)
            end
        end)
    else
        cleanupBarriers()
    end
end

-- =========================================================================
-- FITUR 3: INSTANT CARRY (FAST GRAB DENGAN STRICT RARITY FILTER)
-- =========================================================================
local _lastInstantCarryAttempt = 0

local function getEggCategory(rec)
    if not rec then return "" end
    return tostring(rec.AssetCategory or "")
end

local function getRarity(cat)
    if UIX and UIX.catRarityId then
        local r = UIX.catRarityId(cat)
        if r and r ~= "?" then return r end
    end
    local d = AssetsDir and AssetsDir.Directory and AssetsDir.Directory[cat]
    if d and d.Rarity and d.Rarity._id then
        return tostring(d.Rarity._id)
    end
    return "Common"
end

local function isPlayerCarrying()
    if UIX and UIX.myCarriedEgg and UIX.myCarriedEgg() then
        return true
    end
    local c = LP.Character
    if c then
        for _, ch in ipairs(c:GetChildren()) do
            if ch:IsA("Tool") then return true end
        end
    end
    return false
end

local function runInstantCarryCycle()
    if not ST.instantCarry or not alive() then return end
    if isPlayerCarrying() then return end
    if (os.clock() - _lastInstantCarryAttempt) < 0.25 then return end

    local r = hrp()
    if not r then return end
    local myPos = r.Position

    -- Ambil data telur terdekat
    local snap
    pcall(function()
        if EggCmds and EggCmds.RequestAreaEggSnapshot then
            snap = EggCmds.RequestAreaEggSnapshot()
        elseif EggCmds and EggCmds.GetAreaEggSnapshot then
            snap = EggCmds.GetAreaEggSnapshot()
        end
    end)
    if not (snap and snap.Records) then return end

    local slotsFolder = Workspace:FindFirstChild("AreaEggSlotsClient")
    local bestUid = nil
    local bestDist = 32 -- Radius grab instan (studs)

    for _, rec in ipairs(snap.Records) do
        if rec and rec.Uid then
            local pos = (rec.BottomCFrame and rec.BottomCFrame.Position)
                or (rec.BoundsCFrame and rec.BoundsCFrame.Position)
            if not pos and slotsFolder then
                local sm = slotsFolder:FindFirstChild(tostring(rec.Uid))
                if sm then pos = sm:GetPivot().Position end
            end

            if pos then
                local dist = (pos - myPos).Magnitude
                if dist <= bestDist then
                    local cat = getEggCategory(rec)
                    local rarity = getRarity(cat)

                    -- Filter ketat: HANYA Divine, Eternal, Secret, Cosmic
                    local isAllowed = (rarity == "Divine" or rarity == "Eternal" or rarity == "Secret" or rarity == "Cosmic")
                    if isAllowed and ST.instantCarryRarities[rarity] then
                        bestUid = rec.Uid
                        bestDist = dist
                        break -- Ambil yang pertama cocok dalam radius
                    end
                end
            end
        end
    end

    if bestUid then
        _lastInstantCarryAttempt = os.clock()
        pcall(function()
            if EggCmds and EggCmds.RequestCarryAreaEgg then
                EggCmds.RequestCarryAreaEgg(bestUid)
            end
            if slotsFolder then
                local sm = slotsFolder:FindFirstChild(tostring(bestUid))
                local prompt = sm and (sm:FindFirstChildOfClass("ProximityPrompt", true) or sm:FindFirstChild("CarryAreaEgg", true))
                if prompt and prompt.Enabled and fireproximityprompt then
                    prompt.HoldDuration = 0
                    prompt.RequiresLineOfSight = false
                    prompt.MaxActivationDistance = 9999
                    fireproximityprompt(prompt, 0)
                end
            end
        end)
    end
end

-- =========================================================================
-- FITUR 4: RARE EGG ESP (COSMIC, SECRET, ETERNAL, DIVINE)
-- =========================================================================
local espItems = {} -- uid -> { anchorPart, billboard, distLabel, titleLabel, highlight, rarity, cat }
local RARITY_COLORS = {
    ["Divine"]  = Color3.fromRGB(255, 215, 0),   -- Gold
    ["Eternal"] = Color3.fromRGB(255, 60, 60),    -- Flame Red
    ["Secret"]  = Color3.fromRGB(195, 55, 255),  -- Neon Violet
    ["Cosmic"]  = Color3.fromRGB(0, 240, 255),    -- Cyan
}

local function cleanupESP()
    for uid, data in pairs(espItems) do
        pcall(function()
            if data.billboard then data.billboard:Destroy() end
            if data.highlight then data.highlight:Destroy() end
            if data.anchorPart then data.anchorPart:Destroy() end
        end)
    end
    espItems = {}
    local oldFolder = Workspace:FindFirstChild("__RareEggESPFolder")
    if oldFolder then pcall(function() oldFolder:Destroy() end) end
end

local function getESPFolder()
    local f = Workspace:FindFirstChild("__RareEggESPFolder")
    if not f then
        f = Instance.new("Folder")
        f.Name = "__RareEggESPFolder"
        f.Parent = Workspace
    end
    return f
end

local function isRareEgg(rarity)
    if rarity == "Divine" or rarity == "Eternal" or rarity == "Secret" or rarity == "Cosmic" then
        return true
    end
    if UIX and UIX.rarityNumOf then
        local cosmicNum = UIX.rarityNumOf("Cosmic")
        local thisNum = UIX.rarityNumOf(rarity)
        if cosmicNum > 0 and thisNum >= cosmicNum then
            return true
        end
    end
    return false
end

local function runESPCycle()
    if not ST.rareEggESP then
        if next(espItems) ~= nil then cleanupESP() end
        return
    end

    local r = hrp()
    local myPos = r and r.Position or Vector3.zero

    local snap
    pcall(function()
        if EggCmds and EggCmds.RequestAreaEggSnapshot then
            snap = EggCmds.RequestAreaEggSnapshot()
        elseif EggCmds and EggCmds.GetAreaEggSnapshot then
            snap = EggCmds.GetAreaEggSnapshot()
        end
    end)

    if not (snap and snap.Records) then return end
    local activeUids = {}
    local slotsFolder = Workspace:FindFirstChild("AreaEggSlotsClient")
    local espFolder = getESPFolder()

    for _, rec in ipairs(snap.Records) do
        if rec and rec.Uid then
            local cat = getEggCategory(rec)
            local rarity = getRarity(cat)

            if isRareEgg(rarity) then
                local uidStr = tostring(rec.Uid)
                activeUids[uidStr] = true

                local pos = (rec.BottomCFrame and rec.BottomCFrame.Position)
                    or (rec.BoundsCFrame and rec.BoundsCFrame.Position)
                local model = (slotsFolder and slotsFolder:FindFirstChild(uidStr))
                    or (Workspace:FindFirstChild("PlacedEggRenders") and Workspace.PlacedEggRenders:FindFirstChild(uidStr))

                if model and not pos then
                    pos = model:GetPivot().Position
                end

                if pos then
                    local color = RARITY_COLORS[rarity] or Color3.fromRGB(255, 255, 255)
                    local dist = math.floor((pos - myPos).Magnitude + 0.5)

                    local esp = espItems[uidStr]
                    if not esp then
                        -- Buat objek ESP baru
                        local anchor = Instance.new("Part")
                        anchor.Name = "ESPAnchor_" .. uidStr
                        anchor.Size = Vector3.new(1, 1, 1)
                        anchor.Transparency = 1
                        anchor.Anchored = true
                        anchor.CanCollide = false
                        anchor.CanTouch = false
                        anchor.CanQuery = false
                        anchor.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
                        anchor.Parent = espFolder

                        local bb = Instance.new("BillboardGui")
                        bb.Name = "ESPBillboard"
                        bb.Adornee = anchor
                        bb.Size = UDim2.new(0, 160, 0, 50)
                        bb.StudsOffset = Vector3.new(0, 2, 0)
                        bb.AlwaysOnTop = true
                        bb.MaxDistance = 5000
                        bb.Parent = anchor

                        local title = Instance.new("TextLabel")
                        title.Name = "Title"
                        title.Size = UDim2.new(1, 0, 0, 18)
                        title.BackgroundTransparency = 1
                        title.Font = FONT_BOLD
                        title.TextSize = 13
                        title.TextColor3 = color
                        title.TextStrokeTransparency = 0.2
                        title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                        title.Text = "[" .. rarity:upper() .. "] " .. cat
                        title.Parent = bb

                        local distLbl = Instance.new("TextLabel")
                        distLbl.Name = "Dist"
                        distLbl.Size = UDim2.new(1, 0, 0, 14)
                        distLbl.Position = UDim2.new(0, 0, 0, 18)
                        distLbl.BackgroundTransparency = 1
                        distLbl.Font = FONT
                        distLbl.TextSize = 11
                        distLbl.TextColor3 = Color3.fromRGB(220, 225, 240)
                        distLbl.TextStrokeTransparency = 0.3
                        distLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                        distLbl.Text = tostring(dist) .. " studs"
                        distLbl.Parent = bb

                        local hl = nil
                        if model and model:IsA("Model") then
                            hl = Instance.new("Highlight")
                            hl.Name = "ESPHighlight"
                            hl.FillColor = color
                            hl.FillTransparency = 0.75
                            hl.OutlineColor = color
                            hl.OutlineTransparency = 0.1
                            hl.Adornee = model
                            hl.Parent = model
                        end

                        espItems[uidStr] = {
                            anchorPart = anchor,
                            billboard  = bb,
                            distLabel  = distLbl,
                            titleLabel = title,
                            highlight  = hl,
                            rarity     = rarity,
                            cat        = cat,
                        }
                    else
                        -- Update posisi & jarak
                        if esp.anchorPart then
                            esp.anchorPart.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
                        end
                        if esp.distLabel then
                            esp.distLabel.Text = tostring(dist) .. " studs"
                        end
                    end
                end
            end
        end
    end

    -- Hapus ESP untuk telur yang sudah hilang/terambil
    for uidStr, esp in pairs(espItems) do
        if not activeUids[uidStr] then
            pcall(function()
                if esp.anchorPart then esp.anchorPart:Destroy() end
                if esp.highlight then esp.highlight:Destroy() end
            end)
            espItems[uidStr] = nil
        end
    end
end

-- =========================================================================
-- LOOP BACKGROUND WORKER (Instant Carry & ESP Ticker)
-- =========================================================================
task.spawn(function()
    while true do
        task.wait(0.08)
        pcall(runInstantCarryCycle)
    end
end)

task.spawn(function()
    while true do
        task.wait(0.2)
        pcall(runESPCycle)
    end
end)

-- Character Added Listener (Re-apply Infinite Jump & Cleanups on Respawn)
trackConn(LP.CharacterAdded:Connect(function()
    task.wait(0.5)
    if ST.infiniteJump then
        applyInfiniteJump(true)
    end
end))

-- =========================================================================
-- BUILD UI PAGE: "Admin Abuse"
-- =========================================================================
local aaPage = makePage("Admin Abuse")
local o = 0
local function n() o = o + 1 return o end

sectionLabel(aaPage, "Admin Abuse & Exploits", n())

-- 1. Infinite Jump + Area Barrier Toggle
toggleRow(aaPage, "Infinite Jump (Space to Sky)", n(), function(on)
    ST.infiniteJump = on
    applyInfiniteJump(on)
    saveConfig()
    showToast("Infinite Jump: " .. (on and "ON (Barrier 3000 stud Active)" or "OFF"))
end, ST.infiniteJump, "Loncat spasi tanpa batas ke langit + Dinding collision setinggi 3000 stud di area mencegah jatuh/mati")

-- 2. Real Godmode Toggle (Kloningan langsung dari Real Godmode menu utama)
toggleRow(aaPage, "Real Godmode", n(), function(on)
    ST.realGodmode = on
    saveConfig()
    showToast("Real Godmode: " .. (on and "ON" or "OFF"))
end, ST.realGodmode, "Anti-Stun, True Anti-Ragdoll, Anti-Knockback & Auto Bat Defense di Area Telur")

sectionLabel(aaPage, "Instant Carry (Fast Grab)", n())

-- 3. Instant Carry Toggle
toggleRow(aaPage, "Instant Carry (Near Eggs)", n(), function(on)
    ST.instantCarry = on
    saveConfig()
    showToast("Instant Carry: " .. (on and "ON (Filter Active)" or "OFF"))
end, ST.instantCarry, "Nge-carry telur secara instan saat dekat telur (hanya berlaku untuk rarity yang dipilih di bawah)")

-- 3b. Filter Rarity untuk Instant Carry (Divine, Eternal, Secret, Cosmic)
dropdownMulti(
    aaPage,
    "Instant Carry Rarities",
    n(),
    function()
        return {
            { key = "Divine",  label = "Divine" },
            { key = "Eternal", label = "Eternal" },
            { key = "Secret",  label = "Secret" },
            { key = "Cosmic",  label = "Cosmic" },
        }
    end,
    ST.instantCarryRarities,
    function()
        saveConfig()
    end,
    nil
)

sectionLabel(aaPage, "Visual ESP", n())

-- 4. Rare Egg ESP Toggle
toggleRow(aaPage, "Rare Egg ESP", n(), function(on)
    ST.rareEggESP = on
    if not on then cleanupESP() end
    saveConfig()
    showToast("Rare Egg ESP: " .. (on and "ON" or "OFF"))
end, ST.rareEggESP, "Highlight & Nametag 3D hanya untuk telur langka (Cosmic, Secret, Eternal, Divine & di atasnya)")

print("[AdminAbuse] Module loaded & Admin Abuse page ready!")

return aaPage
