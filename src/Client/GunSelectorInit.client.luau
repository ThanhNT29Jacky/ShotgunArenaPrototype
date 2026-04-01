local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local selectGunRemote = ReplicatedStorage.Blaster.Remotes:WaitForChild("SelectGun", 5)
if not selectGunRemote then
	warn("[GunSelectorInit] SelectGun remote not found within 5 seconds — aborting")
	return
end

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Gun cycle order
local gunOrder = { "Pistol", "Shotgun", "Rifle", "AWP" }
local selectedIndex = 1

-- Build ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GunSelectorGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 10
screenGui.Parent = playerGui

-- Toast label shown briefly when switching
local toast = Instance.new("Frame")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.new(0.5, 0, 0.88, 0)
toast.Size = UDim2.new(0, 220, 0, 44)
toast.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
toast.BackgroundTransparency = 0.3
toast.BorderSizePixel = 0
toast.Visible = false
toast.Parent = screenGui

local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 8)
toastCorner.Parent = toast

local toastLabel = Instance.new("TextLabel")
toastLabel.Size = UDim2.new(1, 0, 1, 0)
toastLabel.BackgroundTransparency = 1
toastLabel.TextColor3 = Color3.fromRGB(255, 200, 60)
toastLabel.TextSize = 16
toastLabel.Font = Enum.Font.GothamBold
toastLabel.Parent = toast

-- Hint label (always visible, bottom center)
local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 0.95, 0)
hint.Size = UDim2.new(0, 260, 0, 20)
hint.BackgroundTransparency = 1
hint.Text = "[Q] Prev Gun   [D] Next Gun"
hint.TextColor3 = Color3.fromRGB(160, 160, 160)
hint.TextSize = 12
hint.Font = Enum.Font.Gotham
hint.Parent = screenGui

local fadeTask = nil

local function showToast(gunName: string)
	toastLabel.Text = "⬤  " .. gunName
	toast.Visible = true
	toast.BackgroundTransparency = 0.3
	toastLabel.TextTransparency = 0

	if fadeTask then
		task.cancel(fadeTask)
	end

	fadeTask = task.delay(1.2, function()
		TweenService:Create(toast,    TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(toastLabel, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.wait(0.4)
		toast.Visible = false
		fadeTask = nil
	end)
end

local function selectGun(index: number)
	selectedIndex = index
	local gunName = gunOrder[selectedIndex]
	selectGunRemote:FireServer(gunName)
	showToast(gunName)
end

-- Q = previous, D = next
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Q then
		local prev = ((selectedIndex - 2) % #gunOrder) + 1
		selectGun(prev)
	elseif input.KeyCode == Enum.KeyCode.D then
		local next = (selectedIndex % #gunOrder) + 1
		selectGun(next)
	end
end)