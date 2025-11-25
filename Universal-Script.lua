-- Archeron Hub Advanced GUI Script
-- Created for Roblox with Multi-Game & Multi-Language Support

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local LocalizationService = game:GetService("LocalizationService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Cek apakah GUI sudah ada
if playerGui:FindFirstChild("ArcheronHub") then
    playerGui.ArcheronHub:Destroy()
    print("⚠️ Old Archeron Hub GUI removed")
    wait(0.1)
end

-- Cek apakah toggle button sudah ada
if playerGui:FindFirstChild("ArcheronToggle") then
    playerGui.ArcheronToggle:Destroy()
    print("⚠️ Old Archeron Toggle removed")
    wait(0.1)
end

-- ========================================
-- LANGUAGE SYSTEM
-- ========================================

local currentLanguage = "en" -- default

-- Deteksi bahasa otomatis
local function detectLanguage()
    local success, result = pcall(function()
        return LocalizationService.RobloxLocaleId
    end)
    
    if success and result then
        if result:find("^id") then return "id" -- Indonesia
        elseif result:find("^es") then return "es" -- Spanish
        elseif result:find("^pt") then return "pt" -- Portuguese
        elseif result:find("^fr") then return "fr" -- French
        elseif result:find("^de") then return "de" -- German
        end
    end
    return "en" -- English default
end

currentLanguage = detectLanguage()

-- Translations dictionary
local translations = {
    en = {
        hubActive = "Archeron - Hub Active ✅",
        loadSuccess = "Successfully loaded and ready to use!",
        autoLoop = "Auto Loop",
        statusEnabled = "Status: Enabled",
        statusDisabled = "Status: Disabled",
        autoLoopEnabled = "Auto loop has been enabled!",
        autoLoopDisabled = "Auto loop has been disabled!",
        remoteConfig = "Remote Event Configuration",
        remoteDesc = "Edit REMOTE_EVENT_PATH in script to connect to game remote event.\nAuto Loop will automatically connect to the remote event you set.",
        
        -- Menu names
        menuMain = "🔥 Main",
        menuPlayer = "🕹️ Player",
        menuInfo = "📄 Information",
        menuMisc = "⚡ Misc",
        
        -- Features
        autoFarm = "Auto Farm",
        autoFarmDesc = "Automatically farm resources",
        autoChop = "Auto Chop",
        autoChopDesc = "Automatically chop trees",
        fly = "Fly",
        flyDesc = "Enable flight (Mobile compatible)",
        noclip = "Noclip",
        noclipDesc = "Walk through walls",
        walkspeed = "Walk Speed",
        walkspeedDesc = "Adjust your walking speed",
        jumppower = "Jump Power",
        jumppowerDesc = "Adjust your jump height",
        autoCollect = "Auto Collect",
        autoCollectDesc = "Automatically collect items",
        esp = "ESP",
        espDesc = "See players through walls",
        infiniteJump = "Infinite Jump",
        infiniteJumpDesc = "Jump infinitely",
        godMode = "God Mode",
        godModeDesc = "Take no damage",
    },
    id = {
        hubActive = "Archeron - Hub Aktif ✅",
        loadSuccess = "Berhasil dimuat dan siap digunakan!",
        autoLoop = "Loop Otomatis",
        statusEnabled = "Status: Aktif",
        statusDisabled = "Status: Nonaktif",
        autoLoopEnabled = "Loop otomatis telah diaktifkan!",
        autoLoopDisabled = "Loop otomatis telah dinonaktifkan!",
        remoteConfig = "Konfigurasi Remote Event",
        remoteDesc = "Edit REMOTE_EVENT_PATH di script untuk connect ke remote event game.\nAuto Loop akan otomatis nyambung ke remote event yang kamu set.",
        
        menuMain = "Utama",
        menuPlayer = "Pemain",
        menuInfo = "Informasi",
        menuMisc = "Lainnya",
        
        autoFarm = "Farm Otomatis",
        autoFarmDesc = "Farm sumber daya secara otomatis",
        autoChop = "Potong Otomatis",
        autoChopDesc = "Potong pohon secara otomatis",
        fly = "Terbang",
        flyDesc = "Aktifkan terbang (Kompatibel mobile)",
        noclip = "Tembus Dinding",
        noclipDesc = "Berjalan menembus dinding",
        walkspeed = "Kecepatan Jalan",
        walkspeedDesc = "Atur kecepatan berjalanmu",
        jumppower = "Kekuatan Lompat",
        jumppowerDesc = "Atur tinggi lompatanmu",
        autoCollect = "Ambil Otomatis",
        autoCollectDesc = "Ambil item secara otomatis",
        esp = "ESP",
        espDesc = "Lihat pemain melalui dinding",
        infiniteJump = "Lompat Tak Terbatas",
        infiniteJumpDesc = "Lompat tanpa batas",
        godMode = "Mode Dewa",
        godModeDesc = "Tidak menerima damage",
    }
}

local function getText(key)
    return translations[currentLanguage][key] or translations.en[key] or key
end

-- ========================================
-- GAME CONFIGURATIONS
-- ========================================

local gameConfigs = {
    -- Sticks Incremental
    [120870800305934] = {
        menus = {"menuMain", "menuPlayer", "menuInfo"},
        features = {
            menuMain = {
                {name = "autoChop", type = "toggle"},
                {name = "autoCollect", type = "toggle"},
                {name = "autoFarm", type = "toggle"},
            },
            menuPlayer = {
                {name = "fly", type = "toggle"},
                {name = "noclip", type = "toggle"},
                {name = "walkspeed", type = "slider", min = 16, max = 200, default = 16},
                {name = "jumppower", type = "slider", min = 50, max = 300, default = 50},
            },
            menuInfo = {
                -- Info static, bisa dikustom
            }
        }
    },
    
    -- Game Example 2 (ganti dengan game ID lain)
    [1234567890] = {
        menus = {"menuMain", "menuMisc"},
        features = {
            menuMain = {
                {name = "autoFarm", type = "toggle"},
                {name = "autoCollect", type = "toggle"},
            },
            menuMisc = {
                {name = "esp", type = "toggle"},
                {name = "infiniteJump", type = "toggle"},
                {name = "godMode", type = "toggle"},
            }
        }
    }
}

-- Get current game config
local currentGameId = game.PlaceId
local currentConfig = gameConfigs[currentGameId]

if not currentConfig then
    player:Kick("⚠️ Archeron Hub\n\nGame ini tidak didukung oleh Archeron Hub.\nSilakan gunakan di game yang didukung.")
    return
end

-- ========================================
-- CONFIGURATION SECTION
-- ========================================

local LOGO_TEXTURE_ID = "rbxassetid://139400776308881"
local REMOTE_EVENT_PATH = nil
local REMOTE_EVENT_NAME = "YourRemoteEvent"

local function getRemoteArgs()
    return {}
end

-- ========================================
-- MAIN GUI
-- ========================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ArcheronHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = playerGui

-- ========================================
-- NOTIFICATION SYSTEM
-- ========================================

local NotificationFrame = Instance.new("Frame")
NotificationFrame.Name = "NotificationContainer"
NotificationFrame.Size = UDim2.new(0, 300, 1, 0)
NotificationFrame.Position = UDim2.new(1, -320, 0, 0)
NotificationFrame.BackgroundTransparency = 1
NotificationFrame.Parent = ScreenGui

local notificationQueue = {}

local function createNotification(title, message, duration)
    duration = duration or 5
    
    local notif = Instance.new("Frame")
    notif.Size = UDim2.new(1, 0, 0, 80)
    notif.Position = UDim2.new(0, 0, 1, 20)
    notif.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    notif.BorderSizePixel = 0
    notif.ClipsDescendants = true
    notif.Parent = NotificationFrame
    
    local notifCorner = Instance.new("UICorner")
    notifCorner.CornerRadius = UDim.new(0, 10)
    notifCorner.Parent = notif
    
    local accentBar = Instance.new("Frame")
    accentBar.Size = UDim2.new(0, 4, 1, 0)
    accentBar.Position = UDim2.new(0, 0, 0, 0)
    accentBar.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
    accentBar.BorderSizePixel = 0
    accentBar.Parent = notif
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -50, 0, 25)
    titleLabel.Position = UDim2.new(0, 15, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 14
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = notif
    
    local messageLabel = Instance.new("TextLabel")
    messageLabel.Size = UDim2.new(1, -50, 0, 40)
    messageLabel.Position = UDim2.new(0, 15, 0, 35)
    messageLabel.BackgroundTransparency = 1
    messageLabel.Text = message
    messageLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
    messageLabel.Font = Enum.Font.Gotham
    messageLabel.TextSize = 12
    messageLabel.TextXAlignment = Enum.TextXAlignment.Left
    messageLabel.TextYAlignment = Enum.TextYAlignment.Top
    messageLabel.TextWrapped = true
    messageLabel.Parent = notif
    
    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.new(0, 30, 0, 30)
    icon.Position = UDim2.new(1, -40, 0, 10)
    icon.BackgroundTransparency = 1
    icon.Image = LOGO_TEXTURE_ID
    icon.ScaleType = Enum.ScaleType.Fit
    icon.Parent = notif
    
    local slideIn = TweenService:Create(notif, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, 0, 1, -90)
    })
    slideIn:Play()
    
    table.insert(notificationQueue, notif)
    
    spawn(function()
        task.wait(0.1)
        for i, n in ipairs(notificationQueue) do
            local targetPos = UDim2.new(0, 0, 1, -90 - ((i - 1) * 90))
            TweenService:Create(n, TweenInfo.new(0.3), {Position = targetPos}):Play()
        end
    end)
    
    spawn(function()
        task.wait(duration)
        local slideOut = TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(0, 0, 1, 20)
        })
        slideOut:Play()
        
        slideOut.Completed:Connect(function()
            for i, n in ipairs(notificationQueue) do
                if n == notif then
                    table.remove(notificationQueue, i)
                    break
                end
            end
            notif:Destroy()
            
            for i, n in ipairs(notificationQueue) do
                local targetPos = UDim2.new(0, 0, 1, -90 - ((i - 1) * 90))
                TweenService:Create(n, TweenInfo.new(0.3), {Position = targetPos}):Play()
            end
        end)
    end)
