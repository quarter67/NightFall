--[[
    NightFall Loader v5
    Share this file via loadstring — do NOT share improved_script.lua directly.

    Design rules (mobile / Delta safe):
    - Key UI appears immediately — no character wait, no download wait, no fullscreen overlay on mobile
    - Never disables game touch controls or destroys anything except our own NightFallKeyUI
    - Movement unlock runs in the background the whole time
]]

local VERSION = "5.0.0"
local BUILD = "2026-05-27-rewrite"

local CONFIG = {
    PLACE_ID = 134225461562780,
    API_FALLBACK = "https://visual-mayor-corrected-dancing.trycloudflare.com",
    API_URL_TXT = "https://raw.githubusercontent.com/quarter67/NightFall/main/api-url.txt",
    KEY_FILE = "ScriptHub/nightfall_key.txt",
    MAX_ATTEMPTS = 5,
    HTTP_TIMEOUT = 18,
    KEYLESS_URLS = {
        "https://raw.githubusercontent.com/quarter67/NightFall/main/homelandertest.lua",
        "https://raw.githubusercontent.com/quarter67/NightFall/main/script/improved_script.lua",
        "https://raw.githubusercontent.com/quarter67/NightFall/main/improved_script.lua",
    },
}

local COLORS = {
    bg = Color3.fromRGB(14, 15, 20),
    panel = Color3.fromRGB(24, 26, 34),
    border = Color3.fromRGB(48, 50, 64),
    text = Color3.fromRGB(240, 241, 245),
    muted = Color3.fromRGB(130, 134, 152),
    accent = Color3.fromRGB(99, 102, 241),
    ok = Color3.fromRGB(52, 211, 153),
    err = Color3.fromRGB(239, 68, 68),
}

-- ── Services ────────────────────────────────────────────────────────────────

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

print(string.format("[NightFall] Loader v%s (%s)", VERSION, BUILD))

if game.PlaceId ~= CONFIG.PLACE_ID then
    warn(string.format("[NightFall] Wrong game (need %s, got %s)", CONFIG.PLACE_ID, game.PlaceId))
    return
end

local IS_MOBILE = UIS.TouchEnabled
    or UIS.GyroscopeEnabled
    or UIS.AccelerometerEnabled

-- ── Movement (never block walking) ──────────────────────────────────────────

local moveLoopOn = false

local function unlockMovement()
    pcall(function() GuiService.TouchControlsEnabled = true end)
    pcall(function()
        UIS.MouseBehavior = Enum.MouseBehavior.Default
        UIS.MouseIconEnabled = true
    end)
    pcall(function()
        local plr = Players.LocalPlayer
        local char = plr and plr.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.PlatformStand = false
            hum.AutoRotate = true
            hum.Sit = false
            if hum.WalkSpeed <= 0 then hum.WalkSpeed = 16 end
        end
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.Anchored = false end
    end)
end

local function startMoveLoop()
    if moveLoopOn then return end
    moveLoopOn = true
    task.spawn(function()
        while moveLoopOn do
            unlockMovement()
            task.wait(0.25)
        end
    end)
end

startMoveLoop()

-- ── Filesystem ──────────────────────────────────────────────────────────────

local function fsRead(path)
    local ok, data = pcall(function()
        if isfile and readfile and isfile(path) then return readfile(path) end
    end)
    return ok and data or nil
end

local function fsWrite(path, data)
    pcall(function()
        if writefile then
            if makefolder and isfolder and not isfolder("ScriptHub") then makefolder("ScriptHub") end
            writefile(path, data)
        end
    end)
end

-- ── HTTP ────────────────────────────────────────────────────────────────────

local function getRequest()
    if type(request) == "function" then return request end
    if type(http_request) == "function" then return http_request end
    if syn and type(syn.request) == "function" then return syn.request end
    if http and type(http.request) == "function" then return http.request end
    return nil
end

local REQ = getRequest()

