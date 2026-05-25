local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local root = nil
local camera = Workspace.CurrentCamera

local UI = {}
local State = {
    ejected = false,
    isMobile = UserInputService.TouchEnabled,
    holdingRightClick = false,
    holdingMobileAim = false,
    mobileAimDragUnlocked = false,
    trackedConnections = {},
}

local COLORS = {
    bg = Color3.fromRGB(13, 14, 18),
    sidebar = Color3.fromRGB(16, 17, 23),
    surface = Color3.fromRGB(22, 24, 31),
    surfaceHover = Color3.fromRGB(28, 30, 40),
    elevated = Color3.fromRGB(34, 36, 46),
    border = Color3.fromRGB(44, 46, 58),
    tabActive = Color3.fromRGB(99, 102, 241),
    tabActiveBg = Color3.fromRGB(28, 30, 48),
    text = Color3.fromRGB(236, 237, 242),
    textDark = Color3.fromRGB(255, 255, 255),
    textMuted = Color3.fromRGB(128, 132, 150),
    accent = Color3.fromRGB(99, 102, 241),
    accentLight = Color3.fromRGB(129, 140, 248),
    accentOn = Color3.fromRGB(56, 189, 248),
    success = Color3.fromRGB(52, 211, 153),
    danger = Color3.fromRGB(239, 68, 68),
    toggleCube = Color3.fromRGB(99, 102, 241),
    track = Color3.fromRGB(18, 19, 26),
    toggleOff = Color3.fromRGB(55, 58, 72),
    toggleOn = Color3.fromRGB(99, 102, 241),
}

local RADIUS = { sm = 6, md = 10, lg = 14, xl = 20 }
local SIDEBAR_WIDTH = 132

local function tween(instance, props, duration)
    TweenService:Create(
        instance,
        TweenInfo.new(duration or 0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
        props
    ):Play()
end

local function applyCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or RADIUS.md)
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

local PANDA_SERVICE = "nightfall"
local PANDA_KEY_PATH = "ScriptHub/panda_key.txt"
local AIM_POS_PATH = "ScriptHub/aim_btn_pos.txt"
local TOGGLE_POS_PATH = "ScriptHub/toggle_pos.txt"
local TOGGLE_SIZE_PATH = "ScriptHub/toggle_size.txt"
local TOGGLE_POS_PATH = "ScriptHub/toggle_pos.txt"
local TOGGLE_SIZE_PATH = "ScriptHub/toggle_size.txt"

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

local ejectScript

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

-- Hub GUI (XVC-style)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ScriptHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = CoreGui
UI.ScreenGui = ScreenGui

local function loadAimButtonPos()
    local data = fsRead(AIM_POS_PATH)
    if data then
        local x, y = data:match("([^,]+),([^,]+)")
        if x and y then
            return UDim2.new(0, tonumber(x), 0, tonumber(y))
        end
    end
    return UDim2.new(1, -96, 1, -120)
end

local function saveAimButtonPos(pos)
    fsWrite(AIM_POS_PATH, tostring(pos.X.Offset) .. "," .. tostring(pos.Y.Offset))
end

local function loadTogglePos()
    local data = fsRead(TOGGLE_POS_PATH)
    if data then
        local x, y = data:match("([^,]+),([^,]+)")
        if x and y then
            return UDim2.new(0, tonumber(x), 0, tonumber(y))
        end
    end
    return UDim2.new(0, 10, 0, 10)
end

local function saveTogglePos(pos)
    fsWrite(TOGGLE_POS_PATH, tostring(pos.X.Offset) .. "," .. tostring(pos.Y.Offset))
end

local function loadToggleSize()
    return tonumber(fsRead(TOGGLE_SIZE_PATH)) or 36
end

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
    fsWrite(TOGGLE_SIZE_PATH, tostring(size))
end

State.toggleCubeSize = loadToggleSize()

UI.ToggleGui = Instance.new("ScreenGui")
UI.ToggleGui.Name = "ScriptHubToggle"
UI.ToggleGui.ResetOnSpawn = false
UI.ToggleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
UI.ToggleGui.DisplayOrder = 10
UI.ToggleGui.Parent = CoreGui

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
local toggleDragStart, toggleStartPos
local toggleMoved = false
local TOGGLE_DRAG_THRESHOLD = 6

UI.MobileAimGui = Instance.new("ScreenGui")
UI.MobileAimGui.Name = "ScriptHubMobileAim"
UI.MobileAimGui.ResetOnSpawn = false
UI.MobileAimGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
UI.MobileAimGui.DisplayOrder = 9
UI.MobileAimGui.Enabled = State.isMobile
UI.MobileAimGui.Parent = CoreGui

UI.MobileAimBtn = Instance.new("TextButton")
UI.MobileAimBtn.Name = "MobileAimButton"
UI.MobileAimBtn.Size = UDim2.new(0, 72, 0, 72)
UI.MobileAimBtn.Position = loadAimButtonPos()
UI.MobileAimBtn.BackgroundColor3 = COLORS.accent
UI.MobileAimBtn.BackgroundTransparency = 0.08
UI.MobileAimBtn.Text = "AIM"
UI.MobileAimBtn.TextColor3 = COLORS.text
UI.MobileAimBtn.TextSize = 14
UI.MobileAimBtn.Font = Enum.Font.GothamBold
UI.MobileAimBtn.AutoButtonColor = false
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
local mobileAimDragStart, mobileAimStartPos

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 620, 0, 580)
MainFrame.Position = UDim2.new(0.5, -310, 0.5, -290)
MainFrame.BackgroundTransparency = 1
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = false
MainFrame.ZIndex = 2
MainFrame.Parent = ScreenGui
UI.MainFrame = MainFrame

local WindowBg = Instance.new("Frame")
WindowBg.Name = "WindowBg"
WindowBg.Size = UDim2.new(1, 0, 1, 0)
WindowBg.BackgroundColor3 = COLORS.bg
WindowBg.BorderSizePixel = 0
WindowBg.ZIndex = 0
WindowBg.Parent = MainFrame
applyCorner(WindowBg, RADIUS.xl)
applyStroke(WindowBg, COLORS.border, 1, 0.35)

local MainShadow = Instance.new("Frame")
MainShadow.Size = UDim2.new(0, 632, 0, 592)
MainShadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
MainShadow.BackgroundTransparency = 0.6
MainShadow.BorderSizePixel = 0
MainShadow.ZIndex = 1
MainShadow.Parent = ScreenGui
applyCorner(MainShadow, RADIUS.xl + 2)
UI.MainShadow = MainShadow

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
    MainShadow.Visible = visible
end

syncMainShadowPosition()

local dragging = false
local dragStart, startPos

local function makeDraggable(frame, handle)
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
end

bindConnection(UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
        syncMainShadowPosition()
    end

    if mobileAimDragging and State.mobileAimDragUnlocked
        and input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - mobileAimDragStart
        UI.MobileAimBtn.Position = UDim2.new(
            mobileAimStartPos.X.Scale, mobileAimStartPos.X.Offset + delta.X,
            mobileAimStartPos.Y.Scale, mobileAimStartPos.Y.Offset + delta.Y
        )
    end

    if toggleDragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - toggleDragStart
        if delta.Magnitude > TOGGLE_DRAG_THRESHOLD then
            toggleMoved = true
        end
        if toggleMoved then
            UI.ToggleCube.Position = UDim2.new(
                toggleStartPos.X.Scale, toggleStartPos.X.Offset + delta.X,
                toggleStartPos.Y.Scale, toggleStartPos.Y.Offset + delta.Y
            )
        end
    end
end))

local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 52)
Header.BackgroundColor3 = COLORS.bg
Header.BorderSizePixel = 0
Header.ZIndex = 2
Header.Parent = MainFrame
applyCorner(Header, RADIUS.xl)

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
UI.CloseBtn.Text = "×"
UI.CloseBtn.TextColor3 = COLORS.textMuted
UI.CloseBtn.TextSize = 22
UI.CloseBtn.Font = Enum.Font.GothamMedium
UI.CloseBtn.AutoButtonColor = false
UI.CloseBtn.Parent = Header
applyCorner(UI.CloseBtn, RADIUS.sm)

UI.CloseBtn.MouseEnter:Connect(function()
    tween(UI.CloseBtn, { BackgroundColor3 = COLORS.danger, TextColor3 = COLORS.text })
end)
UI.CloseBtn.MouseLeave:Connect(function()
    tween(UI.CloseBtn, { BackgroundColor3 = COLORS.surface, TextColor3 = COLORS.textMuted })
end)

