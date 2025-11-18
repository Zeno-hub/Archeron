-- // LOAD RAYFIELD
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Tree Cutting Hub | Zeno",
    LoadingTitle = "Loading UI...",
    LoadingSubtitle = "by Ciefy",
    ConfigurationSaving = {
        Enabled = false
    }
})

local Tab = Window:CreateTab("Main", 4483362458)

local Section = Tab:CreateSection("Auto Farm")


-- // VARIABLES
local Rep = game:GetService("ReplicatedStorage")
local CutEvent = Rep:WaitForChild("Events"):WaitForChild("CutTree")
local TreesFolder = workspace:WaitForChild("Objects")

getgenv().AutoCut = false


-- // AUTO CUT FUNCTION
Tab:CreateToggle({
    Name = "Auto Cut Trees",
    CurrentValue = false,
    Flag = "Toggle1",
    Callback = function(v)
        AutoCut = v

        while AutoCut do
            task.wait()

            for _, tree in ipairs(TreesFolder:GetChildren()) do
                local ID = tonumber(tree.Name)

                if ID and tree:FindFirstChild("ObjectData") then
                    local data = tree.ObjectData
                    if data:FindFirstChild("Health") and data.Health.Value > 0 then
                        CutEvent:FireServer(ID)
                    end
                end
            end
        end
    end,
})


-- // NOTE (DITAMBAHKAN SESUAI REQUEST)
Tab:CreateParagraph({
    Title = "Note",
    Content = "If you want to use the cut trees kill aura, you must be able to instantly kill the tree. However, this does not apply to trees that are still alive. If you want to use the cut trees kill aura, you must be able to instantly kill the tree. But this applies to the tree spawns, which are already very fast. If you're stubborn, you'll experience lag/delay."
})
