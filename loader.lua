--[[
    NightFall Loader (LootLabs Key System)
    Share this file / loadstring — do NOT share improved_script.lua directly

    Users run this → get key from your site → script loads automatically
]]

local CONFIG = {
    REQUIRED_PLACE_ID = 134225461562780,

    -- Fallback if api-url.txt is unavailable (must be HTTPS for Roblox)
    API_BASE_URL = "https://visual-mayor-corrected-dancing.trycloudflare.com",

    -- Auto-loaded from GitHub — update api-url.txt when your tunnel URL changes
    API_URL_SOURCE = "https://raw.githubusercontent.com/quarter67/NightFall/main/api-url.txt",

    KEY_CACHE_PATH = "ScriptHub/nightfall_key.txt",
    MAX_ATTEMPTS = 5,
    DOWNLOAD_TIMEOUT = 15,
    KEYLESS_FALLBACK_URLS = {
        "https://raw.githubusercontent.com/quarter67/NightFall/main/script/improved_script.lua",
        "https://raw.githubusercontent.com/quarter67/NightFall/main/improved_script.lua",
    },
}

local LOADER_VERSION = "4.1.7-keyless"
local LOADER_BUILD = "2026-05-27-keyless-fast-download"
print("[NightFall] Loader v" .. LOADER_VERSION .. " (" .. LOADER_BUILD .. ")")

local COLORS = {
    bg = Color3.fromRGB(13, 14, 18),
    surface = Color3.fromRGB(22, 24, 31),
    surfaceHover = Color3.fromRGB(28, 30, 40),
    border = Color3.fromRGB(44, 46, 58),
    text = Color3.fromRGB(236, 237, 242),
    textMuted = Color3.fromRGB(128, 132, 150),
    accent = Color3.fromRGB(99, 102, 241),
    accentLight = Color3.fromRGB(129, 140, 248),
    success = Color3.fromRGB(52, 211, 153),
    danger = Color3.fromRGB(239, 68, 68),
}

if game.PlaceId ~= CONFIG.REQUIRED_PLACE_ID then
    warn(string.format(
        "[NightFall] Wrong game. Required PlaceId %s, current PlaceId %s.",
        tostring(CONFIG.REQUIRED_PLACE_ID),
        tostring(game.PlaceId)
    ))
    return
end

if CONFIG.API_BASE_URL:find("REPLACE%-WITH") or CONFIG.API_BASE_URL == "https://your-domain.com" then
    warn("[NightFall] Set api-url.txt on GitHub to your HTTPS tunnel URL.")
end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local function detectMobileDevice()
    if UserInputService.TouchEnabled then return true end
    if UserInputService.GyroscopeEnabled then return true end
    if UserInputService.AccelerometerEnabled then return true end
    local cam = workspace.CurrentCamera
    if cam then
        local vp = cam.ViewportSize
        if vp.X > 0 and vp.Y > vp.X and vp.X < 980 then
            return true
        end
    end
    return false
end

local IS_MOBILE = detectMobileDevice()

local FONT_TITLE = IS_MOBILE and Enum.Font.SourceSansBold or Enum.Font.GothamBold
local FONT_BODY = IS_MOBILE and Enum.Font.SourceSans or Enum.Font.GothamMedium
local FONT_BUTTON = IS_MOBILE and Enum.Font.SourceSansSemibold or Enum.Font.GothamSemibold

local function trim(value)
    return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function isValidApiUrl(url)
    url = trim(url)
    return url:sub(1, 8) == "https://" and not url:find("REPLACE%-WITH")
end

local function fsRead(path)
    local ok, result = pcall(function()
        if isfile and readfile and isfile(path) then
            return readfile(path)
        end
    end)
    return ok and result or nil
end

local function fsWrite(path, data)
    pcall(function()
        if writefile then
            if makefolder and isfolder and not isfolder("ScriptHub") then
                makefolder("ScriptHub")
            end
            writefile(path, data)
        end
    end)
end

local function getHwid()
    if typeof(gethwid) == "function" then
        local ok, id = pcall(gethwid)
        if ok and type(id) == "string" and id ~= "" then
            return id
        end
    end

    local plr = Players.LocalPlayer
    if plr then
        return "uid-" .. tostring(plr.UserId)
    end

    return "unknown"
end

local HWID = getHwid()

local DEFAULT_HEADERS = {
    ["Accept"] = "application/json, text/plain, */*",
    ["User-Agent"] = "NightFallLoader/" .. LOADER_VERSION,
}

local function mergeHeaders(custom)
    local merged = {}
    for key, value in pairs(DEFAULT_HEADERS) do
        merged[key] = value
    end
    for key, value in pairs(custom or {}) do
        merged[key] = value
    end
    return merged
end

local function getExecutorRequest()
    if type(request) == "function" then
        return request, "request"
    end
    if type(http_request) == "function" then
        return http_request, "http_request"
    end
    if syn and type(syn.request) == "function" then
        return syn.request, "syn.request"
    end
    if http and type(http.request) == "function" then
        return http.request, "http.request"
    end
    return nil, "HttpService"