makeDraggable(MainFrame, Header)

bindConnection(UI.ToggleCube.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        toggleDragging = true
        toggleMoved = false
        toggleDragStart = input.Position
        toggleStartPos = UI.ToggleCube.Position
    end
end))

bindConnection(UI.ToggleCube.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        if toggleDragging and toggleMoved then
            saveTogglePos(UI.ToggleCube.Position)
        elseif toggleDragging and not toggleMoved then
            setHubVisible(not MainFrame.Visible)
        end
        toggleDragging = false
    end
end))

bindConnection(UI.MobileAimBtn.InputBegan:Connect(function(input)
    if not State.isMobile then return end
    if input.UserInputType ~= Enum.UserInputType.Touch then return end

    if State.mobileAimDragUnlocked then
        mobileAimDragging = true
        mobileAimDragStart = input.Position
        mobileAimStartPos = UI.MobileAimBtn.Position
    else
        State.holdingMobileAim = true
        tween(UI.MobileAimBtn, { BackgroundColor3 = COLORS.success })
    end
end))

bindConnection(UI.MobileAimBtn.InputEnded:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Touch then return end

    if State.mobileAimDragUnlocked then
        mobileAimDragging = false
        saveAimButtonPos(UI.MobileAimBtn.Position)
    else
        State.holdingMobileAim = false
        tween(UI.MobileAimBtn, { BackgroundColor3 = COLORS.accent })
    end
end))

local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, SIDEBAR_WIDTH, 1, -52)
Sidebar.Position = UDim2.new(0, 0, 0, 52)
Sidebar.BackgroundColor3 = COLORS.sidebar
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex = 2
Sidebar.Parent = MainFrame
applyCorner(Sidebar, RADIUS.xl)

local SidebarLine = Instance.new("Frame")
SidebarLine.Size = UDim2.new(0, 1, 1, 0)
SidebarLine.Position = UDim2.new(1, -1, 0, 0)
SidebarLine.BackgroundColor3 = COLORS.border
SidebarLine.BorderSizePixel = 0
SidebarLine.Parent = Sidebar

local NavList = Instance.new("Frame")
NavList.Name = "NavList"
NavList.Size = UDim2.new(1, -12, 1, -16)
NavList.Position = UDim2.new(0, 6, 0, 8)
NavList.BackgroundTransparency = 1
NavList.Parent = Sidebar

local NavLayout = Instance.new("UIListLayout")
NavLayout.Padding = UDim.new(0, 4)
NavLayout.SortOrder = Enum.SortOrder.LayoutOrder
NavLayout.Parent = NavList

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -(SIDEBAR_WIDTH + 20), 1, -68)
Content.Position = UDim2.new(0, SIDEBAR_WIDTH + 10, 0, 58)
Content.BackgroundColor3 = COLORS.bg
Content.BackgroundTransparency = 0
Content.BorderSizePixel = 0
Content.ClipsDescendants = true
Content.ZIndex = 2
Content.Parent = MainFrame
applyCorner(Content, RADIUS.xl)

local pages = {}
local tabButtons = {}
local activeTab = "Home"

local function createPage(name)
    local page = Instance.new("Frame")
    page.Name = name .. "Page"
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Visible = false
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
end

local function createTab(name, icon)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 40)
    btn.BackgroundColor3 = COLORS.sidebar
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = NavList
    applyCorner(btn, RADIUS.md)

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
    iconLabel.Size = UDim2.new(0, 20, 1, 0)
    iconLabel.Position = UDim2.new(0, 14, 0, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = icon
    iconLabel.TextSize = 14
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextColor3 = COLORS.textMuted
    iconLabel.Parent = btn

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -38, 1, 0)
    textLabel.Position = UDim2.new(0, 36, 0, 0)
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

    btn.MouseButton1Click:Connect(function()
        switchTab(name)
    end)
end

local function createHubButton(parent, title, subtitle)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, subtitle and 54 or 46)
    btn.BackgroundColor3 = COLORS.surface
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = parent
    applyCorner(btn, RADIUS.md)
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
    applyCorner(switchTrack, RADIUS.full)

    local switchKnob = Instance.new("Frame")
    switchKnob.Name = "SwitchKnob"
    switchKnob.Size = UDim2.new(0, 18, 0, 18)
    switchKnob.Position = UDim2.new(0, 2, 0.5, -9)
    switchKnob.BackgroundColor3 = COLORS.text
    switchKnob.Parent = switchTrack
    applyCorner(switchKnob, RADIUS.full)

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

local function createHubSlider(parent, title, minVal, maxVal, defaultVal, onChanged)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 68)
    container.BackgroundColor3 = COLORS.surface
    container.Parent = parent
    applyCorner(container, RADIUS.md)
    applyStroke(container, COLORS.border, 1, 0.65)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0.6, 0, 0, 22)
    titleLabel.Position = UDim2.new(0, 14, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = COLORS.text
    titleLabel.TextSize = 13
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = container

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Name = "ValueLabel"
    valueLabel.Size = UDim2.new(0.4, -14, 0, 22)
    valueLabel.Position = UDim2.new(0.6, 0, 0, 10)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(defaultVal)
    valueLabel.TextColor3 = COLORS.accentOn
    valueLabel.TextSize = 13
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = container

    local track = Instance.new("TextButton")
    track.Name = "Track"
    track.Size = UDim2.new(1, -28, 0, 6)
    track.Position = UDim2.new(0, 14, 0, 44)
    track.BackgroundColor3 = COLORS.track
    track.Text = ""
    track.AutoButtonColor = false
    track.Parent = container
    applyCorner(track, RADIUS.full)

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = COLORS.accent
    fill.BorderSizePixel = 0
    fill.Parent = track
    applyCorner(fill, RADIUS.full)

    local knob = Instance.new("Frame")
    knob.Name = "Knob"
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(0, -7, 0.5, -7)
    knob.BackgroundColor3 = COLORS.text
    knob.BorderSizePixel = 0
    knob.ZIndex = 2
    knob.Parent = track
    applyCorner(knob, RADIUS.full)
    applyStroke(knob, COLORS.accentLight, 1, 0.2)

    local current = defaultVal
    local draggingSlider = false

    local function setValue(value, fireCallback)
        current = math.clamp(math.floor(value + 0.5), minVal, maxVal)
        valueLabel.Text = tostring(current)
        local alpha = (current - minVal) / math.max(maxVal - minVal, 1)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, -7, 0.5, -7)
        if fireCallback and onChanged then
            onChanged(current)
        end
    end

    local function updateFromInput(input)
        local trackPos = track.AbsolutePosition.X
        local trackSize = track.AbsoluteSize.X
        if trackSize <= 0 then return end
        local alpha = math.clamp((input.Position.X - trackPos) / trackSize, 0, 1)
        setValue(minVal + (maxVal - minVal) * alpha, true)
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = true
            updateFromInput(input)
        end
    end)

    track.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromInput(input)
        end
    end)

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
    applyCorner(container, RADIUS.md)
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
    applyCorner(box, RADIUS.sm)
    applyStroke(box, COLORS.border, 1, 0.7)

    local boxPad = Instance.new("UIPadding")
    boxPad.PaddingLeft = UDim.new(0, 10)
    boxPad.PaddingRight = UDim.new(0, 10)
    boxPad.Parent = box

    return container, box
end

