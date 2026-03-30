local Knit = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Knit"))

local HUDController = Knit.CreateController {
	Name = "HUDController",
}

function HUDController:KnitInit()
	-- Initialize controller
end

function HUDController:KnitStart()
	local CombatService = Knit.GetService("CombatService")

	CombatService.Client.TakeDamage:Connect(function(victimPlayer)
		print("HUD: Player took damage", victimPlayer.Name)
	end)
end

return HUDController