end

local EXECUTOR_REQUEST, EXECUTOR_NAME = getExecutorRequest()
print("[NightFall] HTTP mode → " .. EXECUTOR_NAME)

local function extractResponseBody(response)
    if type(response) == "string" and response ~= "" then
        return response
    end

    if type(response) == "table" then
        if type(response.Body) == "string" and response.Body ~= "" then
            return response.Body
        end
        if type(response.body) == "string" and response.body ~= "" then
            return response.body
        end
    end

    return nil
end

local function httpFetch(url, options)
    options = options or {}
    local method = options.method or "GET"
    local body = options.body or ""
    local headers = mergeHeaders(options.headers)
    local strategies = {}

    if EXECUTOR_REQUEST then
        table.insert(strategies, function()
            local response = EXECUTOR_REQUEST({
                Url = url,
                Method = method,
                Headers = headers,
                Body = body,
            })
            return extractResponseBody(response)
        end)
    end

    table.insert(strategies, function()
        local payload = {
            Url = url,
            Method = method,
            Headers = headers,
        }
        if body ~= "" then
            payload.Body = body
        end

        local response = HttpService:RequestAsync(payload)
        if response and response.Success and response.Body and response.Body ~= "" then
            return response.Body
        end
        if response and response.Body and response.Body ~= "" then
            return response.Body
        end
        return nil
    end)

    table.insert(strategies, function()
        if method == "POST" then
            return HttpService:PostAsync(url, body, Enum.HttpContentType.ApplicationJson, false, headers)
        end
        return HttpService:GetAsync(url, true, headers)
    end)

    table.insert(strategies, function()
        if method == "POST" then
            if game.HttpPost then
                return game:HttpPost(url, body, true, headers["Content-Type"] or "application/json")
            end
            return nil
        end
        return game:HttpGet(url, true)
    end)

    for attempt = 1, 4 do
        for _, strategy in ipairs(strategies) do
            local ok, responseBody = pcall(strategy)
            if ok and responseBody and responseBody ~= "" then
                return responseBody, nil
            end
        end
        if attempt < 4 then
            task.wait(2)
        end
    end

    return nil, "Could not reach key server (Delta: enable HTTP requests in settings)"
end

local function httpRequestJson(url, method, body, headers)
    method = method or "GET"
    headers = headers or {}

    for attempt = 1, 3 do
        local responseBody, fetchErr = httpFetch(url, {
            method = method,
            body = body or "",
            headers = headers,
        })

        if responseBody and responseBody ~= "" then
            local trimmed = responseBody:gsub("^%s+", ""):gsub("%s+$", "")
            if trimmed:sub(1, 1) == "{" then
                local decodeOk, data = pcall(function()
                    return HttpService:JSONDecode(trimmed)
                end)
                if decodeOk then
                    return data, nil
                end
            end
            if responseBody:find("<!DOCTYPE") or responseBody:find("<html") then
                if responseBody:find("Cloudflare Tunnel error") or responseBody:find("error code: 1033") then
                    return nil, "Tunnel URL expired — update api-url.txt on GitHub."
                end
                if attempt < 3 then
                    task.wait(3)
                else
                    return nil, "Server waking up — wait 30 seconds and try again."
                end
            else
                return nil, "Invalid server response"
            end
        elseif attempt < 3 then
            task.wait(3)
        end
    end

    return nil, fetchErr or "Could not reach key server (use HTTPS URL in api-url.txt)"
end

local function httpRequestRaw(url, method, body, headers)
    method = method or "GET"
    for attempt = 1, 4 do
        local responseBody, fetchErr = httpFetch(url, {
            method = method,
            body = body or "",
            headers = headers or {},
        })

        if responseBody and responseBody ~= "" then
            if responseBody:find("<!DOCTYPE") or responseBody:find("<html") then
                if attempt < 4 then
                    task.wait(3)
                else
                    return nil, "Server waking up — wait 30 seconds and try again."
                end
            else
                return responseBody, nil
            end
        elseif attempt < 4 then
            task.wait(2)
        end
    end

    return nil, fetchErr or "Could not download script"
end

local GuiService = game:GetService("GuiService")

local function enableRobloxMovement()
    pcall(function() GuiService.TouchControlsEnabled = true end)
    pcall(function()
        local plr = Players.LocalPlayer
        if not plr then return end
        local ps = plr:FindFirstChild("PlayerScripts")
        if not ps then return end
        local pm = ps:FindFirstChild("PlayerModule")
        if not pm then return end
        local controls = require(pm):GetControls()
        if controls and controls.Enable then
            controls:Enable(true)
        end
    end)
end