local function createMiscFold(parent, title, startExpanded)
    local section = Instance.new("Frame")
    section.Size = UDim2.new(1, 0, 0, 40)
    section.BackgroundTransparency = 1
    section.Parent = parent

    local header = Instance.new("TextButton")
    header.Size = UDim2.new(1, 0, 0, 40)
    header.BackgroundColor3 = COLORS.surface
    header.Text = ""
    header.AutoButtonColor = false
    header.Parent = section
    applyCorner(header, RADIUS.md)
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
    titleLabel.TextSize = 14
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = header

    local arrow = Instance.new("TextLabel")
    arrow.Name = "Arrow"
    arrow.Size = UDim2.new(0, 24, 1, 0)
    arrow.Position = UDim2.new(1, -32, 0, 0)
    arrow.BackgroundTransparency = 1
    arrow.Text = "▸"
    arrow.TextColor3 = COLORS.textMuted
    arrow.TextSize = 14
    arrow.Font = Enum.Font.GothamBold
    arrow.Parent = header

    local body = Instance.new("Frame")
    body.Name = "Body"
    body.Size = UDim2.new(1, 0, 0, 0)
    body.Position = UDim2.new(0, 0, 0, 44)
    body.BackgroundTransparency = 1
    body.ClipsDescendants = true
    body.Parent = section

    local bodyLayout = Instance.new("UIListLayout")
    bodyLayout.Padding = UDim.new(0, 8)
    bodyLayout.Parent = body

    local expanded = startExpanded == true

    local function refreshSectionSize()
        local bodyHeight = expanded and bodyLayout.AbsoluteContentSize.Y or 0
        body.Size = UDim2.new(1, 0, 0, bodyHeight)
        section.Size = UDim2.new(1, 0, 0, 40 + (expanded and bodyHeight + 4 or 0))
    end

    bodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refreshSectionSize)

    local function setExpanded(value)
        expanded = value
        arrow.Text = expanded and "▾" or "▸"
        for _, child in ipairs(body:GetChildren()) do
            if not child:IsA("UIListLayout") then
                child.Visible = expanded
            end
        end
        refreshSectionSize()
    end

    header.MouseButton1Click:Connect(function()
        setExpanded(not expanded)
    end)

    header.MouseEnter:Connect(function()
        tween(header, { BackgroundColor3 = COLORS.surfaceHover })
    end)
    header.MouseLeave:Connect(function()
        tween(header, { BackgroundColor3 = COLORS.surface })
    end)

    setExpanded(expanded)

    return section, body
end

createTab("Home", "⌂")
createTab("Scanner", "◉")
createTab("Movement", "↗")
createTab("Combat", "⚡")
createTab("Troll", "☠")
createTab("Misc", "◔")
createTab("Settings", "⚙")

do

local HomePage = createPage("Home")
local ScannerPage = createPage("Scanner")
local MovementPage = createPage("Movement")
local CombatPage = createPage("Combat")
local TrollPage = createPage("Troll")
local MiscPage = createPage("Misc")
local SettingsPage = createPage("Settings")

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

local HomeCard = Instance.new("Frame")
HomeCard.Size = UDim2.new(1, 0, 0, 128)
HomeCard.BackgroundColor3 = COLORS.surface
HomeCard.Parent = HomePage
applyCorner(HomeCard, RADIUS.lg)
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
HomeSubText.Text = "TempV scanner, combat tools, movement hacks & troll features — all in one hub."
HomeSubText.TextColor3 = COLORS.textMuted
HomeSubText.TextSize = 12
HomeSubText.Font = Enum.Font.GothamMedium
HomeSubText.TextXAlignment = Enum.TextXAlignment.Left
HomeSubText.TextYAlignment = Enum.TextYAlignment.Top
HomeSubText.TextWrapped = true
HomeSubText.Parent = HomeCard

local HomeList = Instance.new("Frame")
HomeList.Size = UDim2.new(1, 0, 1, -140)
HomeList.Position = UDim2.new(0, 0, 0, 140)
HomeList.BackgroundTransparency = 1
HomeList.Parent = HomePage

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

local ScannerScroll = Instance.new("ScrollingFrame")
ScannerScroll.Size = UDim2.new(1, 0, 1, -168)
ScannerScroll.BackgroundColor3 = COLORS.surface
ScannerScroll.BorderSizePixel = 0
ScannerScroll.ScrollBarThickness = 4
ScannerScroll.ScrollBarImageColor3 = COLORS.border
ScannerScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
ScannerScroll.Parent = ScannerPage
applyCorner(ScannerScroll, RADIUS.lg)
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

local ScannerControls = Instance.new("Frame")
ScannerControls.Size = UDim2.new(1, 0, 0, 160)
ScannerControls.Position = UDim2.new(0, 0, 1, -160)
ScannerControls.BackgroundTransparency = 1
ScannerControls.Parent = ScannerPage

local ScannerControlsLayout = Instance.new("UIListLayout")
ScannerControlsLayout.Padding = UDim.new(0, 8)
ScannerControlsLayout.Parent = ScannerControls

UI.AutoRefreshToggle = createHubButton(ScannerControls, "Auto Scan", "Refresh list automatically")
setHubToggle(UI.AutoRefreshToggle, true)

UI.TempVHighlightToggle = createHubButton(ScannerControls, "TempV Highlight", "World ESP for TempV models")
setHubToggle(UI.TempVHighlightToggle, false)

UI.RefreshNowBtn = createHubButton(ScannerControls, "Refresh Scanner", "Scan workspace now")

local MovementScroll = Instance.new("ScrollingFrame")
MovementScroll.Size = UDim2.new(1, 0, 1, 0)
MovementScroll.BackgroundTransparency = 1
MovementScroll.BorderSizePixel = 0
MovementScroll.ScrollBarThickness = 5
MovementScroll.ScrollBarImageColor3 = COLORS.border
MovementScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
MovementScroll.Parent = MovementPage

local MovementList = Instance.new("Frame")
MovementList.Size = UDim2.new(1, 0, 0, 420)
MovementList.BackgroundTransparency = 1
MovementList.Parent = MovementScroll

local MovementLayout = Instance.new("UIListLayout")
MovementLayout.Padding = UDim.new(0, 8)
MovementLayout.Parent = MovementList

MovementLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    MovementList.Size = UDim2.new(1, 0, 0, MovementLayout.AbsoluteContentSize.Y)
    MovementScroll.CanvasSize = UDim2.new(0, 0, 0, MovementLayout.AbsoluteContentSize.Y + 8)
end)

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

local CombatScroll = Instance.new("ScrollingFrame")
CombatScroll.Size = UDim2.new(1, 0, 1, 0)
CombatScroll.BackgroundTransparency = 1
CombatScroll.BorderSizePixel = 0
CombatScroll.ScrollBarThickness = 5
CombatScroll.ScrollBarImageColor3 = COLORS.border
CombatScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
CombatScroll.Parent = CombatPage

local CombatList = Instance.new("Frame")
CombatList.Size = UDim2.new(1, 0, 0, 420)
CombatList.BackgroundTransparency = 1
CombatList.Parent = CombatScroll

local CombatLayout = Instance.new("UIListLayout")
CombatLayout.Padding = UDim.new(0, 8)
CombatLayout.Parent = CombatList

CombatLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    CombatList.Size = UDim2.new(1, 0, 0, CombatLayout.AbsoluteContentSize.Y)
    CombatScroll.CanvasSize = UDim2.new(0, 0, 0, CombatLayout.AbsoluteContentSize.Y + 8)
end)

UI.HomelanderESPToggle = createHubButton(CombatList, "Killer ESP", "Homelander & Stormfront · rescans every 5s")
setHubToggle(UI.HomelanderESPToggle, false)

UI.TeamESPToggle = createHubButton(CombatList, "Team ESP", "Rescans players every 5 seconds")
setHubToggle(UI.TeamESPToggle, false)

UI.AimbotToggle = createHubButton(CombatList, "Aimbot", State.isMobile and "Hold mobile AIM button" or "Hold right-click · toggle with R")
setHubToggle(UI.AimbotToggle, false)

UI.MobileAimDragToggle = createHubButton(CombatList, "Unlock Mobile Aim Button", "Hold the AIM button to aim on mobile")
setHubToggle(UI.MobileAimDragToggle, false, "UNLOCKED", "LOCKED")
UI.MobileAimDragToggle.Visible = State.isMobile

UI.TeleportHomelanderBtn = createHubButton(CombatList, "Teleport To Homelander", "Requires Homelander ESP")

UI.TeleportSafeZoneBtn = createHubButton(CombatList, "Teleport To Safe Zone", "Instant safe zone TP")

UI.ClearESPBtn = createHubButton(CombatList, "Clear All ESP", "Remove highlights & billboards")

UI.BloodManipToggle = createHubButton(CombatList, "Blood Manipulator Kill", "Hold E on head · stays locked until release")
setHubToggle(UI.BloodManipToggle, false)

local TrollScroll = Instance.new("ScrollingFrame")
TrollScroll.Size = UDim2.new(1, 0, 1, 0)
TrollScroll.BackgroundTransparency = 1
TrollScroll.BorderSizePixel = 0
TrollScroll.ScrollBarThickness = 5
TrollScroll.ScrollBarImageColor3 = COLORS.border
TrollScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
TrollScroll.Parent = TrollPage

local TrollList = Instance.new("Frame")
TrollList.Size = UDim2.new(1, 0, 0, 420)
TrollList.BackgroundTransparency = 1
TrollList.Parent = TrollScroll

