local player = game.Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

-- WHITELIST GAME (Tambah PlaceId di sini)
local WHITELISTED_GAMES = {
    [104785855204405] = {
        name = "Tree Cutting Incremental",
        features = {
            Main = {
                {name = "Auto Chop Tree", desc = "Potong pohon otomatis", key = "AutoChop", warning = true, note = "If you want to use the cut trees kill aura, you must be able to instantly kill the tree. However, this does not apply to trees that are still alive. If you want to use the cut trees kill aura, you must be able to instantly kill the tree. But this applies to the tree spawns, which are already very fast. If you're stubborn, you'll experience lag/delay."}
            },
            Player = {
                {name = "Fly", desc = "PC: WASD + Space/Shift | Mobile: Joystick + Up/Down", key = "Fly"},
                {name = "WalkSpeed", desc = "Atur kecepatan berjalan", key = "WalkSpeed"},
                {name = "Noclip", desc = "Tembus tembok dan objek", key = "Noclip"}
            }
        }
    },
    [129827112113663] = {
        name = "Prospecting",
        features = {
            Main = {
                {name = "Auto Dig", desc = "Gali otomatis", key = "AutoDig"},
                {name = "Auto Pan", desc = "Pan emas otomatis", key = "AutoPan"},
                {name = "Auto Shake", desc = "Goyang pan otomatis", key = "AutoShake"}
            },
            Player = {
                {name = "Fly", desc = "PC: WASD + Space/Shift | Mobile: Joystick + Up/Down", key = "Fly"},
                {name = "WalkSpeed", desc = "Atur kecepatan berjalan", key = "WalkSpeed"},
                {name = "Noclip", desc = "Tembus tembok dan objek", key = "Noclip"}
            }
        }
    }
}

-- Cek apakah game di whitelist
local currentPlaceId = game.PlaceId
local gameConfig = WHITELISTED_GAMES[currentPlaceId]

if not gameConfig then
    warn("❌ Game ini tidak tersedia di Archeron Hub!")
    wait(2)
    player:Kick("Game tidak terdaftar dalam whitelist Archeron Hub")
    return
end

print("✅ Game terdeteksi: " .. gameConfig.name)

-- Hapus GUI lama
if playerGui:FindFirstChild("ArcheronHub") then
    playerGui.ArcheronHub:Destroy()
end

-- RemoteEvent / RemoteFunction table (DINAMIS SESUAI GAME)
local Remotes = {}

local function initializeRemotesProspecting()
    pcall(function()
        if player.Character and player.Character:FindFirstChild("Plastic Pan") then
            local plasticPan = player.Character["Plastic Pan"]
            if plasticPan:FindFirstChild("Scripts") then
                local scripts = plasticPan.Scripts
                if scripts:FindFirstChild("Collect") then
                    Remotes.AutoDig = {
                        Instance = scripts.Collect,
                        Type = "Function",
                        Args = {1}
                    }
                end
                if scripts:FindFirstChild("Pan") then
                    Remotes.AutoPan = {
                        Instance = scripts.Pan,
                        Type = "Function",
                        Args = {}
                    }
                end
                if scripts:FindFirstChild("Shake") then
                    Remotes.AutoShake = {
                        Instance = scripts.Shake,
                        Type = "Event",
                        Args = {}
                    }
                end
            end
        end
    end)
end

local function initializeRemotesTreeCutting()
    pcall(function()
        -- Cari CutEvent di ReplicatedStorage atau tempat lain
        local cutEvent = game.ReplicatedStorage:FindFirstChild("CutEvent")
        if cutEvent then
            Remotes.AutoChop = {
                Instance = cutEvent,
                Type = "Event",
                Args = {} -- Will be set dynamically saat toggle
            }
        end
    end)
end

local function initializeRemotes()
    if currentPlaceId == 104785855204405 then -- Tree Cutting
        initializeRemotesTreeCutting()
    elseif currentPlaceId == 129827112113663 then -- Prospecting
        initializeRemotesProspecting()
    end
end

initializeRemotes()

player.CharacterAdded:Connect(function()
    wait(1)
    initializeRemotes()
end)

-- Toggle states (DINAMIS)
local toggles = {
    AutoChop = false,
    AutoDig = false,
    AutoPan = false,
    AutoShake = false,
    Fly = false,
    Noclip = false
}

local walkSpeedValue = 16

