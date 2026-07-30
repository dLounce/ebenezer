-- EbenezerWorld  (Script, ServerScriptService)
--
-- Builds the ground the stones stand in: pre-dawn light, low fog, scattered rock
-- and pine, and one chasm. The chasm matters -- it is the moment generator. A
-- player walks into it in the fog, dies, and comes back to find something
-- standing where they fell.
--
-- Deliberately procedural: no imported models, no marketplace assets, nothing
-- that has to load before the world exists.

local Lighting = game:GetService("Lighting")
local Terrain = workspace.Terrain

local RNG = Random.new(20260730)

--------------------------------------------------------------------- light
local function light()
	Lighting.ClockTime = 5.15                 -- just before sunrise
	Lighting.GeographicLatitude = 12
	Lighting.Brightness = 1.35
	Lighting.Ambient = Color3.fromRGB(38, 42, 58)
	Lighting.OutdoorAmbient = Color3.fromRGB(54, 60, 80)
	Lighting.ExposureCompensation = 0.18
	pcall(function() Lighting.EnvironmentDiffuseScale = 0.62 end)
	pcall(function() Lighting.EnvironmentSpecularScale = 0.35 end)
	pcall(function() Lighting.GlobalShadows = true end)
	pcall(function() Lighting.Technology = Enum.Technology.Future end)

	-- legacy fog, still the cheapest depth cue
	Lighting.FogColor = Color3.fromRGB(104, 112, 132)
	Lighting.FogStart = 24
	Lighting.FogEnd = 250

	pcall(function()
		local a = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
		a.Density = 0.44
		a.Offset = 0.08
		a.Color = Color3.fromRGB(192, 198, 212)
		a.Decay = Color3.fromRGB(88, 96, 118)
		a.Glare = 0.12
		a.Haze = 2.3
		a.Parent = Lighting
	end)

	pcall(function()
		local s = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
		s.StarCount = 2600
		s.Parent = Lighting
	end)
end

--------------------------------------------------------------------- helpers
local dressing = workspace:FindFirstChild("World")
if not dressing then
	dressing = Instance.new("Folder")
	dressing.Name = "World"
	dressing.Parent = workspace
else
	dressing:ClearAllChildren()
end

