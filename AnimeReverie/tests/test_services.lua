-- Tes layanan gameplay (CombatService, QuestService, world, remote) di atas Roblox palsu. `__req` dan `H` dari runner.
-- ATURAN YANG DIBUKTIKAN: Power hanya dari klik valid; kill tidak memberi Power; Power independen dari damage/HP/hidup-mati NPC.
local GameConfig, E, Q = __req("GameConfig"), __req("EnemyConfig"), __req("QuestConfig")
local passed, failed = 0, 0
local function test(name, fn)
	H.reset()
	local ok, err = pcall(H.run, fn)
	if ok and #H.Sched.errors > 0 then ok, err = false, "error di thread: " .. H.Sched.errors[1] end
	if ok then passed += 1 else failed += 1; print("FAIL: " .. name .. " -> " .. tostring(err)) end
end
local function eq(actual, expected, label)
	if actual ~= expected then error(("%s: expected %s, got %s"):format(label or "eq", tostring(expected), tostring(actual)), 2) end
end
local function KEY(id) return GameConfig.Data.KeyPrefix .. id end
local BASE = GameConfig.Click.BasePowerPerClick

local function boot(jobId, store, opts)
	local s = H.newServer(jobId, store, opts)
	s.Stats, s.Data, s.Combat, s.Quest = s.require("PlayerStatsService"), s.require("DataService"), s.require("CombatService"), s.require("QuestService")
	s.Stats.Init(); s.Combat.Init(); s.Quest.Init(); s.Data.Start()
	return s
end
local function join(server, userId, world)
	local p = server:AddPlayer(userId)
	H.runUntil(function() return server.Data.GetData(p) ~= nil end, 120)
	H.runFor(0.5)
	if world then assert(server.Stats.SetCurrentWorld(p, world), "SetCurrentWorld gagal") end
	return p
end
local function click(A, p, id) return A.Combat.HandleClick(p, id) end
local function killWith(A, p, id) -- klik sampai mati (<= 12 klik, dalam 1 detik); return hasil klik pembunuh
	for _ = 1, 12 do
		local r, why = click(A, p, id); assert(r, "klik ditolak: " .. tostring(why))
		if r.Killed then return r end
	end
	error("musuh tidak mati dalam 12 klik")
end
local function snap(A, p)
	local s = A.Stats.GetStats(p)
	return { s.Power, s.Coins, s.Stars, s.TotalKills, s.TotalEXP, s.BossKills }
end
local function same(a, b, skipPower)
	for i = (skipPower and 2 or 1), #a do eq(a[i], b[i], "snapshot[" .. i .. "]") end
end

test("klik valid memberi Power walau NPC hidup & damage tidak cukup membunuh", function()
	local A = boot("JOB_A", H.newStore()); local p = join(A, 1, 1)
	local r = click(A, p, "W1_Boss")
	eq(r.PowerGained, BASE); eq(r.Killed, false); assert(r.Hp > 0 and r.Hp < r.MaxHp, "NPC terkena damage tapi hidup")
	eq(A.Stats.GetStats(p).Power, BASE); eq(A.Stats.GetStats(p).TotalKills, 0)
end)

test("kill TIDAK menambah Power: Power = jumlah Power klik; AwardKill langsung tidak mengubah Power; AwardClick tanpa NPC", function()
	local A = boot("JOB_A", H.newStore()); local p = join(A, 1, 1)
	local sum, killed = 0, false
	for _ = 1, 12 do
		local r = click(A, p, "W1_E1"); sum += r.PowerGained
		if r.Killed then killed = true; break end
	end
	assert(killed, "NPC harus mati"); eq(A.Stats.GetStats(p).Power, sum, "kill tidak boleh menambah Power")
	local before = A.Stats.GetStats(p).Power
	A.Stats.AwardKill(p, { Kind = "Normal" }); A.Stats.AwardKill(p, { Kind = "Boss", BossBonusEXP = 50 })
	eq(A.Stats.GetStats(p).Power, before, "AwardKill tidak boleh mengubah Power")
	local g = A.Stats.AwardClick(p); eq(g, BASE); eq(A.Stats.GetStats(p).Power, before + g, "AwardClick tidak butuh NPC/kill")
end)

test("klik valid pada NPC yang sudah mati TETAP memberi Power, tanpa damage/reward kill", function()
	local A = boot("JOB_A", H.newStore()); local p = join(A, 1, 1)
	killWith(A, p, "W1_E1")
	local s0 = snap(A, p)
	local r = click(A, p, "W1_E1")
	assert(r, "klik valid pada NPC mati harus diterima (Power independen dari status hidup/mati)")
	eq(r.TargetAlive, false); eq(r.Damage, 0); eq(r.Killed, false); eq(r.PowerGained, BASE)
	local s1 = snap(A, p); eq(s1[1], s0[1] + BASE, "Power naik tepat 1 klik"); same(s0, s1, true)
end)

