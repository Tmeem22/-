--[[
	مفاعل الانهيار — منطق اللعبة
	ضعه في: ServerScriptService > Script جديد باسم GameManager
	يحتاج: سكريبت MapBuilder (يبني ReactorMap) — هذا السكريبت ينتظره تلقائيًا.

	المراحل:
	  1) البقاء والصناعة : الحرارة ترتفع — اجمع الموارد وابنِ نظام التبريد قبل الانهيار
	  2) تحويل الطاقة    : ابنِ التوربينات — تحوّل الحرارة إلى كهرباء وتبرّد المفاعل
	  3) الهندسة المتقدمة: كرّر الوقود (يسخّن المفاعل!) وابنِ الصاروخ ودافع بالأبراج
]]

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

---------------------------------------------------------------- الإعدادات (عدّلها براحتك)
local CONFIG = {
	StartHeat         = 10,
	HeatRate          = { 0.30, 0.35, 0.30 }, -- ارتفاع الحرارة في الثانية لكل مرحلة
	CoolingSystemRate = 0.15,  -- تبريد دائم بعد بناء نظام التبريد
	CoolingBuiltDrop  = 40,    -- كم تنزل الحرارة فورًا لما يكتمل نظام التبريد
	TurbineCooling    = 0.12,  -- تبريد كل توربين في الثانية
	PowerPerTurbine   = 0.35,  -- كهرباء كل توربين في الثانية (تزيد مع الحرارة)
	PowerRequired     = 100,
	GatherMultiplier  = 1,
	RefineScrapCost   = 2,
	RefineFuelGain    = 2,
	RefineHeat        = 1,     -- تكرير الوقود يسخّن المفاعل
	HeatZoneRadius    = 32,
	FirstWaveDelay    = 20,
	WaveInterval      = 45,
	MaxEnemies        = 25,
	EnemyDamage       = 10,
	EnemySabotageHeat = 6,     -- العدو اللي يوصل المفاعل يرفع الحرارة
	KillReward        = 2,     -- خردة لكل قتلة
	WrenchDamage      = 30,
	WrenchCooldown    = 0.6,
	TurretDamage      = 20,
	TurretFireRate    = 0.8,
	TurretRange       = 70,
	ResetDelay        = 12,
}

local ORDER = { "Scrap", "Copper", "Coolant", "RefinedFuel" }
local NAMES = { Scrap = "خردة", Copper = "نحاس", Coolant = "تبريد", RefinedFuel = "وقود" }
local OBJECTIVES = {
	"اجمع الموارد من ساحة الخردة (غرب) وابنِ نظام التبريد قبل انهيار المفاعل!",
	"ابنِ التوربينات في محطة الطاقة (شرق) واشحن شبكة القاعدة. حرارة أعلى = كهرباء أكثر",
	"كرّر الوقود في المصفاة وابنِ الصاروخ في منصة الإطلاق (شمال). ابنِ الأبراج ودافع!",
}

---------------------------------------------------------------- انتظار الماب
local Map = workspace:WaitForChild("ReactorMap", 60)
if not Map then
	warn("❌ ما لقيت ReactorMap — أضف سكريبت MapBuilder أول")
	return
end
while not Map:GetAttribute("Ready") do task.wait(0.2) end

local Reactor   = Map:WaitForChild("Reactor")
local Base      = Map:WaitForChild("SafeBase")
local P1        = Map:WaitForChild("Phase1_Scavenge")
local P2        = Map:WaitForChild("Phase2_PowerStation")
local P3        = Map:WaitForChild("Phase3_LaunchSite")
local core      = Reactor:WaitForChild("ReactorCore")
local grid      = Base:WaitForChild("BasePowerGrid")
local refinery  = P3:WaitForChild("FuelRefinery")
local rocket    = P3:WaitForChild("HF_HeavyRocket")
local rocketHome = rocket:GetPivot()