-- Auto loop untuk remotes
spawn(function()
    while true do
        for name, isActive in pairs(toggles) do
            if isActive and Remotes[name] then
                pcall(function()
                    local remote = Remotes[name]
                    
                    if name == "AutoChop" then
                        -- Special handling untuk Auto Cut Trees
                        local TreesFolder = workspace:FindFirstChild("Trees") or workspace:FindFirstChild("TreesFolder")
                        if TreesFolder then
                            for _, tree in ipairs(TreesFolder:GetChildren()) do
                                local ID = tonumber(tree.Name)
                                if ID and tree:FindFirstChild("ObjectData") then
                                    local data = tree.ObjectData
                                    if data:FindFirstChild("Health") and data.Health.Value > 0 then
                                        remote.Instance:FireServer(ID)
                                    end
                                end
                            end
                        end
                    else
                        -- Standard remote calling
                        if remote.Type == "Function" then
                            remote.Instance:InvokeServer(unpack(remote.Args))
                        elseif remote.Type == "Event" then
                            remote.Instance:FireServer(unpack(remote.Args))
                        end
                    end
                end)
            end
        end
        wait(0.1)
    end
end)

-- Fly functionality
local flying = false
local flySpeed = 50
local bodyVelocity, bodyGyro
local flyControlGui

local function createFlyControls()
    local controlFrame = Instance.new("Frame")
    controlFrame.Name = "FlyControls"
    controlFrame.Size = UDim2.new(0, 160, 0, 160)
    controlFrame.Position = UDim2.new(0, 20, 1, -180)
    controlFrame.BackgroundTransparency = 1
    controlFrame.Parent = playerGui:WaitForChild("ArcheronHub")
    controlFrame.Visible = false
    
    local joystickBg = Instance.new("Frame")
    joystickBg.Size = UDim2.new(0, 120, 0, 120)
    joystickBg.Position = UDim2.new(0, 0, 0, 0)
    joystickBg.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    joystickBg.BackgroundTransparency = 0.5
    joystickBg.BorderSizePixel = 0
    joystickBg.Parent = controlFrame
    
    local joystickCorner = Instance.new("UICorner")
    joystickCorner.CornerRadius = UDim.new(1, 0)
    joystickCorner.Parent = joystickBg
    
    local joystickKnob = Instance.new("Frame")
    joystickKnob.Size = UDim2.new(0, 50, 0, 50)
    joystickKnob.Position = UDim2.new(0.5, -25, 0.5, -25)
    joystickKnob.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
    joystickKnob.BackgroundTransparency = 0.3
    joystickKnob.BorderSizePixel = 0
    joystickKnob.Parent = joystickBg
    
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = joystickKnob
    
    local upBtn = Instance.new("TextButton")
    upBtn.Size = UDim2.new(0, 50, 0, 50)
    upBtn.Position = UDim2.new(1, -60, 0, 0)
    upBtn.Text = "▲"
    upBtn.Font = Enum.Font.GothamBold
    upBtn.TextSize = 20
    upBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    upBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    upBtn.BackgroundTransparency = 0.5
    upBtn.BorderSizePixel = 0
    upBtn.Parent = controlFrame
    
    local upCorner = Instance.new("UICorner")
    upCorner.CornerRadius = UDim.new(1, 0)
    upCorner.Parent = upBtn
    
    local downBtn = Instance.new("TextButton")
    downBtn.Size = UDim2.new(0, 50, 0, 50)
    downBtn.Position = UDim2.new(1, -60, 1, -50)
    downBtn.Text = "▼"
    downBtn.Font = Enum.Font.GothamBold
    downBtn.TextSize = 20
    downBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    downBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    downBtn.BackgroundTransparency = 0.5
    downBtn.BorderSizePixel = 0
    downBtn.Parent = controlFrame
    
    local downCorner = Instance.new("UICorner")
    downCorner.CornerRadius = UDim.new(1, 0)
    downCorner.Parent = downBtn
    
    return controlFrame, joystickBg, joystickKnob, upBtn, downBtn
end

