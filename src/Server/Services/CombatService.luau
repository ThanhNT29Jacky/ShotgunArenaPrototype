local Knit = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Knit"))
local Players = game:GetService("Players")
local WeaponConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("WeaponConfig"))

local CombatService = Knit.CreateService {
	Name = "CombatService",
	Client = {
		ShootRequest = Knit.CreateSignal(),
		TakeDamage = Knit.CreateSignal(),
	},
}

function CombatService:KnitInit()
	-- Listen for ShootRequest from clients
	self.Client.ShootRequest:Connect(function(player: Player, data: any)
		self:_handleShootRequest(player, data)
	end)
end

function CombatService:KnitStart()
	-- Start service
end

function CombatService:_handleShootRequest(player: Player, data: any)
	-- Validate player is alive
	if not player.Character or not player.Character:FindFirstChild("Humanoid") then
		warn("CombatService: ShootRequest from dead/invalid player", player.Name)
		return
	end

	local shooter: Model = player.Character
	local shooterHRP: Part? = shooter:FindFirstChild("HumanoidRootPart")

	if not shooterHRP then
		warn("CombatService: ShootRequest from player without HRP", player.Name)
		return
	end

	-- Validate pellet data
	if not data or not data.pellets then
		warn("CombatService: ShootRequest with invalid data structure")
		return
	end

	local pellets: { any } = data.pellets

	if #pellets > WeaponConfig.PELLET_COUNT then
		warn("CombatService: ShootRequest with too many pellets", #pellets, ">", WeaponConfig.PELLET_COUNT)
		return
	end

	-- Validate pellet origins (anti-cheat: origin within 10 studs of shooter)
	for _, pellet in pairs(pellets) do
		if not pellet.origin or not pellet.direction then
			warn("CombatService: Pellet missing origin or direction")
			return
		end

		local distance: number = (pellet.origin - shooterHRP.Position).Magnitude
		if distance > 10 then
			warn("CombatService: Pellet origin too far from shooter", distance, "> 10")
			return
		end
	end

	-- Process raycasts
	local raycastParams: RaycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { shooter }
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	for _, pellet in pairs(pellets) do
		local origin: Vector3 = pellet.origin
		local direction: Vector3 = pellet.direction

		-- Raycast to find hit
		local result: RaycastResult? = workspace:Raycast(origin, direction * WeaponConfig.MAX_RANGE, raycastParams)

		if result then
			-- Find humanoid in hit part or parent
			local hitInstance: Instance = result.Instance
			local humanoid: Humanoid? = nil

			-- Try hit part first
			if hitInstance:IsA("BasePart") then
				humanoid = hitInstance.Parent:FindFirstChild("Humanoid")
				if not humanoid then
					humanoid = hitInstance.Parent.Parent:FindFirstChild("Humanoid")
				end
			end

			-- Apply damage if humanoid found and alive
			if humanoid and humanoid.Health > 0 then
				humanoid:TakeDamage(WeaponConfig.DAMAGE_PER_PELLET)

				-- Fire TakeDamage signal to victim
				local victimPlayer: Player? = Players:GetPlayerFromCharacter(humanoid.Parent)
				if victimPlayer then
					self.Client.TakeDamage:Fire(victimPlayer, victimPlayer)
				end
			end
		end
	end
end

return CombatService
