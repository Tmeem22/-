--[[
	مفاعل الانهيار — سكريبت بناء الماب
	طريقة التشغيل: Roblox Studio > View > Command Bar > الصق السكريبت كاملًا > Enter
	يمكن التراجع عنه بـ Ctrl+Z، وإعادة تشغيله تحذف النسخة القديمة وتبني من جديد.

	تخطيط الماب (المفاعل في المركز 0,0):
	  جنوب  (Z = -200) : القاعدة الآمنة + نقطة الظهور
	  غرب   (X = -190) : ساحة الخردة — المرحلة 1 (جمع الموارد + محطة التبريد)
	  شرق   (X =  190) : محطة الطاقة — المرحلة 2 (التوربينات والمولدات)
	  شمال  (Z =  210) : منصة الإطلاق — المرحلة 3 (الصاروخ + مصفاة الوقود)
	  الزوايا          : نقاط ظهور الأعداء
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local recording = ChangeHistoryService:TryBeginRecording("Build Reactor Map")

local old = workspace:FindFirstChild("ReactorMap")
if old then old:Destroy() end

local Map = Instance.new("Folder")
Map.Name = "ReactorMap"
Map.Parent = workspace

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent or Map
	return f
end

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Name = props.Name or "Part"
	if props.Shape then p.Shape = props.Shape end
	p.Size = props.Size
	p.CFrame = props.CFrame
	p.Color = props.Color or Color3.fromRGB(120, 120, 120)
	p.Material = props.Material or Enum.Material.Concrete
	p.Transparency = props.Transparency or 0
	p.CanCollide = props.CanCollide ~= false
	p.CastShadow = props.CastShadow ~= false
	if props.Tag then CollectionService:AddTag(p, props.Tag) end
	if props.Attributes then
		for k, v in pairs(props.Attributes) do p:SetAttribute(k, v) end
	end
	p.Parent = props.Parent
	return p
end

local function light(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = parent
	return l
end

local function label(parent, text, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 50)
	gui.StudsOffset = Vector3.new(0, 6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 250
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.Parent = gui
	gui.Parent = parent
end

-- قطعة مؤقتة تُستبدل لاحقًا بمجسم Higgsfield بنفس الاسم
local function placeholder(name, size, cf, color, parent)
	local m = Instance.new("Model")
	m.Name = "HF_" .. name
	local p = part({
		Name = "Placeholder", Size = size, CFrame = cf, Color = color,
		Material = Enum.Material.SmoothPlastic, Transparency = 0.15, Parent = m,
	})
	m.PrimaryPart = p
	m:SetAttribute("ReplaceWithHiggsfield", true)
	CollectionService:AddTag(m, "HF_Placeholder")
	m.Parent = parent
	return m
end

local C = {
	ground   = Color3.fromRGB(58, 60, 56),
	concrete = Color3.fromRGB(140, 138, 130),
	metal    = Color3.fromRGB(90, 96, 104),
	rust     = Color3.fromRGB(122, 74, 46),
	hazard   = Color3.fromRGB(240, 190, 30),
	heat     = Color3.fromRGB(255, 110, 20),
	coolant  = Color3.fromRGB(40, 200, 255),
	power    = Color3.fromRGB(255, 230, 70),
	fuel     = Color3.fromRGB(90, 255, 90),
	danger   = Color3.fromRGB(200, 30, 30),
}

---------------------------------------------------------------- الأرض والسور
local Env = folder("Environment")
part({ Name = "Ground", Size = Vector3.new(640, 4, 640), CFrame = CFrame.new(0, -2, 0),
	Color = C.ground, Material = Enum.Material.Asphalt, Parent = Env })

for i, d in ipairs({ {0, 320, 640, 6}, {0, -320, 640, 6}, {320, 0, 6, 640}, {-320, 0, 6, 640} }) do
	part({ Name = "PerimeterWall" .. i, Size = Vector3.new(d[3], 30, d[4]),
		CFrame = CFrame.new(d[1], 15, d[2]), Color = C.metal,
		Material = Enum.Material.CorrodedMetal, Parent = Env })
end

-- طرق تربط المفاعل بكل منطقة
for i, r in ipairs({ {0, -110, 16, 200}, {0, 115, 16, 190}, {-105, 0, 190, 16}, {105, 0, 190, 16} }) do
	part({ Name = "Road" .. i, Size = Vector3.new(r[3], 0.4, r[4]), CFrame = CFrame.new(r[1], 0.2, r[2]),
		Color = C.concrete, Material = Enum.Material.Concrete, Parent = Env })
end

---------------------------------------------------------------- المفاعل (المركز)
local Reactor = folder("Reactor")
part({ Name = "ReactorPlatform", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 70, 70),
	CFrame = CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90)),
	Color = C.concrete, Material = Enum.Material.DiamondPlate, Parent = Reactor })

local core = part({ Name = "ReactorCore", Shape = Enum.PartType.Cylinder, Size = Vector3.new(34, 18, 18),
	CFrame = CFrame.new(0, 19, 0) * CFrame.Angles(0, 0, math.rad(90)),
	Color = C.heat, Material = Enum.Material.Neon, Parent = Reactor,
	Tag = "ReactorCore", Attributes = { Heat = 0, MaxHeat = 100, HeatPerSecond = 0.5 } })
light(core, C.heat, 60, 3)
label(core, "☢ قلب المفاعل", C.heat)

-- قفص الاحتواء
for i = 0, 7 do
	local a = math.rad(i * 45)
	part({ Name = "ContainmentPillar" .. i, Size = Vector3.new(3, 40, 3),
		CFrame = CFrame.new(math.cos(a) * 16, 20, math.sin(a) * 16),
		Color = C.metal, Material = Enum.Material.Metal, Parent = Reactor })
end
part({ Name = "ContainmentRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 38, 38),
	CFrame = CFrame.new(0, 40, 0) * CFrame.Angles(0, 0, math.rad(90)),
	Color = C.metal, Material = Enum.Material.Metal, Parent = Reactor })

-- منطقة الخطر حول المفاعل (لضرر الحرارة لاحقًا)
part({ Name = "HeatZone", Shape = Enum.PartType.Cylinder, Size = Vector3.new(30, 60, 60),
	CFrame = CFrame.new(0, 15, 0) * CFrame.Angles(0, 0, math.rad(90)),
	Transparency = 1, CanCollide = false, CastShadow = false, Parent = Reactor, Tag = "HeatZone" })

placeholder("ReactorShell", Vector3.new(26, 44, 26), CFrame.new(0, 22, 0), C.metal, Reactor):FindFirstChild("Placeholder").Transparency = 0.85

---------------------------------------------------------------- القاعدة الآمنة (جنوب)
local Base = folder("SafeBase")
part({ Name = "BaseFloor", Size = Vector3.new(110, 1, 70), CFrame = CFrame.new(0, 0.5, -230),
	Color = C.concrete, Material = Enum.Material.Concrete, Parent = Base })
for i, w in ipairs({ {0, -265, 110, 2}, {-55, -230, 2, 70}, {55, -230, 2, 70} }) do
	part({ Name = "BaseWall" .. i, Size = Vector3.new(w[3], 14, w[4]), CFrame = CFrame.new(w[1], 7, w[2]),
		Color = C.metal, Material = Enum.Material.Metal, Parent = Base })
end
local spawn = Instance.new("SpawnLocation")
spawn.Name = "PlayerSpawn"
spawn.Anchored = true
spawn.Size = Vector3.new(14, 1, 14)
spawn.CFrame = CFrame.new(0, 1.5, -240)
spawn.Color = C.coolant
spawn.Material = Enum.Material.Neon
spawn.Duration = 3
spawn.Parent = Base

local baseLights = part({ Name = "BasePowerGrid", Size = Vector3.new(8, 8, 8), CFrame = CFrame.new(40, 4.5, -250),
	Color = C.metal, Material = Enum.Material.Metal, Parent = Base, Tag = "BasePowerGrid",
	Attributes = { Powered = false, Power = 0, PowerRequired = 100 } })
label(baseLights, "شبكة كهرباء القاعدة", C.power)
placeholder("Workbench", Vector3.new(10, 4, 5), CFrame.new(-35, 3, -250), C.rust, Base)
CollectionService:AddTag(Base:FindFirstChild("HF_Workbench"), "CraftingStation")

---------------------------------------------------------------- المرحلة 1: ساحة الخردة (غرب)
local P1 = folder("Phase1_Scavenge")
part({ Name = "ScrapYardFloor", Size = Vector3.new(170, 0.6, 260), CFrame = CFrame.new(-215, 0.3, 0),
	Color = Color3.fromRGB(85, 72, 58), Material = Enum.Material.Ground, Parent = P1 })

local nodes = folder("ResourceNodes", P1)
local resourceTypes = {
	{ "Scrap",   C.rust,    Enum.Material.CorrodedMetal, 14 },
	{ "Copper",  Color3.fromRGB(200, 120, 60), Enum.Material.Metal, 8 },
	{ "Coolant", C.coolant, Enum.Material.Glass, 8 },
}
local rng = Random.new(2026)
for _, rt in ipairs(resourceTypes) do
	for i = 1, rt[4] do
		local pos = Vector3.new(rng:NextNumber(-290, -140), 0, rng:NextNumber(-120, 120))
		local n = part({ Name = rt[1] .. "Node" .. i, Size = Vector3.new(5, 4, 5),
			CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
			Color = rt[2], Material = rt[3], Parent = nodes, Tag = "ResourceNode",
			Attributes = { ResourceType = rt[1], Amount = 3, RespawnTime = 45 } })
		local pp = Instance.new("ProximityPrompt")
		pp.ActionText = "اجمع"
		pp.ObjectText = rt[1]
		pp.HoldDuration = 1.2
		pp.Parent = n
	end
end

-- أكوام خردة ديكور
for i = 1, 10 do
	placeholder("ScrapPile", Vector3.new(rng:NextNumber(8, 14), rng:NextNumber(4, 8), rng:NextNumber(8, 14)),
		CFrame.new(rng:NextNumber(-295, -140), 3, rng:NextNumber(-125, 125)), C.rust, P1).Name = "HF_ScrapPile" .. i
end

-- منصة بناء نظام التبريد (بين الساحة والمفاعل)
local coolPad = part({ Name = "CoolingSystemBuildPad", Size = Vector3.new(30, 1, 30), CFrame = CFrame.new(-70, 0.5, 0),
	Color = C.coolant, Material = Enum.Material.DiamondPlate, Parent = P1, Tag = "BuildPad",
	Attributes = { Phase = 1, Builds = "CoolingSystem", Scrap = 30, Copper = 15, Coolant = 20, Progress = 0 } })
label(coolPad, "المرحلة 1: ابنِ نظام التبريد", C.coolant)
placeholder("CoolingSystem", Vector3.new(22, 18, 22), CFrame.new(-70, 10, 0), C.coolant, P1).PrimaryPart.Transparency = 0.8

-- أنابيب من منصة التبريد للمفاعل
part({ Name = "CoolantPipe", Shape = Enum.PartType.Cylinder, Size = Vector3.new(38, 3, 3),
	CFrame = CFrame.new(-36, 4, 6), Color = C.metal, Material = Enum.Material.Metal, Parent = P1 })

---------------------------------------------------------------- المرحلة 2: محطة الطاقة (شرق)
local P2 = folder("Phase2_PowerStation")
part({ Name = "PowerStationFloor", Size = Vector3.new(160, 1, 200), CFrame = CFrame.new(210, 0.5, 0),
	Color = C.concrete, Material = Enum.Material.Concrete, Parent = P2 })

for i = 1, 3 do
	local z = -60 + (i - 1) * 60
	local t = placeholder("SteamTurbine" .. i, Vector3.new(16, 14, 30), CFrame.new(180, 8, z), C.metal, P2)
	CollectionService:AddTag(t, "Turbine")
	t:SetAttribute("Phase", 2)
	t:SetAttribute("Built", false)
	t:SetAttribute("PowerOutput", 35)
	local pad = part({ Name = "TurbinePad" .. i, Size = Vector3.new(22, 0.4, 36), CFrame = CFrame.new(180, 1.2, z),
		Color = C.power, Material = Enum.Material.DiamondPlate, Parent = P2, Tag = "BuildPad",
		Attributes = { Phase = 2, Builds = "SteamTurbine" .. i, Scrap = 20, Copper = 25, Progress = 0 } })
	label(pad, "المرحلة 2: توربين " .. i, C.power)
end

local converter = part({ Name = "EnergyConverter", Size = Vector3.new(14, 20, 14), CFrame = CFrame.new(250, 11, 0),
	Color = C.power, Material = Enum.Material.Neon, Transparency = 0.3, Parent = P2, Tag = "EnergyConverter",
	Attributes = { Efficiency = 0.6, StoredPower = 0 } })
light(converter, C.power, 40, 2)
label(converter, "محوّل الطاقة الحرارية", C.power)

for i = 1, 4 do
	placeholder("CoolingTower" .. i, Vector3.new(24, 50, 24),
		CFrame.new(275, 26, -80 + (i - 1) * 53), Color3.fromRGB(170, 170, 165), P2)
end

-- كابلات الكهرباء إلى القاعدة
for i = 0, 6 do
	part({ Name = "PowerPylon" .. i, Size = Vector3.new(2, 24, 2), CFrame = CFrame.new(150 - i * 22, 12, -60 - i * 26),
		Color = C.metal, Material = Enum.Material.Metal, Parent = P2 })
end

---------------------------------------------------------------- المرحلة 3: منصة الإطلاق (شمال)
local P3 = folder("Phase3_LaunchSite")
part({ Name = "LaunchPadBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 80, 80),
	CFrame = CFrame.new(0, 1.5, 230) * CFrame.Angles(0, 0, math.rad(90)),
	Color = C.concrete, Material = Enum.Material.Concrete, Parent = P3 })
for i = 0, 3 do
	local a = math.rad(i * 90 + 45)
	part({ Name = "LaunchTowerArm" .. i, Size = Vector3.new(4, 70, 4),
		CFrame = CFrame.new(math.cos(a) * 20, 36, 230 + math.sin(a) * 20),
		Color = C.hazard, Material = Enum.Material.Metal, Parent = P3 })
end

local rocketPad = part({ Name = "RocketBuildPad", Size = Vector3.new(26, 0.5, 26), CFrame = CFrame.new(0, 3.3, 230),
	Color = C.fuel, Material = Enum.Material.Neon, Transparency = 0.5, Parent = P3, Tag = "BuildPad",
	Attributes = { Phase = 3, Builds = "HeavyRocket", Stages = 4, Scrap = 80, Copper = 60, RefinedFuel = 40, Progress = 0 } })
label(rocketPad, "المرحلة 3: الصاروخ الثقيل", C.fuel)
placeholder("HeavyRocket", Vector3.new(14, 70, 14), CFrame.new(0, 38, 230), Color3.fromRGB(230, 230, 235), P3).PrimaryPart.Transparency = 0.8

local refinery = part({ Name = "FuelRefinery", Size = Vector3.new(30, 18, 24), CFrame = CFrame.new(-80, 9, 220),
	Color = C.metal, Material = Enum.Material.Metal, Parent = P3, Tag = "FuelRefinery",
	Attributes = { InputPerFuel = 5, SecondsPerFuel = 8 } })
light(refinery, C.fuel, 30, 2)
label(refinery, "مصفاة الوقود النووي", C.fuel)
placeholder("FuelTank", Vector3.new(12, 20, 12), CFrame.new(-110, 10, 240), C.fuel, P3)

-- مواقع أبراج الدفاع حول المنصة
local turrets = folder("TurretSlots", P3)
for i = 0, 5 do
	local a = math.rad(i * 60)
	local slot = part({ Name = "TurretSlot" .. i, Size = Vector3.new(8, 1, 8),
		CFrame = CFrame.new(math.cos(a) * 60, 0.5, 230 + math.sin(a) * 55),
		Color = C.danger, Material = Enum.Material.DiamondPlate, Parent = turrets, Tag = "TurretSlot",
		Attributes = { Built = false, Scrap = 15, Copper = 10 } })
	label(slot, "برج دفاع", C.danger)
end

---------------------------------------------------------------- نقاط ظهور الأعداء
local Enemies = folder("EnemySpawns")
for i, p in ipairs({ {-290, 290}, {290, 290}, {-290, -150}, {290, -150}, {0, 300} }) do
	part({ Name = "EnemySpawn" .. i, Size = Vector3.new(12, 1, 12), CFrame = CFrame.new(p[1], 0.5, p[2]),
		Color = C.danger, Material = Enum.Material.Neon, Transparency = 0.6, CanCollide = false,
		Parent = Enemies, Tag = "EnemySpawn", Attributes = { ActiveFromPhase = i <= 2 and 2 or 3 } })
end

---------------------------------------------------------------- الإضاءة والأجواء
Lighting.ClockTime = 18.3
Lighting.Brightness = 2
Lighting.Ambient = Color3.fromRGB(60, 45, 40)
Lighting.OutdoorAmbient = Color3.fromRGB(110, 80, 60)
Lighting.FogColor = Color3.fromRGB(120, 80, 50)
for _, cls in ipairs({ "Atmosphere", "BloomEffect", "ColorCorrectionEffect" }) do
	local e = Lighting:FindFirstChildOfClass(cls)
	if e then e:Destroy() end
end
local atm = Instance.new("Atmosphere")
atm.Density = 0.38
atm.Haze = 2.2
atm.Color = Color3.fromRGB(200, 140, 90)
atm.Decay = Color3.fromRGB(110, 60, 40)
atm.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.8
bloom.Size = 30
bloom.Threshold = 1.2
bloom.Parent = Lighting
local cc = Instance.new("ColorCorrectionEffect")
cc.Contrast = 0.12
cc.Saturation = -0.1
cc.TintColor = Color3.fromRGB(255, 235, 220)
cc.Parent = Lighting

---------------------------------------------------------------- حالة اللعبة
Map:SetAttribute("CurrentPhase", 1)
Map:SetAttribute("Phase1_TimeLimit", 600)

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print("✅ تم بناء ماب المفاعل — عدد المجسمات المؤقتة:", #CollectionService:GetTagged("HF_Placeholder"))
