--!nonstrict
--[[
	ProfileStore | ModuleScript
	Lokasi Studio: ServerScriptService > Services > ProfileStore
	Logika load/save murni terhadap objek "Store" yang punya :UpdateAsync(key, fn) (DataStore asli
	atau tiruan untuk unit test). Tidak memakai service Roblox langsung -> bisa diuji di luar Studio.

	Jaminan:
	- Session lock per server (JobId): dua server tidak bisa menulis data pemain yang sama.
	- Load gagal / terkunci / rusak / skema lebih baru  => TIDAK mengembalikan profil, TIDAK menulis apa pun.
	- Save hanya menulis jika lock masih milik server ini (kalau hilang: "LockLost", data lain tidak ditimpa).
	- Retry dengan jeda bertahap; snapshot data diambil sekali per save.
	- Versi skema + migrasi berurutan + reconcile (key baru dari template diisi otomatis).
]]

local ProfileStore = {}
ProfileStore.__index = ProfileStore

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function reconcile(data, template)
	for key, templateValue in template do
		local current = data[key]
		if current == nil then
			data[key] = deepCopy(templateValue)
		elseif type(current) == "table" and type(templateValue) == "table" then
			reconcile(current, templateValue)
		end
	end
end

-- deps: { Store, JobId, Now, Wait, Log }
-- options: { Template, SchemaVersion, Migrations, LockTimeout, LoadAttempts, LockRetryDelay, RetryDelay, SaveAttempts, FatalErrorHints }
function ProfileStore.new(deps, options)
	local self = setmetatable({}, ProfileStore)
	self.Store = deps.Store
	self.JobId = deps.JobId
	self.Now = deps.Now
	self.Wait = deps.Wait
	self.Log = deps.Log or function() end
	self.Template = options.Template
	self.SchemaVersion = options.SchemaVersion
	self.Migrations = options.Migrations or {}
	self.LockTimeout = options.LockTimeout
	self.LoadAttempts = options.LoadAttempts
	self.LockRetryDelay = options.LockRetryDelay
	self.RetryDelay = options.RetryDelay
	self.SaveAttempts = options.SaveAttempts
	self.FatalErrorHints = options.FatalErrorHints or {}
	return self
end

function ProfileStore:_isFatal(err)
	local lower = string.lower(tostring(err))
	for _, hint in self.FatalErrorHints do
		if string.find(lower, hint, 1, true) then
			return true
		end
	end
	return false
end

function ProfileStore:_prepareData(record)
	local data = deepCopy(record.Data)
	for version = (record.SchemaVersion or 1) + 1, self.SchemaVersion do
		local migrate = self.Migrations[version]
		if migrate then
			data = migrate(data) or data
		end
	end
	reconcile(data, self.Template)
	return data
end

function ProfileStore:_releaseLockOnly(key)
	pcall(function()
		self.Store:UpdateAsync(key, function(current)
			if type(current) == "table" and type(current.SessionLock) == "table" and current.SessionLock.JobId == self.JobId then
				current.SessionLock = nil
				return current
			end
			return nil
		end)
	end)
end

