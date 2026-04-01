--!nocheck
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local drawRayResults = require(script.Parent.Parent.Utility.drawRayResults)
local castRays = require(script.Parent.Parent.Utility.castRays)
local playRandomSoundFromSource = require(script.Parent.Parent.Utility.playRandomSoundFromSource)

local remotes = ReplicatedStorage.Blaster.Remotes
local replicateShotRemote = remotes.ReplicateShot

local function onReplicateShotEvent(blaster: Tool, position: Vector3, rayResults: { castRays.RayResult })
	-- Make sure that the blaster is currently streamed in
	if blaster and blaster:IsDescendantOf(game) then
		local handle = blaster.Handle
		local sounds = blaster.Sounds
		local emitter = handle.AudioEmitter
		local muzzle = blaster:FindFirstChild("MuzzleAttachment", true)

		-- If the blaster has a MuzzleAttachment, we'll use that as the laser starting point, otherwise
		-- default to the blaster's pivot position.
		if muzzle then
			position = muzzle.WorldPosition

			-- Play VFX
			muzzle.FlashEmitter:Emit(1)
		else
			position = blaster:GetPivot().Position
		end

		-- Play SFX
		playRandomSoundFromSource(sounds.Shoot, emitter)
	end

	drawRayResults(position, rayResults)
end

replicateShotRemote.OnClientEvent:Connect(onReplicateShotEvent)
