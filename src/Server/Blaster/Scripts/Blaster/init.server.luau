local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Blaster.Constants)
local validateInstance = require(ServerScriptService.Utility.TypeValidation.validateInstance)
local validateShootArguments = require(script.validateShootArguments)
local validateShot = require(script.validateShot)
local validateTag = require(script.validateTag)
local validateReload = require(script.validateReload)
local getRayDirections = require(ReplicatedStorage.Blaster.Utility.getRayDirections)
local castRays = require(ReplicatedStorage.Blaster.Utility.castRays)

local remotes = ReplicatedStorage.Blaster.Remotes
local shootRemote = remotes.Shoot
local reloadRemote = remotes.Reload
local replicateShotRemote = remotes.ReplicateShot

local events = ServerScriptService.Blaster.Events
local taggedEvent = events.Tagged
local eliminatedEvent = events.Eliminated

local function onShootEvent(
	player: Player,
	timestamp: number,
	blaster: Tool,
	origin: CFrame,
	tagged: { [string]: Humanoid }
)
	-- Validate the received arguments
	if not validateShootArguments(timestamp, blaster, origin, tagged) then
		return
	end

	-- Validate that the player can make this shot
	if not validateShot(player, timestamp, blaster, origin) then
		return
	end

	local spread = blaster:GetAttribute(Constants.SPREAD_ATTRIBUTE)
	local raysPerShot = blaster:GetAttribute(Constants.RAYS_PER_SHOT_ATTRIBUTE)
	local range = blaster:GetAttribute(Constants.RANGE_ATTRIBUTE)
	local rayRadius = blaster:GetAttribute(Constants.RAY_RADIUS_ATTRIBUTE)
	local damage = blaster:GetAttribute(Constants.DAMAGE_ATTRIBUTE)

	-- Subtract ammo
	local ammo = blaster:GetAttribute(Constants.AMMO_ATTRIBUTE)
	blaster:SetAttribute(Constants.AMMO_ATTRIBUTE, ammo - 1)

	-- The timestamp that was passed by the client also serves as the seed for the blaster's random spread.
	-- This allows us to recalculate the spread accurately on the server relative to the look direction, rather than simply
	-- accepting a direction or directions from the client.
	local spreadAngle = math.rad(spread)
	local rayDirections = getRayDirections(origin, raysPerShot, spreadAngle, timestamp)
	for index, direction in rayDirections do
		rayDirections[index] = direction * range
	end
	-- Raycast against static geometry only
	local rayResults = castRays(player, origin.Position, rayDirections, rayRadius, true)

	-- Validate hits
	for indexString, taggedHumanoid in tagged do
		-- The tagged table contains a client-reported list of the humanoids hit by each of the rays that was fired.
		-- Strings are used for the indices since non-contiguous arrays do not get passed over the network correctly.
		-- (This may be non-contiguous in the case of firing a shotgun, where not all of the rays hit a target)
		-- For each humanoid that the client reports it tagged, we'll validate against the ray that was recast on the server.
		local index = tonumber(indexString)
		if not index then
			continue
		end
		local rayResult = rayResults[index]
		if not rayResults[index] then
			continue
		end
		local rayDirection = rayDirections[index]
		if not rayDirection then
			continue
		end

		-- Validate that the player is able to tag this humanoid based on the server raycast
		if not validateTag(player, taggedHumanoid, origin.Position, rayDirection, rayResult) then
			continue
		end

		rayResult.taggedHumanoid = taggedHumanoid

		-- Align the rayResult position to the tagged humanoid. This is necessary so that when we replicate
		-- this shot to the other clients they don't see lasers going through characters they should be hitting.
		local model = taggedHumanoid:FindFirstAncestorOfClass("Model")
		if model then
			local modelPosition = model:GetPivot().Position
			local distance = (modelPosition - origin.Position).Magnitude
			rayResult.position = origin.Position + rayDirection.Unit * distance
		end

		if taggedHumanoid.Health <= 0 then
			continue
		end

		-- Apply damage and fire any relevant events
		taggedHumanoid:TakeDamage(damage)
		taggedEvent:Fire(player, taggedHumanoid, damage)

		if taggedHumanoid.Health <= 0 then
			eliminatedEvent:Fire(player, taggedHumanoid, damage)
		end
	end

	-- Apply physics impulse
	-- This is the most straightforward way to do this, although there will be some latency since the impulse is being applied on the server
	local force = blaster:GetAttribute(Constants.UNANCHORED_IMPULSE_FORCE_ATTRIBUTE)
	if force ~= 0 then
		for index, rayResult in rayResults do
			-- We don't want to apply impulses to characters, so we'll skip if we tagged a humanoid
			if rayResult.taggedHumanoid then
				continue
			end

			if rayResult.instance and rayResult.instance:IsA("BasePart") and not rayResult.instance.Anchored then
				local direction = rayDirections[index]
				local impulse = direction * force
				rayResult.instance:ApplyImpulseAtPosition(impulse, rayResult.position)
			end
		end
	end

	-- Replicate shot to other players
	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer == player then
			continue
		end

		replicateShotRemote:FireClient(otherPlayer, blaster, origin.Position, rayResults)
	end
end

local function onReloadInvoke(player: Player, blaster: Tool): boolean
	-- Validate the received argument
	if not validateInstance(blaster, "Tool") then
		return false
	end

	-- Make sure the player is able to reload this blaster
	if not validateReload(player, blaster) then
		return false
	end

	local reloadTime = blaster:GetAttribute(Constants.RELOAD_TIME_ATTRIBUTE)
	local magazineSize = blaster:GetAttribute(Constants.MAGAZINE_SIZE_ATTRIBUTE)

	local character = player.Character
	blaster:SetAttribute(Constants.RELOADING_ATTRIBUTE, true)

	local reloadTask
	local ancestryChangedConnection
	local reloadActive = true

	reloadTask = task.delay(reloadTime, function()
		if not reloadActive then
			return
		end
		reloadActive = false
		blaster:SetAttribute(Constants.AMMO_ATTRIBUTE, magazineSize)
		blaster:SetAttribute(Constants.RELOADING_ATTRIBUTE, false)
		ancestryChangedConnection:Disconnect()
	end)

	ancestryChangedConnection = blaster.AncestryChanged:Connect(function()
		if blaster.Parent ~= character then
			if not reloadActive then
				return
			end
			reloadActive = false
			blaster:SetAttribute(Constants.RELOADING_ATTRIBUTE, false)

			task.cancel(reloadTask)
			ancestryChangedConnection:Disconnect()
		end
	end)

	return true
end

local function initialize()
	shootRemote.OnServerEvent:Connect(onShootEvent)
	reloadRemote.OnServerInvoke = onReloadInvoke
end

initialize()
