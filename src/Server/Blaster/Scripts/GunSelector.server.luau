local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GunConfigs = require(ReplicatedStorage.Blaster.GunConfigs)
local Constants = require(ReplicatedStorage.Blaster.Constants)
local safePlayerAdded = require(ReplicatedStorage.Utility.safePlayerAdded)

local selectGunRemote = ReplicatedStorage.Blaster.Remotes:WaitForChild("SelectGun", 5)
if not selectGunRemote then
	warn("[GunSelector] SelectGun remote not found within 5 seconds — aborting")
	return
end

local selectedGuns = {}
local connections: { [Player]: { RBXScriptConnection } } = {}
local lastSelectTime: { [Player]: number } = {}

local function applyConfig(player: Player, gunName: string)
	local config = GunConfigs[gunName]
	if not config then return end

	local tool = (player.Backpack and player.Backpack:FindFirstChild("Blaster"))
		or (player.Character and player.Character:FindFirstChild("Blaster"))

	if not tool then return end

	for attributeName, value in config do
		tool:SetAttribute(attributeName, value)
	end
	-- Reset ammo to new magazine size and clear any reloading state
	tool:SetAttribute(Constants.AMMO_ATTRIBUTE, config.magazineSize)
	tool:SetAttribute(Constants.RELOADING_ATTRIBUTE, false)
end

local function onSelectGun(player: Player, gunName: unknown)
	if type(gunName) ~= "string" then
		warn("[GunSelector] gunName must be string, got", type(gunName))
		return
	end
	if #gunName == 0 or #gunName > 50 then
		warn("[GunSelector] gunName length invalid:", #gunName)
		return
	end
	if not GunConfigs[gunName] then
		warn("[GunSelector] gunName not in GunConfigs:", gunName)
		return
	end

	-- Rate limiting: enforce 100ms minimum between gun selections per player
	if lastSelectTime[player] and tick() - lastSelectTime[player] < 0.1 then
		warn("[GunSelector] Selection throttled for", player.Name)
		return
	end
	lastSelectTime[player] = tick()

	selectedGuns[player.UserId] = gunName
	applyConfig(player, gunName)
end

local function onCharacterAdded(player: Player)
	task.wait() -- let Backpack populate
	local saved = selectedGuns[player.UserId]
	-- Apply the saved gun config, or default to Pistol on first spawn
	applyConfig(player, saved or "Pistol")
end

local function onPlayerAdded(player: Player)
	local charConn = player.CharacterAdded:Connect(function()
		onCharacterAdded(player)
	end)
	connections[player] = { charConn }
end

selectGunRemote.OnServerEvent:Connect(onSelectGun)

safePlayerAdded(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player: Player)
	selectedGuns[player.UserId] = nil
	lastSelectTime[player] = nil
	if connections[player] then
		for _, conn in connections[player] do
			conn:Disconnect()
		end
		connections[player] = nil
	end
end)
