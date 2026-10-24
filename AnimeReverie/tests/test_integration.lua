-- Tes integrasi (dijalankan run_tests.py; `__req` dan `H` disediakan runner). BUKAN untuk Roblox Studio.
-- Waktu di sini VIRTUAL (penjadwal palsu), jadi "25 detik" selesai seketika.
local GameConfig = __req("GameConfig")

local passed, failed = 0, 0
local function test(name, fn)
	H.reset()
	local ok, err = pcall(H.run, fn)
	if ok and #H.Sched.errors > 0 then ok, err = false, "error di thread: " .. H.Sched.errors[1] end
	if ok then passed += 1 else failed += 1; print("FAIL: " .. name .. " -> " .. tostring(err)) end
end
local function eq(actual, expected, label)
	if actual ~= expected then
		error(("%s: expected %s, got %s"):format(label or "eq", tostring(expected), tostring(actual)), 2)
	end
end
local function KEY(userId) return GameConfig.Data.KeyPrefix .. userId end

local function boot(jobId, store, opts)
	local s = H.newServer(jobId, store, opts)
	s.Stats, s.Data = s.require("PlayerStatsService"), s.require("DataService")
	s.Stats.Init()
	s.Data.Start() -- urutan sama dengan Main: Init() dulu, Start() terakhir
	return s
end
local function join(server, userId)
	local p = server:AddPlayer(userId)
	H.runUntil(function() return server.Data.GetData(p) ~= nil or p.KickMessage ~= nil end, 120)
	H.runFor(0.5) -- beri waktu loop flush menyinkronkan leaderstats
	return p
end
local function kills(server, p, n)
	for _ = 1, n do server.Stats.AwardKill(p, { Kind = "Normal" }) end
end
local function leader(server, p, name)
	for _, inst in server.Instances do
		if inst.Name == name and inst.Parent and inst.Parent.Name == "leaderstats" and inst.Parent.Parent == p then
			return inst.Value
		end
	end
end

test("alur lengkap: join, 10 kill -> Lv2 +1 Stat Point, leave, rejoin di server lain: progres bertahan", function()
	local store = H.newStore()
	local A = boot("JOB_A", store)
	local p = join(A, 100)
	eq(p.KickMessage, nil, "tidak boleh di-kick")
	eq(leader(A, p, "Level"), 1); eq(leader(A, p, "EXP"), "0/10")
	kills(A, p, 5); H.runFor(1)
	eq(leader(A, p, "EXP"), "5/10", "5 kill = 5 EXP")
	kills(A, p, 5); H.runFor(1)
	local s = A.Stats.GetStats(p)
	eq(s.Level, 2); eq(s.StatPoints, 1); eq(s.CurrentEXP, 0); eq(s.TotalKills, 10)
	eq(leader(A, p, "Level"), 2); eq(leader(A, p, "EXP"), "0/25"); eq(leader(A, p, "Kills"), 10)
	A:RemovePlayer(p); H.runFor(10)
	local rec = store.data[KEY(100)]
	eq(rec.SessionLock, nil, "lock dilepas"); eq(rec.Data.Level, 2); eq(rec.Data.TotalKills, 10)
	local B = boot("JOB_B", store)
	local s2 = B.Stats.GetStats(join(B, 100))
	eq(s2.Level, 2); eq(s2.StatPoints, 1); eq(s2.TotalKills, 10)
end)

test("tidak ada reward setelah pemain mulai keluar", function()
	local store = H.newStore(); local A = boot("JOB_A", store); local p = join(A, 1)
	kills(A, p, 3)
	A:RemovePlayer(p)
	local r, why = A.Stats.AwardKill(p, { Kind = "Normal" })
	eq(r, nil); eq(why, "NoProfile")
	eq((A.Stats.AddCoins(p, 5)), false)
	H.runFor(5)
	eq(store.data[KEY(1)].Data.TotalKills, 3); eq(store.data[KEY(1)].Data.Coins, 0)
end)

