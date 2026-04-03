--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerScripts = player:WaitForChild("PlayerScripts")

local gameplayFolder = ReplicatedStorage:WaitForChild("Gameplay", 10)
if not gameplayFolder then
	warn("[GameplayScriptsBootstrap] Gameplay folder not found within 10s — aborting")
	return
end

local scriptsFolder = gameplayFolder:WaitForChild("Scripts", 10)
if not scriptsFolder then
	warn("[GameplayScriptsBootstrap] Gameplay scripts folder not found within 10s — aborting")
	return
end

local function mountClientScript(sourceScript: Instance): ()
	if not sourceScript:IsA("LocalScript") then
		return
	end

	if playerScripts:FindFirstChild(sourceScript.Name) then
		return
	end

	sourceScript:Clone().Parent = playerScripts
end

for _, child in scriptsFolder:GetChildren() do
	mountClientScript(child)
end
