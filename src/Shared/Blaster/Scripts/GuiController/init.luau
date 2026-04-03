local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Blaster.Constants)
local GameplayConstants = require(ReplicatedStorage.Gameplay.Constants)
local InputCategorizer = require(script.Parent.InputCategorizer)
local disconnectAndClear = require(ReplicatedStorage.Utility.disconnectAndClear)
local playSoundFromSource = require(ReplicatedStorage.Blaster.Utility.playSoundFromSource)

local player = Players.LocalPlayer
local playerGui = player.PlayerGui
local blasterGuiTemplate = script.BlasterGui
local reticleGuiTemplate = script.ReticleGui
local hitmarkerSound = script.Hitmarker
local audioTarget = SoundService.Audio.Busses.UI.AudioCompressor

local AMMO_TEXT_FORMAT_STRING = `<font transparency="0.5">%s</font>%s`

local GuiController = {}
GuiController.__index = GuiController

function GuiController.new(blaster: Tool)
	local magazineSize = blaster:GetAttribute(Constants.MAGAZINE_SIZE_ATTRIBUTE)
	local leadingZeros = #tostring(magazineSize)

	local blasterGui = blasterGuiTemplate:Clone()
	blasterGui.Blaster.IconLabel.Image = blaster.TextureId
	blasterGui.Blaster.Ammo.MagazineLabel.Text = `/{magazineSize}`
	blasterGui.Enabled = false
	blasterGui.Parent = playerGui

	local reticleGui = reticleGuiTemplate:Clone()
	reticleGui.Enabled = false
	reticleGui.Parent = playerGui

	-- Build scope overlay inside reticleGui
	local SCOPE_R = 150 -- half-size of the circular opening in pixels

	local scopeOverlay = Instance.new("CanvasGroup")
	scopeOverlay.Name = "ScopeOverlay"
	scopeOverlay.BackgroundTransparency = 1
	scopeOverlay.GroupTransparency = 1
	scopeOverlay.Size = UDim2.fromScale(1, 1)
	scopeOverlay.ZIndex = 10
	scopeOverlay.Parent = reticleGui

	local function makeBar(name, size, position)
		local bar = Instance.new("Frame")
		bar.Name = name
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BackgroundTransparency = 0
		bar.BorderSizePixel = 0
		bar.Size = size
		bar.Position = position
		bar.ZIndex = 10
		bar.Parent = scopeOverlay
	end

	makeBar("TopBar",    UDim2.new(1, 0, 0.5, -SCOPE_R), UDim2.new(0, 0, 0, 0))
	makeBar("BottomBar", UDim2.new(1, 0, 0.5, -SCOPE_R), UDim2.new(0, 0, 0.5, SCOPE_R))
	makeBar("LeftBar",   UDim2.new(0.5, -SCOPE_R, 0, SCOPE_R * 2), UDim2.new(0, 0, 0.5, -SCOPE_R))
	makeBar("RightBar",  UDim2.new(0.5, -SCOPE_R, 0, SCOPE_R * 2), UDim2.new(0.5, SCOPE_R, 0.5, -SCOPE_R))

	-- Circular scope ring sitting at the edge of the opening
	local scopeRing = Instance.new("Frame")
	scopeRing.Name = "ScopeRing"
	scopeRing.BackgroundTransparency = 1
	scopeRing.Size = UDim2.fromOffset(SCOPE_R * 2, SCOPE_R * 2)
	scopeRing.AnchorPoint = Vector2.new(0.5, 0.5)
	scopeRing.Position = UDim2.fromScale(0.5, 0.5)
	scopeRing.ZIndex = 11
	scopeRing.Parent = scopeOverlay
	local ringCorner = Instance.new("UICorner")
	ringCorner.CornerRadius = UDim.new(0.5, 0)
	ringCorner.Parent = scopeRing
	local ringStroke = Instance.new("UIStroke")
	ringStroke.Color = Color3.fromRGB(200, 200, 200)
	ringStroke.Thickness = 2
	ringStroke.Parent = scopeRing

	-- Crosshair lines
	local lineColor = Color3.fromRGB(200, 200, 200)
	local function makeLine(name, size)
		local line = Instance.new("Frame")
		line.Name = name
		line.BackgroundColor3 = lineColor
		line.BorderSizePixel = 0
		line.Size = size
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromScale(0.5, 0.5)
		line.ZIndex = 12
		line.Parent = scopeRing
	end
	makeLine("HLine", UDim2.new(0.85, 0, 0, 1))
	makeLine("VLine", UDim2.new(0, 1, 0.85, 0))
	local centerDot = Instance.new("Frame")
	centerDot.Name = "CenterDot"
	centerDot.BackgroundColor3 = lineColor
	centerDot.BorderSizePixel = 0
	centerDot.Size = UDim2.fromOffset(3, 3)
	centerDot.AnchorPoint = Vector2.new(0.5, 0.5)
	centerDot.Position = UDim2.fromScale(0.5, 0.5)
	centerDot.ZIndex = 13
	centerDot.Parent = scopeRing
	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(0.5, 0)
	dotCorner.Parent = centerDot

	local scaleTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local transparencyTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local hitmarkerScaleTween = TweenService:Create(reticleGui.Hitmarker.UIScale, scaleTweenInfo, { Scale = 1 })
	local hitmarkerTransparencyTween =
		TweenService:Create(reticleGui.Hitmarker, transparencyTweenInfo, { GroupTransparency = 1 })

	local self = {
		blaster = blaster,
		blasterGui = blasterGui,
		reticleGui = reticleGui,
		hitmarkerScaleTween = hitmarkerScaleTween,
		hitmarkerTransparencyTween = hitmarkerTransparencyTween,
		scopeOverlay = scopeOverlay,
		enabled = false,
		leadingZeros = leadingZeros,
		ammo = 0,
		reloading = false,
		connections = {},
	}
	setmetatable(self, GuiController)
	self:initialize()
	return self
