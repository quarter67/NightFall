-- SurviveHomelanderMobilekeyless
-- BUILD: 2026-05-27-MOBILE-KEYLESS1
-- Keyless mobile build — full hub, premium features disabled (no key required)

if typeof(getgenv) == "function" then
    pcall(function() getgenv().NF_FORCE_MOBILE = true end)
elseif typeof(shared) == "table" then
    shared.NF_FORCE_MOBILE = true
else
    _G.NF_FORCE_MOBILE = true
end

local NF = { State = {}, UI = {}, F = {}, COLORS = {}, CONST = {} }
local State = NF.State
local UI = NF.UI
local F = NF.F
local COLORS = NF.COLORS
local CONST = NF.CONST

local function resolveScriptAccess()
    return false, true
end

local isPremium, allowRun = resolveScriptAccess()
if not allowRun then
    warn("[SurviveHomelander] Keyless build failed to start.")
    return
end

State.isPremium = isPremium
State.isKeyless = not isPremium

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
if not player then
    player = Players.PlayerAdded:Wait()
end
local root = nil
local camera = Workspace.CurrentCamera

local ejectScript
do -- scope block 0 (core + GUI builders; Luau local register limit)
local function detectMobileDevice()
    if typeof(getgenv) == "function" then
        local g = getgenv()
        if g.NF_FORCE_MOBILE == true then return true end
        if g.NF_FORCE_MOBILE == false then return false end
    end
    if UserInputService.TouchEnabled then return true end
    if UserInputService.GyroscopeEnabled then return true end
    if UserInputService.AccelerometerEnabled then return true end
    local cam = Workspace.CurrentCamera
    if cam then
        local vp = cam.ViewportSize
        if vp.X > 0 and vp.Y > vp.X and vp.X < 980 then
            return true
        end
    end
    return false
end

State.isMobile = detectMobileDevice()

local function resolveGuiParent()
    if State.isMobile and player then
        local pg = player:FindFirstChild("PlayerGui")
        if not pg then
            pg = player:WaitForChild("PlayerGui", 8)
        end
        if pg then return pg end
    end
    if typeof(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and hui then return hui end
    end
    if State.isMobile and player then
        local pg = player:FindFirstChild("PlayerGui")
        if pg then return pg end
    end
    return CoreGui
end

-- PlayerGui on mobile keeps the game's touch thumbstick working (CoreGui can block it).
local GUI_PARENT = resolveGuiParent()

local function dismissNightFallLoaderUi()
    local targets = { "NightFallLoaderOverlay", "NightFallKeyUI", "NightFallPCKeyUI", "NightFallLoaderUI" }
    local parents = {}
    if player then
        local pg = player:FindFirstChild("PlayerGui")
        if pg then table.insert(parents, pg) end
    end
    table.insert(parents, CoreGui)
    if typeof(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and hui then table.insert(parents, hui) end
    end
    for _, parent in ipairs(parents) do
        for _, name in ipairs(targets) do
            local gui = parent:FindFirstChild(name)
            if gui then
                pcall(function() gui:Destroy() end)
            end
        end
    end
end

dismissNightFallLoaderUi()

local function mobileUnblockInput()
    if not State.isMobile then return end
    pcall(function() GuiService.TouchControlsEnabled = true end)
    pcall(function()
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.PlatformStand = false
            hum.AutoRotate = true
            if hum.WalkSpeed <= 0 then
                hum.WalkSpeed = 16
            end
        end
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.Anchored = false
        end
    end)
end

mobileUnblockInput()
task.spawn(function()
    for _ = 1, 60 do
        mobileUnblockInput()
        task.wait(1)
    end
end)

-- Workspace.CurrentCamera is replaced by Roblox on death/respawn and after some
-- camera-control scripts run. Keep our local `camera` reference fresh so the
-- aimbot, freecam, spectate, etc. don't silently break a few minutes in.
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    local cam = Workspace.CurrentCamera
    if cam then camera = cam end
end)

local function refreshCamera()
    local cam = Workspace.CurrentCamera
    if cam then camera = cam end
    return cam
end

local function restoreAimbotCamera()
    local cam = refreshCamera()
    if not cam then return end
    pcall(function()
        local needsSubject = cam.CameraType == Enum.CameraType.Scriptable
            or State.aimbotSavedCameraType ~= nil
        if State.aimbotSavedCameraType then
            cam.CameraType = State.aimbotSavedCameraType
        elseif cam.CameraType == Enum.CameraType.Scriptable then
            cam.CameraType = Enum.CameraType.Custom
        end
        if needsSubject then
            local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                cam.CameraSubject = hum
            end
        end
        if State.isMobile then
            pcall(function()
                player.CameraMinZoomDistance = State.cameraSavedMinZoom or 0.5
                player.CameraMaxZoomDistance = State.cameraSavedMaxZoom or 400
            end)
        end
    end)
    State.aimbotSavedCameraType = nil
    State.mobileAimCamFlatDist = nil
    State.mobileAimCamHeight = nil
end

local function cameraNeedsAimbotRestore()
    if State.freecamEnabled or State.spectating or State.ejected then
        return false
    end
    if State.isMobile and State.holdingMobileAim then
        return false
    end
    local cam = refreshCamera()
    if not cam then return false end
    if State.aimbotSavedCameraType then return true end
    return cam.CameraType == Enum.CameraType.Scriptable
end

local function ensureGameplayCamera()
    if not cameraNeedsAimbotRestore() then return end
    restoreAimbotCamera()
end

local function isAimHoldActive()
    if State.isMobile then
        return State.holdingMobileAim
    end
    return State.holdingRightClick
end

local function detectGameShiftLock()
    if State.isMobile or State.freecamEnabled or State.spectating then
        return false
    end
    -- Do not treat our own LockCenter as game shift lock (causes stuck cursor).
    -- Rivals: Left Alt shift lock hides the cursor and pins it to screen center.
    if UserInputService.MouseIconEnabled then
        return false
    end
    local cam = workspace.CurrentCamera
    if not cam then return false end
    local loc = UserInputService:GetMouseLocation()
    local vp = cam.ViewportSize
    local ok, inset = pcall(function() return GuiService:GetGuiInset() end)
    local ix = ok and inset and inset.X or 0
    local iy = ok and inset and inset.Y or 0
    local cx = vp.X * 0.5 + ix
    local cy = vp.Y * 0.5 + iy
    local tol = math.clamp(math.min(vp.X, vp.Y) * 0.04, 16, 48)
    return math.abs(loc.X - cx) <= tol and math.abs(loc.Y - cy) <= tol
end

local function isPcShiftLocked()
    if State.isMobile then return false end
    return State.shiftLockActive == true
end

local function refreshShiftLockState()
    if State.isMobile or State.freecamEnabled or State.spectating then
        State.shiftLockActive = false
        return
    end
    if State.shiftLockSuppressed or State.shiftLockAutoSynced then
        return
    end
    -- One-time sync if already shift locked before the script loaded (e.g. Rivals Alt lock).
    if detectGameShiftLock() then
        State.shiftLockActive = true
    end
    State.shiftLockAutoSynced = true
end

local function handleShiftLockKeyPress()
    State.shiftLockActive = not State.shiftLockActive
    if State.shiftLockActive then
        State.shiftLockSuppressed = false
        setAimbotShiftCursorLocked(true)
    else
        State.shiftLockSuppressed = true
        State.nfOwnsShiftLockCursor = false
        setAimbotShiftCursorLocked(false)
        pcall(function()
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
        end)
        if UI.AimCursor then
            UI.AimCursor.Visible = false
        end
    end
end

local function keyCodeToDisplay(keyCode)
    if not keyCode or keyCode == Enum.KeyCode.Unknown then return "None" end
    return (keyCode.Name or tostring(keyCode))
        :gsub("Left", "L")
        :gsub("Right", "R")
end

local function inputToKeyCode(input)
    if input.KeyCode and input.KeyCode ~= Enum.KeyCode.Unknown then
        return input.KeyCode
    end
    return nil
end

local function isShiftLockKeyInput(input)
    if not State.shiftLockKey then return false end
    return input.KeyCode == State.shiftLockKey
end

local function getAimReferenceUsesCenter()
    if State.isMobile then
        return State.holdingMobileAim
    end
    return isPcShiftLocked()
end

local function getAimHoldButton()
    return State.swappedMouseButtons and Enum.UserInputType.MouseButton1
        or Enum.UserInputType.MouseButton2
end

local function syncPcAimHoldState()
    if State.isMobile or not State.aimbotEnabled then return end
    if State.freecamEnabled or State.spectating then return end
    State.holdingRightClick = UserInputService:IsMouseButtonPressed(getAimHoldButton())
end

local function isRobloxCameraDragging()
    if State.isMobile then return false end
    return UserInputService.MouseBehavior == Enum.MouseBehavior.LockCurrentPosition
end

local function ensurePcAimMouseFree()
    -- Only unlock the mouse for aimbot while actively holding aim - never override Roblox camera drag.
    if State.isMobile or not State.aimbotEnabled or not isAimHoldActive() then return end
    if isPcShiftLocked() or isRobloxCameraDragging() then return end
    pcall(function()
        if State.nfOwnsShiftLockCursor and UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
            State.nfOwnsShiftLockCursor = false
        elseif UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCurrentPosition then
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
        end
    end)
end

local AIM_CURSOR_GUI_POS = UDim2.new(0.5, -2, 0.5, -2)
local AIM_CURSOR_SCREEN_OFFSET = Vector2.new(-2, -2)

local function releaseScriptShiftLockCursor()
    if State.isMobile then return end
    if UI.AimCursor then
        UI.AimCursor.Visible = false
    end
    if not State.nfOwnsShiftLockCursor then return end
    State.nfOwnsShiftLockCursor = false
    pcall(function()
        if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        end
        if not isRobloxCameraDragging() then
            UserInputService.MouseIconEnabled = true
        end
    end)
end

local function setAimbotShiftCursorLocked(locked)
    if State.isMobile then return end
    if locked then
        pcall(function()
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
            UserInputService.MouseIconEnabled = false
            State.nfOwnsShiftLockCursor = true
        end)
        if UI.AimCursor then
            UI.AimCursor.Visible = true
            UI.AimCursor.Position = AIM_CURSOR_GUI_POS
        end
    else
        releaseScriptShiftLockCursor()
    end
end

local function maintainPcShiftLockCursor()
    if State.isMobile or State.ejected then return end
    if State.freecamEnabled or State.spectating then
        releaseScriptShiftLockCursor()
        return
    end
    if isRobloxCameraDragging() then
        return
    end
    if State.shiftLockActive then
        setAimbotShiftCursorLocked(true)
    else
        releaseScriptShiftLockCursor()
    end
end

local function getShiftLockAimScreen()
    local cam = refreshCamera()
    if not cam then
        local loc = UserInputService:GetMouseLocation()
        return Vector2.new(loc.X, loc.Y)
    end
    local vp = cam.ViewportSize
    return Vector2.new(vp.X / 2 + AIM_CURSOR_SCREEN_OFFSET.X, vp.Y / 2 + AIM_CURSOR_SCREEN_OFFSET.Y)
end

local AIM_VIEWPORT_INSET_Y = 36

local function getViewportInsetY()
    local ok, inset = pcall(function() return GuiService:GetGuiInset() end)
    if ok and inset then
        return math.clamp(inset.Y, 0, 58)
    end
    return AIM_VIEWPORT_INSET_Y
end

local function getRealMouseViewport()
    local loc = UserInputService:GetMouseLocation()
    return Vector2.new(loc.X, loc.Y - getViewportInsetY())
end

local function syncPcAimCursorFromSystem()
    if State.isMobile then return end
    State.aimbotCursorPos = getRealMouseViewport()
end

local function clearPcAimCursor()
    State.aimbotCursorPos = nil
end

State.ejected = false
State.holdingRightClick = false
State.holdingMobileAim = false
State.mobileAimCamFlatDist = nil
State.mobileAimCamHeight = nil
State.shiftLockActive = false
State.shiftLockSuppressed = false
State.nfOwnsShiftLockCursor = false
State.shiftLockAutoSynced = false
State.mobileAimDragUnlocked = false
State.trackedConnections = {}
State.hubSliderDrag = nil
State.capturedDefaultSpeed = false
State.guiScale = 1.0
State.lastTouchScreenPos = nil
State.mobileFlightUp = false
State.mobileFlightDown = false
State.hideMobileGui = false
State.failsafeEnabled = false
State.failsafeThreshold = 25 -- teleports when HP % drops BELOW this value
State.failsafeTripped = false
State.failsafeReturnCFrame = nil
State.aimbotDelayMs = 0 -- 0 = fast lock; higher = smoother/slower
State.aimbotTargetPart = "Head"
State.shiftLockKey = Enum.KeyCode.LeftAlt
State.hubKeybindListen = nil

local function mouseScreenToViewport(screenX, screenY)
    return Vector2.new(screenX, screenY - AIM_VIEWPORT_INSET_Y)
end

local function viewportToMouseScreen(vpX, vpY)
    return vpX, vpY + getViewportInsetY()
end

-- Populate in place ??? do NOT reassign NF.COLORS (local COLORS alias would stay empty).
COLORS.bg = Color3.fromRGB(13, 14, 18)
COLORS.sidebar = Color3.fromRGB(16, 17, 23)
COLORS.surface = Color3.fromRGB(22, 24, 31)
COLORS.surfaceHover = Color3.fromRGB(28, 30, 40)
COLORS.elevated = Color3.fromRGB(34, 36, 46)
COLORS.border = Color3.fromRGB(44, 46, 58)
COLORS.tabActive = Color3.fromRGB(99, 102, 241)
COLORS.tabActiveBg = Color3.fromRGB(28, 30, 48)
COLORS.text = Color3.fromRGB(236, 237, 242)
COLORS.textDark = Color3.fromRGB(255, 255, 255)
COLORS.textMuted = Color3.fromRGB(128, 132, 150)
COLORS.accent = Color3.fromRGB(99, 102, 241)
COLORS.accentLight = Color3.fromRGB(129, 140, 248)
COLORS.accentOn = Color3.fromRGB(56, 189, 248)
COLORS.success = Color3.fromRGB(52, 211, 153)
COLORS.danger = Color3.fromRGB(239, 68, 68)
COLORS.toggleCube = Color3.fromRGB(99, 102, 241)
COLORS.track = Color3.fromRGB(18, 19, 26)
COLORS.toggleOff = Color3.fromRGB(55, 58, 72)
COLORS.toggleOn = Color3.fromRGB(99, 102, 241)

CONST.RADIUS = { sm = 6, md = 10, lg = 14, xl = 20, full = 999 }
CONST.SIDEBAR_WIDTH = 132

-- ASCII-safe icons (UTF-8 emoji show as ??? in Roblox Gotham on many executors)
CONST.ICON = {
    tabHome = "H",
    tabScanner = "S",
    tabMovement = "M",
    tabPremium = "P",
    tabCombat = "C",
    tabTroll = "T",
    tabMisc = "B",
    tabSettings = "G",
    foldClosed = "+",
    foldOpen = "-",
    close = "X",
    flightUp = "^",
    flightDown = "v",
    tempv = "*",
    dot = "-",
    dash = "-",
}

local function tween(instance, props, duration)
    if State.isMobile then
        -- Skip animations on mobile ??? apply instantly to save CPU/GPU
        for k, v in pairs(props) do
            pcall(function() instance[k] = v end)
        end
        return
    end
    TweenService:Create(
        instance,
        TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        props
    ):Play()
end

local function applyCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or CONST.RADIUS.md)
    corner.Parent = parent
    return corner
end

local function applyStroke(parent, color, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or COLORS.border
    stroke.Thickness = thickness or 1
    stroke.Transparency = transparency or 0.55
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = parent
    return stroke
end

local HttpService = game:GetService("HttpService")

CONST.AIM_POS_PATH    = "ScriptHub/aim_btn_pos.txt"
CONST.TOGGLE_POS_PATH = "ScriptHub/toggle_pos.txt"
CONST.TOGGLE_SIZE_PATH = "ScriptHub/toggle_size.txt"
CONST.GUI_SCALE_PATH  = "ScriptHub/gui_scale.txt"
CONST.HIDE_MOBILE_PATH = "ScriptHub/hide_mobile_gui.txt"
CONST.FAILSAFE_PATH     = "ScriptHub/failsafe.txt"
CONST.AIMBOT_PATH       = "ScriptHub/aimbot.txt"

-- Safe zone coordinates (manual TP + failsafe destination)
CONST.SAFE_ZONE_CFRAME = CFrame.new(296.5682678222656, 22.201051712036133, -255.1030731201172)

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

local function bindConnection(conn)
    table.insert(State.trackedConnections, conn)
    return conn
end

local function guiPassThrough(root)
    if not root then return end
    for _, child in ipairs(root:GetDescendants()) do
        if child:IsA("GuiObject") and child.Name ~= "HitLayer" then
            child.Active = false
        end
    end
end

local function passiveContainer(gui)
    if gui and gui:IsA("GuiObject") and not gui:IsA("GuiButton") and not gui:IsA("ScrollingFrame") then
        gui.Active = false
    end
end

local function addButtonHitLayer(btn)
    if not btn or btn:FindFirstChild("HitLayer") then return end
    local hit = Instance.new("TextButton")
    hit.Name = "HitLayer"
    hit.Size = UDim2.new(1, 0, 1, 0)
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.ZIndex = 50
    hit.Active = true
    hit.Selectable = false
    hit.AutoButtonColor = false
    hit.Parent = btn
end

local function pointInGui(gui, screenPos)
    if not gui or not gui:IsA("GuiObject") or not gui.Parent or not gui.Visible then return false end
    if not gui.Active and gui.Name ~= "HitLayer" then return false end
    local ap = gui.AbsolutePosition
    local as = gui.AbsoluteSize
    if as.X < 2 or as.Y < 2 then return false end
    return screenPos.X >= ap.X and screenPos.X <= ap.X + as.X
        and screenPos.Y >= ap.Y and screenPos.Y <= ap.Y + as.Y
end

State.hubClickRegistry = State.hubClickRegistry or {}
State.hubActiveTouch = nil
State.hubTouchClaimed = false

local function ensureHubTouchMobile()
    if State.hubTouchMobileReady then return end
    State.hubTouchMobileReady = true

    bindConnection(UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch then return end
        State.hubActiveTouch = input
        State.hubTouchClaimed = false
    end))

    bindConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch then return end
        if State.hubActiveTouch == input then
            State.hubActiveTouch = nil
        end
    end))
end

local function bindHubClick(btn, fn)
    if not btn or type(fn) ~= "function" then return end

    local useMobileDirect = UserInputService.TouchEnabled or State.isMobile

    if useMobileDirect then
        ensureHubTouchMobile()
        if not btn:FindFirstChild("HitLayer") then
            addButtonHitLayer(btn)
        end
        guiPassThrough(btn)
        btn.Active = false

        local lastFire = 0
        local function fire()
            if State.hubTouchClaimed then return end
            local now = tick()
            if now - lastFire < 0.22 then return end
            State.hubTouchClaimed = true
            lastFire = now
            task.defer(fn)
        end

        local hit = btn:FindFirstChild("HitLayer")
        if hit then
            bindConnection(hit.Activated:Connect(fire))
        end
        return
    end

    if not btn:FindFirstChild("HitLayer") then
        addButtonHitLayer(btn)
    end
    guiPassThrough(btn)

    local lastFire = 0
    local function fire()
        local now = tick()
        if now - lastFire < 0.15 then return end
        lastFire = now
        task.defer(fn)
    end

    State.hubClickRegistry[btn] = fire
    local hit = btn:FindFirstChild("HitLayer")
    if hit then
        State.hubClickRegistry[hit] = fire
    end

    bindConnection(btn.MouseButton1Click:Connect(fire))
    bindConnection(btn.Activated:Connect(fire))

    if btn:IsA("GuiButton") then
        pcall(function()
            bindConnection(btn.TouchTap:Connect(fire))
        end)
    end

    if hit then
        bindConnection(hit.MouseButton1Click:Connect(fire))
        bindConnection(hit.Activated:Connect(fire))
    end
end

-- Safe root update with error handling
local function updateRoot()
    local success, err = pcall(function()
        if player.Character then
            root = player.Character:WaitForChild("HumanoidRootPart", 5)
        end
    end)
    if not success then
        warn("Failed to update root:", err)
    end
end

player.CharacterAdded:Connect(updateRoot)
if player.Character then 
    updateRoot() 
end

local function getHumanoid()
    local character = player.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
    local character = player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

-- Hub GUI (XVC-style)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ScriptHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 1000
ScreenGui.Parent = GUI_PARENT
UI.ScreenGui = ScreenGui

UI.AimCursor = Instance.new("Frame")
UI.AimCursor.Name = "AimCursor"
UI.AimCursor.Size = UDim2.new(0, 5, 0, 5)
UI.AimCursor.AnchorPoint = Vector2.new(0.5, 0.5)
UI.AimCursor.Position = AIM_CURSOR_GUI_POS
UI.AimCursor.BackgroundColor3 = COLORS.accentLight
UI.AimCursor.BorderSizePixel = 0
UI.AimCursor.Visible = false
UI.AimCursor.Active = false
UI.AimCursor.ZIndex = 200
UI.AimCursor.Parent = ScreenGui
local aimCursorCorner = Instance.new("UICorner")
aimCursorCorner.CornerRadius = UDim.new(1, 0)
aimCursorCorner.Parent = UI.AimCursor

-- Default: center of the screen (button is 90x90, so offset by -45)
local DEFAULT_AIM_POS = UDim2.new(0.5, -45, 0.5, -45)

local function loadAimButtonPos()
    local data = fsRead(CONST.AIM_POS_PATH)
    if data then
        -- New format: "xs,xo,ys,yo" (Scale + Offset for both axes)
        local xs, xo, ys, yo = data:match("([^,]+),([^,]+),([^,]+),([^,]+)")
        if xs and xo and ys and yo then
            return UDim2.new(tonumber(xs), tonumber(xo), tonumber(ys), tonumber(yo))
        end
        -- Old 2-value format saved Offset only and dropped Scale, which left old
        -- bottom-right defaults rendering at literal pixel (-96, -120) (off-screen).
        -- Discard such entries and fall through to the default.
        local x, y = data:match("([^,]+),([^,]+)")
        if x and y then
            local nx, ny = tonumber(x), tonumber(y)
            if nx and ny and nx >= 0 and ny >= 0 then
                return UDim2.new(0, nx, 0, ny)
            end
        end
    end
    return DEFAULT_AIM_POS
end

local function saveAimButtonPos(pos)
    fsWrite(CONST.AIM_POS_PATH, string.format("%s,%s,%s,%s",
        tostring(pos.X.Scale), tostring(pos.X.Offset),
        tostring(pos.Y.Scale), tostring(pos.Y.Offset)))
end

local function getDefaultTogglePos()
    local size = State.toggleCubeSize or tonumber(fsRead(CONST.TOGGLE_SIZE_PATH)) or 36
    local cam = Workspace.CurrentCamera
    if cam then
        local vp = cam.ViewportSize
        if vp.X > 0 and vp.Y > 0 then
            return UDim2.new(0, math.floor((vp.X - size) / 2), 0, math.floor((vp.Y - size) / 2))
        end
    end
    return UDim2.new(0.5, -math.floor(size / 2), 0.5, -math.floor(size / 2))
end

local function loadTogglePos()
    local data = fsRead(CONST.TOGGLE_POS_PATH)
    if data then
        local x, y = data:match("([^,]+),([^,]+)")
        if x and y then
            return UDim2.new(0, tonumber(x), 0, tonumber(y))
        end
    end
    return getDefaultTogglePos()
end

local function saveTogglePos(pos)
    fsWrite(CONST.TOGGLE_POS_PATH, tostring(pos.X.Offset) .. "," .. tostring(pos.Y.Offset))
end

local function loadToggleSize()
    return tonumber(fsRead(CONST.TOGGLE_SIZE_PATH)) or 36
end

local function loadGuiScale()
    local saved = tonumber(fsRead(CONST.GUI_SCALE_PATH))
    if saved and saved >= 0.3 and saved <= 1.0 then return saved end
    return State.isMobile and 0.62 or 1.0
end

local function applyGuiScale(scale)
    State.guiScale = math.clamp(scale, 0.3, 1.0)
    if UI.WindowScale then
        UI.WindowScale.Scale = State.guiScale
    end
    if UI.ShadowScale then
        UI.ShadowScale.Scale = State.guiScale
    end
    if UI.MainShadow and UI.MainFrame then
        syncMainShadowPosition()
    end
    pcall(function() fsWrite(CONST.GUI_SCALE_PATH, tostring(State.guiScale)) end)
end

-- "Remove Mobile GUI" toggle: hides the LOCK ON button, FOV circle, and mobile
-- flight up/down buttons so they don't clutter the screen when playing on PC.
local function loadHideMobileGui()
    local data = fsRead(CONST.HIDE_MOBILE_PATH)
    return data == "1" or data == "true"
end

local function applyHideMobileGui(hidden)
    State.hideMobileGui = hidden and true or false
    local show = not State.hideMobileGui and State.aimbotEnabled
    if UI.MobileAimGui then UI.MobileAimGui.Enabled = show end
    if UI.FovGui then UI.FovGui.Enabled = show end
    pcall(function()
        fsWrite(CONST.HIDE_MOBILE_PATH, State.hideMobileGui and "1" or "0")
    end)
end

local function loadFailsafeSettings()
    local data = fsRead(CONST.FAILSAFE_PATH)
    if not data then return end
    local enabled, threshold = data:match("([^,]+),([^,]+)")
    if enabled then
        State.failsafeEnabled = (enabled == "1" or enabled == "true")
    end
    if threshold then
        local n = tonumber(threshold)
        if n and n >= 1 and n <= 100 then
            State.failsafeThreshold = n
        end
    end
end

local function saveFailsafeSettings()
    pcall(function()
        fsWrite(CONST.FAILSAFE_PATH, (State.failsafeEnabled and "1" or "0") .. "," .. tostring(State.failsafeThreshold))
    end)
end

loadFailsafeSettings()

local function loadAimbotSettings()
    local data = fsRead(CONST.AIMBOT_PATH)
    if not data then return end
    local delay, part, keyName = data:match("([^,]+),([^,]+),([^,]+)")
    if not keyName then
        delay, part = data:match("([^,]+),([^,]+)")
    end
    if delay then
        local n = tonumber(delay)
        if n and n >= 0 and n <= 500 then
            State.aimbotDelayMs = n
        end
    end
    if part and part ~= "" then
        State.aimbotTargetPart = part
    end
    if keyName and keyName ~= "" and Enum.KeyCode[keyName] then
        State.shiftLockKey = Enum.KeyCode[keyName]
    end
end

local function saveAimbotSettings()
    pcall(function()
        local keyName = State.shiftLockKey and State.shiftLockKey.Name or "LeftAlt"
        fsWrite(
            CONST.AIMBOT_PATH,
            tostring(State.aimbotDelayMs or 0)
                .. ","
                .. tostring(State.aimbotTargetPart or "Head")
                .. ","
                .. keyName
        )
    end)
end

loadAimbotSettings()

local function applyToggleCubeSize(size)
    State.toggleCubeSize = size
    if UI.ToggleCube then
        UI.ToggleCube.Size = UDim2.new(0, size, 0, size)
    end
    if UI.ToggleIcon then
        UI.ToggleIcon.TextSize = math.clamp(math.floor(size * 0.44), 10, 28)
    end
    if UI.ToggleCorner then
        UI.ToggleCorner.CornerRadius = UDim.new(0, math.clamp(math.floor(size * 0.22), 4, 14))
    end
    fsWrite(CONST.TOGGLE_SIZE_PATH, tostring(size))
end

State.toggleCubeSize = loadToggleSize()

UI.ToggleGui = Instance.new("ScreenGui")
UI.ToggleGui.Name = "ScriptHubToggle"
UI.ToggleGui.ResetOnSpawn = false
UI.ToggleGui.IgnoreGuiInset = true
UI.ToggleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
UI.ToggleGui.DisplayOrder = 10
UI.ToggleGui.Parent = GUI_PARENT

UI.ToggleCube = Instance.new("TextButton")
UI.ToggleCube.Name = "ToggleCube"
UI.ToggleCube.Size = UDim2.new(0, State.toggleCubeSize, 0, State.toggleCubeSize)
UI.ToggleCube.Position = loadTogglePos()
UI.ToggleCube.BackgroundColor3 = COLORS.elevated
UI.ToggleCube.Text = ""
UI.ToggleCube.AutoButtonColor = false
UI.ToggleCube.Parent = UI.ToggleGui

UI.ToggleCorner = Instance.new("UICorner")
UI.ToggleCorner.CornerRadius = UDim.new(0, 10)
UI.ToggleCorner.Parent = UI.ToggleCube

local ToggleStroke = Instance.new("UIStroke")
ToggleStroke.Color = COLORS.accent
ToggleStroke.Thickness = 1.5
ToggleStroke.Transparency = 0.35
ToggleStroke.Parent = UI.ToggleCube

UI.ToggleIcon = Instance.new("TextLabel")
UI.ToggleIcon.Size = UDim2.new(1, 0, 1, 0)
UI.ToggleIcon.BackgroundTransparency = 1
UI.ToggleIcon.Text = "NF"
UI.ToggleIcon.TextColor3 = COLORS.accentLight
UI.ToggleIcon.TextSize = 14
UI.ToggleIcon.Font = Enum.Font.GothamBold
UI.ToggleIcon.Parent = UI.ToggleCube

applyToggleCubeSize(State.toggleCubeSize)

local toggleDragging = false
local toggleDragInput = nil
local toggleMoved = false
local toggleDragStartPointer = Vector2.zero
local toggleDragStartPos = UDim2.new()
local togglePressPointer = Vector2.zero
local toggleMousePointer = nil
local TOGGLE_DRAG_THRESHOLD = 6

UI.MobileAimGui = Instance.new("ScreenGui")
UI.MobileAimGui.Name = "ScriptHubMobileAim"
UI.MobileAimGui.ResetOnSpawn = false
UI.MobileAimGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
UI.MobileAimGui.DisplayOrder = 99  -- on top of everything
UI.MobileAimGui.Enabled = not State.isMobile  -- off on mobile until aimbot overlay is needed
UI.MobileAimGui.IgnoreGuiInset = true  -- so positions are relative to the true viewport
UI.MobileAimGui.Parent = GUI_PARENT

UI.MobileAimBtn = Instance.new("TextButton")
UI.MobileAimBtn.Name = "MobileAimButton"
UI.MobileAimBtn.Size = UDim2.new(0, 90, 0, 90)
UI.MobileAimBtn.Position = loadAimButtonPos()
UI.MobileAimBtn.BackgroundColor3 = COLORS.accent
UI.MobileAimBtn.BackgroundTransparency = 0
UI.MobileAimBtn.Text = "LOCK ON"
UI.MobileAimBtn.TextColor3 = COLORS.text
UI.MobileAimBtn.TextSize = 14
UI.MobileAimBtn.Font = Enum.Font.GothamBold
UI.MobileAimBtn.AutoButtonColor = false
UI.MobileAimBtn.ZIndex = 100
UI.MobileAimBtn.Visible = false
UI.MobileAimBtn.Parent = UI.MobileAimGui

local MobileAimCorner = Instance.new("UICorner")
MobileAimCorner.CornerRadius = UDim.new(1, 0)
MobileAimCorner.Parent = UI.MobileAimBtn

local MobileAimStroke = Instance.new("UIStroke")
MobileAimStroke.Color = COLORS.accentLight
MobileAimStroke.Thickness = 2
MobileAimStroke.Transparency = 0.35
MobileAimStroke.Parent = UI.MobileAimBtn

local mobileAimDragging = false
local mobileAimDragInput = nil
local mobileAimDragStartPointer = Vector2.zero
local mobileAimDragStartPos = UDim2.new()

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 620, 0, 580)
MainFrame.Position = UDim2.new(0.5, -310, 0.5, -290)
MainFrame.BackgroundTransparency = 1
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = false
MainFrame.ZIndex = 2
MainFrame.Active = false
MainFrame.Parent = ScreenGui
UI.MainFrame = MainFrame

local WindowBg = Instance.new("Frame")
WindowBg.Name = "WindowBg"
WindowBg.Size = UDim2.new(1, 0, 1, 0)
WindowBg.BackgroundColor3 = COLORS.bg
WindowBg.BorderSizePixel = 0
WindowBg.ZIndex = 0
WindowBg.Parent = MainFrame
applyCorner(WindowBg, CONST.RADIUS.xl)
applyStroke(WindowBg, COLORS.border, 1, 0.35)

-- UIScale lets us resize the entire GUI with one value (mobile default 0.62)
State.guiScale = loadGuiScale()
local WindowScale = Instance.new("UIScale")
WindowScale.Scale = State.guiScale
WindowScale.Parent = MainFrame
UI.WindowScale = WindowScale

local MainShadow = Instance.new("Frame")
MainShadow.Size = UDim2.new(0, 632, 0, 592)
MainShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
MainShadow.BackgroundTransparency = 0.6
MainShadow.BorderSizePixel = 0
MainShadow.ZIndex = 1
-- Shadow is expensive on mobile ??? skip it entirely
MainShadow.Visible = not State.isMobile
MainShadow.Parent = ScreenGui
applyCorner(MainShadow, CONST.RADIUS.xl + 2)
UI.MainShadow = MainShadow

local ShadowScale = Instance.new("UIScale")
ShadowScale.Scale = State.guiScale
ShadowScale.Parent = MainShadow
UI.ShadowScale = ShadowScale

local SHADOW_PAD = 6

local function syncMainShadowPosition()
    local pos = MainFrame.Position
    MainShadow.Position = UDim2.new(
        pos.X.Scale, pos.X.Offset - SHADOW_PAD,
        pos.Y.Scale, pos.Y.Offset - SHADOW_PAD
    )
end

local function setHubVisible(visible)
    MainFrame.Visible = visible
    if UI.MainShadow then
        UI.MainShadow.Visible = visible and not State.isMobile
    end
    if State.isMobile and not visible then
        pcall(function() GuiService.TouchControlsEnabled = true end)
        task.defer(function()
            if type(NF.F.ensureMobileGameplay) == "function" then
                NF.F.ensureMobileGameplay()
            else
                mobileUnblockInput()
            end
        end)
    end
end

