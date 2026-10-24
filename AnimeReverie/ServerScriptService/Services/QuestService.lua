--!nonstrict
--[[
	QuestService | ModuleScript | ServerScriptService > Services > QuestService
	Klaim reward quest kill (Stars + EXP) -- tepat sekali per quest (QuestLogic.Claim). Progres quest dihitung
	CombatService saat kill. Remote: "ClaimQuest"(questId: string) -> "QuestResult" { Ok, Reward | Reason }.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local QuestConfig = require(ReplicatedStorage.Configurations.QuestConfig)
local QuestLogic = require(ReplicatedStorage.SharedModules.QuestLogic)
local DataService = require(script.Parent.DataService)
local PlayerStatsService = require(script.Parent.PlayerStatsService)
local Remotes = require(script.Parent.Remotes)

local QuestService = {}
local byId = {}
for _, quest in QuestConfig.List do byId[quest.Id] = quest end

-- Return: true, reward ATAU false, alasan ("NoProfile" | "InvalidQuest" | "NotCompleted" | "AlreadyClaimed")
function QuestService.Claim(player, questId)
	local data = DataService.GetData(player)
	if not data then return false, "NoProfile" end
	local quest = type(questId) == "string" and byId[questId] or nil
	if not quest then return false, "InvalidQuest" end
	local ok, reward = QuestLogic.Claim(data.Quests, quest)
	if not ok then return false, reward end
	PlayerStatsService.AddStars(player, reward.Stars)
	PlayerStatsService.AddEXP(player, reward.EXP)
	return true, reward
end

function QuestService.GetSummary(player, questId)
	local data, quest = DataService.GetData(player), byId[questId]
	if not data or not quest then return nil end
	return QuestLogic.Summary(data.Quests, quest)
end

function QuestService.Init()
	Remotes.Event("ClaimQuest").OnServerEvent:Connect(function(player, questId)
		local ok, result = QuestService.Claim(player, questId)
		Remotes.Event("QuestResult"):FireClient(player, ok and { Ok = true, Reward = result } or { Ok = false, Reason = result })
	end)
	Remotes.Event("QuestResult")
end

return QuestService
