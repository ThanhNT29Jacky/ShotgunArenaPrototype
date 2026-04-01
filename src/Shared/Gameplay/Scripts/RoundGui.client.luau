local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Gameplay.Constants)

local player = Players.LocalPlayer
local playerGui = player.PlayerGui
local gui = playerGui:WaitForChild("GameplayGui")
local teamScoreLabelTemplate = script.TeamScoreLabel

local teamScoreLabels = {}

local function updateTimerLabel()
	local timer = Workspace:GetAttribute(Constants.TIMER_ATTRIBUTE) or 0
	local minutes = math.floor(timer / 60)
	local seconds = timer % 60
	local timerText = string.format("%02d:%02d", minutes, seconds)

	gui.Round.TimerLabel.Text = timerText
end

local function updateTeamScoreLabel(team: Team)
	local scoreLabel = teamScoreLabels[team]
	if not scoreLabel then
		return
	end

	local score = team:GetAttribute(Constants.TEAM_SCORE_ATTRIBUTE) or 0
	scoreLabel.Text = tostring(score)
	-- Set layout order to -score so that team scores are layed out highest to lowest from left to right
	scoreLabel.LayoutOrder = -score
end

local function onTeamAdded(team: Team)
	-- Create a label for each team to display their score
	local scoreLabel = teamScoreLabelTemplate:Clone()
	scoreLabel.BackgroundColor3 = team.TeamColor.Color
	scoreLabel.UIStroke.Enabled = team == player.Team
	scoreLabel.Parent = gui.Round.Scores

	teamScoreLabels[team] = scoreLabel

	team:GetAttributeChangedSignal(Constants.TEAM_SCORE_ATTRIBUTE):Connect(function()
		updateTeamScoreLabel(team)
	end)

	updateTeamScoreLabel(team)
end

local function onTeamRemoved(team: Team)
	if teamScoreLabels[team] then
		teamScoreLabels[team]:Destroy()
		teamScoreLabels[team] = nil
	end
end

local function onTeamChanged()
	-- Update the outline around the team score labels to match the player's current team
	for team, scoreLabel in teamScoreLabels do
		scoreLabel.UIStroke.Enabled = team == player.Team
	end
end

local function initialize()
	Teams.ChildAdded:Connect(onTeamAdded)
	Teams.ChildRemoved:Connect(onTeamRemoved)
	Workspace:GetAttributeChangedSignal(Constants.TIMER_ATTRIBUTE):Connect(updateTimerLabel)
	player:GetPropertyChangedSignal("Team"):Connect(onTeamChanged)

	for _, team in Teams:GetChildren() do
		onTeamAdded(team)
	end

	updateTimerLabel()
end

initialize()