local enemiesFolder = Instance.new("Folder")
enemiesFolder.Name = "Enemies"
enemiesFolder.Parent = workspace
local turretsFolder = Instance.new("Folder")
turretsFolder.Name = "Turrets"
turretsFolder.Parent = workspace

local State = { phase = 1, heat = CONFIG.StartHeat, power = 0, wave = 0, netRate = 0,
	coolingBuilt = false, running = true, nextWave = CONFIG.FirstWaveDelay }

---------------------------------------------------------------- موارد اللاعب
local function stat(plr, key)
	local ls = plr:FindFirstChild("leaderstats")
	return ls and ls:FindFirstChild(NAMES[key])
end
local function getRes(plr, key)
	local s = stat(plr, key)
	return s and s.Value or 0
end
local function addRes(plr, key, n)
	local s = stat(plr, key)
	if s then s.Value = math.max(0, s.Value + n) end
end

---------------------------------------------------------------- الواجهة (HUD)
local function newText(parent, name, pos, size, textSize)
	local t = Instance.new("TextLabel")
	t.Name = name
	t.Position = pos
	t.Size = size
	t.BackgroundTransparency = 1
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.4
	t.Font = Enum.Font.GothamBold
	t.TextSize = textSize
	t.TextWrapped = true
	t.Text = ""
	t.Parent = parent
	return t
end

local function newBar(parent, name, y, color)
	local bg = Instance.new("Frame")
	bg.Name = name
	bg.Position = UDim2.new(0, 10, 0, y)
	bg.Size = UDim2.new(1, -20, 0, 22)
	bg.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	bg.Parent = parent
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = bg
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 6)
	local t = newText(bg, "Text", UDim2.new(0, 0, 0, 0), UDim2.fromScale(1, 1), 14)
	t.ZIndex = 2
	return bg
end

local function makeHUD(plr)
	local pg = plr:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild("ReactorHUD")
	if old then old:Destroy() end
	local gui = Instance.new("ScreenGui")
	gui.Name = "ReactorHUD"
	gui.ResetOnSpawn = false

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 6)
	panel.Size = UDim2.new(0.9, 0, 0, 158)
	panel.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
	panel.BackgroundTransparency = 0.35
	panel.Parent = gui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(520, 158)
	limit.Parent = panel

	newText(panel, "Phase", UDim2.new(0, 10, 0, 4), UDim2.new(1, -20, 0, 22), 18)
	newText(panel, "Objective", UDim2.new(0, 10, 0, 26), UDim2.new(1, -20, 0, 34), 13)
	newBar(panel, "HeatBar", 62, Color3.fromRGB(255, 120, 30))
	newBar(panel, "PowerBar", 88, Color3.fromRGB(255, 225, 60))
	newBar(panel, "RocketBar", 114, Color3.fromRGB(90, 255, 90))
	newText(panel, "Wave", UDim2.new(0, 10, 0, 138), UDim2.new(1, -20, 0, 18), 13)

	local notice = newText(gui, "Notice", UDim2.new(0.1, 0, 0.32, 0), UDim2.new(0.8, 0, 0, 50), 22)
	notice.TextColor3 = Color3.fromRGB(255, 230, 120)
	gui.Parent = pg
end

local noticeToken = {}
local function notify(plr, msg, seconds)
	local gui = plr:FindFirstChild("PlayerGui") and plr.PlayerGui:FindFirstChild("ReactorHUD")
	if not gui then return end
	local token = {}
	noticeToken[plr] = token
	gui.Notice.Text = msg
	task.delay(seconds or 3, function()
		if noticeToken[plr] == token and gui.Parent then gui.Notice.Text = "" end
	end)
end
local function broadcast(msg, seconds)
	for _, plr in ipairs(Players:GetPlayers()) do notify(plr, msg, seconds) end
end