local function httpGet(url)
    local headers = { ["Accept"] = "text/plain, application/json, */*", ["User-Agent"] = "NightFallLoader/" .. VERSION }

    if REQ then
        local ok, res = pcall(function()
            return REQ({ Url = url, Method = "GET", Headers = headers })
        end)
        if ok and type(res) == "table" and res.Body and res.Body ~= "" then return res.Body end
        if ok and type(res) == "string" and res ~= "" then return res end
    end

    local ok, body = pcall(function() return HttpService:GetAsync(url, true, headers) end)
    if ok and body and body ~= "" then return body end

    ok, body = pcall(function() return game:HttpGet(url, true) end)
    if ok and body and body ~= "" then return body end

    return nil
end

local function httpPostJson(url, tbl)
    local body = HttpService:JSONEncode(tbl)
    local headers = { ["Content-Type"] = "application/json", ["Accept"] = "application/json, */*" }

    if REQ then
        local ok, res = pcall(function()
            return REQ({ Url = url, Method = "POST", Headers = headers, Body = body })
        end)
        if ok and type(res) == "table" and res.Body and res.Body ~= "" then return res.Body end
    end

    local ok, resBody = pcall(function()
        return HttpService:PostAsync(url, body, Enum.HttpContentType.ApplicationJson, false, headers)
    end)
    if ok and resBody and resBody ~= "" then return resBody end

    return nil
end

local function httpJson(url, method, tbl)
    local raw
    if method == "POST" then
        raw = httpPostJson(url, tbl or {})
    else
        raw = httpGet(url)
    end
    if not raw or raw == "" then return nil, "HTTP failed — enable HTTP in Delta settings" end
    if raw:find("<!DOCTYPE") or raw:find("<html") then return nil, "Server offline or tunnel expired" end
    local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if ok and type(data) == "table" then return data, nil end
    return nil, "Bad JSON from server"
end

-- ── API base URL (non-blocking) ─────────────────────────────────────────────

local API = CONFIG.API_FALLBACK:gsub("/+$", "")

local function trim(s) return (s or ""):gsub("^%s+", ""):gsub("%s+$", "") end

local function isHttps(url)
    url = trim(url)
    return url:sub(1, 8) == "https://" and not url:find("REPLACE")
end

task.spawn(function()
    local txt = httpGet(CONFIG.API_URL_TXT)
    if txt and isHttps(txt) then
        API = trim(txt):gsub("/+$", "")
        print("[NightFall] API -> " .. API)
    else
        print("[NightFall] API -> " .. API .. " (fallback)")
    end
end)

-- ── HWID / key helpers ──────────────────────────────────────────────────────

local function getHwid()
    if typeof(gethwid) == "function" then
        local ok, id = pcall(gethwid)
        if ok and type(id) == "string" and id ~= "" then return id end
    end
    local plr = Players.LocalPlayer
    return plr and ("uid-" .. plr.UserId) or "unknown"
end

local HWID = getHwid()

local function keyError(code)
    local map = {
        KEY_EXPIRED = "Key expired — get a new one.",
        KEY_REVOKED = "Key revoked.",
        HWID_MISMATCH = "Key locked to another device.",
    }
    return map[code] or code or "Invalid key"
end

-- ── Script compile / patch (Delta sandbox) ──────────────────────────────────

local function getEnv()
    if typeof(getgenv) == "function" then
        local ok, g = pcall(getgenv)
        if ok and type(g) == "table" then return g end
    end
    if typeof(shared) == "table" then return shared end
    return _G
end

local function patchSource(source, mode, scriptKey)
    if mode == "keyless" then
        source = source:gsub(
            "local isPremium, allowRun = resolveScriptAccess%(%)",
            "local isPremium, allowRun = false, true",
            1
        )
        return table.concat({
            "_G.NF_KEYLESS = true",
            "shared.NF_KEYLESS = true",
            "pcall(function() if typeof(getgenv)=='function' then getgenv().NF_KEYLESS=true end end)",
            source,
        }, "\n")
    end

    local keyLit = HttpService:JSONEncode(scriptKey or "")
    source = source:gsub(
        "local isPremium, allowRun = resolveScriptAccess%(%)",
        "local isPremium, allowRun = true, true",
        1
    )
    return table.concat({
        "_G.SCRIPT_KEY = " .. keyLit,
        "shared.SCRIPT_KEY = " .. keyLit,
        "_G.NF_KEYLESS = false",
        "pcall(function() if typeof(getgenv)=='function' then local g=getgenv() g.SCRIPT_KEY=" .. keyLit .. " g.NF_KEYLESS=false end end)",
        source,
    }, "\n")
