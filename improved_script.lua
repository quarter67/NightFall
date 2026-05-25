-- IMPROVED SCRIPT - Bug Fixes & Enhanced GUI
-- TempV Scanner + Player ESP + Invisibility + Aimbot
-- Optimized and cleaned up version

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
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
    bg = Color3.fromRGB(36, 36, 40),
    surface = Color3.fromRGB(54, 54, 58),
    surfaceHover = Color3.fromRGB(64, 64, 68),
    tabActive = Color3.fromRGB(196, 196, 201),
    text = Color3.fromRGB(255, 255, 255),
    textDark = Color3.fromRGB(28, 28, 32),
    textMuted = Color3.fromRGB(160, 160, 168),
    accent = Color3.fromRGB(90, 200, 140),
    accentOn = Color3.fromRGB(70, 170, 255),
    danger = Color3.fromRGB(210, 75, 75),
    toggleCube = Color3.fromRGB(120, 90, 200),
}

local VALID_KEY = "QownsU"
local SESSION_PATH = "ScriptHub/run_count.txt"
local KEY_OK_PATH = "ScriptHub/key_ok.txt"
local AIM_POS_PATH = "ScriptHub/aim_btn_pos.txt"
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

local function shouldPromptForKey()
    if not fsRead(KEY_OK_PATH) then
        return true
    end
    local count = tonumber(fsRead(SESSION_PATH)) or 0
    return count >= 5
end

local function resetKeySessionCount()
    fsWrite(SESSION_PATH, "0")
    fsWrite(KEY_OK_PATH, "1")
end

local function incrementKeySessionCount()
    local count = tonumber(fsRead(SESSION_PATH)) or 0
    fsWrite(SESSION_PATH, tostring(count + 1))
    fsWrite(KEY_OK_PATH, "1")
end

local function showKeyPrompt()
    local accepted = false
    local finished = false

    local keyGui = Instance.new("ScreenGui")
    keyGui.Name = "ScriptHubKey"
    keyGui.ResetOnSpawn = false
    keyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    keyGui.Parent = CoreGui

    local backdrop = Instance.new("Frame")
    backdrop.Size = UDim2.new(1, 0, 1, 0)
    backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    backdrop.BackgroundTransparency = 0.35
    backdrop.BorderSizePixel = 0
    backdrop.Parent = keyGui

    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(0, 320, 0, 180)
    panel.Position = UDim2.new(0.5, -160, 0.5, -90)
    panel.BackgroundColor3 = COLORS.bg
    panel.BorderSizePixel = 0
    panel.Parent = keyGui

    local panelCorner = Instance.new("UICorner")
    panelCorner.CornerRadius = UDim.new(0, 12)
    panelCorner.Parent = panel

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -24, 0, 36)
    title.Position = UDim2.new(0, 12, 0, 12)
    title.BackgroundTransparency = 1
    title.Text = "Script Hub · Key Required"
    title.TextColor3 = COLORS.text
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = panel

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(1, -24, 0, 20)
    sub.Position = UDim2.new(0, 12, 0, 44)
    sub.BackgroundTransparency = 1
    sub.Text = "Enter your key to continue"
    sub.TextColor3 = COLORS.textMuted
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 13
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Parent = panel

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -24, 0, 36)
    box.Position = UDim2.new(0, 12, 0, 72)
    box.BackgroundColor3 = COLORS.surface
    box.TextColor3 = COLORS.text
    box.PlaceholderText = "Key..."
    box.PlaceholderColor3 = COLORS.textMuted
    box.Font = Enum.Font.GothamSemibold
    box.TextSize = 15
    box.ClearTextOnFocus = false
    box.Parent = panel

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 8)
    boxCorner.Parent = box

    local err = Instance.new("TextLabel")
    err.Size = UDim2.new(1, -24, 0, 16)
    err.Position = UDim2.new(0, 12, 0, 112)
    err.BackgroundTransparency = 1
    err.Text = ""
    err.TextColor3 = COLORS.danger
    err.Font = Enum.Font.Gotham
    err.TextSize = 12
    err.TextXAlignment = Enum.TextXAlignment.Left
    err.Parent = panel

    local submit = Instance.new("TextButton")
    submit.Size = UDim2.new(1, -24, 0, 36)
    submit.Position = UDim2.new(0, 12, 0, 132)
    submit.BackgroundColor3 = COLORS.accentOn
    submit.Text = "Submit"
    submit.TextColor3 = COLORS.text
    submit.Font = Enum.Font.GothamBold
    submit.TextSize = 15
    submit.AutoButtonColor = false
    submit.Parent = panel

    local submitCorner = Instance.new("UICorner")
    submitCorner.CornerRadius = UDim.new(0, 8)
    submitCorner.Parent = submit

    local function trySubmit()
        if box.Text == VALID_KEY then
            accepted = true
            finished = true
            resetKeySessionCount()
        else
            err.Text = "Invalid key"
        end
    end

    submit.MouseButton1Click:Connect(trySubmit)
    box.FocusLost:Connect(function(enter)
        if enter then
            trySubmit()
        end
    end)

    while not finished do
        task.wait()
    end

    keyGui:Destroy()
    return accepted
