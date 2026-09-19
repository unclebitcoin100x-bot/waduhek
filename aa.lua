-- RING2

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

-- UI Builders dari UI / UIX table
local makePage = (UI and UI.makePage) or (UIX and UIX.makePage)
local sectionLabel = (UI and UI.sectionLabel) or (UIX and UIX.sectionLabel)
local toggleRow = (UI and UI.toggleRow) or (UIX and UIX.toggleRow)
local toggleDual = (UI and UI.toggleDual) or (UIX and UIX.toggleDual)
local dropdownMulti = (UI and UI.dropdownMulti) or (UIX and UIX.dropdownMulti)
local buttonRow = (UI and UI.buttonRow) or (UIX and UIX.buttonRow)

if not makePage then
    warn("[AdminAbuse] Error: makePage tidak tersedia di UI maupun UIX!")
    return
end

-- Inisialisasi State ST jika belum ada
ST.infiniteJump = ST.infiniteJump or false
ST.instantCarry = ST.instantCarry or false
ST.rareEggESP = ST.rareEggESP or false
ST.autoCollectRings = ST.autoCollectRings or false

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

    -- Area Steal an Egg (Termasuk Area Light Dark & Ujung Timur Map):
    -- X: 548 (SeparationLine / Pintu Masuk Safe Zone) s/d 8200 (Melewati seluruh area Light Dark). Panjang = 7652 stud
    -- Z: -900 s/d 500 (Mencakup seluruh koridor dan biome selatan Light Dark). Lebar = 1400 stud, Center Z = -200
    -- Y: Ground ~60 s/d 170 stud (Ceiling limit Y=170, Floor Y=45). Center Y = 109, Tinggi = 122
    local function createWall(name, cf, sz)
        local p = Instance.new("Part")
        p.Name = name
        p.Anchored = true
        p.CanCollide = true
        p.CanTouch = false
        p.CanQuery = false
        p.CastShadow = false
        p.Transparency = 1 -- Invisible solid wall/floor/ceiling
        p.Material = Enum.Material.SmoothPlastic
        p.Size = sz
        p.CFrame = cf
        p.Parent = barrierFolder
        return p
    end

    -- 4 Segmen sepanjang X = 548 s/d 8200 (Masing-masing 1950 stud agar tidak mentok limit 2048 stud engine)
    local segments = {
        { cX = 1523, szX = 1950 }, -- Segmen 1: Safe Zone boundary s/d Jungle
        { cX = 3473, szX = 1950 }, -- Segmen 2: Cherry & Cosmic
        { cX = 5423, szX = 1950 }, -- Segmen 3: Titan Temple s/d Light Dark
        { cX = 7225, szX = 1950 }, -- Segmen 4: Light Dark s/d Ujung Timur Map
    }

    for i, seg in ipairs(segments) do
        -- 1. Tembok Samping Utara (Batas luar map Z = 500, Y = 48 s/d 170)
        createWall("NorthBarrierWall_" .. i, CFrame.new(seg.cX, 109, 500), Vector3.new(seg.szX, 122, 8))
        -- 2. Tembok Samping Selatan (Batas luar map Z = -900, Y = 48 s/d 170)
        createWall("SouthBarrierWall_" .. i, CFrame.new(seg.cX, 109, -900), Vector3.new(seg.szX, 122, 8))
        -- 4. Lantai Pengaman Void (Bawah map di Y = 45 agar tidak pernah jatuh ke void)
        createWall("AntiVoidFloor_" .. i, CFrame.new(seg.cX, 45, -200), Vector3.new(seg.szX, 6, 1450))
        -- 5. Plafon Langit / Atap Anti-Death Ceiling (Y = 170 agar kepala mentok aman)
        createWall("AntiKillCeiling_" .. i, CFrame.new(seg.cX, 170, -200), Vector3.new(seg.szX, 6, 1450))
    end

    -- 3. Tembok Belakang Ujung Timur Map (Dipasang di X = 8200 SETELAH Light Dark, bukan di X = 4900!)
    createWall("EastBarrierWall", CFrame.new(8200, 109, -200), Vector3.new(8, 122, 1450))
    -- CATATAN: Pintu masuk Safe Zone (X = 548) 100% TERBUKA! Tidak ada tembok penghalang Safe Zone!

    print("[AdminAbuse] Area Barrier aktif (Tembok Utara/Selatan/Timur X=8200, Plafon Y=170, Area Light Dark Terbuka Penuh)!")