test("BindToClose menunggu 3 save paralel (latensi 2 dtk) dan melepas semua lock", function()
	local store = H.newStore(); local A = boot("JOB_A", store)
	local ps = { join(A, 1), join(A, 2), join(A, 3) }
	for i, p in ps do kills(A, p, i) end
	store.latency = 2
	local t0 = H.now()
	A:Shutdown()
	local took = H.now() - t0
	assert(took >= 2 and took < 20, "lama shutdown " .. took)
	for i = 1, 3 do
		eq(store.data[KEY(i)].SessionLock, nil, "lock " .. i); eq(store.data[KEY(i)].Data.TotalKills, i, "kills " .. i)
	end
	eq(next(A.Data.Profiles), nil, "Profiles harus kosong")
end)

test("BindToClose juga menunggu release yang sudah berjalan (PlayerRemoving lebih dulu)", function()
	local store = H.newStore(); local A = boot("JOB_A", store); local p = join(A, 1)
	kills(A, p, 4)
	store.latency = 5
	A:RemovePlayer(p); H.runFor(1)
	local t0 = H.now()
	A:Shutdown()
	assert(H.now() - t0 >= 3.5, "shutdown tidak menunggu release yang sedang berjalan: " .. (H.now() - t0))
	eq(store.data[KEY(1)].Data.TotalKills, 4); eq(store.data[KEY(1)].SessionLock, nil)
end)

test("BindToClose tidak menggantung: berhenti di batas CloseTimeoutSeconds saat DataStore sangat lambat", function()
	local store = H.newStore(); local A = boot("JOB_A", store); join(A, 1)
	store.latency = 100
	local t0 = H.now()
	A:Shutdown()
	local took = H.now() - t0
	assert(took >= GameConfig.Data.CloseTimeoutSeconds - 0.2 and took <= GameConfig.Data.CloseTimeoutSeconds + 1, "took " .. took)
end)

test("error tak terduga di jalur release tidak membuat BindToClose menunggu sampai timeout", function()
	local store = H.newStore(); local A = boot("JOB_A", store); join(A, 1)
	A.require("ProfileStore").SaveProfile = function() error("boom") end -- sabotase di luar pcall internal ProfileStore
	local t0 = H.now()
	A:Shutdown()
	local took = H.now() - t0
	assert(took < 5, "shutdown menunggu " .. took .. " dtk (activeReleases macet)")
	eq(next(A.Data.Profiles), nil, "Profiles harus tetap dibersihkan")
end)

test("pemain keluar saat loading lalu server mati: lock tidak tertinggal", function()
	local store = H.newStore(); store.latency = 3
	local A = boot("JOB_A", store)
	local p = A:AddPlayer(1) -- load dimulai (butuh ~3 dtk)
	H.runFor(1)
	A:RemovePlayer(p) -- keluar sebelum load selesai
	H.runFor(0.5)
	A:Shutdown()
	local rec = store.data[KEY(1)]
	assert(rec == nil or rec.SessionLock == nil, "lock tertinggal setelah BindToClose selesai")
end)

test("autosave: progres tersimpan dan waktu lock diperbarui", function()
	local store = H.newStore(); local A = boot("JOB_A", store); local p = join(A, 1)
	kills(A, p, 3)
	H.runFor(GameConfig.Data.AutosaveSeconds + 5)
	local rec = store.data[KEY(1)]
	eq(rec.Data.TotalKills, 3)
	assert(rec.SessionLock and rec.SessionLock.Time >= H.BASE_TIME + GameConfig.Data.AutosaveSeconds - 1, "lock tidak diperbarui")
end)

test("Studio tanpa akses API: data sementara, tidak di-kick, TIDAK PERNAH menulis ke store", function()
	local store = H.newStore(); store.failNext = 1000000; store.failWith = "Studio access to APIs is not allowed"
	local A = boot("JOB_A", store, { isStudio = true })
	local p = join(A, 1)
	eq(p.KickMessage, nil); assert(A.Data.GetData(p) ~= nil, "harus punya data sementara")
	eq(A.Stats.AwardKill(p, { Kind = "Normal" }).TotalEXP, 1)
	A:RemovePlayer(p); H.runFor(5)
	eq(store.data[KEY(1)], nil); eq(store.calls, 1, "error fatal tidak di-retry")
end)

