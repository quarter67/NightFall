--[[
    NightFall Loader (Junkie Key System)
    Share this file / loadstring — do NOT share improved_script.lua directly

    Dashboard setup:
    1. Create a service named "nightfall" on jnkie.com
    2. Set JUNKIE_IDENTIFIER to your dashboard user ID
    3. Upload improved_script.lua to Junkie CDN and paste the download URL below
       (or leave JUNKIE_SCRIPT_URL empty to load from GitHub after key check)
]]

local CONFIG = {
    REQUIRED_PLACE_ID = 134225461562780,

    JUNKIE_SERVICE = "nightfall",
    JUNKIE_IDENTIFIER = "1111611",
    JUNKIE_PROVIDER = "Mixed",

    -- Paste from Junkie dashboard after uploading the script (recommended for production)
    JUNKIE_SCRIPT_URL = "https://api.jnkie.com/api/v1/luascripts/public/6184ece50b3bd7920c9c2ee296c7d9e3ec20db1d89c12d1882226c7533a8f910/download",

    GITHUB_SCRIPT_URL = "https://raw.githubusercontent.com/quarter67/NightFall/main/improved_script.lua?v=",

    KEY_CACHE_PATH = "ScriptHub/junkie_key.txt",
    MAX_ATTEMPTS = 5,
}

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

if CONFIG.JUNKIE_IDENTIFIER == "REPLACE_WITH_YOUR_JUNKIE_USER_ID" then
    warn("[NightFall] Set CONFIG.JUNKIE_IDENTIFIER in loader.lua to your Junkie dashboard user ID.")
    return
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

local function loadJunkie()
    local ok, lib = pcall(function()
        return loadstring(game:HttpGet("https://jnkie.com/sdk/library.lua"))()
    end)
    if not ok or not lib then
        warn("[NightFall] Failed to load Junkie SDK.")
        return nil
    end

    lib.service = CONFIG.JUNKIE_SERVICE
    lib.identifier = CONFIG.JUNKIE_IDENTIFIER
    lib.provider = CONFIG.JUNKIE_PROVIDER
    return lib
end

local function formatKeyError(message)
    local msg = message or "Invalid key"
    if msg == "KEY_EXPIRED" then
        return "Key expired — get a new one."
    elseif msg == "HWID_BANNED" then
        return "Hardware banned."
    elseif msg == "KEY_INVALIDATED" then
        return "Key was revoked."
    elseif msg == "ALREADY_USED" then
        return "Key already used."
    elseif msg == "HWID_MISMATCH" then
        return "HWID limit reached for this key."
    elseif msg == "SERVICE_MISMATCH" then
        return "Key is for a different script."
    elseif msg == "PREMIUM_REQUIRED" then
        return "Premium key required."
    end
    return msg
end

local function validateKey(Junkie, key)
    if not key or key == "" then
        return false, "Enter a key."
    end

    local ok, result = pcall(function()
        return Junkie.check_key(key)
    end)

    if not ok or not result then
        return false, "Validation failed. Try again."
    end

    if result.valid then
        return true, key
    end

    return false, formatKeyError(result.message or result.error)
end

local function createKeyUI(Junkie)
    local Players = game:GetService("Players")
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
    subtitle.Text = "Enter your Junkie key to continue"
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
    box.PlaceholderText = "Paste key here..."
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
    hint.Text = "Your key is saved locally after first login."
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
        local ok, link = pcall(function()
            return Junkie.get_key_link()
        end)

        if ok and link and link ~= "" then
            if setclipboard then
                setclipboard(link)
                setStatus("Key link copied to clipboard.", COLORS.success)
            else
                setStatus("Key link: " .. link, COLORS.accentLight)
            end
        else
            setStatus("Please wait a few minutes before requesting another link.", COLORS.danger)
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

        local valid, keyOrErr = validateKey(Junkie, box.Text:gsub("^%s+", ""):gsub("%s+$", ""))
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

        if keyOrErr == "Hardware banned." then
            setStatus(keyOrErr, COLORS.danger)
            done = true
            task.delay(0.5, function()
                gui:Destroy()
                player:Kick("[NightFall] Hardware banned.")
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

local Junkie = loadJunkie()
if not Junkie then
    return
end

local validatedKey = nil
local cachedKey = fsRead(CONFIG.KEY_CACHE_PATH)
if cachedKey and cachedKey ~= "" then
    local valid, keyOrErr = validateKey(Junkie, cachedKey)
    if valid then
        validatedKey = keyOrErr
        print("[NightFall] Cached key accepted.")
    else
        warn("[NightFall] Cached key invalid: " .. tostring(keyOrErr))
    end
end

if not validatedKey then
    validatedKey = createKeyUI(Junkie)
end

if not validatedKey then
    warn("[NightFall] No valid key provided.")
    return
end

getgenv().SCRIPT_KEY = validatedKey

local scriptUrl = CONFIG.JUNKIE_SCRIPT_URL
if not scriptUrl or scriptUrl == "" then
    scriptUrl = CONFIG.GITHUB_SCRIPT_URL .. tostring(os.time())
end

local ok, source = pcall(function()
    return game:HttpGet(scriptUrl)
end)

if not ok or not source then
    warn("[NightFall] Failed to download script.")
    return
end

loadstring(source)()
