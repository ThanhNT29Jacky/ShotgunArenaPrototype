local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Teams = game:GetService("Teams")

local Constants = require(ReplicatedStorage.Gameplay.Constants)
local Scoring = require(script.Parent.Scoring)
local spawnCharacters = require(script.spawnCharacters)
local despawnCharacters = require(script.despawnCharacters)
local TeamAssigner = require(script.TeamAssigner)

local remotes = ReplicatedStorage.Gameplay.Remotes
local roundWinnerRemote = remotes.RoundWinner

local MODES = {
	require(script.Parent.Modes.TDM),
}

local random = Random.new()

-- Assign team each time a player's character loads so the balanced
-- round-robin stays correct across respawns.
local function onCharacterAdded(player: Player): ()
	local team = TeamAssigner.assignTeam(player)
	if team == "" then
		warn("[Rounds] TeamAssigner returned empty team for", player.Name)
	end
end

local function onPlayerAdded(player: Player): ()
	player.CharacterAdded:Connect(function()
		onCharacterAdded(player)
	end)
end

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

local function startRoundLoopAsync()
	while true do
		-- Reset scores
		Scoring.resetScores()

		-- Pick mode
		local mode = MODES[random:NextInteger(1, #MODES)]
		local timer = mode.timer

		-- Start the mode, passing in a callback to be called if it finishes early
		local roundFinished = false
		mode.start(function()
			roundFinished = true
		end)

		-- Spawn characters
		Players.CharacterAutoLoads = true
		spawnCharacters()

		-- Countdown timer
		while timer > 0 and not roundFinished do
			timer -= 1
			Workspace:SetAttribute(Constants.TIMER_ATTRIBUTE, timer)
			task.wait(1)
		end

		-- End the mode
		mode.stop()

		-- Display winning team
		local teams = Teams:GetTeams()
		table.sort(teams, function(teamA: Team, teamB: Team)
			return Scoring.getTeamScore(teamA) > Scoring.getTeamScore(teamB)
		end)

		local winningTeam = teams[1]
		roundWinnerRemote:FireAllClients(winningTeam)

		-- Disable spawning
		Players.CharacterAutoLoads = false
		despawnCharacters()

		-- Wait for intermission
		task.wait(Constants.INTERMISSION_TIME)
	end
end

task.spawn(startRoundLoopAsync)
