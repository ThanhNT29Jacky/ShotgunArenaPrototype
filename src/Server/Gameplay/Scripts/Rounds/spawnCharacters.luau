local Players = game:GetService("Players")

local function spawnCharacters()
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			player:LoadCharacter()
		end)
	end
end

return spawnCharacters
