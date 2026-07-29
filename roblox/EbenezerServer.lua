-- EbenezerServer  (Script, ServerScriptService)
--
-- Watches for real moments, asks the backend what Scripture belongs to each one,
-- and raises a stone at the coordinates where it happened.
--
--   moment  ->  Gloo AI selects a reference from a curated pool of 35
--           ->  YouVersion returns the words, in that player's own language
--           ->  a stone rises out of the ground and stays there
--
-- The stones are public and they persist. Weeks later a different player walks
-- past and reads one without ever knowing whose night it was.

local HttpService      = game:GetService("HttpService")
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local DataStoreService  = game:GetService("DataStoreService")

local Config = require(script.Parent:WaitForChild("EbenezerConfig"))
local BASE, SECRET = Config.BASE, Config.SECRET

local function log(...)
	if Config.VERBOSE then print("[Ebenezer]", ...) end
end

--============================================================ transport
local function request(method, path, body)
	local opts = {
		Url = BASE .. path,
		Method = method,
		Headers = {
			["Content-Type"] = "application/json",
			["X-Ebenezer-Key"] = SECRET,
		},
	}
	if body then opts.Body = HttpService:JSONEncode(body) end

	local ok, res = pcall(function() return HttpService:RequestAsync(opts) end)
	if not ok then
		warn("[Ebenezer] request failed: " .. tostring(res))
		return nil
	end
	if not res.Success then
		warn(("[Ebenezer] HTTP %d on %s -> %s")
			:format(res.StatusCode, path, tostring(res.Body)))
		return nil
	end
	local okj, decoded = pcall(function() return HttpService:JSONDecode(res.Body) end)
	if not okj then
		warn("[Ebenezer] unreadable response from " .. path)
		return nil
	end
	return decoded
end

-- Free hosting sleeps after 15 minutes and cold-starts in about 50 seconds.
-- Absorb that on boot so the first real moment of a session is not the one that
-- has to wait for it.
local function warmup()
	for i = 1, Config.WARMUP_TRIES do
		local h = request("GET", "/health")
		if h then
			log(("backend awake -- %d languages, %d stones on record")
				:format(h.languages or 0, h.stones or 0))
			return true
		end
		log(("backend still waking (%d/%d)"):format(i, Config.WARMUP_TRIES))
		task.wait(Config.WARMUP_GAP)
	end
	warn("[Ebenezer] backend unreachable -- check BASE and SECRET in EbenezerConfig")
	return false
end

--============================================================ the stone
local stonesFolder = workspace:FindFirstChild("Stones")
if not stonesFolder then
	stonesFolder = Instance.new("Folder")
	stonesFolder.Name = "Stones"
	stonesFolder.Parent = workspace
end

local INK  = Color3.fromRGB(244, 238, 226)
local GOLD = Color3.fromRGB(228, 202, 152)

local function groundAt(x, z, hintY)
	local params = RaycastParams.new()
	local okf = pcall(function() params.FilterType = Enum.RaycastFilterType.Exclude end)
	if not okf then pcall(function() params.FilterType = Enum.RaycastFilterType.Blacklist end) end
	params.FilterDescendantsInstances = { stonesFolder }
	params.IgnoreWater = true

	local from = Vector3.new(x, (hintY or 0) + 180, z)
	local hit = workspace:Raycast(from, Vector3.new(0, -900, 0), params)
	if hit then return hit.Position.Y end
	return hintY or 0
end

local function inscribe(slab, data)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Inscription"
	gui.Size = UDim2.fromScale(12, 6.4)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 5.9, 0)
	gui.MaxDistance = 85          -- you have to walk up to it to read it
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.Enabled = false
	gui.Parent = slab

	local ref = Instance.new("TextLabel")
	ref.Name = "Reference"
	ref.BackgroundTransparency = 1
	ref.Size = UDim2.new(1, 0, 0.19, 0)
	ref.Position = UDim2.new(0, 0, 0, 0)
	ref.Font = Enum.Font.Merriweather
	ref.Text = string.upper(tostring(data.reference or ""))
	ref.TextColor3 = GOLD
	ref.TextScaled = true
	ref.TextStrokeColor3 = Color3.new(0, 0, 0)
	ref.TextStrokeTransparency = 0.45
	ref.Parent = gui
	local rc = Instance.new("UITextSizeConstraint")
	rc.MaxTextSize = 17
	rc.Parent = ref

	local verse = Instance.new("TextLabel")
	verse.Name = "Verse"
	verse.BackgroundTransparency = 1
	verse.Size = UDim2.new(1, 0, 0.81, 0)
	verse.Position = UDim2.new(0, 0, 0.19, 0)
	verse.Font = Enum.Font.Merriweather
	verse.Text = tostring(data.text or "")
	verse.TextColor3 = INK
	verse.TextScaled = true
	verse.TextWrapped = true
	verse.TextYAlignment = Enum.TextYAlignment.Top
	verse.TextStrokeColor3 = Color3.new(0, 0, 0)
	verse.TextStrokeTransparency = 0.45
	verse.Parent = gui
	local vc = Instance.new("UITextSizeConstraint")
	vc.MaxTextSize = 26
	vc.Parent = verse

	return gui
