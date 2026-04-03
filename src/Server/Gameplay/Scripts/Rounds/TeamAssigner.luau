--!strict

--[[
	TeamAssigner — assigns a player to the team with the fewest players (balanced round-robin).

	Usage:
		local TeamAssigner = require(script.Parent.TeamAssigner)
		local teamName = TeamAssigner.assignTeam(player)   --> "Pink" | "Green"

	The assignment is applied via player.Team (Roblox native API) so that all downstream
	systems — canPlayerDamageHumanoid, TeamCollisionFiltering, Scoring — automatically see it.

	CollectionService tags ("Team_<name>") are also added so external systems can query
	team membership without iterating Teams:GetPlayers().
]]

local CollectionService = game:GetService("CollectionService")
local Teams = game:GetService("Teams")

-- ─── Types ───────────────────────────────────────────────────────────────────

type TeamInfo = {
	team: Team,
	name: string,
	tag: string,
}

-- ─── Module ──────────────────────────────────────────────────────────────────

local TeamAssigner = {}

--- Remove all existing team tags from a player so re-assignment is clean.
local function clearTeamTags(player: Player): ()
	for _, team in Teams:GetTeams() do
		local tag = "Team_" .. team.Name
		if CollectionService:HasTag(player, tag) then
			CollectionService:RemoveTag(player, tag)
		end
	end
end

--- Return the Team object with the fewest current players.
--- Ties are broken by iterating order (stable for 2-team games).
local function pickSmallestTeam(): Team?
	local teams = Teams:GetTeams()
	if #teams == 0 then
		warn("[TeamAssigner] No teams found in Teams service.")
		return nil
	end

	local smallest: Team = teams[1]
	local smallestCount: number = #teams[1]:GetPlayers()

	for i = 2, #teams do
		local count = #teams[i]:GetPlayers()
		if count < smallestCount then
			smallest = teams[i]
			smallestCount = count
		end
	end

	return smallest
end

--- Assign `player` to the team with the fewest players.
---
--- Returns the name of the assigned team, or an empty string if no teams exist.
---
--- Side effects:
---   - Sets `player.Team` to the chosen Team object.
---   - Removes any existing "Team_*" CollectionService tags from the player.
---   - Adds a "Team_<name>" CollectionService tag for the chosen team.
function TeamAssigner.assignTeam(player: Player): string
	local team = pickSmallestTeam()
	if not team then
		return ""
	end

	-- Clear previous team tags before re-assigning
	clearTeamTags(player)

	-- Assign via Roblox's native Team property so all engine systems
	-- (damage checks, collision filtering, leaderboards) see the change.
	player.Team = team

	-- Mirror assignment as a CollectionService tag for easy external querying.
	CollectionService:AddTag(player, "Team_" .. team.Name)

	return team.Name
end

return TeamAssigner
