local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Blaster.Constants)
local AimAssistController = require(script.Parent.AimAssistController)
local AimAssistEnum = require(script.Parent.AimAssistController.AimAssistEnum)
local TouchInputController = require(script.Parent.TouchInputController)
local CameraRecoiler = require(script.Parent.CameraRecoiler)
local ViewModelController = require(script.Parent.ViewModelController)
local CharacterAnimationController = require(script.Parent.CharacterAnimationController)
local GuiController = require(script.Parent.GuiController)
local disconnectAndClear = require(ReplicatedStorage.Utility.disconnectAndClear)
local getRayDirections = require(script.Parent.Parent.Utility.getRayDirections)
local drawRayResults = require(script.Parent.Parent.Utility.drawRayResults)
local castRays = require(script.Parent.Parent.Utility.castRays)

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local remotes = ReplicatedStorage.Blaster.Remotes
local shootRemote = remotes.Shoot
local reloadRemote = remotes.Reload

local random = Random.new()

local BlasterController = {}
BlasterController.__index = BlasterController

function BlasterController.new(blaster: Tool)
	local aimAssistController = AimAssistController.new()
	local viewModelController = ViewModelController.new(blaster)
	local guiController = GuiController.new(blaster)
	local touchInputController = TouchInputController.new(blaster)
	local characterAnimationController = CharacterAnimationController.new(blaster)

	local hapticsFolder = blaster:FindFirstChild("Haptics")
	local self = {
		blaster = blaster,
		aimAssistController = aimAssistController,
		viewModelController = viewModelController,
		guiController = guiController,
		touchInputController = touchInputController,
		characterAnimationController = characterAnimationController,
		activated = false,
		equipped = false,
		shooting = false,
		ammo = blaster:GetAttribute(Constants.AMMO_ATTRIBUTE),
		reloading = blaster:GetAttribute(Constants.RELOADING_ATTRIBUTE),
		connections = {},
		shootHaptic = hapticsFolder and hapticsFolder:FindFirstChild("ShootHaptic") or nil,
		wantsScope = false,
		isScoped = false,
	}
	setmetatable(self, BlasterController)

	self:initialize()

	return self
end

function BlasterController:isHumanoidAlive(): boolean
	if not self.humanoid then
		return false
	end
	return self.humanoid.Health > 0
end

function BlasterController:canShoot(): boolean
	return self:isHumanoidAlive() and self.equipped and self.ammo > 0 and not self.reloading
end

function BlasterController:canReload(): boolean
	local magazineSize = self.blaster:GetAttribute(Constants.MAGAZINE_SIZE_ATTRIBUTE)
	return self:isHumanoidAlive() and self.equipped and self.ammo < magazineSize and not self.reloading
end

function BlasterController:recoil()
	local recoilMax      = self.blaster:GetAttribute(Constants.RECOIL_MAX_ATTRIBUTE)
	local accelerateTime = self.blaster:GetAttribute(Constants.RECOIL_ACCELERATE_ATTRIBUTE)

	local maxXRad = math.rad(recoilMax.X)
	local maxYRad = math.rad(recoilMax.Y)
	local ySign   = (random:NextNumber() > 0.5) and 1 or -1

	CameraRecoiler.recoil(maxXRad, maxYRad, accelerateTime, ySign)
end

function BlasterController:_scopeIn()
	self.isScoped = true
	self.viewModelController:scopeIn()
	self.guiController:showScope()
	CameraRecoiler.setScopeZoom(Constants.SCOPE_FOV - Constants.RECOIL_DEFAULT_FOV)
end

function BlasterController:_scopeOut()
	self.isScoped = false
	self.viewModelController:scopeOut()
	self.guiController:hideScope()
	CameraRecoiler.setScopeZoom(0)
end

function BlasterController:shoot()
	local spread = self.blaster:GetAttribute(Constants.SPREAD_ATTRIBUTE)
	local raysPerShot = self.blaster:GetAttribute(Constants.RAYS_PER_SHOT_ATTRIBUTE)
	local range = self.blaster:GetAttribute(Constants.RANGE_ATTRIBUTE)
	local rayRadius = self.blaster:GetAttribute(Constants.RAY_RADIUS_ATTRIBUTE)

	self.viewModelController:playShootAnimation()
	self.characterAnimationController:playShootAnimation()
	self:recoil()

	self.ammo -= 1

	self.guiController:setAmmo(self.ammo)

	local now = Workspace:GetServerTimeNow()
	local origin = camera.CFrame

	local rayDirections = getRayDirections(origin, raysPerShot, math.rad(spread), now)
	for index, direction in rayDirections do
		rayDirections[index] = direction * range
	end

	local rayResults = castRays(player, origin.Position, rayDirections, rayRadius)

	-- Rather than passing the entire table of rayResults to the server, we'll pass the shot origin and a list of tagged humanoids.
	-- The server will then recalculate the ray directions from the origin and validate the tagged humanoids.
	-- Strings are used for the indices since non-contiguous arrays do not get passed over the network correctly.
	-- (This may be non-contiguous in the case of firing a shotgun, where not all of the rays hit a target)
	local tagged = {}
	local didTag = false
	for index, rayResult in rayResults do
		if rayResult.taggedHumanoid then
			tagged[tostring(index)] = rayResult.taggedHumanoid
			didTag = true
		end
	end

	if didTag then
		self.guiController:showHitmarker()
	end

	shootRemote:FireServer(now, self.blaster, origin, tagged)

	local muzzlePosition = self.viewModelController:getMuzzlePosition()
	drawRayResults(muzzlePosition, rayResults)

	-- fire haptic
	if self.shootHaptic then
		self.shootHaptic:Play()
	end

	-- Brief unscope on shoot, then auto-rescope after delay
	if self.isScoped then
		self:_scopeOut()
		task.delay(Constants.SCOPE_UNSCOPE_DELAY, function()
			if self.wantsScope then
				self:_scopeIn()
			end
		end)
	end
