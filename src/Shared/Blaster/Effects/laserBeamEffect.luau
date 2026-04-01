local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Blaster.Constants)

local laserBeamTemplate = ReplicatedStorage.Blaster.Objects.LaserBeam

local function laserBeamEffect(startPosition: Vector3, endPosition: Vector3)
	local distance = (startPosition - endPosition).Magnitude
	local tweenTime = distance / Constants.LASER_BEAM_VISUAL_SPEED
	local tweenInfo = TweenInfo.new(tweenTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

	local laser = laserBeamTemplate:Clone()
	laser.CFrame = CFrame.lookAt(startPosition, endPosition)
	laser.StartAttachment.Position = Vector3.zero
	laser.EndAttachment.Position = Vector3.new(0, 0, -distance)
	laser.Parent = Workspace

	local tween = TweenService:Create(laser.StartAttachment, tweenInfo, { Position = laser.EndAttachment.Position })
	tween:Play()
	tween.Completed:Once(function()
		laser:Destroy()
	end)
end

return laserBeamEffect
