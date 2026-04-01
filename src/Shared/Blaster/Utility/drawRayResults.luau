local castRays = require(script.Parent.castRays)
local laserBeamEffect = require(script.Parent.Parent.Effects.laserBeamEffect)
local impactEffect = require(script.Parent.Parent.Effects.impactEffect)

local function drawRayResults(position: Vector3, rayResults: { castRays.RayResult })
	for _, rayResult in rayResults do
		laserBeamEffect(position, rayResult.position)

		if rayResult.instance then
			impactEffect(rayResult.position, rayResult.normal, rayResult.taggedHumanoid ~= nil)
		end
	end
end

return drawRayResults
