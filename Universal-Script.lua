-- Archeron Hub - Fixed Version
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Destroy old GUI if exists
if playerGui:FindFirstChild("ArcheronHub") then
    playerGui.ArcheronHub:Destroy()
    wait(0.1)
end

-- Translations
local function getText(key)
    local translations = {
        hubActive = "Archeron - Hub Active ✅",
        loadSuccess = "Successfully loaded!",
        statusEnabled = "Status: Enabled",
        statusDisabled = "Status: Disabled",
        menuMain = "🔥 Main",
        menuPlayer = "🕹️ Player",
        menuInfo = "📄 Info",
        collectAllStick = "Collect All Stick",
        collectAllStickDesc = "Automatically collect all sticks",
        autoClick = "Auto Click", 
        autoClickDesc = "For clicking Hub",
        fly = "Fly",
        flyDesc = "Enable flight (Mobile & PC)",
        noclip = "Noclip",
        noclipDesc = "Walk through walls",
        walkspeed = "Walk Speed",
        walkspeedDesc = "Set walking speed",
        jumppower = "Jump Power",
        jumppowerDesc = "Set jump height",
        owner = "Owner",
    }
    return translations[key] or key
end

-- Game Config
local gameConfig = {
    menus = {"menuMain", "menuPlayer", "menuInfo"},
    features = {
        menuMain = {
            {name = "collectAllStick", type = "toggle"},
            {name = "autoClick", type = "toggle"},
        },
        menuPlayer = {
            {name = "fly", type = "toggle"},
            {name = "noclip", type = "toggle"},
            {name = "walkspeed", type = "slider", min = 16, max = 500, default = 16},
            {name = "jumppower", type = "slider", min = 50, max = 500, default = 50},
        },
        menuInfo = {
            {name = "owner", type = "info", value = "Archeron"}
        }
    },
    remotePaths = { 
        pickup = "ReplicatedStorage.Events.PickUp",
        click = "ReplicatedStorage.Events.Click",  
    },
}
        


local LOGO_ID = "rbxassetid://139400776308881"
local RemoteEvents = {}
local featureStates = {}
local flyConnection = nil
local noclipConnection = nil

-- Connect Remote
local function connectRemote(key, path)
local function connectRemote(key, path)
    if not path then 
        print("❌ No path for:", key)
        return nil 
    end
    print("🔍 Connecting:", key, "at", path)
    local success, result = pcall(function()
        local parts = string.split(path, ".")
        local current = game:GetService(parts[1])
        for i = 2, #parts do
            current = current:WaitForChild(parts[i], 10)
        end
        return current
    end)
    if success and result then
        RemoteEvents[key] = result  
        print("✅ Remote connected:", key)
    else
        print("❌ Failed:", key, result)
    end
    return result
end

task.spawn(function()
    wait(2)
    -- Connect semua remote
    for key, path in pairs(gameConfig.remotePaths) do  
        connectRemote(key, path)
    end
end)


-- Create GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ArcheronHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = playerGui

-- Notification
local NotificationFrame = Instance.new("Frame")
NotificationFrame.Size = UDim2.new(0, 300, 1, 0)
NotificationFrame.Position = UDim2.new(1, -320, 0, 0)
NotificationFrame.BackgroundTransparency = 1
NotificationFrame.Parent = ScreenGui

local function createNotification(title, message, duration)
    local notif = Instance.new("Frame")
    notif.Size = UDim2.new(1, 0, 0, 80)
    notif.Position = UDim2.new(0, 0, 1, 20)
    notif.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    notif.BorderSizePixel = 0
    notif.Parent = NotificationFrame
    
    Instance.new("UICorner", notif).CornerRadius = UDim.new(0, 10)
    
    local bar = Instance.new("Frame", notif)
    bar.Size = UDim2.new(0, 4, 1, 0)
    bar.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
    bar.BorderSizePixel = 0
    
    local titleLabel = Instance.new("TextLabel", notif)
    titleLabel.Size = UDim2.new(1, -50, 0, 25)
    titleLabel.Position = UDim2.new(0, 15, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 14
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    
    local msgLabel = Instance.new("TextLabel", notif)
    msgLabel.Size = UDim2.new(1, -50, 0, 40)
    msgLabel.Position = UDim2.new(0, 15, 0, 35)
    msgLabel.BackgroundTransparency = 1
    msgLabel.Text = message
    msgLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
    msgLabel.Font = Enum.Font.Gotham
    msgLabel.TextSize = 12
    msgLabel.TextXAlignment = Enum.TextXAlignment.Left
    msgLabel.TextWrapped = true
    
    TweenService:Create(notif, TweenInfo.new(0.4, Enum.EasingStyle.Back), {
        Position = UDim2.new(0, 0, 1, -90)
    }):Play()
    
    task.delay(duration or 5, function()
        TweenService:Create(notif, TweenInfo.new(0.3), {
            Position = UDim2.new(0, 0, 1, 20)
        }):Play()
        wait(0.3)
        notif:Destroy()
    end)
end

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 700, 0, 450)
MainFrame.Position = UDim2.new(0.5, -350, 0.5, -225)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 15)