end

function BlasterController:startShooting()
	-- If the player tries to shoot without any ammo, reload instead
	if self.ammo == 0 then
		self:reload()
		return
	end

	if not self:canShoot() then
		return
	end

	if self.shooting then
		return
	end

	local fireMode = self.blaster:GetAttribute(Constants.FIRE_MODE_ATTRIBUTE)
	local rateOfFire = self.blaster:GetAttribute(Constants.RATE_OF_FIRE_ATTRIBUTE)

	if fireMode == Constants.FIRE_MODE.SEMI then
		self.shooting = true
		self:shoot()
		task.delay(60 / rateOfFire, function()
			self.shooting = false

			if self.ammo == 0 then
				self:reload()
			end
		end)
	elseif fireMode == Constants.FIRE_MODE.AUTO then
		task.spawn(function()
			self.shooting = true
			while self.activated and self:canShoot() do
				self:shoot()
				task.wait(60 / rateOfFire)
			end
			self.shooting = false

			if self.ammo == 0 then
				self:reload()
			end
		end)
	end
end

function BlasterController:reload()
	if not self:canReload() then
		return
	end

	local reloadTime = self.blaster:GetAttribute(Constants.RELOAD_TIME_ATTRIBUTE)
	local magazineSize = self.blaster:GetAttribute(Constants.MAGAZINE_SIZE_ATTRIBUTE)

	self.viewModelController:playReloadAnimation(reloadTime)
	self.characterAnimationController:playReloadAnimation(reloadTime)

	-- Optimistically set reloading state for responsive UI feedback
	self.reloading = true
	self.guiController:setReloading(self.reloading)

	-- InvokeServer waits for the server to confirm whether the reload was accepted.
	-- The server validates the request, sets RELOADING_ATTRIBUTE, and returns true/false.
	local success = reloadRemote:InvokeServer(self.blaster)
	if not success then
		-- Server rejected the reload — roll back optimistic state
		warn("[BlasterController] Reload failed on server")
		self.reloading = false
		self.guiController:setReloading(self.reloading)
		return
	end

	-- Server accepted: schedule client-side ammo/state update after reload completes
	self.reloadTask = task.delay(reloadTime, function()
		self.ammo = magazineSize
		self.reloading = false
		self.reloadTask = nil
		self.guiController:setAmmo(self.ammo)
		self.guiController:setReloading(self.reloading)
	end)
end

function BlasterController:activate()
	if self.activated then
		return
	end
	self.activated = true

	self:startShooting()
end

function BlasterController:deactivate()
	if not self.activated then
		return
	end
	self.activated = false
end

