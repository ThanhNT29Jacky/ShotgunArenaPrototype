--!strict

-- LobbyGui — displays a waiting screen until MIN_PLAYERS are connected.
-- Listens to the LobbyStatus RemoteEvent (fired from Rounds/init.server.luau).
-- RemoteEvent payload: (currentCount: number, required: number)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player.PlayerGui

local remotes = ReplicatedStorage.Gameplay.Remotes
local lobbyStatusRemote = remotes:WaitForChild("LobbyStatus", 10)

-- ── Build the ScreenGui programmatically (no template required) ───────────────

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LobbyGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 10
screenGui.Enabled = false
screenGui.ScreenInsets = Enum.ScreenInsets.None
screenGui.Parent = playerGui

-- Dark full-bleed background
local background = Instance.new("Frame")
background.Name = "Background"
background.Size = UDim2.fromScale(1, 1)
background.Position = UDim2.fromScale(0, 0)
background.BackgroundColor3 = Color3.fromRGB(8, 12, 24)
background.BorderSizePixel = 0
background.Parent = screenGui

-- Vertical layout container centred on screen
local container = Instance.new("Frame")
container.Name = "Container"
container.AnchorPoint = Vector2.new(0.5, 0.5)
container.Position = UDim2.fromScale(0.5, 0.5)
container.Size = UDim2.fromOffset(600, 300)
container.BackgroundTransparency = 1
container.Parent = background

local layout = Instance.new("UIListLayout")
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 20)
layout.Parent = container

-- Title label
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(1, 0, 0, 60)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 42
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.Text = "WAITING FOR PLAYERS"
titleLabel.TextXAlignment = Enum.TextXAlignment.Center
titleLabel.Parent = container

-- Player count label  (e.g. "1 / 2 PLAYERS")
local countLabel = Instance.new("TextLabel")
countLabel.Name = "CountLabel"
countLabel.Size = UDim2.new(1, 0, 0, 48)
countLabel.BackgroundTransparency = 1
countLabel.Font = Enum.Font.GothamBold
countLabel.TextSize = 34
countLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
countLabel.Text = "0 / 2 PLAYERS"
countLabel.TextXAlignment = Enum.TextXAlignment.Center
countLabel.Parent = container

-- Animated dot indicator
local dotLabel = Instance.new("TextLabel")
dotLabel.Name = "DotLabel"
dotLabel.Size = UDim2.new(1, 0, 0, 36)
dotLabel.BackgroundTransparency = 1
dotLabel.Font = Enum.Font.GothamBold
dotLabel.TextSize = 28
dotLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
dotLabel.Text = "..."
dotLabel.TextXAlignment = Enum.TextXAlignment.Center
dotLabel.Parent = container

-- ── Dot animation ─────────────────────────────────────────────────────────────

local dotFrames = { ".", "..", "..." }
local dotIndex = 1
local dotConnection: RBXScriptConnection? = nil

local function startDotAnimation(): ()
	dotConnection = game:GetService("RunService").Heartbeat:Connect(function()
		-- No-op: we use task.spawn loop instead
	end)
	dotConnection:Disconnect()
	dotConnection = nil

	task.spawn(function()
		while screenGui.Enabled do
			dotLabel.Text = dotFrames[dotIndex]
			dotIndex = (dotIndex % #dotFrames) + 1
			task.wait(0.5)
		end
		dotLabel.Text = "..."
		dotIndex = 1
	end)
end

-- ── Show / hide logic ─────────────────────────────────────────────────────────

local function showLobby(currentCount: number, required: number): ()
	countLabel.Text = string.format("%d / %d PLAYERS", currentCount, required)
	if not screenGui.Enabled then
		screenGui.Enabled = true
		background.BackgroundTransparency = 1
		TweenService:Create(
			background,
			TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 0 }
		):Play()
		startDotAnimation()
	end
end

local function hideLobby(): ()
	if screenGui.Enabled then
		local tween = TweenService:Create(
			background,
			TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ BackgroundTransparency = 1 }
		)
		tween:Play()
		tween.Completed:Once(function()
			screenGui.Enabled = false
		end)
	end
end

-- ── Remote listener ───────────────────────────────────────────────────────────

if lobbyStatusRemote then
	lobbyStatusRemote.OnClientEvent:Connect(function(currentCount: number, required: number)
		if currentCount >= required then
			hideLobby()
		else
			showLobby(currentCount, required)
		end
	end)
else
	warn("[LobbyGui] LobbyStatus remote not found — lobby screen will not appear")
end