local function setMobileOverlayEnabled(enabled)
    if not State.isMobile or State.hideMobileGui then
        enabled = false
    end
    if UI.MobileAimGui then
        UI.MobileAimGui.Enabled = enabled and State.aimbotEnabled
    end
    if UI.FovGui then
        UI.FovGui.Enabled = enabled and State.aimbotEnabled
    end
end

local function closeHubMenu()
    setHubVisible(false)
    setMobileOverlayEnabled(false)
end

syncMainShadowPosition()

-- Mobile: start slightly inset so the window isn't stuck off-screen before first drag
if State.isMobile then
    MainFrame.Position = UDim2.new(0, 12, 0.5, -200)
    syncMainShadowPosition()
    setHubVisible(false)
    setMobileOverlayEnabled(false)
end

-- Window drag (RenderStepped polling ??? works on PC + mobile in all executors)
State.WindowDrag = {
    active = false,
    touchInput = nil,
    pointerStart = Vector2.zero,
    frameStart = nil,
}

local function getGuiPointerScreen(input)
    if input then
        return Vector2.new(input.Position.X, input.Position.Y)
    end
    local loc = UserInputService:GetMouseLocation()
    return Vector2.new(loc.X, loc.Y)
end

local function getPointerScreen(input)
    return getGuiPointerScreen(input)
end

local function getGuiScreenSize()
    if UI.ToggleGui then
        local abs = UI.ToggleGui.AbsoluteSize
        if abs.X > 0 and abs.Y > 0 then
            return abs.X, abs.Y
        end
    end
    local cam = Workspace.CurrentCamera
    if not cam then return 1920, 1080 end
    local vp = cam.ViewportSize
    local ok, inset = pcall(function() return GuiService:GetGuiInset() end)
    local insetY = ok and inset and inset.Y or 0
    return vp.X, vp.Y + insetY
end

local function getIgnoreInsetScreenSize()
    return getGuiScreenSize()
end

local function getGuiObjectScreenSize(guiObj)
    local abs = guiObj.AbsoluteSize
    if abs.X > 0 and abs.Y > 0 then
        return abs.X, abs.Y
    end
    return guiObj.Size.X.Offset, guiObj.Size.Y.Offset
end

local function clampPositionToViewport(x, y, width, height)
    local screenW, screenH = getIgnoreInsetScreenSize()
    width = width or 0
    height = height or 0
    return math.clamp(x, 0, math.max(0, screenW - width)), math.clamp(y, 0, math.max(0, screenH - height))
end

local function getDragScaleFactor()
    return 1 / math.max(State.guiScale or 1, 0.01)
end

function State.WindowDrag.start(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    State.WindowDrag.active = true
    State.WindowDrag.pointerStart = getPointerScreen(input)
    State.WindowDrag.frameStart = MainFrame.Position
    State.WindowDrag.touchInput = input.UserInputType == Enum.UserInputType.Touch and input or nil
end

function State.WindowDrag.stop(input)
    if not State.WindowDrag.active then return end
    if input then
        if State.WindowDrag.touchInput then
            if input.UserInputType ~= Enum.UserInputType.Touch
                or input ~= State.WindowDrag.touchInput then
                return
            end
        elseif input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            -- Ignore keyboard / mouse2 / wheel ??? they were killing drag on fast movement
            return
        end
    end
    State.WindowDrag.active = false
    State.WindowDrag.touchInput = nil
end

function State.WindowDrag.isOverHeader()
    if not UI.HeaderDrag then return false end
    local mp = getPointerScreen()
    if UI.CloseBtn and UI.CloseBtn.Visible then
        local cb = UI.CloseBtn.AbsolutePosition
        local cs = UI.CloseBtn.AbsoluteSize
        if cs.X > 1 and cs.Y > 1
            and mp.X >= cb.X and mp.X <= cb.X + cs.X
            and mp.Y >= cb.Y and mp.Y <= cb.Y + cs.Y then
            return false
        end
    end
    local ap = UI.HeaderDrag.AbsolutePosition
    local asz = UI.HeaderDrag.AbsoluteSize
    if asz.X <= 1 or asz.Y <= 1 then return false end
    return mp.X >= ap.X and mp.X <= ap.X + asz.X
        and mp.Y >= ap.Y and mp.Y <= ap.Y + asz.Y
end

function State.WindowDrag.tick()
    if not State.WindowDrag.active or not State.WindowDrag.frameStart then return end

    local pointer
    if State.WindowDrag.touchInput then
        if State.WindowDrag.touchInput.UserInputState == Enum.UserInputState.End then
            State.WindowDrag.active = false
            State.WindowDrag.touchInput = nil
            return
        end
        pointer = Vector2.new(State.WindowDrag.touchInput.Position.X, State.WindowDrag.touchInput.Position.Y)
    else
        if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
            State.WindowDrag.active = false
            return
        end
        pointer = getPointerScreen()
    end

    local delta = pointer - State.WindowDrag.pointerStart
    local factor = getDragScaleFactor()
    local start = State.WindowDrag.frameStart
    MainFrame.Position = UDim2.new(
        start.X.Scale, start.X.Offset + delta.X * factor,
        start.Y.Scale, start.Y.Offset + delta.Y * factor
    )
    syncMainShadowPosition()
end

bindConnection(RunService.RenderStepped:Connect(function()
    State.WindowDrag.tick()

    if toggleDragging then
        local pointer
        local ended = false

        if toggleDragInput and toggleDragInput.UserInputType == Enum.UserInputType.Touch then
            if toggleDragInput.UserInputState == Enum.UserInputState.End then
                ended = true
            else
                pointer = getGuiPointerScreen(toggleDragInput)
            end
        elseif toggleDragInput and toggleDragInput.UserInputType == Enum.UserInputType.MouseButton1 then
            if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                return
            end
            pointer = toggleMousePointer or toggleDragStartPointer
        else
            if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                ended = true
            else
                pointer = getGuiPointerScreen()
            end
        end

        if ended then
            if toggleMoved then
                saveTogglePos(UI.ToggleCube.Position)
            elseif not toggleMoved then
                setHubVisible(not MainFrame.Visible)
            end
            toggleDragging = false
            toggleDragInput = nil
            toggleMoved = false
            return
        end

        if not toggleMoved and (pointer - togglePressPointer).Magnitude > TOGGLE_DRAG_THRESHOLD then
            toggleMoved = true
        end
        if toggleMoved then
            local delta = pointer - toggleDragStartPointer
            local w, h = getGuiObjectScreenSize(UI.ToggleCube)
            local x, y = clampPositionToViewport(
                toggleDragStartPos.X.Offset + delta.X,
                toggleDragStartPos.Y.Offset + delta.Y,
                w,
                h
            )
            UI.ToggleCube.Position = UDim2.new(0, x, 0, y)
        end
    end

    if mobileAimDragging and State.mobileAimDragUnlocked then
        local pointer
        local ended = false

        if mobileAimDragInput and mobileAimDragInput.UserInputType == Enum.UserInputType.Touch then
            if mobileAimDragInput.UserInputState == Enum.UserInputState.End then
                ended = true
            else
                pointer = getGuiPointerScreen(mobileAimDragInput)
            end
        else
            if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                ended = true
            else
                pointer = getGuiPointerScreen()
            end
        end

        if ended then
            mobileAimDragging = false
            mobileAimDragInput = nil
            saveAimButtonPos(UI.MobileAimBtn.Position)
        elseif pointer then
            local delta = pointer - mobileAimDragStartPointer
            local w, h = getGuiObjectScreenSize(UI.MobileAimBtn)
            local x, y = clampPositionToViewport(
                mobileAimDragStartPos.X.Offset + delta.X,
                mobileAimDragStartPos.Y.Offset + delta.Y,
                w,
                h
            )
            UI.MobileAimBtn.Position = UDim2.new(0, x, 0, y)
        end
    end

    local sd = State.hubSliderDrag
    if sd and sd.active then
        if sd.touchInput then
            if sd.touchInput.UserInputState == Enum.UserInputState.End then
                sd.onEnd()
            else
                sd.updateFromScreenX(sd.touchInput.Position.X)
            end
        else
            if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
                sd.onEnd()
            else
                sd.updateFromScreenX(UserInputService:GetMouseLocation().X)
            end
        end
    end
end))

bindConnection(UserInputService.InputChanged:Connect(function(input)
    if toggleDragging and toggleDragInput
        and toggleDragInput.UserInputType == Enum.UserInputType.MouseButton1
        and input.UserInputType == Enum.UserInputType.MouseMovement
        and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        toggleMousePointer = getGuiPointerScreen()
    end
end))

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 52)
Header.BackgroundColor3 = COLORS.bg
Header.BorderSizePixel = 0
Header.ZIndex = 2
Header.Parent = MainFrame
applyCorner(Header, CONST.RADIUS.xl)

local HeaderLine = Instance.new("Frame")
HeaderLine.Size = UDim2.new(1, 0, 0, 1)
HeaderLine.Position = UDim2.new(0, 0, 1, -1)
HeaderLine.BackgroundColor3 = COLORS.border
HeaderLine.BorderSizePixel = 0
HeaderLine.Parent = Header

local HeaderAccent = Instance.new("Frame")
HeaderAccent.Size = UDim2.new(0, 3, 0, 22)
HeaderAccent.Position = UDim2.new(0, 16, 0.5, -11)
HeaderAccent.BackgroundColor3 = COLORS.accent
HeaderAccent.BorderSizePixel = 0
HeaderAccent.Parent = Header
applyCorner(HeaderAccent, 2)

local HubTitle = Instance.new("TextLabel")
HubTitle.Name = "HubTitle"
HubTitle.Size = UDim2.new(0, 180, 0, 22)
HubTitle.Position = UDim2.new(0, 28, 0, 10)
HubTitle.BackgroundTransparency = 1
HubTitle.Text = "NightFall"
HubTitle.TextColor3 = COLORS.text
HubTitle.TextSize = 20
HubTitle.Font = Enum.Font.GothamBold
HubTitle.TextXAlignment = Enum.TextXAlignment.Left
HubTitle.Parent = Header

local HubSubtitle = Instance.new("TextLabel")
HubSubtitle.Size = UDim2.new(0, 200, 0, 14)
HubSubtitle.Position = UDim2.new(0, 28, 0, 32)
HubSubtitle.BackgroundTransparency = 1
HubSubtitle.Text = "Professional Script Hub"
HubSubtitle.TextColor3 = COLORS.textMuted
HubSubtitle.TextSize = 11
HubSubtitle.Font = Enum.Font.GothamMedium
HubSubtitle.TextXAlignment = Enum.TextXAlignment.Left
HubSubtitle.Parent = Header

UI.CloseBtn = Instance.new("TextButton")
UI.CloseBtn.Size = UDim2.new(0, 32, 0, 32)
UI.CloseBtn.Position = UDim2.new(1, -44, 0.5, -16)
UI.CloseBtn.BackgroundColor3 = COLORS.surface
UI.CloseBtn.Text = "X"
UI.CloseBtn.TextColor3 = COLORS.textMuted
UI.CloseBtn.TextSize = 22
UI.CloseBtn.Font = Enum.Font.GothamMedium
UI.CloseBtn.AutoButtonColor = false
UI.CloseBtn.ZIndex = 20
UI.CloseBtn.Active = true
UI.CloseBtn.Selectable = true
UI.CloseBtn.Parent = Header
applyCorner(UI.CloseBtn, CONST.RADIUS.sm)

local closeBtnLastFire = 0
local function fireCloseHubMenu()
    local now = tick()
    if now - closeBtnLastFire < 0.15 then return end
    closeBtnLastFire = now
    setHubVisible(false)
    setMobileOverlayEnabled(false)
end

addButtonHitLayer(UI.CloseBtn)
UI.CloseBtn.Active = true
State.hubClickRegistry[UI.CloseBtn] = fireCloseHubMenu
local closeHit = UI.CloseBtn:FindFirstChild("HitLayer")
if closeHit then
    closeHit.Active = true
    State.hubClickRegistry[closeHit] = fireCloseHubMenu
    bindConnection(closeHit.MouseButton1Click:Connect(fireCloseHubMenu))
    bindConnection(closeHit.Activated:Connect(fireCloseHubMenu))
end

bindConnection(UI.CloseBtn.MouseButton1Click:Connect(fireCloseHubMenu))
bindConnection(UI.CloseBtn.Activated:Connect(fireCloseHubMenu))
bindConnection(UI.CloseBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        fireCloseHubMenu()
    end
end))

-- Full-width invisible drag handle (must be AFTER title labels, BEFORE close hit area)
UI.HeaderDrag = Instance.new("TextButton")
UI.HeaderDrag.Name = "HeaderDrag"
UI.HeaderDrag.Size = UDim2.new(1, -52, 1, 0)
UI.HeaderDrag.Position = UDim2.new(0, 0, 0, 0)
UI.HeaderDrag.BackgroundTransparency = 1
UI.HeaderDrag.Text = ""
UI.HeaderDrag.AutoButtonColor = false
UI.HeaderDrag.ZIndex = 18
UI.HeaderDrag.Active = true
UI.HeaderDrag.Selectable = false
UI.HeaderDrag.Parent = Header

HubTitle.ZIndex = 19
HubSubtitle.ZIndex = 19
HubTitle.Active = false
HubSubtitle.Active = false
HeaderAccent.Active = false

local function onHeaderDragBegan(input, gameProcessed)
    if input.UserInputType ~= Enum.UserInputType.Touch and gameProcessed then return end
    State.WindowDrag.start(input)
end

bindConnection(UI.HeaderDrag.InputBegan:Connect(onHeaderDragBegan))
bindConnection(UI.HeaderDrag.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        State.WindowDrag.stop(input)
    end
end))

-- Global fallback when executor swallows Gui events
bindConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if State.WindowDrag.active then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end
    task.defer(function()
        if State.WindowDrag.isOverHeader() then
            State.WindowDrag.start(input)
        end
    end)
end))

UI.CloseBtn.MouseEnter:Connect(function()
    tween(UI.CloseBtn, { BackgroundColor3 = COLORS.danger, TextColor3 = COLORS.text })
end)
UI.CloseBtn.MouseLeave:Connect(function()
    tween(UI.CloseBtn, { BackgroundColor3 = COLORS.surface, TextColor3 = COLORS.textMuted })
end)

bindConnection(UI.ToggleCube.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        toggleDragging = true
        toggleDragInput = input
        toggleMoved = false
        toggleMousePointer = nil
        toggleDragStartPointer = getGuiPointerScreen(input)
        toggleDragStartPos = UI.ToggleCube.Position
        togglePressPointer = toggleDragStartPointer
    end
end))

bindConnection(UI.ToggleCube.InputEnded:Connect(function(input)
    if not toggleDragInput or input ~= toggleDragInput then return end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if toggleDragging and toggleMoved then
            saveTogglePos(UI.ToggleCube.Position)
        elseif toggleDragging and not toggleMoved then
            setHubVisible(not MainFrame.Visible)
        end
        toggleDragging = false
        toggleDragInput = nil
        toggleMousePointer = nil
        toggleMoved = false
        return
    end

    if input.UserInputType ~= Enum.UserInputType.Touch then return end
    -- Finger left the small button hitbox while still dragging ??? keep going until touch ends.
    if toggleDragging and toggleMoved then
        return
    end
    if toggleDragging and not toggleMoved then
        setHubVisible(not MainFrame.Visible)
    end
    toggleDragging = false
    toggleDragInput = nil
    toggleMoved = false
end))

-- LOCK ON button: TAP to toggle aim on/off (not hold).
-- In drag-unlocked mode, dragging the button repositions it instead of toggling.
local mobileAimPressStart = nil
local MOBILE_AIM_TAP_THRESHOLD = 8  -- pixels ??? distance moved still counts as tap

bindConnection(UI.MobileAimBtn.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Touch
        and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

    if State.mobileAimDragUnlocked then
        mobileAimDragging = true
        mobileAimDragInput = input
        mobileAimDragStartPointer = getGuiPointerScreen(input)
        mobileAimDragStartPos = UI.MobileAimBtn.Position
    else
        -- Record press start so InputEnded can decide if it was a tap (toggle) or drag (ignored)
        mobileAimPressStart = Vector2.new(input.Position.X, input.Position.Y)
    end
end))

bindConnection(UI.MobileAimBtn.InputEnded:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Touch
        and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

    if State.mobileAimDragUnlocked then
        -- Finger left the button while repositioning ??? RenderStepped finishes the drag.
        if mobileAimDragging and mobileAimDragInput == input
            and input.UserInputType == Enum.UserInputType.Touch
            and input.UserInputState ~= Enum.UserInputState.End then
            return
        end
        mobileAimDragging = false
        mobileAimDragInput = nil
        saveAimButtonPos(UI.MobileAimBtn.Position)
        return
    end

    -- Tap-to-toggle: only fire if the finger barely moved (avoid scroll-style swipes)
    local moved = math.huge
    if mobileAimPressStart then
        local endPos = Vector2.new(input.Position.X, input.Position.Y)
        moved = (endPos - mobileAimPressStart).Magnitude
    end
    mobileAimPressStart = nil

    if moved <= MOBILE_AIM_TAP_THRESHOLD then
        State.holdingMobileAim = not State.holdingMobileAim
        if State.holdingMobileAim then
            State.mobileAimCamFlatDist = nil
            State.mobileAimCamHeight = nil
            tween(UI.MobileAimBtn, { BackgroundColor3 = COLORS.success })
            UI.MobileAimBtn.Text = "LOCKED"
        else
            State.aimbotLockedTarget = nil
            State.aimbotLockedHead = nil
            State.aimbotLockExpired = false
            clearMobileAimCameraSnapshot()
            restoreAimbotCamera()
            tween(UI.MobileAimBtn, { BackgroundColor3 = COLORS.accent })
            UI.MobileAimBtn.Text = "LOCK ON"
        end
    end
end))

-- ?????? Mobile Flight Up/Down buttons ??????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
-- Shown at bottom-right when flight is active on mobile.
local function makeMobileFlightBtn(label, xOff)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 64, 0, 64)
    btn.Position = UDim2.new(1, xOff, 1, -80)
    btn.BackgroundColor3 = COLORS.elevated
    btn.BackgroundTransparency = 0.15
    btn.Text = label
    btn.TextColor3 = COLORS.text
    btn.TextSize = 22
    btn.Font = Enum.Font.GothamBold
    btn.AutoButtonColor = false
    btn.Visible = false
    btn.Parent = UI.MobileAimGui
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(1, 0); c.Parent = btn
    local s = Instance.new("UIStroke"); s.Color = COLORS.border; s.Thickness = 2; s.Parent = btn
    return btn
end
UI.MobileFlightUpBtn   = makeMobileFlightBtn(CONST.ICON.flightUp, -148)
UI.MobileFlightDownBtn = makeMobileFlightBtn(CONST.ICON.flightDown,  -76)

bindConnection(UI.MobileFlightUpBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        State.mobileFlightUp = true
    end
end))
bindConnection(UI.MobileFlightUpBtn.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        State.mobileFlightUp = false
    end
end))
bindConnection(UI.MobileFlightDownBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        State.mobileFlightDown = true
    end
end))
bindConnection(UI.MobileFlightDownBtn.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        State.mobileFlightDown = false
    end
end))

-- Blood manip on mobile is activated by holding your finger on a player
-- (touch-hold detection ??? see InputBegan handler below).
State.bloodManipTouchInput = nil
State.mobileCamTouch = nil

-- ?????? FOV circle (shown at screen center when mobile aim is held) ??????????????????????????????????????????
local FovGui = Instance.new("ScreenGui")
FovGui.Name = "ScriptHubFov"
FovGui.ResetOnSpawn = false
FovGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
FovGui.DisplayOrder = 98
FovGui.Enabled = not State.isMobile  -- off on mobile until aimbot overlay is needed
FovGui.IgnoreGuiInset = true
FovGui.Parent = GUI_PARENT
UI.FovGui = FovGui

UI.FovCircle = Instance.new("Frame")
UI.FovCircle.Size = UDim2.new(0, 440, 0, 440)  -- diameter = AIMBOT_MAX_FOV(220) * 2
UI.FovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
UI.FovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
UI.FovCircle.BackgroundTransparency = 1
UI.FovCircle.Visible = false
UI.FovCircle.Active = false
UI.FovCircle.Parent = FovGui
local _fc = Instance.new("UICorner"); _fc.CornerRadius = UDim.new(1,0); _fc.Parent = UI.FovCircle
local _fs = Instance.new("UIStroke")
_fs.Color = COLORS.accentLight
_fs.Thickness = 2
_fs.Transparency = 0.2
_fs.Parent = UI.FovCircle
-- Dot at center
local _fd = Instance.new("Frame")
_fd.Size = UDim2.new(0, 6, 0, 6)
_fd.AnchorPoint = Vector2.new(0.5, 0.5)
_fd.Position = UDim2.new(0.5, 0, 0.5, 0)
_fd.BackgroundColor3 = COLORS.accentLight
_fd.BorderSizePixel = 0
_fd.Parent = UI.FovCircle
local _fdc = Instance.new("UICorner"); _fdc.CornerRadius = UDim.new(1,0); _fdc.Parent = _fd

local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, CONST.SIDEBAR_WIDTH, 1, -52)
Sidebar.Position = UDim2.new(0, 0, 0, 52)
Sidebar.BackgroundColor3 = COLORS.sidebar
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex = 2
Sidebar.Active = false
Sidebar.Parent = MainFrame
applyCorner(Sidebar, CONST.RADIUS.xl)

local SidebarLine = Instance.new("Frame")
SidebarLine.Size = UDim2.new(0, 1, 1, 0)
SidebarLine.Position = UDim2.new(1, -1, 0, 0)
SidebarLine.BackgroundColor3 = COLORS.border
SidebarLine.BorderSizePixel = 0
SidebarLine.Parent = Sidebar

-- Sidebar navigation: scrollable so any number of tabs fit on a small window.
local NavList = Instance.new("ScrollingFrame")
NavList.Name = "NavList"
NavList.Size = UDim2.new(1, -12, 1, -16)
NavList.Position = UDim2.new(0, 6, 0, 8)
NavList.BackgroundTransparency = 1
NavList.BorderSizePixel = 0
NavList.ScrollBarThickness = 0  -- hide bar; tabs auto-fit on most screens
NavList.CanvasSize = UDim2.new(0, 0, 0, 0)
NavList.AutomaticCanvasSize = Enum.AutomaticSize.Y
NavList.ScrollingDirection = Enum.ScrollingDirection.Y
NavList.Parent = Sidebar

local NavLayout = Instance.new("UIListLayout")
NavLayout.Padding = UDim.new(0, 4)
NavLayout.SortOrder = Enum.SortOrder.LayoutOrder
NavLayout.Parent = NavList

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -(CONST.SIDEBAR_WIDTH + 20), 1, -68)
Content.Position = UDim2.new(0, CONST.SIDEBAR_WIDTH + 10, 0, 58)
Content.BackgroundColor3 = COLORS.bg
Content.BackgroundTransparency = 0
Content.BorderSizePixel = 0
Content.ClipsDescendants = true
Content.ZIndex = 2
Content.Active = false
Content.Parent = MainFrame
applyCorner(Content, CONST.RADIUS.xl)

local pages = {}
UI.pages = pages
local tabButtons = {}
local activeTab = "Home"

local function createPage(name)
    local page = Instance.new("Frame")
    page.Name = name .. "Page"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.Active = false
    page.Parent = Content
    pages[name] = page
    return page
end

local function switchTab(name)
    activeTab = name
    for pageName, page in pairs(pages) do
        page.Visible = pageName == name
    end
    for tabName, data in pairs(tabButtons) do
        local selected = tabName == name
        data.indicator.Visible = selected
        tween(data.button, {
            BackgroundColor3 = selected and COLORS.tabActiveBg or COLORS.sidebar,
        })
        data.label.TextColor3 = selected and COLORS.text or COLORS.textMuted
        data.icon.TextColor3 = selected and COLORS.accentLight or COLORS.textMuted
    end
    -- Auto-refresh player list whenever Misc tab is opened
    if name == "Misc" then
        if State.__miscCollapseAll then
            State.__miscCollapseAll()
        end
        task.defer(function()
            if NF.F.refreshMiscPlayerList then
                NF.F.refreshMiscPlayerList()
            end
        end)
        if NF.F.refreshMiscPlayerList then
            NF.F.refreshMiscPlayerList()
        end
    end
end

local function createTab(name, icon)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 40)
    btn.BackgroundColor3 = COLORS.sidebar
    btn.Text = ""
    btn.AutoButtonColor = State.isMobile
    btn.Active = true
    btn.Selectable = true
    btn.Parent = NavList
    applyCorner(btn, CONST.RADIUS.md)

    local indicator = Instance.new("Frame")
    indicator.Name = "Indicator"
    indicator.Size = UDim2.new(0, 3, 0, 20)
    indicator.Position = UDim2.new(0, 4, 0.5, -10)
    indicator.BackgroundColor3 = COLORS.accent
    indicator.BorderSizePixel = 0
    indicator.Visible = false
    indicator.Parent = btn
    applyCorner(indicator, 2)

    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.new(0, 0, 1, 0)
    iconLabel.Visible = false
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = ""
    iconLabel.Parent = btn

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -28, 1, 0)
    textLabel.Position = UDim2.new(0, 14, 0, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = name
    textLabel.TextSize = 13
    textLabel.Font = Enum.Font.GothamSemibold
    textLabel.TextColor3 = COLORS.textMuted
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.Parent = btn

    tabButtons[name] = { button = btn, label = textLabel, icon = iconLabel, indicator = indicator }

    btn.MouseEnter:Connect(function()
        if activeTab ~= name then
            tween(btn, { BackgroundColor3 = COLORS.surface })
        end
    end)
    btn.MouseLeave:Connect(function()
        if activeTab ~= name then
            tween(btn, { BackgroundColor3 = COLORS.sidebar })
        end
    end)

    addButtonHitLayer(btn)
    bindHubClick(btn, function()
        switchTab(name)
    end)
    guiPassThrough(btn)
end

local function createHubButton(parent, title, subtitle)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, subtitle and 54 or 46)
    btn.BackgroundColor3 = COLORS.surface
    btn.Text = ""
    btn.AutoButtonColor = State.isMobile
    btn.Active = true
    btn.Selectable = true
    btn.ZIndex = 3
    btn.Parent = parent
    applyCorner(btn, CONST.RADIUS.md)
    applyStroke(btn, COLORS.border, 1, 0.65)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(1, -110, 0, 18)
    titleLabel.Position = UDim2.new(0, 14, 0, subtitle and 10 or 14)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = COLORS.text
    titleLabel.TextSize = 14
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = btn

    if subtitle then
        local subLabel = Instance.new("TextLabel")
        subLabel.Name = "SubLabel"
        subLabel.Size = UDim2.new(1, -110, 0, 14)
        subLabel.Position = UDim2.new(0, 14, 0, 30)
        subLabel.BackgroundTransparency = 1
        subLabel.Text = subtitle
        subLabel.TextColor3 = COLORS.textMuted
        subLabel.TextSize = 11
        subLabel.Font = Enum.Font.GothamMedium
        subLabel.TextXAlignment = Enum.TextXAlignment.Left
        subLabel.Parent = btn
    end

    local switchTrack = Instance.new("Frame")
    switchTrack.Name = "SwitchTrack"
    switchTrack.Size = UDim2.new(0, 44, 0, 22)
    switchTrack.Position = UDim2.new(1, -58, 0.5, -11)
    switchTrack.BackgroundColor3 = COLORS.toggleOff
    switchTrack.Visible = false
    switchTrack.Parent = btn
    applyCorner(switchTrack, CONST.RADIUS.full)

    local switchKnob = Instance.new("Frame")
    switchKnob.Name = "SwitchKnob"
    switchKnob.Size = UDim2.new(0, 18, 0, 18)
    switchKnob.Position = UDim2.new(0, 2, 0.5, -9)
    switchKnob.BackgroundColor3 = COLORS.text
    switchKnob.Parent = switchTrack
    applyCorner(switchKnob, CONST.RADIUS.full)

    local stateLabel = Instance.new("TextLabel")
    stateLabel.Name = "StateLabel"
    stateLabel.Size = UDim2.new(0, 72, 1, 0)
    stateLabel.Position = UDim2.new(1, -82, 0, 0)
    stateLabel.BackgroundTransparency = 1
    stateLabel.Text = ""
    stateLabel.TextColor3 = COLORS.textMuted
    stateLabel.TextSize = 12
    stateLabel.Font = Enum.Font.GothamBold
    stateLabel.TextXAlignment = Enum.TextXAlignment.Right
    stateLabel.Visible = false
    stateLabel.Parent = btn

    btn.MouseEnter:Connect(function()
        tween(btn, { BackgroundColor3 = COLORS.surfaceHover })
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, { BackgroundColor3 = COLORS.surface })
    end)

    addButtonHitLayer(btn)
    guiPassThrough(btn)
    return btn
end

local function setHubToggle(btn, enabled, onText, offText)
    local state = btn:FindFirstChild("StateLabel")
    local track = btn:FindFirstChild("SwitchTrack")
    local knob = track and track:FindFirstChild("SwitchKnob")

    if onText or offText then
        if track then track.Visible = false end
        if state then
            state.Visible = true
            state.Text = enabled and (onText or "ON") or (offText or "OFF")
            state.TextColor3 = enabled and COLORS.success or COLORS.textMuted
        end
        return
    end

    if track and knob then
        track.Visible = true
        if state then state.Visible = false end
        tween(track, { BackgroundColor3 = enabled and COLORS.toggleOn or COLORS.toggleOff })
        tween(knob, {
            Position = enabled and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9),
        })
    elseif state then
        state.Visible = true
        state.Text = enabled and "ON" or "OFF"
        state.TextColor3 = enabled and COLORS.success or COLORS.textMuted
    end
end

local function findScrollParent(gui)
    local p = gui and gui.Parent
    while p do
        if p:IsA("ScrollingFrame") then return p end
        p = p.Parent
    end
    return nil
end

local function createHubSlider(parent, title, minVal, maxVal, defaultVal, onChanged)
    local trackHeight = State.isMobile and 10 or 10
    local hitHeight = State.isMobile and 40 or 32
    local containerHeight = State.isMobile and 82 or 72
    local trackY = State.isMobile and 42 or 46
    local knobSize = State.isMobile and 24 or 18

    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, containerHeight)
    container.BackgroundColor3 = COLORS.surface
    container.Parent = parent
    applyCorner(container, CONST.RADIUS.md)
    applyStroke(container, COLORS.border, 1, 0.65)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0.6, 0, 0, 22)
    titleLabel.Position = UDim2.new(0, 14, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = COLORS.text
    titleLabel.TextSize = State.isMobile and 14 or 13
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Active = false
    titleLabel.Parent = container

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Name = "ValueLabel"
    valueLabel.Size = UDim2.new(0.4, -14, 0, 22)
    valueLabel.Position = UDim2.new(0.6, 0, 0, 10)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(defaultVal)
    valueLabel.TextColor3 = COLORS.accentOn
    valueLabel.TextSize = State.isMobile and 14 or 13
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Active = false
    valueLabel.Parent = container

    -- Large invisible hit zone ??? much easier to grab than the thin visual track
    local hitPad = Instance.new("TextButton")
    hitPad.Name = "HitPad"
    hitPad.Size = UDim2.new(1, -16, 0, hitHeight)
    hitPad.Position = UDim2.new(0, 8, 0, trackY - math.floor((hitHeight - trackHeight) / 2))
    hitPad.BackgroundTransparency = 1
    hitPad.Text = ""
    hitPad.AutoButtonColor = false
    hitPad.ZIndex = 6
    hitPad.Parent = container

    local track = Instance.new("Frame")
    track.Name = "Track"
    track.Size = UDim2.new(1, -28, 0, trackHeight)
    track.Position = UDim2.new(0, 14, 0, trackY)
    track.BackgroundColor3 = COLORS.track
    track.BorderSizePixel = 0
    track.ZIndex = 3
    track.Active = false
    track.Parent = container
    applyCorner(track, CONST.RADIUS.full)

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = COLORS.accent
    fill.BorderSizePixel = 0
    fill.ZIndex = 4
    fill.Parent = track
    applyCorner(fill, CONST.RADIUS.full)

    local knob = Instance.new("Frame")
    knob.Name = "Knob"
    knob.Size = UDim2.new(0, knobSize, 0, knobSize)
    knob.Position = UDim2.new(0, -math.floor(knobSize / 2), 0.5, -math.floor(knobSize / 2))
    knob.BackgroundColor3 = COLORS.text
    knob.BorderSizePixel = 0
    knob.ZIndex = 5
    knob.Parent = track
    applyCorner(knob, CONST.RADIUS.full)
    applyStroke(knob, COLORS.accentLight, 1.5, 0.15)

    local current = defaultVal
    local scrollParent = nil
    local halfKnob = math.floor(knobSize / 2)

    local function setScrollLocked(locked)
        if scrollParent and scrollParent.Parent then
            scrollParent.ScrollingEnabled = not locked
        end
    end

    local function setValue(value, fireCallback)
        current = math.clamp(math.floor(value + 0.5), minVal, maxVal)
        valueLabel.Text = tostring(current)
        local alpha = (current - minVal) / math.max(maxVal - minVal, 1)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, -halfKnob, 0.5, -halfKnob)
        if fireCallback and onChanged then
            onChanged(current)
        end
    end

    local function updateFromScreenX(screenX)
        local trackPos = track.AbsolutePosition.X
        local trackSize = track.AbsoluteSize.X
        if trackSize <= 0 then return end
        local alpha = math.clamp((screenX - trackPos) / trackSize, 0, 1)
        setValue(minVal + (maxVal - minVal) * alpha, true)
    end

    local function endSliderDrag()
        setScrollLocked(false)
        if State.hubSliderDrag and State.hubSliderDrag.container == container then
            State.hubSliderDrag = nil
        end
    end

    local function beginSliderDrag(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        scrollParent = findScrollParent(container)
        setScrollLocked(true)
        State.hubSliderDrag = {
            active = true,
            container = container,
            touchInput = input.UserInputType == Enum.UserInputType.Touch and input or nil,
            updateFromScreenX = updateFromScreenX,
            onEnd = endSliderDrag,
        }
        local startX = input.UserInputType == Enum.UserInputType.Touch
            and input.Position.X
            or UserInputService:GetMouseLocation().X
        updateFromScreenX(startX)
    end

    hitPad.InputBegan:Connect(beginSliderDrag)

    setValue(defaultVal, false)

    return container, function(value)
        setValue(value, false)
    end, function()
        return current
    end
end

local function createHubTextInput(parent, title, placeholder, defaultText)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 68)
    container.BackgroundColor3 = COLORS.surface
    container.Parent = parent
    applyCorner(container, CONST.RADIUS.md)
    applyStroke(container, COLORS.border, 1, 0.65)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -28, 0, 22)
    titleLabel.Position = UDim2.new(0, 14, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = COLORS.text
    titleLabel.TextSize = 13
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = container

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -28, 0, 26)
    box.Position = UDim2.new(0, 14, 0, 34)
    box.BackgroundColor3 = COLORS.track
    box.BorderSizePixel = 0
    box.TextColor3 = COLORS.text
    box.PlaceholderColor3 = COLORS.textMuted
    box.PlaceholderText = placeholder or ""
    box.Text = defaultText or ""
    box.TextSize = 13
    box.Font = Enum.Font.GothamMedium
    box.ClearTextOnFocus = false
    box.Parent = container
    applyCorner(box, CONST.RADIUS.sm)
    applyStroke(box, COLORS.border, 1, 0.7)

    local boxPad = Instance.new("UIPadding")
    boxPad.PaddingLeft = UDim.new(0, 10)
    boxPad.PaddingRight = UDim.new(0, 10)
    boxPad.Parent = box

    return container, box
