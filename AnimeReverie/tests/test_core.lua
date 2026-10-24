-- Dijalankan lewat run_tests.py (modul digabung; require dipetakan ke __req). BUKAN untuk Roblox Studio.
local SF = __req("StatFormulas")
local GameConfig = __req("GameConfig")
local ProfileStore = __req("ProfileStore")
local DataTemplate = __req("DataTemplate")

local passed, failed = 0, 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL: " .. name .. " -> " .. tostring(err))
	end
end
local function eq(actual, expected, label)
	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(label or "eq", tostring(expected), tostring(actual)), 2)
	end
end
local function near(actual, expected, tol, label)
	if math.abs(actual - expected) > tol then
		error(("%s: expected ~%s, got %s"):format(label or "near", tostring(expected), tostring(actual)), 2)
	end
end
local function deepCopy(v)
	if type(v) ~= "table" then return v end
	local c = {}
	for k, x in v do c[k] = deepCopy(x) end
	return c
end
local function deepEq(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for k, v in a do if not deepEq(v, b[k]) then return false end end
	for k in b do if a[k] == nil then return false end end
	return true
end
local function newState()
	return { Level = 1, CurrentEXP = 0, TotalEXP = 0, StatPoints = 0, Power = 0, Allocated = { Fortune = 0, Vitality = 0, Haste = 0, Focus = 0 } }
end

-- ===== StatFormulas =====
test("RequiredEXP level 1 = 10 (spesifikasi)", function() eq(SF.RequiredEXP(1), 10) end)
test("RequiredEXP = floor(10*L^1.35): L2=25, L10=223", function()
	eq(SF.RequiredEXP(2), 25); eq(SF.RequiredEXP(10), 223)
	for _, L in { 3, 7, 25, 100, 500 } do eq(SF.RequiredEXP(L), math.floor(10 * L ^ 1.35), "L" .. L) end
end)
test("RequiredEXP tidak pernah turun (1..500)", function()
	local prev = 0
	for L = 1, 500 do local r = SF.RequiredEXP(L); assert(r >= prev, "turun di level " .. L); prev = r end
end)
test("1 kill normal = +1 EXP, belum naik level", function()
	local s = newState()
	local k = SF.ComputeKillEXP("Normal", nil, 1)
	eq(k.TotalEXP, 1); eq(SF.ApplyEXP(s, k.TotalEXP), 0); eq(s.CurrentEXP, 1); eq(s.Level, 1)
end)
test("10 kill normal -> Level 2, 1 Stat Point, EXP 0", function()
	local s = newState()
	for _ = 1, 10 do SF.ApplyEXP(s, SF.ComputeKillEXP("Normal", nil, 1).TotalEXP) end
	eq(s.Level, 2); eq(s.StatPoints, 1); eq(s.CurrentEXP, 0); eq(s.TotalEXP, 10)
end)
test("kill normal SELALU base 1 (1000x, bonus boss diabaikan)", function()
	for _ = 1, 1000 do
		local k = SF.ComputeKillEXP("Normal", 9999, 1)
		eq(k.BaseEXP, 1); eq(k.MultiplierBonusEXP, 0); eq(k.BossBonusEXP, 0); eq(k.TotalEXP, 1)
	end
	eq(SF.ComputeKillEXP(nil, nil, 1).TotalEXP, 1, "kind nil")
end)
test("boss: base 0 + bonus terpisah", function()
	local k = SF.ComputeKillEXP("Boss", 50, 1)
	eq(k.BaseEXP, 0); eq(k.BossBonusEXP, 50); eq(k.TotalEXP, 50)
	eq(SF.ComputeKillEXP("Boss", -5, 1).TotalEXP, 0, "bonus negatif")
end)
test("multiplier 1.5: total hanya 1 atau 2, rata-rata ~1.5", function()
	math.randomseed(1234)
	local sum, n = 0, 20000
	for _ = 1, n do
		local t = SF.ComputeKillEXP("Normal", nil, 1.5).TotalEXP
		assert(t == 1 or t == 2, "total " .. t); sum += t
	end
	near(sum / n, 1.5, 0.03, "rata-rata")
end)
test("multi level-up: invarian EXP/level/stat point", function()
	local s = newState()
	SF.ApplyEXP(s, 5000)
	eq(s.StatPoints, s.Level - 1, "1 poin per level"); eq(s.TotalEXP, 5000)
	assert(s.CurrentEXP < SF.RequiredEXP(s.Level))
	local spent = s.CurrentEXP
	for L = 1, s.Level - 1 do spent += SF.RequiredEXP(L) end
	eq(spent, 5000, "jumlah EXP konsisten")
end)
test("batas MaxLevel: berhenti di MaxLevel (100), tidak loop tak hingga", function()
	local s = newState()
	SF.ApplyEXP(s, 1e12)
	eq(s.Level, GameConfig.EXP.MaxLevel); eq(s.CurrentEXP, 0); eq(s.StatPoints, GameConfig.EXP.MaxLevel - 1); eq(s.TotalEXP, 1e12)
end)
test("jumlah EXP tidak valid diabaikan", function()
	for _, bad in { -5, 0, 0.5, 0 / 0, math.huge, -math.huge, "10", {}, true } do
		local s = newState()
		eq(SF.ApplyEXP(s, bad), 0); eq(s.CurrentEXP, 0, tostring(bad)); eq(s.TotalEXP, 0)
	end
	local s = newState(); eq(SF.ApplyEXP(s, nil), 0)
end)
test("SanitizeData memperbaiki data rusak + menyelesaikan level-up tertunda", function()
	local d = { Level = -3, CurrentEXP = "x", StatPoints = 0 / 0, Coins = -5, Gems = math.huge, TotalKills = "a", Playtime = -1 }
	SF.SanitizeData(d)
	eq(d.Level, 1); eq(d.CurrentEXP, 0); eq(d.StatPoints, 0); eq(d.Coins, 0); eq(d.Gems, 0); eq(d.TotalKills, 0); eq(d.Playtime, 0)
	eq(type(d.Allocated), "table"); eq(d.Allocated.Focus, 0); eq(d.Stars, 0); eq(d.Power, 0)
	local e = { Level = 1, CurrentEXP = 999, StatPoints = 0, Allocated = {} }
	SF.SanitizeData(e)
	assert(e.Level > 1 and e.CurrentEXP < SF.RequiredEXP(e.Level)); eq(e.StatPoints, e.Level - 1)
end)
test("TryAllocate valid", function()
	local s = newState(); s.StatPoints = 3
	eq((SF.TryAllocate(s, "Fortune", 2)), true); eq(s.StatPoints, 1); eq(s.Allocated.Fortune, 2)
end)
test("TryAllocate menolak input buruk & state tidak berubah", function()
	for _, c in { { "Hack", 1 }, { "Power", 1 }, { "Fortune", 0 }, { "Fortune", -1 }, { "Fortune", 1.5 }, { "Fortune", 0 / 0 }, { "Fortune", math.huge }, { "Fortune", 4 }, { "Fortune", "1" }, { {}, 1 }, { nil, 1 } } do
		local s = newState(); s.StatPoints = 3
		local before = deepCopy(s)
		eq((SF.TryAllocate(s, c[1], c[2])), false, "kasus " .. tostring(c[1]) .. "/" .. tostring(c[2]))
		assert(deepEq(s, before), "state berubah")
	end
end)
test("ComputeDerived default: damage 12, crit 5%/1.5x, speed 1.25, HP 105", function()
	local d = SF.ComputeDerived(newState())
	eq(d.BaseDamage, 12); eq(d.TotalDamage, 12); eq(d.BonusDamage, 0); eq(d.Luck, 1)
	near(d.CriticalChance, 0.05, 1e-9); eq(d.CriticalMultiplier, 1.5); eq(d.AttackSpeed, 1.25); eq(d.MaxHealth, 105); eq(d.EXPMultiplier, 1)
end)
test("ComputeDerived: Level 10 + Power 20 + multiplier", function()
	local s = newState(); s.Level = 10; s.Power = 20
	local d = SF.ComputeDerived(s, { PetMultiplier = 2, EquipmentMultiplier = 1.5 })
	eq(d.BaseDamage, 60); eq(d.TotalDamage, 180); eq(d.BonusDamage, 120)
	eq(SF.ComputeDerived(s, { EXPMultiplierBonus = 0.5 }).EXPMultiplier, 1.5)
end)
test("ComputeDerived menghormati batas keras", function()
	local s = newState(); s.Allocated.Focus = 1e6; s.Allocated.Haste = 1e6; s.Allocated.Fortune = 1e6
	local d = SF.ComputeDerived(s)
	eq(d.CriticalChance, 0.75); eq(d.CriticalMultiplier, 4.0); eq(d.AttackSpeed, 3.0); eq(d.Luck, 5.0)
end)
test("RollHit: crit vs non-crit deterministik, damage >= 1", function()
	local d = SF.ComputeDerived(newState())
	local dmg, crit = SF.RollHit(d, function() return 0 end)
	eq(crit, true); eq(dmg, 18)
	local dmg2, crit2 = SF.RollHit(d, function() return 0.99 end)
	eq(crit2, false); eq(dmg2, 12)
	assert(SF.RollHit({ TotalDamage = 0, CriticalChance = 0, CriticalMultiplier = 1 }, function() return 0.5 end) >= 1)
end)
test("DataTemplate konsisten dengan SanitizeData", function()
	local d = deepCopy(DataTemplate)
	local before = deepCopy(d)
	SF.SanitizeData(d)
	assert(deepEq(d, before), "SanitizeData mengubah template")
	eq(d.Level, 1); eq(d.HighestWorldUnlocked, 1); eq(d.CurrentWorld, 0)
end)

-- ===== ProfileStore (DataStore tiruan) =====
local KEY = "Player_1"
local function newEnv()
	local env = { clock = 1000000, waited = 0 }
	local store = { data = {}, calls = 0, failNext = 0 }
	function store:UpdateAsync(key, fn)
		self.calls += 1
		if self.failNext > 0 then self.failNext -= 1; error("simulated DataStore error 502") end
		local new = fn(deepCopy(self.data[key]))
		if new == nil then return nil end
		self.data[key] = deepCopy(new)
		return deepCopy(new)
	end
	env.store = store
	function env.make(jobId, extra)
		local options = { Template = DataTemplate, SchemaVersion = 1, Migrations = {}, LockTimeout = 600, LoadAttempts = 4, LockRetryDelay = 3, RetryDelay = 2, SaveAttempts = 3, FatalErrorHints = { "studio access" } }
		for k, v in extra or {} do options[k] = v end
		return ProfileStore.new({ Store = store, JobId = jobId, Now = function() return env.clock end, Wait = function(s) env.clock += s; env.waited += s end, Log = function() end }, options)
	end
	return env
end

test("load: pemain baru -> data default + lock server ini", function()
	local env = newEnv(); local p, err = env.make("A"):LoadProfile(KEY)
	eq(err, nil); eq(p.IsNew, true); eq(p.Data.Level, 1); eq(env.store.data[KEY].SessionLock.JobId, "A")
end)
test("save+release lalu load server lain: data bertahan, lock dilepas, save ulang ditolak", function()
	local env = newEnv(); local A = env.make("A"); local p = A:LoadProfile(KEY)
	p.Data.Level = 7; p.Data.Coins = 123
	eq((A:SaveProfile(p, true)), true); eq(env.store.data[KEY].SessionLock, nil)
	local p2 = env.make("B"):LoadProfile(KEY)
	eq(p2.Data.Level, 7); eq(p2.Data.Coins, 123); eq(p2.IsNew, false)
	eq((A:SaveProfile(p, false)), false, "profil released")
end)
test("lock segar milik server lain: load GAGAL, record tidak berubah", function()
	local env = newEnv()
	env.store.data[KEY] = { SchemaVersion = 1, SessionLock = { JobId = "OTHER", Time = env.clock - 5 }, Data = { Level = 9 } }
	local before = deepCopy(env.store.data[KEY])
	local p, err = env.make("A"):LoadProfile(KEY)
	eq(p, nil); eq(err, "SessionLocked"); eq(env.store.calls, 4, "jumlah percobaan")
	assert(deepEq(env.store.data[KEY], before), "record berubah!")
end)
test("lock basi (> timeout): diambil alih", function()
	local env = newEnv()
	env.store.data[KEY] = { SchemaVersion = 1, SessionLock = { JobId = "DEAD", Time = env.clock - 10000 }, Data = { Level = 9 } }
	local p = env.make("A"):LoadProfile(KEY)
	eq(p.Data.Level, 9); eq(env.store.data[KEY].SessionLock.JobId, "A")
end)
test("error DataStore sementara: retry lalu berhasil", function()
	local env = newEnv(); env.store.failNext = 2
	local p = env.make("A"):LoadProfile(KEY)
	assert(p ~= nil, "harus berhasil"); assert(env.store.calls >= 3)
end)
test("error DataStore terus-menerus: TIDAK ada profil & data lama TIDAK tertimpa", function()
	local env = newEnv()
	env.store.data[KEY] = { SchemaVersion = 1, Data = { Level = 7, Coins = 999 } }
	local before = deepCopy(env.store.data[KEY])
	env.store.failNext = 100
	local p, err = env.make("A"):LoadProfile(KEY)
	eq(p, nil); assert(err ~= nil)
	env.store.failNext = 0
	assert(deepEq(env.store.data[KEY], before), "record berubah!")
end)
test("error 'Studio access' = fatal, tidak di-retry", function()
	local env = newEnv(); env.store.failNext = 100
	local store = env.store
	function store:UpdateAsync() self.calls += 1; error("Studio access to APIs is not allowed") end
	local p, err = env.make("A"):LoadProfile(KEY)
	eq(p, nil); eq(err, "ApiUnavailable"); eq(store.calls, 1)
end)
test("record rusak: ditolak, tidak ditimpa", function()
	local env = newEnv(); env.store.data[KEY] = "garbage"
	local p, err = env.make("A"):LoadProfile(KEY)
	eq(p, nil); eq(err, "CorruptRecord"); eq(env.store.data[KEY], "garbage"); eq(env.store.calls, 1)
end)
test("skema lebih baru dari server: ditolak (anti downgrade)", function()
	local env = newEnv(); env.store.data[KEY] = { SchemaVersion = 5, Data = { Level = 3 } }
	local p, err = env.make("A"):LoadProfile(KEY)
	eq(p, nil); eq(err, "FutureSchema"); eq(env.store.data[KEY].SchemaVersion, 5)
end)
test("save saat lock sudah diambil server lain: LockLost, data lain TIDAK ditimpa", function()
	local env = newEnv(); local A = env.make("A"); local p = A:LoadProfile(KEY)
	env.store.data[KEY].SessionLock = { JobId = "B", Time = env.clock }
	env.store.data[KEY].Data.Level = 99
	p.Data.Level = 2
	local ok, reason = A:SaveProfile(p, false)
	eq(ok, false); eq(reason, "LockLost"); eq(env.store.data[KEY].Data.Level, 99); eq(p.Released, true)
	eq((A:SaveProfile(p, false)), false, "tidak menulis lagi")
end)
test("save: retry saat error sementara; gagal total = false tanpa merusak", function()
	local env = newEnv(); local A = env.make("A"); local p = A:LoadProfile(KEY)
	p.Data.Level = 4; env.store.failNext = 2
	eq((A:SaveProfile(p, false)), true); eq(env.store.data[KEY].Data.Level, 4)
	p.Data.Level = 5; env.store.failNext = 100; env.store.calls = 0
	local ok, reason = A:SaveProfile(p, false)
	eq(ok, false); assert(string.find(reason, "SaveFailed", 1, true)); eq(env.store.calls, 3); eq(env.store.data[KEY].Data.Level, 4)
end)
test("autosave memperbarui waktu lock", function()
	local env = newEnv(); local A = env.make("A"); local p = A:LoadProfile(KEY)
	env.clock += 100; A:SaveProfile(p, false)
	eq(env.store.data[KEY].SessionLock.Time, env.clock)
end)
test("migrasi v1->v2 + reconcile key baru; versi baru tersimpan saat save", function()
	local env = newEnv()
	env.store.data[KEY] = { SchemaVersion = 1, Data = { Level = 3, Coins = 5, Allocated = { Power = 2 } } }
	local S = env.make("A", { SchemaVersion = 2, Migrations = { [2] = function(d) d.Coins += 100; return d end } })
	local p = S:LoadProfile(KEY)
	eq(p.Data.Coins, 105); eq(p.Data.Allocated.Power, 2); eq(p.Data.Allocated.Focus, 0, "key nested terisi"); eq(p.Data.Gems, 0)
	eq(env.store.data[KEY].SchemaVersion, 1, "belum ditulis sebelum save")
	S:SaveProfile(p, false); eq(env.store.data[KEY].SchemaVersion, 2)
end)
test("migrasi error: tidak ada profil, lock dilepas, data tidak rusak", function()
	local env = newEnv()
	env.store.data[KEY] = { SchemaVersion = 1, Data = { Level = 3 } }
	local S = env.make("A", { SchemaVersion = 2, Migrations = { [2] = function() error("boom") end } })
	local p, err = S:LoadProfile(KEY)
	eq(p, nil); eq(err, "MigrationFailed"); eq(env.store.data[KEY].SessionLock, nil); eq(env.store.data[KEY].Data.Level, 3)
end)
test("profil sementara (Studio) tidak pernah menulis ke store", function()
	local env = newEnv(); local S = env.make("A")
	local p = S:CreateEphemeralProfile(KEY)
	eq((S:SaveProfile(p, false)), true); eq((S:SaveProfile(p, true)), true); eq(env.store.calls, 0)
end)
test("data profil terisolasi dari store sebelum save", function()
	local env = newEnv(); local A = env.make("A"); local p = A:LoadProfile(KEY)
	p.Data.Level = 50
	eq(env.store.data[KEY].Data.Level, 1)
end)

return passed, failed