-- Header
local HeaderFrame = Instance.new("Frame", MainFrame)
HeaderFrame.Size = UDim2.new(1, 0, 0, 70)
HeaderFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
HeaderFrame.BorderSizePixel = 0

Instance.new("UICorner", HeaderFrame).CornerRadius = UDim.new(0, 15)

local HeaderCover = Instance.new("Frame", HeaderFrame)
HeaderCover.Size = UDim2.new(1, 0, 0, 15)
HeaderCover.Position = UDim2.new(0, 0, 1, -15)
HeaderCover.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
HeaderCover.BorderSizePixel = 0

local LogoFrame = Instance.new("ImageLabel", HeaderFrame)
LogoFrame.Size = UDim2.new(0, 50, 0, 50)
LogoFrame.Position = UDim2.new(0, 10, 0, 10)
LogoFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
LogoFrame.BorderSizePixel = 0
LogoFrame.Image = LOGO_ID

Instance.new("UICorner", LogoFrame).CornerRadius = UDim.new(0, 10)

local GameNameLabel = Instance.new("TextLabel", HeaderFrame)
GameNameLabel.Size = UDim2.new(1, -80, 0, 30)
GameNameLabel.Position = UDim2.new(0, 70, 0, 12)
GameNameLabel.BackgroundTransparency = 1
GameNameLabel.Text = "Sticks Incremental"
GameNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
GameNameLabel.Font = Enum.Font.GothamBold
GameNameLabel.TextSize = 18
GameNameLabel.TextXAlignment = Enum.TextXAlignment.Left

local HubLabel = Instance.new("TextLabel", HeaderFrame)
HubLabel.Size = UDim2.new(1, -80, 0, 20)
HubLabel.Position = UDim2.new(0, 70, 0, 42)
HubLabel.BackgroundTransparency = 1
HubLabel.Text = "Archeron - Hub"
HubLabel.TextColor3 = Color3.fromRGB(150, 150, 200)
HubLabel.Font = Enum.Font.Gotham
HubLabel.TextSize = 14
HubLabel.TextXAlignment = Enum.TextXAlignment.Left

-- Menu Sidebar
local MenuSidebar = Instance.new("Frame", MainFrame)
MenuSidebar.Size = UDim2.new(0, 150, 1, -90)
MenuSidebar.Position = UDim2.new(0, 10, 0, 80)
MenuSidebar.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
MenuSidebar.BorderSizePixel = 0

Instance.new("UICorner", MenuSidebar).CornerRadius = UDim.new(0, 10)

local MenuList = Instance.new("UIListLayout", MenuSidebar)
MenuList.Padding = UDim.new(0, 5)

local MenuPad = Instance.new("UIPadding", MenuSidebar)
MenuPad.PaddingTop = UDim.new(0, 5)
MenuPad.PaddingLeft = UDim.new(0, 5)
MenuPad.PaddingRight = UDim.new(0, 5)

-- Content Area
local ContentArea = Instance.new("ScrollingFrame", MainFrame)
ContentArea.Size = UDim2.new(1, -180, 1, -90)
ContentArea.Position = UDim2.new(0, 170, 0, 80)
ContentArea.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
ContentArea.BorderSizePixel = 0
ContentArea.ScrollBarThickness = 6

Instance.new("UICorner", ContentArea).CornerRadius = UDim.new(0, 10)

local ContentList = Instance.new("UIListLayout", ContentArea)
ContentList.Padding = UDim.new(0, 10)

local ContentPad = Instance.new("UIPadding", ContentArea)
ContentPad.PaddingTop = UDim.new(0, 10)
ContentPad.PaddingLeft = UDim.new(0, 10)
ContentPad.PaddingRight = UDim.new(0, 10)