end

local function createHubKeybindRow(parent, title, subtitle, getKeyCode, onKeySet)
    local btn = createHubButton(parent, title, subtitle)
    local keyLabel = btn:FindFirstChild("StateLabel")
    if keyLabel then
        keyLabel.Visible = true
        keyLabel.Text = keyCodeToDisplay(getKeyCode())
        keyLabel.TextColor3 = COLORS.accentOn
    end
    bindHubClick(btn, function()
        if keyLabel then
            keyLabel.Text = "..."
            keyLabel.TextColor3 = COLORS.textMuted
        end
        State.hubKeybindListen = {
            label = keyLabel,
            onSet = function(keyCode)
                onKeySet(keyCode)
                if keyLabel then
                    keyLabel.Text = keyCodeToDisplay(keyCode)
                    keyLabel.TextColor3 = COLORS.accentOn
                end
                State.hubKeybindListen = nil
            end,
        }
    end)
    return btn
end

local function setupMobileScroll(scroll)
    if not scroll then return end
    scroll.ScrollingEnabled = true
    scroll.ScrollingDirection = Enum.ScrollingDirection.Y
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    if State.isMobile then
        scroll.Active = true
        scroll.ScrollBarThickness = 10
        scroll.ScrollBarImageTransparency = 0.25
        scroll.BorderSizePixel = 0
        scroll.ScrollingEnabled = true
        pcall(function()
            scroll.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
        end)
    else
        scroll.Active = true
    end
end

setupMobileScroll(NavList)

local function scrollToVisible(scroll, element, padding)
    if not scroll or not element then return end
    padding = padding or 12
    task.defer(function()
        task.wait(0.06)
        if not scroll.Parent or not element.Parent then return end
        local offset = element.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y
        local viewH = scroll.AbsoluteSize.Y
        local elemH = element.AbsoluteSize.Y
        local canvasH = scroll.AbsoluteCanvasSize.Y
        local maxScroll = math.max(0, canvasH - viewH)
        local targetTop = offset - padding
        local targetBottom = offset + elemH - viewH + padding

        if elemH > viewH - padding * 2 then
            scroll.CanvasPosition = Vector2.new(0, math.clamp(targetTop, 0, maxScroll))
        elseif targetBottom > scroll.CanvasPosition.Y then
            scroll.CanvasPosition = Vector2.new(0, math.clamp(targetBottom, 0, maxScroll))
        elseif targetTop < scroll.CanvasPosition.Y then
            scroll.CanvasPosition = Vector2.new(0, math.clamp(targetTop, 0, maxScroll))
        end
    end)
end

local miscFoldSetters = {}

local function createMiscFold(parent, title, startExpanded, pageScroll)
    local headerH = State.isMobile and 44 or 40
    local section = Instance.new("Frame")
    section.Name = title .. "Section"
    section.Size = UDim2.new(1, 0, 0, 0)
    section.AutomaticSize = Enum.AutomaticSize.Y
    section.BackgroundTransparency = 1
    section.ClipsDescendants = true
    section.Parent = parent

    local sectionLayout = Instance.new("UIListLayout")
    sectionLayout.Padding = UDim.new(0, 4)
    sectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
    sectionLayout.Parent = section

    local header = Instance.new("TextButton")
    header.Size = UDim2.new(1, 0, 0, headerH)
    header.LayoutOrder = 1
    header.BackgroundColor3 = COLORS.surface
    header.Text = ""
    header.AutoButtonColor = State.isMobile
    header.Active = true
    header.Selectable = true
    header.ZIndex = 2
    header.Parent = section
    applyCorner(header, CONST.RADIUS.md)
    applyStroke(header, COLORS.border, 1, 0.65)

    local accentBar = Instance.new("Frame")
    accentBar.Size = UDim2.new(0, 3, 0, 18)
    accentBar.Position = UDim2.new(0, 10, 0.5, -9)
    accentBar.BackgroundColor3 = COLORS.accent
    accentBar.BorderSizePixel = 0
    accentBar.Parent = header
    applyCorner(accentBar, 2)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -52, 1, 0)
    titleLabel.Position = UDim2.new(0, 20, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = COLORS.text
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = State.isMobile and 15 or 14
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Active = false
    titleLabel.Parent = header

    local arrow = Instance.new("TextLabel")
    arrow.Name = "Arrow"
    arrow.Size = UDim2.new(0, 24, 1, 0)
    arrow.Position = UDim2.new(1, -32, 0, 0)
    arrow.BackgroundTransparency = 1
    arrow.Text = CONST.ICON.foldClosed
    arrow.TextColor3 = COLORS.textMuted
    arrow.TextSize = 14
    arrow.Font = Enum.Font.SourceSansBold
    arrow.Active = false
    arrow.Parent = header

    local body = Instance.new("Frame")
    body.Name = "Body"
    body.Size = UDim2.new(1, 0, 0, 0)
    body.AutomaticSize = Enum.AutomaticSize.Y
    body.LayoutOrder = 2
    body.BackgroundTransparency = 1
    body.ClipsDescendants = true
    body.Visible = false
    body.Parent = section

    local bodyLayout = Instance.new("UIListLayout")
    bodyLayout.Padding = UDim.new(0, 8)
    bodyLayout.Parent = body

    local expanded = false

    body.ChildAdded:Connect(function()
        if not expanded then
            body.Visible = false
        end
    end)

    local setExpanded
    setExpanded = function(value)
        if value and State.isMobile then
            for _, fn in ipairs(miscFoldSetters) do
                if fn ~= setExpanded then
                    fn(false)
                end
            end
        end
        expanded = value == true
        arrow.Text = expanded and CONST.ICON.foldOpen or CONST.ICON.foldClosed
        body.Visible = expanded
        if expanded and pageScroll then
            scrollToVisible(pageScroll, section, 24)
            task.delay(0.15, function()
                scrollToVisible(pageScroll, section, 24)
            end)
            task.delay(0.35, function()
                scrollToVisible(pageScroll, section, 24)
            end)
        end
        if expanded and title == "Spectate" and NF.F.refreshMiscPlayerList then
            task.defer(NF.F.refreshMiscPlayerList)
        end
    end

    table.insert(miscFoldSetters, setExpanded)

    addButtonHitLayer(header)
    bindHubClick(header, function()
        setExpanded(not expanded)
    end)

    guiPassThrough(header)

    setExpanded(startExpanded == true)

    return section, body, setExpanded
end

createTab("Home", CONST.ICON.tabHome)
createTab("Scanner", CONST.ICON.tabScanner)
createTab("Movement", CONST.ICON.tabMovement)
createTab("Premium", CONST.ICON.tabPremium)
createTab("Combat", CONST.ICON.tabCombat)
createTab("Troll", CONST.ICON.tabTroll)
createTab("Misc", CONST.ICON.tabMisc)
createTab("Settings", CONST.ICON.tabSettings)

-- Export core helpers for later scope blocks (Luau 200-local limit)
NF.F.bindConnection = bindConnection
NF.F.bindHubClick = bindHubClick
NF.F.tween = tween
NF.F.applyCorner = applyCorner
NF.F.applyStroke = applyStroke
NF.F.fsRead = fsRead
NF.F.fsWrite = fsWrite
NF.F.updateRoot = updateRoot
NF.F.getHumanoid = getHumanoid
NF.F.getRoot = getRoot
NF.F.createPage = createPage
NF.F.switchTab = switchTab
NF.F.createTab = createTab
NF.F.createHubButton = createHubButton
NF.F.setHubToggle = setHubToggle
NF.F.createHubSlider = createHubSlider
NF.F.createHubTextInput = createHubTextInput
NF.F.createHubKeybindRow = createHubKeybindRow
NF.F.setupMobileScroll = setupMobileScroll
NF.F.scrollToVisible = scrollToVisible
NF.F.createMiscFold = createMiscFold
NF.F.setHubVisible = setHubVisible
NF.F.setMobileOverlayEnabled = setMobileOverlayEnabled
NF.F.closeHubMenu = closeHubMenu
NF.F.refreshCamera = refreshCamera
NF.F.restoreAimbotCamera = restoreAimbotCamera
NF.F.cameraNeedsAimbotRestore = cameraNeedsAimbotRestore
NF.F.ensureGameplayCamera = ensureGameplayCamera
NF.F.isAimHoldActive = isAimHoldActive
NF.F.getAimHoldButton = getAimHoldButton
NF.F.isPcShiftLocked = isPcShiftLocked
NF.F.refreshShiftLockState = refreshShiftLockState
NF.F.handleShiftLockKeyPress = handleShiftLockKeyPress
NF.F.inputToKeyCode = inputToKeyCode
NF.F.isShiftLockKeyInput = isShiftLockKeyInput
NF.F.getAimReferenceUsesCenter = getAimReferenceUsesCenter
NF.F.syncPcAimHoldState = syncPcAimHoldState
NF.F.ensurePcAimMouseFree = ensurePcAimMouseFree
NF.F.setAimbotShiftCursorLocked = setAimbotShiftCursorLocked
NF.F.maintainPcShiftLockCursor = maintainPcShiftLockCursor
NF.F.getShiftLockAimScreen = getShiftLockAimScreen
NF.F.syncPcAimCursorFromSystem = syncPcAimCursorFromSystem
NF.F.applyGuiScale = applyGuiScale
NF.F.getDefaultTogglePos = getDefaultTogglePos
NF.F.applyToggleCubeSize = applyToggleCubeSize
NF.F.saveAimbotSettings = saveAimbotSettings
NF.F.loadAimbotSettings = loadAimbotSettings
NF.F.onHeaderDragBegan = onHeaderDragBegan
NF.F.makeMobileFlightBtn = makeMobileFlightBtn
NF.pages = pages
NF.tabButtons = tabButtons
NF.miscFoldSetters = miscFoldSetters
NF.GUI_PARENT = GUI_PARENT

end -- scope block 0 (core + GUI builders; Luau local register limit)

local bindConnection = NF.F.bindConnection
local bindHubClick = NF.F.bindHubClick
local tween = NF.F.tween
local applyCorner = NF.F.applyCorner
local applyStroke = NF.F.applyStroke
local fsRead = NF.F.fsRead
local fsWrite = NF.F.fsWrite
local updateRoot = NF.F.updateRoot
local getHumanoid = NF.F.getHumanoid
local getRoot = NF.F.getRoot
local createPage = NF.F.createPage
local switchTab = NF.F.switchTab
local createTab = NF.F.createTab
local createHubButton = NF.F.createHubButton
local setHubToggle = NF.F.setHubToggle
local createHubSlider = NF.F.createHubSlider
local createHubTextInput = NF.F.createHubTextInput
local createHubKeybindRow = NF.F.createHubKeybindRow
local setupMobileScroll = NF.F.setupMobileScroll
local scrollToVisible = NF.F.scrollToVisible
local createMiscFold = NF.F.createMiscFold
local setHubVisible = NF.F.setHubVisible
local setMobileOverlayEnabled = NF.F.setMobileOverlayEnabled
local refreshCamera = NF.F.refreshCamera
local restoreAimbotCamera = NF.F.restoreAimbotCamera
local isAimHoldActive = NF.F.isAimHoldActive
local isPcShiftLocked = NF.F.isPcShiftLocked
local refreshShiftLockState = NF.F.refreshShiftLockState
local handleShiftLockKeyPress = NF.F.handleShiftLockKeyPress
local inputToKeyCode = NF.F.inputToKeyCode
local isShiftLockKeyInput = NF.F.isShiftLockKeyInput
local getAimReferenceUsesCenter = NF.F.getAimReferenceUsesCenter
local syncPcAimHoldState = NF.F.syncPcAimHoldState
local ensurePcAimMouseFree = NF.F.ensurePcAimMouseFree
local syncPcAimCursorFromSystem = NF.F.syncPcAimCursorFromSystem
local saveAimbotSettings = NF.F.saveAimbotSettings
local loadAimbotSettings = NF.F.loadAimbotSettings
local onHeaderDragBegan = NF.F.onHeaderDragBegan
local makeMobileFlightBtn = NF.F.makeMobileFlightBtn
local pages = NF.pages
local tabButtons = NF.tabButtons
local miscFoldSetters = NF.miscFoldSetters
local GUI_PARENT = NF.GUI_PARENT

do -- scope block 1a-home (GUI - Luau local register limit)

local HomePage = createPage("Home")
local ScannerPage = createPage("Scanner")
createPage("Movement")
createPage("Premium")
createPage("Combat")
createPage("Troll")
createPage("Misc")
createPage("Settings")

State.walkSpeed = 16
State.jumpPower = 50
State.defaultWalkSpeed = 16
State.defaultJumpPower = 50
State.speedEnabled = false
State.jumpEnabled = false
State.flightEnabled = false
State.noclipEnabled = false
State.flingInProgress = false
State.infJumpEnabled = false
State.flightSpeed = 80
State.hookedHumanoids = {}

-- Home page: a single scrollable column so the welcome card and status
-- buttons can never get cut off.
local HomeScroll = Instance.new("ScrollingFrame")
HomeScroll.Size = UDim2.new(1, 0, 1, 0)
HomeScroll.BackgroundTransparency = 1
HomeScroll.BorderSizePixel = 0
HomeScroll.ScrollBarThickness = 5
HomeScroll.ScrollBarImageColor3 = COLORS.border
HomeScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
HomeScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
HomeScroll.Parent = HomePage
setupMobileScroll(HomeScroll)

local HomeScrollLayout = Instance.new("UIListLayout")
HomeScrollLayout.Padding = UDim.new(0, 12)
HomeScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
HomeScrollLayout.Parent = HomeScroll

local HomeCard = Instance.new("Frame")
HomeCard.Size = UDim2.new(1, 0, 0, 128)
HomeCard.BackgroundColor3 = COLORS.surface
HomeCard.LayoutOrder = 1
HomeCard.Parent = HomeScroll
applyCorner(HomeCard, CONST.RADIUS.lg)
applyStroke(HomeCard, COLORS.border, 1, 0.6)

local HomeCardAccent = Instance.new("Frame")
HomeCardAccent.Size = UDim2.new(0, 4, 1, -20)
HomeCardAccent.Position = UDim2.new(0, 0, 0, 10)
HomeCardAccent.BackgroundColor3 = COLORS.accent
HomeCardAccent.BorderSizePixel = 0
HomeCardAccent.Parent = HomeCard
applyCorner(HomeCardAccent, 2)

local WelcomeText = Instance.new("TextLabel")
WelcomeText.Size = UDim2.new(1, -28, 0, 28)
WelcomeText.Position = UDim2.new(0, 18, 0, 16)
WelcomeText.BackgroundTransparency = 1
WelcomeText.Text = "Welcome back, " .. player.DisplayName
WelcomeText.TextColor3 = COLORS.text
WelcomeText.TextSize = 19
WelcomeText.Font = Enum.Font.GothamBold
WelcomeText.TextXAlignment = Enum.TextXAlignment.Left
WelcomeText.Parent = HomeCard

local HomeSubText = Instance.new("TextLabel")
HomeSubText.Size = UDim2.new(1, -28, 0, 44)
HomeSubText.Position = UDim2.new(0, 18, 0, 48)
HomeSubText.BackgroundTransparency = 1
HomeSubText.Text = "NightFall " .. CONST.ICON.dash .. " your favorite scripting hub."
HomeSubText.TextColor3 = COLORS.textMuted
HomeSubText.TextSize = 12
HomeSubText.Font = Enum.Font.GothamMedium
HomeSubText.TextXAlignment = Enum.TextXAlignment.Left
HomeSubText.TextYAlignment = Enum.TextYAlignment.Top
HomeSubText.TextWrapped = true
HomeSubText.Parent = HomeCard

local HomeList = Instance.new("Frame")
HomeList.Size = UDim2.new(1, 0, 0, 0)
HomeList.AutomaticSize = Enum.AutomaticSize.Y
HomeList.BackgroundTransparency = 1
HomeList.LayoutOrder = 2
HomeList.Active = false
HomeList.Parent = HomeScroll

local HomeListLayout = Instance.new("UIListLayout")
HomeListLayout.Padding = UDim.new(0, 8)
HomeListLayout.Parent = HomeList

UI.StatusTempV = createHubButton(HomeList, "TempV In World", "Auto-updates every 2 seconds")
UI.StatusTempV.StateLabel.Visible = true
UI.StatusTempV.StateLabel.Text = "0"
UI.StatusTempV.StateLabel.TextColor3 = COLORS.accentOn
UI.StatusTempV.Active = false
UI.StatusTempV.AutoButtonColor = false

UI.StatusHomelander = createHubButton(HomeList, "Homelander", "Enable Combat tab ESP")
UI.StatusHomelander.StateLabel.Visible = true
UI.StatusHomelander.StateLabel.Text = "NONE"
UI.StatusHomelander.Active = false
UI.StatusHomelander.AutoButtonColor = false

UI.StatusScan = createHubButton(HomeList, "Auto Scan", "Refreshes when TempV picked up")
UI.StatusScan.StateLabel.Visible = true
UI.StatusScan.StateLabel.Text = "ON"
UI.StatusScan.StateLabel.TextColor3 = COLORS.accent
UI.StatusScan.Active = false
UI.StatusScan.AutoButtonColor = false

UI.Title = WelcomeText

-- Scanner page: a single scrollable column containing the list area and the
-- control buttons. Auto-grows so nothing is ever cut off, regardless of how many
-- items appear in the scanner.
local ScannerOuterScroll = Instance.new("ScrollingFrame")
ScannerOuterScroll.Size = UDim2.new(1, 0, 1, 0)
ScannerOuterScroll.BackgroundTransparency = 1
ScannerOuterScroll.BorderSizePixel = 0
ScannerOuterScroll.ScrollBarThickness = 5
ScannerOuterScroll.ScrollBarImageColor3 = COLORS.border
ScannerOuterScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
ScannerOuterScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
ScannerOuterScroll.Parent = ScannerPage
setupMobileScroll(ScannerOuterScroll)

local ScannerOuterLayout = Instance.new("UIListLayout")
ScannerOuterLayout.Padding = UDim.new(0, 8)
ScannerOuterLayout.SortOrder = Enum.SortOrder.LayoutOrder
ScannerOuterLayout.Parent = ScannerOuterScroll

-- The TempV results list: fixed height inner scroll so it never pushes the
-- controls below the visible area.
local ScannerScroll = Instance.new("ScrollingFrame")
ScannerScroll.Size = UDim2.new(1, 0, 0, 220)
ScannerScroll.BackgroundColor3 = COLORS.surface
ScannerScroll.BorderSizePixel = 0
ScannerScroll.ScrollBarThickness = 4
ScannerScroll.ScrollBarImageColor3 = COLORS.border
ScannerScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
ScannerScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
ScannerScroll.LayoutOrder = 1
ScannerScroll.Parent = ScannerOuterScroll
setupMobileScroll(ScannerScroll)
applyCorner(ScannerScroll, CONST.RADIUS.lg)
applyStroke(ScannerScroll, COLORS.border, 1, 0.65)

local Scroll = ScannerScroll
UI.ScannerScroll = Scroll

local UIList = Instance.new("UIListLayout")
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Padding = UDim.new(0, 6)
UIList.Parent = Scroll
UI.ScannerUIList = UIList

local UIPadding = Instance.new("UIPadding")
UIPadding.PaddingTop = UDim.new(0, 8)
UIPadding.PaddingBottom = UDim.new(0, 8)
UIPadding.PaddingLeft = UDim.new(0, 8)
UIPadding.PaddingRight = UDim.new(0, 8)
UIPadding.Parent = Scroll

-- Controls sit underneath the list inside the outer scroll, so they always
-- have room and you can scroll the whole page if the window is short.
local ScannerControls = Instance.new("Frame")
ScannerControls.Size = UDim2.new(1, 0, 0, 0)
ScannerControls.AutomaticSize = Enum.AutomaticSize.Y
ScannerControls.BackgroundTransparency = 1
ScannerControls.LayoutOrder = 2
ScannerControls.Parent = ScannerOuterScroll

local ScannerControlsLayout = Instance.new("UIListLayout")
ScannerControlsLayout.Padding = UDim.new(0, 8)
ScannerControlsLayout.SortOrder = Enum.SortOrder.LayoutOrder
ScannerControlsLayout.Parent = ScannerControls

UI.AutoRefreshToggle = createHubButton(ScannerControls, "Auto Scan", "Refresh list automatically")
setHubToggle(UI.AutoRefreshToggle, true)

UI.TempVHighlightToggle = createHubButton(ScannerControls, "TempV Highlight", "World ESP for TempV models")
setHubToggle(UI.TempVHighlightToggle, false)

UI.RefreshNowBtn = createHubButton(ScannerControls, "Refresh Scanner", "Scan workspace now")

end -- scope block 1a-home (GUI - Luau local register limit)

do -- scope block 1a-move (GUI - Luau local register limit)

local MovementScroll = Instance.new("ScrollingFrame")
MovementScroll.Size = UDim2.new(1, 0, 1, 0)
MovementScroll.BackgroundTransparency = 1
MovementScroll.BorderSizePixel = 0
MovementScroll.ScrollBarThickness = 5
MovementScroll.ScrollBarImageColor3 = COLORS.border
MovementScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
MovementScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
MovementScroll.ScrollingDirection = Enum.ScrollingDirection.Y
MovementScroll.Parent = pages.Movement
setupMobileScroll(MovementScroll)

local MovementListPad = Instance.new("UIPadding")
MovementListPad.PaddingTop = UDim.new(0, 4)
MovementListPad.PaddingBottom = UDim.new(0, 8)
MovementListPad.PaddingRight = UDim.new(0, 6)
MovementListPad.Parent = MovementScroll

local MovementList = Instance.new("Frame")
MovementList.Size = UDim2.new(1, 0, 0, 0)
MovementList.AutomaticSize = Enum.AutomaticSize.Y
MovementList.BackgroundTransparency = 1
MovementList.Active = false
MovementList.Parent = MovementScroll

local MovementLayout = Instance.new("UIListLayout")
MovementLayout.Padding = UDim.new(0, 8)
MovementLayout.Parent = MovementList

UI.SpeedToggle = createHubButton(MovementList, "Custom Walk Speed", "Enable before using slider")
setHubToggle(UI.SpeedToggle, false)

UI.SpeedSlider, UI.setSpeedSliderValue = createHubSlider(MovementList, "Walk Speed", 16, 200, 16, function(value)
    State.walkSpeed = value
end)

UI.JumpToggle = createHubButton(MovementList, "Custom Jump Power", "Enable before using slider")
setHubToggle(UI.JumpToggle, false)

UI.JumpSlider, UI.setJumpSliderValue = createHubSlider(MovementList, "Jump Power", 50, 300, 50, function(value)
    State.jumpPower = value
end)

UI.FlightToggle = createHubButton(MovementList, "Flight", "WASD + Space/Shift to fly")
setHubToggle(UI.FlightToggle, false)

UI.NoclipToggle = createHubButton(MovementList, "Noclip", "Walk through walls")
setHubToggle(UI.NoclipToggle, false)

UI.InfJumpToggle = createHubButton(MovementList, "Infinite Jump", "Jump repeatedly in mid-air")
setHubToggle(UI.InfJumpToggle, false)

UI.ResetMovementBtn = createHubButton(MovementList, "Reset Movement", "Restore default speed & jump")

local PremiumScroll = Instance.new("ScrollingFrame")
PremiumScroll.Size = UDim2.new(1, 0, 1, 0)
PremiumScroll.BackgroundTransparency = 1
PremiumScroll.BorderSizePixel = 0
PremiumScroll.ScrollBarThickness = 5
PremiumScroll.ScrollBarImageColor3 = COLORS.border
PremiumScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
PremiumScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
PremiumScroll.ScrollingDirection = Enum.ScrollingDirection.Y
PremiumScroll.Parent = pages.Premium
setupMobileScroll(PremiumScroll)

local PremiumListPad = Instance.new("UIPadding")
PremiumListPad.PaddingTop = UDim.new(0, 4)
PremiumListPad.PaddingBottom = UDim.new(0, 8)
PremiumListPad.PaddingRight = UDim.new(0, 6)
PremiumListPad.Parent = PremiumScroll

local PremiumList = Instance.new("Frame")
PremiumList.Size = UDim2.new(1, 0, 0, 0)
PremiumList.AutomaticSize = Enum.AutomaticSize.Y
PremiumList.BackgroundTransparency = 1
PremiumList.Active = false
PremiumList.Parent = PremiumScroll

local PremiumLayout = Instance.new("UIListLayout")
PremiumLayout.Padding = UDim.new(0, 8)
PremiumLayout.Parent = PremiumList

UI.PremiumStatusBtn = createHubButton(
    PremiumList,
    State.isPremium and "Premium Active" or "Premium Locked",
    State.isPremium and "Premium features unlocked" or "Get a key to unlock premium features"
)
UI.PremiumStatusBtn.Active = false
UI.PremiumStatusBtn.AutoButtonColor = false
if UI.PremiumStatusBtn:FindFirstChild("StateLabel") then
    UI.PremiumStatusBtn.StateLabel.Visible = false
end

UI.ATrainKillToggle = createHubButton(
    PremiumList,
    "A-Train Kill",
    "PC: enable + press Q - Mobile: enable + tap in-game DASH"
)
setHubToggle(UI.ATrainKillToggle, false)
UI.ATrainKillToggle.Visible = State.isPremium
bindHubClick(UI.ATrainKillToggle, function()
    if NF.F.setATrainKill then
        NF.F.setATrainKill(not State.aTrainKillEnabled)
    end
end)

UI.HomelanderAutowinToggle = createHubButton(
    PremiumList,
    "Homelander Autowin",
    "Auto TP behind players and choke (E) until they die - needs Homelander role"
)
setHubToggle(UI.HomelanderAutowinToggle, false)
UI.HomelanderAutowinToggle.Visible = State.isPremium
bindHubClick(UI.HomelanderAutowinToggle, function()
    if NF.F.setHomelanderAutowin then
        NF.F.setHomelanderAutowin(not State.homelanderAutowinEnabled)
    end
end)

local CombatScroll = Instance.new("ScrollingFrame")
CombatScroll.Size = UDim2.new(1, 0, 1, 0)
CombatScroll.BackgroundTransparency = 1
CombatScroll.BorderSizePixel = 0
CombatScroll.ScrollBarThickness = 5
CombatScroll.ScrollBarImageColor3 = COLORS.border
CombatScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
CombatScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
CombatScroll.ScrollingDirection = Enum.ScrollingDirection.Y
CombatScroll.Parent = pages.Combat
setupMobileScroll(CombatScroll)

local CombatListPad = Instance.new("UIPadding")
CombatListPad.PaddingTop = UDim.new(0, 4)
CombatListPad.PaddingBottom = UDim.new(0, 8)
CombatListPad.PaddingRight = UDim.new(0, 6)
CombatListPad.Parent = CombatScroll

local CombatList = Instance.new("Frame")
CombatList.Size = UDim2.new(1, 0, 0, 0)
CombatList.AutomaticSize = Enum.AutomaticSize.Y
CombatList.BackgroundTransparency = 1
CombatList.Active = false
CombatList.Parent = CombatScroll

local CombatLayout = Instance.new("UIListLayout")
CombatLayout.Padding = UDim.new(0, 8)
CombatLayout.Parent = CombatList

UI.HomelanderESPToggle = createHubButton(CombatList, "Killer ESP", "Homelander & Stormfront - rescans every 3s")
setHubToggle(UI.HomelanderESPToggle, false)

UI.TeamESPToggle = createHubButton(CombatList, "Team ESP", "Rescans players every 3 seconds")
setHubToggle(UI.TeamESPToggle, false)

UI.AimbotToggle = createHubButton(CombatList, "Aimbot", "Enable - PC hold RMB to lock - Mobile tap LOCK ON")
setHubToggle(UI.AimbotToggle, false)

UI.MobileAimDragToggle = createHubButton(CombatList, "Unlock LOCK ON Button", "Drag the LOCK ON button to reposition it")
setHubToggle(UI.MobileAimDragToggle, false, "UNLOCKED", "LOCKED")
UI.MobileAimDragToggle.Visible = true

UI.TeleportHomelanderBtn = createHubButton(CombatList, "Teleport To Homelander", "Requires Homelander ESP")

UI.TeleportSafeZoneBtn = createHubButton(CombatList, "Teleport To Safe Zone", "Instant safe zone TP")

UI.ClearESPBtn = createHubButton(CombatList, "Clear All ESP", "Remove highlights & billboards")

UI.BloodManipToggle = createHubButton(CombatList, "Blood Manipulator Kill", "Hold E on head - stays locked until release")
setHubToggle(UI.BloodManipToggle, false)
bindHubClick(UI.BloodManipToggle, function()
    State.bloodManipEnabled = not State.bloodManipEnabled
    setHubToggle(UI.BloodManipToggle, State.bloodManipEnabled)
    if not State.bloodManipEnabled then
        State.holdingBloodManipKey = false
        if NF.F.resetBloodManipState then NF.F.resetBloodManipState() end
    end
end)

end -- scope block 1a-move (GUI - Luau local register limit)

do -- scope block 1a-misc (GUI - Luau local register limit)

local TrollScroll = Instance.new("ScrollingFrame")
TrollScroll.Size = UDim2.new(1, 0, 1, 0)
TrollScroll.BackgroundTransparency = 1
TrollScroll.BorderSizePixel = 0
TrollScroll.ScrollBarThickness = 5
TrollScroll.ScrollBarImageColor3 = COLORS.border
TrollScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
TrollScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
TrollScroll.ScrollingDirection = Enum.ScrollingDirection.Y
TrollScroll.Parent = pages.Troll
setupMobileScroll(TrollScroll)

local TrollListPad = Instance.new("UIPadding")
TrollListPad.PaddingTop = UDim.new(0, 4)
TrollListPad.PaddingBottom = UDim.new(0, 8)
TrollListPad.PaddingRight = UDim.new(0, 6)
TrollListPad.Parent = TrollScroll

local TrollList = Instance.new("Frame")
TrollList.Size = UDim2.new(1, 0, 0, 0)
TrollList.AutomaticSize = Enum.AutomaticSize.Y
TrollList.BackgroundTransparency = 1
TrollList.Active = false
TrollList.Parent = TrollScroll

local TrollLayout = Instance.new("UIListLayout")
TrollLayout.Padding = UDim.new(0, 8)
TrollLayout.Parent = TrollList

UI.SpinToggle = createHubButton(TrollList, "Spin Bot", "Spin your character constantly")
setHubToggle(UI.SpinToggle, false)
bindHubClick(UI.SpinToggle, function()
    State.spinEnabled = not State.spinEnabled
    setHubToggle(UI.SpinToggle, State.spinEnabled)
end)

UI.DesyncToggle = createHubButton(TrollList, "Desync", "Server marker + client label - hold E to interact")
setHubToggle(UI.DesyncToggle, false)
bindHubClick(UI.DesyncToggle, function()
    if NF.F.setDesync then
        NF.F.setDesync(not State.desyncEnabled)
        setHubToggle(UI.DesyncToggle, State.desyncEnabled, "ON", "OFF")
    end
end)

UI.FlingHomelanderBtn = createHubButton(TrollList, "Fling Homelander", "SkidFling overlap - needs collision")
bindHubClick(UI.FlingHomelanderBtn, function()
    if NF.F.flingHomelander then task.spawn(NF.F.flingHomelander) end
end)

UI.FlingSelfBtn = createHubButton(TrollList, "Fling Self", "Launch yourself into the air")
bindHubClick(UI.FlingSelfBtn, function()
    if NF.F.flingSelf then NF.F.flingSelf() end
end)

UI.TpRandomBtn = createHubButton(TrollList, "TP To Random Player", "Teleport to a random player")
bindHubClick(UI.TpRandomBtn, function()
    if NF.F.tpRandomPlayer then NF.F.tpRandomPlayer() end
end)

UI.AnnoySoundBtn = createHubButton(TrollList, "Play Loud Sound", "Play an annoying sound locally")
bindHubClick(UI.AnnoySoundBtn, function()
    if NF.F.playAnnoyingSound then NF.F.playAnnoyingSound() end
end)

UI.ResetTrollBtn = createHubButton(TrollList, "Reset Troll Effects", "Turn off spin & desync")
bindHubClick(UI.ResetTrollBtn, function()
    if NF.F.resetTrollEffects then NF.F.resetTrollEffects() end
end)

local MiscScroll = Instance.new("ScrollingFrame")
MiscScroll.Name = "MiscScroll"
MiscScroll.Size = UDim2.new(1, 0, 1, 0)
MiscScroll.BackgroundTransparency = 1
MiscScroll.BorderSizePixel = 0
MiscScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
MiscScroll.ClipsDescendants = true
MiscScroll.Parent = pages.Misc
setupMobileScroll(MiscScroll)

local MiscContent = Instance.new("Frame")
MiscContent.Name = "MiscContent"
MiscContent.Size = UDim2.new(1, 0, 0, 0)
MiscContent.AutomaticSize = Enum.AutomaticSize.Y
MiscContent.BackgroundTransparency = 1
MiscContent.ClipsDescendants = true
MiscContent.Active = false
MiscContent.Parent = MiscScroll

local MiscListPad = Instance.new("UIPadding")
MiscListPad.PaddingTop = UDim.new(0, 4)
MiscListPad.PaddingBottom = UDim.new(0, State.isMobile and 120 or 12)
MiscListPad.PaddingRight = UDim.new(0, 8)
MiscListPad.PaddingLeft = UDim.new(0, 4)
MiscListPad.Parent = MiscContent

local MiscLayout = Instance.new("UIListLayout")
MiscLayout.Padding = UDim.new(0, 8)
MiscLayout.Parent = MiscContent

local _, SpectateBody = createMiscFold(MiscContent, "Spectate", State.isMobile, MiscScroll)

local MiscSubLabel = Instance.new("TextLabel")
MiscSubLabel.Size = UDim2.new(1, 0, 0, 18)
MiscSubLabel.BackgroundTransparency = 1
MiscSubLabel.Text = "Select a player below - spectate or fling"
MiscSubLabel.TextColor3 = COLORS.textMuted
MiscSubLabel.TextSize = 12
MiscSubLabel.Font = Enum.Font.GothamMedium
MiscSubLabel.TextXAlignment = Enum.TextXAlignment.Left
MiscSubLabel.Parent = SpectateBody

UI.SpectateSelectedLabel = Instance.new("TextLabel")
UI.SpectateSelectedLabel.Size = UDim2.new(1, 0, 0, 32)
UI.SpectateSelectedLabel.BackgroundColor3 = COLORS.elevated
UI.SpectateSelectedLabel.Text = "Selected: None"
UI.SpectateSelectedLabel.TextColor3 = COLORS.textMuted
UI.SpectateSelectedLabel.TextSize = 12
UI.SpectateSelectedLabel.Font = Enum.Font.GothamSemibold
UI.SpectateSelectedLabel.TextXAlignment = Enum.TextXAlignment.Left
UI.SpectateSelectedLabel.Parent = SpectateBody
applyCorner(UI.SpectateSelectedLabel, CONST.RADIUS.md)
applyStroke(UI.SpectateSelectedLabel, COLORS.border, 1, 0.7)

local SpectateSelectedPad = Instance.new("UIPadding")
SpectateSelectedPad.PaddingLeft = UDim.new(0, 12)
SpectateSelectedPad.Parent = UI.SpectateSelectedLabel

UI.SpectatePlayerScroll = Instance.new("ScrollingFrame")
UI.SpectatePlayerScroll.Size = UDim2.new(1, 0, 0, State.isMobile and 120 or 180)
UI.SpectatePlayerScroll.BackgroundColor3 = COLORS.surface
UI.SpectatePlayerScroll.BorderSizePixel = 0
UI.SpectatePlayerScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
UI.SpectatePlayerScroll.Parent = SpectateBody
setupMobileScroll(UI.SpectatePlayerScroll)
applyCorner(UI.SpectatePlayerScroll, CONST.RADIUS.md)
applyStroke(UI.SpectatePlayerScroll, COLORS.border, 1, 0.65)

UI.SpectatePlayerList = Instance.new("Frame")
UI.SpectatePlayerList.Size = UDim2.new(1, -12, 0, 0)
UI.SpectatePlayerList.Position = UDim2.new(0, 6, 0, 6)
UI.SpectatePlayerList.BackgroundTransparency = 1
UI.SpectatePlayerList.Active = false
UI.SpectatePlayerList.Parent = UI.SpectatePlayerScroll

local SpectatePlayerLayout = Instance.new("UIListLayout")
SpectatePlayerLayout.Padding = UDim.new(0, 6)
SpectatePlayerLayout.Parent = UI.SpectatePlayerList

SpectatePlayerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    UI.SpectatePlayerList.Size = UDim2.new(1, -12, 0, SpectatePlayerLayout.AbsoluteContentSize.Y)
    UI.SpectatePlayerScroll.CanvasSize = UDim2.new(0, 0, 0, SpectatePlayerLayout.AbsoluteContentSize.Y + 12)
end)