test("kill hanya memberi reward terkonfigurasi: normal = +1 EXP + koin; boss = bonus EXP + Stars + koin; tanpa Power tambahan", function()
	local A = boot("JOB_A", H.newStore()); local p = join(A, 1, 1)
	killWith(A, p, "W1_E1")
	local s = A.Stats.GetStats(p); local e = E.Enemies.W1_E1
	eq(s.TotalKills, 1); eq(s.TotalEXP, 1); eq(s.Coins, e.CoinReward); eq(s.Stars, 0); eq(s.BossKills, 0)
	local p2 = join(A, 2, 1)
	A.Data.GetData(p2).Power = 1e6; A.Stats.InvalidateDerived(p2)
	local r = click(A, p2, "W1_Boss"); local b = E.Enemies.W1_Boss
	eq(r.Killed, true); eq(r.Kill.BaseEXP, 0); eq(r.Kill.BossBonusEXP, b.BossBonusEXP)
	local s2 = A.Stats.GetStats(p2)
	eq(s2.Power, 1e6 + r.PowerGained, "boss kill tidak menambah Power"); eq(s2.Stars, b.StarsReward); eq(s2.TotalEXP, b.BossBonusEXP)
	eq(s2.Coins, b.CoinReward); eq(s2.BossKills, 1)
end)

test("klik invalid / world salah / world terkunci / rate limit tidak menghasilkan reward ilegal", function()
	local A = boot("JOB_A", H.newStore()); local p = join(A, 1, 1)
	local s0 = snap(A, p)
	for _, bad in { 123, {}, true, "NOPE", "", string.rep("x", 1000) } do
		local r, why = click(A, p, bad); eq(r, nil); eq(why, "InvalidTarget")
	end
	eq((select(2, click(A, p, nil))), "InvalidTarget")
	eq((select(2, click(A, p, "W2_E1"))), "WrongWorld")
	A.Data.GetData(p).CurrentWorld = 2 -- simulasi exploit/data rusak: level 1 belum boleh world 2
	eq((select(2, click(A, p, "W2_E1"))), "WorldLocked")
	assert(A.Stats.SetCurrentWorld(p, 0)); eq((select(2, click(A, p, "W1_E1"))), "WrongWorld")
	same(s0, snap(A, p))
	assert(A.Stats.SetCurrentWorld(p, 1))
	local max = GameConfig.Click.MaxClicksPerSecond
	for i = 1, max do assert(click(A, p, "W1_Boss"), "klik " .. i) end
	for _ = 1, 20 do eq((select(2, click(A, p, "W1_Boss"))), "RateLimited") end
	eq(A.Stats.GetStats(p).Power, max * BASE, "klik di atas batas tidak memberi Power")
	H.runFor(1.1); assert(click(A, p, "W1_Boss"), "boleh lagi setelah jeda")
end)

test("kill & respawn tidak memberi reward ganda", function()
	local A = boot("JOB_A", H.newStore()); local p = join(A, 1, 1); local e = E.Enemies.W1_E1
	killWith(A, p, "W1_E1")
	local s1 = snap(A, p)
	for i = 1, 3 do
		H.runFor(1); local r = click(A, p, "W1_E1"); eq(r.TargetAlive, false, "masih mati " .. i)
	end
	local s2 = snap(A, p); eq(s2[1], s1[1] + 3 * BASE); same(s1, s2, true)
	H.runFor(e.RespawnSeconds + 1)
	same(s2, snap(A, p), false) -- respawn sendiri tidak memberi apa pun
	killWith(A, p, "W1_E1")
	local s3 = A.Stats.GetStats(p); eq(s3.TotalKills, 2); eq(s3.Coins, 2 * e.CoinReward); eq(s3.TotalEXP, 2)
end)

test("dua pemain: reward kill hanya untuk pemukul terakhir; pemain lain tetap dapat Power dari kliknya", function()
	local A = boot("JOB_A", H.newStore()); local pA, pB = join(A, 1, 1), join(A, 2, 1)
	A.Data.GetData(pA).Power = 1e6; A.Stats.InvalidateDerived(pA)
	eq(click(A, pA, "W1_E2").Killed, true)
	local r = click(A, pB, "W1_E2")
	eq(r.TargetAlive, false); eq(r.PowerGained, BASE)
	local sB = A.Stats.GetStats(pB); eq(sB.TotalKills, 0); eq(sB.Coins, 0); eq(sB.TotalEXP, 0); eq(sB.Power, BASE)
	eq(A.Stats.GetStats(pA).TotalKills, 1)
end)

