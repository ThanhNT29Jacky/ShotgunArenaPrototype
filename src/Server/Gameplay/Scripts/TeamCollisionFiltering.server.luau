local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local disconnectAndClear = require(ReplicatedStorage.Utility.disconnectAndClear)

local connections: { [string]: { RBXScriptConnection } } = {}

-- When a new team is added, we'll register a new collision group for that team that doesn't collide with itself.
-- This allows players on the same team to walk and shoot through each other, as well as block other teams from
-- walking through their spawn protection forcefields.
local function onTeamAdded(team: Team)
	local collisionGroup = team.Name

	if not PhysicsService:IsCollisionGroupRegistered(collisionGroup) then
		PhysicsService:RegisterCollisionGroup(collisionGroup)
		PhysicsService:CollisionGroupSetCollidable(collisionGroup, collisionGroup, false)
	end

	if not connections[team.Name] then
		connections[team.Name] = {}
	end

	-- Assign the new collision group to anything tagged with <team.Name>Forcefield
	local forcefieldTag = `{team.Name}Forcefield`

	table.insert(
		connections[team.Name],
		CollectionService:GetInstanceAddedSignal(forcefieldTag):Connect(function(instance: Instance)
			if instance:IsA("BasePart") then
				instance.CollisionGroup = collisionGroup
			end
		end)
	)

	for _, instance in CollectionService:GetTagged(forcefieldTag) do
		if instance:IsA("BasePart") then
			instance.CollisionGroup = collisionGroup
		end
	end
end

-- Deregister collision groups when the associated team is removed
local function onTeamRemoved(team: Team)
	local collisionGroup = team.Name

	if PhysicsService:IsCollisionGroupRegistered(collisionGroup) then
		PhysicsService:UnregisterCollisionGroup(collisionGroup)
	end

	if connections[team.Name] then
		disconnectAndClear(connections[team.Name])
		connections[team.Name] = nil
	end
end

-- Assign team collision groups to characters when they spawn so they can walk through other
-- characters on their team as well as their spawn protection forcefields.
local function onCharacterAdded(character: Model)
	local player = Players:GetPlayerFromCharacter(character)
	assert(player, `{character} has no player!`)

	if player.Neutral or not player.Team then
		return
	end

	local collisionGroup = player.Team.Name

	character.DescendantAdded:Connect(function(instance: Instance)
		if instance:IsA("BasePart") then
			instance.CollisionGroup = collisionGroup
		end
	end)

	for _, instance in character:GetDescendants() do
		if instance:IsA("BasePart") then
			instance.CollisionGroup = collisionGroup
		end
	end
end

local function onPlayerAdded(player: Player)
	if player.Character then
		onCharacterAdded(player.Character)
	end

	player.CharacterAdded:Connect(onCharacterAdded)
end

local function initialize()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Teams.ChildAdded:Connect(onTeamAdded)
	Teams.ChildRemoved:Connect(onTeamRemoved)

	for _, team in Teams:GetChildren() do
		onTeamAdded(team)
	end
end

initialize()
