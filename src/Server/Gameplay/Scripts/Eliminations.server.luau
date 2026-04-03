local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local blasterEvents = ServerScriptService.Blaster.Events
local eliminatedEvent = blasterEvents.Eliminated

local remotes = ReplicatedStorage.Gameplay.Remotes
local eliminatedRemote = remotes.Eliminated

local function onEliminated(player: Player, eliminatedHumanoid: Humanoid)
	-- When a player gets an elimination, fire a remote to tell them to display an elimination UI
	local eliminatedCharacter = eliminatedHumanoid.Parent
	if not eliminatedCharacter then
		return
	end
	local eliminatedPlayer = Players:GetPlayerFromCharacter(eliminatedCharacter)
	local name = if eliminatedPlayer then eliminatedPlayer.DisplayName else eliminatedCharacter.Name

	eliminatedRemote:FireClient(player, name)
end

eliminatedEvent.Event:Connect(function(player: Player, eliminatedHumanoid: Humanoid)
	local ok, err = xpcall(onEliminated, function(e: string): string
		warn("[Eliminations] onEliminated error:", e, debug.traceback())
		return e
	end, player, eliminatedHumanoid)
end)