local function startFly()
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        local rootPart = player.Character.HumanoidRootPart
        
        bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        bodyVelocity.Parent = rootPart
        
        bodyGyro = Instance.new("BodyGyro")
        bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        bodyGyro.P = 9e4
        bodyGyro.Parent = rootPart
        
        flying = true
        local controlFrame, joystickBg, joystickKnob, upBtn, downBtn = createFlyControls()
        flyControlGui = controlFrame
        
        local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
        if isMobile then
            controlFrame.Visible = true
        end
        
        local joystickActive = false
        local joystickInput = Vector2.new(0, 0)
        local upPressed = false
        local downPressed = false
        
        joystickBg.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or 
               input.UserInputType == Enum.UserInputType.MouseButton1 then
                joystickActive = true
            end
        end)
        
        joystickBg.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or 
               input.UserInputType == Enum.UserInputType.MouseButton1 then
                joystickActive = false
                joystickInput = Vector2.new(0, 0)
                joystickKnob.Position = UDim2.new(0.5, -25, 0.5, -25)
            end
        end)
        
        UserInputService.InputChanged:Connect(function(input)
            if joystickActive and (input.UserInputType == Enum.UserInputType.Touch or 
               input.UserInputType == Enum.UserInputType.MouseMovement) then
                local center = joystickBg.AbsolutePosition + joystickBg.AbsoluteSize / 2
                local mousePos = Vector2.new(input.Position.X, input.Position.Y)
                local delta = mousePos - center
                local distance = math.min(delta.Magnitude, 35)
                local direction = delta.Unit
                
                joystickInput = direction * (distance / 35)
                joystickKnob.Position = UDim2.new(0.5, direction.X * distance - 25, 0.5, direction.Y * distance - 25)
            end
        end)
        
        upBtn.MouseButton1Down:Connect(function() upPressed = true end)
        upBtn.MouseButton1Up:Connect(function() upPressed = false end)
        downBtn.MouseButton1Down:Connect(function() downPressed = true end)
        downBtn.MouseButton1Up:Connect(function() downPressed = false end)
        
        spawn(function()
            local camera = workspace.CurrentCamera
            while flying and toggles.Fly do
                local moveDirection = Vector3.new(0, 0, 0)
                
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                    moveDirection = moveDirection + (camera.CFrame.LookVector)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                    moveDirection = moveDirection - (camera.CFrame.LookVector)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                    moveDirection = moveDirection - (camera.CFrame.RightVector)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                    moveDirection = moveDirection + (camera.CFrame.RightVector)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                    moveDirection = moveDirection + Vector3.new(0, 1, 0)
                end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                    moveDirection = moveDirection - Vector3.new(0, 1, 0)
                end
                
                if joystickInput.Magnitude > 0 then
                    local forward = camera.CFrame.LookVector * -joystickInput.Y
                    local right = camera.CFrame.RightVector * joystickInput.X
                    moveDirection = moveDirection + forward + right
                end
                
                if upPressed then
                    moveDirection = moveDirection + Vector3.new(0, 1, 0)
                end
                if downPressed then
                    moveDirection = moveDirection - Vector3.new(0, 1, 0)
                end
                
                if bodyVelocity and bodyGyro then
                    bodyVelocity.Velocity = moveDirection * flySpeed
                    bodyGyro.CFrame = camera.CFrame
                end
                
                wait()
            end
        end)
    end
end

local function stopFly()
    flying = false
    if bodyVelocity then
        bodyVelocity:Destroy()
        bodyVelocity = nil
    end
    if bodyGyro then
        bodyGyro:Destroy()
        bodyGyro = nil
    end
    if flyControlGui then
        flyControlGui:Destroy()
        flyControlGui = nil
    end
end

-- Noclip functionality
spawn(function()
    while true do
        if toggles.Noclip and player.Character then
            for _, part in pairs(player.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
        wait(0.1)
    end
end)

-- WalkSpeed functionality
spawn(function()
    while true do
        if player.Character and player.Character:FindFirstChild("Humanoid") then
            player.Character.Humanoid.WalkSpeed = walkSpeedValue
        end
        wait(0.1)
    end
end)

-- ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ArcheronHub"
screenGui.Parent = playerGui
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Toggle Frame
local toggleFrame = Instance.new("Frame")
toggleFrame.Size = UDim2.new(0, 200, 0, 50)
toggleFrame.Position = UDim2.new(0.5, -100, 0, 20)
toggleFrame.BackgroundColor3 = Color3.fromRGB(15, 20, 15)
toggleFrame.BackgroundTransparency = 0.1
toggleFrame.BorderSizePixel = 0
toggleFrame.Parent = screenGui
toggleFrame.ZIndex = 10
toggleFrame.Active = true

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 25)
toggleCorner.Parent = toggleFrame

local toggleStroke = Instance.new("UIStroke")
toggleStroke.Color = Color3.fromRGB(80, 80, 85)
toggleStroke.Thickness = 1.5
toggleStroke.Transparency = 0.3
toggleStroke.Parent = toggleFrame

local dragIcon = Instance.new("TextLabel")
dragIcon.Size = UDim2.new(0, 35, 1, 0)
dragIcon.Position = UDim2.new(0, 5, 0, 0)
dragIcon.Text = "⊕"
dragIcon.Font = Enum.Font.GothamBold
dragIcon.TextSize = 24
dragIcon.TextColor3 = Color3.fromRGB(200, 200, 200)
dragIcon.BackgroundTransparency = 1
dragIcon.Parent = toggleFrame

