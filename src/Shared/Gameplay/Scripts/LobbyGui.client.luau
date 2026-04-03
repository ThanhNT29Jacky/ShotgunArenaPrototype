--!strict

-- LobbyGui — displays a waiting screen until MIN_PLAYERS are connected.
-- Listens to the LobbyStatus RemoteEvent (fired from Rounds/init.server.luau).
-- RemoteEvent payload: (status: "waiting" | "starting", currentCount: number, required: number)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player.PlayerGui

local remotes = ReplicatedStorage.Gameplay.Remotes
local lobbyStatusRemote = remotes:WaitForChild("LobbyStatus", 10)
local LOBBY_START_GRACE = 3
local currentLobbyStatus = "waiting"

local BACKGROUND_FADE_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PANEL_FADE_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BLUR_FADE_INFO = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BACKGROUND_SWEEP_INFO = TweenInfo.new(14, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LobbyGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 10
screenGui.Enabled = false
screenGui.ScreenInsets = Enum.ScreenInsets.None
screenGui.Parent = playerGui

local blur = Instance.new("BlurEffect")
blur.Name = "LobbyBlur"
blur.Size = 0
blur.Enabled = true
if Workspace.CurrentCamera then
	blur.Parent = Workspace.CurrentCamera
end

local function attachBlurToCamera(): ()
	if Workspace.CurrentCamera then
		blur.Parent = Workspace.CurrentCamera
	end
end

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(attachBlurToCamera)
attachBlurToCamera()

-- Dark full-bleed background
local background = Instance.new("Frame")
background.Name = "Background"
background.Size = UDim2.fromScale(1, 1)
background.Position = UDim2.fromScale(0, 0)
background.BackgroundColor3 = Color3.fromRGB(8, 12, 24)
background.BorderSizePixel = 0
background.Parent = screenGui

local backgroundGradient = Instance.new("UIGradient")
backgroundGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 20, 38)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(8, 12, 24)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(4, 6, 16)),
})
backgroundGradient.Rotation = 0
backgroundGradient.Parent = background

-- Center panel
local panel: CanvasGroup = Instance.new("CanvasGroup")
panel.Name = "CenterPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(640, 380)
panel.BackgroundColor3 = Color3.fromRGB(14, 18, 34)
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.GroupTransparency = 1
panel.Parent = background

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 16)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(70, 84, 120)
panelStroke.Transparency = 0.45
panelStroke.Thickness = 1
panelStroke.Parent = panel

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 18)
padding.PaddingBottom = UDim.new(0, 18)
padding.PaddingLeft = UDim.new(0, 20)
padding.PaddingRight = UDim.new(0, 20)
padding.Parent = panel

local gameTitleLabel = Instance.new("TextLabel")
gameTitleLabel.Name = "GameTitleLabel"
gameTitleLabel.Size = UDim2.new(1, 0, 0, 28)
gameTitleLabel.Position = UDim2.fromOffset(0, 0)
gameTitleLabel.BackgroundTransparency = 1
gameTitleLabel.Font = Enum.Font.GothamBold
gameTitleLabel.TextSize = 20
gameTitleLabel.TextColor3 = Color3.fromRGB(255, 210, 70)
gameTitleLabel.Text = "SHOTGUN ARENA"
gameTitleLabel.TextXAlignment = Enum.TextXAlignment.Center
gameTitleLabel.Parent = panel

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(1, 0, 0, 54)
titleLabel.Position = UDim2.fromOffset(0, 34)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.TextSize = 38
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.Text = "WAITING FOR PLAYERS"
titleLabel.TextXAlignment = Enum.TextXAlignment.Center
titleLabel.Parent = panel

local countLabel = Instance.new("TextLabel")
countLabel.Name = "CountLabel"
countLabel.Size = UDim2.new(1, 0, 0, 32)
countLabel.Position = UDim2.fromOffset(0, 92)
countLabel.BackgroundTransparency = 1
countLabel.Font = Enum.Font.GothamBold
countLabel.TextSize = 28
countLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
countLabel.Text = "0 / 2 PLAYERS"
countLabel.TextXAlignment = Enum.TextXAlignment.Center
countLabel.Parent = panel