local function destroyStaleLoaderUi()
    local parents = {}
    local plr = Players.LocalPlayer
    if plr then
        local pg = plr:FindFirstChild("PlayerGui")
        if pg then table.insert(parents, pg) end
    end
    table.insert(parents, game:GetService("CoreGui"))
    if typeof(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and hui then table.insert(parents, hui) end
    end
    for _, parent in ipairs(parents) do
        for _, name in ipairs({ "NightFallLoaderOverlay", "NightFallKeyUI" }) do
            local gui = parent:FindFirstChild(name)
            if gui then
                pcall(function() gui:Destroy() end)
            end
        end
    end
end

local function waitForLocalPlayer()
    local plr = Players.LocalPlayer
    if plr then return plr end
    return Players.PlayerAdded:Wait()
end

local function getGuiParent()
    if IS_MOBILE then
        local plr = Players.LocalPlayer
        if plr then
            local pg = plr:FindFirstChild("PlayerGui")
            if not pg then
                pg = plr:WaitForChild("PlayerGui", 8)
            end
            if pg then
                return pg
            end
        end
    end
    if typeof(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and hui then
            return hui
        end
    end
    return game:GetService("CoreGui")
end

local function setLoaderFlags(isKeyless, scriptKey)
    local function write(env)
        if type(env) ~= "table" then return end
        if isKeyless then
            env.NF_KEYLESS = true
            env.SCRIPT_KEY = nil
        else
            env.NF_KEYLESS = false
            env.SCRIPT_KEY = scriptKey
        end
    end
    pcall(function()
        if typeof(getgenv) == "function" then
            write(getgenv())
        end
    end)
    pcall(function()
        if typeof(shared) == "table" then
            write(shared)
        end
    end)
    write(_G)
end

local function protectGui(gui)
    pcall(function()
        if syn and typeof(syn.protect_gui) == "function" then
            syn.protect_gui(gui)
        elseif typeof(protectgui) == "function" then
            protectgui(gui)
        end
    end)
end

local LoadingOverlay = nil

local function setLoadingMessage(text)
    if LoadingOverlay and LoadingOverlay.subtitle then
        LoadingOverlay.subtitle.Text = text or "Please wait..."
    end
end

local function showLoadingOverlay(message)
    message = message or "Please wait..."

    if LoadingOverlay and LoadingOverlay.gui then
        setLoadingMessage(message)
        LoadingOverlay.gui.Enabled = true
        return LoadingOverlay
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "NightFallLoaderOverlay"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    gui.DisplayOrder = 999999
    gui.Parent = getGuiParent()
    protectGui(gui)

    local card = Instance.new("Frame")
    card.Name = "LoadingCard"
    if IS_MOBILE then
        -- Small bottom toast: never cover the thumbstick / jump area.
        card.AnchorPoint = Vector2.new(0.5, 1)
        card.Position = UDim2.new(0.5, 0, 1, -20)
        card.Size = UDim2.new(0.92, 0, 0, 72)
    else
        local backdrop = Instance.new("Frame")
        backdrop.Name = "Backdrop"
        backdrop.Size = UDim2.fromScale(1, 1)
        backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        backdrop.BackgroundTransparency = 0.45
        backdrop.BorderSizePixel = 0
        backdrop.Active = false
        backdrop.ZIndex = 1
        backdrop.Parent = gui

        card.AnchorPoint = Vector2.new(0.5, 0.5)
        card.Position = UDim2.fromScale(0.5, 0.5)
        card.Size = UDim2.new(0, 320, 0, 140)
    end
    card.BackgroundColor3 = COLORS.bg
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel = 0
    card.Active = false
    card.ZIndex = 2
    card.Parent = gui

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 18)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = COLORS.border
    cardStroke.Transparency = 0.35
    cardStroke.Parent = card

    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(0, 4, 0, 36)
    accent.Position = UDim2.new(0, 18, 0, 24)
    accent.BackgroundColor3 = COLORS.accent
    accent.BorderSizePixel = 0
    accent.Parent = card

    local accentCorner = Instance.new("UICorner")
    accentCorner.CornerRadius = UDim.new(1, 0)
    accentCorner.Parent = accent

    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, -40, 0, 34)
    title.Position = UDim2.new(0, 32, 0, 22)
    title.BackgroundTransparency = 1
    title.Font = FONT_TITLE
    title.TextSize = IS_MOBILE and 18 or 28
    title.TextColor3 = COLORS.text
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "Loading"
    title.Parent = card

    local subtitle = Instance.new("TextLabel")
    subtitle.Name = "Subtitle"
    subtitle.Size = UDim2.new(1, -40, 0, IS_MOBILE and 28 or 44)
    subtitle.Position = UDim2.new(0, 32, 0, IS_MOBILE and 38 or 62)
    subtitle.BackgroundTransparency = 1
    subtitle.Font = FONT_BODY
    subtitle.TextSize = IS_MOBILE and 13 or 13
    subtitle.TextColor3 = COLORS.textMuted
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.TextYAlignment = Enum.TextYAlignment.Top
    subtitle.TextWrapped = true
    if IS_MOBILE then
        accent.Visible = false
        title.Visible = false
        subtitle.Position = UDim2.new(0, 16, 0, 10)
        subtitle.Size = UDim2.new(1, -32, 1, -16)
        subtitle.TextXAlignment = Enum.TextXAlignment.Center
    end
    subtitle.Text = message
    subtitle.Parent = card

    if not IS_MOBILE then
        local dots = Instance.new("TextLabel")
        dots.Name = "Dots"
        dots.Size = UDim2.new(1, -40, 0, 20)
        dots.Position = UDim2.new(0, 32, 1, -34)
        dots.BackgroundTransparency = 1
        dots.Font = FONT_TITLE
        dots.TextSize = 18
        dots.TextColor3 = COLORS.accentLight
        dots.TextXAlignment = Enum.TextXAlignment.Left
        dots.Text = "..."
        dots.Parent = card

        local animRunning = true
        task.spawn(function()
            local frames = { ".", "..", "..." }
            local index = 1
            while animRunning and dots and dots.Parent do
                dots.Text = frames[index]
                index = index % #frames + 1
                task.wait(0.45)
            end
        end)

        LoadingOverlay.stopAnimation = function()
            animRunning = false
        end
    end

    LoadingOverlay = LoadingOverlay or {}
    LoadingOverlay.gui = gui
    LoadingOverlay.subtitle = subtitle
    LoadingOverlay.stopAnimation = LoadingOverlay.stopAnimation or function() end

    if IS_MOBILE then
        enableRobloxMovement()
    end

    return LoadingOverlay