local TrollLayout = Instance.new("UIListLayout")
TrollLayout.Padding = UDim.new(0, 8)
TrollLayout.Parent = TrollList

TrollLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    TrollList.Size = UDim2.new(1, 0, 0, TrollLayout.AbsoluteContentSize.Y)
    TrollScroll.CanvasSize = UDim2.new(0, 0, 0, TrollLayout.AbsoluteContentSize.Y + 8)
end)

UI.SpinToggle = createHubButton(TrollList, "Spin Bot", "Spin your character constantly")
setHubToggle(UI.SpinToggle, false)

UI.DesyncToggle = createHubButton(TrollList, "Desync", "Server marker + client label · hold E to interact")
setHubToggle(UI.DesyncToggle, false)

UI.FlingHomelanderBtn = createHubButton(TrollList, "Fling Homelander", "SkidFling overlap · needs collision")

UI.FlingSelfBtn = createHubButton(TrollList, "Fling Self", "Launch yourself into the air")

UI.TpRandomBtn = createHubButton(TrollList, "TP To Random Player", "Teleport to a random player")

UI.TpAllToMeBtn = createHubButton(TrollList, "Bring Players To You", "Pull nearby players to you")

UI.AnnoySoundBtn = createHubButton(TrollList, "Play Loud Sound", "Play an annoying sound locally")

UI.ResetTrollBtn = createHubButton(TrollList, "Reset Troll Effects", "Turn off spin & desync")

local MiscScroll = Instance.new("ScrollingFrame")
MiscScroll.Size = UDim2.new(1, 0, 1, 0)
MiscScroll.BackgroundTransparency = 1
MiscScroll.BorderSizePixel = 0
MiscScroll.ScrollBarThickness = 5
MiscScroll.ScrollBarImageColor3 = COLORS.border
MiscScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
MiscScroll.Parent = MiscPage

local MiscList = Instance.new("Frame")
MiscList.Size = UDim2.new(1, 0, 0, 200)
MiscList.BackgroundTransparency = 1
MiscList.Parent = MiscScroll

local MiscLayout = Instance.new("UIListLayout")
MiscLayout.Padding = UDim.new(0, 8)
MiscLayout.Parent = MiscList

MiscLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    MiscList.Size = UDim2.new(1, 0, 0, MiscLayout.AbsoluteContentSize.Y)
    MiscScroll.CanvasSize = UDim2.new(0, 0, 0, MiscLayout.AbsoluteContentSize.Y + 8)
end)

local _, SpectateBody = createMiscFold(MiscList, "Spectate", true)

local MiscSubLabel = Instance.new("TextLabel")
MiscSubLabel.Size = UDim2.new(1, 0, 0, 18)
MiscSubLabel.BackgroundTransparency = 1
MiscSubLabel.Text = "Select a player below · spectate or fling"
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
applyCorner(UI.SpectateSelectedLabel, RADIUS.md)
applyStroke(UI.SpectateSelectedLabel, COLORS.border, 1, 0.7)

local SpectateSelectedPad = Instance.new("UIPadding")
SpectateSelectedPad.PaddingLeft = UDim.new(0, 12)
SpectateSelectedPad.Parent = UI.SpectateSelectedLabel

UI.SpectatePlayerScroll = Instance.new("ScrollingFrame")
UI.SpectatePlayerScroll.Size = UDim2.new(1, 0, 0, 180)
UI.SpectatePlayerScroll.BackgroundColor3 = COLORS.surface
UI.SpectatePlayerScroll.BorderSizePixel = 0
UI.SpectatePlayerScroll.ScrollBarThickness = 4
UI.SpectatePlayerScroll.ScrollBarImageColor3 = COLORS.border
UI.SpectatePlayerScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
UI.SpectatePlayerScroll.Parent = SpectateBody
applyCorner(UI.SpectatePlayerScroll, RADIUS.md)
applyStroke(UI.SpectatePlayerScroll, COLORS.border, 1, 0.65)

UI.SpectatePlayerList = Instance.new("Frame")
UI.SpectatePlayerList.Size = UDim2.new(1, -12, 0, 0)
UI.SpectatePlayerList.Position = UDim2.new(0, 6, 0, 6)
UI.SpectatePlayerList.BackgroundTransparency = 1
UI.SpectatePlayerList.Parent = UI.SpectatePlayerScroll

local SpectatePlayerLayout = Instance.new("UIListLayout")
SpectatePlayerLayout.Padding = UDim.new(0, 6)
SpectatePlayerLayout.Parent = UI.SpectatePlayerList

SpectatePlayerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    UI.SpectatePlayerList.Size = UDim2.new(1, -12, 0, SpectatePlayerLayout.AbsoluteContentSize.Y)
    UI.SpectatePlayerScroll.CanvasSize = UDim2.new(0, 0, 0, SpectatePlayerLayout.AbsoluteContentSize.Y + 12)
end)

UI.RefreshSpectateListBtn = createHubButton(SpectateBody, "Refresh Player List", "Update online players")
UI.SpectateBtn = createHubButton(SpectateBody, "Spectate", "Right-drag orbit · scroll zoom")
UI.StopSpectateBtn = createHubButton(SpectateBody, "Stop Spectate", "Return camera to you")

local _, FlingBody = createMiscFold(MiscList, "Fling", false)

UI.FlingSelectedBtn = createHubButton(FlingBody, "Fling Selected", "SkidFling · turn off noclip/desync first")

local _, FreecamBody = createMiscFold(MiscList, "Freecam", false)

UI.FreecamToggle = createHubButton(FreecamBody, "Freecam", "WASD move · right-drag look · scroll speed")
setHubToggle(UI.FreecamToggle, false)

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

local _, EffectsBody = createMiscFold(MiscList, "Effects", false)

UI.RemoveBloodManipEffectsToggle = createHubButton(
    EffectsBody,
    "Remove Blood Manipulator Effects",
    "Blocks red screen overlay & forced zoom"
)
setHubToggle(UI.RemoveBloodManipEffectsToggle, false)

local SettingsScroll = Instance.new("ScrollingFrame")
SettingsScroll.Size = UDim2.new(1, 0, 1, 0)
SettingsScroll.BackgroundTransparency = 1
SettingsScroll.BorderSizePixel = 0
SettingsScroll.ScrollBarThickness = 5
SettingsScroll.ScrollBarImageColor3 = COLORS.border
SettingsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
SettingsScroll.Parent = SettingsPage

local SettingsList = Instance.new("Frame")
SettingsList.Size = UDim2.new(1, 0, 0, 220)
SettingsList.BackgroundTransparency = 1
SettingsList.Parent = SettingsScroll

local SettingsLayout = Instance.new("UIListLayout")
SettingsLayout.Padding = UDim.new(0, 8)
SettingsLayout.Parent = SettingsList

SettingsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    SettingsList.Size = UDim2.new(1, 0, 0, SettingsLayout.AbsoluteContentSize.Y)
    SettingsScroll.CanvasSize = UDim2.new(0, 0, 0, SettingsLayout.AbsoluteContentSize.Y + 8)
end)

UI.ToggleSizeSlider, UI.setToggleSizeSliderValue = createHubSlider(
    SettingsList,
    "Toggle Button Size",
    24,
    72,
    State.toggleCubeSize,
    function(value)
        applyToggleCubeSize(value)
    end
)

UI.ResetTogglePosBtn = createHubButton(SettingsList, "Reset Toggle Position", "Move cube back to top-left")

UI.SwappedMouseToggle = createHubButton(
    SettingsList,
    "Right-Click Primary Mouse",
    "Use if your mouse buttons are swapped"
)
setHubToggle(UI.SwappedMouseToggle, true)

switchTab("Home")

State.autoRefreshEnabled = true
State.homelanderESPEnabled = false
State.teamESPEnabled = false
State.tempVHighlightEnabled = false
State.aimbotEnabled = false

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
State.removeBloodManipEffects = false
State.bloodEffectSavedFov = 70
State.bloodEffectSavedMaxZoom = 128
State.bloodEffectSavedMinZoom = 0.5
State.bloodEffectBlockConnections = {}
State.bloodEffectTracked = {}
State.bloodEffectRestoringCamera = false
State.swappedMouseButtons = true
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

local function clearHighlight(plr)
    if State.highlights[plr] then
        State.highlights[plr]:Destroy()
        State.highlights[plr] = nil
    end
    if State.billboards[plr] then
        State.billboards[plr].gui:Destroy()
        State.billboards[plr] = nil
    end
end

