--!nonstrict
--[[
	EnemyConfig | ModuleScript | ReplicatedStorage > Configurations > EnemyConfig
	Musuh World 1-5. SEMUA musuh & boss DIAM (Behavior = "Stationary"): tidak mengejar, tidak menyerang, tidak punya field
	damage ke pemain. Mereka hanya menerima serangan, bereaksi (hit reaction), mati, lalu respawn. HP naik per zona; boss
	HP tertinggi tapi tetap diam. Kill Normal = tepat +1 EXP dasar (GameConfig.EXP) -> config ini TIDAK punya EXPReward.
	Nama = plesetan/original, bukan nama karakter anime persis. Lobby (World 0) tidak punya musuh.
]]
local function deepFreeze(t)
	if table.isfrozen(t) then return t end
	for _, v in t do if type(v) == "table" then deepFreeze(v) end end
	return table.freeze(t)
end

-- { world, zona, nama, HP, koin }
local NORMAL = {
	{ 1, 1, "Saibaro", 50, 5 }, { 1, 2, "Raditro", 140, 12 }, { 1, 3, "Nappo", 380, 30 }, { 1, 4, "Frizo", 900, 70 },
	{ 2, 1, "Zombo", 2200, 150 }, { 2, 2, "Bombo", 5000, 320 }, { 2, 3, "Gunno", 11000, 700 }, { 2, 4, "Katanor", 24000, 1500 },
	{ 3, 1, "Kargo Scout", 55000, 3200 }, { 3, 2, "Tuskor Brute", 120000, 7000 }, { 3, 3, "Berux Antling", 260000, 15000 }, { 3, 4, "Kamisho Warden", 560000, 32000 },
	{ 4, 1, "Antu Soldier", 1200000, 70000 }, { 4, 2, "Troupo Thief", 2600000, 150000 }, { 4, 3, "Hisoko Jester", 5600000, 320000 }, { 4, 4, "Neferpiko Guard", 12000000, 700000 },
	{ 5, 1, "Wispo Spirit", 26000000, 1500000 }, { 5, 2, "Terukio Esper", 56000000, 3200000 }, { 5, 3, "Toichiru Claw", 120000000, 7000000 }, { 5, 4, "Suzuko Psychic", 260000000, 15000000 },
}
-- { world, nama, HP, koin, bonusEXP (terpisah dari +1 kill normal), Stars }
local BOSSES = {
	{ 1, "Bubo the Pink Tyrant", 6000, 400, 50, 10 },
	{ 2, "Makimo the Control Devil", 60000, 4000, 120, 20 },
	{ 3, "Antaros the Dominion King", 1200000, 90000, 250, 40 },
	{ 4, "Meruemo the Chimera King", 28000000, 2000000, 450, 80 },
	{ 5, "Mobu Hundred", 600000000, 45000000, 800, 160 },
}

local EnemyConfig = { Enemies = {}, ByWorld = {}, BossByWorld = {} }
for w = 1, 5 do EnemyConfig.ByWorld[w] = {} end
for _, e in NORMAL do
	local id = ("W%d_E%d"):format(e[1], e[2])
	EnemyConfig.Enemies[id] = { Id = id, WorldId = e[1], Zone = e[2], Name = e[3], Kind = "Normal", MaxHealth = e[4], CoinReward = e[5], BossBonusEXP = 0, StarsReward = 0, RespawnSeconds = 5, Behavior = "Stationary" }
	table.insert(EnemyConfig.ByWorld[e[1]], id)
end
for _, b in BOSSES do
	local id = ("W%d_Boss"):format(b[1])
	EnemyConfig.Enemies[id] = { Id = id, WorldId = b[1], Zone = 5, Name = b[2], Kind = "Boss", MaxHealth = b[3], CoinReward = b[4], BossBonusEXP = b[5], StarsReward = b[6], RespawnSeconds = 60, Behavior = "Stationary" }
	table.insert(EnemyConfig.ByWorld[b[1]], id)
	EnemyConfig.BossByWorld[b[1]] = id
end

local FORBIDDEN = { "Damage", "AttackDamage", "ChaseSpeed", "MoveSpeed", "WalkSpeed", "AggroRange", "AttackRange", "AttackCooldown" }
local ANIME_EXACT = {} -- nama karakter anime PERSIS yang dilarang sebagai nama unit game
for _, n in { "goku", "vegeta", "frieza", "cell", "buu", "majin buu", "denji", "makima", "pochita", "power", "aki", "sung jinwoo", "jinwoo", "igris", "beru", "gon", "killua", "hisoka", "meruem", "mob", "dimple", "reigen", "saibaman", "raditz", "nappa" } do
	ANIME_EXACT[n] = true
end
EnemyConfig.AnimeExactNames = ANIME_EXACT

-- Return daftar masalah (kosong = valid). Parameter opsional supaya validator bisa diuji dengan data rusak.
function EnemyConfig.Validate(enemies, byWorld)
	enemies, byWorld = enemies or EnemyConfig.Enemies, byWorld or EnemyConfig.ByWorld
	local problems, seen = {}, {}
	for id, e in enemies do
		if e.Behavior ~= "Stationary" then table.insert(problems, id .. ": Behavior harus 'Stationary'") end
		for _, key in FORBIDDEN do
			if e[key] ~= nil then table.insert(problems, id .. ": field agresif terlarang '" .. key .. "'") end
		end
		if type(e.MaxHealth) ~= "number" or e.MaxHealth <= 0 then table.insert(problems, id .. ": MaxHealth tidak valid") end
		if e.WorldId == nil or e.WorldId < 1 then table.insert(problems, id .. ": Lobby/world tidak valid tidak boleh punya musuh") end
		local lower = string.lower(e.Name)
		if ANIME_EXACT[lower] then table.insert(problems, id .. ": nama anime persis '" .. e.Name .. "'") end
		if seen[lower] then table.insert(problems, id .. ": nama kembar dengan " .. seen[lower]) end
		seen[lower] = id
	end
	if byWorld[0] ~= nil then table.insert(problems, "Lobby (world 0) tidak boleh punya daftar musuh") end
	for w = 1, 5 do
		local ids = byWorld[w]
		if not ids or #ids < 5 then
			table.insert(problems, "world " .. w .. ": butuh >= 4 musuh normal + 1 boss")
		else
			local last = 0
			for _, id in ids do
				local e = enemies[id]
				if not e or e.WorldId ~= w then table.insert(problems, "world " .. w .. ": " .. tostring(id) .. " bukan milik world ini")
				elseif e.MaxHealth <= last then table.insert(problems, id .. ": HP harus naik menurut zona") end
				if e then last = e.MaxHealth end
			end
		end
	end
	return problems
end

return deepFreeze(EnemyConfig)
