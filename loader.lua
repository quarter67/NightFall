--[[
    NightFall Loader v5.1 — GUI ONLY
    This file ONLY opens the key menu. It does NOT download or run the script yet.

    loadstring(game:HttpGet("https://raw.githubusercontent.com/quarter67/NightFall/main/loader.lua?t=" .. tostring(os.time()) .. "&v=510"))()
]]

local VERSION = "5.1.0-gui-only"

local CONFIG = {
    PLACE_ID = 134225461562780,
}

print("[NightFall] Loader v" .. VERSION .. " (GUI only — no script load)")

-- ── Place check ─────────────────────────────────────────────────────────────

if game.PlaceId ~= CONFIG.PLACE_ID then
    warn("[NightFall] Wrong game.")
    return
end

-- ── Services ────────────────────────────────────────────────────────────────

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local IS_MOBILE = UIS.TouchEnabled == true

-- ── Keep Roblox movement working (we never disable it) ────────────────────────

local function keepMovementOn()
    pcall(function() GuiService.TouchControlsEnabled = true end)
end

keepMovementOn()

task.spawn(function()
    while true do
        keepMovementOn()
        task.wait(1)
    end
end)

-- ── Parent for our GUI only ─────────────────────────────────────────────────

local function getPlayerGui()
    local plr = Players.LocalPlayer
    if not plr then
        plr = Players.PlayerAdded:Wait()
    end
    local pg = plr:FindFirstChild("PlayerGui")
    if pg then return pg end
    return plr:WaitForChild("PlayerGui", 5)
end

-- ── Remove ONLY our old loader UI (never touch anything else) ───────────────

pcall(function()
    local pg = getPlayerGui()
    if not pg then return end
    local old = pg:FindFirstChild("NightFallKeyUI")
    if old then old:Destroy() end
end)

-- ── Build loader GUI ────────────────────────────────────────────────────────

local pg = getPlayerGui()
if not pg then
    warn("[NightFall] Could not find PlayerGui.")
    return
end

keepMovementOn()

local gui = Instance.new("ScreenGui")
gui.Name = "NightFallKeyUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 50
gui.Enabled = true
gui.Parent = pg

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.BackgroundColor3 = Color3.fromRGB(16, 17, 22)
panel.BorderSizePixel = 0
panel.Active = false
panel.ClipsDescendants = true
if IS_MOBILE then
    panel.AnchorPoint = Vector2.new(0.5, 0)
    panel.Position = UDim2.new(0.5, 0, 0, 8)
    panel.Size = UDim2.new(0.94, 0, 0, 280)
else
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.Size = UDim2.new(0, 380, 0, 320)
end
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(55, 58, 72)
stroke.Thickness = 1
stroke.Transparency = 0.35
stroke.Parent = panel

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 14, 0, 10)
title.Size = UDim2.new(1, -28, 0, 26)
title.Font = Enum.Font.GothamBold
title.TextSize = IS_MOBILE and 20 or 18
title.TextColor3 = Color3.fromRGB(240, 241, 245)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "NightFall"
title.Parent = panel

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.new(0, 14, 0, 36)
subtitle.Size = UDim2.new(1, -28, 0, 32)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 12
subtitle.TextColor3 = Color3.fromRGB(140, 144, 160)
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextYAlignment = Enum.TextYAlignment.Top
subtitle.TextWrapped = true
subtitle.Text = "Loader menu only — script loading comes next."
subtitle.Parent = panel

local status = Instance.new("TextLabel")
status.Name = "Status"
status.BackgroundTransparency = 1
status.Position = UDim2.new(0, 14, 0, 72)
status.Size = UDim2.new(1, -28, 0, 24)
status.Font = Enum.Font.GothamMedium
status.TextSize = 12
status.TextColor3 = Color3.fromRGB(52, 211, 153)
status.TextXAlignment = Enum.TextXAlignment.Left
status.Text = "Menu open — you can still walk and play."
status.Parent = panel

local box = Instance.new("TextBox")
box.Name = "KeyBox"
box.Position = UDim2.new(0, 14, 0, 104)
box.Size = UDim2.new(1, -28, 0, 34)
box.BackgroundColor3 = Color3.fromRGB(28, 30, 38)
box.TextColor3 = Color3.fromRGB(240, 241, 245)
box.PlaceholderText = "NF-XXXX-XXXX-XXXX"
box.PlaceholderColor3 = Color3.fromRGB(120, 124, 140)
box.Font = Enum.Font.Gotham
box.TextSize = 14
box.ClearTextOnFocus = false
box.Text = ""
box.Parent = panel

local boxCorner = Instance.new("UICorner")
boxCorner.CornerRadius = UDim.new(0, 8)
boxCorner.Parent = box

local boxPad = Instance.new("UIPadding")
boxPad.PaddingLeft = UDim.new(0, 10)
boxPad.PaddingRight = UDim.new(0, 10)
boxPad.Parent = box

local function makeBtn(name, text, xScale, widthScale, y, color)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(widthScale, 0, 0, 36)
    btn.Position = UDim2.new(xScale, 0, 0, y)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(240, 241, 245)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 13
    btn.AutoButtonColor = true
    btn.Parent = panel
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = btn
    return btn
end

local getKeyBtn = makeBtn("GetKey", "Get Key", 0, 0.48, 150, Color3.fromRGB(28, 30, 38))
local continueBtn = makeBtn("Continue", "Continue", 0.52, 0.48, 150, Color3.fromRGB(99, 102, 241))
local keylessBtn = makeBtn("Keyless", "Keyless (coming soon)", 0, 1, 196, Color3.fromRGB(28, 30, 38))

local hint = Instance.new("TextLabel")
hint.BackgroundTransparency = 1
hint.Position = UDim2.new(0, 14, 0, 242)
hint.Size = UDim2.new(1, -28, 0, 28)
hint.Font = Enum.Font.Gotham
hint.TextSize = 11
hint.TextColor3 = Color3.fromRGB(120, 124, 140)
hint.TextWrapped = true
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Text = "v" .. VERSION .. " · GUI test build · no HTTP · no script run"
hint.Parent = panel

-- ── Buttons (placeholder — no download / no loadstring yet) ────────────────

local function setStatus(msg)
    status.Text = msg
    print("[NightFall] " .. msg)
end

local function onTap(btn, fn)
    if IS_MOBILE then
        btn.Activated:Connect(fn)
    else
        btn.MouseButton1Click:Connect(fn)
    end
end

onTap(getKeyBtn, function()
    setStatus("Get Key — not wired yet (GUI test).")
end)

onTap(continueBtn, function()
    local key = box.Text:gsub("^%s+", ""):gsub("%s+$", "")
    if key == "" then
        setStatus("Enter a key first.")
        return
    end
    setStatus("Key saved for later — script load not enabled yet.")
end)

onTap(keylessBtn, function()
    setStatus("Keyless — script load not enabled yet.")
end)

keepMovementOn()
print("[NightFall] Loader GUI shown.")