local lightningIcon = Instance.new("TextLabel")
lightningIcon.Size = UDim2.new(0, 30, 1, 0)
lightningIcon.Position = UDim2.new(0, 40, 0, 0)
lightningIcon.Text = "⚡"
lightningIcon.Font = Enum.Font.GothamBold
lightningIcon.TextSize = 20
lightningIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
lightningIcon.BackgroundTransparency = 1
lightningIcon.Parent = toggleFrame

local toggleTitle = Instance.new("TextLabel")
toggleTitle.Size = UDim2.new(0, 120, 1, 0)
toggleTitle.Position = UDim2.new(0, 75, 0, 0)
toggleTitle.Text = "Archeron - Hub"
toggleTitle.Font = Enum.Font.GothamBold
toggleTitle.TextSize = 15
toggleTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleTitle.BackgroundTransparency = 1
toggleTitle.TextXAlignment = Enum.TextXAlignment.Left
toggleTitle.Parent = toggleFrame

-- Main Frame
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 550, 0, 380)
mainFrame.Position = UDim2.new(0.5, -275, 0.5, -190)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.Active = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = mainFrame

-- Header
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 50)
header.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
header.BorderSizePixel = 0
header.Active = true
header.Parent = mainFrame

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 12)
headerCorner.Parent = header

local headerCover = Instance.new("Frame")
headerCover.Size = UDim2.new(1, 0, 0, 12)
headerCover.Position = UDim2.new(0, 0, 1, -12)
headerCover.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
headerCover.BorderSizePixel = 0
headerCover.Parent = header

local logoIcon = Instance.new("ImageLabel")
logoIcon.Size = UDim2.new(0, 30, 0, 30)
logoIcon.Position = UDim2.new(0, 12, 0.5, -15)
logoIcon.BackgroundTransparency = 1
logoIcon.BorderSizePixel = 0
logoIcon.Image = "rbxassetid://139400776308881"
logoIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
logoIcon.ScaleType = Enum.ScaleType.Fit
logoIcon.ZIndex = 1
logoIcon.Parent = header

local logoCorner = Instance.new("UICorner")
logoCorner.CornerRadius = UDim.new(0, 8)
logoCorner.Parent = logoIcon

-- Glow frame
local glowFrame = Instance.new("Frame")
glowFrame.Size = UDim2.new(0, 38, 0, 38)
glowFrame.Position = UDim2.new(0, 8, 0.5, -19)
glowFrame.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
glowFrame.BackgroundTransparency = 0.6
glowFrame.BorderSizePixel = 0
glowFrame.ZIndex = 0
glowFrame.Parent = header

local glowCorner = Instance.new("UICorner")
glowCorner.CornerRadius = UDim.new(0, 10)
glowCorner.Parent = glowFrame

-- Pulsing animation
spawn(function()
    while glowFrame and glowFrame.Parent do
        -- Glow terang
        TweenService:Create(glowFrame, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            BackgroundTransparency = 0.3,
            Size = UDim2.new(0, 42, 0, 42),
            Position = UDim2.new(0, 6, 0.5, -21)
        }):Play()
        wait(1)
        
        -- Glow redup
        TweenService:Create(glowFrame, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
            BackgroundTransparency = 0.7,
            Size = UDim2.new(0, 38, 0, 38),
            Position = UDim2.new(0, 8, 0.5, -19)
        }):Play()
        wait(1)
    end
end)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0, 180, 0, 22)
titleLabel.Position = UDim2.new(0, 50, 0, 7)
titleLabel.Text = gameConfig.name
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 18
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.BackgroundTransparency = 1
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = header

local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.Size = UDim2.new(0, 280, 0, 16)
subtitleLabel.Position = UDim2.new(0, 50, 0, 28)
subtitleLabel.Text = "Archeron Hub"
subtitleLabel.Font = Enum.Font.Gotham
subtitleLabel.TextSize = 11
subtitleLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
subtitleLabel.Parent = header

local function createControlButton(icon, position, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 30, 0, 30)
    btn.Position = position
    btn.Text = icon
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 16
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.BackgroundColor3 = color
    btn.BackgroundTransparency = 0.7
    btn.BorderSizePixel = 0
    btn.Parent = header
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = btn
    
    btn.MouseEnter:Connect(function()
        btn.BackgroundTransparency = 0.3
    end)
    
    btn.MouseLeave:Connect(function()
        btn.BackgroundTransparency = 0.7
    end)
    
    return btn
