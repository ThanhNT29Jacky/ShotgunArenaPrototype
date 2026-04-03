local Players = game:GetService("Players")

local function safePlayerAdded(callback: (Player) -> ()): RBXScriptConnection
	for _, player in Players:GetPlayers() do
		task.spawn(callback, player)
	end

	return Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(callback, player)
	end)
end

return safePlayerAdded
