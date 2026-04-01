local ServerScriptService = game:GetService("ServerScriptService")

local EnsureTeams = require(ServerScriptService.Gameplay.Scripts.EnsureTeams)

local ok, err = pcall(EnsureTeams.ensure)
if not ok then
	warn("[CreateTeams] Failed to ensure teams:", err)
end