test("server live: load gagal -> pemain di-kick, tanpa profil, data lama utuh", function()
	local store = H.newStore()
	store.data[KEY(1)] = { SchemaVersion = 1, Data = { Level = 7, Coins = 999 } }
	store.failNext = 1000000
	local A = boot("JOB_A", store)
	local p = join(A, 1)
	assert(p.KickMessage and string.find(p.KickMessage, "Failed to load", 1, true), "harus di-kick")
	eq(A.Data.GetData(p), nil); eq((A.Stats.AwardKill(p, {})), nil); eq(store.calls, GameConfig.Data.LoadAttempts)
	store.failNext = 0
	local rec = store.data[KEY(1)]
	eq(rec.Data.Level, 7); eq(rec.Data.Coins, 999); eq(rec.SessionLock, nil)
end)

test("modifier provider: pet x2 menaikkan damage; multiplier EXP hanya aktif bila terdaftar; base EXP tetap 1", function()
	local store = H.newStore(); local A = boot("JOB_A", store); local p = join(A, 1)
	local r1 = A.Stats.AwardKill(p, { Kind = "Normal" })
	eq(r1.BaseEXP, 1); eq(r1.MultiplierBonusEXP, 0); eq(r1.TotalEXP, 1)
	eq(A.Stats.GetDerived(p).TotalDamage, 12)
	A.Stats.RegisterModifierProvider("TestPets", function() return { PetMultiplier = 2, EXPMultiplierBonus = 1 } end)
	A.Stats.InvalidateDerived(p)
	eq(A.Stats.GetDerived(p).TotalDamage, 24)
	local r2 = A.Stats.AwardKill(p, { Kind = "Normal" })
	eq(r2.BaseEXP, 1); eq(r2.MultiplierBonusEXP, 1); eq(r2.TotalEXP, 2)
	A.Stats.RegisterModifierProvider("Bad", function() error("provider rusak") end)
	A.Stats.InvalidateDerived(p)
	eq(A.Stats.GetDerived(p).TotalDamage, 24, "provider error tidak merusak stat")
end)

test("mata uang divalidasi + alokasi Stat Point server-side (Haste -> AttackSpeed; Power bukan atribut alokasi)", function()
	local store = H.newStore(); local A = boot("JOB_A", store); local p = join(A, 1)
	local ok, bal = A.Stats.AddCoins(p, 100); eq(ok, true); eq(bal, 100)
	for _, bad in { -5, 0 / 0, math.huge, "9" } do eq((A.Stats.AddCoins(p, bad)), false, "AddCoins " .. tostring(bad)) end
	local ok2, why = A.Stats.TrySpendCoins(p, 150); eq(ok2, false); eq(why, "Insufficient")
	local ok3, bal3 = A.Stats.TrySpendCoins(p, 40); eq(ok3, true); eq(bal3, 60)
	H.runFor(1); eq(leader(A, p, "Coins"), 60)
	eq(A.Stats.GetDerived(p).BaseDamage, 12)
	kills(A, p, 10); eq(A.Stats.GetStats(p).StatPoints, 1); eq(A.Stats.GetDerived(p).BaseDamage, 14, "Lv2")
	eq((A.Stats.AllocateStat(p, "Haste", 1)), true)
	assert(math.abs(A.Stats.GetDerived(p).AttackSpeed - 1.265) < 1e-9, "Haste harus menaikkan AttackSpeed")
	local ok4, why4 = A.Stats.AllocateStat(p, "Haste", 1); eq(ok4, false); eq(why4, "NotEnoughPoints")
	eq(select(2, A.Stats.AllocateStat(p, "Power", 1)), "InvalidAttribute", "Power bukan atribut alokasi lagi")
	eq(select(2, A.Stats.AllocateStat(p, "Hack", 1)), "InvalidAttribute")
end)

test("playtime ~ lama sesi tercatat saat release", function()
	local store = H.newStore(); local A = boot("JOB_A", store); local p = join(A, 1)
	H.runFor(30)
	A:RemovePlayer(p); H.runFor(5)
	local playtime = store.data[KEY(1)].Data.Playtime
	assert(playtime >= 29 and playtime <= 32, "playtime " .. tostring(playtime))
end)