end

-- ========================================
-- MAIN FRAME WITH LOGO BACKGROUND
-- ========================================

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 700, 0, 450)
MainFrame.Position = UDim2.new(0.5, -350, 0.5, -225)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 15)
MainCorner.Parent = MainFrame

-- Background Logo (Watermark style)
local BackgroundLogo = Instance.new("ImageLabel")
BackgroundLogo.Name = "BackgroundLogo"
BackgroundLogo.Size = UDim2.new(0, 300, 0, 300)
BackgroundLogo.Position = UDim2.new(0.5, -150, 0.5, -150)
BackgroundLogo.AnchorPoint = Vector2.new(0.5, 0.5)
BackgroundLogo.BackgroundTransparency = 1
BackgroundLogo.Image = LOGO_TEXTURE_ID
BackgroundLogo.ImageTransparency = 0.95
BackgroundLogo.ScaleType = Enum.ScaleType.Fit
BackgroundLogo.ZIndex = 1
BackgroundLogo.Parent = MainFrame

local LogoCornerBg = Instance.new("UICorner")
LogoCornerBg.CornerRadius = UDim.new(0, 12)
LogoCornerBg.Parent = BackgroundLogo

-- Header Frame
local HeaderFrame = Instance.new("Frame")
HeaderFrame.Name = "HeaderFrame"
HeaderFrame.Size = UDim2.new(1, 0, 0, 70)
HeaderFrame.Position = UDim2.new(0, 0, 0, 0)
HeaderFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
HeaderFrame.BorderSizePixel = 0
HeaderFrame.ZIndex = 2
HeaderFrame.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 15)
HeaderCorner.Parent = HeaderFrame