UI.RefreshSpectateListBtn = createHubButton(SpectateBody, "Refresh Player List", "Update online players")
bindHubClick(UI.RefreshSpectateListBtn, function()
    if NF.F.refreshMiscPlayerList then NF.F.refreshMiscPlayerList() end
end)

UI.SpectateBtn = createHubButton(SpectateBody, "Spectate", "Right-drag orbit - scroll zoom")
bindHubClick(UI.SpectateBtn, function()
    if State.spectateSelected then
        if NF.F.stopFreecam then NF.F.stopFreecam() end
        if NF.F.startSpectate then NF.F.startSpectate(State.spectateSelected) end
    else
        warn("[NightFall] Select a player from the list first.")
    end
end)

UI.StopSpectateBtn = createHubButton(SpectateBody, "Stop Spectate", "Return camera to you")
bindHubClick(UI.StopSpectateBtn, function()
    if NF.F.stopSpectate then NF.F.stopSpectate() end
end)

local _, FlingBody = createMiscFold(MiscContent, "Fling", false, MiscScroll)

UI.FlingSelectedBtn = createHubButton(FlingBody, "Fling Selected", "SkidFling - turn off noclip/desync first")
bindHubClick(UI.FlingSelectedBtn, function()
    if State.spectateSelected and NF.F.skidFlingPlayer then
        task.spawn(function()
            NF.F.skidFlingPlayer(State.spectateSelected)
        end)
    else
        warn("[NightFall] Select a player from the list first.")
    end
end)

local _, FreecamBody = createMiscFold(MiscContent, "Freecam", false, MiscScroll)

UI.FreecamToggle = createHubButton(FreecamBody, "Freecam", "WASD move - right-drag look - scroll speed")
setHubToggle(UI.FreecamToggle, false)
bindHubClick(UI.FreecamToggle, function()
    if NF.F.setFreecam then NF.F.setFreecam(not State.freecamEnabled) end
end)

UI.FreecamSpeedSlider, UI.setFreecamSpeedSliderValue = createHubSlider(
    FreecamBody,
    "Freecam Speed",
    20,
    250,
    80,
    function(value)
        State.freecamSpeed = value
    end
)

local _, EffectsBody = createMiscFold(MiscContent, "Effects", false, MiscScroll)

UI.RemoveBloodManipEffectsToggle = createHubButton(
    EffectsBody,
    "Remove Blood Manipulator Effects",
    "Blocks red screen overlay & forced zoom"
)
setHubToggle(UI.RemoveBloodManipEffectsToggle, false)
bindHubClick(UI.RemoveBloodManipEffectsToggle, function()
    if NF.F.setRemoveBloodManipEffects then
        NF.F.setRemoveBloodManipEffects(not State.removeBloodManipEffects)
    end
end)

local _, AimbotBody = createMiscFold(MiscContent, "Aimbot", false, MiscScroll)

local AimbotDesc = Instance.new("TextLabel")
AimbotDesc.Size = UDim2.new(1, 0, 0, 32)
AimbotDesc.BackgroundTransparency = 1
AimbotDesc.Text = "Enable Aimbot - PC hold RMB - set shift lock key below - delay 0 = fast"
AimbotDesc.TextColor3 = COLORS.textMuted
AimbotDesc.TextSize = 11
AimbotDesc.Font = Enum.Font.GothamMedium
AimbotDesc.TextWrapped = true
AimbotDesc.TextXAlignment = Enum.TextXAlignment.Left
AimbotDesc.TextYAlignment = Enum.TextYAlignment.Top
AimbotDesc.Parent = AimbotBody

UI.AimbotDelaySlider, UI.setAimbotDelaySliderValue = createHubSlider(
    AimbotBody,
    "Aim Delay (ms)",
    0,
    500,
    State.aimbotDelayMs,
    function(value)
        State.aimbotDelayMs = value
        saveAimbotSettings()
    end
)

local _, AimbotPartBox = createHubTextInput(
    AimbotBody,
    "Target Part",
    "Head, HumanoidRootPart, UpperTorso...",
    State.aimbotTargetPart
)
UI.AimbotPartBox = AimbotPartBox

bindConnection(AimbotPartBox.FocusLost:Connect(function()
    local text = AimbotPartBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then text = "Head" end
    State.aimbotTargetPart = text
    AimbotPartBox.Text = text
    saveAimbotSettings()
end))

local function setAimbotTargetPartPreset(partName)
    State.aimbotTargetPart = partName
    if UI.AimbotPartBox then
        UI.AimbotPartBox.Text = partName
    end
    saveAimbotSettings()
end

UI.AimbotPartHeadBtn = createHubButton(AimbotBody, "Preset: Head", "Default face-level tracking")
bindHubClick(UI.AimbotPartHeadBtn, function()
    setAimbotTargetPartPreset("Head")
end)

UI.AimbotPartHrpBtn = createHubButton(AimbotBody, "Preset: HumanoidRootPart", "Track center mass")
bindHubClick(UI.AimbotPartHrpBtn, function()
    setAimbotTargetPartPreset("HumanoidRootPart")
end)

UI.AimbotPartTorsoBtn = createHubButton(AimbotBody, "Preset: UpperTorso", "Track upper body (R15/R6 fallback)")
bindHubClick(UI.AimbotPartTorsoBtn, function()
    setAimbotTargetPartPreset("UpperTorso")
end)

UI.ShiftLockKeyBtn = createHubKeybindRow(
    AimbotBody,
    "Shift Lock Key",
    "Click then press a key - toggles shift lock mode for aimbot",
    function()
        return State.shiftLockKey
    end,
    function(keyCode)
        State.shiftLockKey = keyCode
        saveAimbotSettings()
    end
)

local _, FailsafeBody = createMiscFold(MiscContent, "Failsafe", false, MiscScroll)

local FailsafeDesc = Instance.new("TextLabel")
FailsafeDesc.Size = UDim2.new(1, 0, 0, 32)
FailsafeDesc.BackgroundTransparency = 1
FailsafeDesc.Text = "TP to safe zone when HP drops below threshold - TP back when you heal above it."
FailsafeDesc.TextColor3 = COLORS.textMuted
FailsafeDesc.TextSize = 11
FailsafeDesc.Font = Enum.Font.GothamMedium
FailsafeDesc.TextWrapped = true
FailsafeDesc.TextXAlignment = Enum.TextXAlignment.Left
FailsafeDesc.TextYAlignment = Enum.TextYAlignment.Top
FailsafeDesc.Parent = FailsafeBody

UI.FailsafeToggle = createHubButton(
    FailsafeBody,
    "Failsafe Teleport",
    "Auto-TP to safe zone when health goes under your threshold"
)
setHubToggle(UI.FailsafeToggle, State.failsafeEnabled)

UI.FailsafeSlider, UI.setFailsafeSliderValue = createHubSlider(
    FailsafeBody,
    "Failsafe Health %",
    1,
    100,
    State.failsafeThreshold,
    function(value)
        State.failsafeThreshold = value
        saveFailsafeSettings()
    end
)

-- All Misc sections start collapsed (children are added after fold creation)
for _, collapse in ipairs(miscFoldSetters) do
    collapse(false)
end
MiscScroll.CanvasPosition = Vector2.new(0, 0)

State.__miscCollapseAll = function()
    for _, collapseFn in ipairs(miscFoldSetters) do
        collapseFn(false)
    end
    MiscScroll.CanvasPosition = Vector2.new(0, 0)
end

local SettingsScroll = Instance.new("ScrollingFrame")
SettingsScroll.Size = UDim2.new(1, 0, 1, 0)
SettingsScroll.BackgroundTransparency = 1
SettingsScroll.BorderSizePixel = 0
SettingsScroll.ScrollBarThickness = 5
SettingsScroll.ScrollBarImageColor3 = COLORS.border
SettingsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
SettingsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
SettingsScroll.ScrollingDirection = Enum.ScrollingDirection.Y
SettingsScroll.Parent = pages.Settings
setupMobileScroll(SettingsScroll)

local SettingsListPad = Instance.new("UIPadding")
SettingsListPad.PaddingTop = UDim.new(0, 4)
SettingsListPad.PaddingBottom = UDim.new(0, 8)
SettingsListPad.PaddingRight = UDim.new(0, 6)
SettingsListPad.Parent = SettingsScroll

local SettingsList = Instance.new("Frame")
SettingsList.Size = UDim2.new(1, 0, 0, 0)
SettingsList.AutomaticSize = Enum.AutomaticSize.Y
SettingsList.BackgroundTransparency = 1
SettingsList.Active = false
SettingsList.Parent = SettingsScroll

local SettingsLayout = Instance.new("UIListLayout")
SettingsLayout.Padding = UDim.new(0, 8)
SettingsLayout.Parent = SettingsList

UI.ToggleSizeSlider, UI.setToggleSizeSliderValue = createHubSlider(
    SettingsList,
    "Toggle Button Size",
    24,
    72,
    State.toggleCubeSize,
    function(value)
        if NF.F.applyToggleCubeSize then
            NF.F.applyToggleCubeSize(value)
        end
    end
)

UI.ResetTogglePosBtn = createHubButton(SettingsList, "Reset Toggle Position", "Move cube back to screen center")

local _, GuiSizeBox = createHubTextInput(
    SettingsList,
    "GUI Size",
    "30-100",
    tostring(math.floor(State.guiScale * 100))
)
UI.GuiSizeBox = GuiSizeBox

bindConnection(GuiSizeBox.FocusLost:Connect(function()
    local raw = GuiSizeBox.Text:gsub("%%", ""):gsub("^%s+", ""):gsub("%s+$", "")
    local n = tonumber(raw)
    if not n then
        GuiSizeBox.Text = tostring(math.floor(State.guiScale * 100))
        return
    end
    n = math.clamp(math.floor(n + 0.5), 30, 100)
    GuiSizeBox.Text = tostring(n)
    if NF.F.applyGuiScale then
        NF.F.applyGuiScale(n / 100)
    end
end))

UI.SwappedMouseToggle = createHubButton(
    SettingsList,
    "Right-Click Primary Mouse",
    "Use if your mouse buttons are swapped"
)
setHubToggle(UI.SwappedMouseToggle, false)

UI.HideMobileGuiToggle = createHubButton(
    SettingsList,
    "Hide Mobile GUI",
    "Hides LOCK ON button, FOV circle & flight up/down buttons"
)
setHubToggle(UI.HideMobileGuiToggle, false)

switchTab("Home")

end -- scope block 1a-misc (GUI - Luau local register limit)

do -- scope block 1b (homelander detect - Luau local register limit)

State.autoRefreshEnabled = true
State.homelanderESPEnabled = false
State.teamESPEnabled = false
State.tempVHighlightEnabled = false
State.aimbotEnabled = false
State.aimbotLockedTarget = nil
State.aimbotLockedHead = nil
State.aimbotLockExpired = false
State.aimbotCursorPos = nil

State.aTrainKillEnabled = false
State.aTrainKillExecuting = false
State.aTrainDashHooked = {}
State.aTrainLastDashTrigger = 0
State.aTrainDashScanConn = nil

State.homelanderAutowinEnabled = false
State.homelanderAutowinRunning = false
State.homelanderAutowinTarget = nil
State.homelanderAutowinHoldActive = false
State.homelanderAutowinLastE = 0
State.tempVRecentUntil = {}

State.spinEnabled = false
State.desyncEnabled = false
State.desyncConnections = {}
State.desyncClientCFrame = nil
State.desyncServerCFrame = nil
State.desyncRenderBound = false
State.desyncPositionHoldConnection = nil
State.desyncVisualFolder = nil
State.desyncServerMarker = nil
State.desyncServerBillboard = nil
State.desyncClientBillboard = nil
State.desyncClientHighlight = nil

State.spectateTarget = nil
State.spectateSelected = nil
State.spectating = false
State.spectateConnections = {}
State.spectateSavedCameraType = nil
State.spectateSavedCameraSubject = nil
State.spectateFollowDistance = 18
State.spectateYaw = 0
State.spectatePitch = 20

State.freecamEnabled = false
State.freecamLooking = false
State.freecamSpeed = 80
State.freecamCFrame = nil
State.freecamYaw = 0
State.freecamPitch = 0
State.cameraDragDelta = Vector2.zero
State.cameraSavedType = nil
State.cameraSavedSubject = nil
State.cameraSavedMaxZoom = nil
State.cameraSavedMinZoom = nil

State.bloodManipEnabled = false
State.holdingBloodManipKey = false
State.bloodManipTarget = nil
State.bloodManipHighlight = nil
State.bloodManipLockPos = nil
State.bloodManipWalkAwayStart = nil
State.bloodManipExecuting = false
State.bloodManipTargetLockedAt = nil
State.removeBloodManipEffects = false
State.bloodEffectSavedFov = 70
State.bloodEffectSavedMaxZoom = 128
State.bloodEffectSavedMinZoom = 0.5
State.bloodEffectBlockConnections = {}
State.bloodEffectTracked = {}
State.bloodEffectRestoringCamera = false
State.swappedMouseButtons = false
State.spectateOrbiting = false
State.cameraMouseLocked = false

State.highlights = {}
State.billboards = {}
State.tempVHighlights = {}
State.tempVBillboards = {}
State.trackedTempVModels = {}
State.firstHomelander = nil
State.detectedKillerRole = nil
State.scanTempVParts = nil
State.scanForHomelander = nil

CONST.KILLER_ROLES = {"HOMELANDER", "STORMFRONT"}
CONST.SCRIPT_GUI_NAMES = {
    ScriptHub = true,
    ScriptHubToggle = true,
    ScriptHubMobileAim = true,
}

function NF.F.clearHighlight(plr)
    if State.highlights[plr] then
        State.highlights[plr]:Destroy()
        State.highlights[plr] = nil
    end
    if State.billboards[plr] then
        State.billboards[plr].gui:Destroy()
        State.billboards[plr] = nil
    end
end

function NF.F.createPlayerESP(plr, color, isHomelander)
    if not plr.Character then return end
    
    NF.F.clearHighlight(plr)
    
    local success = pcall(function()
        local hl = Instance.new("Highlight")
        hl.Adornee = plr.Character
        hl.FillColor = color
        hl.OutlineColor = isHomelander and Color3.fromRGB(255, 200, 0) or Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = isHomelander and 0.3 or 0.4
        hl.OutlineTransparency = isHomelander and 0 or 0.3
        hl.Parent = plr.Character
        State.highlights[plr] = hl

        local head = plr.Character:FindFirstChild("Head") or plr.Character:FindFirstChild("HumanoidRootPart")
        if head then
            local bb = Instance.new("BillboardGui")
            bb.Adornee = head
            bb.Size = UDim2.new(0, isHomelander and 280 or 250, 0, isHomelander and 90 or 80)
            bb.StudsOffset = Vector3.new(0, isHomelander and 5 or 4.5, 0)
            bb.AlwaysOnTop = true
            bb.Name = "ScriptHubESPLabel"
            bb:SetAttribute("ScriptHubESP", true)
            bb.Parent = CoreGui

            local txt = Instance.new("TextLabel")
            txt.Size = UDim2.new(1, 0, 1, 0)
            txt.BackgroundTransparency = 1
            txt.TextColor3 = color
            txt.TextStrokeTransparency = 0
            txt.TextStrokeColor3 = Color3.new(0, 0, 0)
            txt.Font = Enum.Font.SourceSansBold
            txt.TextSize = isHomelander and 18 or 16
            txt.Parent = bb

            State.billboards[plr] = {gui = bb, label = txt}
        end
    end)
    
    if not success then
        warn("Failed to create ESP for", plr.Name)
    end
end

function NF.F.isScriptOwnedGui(obj)
    if not obj then return false end
    if obj:GetAttribute("ScriptHubESP") then return true end
    local gui = obj:IsA("ScreenGui") and obj or obj:FindFirstAncestorOfClass("ScreenGui")
    return gui and CONST.SCRIPT_GUI_NAMES[gui.Name] == true
end

function NF.F.isOtherPlayer(plr)
    return plr and plr ~= player
end

function NF.F.getKillerRoleFromText(text)
    if type(text) ~= "string" or text == "" then return nil end
    local upper = text:upper()
    for _, role in ipairs(CONST.KILLER_ROLES) do
        if upper:find("%[" .. role .. "%]", 1, true) then
            return role
        end
        if upper:find("X%[" .. role .. "%]", 1, true) then
            return role
        end
        if upper:match("^" .. role .. "$") then
            return role
        end
    end
    return nil
end

function NF.F.textHasKillerRole(text)
    return NF.F.getKillerRoleFromText(text) ~= nil
end

function NF.F.textHasHomelanderRole(text)
    return NF.F.textHasKillerRole(text)
end

function NF.F.isKillerRoleName(name)
    if not name or name == "" then return false end
    local upper = name:upper()
    for _, role in ipairs(CONST.KILLER_ROLES) do
        if upper == role then
            return true
        end
    end
    return false
end

function NF.F.playerFromCharacterModel(model)
    if not model then return nil end
    for _, plr in pairs(Players:GetPlayers()) do
        if plr.Character == model then
            return plr
        end
    end
    return Players:GetPlayerFromCharacter(model)
end

function NF.F.nameLooksLikeHomelander(name)
    if not name or name == "" then return false end
    return NF.F.textHasHomelanderRole(name)
end

function NF.F.instanceShowsHomelanderRole(obj)
    if not obj then return false end

    if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
        return NF.F.textHasKillerRole(obj.Text)
    end
    if obj:IsA("StringValue") then
        return NF.F.textHasKillerRole(obj.Value) or NF.F.isKillerRoleName(obj.Value)
    end

    return false
end

function NF.F.characterHasHomelanderTag(character)
    if not character then return false end

    local tagged = false
    pcall(function()
        for _, tag in ipairs(CollectionService:GetTags(character)) do
            if NF.F.isKillerRoleName(tag) or NF.F.textHasKillerRole(tag) then
                tagged = true
                break
            end
        end
    end)
    return tagged
end

function NF.F.matchPlayerAndRoleFromText(text)
    local role = NF.F.getKillerRoleFromText(text)
    if not role then return nil, nil end

    local roleTag = "%[" .. role .. "%]"
    local parsedName = text:match("Spectating:%s*(.-)%s*<%s*" .. roleTag)
        or text:match("Spectating:%s*(.-)X" .. roleTag)
        or text:match("Spectating:%s*(.-)" .. roleTag)
    if parsedName then
        parsedName = parsedName:gsub("X$", ""):gsub("[%s<]+$", ""):gsub("%s+$", "")
        for _, plr in pairs(Players:GetPlayers()) do
            if NF.F.isOtherPlayer(plr) then
                if plr.Name == parsedName or plr.DisplayName == parsedName then
                    return plr, role
                end
                if plr.Name:find(parsedName, 1, true) or parsedName:find(plr.Name, 1, true) then
                    return plr, role
                end
            end
        end
    end

    for _, plr in pairs(Players:GetPlayers()) do
        if NF.F.isOtherPlayer(plr) then
            for _, checkRole in ipairs(CONST.KILLER_ROLES) do
                local checkTag = "%[" .. checkRole .. "%]"
                if text:find(plr.Name .. "X" .. checkTag, 1, true)
                    or text:find(plr.Name .. "%s*<%s*" .. checkTag, 1, true)
                    or text:find(plr.Name .. checkTag, 1, true)
                    or (plr.DisplayName ~= "" and (
                        text:find(plr.DisplayName .. "X" .. checkTag, 1, true)
                        or text:find(plr.DisplayName .. "%s*<%s*" .. checkTag, 1, true)
                        or text:find(plr.DisplayName .. checkTag, 1, true)
                    )) then
                    return plr, checkRole
                end
            end
        end
    end

    return nil, nil
end

function NF.F.matchPlayerFromText(text)
    local matchedPlayer = NF.F.matchPlayerAndRoleFromText(text)
    return matchedPlayer
end

