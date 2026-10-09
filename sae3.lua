--[[
    Steal an Egg — fetch shim.

    This file is NOT the script. It trades a key that already passed
    verification in the loader for the real script body, which lives outside
    the server's docroot and has no public URL at all.

    What guards the door is the key check on the server, NOT the obfuscation
    in here. This file is public: anyone can read it, and anyone running the
    loader can see where it points by watching outbound traffic. The
    scrambling below only slows down a casual reader; it hides nothing from
    someone serious.
]]

local HttpService = game:GetService("HttpService")
local Players     = game:GetService("Players")
local StarterGui  = game:GetService("StarterGui")
local LP          = Players.LocalPlayer or Players.PlayerAdded:Wait()

--[[ Failures MUST surface themselves.

     The loader reports "Loaded" BEFORE it runs this chunk (fetchAndRun,
     around line 1525), then runs it inside task.spawn and swallows runtime
     errors into a console warn(). So if this file only called error(), the
     buyer would see "Steal an Egg loaded.", watch the loader close, and get
     nothing — with no visible reason. Every key problem would turn into the
     same "script doesn't work" ticket.

     The notification is the channel a buyer actually sees; the warn stays so
     there is still a console trail for us. ]]
local function fail(message)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title    = "Steal an Egg — load failed",
            Text     = message,
            Duration = 12,
        })
    end)
    warn("[SAE] " .. message)
    error("SAE: " .. message, 0)
end

-- The executor's HTTP function. game:HttpGet is deliberately not used: it can
-- only do GET, and the key has to travel in the request BODY, not the URL.
local httpRequest = (syn and syn.request)
    or (http and http.request)
    or http_request
    or request
    or (fluxus and fluxus.request)

if type(httpRequest) ~= "function" then
    fail("This executor has no request() — use a different executor")
end

--[[ The endpoint, assembled at runtime.

     Split up so the full address does not show up when this file is skimmed
     or grepped. Kept deliberately this simple: the first version used a
     hand-rolled base64 decoder, which traded real reliability for fake
     security — one wrong bit operation and NOBODY can run the script, while
     the protection is still zero. The key check on the server is what
     guards this, not the lines below. ]]
local function endpoint()
    local scheme = ("sptth"):reverse()
    local host   = { "www", "nrlscript", "com" }

    return scheme .. "://" .. host[1] .. "." .. host[2] .. "." .. host[3]
        .. "/" .. ("ipa"):reverse() .. "/" .. ("eas"):reverse()
end

-- The key is read from where the loader stores it after a successful check.
-- Format is `key|timestamp|tier|expiry`; only the first field is needed.
local function cachedKey()
    local ok, contents = pcall(readfile, "nr_loader_key.txt")
    if not ok or type(contents) ~= "string" then return nil end

    local key = contents:match("^([^|%s]+)")

    return (key and #key >= 6) and key or nil
end

-- MUST match machineId() in the loader exactly. If it differs, the server
-- treats this as a new device and burns one of the buyer's HWID slots.
local function machineId()
    local ok, id = pcall(function() return gethwid() end)
    if ok and type(id) == "string" and id ~= "" then return id end

    return "uid-" .. tostring(LP.UserId)
end

local key = cachedKey()
if not key then
    fail("No key found — open the loader and enter your key first")
end

local sent, res = pcall(httpRequest, {
    Url     = endpoint(),
    Method  = "POST",
    Headers = { ["Content-Type"] = "application/json" },
    Body    = HttpService:JSONEncode({ key = key, hwid = machineId() }),
})

if not sent or type(res) ~= "table" then
    fail("Could not reach the server — check your connection")
end

local status = tonumber(res.StatusCode) or 0
local body   = tostring(res.Body or "")

if status ~= 200 then
    --[[ Check the status code FIRST.

         Only 403 sends a single reason word; 429, 503 and 405 send English
         sentences ("too many requests, try again later", "script
         unavailable, contact staff"). Treating those as reason words would
         leak the raw server text straight to the buyer. ]]
    if status == 429 then
        fail("Loading too often — wait a few minutes")
    elseif status == 503 then
        fail("Script is unavailable right now — contact an admin")
    elseif status ~= 403 then
        fail("Server refused the request (HTTP " .. status .. ")")
    end

    --[[ 403: map the server's reason word one by one. "expired" and "used on
         another device" need different actions from the buyer, and collapsing
         them into one "access denied" turns every problem into the same
         support question. ]]
    local reason = body:match("^%-%-%s*(.-)%s*$") or ""

    fail(({
        malformed     = "Invalid key format",
        not_found     = "Key is not registered",
        revoked       = "Key has been revoked",
        expired       = "Key has expired — please renew it",
        hwid_required = "Could not read your device ID",
        hwid_limit    = "Key is already in use on another device",
    })[reason] or ("Access denied (" .. reason .. ")"))
end

if #body < 1000 then
    fail("Server response was incomplete (" .. #body .. " bytes)")
end

local chunk, compileErr = loadstring(body)
if not chunk then
    fail("Script failed to compile — " .. tostring(compileErr))
end

return chunk()