end

local function hideLoadingOverlay()
    if LoadingOverlay and LoadingOverlay.gui then
        if LoadingOverlay.stopAnimation then
            LoadingOverlay.stopAnimation()
        end
        LoadingOverlay.gui.Enabled = false
    end
end

local function destroyLoadingOverlay()
    if LoadingOverlay and LoadingOverlay.gui then
        if LoadingOverlay.stopAnimation then
            LoadingOverlay.stopAnimation()
        end
        pcall(function()
            LoadingOverlay.gui:Destroy()
        end)
        LoadingOverlay = nil
    end
end

local function resolveApiUrl()
    local remote, _ = httpFetch(CONFIG.API_URL_SOURCE, { method = "GET" })
    if remote then
        local url = trim(remote)
        if isValidApiUrl(url) then
            return url
        end
    end

    if isValidApiUrl(CONFIG.API_BASE_URL) then
        return trim(CONFIG.API_BASE_URL)
    end

    return nil
end

local API_BASE_URL = trim(CONFIG.API_BASE_URL)
if not isValidApiUrl(API_BASE_URL) then
    API_BASE_URL = resolveApiUrl()
end

local function refreshApiUrlAsync()
    task.spawn(function()
        local url = resolveApiUrl()
        if url and url ~= API_BASE_URL then
            API_BASE_URL = url
            print("[NightFall] API updated -> " .. url)
        end
    end)
end

local function fetchGetKeyUrl()
    local data, err = httpRequestJson(
        API_BASE_URL .. "/api/get-link",
        "POST",
        "{}",
        { ["Content-Type"] = "application/json" }
    )

    if not data then
        return nil, err or "Could not reach key server"
    end

    if data.ok and data.url then
        return data.url, nil
    end

    return nil, data.error or "Get key failed"
end

local function formatKeyError(code)
    if code == "KEY_EXPIRED" then
        return "Key expired — get a new one from the website."
    elseif code == "KEY_REVOKED" then
        return "Key was revoked."
    elseif code == "HWID_MISMATCH" then
        return "This key is locked to another device."
    elseif code == "Missing HWID." then
        return "Could not read HWID from executor."
    end
    return code or "Invalid key"
end

local function validateKey(key)
    if not key or key == "" then
        return false, "Enter a key."
    end

    local payload = HttpService:JSONEncode({
        key = key:upper(),
        hwid = HWID,
    })

    local data, err = httpRequestJson(
        API_BASE_URL .. "/api/validate",
        "POST",
        payload,
        { ["Content-Type"] = "application/json" }
    )

    if not data then
        local url = string.format(
            "%s/api/validate?key=%s&hwid=%s",
            API_BASE_URL,
            HttpService:UrlEncode(key:upper()),
            HttpService:UrlEncode(HWID)
        )
        data, err = httpRequestJson(url, "GET")
    end

    if not data then
        return false, err or "Validation failed."
    end

    if data.valid then
        return true, key:upper()
    end

    return false, formatKeyError(data.error)
end

