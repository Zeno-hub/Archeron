--!nonstrict
--[[
	GameConfig | ModuleScript
	Lokasi Studio: ReplicatedStorage > Configurations > GameConfig
	Semua angka balance & rumus utama ada di sini. Service lain DILARANG hardcode angka ini.
	Tabel dibekukan (read-only) supaya tidak ada script yang mengubahnya diam-diam saat runtime.
]]

local GameConfig = {}

GameConfig.EXP = {
	NormalKillBaseEXP = 1, -- ATURAN INTI: tiap kill musuh normal = tepat +1 EXP dasar
	RequiredBase = 10, -- RequiredEXP = floor(RequiredBase * Level ^ RequiredExponent)
	RequiredExponent = 1.35,
	MaxLevel = 100, -- revisi gameplay: level pemain 1-100
	StatPointsPerLevel = 1, -- ATURAN INTI: +1 Stat Point tiap level-up
}

GameConfig.Damage = {
	BaseConstant = 10, -- BaseDamage = BaseConstant + Level*PerLevel + Power*PerPower
	PerLevel = 2,
	PerPower = 1.5,
}

GameConfig.Attributes = {
	Order = { "Fortune", "Vitality", "Haste", "Focus" }, -- "Power" BUKAN atribut alokasi lagi (hanya klik/pet/gacha/upgrade)
	Base = { Luck = 1.0, CriticalChance = 0.05, CriticalMultiplier = 1.5, AttackSpeed = 1.25, MaxHealth = 100 },
	PerPoint = {
		Fortune = { Luck = 0.01 },
		Vitality = { MaxHealth = 10 },
		Haste = { AttackSpeed = 0.015 }, -- serangan/detik per poin
		Focus = { CriticalChance = 0.004, CriticalMultiplier = 0.01 },
	},
	HealthPerLevel = 5,
	Limits = { Luck = 5.0, CriticalChance = 0.75, CriticalMultiplier = 4.0, AttackSpeed = 3.0 }, -- batas keras
}

GameConfig.Economy = { MaxCurrency = 1e15, MaxPower = 1e15 }

-- Klik attack: Power per klik dasar (dikali pet/gacha/upgrade). MaxClicksPerSecond untuk ClickService (BELUM ada).
GameConfig.Click = { BasePowerPerClick = 5, MaxClicksPerSecond = 12, MaxRequestsPerSecond = 30 }

GameConfig.Start = {
	Coins = 0,
	Gems = 0,
	Stars = 0, -- mata uang gacha pet
	CurrentWorld = 0, -- pemain baru selalu muncul di World 0 (lobi)
	HighestWorldUnlocked = 1,
	PetEquipCapacity = 3,
	PetStorageCapacity = 50,
}

GameConfig.Data = {
	StoreName = "AnimeReverie_PlayerData",
	KeyPrefix = "Player_",
	SchemaVersion = 2, -- v2: Power menjadi hasil klik (lihat DataMigrations)
	AutosaveSeconds = 120,
	LockTimeoutSeconds = 600, -- lock sesi dianggap mati bila lebih tua dari ini
	LoadAttempts = 6,
	LockRetryDelay = 3,
	RetryDelay = 2,
	SaveAttempts = 5,
	CloseTimeoutSeconds = 25,
	AllowEphemeralInStudio = true, -- Studio tanpa akses API: pakai data sementara (TIDAK disimpan)
	FatalErrorHints = { "studio access" }, -- potongan pesan error yang tidak perlu di-retry
}

GameConfig.Runtime = {
	PlaytimeTickSeconds = 10,
	StatsFlushInterval = 0.25, -- satu loop untuk semua pemain, bukan per event
}

GameConfig.Dev = { EnableDevTools = true } -- hanya berlaku di Studio

local function deepFreeze(tbl)
	if table.isfrozen(tbl) then
		return tbl
	end
	for _, value in tbl do
		if type(value) == "table" then
			deepFreeze(value)
		end
	end
	return table.freeze(tbl)
end

return deepFreeze(GameConfig)