end

local inputJumpConn = nil

local function applyInfiniteJump(enabled)
    if infJumpConn then
        pcall(function() infJumpConn:Disconnect() end)
        infJumpConn = nil
    end
    if inputJumpConn then
        pcall(function() inputJumpConn:Disconnect() end)
        inputJumpConn = nil
    end
    if touchJumpConn then
        pcall(function() touchJumpConn:Disconnect() end)
        touchJumpConn = nil
    end

    if enabled then
        spawnBarriers()

        local function doAirJump()
            local c = LP.Character
            local hum = c and c:FindFirstChildOfClass("Humanoid")
            local r = c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("RootPart") or c.PrimaryPart)
            if hum and r and hum.Health > 0 then
                -- Batasi ketinggian maksimal di Y = 170 (clamp di Y >= 168) agar mentok aman di plafon
                if r.Position.Y >= 168 then
                    r.AssemblyLinearVelocity = Vector3.new(r.AssemblyLinearVelocity.X, math.min(r.AssemblyLinearVelocity.Y, 0), r.AssemblyLinearVelocity.Z)
                    return
                end
                local pwr = (hum.JumpPower and hum.JumpPower > 0) and hum.JumpPower or 52
                r.AssemblyLinearVelocity = Vector3.new(r.AssemblyLinearVelocity.X, math.max(r.AssemblyLinearVelocity.Y, pwr), r.AssemblyLinearVelocity.Z)
                hum.Jump = true
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end

        -- 1. InputBegan Hook (Mencegat tombol Spasi di udara; Roblox JumpRequest TIDAK TERPANGGIL saat Freefall)
        inputJumpConn = UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if not ST.infiniteJump then return end
            if input.KeyCode == Enum.KeyCode.Space or (input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.ButtonA) then
                doAirJump()
            end
        end)

        -- 2. Engine JumpRequest Hook (Cadangan saat menyentuh lantai/tangga)
        infJumpConn = UserInputService.JumpRequest:Connect(function()
            if not ST.infiniteJump then return end
            doAirJump()
        end)

        -- 3. Mobile Touch Jump Hook (Tombol loncat TouchGui di layar HP)
        pcall(function()
            local pGui = LP:FindFirstChildOfClass("PlayerGui")
            local touchGui = pGui and pGui:FindFirstChild("TouchGui")
            local jumpBtn = touchGui and touchGui:FindFirstChild("TouchControlFrame") and touchGui.TouchControlFrame:FindFirstChild("JumpButton")
            if jumpBtn and jumpBtn:IsA("GuiButton") then
                touchJumpConn = jumpBtn.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch and ST.infiniteJump then
                        doAirJump()
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
    -- 1. Ambil ID telur yang tercatat sedang dipegang
    local heldUid = nil
    if UIX and UIX.myCarriedEgg then
        heldUid = UIX.myCarriedEgg()
    end

    if not heldUid and EggCmds and EggCmds.GetAreaEggSnapshot then
        local ok, snap = pcall(EggCmds.GetAreaEggSnapshot)
        if ok and snap and snap.Records then
            local myId = LP.UserId
            for _, r in ipairs(snap.Records) do
                if r.State == "Carried" and r.CarrierUserId == myId then
                    heldUid = r.Uid
                    break
                end
            end
        end
    end

    -- 2. Jika tidak ada heldUid, player pasti TIDAK sedang carry -> Instant Carry aktif!
    if not heldUid then
        return false
    end

    -- 3. Verifikasi apakah telur yang dipegang BENAR-BENAR belum tersimpan/ter-steal di safe zone:
    local rec = nil
    pcall(function()
        if EggCmds and EggCmds.GetAreaEggRecord then
            rec = EggCmds.GetAreaEggRecord(heldUid)
        end
    end)

    -- Jika record nil, atau statusnya bukan "Carried" (misal sudah "Claimed"), atau CarrierUserId bukan kita:
    -- Berarti telur sudah sukses tersimpan / ke-steal di safe zone -> Player bebas untuk carry lagi!
    if not rec or rec.State ~= "Carried" or rec.CarrierUserId ~= LP.UserId then
        if UIX then UIX._lastHeldUid = nil end
        return false
    end

    -- Telur valid dan masih dalam status dibawa (belum selesai ke-steal)
    return true
end

local function runInstantCarryCycle()
    if not ST.instantCarry or not alive() then return end
    -- Hanya abaikan jika player BENAR-BENAR sedang membawa telur yang belum ke-steal
    if isPlayerCarrying() then return end
    if (os.clock() - _lastInstantCarryAttempt) < 0.2 then return end

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
    local bestDist = 36 -- Radius grab instan (studs)

    for _, rec in ipairs(snap.Records) do
        if rec and rec.Uid then
            -- Pastikan telur ini belum di-claim dan belum dibawa player lain!
            local state = rec.State
            local isAvailable = (state == "Slot" or state == "Dropped" or (state ~= "Claimed" and (rec.CarrierUserId == nil or rec.CarrierUserId == 0)))
            if isAvailable then
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
    end

    if bestUid then
        _lastInstantCarryAttempt = os.clock()
        pcall(function()
            if EggCmds and EggCmds.RequestCarryAreaEgg then
                EggCmds.RequestCarryAreaEgg(bestUid)
            end

            -- Trigger langsung ProximityPrompt CarryAreaEgg di SmartPromptPart Workspace jika ada dalam jangkauan
            for _, d in ipairs(Workspace:GetDescendants()) do
                if d:IsA("ProximityPrompt") and d.Name == "CarryAreaEgg" then
                    local part = d.Parent
                    if part and part:IsA("BasePart") and (part.Position - myPos).Magnitude <= 35 then
                        d.HoldDuration = 0
                        d.RequiresLineOfSight = false
                        d.MaxActivationDistance = 9999
                        if fireproximityprompt then
                            fireproximityprompt(d, 0)
                        end
                    end
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

-- =========================================================================
-- FITUR 5: AUTO COLLECT RINGS (SPEED-SWEEP GLIDE & MAGNET FARM - LVD EVENT)
-- =========================================================================
local ringSweepThread = nil
local ringEventConns = {}
local activeWaveData = {
    waveId = nil,
    zone = "LightDark",
    rings = {},
    powerUps = {}
}

local function getLvdRemotes()
    local ok, remotes = pcall(function()
        return require(game:GetService("ReplicatedStorage").Shared.Remotes)
    end)
    if ok and remotes and remotes.LightVsDarkness then
        return remotes.LightVsDarkness
    end
    return nil
end

local function ensureLvdTeam(lvdRemotes)
    local team = LP:GetAttribute("LvdTeam")
    if type(team) ~= "string" or team == "" then
        pcall(function()
            lvdRemotes.AskSelectTeam:FireServer("Random")
        end)
    end
end

local _lastMilestoneCheck = 0
local function checkClaimMilestones(lvdRemotes)
    local now = os.clock()
    if (now - _lastMilestoneCheck) < 3.5 then return end
    _lastMilestoneCheck = now
    pcall(function()
        lvdRemotes.AskClaimMilestone:FireServer(1)
        lvdRemotes.AskClaimMilestone:FireServer(2)
        lvdRemotes.AskClaimMilestone:FireServer(3)
    end)
end

local function refreshRingsFromServer(lvdRemotes)
    pcall(function()
        local wId, z, rTbl, pTbl = lvdRemotes.FetchRings:InvokeServer()
        if type(wId) == "number" then
            activeWaveData.waveId = wId
            activeWaveData.zone = z or activeWaveData.zone
            if type(rTbl) == "table" then
                activeWaveData.rings = rTbl
            end
            if type(pTbl) == "table" then
                activeWaveData.powerUps = pTbl
            end
        end
    end)
end

local function stopRingSweep()
    if ringSweepThread then
        task.cancel(ringSweepThread)
        ringSweepThread = nil
    end
    for _, conn in ipairs(ringEventConns) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(ringEventConns)

    local c = LP.Character
    local r = c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("RootPart") or c.PrimaryPart)
    if r then
        r.AssemblyLinearVelocity = Vector3.zero
    end
end

local function startRingSweepLoop()
    if ringSweepThread then return end
    ringSweepThread = task.spawn(function()
        local lvdRemotes = getLvdRemotes()
        if not lvdRemotes then
            warn("[RingCollector] Remotes LightVsDarkness tidak ditemukan!")
            return
        end

        ensureLvdTeam(lvdRemotes)
        refreshRingsFromServer(lvdRemotes)

        while ST.autoCollectRings do
            local char = LP.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local r = char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("RootPart") or char.PrimaryPart)

            if hum and r and hum.Health > 0 then
                ensureLvdTeam(lvdRemotes)
                checkClaimMilestones(lvdRemotes)

                local targetPos = nil
                local targetType = nil
                local targetId = nil

                local charPos = r.Position

                -- 1. Prioritas PowerUps (Magnet / x2)
                if activeWaveData.powerUps and type(activeWaveData.powerUps) == "table" then
                    for pId, pData in pairs(activeWaveData.powerUps) do
                        if type(pData) == "table" and pData.X and pData.Y and pData.Z then
                            targetPos = Vector3.new(pData.X, pData.Y, pData.Z)
                            targetType = "PowerUp"
                            targetId = pId
                            break
                        end
                    end
                end

                -- 2. Jika tidak ada PowerUp, cari Ring dengan Score tertinggi (Rarity tinggi & Jarak terdekat)
                if not targetPos and activeWaveData.rings and type(activeWaveData.rings) == "table" then
                    local bestScore = -999999
                    for rId, rData in pairs(activeWaveData.rings) do
                        if type(rData) == "table" and rData.X and rData.Y and rData.Z then
                            local pos = Vector3.new(rData.X, rData.Y, rData.Z)
                            local dist = (pos - charPos).Magnitude
                            local rarity = tonumber(rData.Rarity) or 1
                            local score = (rarity * 350) - dist
                            if score > bestScore then
                                bestScore = score
                                targetPos = pos
                                targetType = "Ring"
                                targetId = rId
                            end
                        end
                    end
                end

                -- 3. Fallback: Deteksi part visual di Workspace.LightVsDarknessRings jika table server kosong
                if not targetPos then
                    local wFolder = Workspace:FindFirstChild("LightVsDarknessRings")
                    if wFolder then
                        local nearestDist = 999999
                        for _, part in ipairs(wFolder:GetChildren()) do
                            if part:IsA("BasePart") then
                                local dist = (part.Position - charPos).Magnitude
                                if dist < nearestDist then
                                    nearestDist = dist
                                    targetPos = part.Position
                                    targetType = "PhysicalRing"
                                    targetId = part.Name
                                end
                            end
                        end
                    end
                end

                -- 4. Eksekusi Glide Cepat (Speed-Sweep) ke Posisi Target
                if targetPos then
                    local dist = (targetPos - r.Position).Magnitude
                    local sweepSpeed = 280 -- studs per second: cepat, stabil & aman dari kick
                    local stepTime = 0.03
                    local maxSteps = math.clamp(math.ceil(dist / (sweepSpeed * stepTime)), 1, 60)

                    for step = 1, maxSteps do
                        if not ST.autoCollectRings or not alive() then break end
                        local curPos = r.Position
                        local curDist = (targetPos - curPos).Magnitude

                        -- Jika sudah dalam radius serap (35-40 stud), tembak collect remote
                        if curDist <= 40 and activeWaveData.waveId then
                            if targetType == "PowerUp" then
                                lvdRemotes.AskCollectPowerUp:FireServer(activeWaveData.waveId, targetId)
                                if activeWaveData.powerUps then activeWaveData.powerUps[targetId] = nil end
                            else
                                lvdRemotes.AskCollectRing:FireServer(activeWaveData.waveId, activeWaveData.zone, targetId)
                                if activeWaveData.rings then activeWaveData.rings[targetId] = nil end
                            end
                        end

                        if curDist <= 10 then break end

                        local nextPos = curPos:Lerp(targetPos, math.clamp((step / maxSteps) * 1.5, 0, 1))
                        r.CFrame = CFrame.new(nextPos, nextPos + (targetPos - curPos).Unit)
                        r.AssemblyLinearVelocity = Vector3.zero
                        task.wait(stepTime)
                    end

                    -- Konfirmasi collect remote saat di target
                    if activeWaveData.waveId then
                        if targetType == "PowerUp" then
                            lvdRemotes.AskCollectPowerUp:FireServer(activeWaveData.waveId, targetId)
                            if activeWaveData.powerUps then activeWaveData.powerUps[targetId] = nil end
                        else
                            lvdRemotes.AskCollectRing:FireServer(activeWaveData.waveId, activeWaveData.zone, targetId)
                            if activeWaveData.rings then activeWaveData.rings[targetId] = nil end
                        end
                    end
                else
                    -- Jika sedang tidak ada ring/wave, refresh berkala
                    refreshRingsFromServer(lvdRemotes)
                    task.wait(1.5)
                end
            else
                task.wait(0.5)
            end
            task.wait(0.02)
        end

        local c = LP.Character
        local r = c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("RootPart") or c.PrimaryPart)
        if r then
            r.AssemblyLinearVelocity = Vector3.zero
        end
        ringSweepThread = nil
    end)
