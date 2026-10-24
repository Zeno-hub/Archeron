--!nonstrict
--[[
	GachaLogic | ModuleScript | ReplicatedStorage > SharedModules > GachaLogic
	Logika gacha MURNI (undian berbobot, validasi peluang, bonus pet, multiplier Power gacha).
	Pembayaran, penyimpanan, dan pemanggilan Roll terjadi di SERVER (service gacha, belum dibuat).
	State multiplier memakai key string "W<id>" (DataStore tidak boleh key angka non-urut).
]]
local GachaLogic = {}

-- Return: ok, jumlah. Tabel valid bila semua Weight > 0 dan jumlahnya TEPAT 100.
function GachaLogic.ValidateOdds(entries)
	local sum = 0
	for _, e in entries do
		if type(e.Weight) ~= "number" or e.Weight ~= e.Weight or e.Weight <= 0 then return false, "InvalidWeight" end
		sum += e.Weight
	end
	return math.abs(sum - 100) < 1e-9, sum
end

function GachaLogic.Roll(entries, rng)
	rng = rng or math.random
	local total = 0
	for _, e in entries do total += e.Weight end
	local r, acc = rng() * total, 0
	for _, e in entries do
		acc += e.Weight
		if r < acc then return e end
	end
	return entries[#entries]
end

-- Total bonus pet yang di-equip: 1 + jumlah ClickBonus.
function GachaLogic.PetClickMultiplier(equippedPets)
	local bonus = 0
	for _, pet in equippedPets do bonus += pet.ClickBonus end
	return 1 + bonus
end

-- best: { ["W1"] = multiplier terbaik }. Return true bila hasil pull lebih baik dari yang tercatat.
function GachaLogic.RecordPowerPull(best, worldId, entry)
	local key = "W" .. worldId
	if entry.Multiplier > (best[key] or 1) then
		best[key] = entry.Multiplier
		return true
	end
	return false
end

-- Multiplier aktif = 1 + jumlah (terbaik tiap world - 1).
function GachaLogic.ActiveMultiplier(best)
	local total = 1
	for _, m in best do total += math.max(0, m - 1) end
	return total
end

return GachaLogic