function BlasterController:equip()
	if self.equipped then
		return
	end
	self.equipped = true

	-- Resync ammo and reloading values
	self.ammo = self.blaster:GetAttribute(Constants.AMMO_ATTRIBUTE)
	self.reloading = self.blaster:GetAttribute(Constants.RELOADING_ATTRIBUTE)

	-- Apply per-gun recoil recovery speed
	local recovery = self.blaster:GetAttribute(Constants.RECOIL_RECOVERY_ATTRIBUTE)
	if recovery then
		CameraRecoiler.setRecoverySpeed(recovery)
	end

	-- Resync aim assist values
	self.range = self.blaster:GetAttribute(Constants.AIM_ASSIST_RANGE_ATTRIBUTE)
	self.fov = self.blaster:GetAttribute(Constants.AIM_ASSIST_FOV_ATTRIBUTE)
	self.friction = self.blaster:GetAttribute(Constants.AIM_ASSIST_FRICTION_STRENGTH_ATTRIBUTE)
	self.tracking = self.blaster:GetAttribute(Constants.AIM_ASSIST_TRACKING_STRENGTH_ATTRIBUTE)
	self.centering = self.blaster:GetAttribute(Constants.AIM_ASSIST_TRACKING_STRENGTH_ATTRIBUTE)

	-- Set up the Aim Assist Controller
	self.aimAssistController:setSubject(Workspace.CurrentCamera)
	self.aimAssistController:setRange(self.range)
	self.aimAssistController:setFieldOfView(self.fov)
	self.aimAssistController:addTargetTag(Constants.AIM_ASSIST_TARGET_TAG)
	self.aimAssistController:addPlayerTargets(true, true)
	self.aimAssistController:setMethodStrength(AimAssistEnum.AimAssistMethod.Friction, self.friction)
	self.aimAssistController:setMethodStrength(AimAssistEnum.AimAssistMethod.Tracking, self.tracking)
	self.aimAssistController:setMethodStrength(AimAssistEnum.AimAssistMethod.Centering, self.centering)
	self.aimAssistController:setEasingFunc(
		AimAssistEnum.AimAssistEasingAttribute.Distance,
		function(distance: number): number
			if distance < Constants.AIM_ASSIST_MIN_RANGE then
				return 0
			else
				return 1
			end
		end
	)
	self.aimAssistController:setDebug(false)

	-- Enable Aim Assist
	self.aimAssistController:enable()

	-- Enable GUI
	self.guiController:setAmmo(self.ammo)
	self.guiController:setReloading(self.reloading)
	self.guiController:enable()

	-- Enable touch input controller
	self.touchInputController:enable()

	-- Keep track of the humanoid in the character currently equipping the blaster.
	-- We need this to make sure the player can't shoot while dead.
	-- FindFirstChildOfClass is instant (no yield). If it returns nil the character is
	-- still being assembled (e.g. streaming in), so fall back to WaitForChild with a
	-- 10-second timeout. If neither finds it in time, warn and bail out gracefully
	-- rather than letting the coroutine hang indefinitely.
	local character = self.blaster.Parent
	local humanoid = character:FindFirstChildOfClass("Humanoid")
		or character:WaitForChild("Humanoid", 10)
	if not humanoid then
		warn("[BlasterController] Humanoid not found in character '"
			.. tostring(character.Name) .. "' — equip aborted.")
		self.equipped = false
		return
	end
	self.humanoid = humanoid

	-- Enable view model (humanoid must be confirmed before enabling animations)
	self.viewModelController:enable()

	-- Enable character animations (requires humanoid to be set)
	self.characterAnimationController:enable()
end

function BlasterController:unequip()
	if not self.equipped then
		return
	end
	self.equipped = false

	-- Force deactivate the blaster when unequipping it
	self:deactivate()

	-- Unscope when unequipping
	if self.wantsScope then
		self.wantsScope = false
		self:_scopeOut()
	end

	-- If the blaster is being reloaded, stop it
	if self.reloadTask then
		task.cancel(self.reloadTask)
		self.reloadTask = nil
	end

	-- Disable Aim Assist debug UI
	self.aimAssistController:setDebug(false)
	-- Disable Aim Assist
	self.aimAssistController:disable()

	-- Disable view model
	self.viewModelController:disable()

	-- Disable GUI
	self.guiController:disable()

	-- Disable touch input controller
	self.touchInputController:disable()

	-- Disable character animations
	self.characterAnimationController:disable()
end

function BlasterController:initialize()
	table.insert(
		self.connections,
		self.blaster.Equipped:Connect(function()
			self:equip()
		end)
	)
	table.insert(
		self.connections,
		self.blaster.Unequipped:Connect(function()
			self:unequip()
		end)
	)
	table.insert(
		self.connections,
		self.blaster.Activated:Connect(function()
			self:activate()
		end)
	)
	table.insert(
		self.connections,
		self.blaster.Deactivated:Connect(function()
			self:deactivate()
		end)
	)
	table.insert(
		self.connections,
		UserInputService.InputBegan:Connect(function(inputObject: InputObject, processed: boolean)
			if processed then
				return
			end

			if
				inputObject.KeyCode == Constants.KEYBOARD_RELOAD_KEY_CODE
				or inputObject.KeyCode == Constants.GAMEPAD_RELOAD_KEY_CODE
			then
				self:reload()
			end

			if
				inputObject.UserInputType == Enum.UserInputType.MouseButton2
				and self.equipped
				and self.blaster:GetAttribute(Constants.SCOPEABLE_ATTRIBUTE)
			then
				self.wantsScope = not self.wantsScope
				if self.wantsScope then
					self:_scopeIn()
				else
					self:_scopeOut()
				end
			end
		end)
	)

	table.insert(
		self.connections,
		UserInputService.InputChanged:Connect(function(inputObject: InputObject, _)
			if
				inputObject.UserInputType == Enum.UserInputType.Gamepad1
				and (inputObject.KeyCode == Enum.KeyCode.Thumbstick1 or inputObject.KeyCode == Enum.KeyCode.Thumbstick2)
			then
				self.aimAssistController:updateGamepadEligibility(inputObject.KeyCode, inputObject.Position)
			end
		end)
	)

	table.insert(
		self.connections,
		UserInputService.TouchPan:Connect(function()
			self.aimAssistController:updateTouchEligibility()
		end)
	)

	self.touchInputController:setReloadCallback(function()
		self:reload()
	end)
end

function BlasterController:destroy()
	self:unequip()
	disconnectAndClear(self.connections)
	self.aimAssistController:destroy()
	self.viewModelController:destroy()
	self.touchInputController:destroy()
	self.characterAnimationController:destroy()
	self.guiController:destroy()
end

return BlasterController