local dotLabel = Instance.new("TextLabel")
dotLabel.Name = "DotLabel"
dotLabel.Size = UDim2.new(1, 0, 0, 24)
dotLabel.Position = UDim2.fromOffset(0, 126)
dotLabel.BackgroundTransparency = 1
dotLabel.Font = Enum.Font.GothamBold
dotLabel.TextSize = 24
dotLabel.TextColor3 = Color3.fromRGB(150, 155, 175)
dotLabel.Text = "."
dotLabel.TextXAlignment = Enum.TextXAlignment.Center
dotLabel.Parent = panel

local playerListHeader = Instance.new("TextLabel")
playerListHeader.Name = "PlayerListHeader"
playerListHeader.Size = UDim2.new(1, 0, 0, 22)
playerListHeader.Position = UDim2.fromOffset(0, 162)
playerListHeader.BackgroundTransparency = 1
playerListHeader.Font = Enum.Font.GothamSemibold
playerListHeader.TextSize = 14
playerListHeader.TextColor3 = Color3.fromRGB(190, 198, 220)
playerListHeader.Text = "CONNECTED PLAYERS"
playerListHeader.TextXAlignment = Enum.TextXAlignment.Left
playerListHeader.Parent = panel

local playerListFrame = Instance.new("ScrollingFrame")
playerListFrame.Name = "PlayerList"
playerListFrame.Size = UDim2.new(1, 0, 0, 146)
playerListFrame.Position = UDim2.fromOffset(0, 186)
playerListFrame.BackgroundColor3 = Color3.fromRGB(10, 14, 26)
playerListFrame.BackgroundTransparency = 0.15
playerListFrame.BorderSizePixel = 0
playerListFrame.ScrollBarThickness = 4
playerListFrame.ScrollingDirection = Enum.ScrollingDirection.Y
playerListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
playerListFrame.CanvasSize = UDim2.fromOffset(0, 0)
playerListFrame.Parent = panel

local playerListCorner = Instance.new("UICorner")
playerListCorner.CornerRadius = UDim.new(0, 10)
playerListCorner.Parent = playerListFrame

local playerListPadding = Instance.new("UIPadding")
playerListPadding.PaddingTop = UDim.new(0, 8)
playerListPadding.PaddingBottom = UDim.new(0, 8)
playerListPadding.PaddingLeft = UDim.new(0, 12)
playerListPadding.PaddingRight = UDim.new(0, 12)
playerListPadding.Parent = playerListFrame

local playerListLayout = Instance.new("UIListLayout")
playerListLayout.Padding = UDim.new(0, 6)
playerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
playerListLayout.Parent = playerListFrame

local pendingHideToken = 0
local activeBackgroundTween: Tween? = nil
local activePanelTween: Tween? = nil
local activeBlurTween: Tween? = nil

local function cancelTween(tween: Tween?)
	if tween then
		tween:Cancel()
	end
end