local HeaderCover = Instance.new("Frame")
HeaderCover.Size = UDim2.new(1, 0, 0, 15)
HeaderCover.Position = UDim2.new(0, 0, 1, -15)
HeaderCover.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
HeaderCover.BorderSizePixel = 0
HeaderCover.ZIndex = 2
HeaderCover.Parent = HeaderFrame

-- Logo in Header
local LogoFrame = Instance.new("ImageLabel")
LogoFrame.Name = "LogoFrame"
LogoFrame.Size = UDim2.new(0, 50, 0, 50)
LogoFrame.Position = UDim2.new(0, 10, 0, 10)
LogoFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 65)
LogoFrame.BorderSizePixel = 0
LogoFrame.Image = LOGO_TEXTURE_ID
LogoFrame.ScaleType = Enum.ScaleType.Fit
LogoFrame.ZIndex = 3
LogoFrame.Parent = HeaderFrame

local LogoCorner = Instance.new("UICorner")
LogoCorner.CornerRadius = UDim.new(0, 10)
LogoCorner.Parent = LogoFrame

-- Text Info
local TextFrame = Instance.new("Frame")
TextFrame.Name = "TextFrame"
TextFrame.Size = UDim2.new(1, -70, 1, 0)
TextFrame.Position = UDim2.new(0, 70, 0, 0)
TextFrame.BackgroundTransparency = 1
TextFrame.ZIndex = 3
TextFrame.Parent = HeaderFrame

