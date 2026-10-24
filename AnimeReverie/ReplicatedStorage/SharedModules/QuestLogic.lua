--!nonstrict
--[[
	QuestLogic | ModuleScript | ReplicatedStorage > SharedModules > QuestLogic
	Logika quest kill MURNI. state = { [questId] = { Progress, Status } }, Status: "Active" -> "Completed" -> "Claimed".
	Kill hanya dihitung bila world & musuh cocok dengan target quest, dan hanya saat Active (satu kill tidak bisa
	dihitung dua kali oleh quest yang sama). Reward hanya keluar sekali lewat Claim.
]]
local QuestLogic = {}

local function entry(state, id)
	local s = state[id]
	if not s then
		s = { Progress = 0, Status = "Active" }
		state[id] = s
	end
	return s
end

-- Panggil SETELAH server mengonfirmasi satu kill. Return: daftar id quest yang baru menjadi Completed.
function QuestLogic.OnKill(state, quests, worldId, enemyId)
	local completed = {}
	for _, q in quests do
		if q.WorldId == worldId and table.find(q.TargetEnemyIds, enemyId) then
			local s = entry(state, q.Id)
			if s.Status == "Active" then
				s.Progress = math.min(q.Goal, s.Progress + 1)
				if s.Progress >= q.Goal then
					s.Status = "Completed"
					table.insert(completed, q.Id)
				end
			end
		end
	end
	return completed
end

-- Return: true, reward  ATAU  false, "NotCompleted" | "AlreadyClaimed"
function QuestLogic.Claim(state, quest)
	local s = state[quest.Id]
	if s and s.Status == "Claimed" then return false, "AlreadyClaimed" end
	if not s or s.Status ~= "Completed" then return false, "NotCompleted" end
	s.Status = "Claimed"
	return true, quest.Reward
end

function QuestLogic.Summary(state, quest)
	local s = state[quest.Id]
	return { Progress = s and s.Progress or 0, Goal = quest.Goal, Status = s and s.Status or "Active" }
end

return QuestLogic
