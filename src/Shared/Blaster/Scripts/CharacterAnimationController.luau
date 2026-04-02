--!nocheck
local CharacterAnimationController = {}
CharacterAnimationController.__index = CharacterAnimationController

function CharacterAnimationController.new(blaster: Tool)
	local self = {
		enabled = false,
		loadedAnimations = false,
		blaster = blaster,
		animationTracks = {},
	}
	setmetatable(self, CharacterAnimationController)

	return self
end

function CharacterAnimationController:playShootAnimation()
	self.animationTracks.Shoot:Play(0)
end

function CharacterAnimationController:playReloadAnimation(reloadTime: number)
	local speed = self.animationTracks.Reload.Length / reloadTime
	self.animationTracks.Reload:Play(0.1, 1, speed)
end

function CharacterAnimationController:loadAnimations()
	if self.loadedAnimations then
		return
	end

	self.loadedAnimations = true

	local animationsFolder = self.blaster.Animations
	-- This should only be called when the blaster has been equipped
	local humanoid = self.blaster.Parent:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn("[CharacterAnimationController] Cannot load animations: humanoid not found (blaster not equipped?)")
		return
	end
	local animator = humanoid.Animator

	local animationTracks = {}
	for _, animation in animationsFolder:GetChildren() do
		local animationTrack = animator:LoadAnimation(animation)
		animationTracks[animation.Name] = animationTrack

		-- Unlike the ViewModelController, we won't tie any sounds to these animations.
		-- Since we're playing these animations from the client and relying on default replication behavior,
		-- any sounds we played here would overlap the view model sounds and wouldn't replicate.
	end

	self.animationTracks = animationTracks
end

function CharacterAnimationController:enable()
	if self.enabled then
		return
	end

	-- Load animations if they haven't been loaded already
	if not self.loadedAnimations then
		self:loadAnimations()
	end

	if not self.animationTracks or not self.animationTracks.Idle then
		warn("[CharacterAnimationController] Animation tracks not loaded, skipping enable")
		return  -- self.enabled stays false; future enable() calls can retry
	end
	self.enabled = true
	self.animationTracks.Idle:Play()
end

function CharacterAnimationController:disable()
	if not self.enabled then
		return
	end
	self.enabled = false

	for _, animation in self.animationTracks do
		animation:Stop()
	end
end

function CharacterAnimationController:destroy()
	self:disable()
	-- Clear the animationTracks table so we don't keep any references around.
	-- This makes sure the animation tracks get garbage collected correctly and don't cause a memory leak.
	table.clear(self.animationTracks)
end

return CharacterAnimationController
