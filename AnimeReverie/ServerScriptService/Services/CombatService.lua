--!nonstrict
--[[
	CombatService | ModuleScript | ServerScriptService > Services > CombatService
	Klik attack -> Power -> damage ke musuh DIAM -> kill -> reward -> quest. Semua otoritatif di server.

	ATURAN POWER: Power hanya dari klik valid (target ada, world benar, level cukup, di bawah rate limit). Power diberikan
	INDEPENDEN dari damage, HP, status hidup/mati NPC, dan kill. Kill TIDAK memberi Power; kill hanya memberi EXP/koin/Stars
	dan progres quest sesuai config. Klik valid ke NPC yang sedang mati tetap memberi Power (tanpa damage/reward kill).

	Musuh tidak bergerak/menyerang: state-nya hanya HP + hidup/mati + respawn. Hit reaction & animasi = tugas client
	(Remote "HitResult"); BELUM dibuat. Satu instance per enemyId per server (target bersama; kill dikreditkan ke pemukul
	terakhir; target mati tidak bisa dibunuh lagi -> reward tidak ganda).
	Batas: klik/detik (MaxClicksPerSecond) dan request remote/detik (MaxRequestsPerSecond, semua payload termasuk invalid;
	kelebihan DIBUANG tanpa balasan). Jendela per detik (os.time): burst di batas detik bisa sampai ~2x.
	Remote "ClickAttack"(enemyId: string) atau langsung dari server: HandleClick(player, enemyId).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Configurations.GameConfig)
local EnemyConfig = require(ReplicatedStorage.Configurations.EnemyConfig)
local QuestConfig = require(ReplicatedStorage.Configurations.QuestConfig)
local StatFormulas = require(ReplicatedStorage.SharedModules.StatFormulas)
local QuestLogic = require(ReplicatedStorage.SharedModules.QuestLogic)
local DataService = require(script.Parent.DataService)
local PlayerStatsService = require(script.Parent.PlayerStatsService)
local Remotes = require(script.Parent.Remotes)

local CombatService = {}
local enemies = {} -- [enemyId] = { Hp, Alive }
local clicks = {} -- [player] = { Second, Count }  (klik valid)
local requests = {} -- [player] = { Second, Count } (semua request remote)

local function stateOf(id, enemy)
	local s = enemies[id]
	if not s then
		s = { Hp = enemy.MaxHealth, Alive = true }
		enemies[id] = s
	end
	return s
end

local function bump(bucketTable, player)
	local now = os.time()
	local bucket = bucketTable[player]
	if not bucket or bucket.Second ~= now then
		bucket = { Second = now, Count = 0 }
		bucketTable[player] = bucket
	end
	bucket.Count += 1
	return bucket.Count
end

-- Return: hasil (tabel) ATAU nil, alasan. Alasan: NoProfile, InvalidTarget, WrongWorld, WorldLocked, RateLimited
function CombatService.HandleClick(player, enemyId)
	local data = DataService.GetData(player)
	if not data then return nil, "NoProfile" end
	local enemy = type(enemyId) == "string" and EnemyConfig.Enemies[enemyId] or nil
	if not enemy then return nil, "InvalidTarget" end
	if data.CurrentWorld ~= enemy.WorldId then return nil, "WrongWorld" end
	if not PlayerStatsService.CanEnterWorld(player, enemy.WorldId) then return nil, "WorldLocked" end
	if bump(clicks, player) > GameConfig.Click.MaxClicksPerSecond then return nil, "RateLimited" end

	-- Klik valid: Power SELALU diberikan di sini (sebelum mengecek HP/hidup-mati NPC), lalu damage dihitung dari Power terbaru.
	local powerGained = PlayerStatsService.AwardClick(player)
	local state = stateOf(enemyId, enemy)
	local result = {
		EnemyId = enemyId, Damage = 0, Critical = false, Hp = state.Hp, MaxHp = enemy.MaxHealth,
		Killed = false, PowerGained = powerGained, TargetAlive = state.Alive,
	}
	if not state.Alive then return result end -- NPC mati/vanish: tidak ada damage, tidak ada reward kill

	local damage, critical = StatFormulas.RollHit(PlayerStatsService.GetDerived(player))
	state.Hp = math.max(0, state.Hp - damage)
	result.Damage, result.Critical, result.Hp = damage, critical, state.Hp

	if state.Hp <= 0 then
		state.Alive = false
		result.Killed, result.TargetAlive = true, false
		-- Reward kill: EXP/koin/Stars/quest saja. TIDAK ADA Power di jalur ini.
		result.Kill = PlayerStatsService.AwardKill(player, { Kind = enemy.Kind, BossBonusEXP = enemy.BossBonusEXP })
		PlayerStatsService.AddCoins(player, enemy.CoinReward)
		if enemy.StarsReward > 0 then PlayerStatsService.AddStars(player, enemy.StarsReward) end
		result.QuestsCompleted = QuestLogic.OnKill(data.Quests, QuestConfig.List, enemy.WorldId, enemyId)
		task.delay(enemy.RespawnSeconds, function()
			state.Hp, state.Alive = enemy.MaxHealth, true
		end)
	end
	return result
end

function CombatService.Init()
	DataService.OnProfileReleasing(function(player)
		clicks[player], requests[player] = nil, nil
	end)
	Remotes.Event("ClickAttack").OnServerEvent:Connect(function(player, enemyId)
		if bump(requests, player) > GameConfig.Click.MaxRequestsPerSecond then return end -- spam: buang tanpa balasan
		local result, reason = CombatService.HandleClick(player, enemyId)
		Remotes.Event("HitResult"):FireClient(player, result or { Error = reason })
	end)
	Remotes.Event("HitResult") -- pastikan ada sebelum client menunggu
end

return CombatService