end

function GuiController:initialize()
	table.insert(
		self.connections,
		self.blasterGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:updateScale()
		end)
	)

	table.insert(
		self.connections,
		InputCategorizer.lastInputCategoryChanged:Connect(function()
			self:updateAlignment()
		end)
	)

	self:updateScale()
	self:updateAlignment()
end

function GuiController:updateScale()
	-- Update UI size. This is the same logic used by the default touch controls
	local minScreenSize = math.min(self.blasterGui.AbsoluteSize.X, self.blasterGui.AbsoluteSize.Y)
	local isSmallScreen = minScreenSize < GameplayConstants.UI_SMALL_SCREEN_THRESHOLD
	self.blasterGui.UIScale.Scale = if isSmallScreen then GameplayConstants.UI_SMALL_SCREEN_SCALE else 1
end

function GuiController:updateAlignment()
	local lastInputCategory = InputCategorizer.getLastInputCategory()
	if lastInputCategory == InputCategorizer.InputCategory.Touch then
		-- Align the blaster UI to the center of the screen, since the touch controls cover the bottom right corner
		self.blasterGui.Blaster.AnchorPoint = Vector2.new(0.5, 1)
		-- Slight vertical offset to account for the backpack UI
		self.blasterGui.Blaster.Position = UDim2.new(0.5, 0, 1, -65)
	else
		self.blasterGui.Blaster.AnchorPoint = Vector2.new(1, 1)
		self.blasterGui.Blaster.Position = UDim2.fromScale(1, 1)
	end
end

function GuiController:updateAmmoText()
	local zeroText = ""
	local ammoText = ""

	if self.reloading then
		zeroText = string.rep("-", self.leadingZeros)
	else
		ammoText = tostring(self.ammo)
		local numZeros = self.leadingZeros - #ammoText
		if numZeros > 0 then
			-- Add leading zeros to the ammo text, using rich text to give them a higher transparency
			zeroText = string.rep("0", numZeros)
		end
	end

	self.blasterGui.Blaster.Ammo.AmmoLabel.Text = string.format(AMMO_TEXT_FORMAT_STRING, zeroText, ammoText)
end

function GuiController:setAmmo(ammo: number)
	self.ammo = ammo
	self:updateAmmoText()
end

function GuiController:setReloading(reloading: boolean)
	self.reloading = reloading
	self:updateAmmoText()
end

function GuiController:showScope()
	TweenService:Create(
		self.scopeOverlay,
		TweenInfo.new(Constants.SCOPE_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ GroupTransparency = 0 }
	):Play()
	self.reticleGui.Reticle.Visible = false
end

function GuiController:hideScope()
	TweenService:Create(
		self.scopeOverlay,
		TweenInfo.new(Constants.SCOPE_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ GroupTransparency = 1 }
	):Play()
	self.reticleGui.Reticle.Visible = true
end

function GuiController:showHitmarker()
	-- Slightly delay the hitmarker sound so it doesn't overlap the shooting sound
	task.delay(Constants.HITMARKER_SOUND_DELAY, function()
		playSoundFromSource(hitmarkerSound, audioTarget)
	end)

	if self.hitmarkerScaleTween.PlaybackState == Enum.PlaybackState.Playing then
		self.hitmarkerScaleTween:Cancel()
	end
	if self.hitmarkerTransparencyTween.PlaybackState == Enum.PlaybackState.Playing then
		self.hitmarkerTransparencyTween:Cancel()
	end

	self.reticleGui.Hitmarker.GroupTransparency = 0
	self.reticleGui.Hitmarker.UIScale.Scale = 2

	self.hitmarkerScaleTween:Play()
	self.hitmarkerTransparencyTween:Play()
end

function GuiController:enable()
	if self.enabled then
		return
	end
	self.enabled = true
	self.blasterGui.Enabled = true
	self.reticleGui.Enabled = true

	UserInputService.MouseIconEnabled = false
end

function GuiController:disable()
	if not self.enabled then
		return
	end
	self.enabled = false
	self.blasterGui.Enabled = false
	self.reticleGui.Enabled = false
	self.scopeOverlay.GroupTransparency = 1
	self.reticleGui.Reticle.Visible = true

	UserInputService.MouseIconEnabled = true
end

function GuiController:destroy()
	self:disable()
	disconnectAndClear(self.connections)
	self.blasterGui:Destroy()
	self.reticleGui:Destroy()
end

return GuiController