end

local function compile(source, name)
    name = name or "NightFall"
    local env = getEnv()
    if type(load) == "function" then
        local fn, err = load(source, name, "t", env)
        if type(fn) == "function" then return fn, nil end
        if err then warn("[NightFall] compile: " .. tostring(err)) end
    end
    local ls = loadstring or (env and env.loadstring)
    if type(ls) ~= "function" then return nil, "No loadstring" end
    local fn, err = ls(source, name)
    if type(fn) ~= "function" then return nil, err end
    pcall(function() if setfenv then setfenv(fn, env) end end)
    return fn, nil
end

local function validScriptBody(body)
    return type(body) == "string" and #body > 500 and not body:find("<!DOCTYPE")
end

-- ── UI (shown immediately) ──────────────────────────────────────────────────

local KeyGui = nil

local function removeOldKeyUi()
    pcall(function()
        local plr = Players.LocalPlayer
        if plr then
            local pg = plr:FindFirstChild("PlayerGui")
            if pg then
                local old = pg:FindFirstChild("NightFallKeyUI")
                if old then old:Destroy() end
            end
        end
    end)
end

local function guiParent()
    local plr = Players.LocalPlayer or Players.PlayerAdded:Wait()
    local pg = plr:FindFirstChild("PlayerGui")
    if not pg then
        pg = plr:WaitForChild("PlayerGui", 6)
    end
    return pg or workspace
end

local function corner(inst, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = inst
end

local function bindBtn(btn, fn)
    if IS_MOBILE then btn.Activated:Connect(fn) else btn.MouseButton1Click:Connect(fn) end
end

local function setStatus(lbl, text, color)
    if lbl and lbl.Parent then
        lbl.Text = text
        lbl.TextColor3 = color or COLORS.muted
    end
    print("[NightFall] " .. text)
end

local function waitForHub(timeout)
    local t0 = os.clock()
    while os.clock() - t0 < (timeout or 15) do
        for _, root in ipairs({ guiParent(), game:GetService("CoreGui") }) do
            if root:FindFirstChild("ScriptHubToggle", true) or root:FindFirstChild("ScriptHub", true) then
                return true
            end
        end
        unlockMovement()
        task.wait(0.2)
    end
    return false
end

local function runScript(source, mode, scriptKey)
    source = patchSource(source, mode, scriptKey)
    local fn, err = compile(source, "NightFall")
    if not fn then
        warn("[NightFall] Compile failed: " .. tostring(err))
        return false
    end
    unlockMovement()
    local ok, runErr = pcall(fn)
    if not ok then
        warn("[NightFall] Runtime error: " .. tostring(runErr))
        return false
    end
    if waitForHub(15) then
        pcall(function() if KeyGui then KeyGui:Destroy() end end)
        print("[NightFall] Ready.")
        return true
    end
    warn("[NightFall] Script ran but hub UI not found — check F9 for errors.")
    unlockMovement()
    return false
end

local function downloadKeyless()
    local tries = {
        { name = "server", url = function() return API .. "/api/script-keyless?t=" .. os.time() end },
    }
    for _, u in ipairs(CONFIG.KEYLESS_URLS) do
        table.insert(tries, { name = "GitHub", url = function() return u .. "?t=" .. os.time() end })
    end
    for _, t in ipairs(tries) do
        local body = httpGet(t.url())
        if validScriptBody(body) then
            print("[NightFall] Downloaded (" .. t.name .. ")")
            return body, nil
        end
    end
    return nil, "All keyless sources failed"
end

local function downloadPremium(key)
    local url = string.format(
        "%s/api/script?key=%s&hwid=%s&t=%s",
        API, HttpService:UrlEncode(key), HttpService:UrlEncode(HWID), os.time()
    )
    local body = httpGet(url)
    if validScriptBody(body) then return body, nil end
    if body and body:sub(1, 1) == "{" then
        local ok, j = pcall(function() return HttpService:JSONDecode(body) end)
        if ok and j and j.error then return nil, j.error end
    end
    return nil, "Premium download failed — check key server"
end

-- Build UI NOW (before any network / character wait)
removeOldKeyUi()
unlockMovement()

local screen = Instance.new("ScreenGui")
screen.Name = "NightFallKeyUI"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.DisplayOrder = 900
screen.Parent = guiParent()
KeyGui = screen

pcall(function()
    if syn and syn.protect_gui then syn.protect_gui(screen)
    elseif protectgui then protectgui(screen) end
end)

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.BackgroundColor3 = COLORS.bg
panel.BorderSizePixel = 0
panel.Active = false
if IS_MOBILE then
    panel.AnchorPoint = Vector2.new(0.5, 0)
    panel.Position = UDim2.new(0.5, 0, 0, 6)
    panel.Size = UDim2.new(0.96, 0, 0, 300)
else
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.Size = UDim2.new(0, 400, 0, 340)
end
panel.Parent = screen
corner(panel, 16)

local stroke = Instance.new("UIStroke")
stroke.Color = COLORS.border
stroke.Thickness = 1
stroke.Transparency = 0.4
stroke.Parent = panel

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 16, 0, 12)
title.Size = UDim2.new(1, -32, 0, 28)
title.Font = Enum.Font.GothamBold
title.TextSize = IS_MOBILE and 22 or 20
title.TextColor3 = COLORS.text
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "NightFall"
title.Parent = panel

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.Position = UDim2.new(0, 16, 0, 44)
status.Size = UDim2.new(1, -32, 0, 36)
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextColor3 = COLORS.muted
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.TextWrapped = true
status.Text = "Enter your key or use keyless. You can still walk and play."
status.Parent = panel