---------------------------------------------------------------- المنصات (البناء الجماعي)
local pads = {}
for _, d in ipairs(Map:GetDescendants()) do
	if d:IsA("BasePart") and d:GetAttribute("Builds") then
		table.insert(pads, d)
		local bb = d:FindFirstChildOfClass("BillboardGui")
		d:SetAttribute("Title", bb and bb:FindFirstChildOfClass("TextLabel").Text or d.Name)
	end
end

local function padRequirements(pad)
	local r = {}
	for _, k in ipairs(ORDER) do
		local v = pad:GetAttribute(k)
		if v and v > 0 then r[k] = v end
	end
	return r
end

local function padProgress(pad)
	local need, have = 0, 0
	for k, v in pairs(padRequirements(pad)) do
		need = need + v
		have = have + math.min(v, pad:GetAttribute("Have_" .. k) or 0)
	end
	return need > 0 and have / need or 1
end

local function setGhost(model, ratio) -- ratio: 0 = شبح، 1 = مكتمل
	if not model then return end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			if part:GetAttribute("OrigT") == nil then
				part:SetAttribute("OrigT", part.Name == "Placeholder" and 0 or part.Transparency)
			end
			local orig = part:GetAttribute("OrigT")
			part.Transparency = orig + (0.85 - orig) * (1 - ratio)
			part.CanCollide = ratio >= 1
		end
	end
end

local function padModel(pad)
	return Map:FindFirstChild("HF_" .. pad:GetAttribute("Builds"), true)
end

local function updatePad(pad)
	local p = padProgress(pad)
	pad:SetAttribute("Progress", math.floor(p * 100))
	local lines = { pad:GetAttribute("Title") .. string.format("  %d%%", math.floor(p * 100)) }
	if p < 1 then
		local missing = {}
		for k, v in pairs(padRequirements(pad)) do
			local left = v - (pad:GetAttribute("Have_" .. k) or 0)
			if left > 0 then table.insert(missing, NAMES[k] .. " " .. left) end
		end
		table.insert(lines, "ناقص: " .. table.concat(missing, " · "))
	else
		lines[1] = "✅ " .. lines[1]
	end
	local bb = pad:FindFirstChildOfClass("BillboardGui")
	if bb then
		bb.Size = UDim2.fromOffset(300, 70)
		bb:FindFirstChildOfClass("TextLabel").Text = table.concat(lines, "\n")
	end
	if pad:GetAttribute("Builds") == "HeavyRocket" and p < 1 then
		setGhost(padModel(pad), p)
	end
end

local function countTurbines()
	local n = 0
	for _, pad in ipairs(pads) do
		if pad:GetAttribute("Done") and string.sub(pad:GetAttribute("Builds"), 1, 12) == "SteamTurbine" then
			n = n + 1
		end
	end
	return n
end

local setPhase, endRound, launchRocket -- تعريف مسبق

local function onBuilt(pad)
	local builds = pad:GetAttribute("Builds")
	setGhost(padModel(pad), 1)
	if builds == "CoolingSystem" then
		State.coolingBuilt = true
		State.heat = math.max(0, State.heat - CONFIG.CoolingBuiltDrop)
		broadcast("❄️ اكتمل نظام التبريد! المفاعل استقر مؤقتًا", 4)
		setPhase(2)
	elseif string.sub(builds, 1, 12) == "SteamTurbine" then
		broadcast("⚡ اشتغل توربين جديد! (" .. countTurbines() .. "/3)", 3)
	elseif builds == "HeavyRocket" then
		launchRocket()
	end
end

local function contribute(plr, pad)
	if not State.running then return end
	local phase = pad:GetAttribute("Phase")
	if phase > State.phase then
		notify(plr, "🔒 هذي المنصة تنفتح في المرحلة " .. phase)
		return
	end
	if pad:GetAttribute("Done") then return end
	local gave = false
	for k, v in pairs(padRequirements(pad)) do
		local have = pad:GetAttribute("Have_" .. k) or 0
		local give = math.min(v - have, getRes(plr, k))
		if give > 0 then
			addRes(plr, k, -give)
			pad:SetAttribute("Have_" .. k, have + give)
			gave = true
		end
	end
	if not gave then
		notify(plr, "ما عندك الموارد اللي تحتاجها هذي المنصة")
		return
	end
	updatePad(pad)
	if padProgress(pad) >= 1 then
		pad:SetAttribute("Done", true)
		onBuilt(pad)
	end
