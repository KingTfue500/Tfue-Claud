--!strict
-- Einfaches, typisiertes Signal (Ereignis) ohne Roblox-Instanzen

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	DisconnectAll: (self: Signal<T...>) -> (),
}

local Signal = {}

function Signal.new<T...>(): Signal<T...>
	local handlers: { [Connection]: (T...) -> () } = {}
	local self = {} :: Signal<T...>

	function self.Connect(_s: Signal<T...>, fn: (T...) -> ()): Connection
		local conn = { Connected = true } :: Connection
		function conn.Disconnect(c: Connection)
			c.Connected = false
			handlers[c] = nil
		end
		handlers[conn] = fn
		return conn
	end

	function self.Once(s: Signal<T...>, fn: (T...) -> ()): Connection
		local conn: Connection
		conn = s:Connect(function(...: T...)
			conn:Disconnect()
			fn(...)
		end)
		return conn
	end

	function self.Fire(_s: Signal<T...>, ...: T...)
		-- Kopie, damit Handler sich während Fire trennen dürfen
		local list: { (T...) -> () } = {}
		for _, fn in handlers do
			table.insert(list, fn)
		end
		for _, fn in list do
			task.spawn(fn, ...)
		end
	end

	function self.Wait(s: Signal<T...>): T...
		local thread = coroutine.running()
		s:Once(function(...: T...)
			task.spawn(thread, ...)
		end)
		return coroutine.yield()
	end

	function self.DisconnectAll(_s: Signal<T...>)
		for conn in handlers do
			conn.Connected = false
		end
		table.clear(handlers)
	end

	return self
end

return Signal