-- Create Toggle Feature
local function createToggle(name, parent)
    -- JANGAN set false kalau udah ada state sebelumnya
    if featureStates[name] == nil then
        featureStates[name] = false
    end
    
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1, -10, 0, 70)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    frame.BorderSizePixel = 0
    
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
    
    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1, -100, 0, 25)
    title.Position = UDim2.new(0, 15, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = getText(name)
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    local desc = Instance.new("TextLabel", frame)
    desc.Size = UDim2.new(1, -100, 0, 30)
    desc.Position = UDim2.new(0, 15, 0, 35)
    desc.BackgroundTransparency = 1
    desc.Text = getText(name .. "Desc")
    desc.TextColor3 = Color3.fromRGB(150, 150, 170)
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 11
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.TextWrapped = true
    
    local btn = Instance.new("TextButton", frame)
    btn.Size = UDim2.new(0, 70, 0, 35)
    btn.Position = UDim2.new(1, -85, 0.5, -17.5)
    -- SET button sesuai state yang sebenarnya
    btn.BackgroundColor3 = featureStates[name] and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(200, 100, 100)
    btn.BorderSizePixel = 0
    btn.Text = featureStates[name] and "ON" or "OFF"  -- SET text sesuai state
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    
    local loop = nil
    
    btn.MouseButton1Click:Connect(function()
        featureStates[name] = not featureStates[name]
        
        if featureStates[name] then
            btn.Text = "ON"
            btn.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
            createNotification(getText(name), getText("statusEnabled"), 3)
            
            if name == "collectAllStick" then
    print("🔄 Activating collectAllStick...")
    if not RemoteEvents.pickup then 
        connectRemote("pickup", gameConfig.remotePaths.pickup) 
        wait(0.5) 
    end
    if RemoteEvents.pickup then
        print("✅ Starting collect loop")
        loop = RunService.Heartbeat:Connect(function()
            if featureStates[name] then
                pcall(function()
                    RemoteEvents.pickup:FireServer("Stick")
                    RemoteEvents.pickup:FireServer("Gold stick")
                    RemoteEvents.pickup:FireServer("ShadowStick")
                end)
                wait(0.1)
            end
        end)
    else
        print("❌ RemoteEvents.pickup not found!")
    end

elseif name == "autoClick" then
    print("🔄 Activating autoClick...")
    if not RemoteEvents.click then 
        connectRemote("click", gameConfig.remotePaths.click) 
        wait(0.5) 
    end
    if RemoteEvents.click then
        print("✅ Starting click loop")
        loop = RunService.Heartbeat:Connect(function()
            if featureStates[name] then
                pcall(function()
                    RemoteEvents.click:FireServer()
                end)
                wait(0.05)
            end
        end)
    else
        print("❌ RemoteEvents.click not found!")
    end
            
            elseif name == "fly" then
                local char = player.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    local root = char:FindFirstChild("HumanoidRootPart")
                    if hum and root then
                        local bv = Instance.new("BodyVelocity", root)
                        bv.Velocity = Vector3.new(0, 0, 0)
                        bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                        
                        local bg = Instance.new("BodyGyro", root)
                        bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
                        bg.P = 9e4
                        
                        flyConnection = RunService.Heartbeat:Connect(function()
                            if featureStates["fly"] then
                                local cam = workspace.CurrentCamera
                                local dir = Vector3.new(0, 0, 0)
                                
                                if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
                                if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
                                if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
                                if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
                                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
                                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end
                                
                                if hum.MoveVector.Magnitude > 0 then
                                    dir = dir + (cam.CFrame.LookVector * hum.MoveVector.Z)
                                    dir = dir + (cam.CFrame.RightVector * hum.MoveVector.X)
                                end
                                
                                bv.Velocity = dir.Unit * 50
                                bg.CFrame = cam.CFrame
                            end
                        end)
                    end
                end
            
            elseif name == "noclip" then
                noclipConnection = RunService.Stepped:Connect(function()
                    if featureStates["noclip"] then
                        local char = player.Character
                        if char then
                            for _, part in pairs(char:GetDescendants()) do
                                if part:IsA("BasePart") then
                                    part.CanCollide = false
                                end
                            end
                        end
                    end
                end)
            end
        else
            btn.Text = "OFF"
            btn.BackgroundColor3 = Color3.fromRGB(200, 100, 100)
            createNotification(getText(name), getText("statusDisabled"), 3)
            
            if loop then loop:Disconnect() end
            
            if name == "fly" and flyConnection then
                flyConnection:Disconnect()
                local char = player.Character
                if char then
                    local root = char:FindFirstChild("HumanoidRootPart")
                    if root then
                        for _, obj in pairs(root:GetChildren()) do
                            if obj:IsA("BodyVelocity") or obj:IsA("BodyGyro") then
                                obj:Destroy()
                            end
                        end
                    end
                end
            end
            
            if name == "noclip" and noclipConnection then
                noclipConnection:Disconnect()
                local char = player.Character
                if char then
                    for _, part in pairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = true
                        end
                    end
                end
            end
        end
    end)
end

-- Create Slider Feature
local function createSlider(name, minVal, maxVal, def, parent)
    featureStates[name] = def
    
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1, -10, 0, 90)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    frame.BorderSizePixel = 0
    
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
    
    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1, -80, 0, 25)
    title.Position = UDim2.new(0, 15, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = getText(name)
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    local val = Instance.new("TextLabel", frame)
    val.Size = UDim2.new(0, 60, 0, 20)
    val.Position = UDim2.new(1, -75, 0, 10)
    val.BackgroundTransparency = 1
    val.Text = tostring(def)
    val.TextColor3 = Color3.fromRGB(138, 43, 226)
    val.Font = Enum.Font.GothamBold
    val.TextSize = 14
    
    local desc = Instance.new("TextLabel", frame)
    desc.Size = UDim2.new(1, -30, 0, 30)
    desc.Position = UDim2.new(0, 15, 0, 35)
    desc.BackgroundTransparency = 1
    desc.Text = getText(name .. "Desc")
    desc.TextColor3 = Color3.fromRGB(150, 150, 170)
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 11
    desc.TextXAlignment = Enum.TextXAlignment.Left
    
    local bar = Instance.new("Frame", frame)
    bar.Size = UDim2.new(1, -30, 0, 8)
    bar.Position = UDim2.new(0, 15, 1, -20)
    bar.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    bar.BorderSizePixel = 0
    
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
    
    local fill = Instance.new("Frame", bar)
    fill.Size = UDim2.new((def - minVal) / (maxVal - minVal), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
    fill.BorderSizePixel = 0
    
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    
    local btn = Instance.new("TextButton", bar)
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    
    local drag = false
    
    btn.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag = true
        end
    end)
    
    btn.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            drag = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local pos = math.clamp((i.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            local v = math.floor(minVal + (maxVal - minVal) * pos)
            featureStates[name] = v
            val.Text = tostring(v)
            TweenService:Create(fill, TweenInfo.new(0.1), {Size = UDim2.new(pos, 0, 1, 0)}):Play()
            
            local char = player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    if name == "walkspeed" then hum.WalkSpeed = v end
                    if name == "jumppower" then hum.JumpPower = v end
                end
            end
        end
    end)
end

-- Create Info Feature
local function createInfo(name, value, parent)
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1, -10, 0, 80)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    frame.BorderSizePixel = 0
    
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
    
    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1, -30, 0, 25)
    title.Position = UDim2.new(0, 15, 0, 12)
    title.BackgroundTransparency = 1
    title.Text = getText(name)
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    
    local valueLabel = Instance.new("TextLabel", frame)
    valueLabel.Size = UDim2.new(1, -30, 0, 30)
    valueLabel.Position = UDim2.new(0, 15, 0, 40)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = value
    valueLabel.TextColor3 = Color3.fromRGB(138, 43, 226)
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 20
    valueLabel.TextXAlignment = Enum.TextXAlignment.Left
