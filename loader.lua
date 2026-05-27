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
}

local LOADER_VERSION = "3.9-daki-delta"
print("[NightFall] Loader v" .. LOADER_VERSION)

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
local IS_MOBILE = UserInputService.TouchEnabled

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
    ["User-Agent"] = "NightFallLoader/3.7",
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

local function getGuiParent()
    if typeof(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and hui then
            return hui
        end
    end
    return game:GetService("CoreGui")
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

    local backdrop = Instance.new("Frame")
    backdrop.Name = "Backdrop"
    backdrop.Size = UDim2.fromScale(1, 1)
    backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    backdrop.BackgroundTransparency = IS_MOBILE and 0.35 or 0.45
    backdrop.BorderSizePixel = 0
    backdrop.Active = false
    backdrop.ZIndex = 1
    backdrop.Parent = gui

    local card = Instance.new("Frame")
    card.Name = "LoadingCard"
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.Size = IS_MOBILE and UDim2.new(0.88, 0, 0, 168) or UDim2.new(0, 320, 0, 140)
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
    title.TextSize = IS_MOBILE and 32 or 28
    title.TextColor3 = COLORS.text
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "Loading"
    title.Parent = card

    local subtitle = Instance.new("TextLabel")
    subtitle.Name = "Subtitle"
    subtitle.Size = UDim2.new(1, -40, 0, 44)
    subtitle.Position = UDim2.new(0, 32, 0, 62)
    subtitle.BackgroundTransparency = 1
    subtitle.Font = FONT_BODY
    subtitle.TextSize = IS_MOBILE and 15 or 13
    subtitle.TextColor3 = COLORS.textMuted
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.TextYAlignment = Enum.TextYAlignment.Top
    subtitle.TextWrapped = true
    subtitle.Text = message
    subtitle.Parent = card

    local dots = Instance.new("TextLabel")
    dots.Name = "Dots"
    dots.Size = UDim2.new(1, -40, 0, 20)
    dots.Position = UDim2.new(0, 32, 1, -34)
    dots.BackgroundTransparency = 1
    dots.Font = FONT_TITLE
    dots.TextSize = IS_MOBILE and 22 or 18
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

    LoadingOverlay = {
        gui = gui,
        subtitle = subtitle,
        stopAnimation = function()
            animRunning = false
        end,
    }

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

local API_BASE_URL = resolveApiUrl()
if not API_BASE_URL then
    warn("[NightFall] No valid HTTPS API URL. Upload api-url.txt to GitHub with your tunnel URL.")
    return
end

print("[NightFall] API → " .. API_BASE_URL)
showLoadingOverlay("Connecting to key server...")

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
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    gui.DisplayOrder = 999999
    gui.Parent = getGuiParent()
    protectGui(gui)

    local root = Instance.new("Frame")
    root.Size = IS_MOBILE and UDim2.new(0.92, 0, 0, 320) or UDim2.new(0, 420, 0, 300)
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.Position = UDim2.fromScale(0.5, 0.5)
    root.BackgroundColor3 = COLORS.bg
    root.BorderSizePixel = 0
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
    hint.Size = UDim2.new(1, -32, 0, 40)
    hint.Position = UDim2.new(0, 16, 0, 200)
    hint.BackgroundTransparency = 1
    hint.Text = "Complete ad steps on the website. Key saves locally after login."
    hint.Font = FONT_BODY
    hint.TextSize = IS_MOBILE and 13 or 11
    hint.TextColor3 = COLORS.textMuted
    hint.TextWrapped = true
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.Parent = root

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

    return keyReady.Event:Wait()
end

local function acquireKey()
    showLoadingOverlay("Checking saved key...")

    local cachedKey = fsRead(CONFIG.KEY_CACHE_PATH)
    if cachedKey and cachedKey ~= "" then
        local cachedResult = nil
        local finished = Instance.new("BindableEvent")

        task.spawn(function()
            local valid, keyOrErr = validateKey(cachedKey)
            if valid then
                cachedResult = keyOrErr
                print("[NightFall] Cached key accepted.")
            else
                warn("[NightFall] Cached key invalid: " .. tostring(keyOrErr))
            end
            finished:Fire()
        end)

        finished.Event:Wait()

        if cachedResult then
            return cachedResult
        end
    end

    hideLoadingOverlay()
    return createKeyUI()
end

local validatedKey = acquireKey()
if not validatedKey then
    destroyLoadingOverlay()
    warn("[NightFall] No valid key provided.")
    return
end

getgenv().SCRIPT_KEY = validatedKey

showLoadingOverlay("Downloading NightFall...")

local downloadedSource = nil
local downloadError = nil
local downloadDone = Instance.new("BindableEvent")

task.spawn(function()
    downloadedSource, downloadError = downloadScript(validatedKey)
    downloadDone:Fire()
end)

downloadDone.Event:Wait()

if not downloadedSource then
    destroyLoadingOverlay()
    warn("[NightFall] " .. tostring(downloadError))
    return
end

setLoadingMessage("Starting NightFall...")
task.wait(0.05)

loadstring(downloadedSource)()
destroyLoadingOverlay()