end

for _, pad in ipairs(pads) do
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = "ساهم بالموارد"
	pp.ObjectText = pad:GetAttribute("Title")
	pp.HoldDuration = 0.8
	pp.MaxActivationDistance = 18
	pp.RequiresLineOfSight = false
	pp.Parent = pad
	pp.Triggered:Connect(function(plr) contribute(plr, pad) end)
end

---------------------------------------------------------------- جمع الموارد
local nodes = P1:WaitForChild("ResourceNodes"):GetChildren()
for _, node in ipairs(nodes) do
	local pp = node:FindFirstChildOfClass("ProximityPrompt")
	if pp then
		pp.Triggered:Connect(function(plr)
			if node:GetAttribute("Depleted") or not State.running then return end
			local kind = node:GetAttribute("ResourceType")
			local amount = math.floor((node:GetAttribute("Amount") or 3) * CONFIG.GatherMultiplier)
			addRes(plr, kind, amount)
			notify(plr, "+" .. amount .. " " .. NAMES[kind], 1.5)
			node:SetAttribute("Depleted", true)
			node.Transparency = 0.9
			node.CanCollide = false
			pp.Enabled = false
			task.delay(node:GetAttribute("RespawnTime") or 45, function()
				node:SetAttribute("Depleted", false)
				node.Transparency = 0
				node.CanCollide = true
				pp.Enabled = true
			end)
		end)
	end
end

---------------------------------------------------------------- مصفاة الوقود (المرحلة 3)
do
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = "كرّر وقود نووي"
	pp.ObjectText = string.format("%d خردة ← %d وقود (يسخّن المفاعل!)", CONFIG.RefineScrapCost, CONFIG.RefineFuelGain)
	pp.HoldDuration = 2.5
	pp.MaxActivationDistance = 20
	pp.RequiresLineOfSight = false
	pp.Parent = refinery
	pp.Triggered:Connect(function(plr)
		if not State.running then return end
		if State.phase < 3 then notify(plr, "🔒 المصفاة تحتاج كهرباء القاعدة (المرحلة 3)") return end
		if getRes(plr, "Scrap") < CONFIG.RefineScrapCost then
			notify(plr, "تحتاج " .. CONFIG.RefineScrapCost .. " خردة")
			return
		end
		addRes(plr, "Scrap", -CONFIG.RefineScrapCost)
		addRes(plr, "RefinedFuel", CONFIG.RefineFuelGain)
		State.heat = State.heat + CONFIG.RefineHeat
		notify(plr, "☢ +" .. CONFIG.RefineFuelGain .. " وقود — الحرارة ارتفعت!", 1.5)
	end)
end

---------------------------------------------------------------- الأعداء
local function aliveEnemies()
	local list = {}
	for _, e in ipairs(enemiesFolder:GetChildren()) do
		local h = e:FindFirstChildOfClass("Humanoid")
		if h and h.Health > 0 and e.PrimaryPart then table.insert(list, e) end
	end
	return list
end

local function nearestPlayer(pos, range)
	local best, bestD = nil, range
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 then
			local d = (hrp.Position - pos).Magnitude
			if d < bestD then best, bestD = char, d end
		end
	end
	return best, bestD
end