local GameNameLabel = Instance.new("TextLabel")
GameNameLabel.Name = "GameName"
GameNameLabel.Size = UDim2.new(1, 0, 0, 30)
GameNameLabel.Position = UDim2.new(0, 0, 0, 12)
GameNameLabel.BackgroundTransparency = 1
GameNameLabel.Text = "Loading..."
GameNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
GameNameLabel.Font = Enum.Font.GothamBold
GameNameLabel.TextSize = 18
GameNameLabel.TextXAlignment = Enum.TextXAlignment.Left
GameNameLabel.TextYAlignment = Enum.TextYAlignment.Top
GameNameLabel.ZIndex = 3
GameNameLabel.Parent = TextFrame

spawn(function()
    local success, gameName = pcall(function()
        return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
    end)
    if success then
        GameNameLabel.Text = gameName
    else
        GameNameLabel.Text = "Unknown Game"
    end
end)

local HubNameLabel = Instance.new("TextLabel")
HubNameLabel.Name = "HubName"
HubNameLabel.Size = UDim2.new(1, 0, 0, 20)
HubNameLabel.Position = UDim2.new(0, 0, 0, 42)
HubNameLabel.BackgroundTransparency = 1
HubNameLabel.Text = "Archeron - Hub"
HubNameLabel.TextColor3 = Color3.fromRGB(150, 150, 200)
HubNameLabel.Font = Enum.Font.Gotham
HubNameLabel.TextSize = 14
HubNameLabel.TextXAlignment = Enum.TextXAlignment.Left
HubNameLabel.TextYAlignment = Enum.TextYAlignment.Top
HubNameLabel.ZIndex = 3
HubNameLabel.Parent = TextFrame

-- ========================================
-- MENU SIDEBAR (BLUE BAR)
-- ========================================

local MenuSidebar = Instance.new("Frame")
MenuSidebar.Name = "MenuSidebar"
MenuSidebar.Size = UDim2.new(0, 150, 1, -90)
MenuSidebar.Position = UDim2.new(0, 10, 0, 80)
MenuSidebar.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
MenuSidebar.BorderSizePixel = 0
MenuSidebar.ZIndex = 2
MenuSidebar.Parent = MainFrame

local SidebarCorner = Instance.new("UICorner")
SidebarCorner.CornerRadius = UDim.new(0, 10)
SidebarCorner.Parent = MenuSidebar

local MenuList = Instance.new("UIListLayout")
MenuList.SortOrder = Enum.SortOrder.LayoutOrder
MenuList.Padding = UDim.new(0, 5)
MenuList.Parent = MenuSidebar

-- ========================================
-- CONTENT AREA (RIGHT SIDE)
-- ========================================

local ContentArea = Instance.new("ScrollingFrame")
ContentArea.Name = "ContentArea"
ContentArea.Size = UDim2.new(1, -180, 1, -90)
ContentArea.Position = UDim2.new(0, 170, 0, 80)
ContentArea.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
ContentArea.BorderSizePixel = 0
ContentArea.ScrollBarThickness = 6
ContentArea.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 120)
ContentArea.ZIndex = 2
ContentArea.Parent = MainFrame

