local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Gameplay.Constants)

local player = Players.LocalPlayer
local playerGui = player.PlayerGui
local gui = playerGui:WaitForChild("GameplayGui")

function updateScale()
	-- Update UI size. This is the same logic used by the default touch controls
	local minScreenSize = math.min(gui.AbsoluteSize.X, gui.AbsoluteSize.Y)
	local isSmallScreen = minScreenSize < Constants.UI_SMALL_SCREEN_THRESHOLD
	gui.UIScale.Scale = if isSmallScreen then Constants.UI_SMALL_SCREEN_SCALE else 1
end

gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateScale)
updateScale()