local function downloadScript(key)
    local payload = HttpService:JSONEncode({
        key = key,
        hwid = HWID,
    })

    local source, dlErr = httpRequestRaw(
        API_BASE_URL .. "/api/script",
        "POST",
        payload,
        { ["Content-Type"] = "application/json", ["Accept"] = "text/plain, application/json, */*" }
    )

    if not source then
        local url = string.format(
            "%s/api/script?key=%s&hwid=%s&t=%s",
            API_BASE_URL,
            HttpService:UrlEncode(key),
            HttpService:UrlEncode(HWID),
            tostring(os.time())
        )
        source, dlErr = httpRequestRaw(url, "GET")
    end

    if not source then
        return nil, dlErr or "Failed to download script."
    end

    if source:sub(1, 1) == "{" then
        local decodeOk, data = pcall(function()
            return HttpService:JSONDecode(source)
        end)
        if decodeOk and data and data.error then
            return nil, data.error
        end
    end

    return source, nil
end

local function runAsync(action, timeoutSec)
    local finished = false
    local out = { nil, nil }
    task.spawn(function()
        local ok, a, b = pcall(action)
        if ok then
            out[1], out[2] = a, b
        else
            out[2] = tostring(a)
        end
        finished = true
    end)

    local deadline = os.clock() + (timeoutSec or CONFIG.DOWNLOAD_TIMEOUT or 15)
    while not finished and os.clock() < deadline do
        enableRobloxMovement()
        task.wait(0.15)
    end

    if not finished then
        return nil, "Download timed out. Check your connection or try again."
    end
    return out[1], out[2]
end

local function fastHttpGet(url, timeoutSec)
    timeoutSec = timeoutSec or CONFIG.DOWNLOAD_TIMEOUT or 15
    return runAsync(function()
        if EXECUTOR_REQUEST then
            local ok, response = pcall(function()
                return EXECUTOR_REQUEST({
                    Url = url,
                    Method = "GET",
                    Headers = mergeHeaders({ ["Accept"] = "text/plain, application/json, */*" }),
                })
            end)
            if ok then
                local body = extractResponseBody(response)
                if body and body ~= "" then
                    return body, nil
                end
            end
        end

        local ok, body = pcall(function()
            return HttpService:GetAsync(url, true, mergeHeaders({ ["Accept"] = "text/plain, */*" }))
        end)
        if ok and body and body ~= "" then
            return body, nil
        end

        ok, body = pcall(function()
            return game:HttpGet(url, true)
        end)
        if ok and body and body ~= "" then
            return body, nil
        end

        return nil, "HTTP request failed — enable HTTP requests in executor settings"
    end, timeoutSec)
end

local function showDownloadStatus(message, statusLabel)
    message = message or "Downloading..."
    print("[NightFall] " .. message)
    enableRobloxMovement()
    if statusLabel and statusLabel.Parent then
        statusLabel.Text = message
    end
end