local ContentCorner = Instance.new("UICorner")
ContentCorner.CornerRadius = UDim.new(0, 10)
ContentCorner.Parent = ContentArea

local ContentList = Instance.new("UIListLayout")
ContentList.SortOrder = Enum.SortOrder.LayoutOrder
ContentList.Padding = UDim.new(0, 10)
ContentList.Parent = ContentArea

local ContentPadding = Instance.new("UIPadding")
ContentPadding.PaddingTop = UDim.new(0, 10)
ContentPadding.PaddingLeft = UDim.new(0, 10)
ContentPadding.PaddingRight = UDim.new(0, 10)
ContentPadding.Parent = ContentArea

-- ========================================
-- FEATURE CREATION FUNCTIONS
-- ========================================

local featureStates = {}

local function createToggleFeature(featureName, parent)
    local featureKey = featureName
    featureStates[featureKey] = false
    
    local ToggleFrame = Instance.new("Frame")
    ToggleFrame.Size = UDim2.new(1, -10, 0, 70)
    ToggleFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    ToggleFrame.BorderSizePixel = 0
    ToggleFrame.Parent = parent
    
    local ToggleCorner = Instance.new("UICorner")
    ToggleCorner.CornerRadius = UDim.new(0, 10)
    ToggleCorner.Parent = ToggleFrame
    
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -100, 0, 25)
    Title.Position = UDim2.new(0, 15, 0, 10)
    Title.BackgroundTransparency = 1
    Title.Text = getText(featureName)
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 14
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = ToggleFrame
    
    local Desc = Instance.new("TextLabel")
    Desc.Size = UDim2.new(1, -100, 0, 30)
    Desc.Position = UDim2.new(0, 15, 0, 35)
    Desc.BackgroundTransparency = 1
    Desc.Text = getText(featureName .. "Desc")
    Desc.TextColor3 = Color3.fromRGB(150, 150, 170)
    Desc.Font = Enum.Font.Gotham
    Desc.TextSize = 11
    Desc.TextXAlignment = Enum.TextXAlignment.Left
    Desc.TextWrapped = true
    Desc.Parent = ToggleFrame
    
    local ToggleButton = Instance.new("TextButton")
    ToggleButton.Size = UDim2.new(0, 70, 0, 35)
    ToggleButton.Position = UDim2.new(1, -85, 0.5, -17.5)
    ToggleButton.BackgroundColor3 = Color3.fromRGB(200, 100, 100)
    ToggleButton.BorderSizePixel = 0
    ToggleButton.Text = "OFF"
    ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleButton.Font = Enum.Font.GothamBold
    ToggleButton.TextSize = 14
    ToggleButton.Parent = ToggleFrame
    
    local ButtonCorner = Instance.new("UICorner")
    ButtonCorner.CornerRadius = UDim.new(0, 8)
    ButtonCorner.Parent = ToggleButton
    
    ToggleButton.MouseButton1Click:Connect(function()
        featureStates[featureKey] = not featureStates[featureKey]
        
        if featureStates[featureKey] then
            ToggleButton.Text = "ON"
            ToggleButton.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
            createNotification(getText(featureName), getText("statusEnabled"), 3)
        else
            ToggleButton.Text = "OFF"
            ToggleButton.BackgroundColor3 = Color3.fromRGB(200, 100, 100)
            createNotification(getText(featureName), getText("statusDisabled"), 3)
        end
    end)
end