end

if shouldPromptForKey() then
    if not showKeyPrompt() then
        return
    end
else
    incrementKeySessionCount()
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
UI.ToggleCube.BackgroundColor3 = COLORS.toggleCube
UI.ToggleCube.Text = ""
UI.ToggleCube.AutoButtonColor = false
UI.ToggleCube.Parent = UI.ToggleGui

UI.ToggleCorner = Instance.new("UICorner")
UI.ToggleCorner.CornerRadius = UDim.new(0, 8)
UI.ToggleCorner.Parent = UI.ToggleCube

local ToggleStroke = Instance.new("UIStroke")
ToggleStroke.Color = Color3.fromRGB(180, 150, 255)
ToggleStroke.Thickness = 1.5
ToggleStroke.Transparency = 0.35
ToggleStroke.Parent = UI.ToggleCube

UI.ToggleIcon = Instance.new("TextLabel")
UI.ToggleIcon.Size = UDim2.new(1, 0, 1, 0)
UI.ToggleIcon.BackgroundTransparency = 1
UI.ToggleIcon.Text = "◆"
UI.ToggleIcon.TextColor3 = COLORS.text
UI.ToggleIcon.TextSize = 16
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
UI.MobileAimBtn.BackgroundColor3 = Color3.fromRGB(70, 170, 255)
UI.MobileAimBtn.BackgroundTransparency = 0.15
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
MobileAimStroke.Color = COLORS.text
MobileAimStroke.Thickness = 2
MobileAimStroke.Transparency = 0.4
MobileAimStroke.Parent = UI.MobileAimBtn

local mobileAimDragging = false
local mobileAimDragStart, mobileAimStartPos

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 500, 0, 560)
MainFrame.Position = UDim2.new(0.5, -250, 0.5, -280)
MainFrame.BackgroundColor3 = COLORS.bg
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 14)
MainCorner.Parent = MainFrame

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
Header.Size = UDim2.new(1, 0, 0, 48)
Header.BackgroundTransparency = 1
Header.Parent = MainFrame

local HubTitle = Instance.new("TextLabel")
HubTitle.Name = "HubTitle"
HubTitle.Size = UDim2.new(1, -50, 1, 0)
HubTitle.Position = UDim2.new(0, 18, 0, 0)
HubTitle.BackgroundTransparency = 1
HubTitle.Text = "Script Hub"
HubTitle.TextColor3 = COLORS.text
HubTitle.TextSize = 22
HubTitle.Font = Enum.Font.GothamBold
HubTitle.TextXAlignment = Enum.TextXAlignment.Left
HubTitle.Parent = Header

UI.CloseBtn = Instance.new("TextButton")
UI.CloseBtn.Size = UDim2.new(0, 32, 0, 32)
UI.CloseBtn.Position = UDim2.new(1, -40, 0.5, -16)
UI.CloseBtn.BackgroundTransparency = 1
UI.CloseBtn.Text = "×"
UI.CloseBtn.TextColor3 = COLORS.textMuted
UI.CloseBtn.TextSize = 28
UI.CloseBtn.Font = Enum.Font.Gotham
UI.CloseBtn.Parent = Header