end

-- animate=true for a stone being raised right now; false when repopulating a
-- world that already had them.
local function buildStone(data, animate)
	if not data or not data.pos then return nil end
	local id = tostring(data.stone_id or HttpService:GenerateGUID(false))
	if stonesFolder:FindFirstChild("Stone_" .. id) then return nil end

	local x, z = tonumber(data.pos.x) or 0, tonumber(data.pos.z) or 0
	local y = groundAt(x, z, tonumber(data.pos.y) or 0)

	local model = Instance.new("Model")
	model.Name = "Stone_" .. id

	local slab = Instance.new("Part")
	slab.Name = "Slab"
	slab.Size = Vector3.new(4.3, 6.6, 1.15)
	slab.Anchored = true
	slab.CanCollide = true
	slab.Material = Enum.Material.Slate
	slab.Color = Color3.fromRGB(82, 80, 86)
	slab.TopSurface = Enum.SurfaceType.Smooth
	slab.BottomSurface = Enum.SurfaceType.Smooth
	slab.Parent = model

	local rest = CFrame.new(x, y + 2.9, z)
		* CFrame.Angles(0, math.rad((x * 7 + z * 13) % 360), math.rad(-2))
	slab.CFrame = rest
	model.PrimaryPart = slab

	-- rubble at the base, so it reads as something that came up out of the ground
	for i = 1, 4 do
		local s = 1.5 + ((i * 0.7) % 1.6)
		local r = Instance.new("Part")
		r.Name = "Rubble"
		r.Size = Vector3.new(s, s * 0.6, s)
		r.Anchored = true
		r.Material = Enum.Material.Slate
		r.Color = Color3.fromRGB(70, 68, 74)
		r.TopSurface = Enum.SurfaceType.Smooth
		r.BottomSurface = Enum.SurfaceType.Smooth
		local a = (i / 4) * math.pi * 2
		r.CFrame = CFrame.new(x + math.cos(a) * 2.5, y + s * 0.22, z + math.sin(a) * 2.5)
			* CFrame.Angles(0, a, math.rad(6))
		r.Parent = model
	end

	-- warm light, so a stone can be found in fog before it can be read
	local lamp = Instance.new("PointLight")
	lamp.Color = Color3.fromRGB(255, 226, 172)
	lamp.Brightness = 1.55
	lamp.Range = 24
	lamp.Shadows = false
	lamp.Parent = slab

	local gui = inscribe(slab, data)

	-- searchable metadata, and it makes the repo honest about what a stone is
	for key, val in pairs({
		Theme = tostring(data.theme or ""),
		Usfm = tostring(data.usfm or ""),
		Reference = tostring(data.reference or ""),
		Locale = tostring(data.locale or ""),
		LeftBy = tostring(data.left_by or ""),
		StoneId = id,
	}) do
		local a = Instance.new("StringValue")
		a.Name = key
		a.Value = val
		a.Parent = model
	end

	model.Parent = stonesFolder

	if not animate then
		gui.Enabled = true
		return model
	end

	-- The rise is the latency budget made visible: the round trip through both
	-- APIs takes a beat, and the stone spends that beat coming up.
	slab.CFrame = rest * CFrame.new(0, -8.2, 0)
	slab.CanCollide = false

	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(150, 142, 126))
	dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	dust.Size = NumberSequence.new(2.6, 5.2)
	dust.Lifetime = NumberRange.new(0.9, 1.7)
	dust.Rate = 70
	dust.Speed = NumberRange.new(1.4, 3.6)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.Parent = slab

	TweenService:Create(slab,
		TweenInfo.new(2.1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ CFrame = rest }):Play()

	task.delay(1.5, function()
		dust.Rate = 0
		if gui then gui.Enabled = true end
		slab.CanCollide = true
		task.delay(2.5, function() if dust then dust:Destroy() end end)
	end)

	return model
