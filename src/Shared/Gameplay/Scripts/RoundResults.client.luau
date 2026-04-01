local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage.Gameplay.Constants)

local player = Players.LocalPlayer
local playerGui = player.PlayerGui
local roundResultsGuiTemplate = script.RoundResultsGui
local victoryPlayer = SoundService.Audio.Players.UI.VictoryPlayer
local defeatPlayer = SoundService.Audio.Players.UI.DefeatPlayer

local remotes = ReplicatedStorage.Gameplay.Remotes
local roundWinnerRemote = remotes.RoundWinner

local VICTORY_TEXT = "Victory!"
local DEFEAT_TEXT = "Defeat..."
local WINNER_TEXT_FORMAT_STRING = "%s wins"

local BACKGROUND_TWEEN_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TEXT_TWEEN_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)

local function onRoundWinner(winner: Team)
	-- If our team won, we'll display Victory! Otherwise display Defeat...
	local isVictory = player.Team == winner

	if isVictory then
		victoryPlayer:Play()
	else
		defeatPlayer:Play()
	end

	local gui = roundResultsGuiTemplate:Clone()
	gui.Background.BackgroundTransparency = 1
	gui.UIScale.Scale = 2
	gui.VictoryDefeatLabel.TextTransparency = 1
	gui.VictoryDefeatLabel.Text = if isVictory then VICTORY_TEXT else DEFEAT_TEXT
	gui.WinnerLabel.TextTransparency = 1
	gui.WinnerLabel.Text = string.format(WINNER_TEXT_FORMAT_STRING, winner.Name)
	gui.WinnerLabel.TextColor3 = winner.TeamColor.Color
	gui.Parent = playerGui

	local backgroundTween = TweenService:Create(gui.Background, BACKGROUND_TWEEN_INFO, { BackgroundTransparency = 0.5 })
	backgroundTween:Play()

	local scaleTween = TweenService:Create(gui.UIScale, TEXT_TWEEN_INFO, { Scale = 1 })
	local textTweenA = TweenService:Create(gui.VictoryDefeatLabel, TEXT_TWEEN_INFO, { TextTransparency = 0 })
	local textTweenB = TweenService:Create(gui.WinnerLabel, TEXT_TWEEN_INFO, { TextTransparency = 0 })

	scaleTween:Play()
	textTweenA:Play()
	textTweenB:Play()

	task.delay(Constants.INTERMISSION_TIME, function()
		gui:Destroy()
	end)
end

roundWinnerRemote.OnClientEvent:Connect(onRoundWinner)
