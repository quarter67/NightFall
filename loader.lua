--[[
    NightFall Loader (LootLabs Key System)
    Share this file / loadstring — do NOT share improved_script.lua directly

    Users run this → get key from your site → script loads automatically
]]

local CONFIG = {
    REQUIRED_PLACE_ID = 134225461562780,

    -- Your Render key server (no trailing slash)
    API_BASE_URL = "https://nightfall-keys.onrender.com",

    KEY_CACHE_PATH = "ScriptHub/nightfall_key.txt",
    MAX_ATTEMPTS = 5,
}

local LOADER_VERSION = "3.2-lootlabs"
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

if CONFIG.API_BASE_URL == "https://your-domain.com" then
    warn("[NightFall] Set CONFIG.API_BASE_URL in loader.lua to your deployed key site.")
    return
end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

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

local function httpRequestJson(url, method, body, headers)
    method = method or "GET"
    headers = headers or {}

    for attempt = 1, 3 do
        local ok, responseBody = pcall(function()
            if request then
                local res = request({
                    Url = url,
                    Method = method,
                    Headers = headers,
                    Body = body or "",
                })
                if res and res.Body then
                    return res.Body
                end
            end
            if method == "POST" then
                return game:HttpPost(url, body or "", true, headers["Content-Type"] or "application/json")
            end
            return game:HttpGet(url)
        end)

        if ok and responseBody and responseBody ~= "" then
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

    return nil, "Could not reach key server"
end

local function httpRequestRaw(url)
    for attempt = 1, 3 do
        local ok, responseBody = pcall(function()
            if request then
                local res = request({
                    Url = url,
                    Method = "GET",
                })
                if res and res.Body then
                    return res.Body
                end
            end
            return game:HttpGet(url)
        end)

        if ok and responseBody and responseBody ~= "" then
            if responseBody:find("<!DOCTYPE") or responseBody:find("<html") then
                if attempt < 3 then
                    task.wait(3)
                else
                    return nil, "Server waking up — wait 30 seconds and try again."
                end
            else
                return responseBody, nil
            end
        elseif attempt < 3 then
            task.wait(3)
        end
    end

    return nil, "Could not download script"
end

local function fetchGetKeyUrl()
    local data, err = httpRequestJson(
        CONFIG.API_BASE_URL .. "/api/get-link",
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

    local url = string.format(
        "%s/api/validate?key=%s&hwid=%s",
        CONFIG.API_BASE_URL,
        HttpService:UrlEncode(key:upper()),
        HttpService:UrlEncode(HWID)
    )

    local data, err = httpRequestJson(url, "GET")
    if not data then
        return false, err or "Validation failed."
    end

    if data.valid then
        return true, key:upper()
    end

    return false, formatKeyError(data.error)
end

local function downloadScript(key)
    local url = string.format(
        "%s/api/script?key=%s&hwid=%s&t=%s",
        CONFIG.API_BASE_URL,
        HttpService:UrlEncode(key),
        HttpService:UrlEncode(HWID),
        tostring(os.time())
    )

    local source, dlErr = httpRequestRaw(url)
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
    local CoreGui = game:GetService("CoreGui")
    local TweenService = game:GetService("TweenService")
    local player = Players.LocalPlayer

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
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 100
    gui.Parent = CoreGui

    local root = Instance.new("Frame")
    root.Size = UDim2.new(0, 420, 0, 300)
    root.Position = UDim2.new(0.5, -210, 0.5, -150)
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
    title.Font = Enum.Font.GothamBold
    title.TextSize = 22
    title.TextColor3 = COLORS.text
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = root

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -32, 0, 18)
    subtitle.Position = UDim2.new(0, 28, 0, 42)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "Enter your key to continue"
    subtitle.Font = Enum.Font.GothamMedium
    subtitle.TextSize = 12
    subtitle.TextColor3 = COLORS.textMuted
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = root

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -32, 0, 18)
    status.Position = UDim2.new(0, 16, 0, 72)
    status.BackgroundTransparency = 1
    status.Text = "Don't have a key? Click Get Key below."
    status.Font = Enum.Font.GothamMedium
    status.TextSize = 11
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
    box.Font = Enum.Font.GothamMedium
    box.TextSize = 14
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
    getKeyBtn.Font = Enum.Font.GothamSemibold
    getKeyBtn.TextSize = 14
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
    submitBtn.Font = Enum.Font.GothamBold
    submitBtn.TextSize = 14
    submitBtn.AutoButtonColor = false
    submitBtn.Parent = root
    corner(submitBtn, 10)

    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -32, 0, 40)
    hint.Position = UDim2.new(0, 16, 0, 200)
    hint.BackgroundTransparency = 1
    hint.Text = "Complete ad steps on the website. Key saves locally after login."
    hint.Font = Enum.Font.GothamMedium
    hint.TextSize = 11
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

        local link, err = fetchGetKeyUrl()
        if link and link ~= "" then
            if setclipboard then
                setclipboard(link)
                setStatus("Key link copied — paste in browser.", COLORS.success)
            else
                setStatus("Open: " .. CONFIG.API_BASE_URL, COLORS.accentLight)
            end
            print("[NightFall] Get key:", link)
        else
            setStatus("Get key failed: " .. tostring(err), COLORS.danger)
            warn("[NightFall] get-link failed:", tostring(err))
        end
    end)

    local function trySubmit()
        if done then return end

        attempts = attempts + 1
        if attempts > CONFIG.MAX_ATTEMPTS then
            setStatus("Too many failed attempts.", COLORS.danger)
            done = true
            task.delay(1.5, function()
                gui:Destroy()
            end)
            return
        end

        setStatus("Checking key...", COLORS.textMuted)
        submitBtn.Text = "Checking..."
        submitBtn.AutoButtonColor = false

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
            end)
            return
        end

        setStatus(keyOrErr, COLORS.danger)
        submitBtn.Text = "Continue"
    end

    submitBtn.MouseButton1Click:Connect(trySubmit)

    while not done do
        task.wait(0.1)
    end

    return resolvedKey
end

local validatedKey = nil
local cachedKey = fsRead(CONFIG.KEY_CACHE_PATH)
if cachedKey and cachedKey ~= "" then
    local valid, keyOrErr = validateKey(cachedKey)
    if valid then
        validatedKey = keyOrErr
        print("[NightFall] Cached key accepted.")
    else
        warn("[NightFall] Cached key invalid: " .. tostring(keyOrErr))
    end
end

if not validatedKey then
    validatedKey = createKeyUI()
end

if not validatedKey then
    warn("[NightFall] No valid key provided.")
    return
end

getgenv().SCRIPT_KEY = validatedKey

local source, dlErr = downloadScript(validatedKey)
if not source then
    warn("[NightFall] " .. tostring(dlErr))
    return
end

loadstring(source)()
