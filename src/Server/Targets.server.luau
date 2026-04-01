local CollectionService = game:GetService("CollectionService")

local TARGET_TAG = "Target"
local RESPAWN_TIME = 3

local function onTargetAdded(target: Instance)
	-- Non-player targets should still have a humanoid in them so they can take damage
	local humanoid: Humanoid? = target:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn(`[Targets] {target:GetFullName()} is missing a Humanoid — skipping target setup`)
		return
	end

	local respawning = false
	humanoid.HealthChanged:Connect(function(health: number)
		if respawning then
			return
		end

		if health <= 0 then
			respawning = true
			task.wait(RESPAWN_TIME)
			humanoid.Health = humanoid.MaxHealth
			respawning = false
		end
	end)
end

local function initialize()
	CollectionService:GetInstanceAddedSignal(TARGET_TAG):Connect(onTargetAdded)

	for _, target in CollectionService:GetTagged(TARGET_TAG) do
		task.spawn(onTargetAdded, target)
	end
end

initialize()
