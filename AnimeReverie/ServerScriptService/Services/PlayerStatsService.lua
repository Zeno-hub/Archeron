--!nonstrict
--[[
	PlayerStatsService | ModuleScript
	Lokasi Studio: ServerScriptService > Services > PlayerStatsService
	Pemilik tunggal progres pemain di server: EXP, level, Stat Point, kill, koin/gem, stat turunan.
	Semua rumus dipanggil dari StatFormulas (tidak ada rumus ganda di service lain).
	AwardKill / AddCoins dst. HANYA boleh dipanggil kode server tepercaya (mis. RewardService setelah
	kill divalidasi) -- jangan pernah dihubungkan langsung ke RemoteEvent.

	Modifier (pet/equipment/buff/skill) didaftarkan lewat RegisterModifierProvider. Nama key menentukan
	cara gabung: akhiran "Multiplier" dikalikan, akhiran "Bonus" dijumlahkan. Provider wajib memanggil
	InvalidateDerived(player) saat nilainya berubah.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Configurations.GameConfig)
local StatFormulas = require(ReplicatedStorage.SharedModules.StatFormulas)
local DataService = require(script.Parent.DataService)

local PlayerStatsService = {}

local runtime = {} -- [Player] = { Derived, DerivedDirty, Dirty, Leaderstats, PlaytimeMark }
local modifierProviders = {} -- [nama] = function(player) -> { Key = number }
local levelUpCallbacks = {}
local statsChangedCallbacks = {}

local function warnOnce(message)
	warn("[PlayerStatsService] " .. message)
end

local function mergeModifiers(player)
	local merged = {}
	for name, provider in modifierProviders do
		local ok, result = pcall(provider, player)
		if not ok then
			warnOnce(("provider '%s' error: %s"):format(name, tostring(result)))
		elseif type(result) == "table" then
			for key, value in result do
				if type(value) == "number" and value == value then
					if string.sub(key, -10) == "Multiplier" then
						merged[key] = (merged[key] or 1) * value
					elseif string.sub(key, -5) == "Bonus" then
						merged[key] = (merged[key] or 0) + value
					end
				end
			end
		end
	end
	return merged
end

-- ===== API publik =====

function PlayerStatsService.RegisterModifierProvider(name, provider)
	modifierProviders[name] = provider
end

function PlayerStatsService.InvalidateDerived(player)
	local state = runtime[player]
	if state then
		state.DerivedDirty = true
		state.Dirty = true
	end
end

function PlayerStatsService.OnLevelUp(callback) -- callback(player, info)
	table.insert(levelUpCallbacks, callback)
end

function PlayerStatsService.OnStatsChanged(callback) -- callback(player) -- sudah digabung (maks 4x/detik)
	table.insert(statsChangedCallbacks, callback)
end

-- Stat turunan ter-cache (tabel beku, jangan diubah). nil jika data belum siap.
function PlayerStatsService.GetDerived(player)
	local state, data = runtime[player], DataService.GetData(player)
	if not state or not data then
		return nil
	end
	if state.DerivedDirty or not state.Derived then
		state.Derived = StatFormulas.ComputeDerived(data, mergeModifiers(player))
		state.DerivedDirty = false
	end
	return state.Derived
end

-- Snapshot lengkap untuk HUD/GUI (DPS & HighestDPS ditambahkan CombatService di Bagian B).
function PlayerStatsService.GetStats(player)
	local data, derived = DataService.GetData(player), PlayerStatsService.GetDerived(player)
	if not data or not derived then
		return nil
	end
	return {
		Level = data.Level,
		CurrentEXP = data.CurrentEXP,
		RequiredEXP = StatFormulas.RequiredEXP(data.Level),
		TotalEXP = data.TotalEXP,
		StatPoints = data.StatPoints,
		Allocated = table.clone(data.Allocated),
		Power = derived.Power,
		PowerPerClick = derived.PowerPerClick,
		Stars = data.Stars,
		BaseDamage = derived.BaseDamage,
		BonusDamage = derived.BonusDamage,
		TotalDamage = derived.TotalDamage,
		Luck = derived.Luck,
		CriticalChance = derived.CriticalChance,
		CriticalMultiplier = derived.CriticalMultiplier,
		AttackSpeed = derived.AttackSpeed,
		MaxHealth = derived.MaxHealth,
		Coins = data.Coins,
		Gems = data.Gems,
		TotalKills = data.TotalKills,
		BossKills = data.BossKills,
		Playtime = math.floor(data.Playtime),
		Rebirths = data.Rebirths,
		CurrentWorld = data.CurrentWorld,
		HighestWorldUnlocked = data.HighestWorldUnlocked,
		PetEquipCapacity = data.PetEquipCapacity,
		PetStorageCapacity = data.PetStorageCapacity,
	}
end

-- Catat satu kill yang SUDAH divalidasi server. killInfo: { Kind = "Normal"|"Boss", BossBonusEXP = n }
-- Normal = tepat +1 EXP dasar. Return: rincian (lihat bawah) atau nil, alasan.
function PlayerStatsService.AwardKill(player, killInfo)
	local data, state = DataService.GetData(player), runtime[player]
	if not data or not state then
		return nil, "NoProfile"
	end
	killInfo = killInfo or {}
	local derived = PlayerStatsService.GetDerived(player)
	local exp = StatFormulas.ComputeKillEXP(killInfo.Kind, killInfo.BossBonusEXP, derived.EXPMultiplier)

	local oldLevel = data.Level
	data.TotalKills += 1
	if exp.Kind == "Boss" then
		data.BossKills += 1
	end
	local levelsGained = StatFormulas.ApplyEXP(data, exp.TotalEXP)

	local result = {
		Kind = exp.Kind,
		BaseEXP = exp.BaseEXP,
		MultiplierBonusEXP = exp.MultiplierBonusEXP,
		BossBonusEXP = exp.BossBonusEXP,
		TotalEXP = exp.TotalEXP,
		OldLevel = oldLevel,
		NewLevel = data.Level,
		LevelsGained = levelsGained,
		StatPointsAwarded = levelsGained * GameConfig.EXP.StatPointsPerLevel,
	}
	state.Dirty = true
	if levelsGained > 0 then
		state.DerivedDirty = true
		for _, callback in levelUpCallbacks do
			task.spawn(callback, player, result)
		end
	end
	return result
end

-- Alokasi Stat Point (validasi penuh di StatFormulas.TryAllocate). Return: ok, alasan
function PlayerStatsService.AllocateStat(player, attribute, amount)
	local data, state = DataService.GetData(player), runtime[player]
	if not data or not state then
		return false, "NoProfile"
	end
	local ok, reason = StatFormulas.TryAllocate(data, attribute, amount)
	if ok then
		state.DerivedDirty = true
		state.Dirty = true
	end
	return ok, reason
end

local function changeCurrency(player, field, amount, spend)
	local data, state = DataService.GetData(player), runtime[player]
	if not data or not state then
		return false, "NoProfile"
	end
	if type(amount) ~= "number" or amount ~= amount or amount < 0 or amount == math.huge then
		return false, "InvalidAmount"
	end
	amount = math.floor(amount)
	if spend then
		if data[field] < amount then
			return false, "Insufficient"
		end
		data[field] -= amount
	else
		data[field] = math.min(data[field] + amount, GameConfig.Economy.MaxCurrency)
	end
	state.Dirty = true
	return true, data[field]
end

function PlayerStatsService.AddCoins(player, amount)
	return changeCurrency(player, "Coins", amount, false)
end
function PlayerStatsService.AddGems(player, amount)
	return changeCurrency(player, "Gems", amount, false)
end
function PlayerStatsService.TrySpendCoins(player, amount)
	return changeCurrency(player, "Coins", amount, true)
end
function PlayerStatsService.TrySpendGems(player, amount)
	return changeCurrency(player, "Gems", amount, true)
end
function PlayerStatsService.AddStars(player, amount)
	return changeCurrency(player, "Stars", amount, false)
end
function PlayerStatsService.TrySpendStars(player, amount)
	return changeCurrency(player, "Stars", amount, true)
end

-- Satu klik attack yang SUDAH divalidasi server (rate limit/target dicek pemanggil; ClickService belum ada).
-- Power per klik = dasar x pet x gacha x upgrade (stat turunan). Return: didapat, total Power  ATAU  nil, alasan.
function PlayerStatsService.AwardClick(player)
	local data, state = DataService.GetData(player), runtime[player]
	if not data or not state then
		return nil, "NoProfile"
	end
	local gained = PlayerStatsService.GetDerived(player).PowerPerClick
	data.Power = math.min(data.Power + gained, GameConfig.Economy.MaxPower)
	state.DerivedDirty = true -- Power memengaruhi damage
	state.Dirty = true
	return gained, data.Power
end

-- ===== internal =====

local function createLeaderstats(player, state)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local function make(className, name)
		local value = Instance.new(className)
		value.Name = name
		value.Parent = folder
		return value
	end
	state.Leaderstats = {
		Level = make("IntValue", "Level"),
		EXP = make("StringValue", "EXP"),
		Kills = make("IntValue", "Kills"),
		Coins = make("IntValue", "Coins"),
		Power = make("IntValue", "Power"),
		Stars = make("IntValue", "Stars"),
	}
	folder.Parent = player
end

local function creditPlaytime(state, data)
	local now = os.time()
	data.Playtime += math.max(0, now - state.PlaytimeMark)
	state.PlaytimeMark = now
end

local function onProfileLoaded(player, profile)
	StatFormulas.SanitizeData(profile.Data)
	local state = { DerivedDirty = true, Dirty = true, PlaytimeMark = os.time() }
	runtime[player] = state
	createLeaderstats(player, state)
	PlayerStatsService.GetDerived(player)
end

local function onProfileReleasing(player, profile)
	local state = runtime[player]
	if state then
		creditPlaytime(state, profile.Data)
	end
	runtime[player] = nil
end

-- Satu loop untuk semua pemain: sinkron leaderstats + beri tahu listener hanya bila ada perubahan.
local function flushLoop()
	while true do
		task.wait(GameConfig.Runtime.StatsFlushInterval)
		for _, player in Players:GetPlayers() do
			local state = runtime[player]
			local data = DataService.GetData(player)
			if state and state.Dirty and data then
				state.Dirty = false
				local ls = state.Leaderstats
				ls.Level.Value = data.Level
				ls.EXP.Value = ("%d/%d"):format(data.CurrentEXP, StatFormulas.RequiredEXP(data.Level))
				ls.Kills.Value = data.TotalKills
				ls.Coins.Value = data.Coins
				ls.Power.Value = data.Power
				ls.Stars.Value = data.Stars
				for _, callback in statsChangedCallbacks do
					task.spawn(callback, player)
				end
			end
		end
	end
end

local function playtimeLoop()
	while true do
		task.wait(GameConfig.Runtime.PlaytimeTickSeconds)
		for _, player in Players:GetPlayers() do
			local state, data = runtime[player], DataService.GetData(player)
			if state and data then
				creditPlaytime(state, data)
			end
		end
	end
end

function PlayerStatsService.Init()
	DataService.OnProfileLoaded(onProfileLoaded)
	DataService.OnProfileReleasing(onProfileReleasing)
	task.spawn(flushLoop)
	task.spawn(playtimeLoop)
end

return PlayerStatsService