local function part(name, size, cf, colour, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = colour
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or dressing
	return p
end

local function jitterCF(x, y, z)
	return CFrame.new(x, y, z)
		* CFrame.Angles(
			math.rad(RNG:NextNumber(-9, 9)),
			math.rad(RNG:NextNumber(0, 360)),
			math.rad(RNG:NextNumber(-9, 9)))
end

local ROCK = {
	Color3.fromRGB(74, 74, 80),
	Color3.fromRGB(88, 84, 82),
	Color3.fromRGB(64, 66, 74),
}

local function rock(x, z, scale)
	local s = scale or RNG:NextNumber(1.6, 5.2)
	local p = part("Rock",
		Vector3.new(s * RNG:NextNumber(0.8, 1.5), s * RNG:NextNumber(0.5, 1.1),
			s * RNG:NextNumber(0.8, 1.5)),
		jitterCF(x, s * 0.28, z),
		ROCK[RNG:NextInteger(1, #ROCK)], Enum.Material.Slate)
	p.Shape = Enum.PartType.Block
	return p
end

local function pine(x, z)
	local h = RNG:NextNumber(13, 26)
	local trunk = part("Trunk", Vector3.new(1.5, h, 1.5),
		CFrame.new(x, h / 2, z), Color3.fromRGB(50, 38, 30), Enum.Material.Wood)
	trunk.Shape = Enum.PartType.Cylinder
	trunk.CFrame = CFrame.new(x, h / 2, z) * CFrame.Angles(0, 0, math.rad(90))

	local tiers = RNG:NextInteger(3, 4)
	for i = 1, tiers do
		local t = (i - 1) / tiers
		local w = (h * 0.62) * (1 - t * 0.62)
		local c = part("Needles", Vector3.new(w, h * 0.30, w),
			CFrame.new(x, h * (0.52 + t * 0.30), z),
			Color3.fromRGB(28 + RNG:NextInteger(0, 12), 52 + RNG:NextInteger(0, 16), 40),
			Enum.Material.Grass)
		c.Shape = Enum.PartType.Ball
	end
end

--------------------------------------------------------------------- ground
local function ground()
	local base = workspace:FindFirstChild("Baseplate")
	if base then
		base.Size = Vector3.new(1400, 20, 1400)
		base.CFrame = CFrame.new(0, -10, 0)
		base.Material = Enum.Material.Grass
		base.Color = Color3.fromRGB(58, 74, 52)
		base.Anchored = true
	else
		local p = part("Baseplate", Vector3.new(1400, 20, 1400), CFrame.new(0, -10, 0),
			Color3.fromRGB(58, 74, 52), Enum.Material.Grass, workspace)
		p.Locked = true
	end

	-- a few low rises so the horizon is not a table
	for _ = 1, 22 do
		local x, z = RNG:NextNumber(-620, 620), RNG:NextNumber(-620, 620)
		if math.abs(x) > 90 or math.abs(z) > 90 then
			local w = RNG:NextNumber(90, 240)
			local p = part("Rise", Vector3.new(w, RNG:NextNumber(10, 30), w),
				jitterCF(x, -RNG:NextNumber(2, 9), z),
				Color3.fromRGB(52, 66, 48), Enum.Material.Grass)
			p.Shape = Enum.PartType.Ball
			p.Locked = true
		end
	end
end

--------------------------------------------------------------------- chasm
-- The moment generator. Slate-black, sunk into the grass, easy to walk into
-- when the fog is this low. Killing on touch is the most reliable trigger in
-- Roblox -- deaths never fail to fire.
local function chasm()
	local c = part("Chasm", Vector3.new(30, 4, 104), CFrame.new(74, -0.9, 26),
		Color3.fromRGB(11, 11, 13), Enum.Material.Slate)
	c.Locked = true

	for _ = 1, 16 do
		rock(74 + RNG:NextNumber(-22, 22), 26 + RNG:NextNumber(-58, 58),
			RNG:NextNumber(2.5, 6.5))
	end

	c.Touched:Connect(function(hit)
		local model = hit and hit.Parent
		local hum = model and model:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			hum.Health = 0
		end
	end)
end

--------------------------------------------------------------------- scatter
local function scatter()
	for _ = 1, 150 do
		local x, z = RNG:NextNumber(-600, 600), RNG:NextNumber(-600, 600)
		if x * x + z * z > 2600 then rock(x, z) end
	end
	for _ = 1, 90 do
		local x, z = RNG:NextNumber(-600, 600), RNG:NextNumber(-600, 600)
		if x * x + z * z > 6400 then pine(x, z) end
	end
end

--------------------------------------------------------------------- spawn
local function spawn()
	local s = workspace:FindFirstChildOfClass("SpawnLocation")
	if not s then
		s = Instance.new("SpawnLocation")
		s.Parent = workspace
	end
	s.Size = Vector3.new(14, 1, 14)
	s.CFrame = CFrame.new(0, 0.5, 0)
	s.Anchored = true
	s.Material = Enum.Material.Slate
	s.Color = Color3.fromRGB(70, 70, 76)
	s.Neutral = true
	pcall(function() s.Enabled = true end)

	-- a cairn at spawn so the first thing you see is the shape of the idea
	for i = 1, 5 do
		local sz = 4.4 - i * 0.6
		local p = part("Cairn", Vector3.new(sz, sz * 0.5, sz),
			jitterCF(0, 1.1 + (i - 1) * 1.35, -9),
			ROCK[RNG:NextInteger(1, #ROCK)], Enum.Material.Slate)
		p.Locked = true
	end
end

--------------------------------------------------------------------- go
local ok, err = pcall(function()
	light()
	ground()
	spawn()
	chasm()
	scatter()
	pcall(function() Terrain:Clear() end)
end)

if ok then
	print("[Ebenezer] world built -- pre-dawn, fog to 250, chasm at (74, 26)")
else
	warn("[Ebenezer] world build failed: " .. tostring(err))
end