UI.CloseBtn.MouseEnter:Connect(function()
    UI.CloseBtn.TextColor3 = COLORS.danger
end)
UI.CloseBtn.MouseLeave:Connect(function()
    UI.CloseBtn.TextColor3 = COLORS.textMuted
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
            MainFrame.Visible = not MainFrame.Visible
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
        UI.MobileAimBtn.BackgroundColor3 = COLORS.accent
    end
end))

bindConnection(UI.MobileAimBtn.InputEnded:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Touch then return end

    if State.mobileAimDragUnlocked then
        mobileAimDragging = false
        saveAimButtonPos(UI.MobileAimBtn.Position)
    else
        State.holdingMobileAim = false
        UI.MobileAimBtn.BackgroundColor3 = Color3.fromRGB(70, 170, 255)
    end
end))

local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -24, 0, 38)
TabBar.Position = UDim2.new(0, 12, 0, 48)
TabBar.BackgroundTransparency = 1
TabBar.Parent = MainFrame

local TabLayout = Instance.new("UIListLayout")
TabLayout.FillDirection = Enum.FillDirection.Horizontal
TabLayout.Padding = UDim.new(0, 8)
TabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabLayout.Parent = TabBar

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -24, 1, -100)
Content.Position = UDim2.new(0, 12, 0, 92)
Content.BackgroundTransparency = 1
Content.ClipsDescendants = true
Content.Parent = MainFrame

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
        data.button.BackgroundColor3 = selected and COLORS.tabActive or COLORS.bg
        data.label.TextColor3 = selected and COLORS.textDark or COLORS.text
        data.icon.TextColor3 = selected and COLORS.textDark or COLORS.text
    end
end

local function createTab(name, icon)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 88, 0, 34)
    btn.BackgroundColor3 = COLORS.bg
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = TabBar

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = btn

    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.new(0, 18, 1, 0)
    iconLabel.Position = UDim2.new(0, 10, 0, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = icon
    iconLabel.TextSize = 14
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextColor3 = COLORS.text
    iconLabel.Parent = btn

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -32, 1, 0)
    textLabel.Position = UDim2.new(0, 28, 0, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = name
    textLabel.TextSize = 12
    textLabel.Font = Enum.Font.GothamSemibold
    textLabel.TextColor3 = COLORS.text
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.Parent = btn

    tabButtons[name] = {button = btn, label = textLabel, icon = iconLabel}
    btn.MouseButton1Click:Connect(function()
        switchTab(name)
    end)
end

local function createHubButton(parent, title, subtitle)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 48)
    btn.BackgroundColor3 = COLORS.surface
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = btn

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(1, -60, 0, 18)
    titleLabel.Position = UDim2.new(0, 14, 0, subtitle and 8 or 15)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = COLORS.text
    titleLabel.TextSize = 15
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = btn

    if subtitle then
        local subLabel = Instance.new("TextLabel")
        subLabel.Name = "SubLabel"
        subLabel.Size = UDim2.new(1, -60, 0, 14)
        subLabel.Position = UDim2.new(0, 14, 0, 26)
        subLabel.BackgroundTransparency = 1
        subLabel.Text = subtitle
        subLabel.TextColor3 = COLORS.textMuted
        subLabel.TextSize = 12
        subLabel.Font = Enum.Font.Gotham
        subLabel.TextXAlignment = Enum.TextXAlignment.Left
        subLabel.Parent = btn
    end

    local stateLabel = Instance.new("TextLabel")
    stateLabel.Name = "StateLabel"
    stateLabel.Size = UDim2.new(0, 40, 1, 0)
    stateLabel.Position = UDim2.new(1, -48, 0, 0)
    stateLabel.BackgroundTransparency = 1
    stateLabel.Text = ""
    stateLabel.TextColor3 = COLORS.textMuted
    stateLabel.TextSize = 13
    stateLabel.Font = Enum.Font.GothamBold
    stateLabel.TextXAlignment = Enum.TextXAlignment.Right
    stateLabel.Visible = false
    stateLabel.Parent = btn

    btn.MouseEnter:Connect(function()
        btn.BackgroundColor3 = COLORS.surfaceHover
    end)
    btn.MouseLeave:Connect(function()
        btn.BackgroundColor3 = COLORS.surface
    end)

    return btn