end

-- Load Menu Function
local currentMenu = nil
local menuBtns = {}

local function clearContent()
    for _, c in ipairs(ContentArea:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
end

local function loadMenu(key)
    if currentMenu == key then return end
    currentMenu = key
    
    for k, b in pairs(menuBtns) do
        b.BackgroundColor3 = (k == key) and Color3.fromRGB(138, 43, 226) or Color3.fromRGB(35, 35, 50)
    end
    
    clearContent()
    
    local features = gameConfig.features[key]
    if features then
        for _, f in ipairs(features) do
            if f.type == "toggle" then
                createToggle(f.name, ContentArea)
            elseif f.type == "slider" then
                createSlider(f.name, f.min, f.max, f.default, ContentArea)
            elseif f.type == "info" then
                createInfo(f.name, f.value, ContentArea)
            end
        end
    end
    
    wait(0.1)
    ContentArea.CanvasSize = UDim2.new(0, 0, 0, ContentList.AbsoluteContentSize.Y + 20)
end

-- Create Menu Buttons
for i, key in ipairs(gameConfig.menus) do
    local btn = Instance.new("TextButton", MenuSidebar)
    btn.Size = UDim2.new(1, -10, 0, 45)
    btn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    btn.BorderSizePixel = 0
    btn.Text = getText(key)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.LayoutOrder = i
    
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    
    menuBtns[key] = btn
    btn.MouseButton1Click:Connect(function() 
        print("Menu clicked:", key)
        loadMenu(key) 
    end)
end

-- Load first menu
print("Loading first menu...")
if #gameConfig.menus > 0 then
    loadMenu(gameConfig.menus[1])
end

-- Toggle Button
local ToggleFrame = Instance.new("Frame", ScreenGui)
ToggleFrame.Size = UDim2.new(0, 60, 0, 60)
ToggleFrame.Position = UDim2.new(0, 20, 0, 20)
ToggleFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
ToggleFrame.BorderSizePixel = 0
ToggleFrame.Active = true
ToggleFrame.ZIndex = 10

Instance.new("UICorner", ToggleFrame).CornerRadius = UDim.new(0, 12)

local ToggleBorder = Instance.new("UIStroke", ToggleFrame)
ToggleBorder.Color = Color3.fromRGB(138, 43, 226)
ToggleBorder.Thickness = 2

local ToggleLogo = Instance.new("ImageLabel", ToggleFrame)
ToggleLogo.Size = UDim2.new(1, -16, 1, -16)
ToggleLogo.Position = UDim2.new(0, 8, 0, 8)
ToggleLogo.BackgroundTransparency = 1
ToggleLogo.Image = LOGO_ID
ToggleLogo.ScaleType = Enum.ScaleType.Fit
ToggleLogo.ZIndex = 11

Instance.new("UICorner", ToggleLogo).CornerRadius = UDim.new(0, 8)

local ToggleBtn = Instance.new("TextButton", ToggleFrame)
ToggleBtn.Size = UDim2.new(1, 0, 1, 0)
ToggleBtn.BackgroundTransparency = 1
ToggleBtn.Text = ""
ToggleBtn.ZIndex = 12

-- Dragging
local dragging = false
local dragInput, dragStart, startPos

ToggleBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = ToggleFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

ToggleBtn.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        ToggleFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- Main frame dragging
local mainDragging = false
local mainDragInput, mainDragStart, mainStartPos

HeaderFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        mainDragging = true
        mainDragStart = input.Position
        mainStartPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                mainDragging = false
            end
        end)
    end
