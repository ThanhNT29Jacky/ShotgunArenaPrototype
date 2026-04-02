--!nocheck

--[[
	Rather than setting up a fully custom scoring system, we'll use the built in 'leaderstats' system
	which integrates with the default leaderboard to track player scores.
	https://create.roblox.com/docs/players/leaderboards
--]]

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Gameplay.Constants)
local safePlayerAdded = require(ReplicatedStorage.Utility.safePlayerAdded)

local Scoring = {}

local function updateTeamScore(team: Team)
	-- Since the default leaderstats system doesn't have an easy way to check team stats, we'll manually
	-- keep track of team scores with an attribute on each team.
	local score = 0
	local players = team:GetPlayers()
	for _, player in players do
		score += Scoring.getPlayerScore(player)
	end
	team:SetAttribute(Constants.TEAM_SCORE_ATTRIBUTE, score)
end

local function onPlayerAdded(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local score = Instance.new("IntValue")
	score.Name = "Score"
	score.Value = 0
	score.Parent = leaderstats

	-- Each time the player's score changes, update the total score for the team they're on
	score.Changed:Connect(function()
		if player.Team then
			updateTeamScore(player.Team)
		end
	end)
end

local function onPlayerRemoving(player: Player)
	-- When a player leaves, make sure to update their team's score
	if player.Team then
		updateTeamScore(player.Team)
	end
end

function Scoring.resetScores()
	-- Reset individual player scores
	for _, player in Players:GetPlayers() do
		local leaderstats = player:FindFirstChild("leaderstats")
		if not leaderstats then continue end
		local score = leaderstats:FindFirstChild("Score")
		if not score then continue end
		score.Value = 0
	end

	-- Also zero out the team score attributes so the scoreboard resets visually
	for _, team in Teams:GetTeams() do
		team:SetAttribute(Constants.TEAM_SCORE_ATTRIBUTE, 0)
	end
end

function Scoring.incrementScore(player: Player, amount: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end
	local score = leaderstats:FindFirstChild("Score")
	if not score then return end
	score.Value += amount
	if player.Team then
		updateTeamScore(player.Team)
	end
end

function Scoring.getPlayerScore(player: Player): number
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return 0 end
	local score = leaderstats:FindFirstChild("Score")
	if not score then return 0 end
	return score.Value
end

function Scoring.getTeamScore(team: Team): number
	return team:GetAttribute(Constants.TEAM_SCORE_ATTRIBUTE) or 0
end

-- Returns a snapshot of every player's stats for the COMBAT REPORT intermission screen.
-- Payload: array of {name, teamName, teamColor, kills}
function Scoring.getPlayerStats(): { { name: string, teamName: string, teamColor: Color3, kills: number } }
	local stats: { { name: string, teamName: string, teamColor: Color3, kills: number } } = {}
	for _, player in Players:GetPlayers() do
		table.insert(stats, {
			name = player.Name,
			teamName = if player.Team then player.Team.Name else "",
			teamColor = if player.Team then player.Team.TeamColor.Color else Color3.new(1, 1, 1),
			kills = Scoring.getPlayerScore(player),
		})
	end
	return stats
end

safePlayerAdded(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

return Scoring
