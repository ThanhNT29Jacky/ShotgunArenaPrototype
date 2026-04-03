local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Blaster.Constants)
local lerp = require(ReplicatedStorage.Utility.lerp)

local camera = Workspace.CurrentCamera

-- Absolute offset tracking
local recoilX  = 0   -- accumulated vertical offset (rad), 0..maxX, monotonic during burst
local recoilY  = 0   -- accumulated horizontal offset (rad), -maxY..maxY
local appliedX = 0   -- what has been delta-applied to camera so far
local appliedY = 0

-- Burst state
local isFiring     = false
local firingTime   = 0           -- seconds into current burst
local lastShotTime = -math.huge  -- for burst timeout detection

-- Per-gun config (updated each shot)
local maxX  = 0
local maxY  = 0
local accel = 1  -- accelerateTime; guarded against 0

-- Recovery + FOV
local recoverySpeed = Constants.RECOIL_STOP_SPEED
local zoom = 0

-- Scope zoom (0 = normal, negative = zoomed in)
local scopeZoom = 0
local scopeZoomTarget = 0
local SCOPE_ZOOM_LERP_SPEED = 10

local function onRenderStepped(dt: number)
	local now = tick()

	-- Burst timeout: end burst if no shot within threshold
	if isFiring and (now - lastShotTime >= Constants.RECOIL_BURST_TIMEOUT) then
		isFiring = false
	end

	if isFiring then
		firingTime += dt
		-- X: continuous linear ramp 0 → maxX over accel seconds; never decreases during burst
		local t = math.clamp(firingTime / accel, 0, 1)
		recoilX = math.clamp(t * maxX, recoilX, maxX)
	else
		-- Recovery: both offsets lerp back to 0
		recoilX = lerp(recoilX, 0, math.min(dt * recoverySpeed, 1))
		recoilY = lerp(recoilY, 0, math.min(dt * recoverySpeed, 1))
	end

	-- Apply DELTA to camera (absolute-offset → incremental CFrame API)
	local deltaX = recoilX - appliedX
	local deltaY = recoilY - appliedY
	camera.CFrame *= CFrame.Angles(deltaX, deltaY, 0)
	appliedX = recoilX
	appliedY = recoilY

	-- FOV zoom (recoil bump + scope zoom)
	scopeZoom = lerp(scopeZoom, scopeZoomTarget, math.min(dt * SCOPE_ZOOM_LERP_SPEED, 1))
	camera.FieldOfView = Constants.RECOIL_DEFAULT_FOV + zoom + scopeZoom
	zoom = lerp(zoom, 0, math.min(dt * Constants.RECOIL_ZOOM_RETURN_SPEED, 1))
end

local CameraRecoiler = {}

function CameraRecoiler.setRecoverySpeed(speed: number)
	recoverySpeed = speed
end

function CameraRecoiler.setScopeZoom(target: number)
	scopeZoomTarget = target
end

-- maxXRad, maxYRad : max angular offsets in radians
-- accelerateTime   : seconds to ramp from 0 to full contribution
-- ySign            : +1 or -1, randomised by the caller
function CameraRecoiler.recoil(maxXRad: number, maxYRad: number, accelerateTime: number, ySign: number)
	lastShotTime = tick()
	zoom = 1

	if not isFiring then
		-- New burst: start fresh
		isFiring   = true
		firingTime = 0
		recoilX    = 0
		recoilY    = 0
		appliedX   = 0
		appliedY   = 0
	end

	-- Store per-gun config (updated each shot so gun-switching mid-burst works)
	maxX  = maxXRad
	maxY  = maxYRad
	accel = math.max(accelerateTime, 0.001)

	-- Y: per-shot oscillation scaled by current ramp position
	-- Step ramps from ~2.5% of maxY at burst start to 25% at full acceleration
	local t     = math.clamp(firingTime / accel, 0, 1)
	local yStep = maxY * 0.25 * (0.1 + 0.9 * t)
	recoilY     = math.clamp(recoilY + ySign * yStep, -maxY, maxY)
end

-- apply recoil after aim assist
RunService:BindToRenderStep(Constants.RECOIL_BIND_NAME, Enum.RenderPriority.Camera.Value + 2, onRenderStepped)

return CameraRecoiler
