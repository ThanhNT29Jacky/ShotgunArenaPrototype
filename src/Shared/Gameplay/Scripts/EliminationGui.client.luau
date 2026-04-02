local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player.PlayerGui
local gui = playerGui:WaitForChild("GameplayGui", 10)
if not gui then
	warn("[EliminationGui] GameplayGui not found within 10s — aborting")
	return
end
local eliminationLabelTemplate = script.EliminationLabel
local eliminatedPlayer = SoundService.Audio.Players.UI.EliminatedPlayer

local remotes = ReplicatedStorage.Gameplay.Remotes
local eliminatedRemote = remotes.Eliminated

local ELIMINATION_TEXT_FORMAT_STRING = `Eliminated <font color="rgb(255,62,65)">%s</font>`
local ELIMINATION_SCALE_TWEEN_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local ELIMINATION_TRANSPARENCY_TWEEN_INFO = TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local function onEliminated(eliminated: string)
	-- Play the elimination sound
	eliminatedPlayer:Play()

	-- Shift the layout order of all existing labels by 1 so the new label we create appears at the top
	for _, v in gui.Eliminations:GetChildren() do
		if v:IsA("GuiObject") then
			v.LayoutOrder += 1
		end
	end

	-- Create a new label and animate its size and transparency
	local eliminationLabel = eliminationLabelTemplate:Clone()
	eliminationLabel.Text = string.format(ELIMINATION_TEXT_FORMAT_STRING, eliminated)
	eliminationLabel.UIScale.Scale = 2
	eliminationLabel.Parent = gui.Eliminations

	local scaleTween = TweenService:Create(eliminationLabel.UIScale, ELIMINATION_SCALE_TWEEN_INFO, { Scale = 1 })
	scaleTween:Play()

	local transparencyTween = TweenService:Create(
		eliminationLabel,
		ELIMINATION_TRANSPARENCY_TWEEN_INFO,
		{ BackgroundTransparency = 1, TextTransparency = 1 }
	)
	transparencyTween:Play()
	-- Destroy the label once the tween is completed
	transparencyTween.Completed:Once(function()
		eliminationLabel:Destroy()
	end)
end

eliminatedRemote.OnClientEvent:Connect(onEliminated)
