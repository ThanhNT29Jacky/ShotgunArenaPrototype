local Knit = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Knit"))
local UserInputService = game:GetService("UserInputService")

local InputController = Knit.CreateController {
	Name = "InputController",
}

local actions: { [string]: (boolean) -> () } = {}

function InputController:KnitInit()
	-- Initialize controller
end

function InputController:KnitStart()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		local action = actions[tostring(input.KeyCode)]
		if action then
			action(true)
		end
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		local action = actions[tostring(input.KeyCode)]
		if action then
			action(false)
		end
	end)
end

function InputController:onAction(actionName: string, callback: (boolean) -> ()): ()
	actions[actionName] = callback
end

return InputController