function NF.F.findHomelanderFromSpectateUI()
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return nil, nil end

    for _, obj in pairs(playerGui:GetDescendants()) do
        if not NF.F.isScriptOwnedGui(obj)
            and (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then
            local text = obj.Text
            if text and NF.F.textHasKillerRole(text) then
                local matched, role = NF.F.matchPlayerAndRoleFromText(text)
                if NF.F.isOtherPlayer(matched) then
                    return matched, role
                end
            end
        end
    end

    return nil, nil
end

function NF.F.attributeLooksLikeHomelander(obj)
    if not obj then return false end
    for _, attrName in ipairs({
        "Role", "Character", "Hero", "Class", "Identity",
        "CurrentRole", "RoleName", "TeamRole", "IsHomelander", "SelectedHero",
    }) do
        local value = obj:GetAttribute(attrName)
        if value and NF.F.isKillerRoleName(tostring(value)) then
            return true
        end
    end
    return false
end

function NF.F.getKillerRoleForPlayer(plr)
    if not NF.F.isOtherPlayer(plr) then return nil end

    for _, container in ipairs({plr, plr.Character}) do
        if container then
            for _, attrName in ipairs({
                "Role", "Character", "Hero", "Class", "Identity",
                "CurrentRole", "RoleName", "TeamRole", "SelectedHero",
            }) do
                local value = container:GetAttribute(attrName)
                if value and NF.F.isKillerRoleName(tostring(value)) then
                    return tostring(value):upper()
                end
            end
        end
    end

    if plr.Team and NF.F.isKillerRoleName(plr.Team.Name) then
        return plr.Team.Name:upper()
    end

    local character = plr.Character
    if character then
        for _, obj in pairs(character:GetDescendants()) do
            if not NF.F.isScriptOwnedGui(obj) then
                local role = NF.F.getKillerRoleFromText(
                    obj:IsA("TextLabel") and obj.Text
                    or obj:IsA("StringValue") and obj.Value
                    or ""
                )
                if role then return role end
                if obj:IsA("StringValue") and NF.F.isKillerRoleName(obj.Value) then
                    return obj.Value:upper()
                end
            end
        end
    end

    return nil
end

function NF.F.findHomelanderFromOverheadTags()
    for _, plr in pairs(Players:GetPlayers()) do
        if NF.F.isOtherPlayer(plr) and plr.Character then
            if NF.F.characterHasHomelanderTag(plr.Character) or NF.F.attributeLooksLikeHomelander(plr.Character) then
                return plr
            end

            for _, obj in pairs(plr.Character:GetDescendants()) do
                if not NF.F.isScriptOwnedGui(obj) then
                    if obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
                        for _, child in pairs(obj:GetDescendants()) do
                            if NF.F.instanceShowsHomelanderRole(child) then
                                return plr
                            end
                        end
                    end
                    if NF.F.instanceShowsHomelanderRole(obj) or NF.F.attributeLooksLikeHomelander(obj) then
                        return plr
                    end
                end
            end
        end
    end

    return nil
end

function NF.F.findHomelanderFromLeaderstats()
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= player then
            for _, child in pairs(plr:GetChildren()) do
                if child.Name:lower():find("leader") or child.Name:lower():find("stats") then
                    for _, stat in pairs(child:GetDescendants()) do
                        if NF.F.instanceShowsHomelanderRole(stat) or NF.F.attributeLooksLikeHomelander(stat) then
                            return plr
                        end
                    end
                end
            end

            if plr.Team and NF.F.textHasKillerRole(plr.Team.Name) then
                return plr
            end
        end
    end

    return nil
end

function NF.F.hasExplicitHomelanderRole(plr)
    if not NF.F.isOtherPlayer(plr) then return false end

    local success, result = pcall(function()
        if NF.F.attributeLooksLikeHomelander(plr) then
            return true
        end

        for _, obj in pairs(plr:GetDescendants()) do
            if NF.F.instanceShowsHomelanderRole(obj) or NF.F.attributeLooksLikeHomelander(obj) then
                return true
            end
        end

        local character = plr.Character
        if not character then return false end

        if NF.F.attributeLooksLikeHomelander(character) or NF.F.characterHasHomelanderTag(character) then
            return true
        end

        for _, obj in pairs(character:GetDescendants()) do
            if NF.F.instanceShowsHomelanderRole(obj) or NF.F.attributeLooksLikeHomelander(obj) then
                return true
            end
        end

        return false
    end)

    return success and result
end

function NF.F.isPlayerHomelander(plr)
    return NF.F.hasExplicitHomelanderRole(plr)
end

function NF.F.resolveHomelanderTarget()
    if not State.homelanderESPEnabled then
        State.detectedKillerRole = nil
        return nil
    end

    local spectateTarget, spectateRole = NF.F.findHomelanderFromSpectateUI()
    if NF.F.isOtherPlayer(spectateTarget) then
        State.detectedKillerRole = spectateRole or NF.F.getKillerRoleForPlayer(spectateTarget) or "KILLER"
        return spectateTarget
    end

    local overheadTarget = NF.F.findHomelanderFromOverheadTags()
    if NF.F.isOtherPlayer(overheadTarget) and NF.F.hasExplicitHomelanderRole(overheadTarget) then
        State.detectedKillerRole = NF.F.getKillerRoleForPlayer(overheadTarget) or "KILLER"
        return overheadTarget
    end

    local leaderTarget = NF.F.findHomelanderFromLeaderstats()
    if NF.F.isOtherPlayer(leaderTarget) and NF.F.hasExplicitHomelanderRole(leaderTarget) then
        State.detectedKillerRole = NF.F.getKillerRoleForPlayer(leaderTarget) or "KILLER"
        return leaderTarget
    end

    for _, plr in pairs(Players:GetPlayers()) do
        if NF.F.isOtherPlayer(plr) and NF.F.hasExplicitHomelanderRole(plr) then
            State.detectedKillerRole = NF.F.getKillerRoleForPlayer(plr) or "KILLER"
            return plr
        end
    end

    State.detectedKillerRole = nil
    return nil
end

function NF.F.setHomelanderTarget(newTarget)
    if newTarget == player then
        newTarget = nil
    end
    if newTarget and not State.detectedKillerRole then
        State.detectedKillerRole = NF.F.getKillerRoleForPlayer(newTarget) or "KILLER"
    end
    if not newTarget then
        State.detectedKillerRole = nil
    end
    if newTarget == State.firstHomelander then
        if State.firstHomelander and State.firstHomelander.Character
            and State.firstHomelander.Character:FindFirstChild("HumanoidRootPart")
            and not State.highlights[State.firstHomelander] then
            NF.F.createPlayerESP(State.firstHomelander, Color3.fromRGB(255, 50, 50), true)
        end
        return
    end

    if State.firstHomelander then
        NF.F.clearHighlight(State.firstHomelander)
    end

    State.firstHomelander = newTarget

    if State.firstHomelander then
        UI.StatusHomelander.StateLabel.Text = (State.detectedKillerRole or "KILLER") .. " - " .. State.firstHomelander.Name:upper()
        UI.StatusHomelander.StateLabel.TextColor3 = COLORS.danger
    else
        UI.StatusHomelander.StateLabel.Text = "NONE"
        UI.StatusHomelander.StateLabel.TextColor3 = COLORS.textMuted
    end

    if State.firstHomelander and State.firstHomelander.Character
        and State.firstHomelander.Character:FindFirstChild("HumanoidRootPart") then
        NF.F.createPlayerESP(State.firstHomelander, Color3.fromRGB(255, 50, 50), true)
    end
end

State.scanForHomelander = function()
    if not State.homelanderESPEnabled then
        NF.F.setHomelanderTarget(nil)
        return
    end

    NF.F.setHomelanderTarget(NF.F.resolveHomelanderTarget())
end

NF.F.getHumanoid = getHumanoid
NF.F.getRoot = getRoot
NF.F.setHubToggle = setHubToggle

end -- scope block 1b (homelander detect - Luau local register limit)

do -- scope block 1e (desync + movement - Luau local register limit)

local A = NF.F
local getRoot = A.getRoot
local getHumanoid = A.getHumanoid

local NEXTGEN_REPLICATOR_FLAGS = {
    "NextGenReplicatorEnabledWrite4",
    "NextGenReplicatorEnabledWrite3",
    "NextGenReplicatorEnabledWrite2",
    "NextGenReplicatorEnabledWrite",
}

local DESYNC_FFLAGS_ON = {
    PhysicsSenderMaxBandwidthBps = "0",
    PhysicsSenderMaxBandwidthBpsScaling = "0",
    S2PhysicsSenderRate = "0",
    GameNetDontSendRedundantDeltaPositionMillionth = "0",
}

local DESYNC_FFLAGS_OFF = {
    PhysicsSenderMaxBandwidthBps = "38760",
    PhysicsSenderMaxBandwidthBpsScaling = "1",
    S2PhysicsSenderRate = "60",
    GameNetDontSendRedundantDeltaPositionMillionth = "1000000",
}

local function setDesyncFFlags(flagTable)
    for name, value in pairs(flagTable) do
        pcall(function()
            setfflag(name, value)
        end)
    end
end

local function setNextGenReplicator(enabled)
    for _, flagName in ipairs(NEXTGEN_REPLICATOR_FLAGS) do
        pcall(function()
            setfflag(flagName, enabled and "True" or "False")
        end)
    end

    if enabled then
        for _, flagName in ipairs(NEXTGEN_REPLICATOR_FLAGS) do
            pcall(function()
                setfflag(flagName, "False")
                setfflag(flagName, "True")
            end)
        end
    end
end

local function applyDesyncHiddenProps(hrp, enabled)
    if not hrp then return end

    pcall(function()
        sethiddenproperty(hrp, "NetworkIsSleeping", enabled)
    end)
    pcall(function()
        local rule = Enum.NetworkOwnership.Automatic
        if enabled then
            pcall(function()
                rule = Enum.NetworkOwnership.Manual
            end)
        end
        sethiddenproperty(hrp, "NetworkOwnershipRule", rule)
    end)
    pcall(function()
        sethiddenproperty(player, "SimulationRadius", enabled and 2e19 or 0)
        sethiddenproperty(player, "MaxSimulationRadius", enabled and 2e19 or 0)
    end)
    if enabled then
        pcall(function()
            setsimulationradius(2e19, 2e19)
        end)
    end
end

local function ensurePartTouchInterest(part)
    if not part or not part:IsA("BasePart") then return end

    pcall(function()
        part.CanTouch = true
        part.CanQuery = true
    end)

    if not part:FindFirstChild("TouchInterest") then
        local conn = part.Touched:Connect(function() end)
        table.insert(State.desyncConnections, conn)
    end
end

local function applyDesyncTouchInterest(character)
    if not character then return end

    pcall(function()
        setsimulationradius(2e19, 2e19)
        sethiddenproperty(player, "SimulationRadius", 2e19)
        sethiddenproperty(player, "MaxSimulationRadius", 2e19)
    end)

    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            ensurePartTouchInterest(part)

            pcall(function()
                part.CanCollide = true
                sethiddenproperty(part, "NetworkIsSleeping", part.Name ~= "HumanoidRootPart")
            end)
        end
    end
end

local function bindDesyncTouchInterest(character)
    if not character then return end

    applyDesyncTouchInterest(character)

    table.insert(State.desyncConnections, character.DescendantAdded:Connect(function(desc)
        if not State.desyncEnabled then return end
        if desc:IsA("BasePart") then
            ensurePartTouchInterest(desc)
            pcall(function()
                desc.CanCollide = true
                sethiddenproperty(desc, "NetworkIsSleeping", desc.Name ~= "HumanoidRootPart")
            end)
        end
    end))
end

local function createDesyncBillboard(adornee, text, textColor, offset, guiParent)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "NightFallDesyncLabel"
    billboard.Size = UDim2.new(0, 220, 0, 44)
    billboard.StudsOffset = offset or Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.ResetOnSpawn = false
    if adornee then
        billboard.Adornee = adornee
    end
    billboard.Parent = guiParent or CoreGui

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 0.25
    label.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    label.Text = text
    label.TextColor3 = textColor
    label.TextStrokeTransparency = 0.35
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 15
    label.Parent = billboard

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = label

    return billboard, label
end

local function cleanupDesyncVisuals()
    pcall(function()
        if State.desyncClientBillboard then
            State.desyncClientBillboard:Destroy()
        end
    end)
    pcall(function()
        if State.desyncClientHighlight then
            State.desyncClientHighlight:Destroy()
        end
    end)
    pcall(function()
        if State.desyncServerBillboard then
            State.desyncServerBillboard:Destroy()
        end
    end)

    if State.desyncVisualFolder then
        pcall(function()
            State.desyncVisualFolder:Destroy()
        end)
    end

    pcall(function()
        if player.Character then
            for _, desc in ipairs(player.Character:GetDescendants()) do
                if desc:IsA("BillboardGui") and desc.Name == "NightFallDesyncLabel" then
                    desc:Destroy()
                end
            end
        end
        for _, desc in ipairs(CoreGui:GetChildren()) do
            if desc:IsA("BillboardGui") and desc.Name == "NightFallDesyncLabel" then
                desc:Destroy()
            end
        end
    end)

    State.desyncVisualFolder = nil
    State.desyncServerMarker = nil
    State.desyncServerBillboard = nil
    State.desyncClientBillboard = nil
    State.desyncClientHighlight = nil
end

local function setupDesyncVisuals(serverCFrame)
    cleanupDesyncVisuals()

    local folder = Instance.new("Folder")
    folder.Name = "ScriptHubDesyncVisuals"
    folder:SetAttribute("ScriptHubESP", true)
    folder.Parent = Workspace
    State.desyncVisualFolder = folder

    local marker = Instance.new("Part")
    marker.Name = "ServerPositionMarker"
    marker.Size = Vector3.new(2.2, 5.2, 2.2)
    marker.Anchored = true
    marker.CanCollide = false
    marker.CanTouch = false
    marker.CanQuery = false
    marker.Material = Enum.Material.Neon
    marker.Color = Color3.fromRGB(255, 85, 85)
    marker.Transparency = 0.55
    marker.CFrame = serverCFrame
    marker.Parent = folder
    State.desyncServerMarker = marker

    local markerHighlight = Instance.new("Highlight")
    markerHighlight.Adornee = marker
    markerHighlight.FillColor = Color3.fromRGB(255, 70, 70)
    markerHighlight.OutlineColor = Color3.fromRGB(255, 180, 180)
    markerHighlight.FillTransparency = 0.35
    markerHighlight.OutlineTransparency = 0
    markerHighlight.Parent = folder

    State.desyncServerBillboard = createDesyncBillboard(
        marker,
        "SERVER POSITION",
        Color3.fromRGB(255, 120, 120),
        Vector3.new(0, 3.4, 0),
        folder
    )

    local character = player.Character
    if character then
        State.desyncClientHighlight = Instance.new("Highlight")
        State.desyncClientHighlight.Adornee = character
        State.desyncClientHighlight.FillColor = Color3.fromRGB(80, 180, 255)
        State.desyncClientHighlight.OutlineColor = Color3.fromRGB(150, 220, 255)
        State.desyncClientHighlight.FillTransparency = 0.55
        State.desyncClientHighlight.OutlineTransparency = 0
        State.desyncClientHighlight.Parent = folder

        local adornee = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
        if adornee then
            State.desyncClientBillboard = createDesyncBillboard(
                adornee,
                "CLIENT POSITION",
                Color3.fromRGB(120, 210, 255),
                Vector3.new(0, 2.8, 0),
                folder
            )
        end
    end
end

local function updateDesyncVisuals()
    if not State.desyncEnabled then return end

    if State.desyncServerMarker and State.desyncServerCFrame then
        pcall(function()
            State.desyncServerMarker.CFrame = State.desyncServerCFrame
        end)
    end

    local character = player.Character
    if not character then return end

    if State.desyncClientHighlight and State.desyncClientHighlight.Adornee ~= character then
        State.desyncClientHighlight.Adornee = character
    end

    if State.desyncClientBillboard then
        local adornee = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
        if adornee and State.desyncClientBillboard.Adornee ~= adornee then
            State.desyncClientBillboard.Adornee = adornee
        end
    elseif State.desyncVisualFolder then
        local adornee = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
        if adornee then
            State.desyncClientBillboard = createDesyncBillboard(
                adornee,
                "CLIENT POSITION",
                Color3.fromRGB(120, 210, 255),
                Vector3.new(0, 2.8, 0),
                State.desyncVisualFolder
            )
        end
    end
end

local function processDesyncInteractions(hrp)
    if not hrp or not State.desyncEnabled then return end
    if State.bloodManipEnabled and State.holdingBloodManipKey then return end

    pcall(function()
        if firetouchinterest then
            for _, part in ipairs(Workspace:GetPartsInPart(hrp)) do
                if part ~= hrp and part.CanTouch and not part:IsDescendantOf(player.Character) then
                    firetouchinterest(hrp, part, 0)
                    firetouchinterest(hrp, part, 1)
                end
            end
        end
    end)

    local interactHeld = UserInputService:IsKeyDown(Enum.KeyCode.E)
        or UserInputService:IsKeyDown(Enum.KeyCode.F)

    if not interactHeld then return end

    pcall(function()
        if fireproximityprompt then
            for _, desc in ipairs(Workspace:GetDescendants()) do
                if desc:IsA("ProximityPrompt") and desc.Enabled then
                    local anchor = desc.Parent
                    local anchorPos = nil

                    if anchor:IsA("Attachment") then
                        anchorPos = anchor.WorldPosition
                    elseif anchor:IsA("BasePart") then
                        anchorPos = anchor.Position
                    elseif anchor:IsA("Model") then
                        local primary = anchor.PrimaryPart or anchor:FindFirstChildWhichIsA("BasePart")
                        anchorPos = primary and primary.Position
                    end

                    if anchorPos and (hrp.Position - anchorPos).Magnitude <= desc.MaxActivationDistance + 3 then
                        fireproximityprompt(desc, 1)
                    end
                end
            end
        end
    end)

    pcall(function()
        if not getconnections then return end

        local ray = Ray.new(hrp.Position, hrp.CFrame.LookVector * 12)
        local hit = Workspace:FindPartOnRayWithIgnoreList(ray, {player.Character, State.desyncVisualFolder})
        if not hit then return end

        for _, desc in ipairs(hit:GetDescendants()) do
            if desc:IsA("ClickDetector") then
                for _, conn in ipairs(getconnections(desc.MouseClick)) do
                    conn:Fire()
                end
            end
        end

        local clickDetector = hit:FindFirstChildOfClass("ClickDetector")
        if clickDetector then
            for _, conn in ipairs(getconnections(clickDetector.MouseClick)) do
                conn:Fire()
            end
        end
    end)
end

local function holdDesyncExitPosition(cframe)
    if State.desyncPositionHoldConnection then
        pcall(function()
            State.desyncPositionHoldConnection:Disconnect()
        end)
        State.desyncPositionHoldConnection = nil
    end

    if not cframe then return end

    local holdUntil = tick() + 1.5
    State.desyncPositionHoldConnection = RunService.Heartbeat:Connect(function()
        if State.desyncEnabled or tick() > holdUntil then
            if State.desyncPositionHoldConnection then
                State.desyncPositionHoldConnection:Disconnect()
                State.desyncPositionHoldConnection = nil
            end
            return
        end

        local hrp = getRoot()
        if hrp then
            pcall(function()
                hrp.CFrame = cframe
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end)
end

local function cleanupDesyncConnections()
    for _, connection in pairs(State.desyncConnections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    State.desyncConnections = {}

    if State.desyncRenderBound then
        pcall(function()
            RunService:UnbindFromRenderStep("ScriptHubDesync")
        end)
        State.desyncRenderBound = false
    end

    cleanupDesyncVisuals()
end

local function stopDesyncEngine()
    local keepCFrame = State.desyncClientCFrame
    if not keepCFrame then
        local currentHrp = getRoot()
        if currentHrp then
            keepCFrame = currentHrp.CFrame
        end
    end

    cleanupDesyncConnections()
    State.desyncClientCFrame = nil
    State.desyncServerCFrame = nil

    setNextGenReplicator(false)
    setDesyncFFlags(DESYNC_FFLAGS_OFF)

    pcall(function()
        setfflag("WorldStepMax", "-1")
    end)

    pcall(function()
        settings().Physics.PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.Default
    end)

    local hrp = getRoot()
    if hrp then
        applyDesyncHiddenProps(hrp, false)

        if keepCFrame then
            pcall(function()
                hrp.CFrame = keepCFrame
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.AssemblyAngularVelocity = Vector3.zero
            end)
            holdDesyncExitPosition(keepCFrame)
        end
    end
end

local function startDesyncEngine()
    if State.desyncPositionHoldConnection then
        pcall(function()
            State.desyncPositionHoldConnection:Disconnect()
        end)
        State.desyncPositionHoldConnection = nil
    end

    cleanupDesyncConnections()

    setDesyncFFlags(DESYNC_FFLAGS_ON)
    setNextGenReplicator(true)

    pcall(function()
        setfflag("WorldStepMax", "-99999999999999")
    end)
    task.defer(function()
        pcall(function()
            setfflag("WorldStepMax", "-1")
        end)
    end)

    pcall(function()
        settings().Physics.PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.Disabled
    end)

    local hrp = getRoot()
    if hrp then
        State.desyncServerCFrame = hrp.CFrame
        State.desyncClientCFrame = hrp.CFrame
        applyDesyncHiddenProps(hrp, true)
        bindDesyncTouchInterest(hrp.Parent)
        setupDesyncVisuals(State.desyncServerCFrame)
    end

    table.insert(State.desyncConnections, RunService.Heartbeat:Connect(function()
        if not State.desyncEnabled then return end

        local currentHrp = getRoot()
        if not currentHrp then return end

        State.desyncClientCFrame = currentHrp.CFrame

        applyDesyncHiddenProps(currentHrp, true)
        applyDesyncTouchInterest(currentHrp.Parent)
        updateDesyncVisuals()
        processDesyncInteractions(currentHrp)
    end))
end

local function setDesync(enabled)
    if enabled then
        local ok, err = pcall(function()
            State.desyncEnabled = true
            startDesyncEngine()
        end)
        if not ok then
            warn("[ScriptHub] Desync failed:", err)
            State.desyncEnabled = false
            pcall(stopDesyncEngine)
        end
    else
        State.desyncEnabled = false
        pcall(stopDesyncEngine)
    end
end

local function applyJumpStats(humanoid)
    if not humanoid then return end
    pcall(function()
        humanoid.UseJumpPower = true
        humanoid.JumpPower = State.jumpPower
    end)
    pcall(function()
        humanoid.JumpHeight = State.jumpPower * 0.625
    end)
end

local function getJumpVelocity()
    return math.max(State.jumpPower * 0.85, 50)
end

local function applyWalkSpeedStat(humanoid)
    if not humanoid then return end
    if not State.speedEnabled or State.flightEnabled then
        pcall(function()
            humanoid.WalkSpeed = State.defaultWalkSpeed
        end)
        return
    end
    pcall(function()
        humanoid.WalkSpeed = State.walkSpeed
    end)
end

local function applyMovementStatsNow()
    local humanoid = getHumanoid()
    if not humanoid then return end
    applyWalkSpeedStat(humanoid)
    if State.jumpEnabled then
        applyJumpStats(humanoid)
    end
end

local function applyJumpBoost(hrp)
    if not hrp or not State.jumpEnabled then return end
    pcall(function()
        local vel = hrp.AssemblyLinearVelocity
        hrp.AssemblyLinearVelocity = Vector3.new(vel.X, getJumpVelocity(), vel.Z)
    end)
end

local function bindMovementHumanoid(humanoid)
    if State.hookedHumanoids[humanoid] then return end
    State.hookedHumanoids[humanoid] = true

    humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        if not humanoid.Parent or not State.speedEnabled or State.flightEnabled then return end
        if math.abs(humanoid.WalkSpeed - State.walkSpeed) > 0.01 then
            humanoid.WalkSpeed = State.walkSpeed
        end
    end)

    humanoid:GetPropertyChangedSignal("JumpPower"):Connect(function()
        if not humanoid.Parent or not State.jumpEnabled then return end
        applyJumpStats(humanoid)
    end)

    humanoid:GetPropertyChangedSignal("JumpHeight"):Connect(function()
        if not humanoid.Parent or not State.jumpEnabled then return end
        applyJumpStats(humanoid)
    end)

    humanoid.StateChanged:Connect(function(_, newState)
        if not State.jumpEnabled or newState ~= Enum.HumanoidStateType.Jumping then return end
        local hrp = humanoid.Parent and humanoid.Parent:FindFirstChild("HumanoidRootPart")
        if hrp then
            task.defer(function()
                if State.jumpEnabled and hrp.Parent then
                    applyJumpBoost(hrp)
                end
            end)
        end
    end)

    humanoid.AncestryChanged:Connect(function(_, parent)
        if not parent then
            State.hookedHumanoids[humanoid] = nil
        end
    end)
end

local function updateSpeedHack(humanoid, hrp)
    if not State.speedEnabled or State.flightEnabled then return end

    applyWalkSpeedStat(humanoid)

    local moveDir = humanoid.MoveDirection
    if moveDir.Magnitude > 0.05 then
        pcall(function()
            local vel = hrp.AssemblyLinearVelocity
            local desired = moveDir.Unit * State.walkSpeed
            hrp.AssemblyLinearVelocity = Vector3.new(desired.X, vel.Y, desired.Z)
        end)
    end
end

local function updateJumpHack(humanoid)
    if not State.jumpEnabled then return end
    applyJumpStats(humanoid)
end

local function updateMovementHacks()
    if State.flingInProgress or State.bloodManipExecuting then return end
    local humanoid = getHumanoid()
    local hrp = getRoot()
    if not humanoid or not hrp then return end

    root = hrp
    bindMovementHumanoid(humanoid)

    if State.jumpEnabled then
        updateJumpHack(humanoid)
    end

    if State.speedEnabled and not State.flightEnabled then
        updateSpeedHack(humanoid, hrp)
    end
end

local function removeFlightPhysics(hrp)
    if not hrp then return end
    pcall(function()
        for _, child in pairs(hrp:GetChildren()) do
            if child.Name == "HubFlightBV" or child.Name == "HubFlightBG" then
                child:Destroy()
            end
        end
    end)
end

local function setNoclip(enabled)
    local character = player.Character
    if not character then return end

    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = not enabled
        end
    end
end

local function getOrCreateFlightMovers(hrp, cam)
    local bv = hrp:FindFirstChild("HubFlightBV")
    if not bv or not bv:IsA("BodyVelocity") then
        if bv then bv:Destroy() end
        bv = Instance.new("BodyVelocity")
        bv.Name = "HubFlightBV"
        bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        bv.Velocity = Vector3.zero
        bv.Parent = hrp
    end

    local bg = hrp:FindFirstChild("HubFlightBG")
    if not bg or not bg:IsA("BodyGyro") then
        if bg then bg:Destroy() end
        bg = Instance.new("BodyGyro")
        bg.Name = "HubFlightBG"
        bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
        bg.P = 12000
        bg.D = 800
        bg.Parent = hrp
    end

    -- Update gyro orientation every frame to match camera look direction
    if cam then
        bg.CFrame = cam.CFrame
    end

    return bv, bg
end

local function updateFlight()
    if State.bloodManipExecuting then return end
    if State.flingInProgress then return end
    local humanoid = getHumanoid()
    local hrp = getRoot()
    if not hrp then return end

    root = hrp
    camera = Workspace.CurrentCamera

    if not State.flightEnabled then
        removeFlightPhysics(hrp)
        if humanoid then
            pcall(function()
                humanoid.PlatformStand = false
                humanoid.AutoRotate = true
            end)
            -- Do NOT call applyWalkSpeedStat here ??? this runs 60x/sec and would
            -- lock WalkSpeed to our default every frame, breaking game sprint.
        end
        if not State.noclipEnabled and player.Character then
            setNoclip(false)
        end
        return
    end

    local cam = Workspace.CurrentCamera
    if not cam then return end

    if humanoid then
        bindMovementHumanoid(humanoid)
        pcall(function()
            humanoid.PlatformStand = true
            humanoid.AutoRotate = false
            humanoid:ChangeState(Enum.HumanoidStateType.Physics)
        end)
    end

    setNoclip(true)

    local moveDirection = Vector3.zero
    local lookVector = cam.CFrame.LookVector
    local rightVector = cam.CFrame.RightVector

    -- Keyboard input (desktop / keyboard-equipped mobile executors)
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDirection = moveDirection + lookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDirection = moveDirection - lookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDirection = moveDirection - rightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDirection = moveDirection + rightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDirection = moveDirection + Vector3.yAxis end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
        or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
        moveDirection = moveDirection - Vector3.yAxis
    end
    -- Thumbstick / virtual joystick input (always checked so mobile works even when
    -- TouchEnabled is misreported by the executor)
    if humanoid then
        local md = humanoid.MoveDirection
        if md.Magnitude > 0.05 then
            local flatLook  = Vector3.new(lookVector.X, 0, lookVector.Z)
            local flatRight = Vector3.new(rightVector.X, 0, rightVector.Z)
            if flatLook.Magnitude  > 0.01 then flatLook  = flatLook.Unit  end
            if flatRight.Magnitude > 0.01 then flatRight = flatRight.Unit end
            local joyFwd   = flatLook:Dot(md)
            local joyRight = flatRight:Dot(md)
            moveDirection  = moveDirection
                           + cam.CFrame.LookVector * joyFwd
                           + cam.CFrame.RightVector * joyRight
        end
    end
    -- Mobile flight up/down buttons
    if State.mobileFlightUp   then moveDirection = moveDirection + Vector3.yAxis end
    if State.mobileFlightDown then moveDirection = moveDirection - Vector3.yAxis end

    pcall(function()
        local bv, bg = getOrCreateFlightMovers(hrp, cam)
        if moveDirection.Magnitude > 0 then
            bv.Velocity = moveDirection.Unit * (State.flightSpeed or 80)
        else
            bv.Velocity = Vector3.zero
        end
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
end

local function stopFlight()
    local humanoid = getHumanoid()
    local hrp = getRoot()
    if humanoid then
        pcall(function()
            humanoid.PlatformStand = false
            humanoid.AutoRotate = true
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
    end
    if hrp then
        removeFlightPhysics(hrp)
        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
    end
    if not State.noclipEnabled and player.Character then
        setNoclip(false)
    end
end

local function resetMovementSettings()
    State.walkSpeed = State.defaultWalkSpeed
    State.jumpPower = State.defaultJumpPower
    State.speedEnabled = false
    State.jumpEnabled = false
    State.flightEnabled = false
    State.noclipEnabled = false
    State.infJumpEnabled = false
    State.hookedHumanoids = {}

    if UI.setSpeedSliderValue then UI.setSpeedSliderValue(State.defaultWalkSpeed) end
    if UI.setJumpSliderValue then UI.setJumpSliderValue(State.defaultJumpPower) end
    setHubToggle(UI.SpeedToggle, false)
    setHubToggle(UI.JumpToggle, false)
    setHubToggle(UI.FlightToggle, false)
    setHubToggle(UI.NoclipToggle, false)
    setHubToggle(UI.InfJumpToggle, false)

    stopFlight()
    setNoclip(false)

    local humanoid = getHumanoid()
    if humanoid then
        pcall(function()
            humanoid.WalkSpeed = State.defaultWalkSpeed
            humanoid.JumpPower = State.defaultJumpPower
            humanoid.JumpHeight = 7.2
        end)
    end
end

local function setupCharacterMovement(character)
    character:WaitForChild("HumanoidRootPart", 5)
    local humanoid = character:WaitForChild("Humanoid", 5)
    updateRoot()
    -- Capture the game's actual default speeds before we touch anything.
    -- Hardcoding 16 breaks games that use a different base WalkSpeed.
    if humanoid and not State.capturedDefaultSpeed then
        local spd = humanoid.WalkSpeed
        local jp  = humanoid.JumpPower
        if spd and spd > 0.1 then
            State.defaultWalkSpeed = spd
            if not State.speedEnabled then State.walkSpeed = spd end
            State.capturedDefaultSpeed = true
        end
        if jp and jp > 0.1 then
            State.defaultJumpPower = jp
            if not State.jumpEnabled then State.jumpPower = jp end
        end
    end
    bindMovementHumanoid(humanoid)
    applyMovementStatsNow()
    if State.noclipEnabled then
        setNoclip(true)
    end
    if not State.flightEnabled then
        removeFlightPhysics(character:FindFirstChild("HumanoidRootPart"))
    end
    if State.desyncEnabled then
        startDesyncEngine()
    end
end

NF.F.updateMovementHacks = updateMovementHacks
NF.F.updateFlight = updateFlight
NF.F.setNoclip = setNoclip
NF.F.updateSpeedHack = updateSpeedHack
NF.F.resetMovementSettings = resetMovementSettings
NF.F.stopDesyncEngine = stopDesyncEngine
NF.F.setDesync = setDesync
NF.F.setupCharacterMovement = setupCharacterMovement
NF.F.applyJumpBoost = applyJumpBoost
NF.F.applyJumpStats = applyJumpStats
NF.F.applyMovementStatsNow = applyMovementStatsNow
NF.F.stopFlight = stopFlight
NF.F.removeFlightPhysics = removeFlightPhysics

end -- scope block 1e (desync + movement - Luau local register limit)

do -- scope block 1d (fling/troll - Luau local register limit)

local A = NF.F
local getRoot = A.getRoot
local getHumanoid = A.getHumanoid
local setHubToggle = A.setHubToggle
local setDesync = A.setDesync
local resolveHomelanderTarget = A.resolveHomelanderTarget

local function findHomelanderPlayer()
    if State.homelanderESPEnabled and type(State.scanForHomelander) == "function" then
        State.scanForHomelander()
    end
    local resolved = resolveHomelanderTarget()
    if resolved and resolved.Character and resolved.Character:FindFirstChild("HumanoidRootPart") then
        return resolved
    end
    return nil
end

local function expandFlingSimulation()
    pcall(function()
        setsimulationradius(2e19, 2e19)
        sethiddenproperty(player, "SimulationRadius", 2e19)
        sethiddenproperty(player, "MaxSimulationRadius", 2e19)
    end)
end

local function setCharacterCFrame(character, rootPart, cf)
    if not rootPart or not cf then return end

    pcall(function()
        if character and not character.PrimaryPart then
            character.PrimaryPart = rootPart
        end
        if character then
            character:SetPrimaryPartCFrame(cf)
        else
            rootPart.CFrame = cf
        end
    end)

    pcall(function()
        rootPart.CFrame = cf
    end)
end

local function applySkidFlingVelocity(rootPart)
    if not rootPart then return end

    local vel = Vector3.new(9e7, 9e7 * 10, 9e7)
    local rotVel = Vector3.new(9e8, 9e8, 9e8)

    pcall(function()
        rootPart.Velocity = vel
        rootPart.RotVelocity = rotVel
        rootPart.AssemblyLinearVelocity = vel
        rootPart.AssemblyAngularVelocity = rotVel
    end)
end

local function clearPartVelocities(part)
    if not part or not part:IsA("BasePart") then return end

    pcall(function()
        part.Velocity = Vector3.zero
        part.RotVelocity = Vector3.zero
        part.AssemblyLinearVelocity = Vector3.zero
        part.AssemblyAngularVelocity = Vector3.zero
    end)
end

local function getPartSpeed(part)
    if not part then return 0 end

    local speed = 0
    pcall(function()
        speed = part.AssemblyLinearVelocity.Magnitude
        if part.Velocity.Magnitude > speed then
            speed = part.Velocity.Magnitude
        end
    end)

    return speed
end

local function targetWasFlinged(targetCharacter, targetRoot)
    if not targetCharacter then return false end
    if targetRoot and getPartSpeed(targetRoot) > 500 then
        return true
    end

    local head = targetCharacter:FindFirstChild("Head")
    return head ~= nil and getPartSpeed(head) > 500
end

local function setLocalCharacterCollisions(enabled)
    local character = player.Character
    if not character then return end

    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = enabled
        end
    end
end

local function skidFlingOscillate(rootPart, character, basePart, targetHumanoid, angle)
    local moveDir = targetHumanoid and targetHumanoid.MoveDirection or Vector3.zero
    local targetSpeed = getPartSpeed(basePart)

    local function fpos(pos, ang)
        local cf = CFrame.new(basePart.Position) * pos * ang
        setCharacterCFrame(character, rootPart, cf)
        applySkidFlingVelocity(rootPart)
    end

    fpos(CFrame.new(0, 1.5, 0) + moveDir * targetSpeed / 1.25, CFrame.Angles(math.rad(angle), 0, 0))
    task.wait()
    fpos(CFrame.new(0, -1.5, 0) + moveDir * targetSpeed / 1.25, CFrame.Angles(math.rad(angle), 0, 0))
    task.wait()
    fpos(CFrame.new(2.25, 1.5, -2.25) + moveDir * targetSpeed / 1.25, CFrame.Angles(math.rad(angle), 0, 0))
    task.wait()
    fpos(CFrame.new(-2.25, -1.5, 2.25) + moveDir * targetSpeed / 1.25, CFrame.Angles(math.rad(angle), 0, 0))
    task.wait()
    fpos(CFrame.new(0, 1.5, 0) + moveDir, CFrame.Angles(math.rad(angle), 0, 0))
    task.wait()
    fpos(CFrame.new(0, -1.5, 0) + moveDir, CFrame.Angles(math.rad(angle), 0, 0))
    task.wait()
end

local function skidFlingSpin(rootPart, character, basePart, targetHumanoid, targetRoot)
    local walkSpeed = targetHumanoid and targetHumanoid.WalkSpeed or 16
    local targetSpeed = getPartSpeed(targetRoot or basePart)

    local function fpos(pos, ang)
        local cf = CFrame.new(basePart.Position) * pos * ang
        setCharacterCFrame(character, rootPart, cf)
        applySkidFlingVelocity(rootPart)
    end

    fpos(CFrame.new(0, 1.5, walkSpeed), CFrame.Angles(math.rad(90), 0, 0))
    task.wait()
    fpos(CFrame.new(0, -1.5, -walkSpeed), CFrame.Angles(0, 0, 0))
    task.wait()
    fpos(CFrame.new(0, 1.5, walkSpeed), CFrame.Angles(math.rad(90), 0, 0))
    task.wait()
    fpos(CFrame.new(0, 1.5, targetSpeed / 1.25), CFrame.Angles(math.rad(90), 0, 0))
    task.wait()
    fpos(CFrame.new(0, -1.5, -targetSpeed / 1.25), CFrame.Angles(0, 0, 0))
    task.wait()
    fpos(CFrame.new(0, 1.5, targetSpeed / 1.25), CFrame.Angles(math.rad(90), 0, 0))
    task.wait()
    fpos(CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0))
    task.wait()
    fpos(CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
    task.wait()
    fpos(CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(-90), 0, 0))
    task.wait()
    fpos(CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0))
    task.wait()
end

local function runSkidFlingOnPart(rootPart, character, humanoid, targetPlayer, targetCharacter, targetHumanoid, basePart, timeLimit)
    local angle = 0
    local started = tick()
    local targetRoot = targetHumanoid and targetHumanoid.RootPart

    repeat
        if not rootPart.Parent or not basePart.Parent or humanoid.Health <= 0 then
            break
        end
        if targetHumanoid and targetHumanoid.Sit then
            break
        end

        angle = angle + 100
        if getPartSpeed(basePart) < 50 then
            skidFlingOscillate(rootPart, character, basePart, targetHumanoid, angle)
        else
            skidFlingSpin(rootPart, character, basePart, targetHumanoid, targetRoot)
        end
    until targetWasFlinged(targetCharacter, targetRoot)
        or basePart.Parent ~= targetCharacter
        or targetPlayer.Parent ~= Players
        or targetPlayer.Character ~= targetCharacter
        or (targetHumanoid and targetHumanoid.Sit)
        or humanoid.Health <= 0
        or tick() > started + timeLimit
end

local function skidFlingPlayer(targetPlayer)
    if State.flingInProgress or not targetPlayer or targetPlayer == player then
        return false
    end

    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local rootPart = humanoid and humanoid.RootPart

    local targetCharacter = targetPlayer.Character
    local targetHumanoid = targetCharacter and targetCharacter:FindFirstChildOfClass("Humanoid")
    local targetRoot = targetHumanoid and targetHumanoid.RootPart
    local targetHead = targetCharacter and targetCharacter:FindFirstChild("Head")

    if not character or not humanoid or not rootPart then
        return false
    end
    if not targetCharacter or not targetHumanoid or not targetRoot then
        return false
    end
    if targetHumanoid.Sit then
        warn("[NightFall] Target is sitting.")
        return false
    end
    if not targetCharacter:FindFirstChildWhichIsA("BasePart") then
        return false
    end

    State.flingInProgress = true
    expandFlingSimulation()

    local returnCFrame = rootPart.CFrame
    local savedFPDH = Workspace.FallenPartsDestroyHeight
    local hadNoclip = State.noclipEnabled
    local hadDesync = State.desyncEnabled
    local hadFlight = State.flightEnabled

    if hadDesync then
        setDesync(false)
    end
    if hadFlight then
        State.flightEnabled = false
        NF.F.removeFlightPhysics(rootPart)
    end

    pcall(function()
        if targetHead then
            Workspace.CurrentCamera.CameraSubject = targetHead
        else
            Workspace.CurrentCamera.CameraSubject = targetHumanoid
        end
    end)

    setLocalCharacterCollisions(true)
    pcall(function()
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
        humanoid.PlatformStand = false
    end)
    pcall(function()
        sethiddenproperty(targetRoot, "NetworkOwnershipRule", Enum.NetworkOwnership.Manual)
    end)

    Workspace.FallenPartsDestroyHeight = 0 / 0

    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.Name = "NightFallFlingBV"
    bodyVelocity.Parent = rootPart
    bodyVelocity.Velocity = Vector3.new(9e8, 9e8, 9e8)
    bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)

    local flingPart = targetRoot
    if targetHead and (targetRoot.Position - targetHead.Position).Magnitude > 5 then
        flingPart = targetHead
    end

    local flung = false
    pcall(function()
        runSkidFlingOnPart(
            rootPart,
            character,
            humanoid,
            targetPlayer,
            targetCharacter,
            targetHumanoid,
            flingPart,
            2.5
        )
        flung = targetWasFlinged(targetCharacter, targetRoot)
    end)

    bodyVelocity:Destroy()
    pcall(function()
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
    end)
    pcall(function()
        if Workspace.CurrentCamera then
            Workspace.CurrentCamera.CameraSubject = humanoid
        end
    end)

    local restoreStarted = tick()
    repeat
        setCharacterCFrame(character, rootPart, returnCFrame * CFrame.new(0, 0.5, 0))
        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end)
        for _, part in ipairs(character:GetChildren()) do
            if part:IsA("BasePart") then
                clearPartVelocities(part)
            end
        end
        task.wait()
    until (rootPart.Position - returnCFrame.Position).Magnitude < 25 or tick() > restoreStarted + 3

    Workspace.FallenPartsDestroyHeight = savedFPDH

    if hadNoclip then
        setLocalCharacterCollisions(false)
    end
    if hadFlight then
        State.flightEnabled = true
    end
    if hadDesync then
        setDesync(true)
        setHubToggle(UI.DesyncToggle, true, "ON", "OFF")
    end

    State.flingInProgress = false

    if flung then
        print("[NightFall] Fling connected on " .. targetPlayer.Name)
    else
        warn("[NightFall] Fling missed ??? turn off Noclip/Desync and try again")
    end

    return flung
end

local function flingHomelander()
    local homelander = findHomelanderPlayer()
    if not homelander then
        warn("[NightFall] No killer found! Enable Killer ESP first.")
        return
    end

    skidFlingPlayer(homelander)
end

local function updateSpin(dt)
    if State.bloodManipExecuting then return end
    if not State.spinEnabled then return end
    local hrp = getRoot()
    if hrp then
        pcall(function()
            hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(720 * dt), 0)
        end)
    end
end

local function flingSelf()
    local hrp = getRoot()
    if not hrp then return end
    pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.new(
            math.random(-400, 400),
            math.random(350, 600),
            math.random(-400, 400)
        )
    end)
end