local function destroyKeyUi()
    local parents = {}
    local plr = Players.LocalPlayer
    if plr then
        local pg = plr:FindFirstChild("PlayerGui")
        if pg then table.insert(parents, pg) end
    end
    table.insert(parents, game:GetService("CoreGui"))
    if typeof(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and hui then table.insert(parents, hui) end
    end
    for _, parent in ipairs(parents) do
        local gui = parent:FindFirstChild("NightFallKeyUI")
        if gui then
            pcall(function() gui:Destroy() end)
        end
    end
end

local function finishLoaderCleanup()
    movementKeeperRunning = false
    destroyLoadingOverlay()
    hideLoadingOverlay()
    enableRobloxMovement()
end

local movementKeeperRunning = false

local function startMovementKeeper()
    if movementKeeperRunning then return end
    movementKeeperRunning = true
    task.spawn(function()
        while movementKeeperRunning do
            enableRobloxMovement()
            task.wait(0.5)
        end
    end)
end

local function parseDownloadSource(source)
    if not source or source == "" then
        return nil, "Empty script response"
    end
    if source:sub(1, 1) == "{" then
        local decodeOk, data = pcall(function()
            return HttpService:JSONDecode(source)
        end)
        if decodeOk and data and data.error then
            return nil, data.error
        end
    end
    if #source < 500 then
        return nil, "Script response too small — server may be offline"
    end
    return source, nil
end

local function downloadScriptKeyless()
    local attempts = {
        {
            name = "key server",
            url = API_BASE_URL .. "/api/script-keyless?t=" .. tostring(os.time()),
        },
    }

    for _, fallbackUrl in ipairs(CONFIG.KEYLESS_FALLBACK_URLS or {}) do
        table.insert(attempts, {
            name = "GitHub",
            url = fallbackUrl .. "?t=" .. tostring(os.time()),
        })
    end

    local lastErr = "No download sources configured"
    for _, attempt in ipairs(attempts) do
        print("[NightFall] Trying " .. attempt.name .. "...")
        local raw, err = fastHttpGet(attempt.url, CONFIG.DOWNLOAD_TIMEOUT)
        local source, parseErr = parseDownloadSource(raw)
        if source then
            print("[NightFall] Downloaded keyless script from " .. attempt.name .. ".")
            return source, nil
        end
        lastErr = parseErr or err or ("Failed via " .. attempt.name)
        warn("[NightFall] " .. attempt.name .. " failed: " .. tostring(lastErr))
    end

    return nil, lastErr
end

local KEYLESS_SENTINEL = "__NF_KEYLESS__"

local function createKeyUI()
    hideLoadingOverlay()

    local TweenService = game:GetService("TweenService")
    local keyReady = Instance.new("BindableEvent")

    local function tween(obj, props, duration)
        TweenService:Create(
            obj,
            TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            props
        ):Play()
    end

    local function corner(parent, radius)
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(0, radius)
        c.Parent = parent
        return c
    end

    local function stroke(parent)
        local s = Instance.new("UIStroke")
        s.Color = COLORS.border
        s.Thickness = 1
        s.Transparency = 0.45
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        s.Parent = parent
        return s
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "NightFallKeyUI"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 999999
    gui.Parent = getGuiParent()
    protectGui(gui)

    local root = Instance.new("Frame")
    root.Size = IS_MOBILE and UDim2.new(0.92, 0, 0, 360) or UDim2.new(0, 420, 0, 360)
    root.ClipsDescendants = false
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.Position = UDim2.fromScale(0.5, 0.5)
    root.BackgroundColor3 = COLORS.bg
    root.BorderSizePixel = 0
    root.Active = false
    root.Parent = gui
    corner(root, 20)
    stroke(root)

    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(0, 4, 0, 28)
    accent.Position = UDim2.new(0, 16, 0, 18)
    accent.BackgroundColor3 = COLORS.accent
    accent.BorderSizePixel = 0
    accent.Parent = root
    corner(accent, 2)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -32, 0, 24)
    title.Position = UDim2.new(0, 28, 0, 16)
    title.BackgroundTransparency = 1
    title.Text = "NightFall"
    title.Font = FONT_TITLE
    title.TextSize = IS_MOBILE and 24 or 22
    title.TextColor3 = COLORS.text
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = root

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -32, 0, 18)
    subtitle.Position = UDim2.new(0, 28, 0, 42)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Enter your key to continue"
    subtitle.Font = FONT_BODY
    subtitle.TextSize = IS_MOBILE and 14 or 12
    subtitle.TextColor3 = COLORS.textMuted
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = root

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -32, 0, 18)
    status.Position = UDim2.new(0, 16, 0, 72)
    status.BackgroundTransparency = 1
    status.Text = "Don't have a key? Click Get Key below."
    status.Font = FONT_BODY
    status.TextSize = IS_MOBILE and 13 or 11
    status.TextColor3 = COLORS.textMuted
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.TextWrapped = true
    status.Parent = root

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -32, 0, 36)
    box.Position = UDim2.new(0, 16, 0, 98)
    box.BackgroundColor3 = COLORS.surface
    box.TextColor3 = COLORS.text
    box.PlaceholderText = "NF-XXXX-XXXX-XXXX"
    box.PlaceholderColor3 = COLORS.textMuted
    box.Text = ""
    box.Font = FONT_BODY
    box.TextSize = IS_MOBILE and 16 or 14
    box.ClearTextOnFocus = false
    box.Parent = root
    corner(box, 10)
    stroke(box)

    local boxPad = Instance.new("UIPadding")
    boxPad.PaddingLeft = UDim.new(0, 12)
    boxPad.PaddingRight = UDim.new(0, 12)
    boxPad.Parent = box

    local getKeyBtn = Instance.new("TextButton")
    getKeyBtn.Size = UDim2.new(0.48, 0, 0, 38)
    getKeyBtn.Position = UDim2.new(0, 16, 0, 150)
    getKeyBtn.BackgroundColor3 = COLORS.surface
    getKeyBtn.Text = "Get Key"
    getKeyBtn.TextColor3 = COLORS.text
    getKeyBtn.Font = FONT_BUTTON
    getKeyBtn.TextSize = IS_MOBILE and 16 or 14
    getKeyBtn.AutoButtonColor = false
    getKeyBtn.Parent = root
    corner(getKeyBtn, 10)
    stroke(getKeyBtn)

    local submitBtn = Instance.new("TextButton")
    submitBtn.Size = UDim2.new(0.48, 0, 0, 38)
    submitBtn.Position = UDim2.new(0.52, 0, 0, 150)
    submitBtn.BackgroundColor3 = COLORS.accent
    submitBtn.Text = "Continue"
    submitBtn.TextColor3 = COLORS.text
    submitBtn.Font = FONT_TITLE
    submitBtn.TextSize = IS_MOBILE and 16 or 14
    submitBtn.AutoButtonColor = false
    submitBtn.Parent = root
    corner(submitBtn, 10)

    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -32, 0, 32)
    hint.Position = UDim2.new(0, 16, 0, 198)
    hint.BackgroundTransparency = 1
    hint.Text = "Complete ad steps on the website. Key saves locally after login."
    hint.Font = FONT_BODY
    hint.TextSize = IS_MOBILE and 13 or 11
    hint.TextColor3 = COLORS.textMuted
    hint.TextWrapped = true
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.ZIndex = 2
    hint.Parent = root

    local footer = Instance.new("Frame")
    footer.Name = "Footer"
    footer.AnchorPoint = Vector2.new(0, 1)
    footer.Size = UDim2.new(1, -32, 0, 40)
    footer.Position = UDim2.new(0, 16, 1, -16)
    footer.BackgroundTransparency = 1
    footer.ZIndex = 5
    footer.Parent = root

    local keylessBtn = Instance.new("TextButton")
    keylessBtn.Size = UDim2.new(0.62, 0, 1, 0)
    keylessBtn.Position = UDim2.new(0, 0, 0, 0)
    keylessBtn.BackgroundColor3 = COLORS.surface
    keylessBtn.Text = "Continue with keyless version"
    keylessBtn.TextColor3 = COLORS.textMuted
    keylessBtn.Font = FONT_BUTTON
    keylessBtn.TextSize = IS_MOBILE and 13 or 12
    keylessBtn.AutoButtonColor = false
    keylessBtn.ZIndex = 6
    keylessBtn.Parent = footer
    corner(keylessBtn, 10)
    stroke(keylessBtn)

    if not IS_MOBILE then
        getKeyBtn.MouseEnter:Connect(function()
            tween(getKeyBtn, { BackgroundColor3 = COLORS.surfaceHover })
        end)
        getKeyBtn.MouseLeave:Connect(function()
            tween(getKeyBtn, { BackgroundColor3 = COLORS.surface })
        end)
        submitBtn.MouseEnter:Connect(function()
            tween(submitBtn, { BackgroundColor3 = COLORS.accentLight })
        end)
        submitBtn.MouseLeave:Connect(function()
            tween(submitBtn, { BackgroundColor3 = COLORS.accent })
        end)
        keylessBtn.MouseEnter:Connect(function()
            tween(keylessBtn, { BackgroundColor3 = COLORS.surfaceHover, TextColor3 = COLORS.text })
        end)
        keylessBtn.MouseLeave:Connect(function()
            tween(keylessBtn, { BackgroundColor3 = COLORS.surface, TextColor3 = COLORS.textMuted })
        end)
    end

    local cached = fsRead(CONFIG.KEY_CACHE_PATH)
    if cached and cached ~= "" then
        box.Text = cached
    end

    local resolvedKey = nil
    local done = false
    local attempts = 0

    local function setStatus(text, color)
        status.Text = text
        status.TextColor3 = color or COLORS.textMuted
    end

    getKeyBtn.MouseButton1Click:Connect(function()
        setStatus("Creating key link...", COLORS.textMuted)

        task.spawn(function()
            local link, err = fetchGetKeyUrl()
            if link and link ~= "" then
                if setclipboard then
                    setclipboard(link)
                    setStatus("Key link copied — paste in browser.", COLORS.success)
                else
                    setStatus("Open: " .. API_BASE_URL, COLORS.accentLight)
                end
                print("[NightFall] Get key:", link)
            else
                setStatus("Get key failed: " .. tostring(err), COLORS.danger)
                warn("[NightFall] get-link failed:", tostring(err))
            end
        end)
    end)

    local function trySubmit()
        if done then return end

        attempts = attempts + 1
        if attempts > CONFIG.MAX_ATTEMPTS then
            setStatus("Too many failed attempts.", COLORS.danger)
            done = true
            task.delay(1.5, function()
                gui:Destroy()
                keyReady:Fire(nil)
            end)
            return
        end

        setStatus("Checking key...", COLORS.textMuted)
        submitBtn.Text = "Checking..."
        submitBtn.AutoButtonColor = false

        task.spawn(function()
            local trimmed = box.Text:gsub("^%s+", ""):gsub("%s+$", ""):upper()
            local valid, keyOrErr = validateKey(trimmed)

            if valid then
                resolvedKey = keyOrErr
                fsWrite(CONFIG.KEY_CACHE_PATH, resolvedKey)
                getgenv().SCRIPT_KEY = resolvedKey
                setStatus("Key accepted. Loading NightFall...", COLORS.success)
                submitBtn.Text = "Success"
                done = true
                task.delay(0.35, function()
                    gui:Destroy()
                    keyReady:Fire(resolvedKey)
                end)
                return
            end

            setStatus(keyOrErr, COLORS.danger)
            submitBtn.Text = "Continue"
        end)
    end

    submitBtn.MouseButton1Click:Connect(trySubmit)

    local function onKeylessChosen()
        if done then return end
        done = true
        setLoaderFlags(true, nil)
        print("[NightFall] Keyless selected — downloading...")
        setStatus("Downloading keyless version...", COLORS.textMuted)
        keylessBtn.Text = "Downloading..."
        submitBtn.Active = false
        getKeyBtn.Active = false
        keylessBtn.Active = false
        task.spawn(function()
            startMovementKeeper()
            showDownloadStatus("Downloading keyless NightFall...", status)
            local source, dlErr = downloadScriptKeyless()
            if source then
                keyReady:Fire(KEYLESS_SENTINEL, source)
            else
                finishLoaderCleanup()
                done = false
                setStatus("Download failed — tap keyless to retry", COLORS.danger)
                keylessBtn.Text = "Continue with keyless version"
                submitBtn.Active = true
                getKeyBtn.Active = true
                keylessBtn.Active = true
                warn("[NightFall] Keyless download failed: " .. tostring(dlErr))
            end
        end)
    end

    if IS_MOBILE then
        keylessBtn.Activated:Connect(onKeylessChosen)
    else
        keylessBtn.MouseButton1Click:Connect(onKeylessChosen)
    end

    return keyReady.Event:Wait()