local function createSliderFeature(featureName, minVal, maxVal, defaultVal, parent)
    local featureKey = featureName
    featureStates[featureKey] = defaultVal
    
    local SliderFrame = Instance.new("Frame")
    SliderFrame.Size = UDim2.new(1, -10, 0, 90)
    SliderFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    SliderFrame.BorderSizePixel = 0
    SliderFrame.Parent = parent
    
    local SliderCorner = Instance.new("UICorner")
    SliderCorner.CornerRadius = UDim.new(0, 10)
    SliderCorner.Parent = SliderFrame
    
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -20, 0, 25)
    Title.Position = UDim2.new(0, 15, 0, 10)
    Title.BackgroundTransparency = 1
    Title.Text = getText(featureName)
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 14
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = SliderFrame
    
    local Desc = Instance.new("TextLabel")
    Desc.Size = UDim2.new(1, -20, 0, 20)
    Desc.Position = UDim2.new(0, 15, 0, 35)
    Desc.BackgroundTransparency = 1
    Desc.Text = getText(featureName .. "Desc")
    Desc.TextColor3 = Color3.fromRGB(150, 150, 170)
    Desc.Font = Enum.Font.Gotham
    Desc.TextSize = 11
    Desc.TextXAlignment = Enum.TextXAlignment.Left
    Desc.Parent = SliderFrame
    
    local ValueLabel = Instance.new("TextLabel")
    ValueLabel.Size = UDim2.new(0, 60, 0, 20)
    ValueLabel.Position = UDim2.new(1, -75, 0, 10)
    ValueLabel.BackgroundTransparency = 1
    ValueLabel.Text = tostring(defaultVal)
    ValueLabel.TextColor3 = Color3.fromRGB(138, 43, 226)
    ValueLabel.Font = Enum.Font.GothamBold
    ValueLabel.TextSize = 14
    ValueLabel.Parent = SliderFrame
    
    local SliderBar = Instance.new("Frame")
    SliderBar.Size = UDim2.new(1, -30, 0, 8)
    SliderBar.Position = UDim2.new(0, 15, 1, -20)
    SliderBar.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    SliderBar.BorderSizePixel = 0
    SliderBar.Parent = SliderFrame
    
    local SliderBarCorner = Instance.new("UICorner")
    SliderBarCorner.CornerRadius = UDim.new(1, 0)
    SliderBarCorner.Parent = SliderBar
    
    local SliderFill = Instance.new("Frame")
    SliderFill.Size = UDim2.new((defaultVal - minVal) / (maxVal - minVal), 0, 1, 0)
    SliderFill.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
    SliderFill.BorderSizePixel = 0
    SliderFill.Parent = SliderBar
    
    local SliderFillCorner = Instance.new("UICorner")
    SliderFillCorner.CornerRadius = UDim.new(1, 0)
    SliderFillCorner.Parent = SliderFill
    
    local SliderButton = Instance.new("TextButton")
    SliderButton.Size = UDim2.new(1, 0, 1, 0)
    SliderButton.BackgroundTransparency = 1
    SliderButton.Text = ""
    SliderButton.Parent = SliderBar
    
    local dragging = false
    
    SliderButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    
    SliderButton.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    game:GetService("UserInputService").InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local pos = (input.Position.X - SliderBar.AbsolutePosition.X) / SliderBar.AbsoluteSize.X
            pos = math.clamp(pos, 0, 1)
            
            local value = math.floor(minVal + (maxVal - minVal) * pos)
            featureStates[featureKey] = value
            ValueLabel.Text = tostring(value)
            
            TweenService:Create(SliderFill, TweenInfo.new(0.1), {Size = UDim2.new(pos, 0, 1, 0)}):Play()
        end
    end)
end

-- ========================================
-- MENU SYSTEM
-- ========================================

local currentMenu = nil
local menuButtons = {}

local function clearContent()
    for _, child in ipairs(ContentArea:GetChildren()) do
        if child:IsA("Frame") and child.Name ~= "UIListLayout" and child.Name ~= "UIPadding" then
            child:Destroy()
        end
    end
end

local function loadMenu(menuKey)
    if currentMenu == menuKey then return end
    currentMenu = menuKey
    
    -- Update button states
    for key, btn in pairs(menuButtons) do
        if key == menuKey then
            btn.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
        else
            btn.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
        end
    end
    
    -- Clear and load new content
    clearContent()
    
    local features = currentConfig.features[menuKey]
    if features then
        for _, feature in ipairs(features) do
            if feature.type == "toggle" then
                createToggleFeature(feature.name, ContentArea)
            elseif feature.type == "slider" then
                createSliderFeature(feature.name, feature.min, feature.max, feature.default, ContentArea)
            end
        end
    end
    
    -- Update canvas size
    task.wait(0.1)
    ContentArea.CanvasSize = UDim2.new(0, 0, 0, ContentList.AbsoluteContentSize.Y + 20)
end

