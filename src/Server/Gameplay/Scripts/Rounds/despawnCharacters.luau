local Players = game:GetService("Players")

local function despawnCharacters()
	for _, player in Players:GetPlayers() do
		if player.Character then
			player.Character:Destroy()
			-- Set the character to nil so that the client control scripts don't keep trying
			-- to control it (which results in warning spam in the output).
			player.Character = nil
		end
	end
end

return despawnCharacters
