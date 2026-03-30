local Knit = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Knit"))
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local WeaponConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("WeaponConfig"))

local CameraController = Knit.CreateController {
	Name = "CameraController",
}

local camera: Camera = workspace.CurrentCamera
local localPlayer: Player = Players.LocalPlayer
local character: Model?
local hrp: Part?
local head: BasePart?
local humanoid: Humanoid?

local cameraYaw: number = 0
local cameraPitch: number = 0
local recoilTarget: CFrame = CFrame.new()
local recoilOffset: CFrame = CFrame.new()

local viewmodelModel: Model?
local leftArm: Part?
local rightArm: Part?
local weaponPart: Part?

local ARM_ROTATION: CFrame = CFrame.Angles(0, 0, math.rad(90))
local CAMERA_RENDER_STEP: string = "CameraUpdate"

function CameraController:KnitInit()
	camera.CameraType = Enum.CameraType.Scriptable
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
end

function CameraController:KnitStart()
	localPlayer.CharacterAdded:Connect(function(newCharacter: Model)
		character = newCharacter
		hrp = character:WaitForChild("HumanoidRootPart") :: Part
		head = character:WaitForChild("Head") :: BasePart
		humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.AutoRotate = false
		self:_setupViewmodel()
	end)

	if localPlayer.Character then
		character = localPlayer.Character
		hrp = character:WaitForChild("HumanoidRootPart") :: Part
		head = character:WaitForChild("Head") :: BasePart
		humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.AutoRotate = false
		self:_setupViewmodel()
	end

	RunService:BindToRenderStep(
		CAMERA_RENDER_STEP,
		Enum.RenderPriority.Camera.Value + 1,
		function(deltaTime: number)
			self:_updateCamera(deltaTime)
		end
	)
end

function CameraController:_setupViewmodel(): ()
	-- Clean up old viewmodel if exists
	if viewmodelModel then
		viewmodelModel:Destroy()
	end

	-- Create viewmodel model
	viewmodelModel = Instance.new("Model")
	viewmodelModel.Name = "Viewmodel"
	viewmodelModel.Parent = camera

	-- Create left arm part
	leftArm = Instance.new("Part")
	leftArm.Name = "LeftArm"
	leftArm.Shape = Enum.PartType.Cylinder
	leftArm.Size = Vector3.new(0.4, 1.5, 0.4)
	leftArm.Color = Color3.fromRGB(204, 153, 102)
	leftArm.Material = Enum.Material.SmoothPlastic
	leftArm.CanCollide = false
	leftArm.CFrame = camera.CFrame * CFrame.new(-0.6, -0.8, -1) * ARM_ROTATION
	leftArm.Parent = viewmodelModel

	-- Create right arm part
	rightArm = Instance.new("Part")
	rightArm.Name = "RightArm"
	rightArm.Shape = Enum.PartType.Cylinder
	rightArm.Size = Vector3.new(0.4, 1.5, 0.4)
	rightArm.Color = Color3.fromRGB(204, 153, 102)
	rightArm.Material = Enum.Material.SmoothPlastic
	rightArm.CanCollide = false
	rightArm.CFrame = camera.CFrame * CFrame.new(0.6, -0.8, -1) * ARM_ROTATION
	rightArm.Parent = viewmodelModel

	-- Create weapon placeholder block
	weaponPart = Instance.new("Part")
	weaponPart.Name = "WeaponBlock"
	weaponPart.Size = Vector3.new(0.2, 0.2, 1.2)
	weaponPart.Color = Color3.fromRGB(60, 60, 60)
	weaponPart.Material = Enum.Material.Metal
	weaponPart.CanCollide = false
	weaponPart.CFrame = camera.CFrame * CFrame.new(0.3, -0.85, -1.2)
	weaponPart.Parent = viewmodelModel
end

function CameraController:_updateCamera(deltaTime: number): ()
	if not hrp then return end

	-- Get mouse delta
	local mouseDelta: Vector2 = UserInputService:GetMouseDelta()

	-- Update yaw and pitch
	cameraYaw = cameraYaw + mouseDelta.X * WeaponConfig.MOUSE_SENSITIVITY
	cameraPitch = cameraPitch - mouseDelta.Y * WeaponConfig.MOUSE_SENSITIVITY

	-- Clamp pitch to ±80 degrees
	cameraPitch = math.clamp(cameraPitch, math.rad(-80), math.rad(80))

	-- Calculate base camera CFrame (from Head position)
	local headPart = head or hrp  -- fallback if Head not yet loaded
	local basePosition: Vector3 = headPart.Position
	local baseCFrame: CFrame = CFrame.new(basePosition) * CFrame.Angles(0, cameraYaw, 0) * CFrame.Angles(cameraPitch, 0, 0)

	-- Apply recoil offset
	local finalCFrame: CFrame = baseCFrame * recoilOffset

	-- Update camera
	camera.CFrame = finalCFrame

	-- Update viewmodel if exists
	if viewmodelModel then
		if leftArm then
			leftArm.CFrame = camera.CFrame * CFrame.new(-0.6, -0.8, -1) * ARM_ROTATION
		end
		if rightArm then
			rightArm.CFrame = camera.CFrame * CFrame.new(0.6, -0.8, -1) * ARM_ROTATION
		end
		if weaponPart then
			weaponPart.CFrame = camera.CFrame * CFrame.new(0.3, -0.85, -1.2)
		end
	end

	-- Rotate character body to match camera yaw (FPS convention)
	if hrp then
		hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, cameraYaw, 0)
	end

	-- Update recoil spring
	recoilOffset = recoilOffset:Lerp(recoilTarget, deltaTime * 20)
	recoilTarget = recoilTarget:Lerp(CFrame.new(), deltaTime * 8)
end

function CameraController:AddRecoil(kickUp: number, kickSide: number): ()
	recoilTarget = recoilTarget * CFrame.Angles(math.rad(kickUp), math.rad(kickSide), 0)
end

function CameraController:GetLookCFrame(): CFrame
	return camera.CFrame
end

return CameraController
