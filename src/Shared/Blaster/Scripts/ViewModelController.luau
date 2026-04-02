--!nocheck
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Blaster.Constants)
local disconnectAndClear = require(ReplicatedStorage.Utility.disconnectAndClear)
local lerp = require(ReplicatedStorage.Utility.lerp)
local bindSoundsToAnimationEvents = require(script.Parent.Parent.Utility.bindSoundsToAnimationEvents)

local camera = Workspace.CurrentCamera
local viewModels = ReplicatedStorage.Blaster.ViewModels
local audioTarget = SoundService.Audio.Busses.World.AudioCompressor

local ViewModelController = {}
ViewModelController.__index = ViewModelController

function ViewModelController.new(blaster: Tool)
	-- Despite the blaster streaming mode being set to Atomic, objects outside of workspace are not streamed.
	-- This means we need to WaitForChild, since the blaster will be parented to the player's Backpack initially.
	local handle = blaster:WaitForChild("Handle")
	local sounds = blaster:WaitForChild("Sounds")

	local viewModelName = blaster:GetAttribute(Constants.VIEW_MODEL_ATTRIBUTE)
	local viewModelTemplate = viewModels[viewModelName]

	local viewModel = viewModelTemplate:Clone()
	local muzzle = viewModel:FindFirstChild("MuzzleAttachment", true)
	assert(muzzle, `{viewModel} is missing MuzzleAttachment!`)

	local animator = viewModel.AnimationController.Animator
	local animationsFolder = viewModel.Animations

	-- The viewModel needs to be parented to the DataModel in order to load animations, otherwise it will throw an error
	viewModel.Parent = ReplicatedStorage

	-- Cache all BaseParts for scope transparency
	local viewModelParts = {}
	for _, desc in viewModel:GetDescendants() do
		if desc:IsA("BasePart") then
			table.insert(viewModelParts, desc)
		end
	end

	local animations = {}
	for _, animation in animationsFolder:GetChildren() do
		local animationTrack = animator:LoadAnimation(animation)
		animationTrack.Looped = false
		animations[animation.Name] = animationTrack

		-- Sounds will all be driven by animation events
		bindSoundsToAnimationEvents(animationTrack, sounds, audioTarget)
	end

	local self = {
		enabled = false,
		blaster = blaster,
		handle = handle,
		model = viewModel,
		muzzle = muzzle,
		animations = animations,
		toolInstances = {},
		connections = {},
		stride = 0,
		bobbing = 0,
		scopeProgress = 0,
		scopeProgressTarget = 0,
		viewModelParts = viewModelParts,
	}
	setmetatable(self, ViewModelController)

	return self
end

function ViewModelController:update(deltaTime: number)
	-- Hide tool instances
	for _, instance in self.toolInstances do
		instance.LocalTransparencyModifier = 1
	end

	-- View model bobbing animation
	local moveSpeed = (self.handle.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
	local bobbingSpeed = moveSpeed * Constants.VIEW_MODEL_BOBBING_SPEED
	local bobbing = math.min(bobbingSpeed, 1)

	self.stride = (self.stride + bobbingSpeed * deltaTime) % (math.pi * 2)
	self.bobbing = lerp(self.bobbing, bobbing, math.min(deltaTime * Constants.VIEW_MODEL_BOBBING_TRANSITION_SPEED, 1))

	local x = math.sin(self.stride)
	local y = math.sin(self.stride * 2)
	local bobbingOffset = Vector3.new(x, y, 0) * Constants.VIEW_MODEL_BOBBING_AMOUNT * self.bobbing
	local bobbingCFrame = CFrame.new(bobbingOffset)

	-- Lerp scope progress toward target
	local scopeSpeed = math.min(deltaTime / Constants.SCOPE_TWEEN_TIME, 1)
	self.scopeProgress = lerp(self.scopeProgress, self.scopeProgressTarget, scopeSpeed)

	-- Lerp ViewModel offset between hip-fire and ADS positions
	local offset = Constants.VIEW_MODEL_OFFSET:Lerp(Constants.VIEW_MODEL_ADS_OFFSET, self.scopeProgress)
	self.model:PivotTo(camera.CFrame * offset * bobbingCFrame)

	-- Fade ViewModel parts out when scoped
	for _, part in self.viewModelParts do
		part.LocalTransparencyModifier = self.scopeProgress
	end
end

function ViewModelController:checkForToolInstance(instance: Instance)
	if not (instance:IsA("BasePart") or instance:IsA("Decal")) then
		return
	end

	local tool = instance:FindFirstAncestorOfClass("Tool")
	if not tool then
		return
	end

	table.insert(self.toolInstances, instance)
end

function ViewModelController:hideToolInstances()
	local character = self.blaster.Parent

	table.insert(
		self.connections,
		character.DescendantAdded:Connect(function(descendant: Instance)
			self:checkForToolInstance(descendant)
		end)
	)

	table.insert(
		self.connections,
		character.DescendantRemoving:Connect(function(descendant: Instance)
			local index = table.find(self.toolInstances, descendant)
			if index then
				table.remove(self.toolInstances, index)
			end
		end)
	)

	for _, descendant in character:GetDescendants() do
		self:checkForToolInstance(descendant)
	end
end

function ViewModelController:stopHidingToolInstances()
	table.clear(self.toolInstances)
	disconnectAndClear(self.connections)
end

function ViewModelController:scopeIn()
	self.scopeProgressTarget = 1
end

function ViewModelController:scopeOut()
	self.scopeProgressTarget = 0
end

function ViewModelController:getMuzzlePosition(): Vector3
	return self.muzzle.WorldPosition
end

function ViewModelController:playShootAnimation()
	self.animations.Shoot:Play(0)
	self.muzzle.FlashEmitter:Emit(1)
	self.muzzle.CircleEmitter:Emit(1)
end

function ViewModelController:playReloadAnimation(reloadTime: number)
	self.animations.Shoot:Stop()
	local speed = self.animations.Reload.Length / reloadTime
	self.animations.Reload:Play(Constants.VIEW_MODEL_RELOAD_FADE_TIME, 1, speed)
end

function ViewModelController:enable()
	if self.enabled then
		return
	end
	self.enabled = true

	RunService:BindToRenderStep(
		Constants.VIEW_MODEL_BIND_NAME,
		Enum.RenderPriority.Camera.Value + 2, -- after aim assist
		function(deltaTime: number)
			self:update(deltaTime)
		end
	)
	self.model.Parent = Workspace
	self:hideToolInstances()

	-- Play equip and idle animations
	self.animations.Idle:Play()
	self.animations.Equip:Play(0)
end

function ViewModelController:disable()
	if not self.enabled then
		return
	end
	self.enabled = false

	RunService:UnbindFromRenderStep(Constants.VIEW_MODEL_BIND_NAME)
	self.model.Parent = nil
	self:stopHidingToolInstances()

	for _, animation in self.animations do
		animation:Stop(0)
	end
end

function ViewModelController:destroy()
	disconnectAndClear(self.connections)
	self:disable()
	self.model:Destroy()
end

return ViewModelController