test("remote: payload sampah tidak error; spam dibatasi (respons & Power)", function()
	local A = boot("JOB_A", H.newStore()); local p = join(A, 1, 1)
	local maxReq = GameConfig.Click.MaxRequestsPerSecond or 30
	for i = 1, 300 do A:ClientFire(p, "ClickAttack", i % 2 == 0 and {} or "NOPE") end
	A:ClientFire(p, "ClickAttack"); A:ClientFire(p, "ClickAttack", "W1_E1", 1, 2, 3)
	H.runFor(0.1)
	assert(#A.Fired <= maxReq, "respons HitResult membanjir: " .. #A.Fired .. " (maks " .. maxReq .. ")")
	H.runFor(1.1); A.Fired = {}
	local before = A.Stats.GetStats(p).Power
	for _ = 1, 300 do A:ClientFire(p, "ClickAttack", "W1_Boss") end
	H.runFor(0.1)
	local gained = A.Stats.GetStats(p).Power - before
	assert(gained <= GameConfig.Click.MaxClicksPerSecond * BASE, "Power melewati rate limit: " .. gained)
	assert(gained > 0, "klik valid lewat remote harus memberi Power")
	assert(#A.Fired <= maxReq, "respons membanjir: " .. #A.Fired)
	eq(A.Fired[1].Remote, "HitResult"); eq(A.Fired[1].Args[1].EnemyId, "W1_Boss")
end)

test("quest kill: progres hanya dari kill world sendiri; klaim lewat remote tepat sekali (Stars + EXP)", function()
	local A = boot("JOB_A", H.newStore()); local p = join(A, 1, 1); local q = Q.ByWorld[1][1]
	for i = 1, q.Goal do
		local r = killWith(A, p, "W1_E1")
		if i < q.Goal then eq(#r.QuestsCompleted, 0) else eq(r.QuestsCompleted[1], q.Id) end
		H.runFor(6)
	end
	eq(A.Quest.GetSummary(p, "W2_Q1").Progress, 0, "quest world lain tidak ikut naik")
	A:ClientFire(p, "ClaimQuest", q.Id); H.runFor(0.1)
	local res = A.Fired[#A.Fired]; eq(res.Remote, "QuestResult"); eq(res.Args[1].Ok, true)
	local s = A.Stats.GetStats(p); eq(s.Stars, q.Reward.Stars); eq(s.TotalEXP, q.Goal + q.Reward.EXP)
	A:ClientFire(p, "ClaimQuest", q.Id); A:ClientFire(p, "ClaimQuest", "NOPE"); A:ClientFire(p, "ClaimQuest", {}); H.runFor(0.1)
	eq(A.Stats.GetStats(p).Stars, q.Reward.Stars, "klaim ulang tidak menambah Stars")
	eq(A.Fired[#A.Fired].Args[1].Ok, false)
end)

test("world: terbuka menurut level; Lobby selalu boleh; spawn di Lobby; CombatService menolak world terkunci", function()
	local store = H.newStore(); local A = boot("JOB_A", store)
	store.data[KEY(1)] = { SchemaVersion = 2, Data = { Level = 15, CurrentWorld = 3 } }
	local p = join(A, 1)
	eq(A.Stats.GetStats(p).CurrentWorld, 0, "spawn di Lobby")
	local ok = A.Stats.SetCurrentWorld(p, 2); assert(ok, "level 15 memenuhi syarat World 2")
	eq(A.Stats.GetStats(p).HighestWorldUnlocked, 2)
	local ok3, why3 = A.Stats.SetCurrentWorld(p, 3); eq(ok3, false); eq(why3, "WorldLocked")
	for _, bad in { 99, -1, 1.5, 0 / 0, math.huge, "1", {}, true } do eq((A.Stats.SetCurrentWorld(p, bad)), false) end
	A.Data.GetData(p).CurrentWorld = 3
	eq((select(2, click(A, p, "W3_E1"))), "WorldLocked")
	assert(A.Stats.SetCurrentWorld(p, 0))
	store.data[KEY(2)] = { SchemaVersion = 2, Data = { Level = 14 } }
	local p2 = join(A, 2); eq((select(2, A.Stats.SetCurrentWorld(p2, 2))), "WorldLocked")
end)

test("persisten: Power/Stars/Quests tersimpan setelah leave & rejoin; klik setelah leave ditolak", function()
	local store = H.newStore(); local A = boot("JOB_A", store); local p = join(A, 1, 1)
	killWith(A, p, "W1_E1")
	local s = A.Stats.GetStats(p)
	A:RemovePlayer(p)
	eq((select(2, click(A, p, "W1_E1"))), "NoProfile")
	H.runFor(5)
	local rec = store.data[KEY(1)].Data
	eq(rec.Power, s.Power); eq(rec.Coins, s.Coins); eq(rec.Quests.W1_Q1.Progress, 1); eq(rec.Quests.W1_Q1.Status, "Active")
	local B = boot("JOB_B", store); local p2 = join(B, 1)
	eq(B.Stats.GetStats(p2).Power, s.Power); eq(B.Quest.GetSummary(p2, "W1_Q1").Progress, 1)
end)

return passed, failed
