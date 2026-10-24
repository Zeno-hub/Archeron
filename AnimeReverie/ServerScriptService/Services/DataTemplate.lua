--!nonstrict
--[[
	DataTemplate | ModuleScript
	Lokasi Studio: ServerScriptService > Services > DataTemplate
	Skema data pemain default. Key baru yang ditambahkan di fase berikutnya otomatis diisi ke
	pemain lama lewat reconcile (ProfileStore). Hanya field Fase 1 yang ada di sini.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Configurations.GameConfig)

local Start = GameConfig.Start

local allocated = {}
for _, name in GameConfig.Attributes.Order do
	allocated[name] = 0
end

return {
	-- Progresi
	Level = 1,
	CurrentEXP = 0,
	TotalEXP = 0,
	StatPoints = 0,
	Allocated = allocated,
	-- Mata uang
	Coins = Start.Coins,
	Gems = Start.Gems,
	Stars = Start.Stars, -- mata uang gacha pet
	Power = 0, -- hasil klik (BUKAN atribut alokasi)
	-- Quest kill per world: [questId] = { Progress, Status }
	Quests = {},
	-- Statistik
	TotalKills = 0,
	BossKills = 0,
	Playtime = 0,
	Rebirths = 0,
	-- Dunia (WorldService mengelola ini di Bagian B)
	CurrentWorld = Start.CurrentWorld,
	HighestWorldUnlocked = Start.HighestWorldUnlocked,
	-- Kapasitas pet (dipakai Fase 2)
	PetEquipCapacity = Start.PetEquipCapacity,
	PetStorageCapacity = Start.PetStorageCapacity,
}
