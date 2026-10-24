-- tests/mock_roblox.lua  (disisipkan oleh run_tests.py di dalam fungsi; `__sources` disediakan runner)
-- Roblox PALSU minimal + penjadwal virtual (task.spawn/wait/delay) supaya DataService & PlayerStatsService
-- bisa dijalankan di Luau CLI. Ini BUKAN Roblox: hanya memverifikasi ALUR logika kode kita (urutan, penantian,
-- save/load). Tidak memodelkan: throttling DataStore, batas ukuran, teks error asli, replikasi, perilaku Studio.
local BASE_TIME = 1700000000
local Sched = { now = 0, seq = 0, sleepers = {}, errors = {} }
local H = { Sched = Sched, BASE_TIME = BASE_TIME }

local function deepCopy(v)
	if type(v) ~= "table" then return v end
	local c = {}
	for k, x in v do c[k] = deepCopy(x) end
	return c
end
local function deepEq(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for k, v in a do if not deepEq(v, b[k]) then return false end end
	for k in b do if a[k] == nil then return false end end
	return true
end
H.deepCopy, H.deepEq = deepCopy, deepEq

local function resume(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then table.insert(Sched.errors, tostring(err)) end -- error di thread = temuan, bukan diam-diam hilang
end

local function sleep(seconds)
	Sched.seq += 1
	local start = Sched.now
	table.insert(Sched.sleepers, { time = start + seconds, seq = Sched.seq, co = coroutine.running() })
	coroutine.yield()
	return Sched.now - start
end

local function newTask()
	local task = {}
	function task.spawn(fn, ...)
		local co = coroutine.create(fn)
		resume(co, ...)
		return co
	end
	function task.wait(seconds) return sleep(seconds or 0.03) end
	function task.delay(seconds, fn, ...)
		local args = table.pack(...)
		task.spawn(function() sleep(seconds); fn(table.unpack(args, 1, args.n)) end)
	end
	return task
end
local GT = newTask()

function H.now() return Sched.now end
function H.reset() Sched.now, Sched.seq, Sched.sleepers, Sched.errors = 0, 0, {}, {} end

-- Jalankan thread terjadwal sampai predicate true (atau waktu virtual habis / tidak ada thread tersisa).
function H.runUntil(predicate, maxSeconds)
	local limit = Sched.now + (maxSeconds or 1000)
	while true do
		if predicate and predicate() then return true end
		local best, bestIndex
		for i, s in Sched.sleepers do
			if not best or s.time < best.time or (s.time == best.time and s.seq < best.seq) then
				best, bestIndex = s, i
			end
		end
		if not best or best.time > limit then
			Sched.now = math.max(Sched.now, limit)
			return predicate == nil
		end
		table.remove(Sched.sleepers, bestIndex)
		Sched.now = math.max(Sched.now, best.time)
		resume(best.co)
	end
end
function H.runFor(seconds) H.runUntil(nil, seconds) end

-- Jalankan satu tes di dalam coroutine (boleh memanggil task.wait). Error di dalam tes dilempar ulang.
function H.run(fn, maxSeconds)
	local finished, err = false, nil
	local co = coroutine.create(function()
		local ok, e = pcall(fn)
		if not ok then err = e end
		finished = true
	end)
	resume(co)
	H.runUntil(function() return finished end, maxSeconds or 2000)
	if not finished then error("tes menggantung (tidak selesai)", 0) end
	if err ~= nil then error(err, 0) end
end

-- DataStore palsu bersama (dipakai beberapa "server"). transform dijalankan atomik di tengah latensi.
function H.newStore()
	local store = { data = {}, calls = 0, failNext = 0, latency = 0, failWith = "simulated DataStore error 502" }
	function store:UpdateAsync(key, transform)
		self.calls += 1
		if self.latency > 0 then GT.wait(self.latency / 2) end
		if self.failNext > 0 then
			self.failNext -= 1
			error(self.failWith, 0)
		end
		local new = transform(deepCopy(self.data[key]))
		if new ~= nil then self.data[key] = deepCopy(new) end
		if self.latency > 0 then GT.wait(self.latency / 2) end
		return deepCopy(new)
	end
	return store
end

local function newSignal(task)
	local handlers, signal = {}, {}
	function signal:Connect(fn)
		table.insert(handlers, fn)
		return { Disconnect = function() end }
	end
	function signal:Fire(...)
		for _, fn in handlers do task.spawn(fn, ...) end
	end
	return signal
end

-- Satu "server" = kumpulan instance modul baru + game/Players/os palsu sendiri (JobId berbeda).
function H.newServer(jobId, store, opts)
	opts = opts or {}
	local server = { Warnings = {}, CloseCallbacks = {}, Instances = {} }
	local task = newTask()
	local osMock = {
		time = function() return BASE_TIME + math.floor(Sched.now) end,
		clock = function() return Sched.now end,
	}

	local Players = { PlayerAdded = newSignal(task), PlayerRemoving = newSignal(task), List = {} }
	function Players:GetPlayers() return table.clone(self.List) end
	server.Players = Players

	function server:AddPlayer(userId, name)
		local player = { UserId = userId, Name = name or ("Player" .. userId), Parent = Players }
		function player:Kick(message)
			self.KickMessage = message
			server:RemovePlayer(self)
		end
		table.insert(Players.List, player)
		Players.PlayerAdded:Fire(player)
		return player
	end
	function server:RemovePlayer(player)
		if player.Parent == nil then return end
		Players.PlayerRemoving:Fire(player)
		player.Parent = nil
		local index = table.find(Players.List, player)
		if index then table.remove(Players.List, index) end
	end
	-- Meniru shutdown server: jalankan semua callback BindToClose paralel, kembali setelah semuanya selesai.
	function server:Shutdown()
		local remaining = #self.CloseCallbacks
		for _, fn in self.CloseCallbacks do
			task.spawn(function()
				local ok, e = pcall(fn)
				if not ok then table.insert(Sched.errors, tostring(e)) end
				remaining -= 1
			end)
		end
		while remaining > 0 do task.wait(0.05) end
	end

	local services = {
		Players = Players,
		DataStoreService = { GetDataStore = function(_, _name) return store end },
		RunService = { IsStudio = function() return opts.isStudio == true end },
	}
	local game = {
		JobId = jobId,
		GetService = function(_, name) return services[name] or {} end,
		BindToClose = function(_, fn) table.insert(server.CloseCallbacks, fn) end,
	}
	local function warn(...)
		local parts = {}
		for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
		table.insert(server.Warnings, table.concat(parts, " "))
	end
	local Instance = {
		new = function(className)
			local inst = { ClassName = className, Name = className }
			table.insert(server.Instances, inst)
			return inst
		end,
	}

	local cache = {}
	local function req(name)
		if cache[name] == nil then
			local factory = __sources[name]
			assert(factory, "modul tidak dikenal: " .. tostring(name))
			cache[name] = factory(game, task, osMock, warn, Instance, {}, req)
		end
		return cache[name]
	end
	server.require, server.task = req, task
	return server
end

return H
