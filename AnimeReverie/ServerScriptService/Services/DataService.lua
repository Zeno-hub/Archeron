--!nonstrict
--[[
	DataService | ModuleScript
	Lokasi Studio: ServerScriptService > Services > DataService
	Menghubungkan ProfileStore ke Players + DataStoreService: load saat join, autosave, save terakhir
	saat keluar, BindToClose. Service lain mengakses data lewat DataService.GetData(player).

	Urutan boot (lihat Main): semua service memanggil OnProfileLoaded/OnProfileReleasing di Init(),
	DataService.Start() dipanggil PALING AKHIR.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Configurations.GameConfig)
local ProfileStore = require(script.Parent.ProfileStore)
local DataTemplate = require(script.Parent.DataTemplate)
local DataMigrations = require(script.Parent.DataMigrations)

local cfg = GameConfig.Data

local DataService = { Profiles = {} } -- [Player] = profile

local store
local started = false
local activeReleases = 0
local loading = {}
local loadedCallbacks, releasingCallbacks = {}, {}

local function log(message)
	warn("[DataService] " .. message)
end

local function runCallbacks(list, player, profile, label)
	for _, callback in list do
		local ok, err = pcall(callback, player, profile)
		if not ok then
			log(label .. " error: " .. tostring(err))
		end
	end
end

-- callback(player, profile) dipanggil berurutan setelah data siap / sebelum save terakhir
function DataService.OnProfileLoaded(callback)
	table.insert(loadedCallbacks, callback)
end

function DataService.OnProfileReleasing(callback)
	table.insert(releasingCallbacks, callback)
end

-- Data hidup pemain (tabel yang di-save), atau nil jika belum dimuat / sedang keluar.
function DataService.GetData(player)
	local profile = DataService.Profiles[player]
	if profile and not profile.Releasing then
		return profile.Data
	end
	return nil
end

local function handleSaveFailure(player, reason)
	if reason == "LockLost" then
		player:Kick("Your data session was taken over by another server. Please rejoin.")
	else
		log(("Save gagal untuk %s: %s"):format(player.Name, tostring(reason)))
	end
end

-- Simpan segera (mis. setelah pembelian). Return ok, alasan.
function DataService.SaveNow(player)
	local profile = DataService.Profiles[player]
	if not profile or profile.Releasing then
		return false, "NoProfile"
	end
	local ok, reason = store:SaveProfile(profile, false)
	if not ok then
		handleSaveFailure(player, reason)
	end
	return ok, reason
end

-- Satu-satunya jalur pelepasan profil (PlayerRemoving & BindToClose). Pembersihan SELALU terjadi walau ada
-- error tak terduga, supaya activeReleases tidak macet dan BindToClose tidak menunggu sia-sia sampai timeout.
local function releaseProfile(player, profile)
	if profile.Releasing then
		return
	end
	profile.Releasing = true
	activeReleases += 1
	local ok, err = pcall(function()
		runCallbacks(releasingCallbacks, player, profile, "OnProfileReleasing")
		local saved, reason = store:SaveProfile(profile, true)
		if not saved then
			log(("Save terakhir gagal untuk %s: %s"):format(player.Name, tostring(reason)))
		end
	end)
	if not ok then
		log(("Error saat melepas profil %s: %s"):format(player.Name, tostring(err)))
	end
	DataService.Profiles[player] = nil
	activeReleases -= 1
end

local function onPlayerAdded(player)
	if loading[player] or DataService.Profiles[player] then
		return
	end
	loading[player] = true
	local key = cfg.KeyPrefix .. player.UserId
	local loaded, profile, reason = pcall(store.LoadProfile, store, key)
	if not loaded then
		profile, reason = nil, tostring(profile)
	end

	if player.Parent ~= Players then -- pemain keluar saat loading: lepas lock (dilacak agar BindToClose menunggu)
		activeReleases += 1
		loading[player] = nil
		if profile then
			pcall(store.SaveProfile, store, profile, true)
		end
		activeReleases -= 1
		return
	end
	loading[player] = nil

	if not profile then
		if RunService:IsStudio() and cfg.AllowEphemeralInStudio then
			log(("Load gagal (%s). STUDIO: memakai data sementara, TIDAK akan disimpan."):format(tostring(reason)))
			profile = store:CreateEphemeralProfile(key)
		else
			log(("Load gagal untuk %s: %s"):format(player.Name, tostring(reason)))
			player:Kick("Failed to load your data (" .. tostring(reason) .. "). Please rejoin.")
			return
		end
	end

	DataService.Profiles[player] = profile
	runCallbacks(loadedCallbacks, player, profile, "OnProfileLoaded")
end

local function onPlayerRemoving(player)
	local profile = DataService.Profiles[player]
	if profile then
		releaseProfile(player, profile)
	end
end

local function autosaveLoop()
	while true do
		task.wait(cfg.AutosaveSeconds)
		for _, player in Players:GetPlayers() do
			local profile = DataService.Profiles[player]
			if profile and not profile.Releasing and not profile.Ephemeral then
				task.spawn(function()
					local ok, reason = store:SaveProfile(profile, false)
					if not ok then
						handleSaveFailure(player, reason)
					end
				end)
				task.wait(0.2) -- sebar beban request
			end
		end
	end
end

-- Lepas semua profil yang belum dilepas (snapshot dulu, karena releaseProfile mengubah Profiles).
local function releaseAllPending()
	local pending = {}
	for player, profile in DataService.Profiles do
		if not profile.Releasing then
			table.insert(pending, { player, profile })
		end
	end
	for _, entry in pending do
		task.spawn(releaseProfile, entry[1], entry[2])
	end
end

-- BindToClose: kembali HANYA setelah semua save/release selesai (maks CloseTimeoutSeconds, < batas 30 dtk Roblox).
-- Menunggu juga load yang masih berjalan; profil yang baru selesai dimuat saat shutdown ikut dilepas.
-- Batas waktu dihitung dari hasil task.wait (bukan os.clock) supaya tidak bergantung pada semantik jam.
local function onClose()
	local waited = 0
	while true do
		releaseAllPending()
		if activeReleases == 0 and next(loading) == nil then
			return
		end
		if waited >= cfg.CloseTimeoutSeconds then
			log("BindToClose timeout: masih ada proses save/load yang belum selesai")
			return
		end
		waited += task.wait(0.1) or 0.1
	end
end

function DataService.Start()
	if started then
		return
	end
	started = true

	local isStudio = RunService:IsStudio()
	store = ProfileStore.new({
		Store = DataStoreService:GetDataStore(cfg.StoreName),
		JobId = if game.JobId ~= "" then game.JobId else "STUDIO",
		Now = os.time,
		Wait = task.wait,
		Log = log,
	}, {
		Template = DataTemplate,
		SchemaVersion = cfg.SchemaVersion,
		Migrations = DataMigrations, -- [versiBaru] = function(data) ... end (lihat DataMigrations.lua)
		LockTimeout = cfg.LockTimeoutSeconds,
		LoadAttempts = if isStudio then 2 else cfg.LoadAttempts, -- Studio: gagal cepat
		LockRetryDelay = cfg.LockRetryDelay,
		RetryDelay = cfg.RetryDelay,
		SaveAttempts = cfg.SaveAttempts,
		FatalErrorHints = cfg.FatalErrorHints,
	})

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	task.spawn(autosaveLoop)
	game:BindToClose(onClose)
end

return DataService
