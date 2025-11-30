-- Archeron Hub Advanced GUI Script - ENGLISH ONLY
-- Multi-Game Support

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

if playerGui:FindFirstChild("ArcheronHub") then
    playerGui.ArcheronHub:Destroy()
    wait(0.1)
end

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
    fly = "Fly",
    flyDesc = "Enable flight (Mobile & PC)",
    noclip = "Noclip",
    noclipDesc = "Walk through walls",
    walkspeed = "Walk Speed",
    walkspeedDesc = "Set walking speed",
    jumppower = "Jump Power",
    jumppowerDesc = "Set jump height",
    owner = "Owner",
    ownerValue = "Archeron",
}

local function getText(key)
    return translations[key] or key
end

local gameConfigs = {
    [120870800305934] = {
        menus = {"menuMain", "menuPlayer", "menuInfo"},
        features = {
            menuMain = {
                {name = "collectAllStick", type = "toggle"},
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
        remotePath = "ReplicatedStorage.Events.PickUp",
    },
}

local LOGO_TEXTURE_ID = "rbxassetid://139400776308881"
local currentGameId = game.PlaceId
local currentConfig = gameConfigs[currentGameId]

print("🎮 Place ID:", currentGameId)

if not currentConfig then
    warn("⚠️ Game not configured!")
    currentConfig = {
        menus = {"menuMain"},
        features = {menuMain = {}},
        remotePath = nil,
    }
end

local REMOTE_EVENT_PATH = currentConfig.remotePath
local RemoteEvent = nil

local function connectRemoteEvent()
    if not REMOTE_EVENT_PATH then return nil end
    
    local success, result = pcall(function()
        local parts = string.split(REMOTE_EVENT_PATH, ".")
        local current = game:GetService(parts[1])
        for i = 2, #parts do
            current = current:WaitForChild(parts[i], 10)
        end
        return current
    end)
    
    if success and result then
        RemoteEvent = result
        print("✅ Remote connected:", RemoteEvent:GetFullName())
        return RemoteEvent
    else
        warn("❌ Failed to connect")
        return nil
    end
end

task.spawn(function()
    wait(2)
    for i = 1, 5 do
        if RemoteEvent then break end
        print("🔄 Connecting... (" .. i .. "/5)")
        connectRemoteEvent()
        if not RemoteEvent then wait(2) end
    end
    if RemoteEvent then
        print("✅ Connected!")
    else
        warn("❌ Connection failed")
    end
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ArcheronHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = playerGui

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
        local tween = TweenService:Create(notif, TweenInfo.new(0.3), {
            Position = UDim2.new(0, 0, 1, 20)
        })
        tween:Play()
        tween.Completed:Connect(function() notif:Destroy() end)
    end)
end

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 700, 0, 450)
MainFrame.Position = UDim2.new(0.5, -350, 0.5, -225)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 15)

local HeaderFrame = Instance.new("Frame", MainFrame)
HeaderFrame.Size = UDim2.new(1, 0, 0, 70)
HeaderFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
HeaderFrame.BorderSizePixel = 0
HeaderFrame.ZIndex = 2

Instance.new("UICorner", HeaderFrame).CornerRadius = UDim.new(0, 15)

local HeaderCover = Instance.new("Frame", HeaderFrame)
HeaderCover.Size = UDim2.new(1, 0, 0, 15)
HeaderCover.Position = UDim2.new(0, 0, 1, -15)
HeaderCover.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
HeaderCover.BorderSizePixel = 0
HeaderCover.ZIndex = 2

local LogoFrame = Instance.new("ImageLabel", HeaderFrame)
LogoFrame.Size = UDim2.new(0, 50, 0, 50)
LogoFrame.Position = UDim2.new(0, 10, 0, 10)
LogoFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
LogoFrame.BorderSizePixel = 0
LogoFrame.Image = LOGO_TEXTURE_ID
LogoFrame.ZIndex = 3

Instance.new("UICorner", LogoFrame).CornerRadius = UDim.new(0, 10)

local GameNameLabel = Instance.new("TextLabel", HeaderFrame)
GameNameLabel.Size = UDim2.new(1, -80, 0, 30)
GameNameLabel.Position = UDim2.new(0, 70, 0, 12)
GameNameLabel.BackgroundTransparency = 1
GameNameLabel.Text = "Loading..."
GameNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
GameNameLabel.Font = Enum.Font.GothamBold
GameNameLabel.TextSize = 18
GameNameLabel.TextXAlignment = Enum.TextXAlignment.Left
GameNameLabel.ZIndex = 3

spawn(function()
    local s, n = pcall(function()
        return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
    end)
    GameNameLabel.Text = s and n or "Unknown"
end)

local HubLabel = Instance.new("TextLabel", HeaderFrame)
HubLabel.Size = UDim2.new(1, -80, 0, 20)
HubLabel.Position = UDim2.new(0, 70, 0, 42)
HubLabel.BackgroundTransparency = 1
HubLabel.Text = "Archeron - Hub"
HubLabel.TextColor3 = Color3.fromRGB(150, 150, 200)
HubLabel.Font = Enum.Font.Gotham
HubLabel.TextSize = 14
HubLabel.TextXAlignment = Enum.TextXAlignment.Left
HubLabel.ZIndex = 3