test("data lama skema 1 (field hilang / negatif) kompatibel dengan PlayerStatsService", function()
	local store = H.newStore()
	store.data[KEY(1)] = { SchemaVersion = 1, Data = { Level = 4, CurrentEXP = 3, StatPoints = 2, Allocated = { Power = 1 }, Coins = -50, TotalKills = 12 } }
	local A = boot("JOB_A", store); local s = A.Stats.GetStats(join(A, 1))
	eq(s.Level, 4); eq(s.CurrentEXP, 3); eq(s.StatPoints, 3, "1 poin Power dikembalikan oleh migrasi v2"); eq(s.Allocated.Power, nil); eq(s.Allocated.Focus, 0)
	eq(s.Coins, 0, "koin negatif diperbaiki"); eq(s.Gems, 0); eq(s.TotalKills, 12)
	eq(s.PetEquipCapacity, GameConfig.Start.PetEquipCapacity); eq(s.HighestWorldUnlocked, GameConfig.Start.HighestWorldUnlocked)
	eq(s.BaseDamage, 18); eq(s.MaxHealth, 120)
end)

test("lock sesi: server B menunggu selama A memegang data, lalu berhasil setelah A melepas", function()
	local store = H.newStore()
	local A = boot("JOB_A", store); local pA = join(A, 1)
	local B = boot("JOB_B", store); local pB = B:AddPlayer(1)
	H.runFor(4)
	eq(B.Data.GetData(pB), nil, "B belum boleh memuat"); eq(pB.KickMessage, nil, "B belum di-kick (masih retry)")
	A:RemovePlayer(pA)
	H.runUntil(function() return B.Data.GetData(pB) ~= nil or pB.KickMessage ~= nil end, 60)
	assert(B.Data.GetData(pB) ~= nil, "B harus berhasil memuat setelah A melepas lock")
end)

test("klik menghasilkan Power; pet & gacha menaikkan Power per klik; Power menaikkan damage; tersimpan", function()
	local store = H.newStore(); local A = boot("JOB_A", store); local p = join(A, 1)
	local base = GameConfig.Click.BasePowerPerClick
	local gained, total = A.Stats.AwardClick(p); eq(gained, base); eq(total, base)
	A.Stats.RegisterModifierProvider("TestPet", function() return { PetClickMultiplier = 2 } end)
	A.Stats.InvalidateDerived(p)
	eq((A.Stats.AwardClick(p)), base * 2, "pet x2")
	A.Stats.RegisterModifierProvider("TestGacha", function() return { PowerGachaMultiplier = 1.5 } end)
	A.Stats.InvalidateDerived(p)
	eq((A.Stats.AwardClick(p)), math.floor(base * 2 * 1.5 + 0.5), "pet x gacha")
	local power = A.Stats.GetStats(p).Power
	eq(power, base + base * 2 + math.floor(base * 3 + 0.5))
	eq(A.Stats.GetDerived(p).BaseDamage, 10 + 2 + power * 1.5, "damage mengikuti Power")
	H.runFor(1); eq(leader(A, p, "Power"), power)
	A:RemovePlayer(p); H.runFor(5)
	eq(store.data[KEY(1)].Data.Power, power); eq(A.Stats.AwardClick(p), nil)
end)

test("Stars: tambah/belanja tervalidasi, terpisah dari Coins, dan tersimpan", function()
	local store = H.newStore(); local A = boot("JOB_A", store); local p = join(A, 1)
	local ok, bal = A.Stats.AddStars(p, 10); eq(ok, true); eq(bal, 10)
	eq((A.Stats.AddStars(p, -1)), false); eq((A.Stats.AddStars(p, 0 / 0)), false)
	local ok2, why = A.Stats.TrySpendStars(p, 15); eq(ok2, false); eq(why, "Insufficient")
	local ok3, bal3 = A.Stats.TrySpendStars(p, 4); eq(ok3, true); eq(bal3, 6)
	eq(A.Stats.GetStats(p).Coins, 0, "Stars tidak mengubah Coins"); eq(A.Stats.GetStats(p).Stars, 6)
	A:RemovePlayer(p); H.runFor(5)
	eq(store.data[KEY(1)].Data.Stars, 6)
end)

return passed, failed