local function createPlayerESP(plr, color, isHomelander)
    if not plr.Character then return end
    
    clearHighlight(plr)
    
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
            txt.Font = Enum.Font.GothamBold
            txt.TextSize = isHomelander and 18 or 16
            txt.Parent = bb

            State.billboards[plr] = {gui = bb, label = txt}
        end
    end)
    
    if not success then
        warn("Failed to create ESP for", plr.Name)
    end
end

-- Utility Functions
local SCRIPT_GUI_NAMES = {
    ScriptHub = true,
    ScriptHubToggle = true,
    ScriptHubMobileAim = true,
}

local function isScriptOwnedGui(obj)
    if not obj then return false end
    if obj:GetAttribute("ScriptHubESP") then return true end
    local gui = obj:IsA("ScreenGui") and obj or obj:FindFirstAncestorOfClass("ScreenGui")
    return gui and SCRIPT_GUI_NAMES[gui.Name] == true
end

local function isOtherPlayer(plr)
    return plr and plr ~= player
end

local KILLER_ROLES = {"HOMELANDER", "STORMFRONT"}

local function getKillerRoleFromText(text)
    if type(text) ~= "string" or text == "" then return nil end
    local upper = text:upper()
    for _, role in ipairs(KILLER_ROLES) do
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

local function textHasKillerRole(text)
    return getKillerRoleFromText(text) ~= nil
end

local function textHasHomelanderRole(text)
    return textHasKillerRole(text)
end

local function isKillerRoleName(name)
    if not name or name == "" then return false end
    local upper = name:upper()
    for _, role in ipairs(KILLER_ROLES) do
        if upper == role then
            return true
        end
    end
    return false
end

local function playerFromCharacterModel(model)
    if not model then return nil end
    for _, plr in pairs(Players:GetPlayers()) do
        if plr.Character == model then
            return plr
        end
    end
    return Players:GetPlayerFromCharacter(model)
end

local function nameLooksLikeHomelander(name)
    if not name or name == "" then return false end
    return textHasHomelanderRole(name)
end

local function instanceShowsHomelanderRole(obj)
    if not obj then return false end

    if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
        return textHasKillerRole(obj.Text)
    end
    if obj:IsA("StringValue") then
        return textHasKillerRole(obj.Value) or isKillerRoleName(obj.Value)
    end

    return false
end

local function characterHasHomelanderTag(character)
    if not character then return false end

    local tagged = false
    pcall(function()
        for _, tag in ipairs(CollectionService:GetTags(character)) do
            if isKillerRoleName(tag) or textHasKillerRole(tag) then
                tagged = true
                break
            end
        end
    end)
    return tagged
end

local function matchPlayerAndRoleFromText(text)
    local role = getKillerRoleFromText(text)
    if not role then return nil, nil end

    local roleTag = "%[" .. role .. "%]"
    local parsedName = text:match("Spectating:%s*(.-)%s*<%s*" .. roleTag)
        or text:match("Spectating:%s*(.-)X" .. roleTag)
        or text:match("Spectating:%s*(.-)" .. roleTag)
    if parsedName then
        parsedName = parsedName:gsub("X$", ""):gsub("[%s<]+$", ""):gsub("%s+$", "")
        for _, plr in pairs(Players:GetPlayers()) do
            if isOtherPlayer(plr) then
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
        if isOtherPlayer(plr) then
            for _, checkRole in ipairs(KILLER_ROLES) do
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

local function matchPlayerFromText(text)
    local matchedPlayer = matchPlayerAndRoleFromText(text)
    return matchedPlayer
end

local function findHomelanderFromSpectateUI()
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return nil, nil end

    for _, obj in pairs(playerGui:GetDescendants()) do
        if not isScriptOwnedGui(obj)
            and (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then
            local text = obj.Text
            if text and textHasKillerRole(text) then
                local matched, role = matchPlayerAndRoleFromText(text)
                if isOtherPlayer(matched) then
                    return matched, role
                end
            end
        end
    end

    return nil, nil
end

local function attributeLooksLikeHomelander(obj)
    if not obj then return false end
    for _, attrName in ipairs({
        "Role", "Character", "Hero", "Class", "Identity",
        "CurrentRole", "RoleName", "TeamRole", "IsHomelander", "SelectedHero",
    }) do
        local value = obj:GetAttribute(attrName)
        if value and isKillerRoleName(tostring(value)) then
            return true
        end
    end
    return false
end

local function getKillerRoleForPlayer(plr)
    if not isOtherPlayer(plr) then return nil end

    for _, container in ipairs({plr, plr.Character}) do
        if container then
            for _, attrName in ipairs({
                "Role", "Character", "Hero", "Class", "Identity",
                "CurrentRole", "RoleName", "TeamRole", "SelectedHero",
            }) do
                local value = container:GetAttribute(attrName)
                if value and isKillerRoleName(tostring(value)) then
                    return tostring(value):upper()
                end
            end
        end
    end

    if plr.Team and isKillerRoleName(plr.Team.Name) then
        return plr.Team.Name:upper()
    end

    local character = plr.Character
    if character then
        for _, obj in pairs(character:GetDescendants()) do
            if not isScriptOwnedGui(obj) then
                local role = getKillerRoleFromText(
                    obj:IsA("TextLabel") and obj.Text
                    or obj:IsA("StringValue") and obj.Value
                    or ""
                )
                if role then return role end
                if obj:IsA("StringValue") and isKillerRoleName(obj.Value) then
                    return obj.Value:upper()
                end
            end
        end
    end

    return nil
end

local function findHomelanderFromOverheadTags()
    for _, plr in pairs(Players:GetPlayers()) do
        if isOtherPlayer(plr) and plr.Character then
            if characterHasHomelanderTag(plr.Character) or attributeLooksLikeHomelander(plr.Character) then
                return plr
            end

            for _, obj in pairs(plr.Character:GetDescendants()) do
                if not isScriptOwnedGui(obj) then
                    if obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
                        for _, child in pairs(obj:GetDescendants()) do
                            if instanceShowsHomelanderRole(child) then
                                return plr
                            end
                        end
                    end
                    if instanceShowsHomelanderRole(obj) or attributeLooksLikeHomelander(obj) then
                        return plr
                    end
                end
            end
        end
    end

    return nil
end

local function findHomelanderFromLeaderstats()
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= player then
            for _, child in pairs(plr:GetChildren()) do
                if child.Name:lower():find("leader") or child.Name:lower():find("stats") then
                    for _, stat in pairs(child:GetDescendants()) do
                        if instanceShowsHomelanderRole(stat) or attributeLooksLikeHomelander(stat) then
                            return plr
                        end
                    end
                end
            end

            if plr.Team and textHasKillerRole(plr.Team.Name) then
                return plr
            end
        end
    end

    return nil
end

local function hasExplicitHomelanderRole(plr)
    if not isOtherPlayer(plr) then return false end

    local success, result = pcall(function()
        if attributeLooksLikeHomelander(plr) then
            return true
        end

        for _, obj in pairs(plr:GetDescendants()) do
            if instanceShowsHomelanderRole(obj) or attributeLooksLikeHomelander(obj) then
                return true
            end
        end

        local character = plr.Character
        if not character then return false end

        if attributeLooksLikeHomelander(character) or characterHasHomelanderTag(character) then
            return true
        end

        for _, obj in pairs(character:GetDescendants()) do
            if instanceShowsHomelanderRole(obj) or attributeLooksLikeHomelander(obj) then
                return true
            end
        end

        return false
    end)

    return success and result
end

local function isPlayerHomelander(plr)
    return hasExplicitHomelanderRole(plr)
end

local function resolveHomelanderTarget()
    if not State.homelanderESPEnabled then
        State.detectedKillerRole = nil
        return nil
    end

    local spectateTarget, spectateRole = findHomelanderFromSpectateUI()
    if isOtherPlayer(spectateTarget) then
        State.detectedKillerRole = spectateRole or getKillerRoleForPlayer(spectateTarget) or "KILLER"
        return spectateTarget
    end

    local overheadTarget = findHomelanderFromOverheadTags()
    if isOtherPlayer(overheadTarget) then
        State.detectedKillerRole = getKillerRoleForPlayer(overheadTarget) or "KILLER"
        return overheadTarget
    end

    local leaderTarget = findHomelanderFromLeaderstats()
    if isOtherPlayer(leaderTarget) then
        State.detectedKillerRole = getKillerRoleForPlayer(leaderTarget) or "KILLER"
        return leaderTarget
    end

    for _, plr in pairs(Players:GetPlayers()) do
        if isOtherPlayer(plr) and hasExplicitHomelanderRole(plr) then
            State.detectedKillerRole = getKillerRoleForPlayer(plr) or "KILLER"
            return plr
        end
    end

    State.detectedKillerRole = nil
    return nil
end

local function setHomelanderTarget(newTarget)
    if newTarget == player then
        newTarget = nil
    end
    if newTarget and not State.detectedKillerRole then
        State.detectedKillerRole = getKillerRoleForPlayer(newTarget) or "KILLER"
    end
    if not newTarget then
        State.detectedKillerRole = nil
    end
    if newTarget == State.firstHomelander then
        if State.firstHomelander and State.firstHomelander.Character
            and State.firstHomelander.Character:FindFirstChild("HumanoidRootPart")
            and not State.highlights[State.firstHomelander] then
            createPlayerESP(State.firstHomelander, Color3.fromRGB(255, 50, 50), true)
        end
        return
    end

    if State.firstHomelander then
        clearHighlight(State.firstHomelander)
    end

    State.firstHomelander = newTarget

    if State.firstHomelander then
        UI.StatusHomelander.StateLabel.Text = (State.detectedKillerRole or "KILLER") .. " · " .. State.firstHomelander.Name:upper()
        UI.StatusHomelander.StateLabel.TextColor3 = COLORS.danger
    else
        UI.StatusHomelander.StateLabel.Text = "NONE"
        UI.StatusHomelander.StateLabel.TextColor3 = COLORS.textMuted
    end

    if State.firstHomelander and State.firstHomelander.Character
        and State.firstHomelander.Character:FindFirstChild("HumanoidRootPart") then
        createPlayerESP(State.firstHomelander, Color3.fromRGB(255, 50, 50), true)
    end
end

State.scanForHomelander = function()
    if not State.homelanderESPEnabled then
        setHomelanderTarget(nil)
        return
    end

    setHomelanderTarget(resolveHomelanderTarget())
end

local function getHumanoid()
    local character = player.Character
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
    local character = player.Character
    return character and character:FindFirstChild("HumanoidRootPart")
end

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
    label.Font = Enum.Font.GothamBold
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
    if State.flingInProgress then return end
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

local function updateFlight()
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
            applyWalkSpeedStat(humanoid)
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
        end)
    end

    local moveDirection = Vector3.zero
    local lookVector = cam.CFrame.LookVector
    local rightVector = cam.CFrame.RightVector

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        moveDirection += lookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
        moveDirection -= lookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
        moveDirection -= rightVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
        moveDirection += rightVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        moveDirection += Vector3.new(0, 1, 0)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
        or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
        moveDirection -= Vector3.new(0, 1, 0)
    end

    pcall(function()
        if moveDirection.Magnitude > 0 then
            moveDirection = moveDirection.Unit
        end

        hrp.AssemblyLinearVelocity = moveDirection * State.flightSpeed
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
        end)
    end
    if hrp then
        removeFlightPhysics(hrp)
        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)
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

