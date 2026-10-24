--!nonstrict
--[[
	Remotes | ModuleScript (server) | ServerScriptService > Services > Remotes
	Membuat RemoteEvent di ReplicatedStorage > Remotes secara lazy. Client memakai WaitForChild("Remotes"):WaitForChild(nama).
	Aturan: payload dari client TIDAK dipercaya; handler wajib memvalidasi tipe dan nilai.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}
local folder
local cache = {}

function Remotes.Event(name)
	if not cache[name] then
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "Remotes"
			folder.Parent = ReplicatedStorage
		end
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
		cache[name] = event
	end
	return cache[name]
end

return Remotes
