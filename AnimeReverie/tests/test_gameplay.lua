-- Tes gameplay revisi (config + logika murni). Dijalankan run_tests.py; `__req` dan `H` disediakan runner.
local GameConfig, StatFormulas = __req("GameConfig"), __req("StatFormulas")
local W, E, Q, G = __req("WorldConfig"), __req("EnemyConfig"), __req("QuestConfig"), __req("GachaConfig")
local QL, GL = __req("QuestLogic"), __req("GachaLogic")

local passed, failed = 0, 0
local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then passed += 1 else failed += 1; print("FAIL: " .. name .. " -> " .. tostring(err)) end
end
local function eq(actual, expected, label)
	if actual ~= expected then error(("%s: expected %s, got %s"):format(label or "eq", tostring(expected), tostring(actual)), 2) end
end
local function near(actual, expected, tol, label)
	if math.abs(actual - expected) > tol then error(("%s: expected ~%s, got %s"):format(label or "near", tostring(expected), tostring(actual)), 2) end
end
local function deepCopy(v)
	if type(v) ~= "table" then return v end
	local c = {}
	for k, x in v do c[k] = deepCopy(x) end
	return c
end

test("nama world persis sesuai revisi; Lobby terpisah dari world", function()
	eq(W.Lobby.Id, 0); eq(W.Lobby.Name, "Lobby"); eq(W.Lobby.HasEnemies, false); eq(W.Lobby.HasQuests, false)
	local expected = { "Ki Realm", "Devil District", "Shadow Dominion", "Phantom Frontier", "Psychic Chaos" }
	eq(#W.Worlds, 5)
	local maps = { [W.Lobby.MapName] = true }
	for i, name in expected do
		eq(W.Worlds[i].Name, name); eq(W.Worlds[i].Id, i)
		assert(not maps[W.Worlds[i].MapName], "MapName kembar: " .. W.Worlds[i].MapName)
		maps[W.Worlds[i].MapName] = true
	end
end)

test("Lobby tanpa musuh/quest; World 1-5 masing-masing punya musuh, boss, dan quest kill", function()
	eq(E.ByWorld[0], nil)
	for w = 1, 5 do
		assert(#E.ByWorld[w] >= 5, "musuh world " .. w); assert(E.BossByWorld[w], "boss world " .. w); assert(#Q.ByWorld[w] >= 3, "quest world " .. w)
	end
	for _, q in Q.List do assert(q.WorldId >= 1, q.Id) end
end)

test("semua musuh & boss diam: validator tidak menemukan masalah", function()
	local problems = E.Validate()
	eq(#problems, 0, table.concat(problems, "; "))
	for id, e in E.Enemies do eq(e.Behavior, "Stationary", id) end
end)

test("validator menangkap musuh agresif / nama anime persis / HP tidak naik / Lobby berisi musuh", function()
	local byWorld = deepCopy(E.ByWorld)
	local function mutated(fn) local c = deepCopy(E.Enemies); fn(c); return c end
	assert(#E.Validate(mutated(function(c) c.W1_E1.AttackDamage = 5 end), byWorld) > 0, "AttackDamage")
	assert(#E.Validate(mutated(function(c) c.W2_E2.ChaseSpeed = 16 end), byWorld) > 0, "ChaseSpeed")
	assert(#E.Validate(mutated(function(c) c.W3_E1.Behavior = "Aggressive" end), byWorld) > 0, "Behavior")
	assert(#E.Validate(mutated(function(c) c.W4_E1.Name = "Hisoka" end), byWorld) > 0, "nama anime persis")
	assert(#E.Validate(mutated(function(c) c.W5_E2.MaxHealth = 1 end), byWorld) > 0, "HP tidak naik")
	local lobby = deepCopy(E.ByWorld); lobby[0] = { "W1_E1" }
	assert(#E.Validate(nil, lobby) > 0, "Lobby berisi musuh")
end)

test("tidak ada konten training di mana pun (nama world/musuh/quest/gacha, field world)", function()
	local function check(s, where) assert(not string.find(string.lower(s), "train", 1, true), "mengandung 'train': " .. where .. " = " .. s) end
	for _, w in W.Worlds do check(w.Name, "world"); for k in w do check(k, "field world") end end
	for id, e in E.Enemies do check(e.Name, id) end
	for _, q in Q.List do check(q.Name, q.Id) end
	for w = 1, 5 do
		for _, en in G.Pet[w].Entries do check(en.Name, en.Id) end
		for _, en in G.Power[w].Entries do check(en.Name, en.Id) end
	end
end)

test("HP naik per zona dan antar world; boss tertinggi di world-nya", function()
	local prevStrongest = 0
	for w = 1, 5 do
		local ids = E.ByWorld[w]
		assert(E.Enemies[ids[1]].MaxHealth > prevStrongest, "world " .. w .. " mulai lebih lemah dari akhir world sebelumnya")
		prevStrongest = E.Enemies[ids[#ids - 1]].MaxHealth
		local boss = E.Enemies[E.BossByWorld[w]]
		eq(boss.Kind, "Boss"); assert(boss.MaxHealth > prevStrongest, "boss world " .. w); eq(boss.Behavior, "Stationary")
	end
end)

test("aturan EXP: config musuh tanpa EXPReward; kill normal tetap tepat +1; boss bonus terpisah", function()
	for id, e in E.Enemies do eq(e.EXPReward, nil, id) end
	eq(GameConfig.EXP.NormalKillBaseEXP, 1)
	eq(StatFormulas.ComputeKillEXP("Normal", nil, 1).TotalEXP, 1)
	local boss = E.Enemies.W1_Boss
	eq(StatFormulas.ComputeKillEXP("Boss", boss.BossBonusEXP, 1).TotalEXP, boss.BossBonusEXP)
end)

test("level 1-100: MaxLevel=100 dan EXP besar berhenti di level 100", function()
	eq(GameConfig.EXP.MaxLevel, 100)
	local s = { Level = 1, CurrentEXP = 0, TotalEXP = 0, StatPoints = 0 }
	StatFormulas.ApplyEXP(s, 1e12)
	eq(s.Level, 100); eq(s.StatPoints, 99)
	for w = 1, 5 do assert(W.Worlds[w].RequiredLevel >= 1 and W.Worlds[w].RequiredLevel <= 100) end
end)

test("quest kill: tiap world punya daftar sendiri, target hanya musuh world itu, kesulitan naik, boss terakhir", function()
	for w = 1, 5 do
		local list, lastGoal = Q.ByWorld[w], 0
		for i, q in list do
			eq(q.WorldId, w)
			for _, target in q.TargetEnemyIds do eq(E.Enemies[target].WorldId, w, q.Id .. " menarget musuh world lain") end
			assert(q.Goal >= 1 and q.Reward.Stars > 0 and q.Reward.EXP > 0, q.Id)
			if i <= 3 then assert(q.Goal > lastGoal, "goal harus naik"); lastGoal = q.Goal end
		end
		eq(list[#list].TargetEnemyIds[1], E.BossByWorld[w]); eq(list[#list].Goal, 1)
	end
end)

test("QuestLogic: hanya target & world yang cocok dihitung; Completed; klaim tepat satu kali", function()
	local q1, state = Q.ByWorld[1][1], {}
	for _ = 1, 50 do QL.OnKill(state, Q.List, 2, "W1_E1") end -- world tidak cocok
	for _ = 1, 50 do QL.OnKill(state, Q.List, 1, "W2_E1") end -- musuh world lain
	eq(QL.Summary(state, q1).Progress, 0, "kill tidak cocok tidak boleh dihitung")
	for _ = 1, 9 do eq(#QL.OnKill(state, Q.List, 1, "W1_E1"), 0) end
	eq(QL.Summary(state, q1).Progress, 9); eq(QL.Summary(state, q1).Status, "Active")
	eq(QL.Summary(state, Q.ByWorld[1][2]).Progress, 0, "quest lain tidak ikut naik")
	local ok0, why0 = QL.Claim(state, q1); eq(ok0, false); eq(why0, "NotCompleted")
	local done = QL.OnKill(state, Q.List, 1, "W1_E1")
	eq(#done, 1); eq(done[1], q1.Id); eq(QL.Summary(state, q1).Status, "Completed")
	for _ = 1, 20 do QL.OnKill(state, Q.List, 1, "W1_E1") end
	eq(QL.Summary(state, q1).Progress, q1.Goal, "progress tidak melebihi goal")
	local ok, reward = QL.Claim(state, q1); eq(ok, true); eq(reward.Stars, q1.Reward.Stars); eq(reward.EXP, q1.Reward.EXP)
	local ok2, why = QL.Claim(state, q1); eq(ok2, false); eq(why, "AlreadyClaimed")
	local st = {}; eq(#QL.OnKill(st, Q.List, 3, E.BossByWorld[3]), 1, "kill boss menyelesaikan quest boss world 3")
end)

test("semua tabel gacha: peluang tepat 100%, 5 rarity Common..Mythic, biaya > 0; validator menolak yang salah", function()
	local rarities = { "Common", "Rare", "Epic", "Legendary", "Mythic" }
	for w = 1, 5 do
		for _, set in { G.Pet[w], G.Power[w] } do
			local ok, sum = GL.ValidateOdds(set.Entries); assert(ok, "world " .. w .. " jumlah " .. tostring(sum))
			eq(#set.Entries, 5); assert(set.Cost > 0)
			for i, en in set.Entries do eq(en.Rarity, rarities[i]) end
		end
	end
	assert(not (GL.ValidateOdds({ { Weight = 50 }, { Weight = 49 } })), "jumlah 99 harus ditolak")
	assert(not (GL.ValidateOdds({ { Weight = 100 }, { Weight = 0 } })), "weight nol harus ditolak")
end)

test("pet gacha pakai Stars; power gacha TIDAK memakai Stars; nama gacha tidak kembar", function()
	eq(G.PetCurrency, "Stars"); assert(G.PowerCurrency ~= "Stars")
	local names = {}
	for w = 1, 5 do
		eq(G.Pet[w].Currency, "Stars"); eq(G.Power[w].Currency, G.PowerCurrency); assert(G.Power[w].Currency ~= "Stars")
		for _, set in { G.Pet[w], G.Power[w] } do
			for _, en in set.Entries do
				local k = string.lower(en.Name); assert(not names[k], "nama gacha kembar: " .. en.Name); names[k] = true
			end
		end
	end
end)

test("hasil gacha punya efek gameplay: bonus pet > 0 & multiplier > 1, naik menurut rarity dan world", function()
	for w = 1, 5 do
		local lastBonus, lastMult = 0, 1
		for _, en in G.Pet[w].Entries do assert(en.ClickBonus > lastBonus, "bonus pet harus naik per rarity"); lastBonus = en.ClickBonus end
		for _, en in G.Power[w].Entries do assert(en.Multiplier > lastMult, "multiplier harus naik per rarity"); lastMult = en.Multiplier end
	end
	assert(G.Pet[5].Entries[5].ClickBonus > G.Pet[1].Entries[5].ClickBonus)
	assert(G.Power[5].Entries[5].Multiplier > G.Power[1].Entries[5].Multiplier)
end)

test("Roll: distribusi mendekati peluang & semua rarity bisa muncul (seed tetap)", function()
	math.randomseed(42)
	local entries, counts, n = G.Pet[1].Entries, {}, 100000
	for _ = 1, n do local e = GL.Roll(entries); counts[e.Rarity] = (counts[e.Rarity] or 0) + 1 end
	for _, en in entries do
		assert(counts[en.Rarity], en.Rarity .. " tidak pernah keluar")
		near(counts[en.Rarity] / n * 100, en.Weight, math.max(0.3, en.Weight * 0.05), en.Rarity)
	end
	eq(GL.Roll(entries, function() return 0 end).Rarity, "Common"); eq(GL.Roll(entries, function() return 0.999999 end).Rarity, "Mythic")
end)

test("PetClickMultiplier menjumlah bonus; multiplier Power gacha aktif hanya naik, dijumlah antar world", function()
	local pets = { G.Pet[1].Entries[1], G.Pet[1].Entries[3] }
	near(GL.PetClickMultiplier(pets), 1 + pets[1].ClickBonus + pets[2].ClickBonus, 1e-9); eq(GL.PetClickMultiplier({}), 1)
	local best = {}; eq(GL.ActiveMultiplier(best), 1)
	local lo, hi = G.Power[1].Entries[2], G.Power[1].Entries[4]
	eq(GL.RecordPowerPull(best, 1, hi), true); eq(GL.RecordPowerPull(best, 1, lo), false, "hasil lebih rendah tidak menimpa")
	near(GL.ActiveMultiplier(best), hi.Multiplier, 1e-9)
	GL.RecordPowerPull(best, 2, G.Power[2].Entries[3])
	near(GL.ActiveMultiplier(best), 1 + (hi.Multiplier - 1) + (G.Power[2].Entries[3].Multiplier - 1), 1e-9)
end)

test("bonus pet & multiplier gacha benar-benar menaikkan Power per klik (StatFormulas)", function()
	local base = GameConfig.Click.BasePowerPerClick
	local s = { Level = 1, Power = 0, Allocated = { Fortune = 0, Vitality = 0, Haste = 0, Focus = 0 } }
	eq(StatFormulas.ComputeDerived(s).PowerPerClick, base)
	local petMult = GL.PetClickMultiplier({ G.Pet[3].Entries[5] })
	local d = StatFormulas.ComputeDerived(s, { PetClickMultiplier = petMult, PowerGachaMultiplier = G.Power[3].Entries[4].Multiplier })
	assert(d.PowerPerClick > base * 2, "pet + gacha harus menaikkan Power per klik: " .. d.PowerPerClick)
	eq(StatFormulas.ComputeDerived(s, { PetClickMultiplier = 1.5 }).PowerPerClick, math.floor(base * 1.5 + 0.5))
end)

return passed, failed