end

local function setHubToggle(btn, enabled, onText, offText)
    local state = btn:FindFirstChild("StateLabel")
    if state then
        state.Visible = true
        state.Text = enabled and (onText or "ON") or (offText or "OFF")
        state.TextColor3 = enabled and COLORS.accent or COLORS.textMuted
    end
end

local function createHubSlider(parent, title, minVal, maxVal, defaultVal, onChanged)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 62)
    container.BackgroundColor3 = COLORS.surface
    container.Parent = parent

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = container

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0.6, 0, 0, 22)
    titleLabel.Position = UDim2.new(0, 14, 0, 8)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = COLORS.text
    titleLabel.TextSize = 14
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = container

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Name = "ValueLabel"
    valueLabel.Size = UDim2.new(0.4, -14, 0, 22)
    valueLabel.Position = UDim2.new(0.6, 0, 0, 8)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = tostring(defaultVal)
    valueLabel.TextColor3 = COLORS.accentOn
    valueLabel.TextSize = 14
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = container

    local track = Instance.new("TextButton")
    track.Name = "Track"
    track.Size = UDim2.new(1, -28, 0, 8)
    track.Position = UDim2.new(0, 14, 0, 38)
    track.BackgroundColor3 = Color3.fromRGB(30, 30, 34)
    track.Text = ""
    track.AutoButtonColor = false
    track.Parent = container

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track

    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = COLORS.accentOn
    fill.BorderSizePixel = 0
    fill.Parent = track

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    local current = defaultVal
    local draggingSlider = false

    local function setValue(value, fireCallback)
        current = math.clamp(math.floor(value + 0.5), minVal, maxVal)
        valueLabel.Text = tostring(current)
        local alpha = (current - minVal) / math.max(maxVal - minVal, 1)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
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

createTab("Home", "⌂")
createTab("Scanner", "◉")
createTab("Movement", "↗")
createTab("Combat", "⚡")
createTab("Troll", "☠")
createTab("Settings", "⚙")

do

local HomePage = createPage("Home")
local ScannerPage = createPage("Scanner")
local MovementPage = createPage("Movement")
local CombatPage = createPage("Combat")
local TrollPage = createPage("Troll")
local SettingsPage = createPage("Settings")

State.walkSpeed = 16
State.jumpPower = 50
State.defaultWalkSpeed = 16
State.defaultJumpPower = 50
State.speedEnabled = false
State.jumpEnabled = false
State.flightEnabled = false
State.noclipEnabled = false
State.infJumpEnabled = false
State.flightSpeed = 80
State.hookedHumanoids = {}

local HomeCard = Instance.new("Frame")
HomeCard.Size = UDim2.new(1, 0, 0, 120)
HomeCard.BackgroundColor3 = COLORS.surface
HomeCard.Parent = HomePage
local HomeCardCorner = Instance.new("UICorner")
HomeCardCorner.CornerRadius = UDim.new(0, 12)
HomeCardCorner.Parent = HomeCard

local WelcomeText = Instance.new("TextLabel")
WelcomeText.Size = UDim2.new(1, -24, 0, 28)
WelcomeText.Position = UDim2.new(0, 14, 0, 14)
WelcomeText.BackgroundTransparency = 1
WelcomeText.Text = "Welcome back, " .. player.DisplayName
WelcomeText.TextColor3 = COLORS.text
WelcomeText.TextSize = 20
WelcomeText.Font = Enum.Font.GothamBold
WelcomeText.TextXAlignment = Enum.TextXAlignment.Left
WelcomeText.Parent = HomeCard

