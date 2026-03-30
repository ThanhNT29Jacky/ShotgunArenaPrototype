local Knit = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Knit"))
local Players = game:GetService("Players")

local PlayerService = Knit.CreateService {
	Name = "PlayerService",
}

function PlayerService:KnitInit()
	-- Initialize service
end

function PlayerService:KnitStart()
	-- Start service
	Players.PlayerAdded:Connect(function(player)
		-- Handle player joined
	end)

	Players.PlayerRemoving:Connect(function(player)
		-- Handle player left
	end)
end

return PlayerService