end

local function applyAutoCollectRings(enabled)
    stopRingSweep()
    if enabled then
        local lvdRemotes = getLvdRemotes()
        if lvdRemotes then
            local c1 = lvdRemotes.RingsSpawned.OnClientEvent:Connect(function(wId, z, rTbl, pTbl)
                activeWaveData.waveId = wId
                activeWaveData.zone = z or activeWaveData.zone
                activeWaveData.rings = (type(rTbl) == "table") and rTbl or {}
                activeWaveData.powerUps = (type(pTbl) == "table") and pTbl or {}
            end)
            local c2 = lvdRemotes.RingCollected.OnClientEvent:Connect(function(collector, rId)
                if activeWaveData.rings and activeWaveData.rings[rId] then
                    activeWaveData.rings[rId] = nil
                end
            end)
            local c3 = lvdRemotes.RingsCleared.OnClientEvent:Connect(function(wId)
                if activeWaveData.waveId == wId then
                    activeWaveData.rings = {}
                    activeWaveData.powerUps = {}
                    activeWaveData.waveId = nil
                end
            end)
            table.insert(ringEventConns, c1)
            table.insert(ringEventConns, c2)
            table.insert(ringEventConns, c3)
            trackConn(c1)
            trackConn(c2)
            trackConn(c3)
        end
        startRingSweepLoop()
    end
