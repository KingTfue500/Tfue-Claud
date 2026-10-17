--!strict
-- Feder-Löser (gedämpfte Feder) für UI und Viewmodel.
-- Steifigkeit k und Dämpfung c, semi-implizites Euler mit Unterschritten.

export type Spring = {
	Position: number,
	Velocity: number,
	Target: number,
	Stiffness: number,
	Damping: number,
	Step: (self: Spring, dt: number) -> number,
	Impulse: (self: Spring, v: number) -> (),
}

export type Spring3 = {
	Position: Vector3,
	Velocity: Vector3,
	Target: Vector3,
	Stiffness: number,
	Damping: number,
	Step: (self: Spring3, dt: number) -> Vector3,
	Impulse: (self: Spring3, v: Vector3) -> (),
}

local MAX_SUBSTEP = 1 / 240

local Spring = {}

function Spring.new(initial: number, stiffness: number, damping: number): Spring
	local self = {
		Position = initial,
		Velocity = 0,
		Target = initial,
		Stiffness = stiffness,
		Damping = damping,
	} :: Spring

	function self.Step(s: Spring, dt: number): number
		local remaining = math.min(dt, 0.1)
		while remaining > 0 do
			local h = math.min(remaining, MAX_SUBSTEP)
			local force = -s.Stiffness * (s.Position - s.Target) - s.Damping * s.Velocity
			s.Velocity += force * h
			s.Position += s.Velocity * h
			remaining -= h
		end
		return s.Position
	end

	function self.Impulse(s: Spring, v: number)
		s.Velocity += v
	end

	return self
end

function Spring.new3(initial: Vector3, stiffness: number, damping: number): Spring3
	local self = {
		Position = initial,
		Velocity = Vector3.zero,
		Target = initial,
		Stiffness = stiffness,
		Damping = damping,
	} :: Spring3

	function self.Step(s: Spring3, dt: number): Vector3
		local remaining = math.min(dt, 0.1)
		while remaining > 0 do
			local h = math.min(remaining, MAX_SUBSTEP)
			local force = (s.Target - s.Position) * s.Stiffness - s.Velocity * s.Damping
			s.Velocity += force * h
			s.Position += s.Velocity * h
			remaining -= h
		end
		return s.Position
	end

	function self.Impulse(s: Spring3, v: Vector3)
		s.Velocity += v
	end

	return self
end

return Spring