local MenuSidebar = Instance.new("Frame", MainFrame)
MenuSidebar.Size = UDim2.new(0, 150, 1, -90)
MenuSidebar.Position = UDim2.new(0, 10, 0, 80)
MenuSidebar.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
MenuSidebar.BorderSizePixel = 0
MenuSidebar.ZIndex = 2

Instance.new("UICorner", MenuSidebar).CornerRadius = UDim.new(0, 10)

local MenuList = Instance.new("UIListLayout", MenuSidebar)
MenuList.Padding = UDim.new(0, 5)

local MenuPad = Instance.new("UIPadding", MenuSidebar)
MenuPad.PaddingTop = UDim.new(0, 5)
MenuPad.PaddingLeft = UDim.new(0, 5)
MenuPad.PaddingRight = UDim.new(0, 5)

local ContentArea = Instance.new("ScrollingFrame", MainFrame)
ContentArea.Size = UDim2.new(1, -180, 1, -90)
ContentArea.Position = UDim2.new(0, 170, 0, 80)
ContentArea.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
ContentArea.BorderSizePixel = 0
ContentArea.ScrollBarThickness = 6
ContentArea.ZIndex = 2

Instance.new("UICorner", ContentArea).CornerRadius = UDim.new(0, 10)

local ContentList = Instance.new("UIListLayout", ContentArea)
ContentList.Padding = UDim.new(0, 10)

local ContentPad = Instance.new("UIPadding", ContentArea)
ContentPad.PaddingTop = UDim.new(0, 10)
ContentPad.PaddingLeft = UDim.new(0, 10)
ContentPad.PaddingRight = UDim.new(0, 10)

local featureStates = {}
local flyConnection = nil
local noclipConnection = nil

local function createToggleFeature(name, parent)
    featureStates[name] = false
    
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
    btn.BackgroundColor3 = Color3.fromRGB(200, 100, 100)
    btn.BorderSizePixel = 0
    btn.Text = "OFF"
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
            
            -- Collect All Stick Feature
            if name == "collectAllStick" then
                if not RemoteEvent then
                    connectRemoteEvent()
                    wait(0.5)
                end
                
                if RemoteEvent then
                    local count = 0
                    loop = RunService.Heartbeat:Connect(function()
                        if featureStates[name] and RemoteEvent then
                            pcall(function()
                                for _, item in ipairs({"Stick", "Gold stick", "ShadowStick"}) do
                                    RemoteEvent:FireServer(item)
                                end
                                count = count + 1
                                if count % 100 == 0 then
                                    print("✅ Collected", count, "cycles")
                                end
                            end)
                            task.wait(0.1)
                        end
                    end)
                else
                    btn.Text = "OFF"
                    btn.BackgroundColor3 = Color3.fromRGB(200, 100, 100)
                    featureStates[name] = false
                    createNotification("❌ Error", "Remote not found!", 5)
                end
            
            -- Fly Feature (Mobile & PC)
            elseif name == "fly" then
                local char = player.Character
                if char then
                    local humanoid = char:FindFirstChildOfClass("Humanoid")
                    local rootPart = char:FindFirstChild("HumanoidRootPart")
                    
                    if humanoid and rootPart then
                        local flySpeed = 50
                        local bodyVelocity = Instance.new("BodyVelocity")
                        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
                        bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                        bodyVelocity.Parent = rootPart
                        
                        local bodyGyro = Instance.new("BodyGyro")
                        bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
                        bodyGyro.P = 9e4
                        bodyGyro.Parent = rootPart
                        
                        flyConnection = RunService.Heartbeat:Connect(function()
                            if featureStates["fly"] then
                                local camera = workspace.CurrentCamera
                                local moveDir = Vector3.new(0, 0, 0)
                                
                                -- PC Controls
                                if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                                    moveDir = moveDir + (camera.CFrame.LookVector)
                                end
                                if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                                    moveDir = moveDir - (camera.CFrame.LookVector)
                                end
                                if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                                    moveDir = moveDir - (camera.CFrame.RightVector)
                                end
                                if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                                    moveDir = moveDir + (camera.CFrame.RightVector)
                                end
                                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                                    moveDir = moveDir + Vector3.new(0, 1, 0)
                                end
                                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                                    moveDir = moveDir - Vector3.new(0, 1, 0)
                                end
                                
                                -- Mobile Controls (TouchEnabled)
                                if humanoid.MoveVector.Magnitude > 0 then
                                    moveDir = moveDir + (camera.CFrame.LookVector * humanoid.MoveVector.Z)
                                    moveDir = moveDir + (camera.CFrame.RightVector * humanoid.MoveVector.X)
                                end
                                
                                if humanoid.Jump then
                                    moveDir = moveDir + Vector3.new(0, 1, 0)
                                end
                                
                                bodyVelocity.Velocity = moveDir.Unit * flySpeed
                                bodyGyro.CFrame = camera.CFrame
                            end
                        end)
                    end
                end
            
            -- Noclip Feature
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
            
            if loop then
                loop:Disconnect()
                loop = nil
            end
            
            -- Stop Fly
            if name == "fly" and flyConnection then
                flyConnection:Disconnect()
                flyConnection = nil
                local char = player.Character
                if char then
                    local rootPart = char:FindFirstChild("HumanoidRootPart")
                    if rootPart then
                        for _, obj in pairs(rootPart:GetChildren()) do
                            if obj:IsA("BodyVelocity") or obj:IsA("BodyGyro") then
                                obj:Destroy()
                            end
                        end
                    end
                end
            end
            
            -- Stop Noclip
            if name == "noclip" and noclipConnection then
                noclipConnection:Disconnect()
                noclipConnection = nil
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