local HomeSubText = Instance.new("TextLabel")
HomeSubText.Size = UDim2.new(1, -24, 0, 40)
HomeSubText.Position = UDim2.new(0, 14, 0, 44)
HomeSubText.BackgroundTransparency = 1
HomeSubText.Text = "TempV scanner, combat tools,\nmovement hacks & troll features."
HomeSubText.TextColor3 = COLORS.textMuted
HomeSubText.TextSize = 13
HomeSubText.Font = Enum.Font.Gotham
HomeSubText.TextXAlignment = Enum.TextXAlignment.Left
HomeSubText.TextYAlignment = Enum.TextYAlignment.Top
HomeSubText.Parent = HomeCard

local HomeList = Instance.new("Frame")
HomeList.Size = UDim2.new(1, 0, 1, -132)
HomeList.Position = UDim2.new(0, 0, 0, 132)
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
ScannerScroll.ScrollBarThickness = 5
ScannerScroll.ScrollBarImageColor3 = COLORS.textMuted
ScannerScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
ScannerScroll.Parent = ScannerPage

local ScannerScrollCorner = Instance.new("UICorner")
ScannerScrollCorner.CornerRadius = UDim.new(0, 12)
ScannerScrollCorner.Parent = ScannerScroll

local Scroll = ScannerScroll

local UIList = Instance.new("UIListLayout")
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Padding = UDim.new(0, 6)
UIList.Parent = Scroll

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
MovementScroll.ScrollBarImageColor3 = COLORS.textMuted
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
CombatScroll.ScrollBarImageColor3 = COLORS.textMuted
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

local TrollScroll = Instance.new("ScrollingFrame")
TrollScroll.Size = UDim2.new(1, 0, 1, 0)
TrollScroll.BackgroundTransparency = 1
TrollScroll.BorderSizePixel = 0
TrollScroll.ScrollBarThickness = 5
TrollScroll.ScrollBarImageColor3 = COLORS.textMuted
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

UI.DesyncToggle = createHubButton(TrollList, "Desync", "Hide from others · keeps your spot when off · touch doors")
setHubToggle(UI.DesyncToggle, false)

UI.FlingHomelanderBtn = createHubButton(TrollList, "Fling Homelander", "TP into them & launch")

UI.FlingSelfBtn = createHubButton(TrollList, "Fling Self", "Launch yourself into the air")

UI.TpRandomBtn = createHubButton(TrollList, "TP To Random Player", "Teleport to a random player")

UI.TpAllToMeBtn = createHubButton(TrollList, "Bring Players To You", "Pull nearby players to you")

UI.AnnoySoundBtn = createHubButton(TrollList, "Play Loud Sound", "Play an annoying sound locally")

UI.ResetTrollBtn = createHubButton(TrollList, "Reset Troll Effects", "Turn off spin & desync")

local SettingsScroll = Instance.new("ScrollingFrame")
SettingsScroll.Size = UDim2.new(1, 0, 1, 0)
SettingsScroll.BackgroundTransparency = 1
SettingsScroll.BorderSizePixel = 0
SettingsScroll.ScrollBarThickness = 5
SettingsScroll.ScrollBarImageColor3 = COLORS.textMuted
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
    ScriptHubKey = true,
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

            if part.Name ~= "HumanoidRootPart" then
                pcall(function()
                    sethiddenproperty(part, "NetworkIsSleeping", false)
                end)
            end
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
            if desc.Name ~= "HumanoidRootPart" then
                pcall(function()
                    sethiddenproperty(desc, "NetworkIsSleeping", false)
                end)
            end
        end
    end))
end