end

local function acquireKey()
    destroyLoadingOverlay()
    hideLoadingOverlay()
    return createKeyUI()
end

local function runDownloadedSource(downloadedSource, keylessMode)
    finishLoaderCleanup()
    startMovementKeeper()
    enableRobloxMovement()

    if keylessMode then
        downloadedSource = table.concat({
            "pcall(function()",
            "  if typeof(getgenv) == 'function' then getgenv().NF_KEYLESS = true end",
            "  _G.NF_KEYLESS = true",
            "  if typeof(shared) == 'table' then shared.NF_KEYLESS = true end",
            "end)",
            downloadedSource,
        }, "\n")
    end

    local function getCompileFn()
        if type(loadstring) == "function" then return loadstring end
        if type(load) == "function" then return load end
        if getgenv then
            local env = getgenv()
            if env and type(env.loadstring) == "function" then return env.loadstring end
            if env and type(env.load) == "function" then return env.load end
        end
        if getrenv then
            local env = getrenv()
            if env and type(env.loadstring) == "function" then return env.loadstring end
            if env and type(env.load) == "function" then return env.load end
        end
        return nil
    end

    local compile = getCompileFn()
    if type(compile) ~= "function" then
        finishLoaderCleanup()
        warn("[NightFall] Your executor does not support loadstring/load — cannot run the script.")
        return
    end

    local runScript, compileErr = compile(downloadedSource, "NightFall")
    if type(runScript) ~= "function" then
        finishLoaderCleanup()
        warn("[NightFall] Failed to compile script: " .. tostring(compileErr or runScript))
        return
    end

    local ok, runErr = pcall(runScript)
    if ok then
        destroyKeyUi()
    else
        warn("[NightFall] Script error: " .. tostring(runErr))
    end
    finishLoaderCleanup()