local box = Instance.new("TextBox")
box.Position = UDim2.new(0, 16, 0, 88)
box.Size = UDim2.new(1, -32, 0, 36)
box.BackgroundColor3 = COLORS.panel
box.TextColor3 = COLORS.text
box.PlaceholderText = "NF-XXXX-XXXX-XXXX"
box.PlaceholderColor3 = COLORS.muted
box.Font = Enum.Font.Gotham
box.TextSize = 14
box.ClearTextOnFocus = false
box.Parent = panel
corner(box, 8)

local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 10)
pad.PaddingRight = UDim.new(0, 10)
pad.Parent = box

local cached = fsRead(CONFIG.KEY_FILE)
if cached and cached ~= "" then box.Text = cached end

local btnRow = Instance.new("Frame")
btnRow.BackgroundTransparency = 1
btnRow.Position = UDim2.new(0, 16, 0, 136)
btnRow.Size = UDim2.new(1, -32, 0, 40)
btnRow.Parent = panel

local getKey = Instance.new("TextButton")
getKey.Size = UDim2.new(0.48, 0, 1, 0)
getKey.BackgroundColor3 = COLORS.panel
getKey.Text = "Get Key"
getKey.TextColor3 = COLORS.text
getKey.Font = Enum.Font.GothamSemibold
getKey.TextSize = 14
getKey.AutoButtonColor = true
getKey.Parent = btnRow
corner(getKey, 8)

local submit = Instance.new("TextButton")
submit.Size = UDim2.new(0.48, 0, 1, 0)
submit.Position = UDim2.new(0.52, 0, 0, 0)
submit.BackgroundColor3 = COLORS.accent
submit.Text = "Continue"
submit.TextColor3 = COLORS.text
submit.Font = Enum.Font.GothamBold
submit.TextSize = 14
submit.AutoButtonColor = true
submit.Parent = btnRow
corner(submit, 8)

local keyless = Instance.new("TextButton")
keyless.Position = UDim2.new(0, 16, 0, 188)
keyless.Size = UDim2.new(1, -32, 0, 38)
keyless.BackgroundColor3 = COLORS.panel
keyless.Text = "Continue with keyless version"
keyless.TextColor3 = COLORS.muted
keyless.Font = Enum.Font.Gotham
keyless.TextSize = 13
keyless.AutoButtonColor = true
keyless.Parent = panel
corner(keyless, 8)

