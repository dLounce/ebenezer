-- EbenezerFilm -- the world films itself.
--
-- Paste into the Studio command bar DURING a playtest, in the default CLIENT
-- context, then press Ctrl+Enter. Runs about 50 seconds of camera work with no
-- input from you.
--
-- Nothing here fakes anything. It kills the player for real, the real death
-- handler fires, Gloo really chooses the passage, YouVersion really returns the
-- words, and the camera is simply pointed at it while it happens.

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local StarterGui   = game:GetService("StarterGui")

local plr = Players.LocalPlayer
local cam = workspace.CurrentCamera

-- Get the Roblox chrome out of the shot.
pcall(function() StarterGui:SetCore("TopbarEnabled", false) end)
pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)

cam.CameraType = Enum.CameraType.Scriptable
cam.FieldOfView = 65

-- The character respawns mid-film; don't let it steal the camera back.
plr.CharacterAdded:Connect(function()
	task.wait(0.25)
	cam.CameraType = Enum.CameraType.Scriptable
end)

local function look(from, to)
	local ok, cf = pcall(function() return CFrame.lookAt(from, to) end)
	if ok then return cf end
	return CFrame.new(from, to)          -- older Studio
end

local function cut(from, to)
	cam.CFrame = look(from, to)
end

local function move(from, to, seconds, style)
	local goal = look(from, to)
	local tw = TweenService:Create(cam,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Sine,
			Enum.EasingDirection.InOut),
		{ CFrame = goal })
	tw:Play()
	tw.Completed:Wait()
end

local stones = workspace:WaitForChild("Stones", 10)

local function allStones()
	return stones and stones:GetChildren() or {}
end

local function slabOf(model)
	return model and model:FindFirstChild("Slab")
end

local function guiOf(model)
	local slab = slabOf(model)
	return slab and slab:FindFirstChild("Inscription")
end

-- Show exactly one inscription at a time.
--
-- Stones cluster: several deaths in the same place leave several stones within a
-- few studs of each other, and their billboards then print on top of one another.
-- On camera that reads as a bug. So the film takes explicit control of which
-- verse is legible in any given shot, instead of relying on distance.
local function focus(model)
	for _, s in ipairs(allStones()) do
		local g = guiOf(s)
		if g then
			g.MaxDistance = 500          -- visibility is decided here, not by range
			g.Enabled = (s == model)
		end
	end
end

local function seededStone()
	for _, s in ipairs(allStones()) do
		local id = s:FindFirstChild("StoneId")
		if id and tostring(id.Value):sub(1, 4) == "seed" then return s end
	end
end

task.spawn(function()
	-- Long enough to press F11 for fullscreen and get your hands off the keyboard.
	for i = 8, 1, -1 do
		print("[Film] starting in " .. i)
		task.wait(1)
	end

	------------------------------------------------------------------ 1. empty
	-- Fog, half-light, nothing happening. Establishes that this is a world
	-- before it is a point. No text on screen at all.
	focus(nil)
	cut(Vector3.new(-52, 14, -96), Vector3.new(30, 6, 6))
	move(Vector3.new(4, 11, -34), Vector3.new(74, 5, 24), 10)

	------------------------------------------------------------- 2. the chasm
	-- Drift toward the dark seam in the ground.
	move(Vector3.new(44, 9, 6), Vector3.new(74, 1, 26), 5)

	-- Snapshot what's standing, then die for real.
	local before = {}
	for _, s in ipairs(allStones()) do before[s] = true end

	local char = plr.Character
	if char and char:FindFirstChild("HumanoidRootPart") then
		char.HumanoidRootPart.CFrame = CFrame.new(74, 6, 26)
	end

	------------------------------------------------------- 3. the stone rises
	-- Hold on the spot while the round trip happens. The wait is the product:
	-- Gloo reads the moment, YouVersion returns the words, the stone comes up.
	move(Vector3.new(56, 7, 40), Vector3.new(74, 3, 26), 6)

	local fresh, t0 = nil, os.clock()
	repeat
		task.wait(0.15)
		for _, s in ipairs(allStones()) do
			if not before[s] then fresh = s break end
		end
	until fresh or os.clock() - t0 > 30

	if fresh then
		focus(fresh)                      -- this verse, and only this verse
		local slab = slabOf(fresh)
		if slab then
			local p = slab.Position
			cut(p + Vector3.new(13, 6, 15), p)
			move(p + Vector3.new(4, 2.5, 10), p + Vector3.new(0, 1.5, 0), 8)
			task.wait(3)                  -- let it be read
		end
	else
		warn("[Film] no stone appeared -- backend asleep? open /health and retry")
	end

	--------------------------------------------------- 4. a stranger's stone
	-- Somewhere else entirely. Someone left this here and you will never know
	-- who. This is the shot the whole idea rests on.
	local other = seededStone()
	if other then
		focus(other)
		local slab = slabOf(other)
		if slab then
			local p = slab.Position
			cut(p + Vector3.new(-38, 16, 34), p)
			move(p + Vector3.new(-6, 3, 13), p + Vector3.new(0, 1.5, 0), 11)
			task.wait(3)
		end
	end

	--------------------------------------------------------------- 5. the map
	-- Pull up and out. The world is bigger than the one moment. Text off, so the
	-- shot reads as landscape rather than as a wall of overlapping verses.
	local anchor = slabOf(other or fresh)
	local p = anchor and anchor.Position or Vector3.new(0, 0, 0)
	focus(nil)
	move(p + Vector3.new(0, 120, 130), p, 9)

	print("[Film] done -- stop recording")
end)
