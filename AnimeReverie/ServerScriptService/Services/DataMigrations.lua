--!nonstrict
--[[
	DataMigrations | ModuleScript | ServerScriptService > Services > DataMigrations
	[versiBaru] = function(data) ... return data end. ProfileStore menjalankannya berurutan dari versi record + 1.
]]
return {
	-- v2 (revisi gameplay): "Power" tidak lagi atribut alokasi (kini hasil klik). Poin yang sudah dialokasikan
	-- ke Power DIKEMBALIKAN sebagai StatPoints (tidak ada poin yang hilang), key Allocated.Power dihapus.
	[2] = function(data)
		local alloc = data.Allocated
		if type(alloc) == "table" then
			local spent = alloc.Power
			if type(spent) == "number" and spent == spent and spent > 0 and spent < math.huge then
				data.StatPoints = (type(data.StatPoints) == "number" and data.StatPoints or 0) + math.floor(spent)
			end
			alloc.Power = nil
		end
		return data
	end,
}