local hint = Instance.new("TextLabel")
hint.BackgroundTransparency = 1
hint.Position = UDim2.new(0, 16, 0, 236)
hint.Size = UDim2.new(1, -32, 0, 48)
hint.Font = Enum.Font.Gotham
hint.TextSize = 11
hint.TextColor3 = COLORS.muted
hint.TextWrapped = true
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Text = "Loader v" .. VERSION .. " · Delta/mobile safe · walk while this is open"
hint.Parent = panel

-- ── Button handlers ─────────────────────────────────────────────────────────

local busy = false
local attempts = 0

local function lockButtons(locked)
    getKey.Active = not locked
    submit.Active = not locked
    keyless.Active = not locked
    box.TextEditable = not locked
end

bindBtn(getKey, function()
    if busy then return end
    setStatus(status, "Fetching key link...", COLORS.muted)
    task.spawn(function()
        local data, err = httpJson(API .. "/api/get-link", "POST", {})
        if data and data.ok and data.url then
            if setclipboard then
                setclipboard(data.url)
                setStatus(status, "Link copied — paste in browser.", COLORS.ok)
            else
                setStatus(status, "Open: " .. tostring(data.url), COLORS.accent)
            end
        else
            setStatus(status, "Get key failed: " .. tostring(err or (data and data.error) or "?"), COLORS.err)
        end
    end)
end)

bindBtn(submit, function()
    if busy then return end
    attempts += 1
    if attempts > CONFIG.MAX_ATTEMPTS then
        setStatus(status, "Too many tries.", COLORS.err)
        return
    end

    local key = box.Text:gsub("^%s+", ""):gsub("%s+$", ""):upper()
    if key == "" then
        setStatus(status, "Enter a key first.", COLORS.err)
        return
    end

    busy = true
    lockButtons(true)
    setStatus(status, "Checking key...", COLORS.muted)

    task.spawn(function()
        local data, err = httpJson(API .. "/api/validate", "POST", { key = key, hwid = HWID })
        if not data then
            local url = string.format("%s/api/validate?key=%s&hwid=%s", API, HttpService:UrlEncode(key), HttpService:UrlEncode(HWID))
            data, err = httpJson(url, "GET")
        end

        if not data or not data.valid then
            busy = false
            lockButtons(false)
            setStatus(status, data and keyError(data.error) or tostring(err), COLORS.err)
            return
        end

        fsWrite(CONFIG.KEY_FILE, key)
        setStatus(status, "Key OK — downloading premium...", COLORS.ok)

        local source, dlErr = downloadPremium(key)
        if not source then
            busy = false
            lockButtons(false)
            setStatus(status, tostring(dlErr), COLORS.err)
            return
        end

        setStatus(status, "Starting NightFall (premium)...", COLORS.ok)
        local ok = runScript(source, "premium", key)
        busy = false
        if not ok then
            lockButtons(false)
            setStatus(status, "Load failed — see F9. Tap Continue to retry.", COLORS.err)
        end
    end)
end)

bindBtn(keyless, function()
    if busy then return end
    busy = true
    lockButtons(true)
    setStatus(status, "Downloading keyless build...", COLORS.muted)

    task.spawn(function()
        local source, dlErr = downloadKeyless()
        if not source then
            busy = false
            lockButtons(false)
            setStatus(status, tostring(dlErr), COLORS.err)
            return
        end

        setStatus(status, "Starting NightFall (keyless)...", COLORS.ok)
        local ok = runScript(source, "keyless")
        busy = false
        if not ok then
            lockButtons(false)
            setStatus(status, "Load failed — see F9. Tap keyless to retry.", COLORS.err)
        end
    end)
end)

-- Keep movement unlocked while panel is open
task.spawn(function()
    while screen and screen.Parent do
        unlockMovement()
        task.wait(0.3)
    end
    moveLoopOn = false
end)

print("[NightFall] Key UI open — mobile/Delta safe.")
