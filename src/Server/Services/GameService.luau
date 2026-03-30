local Knit = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Knit"))

local GameService = Knit.CreateService {
	Name = "GameService",
}

function GameService:KnitInit()
	-- Initialize service
end

function GameService:KnitStart()
	-- Start service
end

return GameService
