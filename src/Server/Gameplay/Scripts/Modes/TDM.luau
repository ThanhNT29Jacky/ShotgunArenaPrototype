local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Scoring = require(script.Parent.Parent.Scoring)
local disconnectAndClear = require(ReplicatedStorage.Utility.disconnectAndClear)

local blasterEvents = ServerScriptService.Blaster.Events
local eliminatedEvent = blasterEvents.Eliminated

local TEAM_SCORE_LIMIT = 50

local connections = {}

local Mode = {
	timer = 60 * 5,
}

function Mode.start(finish: () -> ())
	table.insert(
		connections,
		eliminatedEvent.Event:Connect(function(player: Player)
			local team = player.Team
			Scoring.incrementScore(player, 1)

			-- Finish early when a team reaches the scoring limit
			if team then
				local teamScore = Scoring.getTeamScore(team)
				if teamScore >= TEAM_SCORE_LIMIT then
					finish()
				end
			end
		end)
	)
end

function Mode.stop()
	disconnectAndClear(connections)
end

return Mode
