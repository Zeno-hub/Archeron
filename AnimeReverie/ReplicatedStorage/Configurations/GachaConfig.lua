--!nonstrict
--[[
	GachaConfig | ModuleScript | ReplicatedStorage > Configurations > GachaConfig
	DUA gacha terpisah di setiap world 1-5:
	  Pet gacha   : mata uang STARS (GameConfig sumber: quest/boss), hasil = pet -> bonus Power per klik saat di-equip.
	  Power gacha : mata uang COINS (sumber: kill musuh), hasil = multiplier Power per klik. Tidak memakai Stars.
	Rarity & peluang ditampilkan ke pemain; Weight = persen dan tiap tabel berjumlah TEPAT 100. Nama = plesetan/original.
]]
local function deepFreeze(t)
	if table.isfrozen(t) then return t end
	for _, v in t do if type(v) == "table" then deepFreeze(v) end end
	return table.freeze(t)
end

local RARITIES = { "Common", "Rare", "Epic", "Legendary", "Mythic" }
local ODDS = { 60, 25, 10, 4, 1 }
local PET_BONUS = { 0.05, 0.10, 0.20, 0.40, 1.00 } -- bonus Power/klik per pet (dikali skala world)
local POWER_MULT = { 1.10, 1.25, 1.50, 2.00, 3.00 } -- multiplier Power/klik (dikali skala world)
local PET_COST = { 10, 25, 50, 100, 200 } -- Stars per pull
local POWER_COST = { 100, 1000, 10000, 100000, 1000000 } -- Coins per pull
local PET_NAMES = {
	{ "Kiblast Pup", "Saibaro Sprout", "Vegaro", "Goka", "Shenro Dragon" },
	{ "Denjo Pup", "Pawari Kitty", "Akio Fox", "Pochiro", "Chainsor Devil" },
	{ "Shadow Imp", "Tuskin", "Beruno", "Igriz", "Jinwu the Monarch" },
	{ "Nen Wisp", "Killuo Zap", "Kurapiko", "Gono", "Gingo Fisher" },
	{ "Psy Wisp", "Ekibo", "Reigeno", "Dimplo", "Mobu Burst" },
}
local POWER_NAMES = {
	{ "Ki Spark", "Kamehamo Wave", "Spirito Bomb", "Super Sayajo Aura", "Ultra Instinko" },
	{ "Blood Rev", "Chainsor Rush", "Gun Fiend Barrage", "Hell Contract", "Devil Heart Surge" },
	{ "Shadow Step", "Dagger Rush", "Arise Echo", "Monarch Domain", "Sovereign Ascend" },
	{ "Nen Aura", "Jajanko Fist", "Bungee Gummo", "Hatsu Burst", "Dark Continento" },
	{ "Psy Pulse", "Spirito Slam", "Explosion Rage", "Barrier Burst", "Hundred Percento Burst" },
}
local function scale(w) return 1 + 0.5 * (w - 1) end

local GachaConfig = { PetCurrency = "Stars", PowerCurrency = "Coins", Rarities = RARITIES, Pet = {}, Power = {} }
for w = 1, 5 do
	local pet, power = {}, {}
	for i, rarity in RARITIES do
		table.insert(pet, { Id = ("W%d_P%d"):format(w, i), Rarity = rarity, Name = PET_NAMES[w][i], Weight = ODDS[i], ClickBonus = PET_BONUS[i] * scale(w) })
		table.insert(power, { Id = ("W%d_G%d"):format(w, i), Rarity = rarity, Name = POWER_NAMES[w][i], Weight = ODDS[i], Multiplier = 1 + (POWER_MULT[i] - 1) * scale(w) })
	end
	GachaConfig.Pet[w] = { WorldId = w, Currency = "Stars", Cost = PET_COST[w], Entries = pet }
	GachaConfig.Power[w] = { WorldId = w, Currency = "Coins", Cost = POWER_COST[w], Entries = power }
end
return deepFreeze(GachaConfig)