local function tpRandomPlayer()
    local candidates = {}
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(candidates, plr)
        end
    end
    if #candidates == 0 or not root then return end
    local target = candidates[math.random(1, #candidates)]
    pcall(function()
        root.CFrame = target.Character.HumanoidRootPart.CFrame * CFrame.new(0, 3, 3)
    end)
end

local function playAnnoyingSound()
    pcall(function()
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://9120386436"
        sound.Volume = 2
        sound.Parent = Workspace
        sound:Play()
        sound.Ended:Connect(function()
            sound:Destroy()
        end)
        task.delay(5, function()
            if sound.Parent then
                sound:Destroy()
            end
        end)
    end)
end

local function resetTrollEffects()
    State.spinEnabled = false
    setHubToggle(UI.SpinToggle, false)
    setDesync(false)
    setHubToggle(UI.DesyncToggle, false)
end

NF.F.updateSpin = updateSpin
NF.F.flingHomelander = flingHomelander
NF.F.skidFlingPlayer = skidFlingPlayer
NF.F.flingSelf = flingSelf
NF.F.tpRandomPlayer = tpRandomPlayer
NF.F.playAnnoyingSound = playAnnoyingSound
NF.F.resetTrollEffects = resetTrollEffects

end -- scope block 1d (fling/troll - Luau local register limit)

do -- scope block 1d-atrain (A-Train kill - Luau local register limit)

local getRoot = NF.F.getRoot
local isOtherPlayer = NF.F.isOtherPlayer
local isPlayerHomelander = NF.F.isPlayerHomelander
local setHubToggle = NF.F.setHubToggle

local ATRAIN_STAY_TIME = 1.0
local ATRAIN_BEHIND_OFFSET = 6
local ATRAIN_DASH_COOLDOWN = 0.35

local executeATrainKill

local OUR_GUI_NAMES = {
    ScriptHub = true,
    ScriptHubToggle = true,
    ScriptHubMobileAim = true,
    ScriptHubFov = true,
}

local function isOurScriptGui(obj)
    if not obj then return false end
    local gui = obj:IsA("ScreenGui") and obj or obj:FindFirstAncestorOfClass("ScreenGui")
    if not gui then return false end
    return OUR_GUI_NAMES[gui.Name] == true
end

local function getButtonDisplayText(obj)
    if obj:IsA("TextButton") or obj:IsA("TextLabel") then
        return obj.Text or ""
    end
    for _, child in ipairs(obj:GetDescendants()) do
        if child:IsA("TextLabel") and child.Text and child.Text ~= "" then
            return child.Text
        end
    end
    return ""
end

local function looksLikeDashButton(obj)
    if not obj or isOurScriptGui(obj) then return false end
    if not (obj:IsA("TextButton") or obj:IsA("ImageButton")) then return false end
    local text = getButtonDisplayText(obj):upper():gsub("%s+", "")
    local name = obj.Name:upper()
    return text == "DASH" or name:find("DASH", 1, true) ~= nil
end

local function onMobileDashTriggered()
    if not State.aTrainKillEnabled or not State.isMobile then return end
    if tick() - (State.aTrainLastDashTrigger or 0) < ATRAIN_DASH_COOLDOWN then return end
    State.aTrainLastDashTrigger = tick()
    executeATrainKill()
end

local function hookDashButton(btn)
    if not btn or State.aTrainDashHooked[btn] then return end
    State.aTrainDashHooked[btn] = true

    if btn:IsA("GuiButton") then
        btn.Activated:Connect(onMobileDashTriggered)
    end
    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            onMobileDashTriggered()
        end
    end)
end

local function scanForDashButtons(root)
    if not root then return end
    for _, desc in ipairs(root:GetDescendants()) do
        if looksLikeDashButton(desc) then
            hookDashButton(desc)
        end
    end
end

local function startATrainDashHooks()
    if not State.isMobile then return end
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return end

    scanForDashButtons(pg)

    if State.aTrainDashScanConn then return end
    State.aTrainDashScanConn = bindConnection(pg.DescendantAdded:Connect(function(desc)
        if State.aTrainKillEnabled and looksLikeDashButton(desc) then
            hookDashButton(desc)
        end
    end))
end

local function teleportHrpTo(hrp, cf)
    if not hrp or not cf then return end
    pcall(function()
        hrp.CFrame = cf
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hrp.Velocity = Vector3.zero
        hrp.RotVelocity = Vector3.zero
    end)
end

local function isAlivePlayer(plr)
    if not isOtherPlayer(plr) then return false end
    local character = plr.Character
    if not character then return false end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local hum = character:FindFirstChildOfClass("Humanoid")
    return hrp and hum and hum.Health > 0
end

local function isTempVRecentlyTaken(plr)
    local untilTick = State.tempVRecentUntil and State.tempVRecentUntil[plr]
    return untilTick ~= nil and tick() < untilTick
end

local function getBehindTargetCFrame(targetHrp)
    if not targetHrp then return nil end
    return CFrame.new(
        targetHrp.Position - targetHrp.CFrame.LookVector * ATRAIN_BEHIND_OFFSET,
        targetHrp.Position
    )
end

local function collectATrainCandidates()
    local candidates = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if isAlivePlayer(plr)
            and not isPlayerHomelander(plr)
            and not isTempVRecentlyTaken(plr) then
            table.insert(candidates, plr)
        end
    end
    return candidates
end

local function setATrainKill(enabled)
    if enabled and not State.isPremium then
        warn("[NightFall] A-Train Kill requires premium.")
        State.aTrainKillEnabled = false
        if UI.ATrainKillToggle then
            setHubToggle(UI.ATrainKillToggle, false)
        end
        return
    end
    State.aTrainKillEnabled = enabled
    if enabled and State.isMobile then
        startATrainDashHooks()
    end
    if UI.ATrainKillToggle then
        setHubToggle(UI.ATrainKillToggle, enabled)
    end
end

executeATrainKill = function()
    if not State.isPremium or not State.aTrainKillEnabled or State.aTrainKillExecuting then return end

    local candidates = collectATrainCandidates()
    if #candidates == 0 then
        warn("[NightFall] A-Train Kill: no valid targets (alive, not Homelander, not fresh TempV)")
        return
    end

    local targetPlayer = candidates[math.random(1, #candidates)]
    local targetChar = targetPlayer.Character
    local targetHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
    if not targetHrp then return end

    State.aTrainKillExecuting = true

    task.spawn(function()
        local hrp = getRoot()
        if not hrp then
            State.aTrainKillExecuting = false
            return
        end

        local returnCFrame = hrp.CFrame
        local behindCF = getBehindTargetCFrame(targetHrp)
        if not behindCF then
            State.aTrainKillExecuting = false
            return
        end

        pcall(function()
            setsimulationradius(2e19, 2e19)
            sethiddenproperty(player, "SimulationRadius", 2e19)
            sethiddenproperty(player, "MaxSimulationRadius", 2e19)
        end)

        teleportHrpTo(hrp, behindCF)
        task.wait(ATRAIN_STAY_TIME)

        local finalHrp = getRoot()
        if finalHrp then
            teleportHrpTo(finalHrp, returnCFrame)
        end

        State.aTrainKillExecuting = false
        print("[NightFall] A-Train Kill on " .. targetPlayer.Name)
    end)
end

NF.F.setATrainKill = setATrainKill
NF.F.executeATrainKill = executeATrainKill
NF.F.startATrainDashHooks = startATrainDashHooks

end -- scope block 1d-atrain (A-Train kill - Luau local register limit)

do -- scope block 1d-autowin (Homelander Autowin - Luau local register limit)

local getRoot = NF.F.getRoot
local isOtherPlayer = NF.F.isOtherPlayer
local isPlayerHomelander = NF.F.isPlayerHomelander
local setHubToggle = NF.F.setHubToggle

local AUTOWIN_BEHIND_OFFSET = 2.5
local AUTOWIN_E_INTERVAL = 0.5
local AUTOWIN_MAX_TARGET_SEC = 50
local AUTOWIN_BETWEEN_TARGETS = 0.4

local VirtualInputManager = game:GetService("VirtualInputManager")

local function teleportHrpTo(hrp, cf)
    if not hrp or not cf then return end
    pcall(function()
        hrp.CFrame = cf
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hrp.Velocity = Vector3.zero
        hrp.RotVelocity = Vector3.zero
    end)
end

local function getBehindTargetCFrame(targetHrp)
    if not targetHrp then return nil end
    return CFrame.new(
        targetHrp.Position - targetHrp.CFrame.LookVector * AUTOWIN_BEHIND_OFFSET,
        targetHrp.Position
    )
end

local function isAlivePlayer(plr)
    if not isOtherPlayer(plr) then return false end
    local character = plr.Character
    if not character then return false end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local hum = character:FindFirstChildOfClass("Humanoid")
    return hrp and hum and hum.Health > 0
end

local function isTempVRecentlyTaken(plr)
    local untilTick = State.tempVRecentUntil and State.tempVRecentUntil[plr]
    return untilTick ~= nil and tick() < untilTick
end

local function collectAutowinCandidates()
    local candidates = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if isAlivePlayer(plr)
            and not isPlayerHomelander(plr)
            and not isTempVRecentlyTaken(plr) then
            table.insert(candidates, plr)
        end
    end
    table.sort(candidates, function(a, b)
        return a.Name:lower() < b.Name:lower()
    end)
    return candidates
end

local function simulateKeyE(down)
    pcall(function()
        if VirtualInputManager and VirtualInputManager.SendKeyEvent then
            VirtualInputManager:SendKeyEvent(down, Enum.KeyCode.E, false, game)
        end
    end)
end

local function simulateKeyEClick()
    simulateKeyE(true)
    task.defer(function()
        simulateKeyE(false)
    end)
end

local function tryChokeInteract(myHrp, targetChar)
    if not myHrp or not targetChar then return end

    pcall(function()
        if fireproximityprompt then
            local function firePrompt(desc)
                if desc:IsA("ProximityPrompt") and desc.Enabled then
                    pcall(function() fireproximityprompt(desc, 0) end)
                    pcall(function() fireproximityprompt(desc, 1) end)
                end
            end
            for _, desc in ipairs(targetChar:GetDescendants()) do
                firePrompt(desc)
            end
            if player.Character then
                for _, desc in ipairs(player.Character:GetDescendants()) do
                    firePrompt(desc)
                end
            end
            local ray = Ray.new(myHrp.Position, myHrp.CFrame.LookVector * 10)
            local ignore = { player.Character }
            if State.desyncVisualFolder then
                table.insert(ignore, State.desyncVisualFolder)
            end
            local hit = Workspace:FindPartOnRayWithIgnoreList(ray, ignore)
            if hit then
                for _, desc in ipairs(hit:GetDescendants()) do
                    firePrompt(desc)
                end
                local prompt = hit:FindFirstChildOfClass("ProximityPrompt")
                if prompt then
                    firePrompt(prompt)
                end
            end
        end
    end)

    pcall(function()
        if firetouchinterest then
            local part = targetChar:FindFirstChild("Head") or targetChar:FindFirstChild("HumanoidRootPart")
            if part then
                firetouchinterest(myHrp, part, 0)
                firetouchinterest(myHrp, part, 1)
            end
        end
    end)

    pcall(function()
        if not getconnections then return end
        for _, part in ipairs(targetChar:GetDescendants()) do
            if part:IsA("BasePart") then
                local cd = part:FindFirstChildOfClass("ClickDetector")
                if cd then
                    for _, conn in ipairs(getconnections(cd.MouseClick)) do
                        conn:Fire()
                    end
                end
            end
        end
    end)
end

local function stopAutowinHoldStep()
    pcall(function()
        RunService:UnbindFromRenderStep("NightFallAutowinHold")
    end)
    State.homelanderAutowinHoldActive = false
    simulateKeyE(false)
end

local function waitForPlayerDeath(plr, timeoutSec)
    local deadline = tick() + timeoutSec
    while tick() < deadline and State.homelanderAutowinEnabled do
        if not plr.Parent then
            return true
        end
        local char = plr.Character
        if not char then
            return true
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then
            return true
        end
        task.wait(0.08)
    end
    return false
end

local function chokeKillPlayer(targetPlayer)
    if not State.homelanderAutowinEnabled then
        return false
    end

    local myHrp = getRoot()
    local targetChar = targetPlayer.Character
    local targetHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
    if not myHrp or not targetHrp then
        return false
    end

    pcall(function()
        setsimulationradius(2e19, 2e19)
        sethiddenproperty(player, "SimulationRadius", 2e19)
        sethiddenproperty(player, "MaxSimulationRadius", 2e19)
    end)

    State.homelanderAutowinTarget = targetPlayer
    State.homelanderAutowinLastE = 0

    pcall(function()
        RunService:BindToRenderStep("NightFallAutowinHold", Enum.RenderPriority.First.Value + 3, function()
            if not State.homelanderAutowinEnabled
                or State.homelanderAutowinTarget ~= targetPlayer then
                stopAutowinHoldStep()
                return
            end

            local hrp = getRoot()
            local char = targetPlayer.Character
            local thrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp or not thrp then
                return
            end

            local behind = getBehindTargetCFrame(thrp)
            if behind then
                teleportHrpTo(hrp, behind)
            end

            local now = tick()
            if now - (State.homelanderAutowinLastE or 0) >= AUTOWIN_E_INTERVAL then
                State.homelanderAutowinLastE = now
                simulateKeyEClick()
                tryChokeInteract(hrp, char)
            end
        end)
    end)
    State.homelanderAutowinHoldActive = true

    local died = waitForPlayerDeath(targetPlayer, AUTOWIN_MAX_TARGET_SEC)

    stopAutowinHoldStep()
    State.homelanderAutowinTarget = nil

    if died then
        print("[NightFall] Autowin killed " .. targetPlayer.Name)
    else
        warn("[NightFall] Autowin timed out on " .. targetPlayer.Name)
    end

    return died
end

local function homelanderAutowinLoop()
    if State.homelanderAutowinRunning then
        return
    end
    State.homelanderAutowinRunning = true

    task.spawn(function()
        while State.homelanderAutowinEnabled and State.isPremium do
            local hrp = getRoot()
            if not hrp then
                task.wait(0.5)
            else
                local candidates = collectAutowinCandidates()
                if #candidates == 0 then
                    task.wait(1)
                else
                    for _, target in ipairs(candidates) do
                        if not State.homelanderAutowinEnabled then
                            break
                        end
                        if isAlivePlayer(target) then
                            chokeKillPlayer(target)
                            task.wait(AUTOWIN_BETWEEN_TARGETS)
                        end
                    end
                end
            end
            task.wait(0.15)
        end

        stopAutowinHoldStep()
        State.homelanderAutowinTarget = nil
        State.homelanderAutowinRunning = false
    end)
end

local function setHomelanderAutowin(enabled)
    if enabled and not State.isPremium then
        warn("[NightFall] Homelander Autowin requires premium.")
        State.homelanderAutowinEnabled = false
        if UI.HomelanderAutowinToggle then
            setHubToggle(UI.HomelanderAutowinToggle, false)
        end
        return
    end

    if enabled and not isPlayerHomelander(player) then
        warn("[NightFall] Autowin: you need the Homelander role to choke players.")
    end

    State.homelanderAutowinEnabled = enabled
    if UI.HomelanderAutowinToggle then
        setHubToggle(UI.HomelanderAutowinToggle, enabled)
    end

    if enabled then
        homelanderAutowinLoop()
    else
        stopAutowinHoldStep()
        State.homelanderAutowinTarget = nil
        State.homelanderAutowinRunning = false
    end
end

NF.F.setHomelanderAutowin = setHomelanderAutowin

end -- scope block 1d-autowin (Homelander Autowin - Luau local register limit)

do -- scope block 1c (spectate - Luau local register limit)

local function clearSpectateConnections()
    for _, conn in ipairs(State.spectateConnections) do
        pcall(function()
            conn:Disconnect()
        end)
    end
    State.spectateConnections = {}
end

local function getSpectateFocusParts(targetPlayer)
    local character = targetPlayer and targetPlayer.Character
    if not character then return nil, nil end

    local hrp = character:FindFirstChild("HumanoidRootPart")
    local head = character:FindFirstChild("Head")
    return hrp or head, head or hrp
end

local function updateSpectateCamera()
    if not State.spectating or not State.spectateTarget or State.freecamEnabled then return end

    local focusPart, lookPart = getSpectateFocusParts(State.spectateTarget)
    if not focusPart or not lookPart then return end

    local cam = Workspace.CurrentCamera
    if not cam then return end

    -- Re-assert scriptable type every frame so the game can never steal it back
    if cam.CameraType ~= Enum.CameraType.Scriptable then
        pcall(function() cam.CameraType = Enum.CameraType.Scriptable end)
    end

    local lookAt = lookPart.Position + Vector3.new(0, 1.5, 0)
    local yaw = math.rad(State.spectateYaw or 0)
    local pitch = math.rad(math.clamp(State.spectatePitch or 20, -80, 80))
    local dist = math.clamp(State.spectateFollowDistance or 18, 4, 500)
    local offset = Vector3.new(
        math.sin(yaw) * math.cos(pitch) * dist,
        math.sin(pitch) * dist + 4,
        math.cos(yaw) * math.cos(pitch) * dist
    )

    pcall(function()
        cam.CFrame = CFrame.new(lookAt + offset, lookAt)
    end)
end

local function restoreSpectateCamera()
    local cam = Workspace.CurrentCamera
    if not cam then return end

    pcall(function()
        if State.spectateSavedCameraType then
            cam.CameraType = State.spectateSavedCameraType
        else
            cam.CameraType = Enum.CameraType.Custom
        end

        if State.spectateSavedCameraSubject then
            cam.CameraSubject = State.spectateSavedCameraSubject
        else
            local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                cam.CameraSubject = humanoid
            end
        end

        player.CameraMaxZoomDistance = State.spectateSavedMaxZoom or 128
        player.CameraMinZoomDistance = State.spectateSavedMinZoom or 0.5
    end)

    State.spectateSavedCameraType = nil
    State.spectateSavedCameraSubject = nil
    State.spectateSavedMaxZoom = nil
    State.spectateSavedMinZoom = nil
end

local function applySpectateCamera(targetPlayer)
    if not targetPlayer then return false end

    local focusPart = getSpectateFocusParts(targetPlayer)
    if not focusPart then return false end

    local cam = Workspace.CurrentCamera
    if not cam then return false end

    if State.spectateSavedCameraType == nil then
        State.spectateSavedCameraType = cam.CameraType
        State.spectateSavedCameraSubject = cam.CameraSubject
        State.spectateSavedMaxZoom = player.CameraMaxZoomDistance
        State.spectateSavedMinZoom = player.CameraMinZoomDistance
    end

    pcall(function()
        player.CameraMaxZoomDistance = math.huge
        player.CameraMinZoomDistance = 0.5
        cam.CameraType = Enum.CameraType.Scriptable
    end)

    updateSpectateCamera()
    return true
end

local function stopSpectate()
    clearSpectateConnections()
    State.spectating = false
    State.spectateTarget = nil
    State.spectateOrbiting = false
    pcall(function()
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end)
    restoreSpectateCamera()

    if UI.SpectateSelectedLabel then
        if State.spectateSelected then
            UI.SpectateSelectedLabel.Text = "Selected: " .. State.spectateSelected.DisplayName
            UI.SpectateSelectedLabel.TextColor3 = COLORS.text
        else
            UI.SpectateSelectedLabel.Text = "Selected: None"
            UI.SpectateSelectedLabel.TextColor3 = COLORS.textMuted
        end
    end
end

local function startSpectate(targetPlayer)
    if not targetPlayer or targetPlayer == player then
        warn("[NightFall] Pick another player to spectate.")
        return
    end

    clearSpectateConnections()
    restoreSpectateCamera()

    State.spectateSelected = targetPlayer
    State.spectateTarget = targetPlayer
    State.spectateYaw = 0
    State.spectatePitch = 20
    State.spectating = applySpectateCamera(targetPlayer)

    if not State.spectating then
        warn("[NightFall] Target has no character to spectate.")
        State.spectateTarget = nil
        return
    end

    table.insert(State.spectateConnections, targetPlayer.CharacterAdded:Connect(function()
        if State.spectating and State.spectateTarget == targetPlayer then
            task.wait(0.5)
            -- Re-apply scriptable camera after the game resets it on respawn
            applySpectateCamera(targetPlayer)
        end
    end))

    table.insert(State.spectateConnections, targetPlayer.AncestryChanged:Connect(function(_, parent)
        if not parent and State.spectateTarget == targetPlayer then
            stopSpectate()
        end
    end))

    if UI.SpectateSelectedLabel then
        UI.SpectateSelectedLabel.Text = "Spectating: " .. targetPlayer.DisplayName
        UI.SpectateSelectedLabel.TextColor3 = COLORS.accentOn
    end
end

local function refreshMiscPlayerList()
    if not UI.SpectatePlayerList then return end

    for _, child in ipairs(UI.SpectatePlayerList:GetChildren()) do
        if not child:IsA("UIListLayout") then
            child:Destroy()
        end
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 0, 36)
            btn.BackgroundColor3 = State.spectateSelected == plr and COLORS.tabActiveBg or COLORS.elevated
            btn.Text = plr.DisplayName .. "  " .. CONST.ICON.dot .. "  @" .. plr.Name
            btn.TextColor3 = State.spectateSelected == plr and COLORS.accentLight or COLORS.text
            btn.Font = Enum.Font.GothamSemibold
            btn.TextSize = 12
            btn.AutoButtonColor = false
            btn.Parent = UI.SpectatePlayerList
            applyCorner(btn, CONST.RADIUS.sm)

            if State.spectateSelected == plr then
                applyStroke(btn, COLORS.accent, 1, 0.35)
            end

            btn.MouseEnter:Connect(function()
                if State.spectateSelected ~= plr then
                    tween(btn, { BackgroundColor3 = COLORS.surfaceHover })
                end
            end)
            btn.MouseLeave:Connect(function()
                if State.spectateSelected ~= plr then
                    tween(btn, { BackgroundColor3 = COLORS.elevated })
                end
            end)

            NF.F.bindHubClick(btn, function()
                State.spectateSelected = plr
                if UI.SpectateSelectedLabel then
                    UI.SpectateSelectedLabel.Text = "Selected: " .. plr.DisplayName
                    UI.SpectateSelectedLabel.TextColor3 = COLORS.text
                end
                refreshMiscPlayerList()
            end)
        end
    end
end

NF.F.stopSpectate = stopSpectate
NF.F.startSpectate = startSpectate
NF.F.refreshMiscPlayerList = refreshMiscPlayerList
NF.F.updateSpectateCamera = updateSpectateCamera

end -- scope block 1c (spectate - Luau local register limit)

do -- scope block 1f (tempv - Luau local register limit)

local Scroll = UI.ScannerScroll
local UIList = UI.ScannerUIList

local function createTempVESP(model)
    if State.tempVBillboards[model] then return end
    if not State.tempVHighlightEnabled then return end  -- Only create if enabled
    
    local primary = model:FindFirstChildWhichIsA("BasePart")
    if not primary then return end

    pcall(function()
        local bb = Instance.new("BillboardGui")
        bb.Adornee = primary
        bb.Size = UDim2.new(0, 220, 0, 70)
        bb.StudsOffset = Vector3.new(0, 3.5, 0)
        bb.AlwaysOnTop = true
        bb.Parent = CoreGui

        local txt = Instance.new("TextLabel")
        txt.Size = UDim2.new(1, 0, 1, 0)
        txt.BackgroundTransparency = 1
        txt.TextColor3 = Color3.fromRGB(0, 255, 255)
        txt.TextStrokeTransparency = 0
        txt.TextStrokeColor3 = Color3.new(0, 0, 0)
        txt.Font = Enum.Font.SourceSansBold
        txt.TextSize = 16
        txt.Text = CONST.ICON.tempv .. " TempV\n[Calculating...]"
        txt.Parent = bb

        State.tempVBillboards[model] = {gui = bb, label = txt}
    end)
end

local function updateTempVESP()
    if not State.tempVHighlightEnabled then return end  -- Don't update if disabled
    
    for model, data in pairs(State.tempVBillboards) do
        if not model.Parent or not isWorldTempV(model) then
            pcall(function() data.gui:Destroy() end)
            State.tempVBillboards[model] = nil
            if State.trackedTempVModels[model] then
                State.trackedTempVModels[model] = nil
                requestTempVRescan()
            end
        elseif root then
            pcall(function()
                local primary = model:FindFirstChildWhichIsA("BasePart")
                if primary then
                    local dist = (root.Position - primary.Position).Magnitude
                    data.label.Text = CONST.ICON.tempv .. " TempV\n" .. CONST.ICON.dot .. " " .. math.floor(dist) .. " studs"
                end
            end)
        end
    end
end

local function highlightTempV(model)
    if not State.tempVHighlightEnabled then return end
    
    pcall(function()
        for _, part in pairs(model:GetDescendants()) do
            if part:IsA("BasePart") and not State.tempVHighlights[part] then
                local hl = Instance.new("Highlight")
                hl.Adornee = part
                hl.FillColor = Color3.fromRGB(0, 255, 255)
                hl.OutlineColor = Color3.fromRGB(255, 255, 0)
                hl.FillTransparency = 0.5
                hl.OutlineTransparency = 0
                hl.Parent = part
                State.tempVHighlights[part] = hl
            end
        end
    end)
end

local function clearTempVModelVisuals(model)
    for part, hl in pairs(State.tempVHighlights) do
        if not part.Parent or part:IsDescendantOf(model) then
            pcall(function() hl:Destroy() end)
            State.tempVHighlights[part] = nil
        end
    end

    if State.tempVBillboards[model] then
        pcall(function() State.tempVBillboards[model].gui:Destroy() end)
        State.tempVBillboards[model] = nil
    end
end

local function isWorldTempV(model)
    if not model or not model:IsA("Model") then
        return false
    end
    if model.Name:lower() ~= "tempv" then
        return false
    end
    if not model:IsDescendantOf(Workspace) then
        return false
    end
    for _, plr in pairs(Players:GetPlayers()) do
        if plr.Character and model:IsDescendantOf(plr.Character) then
            return false
        end
        if plr:FindFirstChild("Backpack") and model:IsDescendantOf(plr.Backpack) then
            return false
        end
    end
    return model:FindFirstChildWhichIsA("BasePart") ~= nil
end

State.lastTempVScanTime = 0
State.lastHomelanderScanTime = 0
State.lastPlayerESPScanTime = 0
State.espRescanInterval = 3
State.tempVRescanPending = false

local function requestTempVRescan()
    if not State.autoRefreshEnabled or State.tempVRescanPending then
        return
    end
    State.tempVRescanPending = true
    task.defer(function()
        State.tempVRescanPending = false
        if State.autoRefreshEnabled and State.scanTempVParts then
            State.scanTempVParts()
        end
    end)
end

local function markTempVPickupUser(model)
    if not model then return end
    local primary = model.PrimaryPart
        or model:FindFirstChild("Handle")
        or model:FindFirstChildWhichIsA("BasePart")
    if not primary then return end

    local pos = primary.Position
    local nearest, bestDist = nil, 20
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local dist = (plr.Character.HumanoidRootPart.Position - pos).Magnitude
            if dist < bestDist then
                bestDist = dist
                nearest = plr
            end
        end
    end

    if nearest then
        State.tempVRecentUntil[nearest] = tick() + 1
    end
end

local function onTempVPickedUp(model)
    if not State.trackedTempVModels[model] then return end
    markTempVPickupUser(model)
    State.trackedTempVModels[model] = nil
    clearTempVModelVisuals(model)
    requestTempVRescan()
end

local function trackTempVModel(model)
    if State.trackedTempVModels[model] then return end
    State.trackedTempVModels[model] = true

    model.AncestryChanged:Connect(function()
        if not isWorldTempV(model) then
            onTempVPickedUp(model)
        end
    end)
end

local function pruneStaleTempVVisuals()
    for model, data in pairs(State.tempVBillboards) do
        if not model.Parent then
            pcall(function() data.gui:Destroy() end)
            State.tempVBillboards[model] = nil
            State.trackedTempVModels[model] = nil
        end
    end

    for part, hl in pairs(State.tempVHighlights) do
        if not part.Parent then
            pcall(function() hl:Destroy() end)
            State.tempVHighlights[part] = nil
        end
    end
end

local function clearAllTempVHighlights()
    for part, hl in pairs(State.tempVHighlights) do
        pcall(function() hl:Destroy() end)
    end
    State.tempVHighlights = {}
end

local function clearAllTempVBillboards()
    for model, data in pairs(State.tempVBillboards) do
        pcall(function() data.gui:Destroy() end)
    end
    State.tempVBillboards = {}
    State.trackedTempVModels = {}
end

State.scanTempVParts = function()
    pruneStaleTempVVisuals()

    for _, child in pairs(Scroll:GetChildren()) do
        if child:IsA("TextButton") then 
            child:Destroy() 
        end
    end

    local found = 0
    local seenModels = {}
    
    pcall(function()
        for _, obj in pairs(Workspace:GetDescendants()) do
            if isWorldTempV(obj) then
                seenModels[obj] = true
                local primary = obj:FindFirstChildWhichIsA("BasePart")
                if primary then
                    local btn = Instance.new("TextButton")
                    btn.Size = UDim2.new(1, -4, 0, 54)
                    btn.BackgroundColor3 = COLORS.elevated
                    btn.BorderSizePixel = 0
                    btn.Font = Enum.Font.GothamSemibold
                    btn.TextSize = 12
                    btn.TextColor3 = COLORS.text
                    btn.TextXAlignment = Enum.TextXAlignment.Left
                    btn.Parent = Scroll
                    applyCorner(btn, CONST.RADIUS.md)
                    applyStroke(btn, COLORS.border, 1, 0.7)

                    local pos = primary.Position
                    local dist = root and math.floor((root.Position - pos).Magnitude) or "?"
                    
                    btn.Text = string.format("  TempV #%d\n  [%d, %d, %d]  %s  %s studs",
                        found + 1,
                        math.floor(pos.X),
                        math.floor(pos.Y),
                        math.floor(pos.Z),
                        CONST.ICON.dot,
                        tostring(dist)
                    )

                    NF.F.bindHubClick(btn, function()
                        if root and primary and primary.Parent then
                            pcall(function()
                                root.CFrame = primary.CFrame * CFrame.new(0, 8, 0)
                            end)
                        end
                    end)

                    btn.MouseEnter:Connect(function()
                        tween(btn, { BackgroundColor3 = COLORS.surfaceHover })
                    end)
                    btn.MouseLeave:Connect(function()
                        tween(btn, { BackgroundColor3 = COLORS.elevated })
                    end)

                    trackTempVModel(obj)
                    highlightTempV(obj)
                    createTempVESP(obj)
                    found = found + 1
                end
            end
        end
    end)

    for model in pairs(State.trackedTempVModels) do
        if not seenModels[model] then
            State.trackedTempVModels[model] = nil
            clearTempVModelVisuals(model)
        end
    end

    UI.StatusTempV.StateLabel.Text = tostring(found)
    Scroll.CanvasSize = UDim2.new(0, 0, 0, UIList.AbsoluteContentSize.Y + 16)
    
    return found
end

NF.F.updateTempVESP = updateTempVESP
NF.F.clearAllTempVHighlights = clearAllTempVHighlights
NF.F.clearAllTempVBillboards = clearAllTempVBillboards
NF.F.onTempVPickedUp = onTempVPickedUp

end -- scope block 1f (tempv - Luau local register limit)


do -- scope block 2a (failsafe + freecam - Luau local register limit)
local clearHighlight = F.clearHighlight
local createPlayerESP = F.createPlayerESP
local updateTempVESP = F.updateTempVESP
local updateMovementHacks = F.updateMovementHacks
local updateFlight = F.updateFlight
local updateSpin = F.updateSpin
local setNoclip = F.setNoclip
local getHumanoid = F.getHumanoid
local getRoot = F.getRoot

local function teleportToSafeZone()
    local hrp = getRoot()
    if not hrp then return end
    pcall(function()
        hrp.CFrame = CONST.SAFE_ZONE_CFRAME
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end)
end

local function updateFailsafe()
    if not State.failsafeEnabled then return end
    local hum = getHumanoid()
    if not hum or hum.MaxHealth <= 0 then return end

    local pct = (hum.Health / hum.MaxHealth) * 100
    if pct < State.failsafeThreshold then
        if not State.failsafeTripped then
            State.failsafeTripped = true
            local hrp = getRoot()
            if hrp then
                State.failsafeReturnCFrame = hrp.CFrame
            end
            teleportToSafeZone()
        end
    elseif pct >= State.failsafeThreshold and State.failsafeTripped then
        State.failsafeTripped = false
        local returnCf = State.failsafeReturnCFrame
        State.failsafeReturnCFrame = nil
        if returnCf then
            local hrp = getRoot()
            if hrp then
                pcall(function()
                    hrp.CFrame = returnCf
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                end)
            end
        end
    end
end

local updateSpeedHack = F.updateSpeedHack
local isPlayerHomelander = F.isPlayerHomelander
local setHubToggle = F.setHubToggle
local resetMovementSettings = F.resetMovementSettings
local resetTrollEffects = F.resetTrollEffects
local stopDesyncEngine = F.stopDesyncEngine
local stopSpectate = F.stopSpectate
local startSpectate = F.startSpectate
local refreshMiscPlayerList = F.refreshMiscPlayerList
local setDesync = F.setDesync
local flingHomelander = F.flingHomelander
local skidFlingPlayer = F.skidFlingPlayer
local flingSelf = F.flingSelf
local setupCharacterMovement = F.setupCharacterMovement
local applyJumpBoost = F.applyJumpBoost
local applyJumpStats = F.applyJumpStats
local tpRandomPlayer = F.tpRandomPlayer
local playAnnoyingSound = F.playAnnoyingSound
local clearAllTempVHighlights = F.clearAllTempVHighlights
local clearAllTempVBillboards = F.clearAllTempVBillboards
local applyMovementStatsNow = F.applyMovementStatsNow
local stopFlight = F.stopFlight
local onTempVPickedUp = F.onTempVPickedUp
local updateSpectateCamera = F.updateSpectateCamera

local function isCameraDragInput(input)
    return input.UserInputType == Enum.UserInputType.MouseButton2
end

local function beginCameraDrag(input)
    if not isCameraDragInput(input) then
        return false
    end

    if State.freecamEnabled then
        State.freecamLooking = true
        pcall(function()
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
            UserInputService.MouseIconEnabled = false
        end)
        return true
    end

    if State.spectating then
        State.spectateOrbiting = true
        pcall(function()
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
        end)
        return true
    end

    return false
end

local function endCameraDrag(input)
    if not isCameraDragInput(input) then
        return false
    end

    local handled = false
    if State.freecamLooking then
        State.freecamLooking = false
        handled = true
    end
    if State.spectateOrbiting then
        State.spectateOrbiting = false
        handled = true
    end

    if handled then
        pcall(function()
            UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            UserInputService.MouseIconEnabled = true
        end)
        return true
    end

    return false
end

local function applyCameraDragDelta(delta)
    if delta.Magnitude <= 0 then return end

    if State.freecamEnabled and State.freecamLooking then
        local sensitivity = 0.003
        State.freecamYaw = (State.freecamYaw or 0) - delta.X * sensitivity
        State.freecamPitch = math.clamp(
            (State.freecamPitch or 0) - delta.Y * sensitivity,
            -1.4,
            1.4
        )
    elseif State.spectating and State.spectateOrbiting then
        State.spectateYaw = (State.spectateYaw or 0) - delta.X * 0.35
        State.spectatePitch = math.clamp(
            (State.spectatePitch or 20) - delta.Y * 0.35,
            -80,
            80
        )
    end
end

local function saveCameraState()
    local cam = Workspace.CurrentCamera
    if not cam or State.cameraSavedType then return end

    State.cameraSavedType = cam.CameraType
    State.cameraSavedSubject = cam.CameraSubject
    State.cameraSavedMaxZoom = player.CameraMaxZoomDistance
    State.cameraSavedMinZoom = player.CameraMinZoomDistance
end

local function restoreCameraState()
    local cam = Workspace.CurrentCamera
    if not cam then return end

    pcall(function()
        cam.CameraType = State.cameraSavedType or Enum.CameraType.Custom
        if State.cameraSavedSubject then
            cam.CameraSubject = State.cameraSavedSubject
        else
            local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                cam.CameraSubject = humanoid
            end
        end
        player.CameraMaxZoomDistance = State.cameraSavedMaxZoom or 128
        player.CameraMinZoomDistance = State.cameraSavedMinZoom or 0.5
    end)

    State.cameraSavedType = nil
    State.cameraSavedSubject = nil
    State.cameraSavedMaxZoom = nil
    State.cameraSavedMinZoom = nil
end

local function stopFreecam()
    if not State.freecamEnabled then return end

    State.freecamEnabled = false
    State.freecamLooking = false
    State.freecamCFrame = nil
    pcall(function()
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
    end)
    restoreCameraState()
    setHubToggle(UI.FreecamToggle, false)
end

local function startFreecam()
    if State.freecamEnabled then return end

    stopSpectate()
    saveCameraState()

    local cam = Workspace.CurrentCamera
    if cam then
        local _, yaw, pitch = cam.CFrame:ToEulerAnglesYXZ()
        State.freecamYaw = yaw
        State.freecamPitch = pitch
        State.freecamCFrame = cam.CFrame
        cam.CameraType = Enum.CameraType.Scriptable
        pcall(function()
            player.CameraMaxZoomDistance = math.huge
            player.CameraMinZoomDistance = 0.5
        end)
    end

    State.freecamEnabled = true
    setHubToggle(UI.FreecamToggle, true)
end

local function setFreecam(enabled)
    if enabled then
        startFreecam()
    else
        stopFreecam()
    end
end

local function updateFreecam(dt)
    if not State.freecamEnabled then return end

    local cam = Workspace.CurrentCamera
    if not cam then return end

    if cam.CameraType ~= Enum.CameraType.Scriptable then
        cam.CameraType = Enum.CameraType.Scriptable
    end

    local pos = State.freecamCFrame and State.freecamCFrame.Position or cam.CFrame.Position
    local yaw = State.freecamYaw or 0
    local pitch = State.freecamPitch or 0
    local rot = CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)
    local cf = CFrame.new(pos) * rot

    local move = Vector3.zero
    local speed = State.freecamSpeed or 80

    -- Keyboard input (works on desktop and keyboard-equipped executors)
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + cf.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - cf.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - cf.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + cf.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.yAxis end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
        or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
        move = move - Vector3.yAxis
    end
    -- Thumbstick / virtual joystick input (always checked so mobile works regardless of
    -- isMobile detection)
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        local md = humanoid.MoveDirection
        if md.Magnitude > 0.05 then
            local flatLook  = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
            local flatRight = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
            if flatLook.Magnitude  > 0.01 then flatLook  = flatLook.Unit  end
            if flatRight.Magnitude > 0.01 then flatRight = flatRight.Unit end
            local joyFwd   = flatLook:Dot(md)
            local joyRight = flatRight:Dot(md)
            move = move + cf.LookVector * joyFwd + cf.RightVector * joyRight
        end
    end

    if move.Magnitude > 0 then
        cf = cf + move.Unit * speed * dt
    end

    State.freecamCFrame = cf
    State.freecamYaw = yaw
    State.freecamPitch = pitch
    cam.CFrame = cf
end

NF.F.beginCameraDrag = beginCameraDrag
NF.F.endCameraDrag = endCameraDrag
NF.F.applyCameraDragDelta = applyCameraDragDelta
NF.F.updateFreecam = updateFreecam
NF.F.stopFreecam = stopFreecam
NF.F.setFreecam = setFreecam
NF.F.updateFailsafe = updateFailsafe
NF.F.teleportToSafeZone = teleportToSafeZone

end -- scope block 2a (failsafe + freecam - Luau local register limit)

do -- scope block 2b (blood manip - Luau local register limit)


local Lighting = game:GetService("Lighting")

local BLOOD_EFFECT_NAME_HINTS = {
    "blood", "manip", "manipulator", "choke", "grip", "victim",
    "controlled", "hemorrhage", "crush", "suffocat", "strangle",
}

local function isHubOwnedGui(obj)
    if not obj then return false end
    if obj:GetAttribute("ScriptHubESP") then return true end
    local gui = obj:IsA("ScreenGui") and obj or obj:FindFirstAncestorOfClass("ScreenGui")
    if not gui then return false end
    return gui.Name == "ScriptHub"
        or gui.Name == "ScriptHubToggle"
        or gui.Name == "ScriptHubMobileAim"
end

local function nameLooksLikeBloodEffect(name)
    if not name or name == "" then return false end
    local lower = name:lower()
    for _, hint in ipairs(BLOOD_EFFECT_NAME_HINTS) do
        if lower:find(hint, 1, true) then
            return true
        end
    end
    return false
end

local function isRedManipColor(color)
    if not color then return false end
    return color.R >= 0.55
        and color.G <= 0.35
        and color.B <= 0.35
        and (color.R - math.max(color.G, color.B)) >= 0.18
end

local function isBloodManipVisual(obj)
    if not obj or isHubOwnedGui(obj) then return false end

    if nameLooksLikeBloodEffect(obj.Name) then
        if obj:IsA("ScreenGui")
            or obj:IsA("Frame")
            or obj:IsA("ImageLabel")
            or obj:IsA("ColorCorrectionEffect")
            or obj:IsA("BlurEffect")
            or obj:IsA("DepthOfFieldEffect") then
            return true
        end
    end

    local ancestor = obj
    while ancestor do
        if ancestor:IsA("ScreenGui") and nameLooksLikeBloodEffect(ancestor.Name) then
            if obj:IsA("GuiObject") or obj:IsA("ColorCorrectionEffect") then
                return true
            end
        end
        ancestor = ancestor.Parent
    end

    if obj:IsA("ColorCorrectionEffect") and obj.Enabled then
        return isRedManipColor(obj.TintColor)
    end

    if obj:IsA("Frame") or obj:IsA("ImageLabel") then
        if not obj.Visible then return false end

        local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
        local absSize = obj.AbsoluteSize
        if absSize.X >= viewport.X * 0.75 and absSize.Y >= viewport.Y * 0.75 then
            local color = obj:IsA("Frame") and obj.BackgroundColor3 or obj.ImageColor3
            local transparency = obj:IsA("Frame") and obj.BackgroundTransparency or obj.ImageTransparency
            if transparency < 0.98 and isRedManipColor(color) then
                return true
            end
        end
    end

    return false
end

local function trackBloodEffect(obj)
    if not obj then return end
    for _, tracked in ipairs(State.bloodEffectTracked) do
        if tracked == obj then
            return
        end
    end
    table.insert(State.bloodEffectTracked, obj)
end

local function neutralizeBloodManipVisual(obj)
    if not obj or not obj.Parent then return end

    pcall(function()
        if obj:IsA("ScreenGui") then
            obj:Destroy()
        elseif obj:IsA("GuiObject") then
            obj.Visible = false
            obj:Destroy()
        elseif obj:IsA("ColorCorrectionEffect")
            or obj:IsA("BlurEffect")
            or obj:IsA("DepthOfFieldEffect") then
            obj.Enabled = false
        end
        trackBloodEffect(obj)
    end)
end

local function maintainTrackedBloodEffects()
    local index = 1
    while index <= #State.bloodEffectTracked do
        local obj = State.bloodEffectTracked[index]
        if not obj or not obj.Parent then
            table.remove(State.bloodEffectTracked, index)
        else
            pcall(function()
                if obj:IsA("ColorCorrectionEffect")
                    or obj:IsA("BlurEffect")
                    or obj:IsA("DepthOfFieldEffect") then
                    if obj.Enabled then
                        obj.Enabled = false
                    end
                elseif obj:IsA("GuiObject") and obj.Visible then
                    obj.Visible = false
                end
            end)
            index = index + 1
        end
    end
end

local function scanForBloodManipEffects(root)
    if not root then return end

    for _, desc in ipairs(root:GetDescendants()) do
        if isBloodManipVisual(desc) then
            neutralizeBloodManipVisual(desc)
        end
    end
end

local function restoreBloodEffectCamera()
    if State.bloodEffectRestoringCamera then return end
    if State.spectating or State.freecamEnabled or State.desyncEnabled then
        return
    end

    local cam = Workspace.CurrentCamera
    if not cam or cam.CameraType == Enum.CameraType.Scriptable then
        return
    end

    local normalFov = State.bloodEffectSavedFov or 70
    local normalMaxZoom = State.bloodEffectSavedMaxZoom or 128
    local normalMinZoom = State.bloodEffectSavedMinZoom or 0.5
    local needsRestore = cam.FieldOfView < normalFov - 1
        or player.CameraMaxZoomDistance < math.min(normalMaxZoom, 12)
        or player.CameraMinZoomDistance > math.max(normalMinZoom, 4)
        or (player.CameraMaxZoomDistance <= player.CameraMinZoomDistance + 0.25
            and player.CameraMaxZoomDistance < normalMaxZoom)

    if not needsRestore then return end

    State.bloodEffectRestoringCamera = true
    pcall(function()
        if cam.FieldOfView < normalFov - 1 then
            cam.FieldOfView = normalFov
        end
        if player.CameraMaxZoomDistance < math.min(normalMaxZoom, 12) then
            player.CameraMaxZoomDistance = normalMaxZoom
        end
        if player.CameraMinZoomDistance > math.max(normalMinZoom, 4) then
            player.CameraMinZoomDistance = normalMinZoom
        end
        if player.CameraMaxZoomDistance <= player.CameraMinZoomDistance + 0.25
            and player.CameraMaxZoomDistance < normalMaxZoom then
            player.CameraMaxZoomDistance = normalMaxZoom
            player.CameraMinZoomDistance = normalMinZoom
        end
    end)
    State.bloodEffectRestoringCamera = false
end

local function updateBloodManipEffectBlock()
    if not State.removeBloodManipEffects then return end

    maintainTrackedBloodEffects()
    restoreBloodEffectCamera()
end

local function clearBloodEffectBlockConnections()
    for _, conn in ipairs(State.bloodEffectBlockConnections or {}) do
        pcall(function() conn:Disconnect() end)
    end
    State.bloodEffectBlockConnections = {}
end

local function hookBloodEffectDescendants(root)
    if not root then return end

    table.insert(State.bloodEffectBlockConnections, root.DescendantAdded:Connect(function(desc)
        if State.removeBloodManipEffects and isBloodManipVisual(desc) then
            task.defer(function()
                neutralizeBloodManipVisual(desc)
            end)
        end
    end))
end

local function startBloodManipEffectBlock()
    clearBloodEffectBlockConnections()

    local cam = Workspace.CurrentCamera
    if cam then
        State.bloodEffectSavedFov = cam.FieldOfView
    end
    State.bloodEffectSavedMaxZoom = player.CameraMaxZoomDistance
    State.bloodEffectSavedMinZoom = player.CameraMinZoomDistance

    hookBloodEffectDescendants(Lighting)
    hookBloodEffectDescendants(player:FindFirstChild("PlayerGui"))

    local function hookCurrentCamera()
        local cam = Workspace.CurrentCamera
        if cam then
            hookBloodEffectDescendants(cam)
        end
    end

    hookCurrentCamera()
    table.insert(State.bloodEffectBlockConnections, Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        if State.removeBloodManipEffects then
            hookCurrentCamera()
            task.defer(function()
                scanForBloodManipEffects(Workspace.CurrentCamera)
            end)
        end
    end))

    if player.Character then
        hookBloodEffectDescendants(player.Character)
    end

    table.insert(State.bloodEffectBlockConnections, player.CharacterAdded:Connect(function(character)
        if State.removeBloodManipEffects then
            hookBloodEffectDescendants(character)
            task.defer(function()
                scanForBloodManipEffects(character)
            end)
        end
    end))

    scanForBloodManipEffects(Lighting)
    scanForBloodManipEffects(Workspace.CurrentCamera)
    scanForBloodManipEffects(player:FindFirstChild("PlayerGui"))
    scanForBloodManipEffects(player.Character)