end

--============================================================ persistence
-- The backend mirror lets a brand-new server repopulate a world it has never
-- seen. DataStore is the long-lived record. Both are optional; the game still
-- works if either is unavailable, which is the correct failure mode.
local store
pcall(function() store = DataStoreService:GetDataStore("EbenezerStones_v1") end)
local KEY = "world"

local function remember(data)
	if not store then return end
	task.spawn(function()
		local ok, err = pcall(function()
			store:UpdateAsync(KEY, function(old)
				old = (type(old) == "table") and old or {}
				table.insert(old, data)
				while #old > 250 do table.remove(old, 1) end
				return old
			end)
		end)
		if not ok then log("datastore write skipped: " .. tostring(err)) end
	end)
end

local function repopulate()
	local seen, all = {}, {}

	local r = request("GET", "/stones")
	if r and type(r.stones) == "table" then
		for _, s in ipairs(r.stones) do
			if s.stone_id and not seen[s.stone_id] then
				seen[s.stone_id] = true
				table.insert(all, s)
			end
		end
	end

	if store then
		local ok, saved = pcall(function() return store:GetAsync(KEY) end)
		if ok and type(saved) == "table" then
			for _, s in ipairs(saved) do
				if type(s) == "table" and s.stone_id and not seen[s.stone_id] then
					seen[s.stone_id] = true
					table.insert(all, s)
				end
			end
		else
			log("datastore unavailable -- enable Studio Access to API Services for it")
		end
	end

	for _, s in ipairs(all) do buildStone(s, false) end
	log(("%d stones already standing in this world"):format(#all))
end

--============================================================ moments
local state = {}     -- userId -> { deaths, lastDeath, joined, lastStone, lonely, survived, pos }

local function st(player)
	local s = state[player.UserId]
	if not s then
		s = { deaths = 0, lastDeath = 0, joined = os.clock(),
			lastStone = -1e9, lonely = false, survived = false,
			pos = Vector3.new(0, 4, 0) }
		state[player.UserId] = s
	end
	return s
end

local function localeOf(player)
	local loc = "en"
	pcall(function()
		if player.LocaleId and player.LocaleId ~= "" then loc = player.LocaleId end
	end)
	return loc
end

-- Position is captured at the instant the moment happens, not after the round
-- trip -- by then the character is gone.
local function raise(player, moment, at)
	local s = st(player)
	local now = os.clock()
	if now - s.lastStone < Config.COOLDOWN then return end
	s.lastStone = now

	local pos = at or s.pos
	local locale = localeOf(player)

	task.spawn(function()
		local data = request("POST", "/stone", {
			event = moment,
			locale = locale,
			x = pos.X, y = pos.Y, z = pos.Z,
			player = player.Name,
		})
		if not data then return end
		buildStone(data, true)
		remember(data)
		log(("%s  %s  [%s/%s]  %s")
			:format(player.Name, data.reference or "?", data.theme or "?",
				data.locale or "?", moment))
	end)
end

-- The words below are the only place a moment gets described. They are written
-- for a model that has to read emotional shape, not keywords.
local function describeDeath(player)
	local s = st(player)
	local n = s.deaths
	if n <= 1 then
		return "Player died for the first time in this world. They were alone and "
			.. "they lost what they were carrying."
	elseif n == 2 then
		return "Player died again in the same place, twice within a few minutes."
	elseif n < 5 then
		return ("Player has died %d times in a row in the same spot and keeps going "
			.. "back to it."):format(n)
	end
	return ("Player has died %d times in the same spot. They are not stopping, but "
		.. "nothing is working either."):format(n)
end

local function watch(player)
	local s = st(player)

	player.CharacterAdded:Connect(function(char)
		local hum = char:WaitForChild("Humanoid", 8)
		local root = char:WaitForChild("HumanoidRootPart", 8)

		if root then
			task.spawn(function()
				while root and root.Parent do
					s.pos = root.Position
					task.wait(1)
				end
			end)
		end

		if hum then
			hum.Died:Connect(function()
				local at = (root and root.Parent) and root.Position or s.pos
				s.deaths = s.deaths + 1
				s.lastDeath = os.clock()
				s.survived = false
				raise(player, describeDeath(player), at)
			end)
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	st(player)
	watch(player)
end)
for _, p in ipairs(Players:GetPlayers()) do st(p); watch(p) end

Players.PlayerRemoving:Connect(function(player) state[player.UserId] = nil end)

-- Two slower moments, checked on a loop rather than an event.
task.spawn(function()
	while true do
		task.wait(15)
		local list = Players:GetPlayers()
		for _, player in ipairs(list) do
			local s = st(player)
			local here = os.clock() - s.joined

			if not s.lonely and #list == 1 and here > Config.LONELY_AFTER then
				s.lonely = true
				raise(player,
					"Player's first time in this world. No one else is online and it "
					.. "is still dark.", s.pos)

			elseif not s.survived and s.deaths > 0
				and os.clock() - s.lastDeath > Config.SURVIVED_FOR then
				s.survived = true
				raise(player,
					("Player has stayed alive for %d minutes after dying repeatedly, "
					.. "and has been building something."):format(
						math.floor(Config.SURVIVED_FOR / 60)), s.pos)
			end
		end
	end
end)

--============================================================ filming hooks
-- Run these from the Studio command bar while playtesting. They exist so the
-- multi-language shot can be captured by one person on one machine.
--
--   _G.Ebenezer.stone("Player died to the same creature five times", "pt")
--   _G.Ebenezer.tour()      -- one stone per language, in a ring around spawn
--
_G.Ebenezer = {
	stone = function(moment, locale, offset)
		local player = Players:GetPlayers()[1]
		local base = player and st(player).pos or Vector3.new(0, 4, 0)
		local at = base + (offset or Vector3.new(math.random(-14, 14), 0, math.random(-14, 14)))
		local data = request("POST", "/stone", {
			event = moment or "Player died alone in the dark and lost everything.",
			locale = locale or "en",
			x = at.X, y = at.Y, z = at.Z,
			player = player and player.Name or "Studio",
		})
		if data then
			buildStone(data, true)
			remember(data)
			log(("%s  [%s]  %s"):format(data.reference, data.locale, data.text))
		end
		return data
	end,

	tour = function(moment)
		local langs = { "en", "pt", "es", "ja", "hi", "fr", "de", "zh",
			"tl", "id", "th", "ar" }
		for i, lg in ipairs(langs) do
			local a = (i / #langs) * math.pi * 2
			_G.Ebenezer.stone(moment or
				"Player's first night in this world, alone, with nothing.", lg,
				Vector3.new(math.cos(a) * 26, 0, math.sin(a) * 26))
			task.wait(0.35)
		end
		log("tour placed -- one stone per entitled language")
	end,

	clear = function()
		stonesFolder:ClearAllChildren()
		log("local stones cleared (backend record untouched)")
	end,
}

--============================================================ boot
task.spawn(function()
	if BASE:find("YOUR%-SERVICE") or SECRET == "REPLACE_ME" then
		warn("[Ebenezer] EbenezerConfig still has placeholders -- set BASE and SECRET")
		return
	end
	if warmup() then
		repopulate()
	end
end)

--============================================================ studio hook
-- The Studio command bar runs in its own Luau VM, so the _G above is NOT the _G
-- the command bar sees. Reach the filming helpers through the DataModel instead
-- (command bar context must be Server):
--
--   game.ServerStorage.EbenezerHook:Invoke("tour")
--   game.ServerStorage.EbenezerHook:Invoke("stone", "Player died five times", "pt")
--   game.ServerStorage.EbenezerHook:Invoke("clear")
--
do
	local ServerStorage = game:GetService("ServerStorage")
	local old = ServerStorage:FindFirstChild("EbenezerHook")
	if old then old:Destroy() end

	local hook = Instance.new("BindableFunction")
	hook.Name = "EbenezerHook"
	hook.Parent = ServerStorage

	hook.OnInvoke = function(action, a, b)
		action = tostring(action or "stone")
		if action == "clear" then
			_G.Ebenezer.clear()
		else
			-- spawned so a twelve-request tour does not block the command bar
			task.spawn(function()
				if action == "tour" then
					_G.Ebenezer.tour(a)
				else
					_G.Ebenezer.stone(a, b)
				end
			end)
		end
		return "ok: " .. action
	end

	log('studio hook ready - game.ServerStorage.EbenezerHook:Invoke("tour")')
end
