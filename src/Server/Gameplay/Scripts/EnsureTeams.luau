local Teams = game:GetService("Teams")

local TEAM_DEFINITIONS: { { name: string, color: BrickColor } } = {
	{ name = "Pink", color = BrickColor.new("Hot pink") },
	{ name = "Green", color = BrickColor.new("Bright green") },
}

local EnsureTeams = {}

-- Creates the "Pink" and "Green" Team objects in the Teams service if they do not
-- already exist. Safe to call multiple times — idempotent.
function EnsureTeams.ensure(): ()
	for _, definition in TEAM_DEFINITIONS do
		if not Teams:FindFirstChild(definition.name) then
			local team = Instance.new("Team")
			team.Name = definition.name
			team.TeamColor = definition.color
			team.AutoAssignable = false
			team.Parent = Teams
		end
	end
end

return EnsureTeams