local function refreshPlayerList(): ()
	for _, child in ipairs(playerListFrame:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end

	local connectedPlayers = Players:GetPlayers()
	table.sort(connectedPlayers, function(a: Player, b: Player)
		return a.Name:lower() < b.Name:lower()
	end)

	for index, connectedPlayer in ipairs(connectedPlayers) do
		local row = Instance.new("TextLabel")
		row.Name = connectedPlayer.Name .. "Row"
		row.Size = UDim2.new(1, 0, 0, 22)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamMedium
		row.TextSize = 16
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextTruncate = Enum.TextTruncate.AtEnd
		row.LayoutOrder = index
		row.Text = "• " .. connectedPlayer.Name
		row.TextColor3 = if connectedPlayer == player then Color3.fromRGB(255, 210, 70) else Color3.fromRGB(235, 238, 245)
		row.Parent = playerListFrame
	end

	if #connectedPlayers == 0 then
		local row = Instance.new("TextLabel")
		row.Name = "EmptyRow"
		row.Size = UDim2.new(1, 0, 0, 22)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamMedium
		row.TextSize = 16
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = "• Waiting for players..."
		row.TextColor3 = Color3.fromRGB(160, 165, 180)
		row.Parent = playerListFrame
	end
end

local function setVisibleState(status: string, currentCount: number, required: number): ()
	currentLobbyStatus = status
	titleLabel.Text = if status == "starting" then "MATCH STARTING" else "WAITING FOR PLAYERS"
	countLabel.Text = string.format("%d / %d PLAYERS", currentCount, required)
	refreshPlayerList()
end

local function showLobby(status: string, currentCount: number, required: number): ()
	setVisibleState(status, currentCount, required)
	pendingHideToken += 1
	cancelTween(activeBackgroundTween)
	cancelTween(activePanelTween)
	cancelTween(activeBlurTween)
	attachBlurToCamera()

	if not screenGui.Enabled then
		screenGui.Enabled = true
		background.BackgroundTransparency = 1
		panel.GroupTransparency = 1
		blur.Size = 0
	end

	activeBackgroundTween = TweenService:Create(background, BACKGROUND_FADE_INFO, { BackgroundTransparency = 0 })
	activePanelTween = TweenService:Create(panel, PANEL_FADE_INFO, { GroupTransparency = 0 })
	activeBlurTween = TweenService:Create(blur, BLUR_FADE_INFO, { Size = 18 })

	activeBackgroundTween:Play()
	activePanelTween:Play()
	activeBlurTween:Play()
end

local function hideLobby(): ()
	pendingHideToken += 1
	local token = pendingHideToken

	cancelTween(activeBackgroundTween)
	cancelTween(activePanelTween)
	cancelTween(activeBlurTween)

	activeBackgroundTween = TweenService:Create(background, BACKGROUND_FADE_INFO, { BackgroundTransparency = 1 })
	activePanelTween = TweenService:Create(panel, PANEL_FADE_INFO, { GroupTransparency = 1 })
	activeBlurTween = TweenService:Create(blur, BLUR_FADE_INFO, { Size = 0 })

	activeBackgroundTween:Play()
	activePanelTween:Play()
	activeBlurTween:Play()

	activePanelTween.Completed:Once(function()
		if token == pendingHideToken and currentLobbyStatus == "starting" then
			screenGui.Enabled = false
		end
	end)
end

local function scheduleHideAfterGrace(): ()
	pendingHideToken += 1
	local token = pendingHideToken
	task.delay(LOBBY_START_GRACE, function()
		if token == pendingHideToken and currentLobbyStatus == "starting" then
			hideLobby()
		end
	end)
end

local dotFrames = { ".", "..", "..." }
local dotIndex = 1

task.spawn(function()
	while screenGui.Parent do
		if screenGui.Enabled then
			dotLabel.Text = dotFrames[dotIndex]
			dotIndex = (dotIndex % #dotFrames) + 1
			task.wait(0.5)
		else
			dotLabel.Text = "."
			dotIndex = 1
			task.wait(0.2)
		end
	end
end)

task.spawn(function()
	while screenGui.Parent do
		if screenGui.Enabled then
			local tween = TweenService:Create(backgroundGradient, BACKGROUND_SWEEP_INFO, { Rotation = 360 })
			tween:Play()
			tween.Completed:Wait()
			if screenGui.Enabled then
				backgroundGradient.Rotation = 0
			end
		else
			task.wait(0.2)
		end
	end
end)

Players.PlayerAdded:Connect(refreshPlayerList)
Players.PlayerRemoving:Connect(refreshPlayerList)
refreshPlayerList()

-- ── Remote listener ───────────────────────────────────────────────────────────

if lobbyStatusRemote then
	lobbyStatusRemote.OnClientEvent:Connect(function(status: string, currentCount: number, required: number)
		if status == "waiting" then
			showLobby(status, currentCount, required)
		elseif status == "starting" then
			showLobby(status, currentCount, required)
			scheduleHideAfterGrace()
		else
			warn("[LobbyGui] Unexpected LobbyStatus status:", status)
		end
	end)
else
	warn("[LobbyGui] LobbyStatus remote not found — lobby screen will not appear")
end
