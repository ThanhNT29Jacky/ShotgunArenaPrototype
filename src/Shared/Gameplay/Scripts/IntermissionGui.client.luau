--[[
	IntermissionGui.client.luau
	Displays the full-screen COMBAT REPORT intermission screen after each round.

	Listens for:
	  IntermissionStart(winningTeam: Team, stats: {{name, teamName, teamColor, kills}}, intermissionEndTime: number)

	Layout:
	  • Dark navy background with UIGradient sweep
	  • Header "— COMBAT REPORT —" in gold
	  • Winner banner in team colour
	  • Gold horizontal divider
	  • Left column  — Team A player cards (sorted by kills desc)
	  • Centre column — circular countdown ring
	  • Right column  — Team B player cards (sorted by kills desc)
	  • BlurEffect on CurrentCamera (tweens in/out)
	  • Auto-hides when countdown reaches 0
--]]

local Players        = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")
local Workspace      = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Gameplay.Constants)

local player    = Players.LocalPlayer
local playerGui = player.PlayerGui
local currentCountdownConnection: RBXScriptConnection? = nil

local remotes              = ReplicatedStorage.Gameplay.Remotes
local intermissionStartRemote = remotes:WaitForChild("IntermissionStart", 10)

-- ── Colours / sizes ─────────────────────────────────────────────────────────
local BG_COLOR   = Color3.fromRGB(8, 12, 24)
local GOLD       = Color3.fromRGB(220, 180, 60)
local WHITE      = Color3.fromRGB(255, 255, 255)
local CARD_BG    = Color3.fromRGB(20, 26, 44)

local FADE_IN_INFO  = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE_OUT_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local BLUR_IN_INFO  = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BLUR_OUT_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local CARD_IN_INFO  = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local CARD_START_SCALE = 0.92
local CARD_STAGGER_DELAY = 0.055

-- ── Blur effect ──────────────────────────────────────────────────────────────
local blur: BlurEffect = Instance.new("BlurEffect")
blur.Size    = 0
blur.Enabled = true
blur.Parent  = workspace.CurrentCamera