local function spawnEnemy(pos, hp)
	local m = Instance.new("Model")
	m.Name = "Mutant"
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(3, 5, 2)
	root.Color = Color3.fromRGB(55, 120, 50)
	root.Material = Enum.Material.SmoothPlastic
	root.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0))
	root.Parent = m
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 2, 2)
	head.Color = Color3.fromRGB(130, 255, 80)
	head.Material = Enum.Material.Neon
	head.CFrame = root.CFrame * CFrame.new(0, 3.5, 0)
	head.Parent = m
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = head
	w.Parent = root
	local hum = Instance.new("Humanoid")
	hum.MaxHealth = hp
	hum.Health = hp
	hum.WalkSpeed = 11 + State.phase
	hum.HipHeight = 0.2
	hum.Parent = m
	m.PrimaryPart = root
	m.Parent = enemiesFolder
	pcall(function() root:SetNetworkOwner(nil) end)

	hum.Died:Connect(function()
		local killer = m:GetAttribute("LastHitBy")
		local plr = killer and Players:GetPlayerByUserId(killer)
		if plr then addRes(plr, "Scrap", CONFIG.KillReward) end
		Debris:AddItem(m, 2)
	end)

	task.spawn(function()
		local lastHit = 0
		while m.Parent and hum.Health > 0 and State.running do
			local target, dist = nearestPlayer(root.Position, 90)
			if target then
				hum:MoveTo(target.HumanoidRootPart.Position)
				if dist < 6 and os.clock() - lastHit > 1 then
					lastHit = os.clock()
					target:FindFirstChildOfClass("Humanoid"):TakeDamage(CONFIG.EnemyDamage)
				end
			else
				hum:MoveTo(core.Position)
				if (root.Position - core.Position).Magnitude < 28 then
					State.heat = State.heat + CONFIG.EnemySabotageHeat
					broadcast("⚠️ عدو خرّب المفاعل! +" .. CONFIG.EnemySabotageHeat .. " حرارة", 2)
					hum.Health = 0
				end
			end
			task.wait(0.4)
		end
	end)
end

