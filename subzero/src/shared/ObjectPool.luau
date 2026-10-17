--!strict
-- ObjectPool: Instanzen (Partikel, Sounds, Decals, Fackeln) wiederverwenden.
-- Wird vorab gefüllt; in der Runde wird nichts neu erzeugt, außer der Pool ist erschöpft
-- und Steal = true: dann wird das älteste aktive Objekt zurückgeholt.

export type Pool<T> = {
	Get: (self: Pool<T>) -> T?,
	Release: (self: Pool<T>, obj: T) -> (),
	ReleaseAll: (self: Pool<T>) -> (),
	ActiveCount: (self: Pool<T>) -> number,
	ForEachActive: (self: Pool<T>, fn: (T) -> ()) -> (),
}

local ObjectPool = {}

function ObjectPool.new<T>(size: number, create: () -> T, reset: (T) -> (), steal: boolean?): Pool<T>
	local free: { T } = {}
	local active: { T } = {} -- in Reihenfolge der Ausgabe (ältestes zuerst)

	for _ = 1, size do
		local obj = create()
		reset(obj)
		table.insert(free, obj)
	end

	local self = {} :: Pool<T>

	function self.Get(_s: Pool<T>): T?
		local obj = table.remove(free)
		if obj == nil then
			if steal and #active > 0 then
				obj = table.remove(active, 1)
				if obj ~= nil then
					reset(obj)
				end
			else
				return nil
			end
		end
		if obj ~= nil then
			table.insert(active, obj)
		end
		return obj
	end

	function self.Release(_s: Pool<T>, obj: T)
		local idx = table.find(active, obj)
		if idx then
			table.remove(active, idx)
			reset(obj)
			table.insert(free, obj)
		end
	end

	function self.ReleaseAll(s: Pool<T>)
		local list = table.clone(active)
		for _, obj in list do
			s:Release(obj)
		end
	end

	function self.ActiveCount(_s: Pool<T>): number
		return #active
	end

	function self.ForEachActive(_s: Pool<T>, fn: (T) -> ())
		for _, obj in table.clone(active) do
			fn(obj)
		end
	end

	return self
end

return ObjectPool