end

local minimizeBtn = createControlButton("-", UDim2.new(1, -120, 0.5, -15), Color3.fromRGB(60, 60, 65))
local maximizeBtn = createControlButton("⛶", UDim2.new(1, -80, 0.5, -15), Color3.fromRGB(60, 60, 65))
local closeBtn = createControlButton("X", UDim2.new(1, -40, 0.5, -15), Color3.fromRGB(220, 50, 50))

-- Sidebar
local sidebar = Instance.new("ScrollingFrame")
sidebar.Size = UDim2.new(0, 180, 1, -50)
sidebar.Position = UDim2.new(0, 0, 0, 50)
sidebar.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
sidebar.BorderSizePixel = 0
sidebar.ScrollBarThickness = 4
sidebar.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 105)
sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y
sidebar.ScrollingDirection = Enum.ScrollingDirection.Y
sidebar.Parent = mainFrame

local sidebarList = Instance.new("UIListLayout")
sidebarList.SortOrder = Enum.SortOrder.LayoutOrder
sidebarList.Padding = UDim.new(0, 4)
sidebarList.Parent = sidebar

local sidebarPadding = Instance.new("UIPadding")
sidebarPadding.PaddingTop = UDim.new(0, 10)
sidebarPadding.PaddingLeft = UDim.new(0, 10)
sidebarPadding.PaddingRight = UDim.new(0, 10)
sidebarPadding.PaddingBottom = UDim.new(0, 10)
sidebarPadding.Parent = sidebar

-- Content area
local contentFrame = Instance.new("ScrollingFrame")
contentFrame.Size = UDim2.new(1, -180, 1, -50)
contentFrame.Position = UDim2.new(0, 180, 0, 50)
contentFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
contentFrame.BorderSizePixel = 0
contentFrame.ScrollBarThickness = 5
contentFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 105)
contentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
contentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
contentFrame.ScrollingDirection = Enum.ScrollingDirection.Y
contentFrame.Parent = mainFrame

local contentPadding = Instance.new("UIPadding")
contentPadding.PaddingTop = UDim.new(0, 15)
contentPadding.PaddingLeft = UDim.new(0, 15)
contentPadding.PaddingRight = UDim.new(0, 15)
contentPadding.PaddingBottom = UDim.new(0, 15)
contentPadding.Parent = contentFrame

local contentList = Instance.new("UIListLayout")
contentList.SortOrder = Enum.SortOrder.LayoutOrder
contentList.Padding = UDim.new(0, 12)
contentList.Parent = contentFrame

local function clearContent()
    for _, child in ipairs(contentFrame:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextButton") then
            child:Destroy()
        end
    end
end

local function createOwnerCard()
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 80)
    card.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    card.BorderSizePixel = 0
    card.Parent = contentFrame
    
    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 10)
    cardCorner.Parent = card
    
    local ownerTitle = Instance.new("TextLabel")
    ownerTitle.Size = UDim2.new(1, -30, 0, 28)
    ownerTitle.Position = UDim2.new(0, 15, 0, 15)
    ownerTitle.Text = "Owner:"
    ownerTitle.Font = Enum.Font.GothamBold
    ownerTitle.TextSize = 16
    ownerTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    ownerTitle.BackgroundTransparency = 1
    ownerTitle.TextXAlignment = Enum.TextXAlignment.Left
    ownerTitle.Parent = card
    
    local ownerName = Instance.new("TextLabel")
    ownerName.Size = UDim2.new(1, -30, 0, 24)
    ownerName.Position = UDim2.new(0, 15, 0, 43)
    ownerName.Text = "Archeron"
    ownerName.Font = Enum.Font.GothamBold
    ownerName.TextSize = 20
    ownerName.TextColor3 = Color3.fromRGB(138, 43, 226)
    ownerName.BackgroundTransparency = 1
    ownerName.TextXAlignment = Enum.TextXAlignment.Left
    ownerName.Parent = card
end

