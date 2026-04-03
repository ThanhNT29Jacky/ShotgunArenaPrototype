local playSoundFromSource = require(script.Parent.playSoundFromSource)

local random = Random.new()

local function playRandomSoundFromSource(soundTemplates: Folder, target: Instance)
	local sounds = soundTemplates:GetChildren()
	if #sounds == 0 then
		warn("[playRandomSoundFromSource] No sounds in folder: " .. soundTemplates:GetFullName())
		return
	end
	local sound = sounds[random:NextInteger(1, #sounds)]
	playSoundFromSource(sound, target)
end

return playRandomSoundFromSource
