-- // LOAD RAYFIELD
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

-- // CREATE WINDOW
local Window = Rayfield:CreateWindow({
    Name = "Archeron - Hub",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "ArcXRona",
    ConfigurationSaving = {
        Enabled = false
    }
})

-- // MAIN TAB
local Tab = Window:CreateTab("Main")

-- // BUTTON GET ALL GAMEPASS
Tab:CreateButton({
    Name = "Get All Gamepass",
    Callback = function()
        local gpFolder = game:GetService("Players").LocalPlayer.Data.Gamepasses
        for _,v in pairs(gpFolder:GetChildren()) do
            if v:IsA("BoolValue") then
                v.Value = true
            end
        end
    end,
})

------------------------------------------------------------
-- // MAKE THE WINDOW DRAGGABLE
------------------------------------------------------------
local function Dragify(Frame)
    local UIS = game:GetService("UserInputService")
    local dragToggle, dragStart, startPos

    Frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragToggle = true
            dragStart = input.Position
            startPos = Frame.Position
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if dragToggle and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            Frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragToggle = false
        end
    end)
end

-- WAIT RAYFIELD LOADED THEN DRAGIFY THE MAIN WINDOW
task.delay(1, function()
    if Rayfield and Rayfield.MainWindow then
        Dragify(Rayfield.MainWindow)
    end
end)