local function createFeatureButton(featureName, featureDesc, toggleKey, hasWarning, noteText)
    local featureBtn = Instance.new("Frame")
    local btnHeight = noteText and 110 or 65
    featureBtn.Size = UDim2.new(1, 0, 0, btnHeight)
    featureBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    featureBtn.BorderSizePixel = 0
    featureBtn.Parent = contentFrame
    
    local featureBtnCorner = Instance.new("UICorner")
    featureBtnCorner.CornerRadius = UDim.new(0, 10)
    featureBtnCorner.Parent = featureBtn
    
    local featureTitle = Instance.new("TextLabel")
    featureTitle.Size = UDim2.new(1, -70, 0, 22)
    featureTitle.Position = UDim2.new(0, 15, 0, 10)
    featureTitle.Text = (hasWarning and "⚠ " or "") .. featureName
    featureTitle.Font = Enum.Font.GothamBold
    featureTitle.TextSize = 14
    featureTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    featureTitle.BackgroundTransparency = 1
    featureTitle.TextXAlignment = Enum.TextXAlignment.Left
    featureTitle.Parent = featureBtn
    
    local featureDescLabel = Instance.new("TextLabel")
    featureDescLabel.Size = UDim2.new(1, -70, 0, 16)
    featureDescLabel.Position = UDim2.new(0, 15, 0, 32)
    featureDescLabel.Text = featureDesc
    featureDescLabel.Font = Enum.Font.Gotham
    featureDescLabel.TextSize = 11
    featureDescLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    featureDescLabel.BackgroundTransparency = 1
    featureDescLabel.TextXAlignment = Enum.TextXAlignment.Left
    featureDescLabel.Parent = featureBtn
    
    -- Note/Warning text jika ada
    if noteText then
        local noteLabel = Instance.new("TextLabel")
        noteLabel.Size = UDim2.new(1, -30, 0, 45)
        noteLabel.Position = UDim2.new(0, 15, 0, 50)
        noteLabel.Text = noteText
        noteLabel.Font = Enum.Font.Gotham
        noteLabel.TextSize = 9
        noteLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
        noteLabel.BackgroundTransparency = 1
        noteLabel.TextXAlignment = Enum.TextXAlignment.Left
        noteLabel.TextWrapped = true
        noteLabel.Parent = featureBtn
    end
    
    local toggleSwitch = Instance.new("TextButton")
    toggleSwitch.Size = UDim2.new(0, 45, 0, 24)
    toggleSwitch.Position = UDim2.new(1, -60, 0.5, -12)
    toggleSwitch.Text = ""
    toggleSwitch.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
    toggleSwitch.BorderSizePixel = 0
    toggleSwitch.Parent = featureBtn
    
    local switchCorner = Instance.new("UICorner")
    switchCorner.CornerRadius = UDim.new(1, 0)
    switchCorner.Parent = toggleSwitch
    
    local switchKnob = Instance.new("Frame")
    switchKnob.Size = UDim2.new(0, 18, 0, 18)
    switchKnob.Position = UDim2.new(0, 3, 0.5, -9)
    switchKnob.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
    switchKnob.BorderSizePixel = 0
    switchKnob.Parent = toggleSwitch
    
    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = switchKnob
    
    if toggleKey and toggles[toggleKey] then
        toggleSwitch.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
        switchKnob.Position = UDim2.new(1, -21, 0.5, -9)
    end
    
    toggleSwitch.MouseButton1Click:Connect(function()
        if toggleKey then
            toggles[toggleKey] = not toggles[toggleKey]
            
            if toggles[toggleKey] then
                toggleSwitch.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
                TweenService:Create(switchKnob, TweenInfo.new(0.2), {
                    Position = UDim2.new(1, -21, 0.5, -9)
                }):Play()
                
                if toggleKey == "Fly" then
                    startFly()
                end
            else
                toggleSwitch.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
                TweenService:Create(switchKnob, TweenInfo.new(0.2), {
                    Position = UDim2.new(0, 3, 0.5, -9)
                }):Play()
                
                if toggleKey == "Fly" then
                    stopFly()
                end
                if toggleKey == "Noclip" and player.Character then
                    for _, part in pairs(player.Character:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = true
                        end
                    end
                end
            end
        end
    end)
end

local function createWalkSpeedSlider()
    local sliderFrame = Instance.new("Frame")
    sliderFrame.Size = UDim2.new(1, 0, 0, 85)
    sliderFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    sliderFrame.BorderSizePixel = 0
    sliderFrame.Parent = contentFrame
    
    local sliderCorner = Instance.new("UICorner")
    sliderCorner.CornerRadius = UDim.new(0, 10)
    sliderCorner.Parent = sliderFrame
    
    local sliderTitle = Instance.new("TextLabel")
    sliderTitle.Size = UDim2.new(1, -30, 0, 22)
    sliderTitle.Position = UDim2.new(0, 15, 0, 10)
    sliderTitle.Text = "WalkSpeed"
    sliderTitle.Font = Enum.Font.GothamBold
    sliderTitle.TextSize = 14
    sliderTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    sliderTitle.BackgroundTransparency = 1
    sliderTitle.TextXAlignment = Enum.TextXAlignment.Left
    sliderTitle.Parent = sliderFrame
    
    local sliderValue = Instance.new("TextLabel")
    sliderValue.Size = UDim2.new(0, 60, 0, 22)
    sliderValue.Position = UDim2.new(1, -75, 0, 10)
    sliderValue.Text = tostring(walkSpeedValue)
    sliderValue.Font = Enum.Font.GothamBold
    sliderValue.TextSize = 14
    sliderValue.TextColor3 = Color3.fromRGB(138, 43, 226)
    sliderValue.BackgroundTransparency = 1
    sliderValue.TextXAlignment = Enum.TextXAlignment.Right
    sliderValue.Parent = sliderFrame
    
    local sliderDesc = Instance.new("TextLabel")
    sliderDesc.Size = UDim2.new(1, -30, 0, 16)
    sliderDesc.Position = UDim2.new(0, 15, 0, 32)
    sliderDesc.Text = "Atur kecepatan berjalan"
    sliderDesc.Font = Enum.Font.Gotham
    sliderDesc.TextSize = 11
    sliderDesc.TextColor3 = Color3.fromRGB(150, 150, 150)
    sliderDesc.BackgroundTransparency = 1
    sliderDesc.TextXAlignment = Enum.TextXAlignment.Left
    sliderDesc.Parent = sliderFrame
    
    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(1, -30, 0, 6)
    sliderBg.Position = UDim2.new(0, 15, 1, -20)
    sliderBg.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
    sliderBg.BorderSizePixel = 0
    sliderBg.Parent = sliderFrame
    
    local sliderBgCorner = Instance.new("UICorner")
    sliderBgCorner.CornerRadius = UDim.new(1, 0)
    sliderBgCorner.Parent = sliderBg
    
    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new((walkSpeedValue - 16) / (200 - 16), 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderBg
    
    local sliderFillCorner = Instance.new("UICorner")
    sliderFillCorner.CornerRadius = UDim.new(1, 0)
    sliderFillCorner.Parent = sliderFill
    
    local sliderKnob = Instance.new("Frame")
    sliderKnob.Size = UDim2.new(0, 16, 0, 16)
    sliderKnob.Position = UDim2.new((walkSpeedValue - 16) / (200 - 16), -8, 0.5, -8)
    sliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    sliderKnob.BorderSizePixel = 0
    sliderKnob.Parent = sliderBg
    
    local sliderKnobCorner = Instance.new("UICorner")
    sliderKnobCorner.CornerRadius = UDim.new(1, 0)
    sliderKnobCorner.Parent = sliderKnob
    
    local draggingSlider = false
    
    sliderKnob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = true
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or 
           input.UserInputType == Enum.UserInputType.Touch) then
            local mousePos = UserInputService:GetMouseLocation()
            local sliderPos = sliderBg.AbsolutePosition.X
            local sliderSize = sliderBg.AbsoluteSize.X
            
            local relative = math.clamp((mousePos.X - sliderPos) / sliderSize, 0, 1)
            walkSpeedValue = math.floor(16 + (relative * (200 - 16)))
            
            sliderValue.Text = tostring(walkSpeedValue)
            sliderFill.Size = UDim2.new(relative, 0, 1, 0)
            sliderKnob.Position = UDim2.new(relative, -8, 0.5, -8)
        end
    end)
    
    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            local mousePos = UserInputService:GetMouseLocation()
            local sliderPos = sliderBg.AbsolutePosition.X
            local sliderSize = sliderBg.AbsoluteSize.X
            
            local relative = math.clamp((mousePos.X - sliderPos) / sliderSize, 0, 1)
            walkSpeedValue = math.floor(16 + (relative * (200 - 16)))
            
            sliderValue.Text = tostring(walkSpeedValue)
            sliderFill.Size = UDim2.new(relative, 0, 1, 0)
            sliderKnob.Position = UDim2.new(relative, -8, 0.5, -8)
        end
    end)