State.__bundleA = {
    clearHighlight = clearHighlight,
    createPlayerESP = createPlayerESP,
    updateMovementHacks = updateMovementHacks,
    updateFlight = updateFlight,
    setNoclip = setNoclip,
    getHumanoid = getHumanoid,
    getRoot = getRoot,
    updateSpeedHack = updateSpeedHack,
    isPlayerHomelander = isPlayerHomelander,
    setHubToggle = setHubToggle,
    resetMovementSettings = resetMovementSettings,
    stopDesyncEngine = stopDesyncEngine,
    setDesync = setDesync,
    setupCharacterMovement = setupCharacterMovement,
    applyJumpBoost = applyJumpBoost,
    applyJumpStats = applyJumpStats,
    applyMovementStatsNow = applyMovementStatsNow,
    stopFlight = stopFlight,
    findHomelanderFromSpectateUI = findHomelanderFromSpectateUI,
    findHomelanderFromOverheadTags = findHomelanderFromOverheadTags,
    findHomelanderFromLeaderstats = findHomelanderFromLeaderstats,
    getKillerRoleForPlayer = getKillerRoleForPlayer,
    hasExplicitHomelanderRole = hasExplicitHomelanderRole,
}

end -- scope block 1 (Luau local register limit)

do

local A = State.__bundleA
local getRoot = A.getRoot
local getHumanoid = A.getHumanoid
local setHubToggle = A.setHubToggle
local setDesync = A.setDesync
local findHomelanderFromSpectateUI = A.findHomelanderFromSpectateUI
local findHomelanderFromOverheadTags = A.findHomelanderFromOverheadTags
local findHomelanderFromLeaderstats = A.findHomelanderFromLeaderstats
local getKillerRoleForPlayer = A.getKillerRoleForPlayer
local hasExplicitHomelanderRole = A.hasExplicitHomelanderRole

local function findHomelanderPlayer()
    local spectateTarget, spectateRole = findHomelanderFromSpectateUI()
    if spectateTarget and spectateTarget.Character
        and spectateTarget.Character:FindFirstChild("HumanoidRootPart") then
        State.detectedKillerRole = spectateRole or getKillerRoleForPlayer(spectateTarget) or State.detectedKillerRole
        return spectateTarget
    end

    local overheadTarget = findHomelanderFromOverheadTags()
    if overheadTarget and overheadTarget.Character
        and overheadTarget.Character:FindFirstChild("HumanoidRootPart") then
        return overheadTarget
    end

    local leaderTarget = findHomelanderFromLeaderstats()
    if leaderTarget and leaderTarget.Character
        and leaderTarget.Character:FindFirstChild("HumanoidRootPart") then
        return leaderTarget
    end

    if State.firstHomelander and State.firstHomelander.Character
        and State.firstHomelander.Character:FindFirstChild("HumanoidRootPart") then
        return State.firstHomelander
    end

    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= player and hasExplicitHomelanderRole(plr)
            and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            return plr
        end
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
        removeFlightPhysics(rootPart)
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
        warn("[NightFall] Fling missed — turn off Noclip/Desync and try again")
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

local function bringPlayersToMe()
    local hrp = getRoot()
    if not hrp then return end
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            pcall(function()
                local targetHrp = plr.Character.HumanoidRootPart
                local offset = Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
                targetHrp.CFrame = hrp.CFrame * CFrame.new(offset)
            end)
        end
    end
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

State.__bundleA.updateSpin = updateSpin
State.__bundleA.flingHomelander = flingHomelander
State.__bundleA.skidFlingPlayer = skidFlingPlayer
State.__bundleA.flingSelf = flingSelf
State.__bundleA.tpRandomPlayer = tpRandomPlayer
State.__bundleA.bringPlayersToMe = bringPlayersToMe
State.__bundleA.playAnnoyingSound = playAnnoyingSound
State.__bundleA.resetTrollEffects = resetTrollEffects

end -- scope block 1d (fling/troll · Luau local register limit)

