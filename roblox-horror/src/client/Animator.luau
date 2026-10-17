-- Client-side procedural animation, so it's smooth and costs the server nothing:
--  * the monster's walk / chase / attack poses and head twitches
--  * swinging chandeliers, lamps, meat hooks and the clock pendulum ("Swing")
--  * the rocking chair and rocking horse ("Rock")
--  * floating keys ("Spin")
--  * doll and statue heads that turn to stare at you ("Watcher")
--  * the wardrobe that rattles ("Rattle")

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Animator = {}

local camera = workspace.CurrentCamera

type Tracked = { inst: Instance, base: CFrame, phase: number }
local tracked: { [string]: { [Instance]: Tracked } } = {}

local function track(tag: string, getBase: (Instance) -> CFrame?)
	local set = {}
	tracked[tag] = set
	local function add(inst: Instance)
		local base = getBase(inst)
		if base then
			set[inst] = { inst = inst, base = base, phase = math.random() * 10 }
		end
	end
	for _, inst in CollectionService:GetTagged(tag) do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(inst)
		set[inst] = nil
	end)
end

local function modelPivot(inst: Instance): CFrame?
	if inst:IsA("Model") then
		return inst:GetPivot()
	end
	return nil
end

local function partCFrame(inst: Instance): CFrame?
	if inst:IsA("BasePart") then
		return inst.CFrame
	end
	return nil
end

----------------------------------------------------------------------------------------------------
-- Monster
----------------------------------------------------------------------------------------------------

local twitch = CFrame.identity
local nextTwitch = 0

local function animateMonster(monster: Model, t: number)
	local root = monster:FindFirstChild("HumanoidRootPart") :: BasePart?
	local torso = monster:FindFirstChild("Torso")
	if not root or not torso then
		return
	end
	local motors = {
		root = root:FindFirstChild("Root") :: Motor6D?,
		lHip = root:FindFirstChild("LeftHip") :: Motor6D?,
		rHip = root:FindFirstChild("RightHip") :: Motor6D?,
		neck = torso:FindFirstChild("Neck") :: Motor6D?,
		lArm = torso:FindFirstChild("LeftShoulder") :: Motor6D?,
		rArm = torso:FindFirstChild("RightShoulder") :: Motor6D?,
	}
	if not (motors.root and motors.lHip and motors.rHip and motors.neck and motors.lArm and motors.rArm) then
		return
	end

	local state = monster:GetAttribute("State")
	local v = root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local stride = math.clamp(speed / 10, 0, 1.3)
	local phase = t * (3 + speed * 0.42)
	local s = math.sin(phase)

	-- every so often the head snaps to a random angle, like a broken neck
	if t > nextTwitch then
		nextTwitch = t + (state == "Chase" and 0.15 or math.random(8, 30) / 10)
		twitch = CFrame.Angles((math.random() - 0.5) * 0.6, (math.random() - 0.5) * 1.2, (math.random() - 0.5) * 1.4)
	end

	motors.lHip.Transform = CFrame.Angles(s * 0.75 * stride, 0, 0)
	motors.rHip.Transform = CFrame.Angles(-s * 0.75 * stride, 0, 0)

	if state == "Attack" then
		local lunge = math.min(1, (t * 4) % 4)
		motors.root.Transform = CFrame.Angles(-0.45, 0, 0)
		motors.lArm.Transform = CFrame.Angles(2.7 - lunge * 0.6, 0, -0.3)
		motors.rArm.Transform = CFrame.Angles(2.7 - lunge * 0.6, 0, 0.3)
		motors.neck.Transform = CFrame.Angles(0.35 + math.sin(t * 40) * 0.08, math.sin(t * 33) * 0.1, math.sin(t * 27) * 0.15)
	elseif state == "Chase" then
		-- hunched forward, arms reaching out, head jittering
		motors.root.Transform = CFrame.Angles(-0.35 + math.sin(phase * 2) * 0.05, 0, math.sin(phase) * 0.08)
		motors.lArm.Transform = CFrame.Angles(1.35 + s * 0.35, 0, -0.15)
		motors.rArm.Transform = CFrame.Angles(1.35 - s * 0.35, 0, 0.15)
		motors.neck.Transform = CFrame.Angles(0.3, 0, 0) * twitch:Lerp(CFrame.identity, 0.5)
	elseif state == "Sleeping" then
		-- slumped over, breathing
		local breathe = math.sin(t * 1.5) * 0.04
		motors.root.Transform = CFrame.Angles(-0.6 + breathe, 0, 0.1)
		motors.lArm.Transform = CFrame.Angles(0.3, 0, 0.1)
		motors.rArm.Transform = CFrame.Angles(0.3, 0, -0.1)
		motors.neck.Transform = CFrame.Angles(0.7, 0, 0.5)
	else
		-- slow, swaying walk, arms dragging, head tilted
		motors.root.Transform = CFrame.Angles(-0.12, math.sin(phase) * 0.06, math.sin(phase) * 0.06)
		motors.lArm.Transform = CFrame.Angles(-s * 0.4 * stride, 0, -0.08 + math.sin(t * 0.9) * 0.05)
		motors.rArm.Transform = CFrame.Angles(s * 0.4 * stride, 0, 0.08 - math.sin(t * 1.1) * 0.05)
		motors.neck.Transform = CFrame.Angles(0.1, 0, 0.45) * twitch
	end