local function holdDesyncExitPosition(cframe)
    if State.desyncPositionHoldConnection then
        pcall(function()
            desyncPositionHoldConnection:Disconnect()
        end)
        State.desyncPositionHoldConnection = nil
    end

    if not cframe then return end

    local holdUntil = tick() + 1.5
    State.desyncPositionHoldConnection = RunService.Heartbeat:Connect(function()
        if State.desyncEnabled or tick() > holdUntil then
            if State.desyncPositionHoldConnection then
                desyncPositionHoldConnection:Disconnect()
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
            desyncPositionHoldConnection:Disconnect()
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
    end

    table.insert(State.desyncConnections, RunService.Heartbeat:Connect(function()
        if not State.desyncEnabled then return end

        local currentHrp = getRoot()
        if not currentHrp then return end

        State.desyncClientCFrame = currentHrp.CFrame
        State.desyncServerCFrame = State.desyncClientCFrame

        applyDesyncHiddenProps(currentHrp, true)
        applyDesyncTouchInterest(currentHrp.Parent)
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

local function flingCharacterRoot(hrp)
    if not hrp then return end

    pcall(function()
        setsimulationradius(2e19, 2e19)
        sethiddenproperty(player, "SimulationRadius", 2e19)
        sethiddenproperty(player, "MaxSimulationRadius", 2e19)
    end)

    local power = 650
    local velocity = Vector3.new(
        math.random(-power, power),
        math.random(500, power),
        math.random(-power, power)
    )

    for _ = 1, 10 do
        pcall(function()
            hrp.AssemblyLinearVelocity = velocity
            hrp.AssemblyAngularVelocity = Vector3.new(
                math.random(-150, 150),
                math.random(-150, 150),
                math.random(-150, 150)
            )
        end)
        RunService.Heartbeat:Wait()
    end
end

local function flingHomelander()
    local homelander = findHomelanderPlayer()
    if not homelander then
        warn("[ScriptHub] No killer found!")
        return
    end

    local targetHrp = homelander.Character and homelander.Character:FindFirstChild("HumanoidRootPart")
    local myHrp = getRoot()
    if not targetHrp or not myHrp then
        warn("[ScriptHub] Could not get character root parts.")
        return
    end

    pcall(function()
        myHrp.CFrame = targetHrp.CFrame
        myHrp.AssemblyLinearVelocity = Vector3.zero
        myHrp.AssemblyAngularVelocity = Vector3.zero
    end)

    task.wait(0.05)

    flingCharacterRoot(targetHrp)
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
                    btn.Size = UDim2.new(1, -4, 0, 52)
                    btn.BackgroundColor3 = COLORS.surfaceHover
                    btn.BorderSizePixel = 0
                    btn.Font = Enum.Font.GothamSemibold
                    btn.TextSize = 13
                    btn.TextColor3 = COLORS.text
                    btn.TextXAlignment = Enum.TextXAlignment.Left
                    btn.Parent = Scroll

                    local corner = Instance.new("UICorner")
                    corner.CornerRadius = UDim.new(0, 8)
                    corner.Parent = btn

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
                        btn.BackgroundColor3 = Color3.fromRGB(72, 72, 76)
                    end)
                    btn.MouseLeave:Connect(function()
                        btn.BackgroundColor3 = COLORS.surfaceHover
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
    if gp then return end
    
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        State.holdingRightClick = true
    elseif input.KeyCode == Enum.KeyCode.R then
        State.aimbotEnabled = not State.aimbotEnabled
        setHubToggle(UI.AimbotToggle, State.aimbotEnabled)
        if State.isMobile and UI.MobileAimBtn then
            UI.MobileAimBtn.Visible = State.aimbotEnabled
        end
    end
end))

bindConnection(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        State.holdingRightClick = false
    end
end))

-- Main Update Loop
bindConnection(RunService.RenderStepped:Connect(function(dt)
    if State.ejected then return end

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
    if State.aimbotEnabled and aiming and root and camera then
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

UI.SpinToggle.MouseButton1Click:Connect(function()
    State.spinEnabled = not State.spinEnabled
    setHubToggle(UI.SpinToggle, State.spinEnabled)
end)

UI.DesyncToggle.MouseButton1Click:Connect(function()
    setDesync(not State.desyncEnabled)
    setHubToggle(UI.DesyncToggle, State.desyncEnabled, "ON", "OFF")
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
end)

end -- scope block (Luau local register limit)

print("✅ Script Hub loaded")
if State.isMobile then
    print("📱 Mobile mode: hold the AIM button to aim")
else
    print("🎮 Press R to toggle Aimbot | Right-click to aim")
end
print("💡 Top-left cube toggles the GUI | Close button ejects the script")
print("💡 Tabs: Scanner · Movement · Combat · Troll")
