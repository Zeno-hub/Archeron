--!nonstrict
--[[
	QuestConfig | ModuleScript | ReplicatedStorage > Configurations > QuestConfig
	Quest KILL per world (World 1-5; Lobby tidak punya). Target hanya musuh dari world itu sendiri. Reward jelas: Stars + EXP,
	diberikan SEKALI lewat klaim (QuestLogic.Claim). Kesulitan progresif: 10 -> 20 -> 30 kill, lalu boss.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EnemyConfig = require(ReplicatedStorage.Configurations.EnemyConfig)
local function deepFreeze(t)
	if table.isfrozen(t) then return t end
	for _, v in t do if type(v) == "table" then deepFreeze(v) end end
	return table.freeze(t)
end

local TIERS = { { goal = 10, zones = { 1 }, stars = 5, exp = 20 }, { goal = 20, zones = { 2 }, stars = 10, exp = 50 }, { goal = 30, zones = { 3, 4 }, stars = 20, exp = 100 } }
local QuestConfig = { List = {}, ByWorld = {} }
local function add(w, i, name, targets, goal, reward)
	local quest = { Id = ("W%d_Q%d"):format(w, i), WorldId = w, Name = name, TargetEnemyIds = targets, Goal = goal, Reward = reward }
	table.insert(QuestConfig.List, quest)
	table.insert(QuestConfig.ByWorld[w], quest)
end
for w = 1, 5 do
	QuestConfig.ByWorld[w] = {}
	for i, t in TIERS do
		local targets, names = {}, {}
		for _, z in t.zones do
			local id = ("W%d_E%d"):format(w, z)
			table.insert(targets, id)
			table.insert(names, EnemyConfig.Enemies[id].Name)
		end
		add(w, i, ("Defeat %d %s"):format(t.goal, table.concat(names, " / ")), targets, t.goal, { Stars = t.stars * w, EXP = t.exp * w })
	end
	local bossId = EnemyConfig.BossByWorld[w]
	add(w, 4, "Defeat " .. EnemyConfig.Enemies[bossId].Name, { bossId }, 1, { Stars = 50 * w, EXP = 300 * w })
end
return deepFreeze(QuestConfig)