end

----------------------------------------------------------------------------------------------------

function Animator.init()
	track("Swing", modelPivot)
	track("Rock", modelPivot)
	track("Spin", modelPivot)
	track("Rattle", modelPivot)
	track("Watcher", partCFrame)

	local rattleUntil = 0
	local nextRattle = os.clock() + 10

	-- Motor6D.Transform has to be written before physics runs each frame.
	RunService.Stepped:Connect(function(t)
		local monster = workspace:FindFirstChild("ThePale")
		if monster then
			animateMonster(monster, t)
		end
	end)

	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local camPos = camera.CFrame.Position

		for _, item in tracked.Swing do
			local amp = math.rad(item.inst:GetAttribute("Amp") or 4)
			local speed = item.inst:GetAttribute("Speed") or 1
			local a = math.sin(t * speed + item.phase)
			item.inst:PivotTo(item.base * CFrame.Angles(a * amp * 0.3, 0, a * amp))
		end

		for _, item in tracked.Rock do
			local amp = math.rad(item.inst:GetAttribute("Amp") or 8)
			local speed = item.inst:GetAttribute("Speed") or 1.5
			item.inst:PivotTo(item.base * CFrame.Angles(math.sin(t * speed + item.phase) * amp, 0, 0))
		end

		for _, item in tracked.Spin do
			local amp = item.inst:GetAttribute("Amp") or 0.25
			item.inst:PivotTo(item.base * CFrame.new(0, math.sin(t * 2 + item.phase) * amp, 0) * CFrame.Angles(0, t * 1.6, 0))
		end

		if t > nextRattle then
			nextRattle = t + math.random(8, 20)
			rattleUntil = t + 1.2
		end
		for _, item in tracked.Rattle do
			if t < rattleUntil then
				local j = 0.06
				item.inst:PivotTo(item.base * CFrame.new((math.random() - 0.5) * j, 0, (math.random() - 0.5) * j) * CFrame.Angles(0, (math.random() - 0.5) * 0.04, 0))
			else
				item.inst:PivotTo(item.base)
			end
		end

		-- Watchers turn slowly while you look at them, and snap to face you when you look away.
		for _, item in tracked.Watcher do
			local head = item.inst :: BasePart
			local pos = item.base.Position
			if (camPos - pos).Magnitude < 45 then
				local target = CFrame.lookAt(pos, camPos)
				local _, onScreen = camera:WorldToViewportPoint(pos)
				if onScreen then
					head.CFrame = head.CFrame:Lerp(target, 0.015)
				else
					head.CFrame = target
				end
			end
		end
	end)
end

return Animator
