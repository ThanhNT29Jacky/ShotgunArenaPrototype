local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Blaster.Constants)
local canPlayerDamageHumanoid = require(ReplicatedStorage.Blaster.Utility.canPlayerDamageHumanoid)

export type RayResult = {
	taggedHumanoid: Humanoid?,
	position: Vector3,
	normal: Vector3,
	instance: Instance?,
}

local function castRays(
	player: Player,
	position: Vector3,
	directions: { Vector3 },
	radius: number,
	staticOnly: boolean?
): { RayResult }
	local exclude = CollectionService:GetTagged(Constants.RAY_EXCLUDE_TAG)

	if staticOnly then
		local nonStatic = CollectionService:GetTagged(Constants.NON_STATIC_TAG)
		-- Append nonStatic to exclude
		table.move(nonStatic, 1, #nonStatic, #exclude + 1, exclude)
	end

	-- Always include the player's character in the exclude list
	if player.Character then
		table.insert(exclude, player.Character)
	end

	local collisionGroup = nil

	-- If the player is on a team, use that team's collision group to ensure the ray passes through
	-- characters and forcefields on that team.
	if player.Team and not player.Neutral then
		collisionGroup = player.Team.Name
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	params.FilterDescendantsInstances = exclude
	if collisionGroup then
		params.CollisionGroup = collisionGroup
	end

	local MAX_SPHERECAST_DISTANCE = 1024

	local rayResults = {}

	for _, direction in directions do
		-- Spherecast has a hard engine limit of 1024 studs; clamp to avoid errors.
		local clampedDirection = if direction.Magnitude > MAX_SPHERECAST_DISTANCE
			then direction.Unit * MAX_SPHERECAST_DISTANCE
			else direction
		-- In order to provide a simple form of bullet magnetism, we use spherecasts with a small radius instead of raycasts.
		-- This allows closely grazing shots to register as hits, making blasters feel a bit more accurate and improving the 'game feel'.
		local raycastResult = Workspace:Spherecast(position, radius, clampedDirection, params)
		local rayResult: RayResult = {
			position = position + clampedDirection,
			normal = clampedDirection.Unit,
		}

		if raycastResult then
			rayResult.position = raycastResult.Position
			rayResult.normal = raycastResult.Normal
			rayResult.instance = raycastResult.Instance

			local humanoid = raycastResult.Instance and raycastResult.Instance.Parent and raycastResult.Instance.Parent:FindFirstChildOfClass("Humanoid")
			if humanoid and canPlayerDamageHumanoid(player, humanoid) then
				rayResult.taggedHumanoid = humanoid
			end
		end

		table.insert(rayResults, rayResult)
	end

	return rayResults
end

return castRays