end)

HeaderFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        mainDragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == mainDragInput and mainDragging then
        local delta = input.Position - mainDragStart
        MainFrame.Position = UDim2.new(mainStartPos.X.Scale, mainStartPos.X.Offset + delta.X, mainStartPos.Y.Scale, mainStartPos.Y.Offset + delta.Y)
    end
end)

-- Toggle GUI Open/Close
local isOpen = true

ToggleBtn.MouseButton1Click:Connect(function()
    if dragging then return end
    
    isOpen = not isOpen
    local tween = TweenService:Create(MainFrame, TweenInfo.new(0.4), {
        Size = isOpen and UDim2.new(0, 700, 0, 450) or UDim2.new(0, 0, 0, 0),
        Position = isOpen and UDim2.new(0.5, -350, 0.5, -225) or UDim2.new(0.5, 0, 0.5, 0)
    })
    tween:Play()
    if isOpen then
        MainFrame.Visible = true
    else
        tween.Completed:Connect(function() MainFrame.Visible = false end)
    end
end)

-- Startup Animation
MainFrame.Size = UDim2.new(0, 0, 0, 0)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
wait(0.1)
TweenService:Create(MainFrame, TweenInfo.new(0.6, Enum.EasingStyle.Back), {
    Size = UDim2.new(0, 700, 0, 450),
    Position = UDim2.new(0.5, -350, 0.5, -225)
}):Play()

wait(0.5)
createNotification(getText("hubActive"), getText("loadSuccess"), 5)
print("✅ Archeron Hub loaded successfully!")
print("📋 Features loaded:", #gameConfig.menus, "menus")