end

-- Create dynamic menu berdasarkan gameConfig
local function showContentByCategory(categoryName)
    clearContent()
    
    if categoryName == "Information" then
        createOwnerCard()
    else
        local features = gameConfig.features[categoryName]
        if features then
            for _, feature in ipairs(features) do
                createFeatureButton(feature.name, feature.desc, feature.key, feature.warning, feature.note)
            end
            
            -- Tambah slider WalkSpeed di menu Player
            if categoryName == "Player" then
                createWalkSpeedSlider()
            end
        end
    end
end

-- Buat sidebar buttons DINAMIS
local currentSelectedButton = nil
local function createSidebarButton(icon, text, categoryName, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    btn.BackgroundTransparency = 1
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.LayoutOrder = order
    btn.Parent = sidebar
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = btn
    
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.new(0, 28, 1, 0)
    iconLabel.Position = UDim2.new(0, 5, 0, 0)
    iconLabel.Text = icon
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextSize = 15
    iconLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Parent = btn
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -38, 1, 0)
    textLabel.Position = UDim2.new(0, 38, 0, 0)
    textLabel.Text = text
    textLabel.Font = Enum.Font.Gotham
    textLabel.TextSize = 13
    textLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    textLabel.BackgroundTransparency = 1
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.Parent = btn
    
    btn.MouseEnter:Connect(function()
        if currentSelectedButton ~= btn then
            btn.BackgroundTransparency = 0.5
        end
    end)
    
    btn.MouseLeave:Connect(function()
        if currentSelectedButton ~= btn then
            btn.BackgroundTransparency = 1
        end
    end)
    
    btn.MouseButton1Click:Connect(function()
        if currentSelectedButton then
            currentSelectedButton.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
            currentSelectedButton.BackgroundTransparency = 1
        end
        
        btn.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
        btn.BackgroundTransparency = 0.7
        currentSelectedButton = btn
        
        showContentByCategory(categoryName)
    end)