do

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
        cam.CameraType = Enum.CameraType.Scriptable
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
            task.wait(0.25)
            updateSpectateCamera()
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
            btn.Text = plr.DisplayName .. "  ·  @" .. plr.Name
            btn.TextColor3 = State.spectateSelected == plr and COLORS.accentLight or COLORS.text
            btn.Font = Enum.Font.GothamSemibold
            btn.TextSize = 12
            btn.AutoButtonColor = false
            btn.Parent = UI.SpectatePlayerList
            applyCorner(btn, RADIUS.sm)

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

            btn.MouseButton1Click:Connect(function()
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

State.__bundleA.stopSpectate = stopSpectate
State.__bundleA.startSpectate = startSpectate
State.__bundleA.refreshMiscPlayerList = refreshMiscPlayerList
State.__bundleA.updateSpectateCamera = updateSpectateCamera

end -- scope block 1c (spectate · Luau local register limit)

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
        txt.Font = Enum.Font.GothamBold
        txt.TextSize = 16
        txt.Text = "⚡ TempV\n[Calculating...]"
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
                    data.label.Text = "⚡ TempV\n📍 " .. math.floor(dist) .. " studs"
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

local function onTempVPickedUp(model)
    if not State.trackedTempVModels[model] then return end
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
                    applyCorner(btn, RADIUS.md)
                    applyStroke(btn, COLORS.border, 1, 0.7)

                    local pos = primary.Position
                    local dist = root and math.floor((root.Position - pos).Magnitude) or "?"
                    
                    btn.Text = string.format("  TempV #%d\n  [%d, %d, %d]  ·  %s studs",
                        found + 1,
                        math.floor(pos.X),
                        math.floor(pos.Y),
                        math.floor(pos.Z),
                        tostring(dist)
                    )

                    btn.MouseButton1Click:Connect(function()
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

State.__bundle = {}
for key, value in pairs(State.__bundleA) do
    State.__bundle[key] = value
end
State.__bundle.updateTempVESP = updateTempVESP
State.__bundle.clearAllTempVHighlights = clearAllTempVHighlights
State.__bundle.clearAllTempVBillboards = clearAllTempVBillboards
State.__bundle.onTempVPickedUp = onTempVPickedUp

do -- scope block 2 (Luau local register limit)
local F = State.__bundle
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
local bringPlayersToMe = F.bringPlayersToMe
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

    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        move = move + cf.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
        move = move - cf.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
        move = move - cf.RightVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
        move = move + cf.RightVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        move = move + Vector3.yAxis
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
        or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
        move = move - Vector3.yAxis
    end

    if move.Magnitude > 0 then
        cf = cf + move.Unit * speed * dt
    end

    State.freecamCFrame = cf
    State.freecamYaw = yaw
    State.freecamPitch = pitch
    cam.CFrame = cf
end

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

    local targetPlayer = nil

    pcall(function()
        local mousePos = UserInputService:GetMouseLocation()
        local ray = cam:ViewportPointToRay(mousePos.X, mousePos.Y)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Blacklist
        params.FilterDescendantsInstances = filter

        local result = Workspace:Raycast(ray.Origin, ray.Direction * 250, params)
        if result and result.Instance and result.Instance.Name == "Head" then
            targetPlayer = getPlayerFromCharacterPart(result.Instance)
        end
    end)

    if targetPlayer and targetPlayer ~= player then
        return targetPlayer
    end

    pcall(function()
        local mousePos = UserInputService:GetMouseLocation()
        local closest, closestDist = nil, 120

        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character and plr.Character:FindFirstChild("Head") then
                local head = plr.Character.Head
                local screenPos, onScreen = cam:WorldToViewportPoint(head.Position)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
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
    clearBloodManipHighlight()
end

local function executeBloodManipKill(targetPlayer)
    if State.bloodManipExecuting or not targetPlayer then return end

    State.bloodManipExecuting = true
    task.spawn(function()
        local hrp = getRoot()
        local targetChar = targetPlayer.Character
        local targetHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")

        if not hrp or not targetHrp then
            State.bloodManipExecuting = false
            return
        end

        local returnCFrame = hrp.CFrame
        local behindPos = targetHrp.Position - targetHrp.CFrame.LookVector * 4.5

        pcall(function()
            hrp.CFrame = CFrame.new(behindPos, targetHrp.Position)
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)

        task.wait(0.60)

        pcall(function()
            hrp.CFrame = returnCFrame
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
        end)

        State.bloodManipExecuting = false
        if not State.holdingBloodManipKey then
            resetBloodManipState()
        else
            State.bloodManipWalkAwayStart = nil
            State.bloodManipLockPos = targetHrp.Position
        end
    end)
end

local function updateBloodManipulator()
    if not State.bloodManipEnabled or State.bloodManipExecuting then return end

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

    if State.bloodManipLockPos then
        local movedAway = (targetHrp.Position - State.bloodManipLockPos).Magnitude >= 5
        if movedAway and not State.bloodManipWalkAwayStart then
            State.bloodManipWalkAwayStart = tick()
        end

        if State.bloodManipWalkAwayStart
            and tick() - State.bloodManipWalkAwayStart >= 4.3 then
            executeBloodManipKill(targetPlayer)
        end
    end
end

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
                local healthText = health and ("\n❤️ " .. math.floor(health.Health) .. "/" .. math.floor(health.MaxHealth)) or ""
                local roleLabel = State.detectedKillerRole or "KILLER"
                data.label.Text = string.format("⚠️ %s ⚠️\n[%s]\n🎯 %d studs%s", 
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
                        data.label.Text = string.format("🟢 %s\n🎯 %d studs", 
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

local function getMouseClosestTarget(useScreenCenter)
    local mousePos
    if useScreenCenter and camera then
        local viewport = camera.ViewportSize
        mousePos = Vector2.new(viewport.X / 2, viewport.Y / 2)
    else
        mousePos = UserInputService:GetMouseLocation()
    end
    local closest, closestDist = nil, math.huge
    
    pcall(function()
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character and plr.Character:FindFirstChild("Head") then
                local head = plr.Character.Head
                local screenPos, onScreen = camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closest = plr
                    end
                end
            end
        end
    end)
    
    return closest
end

-- Input Handling
bindConnection(UserInputService.InputBegan:Connect(function(input, gp)
    if beginCameraDrag(input) then
        return
    end

    if not gp and input.UserInputType == Enum.UserInputType.MouseButton2 then
        if State.freecamEnabled or State.spectating then
            return
        end
        State.holdingRightClick = true
        return
    end

    if gp then return end

    if input.KeyCode == Enum.KeyCode.E and State.bloodManipEnabled then
        State.holdingBloodManipKey = true
    elseif input.KeyCode == Enum.KeyCode.R then
        State.aimbotEnabled = not State.aimbotEnabled
        setHubToggle(UI.AimbotToggle, State.aimbotEnabled)
        if State.isMobile and UI.MobileAimBtn then
            UI.MobileAimBtn.Visible = State.aimbotEnabled
        end
    end
end))

bindConnection(UserInputService.InputEnded:Connect(function(input)
    endCameraDrag(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        State.holdingRightClick = false
    elseif input.KeyCode == Enum.KeyCode.E then
        State.holdingBloodManipKey = false
        if not State.bloodManipExecuting then
            resetBloodManipState()
        end
    end
end))

bindConnection(UserInputService.InputChanged:Connect(function(input, gp)
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
bindConnection(RunService.RenderStepped:Connect(function(dt)
    if State.ejected then return end

    updateFreecam(dt)
    if State.spectating then
        updateSpectateCamera()
    end
    updateBloodManipulator()
    updateBloodManipEffectBlock()
    updatePlayerESP()
    updateTempVESP()
    updateMovementHacks()
    updateFlight()
    updateSpin(dt)

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
    
    -- Aimbot logic
    local aiming = State.holdingRightClick or State.holdingMobileAim
    if State.aimbotEnabled and aiming and root and camera
        and not State.freecamEnabled and not State.spectating then
        pcall(function()
            local useCenter = State.holdingMobileAim
            local isUserHomelander = isPlayerHomelander(player)
            local target = isUserHomelander and getMouseClosestTarget(useCenter)
                or (State.firstHomelander or getMouseClosestTarget(useCenter))
            
            if target and target.Character and target.Character:FindFirstChild("Head") then
                local headPos = target.Character.Head.Position
                local direction = (headPos - camera.CFrame.Position).Unit
                camera.CFrame = CFrame.lookAt(camera.CFrame.Position, camera.CFrame.Position + direction)
            end
        end)
    end
end))

bindConnection(RunService.Heartbeat:Connect(function()
    if State.ejected then return end
    if not State.speedEnabled or State.flightEnabled then return end
    local humanoid = getHumanoid()
    local hrp = getRoot()
    if humanoid and hrp then
        updateSpeedHack(humanoid, hrp)
    end
end))

bindConnection(UserInputService.JumpRequest:Connect(function()
    local humanoid = getHumanoid()
    local hrp = getRoot()
    if not humanoid or not hrp then return end

    if State.jumpEnabled then
        applyJumpStats(humanoid)
        task.defer(function()
            if State.jumpEnabled then
                applyJumpBoost(getRoot())
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
    pcall(function()
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end)
    pcall(stopDesyncEngine)

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

UI.CloseBtn.MouseButton1Click:Connect(function()
    ejectScript()
end)

UI.HomelanderESPToggle.MouseButton1Click:Connect(function()
    State.homelanderESPEnabled = not State.homelanderESPEnabled
    setHubToggle(UI.HomelanderESPToggle, State.homelanderESPEnabled)
    refreshPlayerESPScan()
end)

UI.TeamESPToggle.MouseButton1Click:Connect(function()
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

UI.TempVHighlightToggle.MouseButton1Click:Connect(function()
    State.tempVHighlightEnabled = not State.tempVHighlightEnabled
    setHubToggle(UI.TempVHighlightToggle, State.tempVHighlightEnabled)
    
    if not State.tempVHighlightEnabled then
        clearAllTempVHighlights()
        clearAllTempVBillboards()
    else
        State.scanTempVParts()
    end
end)

UI.AimbotToggle.MouseButton1Click:Connect(function()
    State.aimbotEnabled = not State.aimbotEnabled
    setHubToggle(UI.AimbotToggle, State.aimbotEnabled)
    if State.isMobile and UI.MobileAimBtn then
        UI.MobileAimBtn.Visible = State.aimbotEnabled
    end
end)

UI.MobileAimDragToggle.MouseButton1Click:Connect(function()
    State.mobileAimDragUnlocked = not State.mobileAimDragUnlocked
    setHubToggle(UI.MobileAimDragToggle, State.mobileAimDragUnlocked, "UNLOCKED", "LOCKED")
    local subLabel = UI.MobileAimDragToggle:FindFirstChild("SubLabel")
    if subLabel then
        subLabel.Text = State.mobileAimDragUnlocked
            and "Drag the AIM button anywhere, then lock it"
            or "Hold the AIM button to aim on mobile"
    end
    UI.MobileAimBtn.Text = State.mobileAimDragUnlocked and "DRAG" or "AIM"
    if not State.mobileAimDragUnlocked then
        saveAimButtonPos(UI.MobileAimBtn.Position)
    end
end)

UI.TeleportHomelanderBtn.MouseButton1Click:Connect(function()
    if State.firstHomelander and State.firstHomelander.Character and State.firstHomelander.Character:FindFirstChild("HumanoidRootPart") and root then
        pcall(function()
            local targetPos = State.firstHomelander.Character.HumanoidRootPart.Position
            root.CFrame = CFrame.new(targetPos + Vector3.new(0, 5, 0))
        end)
    else
        warn("No Homelander found! Enable Homelander ESP first.")
    end
end)

UI.TeleportSafeZoneBtn.MouseButton1Click:Connect(function()
    if root then
        pcall(function()
            -- Teleport to safe zone coordinates
            root.CFrame = CFrame.new(293.305176, 20.5998001, -228.570312)
        end)
    else
        warn("Character not loaded!")
    end
end)

UI.AutoRefreshToggle.MouseButton1Click:Connect(function()
    State.autoRefreshEnabled = not State.autoRefreshEnabled
    setHubToggle(UI.AutoRefreshToggle, State.autoRefreshEnabled)
    UI.StatusScan.StateLabel.Text = State.autoRefreshEnabled and "ON" or "OFF"
    UI.StatusScan.StateLabel.TextColor3 = State.autoRefreshEnabled and COLORS.accent or COLORS.textMuted
    if State.autoRefreshEnabled then
        State.scanTempVParts()
    end
end)

UI.RefreshNowBtn.MouseButton1Click:Connect(function()
    State.scanTempVParts()
end)

UI.SpeedToggle.MouseButton1Click:Connect(function()
    State.speedEnabled = not State.speedEnabled
    setHubToggle(UI.SpeedToggle, State.speedEnabled)
    applyMovementStatsNow()
end)

UI.JumpToggle.MouseButton1Click:Connect(function()
    State.jumpEnabled = not State.jumpEnabled
    setHubToggle(UI.JumpToggle, State.jumpEnabled)
    applyMovementStatsNow()
end)

UI.FlightToggle.MouseButton1Click:Connect(function()
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

UI.NoclipToggle.MouseButton1Click:Connect(function()
    State.noclipEnabled = not State.noclipEnabled
    setHubToggle(UI.NoclipToggle, State.noclipEnabled)
    setNoclip(State.noclipEnabled)
end)

UI.InfJumpToggle.MouseButton1Click:Connect(function()
    State.infJumpEnabled = not State.infJumpEnabled
    setHubToggle(UI.InfJumpToggle, State.infJumpEnabled)
end)

UI.ResetMovementBtn.MouseButton1Click:Connect(function()
    resetMovementSettings()
end)

UI.ResetTogglePosBtn.MouseButton1Click:Connect(function()
    local defaultPos = UDim2.new(0, 10, 0, 10)
    UI.ToggleCube.Position = defaultPos
    saveTogglePos(defaultPos)
end)

UI.ResetTogglePosBtn.MouseButton1Click:Connect(function()
    local defaultPos = UDim2.new(0, 10, 0, 10)
    UI.ToggleCube.Position = defaultPos
    saveTogglePos(defaultPos)
end)

UI.SwappedMouseToggle.MouseButton1Click:Connect(function()
    State.swappedMouseButtons = not State.swappedMouseButtons
    setHubToggle(UI.SwappedMouseToggle, State.swappedMouseButtons)
end)

UI.SpinToggle.MouseButton1Click:Connect(function()
    State.spinEnabled = not State.spinEnabled
    setHubToggle(UI.SpinToggle, State.spinEnabled)
end)

UI.DesyncToggle.MouseButton1Click:Connect(function()
    setDesync(not State.desyncEnabled)
    setHubToggle(UI.DesyncToggle, State.desyncEnabled, "ON", "OFF")
end)

UI.RefreshSpectateListBtn.MouseButton1Click:Connect(function()
    refreshMiscPlayerList()
end)

UI.SpectateBtn.MouseButton1Click:Connect(function()
    if State.spectateSelected then
        stopFreecam()
        startSpectate(State.spectateSelected)
    else
        warn("[NightFall] Select a player from the list first.")
    end
end)

UI.StopSpectateBtn.MouseButton1Click:Connect(function()
    stopSpectate()
end)

UI.FlingSelectedBtn.MouseButton1Click:Connect(function()
    if State.spectateSelected then
        task.spawn(function()
            skidFlingPlayer(State.spectateSelected)
        end)
    else
        warn("[NightFall] Select a player from the list first.")
    end
end)

UI.FreecamToggle.MouseButton1Click:Connect(function()
    setFreecam(not State.freecamEnabled)
end)

UI.RemoveBloodManipEffectsToggle.MouseButton1Click:Connect(function()
    setRemoveBloodManipEffects(not State.removeBloodManipEffects)
end)

UI.BloodManipToggle.MouseButton1Click:Connect(function()
    State.bloodManipEnabled = not State.bloodManipEnabled
    setHubToggle(UI.BloodManipToggle, State.bloodManipEnabled)
    if not State.bloodManipEnabled then
        State.holdingBloodManipKey = false
        resetBloodManipState()
    end
end)

UI.FlingHomelanderBtn.MouseButton1Click:Connect(function()
    task.spawn(flingHomelander)
end)

UI.FlingSelfBtn.MouseButton1Click:Connect(function()
    flingSelf()
end)

UI.TpRandomBtn.MouseButton1Click:Connect(function()
    tpRandomPlayer()
end)

UI.TpAllToMeBtn.MouseButton1Click:Connect(function()
    bringPlayersToMe()
end)

UI.AnnoySoundBtn.MouseButton1Click:Connect(function()
    playAnnoyingSound()
end)

UI.ResetTrollBtn.MouseButton1Click:Connect(function()
    resetTrollEffects()
end)

UI.ClearESPBtn.MouseButton1Click:Connect(function()
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

-- Player ESP scan loop (every 5 seconds)
task.spawn(function()
    refreshPlayerESPScan()
    while UI.ScreenGui and UI.ScreenGui.Parent and not State.ejected do
        task.wait(5)
        refreshPlayerESPScan()
    end
end)

bindConnection(Players.PlayerAdded:Connect(function()
    refreshMiscPlayerList()
end))

bindConnection(Players.PlayerRemoving:Connect(function(leaving)
    if State.spectateTarget == leaving then
        stopSpectate()
    end
    if State.spectateSelected == leaving then
        State.spectateSelected = nil
    end
    refreshMiscPlayerList()
end))

-- Character respawn handler
bindConnection(player.CharacterAdded:Connect(function(character)
    task.spawn(function()
        setupCharacterMovement(character)
    end)
end))

if player.Character then
    task.spawn(function()
        setupCharacterMovement(player.Character)
    end)
end

task.defer(function()
    if State.autoRefreshEnabled then
        State.scanTempVParts()
    end
    refreshPlayerESPScan()
    refreshMiscPlayerList()
end)

end -- scope block 2 (Luau local register limit)

print("✅ NightFall loaded")
if State.isMobile then
    print("📱 Mobile mode: hold the AIM button to aim")
else
    print("🎮 Press R to toggle Aimbot | Right-click to aim")
end
print("💡 Top-left cube toggles the GUI | Close button ejects the script")
print("💡 Tabs: Scanner · Movement · Combat · Troll · Misc")
