--!nonstrict
--[[
	StatFormulas | ModuleScript
	Lokasi Studio: ReplicatedStorage > SharedModules > StatFormulas
	Rumus MURNI (tanpa efek samping ke dunia game). Server memakainya secara otoritatif;
	client boleh memakainya untuk preview/tooltip. Semua angka dari GameConfig.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Configurations.GameConfig)

local StatFormulas = {}

local function isFinite(n)
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

local function nonNegInt(n, default)
	if not isFinite(n) then
		return default
	end
	return math.max(0, math.floor(n))
end

-- RequiredEXP = floor(RequiredBase * Level ^ RequiredExponent)  (Level 1 -> 10)
function StatFormulas.RequiredEXP(level, expCfg)
	expCfg = expCfg or GameConfig.EXP
	level = math.max(1, nonNegInt(level, 1))
	return math.max(1, math.floor(expCfg.RequiredBase * level ^ expCfg.RequiredExponent))
end

-- Naikkan level selama EXP cukup (mendukung multi level-up). Return: jumlah level yang naik.
local function settle(state, expCfg)
	local gained = 0
	while state.Level < expCfg.MaxLevel do
		local required = StatFormulas.RequiredEXP(state.Level, expCfg)
		if state.CurrentEXP < required then
			break
		end
		state.CurrentEXP -= required
		state.Level += 1
		state.StatPoints += expCfg.StatPointsPerLevel
		gained += 1
	end
	if state.Level >= expCfg.MaxLevel then
		state.Level = expCfg.MaxLevel
		state.CurrentEXP = 0
	end
	return gained
end

-- state: { Level, CurrentEXP, TotalEXP, StatPoints }. Jumlah tidak valid (negatif/NaN/inf/bukan angka) diabaikan.
function StatFormulas.ApplyEXP(state, amount, expCfg)
	expCfg = expCfg or GameConfig.EXP
	if not isFinite(amount) or amount < 1 then
		return 0
	end
	amount = math.floor(amount)
	state.TotalEXP += amount
	state.CurrentEXP += amount
	return settle(state, expCfg)
end

-- Rincian EXP satu kill. Normal = TEPAT NormalKillBaseEXP (angka dari data musuh TIDAK dipakai).
-- Boss = bonus terpisah (BossBonusEXP). Multiplier hanya menambah EXP dasar; pembulatan stokastik
-- menjaga rata-rata tetap akurat tanpa pecahan EXP. rng opsional (default math.random).
function StatFormulas.ComputeKillEXP(kind, bossBonusEXP, expMultiplier, rng, expCfg)
	expCfg = expCfg or GameConfig.EXP
	local isBoss = kind == "Boss"
	local base = if isBoss then 0 else expCfg.NormalKillBaseEXP
	local boss = if isBoss then nonNegInt(bossBonusEXP, 0) else 0
	local bonus = 0
	local extra = if isFinite(expMultiplier) then math.max(0, expMultiplier - 1) else 0
	if extra > 0 and base > 0 then
		local exact = base * extra
		bonus = math.floor(exact)
		if (rng or math.random)() < exact - bonus then
			bonus += 1
		end
	end
	return {
		Kind = if isBoss then "Boss" else "Normal",
		BaseEXP = base,
		MultiplierBonusEXP = bonus,
		BossBonusEXP = boss,
		TotalEXP = base + bonus + boss,
	}
end

-- Perbaiki data hasil load (tipe salah / negatif / NaN) dan selesaikan level-up yang tertunda.
function StatFormulas.SanitizeData(data, expCfg)
	expCfg = expCfg or GameConfig.EXP
	local maxCurrency = GameConfig.Economy.MaxCurrency
	data.Level = math.clamp(nonNegInt(data.Level, 1), 1, expCfg.MaxLevel)
	data.CurrentEXP = nonNegInt(data.CurrentEXP, 0)
	data.TotalEXP = nonNegInt(data.TotalEXP, 0)
	data.StatPoints = nonNegInt(data.StatPoints, 0)
	if type(data.Allocated) ~= "table" then
		data.Allocated = {}
	end
	for _, name in GameConfig.Attributes.Order do
		data.Allocated[name] = nonNegInt(data.Allocated[name], 0)
	end
	data.Coins = math.min(nonNegInt(data.Coins, 0), maxCurrency)
	data.Gems = math.min(nonNegInt(data.Gems, 0), maxCurrency)
	data.Stars = math.min(nonNegInt(data.Stars, 0), maxCurrency)
	data.Power = math.min(nonNegInt(data.Power, 0), GameConfig.Economy.MaxPower)
	for _, field in { "TotalKills", "BossKills", "Rebirths" } do
		data[field] = nonNegInt(data[field], 0)
	end
	data.Playtime = if isFinite(data.Playtime) then math.max(0, data.Playtime) else 0
	settle(data, expCfg)
end

local NO_MODS = table.freeze({})

-- Stat turunan dari data + modifier (dari provider: pet/equipment/buff/skill). Modifier default netral.
-- mods: PowerBonus, PetMultiplier, EquipmentMultiplier, BuffMultiplier, LuckBonus, CriticalChanceBonus,
--       CriticalMultiplierBonus, AttackSpeedBonus, MaxHealthBonus, EXPMultiplierBonus
function StatFormulas.ComputeDerived(data, mods)
	mods = mods or NO_MODS
	local dmg, attr = GameConfig.Damage, GameConfig.Attributes
	local per, limits, base = attr.PerPoint, attr.Limits, attr.Base
	local alloc, level = data.Allocated, data.Level

	local power = (data.Power or 0) + (mods.PowerBonus or 0) -- Power = hasil klik (+ bonus), bukan atribut alokasi
	local baseDamage = dmg.BaseConstant + level * dmg.PerLevel + power * dmg.PerPower
	local damageMultiplier =
		math.max(0, (mods.PetMultiplier or 1) * (mods.EquipmentMultiplier or 1) * (mods.BuffMultiplier or 1))
	local totalDamage = baseDamage * damageMultiplier

	return table.freeze({
		Level = level,
		Power = power,
		BaseDamage = baseDamage,
		DamageMultiplier = damageMultiplier,
		TotalDamage = totalDamage,
		BonusDamage = totalDamage - baseDamage,
		Luck = math.clamp(base.Luck + alloc.Fortune * per.Fortune.Luck + (mods.LuckBonus or 0), 0, limits.Luck),
		CriticalChance = math.clamp(
			base.CriticalChance + alloc.Focus * per.Focus.CriticalChance + (mods.CriticalChanceBonus or 0),
			0,
			limits.CriticalChance
		),
		CriticalMultiplier = math.clamp(
			base.CriticalMultiplier + alloc.Focus * per.Focus.CriticalMultiplier + (mods.CriticalMultiplierBonus or 0),
			1,
			limits.CriticalMultiplier
		),
		AttackSpeed = math.clamp(
			base.AttackSpeed + alloc.Haste * per.Haste.AttackSpeed + (mods.AttackSpeedBonus or 0),
			0.1,
			limits.AttackSpeed
		),
		MaxHealth = base.MaxHealth + level * attr.HealthPerLevel + alloc.Vitality * per.Vitality.MaxHealth + (mods.MaxHealthBonus or 0),
		EXPMultiplier = 1 + math.max(0, mods.EXPMultiplierBonus or 0),
		PowerPerClick = math.max(1, math.floor(GameConfig.Click.BasePowerPerClick * math.max(0, (mods.PetClickMultiplier or 1) * (mods.PowerGachaMultiplier or 1) * (mods.UpgradeClickMultiplier or 1)) + 0.5)),
	})
end

-- Satu pukulan: return damage (integer >= 1), isCritical. rng opsional (default math.random).
function StatFormulas.RollHit(derived, rng)
	local isCritical = (rng or math.random)() < derived.CriticalChance
	local damage = derived.TotalDamage * (if isCritical then derived.CriticalMultiplier else 1)
	return math.max(1, math.floor(damage + 0.5)), isCritical
end

-- Alokasi Stat Point dengan validasi penuh. Gagal = state tidak berubah. Return: ok, alasan
function StatFormulas.TryAllocate(state, attribute, amount)
	if type(attribute) ~= "string" or not table.find(GameConfig.Attributes.Order, attribute) then
		return false, "InvalidAttribute"
	end
	if not isFinite(amount) or amount ~= math.floor(amount) or amount < 1 then
		return false, "InvalidAmount"
	end
	if amount > state.StatPoints then
		return false, "NotEnoughPoints"
	end
	state.StatPoints -= amount
	state.Allocated[attribute] += amount
	return true
end

return StatFormulas
