--!strict

local CooldownService = {}

local lastUseByPlayer: { [number]: { [string]: number } } = {}

function CooldownService.consume(player: Player, key: string, duration: number): boolean
	local now = os.clock()
	local userCooldowns = lastUseByPlayer[player.UserId]
	if not userCooldowns then
		userCooldowns = {}
		lastUseByPlayer[player.UserId] = userCooldowns
	end

	local lastUse = userCooldowns[key]
	if lastUse and now - lastUse < duration then
		return false
	end

	userCooldowns[key] = now
	return true
end

function CooldownService.clearPlayer(player: Player)
	lastUseByPlayer[player.UserId] = nil
end

return table.freeze(CooldownService)