-- Create menu buttons
for i, menuKey in ipairs(currentConfig.menus) do
    local MenuButton = Instance.new("TextButton")
    MenuButton.Name = menuKey
    MenuButton.Size = UDim2.new(1, -10, 0, 45)
    MenuButton.BackgroundColor3 = Color3.fromRGB(35, 35, 50) -- Dark purple/gray
    MenuButton.BorderSizePixel = 0
    MenuButton.Text = getText(menuKey)
    MenuButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    MenuButton.Font = Enum.Font.GothamBold
    MenuButton.TextSize = 14
    MenuButton.LayoutOrder = i
    MenuButton.Parent = MenuSidebar
    
    local MenuButtonCorner = Instance.new("UICorner")
    MenuButtonCorner.CornerRadius = UDim.new(0, 8)
    MenuButtonCorner.Parent = MenuButton
    
    menuButtons[menuKey] = MenuButton
    
    MenuButton.MouseButton1Click:Connect(function()
        loadMenu(menuKey)
    end)
    
    -- Hover effects
    MenuButton.MouseEnter:Connect(function()
        if currentMenu ~= menuKey then
            TweenService:Create(MenuButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(80, 50, 120)}):Play()
        end
    end)
    
    MenuButton.MouseLeave:Connect(function()
        if currentMenu ~= menuKey then
            TweenService:Create(MenuButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(35, 35, 50)}):Play()
        end
    end)
end

-- Add padding to menu sidebar
local SidebarPadding = Instance.new("UIPadding")
SidebarPadding.PaddingTop = UDim.new(0, 5)
SidebarPadding.PaddingLeft = UDim.new(0, 5)
SidebarPadding.PaddingRight = UDim.new(0, 5)
SidebarPadding.Parent = MenuSidebar

-- Load first menu by default
if #currentConfig.menus > 0 then
    loadMenu(currentConfig.menus[1])
end

-- ========================================
-- TOGGLE BUTTON (DRAGGABLE)
-- ========================================

local ToggleFrame = Instance.new("Frame")
ToggleFrame.Name = "ToggleFrame"
ToggleFrame.Size = UDim2.new(0, 60, 0, 60)
ToggleFrame.Position = UDim2.new(0, 20, 0, 20)
ToggleFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
ToggleFrame.BorderSizePixel = 0
ToggleFrame.Active = true
ToggleFrame.ZIndex = 10
ToggleFrame.Parent = ScreenGui

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 12)
ToggleCorner.Parent = ToggleFrame

local ToggleBorder = Instance.new("UIStroke")
ToggleBorder.Name = "Border"
ToggleBorder.Color = Color3.fromRGB(138, 43, 226)
ToggleBorder.Thickness = 2
ToggleBorder.Transparency = 0
ToggleBorder.Parent = ToggleFrame

local ToggleGlow = Instance.new("ImageLabel")
ToggleGlow.Name = "GlowEffect"
ToggleGlow.Size = UDim2.new(1, 30, 1, 30)
ToggleGlow.Position = UDim2.new(0.5, 0, 0.5, 0)
ToggleGlow.AnchorPoint = Vector2.new(0.5, 0.5)
ToggleGlow.BackgroundTransparency = 1
ToggleGlow.Image = "rbxasset://textures/ui/Glow.png"
ToggleGlow.ImageColor3 = Color3.fromRGB(138, 43, 226)
ToggleGlow.ImageTransparency = 1
ToggleGlow.ScaleType = Enum.ScaleType.Slice
ToggleGlow.SliceCenter = Rect.new(12, 12, 12, 12)
ToggleGlow.ZIndex = 9
ToggleGlow.Parent = ToggleFrame

local ToggleLogo = Instance.new("ImageLabel")
ToggleLogo.Name = "ToggleLogo"
ToggleLogo.Size = UDim2.new(0, 40, 0, 40)
ToggleLogo.Position = UDim2.new(0.5, -20, 0.5, -20)
ToggleLogo.BackgroundTransparency = 1
ToggleLogo.Image = LOGO_TEXTURE_ID
ToggleLogo.ScaleType = Enum.ScaleType.Fit
ToggleLogo.ZIndex = 11
ToggleLogo.Parent = ToggleFrame

