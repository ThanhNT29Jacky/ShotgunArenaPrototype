local Knit = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Knit"))

-- Require all controllers
local Controllers = script.Parent:FindFirstChild("Controllers")
if Controllers then
	for _, module in pairs(Controllers:GetChildren()) do
		if module:IsA("ModuleScript") then
			require(module)
		end
	end
end

-- Start Knit
Knit.Start():catch(warn)
