--!nonstrict
--[[
	CombatService | ModuleScript | ServerScriptService > Services > CombatService
	Klik attack -> Power -> damage ke musuh DIAM -> kill -> reward -> quest. Semua otoritatif di server.
	Musuh tidak bergerak/menyerang: state-nya hanya HP + hidup/mati + respawn. Hit reaction & animasi = tugas client
	(menerima Remote "HitResult"); BELUM dibuat. Satu instance per enemyId per server (target bersama; kill dikreditkan
	ke pemain yang memberi pukulan terakhir; target mati menolak klik lain -> reward tidak bisa ganda).
	Batas klik: jendela per detik (os.time) -- burst di batas detik bisa sampai ~2x; cukup untuk tahap ini.
	Dipanggil via Remote "ClickAttack"(enemyId: string) atau langsung oleh server: HandleClick(player, enemyId).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Configurations.GameConfig)
local EnemyConfig = require(ReplicatedStorage.Configurations.EnemyConfig)
local WorldConfig = require(ReplicatedStorage.Configurations.WorldConfig)
local QuestConfig = require(ReplicatedStorage.Configurations.QuestConfig)
local StatFormulas = require(ReplicatedStorage.SharedModules.StatFormulas)
local QuestLogic = require(ReplicatedStorage.SharedModules.QuestLogic)
local DataService = require(script.Parent.DataService)
local PlayerStatsService = require(script.Parent.PlayerStatsService)
local Remotes = require(script.Parent.Remotes)

local CombatService = {}
local enemies = {} -- [enemyId] = { Hp, Alive }
local clicks = {} -- [player] = { Second, Count }

local function stateOf(id, enemy)
	local s = enemies[id]
	if not s then
		s = { Hp = enemy.MaxHealth, Alive = true }
		enemies[id] = s
	end
	return s
end

-- Return: hasil (tabel) ATAU nil, alasan. Alasan: NoProfile, InvalidTarget, WrongWorld, WorldLocked, RateLimited, TargetDead
function CombatService.HandleClick(player, enemyId)
	local data = DataService.GetData(player)
	if not data then return nil, "NoProfile" end
	local enemy = type(enemyId) == "string" and EnemyConfig.Enemies[enemyId] or nil
	if not enemy then return nil, "InvalidTarget" end
	if data.CurrentWorld ~= enemy.WorldId then return nil, "WrongWorld" end
	if data.Level < WorldConfig.Get(enemy.WorldId).RequiredLevel then return nil, "WorldLocked" end

	local now = os.time()
	local bucket = clicks[player]
	if not bucket or bucket.Second ~= now then
		bucket = { Second = now, Count = 0 }
		clicks[player] = bucket
	end
	if bucket.Count >= GameConfig.Click.MaxClicksPerSecond then return nil, "RateLimited" end
	bucket.Count += 1

	local state = stateOf(enemyId, enemy)
	if not state.Alive then return nil, "TargetDead" end

	local powerGained = PlayerStatsService.AwardClick(player) -- klik dulu menambah Power, lalu damage dihitung
	local damage, critical = StatFormulas.RollHit(PlayerStatsService.GetDerived(player))
	state.Hp = math.max(0, state.Hp - damage)
	local result = {
		EnemyId = enemyId, Damage = damage, Critical = critical, Hp = state.Hp, MaxHp = enemy.MaxHealth,
		Killed = false, PowerGained = powerGained,
	}

	if state.Hp <= 0 then
		state.Alive = false
		result.Killed = true
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
	DataService.OnProfileReleasing(function(player) clicks[player] = nil end)
	Remotes.Event("ClickAttack").OnServerEvent:Connect(function(player, enemyId)
		local result, reason = CombatService.HandleClick(player, enemyId)
		Remotes.Event("HitResult"):FireClient(player, result or { Error = reason })
	end)
	Remotes.Event("HitResult") -- pastikan ada sebelum client menunggu
end

return CombatService