-- ── Helper: create a TextLabel ────────────────────────────────────────────────
local function makeLabel(
	parent:    Instance,
	text:      string,
	size:      UDim2,
	position:  UDim2,
	fontSize:  number,
	color:     Color3,
	font:      Enum.Font,
	anchorPoint: Vector2?
): TextLabel
	local lbl = Instance.new("TextLabel")
	lbl.Size              = size
	lbl.Position          = position
	lbl.AnchorPoint       = anchorPoint or Vector2.new(0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text              = text
	lbl.TextColor3        = color
	lbl.TextSize          = fontSize
	lbl.Font              = font
	lbl.TextScaled        = false
	lbl.TextXAlignment    = Enum.TextXAlignment.Center
	lbl.TextYAlignment    = Enum.TextYAlignment.Center
	lbl.Parent            = parent
	return lbl
end

-- ── Helper: create a Frame ────────────────────────────────────────────────────
local function makeFrame(
	parent:   Instance,
	size:     UDim2,
	position: UDim2,
	color:    Color3,
	transparency: number,
	anchorPoint: Vector2?
): Frame
	local f = Instance.new("Frame")
	f.Size                 = size
	f.Position             = position
	f.AnchorPoint          = anchorPoint or Vector2.new(0, 0)
	f.BackgroundColor3     = color
	f.BackgroundTransparency = transparency
	f.BorderSizePixel      = 0
	f.Parent               = parent
	return f
end

-- ── Build player card ─────────────────────────────────────────────────────────
local function buildPlayerCard(
	parent: Instance,
	layoutOrder: number,
	name: string,
	kills: number,
	teamColor: Color3
): Frame
	local card = makeFrame(parent, UDim2.new(1, 0, 0, 44), UDim2.new(0, 0, 0, 0), CARD_BG, 0)
	card.LayoutOrder = layoutOrder
	card.BackgroundTransparency = 1

	local scale = Instance.new("UIScale")
	scale.Scale = CARD_START_SCALE
	scale.Parent = card

	-- Left accent stripe
	local stripe = makeFrame(card, UDim2.new(0, 3, 1, 0), UDim2.new(0, 0, 0, 0), teamColor, 0)
	stripe.Name = "Stripe"
	stripe.BackgroundTransparency = 1

	-- Player name
	local nameLabel = makeLabel(
		card,
		name,
		UDim2.new(0.7, -8, 1, 0),
		UDim2.new(0, 10, 0, 0),
		16,
		WHITE,
		Enum.Font.GothamMedium
	)
	nameLabel.TextTransparency = 1

	-- Kill count with star
	local killsLabel = makeLabel(
		card,
		"☆ " .. tostring(kills),
		UDim2.new(0.3, -8, 1, 0),
		UDim2.new(0.7, 4, 0, 0),
		16,
		GOLD,
		Enum.Font.GothamBold
	)
	killsLabel.TextTransparency = 1

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = card

	return card
end

local function animatePlayerCard(card: Frame, delaySeconds: number)
	task.delay(delaySeconds, function()
		if not card.Parent then
			return
		end

		local tweens = {}

		local scale = card:FindFirstChildOfClass("UIScale")
		if scale then
			table.insert(tweens, TweenService:Create(scale, CARD_IN_INFO, { Scale = 1 }))
		end

		table.insert(tweens, TweenService:Create(card, CARD_IN_INFO, { BackgroundTransparency = 0 }))

		local stripe = card:FindFirstChild("Stripe")
		if stripe and stripe:IsA("Frame") then
			table.insert(tweens, TweenService:Create(stripe, CARD_IN_INFO, { BackgroundTransparency = 0 }))
		end

		for _, descendant in ipairs(card:GetDescendants()) do
			if descendant:IsA("TextLabel") then
				table.insert(tweens, TweenService:Create(descendant, CARD_IN_INFO, { TextTransparency = 0 }))
			end
		end

		for _, tween in ipairs(tweens) do
			tween:Play()
		end
	end)
end

-- ── Build the full GUI ────────────────────────────────────────────────────────
local function buildGui(
	winningTeam: Team,
	stats: { { name: string, teamName: string, teamColor: Color3, kills: number } },
	intermissionEndTime: number
): (ScreenGui, Frame, TextLabel)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name           = "IntermissionGui"
	screenGui.DisplayOrder   = 20
	screenGui.IgnoreGuiInset = true
	screenGui.Enabled        = false
	screenGui.ResetOnSpawn   = false

	-- ── Dark background ──────────────────────────────────────────────────────
	local bg = makeFrame(screenGui, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), BG_COLOR, 0)
	bg.Name = "Background"
	bg.BackgroundTransparency = 1  -- starts invisible; tweened in

	-- UIGradient diagonal sweep
	local grad = Instance.new("UIGradient")
	grad.Color    = ColorSequence.new({
		ColorSequenceKeypoint.new(0,   Color3.fromRGB(12, 18, 38)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(8, 12, 24)),
		ColorSequenceKeypoint.new(1,   Color3.fromRGB(4, 8, 18)),
	})
	grad.Rotation = 135
	grad.Parent   = bg

	-- ── Header "— COMBAT REPORT —" ───────────────────────────────────────────
	makeLabel(
		bg,
		"— COMBAT REPORT —",
		UDim2.new(1, 0, 0, 70),
		UDim2.new(0.5, 0, 0, 20),
		52,
		GOLD,
		Enum.Font.GothamBold,
		Vector2.new(0.5, 0)
	).Name = "Header"

	-- ── Winner banner ─────────────────────────────────────────────────────────
	makeLabel(
		bg,
		winningTeam.Name:upper() .. " WINS",
		UDim2.new(0.6, 0, 0, 50),
		UDim2.new(0.5, 0, 0, 98),
		32,
		winningTeam.TeamColor.Color,
		Enum.Font.GothamBold,
		Vector2.new(0.5, 0)
	).Name = "WinnerBanner"

	-- ── Gold divider line ─────────────────────────────────────────────────────
	local divider = makeFrame(bg, UDim2.new(0.8, 0, 0, 2), UDim2.new(0.5, 0, 0, 158), GOLD, 0, Vector2.new(0.5, 0))
	divider.Name = "Divider"

	-- ── Three-column content area ─────────────────────────────────────────────
	local content = makeFrame(bg, UDim2.new(1, 0, 0, 340), UDim2.new(0, 0, 0, 170), BG_COLOR, 1)
	content.Name = "Content"

	-- Separate stats into teams (preserve order — first two distinct team names found)
	local teamOrder: { string } = {}
	local teamMap: { [string]: { { name: string, teamColor: Color3, kills: number } } } = {}
	for _, entry in ipairs(stats) do
		if not teamMap[entry.teamName] then
			teamMap[entry.teamName] = {}
			table.insert(teamOrder, entry.teamName)
		end
		table.insert(teamMap[entry.teamName], entry)
	end
	-- Sort each team's players by kills descending
	for _, teamName in ipairs(teamOrder) do
		table.sort(teamMap[teamName], function(a, b) return a.kills > b.kills end)
	end

	local teamAName = teamOrder[1] or ""
	local teamBName = teamOrder[2] or ""
	local teamAPlayers = teamMap[teamAName] or {}
	local teamBPlayers = teamMap[teamBName] or {}

	-- Left column — Team A
	local leftCol = makeFrame(content, UDim2.new(0.35, -10, 1, 0), UDim2.new(0, 20, 0, 0), BG_COLOR, 1)
	leftCol.Name = "LeftColumn"
	local leftLayout = Instance.new("UIListLayout")
	leftLayout.Padding         = UDim.new(0, 6)
	leftLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	leftLayout.Parent          = leftCol

	-- Team A header
	if #teamAPlayers > 0 then
		makeLabel(
			leftCol,
			teamAName:upper(),
			UDim2.new(1, 0, 0, 28),
			UDim2.new(0, 0, 0, 0),
			18,
			teamAPlayers[1].teamColor,
			Enum.Font.GothamBold
		).LayoutOrder = 0
	end

	for i, entry in ipairs(teamAPlayers) do
		animatePlayerCard(buildPlayerCard(leftCol, i, entry.name, entry.kills, entry.teamColor), (i - 1) * CARD_STAGGER_DELAY)
	end

	-- Right column — Team B
	local rightCol = makeFrame(content, UDim2.new(0.35, -10, 1, 0), UDim2.new(0.65, -10, 0, 0), BG_COLOR, 1)
	rightCol.Name = "RightColumn"
	local rightLayout = Instance.new("UIListLayout")
	rightLayout.Padding         = UDim.new(0, 6)
	rightLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rightLayout.Parent          = rightCol

	if #teamBPlayers > 0 then
		makeLabel(
			rightCol,
			teamBName:upper(),
			UDim2.new(1, 0, 0, 28),
			UDim2.new(0, 0, 0, 0),
			18,
			teamBPlayers[1].teamColor,
			Enum.Font.GothamBold
		).LayoutOrder = 0
	end

	for i, entry in ipairs(teamBPlayers) do
		animatePlayerCard(buildPlayerCard(rightCol, i, entry.name, entry.kills, entry.teamColor), (i - 1) * CARD_STAGGER_DELAY)
	end

	-- Centre column — circular countdown ring
	local centreCol = makeFrame(
		content,
		UDim2.new(0, 120, 0, 120),
		UDim2.new(0.5, 0, 0.5, 0),
		CARD_BG,
		0,
		Vector2.new(0.5, 0.5)
	)
	centreCol.Name = "CountdownRing"

	local ringCorner = Instance.new("UICorner")
	ringCorner.CornerRadius = UDim.new(0.5, 0)
	ringCorner.Parent       = centreCol

	local ringStroke = Instance.new("UIStroke")
	ringStroke.Color     = GOLD
	ringStroke.Thickness = 5
	ringStroke.Parent    = centreCol

	local countdownLabel = makeLabel(
		centreCol,
		tostring(math.ceil(math.max(intermissionEndTime - Workspace:GetServerTimeNow(), 0))),
		UDim2.new(1, 0, 1, 0),
		UDim2.new(0, 0, 0, 0),
		32,
		WHITE,
		Enum.Font.GothamBold
	)
	countdownLabel.Name = "CountdownLabel"

	return screenGui, bg, countdownLabel
