--!strict
-- Trove: sammelt Verbindungen, Instanzen, Threads und Funktionen und räumt sie gemeinsam auf

export type Trove = {
	Add: <T>(self: Trove, item: T) -> T,
	Connect: (self: Trove, signal: RBXScriptSignal, fn: (...any) -> ()) -> RBXScriptConnection,
	Clean: (self: Trove) -> (),
	Extend: (self: Trove) -> Trove,
}

local Trove = {}

local function cleanItem(item: any)
	local t = typeof(item)
	if t == "RBXScriptConnection" then
		(item :: RBXScriptConnection):Disconnect()
	elseif t == "Instance" then
		(item :: Instance):Destroy()
	elseif t == "thread" then
		local th = item :: thread
		if coroutine.status(th) ~= "dead" then
			pcall(task.cancel, th)
		end
	elseif t == "function" then
		(item :: () -> ())()
	elseif t == "table" then
		local tbl = item :: any
		if type(tbl.Clean) == "function" then
			tbl:Clean()
		elseif type(tbl.Destroy) == "function" then
			tbl:Destroy()
		elseif type(tbl.Disconnect) == "function" then
			tbl:Disconnect()
		end
	end
end

function Trove.new(): Trove
	local items: { any } = {}
	local self = {} :: Trove

	function self.Add<T>(_s: Trove, item: T): T
		table.insert(items, item)
		return item
	end

	function self.Connect(s: Trove, signal: RBXScriptSignal, fn: (...any) -> ()): RBXScriptConnection
		local c = signal:Connect(fn)
		s:Add(c)
		return c
	end

	function self.Clean(_s: Trove)
		local list = items
		items = {}
		for i = #list, 1, -1 do
			cleanItem(list[i])
		end
	end

	function self.Extend(s: Trove): Trove
		local sub = Trove.new()
		s:Add(sub)
		return sub
	end

	return self
end

return Trove
