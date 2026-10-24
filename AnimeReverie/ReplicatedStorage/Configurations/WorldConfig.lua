--!nonstrict
--[[
	WorldConfig | ModuleScript | ReplicatedStorage > Configurations > WorldConfig
	Lobby (World 0) dan World 1-5 adalah TEMPAT TERPISAH (map berbeda, MapName berbeda). Lobby: tanpa musuh, tanpa quest kill.
	Inspirasi desain (catatan internal, JANGAN ditampilkan di game): W1 Dragon Ball, W2 Chainsaw Man, W3 Solo Leveling,
	W4 Hunter x Hunter, W5 Mob Psycho 100. Tidak ada training area/NPC/quest di mana pun.
]]
local function deepFreeze(t)
	if table.isfrozen(t) then return t end
	for _, v in t do if type(v) == "table" then deepFreeze(v) end end
	return table.freeze(t)
end

local WorldConfig = {
	Lobby = { Id = 0, Name = "Lobby", MapName = "Lobby", HasEnemies = false, HasQuests = false, RequiredLevel = 1 },
	Worlds = {
		{ Id = 1, Name = "Ki Realm", MapName = "KiRealm", RequiredLevel = 1, Zones = 4, HasEnemies = true, HasQuests = true },
		{ Id = 2, Name = "Devil District", MapName = "DevilDistrict", RequiredLevel = 15, Zones = 4, HasEnemies = true, HasQuests = true },
		{ Id = 3, Name = "Shadow Dominion", MapName = "ShadowDominion", RequiredLevel = 35, Zones = 4, HasEnemies = true, HasQuests = true },
		{ Id = 4, Name = "Phantom Frontier", MapName = "PhantomFrontier", RequiredLevel = 55, Zones = 4, HasEnemies = true, HasQuests = true },
		{ Id = 5, Name = "Psychic Chaos", MapName = "PsychicChaos", RequiredLevel = 75, Zones = 4, HasEnemies = true, HasQuests = true },
	},
}
function WorldConfig.Get(id)
	if id == 0 then return WorldConfig.Lobby end
	return WorldConfig.Worlds[id]
end
return deepFreeze(WorldConfig)