end

-- Startup (all functions must be defined above this line)
destroyStaleLoaderUi()
waitForLocalPlayer()
if IS_MOBILE then
    enableRobloxMovement()
end

if not API_BASE_URL or not isValidApiUrl(API_BASE_URL) then
    destroyLoadingOverlay()
    warn("[NightFall] No valid HTTPS API URL. Set CONFIG.API_BASE_URL or api-url.txt on GitHub.")
    return
end

print("[NightFall] API -> " .. API_BASE_URL)
refreshApiUrlAsync()

local keyResult, keylessSource
local keyOk, keyUiErr = pcall(function()
    keyResult, keylessSource = acquireKey()
end)
if not keyOk then
    finishLoaderCleanup()
    warn("[NightFall] Key UI failed: " .. tostring(keyUiErr))
    return
end
if not keyResult then
    finishLoaderCleanup()
    warn("[NightFall] Loader cancelled.")
    return
end

local isKeyless = keyResult == KEYLESS_SENTINEL
setLoaderFlags(isKeyless, isKeyless and nil or keyResult)

if isKeyless then
    print("[NightFall] Keyless mode — premium features disabled.")
    if type(keylessSource) ~= "string" then
        finishLoaderCleanup()
        warn("[NightFall] Keyless download did not return a script.")
        return
    end
    runDownloadedSource(keylessSource, true)
    return
end

print("[NightFall] Premium key accepted.")
showDownloadStatus("Downloading NightFall...", nil)
startMovementKeeper()

local downloadedSource, downloadError = runAsync(function()
    local url = API_BASE_URL .. "/api/script?key=" .. HttpService:UrlEncode(keyResult)
        .. "&hwid=" .. HttpService:UrlEncode(HWID) .. "&t=" .. tostring(os.time())
    local raw, err = fastHttpGet(url, CONFIG.DOWNLOAD_TIMEOUT)
    if not raw then return nil, err end
    return parseDownloadSource(raw)
end, CONFIG.DOWNLOAD_TIMEOUT * 2)
finishLoaderCleanup()

if not downloadedSource then
    warn("[NightFall] " .. tostring(downloadError))
    return
end

setLoaderFlags(false, keyResult)
runDownloadedSource(downloadedSource, false)