local function createSliderFeature(name, minVal, maxVal, def, parent)
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
    desc.TextWrapped = true
    
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
            
            -- Apply Walkspeed
            if name == "walkspeed" then
                local char = player.Character
                if char then
                    local humanoid = char:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        humanoid.WalkSpeed = v
                    end
                end
            end
            
            -- Apply JumpPower
            if name == "jumppower" then
                local char = player.Character
                if char then
                    local humanoid = char:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        humanoid.JumpPower = v
                    end
                end
            end
        end
    end)
end

local function createInfoFeature(name, value, parent)
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
    
    local features = currentConfig.features[key]
    if features then
        for _, f in ipairs(features) do
            if f.type == "toggle" then
                createToggleFeature(f.name, ContentArea)
            elseif f.type == "slider" then
                createSliderFeature(f.name, f.min, f.max, f.default, ContentArea)
            elseif f.type == "info" then
                createInfoFeature(f.name, f.value, ContentArea)
            end
        end
    end
    
    task.wait(0.1)
    ContentArea.CanvasSize = UDim2.new(0, 0, 0, ContentList.AbsoluteContentSize.Y + 20)
end

for i, key in ipairs(currentConfig.menus) do
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
    btn.MouseButton1Click:Connect(function() loadMenu(key) end)
end

if #currentConfig.menus > 0 then
    loadMenu(currentConfig.menus[1])
end

-- TOGGLE BUTTON (DRAGGABLE & FIXED)
local ToggleFrame = Instance.new("Frame", ScreenGui)
ToggleFrame.Size = UDim2.new(0, 60, 0, 60)
ToggleFrame.Position = UDim2.new(0, 20, 0, 20)
ToggleFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
ToggleFrame.BorderSizePixel = 0
ToggleFrame.Active = true
ToggleFrame.ZIndex = 10

Instance.new("UICorner", ToggleFrame).CornerRadius = UDim.new(0, 12)

-- Purple border
local ToggleBorder = Instance.new("UIStroke", ToggleFrame)
ToggleBorder.Color = Color3.fromRGB(138, 43, 226)
ToggleBorder.Thickness = 2

local ToggleLogo = Instance.new("ImageLabel", ToggleFrame)
ToggleLogo.Size = UDim2.new(1, -16, 1, -16)
ToggleLogo.Position = UDim2.new(0, 8, 0, 8)
ToggleLogo.BackgroundTransparency = 1
ToggleLogo.Image = LOGO_TEXTURE_ID
ToggleLogo.ScaleType = Enum.ScaleType.Fit
ToggleLogo.ZIndex = 11

Instance.new("UICorner", ToggleLogo).CornerRadius = UDim.new(0, 8)

local ToggleBtn = Instance.new("TextButton", ToggleFrame)
ToggleBtn.Size = UDim2.new(1, 0, 1, 0)
ToggleBtn.BackgroundTransparency = 1
ToggleBtn.Text = ""
ToggleBtn.ZIndex = 12

-- Dragging system
local dragging = false
local dragInput
local dragStart
local startPos

local function updateInput(input)
    local delta = input.Position - dragStart
    ToggleFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

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
        updateInput(input)
    end
end)

-- Main frame dragging
local mainDragging = false
local mainDragInput
local mainDragStart
local mainStartPos

local function updateMainFrame(input)
    local delta = input.Position - mainDragStart
    MainFrame.Position = UDim2.new(mainStartPos.X.Scale, mainStartPos.X.Offset + delta.X, mainStartPos.Y.Scale, mainStartPos.Y.Offset + delta.Y)
end

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
        updateMainFrame(input)
    end
end)

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

MainFrame.Size = UDim2.new(0, 0, 0, 0)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
wait(0.1)
TweenService:Create(MainFrame, TweenInfo.new(0.6, Enum.EasingStyle.Back), {
    Size = UDim2.new(0, 700, 0, 450),
    Position = UDim2.new(0.5, -350, 0.5, -225)
}):Play()

wait(0.5)
createNotification(getText("hubActive"), getText("loadSuccess"), 5)
print("✅ Archeron Hub loaded!")
