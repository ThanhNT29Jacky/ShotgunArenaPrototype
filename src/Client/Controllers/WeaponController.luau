local Knit = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Knit"))
local WeaponConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("WeaponConfig"))

local WeaponController = Knit.CreateController {
	Name = "WeaponController",
}

local combatService: any
local cameraController: any
local ammo: number = WeaponConfig.MAX_AMMO
local lastFireTime: number = 0
local isReloading: boolean = false

function WeaponController:KnitInit()
	combatService = Knit.GetService("CombatService")
	cameraController = Knit.GetController("CameraController")
end

function WeaponController:KnitStart()
	local UserInputService = game:GetService("UserInputService")

	-- Handle shoot input (Mouse Button 1)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:_onShoot()
		elseif input.KeyCode == Enum.KeyCode.R then
			self:_onReload()
		end
	end)
end

function WeaponController:_onShoot(): ()
	local currentTime: number = tick()

	-- Check fire rate
	if currentTime - lastFireTime < WeaponConfig.FIRE_RATE then
		return
	end

	-- Check ammo
	if ammo <= 0 then
		return
	end

	-- Generate pellets with spread
	local lookCFrame: CFrame = cameraController:GetLookCFrame()
	local pellets: { any } = {}

	for i = 1, WeaponConfig.PELLET_COUNT do
		local pelletData = self:_getSpreadDirection(lookCFrame)
		table.insert(pellets, pelletData)
	end

	-- Fire remote to server
	combatService.Client.ShootRequest:Fire({
		pellets = pellets,
	})

	-- Apply recoil
	cameraController:AddRecoil(5, 0)

	-- Update ammo and fire time
	ammo = ammo - 1
	lastFireTime = currentTime
end

function WeaponController:_onReload(): ()
	if isReloading then
		return
	end

	isReloading = true
	task.wait(WeaponConfig.RELOAD_TIME)
	ammo = WeaponConfig.MAX_AMMO
	isReloading = false
end

function WeaponController:_getSpreadDirection(baseCFrame: CFrame): { origin: Vector3, direction: Vector3 }
	local theta: number = math.random() * math.pi * 2
	local phi: number = math.random() * math.rad(WeaponConfig.SPREAD_ANGLE)

	local spreadCFrame: CFrame = baseCFrame * CFrame.Angles(phi, 0, 0) * CFrame.Angles(0, theta, 0)

	return {
		origin = baseCFrame.Position,
		direction = spreadCFrame.LookVector,
	}
end

function WeaponController:GetAmmo(): number
	return ammo
end

return WeaponController
