--[[
	Signal: a tiny in-process event, used to connect services without hard dependencies.

	local changed = Signal.new()
	local connection = changed:Connect(function(player, value) ... end)
	changed:Fire(player, 10)
	connection:Disconnect()
]]

export type Connection = {
	Disconnect: (self: Connection) -> (),
}

type Handler = {
	fn: (...any) -> (),
	connected: boolean,
}

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} :: { Handler } }, Signal)
end

function Signal:Connect(fn: (...any) -> ()): Connection
	local handler: Handler = { fn = fn, connected = true }
	table.insert(self._handlers, handler)

	local handlers = self._handlers
	return {
		Disconnect = function()
			if not handler.connected then
				return
			end
			handler.connected = false
			local index = table.find(handlers, handler)
			if index then
				table.remove(handlers, index)
			end
		end,
	} :: any
end

function Signal:Fire(...: any)
	-- Clone so handlers that disconnect during Fire do not skip their neighbours.
	for _, handler in table.clone(self._handlers) do
		if handler.connected then
			task.spawn(handler.fn, ...)
		end
	end
end

return Signal