-- Return: profile, nil  ATAU  nil, kodeError ("SessionLocked","FutureSchema","CorruptRecord","ApiUnavailable","MigrationFailed",teks error)
function ProfileStore:LoadProfile(key)
	local lastError = "Unknown"
	for attempt = 1, self.LoadAttempts do
		local blockedBy, futureSchema, corrupt, isNew = nil, false, false, false
		local retryDelay = self.RetryDelay * attempt

		local ok, record = pcall(function()
			return self.Store:UpdateAsync(key, function(current)
				blockedBy, futureSchema, corrupt, isNew = nil, false, false, false -- transform bisa dijalankan ulang
				local now = self.Now()
				if current == nil then
					isNew = true
					return {
						SchemaVersion = self.SchemaVersion,
						SessionLock = { JobId = self.JobId, Time = now },
						Data = deepCopy(self.Template),
					}
				end
				if type(current) ~= "table" or type(current.Data) ~= "table" then
					corrupt = true
					return nil -- JANGAN menimpa record yang tidak dikenali
				end
				if (current.SchemaVersion or 1) > self.SchemaVersion then
					futureSchema = true
					return nil -- data ditulis versi game yang lebih baru: jangan di-downgrade
				end
				local lock = current.SessionLock
				if type(lock) == "table" and lock.JobId ~= self.JobId and (now - (lock.Time or 0)) < self.LockTimeout then
					blockedBy = lock.JobId
					return nil
				end
				current.SessionLock = { JobId = self.JobId, Time = now }
				return current
			end)
		end)

		if not ok then
			lastError = tostring(record)
			self.Log(("Load %s attempt %d/%d error: %s"):format(key, attempt, self.LoadAttempts, lastError))
			if self:_isFatal(lastError) then
				return nil, "ApiUnavailable"
			end
		elseif futureSchema then
			return nil, "FutureSchema"
		elseif corrupt then
			return nil, "CorruptRecord"
		elseif blockedBy then
			lastError = "SessionLocked"
			retryDelay = self.LockRetryDelay
		elseif record == nil then
			lastError = "EmptyResult"
		else
			local prepared, data = pcall(self._prepareData, self, record)
			if not prepared then
				self.Log("Migrasi gagal untuk " .. key .. ": " .. tostring(data))
				self:_releaseLockOnly(key)
				return nil, "MigrationFailed"
			end
			return {
				Key = key,
				Data = data,
				IsNew = isNew,
				Released = false,
				Saving = false,
				Ephemeral = false,
			}, nil
		end

		if attempt < self.LoadAttempts then
			self.Wait(retryDelay)
		end
	end
	return nil, lastError
end

-- Profil sementara (mis. Studio tanpa akses API). TIDAK PERNAH menulis ke DataStore.
function ProfileStore:CreateEphemeralProfile(key)
	return {
		Key = key,
		Data = deepCopy(self.Template),
		IsNew = true,
		Released = false,
		Saving = false,
		Ephemeral = true,
	}
end

function ProfileStore:_doSave(profile, releaseLock)
	local snapshot = deepCopy(profile.Data)
	local lastError = "Unknown"
	for attempt = 1, self.SaveAttempts do
		local lostLock = false
		local ok, err = pcall(function()
			return self.Store:UpdateAsync(profile.Key, function(current)
				lostLock = false
				if
					type(current) ~= "table"
					or type(current.SessionLock) ~= "table"
					or current.SessionLock.JobId ~= self.JobId
				then
					lostLock = true
					return nil -- lock bukan milik kita: jangan menulis
				end
				current.SchemaVersion = self.SchemaVersion
				current.Data = snapshot
				if releaseLock then
					current.SessionLock = nil
				else
					current.SessionLock = { JobId = self.JobId, Time = self.Now() }
				end
				return current
			end)
		end)
		if ok then
			if lostLock then
				profile.Released = true -- berhenti menulis untuk profil ini selamanya
				return false, "LockLost"
			end
			if releaseLock then
				profile.Released = true
			end
			return true
		end
		lastError = tostring(err)
		self.Log(("Save %s attempt %d/%d error: %s"):format(profile.Key, attempt, self.SaveAttempts, lastError))
		if attempt < self.SaveAttempts then
			self.Wait(self.RetryDelay * attempt)
		end
	end
	return false, "SaveFailed: " .. lastError
end

-- Return: ok, alasan. releaseLock=true untuk save terakhir (pemain keluar / server tutup).
function ProfileStore:SaveProfile(profile, releaseLock)
	if profile.Ephemeral then
		if releaseLock then
			profile.Released = true
		end
		return true
	end
	if profile.Released then
		return false, "Released"
	end
	local waited = 0
	while profile.Saving do -- satu save per profil pada satu waktu
		self.Wait(0.1)
		waited += 0.1
		if waited >= 60 then
			return false, "SaveBusy"
		end
	end
	if profile.Released then
		return false, "Released"
	end
	profile.Saving = true
	local success, ok, reason = pcall(self._doSave, self, profile, releaseLock)
	profile.Saving = false
	if not success then
		return false, tostring(ok)
	end
	return ok, reason
end

return ProfileStore