end

local function stopBloodManipEffectBlock()
    clearBloodEffectBlockConnections()
    State.bloodEffectTracked = {}
end

local function setRemoveBloodManipEffects(enabled)
    State.removeBloodManipEffects = enabled
    setHubToggle(UI.RemoveBloodManipEffectsToggle, enabled)

    if enabled then
        startBloodManipEffectBlock()
    else
        stopBloodManipEffectBlock()
    end
end

local function getPlayerFromCharacterPart(part)
    if not part then return nil end
    local model = part:FindFirstAncestorOfClass("Model")
    if not model then return nil end
    return Players:GetPlayerFromCharacter(model)
end

local function getBloodManipHeadTarget()
    local cam = Workspace.CurrentCamera
    if not cam then return nil end

    local filter = {player.Character}
    if State.desyncVisualFolder then
        table.insert(filter, State.desyncVisualFolder)
    end

    -- On mobile: use the last recorded touch position instead of mouse location.
    -- On desktop: use the actual mouse position.
    local function getTargetScreenPos()
        if State.isMobile and State.holdingBloodManipKey and State.lastTouchScreenPos then
            return State.lastTouchScreenPos
        end
        local loc = UserInputService:GetMouseLocation()
        local ok, inset = pcall(function() return GuiService:GetGuiInset() end)
        if ok and inset then
            return Vector2.new(loc.X, loc.Y - inset.Y)
        end
        return Vector2.new(loc.X, loc.Y)
    end

    local targetPlayer = nil

    pcall(function()
        local mouse = player:GetMouse()
        if mouse and mouse.Target then
            local hitPart = mouse.Target
            if not (player.Character and hitPart:IsDescendantOf(player.Character)) then
                if hitPart.Name == "Head" then
                    targetPlayer = getPlayerFromCharacterPart(hitPart)
                else
                    local model = hitPart:FindFirstAncestorOfClass("Model")
                    if model and model:FindFirstChild("Head") then
                        targetPlayer = getPlayerFromCharacterPart(model.Head)
                    end
                end
            end
        end
    end)

    if targetPlayer and targetPlayer ~= player then
        return targetPlayer
    end

    pcall(function()
        local screenPos = getTargetScreenPos()
        local ray = cam:ViewportPointToRay(screenPos.X, screenPos.Y)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Blacklist
        params.FilterDescendantsInstances = filter

        local result = Workspace:Raycast(ray.Origin, ray.Direction * 250, params)
        if result and result.Instance then
            local hitPart = result.Instance
            if hitPart.Name == "Head" then
                targetPlayer = getPlayerFromCharacterPart(hitPart)
            else
                local model = hitPart:FindFirstAncestorOfClass("Model")
                if model and model:FindFirstChild("Head") then
                    targetPlayer = getPlayerFromCharacterPart(model.Head)
                end
            end
        end
    end)

    if targetPlayer and targetPlayer ~= player then
        return targetPlayer
    end

    pcall(function()
        local screenPos = getTargetScreenPos()
        -- On mobile widen the snap radius so it's easy to tap near someone
        local snapRadius = State.isMobile and 200 or 160
        local closest, closestDist = nil, snapRadius

        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character and plr.Character:FindFirstChild("Head") then
                local head = plr.Character.Head
                local vp, _ = cam:WorldToViewportPoint(head.Position)
                if vp.Z > 0 then
                    local dist = (Vector2.new(vp.X, vp.Y) - screenPos).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closest = plr
                    end
                end
            end
        end

        targetPlayer = closest
    end)

    return targetPlayer
end

local function clearBloodManipHighlight()
    if State.bloodManipHighlight then
        pcall(function()
            State.bloodManipHighlight:Destroy()
        end)
        State.bloodManipHighlight = nil
    end
end

local function setBloodManipHighlight(plr)
    clearBloodManipHighlight()
    if not plr or not plr.Character then return end

    pcall(function()
        local hl = Instance.new("Highlight")
        hl.Name = "NightFallBloodManip"
        hl.Adornee = plr.Character
        hl.FillColor = Color3.fromRGB(170, 15, 25)
        hl.OutlineColor = Color3.fromRGB(255, 70, 80)
        hl.FillTransparency = 0.15
        hl.OutlineTransparency = 0
        hl.Parent = CoreGui
        State.bloodManipHighlight = hl
    end)
end

local function resetBloodManipState()
    State.bloodManipTarget = nil
    State.bloodManipLockPos = nil
    State.bloodManipWalkAwayStart = nil
    State.bloodManipTargetLockedAt = nil
    clearBloodManipHighlight()
end

local BLOOD_MANIP_FLEE_TIME = 4.30
local BLOOD_MANIP_STAY_TIME = 0.60
local BLOOD_MANIP_FLEE_DIST = 3
local BLOOD_MANIP_HOLD_KILL_TIME = 4.30

local function bloodManipTeleportHrp(hrp, cf)
    if not hrp or not cf then return end
    pcall(function()
        hrp.CFrame = cf
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hrp.Velocity = Vector3.zero
        hrp.RotVelocity = Vector3.zero
    end)
end

local function getBehindTargetCFrame(targetHrp)
    if not targetHrp then return nil end
    return CFrame.new(
        targetHrp.Position - targetHrp.CFrame.LookVector * 4.5,
        targetHrp.Position
    )
end

local function executeBloodManipKill(targetPlayer)
    if State.bloodManipExecuting or not targetPlayer then return end

    State.bloodManipExecuting = true
    State.bloodManipWalkAwayStart = nil

    task.spawn(function()
        local hrp = getRoot()
        if not hrp then
            State.bloodManipExecuting = false
            return
        end

        if NF.F.removeFlightPhysics then
            NF.F.removeFlightPhysics(hrp)
        end

        local returnCFrame = hrp.CFrame
        local stayUntil = tick() + BLOOD_MANIP_STAY_TIME
        local stepName = "NightFallBloodManipHold"

        pcall(function()
            setsimulationradius(2e19, 2e19)
            sethiddenproperty(player, "SimulationRadius", 2e19)
            sethiddenproperty(player, "MaxSimulationRadius", 2e19)
        end)

        local function holdBehindTarget()
            local currentHrp = getRoot()
            local targetChar = targetPlayer.Character
            local targetHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
            if not currentHrp or not targetHrp then return end

            local cf = getBehindTargetCFrame(targetHrp)
            if cf then
                bloodManipTeleportHrp(currentHrp, cf)
            end
        end

        pcall(function() RunService:UnbindFromRenderStep(stepName) end)
        pcall(function()
            RunService:BindToRenderStep(stepName, Enum.RenderPriority.First.Value + 2, function()
                if tick() <= stayUntil then
                    holdBehindTarget()
                else
                    pcall(function() RunService:UnbindFromRenderStep(stepName) end)
                end
            end)
        end)

        holdBehindTarget()
        while tick() < stayUntil do
            task.wait()
        end

        pcall(function() RunService:UnbindFromRenderStep(stepName) end)

        local finalHrp = getRoot()
        if finalHrp then
            bloodManipTeleportHrp(finalHrp, returnCFrame)
        end

        State.bloodManipExecuting = false
        if not State.holdingBloodManipKey then
            resetBloodManipState()
        else
            local targetChar = targetPlayer.Character
            local targetHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
            State.bloodManipWalkAwayStart = nil
            State.bloodManipTargetLockedAt = tick()
            State.bloodManipLockPos = targetHrp and targetHrp.Position or State.bloodManipLockPos
        end
    end)
end

local function updateBloodManipulator()
    if not State.bloodManipEnabled or State.bloodManipExecuting then return end

    if not State.isMobile then
        State.holdingBloodManipKey = UserInputService:IsKeyDown(Enum.KeyCode.E)
    end

    if not State.holdingBloodManipKey then
        resetBloodManipState()
        return
    end

    if not State.bloodManipTarget then
        local targetPlayer = getBloodManipHeadTarget()
        if not targetPlayer or not targetPlayer.Character then
            return
        end

        local targetHrp = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not targetHrp then
            return
        end

        State.bloodManipTarget = targetPlayer
        State.bloodManipLockPos = targetHrp.Position
        State.bloodManipWalkAwayStart = nil
        State.bloodManipTargetLockedAt = tick()
        setBloodManipHighlight(targetPlayer)
        return
    end

    local targetPlayer = State.bloodManipTarget
    if not targetPlayer.Parent or not targetPlayer.Character then
        resetBloodManipState()
        return
    end

    local targetHrp = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetHrp then
        resetBloodManipState()
        return
    end

    if not State.bloodManipHighlight or not State.bloodManipHighlight.Parent then
        setBloodManipHighlight(targetPlayer)
    end

    if State.bloodManipTargetLockedAt
        and tick() - State.bloodManipTargetLockedAt >= BLOOD_MANIP_HOLD_KILL_TIME then
        executeBloodManipKill(targetPlayer)
        return
    end

    if State.bloodManipLockPos then
        local movedAway = (targetHrp.Position - State.bloodManipLockPos).Magnitude >= BLOOD_MANIP_FLEE_DIST
        if movedAway then
            if not State.bloodManipWalkAwayStart then
                State.bloodManipWalkAwayStart = tick()
            end

            if tick() - State.bloodManipWalkAwayStart >= BLOOD_MANIP_FLEE_TIME then
                executeBloodManipKill(targetPlayer)
            end
        else
            State.bloodManipWalkAwayStart = nil
        end
    end
end

NF.F.updateBloodManipulator = updateBloodManipulator
NF.F.updateBloodManipEffectBlock = updateBloodManipEffectBlock
NF.F.stopBloodManipEffectBlock = stopBloodManipEffectBlock
NF.F.resetBloodManipState = resetBloodManipState
NF.F.setRemoveBloodManipEffects = setRemoveBloodManipEffects

end -- scope block 2b (blood manip - Luau local register limit)

do -- scope block 2c (player esp - Luau local register limit)

local clearHighlight = F.clearHighlight
local createPlayerESP = F.createPlayerESP

