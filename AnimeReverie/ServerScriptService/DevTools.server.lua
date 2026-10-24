--!nonstrict
--[[
	DevTools | Script (server) -- HANYA AKTIF DI STUDIO
	Lokasi Studio: ServerScriptService > DevTools
	Membuat 5 tombol (ProximityPrompt) di dekat spawn untuk menguji progres sebelum combat ada.
	Di server live (bukan Studio) script ini langsung berhenti. Hapus saat rilis bila mau.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.Configurations.GameConfig)
if not RunService:IsStudio() or not GameConfig.Dev.EnableDevTools then
	return
end

local PlayerStatsService = require(ServerScriptService:WaitForChild("Services"):WaitForChild("PlayerStatsService"))

local function makeButton(label, offsetZ, color, handler)
	local part = Instance.new("Part")
	part.Name = "DevButton"
	part.Anchored = true
	part.Size = Vector3.new(4, 1, 4)
	part.Position = Vector3.new(20, 1, offsetZ)
	part.Color = color
	part.Parent = workspace

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = label
	prompt.ObjectText = "DEV (Studio only)"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	prompt.Triggered:Connect(function(player)
		local ok, err = pcall(handler, player)
		if not ok then
			warn("[DevTools] " .. label .. " error: " .. tostring(err))
		end
	end)
end

local function printKill(tag, r, reason)
	if not r then
		print(("[DEV] %s ditolak: %s (profil belum dimuat?)"):format(tag, tostring(reason)))
		return
	end
	print(
		("[DEV] %s: +%d EXP (base %d, bonus %d, boss %d) | Lv %d -> %d | +%d Stat Point"):format(
			tag, r.TotalEXP, r.BaseEXP, r.MultiplierBonusEXP, r.BossBonusEXP, r.OldLevel, r.NewLevel, r.StatPointsAwarded
		)
	)
end

makeButton("Simulate NORMAL kill", 0, Color3.fromRGB(80, 200, 120), function(player)
	printKill("normal kill", PlayerStatsService.AwardKill(player, { Kind = "Normal" }))
end)

makeButton("Simulate BOSS kill (+50 EXP)", 6, Color3.fromRGB(220, 80, 80), function(player)
	printKill("boss kill", PlayerStatsService.AwardKill(player, { Kind = "Boss", BossBonusEXP = 50 }))
end)

makeButton("Add 100 Coins", 12, Color3.fromRGB(240, 200, 60), function(player)
	print("[DEV] AddCoins ->", PlayerStatsService.AddCoins(player, 100))
end)

makeButton("Spend 1 Stat Point on Power", 18, Color3.fromRGB(90, 150, 240), function(player)
	local ok, reason = PlayerStatsService.AllocateStat(player, "Power", 1)
	local stats = PlayerStatsService.GetStats(player)
	print("[DEV] allocate Power ->", ok, reason, "| BaseDamage:", stats and stats.BaseDamage, "| StatPoints:", stats and stats.StatPoints)
end)

makeButton("Print full stats", 24, Color3.fromRGB(180, 180, 180), function(player)
	local stats = PlayerStatsService.GetStats(player)
	if not stats then
		print("[DEV] profil belum dimuat")
		return
	end
	for key, value in stats do
		if type(value) ~= "table" then
			print(("[DEV] %s = %s"):format(key, tostring(value)))
		end
	end
end)