end

-- Buat menu dinamis dari gameConfig
local menuOrder = 1
createSidebarButton("ℹ", "Information", "Information", menuOrder)
menuOrder = menuOrder + 1

if gameConfig.features.Main then
    createSidebarButton("👁", "Main", "Main", menuOrder)
    menuOrder = menuOrder + 1
end

if gameConfig.features.Player then
    createSidebarButton("⚙", "Player", "Player", menuOrder)
    menuOrder = menuOrder + 1
end

-- Tampilkan default content
showContentByCategory("Information")

-- Drag untuk toggle button
local draggingToggle = false
local dragStartToggle = Vector2.new(0, 0)
local startPosToggle = UDim2.new(0, 0, 0, 0)

dragIcon.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or 
       input.UserInputType == Enum.UserInputType.Touch then
        draggingToggle = true
        dragStartToggle = input.Position
        startPosToggle = toggleFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                draggingToggle = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if draggingToggle and (input.UserInputType == Enum.UserInputType.MouseMovement or 
       input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStartToggle
        toggleFrame.Position = UDim2.new(
            startPosToggle.X.Scale,
            startPosToggle.X.Offset + delta.X,
            startPosToggle.Y.Scale,
            startPosToggle.Y.Offset + delta.Y
        )
    end
end)

-- Drag untuk main frame
local dragging = false
local dragStart = Vector2.new(0, 0)
local startPos = UDim2.new(0, 0, 0, 0)

header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or 
       input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or 
       input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

-- Toggle GUI
local function toggleGUI()
    mainFrame.Visible = not mainFrame.Visible
    if mainFrame.Visible then
        mainFrame.Size = UDim2.new(0, 0, 0, 0)
        TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 550, 0, 380)
        }):Play()
    else
        TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0)
        }):Play()
    end
end

local clickStartTime = 0
toggleFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or 
       input.UserInputType == Enum.UserInputType.Touch then
        clickStartTime = tick()
    end
end)

toggleFrame.InputEnded:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseButton1 or 
       input.UserInputType == Enum.UserInputType.Touch) and 
       not draggingToggle and (tick() - clickStartTime) < 0.3 then
        toggleGUI()
    end
end)

-- Close button
closeBtn.MouseButton1Click:Connect(function()
    TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 0)
    }):Play()
    wait(0.2)
    mainFrame.Visible = false
end)

-- Minimize button
minimizeBtn.MouseButton1Click:Connect(function()
    TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 550, 0, 50)
    }):Play()
end)

-- Maximize button
maximizeBtn.MouseButton1Click:Connect(function()
    TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 550, 0, 380)
    }):Play()
end)

-- Keybind R
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.R then
        toggleGUI()
    end
end)

-- Hover effects
toggleFrame.MouseEnter:Connect(function()
    TweenService:Create(toggleFrame, TweenInfo.new(0.2), {
        BackgroundTransparency = 0
    }):Play()
end)

toggleFrame.MouseLeave:Connect(function()
    TweenService:Create(toggleFrame, TweenInfo.new(0.2), {
        BackgroundTransparency = 0.1
    }):Play()
end)

print("✅ Archeron - Hub loaded successfully!")
print("🎮 Game: " .. gameConfig.name)
print("📋 Press R to toggle menu")
