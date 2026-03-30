local Knit = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Knit"))
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local CameraController = Knit.CreateController {
	Name = "CameraController",
}

local camera: Camera = workspace.CurrentCamera
local localPlayer: Player = Players.LocalPlayer
local character: Model?
local hrp: Part?

local cameraYaw: number = 0
local cameraPitch: number = 0
local recoilTarget: CFrame = CFrame.new()
local recoilOffset: CFrame = CFrame.new()

local viewmodelModel: Model?
local leftArm: Part?
local rightArm: Part?

function CameraController:KnitInit()
	camera.CameraType = Enum.CameraType.Scriptable
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
end

function CameraController:KnitStart()
	localPlayer.CharacterAdded:Connect(function(newCharacter: Model)
		character = newCharacter
		hrp = character:WaitForChild("HumanoidRootPart") :: Part
		self:_setupViewmodel()
	end)

	if localPlayer.Character then
		character = localPlayer.Character
		hrp = character:WaitForChild("HumanoidRootPart") :: Part
		self:_setupViewmodel()
	end

	RunService.RenderStepped:Connect(function(deltaTime: number)
		self:_updateCamera(deltaTime)
	end)
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
	leftArm.CFrame = camera.CFrame * CFrame.new(-0.6, -0.8, -1)
	leftArm.Parent = viewmodelModel

	-- Create right arm part
	rightArm = Instance.new("Part")
	rightArm.Name = "RightArm"
	rightArm.Shape = Enum.PartType.Cylinder
	rightArm.Size = Vector3.new(0.4, 1.5, 0.4)
	rightArm.Color = Color3.fromRGB(204, 153, 102)
	rightArm.Material = Enum.Material.SmoothPlastic
	rightArm.CanCollide = false
	rightArm.CFrame = camera.CFrame * CFrame.new(0.6, -0.8, -1)
	rightArm.Parent = viewmodelModel
end

function CameraController:_updateCamera(deltaTime: number): ()
	if not hrp then return end

	-- Get mouse delta
	local mouseDelta: Vector2 = UserInputService:GetMouseDelta()

	-- Update yaw and pitch
	cameraYaw = cameraYaw + mouseDelta.X * 0.003
	cameraPitch = cameraPitch - mouseDelta.Y * 0.003

	-- Clamp pitch to ±80 degrees
	cameraPitch = math.clamp(cameraPitch, math.rad(-80), math.rad(80))

	-- Calculate base camera CFrame (from HRP top)
	local basePosition: Vector3 = hrp.Position + Vector3.new(0, 1.5, 0)
	local baseCFrame: CFrame = CFrame.new(basePosition) * CFrame.Angles(0, cameraYaw, 0) * CFrame.Angles(cameraPitch, 0, 0)

	-- Apply recoil offset
	local finalCFrame: CFrame = baseCFrame * recoilOffset

	-- Update camera
	camera.CFrame = finalCFrame

	-- Update viewmodel if exists
	if viewmodelModel then
		viewmodelModel.Parent = camera -- Ensure it stays in camera

		if leftArm then
			leftArm.CFrame = camera.CFrame * CFrame.new(-0.6, -0.8, -1)
		end
		if rightArm then
			rightArm.CFrame = camera.CFrame * CFrame.new(0.6, -0.8, -1)
		end
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