local function spawnWave()
	State.wave = State.wave + 1
	local spawns = {}
	for _, s in ipairs(Map.EnemySpawns:GetChildren()) do
		if (s:GetAttribute("ActiveFromPhase") or 2) <= State.phase then table.insert(spawns, s) end
	end
	if #spawns == 0 then return end
	local count = 2 + State.wave + (State.phase - 2) * 3
	local hp = 60 + State.wave * 12
	broadcast("👾 الموجة " .. State.wave .. " قادمة! (" .. count .. " أعداء)", 3)
	for i = 1, count do
		if #aliveEnemies() >= CONFIG.MaxEnemies then break end
		local s = spawns[(i % #spawns) + 1]
		spawnEnemy(s.Position + Vector3.new(math.random(-5, 5), 0, math.random(-5, 5)), hp)
		task.wait(0.3)
	end
end

---------------------------------------------------------------- أبراج الدفاع
local function laser(a, b)
	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(255, 60, 60)
	beam.Size = Vector3.new(0.3, 0.3, (b - a).Magnitude)
	beam.CFrame = CFrame.lookAt(a, b) * CFrame.new(0, 0, -(b - a).Magnitude / 2)
	beam.Parent = turretsFolder
	Debris:AddItem(beam, 0.12)
end

local function buildTurret(slot, plr, pp)
	if slot:GetAttribute("Built") or not State.running then return end
	if State.phase < 2 then notify(plr, "🔒 الأبراج تنفتح من المرحلة 2") return end
	local cs, cc = slot:GetAttribute("Scrap") or 0, slot:GetAttribute("Copper") or 0
	if getRes(plr, "Scrap") < cs or getRes(plr, "Copper") < cc then
		notify(plr, string.format("البرج يحتاج %d خردة و %d نحاس", cs, cc))
		return
	end
	addRes(plr, "Scrap", -cs)
	addRes(plr, "Copper", -cc)
	slot:SetAttribute("Built", true)
	pp.Enabled = false

	local m = Instance.new("Model")
	m.Name = "Turret_" .. slot.Name
	local body = Instance.new("Part")
	body.Anchored = true
	body.Size = Vector3.new(4, 8, 4)
	body.CFrame = slot.CFrame * CFrame.new(0, 4.5, 0)
	body.Color = Color3.fromRGB(80, 85, 95)
	body.Material = Enum.Material.Metal
	body.Parent = m
	local head = Instance.new("Part")
	head.Anchored = true
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(4, 4, 4)
	head.CFrame = slot.CFrame * CFrame.new(0, 10, 0)
	head.Color = Color3.fromRGB(255, 50, 50)
	head.Material = Enum.Material.Neon
	head.Parent = m
	m.Parent = turretsFolder
	broadcast("🛡️ " .. plr.DisplayName .. " بنى برج دفاع", 2)

	task.spawn(function()
		while m.Parent do
			local best, bestD = nil, CONFIG.TurretRange
			for _, e in ipairs(aliveEnemies()) do
				local d = (e.PrimaryPart.Position - head.Position).Magnitude
				if d < bestD then best, bestD = e, d end
			end
			if best then
				laser(head.Position, best.PrimaryPart.Position)
				best:FindFirstChildOfClass("Humanoid"):TakeDamage(CONFIG.TurretDamage)
			end
			task.wait(CONFIG.TurretFireRate)
		end
	end)
end

local slots = P3:WaitForChild("TurretSlots"):GetChildren()
for _, slot in ipairs(slots) do
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = "ابنِ برج"
	pp.ObjectText = string.format("%d خردة + %d نحاس", slot:GetAttribute("Scrap") or 0, slot:GetAttribute("Copper") or 0)
	pp.HoldDuration = 1
	pp.RequiresLineOfSight = false
	pp.Parent = slot
	pp.Triggered:Connect(function(plr) buildTurret(slot, plr, pp) end)
end

---------------------------------------------------------------- سلاح اللاعب (مفتاح ربط)
local function giveWrench(plr)
	local backpack = plr:WaitForChild("Backpack")
	if backpack:FindFirstChild("Wrench") then return end
	local tool = Instance.new("Tool")
	tool.Name = "Wrench"
	tool.ToolTip = "مفتاح ربط — اضرب الأعداء"
	tool.CanBeDropped = false
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.6, 3, 0.6)
	handle.Color = Color3.fromRGB(180, 180, 190)
	handle.Material = Enum.Material.Metal
	handle.Parent = tool
	local cooling = false
	tool.Activated:Connect(function()
		if cooling then return end
		cooling = true
		local char = tool.Parent
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			for _, e in ipairs(aliveEnemies()) do
				if (e.PrimaryPart.Position - hrp.Position).Magnitude < 9 then
					e:SetAttribute("LastHitBy", plr.UserId)
					e:FindFirstChildOfClass("Humanoid"):TakeDamage(CONFIG.WrenchDamage)
				end
			end
		end
		task.wait(CONFIG.WrenchCooldown)
		cooling = false
	end)
	tool.Parent = backpack
end

---------------------------------------------------------------- المراحل ونهاية الجولة
setPhase = function(n)
	State.phase = n
	Map:SetAttribute("CurrentPhase", n)
	if n == 2 then
		State.nextWave = CONFIG.FirstWaveDelay
		task.delay(4.5, function() broadcast("المرحلة 2: تحويل الطاقة ⚡", 4) end)
	elseif n == 3 then
		grid.Material = Enum.Material.Neon
		grid.Color = Color3.fromRGB(255, 230, 70)
		grid:SetAttribute("Powered", true)
		broadcast("🔋 القاعدة اشتغلت! المرحلة 3: ابنوا الصاروخ 🚀", 5)
	end
end

endRound = function(won)
	if not State.running then return end
	State.running = false
	if won then
		broadcast("🏆 فزتوا! الصاروخ وصل بأمان", CONFIG.ResetDelay)
	else
		local ex = Instance.new("Explosion")
		ex.Position = core.Position
		ex.BlastRadius = 120
		ex.BlastPressure = 800000
		ex.Parent = workspace
		for _, plr in ipairs(Players:GetPlayers()) do
			local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
			if hum then hum.Health = 0 end
		end
		broadcast("💥 انهار المفاعل! خسرتوا… جولة جديدة قريبًا", CONFIG.ResetDelay)
	end
	for _, e in ipairs(enemiesFolder:GetChildren()) do e:Destroy() end
	task.delay(CONFIG.ResetDelay, function() _G.ReactorReset() end)
end

launchRocket = function()
	broadcast("🚀 اكتمل الصاروخ! الإطلاق خلال 3… 2… 1…", 4)
	task.wait(3)
	local fire = Instance.new("Fire")
	fire.Size = 20
	fire.Heat = 25
	fire.Parent = rocket.PrimaryPart or rocket:FindFirstChildWhichIsA("BasePart", true)
	for i = 1, 180 do
		rocket:PivotTo(rocket:GetPivot() + Vector3.new(0, i * 0.04, 0))
		task.wait(1 / 30)
	end
	endRound(true)
end

local function resetRound()
	State.phase, State.heat, State.power, State.wave = 1, CONFIG.StartHeat, 0, 0
	State.coolingBuilt, State.nextWave = false, CONFIG.FirstWaveDelay
	Map:SetAttribute("CurrentPhase", 1)
	for _, pad in ipairs(pads) do
		for _, k in ipairs(ORDER) do pad:SetAttribute("Have_" .. k, nil) end
		pad:SetAttribute("Done", false)
		updatePad(pad)
		setGhost(padModel(pad), 0)
	end
	rocket:PivotTo(rocketHome)
	local f = rocket:FindFirstChildWhichIsA("Fire", true)
	if f then f:Destroy() end
	turretsFolder:ClearAllChildren()
	enemiesFolder:ClearAllChildren()
	for _, slot in ipairs(slots) do
		slot:SetAttribute("Built", false)
		local pp = slot:FindFirstChildOfClass("ProximityPrompt")
		if pp then pp.Enabled = true end
	end
	grid.Material = Enum.Material.Metal
	grid.Color = Color3.fromRGB(90, 96, 104)
	grid:SetAttribute("Powered", false)
	for _, plr in ipairs(Players:GetPlayers()) do
		for _, k in ipairs(ORDER) do
			local s = stat(plr, k)
			if s then s.Value = 0 end
		end
		plr:LoadCharacter()
	end
	State.running = true
	task.delay(2, function() broadcast("المرحلة 1: البقاء والصناعة ☢ — المفاعل يسخن!", 5) end)
end
_G.ReactorReset = resetRound

---------------------------------------------------------------- اللاعبين
local function onPlayer(plr)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	for _, k in ipairs(ORDER) do
		local v = Instance.new("IntValue")
		v.Name = NAMES[k]
		v.Parent = ls
	end
	ls.Parent = plr
	plr.CharacterAdded:Connect(function() task.wait(0.5) giveWrench(plr) end)
	if plr.Character then giveWrench(plr) end
	makeHUD(plr)
	task.delay(1, function() notify(plr, "☢ المفاعل يسخن! " .. OBJECTIVES[State.phase], 6) end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, plr in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, plr) end
Players.PlayerRemoving:Connect(function(plr) noticeToken[plr] = nil end)

---------------------------------------------------------------- تحديث الواجهة
local function fmtTime(s)
	return string.format("%d:%02d", math.floor(s / 60), math.floor(s % 60))
end

local rocketPad = P3:WaitForChild("RocketBuildPad")
local function updateHUD()
	local heatText = string.format("🔥 الحرارة %d%%", math.floor(State.heat))
	if State.netRate > 0 then
		heatText = heatText .. "  —  انهيار خلال " .. fmtTime((100 - State.heat) / State.netRate)
	else
		heatText = heatText .. "  —  مستقر ❄️"
	end
	local heatColor = State.heat < 50 and Color3.fromRGB(80, 220, 120)
		or State.heat < 80 and Color3.fromRGB(255, 150, 40) or Color3.fromRGB(255, 40, 40)
	local rocketP = (rocketPad:GetAttribute("Progress") or 0) / 100

	for _, plr in ipairs(Players:GetPlayers()) do
		local gui = plr:FindFirstChild("PlayerGui") and plr.PlayerGui:FindFirstChild("ReactorHUD")
		if gui then
			local p = gui.Panel
			p.Phase.Text = "المرحلة " .. State.phase .. " / 3"
			p.Objective.Text = OBJECTIVES[State.phase]
			p.HeatBar.Fill.Size = UDim2.fromScale(State.heat / 100, 1)
			p.HeatBar.Fill.BackgroundColor3 = heatColor
			p.HeatBar.Text.Text = heatText
			p.PowerBar.Visible = State.phase >= 2
			p.PowerBar.Fill.Size = UDim2.fromScale(State.power / CONFIG.PowerRequired, 1)
			p.PowerBar.Text.Text = string.format("⚡ كهرباء القاعدة %d / %d  (توربينات %d/3)",
				math.floor(State.power), CONFIG.PowerRequired, countTurbines())
			p.RocketBar.Visible = State.phase >= 3
			p.RocketBar.Fill.Size = UDim2.fromScale(rocketP, 1)
			p.RocketBar.Text.Text = string.format("🚀 الصاروخ %d%%", math.floor(rocketP * 100))
			p.Wave.Text = State.phase >= 2
				and string.format("👾 الموجة %d — التالية خلال %ds — أعداء: %d", State.wave, math.max(0, math.ceil(State.nextWave)), #aliveEnemies())
				or "اجمع: خردة · نحاس · سائل تبريد"
		end
	end
end

---------------------------------------------------------------- الحلقة الرئيسية
local DT = 0.5
resetRound()
while true do
	task.wait(DT)
	if State.running then
		-- الحرارة
		local rate = CONFIG.HeatRate[State.phase]
		if State.coolingBuilt then rate = rate - CONFIG.CoolingSystemRate end
		local turbines = countTurbines()
		rate = rate - turbines * CONFIG.TurbineCooling
		State.netRate = rate
		State.heat = math.clamp(State.heat + rate * DT, 0, 100)

		-- الكهرباء: التوربينات تحوّل الحرارة إلى طاقة
		if State.phase >= 2 and turbines > 0 then
			State.power = math.min(CONFIG.PowerRequired,
				State.power + turbines * CONFIG.PowerPerTurbine * (0.5 + State.heat / 100) * DT)
			if State.phase == 2 and State.power >= CONFIG.PowerRequired then setPhase(3) end
		end
		grid:SetAttribute("Power", math.floor(State.power))

		-- شكل المفاعل حسب الحرارة
		core:SetAttribute("Heat", State.heat)
		core.Color = Color3.fromRGB(255, math.floor(200 - State.heat * 1.6), 40)
		local l = core:FindFirstChildOfClass("PointLight")
		if l then l.Brightness = 2 + State.heat / 20 + math.sin(os.clock() * (2 + State.heat / 15)) end

		-- ضرر الإشعاع قرب المفاعل
		if State.heat > 50 then
			for _, plr in ipairs(Players:GetPlayers()) do
				local char = plr.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if hrp and hum and (hrp.Position - core.Position).Magnitude < CONFIG.HeatZoneRadius then
					hum:TakeDamage((State.heat - 50) / 5 * DT)
				end
			end
		end

		-- الموجات
		if State.phase >= 2 then
			State.nextWave = State.nextWave - DT
			if State.nextWave <= 0 then
				State.nextWave = CONFIG.WaveInterval
				task.spawn(spawnWave)
			end
		end

		if State.heat >= 100 then endRound(false) end
	end
	updateHUD()
end