end

-- Character Added Listener (Re-apply Infinite Jump & Cleanups on Respawn)
trackConn(LP.CharacterAdded:Connect(function()
    task.wait(0.5)
    if ST.infiniteJump then
        applyInfiniteJump(true)
    end
    if ST.autoCollectRings then
        applyAutoCollectRings(true)
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
    showToast("Infinite Jump: " .. (on and "ON (Ceiling Cap Y=170 Active)" or "OFF"))
end, ST.infiniteJump)

-- 2. Real Godmode Toggle (Kloningan langsung dari Real Godmode menu utama)
toggleRow(aaPage, "Real Godmode", n(), function(on)
    ST.realGodmode = on
    saveConfig()
    showToast("Real Godmode: " .. (on and "ON" or "OFF"))
end, ST.realGodmode)

sectionLabel(aaPage, "Instant Carry (Fast Grab)", n())

-- 3. Instant Carry Toggle
toggleRow(aaPage, "Instant Carry (Near Eggs)", n(), function(on)
    ST.instantCarry = on
    saveConfig()
    showToast("Instant Carry: " .. (on and "ON (Filter Active)" or "OFF"))
end, ST.instantCarry)

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
end, ST.rareEggESP)

sectionLabel(aaPage, "Light vs Darkness (Event Farm)", n())

-- 5. Auto Collect Rings (Speed-Sweep Glide) Toggle
toggleRow(aaPage, "Auto Collect Rings (Speed-Sweep)", n(), function(on)
    ST.autoCollectRings = on
    applyAutoCollectRings(on)
    saveConfig()
    showToast("Ring Collector: " .. (on and "ON (Speed-Sweep Active)" or "OFF"))
end, ST.autoCollectRings)

print("[AdminAbuse] Module loaded & Admin Abuse page ready!")

return aaPage