local LogoToggleCorner = Instance.new("UICorner")
LogoToggleCorner.CornerRadius = UDim.new(0, 12)
LogoToggleCorner.Parent = ToggleLogo

local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "ToggleButton"
ToggleButton.Size = UDim2.new(1, 0, 1, 0)
ToggleButton.Position = UDim2.new(0, 0, 0, 0)
ToggleButton.BackgroundTransparency = 1
ToggleButton.Text = ""
ToggleButton.ZIndex = 12
ToggleButton.Parent = ToggleFrame

-- Dragging toggle button
local toggleDragging = false
local toggleDragInput
local toggleDragStart
local toggleStartPos

local function updateToggle(input)
    local delta = input.Position - toggleDragStart
    ToggleFrame.Position = UDim2.new(toggleStartPos.X.Scale, toggleStartPos.X.Offset + delta.X, toggleStartPos.Y.Scale, toggleStartPos.Y.Offset + delta.Y)
end

ToggleButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        toggleDragging = true
        toggleDragStart = input.Position
        toggleStartPos = ToggleFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                toggleDragging = false
            end
        end)
    end
end)

ToggleButton.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        toggleDragInput = input
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if input == toggleDragInput and toggleDragging then
        updateToggle(input)
    end
end)

-- Dragging main frame
local dragging
local dragInput
local dragStart
local startPos

local function update(input)
    local delta = input.Position - dragStart
    MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

HeaderFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

HeaderFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        update(input)
    end
end)

-- Toggle functionality
local isOpen = true

ToggleButton.MouseButton1Click:Connect(function()
    if toggleDragging then return end
    
    isOpen = not isOpen
    
    local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    
    if isOpen then
        MainFrame.Visible = true
        TweenService:Create(MainFrame, tweenInfo, {
            Size = UDim2.new(0, 700, 0, 450),
            Position = UDim2.new(0.5, -350, 0.5, -225)
        }):Play()
        
        TweenService:Create(ToggleGlow, TweenInfo.new(0.3), {ImageTransparency = 0.5}):Play()
    else
        local closeTween = TweenService:Create(MainFrame, tweenInfo, {
            Size = UDim2.new(0, 0, 0, 0),
            Position = UDim2.new(0.5, 0, 0.5, 0)
        })
        closeTween:Play()
        
        TweenService:Create(ToggleGlow, TweenInfo.new(0.3), {ImageTransparency = 1}):Play()
        
        closeTween.Completed:Connect(function()
            if not isOpen then
                MainFrame.Visible = false
            end
        end)
    end
end)

-- Hover effects
ToggleButton.MouseEnter:Connect(function()
    TweenService:Create(ToggleFrame, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(45, 45, 65)}):Play()
    
    if isOpen then
        TweenService:Create(ToggleGlow, TweenInfo.new(0.2), {ImageTransparency = 0.3}):Play()
    else
        TweenService:Create(ToggleGlow, TweenInfo.new(0.2), {ImageTransparency = 0.6}):Play()
    end
end)

ToggleButton.MouseLeave:Connect(function()
    TweenService:Create(ToggleFrame, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(30, 30, 45)}):Play()
    
    if isOpen then
        TweenService:Create(ToggleGlow, TweenInfo.new(0.2), {ImageTransparency = 0.5}):Play()
    else
        TweenService:Create(ToggleGlow, TweenInfo.new(0.2), {ImageTransparency = 1}):Play()
    end
end)

-- ========================================
-- OPENING ANIMATION
-- ========================================

MainFrame.Size = UDim2.new(0, 0, 0, 0)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)

wait(0.1)

TweenService:Create(MainFrame, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Size = UDim2.new(0, 700, 0, 450),
    Position = UDim2.new(0.5, -350, 0.5, -225)
}):Play()

TweenService:Create(ToggleGlow, TweenInfo.new(0.5), {ImageTransparency = 0.5}):Play()

-- ========================================
-- LAUNCH NOTIFICATION
-- ========================================

wait(0.5)
createNotification(getText("hubActive"), getText("loadSuccess"), 5)

print("Archeron Hub loaded successfully with language: " .. currentLanguage)
