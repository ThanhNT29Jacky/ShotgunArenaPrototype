local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Teams = game:GetService("Teams")

local Constants = require(ReplicatedStorage.Gameplay.Constants)
local Scoring = require(script.Parent.Scoring)
local spawnCharacters = require(script.spawnCharacters)
local despawnCharacters = require(script.despawnCharacters)
local TeamAssigner = require(script.TeamAssigner)

local remotes = ReplicatedStorage.Gameplay.Remotes
local roundWinnerRemote = remotes.RoundWinner
local lobbyStatusRemote = remotes.LobbyStatus
local intermissionStartRemote = remotes.IntermissionStart

local MODES = {
	require(script.Parent.Modes.TDM),
}

local random = Random.new()
local MIN_PLAYERS = 1

-- Assign team each time a player's character loads so the balanced
-- round-robin stays correct across respawns.
local function onCharacterAdded(player: Player): ()
	local team = TeamAssigner.assignTeam(player)
	if team == "" then
		warn("[Rounds] TeamAssigner returned empty team for", player.Name)
	end
end

local function onPlayerAdded(player: Player): ()
	-- Assign team immediately so TeamCollisionFiltering sees it on CharacterAdded
	local team = TeamAssigner.assignTeam(player)
	if team == "" then
		warn("[Rounds] TeamAssigner returned empty team for", player.Name)
	end

	player.CharacterAdded:Connect(function()
		-- Re-assign on each respawn to maintain balanced teams
		onCharacterAdded(player)
	end)
end

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

-- Wait until at least MIN_PLAYERS players are connected.
-- Fires LobbyStatus remote with (currentCount, required) for the lobby UI.
local function waitForPlayers(): ()
	local function broadcastCount(): ()
		lobbyStatusRemote:FireAllClients(#Players:GetPlayers(), MIN_PLAYERS)
	end

	-- Already have enough players — broadcast once and return
	if #Players:GetPlayers() >= MIN_PLAYERS then
		broadcastCount()
		return
	end

	warn("[Rounds] Waiting for players — need", MIN_PLAYERS, "have", #Players:GetPlayers())

	local ready = false
	local connections: { RBXScriptConnection } = {}

	local function checkReady(): ()
		broadcastCount()
		if #Players:GetPlayers() >= MIN_PLAYERS then
			ready = true
		end
	end

	-- React immediately when players join or leave
	table.insert(connections, Players.PlayerAdded:Connect(checkReady))
	table.insert(
		connections,
		Players.PlayerRemoving:Connect(function()
			-- Defer so the player is removed from the list before we count
			task.defer(broadcastCount)
		end)
	)

	-- Poll as a safety net
	while not ready do
		task.wait(1)
		if #Players:GetPlayers() >= MIN_PLAYERS then
			ready = true
		end
		broadcastCount()
	end

	-- Disconnect event listeners
	for _, conn in connections do
		conn:Disconnect()
	end

	broadcastCount() -- final broadcast signals lobby is closing / round starting
	warn("[Rounds] Minimum players reached — starting round")
end

local function startRoundLoopAsync()
	while true do
		local ok, err = xpcall(function()
			-- Wait until minimum players are connected
			waitForPlayers()

			-- Reset scores
			Scoring.resetScores()

			-- Pick mode
			local mode = MODES[random:NextInteger(1, #MODES)]
			local timer = mode.timer

			-- Start the mode, passing in a callback to be called if it finishes early
			local roundFinished = false
			mode.start(function()
				roundFinished = true
			end)

			-- Spawn characters
			Players.CharacterAutoLoads = true
			spawnCharacters()

			-- Countdown timer uses server time so the HUD stays aligned.
			local roundEndTime = Workspace:GetServerTimeNow() + timer
			Workspace:SetAttribute(Constants.TIMER_ATTRIBUTE, timer)

			while timer > 0 and not roundFinished do
				local remaining = math.max(0, math.ceil(roundEndTime - Workspace:GetServerTimeNow()))
				if remaining ~= timer then
					timer = remaining
					Workspace:SetAttribute(Constants.TIMER_ATTRIBUTE, timer)
				end

				if timer <= 0 then
					break
				end

				task.wait(0.1)
			end

			Workspace:SetAttribute(Constants.TIMER_ATTRIBUTE, 0)

			-- End the mode
			mode.stop()

			-- Display winning team
			local teams = Teams:GetTeams()
			table.sort(teams, function(teamA: Team, teamB: Team)
				return Scoring.getTeamScore(teamA) > Scoring.getTeamScore(teamB)
			end)

			local winningTeam = teams[1]
			if not winningTeam then
				warn("[Rounds] No winning team found — Teams service returned empty. Skipping intermission.")
				task.wait(Constants.INTERMISSION_TIME)
				return
			end
			roundWinnerRemote:FireAllClients(winningTeam)

			-- Disable spawning
			Players.CharacterAutoLoads = false
			despawnCharacters()

			-- Collect stats and signal the COMBAT REPORT intermission screen
			local stats = Scoring.getPlayerStats()
			warn("[Rounds] Firing IntermissionStart — winningTeam:", winningTeam.Name, "| stats count:", #stats)
			local intermissionEndTime = Workspace:GetServerTimeNow() + Constants.INTERMISSION_TIME
			intermissionStartRemote:FireAllClients(winningTeam, stats, intermissionEndTime)

			-- Wait for intermission
			task.wait(Constants.INTERMISSION_TIME)
		end, function(e)
			return e .. "\n" .. debug.traceback()
		end)
		if not ok then
			warn("[Rounds] Round iteration error — restarting in 5s:", err)
			task.wait(5)
		end
	end
end

task.spawn(startRoundLoopAsync)