end

-- ── Show / hide helpers ───────────────────────────────────────────────────────
local function showGui(bg: Frame)
	TweenService:Create(bg, FADE_IN_INFO, { BackgroundTransparency = 0 }):Play()
	TweenService:Create(blur, BLUR_IN_INFO, { Size = 20 }):Play()
end

local function hideGui(screenGui: ScreenGui, bg: Frame)
	local fadeTween = TweenService:Create(bg, FADE_OUT_INFO, { BackgroundTransparency = 1 })
	TweenService:Create(blur, BLUR_OUT_INFO, { Size = 0 }):Play()
	fadeTween:Play()
	fadeTween.Completed:Connect(function()
		screenGui.Enabled = false
		screenGui:Destroy()
	end)
end

-- ── Main event handler ────────────────────────────────────────────────────────
intermissionStartRemote.OnClientEvent:Connect(function(
	winningTeam: Team,
	stats: { { name: string, teamName: string, teamColor: Color3, kills: number } },
	intermissionEndTime: number
)
	local ok, err = pcall(function()
		-- Input validation
		if not winningTeam then
			warn("[IntermissionGui] winningTeam is nil — skipping GUI")
			return
		end
		if type(stats) ~= "table" then
			warn("[IntermissionGui] stats is not a table (got", type(stats), ") — using empty table")
			stats = {}
		end
		if type(intermissionEndTime) ~= "number" then
			warn("[IntermissionGui] intermissionEndTime is not a number (got", type(intermissionEndTime), ") — skipping GUI")
			return
		end
		warn("[IntermissionGui] Building GUI — winner:", winningTeam.Name, "| stats:", #stats)

		-- Build fresh GUI each round
		local screenGui, bg, countdownLabel = buildGui(winningTeam, stats, intermissionEndTime)
		screenGui.Parent  = playerGui
		screenGui.Enabled = true

		showGui(bg)

		if currentCountdownConnection then
			currentCountdownConnection:Disconnect()
			currentCountdownConnection = nil
		end

		-- Server-time-driven countdown
		currentCountdownConnection = RunService.Heartbeat:Connect(function()
			local remaining = intermissionEndTime - Workspace:GetServerTimeNow()

			if remaining <= 0 then
				if currentCountdownConnection then
					currentCountdownConnection:Disconnect()
					currentCountdownConnection = nil
				end
				countdownLabel.Text = "0"
				hideGui(screenGui, bg)
			else
				countdownLabel.Text = tostring(math.ceil(remaining))
			end
		end)
	end)
	if not ok then
		warn("[IntermissionGui] ERROR in OnClientEvent:", err)
	end
end)