local function updatePlayerESP()
    for plr, _ in pairs(State.highlights) do
        if not (plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")) then
            clearHighlight(plr)
        end
    end

    if State.homelanderESPEnabled and State.firstHomelander and State.firstHomelander.Character
        and State.firstHomelander.Character:FindFirstChild("HumanoidRootPart") then
        if not State.highlights[State.firstHomelander] then
            createPlayerESP(State.firstHomelander, Color3.fromRGB(255, 50, 50), true)
        end

        local data = State.billboards[State.firstHomelander]
        if data and root then
            pcall(function()
                local dist = (root.Position - State.firstHomelander.Character.HumanoidRootPart.Position).Magnitude
                local health = State.firstHomelander.Character:FindFirstChildOfClass("Humanoid")
                local healthText = health and ("\nHP " .. math.floor(health.Health) .. "/" .. math.floor(health.MaxHealth)) or ""
                local roleLabel = State.detectedKillerRole or "KILLER"
                data.label.Text = string.format("!! %s !!\n[%s]\n> %d studs%s",
                    State.firstHomelander.Name,
                    roleLabel,
                    math.floor(dist),
                    healthText
                )
            end)
        end
    end

    if State.teamESPEnabled then
        for plr, _ in pairs(State.highlights) do
            if plr ~= player and plr ~= State.firstHomelander and plr.Character
                and plr.Character:FindFirstChild("HumanoidRootPart") then
                local data = State.billboards[plr]
                if data and root then
                    pcall(function()
                        local dist = (root.Position - plr.Character.HumanoidRootPart.Position).Magnitude
                        data.label.Text = string.format("+ %s\n> %d studs",
                            plr.Name, 
                            math.floor(dist)
                        )
                    end)
                end
            end
        end
    else
        for plr, _ in pairs(State.highlights) do
            if plr ~= State.firstHomelander then
                clearHighlight(plr)
            end
        end
    end
end

local function refreshPlayerESPScan()
    if State.highlights[player] then
        clearHighlight(player)
    end
    if State.firstHomelander == player then
        State.firstHomelander = nil
        if UI.StatusHomelander then
            UI.StatusHomelander.StateLabel.Text = "NONE"
            UI.StatusHomelander.StateLabel.TextColor3 = COLORS.textMuted
        end
    end

    for plr, _ in pairs(State.highlights) do
        if not plr.Parent then
            clearHighlight(plr)
            if plr == State.firstHomelander then
                State.firstHomelander = nil
                if UI.StatusHomelander then
                    UI.StatusHomelander.StateLabel.Text = "NONE"
                    UI.StatusHomelander.StateLabel.TextColor3 = COLORS.textMuted
                end
            end
        end
    end

    if State.homelanderESPEnabled then
        State.scanForHomelander()
    end

    if State.teamESPEnabled then
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= player and plr ~= State.firstHomelander
                and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                if not State.highlights[plr] then
                    createPlayerESP(plr, Color3.fromRGB(0, 255, 150), false)
                end
            end
        end
    end
end

NF.F.updatePlayerESP = updatePlayerESP
NF.F.refreshPlayerESPScan = refreshPlayerESPScan

end -- scope block 2c (player esp - Luau local register limit)

do -- scope block 2d (aimbot core - Luau local register limit)

local clearHighlight = F.clearHighlight
local createPlayerESP = F.createPlayerESP
local updateTempVESP = F.updateTempVESP
local updateMovementHacks = F.updateMovementHacks
local updateFlight = F.updateFlight
local updateSpin = F.updateSpin
local setNoclip = F.setNoclip
local getHumanoid = F.getHumanoid
local getRoot = F.getRoot
local updateSpeedHack = F.updateSpeedHack
local isPlayerHomelander = F.isPlayerHomelander
local setHubToggle = F.setHubToggle
local resetMovementSettings = F.resetMovementSettings
local resetTrollEffects = F.resetTrollEffects
local stopDesyncEngine = F.stopDesyncEngine
local stopSpectate = F.stopSpectate
local startSpectate = F.startSpectate
local refreshMiscPlayerList = F.refreshMiscPlayerList
local setDesync = F.setDesync
local flingHomelander = F.flingHomelander
local skidFlingPlayer = F.skidFlingPlayer
local flingSelf = F.flingSelf
local setupCharacterMovement = F.setupCharacterMovement
local applyJumpBoost = F.applyJumpBoost
local applyJumpStats = F.applyJumpStats
local tpRandomPlayer = F.tpRandomPlayer
local playAnnoyingSound = F.playAnnoyingSound
local setATrainKill = F.setATrainKill
local executeATrainKill = F.executeATrainKill
local startATrainDashHooks = F.startATrainDashHooks
local clearAllTempVHighlights = F.clearAllTempVHighlights
local clearAllTempVBillboards = F.clearAllTempVBillboards
local applyMovementStatsNow = F.applyMovementStatsNow
local stopFlight = F.stopFlight
local onTempVPickedUp = F.onTempVPickedUp
local updateSpectateCamera = F.updateSpectateCamera
local removeFlightPhysics = F.removeFlightPhysics
local beginCameraDrag = F.beginCameraDrag
local endCameraDrag = F.endCameraDrag
local applyCameraDragDelta = F.applyCameraDragDelta
local updateFreecam = F.updateFreecam
local stopFreecam = F.stopFreecam
local setFreecam = F.setFreecam
local updateBloodManipulator = F.updateBloodManipulator
local updateBloodManipEffectBlock = F.updateBloodManipEffectBlock
local stopBloodManipEffectBlock = F.stopBloodManipEffectBlock
local resetBloodManipState = F.resetBloodManipState
local setRemoveBloodManipEffects = F.setRemoveBloodManipEffects
local updatePlayerESP = F.updatePlayerESP
local refreshPlayerESPScan = F.refreshPlayerESPScan
local updateFailsafe = F.updateFailsafe
local teleportToSafeZone = F.teleportToSafeZone

local function enableRobloxMovementControls()
    pcall(function() GuiService.TouchControlsEnabled = true end)
    if State.isMobile then
        return
    end
    pcall(function()
        local playerScripts = player:FindFirstChild("PlayerScripts")
        if not playerScripts then return end
        local playerModuleScript = playerScripts:FindFirstChild("PlayerModule")
        if not playerModuleScript then return end
        local ok, playerModule = pcall(require, playerModuleScript)
        if not ok or not playerModule or type(playerModule.GetControls) ~= "function" then return end
        local controls = playerModule:GetControls()
        if controls and controls.Enable then
            controls:Enable(true)
        end
    end)
end

local function ensureMobileGameplay()
    if not State.isMobile then return end

    pcall(function() GuiService.TouchControlsEnabled = true end)
    enableRobloxMovementControls()
    pcall(function()
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
    end)

    if State.WindowDrag then
        State.WindowDrag.active = false
        State.WindowDrag.touchInput = nil
    end

    local hum = getHumanoid()
    local hrp = getRoot()
    if hum then
        pcall(function()
            hum.PlatformStand = false
            hum.AutoRotate = true
            hum.Sit = false
            if hum.WalkSpeed <= 0 then
                hum.WalkSpeed = State.defaultWalkSpeed > 0 and State.defaultWalkSpeed or 16
            end
            if not State.flightEnabled then
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end
        end)
    end

    if hrp then
        pcall(function()
            hrp.Anchored = false
        end)
        if not State.flightEnabled and removeFlightPhysics then
            removeFlightPhysics(hrp)
        end
    end

    if not State.freecamEnabled and not State.spectating and not State.holdingMobileAim then
        restoreAimbotCamera()
        local cam = refreshCamera()
        if cam and hum then
            pcall(function()
                if cam.CameraType == Enum.CameraType.Scriptable then
                    cam.CameraType = Enum.CameraType.Custom
                end
                cam.CameraSubject = hum
            end)
        end
    end
end

NF.F.ensureMobileGameplay = ensureMobileGameplay

local function ensureNativePcCamera()
    if State.isMobile or State.ejected then return end
    if State.freecamEnabled or State.spectating then return end
    if NF.F.cameraNeedsAimbotRestore and NF.F.cameraNeedsAimbotRestore() then return end
    local cam = Workspace.CurrentCamera
    local hum = getHumanoid()
    if not cam or not hum then return end
    pcall(function()
        if cam.CameraType == Enum.CameraType.Scriptable then
            cam.CameraType = Enum.CameraType.Custom
        end
        if cam.CameraSubject ~= hum then
            cam.CameraSubject = hum
        end
    end)
end

local function ensurePcGameplay()
    if State.isMobile or State.ejected then return end
    if State.freecamEnabled or State.spectating then return end
    enableRobloxMovementControls()
    ensureNativePcCamera()
end

NF.F.enableRobloxMovementControls = enableRobloxMovementControls
NF.F.ensurePcGameplay = ensurePcGameplay

local clearAimbotLock, updateAimbotLock, aimMouseAtHead = (function()
local AIMBOT_MAX_FOV = 220
local AIMBOT_LOST_GRACE = 0.6

local AIM_PART_FALLBACKS = {
    Head = {"Head"},
    HumanoidRootPart = {"HumanoidRootPart"},
    UpperTorso = {"UpperTorso", "Torso"},
    LowerTorso = {"LowerTorso"},
    Torso = {"Torso", "UpperTorso"},
}

local function getAimSmoothness()
    local delayMs = math.clamp(tonumber(State.aimbotDelayMs) or 0, 0, 500)
    local base = 0.26
    if delayMs <= 0 then return base end
    return math.clamp(base - (delayMs / 500) * (base - 0.08), 0.08, base)
end

local function getAimbotCameraRate()
    local delayMs = math.clamp(tonumber(State.aimbotDelayMs) or 0, 0, 500)
    if delayMs <= 0 then return 14 end
    return math.clamp(14 - (delayMs / 500) * 10, 4, 14)
end

local function resolveAimPartName()
    local partName = State.aimbotTargetPart
    if type(partName) ~= "string" or partName == "" then return "Head" end
    return partName
end

local function findAimPartInCharacter(character)
    if not character then return nil end
    local partName = resolveAimPartName()
    local part = character:FindFirstChild(partName)
    if part and part:IsA("BasePart") then return part end
    local fallbacks = AIM_PART_FALLBACKS[partName]
    if fallbacks then
        for _, name in ipairs(fallbacks) do
            part = character:FindFirstChild(name)
            if part and part:IsA("BasePart") then return part end
        end
    end
    part = character:FindFirstChild("Head")
    if part and part:IsA("BasePart") then return part end
    return character:FindFirstChild("HumanoidRootPart")
end

local function getPlayerAimPart(plr)
    if not plr or plr == player then return nil end
    local character = plr.Character
    if not character then return nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return nil end
    return findAimPartInCharacter(character)
end

local function getPartWorldAimPoint(part)
    if not part or not part:IsA("BasePart") then return nil end
    return part.Position + Vector3.new(0, 0.1, 0)
end

local function getAimMousePos()
    local loc = UserInputService:GetMouseLocation()
    return Vector2.new(loc.X, loc.Y)
end

local function getViewportCenterScreen()
    if not State.isMobile and isPcShiftLocked() then
        if NF.F.getShiftLockAimScreen then
            return NF.F.getShiftLockAimScreen()
        end
    end
    local cam = refreshCamera()
    if not cam then return getAimMousePos() end
    local vp = cam.ViewportSize
    return Vector2.new(vp.X / 2, vp.Y / 2)
end

local function getAimReferenceScreen()
    if State.isMobile and State.holdingMobileAim then
        return getViewportCenterScreen()
    end
    if isPcShiftLocked() then
        return getViewportCenterScreen()
    end
    return getAimMousePos()
end

local function partToScreen(part)
    local cam = refreshCamera()
    if not cam or not part or not part.Parent then return nil end
    local worldPos = getPartWorldAimPoint(part)
    if not worldPos then return nil end
    local ok, sp = pcall(function()
        local vp, _ = cam:WorldToViewportPoint(worldPos)
        return vp
    end)
    if not ok or not sp or sp.Z <= 0 then return nil end
    return Vector2.new(sp.X, sp.Y)
end

local function getDynamicFov(part)
    local cam = refreshCamera()
    if not cam or not part then return AIMBOT_MAX_FOV end
    local dist = (part.Position - cam.CFrame.Position).Magnitude
    return math.clamp(AIMBOT_MAX_FOV + dist * 0.4, AIMBOT_MAX_FOV, 800)
end

local function moveMouseRelative(deltaX, deltaY)
    if math.abs(deltaX) < 0.01 and math.abs(deltaY) < 0.01 then return true end
    local movers = {}
    local function add(fn)
        if type(fn) == "function" then table.insert(movers, fn) end
    end
    add(mousemoverel)
    if getgenv then
        local env = getgenv()
        add(env and env.mousemoverel)
        add(env and env.mouse_move_rel)
    end
    if syn then
        add(syn.mousemoverel)
        if syn.mouse and type(syn.mouse.move) == "function" then
            table.insert(movers, function(x, y)
                syn.mouse.move(x, y, true)
            end)
        end
    end
    for _, mover in ipairs(movers) do
        local ok = pcall(function() mover(deltaX, deltaY) end)
        if ok then return true end
    end
    return false
end

local function getClosestTargetPart()
    local ref = getAimReferenceScreen()
    local closestPart, bestDist = nil, math.huge
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            local part = getPlayerAimPart(plr)
            if part then
                local sp = partToScreen(part)
                if sp then
                    local fov = getDynamicFov(part)
                    local dist = (sp - ref).Magnitude
                    if dist <= fov and dist < bestDist then
                        bestDist = dist
                        closestPart = part
                    end
                end
            end
        end
    end
    return closestPart
end

local function clearMobileAimCameraSnapshot()
    State.mobileAimCamFlatDist = nil
    State.mobileAimCamHeight = nil
end

local function clearAimbotLock()
    State.aimbotLockedTarget = nil
    State.aimbotLockedHead = nil
    State.aimbotLockExpired = false
    State.aimbotHeadLostAt = nil
    clearPcAimCursor()
    clearMobileAimCameraSnapshot()
    if NF.F.ensureGameplayCamera then
        NF.F.ensureGameplayCamera()
    else
        restoreAimbotCamera()
    end
    if camera and camera.CameraType == Enum.CameraType.Scriptable then
        pcall(function() camera.CameraType = Enum.CameraType.Custom end)
        State.aimbotSavedCameraType = nil
    end
end

local function updateAimbotLock(_useCenter)
    local now = os.clock()
    if State.aimbotLockedTarget then
        local part = getPlayerAimPart(State.aimbotLockedTarget)
        if part then
            State.aimbotLockedHead = part
            State.aimbotHeadLostAt = nil
            return State.aimbotLockedTarget, part
        end
        if not State.aimbotHeadLostAt then State.aimbotHeadLostAt = now end
        if now - State.aimbotHeadLostAt < AIMBOT_LOST_GRACE then
            return State.aimbotLockedTarget, nil
        end
        State.aimbotLockedTarget = nil
        State.aimbotLockedHead = nil
        State.aimbotHeadLostAt = nil
    end

    local part = getClosestTargetPart()
    if part then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character and findAimPartInCharacter(plr.Character) == part then
                State.aimbotLockedTarget = plr
                break
            end
        end
    else
        State.aimbotLockedTarget = nil
    end
    State.aimbotLockedHead = part
    State.aimbotHeadLostAt = nil
    return State.aimbotLockedTarget, part
end

local function aimCameraAtWorldPos(part, dt)
    local cam = refreshCamera()
    if not cam or not part then return false end
    local worldPos = getPartWorldAimPoint(part)
    if not worldPos then return false end

    local hrp = getRoot()
    if not hrp then return false end

    local delayMs = math.clamp(tonumber(State.aimbotDelayMs) or 0, 0, 500)
    local alpha = 1
    if delayMs > 0 then
        alpha = 1 - math.exp(-getAimbotCameraRate() * (dt or (1 / 60)))
    else
        alpha = 0.16
    end

    return pcall(function()
        local charFocus = hrp.Position + Vector3.new(0, 2, 0)

        if not State.mobileAimCamFlatDist then
            local offset = cam.CFrame.Position - charFocus
            local flat = Vector3.new(offset.X, 0, offset.Z)
            local flatDist = flat.Magnitude
            State.mobileAimCamFlatDist = math.clamp(flatDist > 1 and flatDist or 12, 8, 22)
            State.mobileAimCamHeight = math.clamp(offset.Y, 1, 4)
        end

        local camDist = State.mobileAimCamFlatDist
        local camHeight = State.mobileAimCamHeight

        local toTarget = worldPos - charFocus
        local flat = Vector3.new(toTarget.X, 0, toTarget.Z)
        if flat.Magnitude < 0.05 then
            flat = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
        end
        if flat.Magnitude < 0.05 then
            flat = Vector3.new(0, 0, -1)
        end

        local backDir = -flat.Unit
        local desiredPos = charFocus + Vector3.new(backDir.X * camDist, camHeight, backDir.Z * camDist)
        local desiredCF = CFrame.new(desiredPos, worldPos)

        if cam.CameraType ~= Enum.CameraType.Scriptable then
            if not State.aimbotSavedCameraType then
                State.aimbotSavedCameraType = cam.CameraType
            end
            cam.CameraType = Enum.CameraType.Scriptable
        end

        cam.CFrame = (delayMs <= 0 or alpha >= 0.99) and desiredCF or cam.CFrame:Lerp(desiredCF, alpha)
    end)
end

-- Shift lock: mousemoverel from crosshair center (never hijack camera on PC).
local function aimPcShiftLock(part)
    local sp = partToScreen(part)
    if not sp then return false end

    local ref = getViewportCenterScreen()
    local smooth = getAimSmoothness()
    local delta = (sp - ref) * smooth
    if delta.Magnitude < 1.25 then return true end
    return moveMouseRelative(delta.X, delta.Y)
end

local function aimPcFreeMouse(part)
    local sp = partToScreen(part)
    if not sp then return false end

    ensurePcAimMouseFree()

    local ref = getAimMousePos()
    local smooth = getAimSmoothness()
    local delta = (sp - ref) * smooth
    if delta.Magnitude < 1.25 then return true end
    return moveMouseRelative(delta.X, delta.Y)
end

local function aimPc(part, _dt)
    if isPcShiftLocked() then
        return aimPcShiftLock(part)
    end
    return aimPcFreeMouse(part)
end

local function aimMouseAtHead(part, _useCenter, dt)
    if not part then return false end
    if State.isMobile then
        return aimCameraAtWorldPos(part, dt)
    end
    return aimPc(part, dt)
end

return clearAimbotLock, updateAimbotLock, aimMouseAtHead
end)()

NF.F.clearAimbotLock = clearAimbotLock
NF.F.updateAimbotLock = updateAimbotLock
NF.F.aimMouseAtHead = aimMouseAtHead

end -- scope block 2d (aimbot core; Luau local register limit)

do -- scope block 2e (input + loops + wiring; Luau local register limit)

local F = NF.F
local clearAimbotLock = F.clearAimbotLock
local updateAimbotLock = F.updateAimbotLock
local aimMouseAtHead = F.aimMouseAtHead
local clearHighlight = F.clearHighlight
local createPlayerESP = F.createPlayerESP
local updateTempVESP = F.updateTempVESP
local updateMovementHacks = F.updateMovementHacks
local updateFlight = F.updateFlight
local updateSpin = F.updateSpin
local setNoclip = F.setNoclip
local getHumanoid = F.getHumanoid
local getRoot = F.getRoot
local updateSpeedHack = F.updateSpeedHack
local isPlayerHomelander = F.isPlayerHomelander
local setHubToggle = F.setHubToggle
local resetMovementSettings = F.resetMovementSettings
local resetTrollEffects = F.resetTrollEffects
local stopDesyncEngine = F.stopDesyncEngine
local stopSpectate = F.stopSpectate
local startSpectate = F.startSpectate
local refreshMiscPlayerList = F.refreshMiscPlayerList
local setDesync = F.setDesync
local flingHomelander = F.flingHomelander
local skidFlingPlayer = F.skidFlingPlayer
local flingSelf = F.flingSelf
local setupCharacterMovement = F.setupCharacterMovement
local applyJumpBoost = F.applyJumpBoost
local applyJumpStats = F.applyJumpStats
local tpRandomPlayer = F.tpRandomPlayer
local playAnnoyingSound = F.playAnnoyingSound
local setATrainKill = F.setATrainKill
local executeATrainKill = F.executeATrainKill
local startATrainDashHooks = F.startATrainDashHooks
local clearAllTempVHighlights = F.clearAllTempVHighlights
local clearAllTempVBillboards = F.clearAllTempVBillboards
local applyMovementStatsNow = F.applyMovementStatsNow
local stopFlight = F.stopFlight
local onTempVPickedUp = F.onTempVPickedUp
local updateSpectateCamera = F.updateSpectateCamera
local removeFlightPhysics = F.removeFlightPhysics
local beginCameraDrag = F.beginCameraDrag
local endCameraDrag = F.endCameraDrag
local applyCameraDragDelta = F.applyCameraDragDelta
local updateFreecam = F.updateFreecam
local stopFreecam = F.stopFreecam
local setFreecam = F.setFreecam
local updateBloodManipulator = F.updateBloodManipulator
local updateBloodManipEffectBlock = F.updateBloodManipEffectBlock
local stopBloodManipEffectBlock = F.stopBloodManipEffectBlock
local resetBloodManipState = F.resetBloodManipState
local setRemoveBloodManipEffects = F.setRemoveBloodManipEffects
local updatePlayerESP = F.updatePlayerESP
local refreshPlayerESPScan = F.refreshPlayerESPScan
local updateFailsafe = F.updateFailsafe
local teleportToSafeZone = F.teleportToSafeZone
local bindConnection = F.bindConnection
local bindHubClick = F.bindHubClick
local tween = F.tween
local refreshCamera = F.refreshCamera
local restoreAimbotCamera = F.restoreAimbotCamera
local isAimHoldActive = F.isAimHoldActive
local isPcShiftLocked = F.isPcShiftLocked
local refreshShiftLockState = F.refreshShiftLockState
local handleShiftLockKeyPress = F.handleShiftLockKeyPress
local inputToKeyCode = F.inputToKeyCode
local isShiftLockKeyInput = F.isShiftLockKeyInput
local getAimReferenceUsesCenter = F.getAimReferenceUsesCenter
local syncPcAimHoldState = F.syncPcAimHoldState
local ensurePcAimMouseFree = F.ensurePcAimMouseFree
local setAimbotShiftCursorLocked = F.setAimbotShiftCursorLocked
local maintainPcShiftLockCursor = F.maintainPcShiftLockCursor
local ensureGameplayCamera = F.ensureGameplayCamera
local cameraNeedsAimbotRestore = F.cameraNeedsAimbotRestore
local ensurePcGameplay = F.ensurePcGameplay
local enableRobloxMovementControls = F.enableRobloxMovementControls
local syncPcAimCursorFromSystem = F.syncPcAimCursorFromSystem
local setHubVisible = F.setHubVisible
local setMobileOverlayEnabled = F.setMobileOverlayEnabled
local closeHubMenu = F.closeHubMenu
local saveAimbotSettings = F.saveAimbotSettings

local ejectScript

-- Input Handling
bindConnection(UserInputService.InputBegan:Connect(function(input, gp)
    if beginCameraDrag(input) then
        return
    end

    if State.hubKeybindListen then
        local keyCode = inputToKeyCode(input)
        if keyCode then
            State.hubKeybindListen.onSet(keyCode)
        end
        return
    end

    if isShiftLockKeyInput(input) then
        handleShiftLockKeyPress()
        return
    end

    if input.KeyCode == Enum.KeyCode.Q and State.isPremium and State.aTrainKillEnabled
        and not gp and not State.isMobile then
        executeATrainKill()
        return
    end

    -- Handle touch inputs (works even when isMobile detection fails in executors)
    if input.UserInputType == Enum.UserInputType.Touch then
        -- Blood manip: hold finger on a player to activate
        -- (waits 0.25 s then sets holdingBloodManipKey if still held)
        if State.bloodManipEnabled and not State.bloodManipTouchInput
            and not State.freecamEnabled and not State.spectating then
            local touchPos = Vector2.new(input.Position.X, input.Position.Y)
            State.lastTouchScreenPos = touchPos
            State.bloodManipTouchInput = input
            task.spawn(function()
                task.wait(0.25)
                if State.bloodManipTouchInput == input then
                    State.holdingBloodManipKey = true
                end
            end)
        end

        if gp then return end

        -- Camera orbit in freecam / spectate
        if (State.freecamEnabled or State.spectating) and not State.mobileCamTouch then
            State.mobileCamTouch = input
            if State.freecamEnabled then
                State.freecamLooking = true
                pcall(function() UserInputService.MouseIconEnabled = false end)
            elseif State.spectating then
                State.spectateOrbiting = true
            end
        end

        return
    end

    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        if State.freecamEnabled or State.spectating then
            return
        end
        if not State.swappedMouseButtons and not State.WindowDrag.active then
            State.holdingRightClick = true
            if State.aimbotEnabled and not State.isMobile and not isPcShiftLocked() then
                syncPcAimCursorFromSystem()
                ensurePcAimMouseFree()
            end
        end
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if State.swappedMouseButtons and not State.WindowDrag.active
            and not State.freecamEnabled and not State.spectating then
            State.holdingRightClick = true
            if State.aimbotEnabled and not State.isMobile and not isPcShiftLocked() then
                syncPcAimCursorFromSystem()
                ensurePcAimMouseFree()
            end
        end
        return
    end

    if input.KeyCode == Enum.KeyCode.E and State.bloodManipEnabled then
        State.holdingBloodManipKey = true
        return
    end

    if gp then return end

    if input.KeyCode == Enum.KeyCode.R then
        State.aimbotEnabled = not State.aimbotEnabled
        setHubToggle(UI.AimbotToggle, State.aimbotEnabled)
        if UI.MobileAimBtn then
            UI.MobileAimBtn.Visible = State.aimbotEnabled
        end
        if not State.aimbotEnabled then
            clearAimbotLock()
            State.holdingMobileAim = false
            if UI.MobileAimBtn and not State.mobileAimDragUnlocked then
                UI.MobileAimBtn.Text = "LOCK ON"
                pcall(function() UI.MobileAimBtn.BackgroundColor3 = COLORS.accent end)
            end
        end
    end
end))

bindConnection(UserInputService.InputEnded:Connect(function(input)
    State.WindowDrag.stop(input)
    endCameraDrag(input)
    -- End touch camera orbit / blood manip hold
    if input.UserInputType == Enum.UserInputType.Touch then
        if input == State.mobileCamTouch then
            State.mobileCamTouch = nil
            if State.freecamEnabled then
                State.freecamLooking = false
                pcall(function() UserInputService.MouseIconEnabled = true end)
            end
            if State.spectating then
                State.spectateOrbiting = false
            end
        end
        if input == State.bloodManipTouchInput then
            State.bloodManipTouchInput = nil
            State.holdingBloodManipKey = false
        end
    end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        if not State.swappedMouseButtons then
            State.holdingRightClick = false
            if State.aimbotEnabled and not State.isMobile then
                clearAimbotLock()
            end
        end
    elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
        if State.swappedMouseButtons then
            State.holdingRightClick = false
            if State.aimbotEnabled and not State.isMobile then
                clearAimbotLock()
            end
        end
    elseif input.KeyCode == Enum.KeyCode.E then
        State.holdingBloodManipKey = false
        if not State.bloodManipExecuting then
            resetBloodManipState()
        end
    end
end))

bindConnection(UserInputService.InputChanged:Connect(function(input, gp)
    -- Route touch drag into camera orbit delta
    if input.UserInputType == Enum.UserInputType.Touch then
        -- Track last touch position for blood manip targeting
        State.lastTouchScreenPos = Vector2.new(input.Position.X, input.Position.Y)
        if input == State.mobileCamTouch then
            local delta = Vector2.new(input.Delta.X, input.Delta.Y)
            if delta.Magnitude > 0 then
                applyCameraDragDelta(delta)
            end
            return
        end
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseMovement then
        if State.freecamLooking or State.spectateOrbiting then
            local delta = Vector2.new(input.Delta.X, input.Delta.Y)
            if delta.Magnitude > 0 then
                applyCameraDragDelta(delta)
            end
        end
        return
    end

    if gp then return end

    if input.UserInputType == Enum.UserInputType.MouseWheel then
        if State.spectating and not State.freecamEnabled then
            State.spectateFollowDistance = math.clamp(
                (State.spectateFollowDistance or 18) - input.Position.Z * 2,
                4,
                500
            )
        elseif State.freecamEnabled then
            State.freecamSpeed = math.clamp(
                (State.freecamSpeed or 80) + input.Position.Z * 4,
                20,
                250
            )
            if UI.setFreecamSpeedSliderValue then
                UI.setFreecamSpeedSliderValue(State.freecamSpeed)
            end
        end
    end
end))

-- Main Update Loop
local _renderFrame = 0
local _espInterval = State.isMobile and 3 or 1  -- ESP runs every 3 frames on mobile

local function tickFeature(fn, ...)
    if type(fn) == "function" then
        pcall(fn, ...)
    end
end

bindConnection(RunService.RenderStepped:Connect(function(dt)
    if State.ejected then return end
    _renderFrame = _renderFrame + 1

    tickFeature(updateFreecam, dt)
    if State.spectating then
        tickFeature(updateSpectateCamera)
    end
    tickFeature(updateBloodManipulator)
    tickFeature(updateBloodManipEffectBlock)
    tickFeature(updateMovementHacks)
    tickFeature(updateFlight)
    tickFeature(updateSpin, dt)

    -- Throttle ESP on mobile to every 3 frames to reduce GPU/CPU pressure
    if _renderFrame % _espInterval == 0 then
        pcall(updatePlayerESP)
        if type(updateTempVESP) == "function" then
            pcall(updateTempVESP)
        end
    end

    if State.noclipEnabled and player.Character then
        setNoclip(true)
    end

    if State.autoRefreshEnabled then
        local now = tick()
        if now - State.lastTempVScanTime >= 2 then
            State.lastTempVScanTime = now
            State.scanTempVParts()
        end
    end

    if not State.ejected and refreshPlayerESPScan then
        local now = tick()
        if now - (State.lastPlayerESPScanTime or 0) >= (State.espRescanInterval or 3) then
            State.lastPlayerESPScanTime = now
            pcall(refreshPlayerESPScan)
        end
    end
    
    -- Mobile overlay button visibility ??? synced every frame so they can never get stuck hidden
    local flightOn = State.flightEnabled
    if UI.MobileFlightUpBtn   then UI.MobileFlightUpBtn.Visible   = flightOn end
    if UI.MobileFlightDownBtn then UI.MobileFlightDownBtn.Visible = flightOn end
    -- LOCK ON button: visible whenever aimbot is on (forced every frame)
    if UI.MobileAimBtn then
        UI.MobileAimBtn.Visible = State.aimbotEnabled
        -- Re-parent if something stripped it (some games clear CoreGui)
        if State.aimbotEnabled and UI.MobileAimGui and not UI.MobileAimGui.Parent then
            pcall(function() UI.MobileAimGui.Parent = GUI_PARENT end)
        end
    end
    -- FOV circle: visible while the LOCK ON button is being held
    if UI.FovCircle then UI.FovCircle.Visible = State.holdingMobileAim end
end))

-- Aimbot: shift lock early (Input), free mouse on RenderStepped ??? same EDEN coords for both
pcall(function() RunService:UnbindFromRenderStep("NightFallAimbot") end)
pcall(function() RunService:UnbindFromRenderStep("NightFallAimbotFree") end)

NF.F.runAimbotStep = function(dt)
    local function releaseShiftAimCursor()
        if isPcShiftLocked() then return end
        if setAimbotShiftCursorLocked then
            setAimbotShiftCursorLocked(false)
        end
    end

    if State.ejected or not State.aimbotEnabled then
        releaseShiftAimCursor()
        if ensureGameplayCamera then
            ensureGameplayCamera()
        end
        return
    end
    if State.freecamEnabled or State.spectating then
        releaseShiftAimCursor()
        return
    end

    syncPcAimHoldState()

    if not isAimHoldActive() then
        releaseShiftAimCursor()
        if State.aimbotLockedTarget or State.aimbotLockedHead
            or (cameraNeedsAimbotRestore and cameraNeedsAimbotRestore()) then
            clearAimbotLock()
        end
        return
    end

    if not refreshCamera() then return end

    local _, part = updateAimbotLock(getAimReferenceUsesCenter())
    if part then
        aimMouseAtHead(part, nil, dt)
    end
end

pcall(function()
    RunService:BindToRenderStep("NightFallAimbot", Enum.RenderPriority.First.Value, function(dt)
        if State.isMobile or not isPcShiftLocked() then return end
        NF.F.runAimbotStep(dt)
    end)
end)

bindConnection(RunService.RenderStepped:Connect(function(dt)
    if not State.isMobile then
        if State.shiftLockActive and maintainPcShiftLockCursor then
            maintainPcShiftLockCursor()
        end
        if ensurePcGameplay and (not State.lastPcGameplayEnsure or tick() - State.lastPcGameplayEnsure > 2) then
            State.lastPcGameplayEnsure = tick()
            ensurePcGameplay()
        end
    end
    if not State.isMobile and isPcShiftLocked() then return end
    NF.F.runAimbotStep(dt)
end))

bindConnection(RunService.Heartbeat:Connect(function()
    if State.ejected then return end
    tickFeature(updateFailsafe)
    if not State.speedEnabled or State.flightEnabled then return end
    local humanoid = getHumanoid()
    local hrp = getRoot()
    if humanoid and hrp then
        tickFeature(updateSpeedHack, humanoid, hrp)
    end
end))

bindConnection(UserInputService.JumpRequest:Connect(function()
    local humanoid = getHumanoid()
    local hrp = getRoot()
    if not humanoid or not hrp then return end

    if State.jumpEnabled and NF.F.applyJumpStats then
        NF.F.applyJumpStats(humanoid)
        task.defer(function()
            if State.jumpEnabled and NF.F.applyJumpBoost then
                NF.F.applyJumpBoost(getRoot())
            end
        end)
    end

    if State.infJumpEnabled then
        pcall(function()
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    end
end))

-- Button Event Handlers
ejectScript = function()
    if State.ejected then return end
    State.ejected = true

    pcall(resetMovementSettings)
    pcall(resetTrollEffects)
    pcall(stopSpectate)
    pcall(stopFreecam)
    pcall(resetBloodManipState)
    pcall(stopBloodManipEffectBlock)
    pcall(clearAimbotLock)
    pcall(function()
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end)
    pcall(stopDesyncEngine)

    pcall(function() RunService:UnbindFromRenderStep("NightFallAimbot") end)
    pcall(function() RunService:UnbindFromRenderStep("NightFallAimbotFree") end)
    pcall(function() RunService:UnbindFromRenderStep("NightFallBloodManipHold") end)
    pcall(function() RunService:UnbindFromRenderStep("NightFallAutowinHold") end)
    if NF.F.setHomelanderAutowin then
        pcall(NF.F.setHomelanderAutowin, false)
    end
    if setAimbotShiftCursorLocked then
        pcall(setAimbotShiftCursorLocked, false)
    end

    for _, hl in pairs(State.highlights or {}) do
        pcall(function() hl:Destroy() end)
    end
    for _, data in pairs(State.billboards or {}) do
        pcall(function() data.gui:Destroy() end)
    end
    for _, hl in pairs(State.tempVHighlights or {}) do
        pcall(function() hl:Destroy() end)
    end
    for _, data in pairs(State.tempVBillboards or {}) do
        pcall(function() data.gui:Destroy() end)
    end

    State.highlights = {}
    State.billboards = {}
    State.tempVHighlights = {}
    State.tempVBillboards = {}
    State.firstHomelander = nil

    for _, conn in pairs(State.trackedConnections) do
        pcall(function() conn:Disconnect() end)
    end
    State.trackedConnections = {}

    pcall(function()
        RunService:UnbindFromRenderStep("ScriptHubDesync")
    end)

    if UI.ScreenGui then UI.ScreenGui:Destroy() end
    if UI.ToggleGui then UI.ToggleGui:Destroy() end
    if UI.MobileAimGui then UI.MobileAimGui:Destroy() end
end

bindHubClick(UI.HomelanderESPToggle, function()
    State.homelanderESPEnabled = not State.homelanderESPEnabled
    setHubToggle(UI.HomelanderESPToggle, State.homelanderESPEnabled)
    refreshPlayerESPScan()
end)

bindHubClick(UI.TeamESPToggle, function()
    State.teamESPEnabled = not State.teamESPEnabled
    setHubToggle(UI.TeamESPToggle, State.teamESPEnabled)
    refreshPlayerESPScan()
    
    if not State.teamESPEnabled then
        for plr, _ in pairs(State.highlights) do
            if plr ~= State.firstHomelander then
                clearHighlight(plr)
            end
        end
    end
end)

bindHubClick(UI.TempVHighlightToggle, function()
    State.tempVHighlightEnabled = not State.tempVHighlightEnabled
    setHubToggle(UI.TempVHighlightToggle, State.tempVHighlightEnabled)
    
    if not State.tempVHighlightEnabled then
        clearAllTempVHighlights()
        clearAllTempVBillboards()
    else
        State.scanTempVParts()
    end
end)

bindHubClick(UI.AimbotToggle, function()
    State.aimbotEnabled = not State.aimbotEnabled
    setHubToggle(UI.AimbotToggle, State.aimbotEnabled)
    if UI.MobileAimBtn then
        UI.MobileAimBtn.Visible = State.aimbotEnabled
    end
    setMobileOverlayEnabled(State.aimbotEnabled)
    if not State.aimbotEnabled then
        clearAimbotLock()
        State.holdingMobileAim = false
        restoreAimbotCamera()
        if UI.MobileAimBtn and not State.mobileAimDragUnlocked then
            UI.MobileAimBtn.Text = "LOCK ON"
            tween(UI.MobileAimBtn, { BackgroundColor3 = COLORS.accent })
        end
    end
end)

bindHubClick(UI.MobileAimDragToggle, function()
    State.mobileAimDragUnlocked = not State.mobileAimDragUnlocked
    setHubToggle(UI.MobileAimDragToggle, State.mobileAimDragUnlocked, "UNLOCKED", "LOCKED")
    local subLabel = UI.MobileAimDragToggle:FindFirstChild("SubLabel")
    if subLabel then
        subLabel.Text = State.mobileAimDragUnlocked
            and "Drag the LOCK ON button anywhere, then lock it"
            or "Drag the LOCK ON button to reposition it"
    end
    if State.mobileAimDragUnlocked then
        UI.MobileAimBtn.Text = "DRAG"
        -- Disengage aim while in drag mode so taps don't accidentally toggle it
        State.holdingMobileAim = false
        State.aimbotLockedTarget = nil
        State.aimbotLockedHead = nil
        State.mobileAimCamFlatDist = nil
        State.mobileAimCamHeight = nil
        tween(UI.MobileAimBtn, { BackgroundColor3 = COLORS.accent })
    else
        saveAimButtonPos(UI.MobileAimBtn.Position)
        UI.MobileAimBtn.Text = State.holdingMobileAim and "LOCKED" or "LOCK ON"
    end
end)

bindHubClick(UI.TeleportHomelanderBtn, function()
    if State.firstHomelander and State.firstHomelander.Character and State.firstHomelander.Character:FindFirstChild("HumanoidRootPart") and root then
        pcall(function()
            local targetPos = State.firstHomelander.Character.HumanoidRootPart.Position
            root.CFrame = CFrame.new(targetPos + Vector3.new(0, 5, 0))
        end)
    else
        warn("No Homelander found! Enable Homelander ESP first.")
    end
end)

bindHubClick(UI.TeleportSafeZoneBtn, function()
    teleportToSafeZone()
end)

bindHubClick(UI.FailsafeToggle, function()
    State.failsafeEnabled = not State.failsafeEnabled
    setHubToggle(UI.FailsafeToggle, State.failsafeEnabled)
    if not State.failsafeEnabled then
        State.failsafeTripped = false
        State.failsafeReturnCFrame = nil
    end
    saveFailsafeSettings()
end)

bindHubClick(UI.AutoRefreshToggle, function()
    State.autoRefreshEnabled = not State.autoRefreshEnabled
    setHubToggle(UI.AutoRefreshToggle, State.autoRefreshEnabled)
    UI.StatusScan.StateLabel.Text = State.autoRefreshEnabled and "ON" or "OFF"
    UI.StatusScan.StateLabel.TextColor3 = State.autoRefreshEnabled and COLORS.accent or COLORS.textMuted
    if State.autoRefreshEnabled then
        State.scanTempVParts()
    end
end)

bindHubClick(UI.RefreshNowBtn, function()
    State.scanTempVParts()
end)

bindHubClick(UI.SpeedToggle, function()
    State.speedEnabled = not State.speedEnabled
    setHubToggle(UI.SpeedToggle, State.speedEnabled)
    applyMovementStatsNow()
end)

bindHubClick(UI.JumpToggle, function()
    State.jumpEnabled = not State.jumpEnabled
    setHubToggle(UI.JumpToggle, State.jumpEnabled)
    applyMovementStatsNow()
end)

bindHubClick(UI.FlightToggle, function()
    State.flightEnabled = not State.flightEnabled
    setHubToggle(UI.FlightToggle, State.flightEnabled)
    if State.flightEnabled then
        local humanoid = getHumanoid()
        if humanoid then
            pcall(function()
                humanoid.PlatformStand = true
                humanoid.AutoRotate = false
            end)
        end
    else
        stopFlight()
        applyMovementStatsNow()
    end
end)

bindHubClick(UI.NoclipToggle, function()
    State.noclipEnabled = not State.noclipEnabled
    setHubToggle(UI.NoclipToggle, State.noclipEnabled)
    setNoclip(State.noclipEnabled)
end)

bindHubClick(UI.InfJumpToggle, function()
    State.infJumpEnabled = not State.infJumpEnabled
    setHubToggle(UI.InfJumpToggle, State.infJumpEnabled)
end)

bindHubClick(UI.ResetMovementBtn, function()
    resetMovementSettings()
end)

bindHubClick(UI.ResetTogglePosBtn, function()
    local defaultPos = NF.F.getDefaultTogglePos and NF.F.getDefaultTogglePos()
        or UDim2.new(0.5, -18, 0.5, -18)
    UI.ToggleCube.Position = defaultPos
    saveTogglePos(defaultPos)
end)

bindHubClick(UI.SwappedMouseToggle, function()
    State.swappedMouseButtons = not State.swappedMouseButtons
    setHubToggle(UI.SwappedMouseToggle, State.swappedMouseButtons)
end)

bindHubClick(UI.HideMobileGuiToggle, function()
    applyHideMobileGui(not State.hideMobileGui)
    setHubToggle(UI.HideMobileGuiToggle, State.hideMobileGui)
end)

-- Restore the saved "Hide Mobile GUI" preference now that the GUIs exist
do
    local saved = loadHideMobileGui()
    if saved then
        applyHideMobileGui(true)
        setHubToggle(UI.HideMobileGuiToggle, true)
    end
end

bindHubClick(UI.ClearESPBtn, function()
    -- Clear all player ESP
    for plr, _ in pairs(State.highlights) do
        clearHighlight(plr)
    end
    State.firstHomelander = nil
    UI.StatusHomelander.StateLabel.Text = "NONE"
    UI.StatusHomelander.StateLabel.TextColor3 = COLORS.textMuted
    
    clearAllTempVHighlights()
    clearAllTempVBillboards()
end)

-- TempV pickup listener
bindConnection(Workspace.DescendantRemoving:Connect(function(obj)
    if obj:IsA("Model") and obj.Name:lower() == "tempv" and State.trackedTempVModels[obj] then
        onTempVPickedUp(obj)
    end
end))

-- Player ESP rescan runs on RenderStepped (every 3s via ESP_RESCAN_INTERVAL)

bindConnection(Players.PlayerAdded:Connect(function()
    refreshMiscPlayerList()
    if State.homelanderESPEnabled or State.teamESPEnabled then
        task.defer(refreshPlayerESPScan)
    end
end))

bindConnection(Players.PlayerRemoving:Connect(function(leaving)
    if State.spectateTarget == leaving then
        stopSpectate()
    end
    if State.spectateSelected == leaving then
        State.spectateSelected = nil
    end
    if State.tempVRecentUntil then
        State.tempVRecentUntil[leaving] = nil
    end
    refreshMiscPlayerList()
end))

-- Character respawn handler
bindConnection(player.CharacterAdded:Connect(function(character)
    State.failsafeTripped = false
    State.failsafeReturnCFrame = nil
    task.spawn(function()
        setupCharacterMovement(character)
        ensureMobileGameplay()
        if ensurePcGameplay then ensurePcGameplay() end
    end)
end))

if player.Character then
    task.spawn(function()
        setupCharacterMovement(player.Character)
        ensureMobileGameplay()
        if ensurePcGameplay then ensurePcGameplay() end
    end)
end

task.defer(function()
    dismissNightFallLoaderUi()
    ensureMobileGameplay()
    if ensurePcGameplay then ensurePcGameplay() end
    if refreshShiftLockState then refreshShiftLockState() end
    if State.isMobile then
        print("[NightFall] Mobile mode - menu closed on load. Tap NF cube to open.")
        task.spawn(function()
            for _ = 1, 45 do
                if State.ejected then break end
                ensureMobileGameplay()
                task.wait(2)
            end
        end)
    end
    if State.autoRefreshEnabled then
        State.scanTempVParts()
    end
    refreshPlayerESPScan()
    refreshMiscPlayerList()
    if State.isMobile and State.aTrainKillEnabled then
        startATrainDashHooks()
    end
end)

if type(NF.F.updateMovementHacks) ~= "function" or type(NF.F.updateTempVESP) ~= "function" then
    warn("[NightFall] Feature bundle incomplete - movement/scanner may not work. Re-download the latest build.")
end

end -- scope block 2e (input + loops + wiring)
print("[SurviveHomelander] Loaded - Mobile keyless build 2026-05-27-MOBILE-KEYLESS1")
if State.isMobile then
    print("[SurviveHomelander] Mobile touch: direct HitLayer Activated (single tap claim)")
end
print("[SurviveHomelander] Aimbot: Combat tab - PC hold RMB - Mobile tap LOCK ON")
if State.isPremium then
    print("[SurviveHomelander] A-Train Kill: Premium tab - PC press Q - Mobile tap DASH")
    print("[SurviveHomelander] Homelander Autowin: Premium tab - toggle ON as Homelander")
else
    print("[SurviveHomelander] Keyless mode - premium features disabled")
end
print("[SurviveHomelander] Drag the top bar to move - Cube toggles menu")
print("[SurviveHomelander] Tabs: Scanner - Movement - Premium - Combat - Troll - Misc")