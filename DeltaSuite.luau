--!strict
--[[
    DeltaSuite — Project Delta (PlaceId: 7336302630)
    Scope: Combat & Visuals/ESP with clean Obsidian Tactical UI
    Designed around Project Delta's live modules, ballistics, targeting,
    clans/factions, AiZones, LootContainers, ExitLocations, and Lighting.
]]

-- ============================================================================
-- 1. SERVICES & SESSION LIFECYCLE
-- ============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer

local function getEnv(): { [string]: any }
    local ok, env = pcall(getgenv)
    if ok and type(env) == "table" then
        return env
    end
    return _G :: any
end

local Env = getEnv()

-- Clean up prior standalone instance if executed outside Mist RUN lifecycle
if type(rawget(Env, "__DeltaSuiteStop")) == "function" then
    pcall(Env.__DeltaSuiteStop)
end

local RUN_REF: any = rawget(_G, "RUN")

local Session = {
    Alive = true,
    Connections = {} :: { RBXScriptConnection },
    TrackedInstances = {} :: { Instance },
    StopCallbacks = {} :: { () -> () },
}

function Session.IsAlive(): boolean
    if not Session.Alive then
        return false
    end
    if RUN_REF and RUN_REF.alive == false then
        return false
    end
    return true
end

function Session.Bind(signal: RBXScriptSignal, fn: (...any) -> ()): RBXScriptConnection
    local wrapped = function(...)
        if not Session.IsAlive() then
            return
        end
        fn(...)
    end
    local conn: RBXScriptConnection
    if RUN_REF and type(RUN_REF.connect) == "function" then
        conn = RUN_REF.connect(signal, wrapped)
    else
        conn = signal:Connect(wrapped)
        table.insert(Session.Connections, conn)
    end
    return conn
end

function Session.Track(inst: Instance): Instance
    if RUN_REF and type(RUN_REF.track) == "function" then
        pcall(RUN_REF.track, inst)
    else
        table.insert(Session.TrackedInstances, inst)
    end
    return inst
end

function Session.OnStop(fn: () -> ())
    if RUN_REF and type(RUN_REF.onStop) == "function" then
        pcall(RUN_REF.onStop, fn)
    end
    table.insert(Session.StopCallbacks, fn)
end

function Session.Stop()
    if not Session.Alive then
        return
    end
    Session.Alive = false
    for i = #Session.StopCallbacks, 1, -1 do
        pcall(Session.StopCallbacks[i])
    end
    table.clear(Session.StopCallbacks)
    for _, conn in ipairs(Session.Connections) do
        pcall(function()
            conn:Disconnect()
        end)
    end
    table.clear(Session.Connections)
    for _, inst in ipairs(Session.TrackedInstances) do
        pcall(function()
            inst:Destroy()
        end)
    end
    table.clear(Session.TrackedInstances)
    Env.__DeltaSuiteStop = nil
    if RUN_REF and type(RUN_REF.stop) == "function" then
        pcall(RUN_REF.stop)
    end
end

Env.__DeltaSuiteStop = Session.Stop

local function getUiParent(): Instance
    if type(gethui) == "function" then
        local ok, root = pcall(gethui)
        if ok and typeof(root) == "Instance" then
            return root
        end
    end
    local okCore = pcall(function()
        return CoreGui.Name
    end)
    if okCore then
        return CoreGui
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

-- ============================================================================
-- 2. CONFIGURATION & KEYBIND HELPERS
-- ============================================================================
export type BindValue = Enum.KeyCode | Enum.UserInputType

local function createDefaultActorLayout(isAI: boolean): { Top: { string }, Bottom: { string }, Left: { string }, Right: { string } }
    if isAI then
        return {
            Top = { "Name" },
            Bottom = { "Distance", "Health", "Weapon" },
            Left = { "HealthBar" },
            Right = {},
        }
    end
    return {
        Top = { "Name" },
        Bottom = { "Distance", "Health", "Weapon", "KDR", "Reports", "Downed" },
        Left = { "HealthBar" },
        Right = {},
    }
end

local function createDefaultTagLayout(catKey: string): { Top: { string }, Bottom: { string }, Left: { string }, Right: { string } }
    if catKey == "Container" then
        return {
            Top = { "Name" },
            Bottom = { "Distance", "Value", "Respawn" },
            Left = {},
            Right = {},
        }
    elseif catKey == "Quest Items" then
        return {
            Top = { "Name" },
            Bottom = { "Distance" },
            Left = {},
            Right = {},
        }
    end
    -- Corpse & Dropped Item
    return {
        Top = { "Name" },
        Bottom = { "Distance", "Value" },
        Left = {},
        Right = {},
    }
end

local function createDefaultConfig()
    return {
        Aimbot = {
            Enabled = false,
            Key = Enum.UserInputType.MouseButton2 :: BindValue,
            Mode = "Hold", -- Hold | Toggle | Always
            Method = "Camera", -- Camera | Mouse
            Priority = "Crosshair", -- Crosshair | Closest Dist | Lowest HP
            HitPart = "Head", -- Head | FaceHitBox | HeadTopHitBox | UpperTorso | HumanoidRootPart | Closest
            TeamCheck = true,
            VisibleCheck = true,
            LockBehindWalls = false,
            VisibleFallback = true,
            MultiPoint = true,
            StickyTarget = true,
            OnlyADS = false,
            IgnoreDowned = true,
            TargetAI = false,
            Prediction = true,
            DropComp = true,
            Smoothness = 22, -- 0 (snap) .. 95 (very smooth)
            MouseSens = 1.0,
            MaxDistance = 800,
            ShowFOV = true,
            FOVRadius = 185,
            FOVColor = Color3.fromRGB(56, 189, 248),
            FOVDynamic = true,
            FOVFilled = false,
        },
        SilentAim = {
            Enabled = false,
            Key = Enum.KeyCode.Unknown :: BindValue,
            Mode = "Always", -- Always | Hold | Toggle
            Priority = "Crosshair", -- Crosshair | Closest Dist | Lowest HP
            HitPart = "Head",
            HitChance = 100,
            TeamCheck = true,
            VisibleCheck = true,
            IgnoreDowned = true,
            TargetAI = false,
            MultiPoint = true,
            Prediction = true,
            DropComp = true,
            TargetLine = true,
            UseFOV = true,
        },
        Targeting = {
            FOV = 185,
            DynamicFOV = true,
            AimPoint = "Selected", -- Selected | Closest | Random
            AimParts = { "Head" },
            VisibleFallback = true,
            TargetAI = false,
            Wallbang = false,
            WallbangMaxWalls = 2,
            WallbangMaxThickness = 3.0,
            WallbangRespectNoPen = true,
            AddFriendKey = Enum.KeyCode.Unknown :: BindValue,
            RaycastBudget = 6,
        },
        WeaponMods = {
            NoRecoil = false,
            RecoilReduction = 100,
            NoSpread = false,
            NoSway = false,
            FastADS = false,
            ADSSpeed = 0.12,
            NoScopeDOF = false,
        },
        TriggerBot = {
            Enabled = false,
            Key = Enum.KeyCode.Unknown :: BindValue,
            Mode = "Hold", -- Hold | Toggle | Always
            DelayMs = 40,
            MaxDistance = 500,
            HitFilter = "Any", -- Any | Head Only | Body Only
            TeamCheck = true,
            IgnoreDowned = true,
            TargetAI = false,
            OnlyADS = false,
        },
        PlayerESP = {
            Enabled = true,
            Highlights = false,
            Box = "Corner", -- Off | 2D | Corner
            Name = true,
            HealthBar = true,
            HealthText = true,
            Distance = true,
            KDR = true,
            Reports = true,
            Weapon = true,
            DownedBadge = true,
            Tracers = false,
            Arrows = false,
            Skeleton = false,
            TeamCheck = false,
            MaxDistance = 1000,
            EnemyColor = Color3.fromRGB(239, 68, 68),
            SquadColor = Color3.fromRGB(34, 197, 94),
            DownedColor = Color3.fromRGB(245, 158, 11),
            ChamsFill = Color3.fromRGB(56, 189, 248),
            ChamsOutline = Color3.fromRGB(255, 255, 255),
            SkeletonColor = Color3.fromRGB(255, 64, 64),
            Layout = createDefaultActorLayout(false),
        },
        AIESP = {
            Enabled = true,
            Highlights = false,
            Box = "Corner", -- Off | 2D | Corner
            Name = true,
            HealthBar = true,
            HealthText = true,
            Distance = true,
            Weapon = true,
            Tracers = false,
            Arrows = false,
            Skeleton = false,
            MaxDistance = 750,
            Color = Color3.fromRGB(251, 146, 60),
            BossColor = Color3.fromRGB(244, 63, 94),
            ChamsFill = Color3.fromRGB(251, 146, 60),
            ChamsOutline = Color3.fromRGB(255, 255, 255),
            SkeletonColor = Color3.fromRGB(255, 138, 42),
            Layout = createDefaultActorLayout(true),
        },
        CorpseESP = {
            Enabled = true,
            Chams = false,
            Box = "Off", -- Off | 2D | Corner
            Name = true,
            Distance = true,
            Value = true,
            Tracers = false,
            Arrows = false,
            Skeleton = false,
            HideEmpty = true,
            MinPrice = 1500,
            MaxDistance = 600,
            Color = Color3.fromRGB(192, 132, 252),
            ChamsOutline = Color3.fromRGB(255, 255, 255),
            SkeletonColor = Color3.fromRGB(192, 112, 255),
            Layout = createDefaultTagLayout("Corpse"),
        },
        ContainerESP = {
            Enabled = false,
            Chams = false,
            Box = "Off", -- Off | 2D | Corner
            Name = true,
            Distance = true,
            Value = true,
            Respawn = true,
            Tracers = false,
            Arrows = false,
            HideEmpty = true,
            ValuableOnly = false,
            MinPrice = 1500,
            MaxDistance = 450,
            Color = Color3.fromRGB(96, 165, 250),
            ValuableColor = Color3.fromRGB(250, 204, 21),
            ChamsOutline = Color3.fromRGB(255, 255, 255),
            Layout = createDefaultTagLayout("Container"),
        },
        DroppedESP = {
            Enabled = false,
            Chams = false,
            Box = "Off", -- Off | 2D | Corner
            Name = true,
            Distance = true,
            Value = true,
            Tracers = false,
            Arrows = false,
            ValuableOnly = false,
            MinPrice = 1500,
            MaxDistance = 450,
            Color = Color3.fromRGB(45, 212, 191),
            ValuableColor = Color3.fromRGB(250, 204, 21),
            ChamsOutline = Color3.fromRGB(255, 255, 255),
            Layout = createDefaultTagLayout("Dropped Item"),
        },
        QuestESP = {
            Enabled = true,
            Chams = true,
            Box = "Corner", -- Off | 2D | Corner
            Name = true,
            Distance = true,
            Tracers = false,
            Arrows = false,
            MaxDistance = 1200,
            Color = Color3.fromRGB(250, 204, 21),
            ChamsOutline = Color3.fromRGB(255, 255, 255),
            Layout = createDefaultTagLayout("Quest Items"),
        },
        ExitESP = {
            Enabled = true,
            Color = Color3.fromRGB(52, 211, 153),
            MaxDistance = 2500,
            ShowTimer = true,
            Tracers = false,
        },
        World = {
            Fullbright = false,
            Brightness = 2.6,
            ClockTime = 14.0,
            NoFog = false,
            NoBlurDOF = false,
            CustomFOV = false,
            FOVValue = 90,

            TerrainColorEnabled = false,
            TerrainPreset = "Default", -- Default | Cyber | Arctic | Mars | Custom
            TerrainGrassColor = Color3.fromRGB(68, 128, 72),
            TerrainGroundColor = Color3.fromRGB(82, 74, 62),
            TerrainRockColor = Color3.fromRGB(95, 98, 105),

            LeavesEnabled = false,
            LeavesColor = Color3.fromRGB(56, 189, 248),
            LeavesHide = false,
            LeavesTransparency = 0,

            TrunksEnabled = false,
            TrunksColor = Color3.fromRGB(72, 58, 48),
            TrunksHide = false,
            TrunksTransparency = 0,

            WaterColorEnabled = false,
            WaterColor = Color3.fromRGB(14, 92, 112),

            NoGrass = false,
            NoMines = false,

            RenderPlayers = false,
            BossChecker = false,
            BossNotify = true,
            BossShowHUD = true,
            BossAlertEvents = true,

            Radar = false,
            RadarSize = 156,
            RadarRange = 320,
            RadarRotate = true,
            RadarPlayers = true,
            RadarNPC = true,
            RadarCorpses = false,
            RadarExits = true,
            RadarX = 24,
            RadarY = 180,

            LightEnabled = false,
            AmbientColor = Color3.fromRGB(130, 135, 145),
            OutdoorAmbientColor = Color3.fromRGB(155, 160, 170),
            Exposure = 0.0,

            TimeSunEnabled = false,
            Latitude = 41.0,

            ShadowsEnabled = false,
            DisableShadows = true,
            ShadowSoftness = 0.25,
            DiffuseScale = 1.0,

            RenderingEnabled = false,
            ExposureBias = 0.0,

            FogEnabled = false,
            FogStart = 0,
            FogEnd = 100000,
            FogColor = Color3.fromRGB(160, 175, 195),

            AtmosphereEnabled = false,
            AtmoDensity = 0.2,
            AtmoHaze = 0.5,
            AtmoGlare = 0.0,
            AtmoOffset = 0.0,
            AtmoColor = Color3.fromRGB(175, 195, 220),

            SkyEnabled = false,
            SkyPreset = "Night Space",
            SkyStars = 3500,
            SkyCelestial = true,

            CloudsEnabled = false,
            CloudsCover = 0.55,
            CloudsDensity = 0.65,
            CloudsColor = Color3.fromRGB(220, 230, 245),

            BloomEnabled = false,
            DisableBloom = true,
            BloomIntensity = 0.6,
            BloomSize = 24,
            BloomThreshold = 1.2,

            BlurEnabled = false,
            BlurSize = 0,
        },
        Misc = {
            FastTrade = false,
            PanicMode = false,
            PanicKey = Enum.KeyCode.End :: BindValue,
            PanicHideVisuals = true,
            PanicDisableCombat = true,
            PanicHideMenu = true,
            PassDoor = false,
            PassDoorKey = Enum.KeyCode.Unknown :: BindValue,
            PassDoorMode = "Always", -- Always | Hold | Toggle
            PassDoorRange = 18,
            PassDoorAutoOpen = true,
            ScreenEffects = false,
            ReportNotify = true,
            ReportAlertSelf = true,
            ReportAlertServer = false,
            ReportsHUD = false,
            JoinNotify = false,
            JoinAlertFlaggedOnly = false,
            JoinLeaveAlerts = false,
            JoinShowAge = true,
        },
        Detect = {
            ContentCreator = false,
            ContentCreatorNotify = true,
            ContentCreatorBadge = true,
            Tester = false,
            TesterNotify = true,
            TesterBadge = true,
            Moderator = true,
            ModeratorNotify = true,
            ModeratorBadge = true,
            Cheater = false,
            CheaterNotify = true,
            CheaterBadge = true,
            CheaterMinFlags = 25,
            CheaterMinHSR = 75,
            CheaterMinKDR = 5.0,
        },
        Settings = {
            MenuKey = Enum.KeyCode.RightControl :: BindValue,
            Watermark = true,
            TargetHUD = true,
            Notifications = true,
            FontSize = 13,
            MenuTransparency = 22, -- 0..45 (%) glass UI translucency
        },
    }
end

local Config = createDefaultConfig()

local ToggleStates: { [string]: boolean } = {}
local KeyHoldStates: { [EnumItem]: boolean } = {}

local function formatBindName(bind: any): string
    if typeof(bind) ~= "EnumItem" then
        return "None"
    end
    if bind == Enum.KeyCode.Unknown then
        return "None"
    end
    if bind == Enum.UserInputType.MouseButton1 then
        return "LMB"
    elseif bind == Enum.UserInputType.MouseButton2 then
        return "RMB"
    elseif bind == Enum.UserInputType.MouseButton3 then
        return "MB3"
    end
    local name = bind.Name
    if name == "RightControl" then
        return "RCtrl"
    elseif name == "LeftControl" then
        return "LCtrl"
    elseif name == "RightShift" then
        return "RShift"
    elseif name == "LeftShift" then
        return "LShift"
    end
    return name
end

local function isBindInputDown(bind: any): boolean
    if typeof(bind) ~= "EnumItem" or bind == Enum.KeyCode.Unknown then
        return false
    end
    if bind.EnumType == Enum.UserInputType then
        return UserInputService:IsMouseButtonPressed(bind :: Enum.UserInputType)
    elseif bind.EnumType == Enum.KeyCode then
        return UserInputService:IsKeyDown(bind :: Enum.KeyCode)
    end
    return KeyHoldStates[bind] == true
end

local function isModeActive(id: string, enabled: boolean, mode: string, bind: any): boolean
    if not enabled then
        return false
    end
    if mode == "Always" then
        return true
    elseif mode == "Toggle" then
        if typeof(bind) ~= "EnumItem" or bind == Enum.KeyCode.Unknown then
            return ToggleStates[id] ~= false
        end
        return ToggleStates[id] == true
    end
    if typeof(bind) ~= "EnumItem" or bind == Enum.KeyCode.Unknown then
        return false
    end
    return isBindInputDown(bind)
end

-- ============================================================================
-- 3. PROJECT DELTA GAME STATE, CLANS, BALLISTICS & VISIBILITY
-- ============================================================================
local Delta = {}

local RSPlayersFolder: Folder? = ReplicatedStorage:FindFirstChild("Players") :: Folder?
local ClansFolder: Folder? = ReplicatedStorage:FindFirstChild("Clans") :: Folder?
local AmmoTypesFolder: Folder? = ReplicatedStorage:FindFirstChild("AmmoTypes") :: Folder?
local RangedWeaponsFolder: Folder? = ReplicatedStorage:FindFirstChild("RangedWeapons") :: Folder?
local ItemsListFolder: Folder? = ReplicatedStorage:FindFirstChild("ItemsList") :: Folder?

local FactionRelations: any = nil
local FunctionLibraryExt: any = nil
do
    local modulesFolder = ReplicatedStorage:FindFirstChild("Modules")
    local frMod = modulesFolder and modulesFolder:FindFirstChild("FactionRelations")
    if frMod and frMod:IsA("ModuleScript") then
        local ok, mod = pcall(require, frMod)
        if ok and type(mod) == "table" then
            FactionRelations = mod
        end
    end
    local fleMod = modulesFolder and modulesFolder:FindFirstChild("FunctionLibraryExtension")
    if fleMod and fleMod:IsA("ModuleScript") then
        local ok, mod = pcall(require, fleMod)
        if ok and type(mod) == "table" then
            FunctionLibraryExt = mod
        end
    end
end

local ItemsPriceCache: { [string]: { Name: string, Type: string, Price: number } } = {}
if ItemsListFolder then
    for _, itemFolder in ipairs(ItemsListFolder:GetChildren()) do
        local props = itemFolder:FindFirstChild("ItemProperties")
        if props then
            local dispName = props:GetAttribute("CallSign") or props:GetAttribute("ItemName") or itemFolder.Name
            local itemType = tostring(props:GetAttribute("ItemType") or "")
            local price = tonumber(props:GetAttribute("Price")) or 0
            ItemsPriceCache[itemFolder.Name] = {
                Name = tostring(dispName),
                Type = itemType,
                Price = price,
            }
        end
    end
end

function Delta.GetItemValue(item: Instance, includeNested: boolean?): (number, number, string)
    local info = ItemsPriceCache[item.Name]
    local props = item:FindFirstChild("ItemProperties")
    local unitPrice = (info and info.Price)
        or tonumber(item:GetAttribute("Price"))
        or (props and tonumber(props:GetAttribute("Price")))
        or 0
    local amount = tonumber(item:GetAttribute("Amount"))
        or (props and tonumber(props:GetAttribute("Amount")))
        or 1
    if unitPrice == 0 and (item.Name == "Rubles" or (info and info.Name == "Rubles")) then
        unitPrice = 1
    elseif unitPrice == 0 and info and (info.Type == "Key" or info.Type == "Keycard") then
        unitPrice = 5000
    end
    local total = unitPrice * math.max(amount, 1)
    if includeNested then
        for _, folderName in ipairs({ "Inventory", "Attachments", "Bullets" }) do
            local subFolder = item:FindFirstChild(folderName)
            if subFolder then
                for _, sub in ipairs(subFolder:GetChildren()) do
                    local subVal = Delta.GetItemValue(sub, true)
                    total += subVal
                end
            end
        end
    end
    local dispName = (info and info.Name) or item.Name
    return total, unitPrice, dispName
end

function Delta.GetRSPlayer(player: Player): Instance?
    if not RSPlayersFolder then
        RSPlayersFolder = ReplicatedStorage:FindFirstChild("Players") :: Folder?
    end
    return RSPlayersFolder and RSPlayersFolder:FindFirstChild(player.Name)
end

function Delta.IsPlayerDowned(player: Player, model: Model?): boolean
    if model then
        local hum = model:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then
            return true
        end
    end
    local rsPlayer = Delta.GetRSPlayer(player)
    local status = rsPlayer and rsPlayer:FindFirstChild("Status")
    local gv = status and status:FindFirstChild("GameplayVariables")
    if gv then
        local unc = gv:FindFirstChild("Unconscious")
        if unc and unc:IsA("ObjectValue") and unc.Value ~= nil then
            return true
        end
        local activeRag = gv:FindFirstChild("ActiveRagdoll")
        if activeRag and activeRag:IsA("ObjectValue") and activeRag.Value ~= nil then
            return true
        end
        local deadState = gv:GetAttribute("DeadState")
        if type(deadState) == "string" and deadState ~= "" then
            return true
        end
    end
    return false
end

local SquadMemberCache: { [string]: boolean } = {}
local LocalClanCache: string? = nil
local LastSquadScan = 0

local function isInvalidClanName(s: any): boolean
    if type(s) ~= "string" then
        return true
    end
    local clean = s:lower():gsub("%s+", "")
    return clean == "" or clean == "nil" or clean == "none" or clean == "null" or clean == "false" or clean == "default"
end

local function readPlayerClan(player: Player): string?
    local rsPlayer = Delta.GetRSPlayer(player)
    local journey = rsPlayer and rsPlayer:FindFirstChild("Status") and rsPlayer.Status:FindFirstChild("Journey")
    local clanFolder = journey and journey:FindFirstChild("Clan")
    if not clanFolder then
        return nil
    end
    local cur = clanFolder:GetAttribute("CurrentClan")
    if not isInvalidClanName(cur) then
        return cur
    end
    return nil
end

local function refreshSquadCache()
    local now = os.clock()
    if now - LastSquadScan < 0.5 then
        return
    end
    LastSquadScan = now
    table.clear(SquadMemberCache)
    LocalClanCache = readPlayerClan(LocalPlayer)

    if not ClansFolder then
        ClansFolder = ReplicatedStorage:FindFirstChild("Clans") :: Folder?
    end
    if not ClansFolder then
        return
    end

    local myTeamName = LocalPlayer.Name .. "'s team"
    for _, clan in ipairs(ClansFolder:GetChildren()) do
        local isMyClan = (clan.Name == myTeamName)
            or (clan:GetAttribute("Owner") == LocalPlayer.Name)
            or (LocalClanCache ~= nil and clan.Name == LocalClanCache)
            or (clan:FindFirstChild(LocalPlayer.Name) ~= nil)
        if isMyClan then
            local ownerAttr = clan:GetAttribute("Owner")
            local ownerName = (type(ownerAttr) == "string" and ownerAttr) or clan.Name:match("^(.+)'s team$")
            if ownerName and ownerName ~= LocalPlayer.Name then
                local ownerPlr = Players:FindFirstChild(ownerName) :: Player?
                local ownerClan = ownerPlr and readPlayerClan(ownerPlr)
                if not ownerClan or ownerClan == clan.Name or ownerClan == LocalClanCache then
                    SquadMemberCache[ownerName] = true
                end
            end
            for _, member in ipairs(clan:GetChildren()) do
                if member.Name ~= LocalPlayer.Name then
                    local memPlr = Players:FindFirstChild(member.Name) :: Player?
                    local memClan = memPlr and readPlayerClan(memPlr)
                    if not memClan or memClan == clan.Name or memClan == LocalClanCache then
                        SquadMemberCache[member.Name] = true
                    end
                end
            end
        end
    end
end

function Delta.IsPlayerProtected(player: Player, model: Model?): boolean
    if model and model:FindFirstChildOfClass("ForceField") then
        return true
    end
    local rsPlayer = Delta.GetRSPlayer(player)
    local gv = rsPlayer and rsPlayer:FindFirstChild("Status") and rsPlayer.Status:FindFirstChild("GameplayVariables")
    if gv then
        if gv:GetAttribute("GodMode") == true then
            return true
        end
        if gv:GetAttribute("Spawned") == false then
            return true
        end
    end
    return false
end

local FriendsWhitelist: { [number]: boolean } = {}

function Delta.IsFriend(player: Player): boolean
    return FriendsWhitelist[player.UserId] == true
end

function Delta.ClearFriends()
    table.clear(FriendsWhitelist)
end

function Delta.IsTeammate(player: Player): boolean
    if player == LocalPlayer then
        return true
    end
    if FriendsWhitelist[player.UserId] then
        return true
    end
    if LocalPlayer.Team ~= nil and player.Team == LocalPlayer.Team then
        return true
    end
    refreshSquadCache()
    if SquadMemberCache[player.Name] then
        return true
    end
    if LocalClanCache then
        local targetClan = readPlayerClan(player)
        if targetClan and targetClan == LocalClanCache then
            return true
        end
    end
    return false
end

local PlayerMetaCache: { [Player]: { KDR: string?, ReportListFlags: number, UpdatedAt: number } } = {}

local function readNumericStat(sources: { Instance? }, keys: { string }): number?
    for _, src in ipairs(sources) do
        if src then
            for _, key in ipairs(keys) do
                local attr = src:GetAttribute(key)
                if type(attr) == "number" then
                    return attr
                end
                local ch = src:FindFirstChild(key)
                if ch and (ch:IsA("NumberValue") or ch:IsA("IntValue")) then
                    return (ch :: any).Value
                end
            end
        end
    end
    return nil
end

local function findReportListFolder(reportList: Instance?, player: Player): Instance?
    if not reportList then
        return nil
    end
    local repKey = player.Name .. "_" .. tostring(player.UserId)
    local mw = reportList:FindFirstChild("MostWanted")
    local rec = reportList:FindFirstChild("Recent")
    local exact = (mw and mw:FindFirstChild(repKey))
        or (rec and rec:FindFirstChild(repKey))
        or reportList:FindFirstChild(repKey)
    if exact then
        return exact
    end
    for _, bucket in ipairs({ mw, rec }) do
        if bucket then
            for _, ch in ipairs(bucket:GetChildren()) do
                if ch:GetAttribute("UserId") == player.UserId or ch:GetAttribute("UserName") == player.Name then
                    return ch
                end
            end
        end
    end
    return nil
end

function Delta.IsPlayerBeingBanned(rsPlayer: Instance?): boolean
    local status = rsPlayer and rsPlayer:FindFirstChild("Status")
    local uac = status and status:FindFirstChild("UAC")
    return (uac and uac:GetAttribute("BeingBanned") == true) or false
end

function Delta.GetUACReportCount(rsPlayer: Instance?): number
    local status = rsPlayer and rsPlayer:FindFirstChild("Status")
    local uac = status and status:FindFirstChild("UAC")
    local reportsFolder = uac and uac:FindFirstChild("Reports")
    if not reportsFolder then
        return 0
    end
    local sum = 0
    for _, val in pairs(reportsFolder:GetAttributes()) do
        if type(val) == "number" then
            sum += val
        end
    end
    local kids = #reportsFolder:GetChildren()
    if kids > sum then
        sum = kids
    end
    return sum
end

function Delta.GetPlayerMeta(player: Player): (string?, number, boolean)
    local rsPlayer = Delta.GetRSPlayer(player)
    local uacReports = Delta.GetUACReportCount(rsPlayer)
    local beingBanned = Delta.IsPlayerBeingBanned(rsPlayer)

    local cached = PlayerMetaCache[player]
    local now = os.clock()
    if cached and cached.KDR ~= nil and (now - cached.UpdatedAt) < 1.5 then
        return cached.KDR, math.max(uacReports, cached.ReportListFlags), beingBanned
    end

    local status = rsPlayer and rsPlayer:FindFirstChild("Status")
    local journey = status and status:FindFirstChild("Journey")
    -- Project Delta's ReportGui computes official player K/D/R from Status.Journey.Statistics (career PvP stats)
    local careerStats = journey and journey:FindFirstChild("Statistics")
    local wipeStats = journey and journey:FindFirstChild("WipeStatistics")
    local statsF = (rsPlayer and (rsPlayer:FindFirstChild("Stats") or rsPlayer:FindFirstChild("StartUp"))) or nil
    local leader = player:FindFirstChild("leaderstats")
    local sources: { Instance? } = { careerStats, wipeStats, journey, status, rsPlayer, player, leader, statsF }

    local kdrStr: string? = nil
    local rlFlags = 0

    -- Compute live PvP KDR cleanly from the same stat container (career Statistics first, then WipeStatistics)
    for _, statNode in ipairs({ careerStats, wipeStats, statsF }) do
        if statNode then
            local kp = statNode:GetAttribute("K_PVP")
            local dp = statNode:GetAttribute("D_PVP")
            if type(kp) == "number" then
                kdrStr = string.format("%.2f", kp / math.max(type(dp) == "number" and dp or 0, 1))
                break
            end
        end
    end

    -- Fallback: ReplicatedStorage.ReportList (MostWanted & Recent carry "Kills/Deaths/Ratio" & TotalFlags)
    local repFolder = findReportListFolder(ReplicatedStorage:FindFirstChild("ReportList"), player)
    if repFolder then
        if not kdrStr then
            local rawKdr = repFolder:GetAttribute("KDR")
            if type(rawKdr) == "string" and rawKdr ~= "" then
                local killsPart, deathsPart, ratioPart = rawKdr:match("^(%d+)/(%d+)/([^/]+)$")
                if killsPart and deathsPart then
                    local kn, dn = tonumber(killsPart) or 0, tonumber(deathsPart) or 0
                    kdrStr = string.format("%.2f", kn / math.max(dn, 1))
                else
                    kdrStr = ratioPart or rawKdr:match("/([^/]+)$") or rawKdr
                end
            elseif type(rawKdr) == "number" then
                kdrStr = string.format("%.2f", rawKdr)
            end
        end
        local flags = repFolder:GetAttribute("TotalFlags")
        if type(flags) == "number" then
            rlFlags = math.max(rlFlags, flags)
        end
    end

    if not kdrStr then
        local kdrNum = readNumericStat(sources, { "KDR", "KD", "KillDeathRatio" })
        if kdrNum ~= nil then
            kdrStr = string.format("%.2f", kdrNum)
        else
            for _, src in ipairs(sources) do
                if src then
                    local kills = readNumericStat({ src }, { "K_PVP", "Kills", "PlayerKills", "Eliminations" })
                    local deaths = readNumericStat({ src }, { "D_PVP", "Deaths" })
                    if kills ~= nil then
                        kdrStr = string.format("%.2f", kills / math.max(deaths or 0, 1))
                        break
                    end
                end
            end
        end
    end

    local statRep = readNumericStat(sources, { "TotalFlags", "Reports", "ReportCount", "TotalReports" })
    if statRep then
        rlFlags = math.max(rlFlags, statRep)
    end

    if kdrStr or rlFlags > 0 then
        PlayerMetaCache[player] = { KDR = kdrStr, ReportListFlags = rlFlags, UpdatedAt = now }
    end
    return kdrStr, math.max(uacReports, rlFlags), beingBanned
end

function Delta.GetContainerRespawnText(inst: Instance): string?
    local props = inst:FindFirstChild("Properties")
    local sources: { Instance? } = { inst, props }
    local nextTime = readNumericStat(sources, { "NextRespawn", "RespawnAt", "RespawnTimestamp" })
    if nextTime and nextTime > 0 then
        local rem = nextTime - Workspace:GetServerTimeNow()
        if rem > 0 and rem < 86400 then
            return string.format("Respawn: %.0fs", rem)
        end
    end
    local timerVal = readNumericStat(sources, { "RespawnTime", "RespawnTimer", "TimeToRespawn", "Cooldown", "Respawn" })
    if timerVal and timerVal > 0 then
        return string.format("Respawn: %.0fs", timerVal)
    end
    for _, src in ipairs(sources) do
        if src then
            local opened = src:GetAttribute("Opened")
            if opened == true then
                return "Looted"
            end
        end
    end
    return nil
end

function Delta.IsQuestObject(inst: Instance): boolean
    if inst:GetAttribute("ItemId") ~= nil or inst:GetAttribute("Quest") ~= nil or inst:GetAttribute("QuestItem") == true or inst:GetAttribute("IsQuestItem") == true then
        return true
    end
    local props = inst:FindFirstChild("ItemProperties")
    if props and props:GetAttribute("Collectable") == true then
        return true
    end
    local info = ItemsPriceCache[inst.Name]
    if info and info.Type:lower():find("quest") then
        return true
    end
    local ln = inst.Name:lower()
    if ln:find("quest") or ln:find("objective") then
        return true
    end
    return false
end

function Delta.GetHeldWeaponName(player: Player?, model: Model?): string?
    if model then
        local holding = model:FindFirstChild("Holding")
        if holding and holding:IsA("ObjectValue") and holding.Value then
            return holding.Value.Name
        end
    end
    if player then
        local rsPlayer = Delta.GetRSPlayer(player)
        local gv = rsPlayer and rsPlayer:FindFirstChild("Status") and rsPlayer.Status:FindFirstChild("GameplayVariables")
        local eq = gv and gv:FindFirstChild("EquippedTool")
        if eq and eq:IsA("ObjectValue") and eq.Value then
            return eq.Value.Name
        end
    end
    return nil
end

function Delta.IsLocalADS(): boolean
    local rsPlayer = Delta.GetRSPlayer(LocalPlayer)
    local gv = rsPlayer and rsPlayer:FindFirstChild("Status") and rsPlayer.Status:FindFirstChild("GameplayVariables")
    if gv and gv:GetAttribute("Aiming") == true then
        return true
    end
    return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
end

-- Exact bullet origin used by Project Delta's Bullet module (accounts for Lean & Crouch offsets)
function Delta.GetShotOrigin(): Vector3
    if FunctionLibraryExt and type(FunctionLibraryExt.GetEstimatedCameraPosition) == "function" then
        local ok, pos = pcall(FunctionLibraryExt.GetEstimatedCameraPosition, FunctionLibraryExt, LocalPlayer)
        if ok and typeof(pos) == "Vector3" then
            return pos
        end
    end
    local cam = Workspace.CurrentCamera
    return cam and cam.CFrame.Position or Vector3.zero
end

local OriginalAmmoSpread: { [Instance]: any } = {}

function Delta.GetBallisticsForAmmo(ammoName: string?): ({ Velocity: number, Drop: number, Drag: number }, Instance?)
    local defaultVel, defaultDrop, defaultDrag = 2200, 4.6, 0.013
    if ammoName and ammoName ~= "" and AmmoTypesFolder then
        local ammoInst = AmmoTypesFolder:FindFirstChild(ammoName)
        if ammoInst then
            local vel = tonumber(ammoInst:GetAttribute("MuzzleVelocity")) or defaultVel
            local drop = tonumber(ammoInst:GetAttribute("ProjectileDrop")) or defaultDrop
            local drag = tonumber(ammoInst:GetAttribute("Drag")) or defaultDrag
            return { Velocity = vel, Drop = drop, Drag = drag }, ammoInst
        end
    end
    return { Velocity = defaultVel, Drop = defaultDrop, Drag = defaultDrag }, nil
end

function Delta.GetLocalBallistics(): { Velocity: number, Drop: number, Drag: number }
    local char = LocalPlayer.Character
    local rsPlayer = Delta.GetRSPlayer(LocalPlayer)
    local gv = rsPlayer and rsPlayer:FindFirstChild("Status") and rsPlayer.Status:FindFirstChild("GameplayVariables")
    local tool: Instance? = nil

    if gv then
        local eq = gv:FindFirstChild("EquippedTool")
        if eq and eq:IsA("ObjectValue") and eq.Value then
            tool = eq.Value
        end
    end
    if not tool and char then
        local holding = char:FindFirstChild("Holding")
        if holding and holding:IsA("ObjectValue") and holding.Value then
            tool = holding.Value
        end
    end
    if not tool then
        return { Velocity = 2200, Drop = 4.6, Drag = 0.013 }
    end

    local ammoName: string? = nil
    local attachments = tool:FindFirstChild("Attachments")
    if attachments then
        for _, att in ipairs(attachments:GetChildren()) do
            local loaded = att:GetAttribute("LoadedAmmo")
            if type(loaded) == "string" and loaded ~= "" then
                ammoName = loaded
                break
            end
            local props = att:FindFirstChild("ItemProperties")
            if props and props:GetAttribute("SlotType") == "Magazine" then
                local bullets = att:FindFirstChild("Bullets")
                local first = bullets and bullets:FindFirstChild("1")
                if first then
                    local at = first:GetAttribute("AmmoType")
                    if type(at) == "string" and at ~= "" then
                        ammoName = at
                        break
                    end
                end
            end
        end
    end
    if not ammoName then
        local bullets = tool:FindFirstChild("Bullets")
        local first = bullets and bullets:FindFirstChild("1")
        if first then
            local at = first:GetAttribute("AmmoType")
            if type(at) == "string" and at ~= "" then
                ammoName = at
            end
        end
    end
    if not ammoName and RangedWeaponsFolder then
        local rw = RangedWeaponsFolder:FindFirstChild(tool.Name)
        if rw then
            local da = rw:GetAttribute("DefaultAmmo")
            if type(da) == "string" and da ~= "" then
                ammoName = da
            end
        end
    end

    local ballistics = Delta.GetBallisticsForAmmo(ammoName)
    return ballistics
end

local HITPART_CANDIDATES: { [string]: { string } } = {
    Head = { "Head", "FaceHitBox", "HumanoidRootPart" },
    FaceHitBox = { "FaceHitBox", "Head", "HumanoidRootPart" },
    HeadTopHitBox = { "HeadTopHitBox", "Head", "FaceHitBox" },
    UpperTorso = { "UpperTorso", "Torso", "HumanoidRootPart" },
    HumanoidRootPart = { "HumanoidRootPart", "UpperTorso", "Torso" },
}

local CLOSEST_SCAN_PARTS = { "FaceHitBox", "Head", "UpperTorso", "LowerTorso", "HumanoidRootPart" }
local FALLBACK_SCAN_PARTS = { "Head", "FaceHitBox", "UpperTorso", "LowerTorso", "HumanoidRootPart", "LeftUpperArm", "RightUpperArm", "LeftLowerLeg", "RightLowerLeg" }
local TargetRng = Random.new()

function Delta.ResolveTargetPart(model: Model, mode: string, refScreenPos: Vector2?, cam: Camera?): BasePart?
    if mode == "Closest" and cam and refScreenPos then
        local bestPart: BasePart? = nil
        local bestDist = math.huge
        for _, partName in ipairs(CLOSEST_SCAN_PARTS) do
            local p = model:FindFirstChild(partName)
            if p and p:IsA("BasePart") then
                local screen, onScreen = cam:WorldToViewportPoint(p.Position)
                if onScreen then
                    local d = (Vector2.new(screen.X, screen.Y) - refScreenPos).Magnitude
                    if d < bestDist then
                        bestDist = d
                        bestPart = p
                    end
                end
            end
        end
        if bestPart then
            return bestPart
        end
    end

    local candidates = HITPART_CANDIDATES[mode] or HITPART_CANDIDATES.Head
    for _, name in ipairs(candidates) do
        local p = model:FindFirstChild(name)
        if p and p:IsA("BasePart") then
            return p
        end
    end
    return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end

local function buildCandidateParts(
    model: Model,
    hitPart: string,
    aimPoint: string?,
    aimParts: { string }?,
    visibleFallback: boolean?,
    allowRandom: boolean?,
    aim2D: Vector2,
    cam: Camera
): { BasePart }
    local out: { BasePart } = {}
    local seen: { [BasePart]: boolean } = {}
    local function pushPart(p: BasePart?)
        if p and p:IsA("BasePart") and not seen[p] then
            seen[p] = true
            table.insert(out, p)
        end
    end

    local primary: { BasePart } = {}
    local primarySeen: { [BasePart]: boolean } = {}
    local useClosestScan = (hitPart == "Closest" and (not aimParts or #aimParts <= 1))
    local sourceNames = useClosestScan and CLOSEST_SCAN_PARTS or (aimParts and #aimParts > 0 and aimParts or nil)

    if sourceNames then
        for _, name in ipairs(sourceNames) do
            local p = model:FindFirstChild(name)
            if p and p:IsA("BasePart") and not primarySeen[p] then
                primarySeen[p] = true
                table.insert(primary, p)
            end
        end
    end

    if #primary == 0 then
        local resolved = Delta.ResolveTargetPart(model, hitPart, aim2D, cam)
        if resolved then
            table.insert(primary, resolved)
        end
    end

    local ptMode = aimPoint or "Selected"
    if (ptMode == "Closest" or useClosestScan) and #primary > 1 then
        table.sort(primary, function(a, b)
            local sa, oa = cam:WorldToViewportPoint(a.Position)
            local sb, ob = cam:WorldToViewportPoint(b.Position)
            local da = oa and (Vector2.new(sa.X, sa.Y) - aim2D).Magnitude or math.huge
            local db = ob and (Vector2.new(sb.X, sb.Y) - aim2D).Magnitude or math.huge
            return da < db
        end)
    elseif ptMode == "Random" and #primary > 1 then
        if allowRandom then
            for i = #primary, 2, -1 do
                local j = TargetRng:NextInteger(1, i)
                primary[i], primary[j] = primary[j], primary[i]
            end
        else
            local idx = (math.floor(os.clock() * 2.5) % #primary) + 1
            if idx ~= 1 then
                primary[1], primary[idx] = primary[idx], primary[1]
            end
        end
    end

    for _, p in ipairs(primary) do
        pushPart(p)
    end

    if visibleFallback then
        for _, name in ipairs(FALLBACK_SCAN_PARTS) do
            local p = model:FindFirstChild(name)
            if p and p:IsA("BasePart") then
                pushPart(p)
            end
        end
    end

    return out
end

export type WallbangConfig = {
    Enabled: boolean,
    MaxWalls: number,
    MaxThickness: number,
    RespectNoPen: boolean,
}

-- Visibility raycast matching Project Delta WeaponRay + PassThrough / Glass / NoCollision & Wallbang penetration
function Delta.IsPartVisible(
    targetModel: Model,
    targetPart: BasePart,
    originPos: Vector3,
    wallbang: WallbangConfig?,
    rayBudget: { Remaining: number }?,
    overrideWorldPos: Vector3?
): boolean
    local cam = Workspace.CurrentCamera
    local ignoreList: { Instance } = {}
    if LocalPlayer.Character then
        table.insert(ignoreList, LocalPlayer.Character)
    end
    if cam then
        table.insert(ignoreList, cam)
    end
    local noCol = Workspace:FindFirstChild("NoCollision")
    if noCol then
        table.insert(ignoreList, noCol)
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true
    pcall(function()
        params.CollisionGroup = "WeaponRay"
    end)

    local revParams = RaycastParams.new()
    revParams.FilterType = Enum.RaycastFilterType.Include
    revParams.IgnoreWater = true

    local currentOrigin = originPos
    local destination = overrideWorldPos or targetPart.Position
    local wallsUsed = 0
    local totalThickness = 0

    for _ = 1, 12 do
        local deltaVec = destination - currentOrigin
        if deltaVec.Magnitude < 0.25 then
            return true
        end
        if rayBudget then
            if rayBudget.Remaining <= 0 then
                return false
            end
            rayBudget.Remaining -= 1
        end
        params.FilterDescendantsInstances = ignoreList
        local res = Workspace:Raycast(currentOrigin, deltaVec, params)
        if not res then
            return true
        end
        local hit = res.Instance
        if hit:IsDescendantOf(targetModel) then
            return true
        end
        local realParent = hit:FindFirstChild("RealParent")
        if realParent and realParent:IsA("ObjectValue") and realParent.Value and (realParent.Value == targetModel or realParent.Value:IsDescendantOf(targetModel)) then
            return true
        end
        local isPassThrough = hit:GetAttribute("PassThrough") ~= nil
            or hit:GetAttribute("Glass") ~= nil
            or (hit:IsA("BasePart") and (hit.Material == Enum.Material.Glass or hit.Transparency >= 0.9 or not hit.CanCollide))
        if isPassThrough then
            table.insert(ignoreList, hit)
            currentOrigin = res.Position + deltaVec.Unit * 0.06
        elseif wallbang and wallbang.Enabled then
            if wallbang.RespectNoPen and hit:GetAttribute("NoPen") == true then
                return false
            end
            wallsUsed += 1
            if wallsUsed > math.max(1, wallbang.MaxWalls) then
                return false
            end
            local remainingThick = math.max(0.05, wallbang.MaxThickness - totalThickness)
            if rayBudget then
                if rayBudget.Remaining <= 0 then
                    return false
                end
                rayBudget.Remaining -= 1
            end
            local dirUnit = deltaVec.Unit
            local probeStart = res.Position + dirUnit * (remainingThick + 0.15)
            revParams.FilterDescendantsInstances = { hit }
            local exitRes = Workspace:Raycast(probeStart, res.Position - dirUnit * 0.05 - probeStart, revParams)
            if not exitRes then
                return false
            end
            local exitAlong = (exitRes.Position - res.Position):Dot(dirUnit)
            local wallThick = math.max(0, exitAlong)
            local targetAlong = (destination - res.Position):Dot(dirUnit)
            if targetAlong <= wallThick and targetAlong <= remainingThick then
                return true
            end
            totalThickness += wallThick
            if totalThickness > wallbang.MaxThickness then
                return false
            end
            table.insert(ignoreList, hit)
            currentOrigin = exitRes.Position + dirUnit * 0.06
        else
            return false
        end
    end
    return false
end

function Delta.FindVisiblePartPoint(
    targetModel: Model,
    targetPart: BasePart,
    originPos: Vector3,
    wallbang: WallbangConfig?,
    rayBudget: { Remaining: number }?,
    multiPoint: boolean?
): Vector3?
    if Delta.IsPartVisible(targetModel, targetPart, originPos, wallbang, rayBudget, nil) then
        return targetPart.Position
    end
    if not multiPoint or (rayBudget and rayBudget.Remaining <= 0) then
        return nil
    end

    local sz = targetPart.Size
    local cf = targetPart.CFrame
    local lname = targetPart.Name:lower()
    local offsets: { Vector3 }
    if lname:find("head") or lname:find("face") then
        offsets = {
            Vector3.new(0, 0.36 * sz.Y, 0),
            Vector3.new(-0.34 * sz.X, 0.14 * sz.Y, 0),
            Vector3.new(0.34 * sz.X, 0.14 * sz.Y, 0),
            Vector3.new(0, -0.25 * sz.Y, 0),
        }
    else
        offsets = {
            Vector3.new(-0.34 * sz.X, 0.18 * sz.Y, 0),
            Vector3.new(0.34 * sz.X, 0.18 * sz.Y, 0),
            Vector3.new(0, 0.34 * sz.Y, 0),
        }
    end

    for _, off in ipairs(offsets) do
        if rayBudget and rayBudget.Remaining <= 0 then
            break
        end
        local probeWorld = cf:PointToWorldSpace(off)
        if Delta.IsPartVisible(targetModel, targetPart, originPos, wallbang, rayBudget, probeWorld) then
            return probeWorld
        end
    end
    return nil
end

function Delta.PredictAimPosition(
    originPos: Vector3,
    targetPart: BasePart,
    useLead: boolean,
    useDrop: boolean,
    ballisticsOverride: { Velocity: number, Drop: number, Drag: number? }?,
    overrideWorldPos: Vector3?
): Vector3
    local pos = overrideWorldPos or targetPart.Position
    if not useLead and not useDrop then
        return pos
    end
    local ballistics = ballisticsOverride or Delta.GetLocalBallistics()
    local speed = math.max(ballistics.Velocity, 100)
    local drag = math.max(ballistics.Drag or 0.013, 0)
    local vel = useLead and targetPart.AssemblyLinearVelocity or Vector3.zero
    if vel.Magnitude < 0.5 then
        vel = Vector3.zero
    end
    -- Project Delta Bullet.onStep gravity (-70 * ProjectileDrop / 4.6) + exponential drag velocity decay
    local gravity = useDrop and (70 * (ballistics.Drop / 4.6)) or 0

    local t = (pos - originPos).Magnitude / speed
    local aimPos = pos
    for _ = 1, 4 do
        local avgSpeed = math.max(speed * math.exp(-0.5 * drag * t * 12), 100)
        local future = pos + vel * t + Vector3.new(0, 0.5 * gravity * t * t, 0)
        t = (future - originPos).Magnitude / avgSpeed
        aimPos = future
    end

    return aimPos
end

-- ============================================================================
-- 4. ENTITY REGISTRY (EVENT-DRIVEN — ZERO PER-FRAME WORKSPACE SCANS)
-- ============================================================================
type ActorEntry = {
    Model: Model,
    IsAI: boolean,
    Player: Player?,
    Draw: { [string]: any },
    Highlight: Highlight?,
}

type TagEntry = {
    Root: BasePart,
    Instance: Instance,
    Category: "Container" | "Corpse" | "Dropped" | "Quest" | "Exit",
    CachedLabel: string,
    CachedSub: string,
    TopItem: string,
    ItemCount: number,
    MaxPrice: number,
    TotalValue: number,
    IsValuable: boolean,
    Highlight: Highlight?,
    Draw: { [string]: any },
}

local Actors: { [Model]: ActorEntry } = {}
local WorldTags: { [Instance]: TagEntry } = {}

-- Forward-declared ESP pool allocators assigned in Block 7
local CreateActorDrawings: () -> { [string]: any }
local DestroyActorVisuals: (entry: ActorEntry) -> ()
local CreateTagDrawings: () -> { [string]: any }
local DestroyTagVisuals: (entry: TagEntry) -> ()

local function registerActor(model: Model, player: Player?, isAI: boolean)
    if not model:IsA("Model") or player == LocalPlayer then
        return
    end
    if Actors[model] then
        return
    end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum then
        return
    end
    Actors[model] = {
        Model = model,
        IsAI = isAI,
        Player = player,
        Draw = CreateActorDrawings(),
        Highlight = nil,
    }
end

local function unregisterActor(model: Instance)
    local entry = Actors[model :: Model]
    if entry then
        DestroyActorVisuals(entry)
        Actors[model :: Model] = nil
    end
end

local function resolveModelRoot(inst: Instance): BasePart?
    if inst:IsA("BasePart") then
        return inst
    elseif inst:IsA("Model") then
        return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")
    end
    return inst:FindFirstChildWhichIsA("BasePart", true)
end

local function refreshContainerTag(tag: TagEntry)
    local lowerName = tag.Instance.Name:lower()
    local dispAttr = tag.Instance:GetAttribute("DisplayName")
    local label = type(dispAttr) == "string" and dispAttr ~= "" and dispAttr or tag.Instance.Name
    local isCorpse = tag.Category == "Corpse"
        or lowerName:find("corpse") ~= nil
        or lowerName:find("body") ~= nil
        or lowerName:find("dead") ~= nil
        or lowerName:find("ragdoll") ~= nil
        or tostring(label):lower():find("corpse") ~= nil
        or (tag.Instance:FindFirstChildOfClass("Humanoid") ~= nil)
    tag.Category = isCorpse and "Corpse" or "Container"

    local inv = tag.Instance:FindFirstChild("Inventory")
    local count = 0
    local maxPrice = 0
    local totalValue = 0
    local topItemName = ""
    if inv then
        for _, item in ipairs(inv:GetChildren()) do
            count += 1
            local itemTotal, unitPrice, dispName = Delta.GetItemValue(item, false)
            totalValue += itemTotal
            if unitPrice > maxPrice then
                maxPrice = unitPrice
                topItemName = dispName
            end
        end
    end

    local minThresh = isCorpse and Config.CorpseESP.MinPrice or Config.ContainerESP.MinPrice
    tag.CachedLabel = tostring(label)
    tag.ItemCount = count
    tag.MaxPrice = maxPrice
    tag.TotalValue = totalValue
    tag.TopItem = topItemName
    tag.IsValuable = maxPrice >= minThresh or totalValue >= minThresh
    tag.CachedSub = count == 0 and "Empty" or (topItemName ~= "" and string.format("%s (%d)", topItemName, count) or string.format("%d items", count))
end

local function registerWorldTag(inst: Instance, category: "Container" | "Corpse" | "Dropped" | "Quest" | "Exit")
    if WorldTags[inst] then
        return
    end
    local root = resolveModelRoot(inst)
    if not root then
        return
    end

    local resolvedCategory = category
    if category == "Dropped" and Delta.IsQuestObject(inst) then
        resolvedCategory = "Quest"
    end

    local tag: TagEntry = {
        Root = root,
        Instance = inst,
        Category = resolvedCategory,
        CachedLabel = inst.Name,
        CachedSub = "",
        TopItem = "",
        ItemCount = 0,
        MaxPrice = 0,
        TotalValue = 0,
        IsValuable = false,
        Highlight = nil,
        Draw = CreateTagDrawings(),
    }

    if resolvedCategory == "Container" or resolvedCategory == "Corpse" then
        refreshContainerTag(tag)
        local inv = inst:FindFirstChild("Inventory")
        if inv then
            Session.Bind(inv.ChildAdded, function()
                refreshContainerTag(tag)
            end)
            Session.Bind(inv.ChildRemoved, function()
                refreshContainerTag(tag)
            end)
        end
    elseif resolvedCategory == "Dropped" or resolvedCategory == "Quest" then
        local itemKey = tostring(inst:GetAttribute("ItemId") or inst.Name)
        local info = ItemsPriceCache[itemKey] or ItemsPriceCache[inst.Name]
        local props = inst:FindFirstChild("ItemProperties")
        local price = (info and info.Price) or tonumber(inst:GetAttribute("Price")) or (props and tonumber(props:GetAttribute("Price"))) or 0
        tag.CachedLabel = info and info.Name or tostring(inst:GetAttribute("DisplayName") or itemKey)
        tag.MaxPrice = price
        tag.TotalValue = price
        tag.ItemCount = 1
        tag.IsValuable = price >= Config.DroppedESP.MinPrice
    elseif resolvedCategory == "Exit" then
        local desc = inst:GetAttribute("TeleportDescription") or inst:GetAttribute("TeleportToMap") or inst.Name
        local exitTime = tonumber(inst:GetAttribute("ExitTime"))
        tag.CachedLabel = tostring(desc)
        tag.CachedSub = exitTime and string.format("%.0fs extract", exitTime) or "Extraction"
    end

    WorldTags[inst] = tag
end

local function unregisterWorldTag(inst: Instance)
    local tag = WorldTags[inst]
    if tag then
        DestroyTagVisuals(tag)
        WorldTags[inst] = nil
    end
end

-- ============================================================================
-- 5. SHARED TARGET SELECTION (AIMBOT, SILENT AIM, TRIGGERBOT, TARGET HUD)
-- ============================================================================
local Targeting = {}

export type TargetResult = {
    Model: Model,
    Player: Player?,
    IsAI: boolean,
    Part: BasePart,
    AimPointWorld: Vector3,
    ScreenPos: Vector2,
    ScreenDist: number,
    WorldDist: number,
    Health: number,
    MaxHealth: number,
}

function Targeting.GetEffectiveFOVRadius(kind: ("Aimbot" | "Silent")?): number
    local useAimbot = (kind == "Aimbot")
    local base = useAimbot and Config.Aimbot.FOVRadius or Config.Targeting.FOV
    local isDynamic = useAimbot and Config.Aimbot.FOVDynamic or Config.Targeting.DynamicFOV
    if not isDynamic then
        return base
    end
    local cam = Workspace.CurrentCamera
    local curFov = cam and cam.FieldOfView or 70
    return base * (70 / math.max(curFov, 25))
end

function Targeting.GetAimOrigin2D(): Vector2
    local cam = Workspace.CurrentCamera
    if not cam then
        return Vector2.new(0, 0)
    end
    if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
        local vp = cam.ViewportSize
        return Vector2.new(vp.X * 0.5, vp.Y * 0.5)
    end
    return UserInputService:GetMouseLocation()
end

function Targeting.ToggleNearestFriend(): (Player?, boolean)
    local cam = Workspace.CurrentCamera
    if not cam then
        return nil, false
    end
    local aim2D = Targeting.GetAimOrigin2D()
    local maxPx = math.clamp(math.max(Targeting.GetEffectiveFOVRadius("Silent"), Targeting.GetEffectiveFOVRadius("Aimbot")), 110, 180)
    local bestPlayer: Player? = nil
    local bestDist = maxPx

    for model, entry in pairs(Actors) do
        if model.Parent and not entry.IsAI and entry.Player and entry.Player ~= LocalPlayer then
            local part = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
            if part and part:IsA("BasePart") then
                local sp, onScreen = cam:WorldToViewportPoint(part.Position)
                if onScreen then
                    local sd = (Vector2.new(sp.X, sp.Y) - aim2D).Magnitude
                    if sd < bestDist then
                        bestDist = sd
                        bestPlayer = entry.Player
                    end
                end
            end
        end
    end

    if not bestPlayer then
        return nil, false
    end
    local uid = bestPlayer.UserId
    local added = not (FriendsWhitelist[uid] == true)
    FriendsWhitelist[uid] = added and true or nil
    return bestPlayer, added
end

function Targeting.FindBestTarget(opts: {
    HitPart: string,
    TeamCheck: boolean,
    VisibleCheck: boolean,
    PreferVisibleFallback: boolean?,
    IgnoreDowned: boolean,
    TargetAI: boolean,
    UseFOV: boolean,
    FOVKind: ("Aimbot" | "Silent")?,
    FOVMultiplier: number?,
    MaxDistance: number,
    RayOrigin: Vector3?,
    AimPoint: string?,
    AimParts: { string }?,
    VisibleFallback: boolean?,
    Wallbang: WallbangConfig?,
    RaycastBudget: number?,
    AllowRandom: boolean?,
    Priority: string?,
    MultiPoint: boolean?,
    OnlyModel: Model?,
}): TargetResult?
    local cam = Workspace.CurrentCamera
    if not cam then
        return nil
    end

    local aim2D = Targeting.GetAimOrigin2D()
    local baseRadius = opts.UseFOV and Targeting.GetEffectiveFOVRadius(opts.FOVKind) or math.huge
    local fovRadius = (baseRadius < math.huge and opts.FOVMultiplier) and (baseRadius * opts.FOVMultiplier) or baseRadius
    local camPos = cam.CFrame.Position
    local visOrigin = opts.RayOrigin or camPos

    type CandidateRec = {
        Model: Model,
        Entry: ActorEntry,
        Parts: { BasePart },
        PrimaryPart: BasePart,
        ScreenPos: Vector2,
        ScreenDist: number,
        WorldDist: number,
        Health: number,
        MaxHealth: number,
    }
    local candidates: { CandidateRec } = {}

    for model, entry in pairs(Actors) do
        if opts.OnlyModel and model ~= opts.OnlyModel then
            continue
        end
        if not model.Parent then
            continue
        end
        if entry.IsAI and not opts.TargetAI then
            continue
        end
        if not entry.IsAI and entry.Player then
            if Delta.IsFriend(entry.Player) then
                continue
            end
            if opts.TeamCheck and Delta.IsTeammate(entry.Player) then
                continue
            end
            if opts.IgnoreDowned and Delta.IsPlayerDowned(entry.Player, model) then
                continue
            end
            if Delta.IsPlayerProtected(entry.Player, model) then
                continue
            end
        end

        local hum = model:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then
            continue
        end

        local parts = buildCandidateParts(model, opts.HitPart, opts.AimPoint, opts.AimParts, opts.VisibleFallback, opts.AllowRandom, aim2D, cam)
        local primary = parts[1]
        if not primary then
            continue
        end

        local worldDist = (primary.Position - camPos).Magnitude
        if worldDist > opts.MaxDistance then
            continue
        end

        local screenPos, onScreen = cam:WorldToViewportPoint(primary.Position)
        if not onScreen or screenPos.Z <= 0 then
            continue
        end

        local pt2D = Vector2.new(screenPos.X, screenPos.Y)
        local screenDist = (pt2D - aim2D).Magnitude
        if screenDist > fovRadius then
            continue
        end

        table.insert(candidates, {
            Model = model,
            Entry = entry,
            Parts = parts,
            PrimaryPart = primary,
            ScreenPos = pt2D,
            ScreenDist = screenDist,
            WorldDist = worldDist,
            Health = hum.Health,
            MaxHealth = math.max(hum.MaxHealth, 1),
        })
    end

    if #candidates == 0 then
        return nil
    end

    local prio = opts.Priority or "Crosshair"
    table.sort(candidates, function(a, b)
        if prio == "Closest Dist" then
            return a.WorldDist < b.WorldDist
        elseif prio == "Lowest HP" then
            if math.abs(a.Health - b.Health) > 1 then
                return a.Health < b.Health
            end
        end
        return a.ScreenDist < b.ScreenDist
    end)

    local budget = { Remaining = math.max(1, opts.RaycastBudget or Config.Targeting.RaycastBudget or 6) }
    local doVisCheck = opts.VisibleCheck or (opts.PreferVisibleFallback == true)
    if doVisCheck then
        for _, cand in ipairs(candidates) do
            if budget.Remaining <= 0 then
                break
            end
            for idx, part in ipairs(cand.Parts) do
                if budget.Remaining <= 0 then
                    break
                end
                if idx > 1 and not opts.VisibleFallback and opts.AimPoint ~= "Random" then
                    break
                end
                local hitWorld = Delta.FindVisiblePartPoint(cand.Model, part, visOrigin, opts.Wallbang, budget, opts.MultiPoint == true)
                if hitWorld then
                    local sp, onScr = cam:WorldToViewportPoint(hitWorld)
                    local p2d = (onScr and sp.Z > 0) and Vector2.new(sp.X, sp.Y) or cand.ScreenPos
                    local sd = (onScr and sp.Z > 0) and (p2d - aim2D).Magnitude or cand.ScreenDist
                    if not opts.UseFOV or sd <= fovRadius then
                        return {
                            Model = cand.Model,
                            Player = cand.Entry.Player,
                            IsAI = cand.Entry.IsAI,
                            Part = part,
                            AimPointWorld = hitWorld,
                            ScreenPos = p2d,
                            ScreenDist = sd,
                            WorldDist = (hitWorld - camPos).Magnitude,
                            Health = cand.Health,
                            MaxHealth = cand.MaxHealth,
                        }
                    end
                end
            end
        end
    end

    if not opts.VisibleCheck or opts.PreferVisibleFallback then
        local cand = candidates[1]
        return {
            Model = cand.Model,
            Player = cand.Entry.Player,
            IsAI = cand.Entry.IsAI,
            Part = cand.PrimaryPart,
            AimPointWorld = cand.PrimaryPart.Position,
            ScreenPos = cand.ScreenPos,
            ScreenDist = cand.ScreenDist,
            WorldDist = cand.WorldDist,
            Health = cand.Health,
            MaxHealth = cand.MaxHealth,
        }
    end

    return nil
end

-- ============================================================================
-- 6. COMBAT SUBSYSTEMS (AIMBOT, SILENT AIM, WEAPON MODS, TRIGGERBOT)
-- ============================================================================
local Combat = {}
local ActiveLockedTarget: TargetResult? = nil

-- 6A. Weapon Mods (No Recoil, No Spread, No Sway, Fast ADS, No Scope DOF)
local OriginalRecoilPattern: { [NumberValue]: number } = {}
local OriginalWeaponSettings: { [table]: { [string]: any } } = {}
local CachedSettingsModules: { table } = {}
local SettingsScanned = false

local SETTINGS_KEYS = {
    "MaxRecoil",
    "MaximumKickBack",
    "RecoilReductionMax",
    "IdleSwayModifier",
    "SprintSwayModifer",
    "WalkSwayModifer",
    "swayMult",
    "AimInSpeed",
    "AimOutSpeed",
    "useDof",
}

local function ensureSettingsCached()
    if SettingsScanned or not ItemsListFolder then
        return
    end
    SettingsScanned = true
    for _, item in ipairs(ItemsListFolder:GetChildren()) do
        local sm = item:FindFirstChild("SettingsModule")
        if sm and sm:IsA("ModuleScript") then
            local ok, tbl = pcall(require, sm)
            if ok and type(tbl) == "table" and tbl.useModuleName == "RangedWeaponDefault" then
                table.insert(CachedSettingsModules, tbl)
                local snap: { [string]: any } = {}
                for _, key in ipairs(SETTINGS_KEYS) do
                    snap[key] = tbl[key]
                end
                OriginalWeaponSettings[tbl] = snap
            end
        end
    end
end

function Combat.ApplyWeaponMods()
    -- 1. RecoilPattern NumberValues (RangedWeapons.<Gun>.RecoilPattern.<1|2|3>.<x|y>)
    if RangedWeaponsFolder then
        local scale = Config.WeaponMods.NoRecoil and (1 - (Config.WeaponMods.RecoilReduction / 100)) or 1
        for _, wep in ipairs(RangedWeaponsFolder:GetChildren()) do
            local rp = wep:FindFirstChild("RecoilPattern")
            if rp then
                for _, step in ipairs(rp:GetChildren()) do
                    for _, axis in ipairs({ step:FindFirstChild("x"), step:FindFirstChild("y") }) do
                        if axis and axis:IsA("NumberValue") then
                            if OriginalRecoilPattern[axis] == nil then
                                OriginalRecoilPattern[axis] = axis.Value
                            end
                            axis.Value = OriginalRecoilPattern[axis] * scale
                        end
                    end
                end
            end
        end
    end

    -- 2. Ammo AccuracyDeviation attribute (No Spread)
    if AmmoTypesFolder then
        for _, ammo in ipairs(AmmoTypesFolder:GetChildren()) do
            if OriginalAmmoSpread[ammo] == nil then
                OriginalAmmoSpread[ammo] = ammo:GetAttribute("AccuracyDeviation")
            end
            if OriginalAmmoSpread[ammo] ~= nil then
                ammo:SetAttribute("AccuracyDeviation", Config.WeaponMods.NoSpread and 0 or OriginalAmmoSpread[ammo])
            end
        end
    end

    -- 3. Ranged SettingsModules (Kickback, Sway, ADS Speed, Scope DOF)
    ensureSettingsCached()
    local recScale = Config.WeaponMods.NoRecoil and (1 - (Config.WeaponMods.RecoilReduction / 100)) or 1
    for _, tbl in ipairs(CachedSettingsModules) do
        local orig = OriginalWeaponSettings[tbl]
        if orig then
            if type(orig.MaxRecoil) == "number" then
                tbl.MaxRecoil = orig.MaxRecoil * recScale
            end
            if type(orig.MaximumKickBack) == "number" then
                tbl.MaximumKickBack = orig.MaximumKickBack * recScale
            end
            if type(orig.IdleSwayModifier) == "number" then
                tbl.IdleSwayModifier = Config.WeaponMods.NoSway and 0 or orig.IdleSwayModifier
            end
            if type(orig.SprintSwayModifer) == "number" then
                tbl.SprintSwayModifer = Config.WeaponMods.NoSway and 0 or orig.SprintSwayModifer
            end
            if type(orig.WalkSwayModifer) == "number" then
                tbl.WalkSwayModifer = Config.WeaponMods.NoSway and 0 or orig.WalkSwayModifer
            end
            if type(orig.swayMult) == "number" then
                tbl.swayMult = Config.WeaponMods.NoSway and 0 or orig.swayMult
            end
            if type(orig.AimInSpeed) == "number" then
                tbl.AimInSpeed = Config.WeaponMods.FastADS and Config.WeaponMods.ADSSpeed or orig.AimInSpeed
            end
            if type(orig.AimOutSpeed) == "number" then
                tbl.AimOutSpeed = Config.WeaponMods.FastADS and Config.WeaponMods.ADSSpeed or orig.AimOutSpeed
            end
            if orig.useDof ~= nil then
                if Config.WeaponMods.NoScopeDOF then
                    tbl.useDof = false
                else
                    tbl.useDof = orig.useDof
                end
            end
        end
    end
end

function Combat.RestoreAllWeaponMods()
    for nv, orig in pairs(OriginalRecoilPattern) do
        pcall(function()
            if nv.Parent then
                nv.Value = orig
            end
        end)
    end
    for ammo, orig in pairs(OriginalAmmoSpread) do
        pcall(function()
            if ammo.Parent then
                ammo:SetAttribute("AccuracyDeviation", orig)
            end
        end)
    end
    for _, tbl in ipairs(CachedSettingsModules) do
        local orig = OriginalWeaponSettings[tbl]
        if orig then
            for _, key in ipairs(SETTINGS_KEYS) do
                tbl[key] = orig[key]
            end
        end
    end
end

-- Hook VFX.RecoilCamera cleanly so camera punch scales/disables with NoRecoil
do
    local modulesFolder = ReplicatedStorage:FindFirstChild("Modules")
    local vfxInst = modulesFolder and modulesFolder:FindFirstChild("VFX")
    local okVfx, VFXMod = pcall(require, vfxInst :: any)
    if okVfx and type(VFXMod) == "table" and type(VFXMod.RecoilCamera) == "function" then
        local origRecoilCam = VFXMod.RecoilCamera
        local hookedRecoilCam: any
        local function wrapperRecoil(...)
            if Session.IsAlive() and Config.WeaponMods.NoRecoil then
                if Config.WeaponMods.RecoilReduction >= 99 then
                    return
                end
            end
            return (hookedRecoilCam or origRecoilCam)(...)
        end
        if type(hookfunction) == "function" then
            hookedRecoilCam = hookfunction(origRecoilCam, wrapperRecoil)
        else
            VFXMod.RecoilCamera = wrapperRecoil
        end
        Session.OnStop(function()
            if type(restorefunction) == "function" then
                pcall(restorefunction, origRecoilCam)
            elseif type(hookfunction) == "function" and hookedRecoilCam then
                pcall(hookfunction, origRecoilCam, hookedRecoilCam)
            else
                VFXMod.RecoilCamera = origRecoilCam
            end
        end)
    end
end

-- Scale/suppress FPS procedural spring recoil shoves (cameraRecoil, recoilRot, recoilPos)
do
    local springHooks: { { tbl: table, orig: any } } = {}
    if type(getgc) == "function" then
        for _, obj in ipairs(getgc(true)) do
            if type(obj) == "table" and type(rawget(obj, "springs")) == "table" and rawget(obj, "CancelTables") ~= nil then
                local springs = rawget(obj, "springs")
                for _, sName in ipairs({ "cameraRecoil", "recoilRot", "recoilPos" }) do
                    local sp = springs[sName]
                    if type(sp) == "table" and type(sp.shove) == "function" then
                        local origShove = sp.shove
                        table.insert(springHooks, { tbl = sp, orig = origShove })
                        sp.shove = function(selfSpring: any, force: any, ...)
                            if Session.IsAlive() and Config.WeaponMods.NoRecoil then
                                local mult = 1 - (Config.WeaponMods.RecoilReduction / 100)
                                if mult <= 0.01 then
                                    return
                                end
                                if typeof(force) == "Vector3" then
                                    force = force * mult
                                end
                            end
                            return origShove(selfSpring, force, ...)
                        end
                    end
                end
                break
            end
        end
    end
    Session.OnStop(function()
        for _, rec in ipairs(springHooks) do
            rec.tbl.shove = rec.orig
        end
    end)
end

-- 6C. Silent Aim hook on Bullet.CreateBullet
local SilentRng = Random.new()

local function findSilentAimTarget(shotOrigin: Vector3, allowRandom: boolean?): TargetResult?
    return Targeting.FindBestTarget({
        HitPart = Config.SilentAim.HitPart,
        TeamCheck = Config.SilentAim.TeamCheck,
        VisibleCheck = Config.SilentAim.VisibleCheck,
        IgnoreDowned = Config.SilentAim.IgnoreDowned,
        TargetAI = (Config.Targeting.TargetAI == true) or (Config.SilentAim.TargetAI == true),
        UseFOV = Config.SilentAim.UseFOV,
        MaxDistance = 4000, -- Project Delta Bullet.onStep max range
        RayOrigin = shotOrigin,
        AimPoint = Config.Targeting.AimPoint,
        AimParts = Config.Targeting.AimParts,
        VisibleFallback = Config.Targeting.VisibleFallback,
        Wallbang = {
            Enabled = Config.Targeting.Wallbang,
            MaxWalls = Config.Targeting.WallbangMaxWalls,
            MaxThickness = Config.Targeting.WallbangMaxThickness,
            RespectNoPen = Config.Targeting.WallbangRespectNoPen,
        },
        RaycastBudget = Config.Targeting.RaycastBudget,
        AllowRandom = allowRandom == true,
        Priority = Config.SilentAim.Priority,
        MultiPoint = Config.SilentAim.MultiPoint,
        FOVKind = "Silent",
    })
end
Combat._FindSilentTarget = findSilentAimTarget

do
    local modulesFolder = ReplicatedStorage:FindFirstChild("Modules")
    local fpsInst = modulesFolder and modulesFolder:FindFirstChild("FPS")
    local bulletInst = fpsInst and fpsInst:FindFirstChild("Bullet")
    local okBullet, BulletMod = pcall(require, bulletInst :: any)

    if okBullet and type(BulletMod) == "table" and type(BulletMod.CreateBullet) == "function" then
        local origCreateBullet = BulletMod.CreateBullet
        local hookedCreateBullet: any = nil

        local function wrappedCreateBullet(...)
            local args = table.pack(...)
            local restoredParts: { { Part: BasePart, PrevCF: CFrame } } = {}
            local restoredSpreads: { { Inst: Instance, PrevVal: any } } = {}

            local panicBlock = Config.Misc.PanicMode and Config.Misc.PanicDisableCombat
            if not panicBlock and Session.IsAlive() and isModeActive("SilentAim", Config.SilentAim.Enabled, Config.SilentAim.Mode, Config.SilentAim.Key) then
                local chance = math.clamp(Config.SilentAim.HitChance, 0, 100)
                if chance >= 100 or SilentRng:NextInteger(1, 100) <= chance then
                    local shotOrigin = Delta.GetShotOrigin()
                    local target = findSilentAimTarget(shotOrigin, true)

                    if target then
                        local ammoArg = (args.n >= 7 and type(args[7]) == "string") and args[7] or nil
                        local ammoBallistics, ammoInst = Delta.GetBallisticsForAmmo(ammoArg)
                        if not ammoInst then
                            ammoBallistics = Delta.GetLocalBallistics()
                        end

                        local aimPos = Delta.PredictAimPosition(
                            shotOrigin,
                            target.Part,
                            Config.SilentAim.Prediction,
                            Config.SilentAim.DropComp,
                            ammoBallistics,
                            target.AimPointWorld
                        )
                        local aimVec = aimPos - shotOrigin

                        if aimVec.Magnitude > 1e-4 then
                            local aimUnit = aimVec.Unit
                            local cam = Workspace.CurrentCamera
                            local camLook = cam and cam.CFrame.LookVector or aimUnit

                            -- Prevent fireBullet random cone dispersion across ammo, weapon tool, and attachments
                            if not Config.WeaponMods.NoSpread then
                                local function zeroDev(inst: Instance?)
                                    if inst then
                                        local prev = inst:GetAttribute("AccuracyDeviation")
                                        if type(prev) == "number" and prev > 0 then
                                            table.insert(restoredSpreads, { Inst = inst, PrevVal = prev })
                                            inst:SetAttribute("AccuracyDeviation", 0)
                                        end
                                    end
                                end
                                zeroDev(ammoInst)
                                local rsPlr = Delta.GetRSPlayer(LocalPlayer)
                                local gv = rsPlr and rsPlr:FindFirstChild("Status") and rsPlr.Status:FindFirstChild("GameplayVariables")
                                local eq = gv and gv:FindFirstChild("EquippedTool")
                                local eqTool = (eq and eq:IsA("ObjectValue")) and eq.Value or nil
                                if not eqTool and LocalPlayer.Character then
                                    local holding = LocalPlayer.Character:FindFirstChild("Holding")
                                    eqTool = (holding and holding:IsA("ObjectValue")) and holding.Value or nil
                                end
                                zeroDev(eqTool)
                                local atts = eqTool and eqTool:FindFirstChild("Attachments")
                                if atts then
                                    for _, att in ipairs(atts:GetChildren()) do
                                        zeroDev(att)
                                    end
                                end
                            end

                            -- Redirect arg #5 (AimPart) & muzzle/CFrame args with true convergence on aimPos
                            local touched: { [BasePart]: boolean } = {}
                            local function lookTarget(fromPos: Vector3): Vector3
                                if (aimPos - fromPos).Magnitude > 1.5 then
                                    return aimPos
                                end
                                return fromPos + aimUnit
                            end
                            for i = 1, args.n do
                                local arg = args[i]
                                if typeof(arg) == "Instance" and arg:IsA("BasePart") and not touched[arg] then
                                    local lname = arg.Name:lower()
                                    if i == 5 or lname:find("aim") or lname:find("muzzle") or lname:find("barrel") or lname:find("fire") then
                                        touched[arg] = true
                                        table.insert(restoredParts, { Part = arg, PrevCF = arg.CFrame })
                                        arg.CFrame = CFrame.lookAt(arg.Position, lookTarget(arg.Position))
                                    end
                                elseif typeof(arg) == "CFrame" then
                                    if i == 5 or arg.LookVector:Dot(camLook) > 0.25 then
                                        args[i] = CFrame.lookAt(arg.Position, lookTarget(arg.Position))
                                    end
                                end
                            end

                            ActiveLockedTarget = target
                        end
                    end
                end
            end

            local targetFn = hookedCreateBullet or origCreateBullet
            local results = table.pack(pcall(targetFn, table.unpack(args, 1, args.n)))
            for _, rec in ipairs(restoredParts) do
                if rec.Part.Parent then
                    rec.Part.CFrame = rec.PrevCF
                end
            end
            if not Config.WeaponMods.NoSpread then
                for _, rec in ipairs(restoredSpreads) do
                    if rec.Inst.Parent then
                        rec.Inst:SetAttribute("AccuracyDeviation", rec.PrevVal)
                    end
                end
            end
            if not results[1] then
                error(results[2])
            end
            return table.unpack(results, 2, results.n)
        end

        if type(hookfunction) == "function" then
            hookedCreateBullet = hookfunction(origCreateBullet, wrappedCreateBullet)
        else
            BulletMod.CreateBullet = wrappedCreateBullet
        end
        Session.OnStop(function()
            if type(restorefunction) == "function" then
                pcall(restorefunction, origCreateBullet)
            elseif type(hookfunction) == "function" and hookedCreateBullet then
                pcall(hookfunction, origCreateBullet, hookedCreateBullet)
            elseif BulletMod.CreateBullet == wrappedCreateBullet then
                BulletMod.CreateBullet = origCreateBullet
            end
        end)
    end
end

-- 6D. Aimbot Step (Sticky lock, EMA velocity prediction, FPS-independent slerp, visible/behind-wall support)
local mouseAccumX, mouseAccumY = 0, 0
local lastTriggerShotAt = 0

Combat._StickyAimModel = nil :: Model?
Combat._AimVelCache = Vector3.zero
Combat._IsMenuOpen = nil :: (() -> boolean)?

local function stepAimbot(dt: number)
    if Config.Misc.PanicMode and Config.Misc.PanicDisableCombat then
        mouseAccumX, mouseAccumY = 0, 0
        Combat._StickyAimModel = nil
        Combat._AimVelCache = Vector3.zero
        ActiveLockedTarget = nil
        return
    end
    local active = isModeActive("Aimbot", Config.Aimbot.Enabled, Config.Aimbot.Mode, Config.Aimbot.Key)
    if active and Config.Aimbot.OnlyADS and not Delta.IsLocalADS() then
        active = false
    end
    if active and Combat._IsMenuOpen and Combat._IsMenuOpen() then
        active = false
    end
    if not active then
        mouseAccumX, mouseAccumY = 0, 0
        Combat._StickyAimModel = nil
        Combat._AimVelCache = Vector3.zero
        if isModeActive("SilentAim", Config.SilentAim.Enabled, Config.SilentAim.Mode, Config.SilentAim.Key) then
            ActiveLockedTarget = findSilentAimTarget(Delta.GetShotOrigin())
        else
            ActiveLockedTarget = nil
        end
        return
    end

    local behindWalls = (Config.Aimbot.LockBehindWalls == true)
    local wantVisCheck = (Config.Aimbot.VisibleCheck == true) and not behindWalls
    local shotOrigin = Delta.GetShotOrigin()

    local aimOpts = {
        HitPart = Config.Aimbot.HitPart,
        TeamCheck = Config.Aimbot.TeamCheck,
        VisibleCheck = wantVisCheck,
        PreferVisibleFallback = behindWalls and (Config.Aimbot.VisibleCheck == true),
        IgnoreDowned = Config.Aimbot.IgnoreDowned,
        TargetAI = Config.Aimbot.TargetAI,
        UseFOV = true,
        FOVKind = "Aimbot" :: ("Aimbot" | "Silent")?,
        MaxDistance = Config.Aimbot.MaxDistance,
        RayOrigin = shotOrigin,
        Priority = Config.Aimbot.Priority or "Crosshair",
        VisibleFallback = (Config.Aimbot.VisibleFallback ~= false),
        MultiPoint = (Config.Aimbot.MultiPoint ~= false),
        RaycastBudget = Config.Targeting.RaycastBudget,
    }

    local target: TargetResult? = nil
    if Config.Aimbot.StickyTarget ~= false and Combat._StickyAimModel and Actors[Combat._StickyAimModel] then
        target = Targeting.FindBestTarget({
            HitPart = aimOpts.HitPart,
            TeamCheck = aimOpts.TeamCheck,
            VisibleCheck = aimOpts.VisibleCheck,
            PreferVisibleFallback = aimOpts.PreferVisibleFallback,
            IgnoreDowned = aimOpts.IgnoreDowned,
            TargetAI = aimOpts.TargetAI,
            UseFOV = true,
            FOVKind = "Aimbot",
            FOVMultiplier = 1.35,
            MaxDistance = aimOpts.MaxDistance,
            RayOrigin = shotOrigin,
            Priority = aimOpts.Priority,
            VisibleFallback = aimOpts.VisibleFallback,
            MultiPoint = aimOpts.MultiPoint,
            RaycastBudget = aimOpts.RaycastBudget,
            OnlyModel = Combat._StickyAimModel,
        })
    end

    if not target then
        target = Targeting.FindBestTarget(aimOpts)
        if target and target.Model ~= Combat._StickyAimModel then
            mouseAccumX, mouseAccumY = 0, 0
            Combat._AimVelCache = Vector3.zero
        end
    end

    Combat._StickyAimModel = target and target.Model or nil
    ActiveLockedTarget = target
    if not target then
        mouseAccumX, mouseAccumY = 0, 0
        Combat._AimVelCache = Vector3.zero
        return
    end

    local cam = Workspace.CurrentCamera
    if not cam then
        return
    end

    local rawVel = target.Part.AssemblyLinearVelocity
    if rawVel.Magnitude > 120 or rawVel.Magnitude < 0.6 then
        rawVel = Vector3.zero
    end
    local velAlpha = math.clamp(dt * 18, 0.25, 0.85)
    Combat._AimVelCache = Combat._AimVelCache:Lerp(rawVel, velAlpha)

    local aimWorld = target.AimPointWorld
    if Config.Aimbot.Prediction or Config.Aimbot.DropComp then
        local ballistics = Delta.GetLocalBallistics()
        local speed = math.max(ballistics.Velocity, 100)
        local drag = math.max(ballistics.Drag or 0.013, 0)
        local vel = Config.Aimbot.Prediction and Combat._AimVelCache or Vector3.zero
        local gravity = Config.Aimbot.DropComp and (70 * (ballistics.Drop / 4.6)) or 0
        local t = (aimWorld - shotOrigin).Magnitude / speed
        for _ = 1, 4 do
            local avgSpeed = math.max(speed * math.exp(-0.5 * drag * t * 12), 100)
            local future = target.AimPointWorld + vel * t + Vector3.new(0, 0.5 * gravity * t * t, 0)
            t = (future - shotOrigin).Magnitude / avgSpeed
            aimWorld = future
        end
    end

    if Config.Aimbot.Method == "Mouse" and type(mousemoverel) == "function" then
        local sp, onScreen = cam:WorldToViewportPoint(aimWorld)
        if not onScreen or sp.Z <= 0 then
            return
        end
        local cur2D = Targeting.GetAimOrigin2D()
        local dx = sp.X - cur2D.X
        local dy = sp.Y - cur2D.Y

        if math.abs(dx) < 0.6 and math.abs(dy) < 0.6 then
            mouseAccumX, mouseAccumY = 0, 0
            return
        end

        local normSmooth = math.clamp(Config.Aimbot.Smoothness / 100, 0, 0.95)
        local responsiveness = math.pow(1 - normSmooth, 1.35)
        local frameAlpha = 1 - math.exp(-responsiveness * 38 * math.clamp(dt, 0.001, 0.05))
        local gain = math.clamp(frameAlpha * Config.Aimbot.MouseSens, 0.03, 1.0)
        mouseAccumX += dx * gain
        mouseAccumY += dy * gain

        local stepX = math.modf(mouseAccumX)
        local stepY = math.modf(mouseAccumY)
        if stepX ~= 0 or stepY ~= 0 then
            mouseAccumX -= stepX
            mouseAccumY -= stepY
            pcall(mousemoverel, math.clamp(stepX, -85, 85), math.clamp(stepY, -85, 85))
        end
    else
        -- Compensate camera rotation around camPos using shot-origin offset if leaning/ADS
        local camPos = cam.CFrame.Position
        local aimDir = aimWorld - shotOrigin
        local lookTarget = (aimDir.Magnitude > 0.25) and (camPos + aimDir) or aimWorld
        local targetCF = CFrame.lookAt(camPos, lookTarget)
        local normSmooth = math.clamp(Config.Aimbot.Smoothness / 100, 0, 0.97)
        if normSmooth <= 0.01 then
            cam.CFrame = targetCF
        else
            local speedRate = math.pow(1 - normSmooth, 1.55) * 42
            local alpha = 1 - math.exp(-speedRate * math.clamp(dt, 0.001, 0.05))
            cam.CFrame = cam.CFrame:Lerp(targetCF, math.clamp(alpha, 0.015, 1))
        end
    end
end

-- 6E. TriggerBot Step (resolves nested armor/helmet/rig Models via ancestor walk & WeaponRay channel)
local function resolveActorFromHit(hit: Instance): (Model?, ActorEntry?, BasePart?)
    local part = hit:IsA("BasePart") and hit or nil
    local realParent = hit:FindFirstChild("RealParent")
    if realParent and realParent:IsA("ObjectValue") and realParent.Value then
        local cur: Instance? = realParent.Value
        while cur do
            if cur:IsA("Model") and Actors[cur] then
                return cur, Actors[cur], part
            end
            cur = cur.Parent
        end
    end
    local cur: Instance? = hit
    while cur and cur ~= Workspace do
        if cur:IsA("Model") and Actors[cur] then
            return cur, Actors[cur], part
        end
        cur = cur.Parent
    end
    return nil, nil, part
end

local function isHeadHitPart(part: BasePart?, model: Model): boolean
    if not part then
        return false
    end
    local lname = part.Name:lower()
    if lname:find("head") or lname:find("face") or lname:find("helmet") or lname:find("visor") or lname:find("mask") then
        return true
    end
    local head = model:FindFirstChild("Head")
    if head and head:IsA("BasePart") and part:IsDescendantOf(head) then
        return true
    end
    return false
end

local function stepTriggerBot()
    if Config.Misc.PanicMode and Config.Misc.PanicDisableCombat then
        return
    end
    if Combat._IsMenuOpen and Combat._IsMenuOpen() then
        return
    end
    if UserInputService:GetFocusedTextBox() ~= nil then
        return
    end
    if not isModeActive("TriggerBot", Config.TriggerBot.Enabled, Config.TriggerBot.Mode, Config.TriggerBot.Key) then
        return
    end
    if Config.TriggerBot.OnlyADS and not Delta.IsLocalADS() then
        return
    end
    local now = os.clock()
    if (now - lastTriggerShotAt) * 1000 < math.max(Config.TriggerBot.DelayMs, 20) then
        return
    end
    local cam = Workspace.CurrentCamera
    if not cam then
        return
    end

    local aim2D = Targeting.GetAimOrigin2D()
    local unitRay = cam:ViewportPointToRay(aim2D.X, aim2D.Y)

    local ignore: { Instance } = { cam }
    if LocalPlayer.Character then
        table.insert(ignore, LocalPlayer.Character)
    end
    local noCol = Workspace:FindFirstChild("NoCollision")
    if noCol then
        table.insert(ignore, noCol)
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true
    pcall(function()
        params.CollisionGroup = "WeaponRay"
    end)

    local maxDist = Config.TriggerBot.MaxDistance or 500
    local origin = unitRay.Origin
    local remainingDist = maxDist
    local hitActorModel: Model? = nil
    local hitEntry: ActorEntry? = nil
    local hitPart: BasePart? = nil

    for _ = 1, 6 do
        if remainingDist <= 0.5 then
            break
        end
        params.FilterDescendantsInstances = ignore
        local res = Workspace:Raycast(origin, unitRay.Direction * remainingDist, params)
        if not res then
            break
        end

        local inst = res.Instance
        local model, entry, bp = resolveActorFromHit(inst)
        if model and entry then
            hitActorModel = model
            hitEntry = entry
            hitPart = bp
            break
        end

        local isPassThrough = inst:GetAttribute("PassThrough") ~= nil
            or inst:GetAttribute("Glass") ~= nil
            or (inst:IsA("BasePart") and (inst.Material == Enum.Material.Glass or inst.Transparency >= 0.85 or not inst.CanCollide))
        if isPassThrough then
            local traveled = (res.Position - origin).Magnitude + 0.08
            remainingDist -= traveled
            table.insert(ignore, inst)
            origin = res.Position + unitRay.Direction * 0.08
        else
            break
        end
    end

    if hitActorModel and hitEntry then
        if hitEntry.IsAI and not Config.TriggerBot.TargetAI then
            return
        end
        if not hitEntry.IsAI and hitEntry.Player then
            if Delta.IsFriend(hitEntry.Player) then
                return
            end
            if Config.TriggerBot.TeamCheck and Delta.IsTeammate(hitEntry.Player) then
                return
            end
            if Config.TriggerBot.IgnoreDowned and Delta.IsPlayerDowned(hitEntry.Player, hitActorModel) then
                return
            end
            if Delta.IsPlayerProtected(hitEntry.Player, hitActorModel) then
                return
            end
        end

        local filter = Config.TriggerBot.HitFilter or "Any"
        if filter == "Head Only" and not isHeadHitPart(hitPart, hitActorModel) then
            return
        elseif filter == "Body Only" and isHeadHitPart(hitPart, hitActorModel) then
            return
        end

        local hum = hitActorModel:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
            local pressDur = math.clamp(math.max(Config.TriggerBot.DelayMs, 20) * 0.00055, 0.011, 0.028)
            if type(mouse1press) == "function" and type(mouse1release) == "function" then
                lastTriggerShotAt = now
                pcall(mouse1press)
                task.delay(pressDur, function()
                    pcall(mouse1release)
                end)
            elseif type(mouse1click) == "function" then
                lastTriggerShotAt = now
                pcall(mouse1click)
            end
        end
    end
end

-- ============================================================================
-- 7. WORLD & LIGHTING ENGINE (WITH CLEAN BACKUP/RESTORE)
-- ============================================================================
local World: { [string]: any } = {}

;(function()
    local terrain: Terrain? = Workspace:FindFirstChildOfClass("Terrain")
    local hasHiddenProp = type(gethiddenproperty) == "function" and type(sethiddenproperty) == "function"

    local LightingBackup = {
        Brightness = Lighting.Brightness,
        ClockTime = Lighting.ClockTime,
        FogEnd = Lighting.FogEnd,
        FogStart = Lighting.FogStart,
        FogColor = Lighting.FogColor,
        GlobalShadows = Lighting.GlobalShadows,
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        ExposureCompensation = Lighting.ExposureCompensation,
        GeographicLatitude = Lighting.GeographicLatitude,
        ShadowSoftness = Lighting.ShadowSoftness,
        EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
        EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
    }

    local AtmosphereInst: Atmosphere? = Lighting:FindFirstChildOfClass("Atmosphere")
    local AtmosphereBackup = AtmosphereInst and {
        Density = AtmosphereInst.Density,
        Haze = AtmosphereInst.Haze,
        Glare = AtmosphereInst.Glare,
        Offset = AtmosphereInst.Offset,
        Color = AtmosphereInst.Color,
    } or nil

    local BloomInst: BloomEffect? = Lighting:FindFirstChildOfClass("BloomEffect")
    local BloomBackup = BloomInst and {
        Enabled = BloomInst.Enabled,
        Intensity = BloomInst.Intensity,
        Size = BloomInst.Size,
        Threshold = BloomInst.Threshold,
    } or nil

    local OrigSky: Sky? = Lighting:FindFirstChildOfClass("Sky")
    local OrigSkyFaces = OrigSky and {
        Bk = OrigSky.SkyboxBk,
        Dn = OrigSky.SkyboxDn,
        Ft = OrigSky.SkyboxFt,
        Lf = OrigSky.SkyboxLf,
        Rt = OrigSky.SkyboxRt,
        Up = OrigSky.SkyboxUp,
        StarCount = OrigSky.StarCount,
        Celestial = OrigSky.CelestialBodiesShown,
    } or nil

    local OrigClouds: Clouds? = terrain and terrain:FindFirstChildOfClass("Clouds") or nil
    local CloudsBackup = OrigClouds and {
        Enabled = OrigClouds.Enabled,
        Cover = OrigClouds.Cover,
        Density = OrigClouds.Density,
        Color = OrigClouds.Color,
    } or nil
    local CustomClouds: Clouds? = nil

    local TERRAIN_MATS = {
        Enum.Material.Grass,
        Enum.Material.LeafyGrass,
        Enum.Material.Ground,
        Enum.Material.Mud,
        Enum.Material.Rock,
        Enum.Material.Sand,
        Enum.Material.Snow,
        Enum.Material.Slate,
    }
    local TerrainMatBackup: { [Enum.Material]: Color3 } = {}
    if terrain then
        for _, mat in ipairs(TERRAIN_MATS) do
            local ok, col = pcall(function() return terrain:GetMaterialColor(mat) end)
            if ok and typeof(col) == "Color3" then
                TerrainMatBackup[mat] = col
            end
        end
    end
    local OrigWaterColor = terrain and terrain.WaterColor or Color3.fromRGB(12, 84, 92)
    local OrigDecoration = true
    if terrain and hasHiddenProp then
        local okD, dec = pcall(gethiddenproperty, terrain, "Decoration")
        if okD and type(dec) == "boolean" then
            OrigDecoration = dec
        end
    end

    local BLUR_EFFECT_NAMES = { "ADS_DOF", "DDOF", "DepthOfFieldInteraction", "WaterBlur", "InventoryBlur", "HurtEffect", "LowHealthEffect" }
    local EffectBackup: { [PostEffect]: { Enabled: boolean, Size: number? } } = {}
    for _, eff in ipairs(Lighting:GetChildren()) do
        if eff:IsA("PostEffect") then
            local isBlurName = table.find(BLUR_EFFECT_NAMES, eff.Name) ~= nil
            if isBlurName or eff:IsA("BlurEffect") or eff:IsA("DepthOfFieldEffect") then
                local sz: number? = nil
                if eff:IsA("BlurEffect") then
                    sz = eff.Size
                end
                EffectBackup[eff] = { Enabled = eff.Enabled, Size = sz }
            end
        end
    end
    local FullbrightEffect = Lighting:FindFirstChild("Fullbright")
    local FullbrightBackupEnabled = (FullbrightEffect and FullbrightEffect:IsA("ColorCorrectionEffect")) and FullbrightEffect.Enabled or false
    local OriginalFOV = Workspace.CurrentCamera and Workspace.CurrentCamera.FieldOfView or 70

    -- State flags to avoid redundant per-frame engine writes
    local AppliedLight, AppliedTime, AppliedShadows, AppliedRender = false, false, false, false
    local AppliedFog, AppliedAtmo, AppliedSky, AppliedClouds = false, false, false, false
    local AppliedBloom, AppliedBlur, AppliedFOV = false, false, false
    local AppliedWater, AppliedNoGrass, AppliedTerrainCols = false, false, false
    local LastNoGrassState: boolean? = nil
    local LastTerrainSig = ""

    -- Tree Leaves / Trunks & Landmines Async Cache + Backup Tables
    type PartBackup = { Color: Color3, Transparency: number, CanCollide: boolean, CanTouch: boolean, SaColor: Color3?, SaInst: SurfaceAppearance? }
    local LeafParts: { [BasePart]: PartBackup } = {}
    local TrunkParts: { [BasePart]: PartBackup } = {}
    local MineParts: { [BasePart]: PartBackup } = {}
    local MinePrompts: { [ProximityPrompt]: boolean } = {}
    local FoliageScanned, MinesScanned = false, false
    local FoliageScanning, MinesScanning = false, false
    local LastLeavesSig, LastTrunksSig, LastMinesApplied = "", "", false

    local function capturePartBackup(p: BasePart): PartBackup
        local sa = p:FindFirstChildOfClass("SurfaceAppearance")
        return {
            Color = p.Color,
            Transparency = p.Transparency,
            CanCollide = p.CanCollide,
            CanTouch = p.CanTouch,
            SaColor = sa and sa.Color or nil,
            SaInst = sa,
        }
    end

    local function isUnderDynamicActor(inst: Instance): boolean
        local cur: Instance? = inst
        while cur and cur ~= Workspace do
            local n = cur.Name
            if n == "Players" or n == "Containers" or n == "DroppedItems" or n == "QuestItems" or n == "Loot" or n == "Vehicles" then
                return true
            end
            if cur:IsA("Model") and cur:FindFirstChildOfClass("Humanoid") then
                return true
            end
            cur = cur.Parent
        end
        return false
    end

    local function hasTreeAncestor(inst: Instance): boolean
        local cur: Instance? = inst.Parent
        for _ = 1, 5 do
            if not cur or cur == Workspace then break end
            local ln = cur.Name:lower()
            if ln:find("tree") or ln:find("pine") or ln:find("foliage") or ln:find("bush") or ln:find("birch") or ln:find("spruce") then
                return true
            end
            cur = cur.Parent
        end
        return false
    end

    local function classifyWorldPart(d: Instance, checkFoliage: boolean, checkMines: boolean)
        if not d:IsA("BasePart") or isUnderDynamicActor(d) then
            return
        end
        local ln = d.Name:lower()
        local parentLn = d.Parent and d.Parent.Name:lower() or ""

        if checkMines then
            local mineAncestor = ln:find("pmn2") or ln:find("mon50") or ln:find("claymore") or ln:find("tripwire")
                or (ln:find("mine") and not ln:find("miner") and not ln:find("mineral"))
                or parentLn:find("pmn2") or parentLn:find("mon50") or parentLn:find("claymore") or parentLn:find("landmine")
            if mineAncestor and not MineParts[d] then
                MineParts[d] = capturePartBackup(d)
                local pr = d:FindFirstChildWhichIsA("ProximityPrompt")
                if pr and MinePrompts[pr] == nil then
                    MinePrompts[pr] = pr.Enabled
                end
            end
        end

        if checkFoliage then
            local isLeaf = ln == "leaf" or ln == "leaves" or ln:find("leaf") ~= nil or ln:find("leaves") ~= nil
                or ln:find("canopy") ~= nil or (hasTreeAncestor(d) and (d.Material == Enum.Material.Grass or ln:find("bush") ~= nil or ln:find("foliage") ~= nil))
            if isLeaf and not LeafParts[d] then
                LeafParts[d] = capturePartBackup(d)
                return
            end
            local isTrunk = ln == "trunk" or ln:find("trunk") ~= nil or ln:find("bark") ~= nil
                or (hasTreeAncestor(d) and (d.Material == Enum.Material.Wood or d.Material == Enum.Material.WoodPlanks or ln:find("log") ~= nil))
            if isTrunk and not TrunkParts[d] then
                TrunkParts[d] = capturePartBackup(d)
            end
        end
    end

    local function ensureAsyncScan(wantFoliage: boolean, wantMines: boolean)
        if wantFoliage and not FoliageScanned and not FoliageScanning then
            FoliageScanning = true
            task.spawn(function()
                local list = Workspace:GetDescendants()
                for i, d in ipairs(list) do
                    if not Session.IsAlive() then break end
                    classifyWorldPart(d, true, Config.World.NoMines)
                    if i % 2500 == 0 then task.wait() end
                end
                FoliageScanned = true
                FoliageScanning = false
                LastLeavesSig = ""
                LastTrunksSig = ""
            end)
        end
        if wantMines and not MinesScanned and not MinesScanning then
            MinesScanning = true
            task.spawn(function()
                local list = Workspace:GetDescendants()
                for i, d in ipairs(list) do
                    if not Session.IsAlive() then break end
                    classifyWorldPart(d, Config.World.LeavesEnabled or Config.World.TrunksEnabled, true)
                    if i % 2500 == 0 then task.wait() end
                end
                MinesScanned = true
                MinesScanning = false
                LastMinesApplied = false
            end)
        end
    end

    Session.Bind(Workspace.DescendantAdded, function(d)
        if FoliageScanned or MinesScanned then
            classifyWorldPart(d, FoliageScanned, MinesScanned)
            LastLeavesSig = ""
            LastTrunksSig = ""
        end
    end)

    local function applyTreeGroup(pool: { [BasePart]: PartBackup }, enabled: boolean, hide: boolean, transPct: number, col: Color3)
        local alpha = hide and 1 or math.clamp((transPct or 0) / 100, 0, 1)
        for p, bk in pairs(pool) do
            if not p.Parent then
                pool[p] = nil
            else
                if enabled then
                    p.Color = col
                    if bk.SaInst and bk.SaInst.Parent then
                        pcall(function() (bk.SaInst :: any).Color = col end)
                    end
                    p.Transparency = alpha
                    if hide then
                        p.CanCollide = false
                    end
                else
                    p.Color = bk.Color
                    p.Transparency = bk.Transparency
                    p.CanCollide = bk.CanCollide
                    if bk.SaInst and bk.SaInst.Parent and bk.SaColor then
                        pcall(function() (bk.SaInst :: any).Color = bk.SaColor end)
                    end
                end
            end
        end
    end

    local function applyMinesState(disableMines: boolean)
        for p, bk in pairs(MineParts) do
            if not p.Parent then
                MineParts[p] = nil
            else
                if disableMines then
                    p.CanTouch = false
                    p.CanCollide = false
                    p.Transparency = math.max(bk.Transparency, 0.55)
                else
                    p.CanTouch = bk.CanTouch
                    p.CanCollide = bk.CanCollide
                    p.Transparency = bk.Transparency
                end
            end
        end
        for pr, origEn in pairs(MinePrompts) do
            if not pr.Parent then
                MinePrompts[pr] = nil
            elseif disableMines then
                pr.Enabled = false
            else
                pr.Enabled = origEn
            end
        end
    end

    -- Boss & World Event Checker State
    local KnownBossNames = { "whisper", "dozer", "death", "anton", "boss", "shturman", "scavboss" }
    local KnownEventNames = { "cargoplane", "mi24", "btr80", "heli", "airdrop", "supplydrop" }
    local ActiveBossCache: { [Instance]: boolean } = {}
    local LastBossCheck = 0
    local LastRenderPlrCheck = 0
    local LastBossHudText = ""

    local function isBossOrEvent(inst: Instance, checkEvents: boolean): (boolean, string?)
        local ln = inst.Name:lower()
        for _, b in ipairs(KnownBossNames) do
            if ln:find(b) then
                return true, inst.Name
            end
        end
        if inst:GetAttribute("IsBoss") == true or inst:GetAttribute("Boss") == true then
            return true, inst.Name
        end
        if checkEvents then
            for _, ev in ipairs(KnownEventNames) do
                if ln:find(ev) then
                    return true, inst.Name
                end
            end
        end
        return false, nil
    end

    function World.Step(suspend: boolean?)
        local paused = (suspend == true)
        local w = Config.World
        local now = os.clock()

        -- 1. Light & Fullbright
        local useLight = not paused and (w.LightEnabled or w.Fullbright)
        if useLight then
            AppliedLight = true
            Lighting.Brightness = w.Brightness
            Lighting.Ambient = w.LightEnabled and w.AmbientColor or Color3.fromRGB(140, 140, 140)
            Lighting.OutdoorAmbient = w.LightEnabled and w.OutdoorAmbientColor or Color3.fromRGB(165, 165, 165)
            if w.LightEnabled then
                Lighting.ExposureCompensation = w.Exposure
            end
            if FullbrightEffect and FullbrightEffect:IsA("ColorCorrectionEffect") then
                FullbrightEffect.Enabled = false
            end
        elseif AppliedLight then
            AppliedLight = false
            Lighting.Brightness = LightingBackup.Brightness
            Lighting.Ambient = LightingBackup.Ambient
            Lighting.OutdoorAmbient = LightingBackup.OutdoorAmbient
            if not w.RenderingEnabled then
                Lighting.ExposureCompensation = LightingBackup.ExposureCompensation
            end
            if FullbrightEffect and FullbrightEffect:IsA("ColorCorrectionEffect") then
                FullbrightEffect.Enabled = FullbrightBackupEnabled
            end
        end

        -- 2. Time & Sun
        local useTime = not paused and (w.TimeSunEnabled or w.Fullbright)
        if useTime then
            AppliedTime = true
            Lighting.ClockTime = w.ClockTime
            if w.TimeSunEnabled then
                Lighting.GeographicLatitude = w.Latitude
            end
        elseif AppliedTime then
            AppliedTime = false
            Lighting.ClockTime = LightingBackup.ClockTime
            Lighting.GeographicLatitude = LightingBackup.GeographicLatitude
        end

        -- 3. Shadows
        local useShadows = not paused and (w.ShadowsEnabled or w.Fullbright)
        if useShadows then
            AppliedShadows = true
            Lighting.GlobalShadows = w.ShadowsEnabled and (not w.DisableShadows) or false
            if w.ShadowsEnabled then
                Lighting.ShadowSoftness = w.ShadowSoftness
                Lighting.EnvironmentDiffuseScale = w.DiffuseScale
            end
        elseif AppliedShadows then
            AppliedShadows = false
            Lighting.GlobalShadows = LightingBackup.GlobalShadows
            Lighting.ShadowSoftness = LightingBackup.ShadowSoftness
            Lighting.EnvironmentDiffuseScale = LightingBackup.EnvironmentDiffuseScale
        end

        -- 4. Rendering & FOV
        local useRender = not paused and w.RenderingEnabled
        if useRender then
            AppliedRender = true
            if not w.LightEnabled then
                Lighting.ExposureCompensation = w.ExposureBias
            end
            Lighting.EnvironmentSpecularScale = 0
        elseif AppliedRender then
            AppliedRender = false
            if not w.LightEnabled then
                Lighting.ExposureCompensation = LightingBackup.ExposureCompensation
            end
            Lighting.EnvironmentSpecularScale = LightingBackup.EnvironmentSpecularScale
        end

        local cam = Workspace.CurrentCamera
        if cam then
            if not paused and w.CustomFOV then
                AppliedFOV = true
                cam.FieldOfView = w.FOVValue
            elseif AppliedFOV then
                AppliedFOV = false
                cam.FieldOfView = OriginalFOV
            end
        end

        -- 5. Fog
        local useFog = not paused and (w.FogEnabled or w.NoFog)
        if useFog then
            AppliedFog = true
            if w.NoFog and not w.FogEnabled then
                Lighting.FogEnd = 1000000
                Lighting.FogStart = 0
            else
                Lighting.FogStart = w.FogStart
                Lighting.FogEnd = w.FogEnd
                Lighting.FogColor = w.FogColor
            end
        elseif AppliedFog then
            AppliedFog = false
            Lighting.FogStart = LightingBackup.FogStart
            Lighting.FogEnd = LightingBackup.FogEnd
            Lighting.FogColor = LightingBackup.FogColor
        end

        -- 6. Atmosphere
        if AtmosphereInst and AtmosphereBackup then
            if not paused and w.AtmosphereEnabled then
                AppliedAtmo = true
                AtmosphereInst.Density = w.AtmoDensity
                AtmosphereInst.Haze = w.AtmoHaze
                AtmosphereInst.Glare = w.AtmoGlare
                AtmosphereInst.Offset = w.AtmoOffset
                AtmosphereInst.Color = w.AtmoColor
            elseif not paused and w.NoFog then
                AppliedAtmo = true
                AtmosphereInst.Density = 0
                AtmosphereInst.Haze = 0
                AtmosphereInst.Glare = 0
            elseif AppliedAtmo then
                AppliedAtmo = false
                AtmosphereInst.Density = AtmosphereBackup.Density
                AtmosphereInst.Haze = AtmosphereBackup.Haze
                AtmosphereInst.Glare = AtmosphereBackup.Glare
                AtmosphereInst.Offset = AtmosphereBackup.Offset
                AtmosphereInst.Color = AtmosphereBackup.Color
            end
        end

        -- 7. Sky
        if OrigSky and OrigSkyFaces then
            if not paused and w.SkyEnabled then
                AppliedSky = true
                OrigSky.StarCount = w.SkyStars
                OrigSky.CelestialBodiesShown = w.SkyCelestial
                if w.SkyPreset == "Night Space" then
                    OrigSky.SkyboxBk = ""
                    OrigSky.SkyboxDn = ""
                    OrigSky.SkyboxFt = ""
                    OrigSky.SkyboxLf = ""
                    OrigSky.SkyboxRt = ""
                    OrigSky.SkyboxUp = ""
                else
                    OrigSky.SkyboxBk = OrigSkyFaces.Bk
                    OrigSky.SkyboxDn = OrigSkyFaces.Dn
                    OrigSky.SkyboxFt = OrigSkyFaces.Ft
                    OrigSky.SkyboxLf = OrigSkyFaces.Lf
                    OrigSky.SkyboxRt = OrigSkyFaces.Rt
                    OrigSky.SkyboxUp = OrigSkyFaces.Up
                end
            elseif AppliedSky then
                AppliedSky = false
                OrigSky.SkyboxBk = OrigSkyFaces.Bk
                OrigSky.SkyboxDn = OrigSkyFaces.Dn
                OrigSky.SkyboxFt = OrigSkyFaces.Ft
                OrigSky.SkyboxLf = OrigSkyFaces.Lf
                OrigSky.SkyboxRt = OrigSkyFaces.Rt
                OrigSky.SkyboxUp = OrigSkyFaces.Up
                OrigSky.StarCount = OrigSkyFaces.StarCount
                OrigSky.CelestialBodiesShown = OrigSkyFaces.Celestial
            end
        end

        -- 8. Clouds
        if terrain then
            if not paused and w.CloudsEnabled then
                AppliedClouds = true
                local targetClouds = OrigClouds or CustomClouds
                if not targetClouds or not targetClouds.Parent then
                    local nc = Instance.new("Clouds")
                    nc.Name = "__DeltaClouds"
                    nc.Parent = terrain
                    Session.Track(nc)
                    CustomClouds = nc
                    targetClouds = nc
                end
                if targetClouds then
                    targetClouds.Enabled = true
                    targetClouds.Cover = w.CloudsCover
                    targetClouds.Density = w.CloudsDensity
                    targetClouds.Color = w.CloudsColor
                end
            elseif AppliedClouds then
                AppliedClouds = false
                if OrigClouds and CloudsBackup and OrigClouds.Parent then
                    OrigClouds.Enabled = CloudsBackup.Enabled
                    OrigClouds.Cover = CloudsBackup.Cover
                    OrigClouds.Density = CloudsBackup.Density
                    OrigClouds.Color = CloudsBackup.Color
                elseif CustomClouds then
                    pcall(function() CustomClouds:Destroy() end)
                    CustomClouds = nil
                end
            end
        end

        -- 9. Bloom
        if BloomInst and BloomBackup then
            if not paused and w.BloomEnabled then
                AppliedBloom = true
                BloomInst.Enabled = not w.DisableBloom
                BloomInst.Intensity = w.BloomIntensity
                BloomInst.Size = w.BloomSize
                BloomInst.Threshold = w.BloomThreshold
            elseif AppliedBloom then
                AppliedBloom = false
                BloomInst.Enabled = BloomBackup.Enabled
                BloomInst.Intensity = BloomBackup.Intensity
                BloomInst.Size = BloomBackup.Size
                BloomInst.Threshold = BloomBackup.Threshold
            end
        end

        -- 10. Blur / DOF
        local useBlur = not paused and (w.BlurEnabled or w.NoBlurDOF)
        if useBlur then
            AppliedBlur = true
            local removeAll = w.NoBlurDOF or (w.BlurEnabled and w.BlurSize <= 0.1)
            for eff, bk in pairs(EffectBackup) do
                if eff.Parent then
                    if removeAll then
                        eff.Enabled = false
                    elseif eff:IsA("BlurEffect") and bk.Size ~= nil then
                        eff.Enabled = true
                        eff.Size = w.BlurSize
                    else
                        eff.Enabled = false
                    end
                end
            end
        elseif AppliedBlur then
            AppliedBlur = false
            for eff, bk in pairs(EffectBackup) do
                if eff.Parent then
                    eff.Enabled = bk.Enabled
                    if eff:IsA("BlurEffect") and bk.Size ~= nil then
                        eff.Size = bk.Size
                    end
                end
            end
        end

        -- 11. Water Color, No Grass & Terrain Material Colors
        if terrain then
            if not paused and w.WaterColorEnabled then
                AppliedWater = true
                terrain.WaterColor = w.WaterColor
            elseif AppliedWater then
                AppliedWater = false
                terrain.WaterColor = OrigWaterColor
            end

            local wantNoGrass = (not paused and w.NoGrass)
            if hasHiddenProp and LastNoGrassState ~= wantNoGrass then
                LastNoGrassState = wantNoGrass
                if wantNoGrass then
                    AppliedNoGrass = true
                    pcall(sethiddenproperty, terrain, "Decoration", false)
                elseif AppliedNoGrass then
                    AppliedNoGrass = false
                    pcall(sethiddenproperty, terrain, "Decoration", OrigDecoration)
                end
            end

            local wantTerr = (not paused and w.TerrainColorEnabled)
            local terrSig = wantTerr and string.format("%s_%d_%d_%d", w.TerrainPreset, math.floor(w.TerrainGrassColor.R * 255), math.floor(w.TerrainGroundColor.R * 255), math.floor(w.TerrainRockColor.R * 255)) or "OFF"
            if terrSig ~= LastTerrainSig then
                LastTerrainSig = terrSig
                if wantTerr then
                    AppliedTerrainCols = true
                    local grassC, groundC, rockC = w.TerrainGrassColor, w.TerrainGroundColor, w.TerrainRockColor
                    if w.TerrainPreset == "Cyber" then
                        grassC = Color3.fromRGB(30, 88, 128)
                        groundC = Color3.fromRGB(22, 28, 42)
                        rockC = Color3.fromRGB(45, 58, 88)
                    elseif w.TerrainPreset == "Arctic" then
                        grassC = Color3.fromRGB(205, 226, 242)
                        groundC = Color3.fromRGB(165, 185, 205)
                        rockC = Color3.fromRGB(130, 145, 165)
                    elseif w.TerrainPreset == "Mars" then
                        grassC = Color3.fromRGB(168, 72, 48)
                        groundC = Color3.fromRGB(128, 56, 38)
                        rockC = Color3.fromRGB(96, 48, 36)
                    end
                    pcall(function()
                        terrain:SetMaterialColor(Enum.Material.Grass, grassC)
                        terrain:SetMaterialColor(Enum.Material.LeafyGrass, grassC)
                        terrain:SetMaterialColor(Enum.Material.Ground, groundC)
                        terrain:SetMaterialColor(Enum.Material.Mud, groundC)
                        terrain:SetMaterialColor(Enum.Material.Rock, rockC)
                        terrain:SetMaterialColor(Enum.Material.Slate, rockC)
                    end)
                elseif AppliedTerrainCols then
                    AppliedTerrainCols = false
                    for mat, col in pairs(TerrainMatBackup) do
                        pcall(function() terrain:SetMaterialColor(mat, col) end)
                    end
                end
            end
        end

        -- 12. Leaves, Tree Trunks & No Mines (Async Scanned, Dirty-Checked)
        local wantLeaves = not paused and (w.LeavesEnabled or w.LeavesHide)
        local wantTrunks = not paused and (w.TrunksEnabled or w.TrunksHide)
        local wantMines = not paused and w.NoMines
        if wantLeaves or wantTrunks or wantMines then
            ensureAsyncScan(wantLeaves or wantTrunks, wantMines)
        end

        if FoliageScanned then
            local lSig = wantLeaves and string.format("1_%s_%d_%d_%d", tostring(w.LeavesHide), math.floor(w.LeavesTransparency), math.floor(w.LeavesColor.R * 255), math.floor(w.LeavesColor.G * 255)) or "OFF"
            if lSig ~= LastLeavesSig then
                LastLeavesSig = lSig
                applyTreeGroup(LeafParts, wantLeaves, w.LeavesHide, w.LeavesTransparency, w.LeavesColor)
            end
            local tSig = wantTrunks and string.format("1_%s_%d_%d_%d", tostring(w.TrunksHide), math.floor(w.TrunksTransparency), math.floor(w.TrunksColor.R * 255), math.floor(w.TrunksColor.G * 255)) or "OFF"
            if tSig ~= LastTrunksSig then
                LastTrunksSig = tSig
                applyTreeGroup(TrunkParts, wantTrunks, w.TrunksHide, w.TrunksTransparency, w.TrunksColor)
            end
        end

        if MinesScanned and wantMines ~= LastMinesApplied then
            LastMinesApplied = wantMines
            applyMinesState(wantMines)
        end

        -- 13. Render Players (throttled ~5 Hz)
        if not paused and w.RenderPlayers and (now - LastRenderPlrCheck) >= 0.2 then
            LastRenderPlrCheck = now
            for _, entry in pairs(Actors) do
                if not entry.IsAI and entry.Model.Parent then
                    for _, ch in ipairs(entry.Model:GetChildren()) do
                        if ch:IsA("BasePart") then
                            ch.LocalTransparencyModifier = 0
                        end
                    end
                end
            end
        end

        -- 14. Boss Checker (throttled ~1.5s)
        local hudFrame = World._BossHudFrame :: Frame?
        local hudLabel = World._BossHudText :: TextLabel?
        if paused or not w.BossChecker then
            if hudFrame then hudFrame.Visible = false end
        elseif (now - LastBossCheck) >= 1.5 then
            LastBossCheck = now
            local foundList: { string } = {}
            local seenNames: { [string]: boolean } = {}
            for model, entry in pairs(Actors) do
                if entry.IsAI and model.Parent then
                    local hum = model:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        local hit, bName = isBossOrEvent(model, w.BossAlertEvents)
                        if hit and bName then
                            local zoneName = model.Parent and model.Parent.Name or "AiZones"
                            local disp = string.format("%s (%s)", bName, zoneName)
                            if not seenNames[disp] then
                                seenNames[disp] = true
                                table.insert(foundList, disp)
                            end
                            if w.BossNotify and not ActiveBossCache[model] then
                                ActiveBossCache[model] = true
                                if World._Notify then
                                    World._Notify("Boss Detected", disp .. " is active!", "warn")
                                end
                            end
                        end
                    end
                end
            end
            if w.BossAlertEvents then
                local we = Workspace:FindFirstChild("WorldEvents")
                if we then
                    for _, ev in ipairs(we:GetChildren()) do
                        local hit, eName = isBossOrEvent(ev, true)
                        if hit and eName then
                            if not seenNames[eName] then
                                seenNames[eName] = true
                                table.insert(foundList, eName)
                            end
                            if w.BossNotify and not ActiveBossCache[ev] then
                                ActiveBossCache[ev] = true
                                if World._Notify then
                                    World._Notify("World Event", eName .. " active on map!", "info")
                                end
                            end
                        end
                    end
                end
            end
            for inst in pairs(ActiveBossCache) do
                if not inst.Parent then ActiveBossCache[inst] = nil end
            end
            if hudFrame and hudLabel then
                hudFrame.Visible = w.BossShowHUD == true
                local txt = (#foundList > 0) and ("BOSS: " .. table.concat(foundList, " • ")) or "BOSS CHECKER: None active"
                if txt ~= LastBossHudText then
                    LastBossHudText = txt
                    hudLabel.Text = txt
                    hudLabel.TextColor3 = (#foundList > 0) and Color3.fromRGB(251, 191, 36) or Color3.fromRGB(148, 163, 184)
                end
            end
        elseif hudFrame then
            hudFrame.Visible = w.BossShowHUD == true
        end
    end

    function World.RestoreAll()
        local w = Config.World
        w.Fullbright = false
        w.NoFog = false
        w.NoBlurDOF = false
        w.CustomFOV = false
        w.LightEnabled = false
        w.TimeSunEnabled = false
        w.ShadowsEnabled = false
        w.RenderingEnabled = false
        w.FogEnabled = false
        w.AtmosphereEnabled = false
        w.SkyEnabled = false
        w.CloudsEnabled = false
        w.BloomEnabled = false
        w.BlurEnabled = false
        w.WaterColorEnabled = false
        w.NoGrass = false
        w.TerrainColorEnabled = false
        w.LeavesEnabled = false
        w.LeavesHide = false
        w.TrunksEnabled = false
        w.TrunksHide = false
        w.NoMines = false
        w.RenderPlayers = false
        w.BossChecker = false
        w.Radar = false
        LastLeavesSig = "RESET"
        LastTrunksSig = "RESET"
        if FoliageScanned then
            applyTreeGroup(LeafParts, false, false, 0, Color3.new(1, 1, 1))
            applyTreeGroup(TrunkParts, false, false, 0, Color3.new(1, 1, 1))
        end
        if MinesScanned then
            applyMinesState(false)
            LastMinesApplied = false
        end
        World.Step(false)
    end
end)()

local Misc: { [string]: any } = {}

-- ============================================================================
-- 8. VISUALS & ESP RENDERING (DRAWING API + POOLED CHAMS)
-- ============================================================================
local HasDrawing = (type(Drawing) == "table" and type(Drawing.new) == "function")
local DrawingOpaqueIsZero = false
if HasDrawing then
    pcall(function()
        local probe = Drawing.new("Line")
        if probe then
            DrawingOpaqueIsZero = (probe.Transparency < 0.5)
            probe:Remove()
        end
    end)
end

local function drawTrans(opacity: number): number
    local op = math.clamp(opacity, 0, 1)
    if DrawingOpaqueIsZero then
        return 1 - op
    end
    return op
end

local function newDraw(kind: string, props: { [string]: any }): any
    if not HasDrawing then
        return nil
    end
    local ok, obj = pcall(Drawing.new, kind)
    if not ok or not obj then
        return nil
    end
    for k, v in pairs(props) do
        pcall(function()
            obj[k] = v
        end)
    end
    return obj
end

local BONE_PAIRS = {
    { "Head", "UpperTorso" },
    { "UpperTorso", "LowerTorso" },
    { "UpperTorso", "LeftUpperArm" },
    { "LeftUpperArm", "LeftLowerArm" },
    { "LeftLowerArm", "LeftHand" },
    { "UpperTorso", "RightUpperArm" },
    { "RightUpperArm", "RightLowerArm" },
    { "RightLowerArm", "RightHand" },
    { "LowerTorso", "LeftUpperLeg" },
    { "LeftUpperLeg", "LeftLowerLeg" },
    { "LeftLowerLeg", "LeftFoot" },
    { "LowerTorso", "RightUpperLeg" },
    { "RightUpperLeg", "RightLowerLeg" },
    { "RightLowerLeg", "RightFoot" },
}

local function setCornerBox(lines: { any }, outlines: { any }?, x: number, y: number, w: number, h: number, color: Color3)
    local L, T = math.floor(x + 0.5), math.floor(y + 0.5)
    local pw, ph = math.max(math.floor(w + 0.5), 6), math.max(math.floor(h + 0.5), 6)
    local R, B = L + pw, T + ph
    local lenX = math.clamp(math.floor(pw * 0.24 + 0.5), 4, 18)
    local lenY = math.clamp(math.floor(ph * 0.19 + 0.5), 4, 22)

    local fgCoords = {
        { Vector2.new(L - 0.5, T), Vector2.new(L + lenX, T) },
        { Vector2.new(L, T - 0.5), Vector2.new(L, T + lenY) },
        { Vector2.new(R + 0.5, T), Vector2.new(R - lenX, T) },
        { Vector2.new(R, T - 0.5), Vector2.new(R, T + lenY) },
        { Vector2.new(L - 0.5, B), Vector2.new(L + lenX, B) },
        { Vector2.new(L, B + 0.5), Vector2.new(L, B - lenY) },
        { Vector2.new(R + 0.5, B), Vector2.new(R - lenX, B) },
        { Vector2.new(R, B + 0.5), Vector2.new(R, B - lenY) },
    }
    local bgCoords = {
        { Vector2.new(L - 1, T), Vector2.new(L + lenX + 1, T) },
        { Vector2.new(L, T - 1), Vector2.new(L, T + lenY + 1) },
        { Vector2.new(R + 1, T), Vector2.new(R - lenX - 1, T) },
        { Vector2.new(R, T - 1), Vector2.new(R, T + lenY + 1) },
        { Vector2.new(L - 1, B), Vector2.new(L + lenX + 1, B) },
        { Vector2.new(L, B + 1), Vector2.new(L, B - lenY - 1) },
        { Vector2.new(R + 1, B), Vector2.new(R - lenX - 1, B) },
        { Vector2.new(R, B + 1), Vector2.new(R, B - lenY - 1) },
    }
    for i = 1, 8 do
        local out = outlines and outlines[i]
        if out then
            out.From = bgCoords[i][1]
            out.To = bgCoords[i][2]
            out.Visible = true
        end
        local line = lines[i]
        if line then
            line.From = fgCoords[i][1]
            line.To = fgCoords[i][2]
            line.Color = color
            line.Visible = true
        end
    end
end

local function updateBoxVisual(d: { [string]: any }, boxMode: string, x: number, y: number, w: number, h: number, color: Color3)
    local px, py = math.floor(x + 0.5), math.floor(y + 0.5)
    local pw, ph = math.max(math.floor(w + 0.5), 6), math.max(math.floor(h + 0.5), 6)
    if boxMode == "2D" then
        if d.BoxFill then
            if pw > 4 and ph > 4 then
                d.BoxFill.Size = Vector2.new(pw - 2, ph - 2)
                d.BoxFill.Position = Vector2.new(px + 1, py + 1)
                d.BoxFill.Color = color
                d.BoxFill.Visible = true
            else
                d.BoxFill.Visible = false
            end
        end
        d.BoxOutline.Size = Vector2.new(pw, ph)
        d.BoxOutline.Position = Vector2.new(px, py)
        d.BoxOutline.Visible = true
        d.Box.Size = Vector2.new(pw, ph)
        d.Box.Position = Vector2.new(px, py)
        d.Box.Color = color
        d.Box.Visible = true
        for i = 1, 8 do
            if d.CornerOutlines and d.CornerOutlines[i] then d.CornerOutlines[i].Visible = false end
            d.Corners[i].Visible = false
        end
    elseif boxMode == "Corner" then
        if d.BoxFill then
            if pw > 4 and ph > 4 then
                d.BoxFill.Size = Vector2.new(pw - 2, ph - 2)
                d.BoxFill.Position = Vector2.new(px + 1, py + 1)
                d.BoxFill.Color = color
                d.BoxFill.Visible = true
            else
                d.BoxFill.Visible = false
            end
        end
        d.BoxOutline.Visible = false
        d.Box.Visible = false
        setCornerBox(d.Corners, d.CornerOutlines, px, py, pw, ph, color)
    else
        if d.BoxFill then d.BoxFill.Visible = false end
        d.BoxOutline.Visible = false
        d.Box.Visible = false
        for i = 1, 8 do
            if d.CornerOutlines and d.CornerOutlines[i] then d.CornerOutlines[i].Visible = false end
            d.Corners[i].Visible = false
        end
    end
end

local function strengthenColor(col: Color3): Color3
    local h, s, v = col:ToHSV()
    if s > 0.05 then
        s = math.clamp(s * 1.15, s, 1)
    end
    v = math.clamp(v * 1.08, 0, 1)
    return Color3.fromHSV(h, s, v)
end

local function updateSkeletonVisual(d: { [string]: any }, model: Instance, cam: Camera, color: Color3, enabled: boolean)
    if enabled and model:IsA("Model") then
        local skelCol = strengthenColor(color)
        for i, pair in ipairs(BONE_PAIRS) do
            local line = d.Bones[i]
            local out = d.BoneOutlines and d.BoneOutlines[i]
            local p1 = model:FindFirstChild(pair[1])
            local p2 = model:FindFirstChild(pair[2])
            if line and p1 and p1:IsA("BasePart") and p2 and p2:IsA("BasePart") then
                local v1, ok1 = cam:WorldToViewportPoint(p1.Position)
                local v2, ok2 = cam:WorldToViewportPoint(p2.Position)
                if ok1 and ok2 then
                    local fPos, tPos = Vector2.new(v1.X, v1.Y), Vector2.new(v2.X, v2.Y)
                    if out then
                        out.From = fPos
                        out.To = tPos
                        out.Visible = true
                    end
                    line.From = fPos
                    line.To = tPos
                    line.Color = skelCol
                    line.Visible = true
                else
                    if out then out.Visible = false end
                    line.Visible = false
                end
            else
                if out then out.Visible = false end
                if line then line.Visible = false end
            end
        end
    else
        for i = 1, #BONE_PAIRS do
            if d.BoneOutlines and d.BoneOutlines[i] then
                d.BoneOutlines[i].Visible = false
            end
            if d.Bones[i] then
                d.Bones[i].Visible = false
            end
        end
    end
end

local function updateOffscreenArrow(d: { [string]: any }, worldPos: Vector3, cam: Camera, vp: Vector2, color: Color3, showArrow: boolean)
    if not showArrow or not d.Arrow then
        if d.Arrow then d.Arrow.Visible = false end
        if d.ArrowOutline then d.ArrowOutline.Visible = false end
        return
    end

    local sp, onScreen = cam:WorldToViewportPoint(worldPos)
    local inBounds = onScreen and sp.X >= 10 and sp.X <= vp.X - 10 and sp.Y >= 10 and sp.Y <= vp.Y - 10
    if inBounds then
        d.Arrow.Visible = false
        if d.ArrowOutline then d.ArrowOutline.Visible = false end
        return
    end

    local localVec = cam.CFrame:PointToObjectSpace(worldPos)
    local flat = Vector2.new(localVec.X, -localVec.Y)
    if flat.Magnitude < 0.001 then
        flat = Vector2.new(0, -1)
    end
    local dir = flat.Unit
    local perp = Vector2.new(-dir.Y, dir.X)

    local center = Vector2.new(vp.X * 0.5, vp.Y * 0.5)
    local radius = math.min(vp.X, vp.Y) * 0.37
    local tip = center + dir * radius
    local tailCenter = tip - dir * 15
    local pB = tailCenter + perp * 7.5
    local pC = tailCenter - perp * 7.5

    if d.ArrowOutline then
        local outTail = tip - dir * 16.5
        d.ArrowOutline.PointA = tip + dir * 2
        d.ArrowOutline.PointB = outTail + perp * 9
        d.ArrowOutline.PointC = outTail - perp * 9
        d.ArrowOutline.Visible = true
    end
    d.Arrow.PointA = tip
    d.Arrow.PointB = pB
    d.Arrow.PointC = pC
    d.Arrow.Color = color
    d.Arrow.Visible = true
end

local function updateHighlightChams(holder: { Highlight: Highlight? }, target: Instance, fillColor: Color3, outlineColor: Color3, enabled: boolean)
    if enabled and target.Parent then
        if not holder.Highlight or holder.Highlight.Parent ~= target then
            if holder.Highlight then
                pcall(function() holder.Highlight:Destroy() end)
            end
            local hl = Instance.new("Highlight")
            hl.Name = "__DeltaChams"
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.FillTransparency = 0.62
            hl.OutlineTransparency = 0.05
            hl.Parent = target
            Session.Track(hl)
            holder.Highlight = hl
        end
        holder.Highlight.FillColor = fillColor
        holder.Highlight.OutlineColor = outlineColor
        holder.Highlight.Enabled = true
    elseif holder.Highlight then
        holder.Highlight.Enabled = false
    end
end

local ACTOR_BOX_SAMPLE_PARTS = {
    "Head",
    "UpperTorso",
    "LowerTorso",
    "LeftUpperArm",
    "RightUpperArm",
    "LeftFoot",
    "RightFoot",
    "HumanoidRootPart",
}

local function computeActorScreenBox(model: Model, root: BasePart, cam: Camera): (boolean, number, number, number, number)
    local head = model:FindFirstChild("Head") :: BasePart?
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local anyVis = false

    local topAnchor = (head and head.Position or root.Position) + Vector3.new(0, 0.62, 0)
    local botAnchor = root.Position - Vector3.new(0, 2.75, 0)
    local feet = { model:FindFirstChild("LeftFoot"), model:FindFirstChild("RightFoot") }
    local lowY = math.huge
    for _, f in ipairs(feet) do
        if f and f:IsA("BasePart") then
            lowY = math.min(lowY, f.Position.Y - 0.28)
        end
    end
    if lowY < math.huge then
        botAnchor = Vector3.new(root.Position.X, lowY, root.Position.Z)
    end

    local t2d, tVis = cam:WorldToViewportPoint(topAnchor)
    local b2d, bVis = cam:WorldToViewportPoint(botAnchor)
    if not tVis and not bVis then
        return false, 0, 0, 0, 0
    end
    minY = math.min(t2d.Y, b2d.Y)
    maxY = math.max(t2d.Y, b2d.Y)

    for _, pName in ipairs(ACTOR_BOX_SAMPLE_PARTS) do
        local p = model:FindFirstChild(pName)
        if p and p:IsA("BasePart") then
            local sp, onScr = cam:WorldToViewportPoint(p.Position)
            if onScr then
                anyVis = true
            end
            if sp.Z > 0 then
                minX = math.min(minX, sp.X)
                maxX = math.max(maxX, sp.X)
                minY = math.min(minY, sp.Y)
                maxY = math.max(maxY, sp.Y)
            end
        end
    end
    if not anyVis then
        return false, 0, 0, 0, 0
    end

    local boxH = math.max(maxY - minY, 10)
    local minWidth = math.max(boxH * 0.50, 8)
    local measuredW = (maxX > minX) and (maxX - minX + boxH * 0.12) or minWidth
    local boxW = math.clamp(math.max(measuredW, minWidth), 8, math.max(boxH * 0.92, 22))
    local cx = (t2d.X + b2d.X) * 0.5
    return true, math.floor(cx - boxW * 0.5 + 0.5), math.floor(minY + 0.5), math.floor(boxW + 0.5), math.floor(boxH + 0.5)
end

local function compute3DScreenBox(inst: Instance, fallbackRoot: BasePart, cam: Camera): (boolean, number, number, number, number)
    local cf: CFrame, sz: Vector3
    if inst:IsA("Model") then
        cf, sz = inst:GetBoundingBox()
    else
        cf, sz = fallbackRoot.CFrame, fallbackRoot.Size
    end
    local hx, hy, hz = math.max(sz.X * 0.5, 0.35), math.max(sz.Y * 0.5, 0.35), math.max(sz.Z * 0.5, 0.35)
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local anyVis = false

    for sx = -1, 1, 2 do
        for sy = -1, 1, 2 do
            for szSign = -1, 1, 2 do
                local corner = (cf * CFrame.new(hx * sx, hy * sy, hz * szSign)).Position
                local vpPt, onScr = cam:WorldToViewportPoint(corner)
                if onScr then
                    anyVis = true
                end
                if vpPt.Z > 0 then
                    minX = math.min(minX, vpPt.X)
                    minY = math.min(minY, vpPt.Y)
                    maxX = math.max(maxX, vpPt.X)
                    maxY = math.max(maxY, vpPt.Y)
                end
            end
        end
    end

    if not anyVis or maxX <= minX or maxY <= minY then
        return false, 0, 0, 0, 0
    end
    local pad = 2
    local x = math.floor(minX - pad + 0.5)
    local y = math.floor(minY - pad + 0.5)
    local w = math.clamp(math.floor((maxX - minX) + pad * 2 + 0.5), 10, 900)
    local h = math.clamp(math.floor((maxY - minY) + pad * 2 + 0.5), 10, 900)
    return true, x, y, w, h
end

local function computeHealthColor(ratio: number): Color3
    local r = math.clamp(ratio, 0, 1)
    if r > 0.5 then
        return Color3.fromRGB(255 * (1 - r) * 2, 225, 65)
    end
    return Color3.fromRGB(239, 68 + 157 * (r * 2), 68)
end

local ACTOR_LABEL_KEYS = { "Name", "Health", "Distance", "KDR", "Reports", "Weapon", "Downed" }
local TAG_LABEL_KEYS = { "Name", "Distance", "Value", "Respawn" }

local function createDrawLinePool(count: number, thickness: number, color: Color3?, transparency: number?, zIndex: number?): { any }
    local arr = {}
    for i = 1, count do
        local props: { [string]: any } = { Thickness = thickness, Visible = false }
        if color then
            props.Color = color
        end
        if transparency then
            props.Transparency = transparency
        end
        if zIndex then
            props.ZIndex = zIndex
        end
        arr[i] = newDraw("Line", props)
    end
    return arr
end

local OUTLINE_DARK = Color3.fromRGB(8, 10, 14)

CreateActorDrawings = function()
    local d: { [string]: any } = {
        BoxFill = newDraw("Square", { Thickness = 1, Filled = true, Transparency = drawTrans(0.08), ZIndex = 1, Visible = false }),
        BoxOutline = newDraw("Square", { Thickness = 2.0, Filled = false, Color = OUTLINE_DARK, Transparency = drawTrans(0.65), ZIndex = 2, Visible = false }),
        CornerOutlines = createDrawLinePool(8, 2.0, OUTLINE_DARK, drawTrans(0.65), 2),
        Box = newDraw("Square", { Thickness = 1.0, Filled = false, Transparency = drawTrans(0.98), ZIndex = 3, Visible = false }),
        Corners = createDrawLinePool(8, 1.0, nil, drawTrans(0.98), 3),
        BoneOutlines = createDrawLinePool(#BONE_PAIRS, 2.9, OUTLINE_DARK, drawTrans(0.72), 3),
        Bones = createDrawLinePool(#BONE_PAIRS, 1.75, nil, drawTrans(1.0), 4),
        HpBg = newDraw("Square", { Thickness = 1, Filled = true, Color = OUTLINE_DARK, Transparency = drawTrans(0.75), ZIndex = 2, Visible = false }),
        HpFill = newDraw("Square", { Thickness = 1, Filled = true, Transparency = drawTrans(1.0), ZIndex = 3, Visible = false }),
        Tracer = newDraw("Line", { Thickness = 1.0, Transparency = drawTrans(0.65), ZIndex = 1, Visible = false }),
        Labels = {},
        ArrowOutline = newDraw("Triangle", { Filled = true, Color = OUTLINE_DARK, Transparency = drawTrans(0.75), ZIndex = 2, Visible = false }),
        Arrow = newDraw("Triangle", { Filled = true, Transparency = drawTrans(1.0), ZIndex = 3, Visible = false }),
    }
    for _, key in ipairs(ACTOR_LABEL_KEYS) do
        d.Labels[key] = newDraw("Text", { Center = true, Outline = true, Size = 13, Font = 2, Transparency = drawTrans(1.0), ZIndex = 5, Visible = false })
    end
    return d
end

local function hideDrawingsTable(d: { [string]: any }, hl: Highlight?, keepArrow: boolean?)
    for k, v in pairs(d) do
        if keepArrow and (k == "Arrow" or k == "ArrowOutline") then
            continue
        end
        if k == "Corners" or k == "CornerOutlines" or k == "Bones" or k == "BoneOutlines" then
            for _, line in ipairs(v) do
                if line then line.Visible = false end
            end
        elseif k == "Labels" then
            for _, lbl in pairs(v) do
                if lbl then lbl.Visible = false end
            end
        elseif v then
            v.Visible = false
        end
    end
    if hl and not keepArrow then
        hl.Enabled = false
    end
end

local function destroyVisualEntry(d: { [string]: any }, holder: { Highlight: Highlight? })
    for k, v in pairs(d) do
        if k == "Corners" or k == "CornerOutlines" or k == "Bones" or k == "BoneOutlines" then
            for _, line in ipairs(v) do
                if line then pcall(function() line:Remove() end) end
            end
        elseif k == "Labels" then
            for _, lbl in pairs(v) do
                if lbl then pcall(function() lbl:Remove() end) end
            end
        elseif v then
            pcall(function() v:Remove() end)
        end
    end
    if holder.Highlight then
        pcall(function() holder.Highlight:Destroy() end)
        holder.Highlight = nil
    end
end

DestroyActorVisuals = function(entry: ActorEntry)
    destroyVisualEntry(entry.Draw, entry)
end

CreateTagDrawings = function()
    local d: { [string]: any } = {
        BoxFill = newDraw("Square", { Thickness = 1, Filled = true, Transparency = drawTrans(0.08), ZIndex = 1, Visible = false }),
        BoxOutline = newDraw("Square", { Thickness = 2.0, Filled = false, Color = OUTLINE_DARK, Transparency = drawTrans(0.65), ZIndex = 2, Visible = false }),
        CornerOutlines = createDrawLinePool(8, 2.0, OUTLINE_DARK, drawTrans(0.65), 2),
        Box = newDraw("Square", { Thickness = 1.0, Filled = false, Transparency = drawTrans(0.98), ZIndex = 3, Visible = false }),
        Corners = createDrawLinePool(8, 1.0, nil, drawTrans(0.98), 3),
        BoneOutlines = createDrawLinePool(#BONE_PAIRS, 2.9, OUTLINE_DARK, drawTrans(0.72), 3),
        Bones = createDrawLinePool(#BONE_PAIRS, 1.75, nil, drawTrans(1.0), 4),
        DotOutline = newDraw("Circle", { Filled = true, Radius = 4.0, NumSides = 14, Color = OUTLINE_DARK, Transparency = drawTrans(0.75), ZIndex = 2, Visible = false }),
        Dot = newDraw("Circle", { Filled = true, Radius = 2.5, NumSides = 14, Transparency = drawTrans(1.0), ZIndex = 3, Visible = false }),
        Tracer = newDraw("Line", { Thickness = 1.0, Transparency = drawTrans(0.65), ZIndex = 1, Visible = false }),
        Labels = {},
        ArrowOutline = newDraw("Triangle", { Filled = true, Color = OUTLINE_DARK, Transparency = drawTrans(0.75), ZIndex = 2, Visible = false }),
        Arrow = newDraw("Triangle", { Filled = true, Transparency = drawTrans(1.0), ZIndex = 3, Visible = false }),
    }
    for _, key in ipairs(TAG_LABEL_KEYS) do
        d.Labels[key] = newDraw("Text", { Center = true, Outline = true, Size = 13, Font = 2, Transparency = drawTrans(1.0), ZIndex = 5, Visible = false })
    end
    return d
end

DestroyTagVisuals = function(entry: TagEntry)
    destroyVisualEntry(entry.Draw, entry)
end

local function formatCompactMoney(amount: number): string
    if amount >= 1000 then
        return string.format("$%.1fk", amount / 1000)
    end
    return string.format("$%.0f", amount)
end

-- Shared 4-zone stacked label + adaptive HealthBar renderer (used by Players, Npcs, and all World Cubes/Tags)
local function renderDockedLabels(
    d: { [string]: any },
    values: { [string]: { Text: string, Color: Color3, Size: number } },
    layout: { Top: { string }, Bottom: { string }, Left: { string }, Right: { string } },
    allowHpBar: boolean,
    hpRatio: number,
    boxX: number,
    boxY: number,
    boxW: number,
    boxH: number,
    lineStep: number
)
    for _, lbl in pairs(d.Labels) do
        lbl.Visible = false
    end
    if d.HpBg then d.HpBg.Visible = false end
    if d.HpFill then d.HpFill.Visible = false end

    for _, zoneName in ipairs({ "Top", "Bottom", "Left", "Right" }) do
        local list = layout[zoneName] or {}
        local hasHpBar = false
        local textKeys: { string } = {}
        for _, key in ipairs(list) do
            if key == "HealthBar" then
                if allowHpBar and d.HpBg and d.HpFill then
                    hasHpBar = true
                end
            elseif values[key] and d.Labels[key] then
                table.insert(textKeys, key)
            end
        end

        if hasHpBar then
            if zoneName == "Left" or zoneName == "Right" then
                local barW = 2
                local barX = math.floor(((zoneName == "Left") and (boxX - 5) or (boxX + boxW + 3)) + 0.5)
                local fillH = math.max(math.floor(boxH * hpRatio + 0.5), 1)
                d.HpBg.Position = Vector2.new(barX - 1, boxY - 1)
                d.HpBg.Size = Vector2.new(barW + 2, boxH + 2)
                d.HpBg.Visible = true
                d.HpFill.Position = Vector2.new(barX, boxY + (boxH - fillH))
                d.HpFill.Size = Vector2.new(barW, fillH)
                d.HpFill.Color = computeHealthColor(hpRatio)
                d.HpFill.Visible = true
            else
                local barH = 2
                local barY = math.floor(((zoneName == "Top") and (boxY - 5) or (boxY + boxH + 3)) + 0.5)
                local fillW = math.max(math.floor(boxW * hpRatio + 0.5), 1)
                d.HpBg.Position = Vector2.new(boxX - 1, barY - 1)
                d.HpBg.Size = Vector2.new(boxW + 2, barH + 2)
                d.HpBg.Visible = true
                d.HpFill.Position = Vector2.new(boxX, barY)
                d.HpFill.Size = Vector2.new(fillW, barH)
                d.HpFill.Color = computeHealthColor(hpRatio)
                d.HpFill.Visible = true
            end
        end

        local n = #textKeys
        if n > 0 then
            local barPad = hasHpBar and 6 or 3
            local centerX = math.floor(boxX + boxW * 0.5 + 0.5)
            local totalTextH = n * lineStep
            local sideStartY = math.floor(boxY + math.max((boxH - totalTextH) * 0.5, 0) + 0.5)

            for idx, key in ipairs(textKeys) do
                local lbl = d.Labels[key]
                local info = values[key]
                lbl.Text = info.Text
                lbl.Color = info.Color
                lbl.Size = info.Size
                if zoneName == "Top" then
                    lbl.Center = true
                    local bottomOfStack = boxY - barPad - 1
                    local rowY = math.floor(bottomOfStack - (n - idx + 1) * lineStep + 0.5)
                    lbl.Position = Vector2.new(centerX, rowY)
                elseif zoneName == "Bottom" then
                    lbl.Center = true
                    local rowY = math.floor(boxY + boxH + barPad + (idx - 1) * lineStep + 0.5)
                    lbl.Position = Vector2.new(centerX, rowY)
                elseif zoneName == "Left" then
                    lbl.Center = false
                    local rowY = sideStartY + (idx - 1) * lineStep
                    local boundsW = lbl.TextBounds.X
                    lbl.Position = Vector2.new(math.floor(boxX - barPad - 4 - boundsW + 0.5), rowY)
                elseif zoneName == "Right" then
                    lbl.Center = false
                    local rowY = sideStartY + (idx - 1) * lineStep
                    lbl.Position = Vector2.new(math.floor(boxX + boxW + barPad + 4 + 0.5), rowY)
                end
                lbl.Visible = true
            end
        end
    end
end

-- Unified renderer for Players and Npcs
local function renderActorESP(entry: ActorEntry, cam: Camera, vp: Vector2)
    local model = entry.Model
    if not model.Parent then
        hideDrawingsTable(entry.Draw, entry.Highlight)
        return
    end

    local isAI = entry.IsAI
    local cfg: any = isAI and Config.AIESP or Config.PlayerESP
    if not cfg.Enabled then
        hideDrawingsTable(entry.Draw, entry.Highlight)
        return
    end

    local isFriend = (not isAI and entry.Player ~= nil) and Delta.IsFriend(entry.Player :: Player) or false
    local isTeam = (not isAI and entry.Player ~= nil) and Delta.IsTeammate(entry.Player :: Player) or false
    if not isAI and not isFriend and Config.PlayerESP.TeamCheck and isTeam then
        hideDrawingsTable(entry.Draw, entry.Highlight)
        return
    end

    local hum = model:FindFirstChildOfClass("Humanoid")
    local root = model:FindFirstChild("HumanoidRootPart") :: BasePart? or model.PrimaryPart
    if not hum or not root or hum.Health <= 0 then
        hideDrawingsTable(entry.Draw, entry.Highlight)
        return
    end

    local camPos = cam.CFrame.Position
    local dist = (root.Position - camPos).Magnitude
    if dist > cfg.MaxDistance then
        hideDrawingsTable(entry.Draw, entry.Highlight)
        return
    end

    -- Semantic color selection
    local isDowned = (not isAI and entry.Player ~= nil) and Delta.IsPlayerDowned(entry.Player :: Player, model) or false
    local primaryColor: Color3
    if isAI then
        local ln = model.Name:lower()
        local isBoss = ln:find("boss") or ln:find("whisper") or ln:find("dozer") or ln:find("death")
        primaryColor = isBoss and Config.AIESP.BossColor or Config.AIESP.Color
    elseif isTeam then
        primaryColor = Config.PlayerESP.SquadColor
    elseif isDowned then
        primaryColor = Config.PlayerESP.DownedColor
    else
        primaryColor = Config.PlayerESP.EnemyColor
    end

    -- Highlight (Chams) works even when offscreen
    updateHighlightChams(entry, model, isTeam and Config.PlayerESP.SquadColor or cfg.ChamsFill, cfg.ChamsOutline, cfg.Highlights)

    -- Offscreen Arrow
    local d = entry.Draw
    updateOffscreenArrow(d, root.Position, cam, vp, primaryColor, cfg.Arrows)

    local hasBox, boxX, boxY, boxW, boxH = computeActorScreenBox(model, root, cam)
    if not hasBox then
        hideDrawingsTable(d, entry.Highlight, true)
        return
    end

    updateBoxVisual(d, cfg.Box, boxX, boxY, boxW, boxH, primaryColor)

    local fontSize = Config.Settings.FontSize
    local lineStep = fontSize + 2
    local hpRatio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)

    local values: { [string]: { Text: string, Color: Color3, Size: number } } = {}
    local detectBadge: string? = nil
    local detectColor: Color3? = nil
    if not isAI and entry.Player and Misc.GetDetectTag then
        detectBadge, detectColor = Misc.GetDetectTag(entry.Player)
    end
    if detectColor then
        primaryColor = detectColor
    end
    if cfg.Name then
        local title = (not isAI and entry.Player) and entry.Player.DisplayName or model.Name
        if isAI then
            title = "[NPC] " .. title
        else
            if isFriend then
                title = "[FRIEND] " .. title
            end
            if detectBadge then
                title = detectBadge .. " " .. title
            end
        end
        values.Name = { Text = title, Color = detectColor or primaryColor, Size = fontSize }
    end
    if cfg.HealthText then
        values.Health = { Text = string.format("%.0f HP", hum.Health), Color = computeHealthColor(hpRatio), Size = math.max(fontSize - 1, 10) }
    end
    if cfg.Distance then
        values.Distance = { Text = string.format("%.0fm", dist), Color = Color3.fromRGB(226, 232, 240), Size = math.max(fontSize - 1, 10) }
    end
    if cfg.Weapon then
        local wepName = Delta.GetHeldWeaponName(entry.Player, model)
        if wepName then
            values.Weapon = { Text = wepName, Color = Color3.fromRGB(203, 213, 225), Size = math.max(fontSize - 1, 10) }
        end
    end
    if not isAI and entry.Player then
        if Config.PlayerESP.DownedBadge and isDowned then
            values.Downed = { Text = "[DOWNED]", Color = Config.PlayerESP.DownedColor, Size = math.max(fontSize - 1, 10) }
        end
        if Config.PlayerESP.KDR or Config.PlayerESP.Reports then
            local kdrStr, repCount, isBeingBanned = Delta.GetPlayerMeta(entry.Player)
            if Config.PlayerESP.KDR then
                values.KDR = { Text = "KDR: " .. (kdrStr or "N/A"), Color = Color3.fromRGB(168, 180, 198), Size = math.max(fontSize - 1, 11) }
            end
            if Config.PlayerESP.Reports then
                local r = repCount or 0
                local repText: string
                local repColor: Color3
                if isBeingBanned then
                    repText = string.format("[BANNING] REP: %d", r)
                    repColor = Color3.fromRGB(255, 64, 64)
                elseif r >= 15 then
                    repText = string.format("[!] REP: %d", r)
                    repColor = Color3.fromRGB(248, 72, 72)
                elseif r >= 5 then
                    repText = string.format("[!] Rep: %d", r)
                    repColor = Color3.fromRGB(251, 146, 60)
                elseif r >= 1 then
                    repText = string.format("Rep: %d", r)
                    repColor = Color3.fromRGB(250, 204, 21)
                else
                    repText = "Rep: 0"
                    repColor = Color3.fromRGB(182, 194, 210)
                end
                values.Reports = { Text = repText, Color = repColor, Size = math.max(fontSize, 12) }
            end
        end
    end

    local layout = cfg.Layout or createDefaultActorLayout(isAI)
    renderDockedLabels(d, values, layout, cfg.HealthBar == true, hpRatio, boxX, boxY, boxW, boxH, lineStep)

    if cfg.Tracers then
        d.Tracer.From = Vector2.new(vp.X * 0.5, vp.Y)
        d.Tracer.To = Vector2.new(boxX + boxW * 0.5, boxY + boxH)
        d.Tracer.Color = primaryColor
        d.Tracer.Visible = true
    else
        d.Tracer.Visible = false
    end

    local skelColor = (not isAI and isTeam) and Config.PlayerESP.SquadColor or (cfg.SkeletonColor or primaryColor)
    updateSkeletonVisual(d, model, cam, skelColor, cfg.Skeleton)
end

-- Unified renderer for Corpse, Container, Dropped Item, Quest Item, and Extractions
local TAG_CATEGORY_TO_KEY: { [string]: string } = {
    Corpse = "Corpse",
    Container = "Container",
    Dropped = "Dropped Item",
    Quest = "Quest Items",
}

local function renderTagESP(tag: TagEntry, cam: Camera, vp: Vector2)
    if not tag.Instance.Parent or not tag.Root.Parent then
        hideDrawingsTable(tag.Draw, tag.Highlight)
        return
    end

    local cfg: any = nil
    local color = Color3.fromRGB(56, 189, 248)
    if tag.Category == "Exit" then
        cfg = Config.ExitESP
        color = Config.ExitESP.Color
    elseif tag.Category == "Corpse" then
        cfg = Config.CorpseESP
        color = Config.CorpseESP.Color
    elseif tag.Category == "Container" then
        cfg = Config.ContainerESP
        color = tag.IsValuable and Config.ContainerESP.ValuableColor or Config.ContainerESP.Color
    elseif tag.Category == "Dropped" then
        cfg = Config.DroppedESP
        color = tag.IsValuable and Config.DroppedESP.ValuableColor or Config.DroppedESP.Color
    elseif tag.Category == "Quest" then
        cfg = Config.QuestESP
        color = Config.QuestESP.Color
    end

    if not cfg or not cfg.Enabled then
        hideDrawingsTable(tag.Draw, tag.Highlight)
        return
    end
    if tag.Category == "Quest" and (tag.Instance:GetAttribute("HideObject") == true or tag.Instance:GetAttribute("Complete") == true) then
        hideDrawingsTable(tag.Draw, tag.Highlight)
        return
    end
    if (tag.Category == "Container" or tag.Category == "Corpse") and cfg.HideEmpty and tag.ItemCount == 0 then
        hideDrawingsTable(tag.Draw, tag.Highlight)
        return
    end
    if (tag.Category == "Container" or tag.Category == "Dropped") and cfg.ValuableOnly and not tag.IsValuable then
        hideDrawingsTable(tag.Draw, tag.Highlight)
        return
    end

    local dist = (tag.Root.Position - cam.CFrame.Position).Magnitude
    if dist > cfg.MaxDistance then
        hideDrawingsTable(tag.Draw, tag.Highlight)
        return
    end

    -- Chams Highlights
    if tag.Category ~= "Exit" then
        updateHighlightChams(tag, tag.Instance, color, cfg.ChamsOutline or Color3.new(1, 1, 1), cfg.Chams == true)
    end

    local d = tag.Draw
    updateOffscreenArrow(d, tag.Root.Position, cam, vp, color, cfg.Arrows == true)

    local sp, onScreen = cam:WorldToViewportPoint(tag.Root.Position + Vector3.new(0, 0.35, 0))
    if not onScreen then
        hideDrawingsTable(d, tag.Highlight, true)
        return
    end

    local boxMode = cfg.Box or "Off"
    local hasBox, bx, by, bw, bh = false, sp.X - 7, sp.Y - 7, 14, 14
    if boxMode ~= "Off" then
        hasBox, bx, by, bw, bh = compute3DScreenBox(tag.Instance, tag.Root, cam)
        if hasBox then
            updateBoxVisual(d, boxMode, bx, by, bw, bh, color)
        else
            bx, by, bw, bh = sp.X - 7, sp.Y - 7, 14, 14
            updateBoxVisual(d, "Off", 0, 0, 0, 0, color)
        end
    else
        updateBoxVisual(d, "Off", 0, 0, 0, 0, color)
    end

    local showDot = (tag.Category == "Exit") or (boxMode == "Off") or (not hasBox)
    local dotPos = Vector2.new(math.floor(sp.X + 0.5), math.floor(sp.Y + 0.5))
    if d.DotOutline then
        d.DotOutline.Position = dotPos
        d.DotOutline.Visible = showDot
    end
    d.Dot.Position = dotPos
    d.Dot.Color = color
    d.Dot.Visible = showDot

    local fs = Config.Settings.FontSize
    local lineStep = fs + 1
    local values: { [string]: { Text: string, Color: Color3, Size: number } } = {}

    if tag.Category == "Exit" then
        values.Name = { Text = tag.CachedLabel, Color = color, Size = math.max(fs - 1, 11) }
        values.Distance = { Text = string.format("%.0fm", dist), Color = Color3.fromRGB(226, 232, 240), Size = math.max(fs - 2, 10) }
        if Config.ExitESP.ShowTimer ~= false and tag.CachedSub ~= "" then
            values.Value = { Text = tag.CachedSub, Color = Color3.fromRGB(167, 243, 208), Size = math.max(fs - 2, 10) }
        end
        renderDockedLabels(d, values, createDefaultTagLayout("Quest Items"), false, 1, bx, by, bw, bh, lineStep)
        -- Show Exit subtitle right below Distance cleanly
        if values.Value and d.Labels.Value then
            d.Labels.Value.Text = values.Value.Text
            d.Labels.Value.Color = values.Value.Color
            d.Labels.Value.Size = values.Value.Size
            d.Labels.Value.Center = true
            d.Labels.Value.Position = Vector2.new(math.floor(sp.X + 0.5), math.floor(by + bh + 3 + lineStep + 0.5))
            d.Labels.Value.Visible = true
        end
        if Config.ExitESP.Tracers then
            d.Tracer.From = Vector2.new(vp.X * 0.5, vp.Y)
            d.Tracer.To = dotPos
            d.Tracer.Color = color
            d.Tracer.Visible = true
        else
            d.Tracer.Visible = false
        end
        updateSkeletonVisual(d, tag.Instance, cam, color, false)
        return
    end

    if cfg.Name then
        values.Name = { Text = tag.CachedLabel, Color = color, Size = math.max(fs - 1, 11) }
    end
    if cfg.Distance then
        values.Distance = { Text = string.format("%.0fm", dist), Color = Color3.fromRGB(226, 232, 240), Size = math.max(fs - 2, 10) }
    end
    if cfg.Value then
        if tag.TotalValue > 0 then
            local valCol = tag.IsValuable and Color3.fromRGB(250, 204, 21) or Color3.fromRGB(74, 222, 128)
            values.Value = { Text = formatCompactMoney(tag.TotalValue), Color = valCol, Size = math.max(fs - 2, 10) }
        elseif tag.CachedSub ~= "" then
            values.Value = { Text = tag.CachedSub, Color = Color3.fromRGB(203, 213, 225), Size = math.max(fs - 2, 10) }
        end
    end
    if tag.Category == "Container" and cfg.Respawn then
        local respText = Delta.GetContainerRespawnText(tag.Instance) or "Ready"
        local isReady = (respText == "Ready")
        values.Respawn = {
            Text = respText,
            Color = isReady and Color3.fromRGB(52, 211, 153) or Color3.fromRGB(251, 146, 60),
            Size = math.max(fs - 2, 10),
        }
    end

    local catKey = TAG_CATEGORY_TO_KEY[tag.Category] or "Dropped Item"
    local layout = cfg.Layout or createDefaultTagLayout(catKey)
    renderDockedLabels(d, values, layout, false, 1, bx, by, bw, bh, lineStep)

    if cfg.Tracers then
        d.Tracer.From = Vector2.new(vp.X * 0.5, vp.Y)
        d.Tracer.To = hasBox and Vector2.new(bx + bw * 0.5, by + bh) or dotPos
        d.Tracer.Color = color
        d.Tracer.Visible = true
    else
        d.Tracer.Visible = false
    end

    if tag.Category == "Corpse" then
        updateSkeletonVisual(d, tag.Instance, cam, cfg.SkeletonColor or color, cfg.Skeleton == true)
    else
        updateSkeletonVisual(d, tag.Instance, cam, color, false)
    end
end

-- HUD FOV Circle & Silent Target Tracer
local FOVCircleOutline = newDraw("Circle", { Thickness = 3.0, NumSides = 72, Filled = false, Color = OUTLINE_DARK, Transparency = drawTrans(0.55), ZIndex = 9, Visible = false })
local FOVCircle = newDraw("Circle", { Thickness = 1.9, NumSides = 72, Filled = false, Transparency = drawTrans(0.95), ZIndex = 10, Visible = false })
Combat._SilentLine = newDraw("Line", { Thickness = 1.0, Transparency = drawTrans(0.75), ZIndex = 9, Visible = false })
Combat._SilentDot = newDraw("Circle", { Filled = true, Radius = 2.6, NumSides = 12, Transparency = drawTrans(0.95), ZIndex = 10, Visible = false })
Combat._SilentFOVOutline = newDraw("Circle", { Thickness = 2.6, NumSides = 72, Filled = false, Color = OUTLINE_DARK, Transparency = drawTrans(0.45), ZIndex = 8, Visible = false })
Combat._SilentFOV = newDraw("Circle", { Thickness = 1.4, NumSides = 72, Filled = false, Color = Color3.fromRGB(168, 85, 247), Transparency = drawTrans(0.85), ZIndex = 9, Visible = false })

;(function()
    local RADAR_MAX_BLIPS = 44
    local radar: { [string]: any }? = nil

    local function ensureRadar()
        if radar or not HasDrawing then
            return
        end
        local blips: { { Dot: any, Label: any } } = {}
        for i = 1, RADAR_MAX_BLIPS do
            blips[i] = {
                Dot = newDraw("Circle", { Filled = true, Radius = 3.2, NumSides = 12, Transparency = drawTrans(0.95), ZIndex = 14, Visible = false }),
                Label = newDraw("Text", { Center = true, Outline = true, Size = 11, Font = 2, Transparency = drawTrans(0.92), ZIndex = 15, Visible = false }),
            }
        end
        radar = {
            Bg = newDraw("Circle", { Filled = true, NumSides = 64, Color = Color3.fromRGB(11, 14, 20), Transparency = drawTrans(0.68), ZIndex = 11, Visible = false }),
            InnerRing = newDraw("Circle", { Filled = false, Thickness = 1.0, NumSides = 48, Color = Color3.fromRGB(38, 47, 68), Transparency = drawTrans(0.45), ZIndex = 12, Visible = false }),
            Border = newDraw("Circle", { Filled = false, Thickness = 1.6, NumSides = 64, Color = Color3.fromRGB(56, 189, 248), Transparency = drawTrans(0.65), ZIndex = 13, Visible = false }),
            CrossH = newDraw("Line", { Thickness = 1.0, Color = Color3.fromRGB(48, 58, 78), Transparency = drawTrans(0.5), ZIndex = 12, Visible = false }),
            CrossV = newDraw("Line", { Thickness = 1.0, Color = Color3.fromRGB(48, 58, 78), Transparency = drawTrans(0.5), ZIndex = 12, Visible = false }),
            FovL = newDraw("Line", { Thickness = 1.0, Color = Color3.fromRGB(56, 189, 248), Transparency = drawTrans(0.45), ZIndex = 12, Visible = false }),
            FovR = newDraw("Line", { Thickness = 1.0, Color = Color3.fromRGB(56, 189, 248), Transparency = drawTrans(0.45), ZIndex = 12, Visible = false }),
            Center = newDraw("Circle", { Filled = true, Radius = 3.4, NumSides = 14, Color = Color3.fromRGB(255, 255, 255), Transparency = drawTrans(1.0), ZIndex = 16, Visible = false }),
            North = newDraw("Text", { Text = "N", Center = true, Outline = true, Size = 12, Font = 2, Color = Color3.fromRGB(56, 189, 248), Transparency = drawTrans(0.95), ZIndex = 15, Visible = false }),
            Blips = blips,
        }
    end

    function World.HideRadar()
        if not radar then return end
        for k, obj in pairs(radar) do
            if k == "Blips" then
                for _, b in ipairs(obj) do
                    if b.Dot then b.Dot.Visible = false end
                    if b.Label then b.Label.Visible = false end
                end
            elseif obj then
                obj.Visible = false
            end
        end
    end

    function World.DestroyRadar()
        if not radar then return end
        for k, obj in pairs(radar) do
            if k == "Blips" then
                for _, b in ipairs(obj) do
                    if b.Dot then pcall(function() b.Dot:Remove() end) end
                    if b.Label then pcall(function() b.Label:Remove() end) end
                end
            elseif obj then
                pcall(function() obj:Remove() end)
            end
        end
        radar = nil
    end

    function World.RenderRadar(cam: Camera, vp: Vector2)
        if not Config.World.Radar then
            World.HideRadar()
            return
        end
        ensureRadar()
        if not radar then return end

        local size = math.clamp(Config.World.RadarSize or 156, 100, 260)
        local rad = size * 0.5
        local cx = math.clamp((Config.World.RadarX or 24) + rad, rad + 6, math.max(rad + 6, vp.X - rad - 6))
        local cy = math.clamp((Config.World.RadarY or 180) + rad, rad + 6, math.max(rad + 6, vp.Y - rad - 6))
        local center = Vector2.new(cx, cy)

        radar.Bg.Position = center
        radar.Bg.Radius = rad
        radar.Bg.Visible = true
        radar.InnerRing.Position = center
        radar.InnerRing.Radius = rad * 0.5
        radar.InnerRing.Visible = true
        radar.Border.Position = center
        radar.Border.Radius = rad
        radar.Border.Visible = true

        radar.CrossH.From = Vector2.new(cx - rad + 4, cy)
        radar.CrossH.To = Vector2.new(cx + rad - 4, cy)
        radar.CrossH.Visible = true
        radar.CrossV.From = Vector2.new(cx, cy - rad + 4)
        radar.CrossV.To = Vector2.new(cx, cy + rad - 4)
        radar.CrossV.Visible = true

        local look = cam.CFrame.LookVector
        local yaw = math.atan2(look.X, look.Z)
        local halfFov = math.rad(math.clamp(cam.FieldOfView * 0.5, 18, 60))
        local rot = Config.World.RadarRotate
        local coneLen = rad * 0.85

        if rot then
            radar.FovL.From = center
            radar.FovL.To = center + Vector2.new(-math.sin(halfFov) * coneLen, -math.cos(halfFov) * coneLen)
            radar.FovR.From = center
            radar.FovR.To = center + Vector2.new(math.sin(halfFov) * coneLen, -math.cos(halfFov) * coneLen)
            local northAngle = -yaw + math.pi
            radar.North.Position = center + Vector2.new(math.sin(northAngle) * (rad - 11), -math.cos(northAngle) * (rad - 11)) - Vector2.new(0, 6)
        else
            local fwd = Vector2.new(look.X, look.Z)
            if fwd.Magnitude < 0.01 then fwd = Vector2.new(0, -1) end
            fwd = fwd.Unit
            local c1 = Vector2.new(fwd.X * math.cos(-halfFov) - fwd.Y * math.sin(-halfFov), fwd.X * math.sin(-halfFov) + fwd.Y * math.cos(-halfFov))
            local c2 = Vector2.new(fwd.X * math.cos(halfFov) - fwd.Y * math.sin(halfFov), fwd.X * math.sin(halfFov) + fwd.Y * math.cos(halfFov))
            radar.FovL.From = center
            radar.FovL.To = center + c1 * coneLen
            radar.FovR.From = center
            radar.FovR.To = center + c2 * coneLen
            radar.North.Position = Vector2.new(cx, cy - rad + 4)
        end
        radar.FovL.Visible = true
        radar.FovR.Visible = true
        radar.North.Visible = true
        radar.Center.Position = center
        radar.Center.Visible = true

        local refPos = (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart? and (LocalPlayer.Character :: any).HumanoidRootPart.Position) or cam.CFrame.Position
        local maxRange = math.max(Config.World.RadarRange or 320, 60)
        local cosY, sinY = math.cos(-yaw + math.pi), math.sin(-yaw + math.pi)
        local blipIdx = 0

        local function pushBlip(worldPos: Vector3, col: Color3, rSize: number, tagTxt: string?)
            if blipIdx >= RADAR_MAX_BLIPS then return end
            local dx = worldPos.X - refPos.X
            local dz = worldPos.Z - refPos.Z
            local dist = math.sqrt(dx * dx + dz * dz)
            if dist > maxRange then return end
            local rx, ry: number
            if rot then
                rx = dx * cosY - dz * sinY
                ry = dx * sinY + dz * cosY
            else
                rx = dx
                ry = dz
            end
            local scale = (rad - 6) / maxRange
            local pos2d = center + Vector2.new(rx * scale, ry * scale)
            blipIdx += 1
            local b = radar.Blips[blipIdx]
            b.Dot.Position = pos2d
            b.Dot.Radius = rSize
            b.Dot.Color = col
            b.Dot.Visible = true
            if tagTxt and tagTxt ~= "" then
                b.Label.Text = tagTxt
                b.Label.Color = col
                b.Label.Position = pos2d + Vector2.new(0, rSize + 1)
                b.Label.Visible = true
            else
                b.Label.Visible = false
            end
        end

        for model, entry in pairs(Actors) do
            if model.Parent then
                local hum = model:FindFirstChildOfClass("Humanoid")
                local root = model:FindFirstChild("HumanoidRootPart") :: BasePart? or model.PrimaryPart
                if hum and root and hum.Health > 0 then
                    if entry.IsAI then
                        if Config.World.RadarNPC then
                            local ln = model.Name:lower()
                            local isBoss = ln:find("whisper") or ln:find("dozer") or ln:find("death") or ln:find("boss") or ln:find("anton")
                            pushBlip(root.Position, isBoss and Config.AIESP.BossColor or Config.AIESP.Color, isBoss and 4.0 or 2.8, isBoss and model.Name or nil)
                        end
                    elseif Config.World.RadarPlayers then
                        local isTeam = entry.Player ~= nil and Delta.IsTeammate(entry.Player)
                        local isDown = entry.Player ~= nil and Delta.IsPlayerDowned(entry.Player, model)
                        local col = isTeam and Config.PlayerESP.SquadColor or (isDown and Config.PlayerESP.DownedColor or Config.PlayerESP.EnemyColor)
                        pushBlip(root.Position, col, 3.2, entry.Player and entry.Player.DisplayName or nil)
                    end
                end
            end
        end

        for _, tag in pairs(WorldTags) do
            if tag.Root and tag.Root.Parent then
                if tag.Category == "Exit" and Config.World.RadarExits then
                    pushBlip(tag.Root.Position, Config.ExitESP.Color, 3.6, "EXIT")
                elseif tag.Category == "Corpse" and Config.World.RadarCorpses then
                    pushBlip(tag.Root.Position, Config.CorpseESP.Color, 2.5, nil)
                end
            end
        end

        for i = blipIdx + 1, RADAR_MAX_BLIPS do
            radar.Blips[i].Dot.Visible = false
            radar.Blips[i].Label.Visible = false
        end
    end
end)()

-- Connect Workspace & Players Event Listeners cleanly
local function bindPlayerTracking(player: Player)
    if player == LocalPlayer then
        return
    end
    if player.Character then
        task.defer(registerActor, player.Character, player, false)
    end
    Session.Bind(player.CharacterAdded, function(char)
        task.wait(0.15)
        if char and char.Parent then
            registerActor(char, player, false)
        end
    end)
    Session.Bind(player.CharacterRemoving, function(char)
        unregisterActor(char)
    end)
end

for _, p in ipairs(Players:GetPlayers()) do
    bindPlayerTracking(p)
end
Session.Bind(Players.PlayerAdded, bindPlayerTracking)
Session.Bind(Players.PlayerRemoving, function(p)
    PlayerMetaCache[p] = nil
    if p.Character then
        unregisterActor(p.Character)
    end
end)

local function bindAiZone(zone: Instance)
    for _, npc in ipairs(zone:GetChildren()) do
        if npc:IsA("Model") then
            registerActor(npc, nil, true)
        end
    end
    Session.Bind(zone.ChildAdded, function(npc)
        task.wait(0.1)
        if npc:IsA("Model") and npc.Parent then
            registerActor(npc, nil, true)
        end
    end)
    Session.Bind(zone.ChildRemoved, unregisterActor)
end

local BoundFolders: { [Instance]: boolean } = {}

local function attachAiZonesFolder(folder: Instance)
    if BoundFolders[folder] then
        return
    end
    BoundFolders[folder] = true
    for _, zone in ipairs(folder:GetChildren()) do
        bindAiZone(zone)
    end
    Session.Bind(folder.ChildAdded, bindAiZone)
end

local function bindFolderTags(folder: Instance?, cat: "Container" | "Corpse" | "Dropped" | "Quest" | "Exit")
    if not folder or BoundFolders[folder] then
        return
    end
    BoundFolders[folder] = true
    for _, ch in ipairs(folder:GetChildren()) do
        registerWorldTag(ch, cat)
    end
    Session.Bind(folder.ChildAdded, function(ch)
        task.wait(0.1)
        if ch.Parent then
            registerWorldTag(ch, cat)
        end
    end)
    Session.Bind(folder.ChildRemoved, unregisterWorldTag)
end

local function hookWorkspaceFolder(child: Instance)
    if child.Name == "AiZones" then
        attachAiZonesFolder(child)
    elseif child.Name == "Containers" then
        bindFolderTags(child, "Container")
    elseif child.Name == "Corpses" or child.Name == "Bodies" or child.Name == "Ragdolls" then
        bindFolderTags(child, "Corpse")
    elseif child.Name == "DroppedItems" then
        bindFolderTags(child, "Dropped")
    elseif child.Name == "QuestItems" or child.Name == "Quests" then
        bindFolderTags(child, "Quest")
    elseif child.Name == "NoCollision" then
        local exits = child:FindFirstChild("ExitLocations")
        if exits then
            bindFolderTags(exits, "Exit")
        end
        local qf = child:FindFirstChild("QuestItems")
        if qf then
            bindFolderTags(qf, "Quest")
        end
        Session.Bind(child.ChildAdded, function(sub)
            if sub.Name == "ExitLocations" then
                bindFolderTags(sub, "Exit")
            elseif sub.Name == "QuestItems" then
                bindFolderTags(sub, "Quest")
            end
        end)
    end
end

for _, wsChild in ipairs(Workspace:GetChildren()) do
    hookWorkspaceFolder(wsChild)
end
Session.Bind(Workspace.ChildAdded, hookWorkspaceFolder)

-- ============================================================================
-- 8B. MISC, DETECT & VAULT SORT SUBSYSTEM
-- ============================================================================
Misc._GroupId = 3765739
Misc._OwnerId = 17953224
Misc._Doors = {} :: { [Model]: { Parts: { BasePart }, LastAutoOpen: number } }
Misc._DoorBackups = {} :: { [BasePart]: boolean }
Misc._DoorsScanned = false
Misc._ScreenBackups = {} :: { [Instance]: { Prop: string, Val: any } }
Misc._ScreenActive = false
Misc._RoleCache = {} :: { [Player]: { Rank: number, ChatTag: string, CheckedAt: number, Fetching: boolean } }
Misc._NotifiedDetect = {} :: { [string]: boolean }
Misc._WatchedReports = {} :: { [Instance]: boolean }
Misc._KnownUacFlags = {} :: { [number]: number }
Misc._LastPanic = false
Misc._MenuWasVisible = true
Misc._LastSlowStep = 0
Misc._LastReportsHudTick = 0
Misc._ShowCleanInReportsHud = false
Misc._Notify = nil :: ((string, string, string?) -> ())?
Misc._SetMenuVisible = nil :: ((boolean) -> ())?
Misc._GetMenuVisible = nil :: (() -> boolean)?
Misc._Watermark = nil :: GuiObject?
Misc._TargetHud = nil :: GuiObject?
Misc._ReportsHud = nil :: GuiObject?
Misc.RefreshReportsHud = nil :: ((boolean?) -> ())?

function Misc._SendNotify(title: string, body: string, kind: string?, bypassPanic: boolean?)
    if not bypassPanic and Config.Misc.PanicMode and (Config.Misc.PanicHideVisuals or Config.Misc.PanicHideMenu) then
        return
    end
    if Misc._Notify then
        Misc._Notify(title, body, kind or "info")
    end
end

function Misc.FormatMoney(val: number): string
    local rounded = math.floor(val + 0.5)
    local s = tostring(rounded)
    local rev = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if rev:sub(1, 1) == "," then
        rev = rev:sub(2)
    end
    return "$" .. rev
end

function Misc._HideAllVisualsNow()
    for _, entry in pairs(Actors) do
        hideDrawingsTable(entry.Draw, entry.Highlight)
    end
    for _, tag in pairs(WorldTags) do
        hideDrawingsTable(tag.Draw, tag.Highlight)
    end
    if FOVCircleOutline then FOVCircleOutline.Visible = false end
    if FOVCircle then FOVCircle.Visible = false end
    if Combat._SilentFOVOutline then Combat._SilentFOVOutline.Visible = false end
    if Combat._SilentFOV then Combat._SilentFOV.Visible = false end
    if Combat._SilentLine then Combat._SilentLine.Visible = false end
    if Combat._SilentDot then Combat._SilentDot.Visible = false end
    if World.HideRadar then World.HideRadar() end
    if World._BossHudFrame then (World._BossHudFrame :: GuiObject).Visible = false end
    if Misc._Watermark then Misc._Watermark.Visible = false end
    if Misc._TargetHud then Misc._TargetHud.Visible = false end
    if Misc._ReportsHud then Misc._ReportsHud.Visible = false end
end

function Misc.RestoreScreenEffects()
    if not Misc._ScreenActive and next(Misc._ScreenBackups) == nil then
        return
    end
    Misc._ScreenActive = false
    for inst, rec in pairs(Misc._ScreenBackups) do
        if inst.Parent then
            pcall(function()
                (inst :: any)[rec.Prop] = rec.Val
            end)
        end
    end
    table.clear(Misc._ScreenBackups)
end

local function suppressEffectProp(inst: Instance, prop: string, val: any)
    if Misc._ScreenBackups[inst] == nil then
        local ok, orig = pcall(function()
            return (inst :: any)[prop]
        end)
        if ok then
            Misc._ScreenBackups[inst] = { Prop = prop, Val = orig }
        end
    end
    pcall(function()
        (inst :: any)[prop] = val
    end)
end

function Misc.StepScreenEffects()
    local shouldHide = Config.Misc.ScreenEffects and not (Config.Misc.PanicMode and Config.Misc.PanicHideVisuals)
    if not shouldHide then
        Misc.RestoreScreenEffects()
        return
    end
    Misc._ScreenActive = true

    for _, eff in ipairs(Lighting:GetChildren()) do
        if eff:IsA("PostEffect") then
            local ln = eff.Name:lower()
            if ln == "lowhealtheffect" or ln == "hurteffect" or ln == "waterblur" or ln:find("flash") or ln:find("suppression") or ln:find("hurt") or ln:find("bleed") then
                suppressEffectProp(eff, "Enabled", false)
            end
        end
    end

    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not pg then
        return
    end

    local dmgMod = pg:FindFirstChild("DamageModule")
    if dmgMod then
        for _, ch in ipairs(dmgMod:GetChildren()) do
            local ln = ch.Name:lower()
            if ln ~= "deadscreen" and ln ~= "respawnoptions" and ln ~= "giveupbutton" and ln ~= "spectatescreen" then
                if ch:IsA("GuiObject") and (ln:find("damage") or ln:find("suppression") or ln:find("noise") or ln:find("eye") or ln:find("flash") or ln:find("blood") or ln:find("vignette")) then
                    suppressEffectProp(ch, "Visible", false)
                end
            end
        end
    end

    local noInset = pg:FindFirstChild("NoInsetGui")
    local mf = noInset and noInset:FindFirstChild("MainFrame")
    local se = mf and mf:FindFirstChild("ScreenEffects")
    if se then
        for _, ch in ipairs(se:GetChildren()) do
            local ln = ch.Name:lower()
            if ln ~= "scopes" then
                if ch:IsA("GuiObject") and (ln:find("flash") or ln:find("visor") or ln:find("parallax") or ln:find("mask") or ln:find("radiation") or ln:find("nightvision") or ln:find("snow") or ln:find("blur")) then
                    suppressEffectProp(ch, "Visible", false)
                elseif ch:IsA("Sound") and ln:find("earring") then
                    suppressEffectProp(ch, "Volume", 0)
                    pcall(function() (ch :: Sound):Stop() end)
                elseif ln:find("flashbang") then
                    for _, sub in ipairs(ch:GetDescendants()) do
                        if sub:IsA("GuiObject") then
                            suppressEffectProp(sub, "Visible", false)
                        elseif sub:IsA("Sound") then
                            suppressEffectProp(sub, "Volume", 0)
                            pcall(function() (sub :: Sound):Stop() end)
                        end
                    end
                end
            end
        end
    end
end

local function findDoorAncestor(part: BasePart): Model?
    local cur: Instance? = part.Parent
    for _ = 1, 3 do
        if not cur or cur == Workspace then
            break
        end
        if cur:IsA("Model") and cur:GetAttribute("DoorState") ~= nil then
            return cur
        end
        cur = cur.Parent
    end
    return nil
end

function Misc.RestoreDoors()
    if next(Misc._DoorBackups) == nil then
        return
    end
    for part, origCollide in pairs(Misc._DoorBackups) do
        if part.Parent then
            pcall(function()
                part.CanCollide = origCollide
            end)
        end
    end
    table.clear(Misc._DoorBackups)
end

function Misc.StepPassDoor()
    local panicBlock = Config.Misc.PanicMode and Config.Misc.PanicHideVisuals
    local active = not panicBlock and isModeActive("PassDoor", Config.Misc.PassDoor, Config.Misc.PassDoorMode, Config.Misc.PassDoorKey)
    if not active then
        Misc.RestoreDoors()
        return
    end

    local now = os.clock()
    if now - (Misc._LastDoorQuery or 0) < 0.08 then
        return
    end
    Misc._LastDoorQuery = now

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or not hrp:IsA("BasePart") then
        Misc.RestoreDoors()
        return
    end

    local range = math.clamp(Config.Misc.PassDoorRange or 18, 6, 45)
    local params = Misc._DoorOverlap
    if not params then
        params = OverlapParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.MaxParts = 160
        Misc._DoorOverlap = params
    end
    local excludes: { Instance } = { char }
    if Workspace.CurrentCamera then
        table.insert(excludes, Workspace.CurrentCamera)
    end
    params.FilterDescendantsInstances = excludes

    local nearby = Workspace:GetPartBoundsInRadius(hrp.Position, range, params)
    local activeParts: { [BasePart]: boolean } = {}
    local autoOpened: { [Model]: boolean } = {}

    for _, hit in ipairs(nearby) do
        if hit:IsA("BasePart") then
            local ln = hit.Name:lower()
            if not (ln == "frame" or ln == "doorframe" or ln == "hinge" or ln == "hinges" or ln == "jamb" or ln:find("frame")) then
                local doorModel = findDoorAncestor(hit)
                if doorModel then
                    activeParts[hit] = true
                    if Misc._DoorBackups[hit] == nil then
                        Misc._DoorBackups[hit] = hit.CanCollide
                    end
                    hit.CanCollide = false

                    if Config.Misc.PassDoorAutoOpen and not autoOpened[doorModel] and doorModel:GetAttribute("DoorState") == false then
                        autoOpened[doorModel] = true
                        local lastOpen = Misc._Doors[doorModel] and Misc._Doors[doorModel].LastAutoOpen or 0
                        if (now - lastOpen) > 1.5 and (hit.Position - hrp.Position).Magnitude <= 8.5 and type(fireproximityprompt) == "function" then
                            local prompt = doorModel:FindFirstChildWhichIsA("ProximityPrompt", true)
                            if prompt and prompt.Enabled then
                                local act = prompt.ActionText:lower()
                                if not act:find("lock") or act:find("unlock") or act:find("open") then
                                    Misc._Doors[doorModel] = Misc._Doors[doorModel] or { Parts = {}, LastAutoOpen = 0 }
                                    Misc._Doors[doorModel].LastAutoOpen = now
                                    pcall(fireproximityprompt, prompt)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    for part, origCollide in pairs(Misc._DoorBackups) do
        if not part.Parent or not activeParts[part] then
            if part.Parent then
                pcall(function()
                    part.CanCollide = origCollide
                end)
            end
            Misc._DoorBackups[part] = nil
        end
    end
end

function Misc.StepFastTrade()
    if not Config.Misc.FastTrade then
        return
    end
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local mg = pg and pg:FindFirstChild("MainGui")
    local mf = mg and mg:FindFirstChild("MainFrame")
    local bf = mf and mf:FindFirstChild("BackpackFrame")
    local ti = bf and bf:FindFirstChild("TradeInfo")
    if not ti or not ti:IsA("GuiObject") or not ti.Visible then
        return
    end
    local validating = ti:FindFirstChild("Validating")
    if validating and validating:IsA("GuiObject") then
        if not validating:GetAttribute("__DeltaFastHook") then
            validating:SetAttribute("__DeltaFastHook", true)
            Session.Bind(validating:GetPropertyChangedSignal("Visible"), function()
                if Config.Misc.FastTrade and validating.Visible then
                    validating.Visible = false
                end
            end)
        end
        validating.Visible = false
    end
    local btns = ti:FindFirstChild("Buttons")
    if btns then
        for _, bName in ipairs({ "Confirm", "Exchange" }) do
            local btn = btns:FindFirstChild(bName)
            if btn and btn:IsA("GuiButton") then
                btn.Active = true
                btn.AutoButtonColor = true
            end
        end
    end
end

function Misc.SetPanicMode(on: boolean, notifyToggle: boolean?)
    Config.Misc.PanicMode = on
    Misc._LastPanic = on
    if on then
        if Misc._GetMenuVisible then
            Misc._MenuWasVisible = Misc._GetMenuVisible()
        end
        if Config.Misc.PanicHideVisuals then
            Misc._HideAllVisualsNow()
            World.Step(true)
            Misc.RestoreScreenEffects()
            Misc.RestoreDoors()
        end
        if Config.Misc.PanicDisableCombat then
            ActiveLockedTarget = nil
            Combat.RestoreAllWeaponMods()
        end
        if Config.Misc.PanicHideMenu and Misc._SetMenuVisible then
            Misc._SetMenuVisible(false)
        end
    else
        if Config.Misc.PanicDisableCombat then
            Combat.ApplyWeaponMods()
        end
        World.Step(false)
        if Misc._Watermark then
            Misc._Watermark.Visible = Config.Settings.Watermark
        end
        if Misc._ReportsHud then
            Misc._ReportsHud.Visible = Config.Misc.ReportsHUD
        end
        if Config.Misc.PanicHideMenu and Misc._MenuWasVisible and Misc._SetMenuVisible then
            Misc._SetMenuVisible(true)
        end
        if notifyToggle then
            Misc._SendNotify("Panic Mode", "Restored active suite settings.", "info", true)
        end
    end
end

Misc._ReportStatsCache = {} :: { [Player]: { Flags: number, HSR: number, KDR: number, UpdatedAt: number } }

local function readPlayerReportStats(player: Player): (number, number, number)
    local rsPlr = Delta.GetRSPlayer(player)
    local uacFlags = Delta.GetUACReportCount(rsPlr)
    local cached = Misc._ReportStatsCache[player]
    local now = os.clock()
    if cached and (now - cached.UpdatedAt) < 1.5 then
        return math.max(uacFlags, cached.Flags), cached.HSR, cached.KDR
    end

    local flags, hsr, kdr = uacFlags, 0, 0
    local repFolder = findReportListFolder(ReplicatedStorage:FindFirstChild("ReportList"), player)
    if repFolder then
        flags = math.max(flags, tonumber(repFolder:GetAttribute("TotalFlags")) or 0)
        local rawHsr = repFolder:GetAttribute("HSR")
        hsr = type(rawHsr) == "number" and rawHsr or (tonumber(tostring(rawHsr or ""):match("[%d%.]+")) or 0)
        local rawKdr = repFolder:GetAttribute("KDR")
        if type(rawKdr) == "number" then
            kdr = rawKdr
        elseif type(rawKdr) == "string" then
            kdr = tonumber(rawKdr:match("/([%d%.]+)$") or rawKdr) or 0
        end
    end
    if kdr == 0 and rsPlr then
        local st = rsPlr:FindFirstChild("Status")
        local jr = st and st:FindFirstChild("Journey")
        local cs = jr and (jr:FindFirstChild("Statistics") or jr:FindFirstChild("WipeStatistics"))
        if cs then
            local kp = tonumber(cs:GetAttribute("K_PVP")) or 0
            local dp = tonumber(cs:GetAttribute("D_PVP")) or 0
            if kp >= 10 then
                kdr = kp / math.max(dp, 1)
            end
        end
    end

    Misc._ReportStatsCache[player] = { Flags = flags, HSR = hsr, KDR = kdr, UpdatedAt = now }
    return flags, hsr, kdr
end

local function ensurePlayerRoleFetched(player: Player)
    if player == LocalPlayer or not player.Parent then
        return
    end
    local cur = Misc._RoleCache[player]
    local now = os.clock()
    if cur and (cur.Fetching or (now - cur.CheckedAt) < 45) then
        return
    end
    local rec = cur or { Rank = 0, ChatTag = "", CheckedAt = now, Fetching = true }
    rec.Fetching = true
    Misc._RoleCache[player] = rec

    task.spawn(function()
        local okRank, rank = pcall(function()
            return player:GetRankInGroup(Misc._GroupId)
        end)
        if okRank and type(rank) == "number" then
            rec.Rank = rank
        end

        local tags: { string } = {}
        local rsPlr = Delta.GetRSPlayer(player)
        local status = rsPlr and rsPlr:FindFirstChild("Status")
        local chatTags = status and status:FindFirstChild("ChatTags")
        if chatTags then
            for k, v in pairs(chatTags:GetAttributes()) do
                table.insert(tags, tostring(k) .. " " .. tostring(v))
            end
            for _, ch in ipairs(chatTags:GetChildren()) do
                table.insert(tags, ch.Name)
                if ch:IsA("StringValue") then
                    table.insert(tags, ch.Value)
                end
            end
        end
        rec.ChatTag = table.concat(tags, " "):lower()
        rec.CheckedAt = os.clock()
        rec.Fetching = false
        if player.Parent and Misc.EvaluatePlayerDetect then
            Misc.EvaluatePlayerDetect(player)
        end
    end)
end

function Misc.ClassifyPlayer(player: Player): { IsMod: boolean, IsCC: boolean, IsTester: boolean, IsCheater: boolean, Reasons: { string } }
    ensurePlayerRoleFetched(player)
    local rec = Misc._RoleCache[player]
    local rank = rec and rec.Rank or 0
    local ct = rec and rec.ChatTag or ""

    local isMod = (player.UserId == Misc._OwnerId) or (rank >= 5) or (ct:find("mod") ~= nil) or (ct:find("admin") ~= nil) or (ct:find("dev") ~= nil)
    local isCC = (rank == 4) or (ct:find("creator") ~= nil) or (ct:find("youtube") ~= nil) or (ct:find("twitch") ~= nil)
    local isTester = (rank == 3) or (ct:find("tester") ~= nil)

    local flags, hsr, kdr = readPlayerReportStats(player)
    local reasons: { string } = {}
    local isCheater = false
    if flags >= (Config.Detect.CheaterMinFlags or 25) then
        isCheater = true
        table.insert(reasons, string.format("%d flags", flags))
    end
    if hsr >= (Config.Detect.CheaterMinHSR or 75) then
        isCheater = true
        table.insert(reasons, string.format("%.0f%% HSR", hsr))
    end
    if kdr >= (Config.Detect.CheaterMinKDR or 5.0) then
        isCheater = true
        table.insert(reasons, string.format("%.1f KDR", kdr))
    end

    return {
        IsMod = isMod,
        IsCC = isCC,
        IsTester = isTester,
        IsCheater = isCheater,
        Reasons = reasons,
    }
end

function Misc.EvaluatePlayerDetect(player: Player)
    if player == LocalPlayer or not Session.IsAlive() then
        return
    end
    local cls = Misc.ClassifyPlayer(player)
    local checks = {
        { Enabled = Config.Detect.Moderator, Notify = Config.Detect.ModeratorNotify, Flag = cls.IsMod, Tag = "Moderator", Kind = "danger", Detail = "Staff / Group Rank detected" },
        { Enabled = Config.Detect.ContentCreator, Notify = Config.Detect.ContentCreatorNotify, Flag = cls.IsCC, Tag = "Content Creator", Kind = "info", Detail = "Partnered creator detected" },
        { Enabled = Config.Detect.Tester, Notify = Config.Detect.TesterNotify, Flag = cls.IsTester, Tag = "Tester", Kind = "info", Detail = "QA / QA Tester detected" },
        { Enabled = Config.Detect.Cheater, Notify = Config.Detect.CheaterNotify, Flag = cls.IsCheater, Tag = "Suspicious Player", Kind = "danger", Detail = (#cls.Reasons > 0) and table.concat(cls.Reasons, ", ") or "High stat threshold" },
    }
    for _, c in ipairs(checks) do
        if c.Enabled and c.Notify and c.Flag then
            local key = c.Tag .. "_" .. tostring(player.UserId)
            if not Misc._NotifiedDetect[key] then
                Misc._NotifiedDetect[key] = true
                Misc._SendNotify(c.Tag .. " Detected", string.format("%s (@%s) - %s", player.DisplayName, player.Name, c.Detail), c.Kind)
            end
        end
    end
end

function Misc.GetDetectTag(player: Player): (string?, Color3?)
    if player == LocalPlayer then
        return nil, nil
    end
    local anyBadge = (Config.Detect.Moderator and Config.Detect.ModeratorBadge)
        or (Config.Detect.Cheater and Config.Detect.CheaterBadge)
        or (Config.Detect.ContentCreator and Config.Detect.ContentCreatorBadge)
        or (Config.Detect.Tester and Config.Detect.TesterBadge)
    if not anyBadge then
        return nil, nil
    end
    local cls = Misc.ClassifyPlayer(player)
    local tags: { string } = {}
    local tagColor: Color3? = nil
    if Config.Detect.Moderator and Config.Detect.ModeratorBadge and cls.IsMod then
        table.insert(tags, "[MOD]")
        tagColor = Color3.fromRGB(251, 146, 60)
    end
    if Config.Detect.Cheater and Config.Detect.CheaterBadge and cls.IsCheater then
        table.insert(tags, "[CHEATER]")
        if not tagColor then
            tagColor = Color3.fromRGB(239, 68, 68)
        end
    end
    if Config.Detect.ContentCreator and Config.Detect.ContentCreatorBadge and cls.IsCC then
        table.insert(tags, "[CC]")
        if not tagColor then
            tagColor = Color3.fromRGB(192, 132, 252)
        end
    end
    if Config.Detect.Tester and Config.Detect.TesterBadge and cls.IsTester then
        table.insert(tags, "[TESTER]")
        if not tagColor then
            tagColor = Color3.fromRGB(56, 189, 248)
        end
    end
    if #tags == 0 then
        return nil, nil
    end
    return table.concat(tags, " "), tagColor
end

function Misc.SortVaultByValue()
    local rsPlr = Delta.GetRSPlayer(LocalPlayer)
    local vault = rsPlr and rsPlr:FindFirstChild("VaultStorage")
    local inv = vault and vault:FindFirstChild("Inventory")
    if not inv then
        Misc._SendNotify("Vault Sort", "VaultStorage not accessible here (open Vault/Main Menu).", "info", true)
        return
    end

    local totalVal = 0
    local topName = ""
    local topVal = 0
    local invItems = inv:GetChildren()
    local itemPoolByName: { [string]: { number } } = {}
    local itemValsByObj: { [Instance]: number } = {}
    local itemValBySlot: { [string]: number } = {}

    for _, item in ipairs(invItems) do
        local val, _, dispName = Delta.GetItemValue(item, true)
        totalVal += val
        itemValsByObj[item] = val
        local slotAttr = item:GetAttribute("Slot")
        if type(slotAttr) == "string" and slotAttr ~= "" then
            itemValBySlot[slotAttr] = (itemValBySlot[slotAttr] or 0) + val
        end
        local key1 = item.Name:lower()
        local key2 = dispName:lower()
        itemPoolByName[key1] = itemPoolByName[key1] or {}
        table.insert(itemPoolByName[key1], val)
        if key2 ~= key1 then
            itemPoolByName[key2] = itemPoolByName[key2] or {}
            table.insert(itemPoolByName[key2], val)
        end
        if val > topVal then
            topVal = val
            topName = dispName
        end
    end
    for _, list in pairs(itemPoolByName) do
        table.sort(list, function(a, b) return a > b end)
    end

    -- Locate visible Vault / Loot Container Grid
    local pg = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local mg = pg and pg:FindFirstChild("MainGui")
    local mf = mg and mg:FindFirstChild("MainFrame")
    local bf = mf and mf:FindFirstChild("BackpackFrame")
    local containerFrame: Instance? = nil
    if bf then
        local loot = bf:FindFirstChild("Loot")
        local lInv = loot and loot:FindFirstChild("Inventory")
        local sc = lInv and lInv:FindFirstChild("ScrollingFrame")
        local cont = sc and sc:FindFirstChild("Container")
        local fr = cont and cont:FindFirstChild("Frame")
        if fr then
            containerFrame = fr
        end
    end

    local sortedSlots = 0
    if containerFrame then
        local grid = containerFrame:FindFirstChildWhichIsA("UIGridLayout")
        if grid then
            grid.SortOrder = Enum.SortOrder.LayoutOrder
        end

        type SlotEntry = { Frame: GuiObject, Value: number, OrigIdx: number, Name: string }
        local entries: { SlotEntry } = {}
        local origIdx = 0

        for _, child in ipairs(containerFrame:GetChildren()) do
            if child:IsA("GuiObject") then
                origIdx += 1
                local slotVal = -1
                local slotName = child.Name

                -- Strategy 1: Live ObjectValue link on Container slot frame
                local objVal = child:FindFirstChildWhichIsA("ObjectValue", true)
                if objVal and objVal.Value then
                    slotVal = itemValsByObj[objVal.Value] or Delta.GetItemValue(objVal.Value, true)
                    slotName = objVal.Value.Name
                elseif itemValBySlot[child.Name] ~= nil then
                    -- Strategy 2: Direct Project Delta Slot attribute match ("Container1..N")
                    slotVal = itemValBySlot[child.Name]
                else
                    -- Strategy 3: ItemName / DisplayName attribute or label text
                    local attrName = child:GetAttribute("ItemName") or child:GetAttribute("Item") or child:GetAttribute("DisplayName")
                    local candidateKey: string? = (type(attrName) == "string" and attrName ~= "") and attrName or nil
                    if not candidateKey then
                        for _, desc in ipairs(child:GetDescendants()) do
                            if desc:IsA("TextLabel") and (desc.Name:lower():find("name") or desc.Name:lower():find("title")) and desc.Text ~= "" then
                                candidateKey = desc.Text
                                break
                            end
                        end
                    end
                    if candidateKey then
                        local pool = itemPoolByName[candidateKey:lower()]
                        if pool and #pool > 0 then
                            slotVal = table.remove(pool, 1) :: number
                        elseif ItemsPriceCache[candidateKey] then
                            slotVal = ItemsPriceCache[candidateKey].Price
                        end
                        slotName = candidateKey
                    elseif child:FindFirstChildWhichIsA("ViewportFrame") or child:FindFirstChildWhichIsA("ImageLabel") then
                        for _, sub in ipairs(child:GetChildren()) do
                            if not sub:IsA("UIStroke") and not sub:IsA("UICorner") and not sub:IsA("UIAspectRatioConstraint") then
                                local pool = itemPoolByName[sub.Name:lower()]
                                if pool and #pool > 0 then
                                    slotVal = table.remove(pool, 1) :: number
                                    slotName = sub.Name
                                    break
                                end
                            end
                        end
                    end
                end

                if slotVal >= 0 then
                    sortedSlots += 1
                end
                table.insert(entries, {
                    Frame = child,
                    Value = slotVal,
                    OrigIdx = origIdx,
                    Name = slotName,
                })
            end
        end

        table.sort(entries, function(a, b)
            if (a.Value >= 0) ~= (b.Value >= 0) then
                return a.Value >= 0
            end
            if a.Value ~= b.Value then
                return a.Value > b.Value
            end
            if a.Name ~= b.Name then
                return a.Name < b.Name
            end
            return a.OrigIdx < b.OrigIdx
        end)

        for rank, rec in ipairs(entries) do
            rec.Frame.LayoutOrder = (rec.Value >= 0) and rank or (1000 + rec.OrigIdx)
        end
    end

    local msg = string.format("Total: %s (%d items)", Misc.FormatMoney(totalVal), #invItems)
    if topName ~= "" then
        msg = msg .. string.format(" | Top: %s (%s)", topName, Misc.FormatMoney(topVal))
    end
    if sortedSlots > 0 then
        msg = msg .. string.format(" | Sorted %d slots", sortedSlots)
    end
    Misc._SendNotify("Vault Sort", msg, "success", true)
end

function Misc.InitListeners()
    -- Watch every in-server player's live Status.UAC.Reports ("0".."4") & BeingBanned
    -- Wait for initial attribute replication settle & remember baseline across respawns so re-syncs never spam notifications.
    local function attachPlayerUACWatcher(plr: Player)
        task.spawn(function()
            local deadline = os.clock() + 18
            local rsPlr: Instance? = nil
            local uac: Instance? = nil
            local reports: Instance? = nil
            while Session.IsAlive() and plr.Parent and os.clock() < deadline do
                rsPlr = Delta.GetRSPlayer(plr)
                local st = rsPlr and rsPlr:FindFirstChild("Status")
                uac = st and st:FindFirstChild("UAC")
                reports = uac and uac:FindFirstChild("Reports")
                if reports and uac then
                    break
                end
                task.wait(0.75)
            end
            if not (reports and uac and rsPlr and plr.Parent and Session.IsAlive()) or Misc._WatchedReports[reports] then
                return
            end
            Misc._WatchedReports[reports] = true

            local uid = plr.UserId
            local hadBaseline = (Misc._KnownUacFlags[uid] ~= nil)
            local settledAt = os.clock() + 2.2
            local lastSum = math.max(Delta.GetUACReportCount(rsPlr), Misc._KnownUacFlags[uid] or 0)
            Misc._KnownUacFlags[uid] = lastSum

            local function onReportChanged()
                local curSum = Delta.GetUACReportCount(rsPlr)
                PlayerMetaCache[plr] = nil
                Misc._ReportStatsCache[plr] = nil

                if os.clock() < settledAt and not hadBaseline then
                    lastSum = math.max(lastSum, curSum)
                    Misc._KnownUacFlags[uid] = lastSum
                    Misc.EvaluatePlayerDetect(plr)
                    return
                end

                hadBaseline = true
                if curSum > lastSum then
                    local added = curSum - lastSum
                    local prevZeroRespawn = (lastSum == 0 and added >= 8 and plr ~= LocalPlayer)
                    lastSum = curSum
                    Misc._KnownUacFlags[uid] = curSum
                    Misc.EvaluatePlayerDetect(plr)
                    if not prevZeroRespawn and Config.Misc.ReportNotify then
                        if plr == LocalPlayer and Config.Misc.ReportAlertSelf then
                            Misc._SendNotify("Report Alert", string.format("Self UAC flag (+%d | %d total)", added, curSum), "danger")
                        elseif plr ~= LocalPlayer and Config.Misc.ReportAlertServer and added <= 10 then
                            Misc._SendNotify("Server Report", string.format("%s flagged (+%d | %d total)", plr.DisplayName, added, curSum), "warn")
                        end
                    end
                elseif curSum ~= lastSum then
                    lastSum = curSum
                    Misc._KnownUacFlags[uid] = math.max(Misc._KnownUacFlags[uid] or 0, curSum)
                end
            end

            Session.Bind(reports.AttributeChanged, onReportChanged)
            Session.Bind(reports.ChildAdded, onReportChanged)
            Session.Bind(uac:GetAttributeChangedSignal("BeingBanned"), function()
                PlayerMetaCache[plr] = nil
                Misc._ReportStatsCache[plr] = nil
                if uac:GetAttribute("BeingBanned") == true and Config.Misc.ReportNotify then
                    if plr == LocalPlayer and Config.Misc.ReportAlertSelf then
                        Misc._SendNotify("UAC Alert", "Your account entered UAC BeingBanned state!", "danger")
                    elseif plr ~= LocalPlayer and Config.Misc.ReportAlertServer then
                        Misc._SendNotify("UAC Ban Flag", plr.DisplayName .. " flagged BeingBanned!", "warn")
                    end
                end
            end)

            task.delay(2.2, function()
                if plr.Parent and reports and reports.Parent and Session.IsAlive() then
                    hadBaseline = true
                    local liveSum = Delta.GetUACReportCount(rsPlr)
                    lastSum = math.max(lastSum, liveSum)
                    Misc._KnownUacFlags[uid] = lastSum
                    PlayerMetaCache[plr] = nil
                    Misc._ReportStatsCache[plr] = nil
                    Misc.EvaluatePlayerDetect(plr)
                end
            end)
        end)
    end

    -- Listen to server ReportNotification remote without notifying unless relevant alerts are enabled
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local repNotif = remotes and remotes:FindFirstChild("ReportNotification")
    if repNotif and repNotif:IsA("RemoteEvent") then
        Session.Bind(repNotif.OnClientEvent, function(...)
            if not Config.Misc.ReportNotify then
                return
            end
            local a = ...
            local detail = type(a) == "string" and a or ""
            local mentionsSelf = detail:find(LocalPlayer.Name, 1, true) ~= nil
            if (mentionsSelf and Config.Misc.ReportAlertSelf) or (not mentionsSelf and Config.Misc.ReportAlertServer and detail ~= "") then
                Misc._SendNotify("Report Notification", detail ~= "" and detail or "Server UAC report notice", "warn")
            end
        end)
    end

    -- Passively refresh cached stats when ReportList.Recent updates for players in THIS server only.
    -- Never notify for global cross-server ReportList refreshes (which dump ~50 entries every minute).
    local function invalidateMatchingServerPlayer(entry: Instance)
        local uid = entry:GetAttribute("UserId")
        local uname = entry:GetAttribute("UserName") or entry.Name:match("^(.+)_%d+$")
        for _, p in ipairs(Players:GetPlayers()) do
            if (uid and p.UserId == uid) or (uname and p.Name == uname) then
                PlayerMetaCache[p] = nil
                Misc._ReportStatsCache[p] = nil
                Misc.EvaluatePlayerDetect(p)
                break
            end
        end
    end

    local rl = ReplicatedStorage:FindFirstChild("ReportList")
    local recent = rl and rl:FindFirstChild("Recent")
    if recent then
        Session.Bind(recent.ChildAdded, function(entry)
            invalidateMatchingServerPlayer(entry)
        end)
    end

    -- Scan current players asynchronously + bind PlayerAdded/Removing for UAC, Join Notify & Detect
    for _, plr in ipairs(Players:GetPlayers()) do
        attachPlayerUACWatcher(plr)
        if plr ~= LocalPlayer then
            ensurePlayerRoleFetched(plr)
        end
    end

    Session.Bind(Players.PlayerAdded, function(plr: Player)
        attachPlayerUACWatcher(plr)
        if plr == LocalPlayer then
            return
        end
        ensurePlayerRoleFetched(plr)
        task.spawn(function()
            task.wait(0.8)
            if not plr.Parent or not Session.IsAlive() then
                return
            end
            local cls = Misc.ClassifyPlayer(plr)
            local isFlagged = cls.IsMod or cls.IsCC or cls.IsTester or cls.IsCheater or (plr.AccountAge < 7)
            if Config.Misc.JoinNotify and (not Config.Misc.JoinAlertFlaggedOnly or isFlagged) then
                local notes: { string } = {}
                if cls.IsMod then table.insert(notes, "MOD") end
                if cls.IsCC then table.insert(notes, "CC") end
                if cls.IsTester then table.insert(notes, "TESTER") end
                if cls.IsCheater then table.insert(notes, "CHEATER") end
                if Config.Misc.JoinShowAge then
                    table.insert(notes, string.format("Age: %dd", plr.AccountAge))
                end
                local suffix = (#notes > 0) and (" (" .. table.concat(notes, " | ") .. ")") or ""
                Misc._SendNotify("Player Joined", string.format("%s (@%s)%s", plr.DisplayName, plr.Name, suffix), cls.IsMod and "danger" or "info")
            end
        end)
    end)

    Session.Bind(Players.PlayerRemoving, function(plr: Player)
        local wasFlagged = false
        local cached = Misc._RoleCache[plr]
        if cached and cached.Rank >= 3 then
            wasFlagged = true
        end
        Misc._RoleCache[plr] = nil
        Misc._ReportStatsCache[plr] = nil
        Misc._KnownUacFlags[plr.UserId] = nil
        PlayerMetaCache[plr] = nil
        if plr ~= LocalPlayer and Config.Misc.JoinNotify and Config.Misc.JoinLeaveAlerts and (not Config.Misc.JoinAlertFlaggedOnly or wasFlagged) then
            Misc._SendNotify("Player Left", string.format("%s (@%s) disconnected", plr.DisplayName, plr.Name), "info")
        end
    end)
end

function Misc.Step()
    if Config.Misc.PanicMode ~= Misc._LastPanic then
        Misc.SetPanicMode(Config.Misc.PanicMode, false)
    end
    Misc.StepPassDoor()
    local now = os.clock()
    if now - Misc._LastSlowStep >= 0.1 then
        Misc._LastSlowStep = now
        Misc.StepFastTrade()
        Misc.StepScreenEffects()
    end
    if now - Misc._LastReportsHudTick >= 1.0 then
        Misc._LastReportsHudTick = now
        if Misc.RefreshReportsHud then
            Misc.RefreshReportsHud(false)
        end
    end
end

Misc.InitListeners()

Session.OnStop(function()
    Misc.RestoreDoors()
    Misc.RestoreScreenEffects()
    Combat.RestoreAllWeaponMods()
    World.RestoreAll()
    for _, entry in pairs(Actors) do
        DestroyActorVisuals(entry)
    end
    table.clear(Actors)
    for _, tag in pairs(WorldTags) do
        DestroyTagVisuals(tag)
    end
    table.clear(WorldTags)
    if FOVCircleOutline then
        pcall(function() FOVCircleOutline:Remove() end)
    end
    if FOVCircle then
        pcall(function() FOVCircle:Remove() end)
    end
    if Combat._SilentLine then
        pcall(function() Combat._SilentLine:Remove() end)
    end
    if Combat._SilentDot then
        pcall(function() Combat._SilentDot:Remove() end)
    end
    if Combat._SilentFOVOutline then
        pcall(function() Combat._SilentFOVOutline:Remove() end)
    end
    if Combat._SilentFOV then
        pcall(function() Combat._SilentFOV:Remove() end)
    end
    if World.DestroyRadar then
        World.DestroyRadar()
    end
end)

-- ============================================================================
-- 8C. EXECUTOR CONFIG MANAGER (JSON SAVE / LOAD / AUTOLOAD)
-- ============================================================================
local ConfigMgr = {
    _Dir = "DeltaSuite",
    _CfgDir = "DeltaSuite/configs",
    _AutoFile = "DeltaSuite/autoload.txt",
    _Selected = "default",
    _InputName = "default",
    _Http = game:GetService("HttpService"),
    _ApplyUI = nil :: (() -> ())?,
}

;(function()
local function sanitizeConfigName(name: string?): string
    local clean = tostring(name or ""):gsub("[^%w%-%_%. ]", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if clean == "" then
        return "default"
    end
    return clean
end

local function hasExecutorFS(): boolean
    return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

local function ensureConfigFolders()
    if type(isfolder) == "function" and type(makefolder) == "function" then
        if not isfolder(ConfigMgr._Dir) then
            pcall(makefolder, ConfigMgr._Dir)
        end
        if not isfolder(ConfigMgr._CfgDir) then
            pcall(makefolder, ConfigMgr._CfgDir)
        end
    end
end

local function getMemConfigStore(): { [string]: string }
    local store = rawget(Env, "__DeltaSuiteSavedConfigs")
    if type(store) ~= "table" then
        store = {}
        Env.__DeltaSuiteSavedConfigs = store
    end
    return store
end

local function serializeValue(val: any): any
    local t = typeof(val)
    if t == "Color3" then
        return { __t = "Color3", r = val.R, g = val.G, b = val.B }
    elseif t == "EnumItem" then
        local enumName = tostring(val.EnumType):match("([^%.]+)$") or "KeyCode"
        return { __t = "EnumItem", e = enumName, n = val.Name }
    elseif type(val) == "table" then
        local out: { [any]: any } = {}
        for k, v in pairs(val) do
            out[k] = serializeValue(v)
        end
        return out
    elseif type(val) == "boolean" or type(val) == "number" or type(val) == "string" then
        return val
    end
    return nil
end

local function deserializeValue(val: any, template: any): any
    if type(val) == "table" then
        if val.__t == "Color3" and type(val.r) == "number" and type(val.g) == "number" and type(val.b) == "number" then
            return Color3.new(val.r, val.g, val.b)
        elseif val.__t == "EnumItem" and type(val.e) == "string" and type(val.n) == "string" then
            local ok, item = pcall(function()
                return (Enum :: any)[val.e][val.n]
            end)
            if ok and typeof(item) == "EnumItem" then
                return item
            end
            return template
        end
    end
    return val
end

local function mergeConfigTable(dst: { [any]: any }, src: { [any]: any })
    for k, tmpl in pairs(dst) do
        local raw = src[k]
        if raw ~= nil then
            if type(tmpl) == "table" and type(raw) == "table" and raw.__t == nil then
                if #tmpl > 0 and #raw > 0 then
                    local nextArr = {}
                    for _, elem in ipairs(raw) do
                        table.insert(nextArr, elem)
                    end
                    dst[k] = nextArr
                else
                    mergeConfigTable(tmpl, raw)
                end
            else
                local decoded = deserializeValue(raw, tmpl)
                if typeof(decoded) == typeof(tmpl) then
                    dst[k] = decoded
                end
            end
        end
    end
end

function ConfigMgr.GetAutoLoad(): string?
    if hasExecutorFS() and isfile(ConfigMgr._AutoFile) then
        local ok, txt = pcall(readfile, ConfigMgr._AutoFile)
        if ok and type(txt) == "string" then
            local clean = txt:gsub("^%s+", ""):gsub("%s+$", "")
            if clean ~= "" then
                return clean
            end
        end
    end
    local memAuto = rawget(Env, "__DeltaSuiteAutoConfig")
    if type(memAuto) == "string" and memAuto ~= "" then
        return memAuto
    end
    return nil
end

function ConfigMgr.SetAutoLoad(name: string?)
    if name and name ~= "" then
        local clean = sanitizeConfigName(name)
        Env.__DeltaSuiteAutoConfig = clean
        if hasExecutorFS() then
            ensureConfigFolders()
            pcall(writefile, ConfigMgr._AutoFile, clean)
        end
    else
        Env.__DeltaSuiteAutoConfig = nil
        if hasExecutorFS() and type(delfile) == "function" and isfile(ConfigMgr._AutoFile) then
            pcall(delfile, ConfigMgr._AutoFile)
        elseif hasExecutorFS() and isfile(ConfigMgr._AutoFile) then
            pcall(writefile, ConfigMgr._AutoFile, "")
        end
    end
end

function ConfigMgr.List(): { string }
    local seen: { [string]: boolean } = { default = true }
    local list: { string } = { "default" }
    local function push(n: string)
        local c = sanitizeConfigName(n)
        if c ~= "" and not seen[c] then
            seen[c] = true
            table.insert(list, c)
        end
    end

    if hasExecutorFS() and type(listfiles) == "function" then
        ensureConfigFolders()
        local ok, files = pcall(listfiles, ConfigMgr._CfgDir)
        if ok and type(files) == "table" then
            for _, fPath in ipairs(files) do
                if type(fPath) == "string" then
                    local stem = fPath:match("([^/\\]+)%.json$")
                    if stem then
                        push(stem)
                    end
                end
            end
        end
    end
    for k in pairs(getMemConfigStore()) do
        push(k)
    end
    if ConfigMgr._Selected ~= "" then
        push(ConfigMgr._Selected)
    end
    table.sort(list, function(a, b)
        if a == "default" then return true end
        if b == "default" then return false end
        return a:lower() < b:lower()
    end)
    return list
end

function ConfigMgr.Save(name: string): boolean
    local clean = sanitizeConfigName(name)
    ConfigMgr._Selected = clean
    ConfigMgr._InputName = clean
    local okEnc, encoded = pcall(function()
        return ConfigMgr._Http:JSONEncode(serializeValue(Config))
    end)
    if not okEnc or type(encoded) ~= "string" then
        Misc._SendNotify("Config Error", "Failed to serialize configuration.", "danger", true)
        return false
    end

    getMemConfigStore()[clean] = encoded
    local savedDisk = false
    if hasExecutorFS() then
        ensureConfigFolders()
        savedDisk = pcall(writefile, ConfigMgr._CfgDir .. "/" .. clean .. ".json", encoded)
    end
    Misc._SendNotify(
        "Config Saved",
        string.format("Saved '%s'%s", clean, savedDisk and " (executor storage)" or " (memory)"),
        "success",
        true
    )
    return true
end

function ConfigMgr.Load(name: string, quiet: boolean?): boolean
    local clean = sanitizeConfigName(name)
    local rawJson: string? = nil
    local filePath = ConfigMgr._CfgDir .. "/" .. clean .. ".json"
    if hasExecutorFS() and isfile(filePath) then
        local okRead, txt = pcall(readfile, filePath)
        if okRead and type(txt) == "string" and txt ~= "" then
            rawJson = txt
        end
    end
    if not rawJson then
        rawJson = getMemConfigStore()[clean]
    end
    if not rawJson then
        if not quiet then
            Misc._SendNotify("Config Load", string.format("Profile '%s' not found.", clean), "warn", true)
        end
        return false
    end

    local okDec, decoded = pcall(function()
        return ConfigMgr._Http:JSONDecode(rawJson :: string)
    end)
    if not okDec or type(decoded) ~= "table" then
        if not quiet then
            Misc._SendNotify("Config Error", "Corrupt JSON in '" .. clean .. "'.", "danger", true)
        end
        return false
    end

    local fresh = createDefaultConfig()
    mergeConfigTable(fresh, decoded)
    fresh.Misc.PanicMode = false
    for k, v in pairs(fresh) do
        Config[k] = v
    end
    table.clear(ToggleStates)
    table.clear(Misc._NotifiedDetect)
    Misc._LastPanic = false
    ConfigMgr._Selected = clean
    ConfigMgr._InputName = clean

    Misc.RestoreDoors()
    Misc.RestoreScreenEffects()
    Combat.ApplyWeaponMods()
    World.Step(false)
    if ConfigMgr._ApplyUI then
        ConfigMgr._ApplyUI()
    end
    if not quiet then
        Misc._SendNotify("Config Loaded", string.format("Loaded profile '%s'", clean), "success", true)
    end
    return true
end

function ConfigMgr.Delete(name: string): boolean
    local clean = sanitizeConfigName(name)
    getMemConfigStore()[clean] = nil
    local filePath = ConfigMgr._CfgDir .. "/" .. clean .. ".json"
    if hasExecutorFS() and type(delfile) == "function" and isfile(filePath) then
        pcall(delfile, filePath)
    end
    if ConfigMgr.GetAutoLoad() == clean then
        ConfigMgr.SetAutoLoad(nil)
    end
    if ConfigMgr._Selected == clean then
        ConfigMgr._Selected = "default"
        ConfigMgr._InputName = "default"
    end
    Misc._SendNotify("Config Deleted", string.format("Removed profile '%s'", clean), "info", true)
    return true
end

function ConfigMgr.TryAutoLoad()
    local target = ConfigMgr.GetAutoLoad()
    if target and target ~= "" then
        if ConfigMgr.Load(target, true) then
            Misc._SendNotify("Auto-Load", "Loaded saved profile: " .. target, "info", true)
        end
    end
end
end)()

-- ============================================================================
-- 9. CLEAN & PROFESSIONAL OBSIDIAN TACTICAL UI + HUD
-- ============================================================================
local THEME = {
    BgMain = Color3.fromRGB(11, 14, 20),
    BgSidebar = Color3.fromRGB(15, 19, 28),
    BgHeader = Color3.fromRGB(14, 18, 26),
    BgCard = Color3.fromRGB(20, 25, 37),
    BgControl = Color3.fromRGB(27, 34, 49),
    BgHover = Color3.fromRGB(34, 43, 62),
    Border = Color3.fromRGB(38, 47, 68),
    Accent = Color3.fromRGB(56, 189, 248),
    AccentAlt = Color3.fromRGB(99, 102, 241),
    TextPrimary = Color3.fromRGB(241, 245, 249),
    TextSecondary = Color3.fromRGB(148, 163, 184),
    TextMuted = Color3.fromRGB(100, 116, 139),
    Success = Color3.fromRGB(34, 197, 94),
    Danger = Color3.fromRGB(239, 68, 68),
}

local function addCorner(inst: Instance, rad: number)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, rad)
    c.Parent = inst
    return c
end

local function addStroke(inst: Instance, color: Color3?, thickness: number?, trans: number?): UIStroke
    local s = Instance.new("UIStroke")
    s.Color = color or THEME.Border
    s.Thickness = thickness or 1
    s.Transparency = trans or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = inst
    return s
end

local function quickTween(inst: Instance, props: { [string]: any }, dur: number?)
    TweenService:Create(inst, TweenInfo.new(dur or 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DeltaSuiteUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.AutoLocalize = false
ScreenGui.DisplayOrder = 120
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = getUiParent()
Session.Track(ScreenGui)

-- Floating Dropdown Popover Layer (prevents clipping inside scroll frames)
local PopupLayer = Instance.new("Frame")
PopupLayer.Name = "PopupLayer"
PopupLayer.Size = UDim2.fromScale(1, 1)
PopupLayer.BackgroundTransparency = 1
PopupLayer.ZIndex = 60
PopupLayer.Parent = ScreenGui

local ActivePopup: Frame? = nil
local IgnoreNextPopupDismiss = false
local function closeActivePopup()
    if ActivePopup then
        ActivePopup:Destroy()
        ActivePopup = nil
    end
end

Session.Bind(UserInputService.InputBegan, function(input: InputObject)
    if not ActivePopup or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
        return
    end
    if IgnoreNextPopupDismiss then
        IgnoreNextPopupDismiss = false
        return
    end
    local pos = input.Position
    local pPos = ActivePopup.AbsolutePosition
    local pSize = ActivePopup.AbsoluteSize
    if pos.X < pPos.X or pos.X > pPos.X + pSize.X or pos.Y < pPos.Y or pos.Y > pPos.Y + pSize.Y then
        closeActivePopup()
    end
end)

-- Notification Toast Stack (Bottom Right)
local ToastContainer = Instance.new("Frame")
ToastContainer.Name = "ToastStack"
ToastContainer.AnchorPoint = Vector2.new(1, 1)
ToastContainer.Position = UDim2.new(1, -18, 1, -18)
ToastContainer.Size = UDim2.fromOffset(290, 260)
ToastContainer.BackgroundTransparency = 1
ToastContainer.ZIndex = 80
ToastContainer.Parent = ScreenGui

local toastLayout = Instance.new("UIListLayout")
toastLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
toastLayout.Padding = UDim.new(0, 8)
toastLayout.Parent = ToastContainer

local UI = {
    _Refreshers = {} :: { () -> () },
    _OnChange = {} :: { () -> () },
    _GlassCards = {} :: { { Frame: Frame, Stroke: UIStroke } },
    _GlassPreview = {} :: { Main: Frame?, Header: Frame?, Stage: Frame?, MainStroke: UIStroke? },
    _ActiveEspCategory = "Player",
    Preview = {} :: { [string]: any },
}

function UI.NotifyChange()
    for _, fn in ipairs(UI._OnChange) do
        pcall(fn)
    end
end

function UI.RefreshAll()
    for _, fn in ipairs(UI._Refreshers) do
        pcall(fn)
    end
    UI.NotifyChange()
end

function UI.Notify(title: string, desc: string, kind: ("info" | "success" | "warn" | "danger")?)
    if not Config.Settings.Notifications or not Session.IsAlive() then
        return
    end
    local accent = kind == "success" and THEME.Success
        or (kind == "danger" and THEME.Danger
        or (kind == "warn" and Color3.fromRGB(245, 158, 11) or THEME.Accent))
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 52)
    card.BackgroundColor3 = THEME.BgCard
    card.BackgroundTransparency = 1
    card.ClipsDescendants = true
    card.Parent = ToastContainer
    addCorner(card, 8)
    local st = addStroke(card, THEME.Border, 1, 1)

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 3, 1, -12)
    bar.Position = UDim2.fromOffset(7, 6)
    bar.BackgroundColor3 = accent
    bar.BorderSizePixel = 0
    bar.Parent = card
    addCorner(bar, 2)

    local tLbl = Instance.new("TextLabel")
    tLbl.BackgroundTransparency = 1
    tLbl.Position = UDim2.fromOffset(18, 7)
    tLbl.Size = UDim2.new(1, -26, 0, 17)
    tLbl.Font = Enum.Font.GothamBold
    tLbl.TextSize = 12
    tLbl.TextColor3 = THEME.TextPrimary
    tLbl.TextXAlignment = Enum.TextXAlignment.Left
    tLbl.Text = title
    tLbl.Parent = card

    local dLbl = Instance.new("TextLabel")
    dLbl.BackgroundTransparency = 1
    dLbl.Position = UDim2.fromOffset(18, 25)
    dLbl.Size = UDim2.new(1, -26, 0, 18)
    dLbl.Font = Enum.Font.Gotham
    dLbl.TextSize = 11
    dLbl.TextColor3 = THEME.TextSecondary
    dLbl.TextXAlignment = Enum.TextXAlignment.Left
    dLbl.TextTruncate = Enum.TextTruncate.AtEnd
    dLbl.Text = desc
    dLbl.Parent = card

    quickTween(card, { BackgroundTransparency = 0.06 }, 0.18)
    quickTween(st, { Transparency = 0.1 }, 0.18)
    task.delay(3.0, function()
        if card.Parent then
            quickTween(card, { BackgroundTransparency = 1 }, 0.2)
            quickTween(st, { Transparency = 1 }, 0.2)
            task.wait(0.22)
            pcall(function() card:Destroy() end)
        end
    end)
end

-- Watermark Pill (Top Right)
local WatermarkFrame = Instance.new("Frame")
WatermarkFrame.Name = "Watermark"
WatermarkFrame.AnchorPoint = Vector2.new(1, 0)
WatermarkFrame.Position = UDim2.new(1, -16, 0, 46)
WatermarkFrame.Size = UDim2.fromOffset(310, 30)
WatermarkFrame.BackgroundColor3 = THEME.BgMain
WatermarkFrame.BackgroundTransparency = 0.12
WatermarkFrame.Parent = ScreenGui
addCorner(WatermarkFrame, 7)
addStroke(WatermarkFrame, THEME.Border, 1, 0.2)

local wmAccent = Instance.new("Frame")
wmAccent.Size = UDim2.new(0, 3, 1, -10)
wmAccent.Position = UDim2.fromOffset(6, 5)
wmAccent.BackgroundColor3 = THEME.Accent
wmAccent.BorderSizePixel = 0
wmAccent.Parent = WatermarkFrame
addCorner(wmAccent, 2)

local WatermarkText = Instance.new("TextLabel")
WatermarkText.BackgroundTransparency = 1
WatermarkText.Position = UDim2.fromOffset(16, 0)
WatermarkText.Size = UDim2.new(1, -24, 1, 0)
WatermarkText.Font = Enum.Font.GothamMedium
WatermarkText.TextSize = 12
WatermarkText.TextColor3 = THEME.TextPrimary
WatermarkText.TextXAlignment = Enum.TextXAlignment.Left
WatermarkText.Text = "DELTA SUITE  |  Project Delta"
WatermarkText.Parent = WatermarkFrame

Misc._Notify = UI.Notify
Misc._Watermark = WatermarkFrame
World._Notify = UI.Notify

;(function()
    local bossHud = Instance.new("Frame")
    bossHud.Name = "BossCheckerHUD"
    bossHud.AnchorPoint = Vector2.new(1, 0)
    bossHud.Position = UDim2.new(1, -16, 0, 82)
    bossHud.Size = UDim2.fromOffset(310, 26)
    bossHud.BackgroundColor3 = THEME.BgMain
    bossHud.BackgroundTransparency = 0.28
    bossHud.Visible = false
    bossHud.Parent = ScreenGui
    addCorner(bossHud, 6)
    addStroke(bossHud, Color3.fromRGB(245, 158, 11), 1, 0.35)

    local bhBar = Instance.new("Frame")
    bhBar.Size = UDim2.new(0, 3, 1, -8)
    bhBar.Position = UDim2.fromOffset(6, 4)
    bhBar.BackgroundColor3 = Color3.fromRGB(245, 158, 11)
    bhBar.BorderSizePixel = 0
    bhBar.Parent = bossHud
    addCorner(bhBar, 2)

    local bhLbl = Instance.new("TextLabel")
    bhLbl.BackgroundTransparency = 1
    bhLbl.Position = UDim2.fromOffset(15, 0)
    bhLbl.Size = UDim2.new(1, -22, 1, 0)
    bhLbl.Font = Enum.Font.GothamBold
    bhLbl.TextSize = 11
    bhLbl.TextColor3 = Color3.fromRGB(251, 191, 36)
    bhLbl.TextXAlignment = Enum.TextXAlignment.Left
    bhLbl.TextTruncate = Enum.TextTruncate.AtEnd
    bhLbl.Text = "BOSS CHECKER: Scanning..."
    bhLbl.Parent = bossHud

    World._BossHudFrame = bossHud
    World._BossHudText = bhLbl
end)()

-- Live Server Check Reports HUD (draggable, translucent, shows live UAC flags & KDR for all players)
;(function()
    local repHud = Instance.new("Frame")
    repHud.Name = "ServerReportsHUD"
    repHud.AnchorPoint = Vector2.new(1, 0)
    repHud.Position = UDim2.new(1, -16, 0, 114)
    repHud.Size = UDim2.fromOffset(310, 212)
    repHud.BackgroundColor3 = THEME.BgMain
    repHud.BackgroundTransparency = 0.22
    repHud.Visible = false
    repHud.ClipsDescendants = true
    repHud.Parent = ScreenGui
    addCorner(repHud, 8)
    addStroke(repHud, THEME.Border, 1, 0.25)

    local rhHeader = Instance.new("Frame")
    rhHeader.Size = UDim2.new(1, 0, 0, 28)
    rhHeader.BackgroundColor3 = THEME.BgSidebar
    rhHeader.BackgroundTransparency = 0.24
    rhHeader.BorderSizePixel = 0
    rhHeader.Parent = repHud

    local rhTitle = Instance.new("TextLabel")
    rhTitle.BackgroundTransparency = 1
    rhTitle.Position = UDim2.fromOffset(10, 0)
    rhTitle.Size = UDim2.new(1, -110, 1, 0)
    rhTitle.Font = Enum.Font.GothamBold
    rhTitle.TextSize = 11
    rhTitle.TextColor3 = THEME.TextPrimary
    rhTitle.TextXAlignment = Enum.TextXAlignment.Left
    rhTitle.Text = "CHECK REPORTS"
    rhTitle.Parent = rhHeader

    local rhFilterBtn = Instance.new("TextButton")
    rhFilterBtn.Size = UDim2.fromOffset(56, 18)
    rhFilterBtn.Position = UDim2.new(1, -84, 0.5, -9)
    rhFilterBtn.BackgroundColor3 = THEME.BgControl
    rhFilterBtn.Font = Enum.Font.GothamSemibold
    rhFilterBtn.TextSize = 10
    rhFilterBtn.TextColor3 = THEME.Accent
    rhFilterBtn.Text = "Flagged"
    rhFilterBtn.AutoButtonColor = false
    rhFilterBtn.Parent = rhHeader
    addCorner(rhFilterBtn, 4)
    addStroke(rhFilterBtn, THEME.Border, 1, 0.35)

    local rhCloseBtn = Instance.new("TextButton")
    rhCloseBtn.Size = UDim2.fromOffset(20, 18)
    rhCloseBtn.Position = UDim2.new(1, -24, 0.5, -9)
    rhCloseBtn.BackgroundColor3 = THEME.BgControl
    rhCloseBtn.Font = Enum.Font.GothamBold
    rhCloseBtn.TextSize = 10
    rhCloseBtn.TextColor3 = THEME.TextSecondary
    rhCloseBtn.Text = "X"
    rhCloseBtn.AutoButtonColor = false
    rhCloseBtn.Parent = rhHeader
    addCorner(rhCloseBtn, 4)

    local rhScroll = Instance.new("ScrollingFrame")
    rhScroll.Position = UDim2.fromOffset(6, 32)
    rhScroll.Size = UDim2.new(1, -12, 1, -38)
    rhScroll.BackgroundTransparency = 1
    rhScroll.BorderSizePixel = 0
    rhScroll.ScrollBarThickness = 3
    rhScroll.ScrollBarImageColor3 = THEME.Border
    rhScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    rhScroll.CanvasSize = UDim2.fromOffset(0, 0)
    rhScroll.Parent = repHud

    local rhList = Instance.new("UIListLayout")
    rhList.Padding = UDim.new(0, 4)
    rhList.SortOrder = Enum.SortOrder.LayoutOrder
    rhList.Parent = rhScroll

    -- Simple header drag for Reports HUD
    local draggingHud = false
    local dragStartPos: Vector2? = nil
    local hudStartPos: UDim2? = nil
    Session.Bind(rhHeader.InputBegan, function(inp: InputObject)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingHud = true
            dragStartPos = Vector2.new(inp.Position.X, inp.Position.Y)
            if repHud.AnchorPoint.X ~= 0 then
                local absPos = repHud.AbsolutePosition
                local rootPos = ScreenGui.AbsolutePosition
                repHud.AnchorPoint = Vector2.new(0, 0)
                repHud.Position = UDim2.fromOffset(absPos.X - rootPos.X, absPos.Y - rootPos.Y)
            end
            hudStartPos = repHud.Position
        end
    end)
    Session.Bind(UserInputService.InputChanged, function(inp: InputObject)
        if draggingHud and dragStartPos and hudStartPos and inp.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = Vector2.new(inp.Position.X, inp.Position.Y) - dragStartPos
            repHud.Position = UDim2.fromOffset(hudStartPos.X.Offset + delta.X, hudStartPos.Y.Offset + delta.Y)
        end
    end)
    Session.Bind(UserInputService.InputEnded, function(inp: InputObject)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingHud = false
        end
    end)

    local lastSig = ""
    local rowObjs: { Instance } = {}

    local function severityForReport(flags: number, banning: boolean): (Color3, string)
        if banning then
            return Color3.fromRGB(255, 64, 64), "BAN"
        elseif flags >= 15 then
            return Color3.fromRGB(248, 72, 72), tostring(flags)
        elseif flags >= 5 then
            return Color3.fromRGB(251, 146, 60), tostring(flags)
        elseif flags >= 1 then
            return Color3.fromRGB(250, 204, 21), tostring(flags)
        end
        return Color3.fromRGB(148, 163, 184), "0"
    end

    local function refreshReportsHud(forceBuild: boolean?)
        local hiddenByPanic = Config.Misc.PanicMode and Config.Misc.PanicHideVisuals
        local shouldShow = (Config.Misc.ReportsHUD == true) and not hiddenByPanic
        repHud.Visible = shouldShow
        if not shouldShow then
            return
        end

        local cam = Workspace.CurrentCamera
        local myPos = cam and cam.CFrame.Position
        local rows = {}
        local flaggedCount = 0
        local totalCount = 0
        for _, plr in ipairs(Players:GetPlayers()) do
            totalCount += 1
            local kdrStr, repCount, isBan = Delta.GetPlayerMeta(plr)
            local flags = repCount or 0
            if flags > 0 or isBan then
                flaggedCount += 1
            end
            if Misc._ShowCleanInReportsHud or flags > 0 or isBan or plr == LocalPlayer then
                local distStr = "-"
                local model = plr.Character or Workspace:FindFirstChild(plr.Name)
                local root = model and model:IsA("Model") and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
                if root and root:IsA("BasePart") and myPos then
                    distStr = string.format("%.0fm", (root.Position - myPos).Magnitude)
                end
                table.insert(rows, {
                    Player = plr,
                    Flags = flags,
                    Ban = isBan,
                    KDR = kdrStr or "N/A",
                    Dist = distStr,
                    IsSelf = (plr == LocalPlayer),
                })
            end
        end

        table.sort(rows, function(a, b)
            if a.Ban ~= b.Ban then return a.Ban end
            if a.Flags ~= b.Flags then return a.Flags > b.Flags end
            return a.Player.Name:lower() < b.Player.Name:lower()
        end)

        rhTitle.Text = string.format("CHECK REPORTS  •  %d/%d Flagged", flaggedCount, totalCount)
        rhFilterBtn.Text = Misc._ShowCleanInReportsHud and "All" or "Flagged"

        local sigParts = { rhTitle.Text, rhFilterBtn.Text }
        for _, r in ipairs(rows) do
            table.insert(sigParts, string.format("%d:%d:%s:%s", r.Player.UserId, r.Flags, r.Ban and "1" or "0", r.Dist))
        end
        local sig = table.concat(sigParts, "|")
        if not forceBuild and sig == lastSig then
            return
        end
        lastSig = sig

        for _, obj in ipairs(rowObjs) do
            obj:Destroy()
        end
        table.clear(rowObjs)

        if #rows == 0 then
            local emptyLbl = Instance.new("TextLabel")
            emptyLbl.Size = UDim2.new(1, 0, 0, 32)
            emptyLbl.BackgroundTransparency = 1
            emptyLbl.Font = Enum.Font.GothamMedium
            emptyLbl.TextSize = 11
            emptyLbl.TextColor3 = THEME.TextSecondary
            emptyLbl.Text = "No reported players in this server."
            emptyLbl.Parent = rhScroll
            table.insert(rowObjs, emptyLbl)
            repHud.Size = UDim2.fromOffset(310, 74)
            return
        end

        for i, r in ipairs(rows) do
            local row = Instance.new("Frame")
            row.LayoutOrder = i
            row.Size = UDim2.new(1, -2, 0, 24)
            row.BackgroundColor3 = THEME.BgControl
            row.BackgroundTransparency = 0.25
            row.Parent = rhScroll
            addCorner(row, 4)

            local badgeCol, badgeText = severityForReport(r.Flags, r.Ban)
            local badge = Instance.new("TextLabel")
            badge.Size = UDim2.fromOffset(36, 18)
            badge.Position = UDim2.fromOffset(4, 3)
            badge.BackgroundColor3 = badgeCol
            badge.BackgroundTransparency = 0.15
            badge.Font = Enum.Font.GothamBold
            badge.TextSize = 10
            badge.TextColor3 = Color3.fromRGB(10, 12, 18)
            badge.Text = badgeText
            badge.Parent = row
            addCorner(badge, 4)

            local nameLbl = Instance.new("TextLabel")
            nameLbl.BackgroundTransparency = 1
            nameLbl.Position = UDim2.fromOffset(46, 0)
            nameLbl.Size = UDim2.new(1, -138, 1, 0)
            nameLbl.Font = r.Flags > 0 and Enum.Font.GothamBold or Enum.Font.GothamMedium
            nameLbl.TextSize = 11
            nameLbl.TextColor3 = r.IsSelf and THEME.Accent or (r.Flags > 0 and badgeCol or THEME.TextPrimary)
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left
            nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
            nameLbl.Text = r.Player.DisplayName .. (r.IsSelf and " (You)" or "")
            nameLbl.Parent = row

            local metaLbl = Instance.new("TextLabel")
            metaLbl.BackgroundTransparency = 1
            metaLbl.Position = UDim2.new(1, -90, 0, 0)
            metaLbl.Size = UDim2.fromOffset(84, 24)
            metaLbl.Font = Enum.Font.Gotham
            metaLbl.TextSize = 10
            metaLbl.TextColor3 = THEME.TextSecondary
            metaLbl.TextXAlignment = Enum.TextXAlignment.Right
            metaLbl.Text = string.format("KD:%s  %s", r.KDR, r.Dist)
            metaLbl.Parent = row

            table.insert(rowObjs, row)
        end

        local targetH = math.clamp(38 + #rows * 28, 86, 260)
        repHud.Size = UDim2.fromOffset(310, targetH)
    end

    Session.Bind(rhFilterBtn.MouseButton1Click, function()
        Misc._ShowCleanInReportsHud = not Misc._ShowCleanInReportsHud
        refreshReportsHud(true)
    end)

    Session.Bind(rhCloseBtn.MouseButton1Click, function()
        Config.Misc.ReportsHUD = false
        repHud.Visible = false
        UI.RefreshAll()
    end)

    Misc._ReportsHud = repHud
    Misc.RefreshReportsHud = refreshReportsHud
end)()

-- Target Lock HUD (Top Center-Bottom)
local TargetHudFrame = Instance.new("Frame")
TargetHudFrame.Name = "TargetHUD"
TargetHudFrame.AnchorPoint = Vector2.new(0.5, 1)
TargetHudFrame.Position = UDim2.new(0.5, 0, 1, -92)
TargetHudFrame.Size = UDim2.fromOffset(236, 56)
TargetHudFrame.BackgroundColor3 = THEME.BgMain
TargetHudFrame.BackgroundTransparency = 0.12
TargetHudFrame.Visible = false
TargetHudFrame.Parent = ScreenGui
addCorner(TargetHudFrame, 8)
addStroke(TargetHudFrame, THEME.Accent, 1, 0.45)

local TargetHudName = Instance.new("TextLabel")
TargetHudName.BackgroundTransparency = 1
TargetHudName.Position = UDim2.fromOffset(12, 7)
TargetHudName.Size = UDim2.new(1, -24, 0, 16)
TargetHudName.Font = Enum.Font.GothamBold
TargetHudName.TextSize = 12
TargetHudName.TextColor3 = THEME.TextPrimary
TargetHudName.TextXAlignment = Enum.TextXAlignment.Left
TargetHudName.Parent = TargetHudFrame

local TargetHudInfo = Instance.new("TextLabel")
TargetHudInfo.BackgroundTransparency = 1
TargetHudInfo.Position = UDim2.fromOffset(12, 23)
TargetHudInfo.Size = UDim2.new(1, -24, 0, 14)
TargetHudInfo.Font = Enum.Font.Gotham
TargetHudInfo.TextSize = 11
TargetHudInfo.TextColor3 = THEME.TextSecondary
TargetHudInfo.TextXAlignment = Enum.TextXAlignment.Left
TargetHudInfo.Parent = TargetHudFrame

local TargetHpBg = Instance.new("Frame")
TargetHpBg.Position = UDim2.new(0, 12, 1, -12)
TargetHpBg.Size = UDim2.new(1, -24, 0, 4)
TargetHpBg.BackgroundColor3 = THEME.BgControl
TargetHpBg.BorderSizePixel = 0
TargetHpBg.Parent = TargetHudFrame
addCorner(TargetHpBg, 2)

local TargetHpFill = Instance.new("Frame")
TargetHpFill.Size = UDim2.fromScale(1, 1)
TargetHpFill.BackgroundColor3 = THEME.Success
TargetHpFill.BorderSizePixel = 0
TargetHpFill.Parent = TargetHpBg
addCorner(TargetHpFill, 2)

-- Main Window
local MainWindow = Instance.new("Frame")
MainWindow.Name = "MainWindow"
MainWindow.AnchorPoint = Vector2.new(0.5, 0.5)
MainWindow.Position = UDim2.fromScale(0.5, 0.5)
MainWindow.Size = UDim2.fromOffset(740, 490)
MainWindow.BackgroundColor3 = THEME.BgMain
MainWindow.BackgroundTransparency = 0.22
MainWindow.ClipsDescendants = true
MainWindow.Parent = ScreenGui
addCorner(MainWindow, 10)
addStroke(MainWindow, THEME.Border, 1.2, 0.25)

-- Sidebar Navigation
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 168, 1, 0)
Sidebar.BackgroundColor3 = THEME.BgSidebar
Sidebar.BackgroundTransparency = 0.28
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainWindow

local SideSep = Instance.new("Frame")
SideSep.Position = UDim2.new(1, -1, 0, 0)
SideSep.Size = UDim2.new(0, 1, 1, 0)
SideSep.BackgroundColor3 = THEME.Border
SideSep.BackgroundTransparency = 0.45
SideSep.BorderSizePixel = 0
SideSep.Parent = Sidebar

local BrandBox = Instance.new("Frame")
BrandBox.Size = UDim2.new(1, 0, 0, 62)
BrandBox.BackgroundTransparency = 1
BrandBox.Parent = Sidebar

local BrandTitle = Instance.new("TextLabel")
BrandTitle.BackgroundTransparency = 1
BrandTitle.Position = UDim2.fromOffset(16, 13)
BrandTitle.Size = UDim2.new(1, -24, 0, 20)
BrandTitle.Font = Enum.Font.GothamBold
BrandTitle.TextSize = 15
BrandTitle.TextColor3 = THEME.TextPrimary
BrandTitle.TextXAlignment = Enum.TextXAlignment.Left
BrandTitle.Text = "DELTA SUITE"
BrandTitle.Parent = BrandBox

local BrandSub = Instance.new("TextLabel")
BrandSub.BackgroundTransparency = 1
BrandSub.Position = UDim2.fromOffset(16, 34)
BrandSub.Size = UDim2.new(1, -24, 0, 15)
BrandSub.Font = Enum.Font.GothamMedium
BrandSub.TextSize = 11
BrandSub.TextColor3 = THEME.Accent
BrandSub.TextXAlignment = Enum.TextXAlignment.Left
BrandSub.Text = "Project Delta"
BrandSub.Parent = BrandBox

local TabButtonList = Instance.new("Frame")
TabButtonList.Position = UDim2.fromOffset(10, 72)
TabButtonList.Size = UDim2.new(1, -20, 1, -124)
TabButtonList.BackgroundTransparency = 1
TabButtonList.Parent = Sidebar

local tabLayout = Instance.new("UIListLayout")
tabLayout.Padding = UDim.new(0, 6)
tabLayout.Parent = TabButtonList

local SideFooter = Instance.new("TextLabel")
SideFooter.BackgroundTransparency = 1
SideFooter.Position = UDim2.new(0, 16, 1, -34)
SideFooter.Size = UDim2.new(1, -28, 0, 22)
SideFooter.Font = Enum.Font.Gotham
SideFooter.TextSize = 11
SideFooter.TextColor3 = THEME.TextMuted
SideFooter.TextXAlignment = Enum.TextXAlignment.Left
SideFooter.Text = "RCtrl to Toggle"
SideFooter.Parent = Sidebar

-- Right Main Content Area
local HeaderBar = Instance.new("Frame")
HeaderBar.Position = UDim2.fromOffset(168, 0)
HeaderBar.Size = UDim2.new(1, -168, 0, 48)
HeaderBar.BackgroundColor3 = THEME.BgHeader
HeaderBar.BackgroundTransparency = 0.28
HeaderBar.BorderSizePixel = 0
HeaderBar.Parent = MainWindow

local HeaderSep = Instance.new("Frame")
HeaderSep.Position = UDim2.new(0, 0, 1, -1)
HeaderSep.Size = UDim2.new(1, 0, 0, 1)
HeaderSep.BackgroundColor3 = THEME.Border
HeaderSep.BackgroundTransparency = 0.45
HeaderSep.BorderSizePixel = 0
HeaderSep.Parent = HeaderBar

local ActiveTabTitle = Instance.new("TextLabel")
ActiveTabTitle.BackgroundTransparency = 1
ActiveTabTitle.Position = UDim2.fromOffset(18, 0)
ActiveTabTitle.Size = UDim2.new(0.5, 0, 1, 0)
ActiveTabTitle.Font = Enum.Font.GothamBold
ActiveTabTitle.TextSize = 14
ActiveTabTitle.TextColor3 = THEME.TextPrimary
ActiveTabTitle.TextXAlignment = Enum.TextXAlignment.Left
ActiveTabTitle.Text = "Combat"
ActiveTabTitle.Parent = HeaderBar

local MinBtn = Instance.new("TextButton")
MinBtn.AnchorPoint = Vector2.new(1, 0.5)
MinBtn.Position = UDim2.new(1, -14, 0.5, 0)
MinBtn.Size = UDim2.fromOffset(26, 26)
MinBtn.BackgroundColor3 = THEME.BgControl
MinBtn.Font = Enum.Font.GothamBold
MinBtn.TextSize = 13
MinBtn.TextColor3 = THEME.TextSecondary
MinBtn.Text = "—"
MinBtn.AutoButtonColor = false
MinBtn.Parent = HeaderBar
addCorner(MinBtn, 6)

local ContentHolder = Instance.new("Frame")
ContentHolder.Position = UDim2.fromOffset(168, 48)
ContentHolder.Size = UDim2.new(1, -168, 1, -48)
ContentHolder.BackgroundTransparency = 1
ContentHolder.ClipsDescendants = true
ContentHolder.Parent = MainWindow

-- Clean Dragging on Sidebar BrandBox & HeaderBar
do
    local dragging = false
    local dragStart = Vector2.new()
    local startPos = MainWindow.Position
    for _, handle in ipairs({ HeaderBar, BrandBox }) do
        Session.Bind(handle.InputBegan, function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = input.Position :: any
                startPos = MainWindow.Position
                closeActivePopup()
            end
        end)
    end
    Session.Bind(UserInputService.InputChanged, function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = (input.Position :: any) - dragStart
            MainWindow.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    Session.Bind(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

-- Tabs & Shared Control Widget Builders
type TabObj = { Left: ScrollingFrame, Right: ScrollingFrame, Page: Frame, Button: TextButton, Indicator: Frame, Title: string }
local Tabs: { TabObj } = {}
local CurrentTab: TabObj? = nil

local function selectTab(tab: TabObj)
    closeActivePopup()
    if CurrentTab == tab then
        return
    end
    for _, t in ipairs(Tabs) do
        local on = (t == tab)
        t.Page.Visible = on
        quickTween(t.Button, {
            BackgroundColor3 = on and THEME.BgControl or THEME.BgSidebar,
            BackgroundTransparency = on and 0.30 or 1,
            TextColor3 = on and THEME.TextPrimary or THEME.TextSecondary,
        })
        quickTween(t.Indicator, { Size = on and UDim2.fromOffset(3, 18) or UDim2.fromOffset(3, 0) })
    end
    CurrentTab = tab
    ActiveTabTitle.Text = tab.Title
    if type(UI.Preview.SyncVisibility) == "function" then
        UI.Preview.SyncVisibility()
    end
end

local function makeScrollColumn(parent: Instance, isRight: boolean): ScrollingFrame
    local sc = Instance.new("ScrollingFrame")
    sc.Position = isRight and UDim2.new(0.5, 5, 0, 12) or UDim2.fromOffset(12, 12)
    sc.Size = UDim2.new(0.5, -17, 1, -24)
    sc.BackgroundTransparency = 1
    sc.BorderSizePixel = 0
    sc.ScrollBarThickness = 3
    sc.ScrollBarImageColor3 = THEME.Border
    sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sc.CanvasSize = UDim2.fromScale(0, 0)
    sc.Parent = parent

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 10)
    layout.Parent = sc
    return sc
end

function UI.AddTab(title: string): TabObj
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = THEME.BgSidebar
    btn.BackgroundTransparency = 1
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 13
    btn.TextColor3 = THEME.TextSecondary
    btn.Text = "   " .. title
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.AutoButtonColor = false
    btn.Parent = TabButtonList
    addCorner(btn, 7)

    local ind = Instance.new("Frame")
    ind.AnchorPoint = Vector2.new(0, 0.5)
    ind.Position = UDim2.new(0, 4, 0.5, 0)
    ind.Size = UDim2.fromOffset(3, 0)
    ind.BackgroundColor3 = THEME.Accent
    ind.BorderSizePixel = 0
    ind.Parent = btn
    addCorner(ind, 2)

    local page = Instance.new("Frame")
    page.Size = UDim2.fromScale(1, 1)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.Parent = ContentHolder

    local tabObj: TabObj = {
        Title = title,
        Button = btn,
        Indicator = ind,
        Page = page,
        Left = makeScrollColumn(page, false),
        Right = makeScrollColumn(page, true),
    }

    Session.Bind(btn.MouseButton1Click, function()
        selectTab(tabObj)
    end)

    table.insert(Tabs, tabObj)
    if #Tabs == 1 then
        selectTab(tabObj)
    end
    return tabObj
end

function UI.ApplyGlassTheme()
    local g = math.clamp((Config.Settings.MenuTransparency or 22) / 100, 0, 0.55)
    local subAlpha = math.clamp(g + 0.06, 0, 0.72)
    local cardAlpha = math.clamp(g + 0.14, 0.08, 0.78)
    MainWindow.BackgroundTransparency = g
    Sidebar.BackgroundTransparency = subAlpha
    HeaderBar.BackgroundTransparency = subAlpha
    WatermarkFrame.BackgroundTransparency = math.clamp(g + 0.06, 0.10, 0.75)
    TargetHudFrame.BackgroundTransparency = math.clamp(g + 0.04, 0.10, 0.72)
    if World._BossHudFrame and (World._BossHudFrame :: Instance).Parent then
        (World._BossHudFrame :: Frame).BackgroundTransparency = math.clamp(g + 0.06, 0.10, 0.75)
    end
    if Misc._ReportsHud and (Misc._ReportsHud :: Instance).Parent then
        (Misc._ReportsHud :: Frame).BackgroundTransparency = math.clamp(g + 0.04, 0.12, 0.72)
    end
    for _, rec in ipairs(UI._GlassCards) do
        if rec.Frame.Parent then
            rec.Frame.BackgroundTransparency = cardAlpha
            rec.Stroke.Transparency = math.clamp(0.32 + g * 0.45, 0.18, 0.72)
        end
    end
    local pv = UI._GlassPreview
    if pv.Main and pv.Main.Parent then
        pv.Main.BackgroundTransparency = g
    end
    if pv.Header and pv.Header.Parent then
        pv.Header.BackgroundTransparency = subAlpha
    end
    if pv.Stage and pv.Stage.Parent then
        pv.Stage.BackgroundTransparency = math.clamp(g + 0.12, 0.12, 0.76)
    end
end

function UI.AddSection(tab: TabObj, colSide: "Left" | "Right", title: string): Frame
    local g = math.clamp((Config.Settings.MenuTransparency or 22) / 100, 0, 0.55)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -4, 0, 32)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = THEME.BgCard
    card.BackgroundTransparency = math.clamp(g + 0.14, 0.08, 0.78)
    card.Parent = (colSide == "Right") and tab.Right or tab.Left
    addCorner(card, 8)
    local cardStroke = addStroke(card, THEME.Border, 1, math.clamp(0.32 + g * 0.45, 0.18, 0.72))
    table.insert(UI._GlassCards, { Frame = card, Stroke = cardStroke })

    local hdr = Instance.new("TextLabel")
    hdr.Position = UDim2.fromOffset(12, 8)
    hdr.Size = UDim2.new(1, -24, 0, 18)
    hdr.BackgroundTransparency = 1
    hdr.Font = Enum.Font.GothamBold
    hdr.TextSize = 12
    hdr.TextColor3 = THEME.Accent
    hdr.TextXAlignment = Enum.TextXAlignment.Left
    hdr.Text = title:upper()
    hdr.Parent = card

    local body = Instance.new("Frame")
    body.Position = UDim2.fromOffset(10, 30)
    body.Size = UDim2.new(1, -20, 0, 0)
    body.AutomaticSize = Enum.AutomaticSize.Y
    body.BackgroundTransparency = 1
    body.Parent = card

    local pad = Instance.new("UIPadding")
    pad.PaddingBottom = UDim.new(0, 10)
    pad.Parent = body

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 7)
    layout.Parent = body
    return body
end

local BindPickers: { { Get: () -> BindValue, Set: (BindValue) -> (), Refresh: () -> () } } = {}
local ListeningPicker: any = nil

local function makeBindButton(parent: Instance, getFn: () -> BindValue, setFn: (BindValue) -> ()): TextButton
    local bindBtn = Instance.new("TextButton")
    bindBtn.Size = UDim2.fromOffset(52, 20)
    bindBtn.BackgroundColor3 = THEME.BgControl
    bindBtn.Font = Enum.Font.GothamMedium
    bindBtn.TextSize = 10
    bindBtn.TextColor3 = THEME.TextSecondary
    bindBtn.AutoButtonColor = false
    bindBtn.Parent = parent
    addCorner(bindBtn, 5)
    addStroke(bindBtn, THEME.Border, 1, 0.2)

    local entry: any = {
        Get = getFn,
        Set = setFn,
    }
    entry.Refresh = function()
        if ListeningPicker == entry then
            bindBtn.Text = "..."
            bindBtn.TextColor3 = THEME.Accent
        else
            bindBtn.Text = formatBindName(getFn())
            bindBtn.TextColor3 = THEME.TextSecondary
        end
    end
    entry.Refresh()

    Session.Bind(bindBtn.MouseButton1Click, function()
        ListeningPicker = entry
        entry.Refresh()
    end)

    table.insert(BindPickers, entry)
    table.insert(UI._Refreshers, entry.Refresh)
    return bindBtn
end

function UI.AddToggle(sec: Frame, label: string, getter: () -> boolean, setter: (boolean) -> (), bindGet: (() -> BindValue)?, bindSet: ((BindValue) -> ())?)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 24)
    row.BackgroundTransparency = 1
    row.Parent = sec

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, bindGet and -102 or -46, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextColor3 = THEME.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.Parent = row

    if bindGet and bindSet then
        local bb = makeBindButton(row, bindGet, bindSet)
        bb.AnchorPoint = Vector2.new(1, 0.5)
        bb.Position = UDim2.new(1, -44, 0.5, 0)
    end

    local track = Instance.new("TextButton")
    track.AnchorPoint = Vector2.new(1, 0.5)
    track.Position = UDim2.new(1, 0, 0.5, 0)
    track.Size = UDim2.fromOffset(38, 20)
    track.Text = ""
    track.AutoButtonColor = false
    track.Parent = row
    addCorner(track, 10)

    local knob = Instance.new("Frame")
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.Size = UDim2.fromOffset(14, 14)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.Parent = track
    addCorner(knob, 7)

    local function sync(instant: boolean?)
        local on = getter()
        local tCol = on and THEME.Accent or THEME.BgControl
        local kPos = on and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
        if instant then
            track.BackgroundColor3 = tCol
            knob.Position = kPos
        else
            quickTween(track, { BackgroundColor3 = tCol }, 0.14)
            quickTween(knob, { Position = kPos }, 0.14)
        end
    end
    sync(true)
    table.insert(UI._Refreshers, function()
        sync(true)
    end)

    Session.Bind(track.MouseButton1Click, function()
        setter(not getter())
        sync(false)
        UI.NotifyChange()
    end)
end

function UI.AddSlider(sec: Frame, label: string, minVal: number, maxVal: number, step: number, suffix: string, getter: () -> number, setter: (number) -> ())
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 34)
    holder.BackgroundTransparency = 1
    holder.Parent = sec

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.65, 0, 0, 16)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextColor3 = THEME.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.Parent = holder

    local valLbl = Instance.new("TextLabel")
    valLbl.AnchorPoint = Vector2.new(1, 0)
    valLbl.Position = UDim2.new(1, 0, 0, 0)
    valLbl.Size = UDim2.new(0.35, 0, 0, 16)
    valLbl.BackgroundTransparency = 1
    valLbl.Font = Enum.Font.GothamMedium
    valLbl.TextSize = 11
    valLbl.TextColor3 = THEME.Accent
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = holder

    local bar = Instance.new("TextButton")
    bar.Position = UDim2.fromOffset(0, 21)
    bar.Size = UDim2.new(1, 0, 0, 7)
    bar.BackgroundColor3 = THEME.BgControl
    bar.Text = ""
    bar.AutoButtonColor = false
    bar.Parent = holder
    addCorner(bar, 4)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.fromScale(0, 1)
    fill.BackgroundColor3 = THEME.Accent
    fill.BorderSizePixel = 0
    fill.Parent = bar
    addCorner(fill, 4)

    local function fmt(v: number): string
        if step < 1 then
            return string.format("%.2f%s", v, suffix)
        end
        return string.format("%.0f%s", v, suffix)
    end

    local function sync()
        local v = math.clamp(getter(), minVal, maxVal)
        local ratio = (v - minVal) / math.max(maxVal - minVal, 0.0001)
        fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
        valLbl.Text = fmt(v)
    end
    sync()
    table.insert(UI._Refreshers, sync)

    local sliding = false
    local function applyInputX(xPos: number)
        local w = math.max(bar.AbsoluteSize.X, 1)
        local ratio = math.clamp((xPos - bar.AbsolutePosition.X) / w, 0, 1)
        local raw = minVal + (maxVal - minVal) * ratio
        local snapped = math.floor(raw / step + 0.5) * step
        snapped = math.clamp(tonumber(string.format("%.4f", snapped)) or raw, minVal, maxVal)
        setter(snapped)
        sync()
        UI.NotifyChange()
    end

    Session.Bind(bar.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = true
            applyInputX(input.Position.X)
        end
    end)
    Session.Bind(UserInputService.InputChanged, function(input)
        if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then
            applyInputX(input.Position.X)
        end
    end)
    Session.Bind(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = false
        end
    end)
end

function UI.AddDropdown(sec: Frame, label: string, options: { string } | () -> { string }, getter: () -> string, setter: (string) -> ())
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 26)
    holder.BackgroundTransparency = 1
    holder.Parent = sec

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.48, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextColor3 = THEME.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.Parent = holder

    local btn = Instance.new("TextButton")
    btn.AnchorPoint = Vector2.new(1, 0.5)
    btn.Position = UDim2.new(1, 0, 0.5, 0)
    btn.Size = UDim2.new(0.5, 0, 0, 24)
    btn.BackgroundColor3 = THEME.BgControl
    btn.BackgroundTransparency = 0.14
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 11
    btn.TextColor3 = THEME.TextPrimary
    btn.TextTruncate = Enum.TextTruncate.AtEnd
    btn.AutoButtonColor = false
    btn.Parent = holder
    addCorner(btn, 6)
    addStroke(btn, THEME.Border, 1, 0.25)

    local function sync()
        btn.Text = getter() .. "  v"
    end
    sync()
    table.insert(UI._Refreshers, sync)

    Session.Bind(btn.MouseButton1Click, function()
        if ActivePopup then
            closeActivePopup()
            return
        end
        IgnoreNextPopupDismiss = true
        local optList: { string } = (type(options) == "function") and (options :: any)() or (options :: { string })
        local menuH = math.min(#optList * 26 + 8, 220)
        local layerSize = PopupLayer.AbsoluteSize
        local mx = math.min(btn.AbsolutePosition.X, math.max(8, layerSize.X - btn.AbsoluteSize.X - 8))
        local my = btn.AbsolutePosition.Y + btn.AbsoluteSize.Y + 4
        if layerSize.Y > 0 and my + menuH > layerSize.Y - 8 then
            my = math.max(8, btn.AbsolutePosition.Y - menuH - 4)
        end

        local menu = Instance.new("Frame")
        menu.Position = UDim2.fromOffset(mx, my)
        menu.Size = UDim2.fromOffset(btn.AbsoluteSize.X, menuH)
        menu.BackgroundColor3 = THEME.BgSidebar
        menu.BackgroundTransparency = 0.08
        menu.ZIndex = 65
        menu.Parent = PopupLayer
        addCorner(menu, 7)
        addStroke(menu, THEME.Accent, 1, 0.4)

        local list = Instance.new("UIListLayout")
        list.Padding = UDim.new(0, 2)
        list.Parent = menu
        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 4)
        pad.PaddingLeft = UDim.new(0, 4)
        pad.PaddingRight = UDim.new(0, 4)
        pad.Parent = menu

        for _, opt in ipairs(optList) do
            local ob = Instance.new("TextButton")
            ob.Size = UDim2.new(1, 0, 0, 24)
            ob.BackgroundColor3 = (opt == getter()) and THEME.BgHover or THEME.BgSidebar
            ob.BackgroundTransparency = (opt == getter()) and 0.15 or 0.35
            ob.Font = Enum.Font.GothamMedium
            ob.TextSize = 11
            ob.TextColor3 = (opt == getter()) and THEME.Accent or THEME.TextPrimary
            ob.Text = opt
            ob.AutoButtonColor = false
            ob.ZIndex = 66
            ob.Parent = menu
            addCorner(ob, 5)
            ob.MouseButton1Click:Connect(function()
                setter(opt)
                sync()
                closeActivePopup()
                UI.NotifyChange()
            end)
        end
        ActivePopup = menu
    end)
end

function UI.AddMultiDropdown(sec: Frame, label: string, options: { string }, getter: () -> { string }, setter: ({ string }) -> ())
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 26)
    holder.BackgroundTransparency = 1
    holder.Parent = sec

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.48, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextColor3 = THEME.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.Parent = holder

    local btn = Instance.new("TextButton")
    btn.AnchorPoint = Vector2.new(1, 0.5)
    btn.Position = UDim2.new(1, 0, 0.5, 0)
    btn.Size = UDim2.new(0.5, 0, 0, 24)
    btn.BackgroundColor3 = THEME.BgControl
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 11
    btn.TextColor3 = THEME.TextPrimary
    btn.TextTruncate = Enum.TextTruncate.AtEnd
    btn.AutoButtonColor = false
    btn.Parent = holder
    addCorner(btn, 6)
    addStroke(btn, THEME.Border, 1, 0.2)

    local function formatSelected(sel: { string }): string
        if #sel == 0 then
            return "None  v"
        elseif #sel == 1 then
            return sel[1] .. "  v"
        end
        return string.format("%s +%d  v", sel[1], #sel - 1)
    end

    local function sync()
        btn.Text = formatSelected(getter())
    end
    sync()
    table.insert(UI._Refreshers, sync)

    Session.Bind(btn.MouseButton1Click, function()
        if ActivePopup then
            closeActivePopup()
            return
        end
        IgnoreNextPopupDismiss = true
        local h = math.min(#options * 26 + 8, 224)
        local layerSize = PopupLayer.AbsoluteSize
        local x = math.min(btn.AbsolutePosition.X, math.max(8, layerSize.X - btn.AbsoluteSize.X - 8))
        local y = btn.AbsolutePosition.Y + btn.AbsoluteSize.Y + 4
        if layerSize.Y > 0 and y + h > layerSize.Y - 8 then
            y = math.max(8, btn.AbsolutePosition.Y - h - 4)
        end

        local menu = Instance.new("Frame")
        menu.Position = UDim2.fromOffset(x, y)
        menu.Size = UDim2.fromOffset(btn.AbsoluteSize.X, h)
        menu.BackgroundColor3 = THEME.BgSidebar
        menu.ZIndex = 65
        menu.Parent = PopupLayer
        addCorner(menu, 7)
        addStroke(menu, THEME.Accent, 1, 0.45)

        local list = Instance.new("UIListLayout")
        list.Padding = UDim.new(0, 2)
        list.Parent = menu
        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 4)
        pad.PaddingLeft = UDim.new(0, 4)
        pad.PaddingRight = UDim.new(0, 4)
        pad.Parent = menu

        local rows: { { Opt: string, Btn: TextButton, Check: TextLabel } } = {}
        local function refreshRows()
            local set: { [string]: boolean } = {}
            for _, v in ipairs(getter()) do
                set[v] = true
            end
            for _, rec in ipairs(rows) do
                local on = set[rec.Opt] == true
                rec.Btn.BackgroundColor3 = on and THEME.BgHover or THEME.BgSidebar
                rec.Btn.TextColor3 = on and THEME.Accent or THEME.TextPrimary
                rec.Check.Text = on and "x" or ""
                rec.Check.TextColor3 = THEME.Accent
            end
        end

        for _, opt in ipairs(options) do
            local ob = Instance.new("TextButton")
            ob.Size = UDim2.new(1, 0, 0, 24)
            ob.BackgroundColor3 = THEME.BgSidebar
            ob.Font = Enum.Font.GothamMedium
            ob.TextSize = 11
            ob.TextColor3 = THEME.TextPrimary
            ob.Text = "  " .. opt
            ob.TextXAlignment = Enum.TextXAlignment.Left
            ob.AutoButtonColor = false
            ob.ZIndex = 66
            ob.Parent = menu
            addCorner(ob, 5)

            local chk = Instance.new("TextLabel")
            chk.AnchorPoint = Vector2.new(1, 0.5)
            chk.Position = UDim2.new(1, -6, 0.5, 0)
            chk.Size = UDim2.fromOffset(14, 14)
            chk.BackgroundTransparency = 1
            chk.Font = Enum.Font.GothamBold
            chk.TextSize = 11
            chk.ZIndex = 67
            chk.Parent = ob

            table.insert(rows, { Opt = opt, Btn = ob, Check = chk })
            ob.MouseButton1Click:Connect(function()
                local set: { [string]: boolean } = {}
                local curCount = 0
                for _, v in ipairs(getter()) do
                    if not set[v] then
                        set[v] = true
                        curCount += 1
                    end
                end
                if set[opt] and curCount <= 1 then
                    return
                end
                set[opt] = not set[opt]
                local nextList: { string } = {}
                for _, candidate in ipairs(options) do
                    if set[candidate] then
                        table.insert(nextList, candidate)
                    end
                end
                setter(nextList)
                sync()
                refreshRows()
                UI.NotifyChange()
            end)
        end

        refreshRows()
        ActivePopup = menu
    end)
end

local function addPopupSlider(pop: Frame, label: string, minVal: number, maxVal: number, step: number, suffix: string, getter: () -> number, setter: (number) -> ()): () -> ()
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 32)
    holder.BackgroundTransparency = 1
    holder.ZIndex = 66
    holder.Parent = pop

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.65, 0, 0, 15)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.TextColor3 = THEME.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.ZIndex = 66
    lbl.Parent = holder

    local valLbl = Instance.new("TextLabel")
    valLbl.AnchorPoint = Vector2.new(1, 0)
    valLbl.Position = UDim2.new(1, 0, 0, 0)
    valLbl.Size = UDim2.new(0.35, 0, 0, 15)
    valLbl.BackgroundTransparency = 1
    valLbl.Font = Enum.Font.GothamMedium
    valLbl.TextSize = 11
    valLbl.TextColor3 = THEME.Accent
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.ZIndex = 66
    valLbl.Parent = holder

    local bar = Instance.new("TextButton")
    bar.Position = UDim2.fromOffset(0, 19)
    bar.Size = UDim2.new(1, 0, 0, 7)
    bar.BackgroundColor3 = THEME.BgControl
    bar.Text = ""
    bar.AutoButtonColor = false
    bar.ZIndex = 66
    bar.Parent = holder
    addCorner(bar, 4)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.fromScale(0, 1)
    fill.BackgroundColor3 = THEME.Accent
    fill.BorderSizePixel = 0
    fill.ZIndex = 67
    fill.Parent = bar
    addCorner(fill, 4)

    local function sync()
        local v = math.clamp(getter(), minVal, maxVal)
        local ratio = (v - minVal) / math.max(maxVal - minVal, 0.0001)
        fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
        if step < 1 then
            valLbl.Text = string.format("%.1f%s", v, suffix)
        else
            valLbl.Text = string.format("%.0f%s", v, suffix)
        end
    end
    sync()

    local sliding = false
    local function applyX(xPos: number)
        local w = math.max(bar.AbsoluteSize.X, 1)
        local ratio = math.clamp((xPos - bar.AbsolutePosition.X) / w, 0, 1)
        local raw = minVal + (maxVal - minVal) * ratio
        local snapped = math.floor(raw / step + 0.5) * step
        snapped = math.clamp(tonumber(string.format("%.4f", snapped)) or raw, minVal, maxVal)
        setter(snapped)
        sync()
        UI.NotifyChange()
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = true
            applyX(input.Position.X)
        end
    end)
    local cMove = UserInputService.InputChanged:Connect(function(input)
        if sliding and pop.Parent and input.UserInputType == Enum.UserInputType.MouseMovement then
            applyX(input.Position.X)
        end
    end)
    local cEnd = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = false
        end
    end)
    pop.Destroying:Connect(function()
        cMove:Disconnect()
        cEnd:Disconnect()
    end)
    return sync
end

local function addPopupToggle(pop: Frame, label: string, getter: () -> boolean, setter: (boolean) -> ())
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 22)
    row.BackgroundTransparency = 1
    row.ZIndex = 66
    row.Parent = pop

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -44, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.TextColor3 = THEME.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.ZIndex = 66
    lbl.Parent = row

    local track = Instance.new("TextButton")
    track.AnchorPoint = Vector2.new(1, 0.5)
    track.Position = UDim2.new(1, 0, 0.5, 0)
    track.Size = UDim2.fromOffset(36, 18)
    track.Text = ""
    track.AutoButtonColor = false
    track.ZIndex = 66
    track.Parent = row
    addCorner(track, 9)

    local knob = Instance.new("Frame")
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.Size = UDim2.fromOffset(12, 12)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.ZIndex = 67
    knob.Parent = track
    addCorner(knob, 6)

    local function sync(instant: boolean?)
        local on = getter()
        local tCol = on and THEME.Accent or THEME.BgControl
        local kPos = on and UDim2.new(1, -15, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
        if instant then
            track.BackgroundColor3 = tCol
            knob.Position = kPos
        else
            quickTween(track, { BackgroundColor3 = tCol }, 0.14)
            quickTween(knob, { Position = kPos }, 0.14)
        end
    end
    sync(true)

    track.MouseButton1Click:Connect(function()
        setter(not getter())
        sync(false)
        UI.NotifyChange()
    end)
end

function UI._AddPopupKeybind(pop: Frame, label: string, getter: () -> BindValue, setter: (BindValue) -> ())
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 22)
    row.BackgroundTransparency = 1
    row.ZIndex = 66
    row.Parent = pop

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -66, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.TextColor3 = THEME.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.ZIndex = 66
    lbl.Parent = row

    local bindBtn = Instance.new("TextButton")
    bindBtn.AnchorPoint = Vector2.new(1, 0.5)
    bindBtn.Position = UDim2.new(1, 0, 0.5, 0)
    bindBtn.Size = UDim2.fromOffset(60, 20)
    bindBtn.BackgroundColor3 = THEME.BgControl
    bindBtn.Font = Enum.Font.GothamMedium
    bindBtn.TextSize = 10
    bindBtn.TextColor3 = THEME.TextSecondary
    bindBtn.AutoButtonColor = false
    bindBtn.ZIndex = 66
    bindBtn.Parent = row
    addCorner(bindBtn, 5)
    addStroke(bindBtn, THEME.Border, 1, 0.2)

    local entry: any = { Get = getter, Set = setter }
    entry.Refresh = function()
        if not bindBtn.Parent then
            return
        end
        if ListeningPicker == entry then
            bindBtn.Text = "..."
            bindBtn.TextColor3 = THEME.Accent
        else
            bindBtn.Text = formatBindName(getter())
            bindBtn.TextColor3 = THEME.TextSecondary
        end
    end
    entry.Refresh()

    bindBtn.MouseButton1Click:Connect(function()
        ListeningPicker = entry
        entry.Refresh()
    end)
    pop.Destroying:Connect(function()
        if ListeningPicker == entry then
            ListeningPicker = nil
        end
    end)
end

function UI._AddPopupCycle(pop: Frame, label: string, options: { string }, getter: () -> string, setter: (string) -> ())
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 22)
    row.BackgroundTransparency = 1
    row.ZIndex = 66
    row.Parent = pop

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -82, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.TextColor3 = THEME.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.ZIndex = 66
    lbl.Parent = row

    local cycBtn = Instance.new("TextButton")
    cycBtn.AnchorPoint = Vector2.new(1, 0.5)
    cycBtn.Position = UDim2.new(1, 0, 0.5, 0)
    cycBtn.Size = UDim2.fromOffset(76, 20)
    cycBtn.BackgroundColor3 = THEME.BgControl
    cycBtn.Font = Enum.Font.GothamMedium
    cycBtn.TextSize = 10
    cycBtn.TextColor3 = THEME.Accent
    cycBtn.AutoButtonColor = false
    cycBtn.ZIndex = 66
    cycBtn.Parent = row
    addCorner(cycBtn, 5)
    addStroke(cycBtn, THEME.Border, 1, 0.2)

    local function sync()
        cycBtn.Text = getter() .. " >"
    end
    sync()

    cycBtn.MouseButton1Click:Connect(function()
        local cur = getter()
        local idx = table.find(options, cur) or 1
        local nextOpt = options[(idx % #options) + 1] or options[1]
        setter(nextOpt)
        sync()
        UI.NotifyChange()
    end)
end

function UI.AddColorPicker(sec: Frame, label: string, getter: () -> Color3, setter: (Color3) -> ())
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 24)
    row.BackgroundTransparency = 1
    row.Parent = sec

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -46, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextColor3 = THEME.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.Parent = row

    local swatch = Instance.new("TextButton")
    swatch.AnchorPoint = Vector2.new(1, 0.5)
    swatch.Position = UDim2.new(1, 0, 0.5, 0)
    swatch.Size = UDim2.fromOffset(32, 18)
    swatch.BackgroundColor3 = getter()
    swatch.Text = ""
    swatch.AutoButtonColor = false
    swatch.Parent = row
    addCorner(swatch, 5)
    addStroke(swatch, THEME.Border, 1, 0)

    local PRESETS = {
        Color3.fromRGB(56, 189, 248),
        Color3.fromRGB(255, 64, 64),
        Color3.fromRGB(34, 197, 94),
        Color3.fromRGB(245, 158, 11),
        Color3.fromRGB(168, 85, 247),
        Color3.fromRGB(250, 204, 21),
        Color3.fromRGB(255, 138, 42),
        Color3.fromRGB(45, 212, 191),
        Color3.fromRGB(244, 63, 94),
        Color3.fromRGB(255, 255, 255),
        Color3.fromRGB(132, 204, 22),
        Color3.fromRGB(236, 72, 153),
    }

    table.insert(UI._Refreshers, function()
        swatch.BackgroundColor3 = getter()
    end)

    Session.Bind(swatch.MouseButton1Click, function()
        if ActivePopup then
            closeActivePopup()
            return
        end
        IgnoreNextPopupDismiss = true
        local popW, popH = 186, 180
        local layerSize = PopupLayer.AbsoluteSize
        local px = math.clamp(swatch.AbsolutePosition.X - popW + 32, 8, math.max(8, layerSize.X - popW - 8))
        local py = swatch.AbsolutePosition.Y + 24
        if layerSize.Y > 0 and py + popH > layerSize.Y - 8 then
            py = math.max(8, swatch.AbsolutePosition.Y - popH - 4)
        end

        local pop = Instance.new("Frame")
        pop.Position = UDim2.fromOffset(px, py)
        pop.Size = UDim2.fromOffset(popW, popH)
        pop.BackgroundColor3 = THEME.BgSidebar
        pop.ZIndex = 65
        pop.Parent = PopupLayer
        addCorner(pop, 8)
        addStroke(pop, THEME.Accent, 1, 0.45)

        local presetsGrid = Instance.new("Frame")
        presetsGrid.Position = UDim2.fromOffset(10, 8)
        presetsGrid.Size = UDim2.fromOffset(popW - 20, 48)
        presetsGrid.BackgroundTransparency = 1
        presetsGrid.ZIndex = 66
        presetsGrid.Parent = pop

        local grid = Instance.new("UIGridLayout")
        grid.CellSize = UDim2.fromOffset(22, 20)
        grid.CellPadding = UDim2.fromOffset(6, 5)
        grid.Parent = presetsGrid

        local slidersBox = Instance.new("Frame")
        slidersBox.Position = UDim2.fromOffset(10, 62)
        slidersBox.Size = UDim2.fromOffset(popW - 20, popH - 70)
        slidersBox.BackgroundTransparency = 1
        slidersBox.ZIndex = 66
        slidersBox.Parent = pop
        local sList = Instance.new("UIListLayout")
        sList.Padding = UDim.new(0, 6)
        sList.Parent = slidersBox

        local curH, curS, curV = getter():ToHSV()
        local syncSliders: { () -> () } = {}
        local function applyHSV()
            local nextCol = Color3.fromHSV(curH, curS, curV)
            setter(nextCol)
            swatch.BackgroundColor3 = nextCol
        end

        table.insert(syncSliders, addPopupSlider(pop, "Hue", 0, 360, 1, "°", function()
            return math.floor(curH * 360 + 0.5)
        end, function(deg)
            curH = math.clamp(deg / 360, 0, 1)
            applyHSV()
        end))
        table.insert(syncSliders, addPopupSlider(pop, "Saturation", 0, 100, 1, "%", function()
            return math.floor(curS * 100 + 0.5)
        end, function(pct)
            curS = math.clamp(pct / 100, 0, 1)
            applyHSV()
        end))
        table.insert(syncSliders, addPopupSlider(pop, "Brightness", 10, 100, 1, "%", function()
            return math.floor(curV * 100 + 0.5)
        end, function(pct)
            curV = math.clamp(pct / 100, 0.1, 1)
            applyHSV()
        end))

        -- Reparent slider holders cleanly inside slidersBox while pop.Destroying still cleans up drag listeners
        for _, child in ipairs(pop:GetChildren()) do
            if child ~= presetsGrid and child ~= slidersBox and child:IsA("Frame") then
                child.Parent = slidersBox
            end
        end

        for _, col in ipairs(PRESETS) do
            local b = Instance.new("TextButton")
            b.BackgroundColor3 = col
            b.Text = ""
            b.AutoButtonColor = false
            b.ZIndex = 66
            b.Parent = presetsGrid
            addCorner(b, 5)
            addStroke(b, THEME.Border, 1, 0.35)
            b.MouseButton1Click:Connect(function()
                curH, curS, curV = col:ToHSV()
                setter(col)
                swatch.BackgroundColor3 = col
                for _, fn in ipairs(syncSliders) do
                    fn()
                end
                UI.NotifyChange()
            end)
        end

        ActivePopup = pop
    end)
end

function UI.AddKeybindRow(sec: Frame, label: string, getFn: () -> BindValue, setFn: (BindValue) -> ())
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 24)
    row.BackgroundTransparency = 1
    row.Parent = sec

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -66, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextColor3 = THEME.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.Parent = row

    local bb = makeBindButton(row, getFn, setFn)
    bb.AnchorPoint = Vector2.new(1, 0.5)
    bb.Position = UDim2.new(1, 0, 0.5, 0)
end

function UI.AddTextBox(sec: Frame, label: string, placeholder: string, getter: () -> string, setter: (string) -> ())
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 26)
    row.BackgroundTransparency = 1
    row.Parent = sec

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.48, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextColor3 = THEME.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.Parent = row

    local box = Instance.new("TextBox")
    box.AnchorPoint = Vector2.new(1, 0.5)
    box.Position = UDim2.new(1, 0, 0.5, 0)
    box.Size = UDim2.new(0.5, 0, 0, 24)
    box.BackgroundColor3 = THEME.BgControl
    box.BackgroundTransparency = 0.14
    box.Font = Enum.Font.GothamMedium
    box.TextSize = 11
    box.TextColor3 = THEME.TextPrimary
    box.PlaceholderColor3 = THEME.TextMuted
    box.PlaceholderText = placeholder
    box.ClearTextOnFocus = false
    box.Text = getter()
    box.Parent = row
    addCorner(box, 6)
    local stroke = addStroke(box, THEME.Border, 1, 0.25)

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 6)
    pad.PaddingRight = UDim.new(0, 6)
    pad.Parent = box

    local function sync()
        if not box:IsFocused() then
            box.Text = getter()
        end
    end
    table.insert(UI._Refreshers, sync)

    Session.Bind(box.Focused, function()
        quickTween(stroke, { Color = THEME.Accent, Transparency = 0.15 }, 0.12)
    end)
    Session.Bind(box.FocusLost, function()
        quickTween(stroke, { Color = THEME.Border, Transparency = 0.25 }, 0.12)
        setter(box.Text)
        sync()
        UI.NotifyChange()
    end)
    Session.Bind(box:GetPropertyChangedSignal("Text"), function()
        if box:IsFocused() then
            setter(box.Text)
        end
    end)
end

function UI.AddButton(sec: Frame, label: string, style: ("normal" | "danger" | "accent")?, onClick: () -> ())
    local bg = style == "danger" and Color3.fromRGB(70, 22, 29)
        or (style == "accent" and Color3.fromRGB(16, 44, 64) or THEME.BgControl)
    local fg = style == "danger" and Color3.fromRGB(252, 165, 165)
        or (style == "accent" and THEME.Accent or THEME.TextPrimary)
    local strokeCol = style == "danger" and THEME.Danger or (style == "accent" and THEME.Accent or THEME.Border)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 28)
    btn.BackgroundColor3 = bg
    btn.BackgroundTransparency = 0.14
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.TextColor3 = fg
    btn.Text = label
    btn.AutoButtonColor = false
    btn.Parent = sec
    addCorner(btn, 6)
    local stroke = addStroke(btn, strokeCol, 1, 0.35)

    Session.Bind(btn.MouseEnter, function()
        quickTween(btn, { BackgroundTransparency = 0.02 }, 0.12)
        quickTween(stroke, { Transparency = 0.12 }, 0.12)
    end)
    Session.Bind(btn.MouseLeave, function()
        quickTween(btn, { BackgroundTransparency = 0.14 }, 0.12)
        quickTween(stroke, { Transparency = 0.35 }, 0.12)
    end)
    Session.Bind(btn.MouseButton1Click, onClick)
end

-- Crisp sliders icon built cleanly with frames (avoids external image asset failure)
local function buildSlidersGlyph(parent: Instance): { Frame }
    local bars: { Frame } = {}
    local offsets = { { y = 4, kx = 5 }, { y = 9, kx = 12 }, { y = 14, kx = 7 } }
    for _, cfg in ipairs(offsets) do
        local line = Instance.new("Frame")
        line.Position = UDim2.fromOffset(3, cfg.y)
        line.Size = UDim2.new(1, -6, 0, 2)
        line.BackgroundColor3 = THEME.TextSecondary
        line.BorderSizePixel = 0
        line.Parent = parent
        addCorner(line, 1)
        table.insert(bars, line)

        local dot = Instance.new("Frame")
        dot.AnchorPoint = Vector2.new(0.5, 0.5)
        dot.Position = UDim2.fromOffset(cfg.kx, cfg.y + 1)
        dot.Size = UDim2.fromOffset(4, 5)
        dot.BackgroundColor3 = THEME.TextSecondary
        dot.BorderSizePixel = 0
        dot.Parent = parent
        addCorner(dot, 2)
        table.insert(bars, dot)
    end
    return bars
end

function UI.AddEspCategoryRow(sec: Frame, label: string, getter: () -> boolean, setter: (boolean) -> (), onFilterClick: () -> (), isSelected: () -> boolean, showDivider: boolean?)
    local wrap = Instance.new("Frame")
    wrap.Size = UDim2.new(1, 0, 0, showDivider ~= false and 31 or 27)
    wrap.BackgroundTransparency = 1
    wrap.Parent = sec

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -76, 0, 24)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextColor3 = THEME.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.Parent = wrap

    local gearBtn = Instance.new("TextButton")
    gearBtn.AnchorPoint = Vector2.new(1, 0)
    gearBtn.Position = UDim2.new(1, -44, 0, 2)
    gearBtn.Size = UDim2.fromOffset(22, 20)
    gearBtn.BackgroundColor3 = THEME.BgControl
    gearBtn.BackgroundTransparency = 1
    gearBtn.Text = ""
    gearBtn.AutoButtonColor = false
    gearBtn.Parent = wrap
    addCorner(gearBtn, 5)
    local glyphParts = buildSlidersGlyph(gearBtn)

    local track = Instance.new("TextButton")
    track.AnchorPoint = Vector2.new(1, 0)
    track.Position = UDim2.new(1, 0, 0, 2)
    track.Size = UDim2.fromOffset(38, 20)
    track.Text = ""
    track.AutoButtonColor = false
    track.Parent = wrap
    addCorner(track, 10)

    local knob = Instance.new("Frame")
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.Size = UDim2.fromOffset(14, 14)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.Parent = track
    addCorner(knob, 7)

    if showDivider ~= false then
        local div = Instance.new("Frame")
        div.Position = UDim2.new(0, 0, 1, -1)
        div.Size = UDim2.new(1, 0, 0, 1)
        div.BackgroundColor3 = THEME.Border
        div.BackgroundTransparency = 0.45
        div.BorderSizePixel = 0
        div.Parent = wrap
    end

    local function sync(instant: boolean?)
        local on = getter()
        local tCol = on and THEME.Accent or THEME.BgControl
        local kPos = on and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
        if instant then
            track.BackgroundColor3 = tCol
            knob.Position = kPos
        else
            quickTween(track, { BackgroundColor3 = tCol }, 0.14)
            quickTween(knob, { Position = kPos }, 0.14)
        end
        local sel = isSelected()
        gearBtn.BackgroundTransparency = sel and 0.25 or 1
        local gCol = sel and THEME.Accent or THEME.TextSecondary
        for _, p in ipairs(glyphParts) do
            p.BackgroundColor3 = gCol
        end
    end
    sync(true)
    table.insert(UI._Refreshers, function()
        sync(true)
    end)

    Session.Bind(track.MouseButton1Click, function()
        setter(not getter())
        sync(false)
        UI.NotifyChange()
    end)
    Session.Bind(gearBtn.MouseButton1Click, function()
        onFilterClick()
        UI.RefreshAll()
    end)
end

function UI._AddPopupColorPicker(pop: Frame, label: string, getter: () -> Color3, setter: (Color3) -> ())
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 22)
    row.BackgroundTransparency = 1
    row.ZIndex = 66
    row.Parent = pop

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -44, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 11
    lbl.TextColor3 = THEME.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.ZIndex = 66
    lbl.Parent = row

    local swatch = Instance.new("TextButton")
    swatch.AnchorPoint = Vector2.new(1, 0.5)
    swatch.Position = UDim2.new(1, 0, 0.5, 0)
    swatch.Size = UDim2.fromOffset(30, 16)
    swatch.BackgroundColor3 = getter()
    swatch.Text = ""
    swatch.AutoButtonColor = false
    swatch.ZIndex = 66
    swatch.Parent = row
    addCorner(swatch, 4)
    addStroke(swatch, THEME.Border, 1, 0.15)

    local palette = Instance.new("Frame")
    palette.Size = UDim2.new(1, 0, 0, 20)
    palette.BackgroundTransparency = 1
    palette.Visible = false
    palette.ZIndex = 66
    palette.Parent = pop

    local pLayout = Instance.new("UIListLayout")
    pLayout.FillDirection = Enum.FillDirection.Horizontal
    pLayout.Padding = UDim.new(0, 4)
    pLayout.Parent = palette

    local POP_COLORS = {
        Color3.fromRGB(56, 189, 248),
        Color3.fromRGB(52, 211, 153),
        Color3.fromRGB(68, 128, 72),
        Color3.fromRGB(250, 204, 21),
        Color3.fromRGB(251, 146, 60),
        Color3.fromRGB(239, 68, 68),
        Color3.fromRGB(168, 85, 247),
        Color3.fromRGB(241, 245, 249),
        Color3.fromRGB(22, 28, 42),
    }

    local open = false
    local function togglePalette(forceOpen: boolean?)
        local nextOpen = (forceOpen ~= nil) and forceOpen or (not open)
        if nextOpen == open then return end
        open = nextOpen
        palette.Visible = open
        if pop.AutomaticSize == Enum.AutomaticSize.None then
            local delta = open and 26 or -26
            pop.Size = UDim2.fromOffset(pop.Size.X.Offset, math.max(50, pop.Size.Y.Offset + delta))
        end
    end

    for _, c in ipairs(POP_COLORS) do
        local sb = Instance.new("TextButton")
        sb.Size = UDim2.fromOffset(18, 18)
        sb.BackgroundColor3 = c
        sb.Text = ""
        sb.AutoButtonColor = false
        sb.ZIndex = 67
        sb.Parent = palette
        addCorner(sb, 4)
        addStroke(sb, THEME.Border, 1, 0.35)
        sb.MouseButton1Click:Connect(function()
            setter(c)
            swatch.BackgroundColor3 = c
            UI.NotifyChange()
        end)
    end

    swatch.MouseButton1Click:Connect(function()
        swatch.BackgroundColor3 = getter()
        togglePalette()
    end)
end

local function spawnSectionPopover(anchorBtn: GuiObject, popHeight: number?, buildPopover: (pop: Frame, anchorBtn: GuiObject) -> ())
    if ActivePopup then
        closeActivePopup()
        return
    end
    IgnoreNextPopupDismiss = true
    local pop = Instance.new("Frame")
    if popHeight then
        pop.Size = UDim2.fromOffset(224, popHeight)
    else
        pop.Size = UDim2.fromOffset(224, 0)
        pop.AutomaticSize = Enum.AutomaticSize.Y
    end
    pop.BackgroundColor3 = THEME.BgSidebar
    pop.BackgroundTransparency = 0.08
    pop.ZIndex = 65
    pop.Parent = PopupLayer
    addCorner(pop, 8)
    addStroke(pop, THEME.Accent, 1, 0.4)

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 8)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 10)
    pad.Parent = pop

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.Parent = pop

    buildPopover(pop, anchorBtn)

    local layerSize = PopupLayer.AbsoluteSize
    local pw = pop.Size.X.Offset
    local ph = (popHeight and popHeight > 0) and popHeight or math.max(pop.AbsoluteSize.Y, 120)
    local px = math.clamp(anchorBtn.AbsolutePosition.X + anchorBtn.AbsoluteSize.X - pw, 8, math.max(8, layerSize.X - pw - 8))
    local py = anchorBtn.AbsolutePosition.Y + anchorBtn.AbsoluteSize.Y + 4
    if layerSize.Y > 0 and py + ph > layerSize.Y - 8 then
        py = math.max(8, anchorBtn.AbsolutePosition.Y - ph - 4)
    end
    pop.Position = UDim2.fromOffset(px, py)
    ActivePopup = pop
end

function UI.AddSubmenuRow(sec: Frame, label: string, buildPopover: (pop: Frame, anchorBtn: GuiObject) -> (), popHeight: number?)
    local rowBtn = Instance.new("TextButton")
    rowBtn.Size = UDim2.new(1, 0, 0, 24)
    rowBtn.BackgroundColor3 = THEME.BgControl
    rowBtn.BackgroundTransparency = 1
    rowBtn.Text = ""
    rowBtn.AutoButtonColor = false
    rowBtn.Parent = sec
    addCorner(rowBtn, 5)

    local lbl = Instance.new("TextLabel")
    lbl.Position = UDim2.fromOffset(2, 0)
    lbl.Size = UDim2.new(1, -24, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextColor3 = THEME.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.Parent = rowBtn

    local arrow = Instance.new("TextLabel")
    arrow.AnchorPoint = Vector2.new(1, 0.5)
    arrow.Position = UDim2.new(1, -4, 0.5, 0)
    arrow.Size = UDim2.fromOffset(14, 14)
    arrow.BackgroundTransparency = 1
    arrow.Font = Enum.Font.GothamBold
    arrow.TextSize = 11
    arrow.TextColor3 = THEME.TextSecondary
    arrow.Text = ">"
    arrow.Parent = rowBtn

    Session.Bind(rowBtn.MouseEnter, function()
        quickTween(rowBtn, { BackgroundTransparency = 0.45 }, 0.12)
        arrow.TextColor3 = THEME.Accent
    end)
    Session.Bind(rowBtn.MouseLeave, function()
        quickTween(rowBtn, { BackgroundTransparency = 1 }, 0.12)
        arrow.TextColor3 = THEME.TextSecondary
    end)
    Session.Bind(rowBtn.MouseButton1Click, function()
        spawnSectionPopover(rowBtn, popHeight, buildPopover)
    end)
end

function UI.AddToggleWithConfig(
    sec: Frame,
    label: string,
    getter: () -> boolean,
    setter: (boolean) -> (),
    buildPopover: (pop: Frame, anchorBtn: GuiObject) -> (),
    popHeight: number?,
    warnBadge: boolean?
)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 24)
    row.BackgroundTransparency = 1
    row.Parent = sec

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, warnBadge and -96 or -76, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextColor3 = THEME.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.Parent = row

    if warnBadge then
        local wb = Instance.new("TextLabel")
        wb.AnchorPoint = Vector2.new(1, 0.5)
        wb.Position = UDim2.new(1, -70, 0.5, 0)
        wb.Size = UDim2.fromOffset(16, 16)
        wb.BackgroundColor3 = Color3.fromRGB(60, 42, 12)
        wb.BackgroundTransparency = 0.15
        wb.Font = Enum.Font.GothamBold
        wb.TextSize = 10
        wb.TextColor3 = Color3.fromRGB(245, 158, 11)
        wb.Text = "!"
        wb.Parent = row
        addCorner(wb, 4)
        addStroke(wb, Color3.fromRGB(245, 158, 11), 1, 0.25)
    end

    local gearBtn = Instance.new("TextButton")
    gearBtn.AnchorPoint = Vector2.new(1, 0.5)
    gearBtn.Position = UDim2.new(1, -44, 0.5, 0)
    gearBtn.Size = UDim2.fromOffset(22, 20)
    gearBtn.BackgroundColor3 = THEME.BgControl
    gearBtn.BackgroundTransparency = 1
    gearBtn.Text = ""
    gearBtn.AutoButtonColor = false
    gearBtn.Parent = row
    addCorner(gearBtn, 5)
    local glyphParts = buildSlidersGlyph(gearBtn)

    local track = Instance.new("TextButton")
    track.AnchorPoint = Vector2.new(1, 0.5)
    track.Position = UDim2.new(1, 0, 0.5, 0)
    track.Size = UDim2.fromOffset(38, 20)
    track.Text = ""
    track.AutoButtonColor = false
    track.Parent = row
    addCorner(track, 10)

    local knob = Instance.new("Frame")
    knob.AnchorPoint = Vector2.new(0, 0.5)
    knob.Size = UDim2.fromOffset(14, 14)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.Parent = track
    addCorner(knob, 7)

    local function sync(instant: boolean?)
        local on = getter()
        local tCol = on and THEME.Accent or THEME.BgControl
        local kPos = on and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
        if instant then
            track.BackgroundColor3 = tCol
            knob.Position = kPos
        else
            quickTween(track, { BackgroundColor3 = tCol }, 0.14)
            quickTween(knob, { Position = kPos }, 0.14)
        end
        for _, p in ipairs(glyphParts) do
            p.BackgroundColor3 = THEME.TextSecondary
        end
    end
    sync(true)
    table.insert(UI._Refreshers, function()
        sync(true)
    end)

    Session.Bind(track.MouseButton1Click, function()
        setter(not getter())
        sync(false)
        UI.NotifyChange()
    end)

    Session.Bind(gearBtn.MouseButton1Click, function()
        spawnSectionPopover(gearBtn, popHeight, buildPopover)
    end)
end

-- ============================================================================
-- 10. POPULATE TABS (COMBAT, VISUALS, WORLD, MISC, SETTINGS)
-- ============================================================================
local CombatTab = UI.AddTab("Combat")
local VisualsTab = UI.AddTab("Visuals")
UI._TabWorld = UI.AddTab("World")
local MiscTab = UI.AddTab("Misc")
local SettingsTab = UI.AddTab("Settings")

-- ---- COMBAT TAB ----
do
    local secAim = UI.AddSection(CombatTab, "Left", "Aimbot")
    UI.AddToggle(secAim, "Enable Aimbot", function() return Config.Aimbot.Enabled end, function(v) Config.Aimbot.Enabled = v end,
        function() return Config.Aimbot.Key end, function(k) Config.Aimbot.Key = k end)
    UI.AddDropdown(secAim, "Activation Mode", { "Hold", "Toggle", "Always" }, function() return Config.Aimbot.Mode end, function(v) Config.Aimbot.Mode = v end)
    UI.AddDropdown(secAim, "Aim Method", { "Camera", "Mouse" }, function() return Config.Aimbot.Method end, function(v) Config.Aimbot.Method = v end)
    UI.AddDropdown(secAim, "Target Priority", { "Crosshair", "Closest Dist", "Lowest HP" }, function() return Config.Aimbot.Priority or "Crosshair" end, function(v) Config.Aimbot.Priority = v end)
    UI.AddDropdown(secAim, "Target Hitbox", { "Head", "FaceHitBox", "HeadTopHitBox", "UpperTorso", "HumanoidRootPart", "Closest" },
        function() return Config.Aimbot.HitPart end, function(v) Config.Aimbot.HitPart = v end)
    UI.AddSlider(secAim, "Smoothness", 0, 95, 1, "%", function() return Config.Aimbot.Smoothness end, function(v) Config.Aimbot.Smoothness = v end)
    UI.AddSlider(secAim, "Mouse Gain", 0.2, 3.0, 0.1, "x", function() return Config.Aimbot.MouseSens end, function(v) Config.Aimbot.MouseSens = v end)
    UI.AddSlider(secAim, "Max Distance", 100, 1500, 25, "m", function() return Config.Aimbot.MaxDistance end, function(v) Config.Aimbot.MaxDistance = v end)
    UI.AddToggle(secAim, "Only When ADS", function() return Config.Aimbot.OnlyADS == true end, function(v) Config.Aimbot.OnlyADS = v end)
    UI.AddToggle(secAim, "Sticky Target", function() return Config.Aimbot.StickyTarget ~= false end, function(v) Config.Aimbot.StickyTarget = v end)
    UI.AddToggle(secAim, "Team / Clan Check", function() return Config.Aimbot.TeamCheck end, function(v) Config.Aimbot.TeamCheck = v end)
    UI.AddToggle(secAim, "Visible Check", function() return Config.Aimbot.VisibleCheck end, function(v) Config.Aimbot.VisibleCheck = v end)
    UI.AddToggle(secAim, "Lock Behind Walls", function() return Config.Aimbot.LockBehindWalls == true end, function(v) Config.Aimbot.LockBehindWalls = v end)
    UI.AddToggle(secAim, "Visible Fallback", function() return Config.Aimbot.VisibleFallback ~= false end, function(v) Config.Aimbot.VisibleFallback = v end)
    UI.AddToggle(secAim, "Multi-Point Scan", function() return Config.Aimbot.MultiPoint ~= false end, function(v) Config.Aimbot.MultiPoint = v end)
    UI.AddToggle(secAim, "Ignore Downed", function() return Config.Aimbot.IgnoreDowned end, function(v) Config.Aimbot.IgnoreDowned = v end)
    UI.AddToggle(secAim, "Target AI / Bots", function() return Config.Aimbot.TargetAI end, function(v) Config.Aimbot.TargetAI = v end)
    UI.AddToggle(secAim, "Lead Prediction", function() return Config.Aimbot.Prediction end, function(v) Config.Aimbot.Prediction = v end)
    UI.AddToggle(secAim, "Bullet Drop Comp", function() return Config.Aimbot.DropComp end, function(v) Config.Aimbot.DropComp = v end)
    UI.AddKeybindRow(secAim, "Add Not Attack", function() return Config.Targeting.AddFriendKey end, function(k)
        Config.Targeting.AddFriendKey = k
        UI.RefreshAll()
    end)

    local secFov = UI.AddSection(CombatTab, "Left", "FOV Circle")
    UI.AddToggle(secFov, "Show FOV Circle", function() return Config.Aimbot.ShowFOV end, function(v) Config.Aimbot.ShowFOV = v end)
    UI.AddSlider(secFov, "FOV Radius", 25, 500, 5, "px", function() return Config.Aimbot.FOVRadius end, function(v)
        Config.Aimbot.FOVRadius = v
    end)
    UI.AddToggle(secFov, "Scale With Zoom", function() return Config.Aimbot.FOVDynamic end, function(v)
        Config.Aimbot.FOVDynamic = v
    end)
    UI.AddToggle(secFov, "Filled Circle", function() return Config.Aimbot.FOVFilled end, function(v) Config.Aimbot.FOVFilled = v end)
    UI.AddColorPicker(secFov, "FOV Color", function() return Config.Aimbot.FOVColor end, function(c) Config.Aimbot.FOVColor = c end)

    local secSilent = UI.AddSection(CombatTab, "Right", "Silent Aim")
    UI.AddToggle(secSilent, "Enable Silent Aim", function() return Config.SilentAim.Enabled end, function(v)
        Config.SilentAim.Enabled = v
        if v then
            ToggleStates.SilentAim = true
        end
    end, function() return Config.SilentAim.Key end, function(k) Config.SilentAim.Key = k end)
    UI.AddDropdown(secSilent, "Silent Mode", { "Always", "Hold", "Toggle" }, function() return Config.SilentAim.Mode end, function(v)
        Config.SilentAim.Mode = v
        if v == "Toggle" then
            ToggleStates.SilentAim = true
        end
    end)
    UI.AddDropdown(secSilent, "Target Priority", { "Crosshair", "Closest Dist", "Lowest HP" }, function() return Config.SilentAim.Priority end, function(v)
        Config.SilentAim.Priority = v
    end)
    UI.AddDropdown(secSilent, "Target Hitbox", { "Head", "FaceHitBox", "HeadTopHitBox", "UpperTorso", "HumanoidRootPart", "Closest" },
        function() return Config.SilentAim.HitPart end, function(v)
            Config.SilentAim.HitPart = v
            if v == "Closest" then
                Config.Targeting.AimPoint = "Closest"
            else
                Config.Targeting.AimParts = { v }
                if Config.Targeting.AimPoint == "Closest" then
                    Config.Targeting.AimPoint = "Selected"
                end
            end
            UI.RefreshAll()
        end)
    UI.AddSlider(secSilent, "Hit Chance", 10, 100, 5, "%", function() return Config.SilentAim.HitChance end, function(v) Config.SilentAim.HitChance = v end)
    UI.AddToggle(secSilent, "Use FOV Circle", function() return Config.SilentAim.UseFOV end, function(v) Config.SilentAim.UseFOV = v end)
    UI.AddToggle(secSilent, "Team / Clan Check", function() return Config.SilentAim.TeamCheck end, function(v) Config.SilentAim.TeamCheck = v end)
    UI.AddToggle(secSilent, "Ignore Downed", function() return Config.SilentAim.IgnoreDowned end, function(v) Config.SilentAim.IgnoreDowned = v end)
    UI.AddToggle(secSilent, "Wall Check", function() return Config.SilentAim.VisibleCheck end, function(v) Config.SilentAim.VisibleCheck = v end)
    UI.AddToggle(secSilent, "Multi-Point Scan", function() return Config.SilentAim.MultiPoint end, function(v) Config.SilentAim.MultiPoint = v end)
    UI.AddToggle(secSilent, "Target AI / Bots", function() return Config.Targeting.TargetAI end, function(v)
        Config.Targeting.TargetAI = v
        Config.SilentAim.TargetAI = v
        UI.RefreshAll()
    end)
    UI.AddToggle(secSilent, "Ballistic Prediction", function() return Config.SilentAim.Prediction end, function(v) Config.SilentAim.Prediction = v end)
    UI.AddToggle(secSilent, "Bullet Drop Comp", function() return Config.SilentAim.DropComp end, function(v) Config.SilentAim.DropComp = v end)
    UI.AddToggle(secSilent, "Show Target Line", function() return Config.SilentAim.TargetLine end, function(v) Config.SilentAim.TargetLine = v end)
    UI.AddKeybindRow(secSilent, "Add Not Attack", function() return Config.Targeting.AddFriendKey end, function(k)
        Config.Targeting.AddFriendKey = k
        UI.RefreshAll()
    end)

    local secTargeting = UI.AddSection(CombatTab, "Right", "Targeting")
    UI.AddSlider(secTargeting, "FOV", 25, 500, 5, "", function() return Config.Targeting.FOV end, function(v)
        Config.Targeting.FOV = v
    end)
    UI.AddToggle(secTargeting, "Dynamic FOV", function() return Config.Targeting.DynamicFOV end, function(v)
        Config.Targeting.DynamicFOV = v
    end)
    UI.AddDropdown(secTargeting, "Aim Point", { "Selected", "Closest", "Random" }, function() return Config.Targeting.AimPoint end, function(v)
        Config.Targeting.AimPoint = v
        if v == "Closest" then
            Config.SilentAim.HitPart = "Closest"
        else
            Config.SilentAim.HitPart = Config.Targeting.AimParts[1] or "Head"
        end
        UI.RefreshAll()
    end)
    UI.AddMultiDropdown(secTargeting, "Aim Parts", {
        "Head",
        "FaceHitBox",
        "HeadTopHitBox",
        "UpperTorso",
        "LowerTorso",
        "HumanoidRootPart",
        "LeftUpperArm",
        "RightUpperArm",
    }, function() return Config.Targeting.AimParts end, function(partsList)
        Config.Targeting.AimParts = partsList
        if Config.Targeting.AimPoint ~= "Closest" then
            Config.SilentAim.HitPart = partsList[1] or "Head"
        end
        UI.RefreshAll()
    end)
    UI.AddToggle(secTargeting, "Visible Fallback", function() return Config.Targeting.VisibleFallback end, function(v)
        Config.Targeting.VisibleFallback = v
    end)
    UI.AddToggleWithConfig(secTargeting, "Wallbang", function() return Config.Targeting.Wallbang end, function(v)
        Config.Targeting.Wallbang = v
    end, function(pop)
        addPopupSlider(pop, "Max Walls", 1, 4, 1, "", function() return Config.Targeting.WallbangMaxWalls end, function(v)
            Config.Targeting.WallbangMaxWalls = v
        end)
        addPopupSlider(pop, "Max Thickness", 0.5, 8.0, 0.5, "st", function() return Config.Targeting.WallbangMaxThickness end, function(v)
            Config.Targeting.WallbangMaxThickness = v
        end)
        addPopupToggle(pop, "Respect NoPen", function() return Config.Targeting.WallbangRespectNoPen end, function(v)
            Config.Targeting.WallbangRespectNoPen = v
        end)
    end)
    UI.AddKeybindRow(secTargeting, "Add Not Attack", function() return Config.Targeting.AddFriendKey end, function(k)
        Config.Targeting.AddFriendKey = k
        UI.RefreshAll()
    end)
    UI.AddButton(secTargeting, "Clear Not Attack List", "normal", function()
        Delta.ClearFriends()
        UI.Notify("Not Attack", "Cleared all added players.", "info")
    end)
    UI.AddSlider(secTargeting, "Raycast Budget", 1, 16, 1, "", function() return Config.Targeting.RaycastBudget end, function(v)
        Config.Targeting.RaycastBudget = v
    end)

    local secWep = UI.AddSection(CombatTab, "Right", "Weapon Mods")
    UI.AddToggle(secWep, "No Recoil", function() return Config.WeaponMods.NoRecoil end, function(v)
        Config.WeaponMods.NoRecoil = v
        Combat.ApplyWeaponMods()
    end)
    UI.AddSlider(secWep, "Recoil Reduction", 0, 100, 5, "%", function() return Config.WeaponMods.RecoilReduction end, function(v)
        Config.WeaponMods.RecoilReduction = v
        Combat.ApplyWeaponMods()
    end)
    UI.AddToggle(secWep, "No Spread", function() return Config.WeaponMods.NoSpread end, function(v)
        Config.WeaponMods.NoSpread = v
        Combat.ApplyWeaponMods()
    end)
    UI.AddToggle(secWep, "No Camera Sway", function() return Config.WeaponMods.NoSway end, function(v)
        Config.WeaponMods.NoSway = v
        Combat.ApplyWeaponMods()
    end)
    UI.AddToggle(secWep, "Fast ADS", function() return Config.WeaponMods.FastADS end, function(v)
        Config.WeaponMods.FastADS = v
        Combat.ApplyWeaponMods()
    end)
    UI.AddToggle(secWep, "Disable Scope DOF", function() return Config.WeaponMods.NoScopeDOF end, function(v)
        Config.WeaponMods.NoScopeDOF = v
        Combat.ApplyWeaponMods()
    end)

    local secTrig = UI.AddSection(CombatTab, "Left", "TriggerBot")
    UI.AddToggle(secTrig, "Enable TriggerBot", function() return Config.TriggerBot.Enabled end, function(v) Config.TriggerBot.Enabled = v end,
        function() return Config.TriggerBot.Key end, function(k) Config.TriggerBot.Key = k end)
    UI.AddDropdown(secTrig, "Mode", { "Hold", "Toggle", "Always" }, function() return Config.TriggerBot.Mode end, function(v) Config.TriggerBot.Mode = v end)
    UI.AddDropdown(secTrig, "Hitbox Filter", { "Any", "Head Only", "Body Only" }, function() return Config.TriggerBot.HitFilter or "Any" end, function(v) Config.TriggerBot.HitFilter = v end)
    UI.AddSlider(secTrig, "Fire Delay", 20, 250, 5, "ms", function() return Config.TriggerBot.DelayMs end, function(v) Config.TriggerBot.DelayMs = v end)
    UI.AddSlider(secTrig, "Max Distance", 50, 1500, 25, "m", function() return Config.TriggerBot.MaxDistance or 500 end, function(v) Config.TriggerBot.MaxDistance = v end)
    UI.AddToggle(secTrig, "Only When ADS", function() return Config.TriggerBot.OnlyADS end, function(v) Config.TriggerBot.OnlyADS = v end)
    UI.AddToggle(secTrig, "Team Check", function() return Config.TriggerBot.TeamCheck end, function(v) Config.TriggerBot.TeamCheck = v end)
    UI.AddToggle(secTrig, "Ignore Downed", function() return Config.TriggerBot.IgnoreDowned end, function(v) Config.TriggerBot.IgnoreDowned = v end)
    UI.AddToggle(secTrig, "Target AI / Bots", function() return Config.TriggerBot.TargetAI end, function(v) Config.TriggerBot.TargetAI = v end)
end

-- ---- VISUALS TAB ----
do
    local secEsp = UI.AddSection(VisualsTab, "Left", "ESP")
    local secFilters = UI.AddSection(VisualsTab, "Right", "Filters · Player")
    local filterTitleLabel = secFilters.Parent and secFilters.Parent:FindFirstChildOfClass("TextLabel")

    local activeCategory = "Player"
    local filterFrames: { [string]: Frame } = {}

    local function selectCategory(cat: string)
        activeCategory = cat
        UI._ActiveEspCategory = cat
        if filterTitleLabel then
            filterTitleLabel.Text = ("Filters · " .. cat):upper()
        end
        for name, fr in pairs(filterFrames) do
            fr.Visible = (name == cat)
        end
        if type(UI.Preview.SyncVisibility) == "function" then
            UI.Preview.SyncVisibility()
        end
    end

    local function makeFilterPage(cat: string): Frame
        local page = Instance.new("Frame")
        page.Size = UDim2.new(1, 0, 0, 0)
        page.AutomaticSize = Enum.AutomaticSize.Y
        page.BackgroundTransparency = 1
        page.Visible = (cat == activeCategory)
        page.Parent = secFilters
        local ly = Instance.new("UIListLayout")
        ly.Padding = UDim.new(0, 7)
        ly.Parent = page
        filterFrames[cat] = page
        return page
    end

    local categories: { { Key: string, Label: string, Get: () -> boolean, Set: (boolean) -> () } } = {
        { Key = "Player", Label = "Player", Get = function() return Config.PlayerESP.Enabled end, Set = function(v) Config.PlayerESP.Enabled = v end },
        { Key = "Npc", Label = "Npc", Get = function() return Config.AIESP.Enabled end, Set = function(v) Config.AIESP.Enabled = v end },
        { Key = "Corpse", Label = "Corpse", Get = function() return Config.CorpseESP.Enabled end, Set = function(v) Config.CorpseESP.Enabled = v end },
        { Key = "Container", Label = "Container", Get = function() return Config.ContainerESP.Enabled end, Set = function(v) Config.ContainerESP.Enabled = v end },
        { Key = "Dropped Item", Label = "Dropped Item", Get = function() return Config.DroppedESP.Enabled end, Set = function(v) Config.DroppedESP.Enabled = v end },
        { Key = "Quest Items", Label = "Quest Items", Get = function() return Config.QuestESP.Enabled end, Set = function(v) Config.QuestESP.Enabled = v end },
    }

    for i, cat in ipairs(categories) do
        UI.AddEspCategoryRow(
            secEsp,
            cat.Label,
            cat.Get,
            cat.Set,
            function()
                selectCategory(cat.Key)
            end,
            function()
                return activeCategory == cat.Key
            end,
            i < #categories
        )
    end

    -- 1. Player Filters (highlights, box, name, healthbar, health, distance, kdr, reports, tracers, arrows, skeleton)
    do
        local p = makeFilterPage("Player")
        UI.AddToggle(p, "Highlights", function() return Config.PlayerESP.Highlights end, function(v) Config.PlayerESP.Highlights = v end)
        UI.AddDropdown(p, "Box", { "Corner", "2D", "Off" }, function() return Config.PlayerESP.Box end, function(v) Config.PlayerESP.Box = v end)
        UI.AddToggle(p, "Name", function() return Config.PlayerESP.Name end, function(v) Config.PlayerESP.Name = v end)
        UI.AddToggle(p, "HealthBar", function() return Config.PlayerESP.HealthBar end, function(v) Config.PlayerESP.HealthBar = v end)
        UI.AddToggle(p, "Health", function() return Config.PlayerESP.HealthText end, function(v) Config.PlayerESP.HealthText = v end)
        UI.AddToggle(p, "Distance", function() return Config.PlayerESP.Distance end, function(v) Config.PlayerESP.Distance = v end)
        UI.AddToggle(p, "KDR", function() return Config.PlayerESP.KDR end, function(v) Config.PlayerESP.KDR = v end)
        UI.AddToggle(p, "Check Reports", function() return Config.PlayerESP.Reports end, function(v) Config.PlayerESP.Reports = v end)
        UI.AddToggle(p, "Tracers", function() return Config.PlayerESP.Tracers end, function(v) Config.PlayerESP.Tracers = v end)
        UI.AddToggle(p, "Arrows", function() return Config.PlayerESP.Arrows end, function(v) Config.PlayerESP.Arrows = v end)
        UI.AddToggle(p, "Skeleton", function() return Config.PlayerESP.Skeleton end, function(v) Config.PlayerESP.Skeleton = v end)
        UI.AddToggle(p, "Held Weapon", function() return Config.PlayerESP.Weapon end, function(v) Config.PlayerESP.Weapon = v end)
        UI.AddToggle(p, "Downed Badge", function() return Config.PlayerESP.DownedBadge end, function(v) Config.PlayerESP.DownedBadge = v end)
        UI.AddToggle(p, "Hide Squadmates", function() return Config.PlayerESP.TeamCheck end, function(v) Config.PlayerESP.TeamCheck = v end)
        UI.AddSlider(p, "Max Distance", 100, 2000, 50, "m", function() return Config.PlayerESP.MaxDistance end, function(v) Config.PlayerESP.MaxDistance = v end)
        UI.AddColorPicker(p, "Enemy Color", function() return Config.PlayerESP.EnemyColor end, function(c) Config.PlayerESP.EnemyColor = c end)
        UI.AddColorPicker(p, "Squad Color", function() return Config.PlayerESP.SquadColor end, function(c) Config.PlayerESP.SquadColor = c end)
        UI.AddColorPicker(p, "Highlight Color", function() return Config.PlayerESP.ChamsFill end, function(c) Config.PlayerESP.ChamsFill = c end)
        UI.AddColorPicker(p, "Skeleton Color", function() return Config.PlayerESP.SkeletonColor end, function(c) Config.PlayerESP.SkeletonColor = c end)
    end

    -- 2. Npc Filters (highlight, box, name, healthbar, health, distance, tracers, arrows, skeleton)
    do
        local p = makeFilterPage("Npc")
        UI.AddToggle(p, "Highlight", function() return Config.AIESP.Highlights end, function(v) Config.AIESP.Highlights = v end)
        UI.AddDropdown(p, "Box", { "Corner", "2D", "Off" }, function() return Config.AIESP.Box end, function(v) Config.AIESP.Box = v end)
        UI.AddToggle(p, "Name", function() return Config.AIESP.Name end, function(v) Config.AIESP.Name = v end)
        UI.AddToggle(p, "HealthBar", function() return Config.AIESP.HealthBar end, function(v) Config.AIESP.HealthBar = v end)
        UI.AddToggle(p, "Health", function() return Config.AIESP.HealthText end, function(v) Config.AIESP.HealthText = v end)
        UI.AddToggle(p, "Distance", function() return Config.AIESP.Distance end, function(v) Config.AIESP.Distance = v end)
        UI.AddToggle(p, "Tracers", function() return Config.AIESP.Tracers end, function(v) Config.AIESP.Tracers = v end)
        UI.AddToggle(p, "Arrows", function() return Config.AIESP.Arrows end, function(v) Config.AIESP.Arrows = v end)
        UI.AddToggle(p, "Skeleton", function() return Config.AIESP.Skeleton end, function(v) Config.AIESP.Skeleton = v end)
        UI.AddToggle(p, "Held Weapon", function() return Config.AIESP.Weapon end, function(v) Config.AIESP.Weapon = v end)
        UI.AddSlider(p, "Max Distance", 100, 1500, 50, "m", function() return Config.AIESP.MaxDistance end, function(v) Config.AIESP.MaxDistance = v end)
        UI.AddColorPicker(p, "NPC Color", function() return Config.AIESP.Color end, function(c) Config.AIESP.Color = c end)
        UI.AddColorPicker(p, "Boss Color", function() return Config.AIESP.BossColor end, function(c) Config.AIESP.BossColor = c end)
        UI.AddColorPicker(p, "Highlight Color", function() return Config.AIESP.ChamsFill end, function(c) Config.AIESP.ChamsFill = c end)
        UI.AddColorPicker(p, "Skeleton Color", function() return Config.AIESP.SkeletonColor end, function(c) Config.AIESP.SkeletonColor = c end)
    end

    -- 3. Corpse Filters (chams, box, name, distance, value, tracers, arrows, skeleton)
    do
        local p = makeFilterPage("Corpse")
        UI.AddToggle(p, "Chams", function() return Config.CorpseESP.Chams end, function(v) Config.CorpseESP.Chams = v end)
        UI.AddDropdown(p, "Box", { "Corner", "2D", "Off" }, function() return Config.CorpseESP.Box end, function(v) Config.CorpseESP.Box = v end)
        UI.AddToggle(p, "Name", function() return Config.CorpseESP.Name end, function(v) Config.CorpseESP.Name = v end)
        UI.AddToggle(p, "Distance", function() return Config.CorpseESP.Distance end, function(v) Config.CorpseESP.Distance = v end)
        UI.AddToggle(p, "Value", function() return Config.CorpseESP.Value end, function(v) Config.CorpseESP.Value = v end)
        UI.AddToggle(p, "Tracers", function() return Config.CorpseESP.Tracers end, function(v) Config.CorpseESP.Tracers = v end)
        UI.AddToggle(p, "Arrows", function() return Config.CorpseESP.Arrows end, function(v) Config.CorpseESP.Arrows = v end)
        UI.AddToggle(p, "Skeleton", function() return Config.CorpseESP.Skeleton end, function(v) Config.CorpseESP.Skeleton = v end)
        UI.AddToggle(p, "Hide Empty", function() return Config.CorpseESP.HideEmpty end, function(v) Config.CorpseESP.HideEmpty = v end)
        UI.AddSlider(p, "Max Distance", 50, 1200, 25, "m", function() return Config.CorpseESP.MaxDistance end, function(v) Config.CorpseESP.MaxDistance = v end)
        UI.AddColorPicker(p, "Corpse Color", function() return Config.CorpseESP.Color end, function(c) Config.CorpseESP.Color = c end)
        UI.AddColorPicker(p, "Skeleton Color", function() return Config.CorpseESP.SkeletonColor end, function(c) Config.CorpseESP.SkeletonColor = c end)
    end

    -- 4. Container Filters (chams, box, name, distance, value, respawn, tracers, arrows)
    do
        local p = makeFilterPage("Container")
        UI.AddToggle(p, "Chams", function() return Config.ContainerESP.Chams end, function(v) Config.ContainerESP.Chams = v end)
        UI.AddDropdown(p, "Box", { "Corner", "2D", "Off" }, function() return Config.ContainerESP.Box end, function(v) Config.ContainerESP.Box = v end)
        UI.AddToggle(p, "Name", function() return Config.ContainerESP.Name end, function(v) Config.ContainerESP.Name = v end)
        UI.AddToggle(p, "Distance", function() return Config.ContainerESP.Distance end, function(v) Config.ContainerESP.Distance = v end)
        UI.AddToggle(p, "Value", function() return Config.ContainerESP.Value end, function(v) Config.ContainerESP.Value = v end)
        UI.AddToggle(p, "Respawn", function() return Config.ContainerESP.Respawn end, function(v) Config.ContainerESP.Respawn = v end)
        UI.AddToggle(p, "Tracers", function() return Config.ContainerESP.Tracers end, function(v) Config.ContainerESP.Tracers = v end)
        UI.AddToggle(p, "Arrows", function() return Config.ContainerESP.Arrows end, function(v) Config.ContainerESP.Arrows = v end)
        UI.AddToggle(p, "Hide Empty", function() return Config.ContainerESP.HideEmpty end, function(v) Config.ContainerESP.HideEmpty = v end)
        UI.AddToggle(p, "Valuable Only", function() return Config.ContainerESP.ValuableOnly end, function(v) Config.ContainerESP.ValuableOnly = v end)
        UI.AddSlider(p, "Min Value", 500, 15000, 250, "$", function() return Config.ContainerESP.MinPrice end, function(v)
            Config.ContainerESP.MinPrice = v
            for _, tag in pairs(WorldTags) do
                if tag.Category == "Container" then
                    refreshContainerTag(tag)
                end
            end
        end)
        UI.AddSlider(p, "Max Distance", 50, 1000, 25, "m", function() return Config.ContainerESP.MaxDistance end, function(v) Config.ContainerESP.MaxDistance = v end)
        UI.AddColorPicker(p, "Container Color", function() return Config.ContainerESP.Color end, function(c) Config.ContainerESP.Color = c end)
        UI.AddColorPicker(p, "Valuable Color", function() return Config.ContainerESP.ValuableColor end, function(c) Config.ContainerESP.ValuableColor = c end)
    end

    -- 5. Dropped Item Filters (chams, box, name, distance, value, tracers, arrows)
    do
        local p = makeFilterPage("Dropped Item")
        UI.AddToggle(p, "Chams", function() return Config.DroppedESP.Chams end, function(v) Config.DroppedESP.Chams = v end)
        UI.AddDropdown(p, "Box", { "Corner", "2D", "Off" }, function() return Config.DroppedESP.Box end, function(v) Config.DroppedESP.Box = v end)
        UI.AddToggle(p, "Name", function() return Config.DroppedESP.Name end, function(v) Config.DroppedESP.Name = v end)
        UI.AddToggle(p, "Distance", function() return Config.DroppedESP.Distance end, function(v) Config.DroppedESP.Distance = v end)
        UI.AddToggle(p, "Value", function() return Config.DroppedESP.Value end, function(v) Config.DroppedESP.Value = v end)
        UI.AddToggle(p, "Tracers", function() return Config.DroppedESP.Tracers end, function(v) Config.DroppedESP.Tracers = v end)
        UI.AddToggle(p, "Arrows", function() return Config.DroppedESP.Arrows end, function(v) Config.DroppedESP.Arrows = v end)
        UI.AddToggle(p, "Valuable Only", function() return Config.DroppedESP.ValuableOnly end, function(v) Config.DroppedESP.ValuableOnly = v end)
        UI.AddSlider(p, "Min Value", 500, 15000, 250, "$", function() return Config.DroppedESP.MinPrice end, function(v)
            Config.DroppedESP.MinPrice = v
            for _, tag in pairs(WorldTags) do
                if tag.Category == "Dropped" then
                    tag.IsValuable = tag.MaxPrice >= v
                end
            end
        end)
        UI.AddSlider(p, "Max Distance", 50, 1000, 25, "m", function() return Config.DroppedESP.MaxDistance end, function(v) Config.DroppedESP.MaxDistance = v end)
        UI.AddColorPicker(p, "Dropped Color", function() return Config.DroppedESP.Color end, function(c) Config.DroppedESP.Color = c end)
        UI.AddColorPicker(p, "Valuable Color", function() return Config.DroppedESP.ValuableColor end, function(c) Config.DroppedESP.ValuableColor = c end)
    end

    -- 6. Quest Items Filters (chams, box, name, distance, tracers, arrows)
    do
        local p = makeFilterPage("Quest Items")
        UI.AddToggle(p, "Chams", function() return Config.QuestESP.Chams end, function(v) Config.QuestESP.Chams = v end)
        UI.AddDropdown(p, "Box", { "Corner", "2D", "Off" }, function() return Config.QuestESP.Box end, function(v) Config.QuestESP.Box = v end)
        UI.AddToggle(p, "Name", function() return Config.QuestESP.Name end, function(v) Config.QuestESP.Name = v end)
        UI.AddToggle(p, "Distance", function() return Config.QuestESP.Distance end, function(v) Config.QuestESP.Distance = v end)
        UI.AddToggle(p, "Tracers", function() return Config.QuestESP.Tracers end, function(v) Config.QuestESP.Tracers = v end)
        UI.AddToggle(p, "Arrows", function() return Config.QuestESP.Arrows end, function(v) Config.QuestESP.Arrows = v end)
        UI.AddSlider(p, "Max Distance", 50, 2000, 50, "m", function() return Config.QuestESP.MaxDistance end, function(v) Config.QuestESP.MaxDistance = v end)
        UI.AddColorPicker(p, "Quest Color", function() return Config.QuestESP.Color end, function(c) Config.QuestESP.Color = c end)
    end

    local secWorld = UI.AddSection(VisualsTab, "Left", "World & Vision")
    UI.AddToggle(secWorld, "Fullbright", function() return Config.World.Fullbright end, function(v) Config.World.Fullbright = v end)
    UI.AddSlider(secWorld, "Brightness", 1, 5, 0.2, "", function() return Config.World.Brightness end, function(v) Config.World.Brightness = v end)
    UI.AddSlider(secWorld, "Clock Time", 0, 24, 0.5, "h", function() return Config.World.ClockTime end, function(v) Config.World.ClockTime = v end)
    UI.AddToggle(secWorld, "No Fog / Clear Air", function() return Config.World.NoFog end, function(v) Config.World.NoFog = v end)
    UI.AddToggle(secWorld, "No Blur / Visor DOF", function() return Config.World.NoBlurDOF end, function(v) Config.World.NoBlurDOF = v end)
    UI.AddToggle(secWorld, "Custom FOV Override", function() return Config.World.CustomFOV end, function(v) Config.World.CustomFOV = v end)
    UI.AddSlider(secWorld, "Field of View", 60, 120, 1, "deg", function() return Config.World.FOVValue end, function(v) Config.World.FOVValue = v end)
end

-- ---- WORLD TAB ----
;(function()
    local worldTab = UI._TabWorld
    local secWorld = UI.AddSection(worldTab, "Left", "World")

    UI.AddSubmenuRow(secWorld, "Terrain Colors", function(pop)
        addPopupToggle(pop, "Enable Custom Terrain", function() return Config.World.TerrainColorEnabled end, function(v)
            Config.World.TerrainColorEnabled = v
        end)
        UI._AddPopupCycle(pop, "Preset", { "Default", "Cyber", "Arctic", "Mars", "Custom" }, function()
            return Config.World.TerrainPreset
        end, function(v)
            Config.World.TerrainPreset = v
            if v ~= "Default" then Config.World.TerrainColorEnabled = true end
        end)
        UI._AddPopupColorPicker(pop, "Grass Color", function() return Config.World.TerrainGrassColor end, function(c)
            Config.World.TerrainGrassColor = c
            Config.World.TerrainPreset = "Custom"
            Config.World.TerrainColorEnabled = true
        end)
        UI._AddPopupColorPicker(pop, "Ground Color", function() return Config.World.TerrainGroundColor end, function(c)
            Config.World.TerrainGroundColor = c
            Config.World.TerrainPreset = "Custom"
            Config.World.TerrainColorEnabled = true
        end)
        UI._AddPopupColorPicker(pop, "Rock Color", function() return Config.World.TerrainRockColor end, function(c)
            Config.World.TerrainRockColor = c
            Config.World.TerrainPreset = "Custom"
            Config.World.TerrainColorEnabled = true
        end)
    end)

    UI.AddSubmenuRow(secWorld, "Leaves", function(pop)
        addPopupToggle(pop, "Custom Leaves Color", function() return Config.World.LeavesEnabled end, function(v)
            Config.World.LeavesEnabled = v
        end)
        UI._AddPopupColorPicker(pop, "Leaves Color", function() return Config.World.LeavesColor end, function(c)
            Config.World.LeavesColor = c
            Config.World.LeavesEnabled = true
        end)
        addPopupToggle(pop, "Hide Leaves", function() return Config.World.LeavesHide end, function(v)
            Config.World.LeavesHide = v
        end)
        addPopupSlider(pop, "Transparency", 0, 100, 5, "%", function() return Config.World.LeavesTransparency end, function(v)
            Config.World.LeavesTransparency = v
        end)
    end)

    UI.AddSubmenuRow(secWorld, "Tree Trunks", function(pop)
        addPopupToggle(pop, "Custom Trunk Color", function() return Config.World.TrunksEnabled end, function(v)
            Config.World.TrunksEnabled = v
        end)
        UI._AddPopupColorPicker(pop, "Trunk Color", function() return Config.World.TrunksColor end, function(c)
            Config.World.TrunksColor = c
            Config.World.TrunksEnabled = true
        end)
        addPopupToggle(pop, "Hide Trunks", function() return Config.World.TrunksHide end, function(v)
            Config.World.TrunksHide = v
        end)
        addPopupSlider(pop, "Transparency", 0, 100, 5, "%", function() return Config.World.TrunksTransparency end, function(v)
            Config.World.TrunksTransparency = v
        end)
    end)

    UI.AddColorPicker(secWorld, "Water Color", function()
        return Config.World.WaterColor
    end, function(c)
        Config.World.WaterColor = c
        Config.World.WaterColorEnabled = true
    end)
    UI.AddToggle(secWorld, "No Grass", function() return Config.World.NoGrass end, function(v)
        Config.World.NoGrass = v
    end)
    UI.AddToggle(secWorld, "No Mines", function() return Config.World.NoMines end, function(v)
        Config.World.NoMines = v
    end)

    local secFeat = UI.AddSection(worldTab, "Left", "Features")
    UI.AddToggle(secFeat, "Render Players", function() return Config.World.RenderPlayers end, function(v)
        Config.World.RenderPlayers = v
    end)
    UI.AddToggleWithConfig(secFeat, "Boss Checker", function() return Config.World.BossChecker end, function(v)
        Config.World.BossChecker = v
    end, function(pop)
        addPopupToggle(pop, "Notify on Spawn", function() return Config.World.BossNotify end, function(v) Config.World.BossNotify = v end)
        addPopupToggle(pop, "Alert World Events", function() return Config.World.BossAlertEvents end, function(v) Config.World.BossAlertEvents = v end)
        addPopupToggle(pop, "Show Status HUD", function() return Config.World.BossShowHUD end, function(v) Config.World.BossShowHUD = v end)
    end, nil, true)

    UI.AddToggleWithConfig(secFeat, "ExitLocations", function() return Config.ExitESP.Enabled end, function(v)
        Config.ExitESP.Enabled = v
        UI.RefreshAll()
    end, function(pop)
        addPopupSlider(pop, "Max Distance", 100, 3000, 50, "m", function() return Config.ExitESP.MaxDistance end, function(v)
            Config.ExitESP.MaxDistance = v
            UI.RefreshAll()
        end)
        UI._AddPopupColorPicker(pop, "Exit Color", function() return Config.ExitESP.Color end, function(c)
            Config.ExitESP.Color = c
            UI.RefreshAll()
        end)
        addPopupToggle(pop, "Show Timer", function() return Config.ExitESP.ShowTimer ~= false end, function(v) Config.ExitESP.ShowTimer = v end)
        addPopupToggle(pop, "Show Tracers", function() return Config.ExitESP.Tracers == true end, function(v) Config.ExitESP.Tracers = v end)
    end)

    UI.AddToggleWithConfig(secFeat, "Radar", function() return Config.World.Radar end, function(v)
        Config.World.Radar = v
    end, function(pop)
        addPopupSlider(pop, "Radar Size", 100, 260, 4, "px", function() return Config.World.RadarSize end, function(v) Config.World.RadarSize = v end)
        addPopupSlider(pop, "Range", 80, 800, 20, "m", function() return Config.World.RadarRange end, function(v) Config.World.RadarRange = v end)
        addPopupToggle(pop, "Rotate With Camera", function() return Config.World.RadarRotate end, function(v) Config.World.RadarRotate = v end)
        addPopupToggle(pop, "Show Players", function() return Config.World.RadarPlayers end, function(v) Config.World.RadarPlayers = v end)
        addPopupToggle(pop, "Show NPCs / Bosses", function() return Config.World.RadarNPC end, function(v) Config.World.RadarNPC = v end)
        addPopupToggle(pop, "Show Corpses", function() return Config.World.RadarCorpses end, function(v) Config.World.RadarCorpses = v end)
        addPopupToggle(pop, "Show Exits", function() return Config.World.RadarExits end, function(v) Config.World.RadarExits = v end)
        addPopupSlider(pop, "Position X", 8, 900, 8, "px", function() return Config.World.RadarX end, function(v) Config.World.RadarX = v end)
        addPopupSlider(pop, "Position Y", 8, 700, 8, "px", function() return Config.World.RadarY end, function(v) Config.World.RadarY = v end)
    end)

    local secLight = UI.AddSection(worldTab, "Right", "Lighting")
    UI.AddToggleWithConfig(secLight, "Light", function() return Config.World.LightEnabled end, function(v)
        Config.World.LightEnabled = v
    end, function(pop)
        addPopupSlider(pop, "Brightness", 0, 8, 0.2, "", function() return Config.World.Brightness end, function(v) Config.World.Brightness = v end)
        addPopupSlider(pop, "Exposure", -2, 3, 0.1, "", function() return Config.World.Exposure end, function(v) Config.World.Exposure = v end)
        UI._AddPopupColorPicker(pop, "Ambient Color", function() return Config.World.AmbientColor end, function(c) Config.World.AmbientColor = c end)
        UI._AddPopupColorPicker(pop, "Outdoor Ambient", function() return Config.World.OutdoorAmbientColor end, function(c) Config.World.OutdoorAmbientColor = c end)
    end)

    UI.AddToggleWithConfig(secLight, "Time & Sun", function() return Config.World.TimeSunEnabled end, function(v)
        Config.World.TimeSunEnabled = v
    end, function(pop)
        addPopupSlider(pop, "Clock Time", 0, 24, 0.5, "h", function() return Config.World.ClockTime end, function(v) Config.World.ClockTime = v end)
        addPopupSlider(pop, "Sun Latitude", -90, 90, 2, "deg", function() return Config.World.Latitude end, function(v) Config.World.Latitude = v end)
    end)

    UI.AddToggleWithConfig(secLight, "Shadows", function() return Config.World.ShadowsEnabled end, function(v)
        Config.World.ShadowsEnabled = v
    end, function(pop)
        addPopupToggle(pop, "Disable Shadows", function() return Config.World.DisableShadows end, function(v) Config.World.DisableShadows = v end)
        addPopupSlider(pop, "Softness", 0, 1, 0.05, "", function() return Config.World.ShadowSoftness end, function(v) Config.World.ShadowSoftness = v end)
        addPopupSlider(pop, "Diffuse Scale", 0, 1, 0.05, "", function() return Config.World.DiffuseScale end, function(v) Config.World.DiffuseScale = v end)
    end)

    UI.AddToggleWithConfig(secLight, "Rendering", function() return Config.World.RenderingEnabled end, function(v)
        Config.World.RenderingEnabled = v
    end, function(pop)
        addPopupToggle(pop, "Custom FOV", function() return Config.World.CustomFOV end, function(v)
            Config.World.CustomFOV = v
            UI.RefreshAll()
        end)
        addPopupSlider(pop, "Field of View", 60, 120, 1, "deg", function() return Config.World.FOVValue end, function(v)
            Config.World.FOVValue = v
            UI.RefreshAll()
        end)
        addPopupSlider(pop, "Exposure Bias", -2, 3, 0.1, "", function() return Config.World.ExposureBias end, function(v) Config.World.ExposureBias = v end)
    end)

    UI.AddToggleWithConfig(secLight, "Fog", function() return Config.World.FogEnabled end, function(v)
        Config.World.FogEnabled = v
    end, function(pop)
        addPopupToggle(pop, "Clear Air Preset", function() return Config.World.NoFog end, function(v)
            Config.World.NoFog = v
            if v then Config.World.FogEnd = 100000 end
            UI.RefreshAll()
        end)
        addPopupSlider(pop, "Fog Start", 0, 1000, 10, "", function() return Config.World.FogStart end, function(v) Config.World.FogStart = v end)
        addPopupSlider(pop, "Fog End", 50, 5000, 50, "", function() return Config.World.FogEnd end, function(v) Config.World.FogEnd = v end)
        UI._AddPopupColorPicker(pop, "Fog Color", function() return Config.World.FogColor end, function(c) Config.World.FogColor = c end)
    end)

    UI.AddToggleWithConfig(secLight, "Atmosphere", function() return Config.World.AtmosphereEnabled end, function(v)
        Config.World.AtmosphereEnabled = v
    end, function(pop)
        addPopupSlider(pop, "Density", 0, 1, 0.05, "", function() return Config.World.AtmoDensity end, function(v) Config.World.AtmoDensity = v end)
        addPopupSlider(pop, "Haze", 0, 10, 0.2, "", function() return Config.World.AtmoHaze end, function(v) Config.World.AtmoHaze = v end)
        addPopupSlider(pop, "Glare", 0, 10, 0.2, "", function() return Config.World.AtmoGlare end, function(v) Config.World.AtmoGlare = v end)
        addPopupSlider(pop, "Offset", 0, 1, 0.05, "", function() return Config.World.AtmoOffset end, function(v) Config.World.AtmoOffset = v end)
        UI._AddPopupColorPicker(pop, "Atmo Color", function() return Config.World.AtmoColor end, function(c) Config.World.AtmoColor = c end)
    end)

    UI.AddToggleWithConfig(secLight, "Sky", function() return Config.World.SkyEnabled end, function(v)
        Config.World.SkyEnabled = v
    end, function(pop)
        UI._AddPopupCycle(pop, "Preset", { "Night Space", "Default" }, function() return Config.World.SkyPreset end, function(v)
            Config.World.SkyPreset = v
        end)
        addPopupSlider(pop, "Star Count", 0, 5000, 250, "", function() return Config.World.SkyStars end, function(v) Config.World.SkyStars = v end)
        addPopupToggle(pop, "Celestial Bodies", function() return Config.World.SkyCelestial end, function(v) Config.World.SkyCelestial = v end)
    end)

    UI.AddToggleWithConfig(secLight, "Clouds", function() return Config.World.CloudsEnabled end, function(v)
        Config.World.CloudsEnabled = v
    end, function(pop)
        addPopupSlider(pop, "Cover", 0, 1, 0.05, "", function() return Config.World.CloudsCover end, function(v) Config.World.CloudsCover = v end)
        addPopupSlider(pop, "Density", 0, 1, 0.05, "", function() return Config.World.CloudsDensity end, function(v) Config.World.CloudsDensity = v end)
        UI._AddPopupColorPicker(pop, "Clouds Color", function() return Config.World.CloudsColor end, function(c) Config.World.CloudsColor = c end)
    end)

    UI.AddToggleWithConfig(secLight, "Bloom", function() return Config.World.BloomEnabled end, function(v)
        Config.World.BloomEnabled = v
    end, function(pop)
        addPopupToggle(pop, "Disable Bloom", function() return Config.World.DisableBloom end, function(v) Config.World.DisableBloom = v end)
        addPopupSlider(pop, "Intensity", 0, 3, 0.1, "", function() return Config.World.BloomIntensity end, function(v) Config.World.BloomIntensity = v end)
        addPopupSlider(pop, "Size", 0, 56, 2, "", function() return Config.World.BloomSize end, function(v) Config.World.BloomSize = v end)
        addPopupSlider(pop, "Threshold", 0.5, 4, 0.1, "", function() return Config.World.BloomThreshold end, function(v) Config.World.BloomThreshold = v end)
    end)

    UI.AddToggleWithConfig(secLight, "Blur", function() return Config.World.BlurEnabled end, function(v)
        Config.World.BlurEnabled = v
    end, function(pop)
        addPopupToggle(pop, "Remove All Blur", function() return Config.World.NoBlurDOF end, function(v)
            Config.World.NoBlurDOF = v
            UI.RefreshAll()
        end)
        addPopupSlider(pop, "Blur Size", 0, 24, 1, "", function() return Config.World.BlurSize end, function(v) Config.World.BlurSize = v end)
    end)
end)()

-- ---- MISC TAB ----
do
    local secMisc = UI.AddSection(MiscTab, "Left", "Misc")
    UI.AddToggle(secMisc, "Fast Trade", function() return Config.Misc.FastTrade end, function(v)
        Config.Misc.FastTrade = v
    end)

    UI.AddToggleWithConfig(secMisc, "Panic Mode", function() return Config.Misc.PanicMode end, function(v)
        Misc.SetPanicMode(v, false)
    end, function(pop)
        UI._AddPopupKeybind(pop, "Panic Key", function() return Config.Misc.PanicKey end, function(k) Config.Misc.PanicKey = k end)
        addPopupToggle(pop, "Hide Visuals", function() return Config.Misc.PanicHideVisuals end, function(v)
            Config.Misc.PanicHideVisuals = v
            if Config.Misc.PanicMode then Misc.SetPanicMode(true, false) end
        end)
        addPopupToggle(pop, "Disable Combat", function() return Config.Misc.PanicDisableCombat end, function(v)
            Config.Misc.PanicDisableCombat = v
            if Config.Misc.PanicMode then Misc.SetPanicMode(true, false) end
        end)
        addPopupToggle(pop, "Hide Menu", function() return Config.Misc.PanicHideMenu end, function(v)
            Config.Misc.PanicHideMenu = v
            if Config.Misc.PanicMode then Misc.SetPanicMode(true, false) end
        end)
    end, 128)

    UI.AddToggleWithConfig(secMisc, "Pass Door", function() return Config.Misc.PassDoor end, function(v)
        Config.Misc.PassDoor = v
        if v and Config.Misc.PassDoorMode == "Toggle" then
            ToggleStates.PassDoor = true
        elseif not v then
            Misc.RestoreDoors()
        end
    end, function(pop)
        UI._AddPopupKeybind(pop, "Pass Key", function() return Config.Misc.PassDoorKey end, function(k) Config.Misc.PassDoorKey = k end)
        UI._AddPopupCycle(pop, "Mode", { "Always", "Hold", "Toggle" }, function() return Config.Misc.PassDoorMode end, function(v)
            Config.Misc.PassDoorMode = v
            if v == "Toggle" then
                ToggleStates.PassDoor = true
            end
        end)
        addPopupSlider(pop, "Phase Range", 6, 35, 1, "st", function() return Config.Misc.PassDoorRange end, function(v) Config.Misc.PassDoorRange = v end)
        addPopupToggle(pop, "Auto Open Unlocked", function() return Config.Misc.PassDoorAutoOpen end, function(v) Config.Misc.PassDoorAutoOpen = v end)
    end, 144)

    UI.AddToggle(secMisc, "Screen Effects", function() return Config.Misc.ScreenEffects end, function(v)
        Config.Misc.ScreenEffects = v
        if not v then
            Misc.RestoreScreenEffects()
        end
    end)

    UI.AddToggleWithConfig(secMisc, "Report Notify", function() return Config.Misc.ReportNotify end, function(v)
        Config.Misc.ReportNotify = v
    end, function(pop)
        addPopupToggle(pop, "Alert My Flags", function() return Config.Misc.ReportAlertSelf end, function(v) Config.Misc.ReportAlertSelf = v end)
        addPopupToggle(pop, "Alert Server Flags", function() return Config.Misc.ReportAlertServer end, function(v) Config.Misc.ReportAlertServer = v end)
    end, 72)

    UI.AddToggleWithConfig(secMisc, "Join Notify", function() return Config.Misc.JoinNotify end, function(v)
        Config.Misc.JoinNotify = v
    end, function(pop)
        addPopupToggle(pop, "Only Flagged / Staff", function() return Config.Misc.JoinAlertFlaggedOnly end, function(v) Config.Misc.JoinAlertFlaggedOnly = v end)
        addPopupToggle(pop, "Leave Alerts", function() return Config.Misc.JoinLeaveAlerts end, function(v) Config.Misc.JoinLeaveAlerts = v end)
        addPopupToggle(pop, "Show Account Age", function() return Config.Misc.JoinShowAge end, function(v) Config.Misc.JoinShowAge = v end)
    end, 100)

    local secDetect = UI.AddSection(MiscTab, "Right", "Detect")
    local function addDetectItem(label: string, key: string, extraBuilder: ((Frame) -> ())?, popH: number?)
        UI.AddToggleWithConfig(secDetect, label, function()
            return (Config.Detect :: any)[key] == true
        end, function(v)
            (Config.Detect :: any)[key] = v
            if v then
                for _, p in ipairs(Players:GetPlayers()) do
                    Misc.EvaluatePlayerDetect(p)
                end
            end
        end, function(pop)
            addPopupToggle(pop, "Notify Alert", function() return (Config.Detect :: any)[key .. "Notify"] == true end, function(v)
                (Config.Detect :: any)[key .. "Notify"] = v
            end)
            addPopupToggle(pop, "ESP Badge", function() return (Config.Detect :: any)[key .. "Badge"] == true end, function(v)
                (Config.Detect :: any)[key .. "Badge"] = v
            end)
            if extraBuilder then
                extraBuilder(pop)
            end
        end, popH or 72)
    end

    addDetectItem("Content Creator", "ContentCreator")
    addDetectItem("Tester", "Tester")
    addDetectItem("Moderator", "Moderator")
    addDetectItem("Cheater", "Cheater", function(pop)
        addPopupSlider(pop, "Min Flags", 3, 100, 1, "", function() return Config.Detect.CheaterMinFlags end, function(v) Config.Detect.CheaterMinFlags = v end)
        addPopupSlider(pop, "Min HSR", 40, 100, 5, "%", function() return Config.Detect.CheaterMinHSR end, function(v) Config.Detect.CheaterMinHSR = v end)
        addPopupSlider(pop, "Min KDR", 1.5, 15.0, 0.5, "", function() return Config.Detect.CheaterMinKDR end, function(v) Config.Detect.CheaterMinKDR = v end)
    end, 188)

    local secCheckRep = UI.AddSection(MiscTab, "Right", "Check Reports")
    UI.AddToggle(secCheckRep, "Reports HUD", function() return Config.Misc.ReportsHUD end, function(v)
        Config.Misc.ReportsHUD = v
        if Misc.RefreshReportsHud then
            Misc.RefreshReportsHud(true)
        end
    end)
    UI.AddButton(secCheckRep, "Scan Server Reports", "accent", function()
        Config.Misc.ReportsHUD = true
        if Misc.RefreshReportsHud then
            Misc.RefreshReportsHud(true)
        end
        UI.RefreshAll()
        local flagged, topName, topRep = 0, "", 0
        for _, plr in ipairs(Players:GetPlayers()) do
            local _, rep = Delta.GetPlayerMeta(plr)
            if (rep or 0) > 0 then
                flagged += 1
                if (rep or 0) > topRep then
                    topRep = rep or 0
                    topName = plr.DisplayName
                end
            end
        end
        if flagged > 0 then
            Misc._SendNotify("Check Reports", string.format("%d flagged player(s) | Top: %s (%d rep)", flagged, topName, topRep), "warn", true)
        else
            Misc._SendNotify("Check Reports", "All server players currently have 0 reports.", "success", true)
        end
    end)

    local secVault = UI.AddSection(MiscTab, "Right", "Vault Sort")
    UI.AddButton(secVault, "Sort By Value", "accent", function()
        Misc.SortVaultByValue()
    end)
end

-- ---- SETTINGS TAB ----
do
    local secUI = UI.AddSection(SettingsTab, "Left", "Interface & HUD")
    UI.AddKeybindRow(secUI, "Menu Toggle Key", function() return Config.Settings.MenuKey end, function(k)
        Config.Settings.MenuKey = k
        SideFooter.Text = formatBindName(k) .. " to Toggle"
    end)
    UI.AddToggle(secUI, "Show Watermark", function() return Config.Settings.Watermark end, function(v)
        Config.Settings.Watermark = v
        WatermarkFrame.Visible = v and not (Config.Misc.PanicMode and Config.Misc.PanicHideVisuals)
    end)
    UI.AddToggle(secUI, "Target Info HUD", function() return Config.Settings.TargetHUD end, function(v) Config.Settings.TargetHUD = v end)
    UI.AddToggle(secUI, "Notifications", function() return Config.Settings.Notifications end, function(v) Config.Settings.Notifications = v end)
    UI.AddSlider(secUI, "ESP Font Size", 10, 18, 1, "px", function() return Config.Settings.FontSize end, function(v) Config.Settings.FontSize = v end)
    UI.AddSlider(secUI, "Menu Transparency", 0, 45, 1, "%", function() return Config.Settings.MenuTransparency end, function(v)
        Config.Settings.MenuTransparency = v
        UI.ApplyGlassTheme()
    end)

    local secCfg = UI.AddSection(SettingsTab, "Right", "Config Manager")
    UI.AddTextBox(secCfg, "Config Name", "default", function()
        return ConfigMgr._InputName
    end, function(txt)
        ConfigMgr._InputName = txt
    end)
    UI.AddDropdown(secCfg, "Saved Profiles", function()
        return ConfigMgr.List()
    end, function()
        return ConfigMgr._Selected
    end, function(v)
        ConfigMgr._Selected = v
        ConfigMgr._InputName = v
        UI.RefreshAll()
    end)
    UI.AddButton(secCfg, "Save Config", "accent", function()
        local name = (ConfigMgr._InputName ~= "" and ConfigMgr._InputName) or ConfigMgr._Selected
        ConfigMgr.Save(name)
        UI.RefreshAll()
    end)
    UI.AddButton(secCfg, "Load Config", "normal", function()
        ConfigMgr.Load(ConfigMgr._Selected, false)
    end)
    UI.AddToggle(secCfg, "Auto Load Selected", function()
        return ConfigMgr.GetAutoLoad() == ConfigMgr._Selected
    end, function(v)
        if v then
            ConfigMgr.SetAutoLoad(ConfigMgr._Selected)
            UI.Notify("Auto-Load", "Set '" .. ConfigMgr._Selected .. "' on startup.", "success")
        else
            ConfigMgr.SetAutoLoad(nil)
            UI.Notify("Auto-Load", "Disabled startup config.", "info")
        end
    end)
    UI.AddButton(secCfg, "Delete Config", "danger", function()
        ConfigMgr.Delete(ConfigMgr._Selected)
        UI.RefreshAll()
    end)

    local secSess = UI.AddSection(SettingsTab, "Right", "Session Control")
    UI.AddButton(secSess, "Restore World & Weapons", "normal", function()
        Config.WeaponMods.NoRecoil = false
        Config.WeaponMods.NoSpread = false
        Config.WeaponMods.NoSway = false
        Config.WeaponMods.FastADS = false
        Config.WeaponMods.NoScopeDOF = false
        if Config.Misc.PanicMode then
            Misc.SetPanicMode(false, false)
        end
        Misc.RestoreDoors()
        Misc.RestoreScreenEffects()
        Combat.RestoreAllWeaponMods()
        World.RestoreAll()
        UI.RefreshAll()
        UI.Notify("Restored", "World lighting and weapon stats restored.", "success")
    end)
    UI.AddButton(secSess, "Reset Default Config", "normal", function()
        local fresh = createDefaultConfig()
        for k, v in pairs(fresh) do
            Config[k] = v
        end
        table.clear(ToggleStates)
        table.clear(Misc._NotifiedDetect)
        Misc._LastPanic = false
        Delta.ClearFriends()
        Misc.RestoreDoors()
        Misc.RestoreScreenEffects()
        Combat.RestoreAllWeaponMods()
        World.RestoreAll()
        WatermarkFrame.Visible = Config.Settings.Watermark
        SideFooter.Text = formatBindName(Config.Settings.MenuKey) .. " to Toggle"
        UI.ApplyGlassTheme()
        UI.RefreshAll()
        if Misc.RefreshReportsHud then
            Misc.RefreshReportsHud(true)
        end
        UI.Notify("Config Reset", "All settings restored to defaults.", "info")
    end)
    UI.AddButton(secSess, "Unload Delta Suite", "danger", function()
        Session.Stop()
    end)
end

-- ============================================================================
-- 10B. INTERACTIVE 4-ZONE ESP PREVIEW PANEL (CHARACTER & LOOT CUBE)
-- ============================================================================
;(function()
    local PreviewFrame = Instance.new("Frame")
    PreviewFrame.Name = "EspPreviewPanel"
    PreviewFrame.Size = UDim2.fromOffset(282, 490)
    PreviewFrame.BackgroundColor3 = THEME.BgMain
    PreviewFrame.BackgroundTransparency = 0.22
    PreviewFrame.ClipsDescendants = true
    PreviewFrame.Visible = false
    PreviewFrame.ZIndex = 20
    PreviewFrame.Parent = ScreenGui
    addCorner(PreviewFrame, 10)
    local pStroke = addStroke(PreviewFrame, THEME.Border, 1.2, 0.25)

    local PHeader = Instance.new("Frame")
    PHeader.Size = UDim2.new(1, 0, 0, 42)
    PHeader.BackgroundColor3 = THEME.BgHeader
    PHeader.BackgroundTransparency = 0.28
    PHeader.BorderSizePixel = 0
    PHeader.Parent = PreviewFrame

    local PHeaderSep = Instance.new("Frame")
    PHeaderSep.Position = UDim2.new(0, 0, 1, -1)
    PHeaderSep.Size = UDim2.new(1, 0, 0, 1)
    PHeaderSep.BackgroundColor3 = THEME.Border
    PHeaderSep.BackgroundTransparency = 0.45
    PHeaderSep.BorderSizePixel = 0
    PHeaderSep.Parent = PHeader

    local PTitle = Instance.new("TextLabel")
    PTitle.BackgroundTransparency = 1
    PTitle.Position = UDim2.fromOffset(14, 0)
    PTitle.Size = UDim2.new(0, 74, 1, 0)
    PTitle.Font = Enum.Font.GothamBold
    PTitle.TextSize = 13
    PTitle.TextColor3 = THEME.TextPrimary
    PTitle.TextXAlignment = Enum.TextXAlignment.Left
    PTitle.Text = "PREVIEW"
    PTitle.Parent = PHeader

    local PCatBadge = Instance.new("TextLabel")
    PCatBadge.Position = UDim2.fromOffset(82, 12)
    PCatBadge.Size = UDim2.fromOffset(74, 18)
    PCatBadge.BackgroundColor3 = THEME.BgControl
    PCatBadge.Font = Enum.Font.GothamBold
    PCatBadge.TextSize = 10
    PCatBadge.TextColor3 = THEME.Accent
    PCatBadge.Text = "PLAYER"
    PCatBadge.Parent = PHeader
    addCorner(PCatBadge, 5)

    local LockBtn = Instance.new("TextButton")
    LockBtn.AnchorPoint = Vector2.new(1, 0.5)
    LockBtn.Position = UDim2.new(1, -46, 0.5, 0)
    LockBtn.Size = UDim2.fromOffset(36, 22)
    LockBtn.BackgroundColor3 = THEME.BgControl
    LockBtn.Font = Enum.Font.GothamBold
    LockBtn.TextSize = 10
    LockBtn.TextColor3 = THEME.TextSecondary
    LockBtn.Text = "Free"
    LockBtn.AutoButtonColor = false
    LockBtn.Parent = PHeader
    addCorner(LockBtn, 5)
    local lockStroke = addStroke(LockBtn, THEME.Border, 1, 0.25)

    local ResetBtn = Instance.new("TextButton")
    ResetBtn.AnchorPoint = Vector2.new(1, 0.5)
    ResetBtn.Position = UDim2.new(1, -10, 0.5, 0)
    ResetBtn.Size = UDim2.fromOffset(30, 22)
    ResetBtn.BackgroundColor3 = THEME.BgControl
    ResetBtn.Font = Enum.Font.GothamBold
    ResetBtn.TextSize = 11
    ResetBtn.TextColor3 = THEME.TextSecondary
    ResetBtn.Text = "Rst"
    ResetBtn.AutoButtonColor = false
    ResetBtn.Parent = PHeader
    addCorner(ResetBtn, 5)
    addStroke(ResetBtn, THEME.Border, 1, 0.25)

    local HintBar = Instance.new("TextLabel")
    HintBar.Position = UDim2.fromOffset(10, 44)
    HintBar.Size = UDim2.new(1, -20, 0, 18)
    HintBar.BackgroundTransparency = 1
    HintBar.Font = Enum.Font.Gotham
    HintBar.TextSize = 10
    HintBar.TextColor3 = THEME.TextMuted
    HintBar.Text = "Drag labels to Top, Bottom, Left, or Right"
    HintBar.Parent = PreviewFrame

    local STAGE_W, STAGE_H = 262, 416
    local curBoxX, curBoxY, curBoxW, curBoxH = 88, 132, 86, 152

    local Stage = Instance.new("Frame")
    Stage.Position = UDim2.fromOffset(10, 64)
    Stage.Size = UDim2.fromOffset(STAGE_W, STAGE_H)
    Stage.BackgroundColor3 = Color3.fromRGB(9, 12, 18)
    Stage.BackgroundTransparency = 0.34
    Stage.ClipsDescendants = true
    Stage.Parent = PreviewFrame
    addCorner(Stage, 8)
    addStroke(Stage, THEME.Border, 1, 0.32)

    UI._GlassPreview = { Main = PreviewFrame, Header = PHeader, Stage = Stage, MainStroke = pStroke }

    local stageGrad = Instance.new("UIGradient")
    stageGrad.Rotation = 90
    stageGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(8, 9, 12)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(13, 15, 19)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(7, 8, 10)),
    })
    stageGrad.Parent = Stage

    -- Soft radial spotlight halo behind the character silhouette
    for _, haloSpec in ipairs({
        { Size = 248, Y = 212, Color = Color3.fromRGB(58, 61, 68), Trans = 0.88 },
        { Size = 182, Y = 210, Color = Color3.fromRGB(74, 77, 85), Trans = 0.84 },
        { Size = 118, Y = 208, Color = Color3.fromRGB(92, 96, 104), Trans = 0.82 },
    }) do
        local halo = Instance.new("Frame")
        halo.AnchorPoint = Vector2.new(0.5, 0.5)
        halo.Position = UDim2.fromOffset(STAGE_W * 0.5, haloSpec.Y)
        halo.Size = UDim2.fromOffset(haloSpec.Size, haloSpec.Size)
        halo.BackgroundColor3 = haloSpec.Color
        halo.BackgroundTransparency = haloSpec.Trans
        halo.BorderSizePixel = 0
        halo.ZIndex = 1
        halo.Parent = Stage
        addCorner(halo, haloSpec.Size)
    end

    -- 2D Pedestal plate (shown for Loot Cube mode; Dummy mode uses the 3D Octagon Pedestal)
    local Pedestal = Instance.new("Frame")
    Pedestal.AnchorPoint = Vector2.new(0.5, 0.5)
    Pedestal.Position = UDim2.fromOffset(curBoxX + curBoxW * 0.5, curBoxY + curBoxH - 2)
    Pedestal.Size = UDim2.fromOffset(118, 22)
    Pedestal.BackgroundColor3 = Color3.fromRGB(17, 23, 35)
    Pedestal.BackgroundTransparency = 0.22
    Pedestal.ZIndex = 2
    Pedestal.Visible = false
    Pedestal.Parent = Stage
    addCorner(Pedestal, 11)
    local pedestalStroke = addStroke(Pedestal, THEME.Accent, 1, 0.45)

    local PedestalInner = Instance.new("Frame")
    PedestalInner.AnchorPoint = Vector2.new(0.5, 0.5)
    PedestalInner.Position = UDim2.fromScale(0.5, 0.5)
    PedestalInner.Size = UDim2.new(1, -18, 1, -8)
    PedestalInner.BackgroundColor3 = Color3.fromRGB(28, 37, 56)
    PedestalInner.BackgroundTransparency = 0.35
    PedestalInner.ZIndex = 2
    PedestalInner.Parent = Pedestal
    addCorner(PedestalInner, 8)
    local pedestalInnerStroke = addStroke(PedestalInner, THEME.Border, 1, 0.35)

    -- 3D ViewportFrame in center (Obsidian R15 Character + 3D Octagon Pedestal / Loot Cube)
    local CharViewport = Instance.new("ViewportFrame")
    CharViewport.Position = UDim2.fromOffset(curBoxX - 58, curBoxY - 14)
    CharViewport.Size = UDim2.fromOffset(curBoxW + 116, curBoxH + 46)
    CharViewport.BackgroundTransparency = 1
    CharViewport.Ambient = Color3.fromRGB(84, 90, 102)
    CharViewport.LightColor = Color3.fromRGB(242, 246, 255)
    CharViewport.LightDirection = Vector3.new(-0.22, -1.0, -0.35)
    CharViewport.ZIndex = 3
    CharViewport.Parent = Stage

    local WorldM = Instance.new("WorldModel")
    WorldM.Parent = CharViewport

    local DummyCam = Instance.new("Camera")
    DummyCam.FieldOfView = 38
    DummyCam.CFrame = CFrame.lookAt(Vector3.new(0, 0.85, 8.20), Vector3.new(0, -0.18, 0))
    DummyCam.Parent = CharViewport
    CharViewport.CurrentCamera = DummyCam

    local DummyModel = Instance.new("Model")
    DummyModel.Name = "DeltaDummyRig"
    DummyModel.Parent = WorldM

    local DummyParts: { { Part: BasePart, Role: string } } = {}
    local DummySkelWorldSegs: { { Vector3 } } = {}
    do
        local function addRigPart(
            name: string,
            size: Vector3,
            localCF: CFrame,
            role: string,
            meshType: Enum.MeshType?,
            meshScale: Vector3?,
            mat: Enum.Material?
        ): BasePart
            local p = Instance.new("Part")
            p.Name = name
            p.Size = size
            p.CFrame = localCF
            p.Anchored = true
            p.Material = mat or Enum.Material.SmoothPlastic
            p.TopSurface = Enum.SurfaceType.Smooth
            p.BottomSurface = Enum.SurfaceType.Smooth
            p.Parent = DummyModel
            if meshType then
                local m = Instance.new("SpecialMesh")
                m.MeshType = meshType
                if meshScale then
                    m.Scale = meshScale
                end
                m.Parent = p
            end
            table.insert(DummyParts, { Part = p, Role = role })
            return p
        end

        -- Clean Sleek Obsidian R15 Character (+Z faces Camera)
        local j = {
            HeadTop = Vector3.new(0, 2.15, 0),
            HeadMid = Vector3.new(0, 1.66, 0),
            Neck = Vector3.new(0, 1.18, 0),
            Pelvis = Vector3.new(0, -0.26, 0),
            LShoulder = Vector3.new(-1.26, 0.88, 0),
            LElbow = Vector3.new(-1.31, 0.24, 0),
            LHand = Vector3.new(-1.35, -0.44, 0),
            RShoulder = Vector3.new(1.26, 0.88, 0),
            RElbow = Vector3.new(1.31, 0.24, 0),
            RHand = Vector3.new(1.35, -0.44, 0),
            LHip = Vector3.new(-0.45, -0.34, 0),
            LKnee = Vector3.new(-0.45, -1.16, 0),
            LFoot = Vector3.new(-0.45, -1.96, 0),
            RHip = Vector3.new(0.45, -0.34, 0),
            RKnee = Vector3.new(0.45, -1.16, 0),
            RFoot = Vector3.new(0.45, -1.96, 0),
        }

        addRigPart("Head", Vector3.new(1.12, 1.12, 1.12), CFrame.new(j.HeadMid), "Body", Enum.MeshType.Head, Vector3.new(1.06, 1.06, 1.06))
        addRigPart("UpperTorso", Vector3.new(1.78, 1.34, 0.92), CFrame.new(0, 0.37, 0), "Body")
        addRigPart("LowerTorso", Vector3.new(1.74, 0.44, 0.90), CFrame.new(0, -0.56, 0), "Body")

        addRigPart("LeftArm", Vector3.new(0.84, 1.62, 0.86), CFrame.new(-1.33, 0.24, 0) * CFrame.Angles(0, 0, math.rad(-2.5)), "Body")
        addRigPart("LeftHandCuff", Vector3.new(0.85, 0.16, 0.87), CFrame.new(-1.36, -0.49, 0) * CFrame.Angles(0, 0, math.rad(-2.5)), "Cuff")
        addRigPart("RightArm", Vector3.new(0.84, 1.62, 0.86), CFrame.new(1.33, 0.24, 0) * CFrame.Angles(0, 0, math.rad(2.5)), "Body")
        addRigPart("RightHandCuff", Vector3.new(0.85, 0.16, 0.87), CFrame.new(1.36, -0.49, 0) * CFrame.Angles(0, 0, math.rad(2.5)), "Cuff")

        addRigPart("LeftLeg", Vector3.new(0.84, 1.18, 0.88), CFrame.new(-0.45, -1.43, 0), "Body")
        addRigPart("RightLeg", Vector3.new(0.84, 1.18, 0.88), CFrame.new(0.45, -1.43, 0), "Body")

        -- Crisp 3D Stencil Initials "DS" flush on the chest front (+Z = +0.475)
        local chestZ = 0.475
        local dsSegs = {
            -- Letter 'D' (left)
            { Vector3.new(-0.45, 0.56, chestZ), Vector3.new(0.065, 0.38, 0.03) },
            { Vector3.new(-0.30, 0.72, chestZ), Vector3.new(0.28, 0.06, 0.03) },
            { Vector3.new(-0.30, 0.40, chestZ), Vector3.new(0.28, 0.06, 0.03) },
            { Vector3.new(-0.14, 0.56, chestZ), Vector3.new(0.065, 0.26, 0.03) },
            -- Letter 'S' (right)
            { Vector3.new(0.29, 0.72, chestZ), Vector3.new(0.34, 0.06, 0.03) },
            { Vector3.new(0.15, 0.64, chestZ), Vector3.new(0.065, 0.16, 0.03) },
            { Vector3.new(0.29, 0.56, chestZ), Vector3.new(0.34, 0.06, 0.03) },
            { Vector3.new(0.43, 0.48, chestZ), Vector3.new(0.065, 0.16, 0.03) },
            { Vector3.new(0.29, 0.40, chestZ), Vector3.new(0.34, 0.06, 0.03) },
        }
        for i, seg in ipairs(dsSegs) do
            addRigPart("LogoDS_" .. tostring(i), seg[2], CFrame.new(seg[1]), "Logo", nil, nil, Enum.Material.Neon)
        end

        -- 3D Octagonal Radar-Ticked Pedestal Base directly under the feet (Y = -2.02)
        local pedY = -2.13
        local pedR = 1.68
        local pedSide = 2 * pedR * math.tan(math.pi / 8)
        for step = 0, 3 do
            local ang = math.rad(step * 45)
            addRigPart("OctBase_" .. tostring(step), Vector3.new(pedR * 2, 0.20, pedSide), CFrame.new(0, pedY, 0) * CFrame.Angles(0, ang, 0), "BasePlate")
            addRigPart("OctSkirt_" .. tostring(step), Vector3.new((pedR + 0.05) * 2, 0.08, pedSide * 1.03), CFrame.new(0, pedY - 0.11, 0) * CFrame.Angles(0, ang, 0), "BaseSkirt")
        end
        for step = 0, 7 do
            local ang = math.rad(step * 45)
            local rotCF = CFrame.Angles(0, ang, 0)
            -- Bright octagon perimeter rim strip
            addRigPart("OctRim_" .. tostring(step), Vector3.new(pedSide * 0.96, 0.025, 0.045), CFrame.new(0, pedY + 0.105, 0) * rotCF * CFrame.new(0, 0, pedR - 0.02), "BaseRim", nil, nil, Enum.Material.Neon)
            -- Subtle radial radar tick inside rim
            addRigPart("OctTick_" .. tostring(step), Vector3.new(0.035, 0.02, 0.18), CFrame.new(0, pedY + 0.105, 0) * rotCF * CFrame.new(0, 0, pedR * 0.74), "BaseTick")
        end

        -- Exact Skeleton bone segments projected to Stage
        local jointPairs = {
            { j.HeadTop, j.Neck },
            { j.Neck, j.Pelvis },
            { j.Neck, j.LShoulder },
            { j.LShoulder, j.LElbow },
            { j.LElbow, j.LHand },
            { j.Neck, j.RShoulder },
            { j.RShoulder, j.RElbow },
            { j.RElbow, j.RHand },
            { j.Pelvis, j.LHip },
            { j.LHip, j.LKnee },
            { j.LKnee, j.LFoot },
            { j.Pelvis, j.RHip },
            { j.RHip, j.RKnee },
            { j.RKnee, j.RFoot },
        }
        for _, pair in ipairs(jointPairs) do
            table.insert(DummySkelWorldSegs, pair)
        end
    end

    -- 3D Tactical Loot Cube for Corpse / Container / Dropped Item / Quest Items
    local CubeParts: { BasePart } = {}
    do
        local cubeCF = CFrame.new(0, 0.08, 0) * CFrame.Angles(math.rad(18), math.rad(-32), 0)
        local cubeSpecs = {
            { "CubeBody", Vector3.new(2.25, 2.25, 2.25), CFrame.new() },
            { "CubeLid", Vector3.new(2.38, 0.24, 2.38), CFrame.new(0, 1.04, 0) },
            { "CubeBand", Vector3.new(2.33, 0.26, 2.33), CFrame.new(0, -0.04, 0) },
        }
        for _, spec in ipairs(cubeSpecs) do
            local p = Instance.new("Part")
            p.Name = spec[1]
            p.Size = spec[2]
            p.CFrame = cubeCF * spec[3]
            p.Anchored = true
            p.Material = Enum.Material.SmoothPlastic
            p.Color = Color3.fromRGB(36, 44, 61)
            p.Parent = nil
            table.insert(CubeParts, p)
        end
    end

    -- Subtle Translucent Fill, Hairline Box, Crisp Corners, Tracer & Arrow Overlays
    local BoxFillFrame = Instance.new("Frame")
    BoxFillFrame.Position = UDim2.fromOffset(curBoxX + 1, curBoxY + 1)
    BoxFillFrame.Size = UDim2.fromOffset(curBoxW - 2, curBoxH - 2)
    BoxFillFrame.BackgroundColor3 = THEME.Accent
    BoxFillFrame.BackgroundTransparency = 0.94
    BoxFillFrame.BorderSizePixel = 0
    BoxFillFrame.ZIndex = 5
    BoxFillFrame.Visible = false
    BoxFillFrame.Parent = Stage

    local BoxShadowFrame = Instance.new("Frame")
    BoxShadowFrame.Position = UDim2.fromOffset(curBoxX - 1, curBoxY - 1)
    BoxShadowFrame.Size = UDim2.fromOffset(curBoxW + 2, curBoxH + 2)
    BoxShadowFrame.BackgroundTransparency = 1
    BoxShadowFrame.ZIndex = 5
    BoxShadowFrame.Visible = false
    BoxShadowFrame.Parent = Stage
    addStroke(BoxShadowFrame, Color3.fromRGB(8, 10, 14), 1, 0.48)

    local BoxOutlineFrame = Instance.new("Frame")
    BoxOutlineFrame.Position = UDim2.fromOffset(curBoxX, curBoxY)
    BoxOutlineFrame.Size = UDim2.fromOffset(curBoxW, curBoxH)
    BoxOutlineFrame.BackgroundTransparency = 1
    BoxOutlineFrame.ZIndex = 6
    BoxOutlineFrame.Visible = false
    BoxOutlineFrame.Parent = Stage
    local boxStroke = addStroke(BoxOutlineFrame, THEME.Accent, 1, 0.04)

    local CornerFrames: { Frame } = {}
    for _ = 1, 8 do
        local f = Instance.new("Frame")
        f.BorderSizePixel = 0
        f.ZIndex = 7
        f.Visible = false
        f.Parent = Stage
        addStroke(f, Color3.fromRGB(8, 10, 14), 0.8, 0.55)
        table.insert(CornerFrames, f)
    end

    local PreviewTracer = Instance.new("Frame")
    PreviewTracer.AnchorPoint = Vector2.new(0.5, 0.5)
    PreviewTracer.BorderSizePixel = 0
    PreviewTracer.BackgroundTransparency = 0.28
    PreviewTracer.ZIndex = 4
    PreviewTracer.Visible = false
    PreviewTracer.Parent = Stage

    local PreviewArrow = Instance.new("TextLabel")
    PreviewArrow.BackgroundTransparency = 1
    PreviewArrow.Position = UDim2.fromOffset(STAGE_W - 24, 6)
    PreviewArrow.Size = UDim2.fromOffset(18, 18)
    PreviewArrow.Font = Enum.Font.GothamBold
    PreviewArrow.TextSize = 13
    PreviewArrow.Text = "^"
    PreviewArrow.Rotation = 35
    PreviewArrow.ZIndex = 9
    PreviewArrow.Visible = false
    PreviewArrow.Parent = Stage

    -- Normalized Skeleton Overlay inside Preview Stage (scales cleanly to Dummy or Corpse Cube)
    local SKEL_NORM_SEGS = {
        { Vector2.new(0.50, 0.14), Vector2.new(0.50, 0.22) },
        { Vector2.new(0.50, 0.22), Vector2.new(0.50, 0.55) },
        { Vector2.new(0.50, 0.22), Vector2.new(0.26, 0.26) },
        { Vector2.new(0.26, 0.26), Vector2.new(0.20, 0.41) },
        { Vector2.new(0.20, 0.41), Vector2.new(0.19, 0.57) },
        { Vector2.new(0.50, 0.22), Vector2.new(0.74, 0.26) },
        { Vector2.new(0.74, 0.26), Vector2.new(0.80, 0.41) },
        { Vector2.new(0.80, 0.41), Vector2.new(0.81, 0.57) },
        { Vector2.new(0.50, 0.55), Vector2.new(0.37, 0.58) },
        { Vector2.new(0.37, 0.58), Vector2.new(0.36, 0.78) },
        { Vector2.new(0.36, 0.78), Vector2.new(0.35, 0.95) },
        { Vector2.new(0.50, 0.55), Vector2.new(0.63, 0.58) },
        { Vector2.new(0.63, 0.58), Vector2.new(0.64, 0.78) },
        { Vector2.new(0.64, 0.78), Vector2.new(0.65, 0.95) },
    }
    local SkelLines: { Frame } = {}
    for _ = 1, #SKEL_NORM_SEGS do
        local line = Instance.new("Frame")
        line.AnchorPoint = Vector2.new(0.5, 0.5)
        line.BorderSizePixel = 0
        line.ZIndex = 6
        line.Visible = false
        line.Parent = Stage
        addStroke(line, Color3.fromRGB(8, 10, 14), 0.75, 0.55)
        table.insert(SkelLines, line)
    end

    -- 4 Exclusive Drop Zones (Top, Bottom, Left, Right)
    local ZONE_BOUNDS: { [string]: { X: number, Y: number, W: number, H: number } } = {
        Top = { X = 6, Y = 4, W = STAGE_W - 12, H = curBoxY - 8 },
        Bottom = { X = 6, Y = curBoxY + curBoxH + 4, W = STAGE_W - 12, H = STAGE_H - (curBoxY + curBoxH + 8) },
        Left = { X = 4, Y = curBoxY, W = curBoxX - 8, H = curBoxH },
        Right = { X = curBoxX + curBoxW + 4, Y = curBoxY, W = STAGE_W - (curBoxX + curBoxW + 8), H = curBoxH },
    }
    local ZoneHighlights: { [string]: { Frame: Frame, Stroke: UIStroke, Tag: TextLabel } } = {}
    for _, zName in ipairs({ "Top", "Bottom", "Left", "Right" }) do
        local b = ZONE_BOUNDS[zName]
        local zf = Instance.new("Frame")
        zf.Position = UDim2.fromOffset(b.X, b.Y)
        zf.Size = UDim2.fromOffset(b.W, b.H)
        zf.BackgroundColor3 = THEME.Accent
        zf.BackgroundTransparency = 1
        zf.ZIndex = 4
        zf.Visible = false
        zf.Parent = Stage
        addCorner(zf, 6)
        local zst = addStroke(zf, THEME.Border, 1, 0.35)

        local zt = Instance.new("TextLabel")
        zt.BackgroundTransparency = 1
        zt.Position = UDim2.fromOffset(4, 2)
        zt.Size = UDim2.new(1, -8, 0, 12)
        zt.Font = Enum.Font.GothamBold
        zt.TextSize = 9
        zt.TextColor3 = THEME.TextMuted
        zt.TextXAlignment = (zName == "Right") and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
        zt.Text = zName:upper()
        zt.Parent = zf

        ZoneHighlights[zName] = { Frame = zf, Stroke = zst, Tag = zt }
    end

    local InsertLine = Instance.new("Frame")
    InsertLine.Size = UDim2.fromOffset(64, 2)
    InsertLine.BackgroundColor3 = THEME.Accent
    InsertLine.BorderSizePixel = 0
    InsertLine.ZIndex = 16
    InsertLine.Visible = false
    InsertLine.Parent = Stage

    -- State for Preview interaction
    local DragLocked = false
    local DynamicItems: { Frame } = {}
    local SlotMeta: { [string]: { { Key: string, CenterY: number } } } = { Top = {}, Bottom = {}, Left = {}, Right = {} }
    local DraggingKey: string? = nil
    local DragGhost: TextLabel? = nil
    local HoverZone: string? = nil
    local HoverIndex = 1

    local CATEGORY_PREVIEW_META: { [string]: { Badge: string, IsCube: boolean, GetCfg: () -> any } } = {
        Player = { Badge = "PLAYER", IsCube = false, GetCfg = function() return Config.PlayerESP end },
        Npc = { Badge = "NPC", IsCube = false, GetCfg = function() return Config.AIESP end },
        Corpse = { Badge = "CORPSE", IsCube = true, GetCfg = function() return Config.CorpseESP end },
        Container = { Badge = "CONTAINER", IsCube = true, GetCfg = function() return Config.ContainerESP end },
        ["Dropped Item"] = { Badge = "DROPPED", IsCube = true, GetCfg = function() return Config.DroppedESP end },
        ["Quest Items"] = { Badge = "QUEST", IsCube = true, GetCfg = function() return Config.QuestESP end },
    }

    local function getActivePreviewTarget(): (string, any, boolean)
        local catKey = UI._ActiveEspCategory or "Player"
        local meta = CATEGORY_PREVIEW_META[catKey] or CATEGORY_PREVIEW_META.Player
        return catKey, meta.GetCfg(), meta.IsCube
    end

    local function getDefaultLayoutForCategory(catKey: string): { Top: { string }, Bottom: { string }, Left: { string }, Right: { string } }
        if catKey == "Player" then
            return createDefaultActorLayout(false)
        elseif catKey == "Npc" then
            return createDefaultActorLayout(true)
        end
        return createDefaultTagLayout(catKey)
    end

    local function applyStageGeometry(isCube: boolean)
        if isCube then
            curBoxX, curBoxY, curBoxW, curBoxH = 79, 156, 104, 104
            CharViewport.Position = UDim2.fromOffset(curBoxX - 16, curBoxY - 16)
            CharViewport.Size = UDim2.fromOffset(curBoxW + 32, curBoxH + 32)
            Pedestal.Size = UDim2.fromOffset(118, 22)
        else
            curBoxX, curBoxY, curBoxW, curBoxH = 88, 132, 86, 152
            CharViewport.Position = UDim2.fromOffset(curBoxX - 58, curBoxY - 14)
            CharViewport.Size = UDim2.fromOffset(curBoxW + 116, curBoxH + 46)
            Pedestal.Size = UDim2.fromOffset(118, 22)
        end
        Pedestal.Visible = isCube
        Pedestal.Position = UDim2.fromOffset(curBoxX + curBoxW * 0.5, curBoxY + curBoxH - 2)
        BoxFillFrame.Position = UDim2.fromOffset(curBoxX + 1, curBoxY + 1)
        BoxFillFrame.Size = UDim2.fromOffset(curBoxW - 2, curBoxH - 2)
        BoxShadowFrame.Position = UDim2.fromOffset(curBoxX - 1, curBoxY - 1)
        BoxShadowFrame.Size = UDim2.fromOffset(curBoxW + 2, curBoxH + 2)
        BoxOutlineFrame.Position = UDim2.fromOffset(curBoxX, curBoxY)
        BoxOutlineFrame.Size = UDim2.fromOffset(curBoxW, curBoxH)

        if isCube then
            DummyModel.Parent = nil
            for _, p in ipairs(CubeParts) do
                p.Parent = WorldM
            end
        else
            for _, p in ipairs(CubeParts) do
                p.Parent = nil
            end
            DummyModel.Parent = WorldM
        end

        local cw, ch = isCube and 16 or 15, isCube and 16 or 18
        local cSpecs = {
            { curBoxX, curBoxY, cw, 1 }, { curBoxX, curBoxY, 1, ch },
            { curBoxX + curBoxW - cw, curBoxY, cw, 1 }, { curBoxX + curBoxW - 1, curBoxY, 1, ch },
            { curBoxX, curBoxY + curBoxH - 1, cw, 1 }, { curBoxX, curBoxY + curBoxH - ch, 1, ch },
            { curBoxX + curBoxW - cw, curBoxY + curBoxH - 1, cw, 1 }, { curBoxX + curBoxW - 1, curBoxY + curBoxH - ch, 1, ch },
        }
        for i, sp in ipairs(cSpecs) do
            local cf = CornerFrames[i]
            cf.Position = UDim2.fromOffset(sp[1], sp[2])
            cf.Size = UDim2.fromOffset(sp[3], sp[4])
        end

        if not isCube then
            local vpX, vpY = curBoxX - 58, curBoxY - 14
            local vpW, vpH = curBoxW + 116, curBoxH + 46
            local halfTan = math.tan(math.rad(DummyCam.FieldOfView * 0.5))
            local aspect = vpW / vpH
            local camCF = DummyCam.CFrame
            local function projectDummyPt(wp: Vector3): Vector2
                local rel = camCF:PointToObjectSpace(wp)
                local zDist = math.max(-rel.Z, 0.1)
                local halfH = zDist * halfTan
                local halfW = halfH * aspect
                local u = 0.5 + rel.X / (2 * halfW)
                local v = 0.5 - rel.Y / (2 * halfH)
                return Vector2.new(vpX + u * vpW, vpY + v * vpH)
            end
            for i, seg in ipairs(DummySkelWorldSegs) do
                local p1 = projectDummyPt(seg[1])
                local p2 = projectDummyPt(seg[2])
                local diff = p2 - p1
                local line = SkelLines[i]
                line.Position = UDim2.fromOffset((p1.X + p2.X) * 0.5, (p1.Y + p2.Y) * 0.5)
                line.Size = UDim2.fromOffset(math.max(diff.Magnitude, 2), 2)
                line.Rotation = math.deg(math.atan2(diff.Y, diff.X))
            end
        else
            local skPadX, skPadY = curBoxW * 0.14, curBoxH * 0.08
            local skX, skY = curBoxX + skPadX, curBoxY + skPadY
            local skW, skH = curBoxW - skPadX * 2, curBoxH - skPadY * 2
            for i, seg in ipairs(SKEL_NORM_SEGS) do
                local p1 = Vector2.new(skX + seg[1].X * skW, skY + seg[1].Y * skH)
                local p2 = Vector2.new(skX + seg[2].X * skW, skY + seg[2].Y * skH)
                local diff = p2 - p1
                local line = SkelLines[i]
                line.Position = UDim2.fromOffset((p1.X + p2.X) * 0.5, (p1.Y + p2.Y) * 0.5)
                line.Size = UDim2.fromOffset(math.max(diff.Magnitude, 2), 2)
                line.Rotation = math.deg(math.atan2(diff.Y, diff.X))
            end
        end

        ZONE_BOUNDS.Top = { X = 6, Y = 4, W = STAGE_W - 12, H = curBoxY - 8 }
        ZONE_BOUNDS.Bottom = { X = 6, Y = curBoxY + curBoxH + 4, W = STAGE_W - 12, H = STAGE_H - (curBoxY + curBoxH + 8) }
        ZONE_BOUNDS.Left = { X = 4, Y = curBoxY, W = curBoxX - 8, H = curBoxH }
        ZONE_BOUNDS.Right = { X = curBoxX + curBoxW + 4, Y = curBoxY, W = STAGE_W - (curBoxX + curBoxW + 8), H = curBoxH }
        for zName, z in pairs(ZoneHighlights) do
            local b = ZONE_BOUNDS[zName]
            z.Frame.Position = UDim2.fromOffset(b.X, b.Y)
            z.Frame.Size = UDim2.fromOffset(b.W, b.H)
        end
    end

    local PREVIEW_SAMPLES: { [string]: string } = {
        Name = "Player",
        Distance = "249m",
        Health = "100 HP",
        Weapon = "AK74",
        KDR = "KDR: 1.35",
        Reports = "[!] Rep: 12",
        Downed = "[DOWNED]",
        Value = "$8.2k",
        Respawn = "Ready",
    }

    local function getPreviewItemsEnabled(cfg: any, catKey: string): { [string]: { Text: string, Color: Color3 } }
        local map: { [string]: { Text: string, Color: Color3 } } = {}
        if catKey == "Player" or catKey == "Npc" then
            local isAI = (catKey == "Npc")
            local baseColor = isAI and cfg.Color or cfg.EnemyColor
            if cfg.Name then
                map.Name = { Text = isAI and "[NPC] Bandit" or "Player", Color = baseColor }
            end
            if cfg.HealthText then
                map.Health = { Text = "100 HP", Color = THEME.Success }
            end
            if cfg.Distance then
                map.Distance = { Text = "249m", Color = Color3.fromRGB(226, 232, 240) }
            end
            if cfg.Weapon then
                map.Weapon = { Text = "AK74", Color = Color3.fromRGB(203, 213, 225) }
            end
            if not isAI then
                if cfg.KDR then
                    map.KDR = { Text = "KDR: 1.35", Color = Color3.fromRGB(148, 163, 184) }
                end
                if cfg.Reports then
                    map.Reports = { Text = "[!] Rep: 12", Color = Color3.fromRGB(251, 146, 60) }
                end
                if cfg.DownedBadge then
                    map.Downed = { Text = "[DOWNED]", Color = Config.PlayerESP.DownedColor }
                end
            end
            return map
        end

        local tagColor = cfg.Color or THEME.Accent
        if cfg.Name then
            local sampleName = (catKey == "Corpse" and "Corpse (Jake)")
                or (catKey == "Container" and "Military Crate")
                or (catKey == "Dropped Item" and "M4A1 Carbine")
                or "Flight Recorder"
            map.Name = { Text = sampleName, Color = tagColor }
        end
        if cfg.Distance then
            local distStr = (catKey == "Corpse" and "142m")
                or (catKey == "Container" and "84m")
                or (catKey == "Dropped Item" and "36m")
                or "195m"
            map.Distance = { Text = distStr, Color = Color3.fromRGB(226, 232, 240) }
        end
        if cfg.Value and (catKey == "Corpse" or catKey == "Container" or catKey == "Dropped Item") then
            local valStr = (catKey == "Corpse" and "$14.5k") or (catKey == "Container" and "$8.2k") or "$6.5k"
            local valCol = (catKey == "Corpse") and Color3.fromRGB(74, 222, 128) or Color3.fromRGB(250, 204, 21)
            map.Value = { Text = valStr, Color = valCol }
        end
        if catKey == "Container" and cfg.Respawn then
            map.Respawn = { Text = "Ready", Color = Color3.fromRGB(52, 211, 153) }
        end
        return map
    end

    local function updateStageZoneVisuals(activeZone: string?)
        local dragging = (DraggingKey ~= nil)
        for zName, z in pairs(ZoneHighlights) do
            z.Frame.Visible = dragging
            local match = (activeZone == zName)
            z.Frame.BackgroundTransparency = match and 0.85 or 0.96
            z.Stroke.Color = match and THEME.Accent or THEME.Border
            z.Stroke.Transparency = match and 0 or 0.4
            z.Tag.TextColor3 = match and THEME.Accent or THEME.TextMuted
        end
    end

    local function resolveZoneFromPoint(stagePos: Vector2): (string, number, number)
        local zone: string
        if stagePos.Y < curBoxY then
            zone = "Top"
        elseif stagePos.Y > curBoxY + curBoxH then
            zone = "Bottom"
        elseif stagePos.X < curBoxX + curBoxW * 0.5 then
            zone = "Left"
        else
            zone = "Right"
        end

        local items = SlotMeta[zone]
        local insertAt = #items + 1
        local lineY = ZONE_BOUNDS[zone].Y + 16
        for i, item in ipairs(items) do
            if stagePos.Y < item.CenterY then
                insertAt = i
                lineY = item.CenterY - 8
                break
            end
            lineY = item.CenterY + 8
        end
        return zone, insertAt, lineY
    end

    local GuiSvc = game:GetService("GuiService")
    local function getMouseAbs(): Vector2
        local inset = GuiSvc:GetGuiInset()
        return UserInputService:GetMouseLocation() - inset
    end

    local function repositionPreview()
        local mwPos = MainWindow.AbsolutePosition
        local mwSize = MainWindow.AbsoluteSize
        local rootPos = ScreenGui.AbsolutePosition
        local cam = Workspace.CurrentCamera
        local vpW = cam and cam.ViewportSize.X or 1920
        local rightX = mwPos.X + mwSize.X + 12
        local targetX = rightX
        if rightX + PreviewFrame.AbsoluteSize.X > vpW - 8 then
            targetX = math.max(8, mwPos.X - PreviewFrame.AbsoluteSize.X - 12)
        end
        PreviewFrame.Position = UDim2.fromOffset(targetX - rootPos.X, mwPos.Y - rootPos.Y)
    end

    function UI.Preview.Refresh()
        for _, item in ipairs(DynamicItems) do
            item:Destroy()
        end
        table.clear(DynamicItems)
        SlotMeta = { Top = {}, Bottom = {}, Left = {}, Right = {} }

        local catKey, cfg, isCube = getActivePreviewTarget()
        local meta = CATEGORY_PREVIEW_META[catKey] or CATEGORY_PREVIEW_META.Player
        PCatBadge.Text = meta.Badge
        applyStageGeometry(isCube)

        local primaryCol = isCube and cfg.Color or (catKey == "Npc" and cfg.Color or cfg.EnemyColor)
        local chamsOn = isCube and (cfg.Chams == true) or (cfg.Highlights == true)
        local chamsCol = cfg.ChamsFill or primaryCol

        -- Dummy / Cube appearance (Chams / Highlights vs Sculpted Studio Shading)
        pedestalStroke.Color = chamsOn and chamsCol or primaryCol
        pedestalInnerStroke.Color = chamsOn and (cfg.ChamsOutline or Color3.new(1, 1, 1)) or THEME.Border
        if isCube then
            local lidCol = chamsOn and chamsCol:Lerp(Color3.new(1, 1, 1), 0.14) or Color3.fromRGB(48, 59, 80)
            local bandCol = chamsOn and (cfg.ChamsOutline or Color3.new(1, 1, 1)) or primaryCol:Lerp(Color3.fromRGB(48, 59, 80), 0.45)
            if CubeParts[1] then CubeParts[1].Color = chamsOn and chamsCol or Color3.fromRGB(36, 44, 61) end
            if CubeParts[2] then CubeParts[2].Color = lidCol end
            if CubeParts[3] then CubeParts[3].Color = bandCol end
            CharViewport.ImageColor3 = chamsOn and chamsCol or Color3.new(1, 1, 1)
        else
            local outlineGlow = cfg.ChamsOutline or Color3.new(1, 1, 1)
            for _, rec in ipairs(DummyParts) do
                local role = rec.Role
                if role == "BasePlate" then
                    rec.Part.Color = Color3.fromRGB(30, 32, 37)
                elseif role == "BaseSkirt" then
                    rec.Part.Color = Color3.fromRGB(14, 16, 20)
                elseif role == "BaseRim" then
                    rec.Part.Color = chamsOn and outlineGlow or Color3.fromRGB(220, 226, 236)
                elseif role == "BaseTick" then
                    rec.Part.Color = Color3.fromRGB(108, 118, 134)
                elseif role == "Logo" then
                    rec.Part.Color = chamsOn and outlineGlow or Color3.fromRGB(205, 215, 230)
                elseif chamsOn then
                    rec.Part.Color = (role == "Cuff") and chamsCol:Lerp(Color3.fromRGB(12, 14, 18), 0.18) or chamsCol
                else
                    rec.Part.Color = (role == "Cuff") and Color3.fromRGB(22, 25, 31) or Color3.fromRGB(14, 16, 20)
                end
            end
            CharViewport.ImageColor3 = Color3.new(1, 1, 1)
        end

        -- Fill, Box & Corners
        BoxFillFrame.Visible = (cfg.Box == "2D" or cfg.Box == "Corner")
        BoxFillFrame.BackgroundColor3 = primaryCol
        BoxShadowFrame.Visible = (cfg.Box == "2D")
        BoxOutlineFrame.Visible = (cfg.Box == "2D")
        boxStroke.Color = primaryCol
        for _, cf in ipairs(CornerFrames) do
            cf.Visible = (cfg.Box == "Corner")
            cf.BackgroundColor3 = primaryCol
        end

        -- Skeleton overlay (Player, Npc, Corpse)
        local showSkel = (cfg.Skeleton == true) and (not isCube or catKey == "Corpse")
        local skelPreviewCol = strengthenColor(cfg.SkeletonColor or primaryCol)
        for _, sk in ipairs(SkelLines) do
            sk.Visible = showSkel
            sk.BackgroundColor3 = skelPreviewCol
        end

        -- Tracer & Arrow visual indicator inside Preview Stage
        if cfg.Tracers == true then
            local trStart = Vector2.new(STAGE_W * 0.5, STAGE_H - 4)
            local trEnd = Vector2.new(curBoxX + curBoxW * 0.5, curBoxY + curBoxH)
            local diff = trEnd - trStart
            PreviewTracer.Position = UDim2.fromOffset((trStart.X + trEnd.X) * 0.5, (trStart.Y + trEnd.Y) * 0.5)
            PreviewTracer.Size = UDim2.fromOffset(math.max(diff.Magnitude, 2), 1.5)
            PreviewTracer.Rotation = math.deg(math.atan2(diff.Y, diff.X))
            PreviewTracer.BackgroundColor3 = primaryCol
            PreviewTracer.Visible = true
        else
            PreviewTracer.Visible = false
        end
        PreviewArrow.Visible = (cfg.Arrows == true)
        PreviewArrow.TextColor3 = primaryCol

        local activeValues = getPreviewItemsEnabled(cfg, catKey)
        local layout = cfg.Layout or getDefaultLayoutForCategory(catKey)
        local lineStep = 15

        local function bindDraggable(widget: GuiButton, key: string)
            Session.Bind(widget.InputBegan, function(input: InputObject)
                if DragLocked or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                    return
                end
                DraggingKey = key
                if DragGhost then
                    DragGhost:Destroy()
                end
                local ghost = Instance.new("TextLabel")
                ghost.Size = UDim2.fromOffset(78, 18)
                ghost.BackgroundColor3 = THEME.BgControl
                ghost.Font = Enum.Font.GothamBold
                ghost.TextSize = 11
                ghost.TextColor3 = THEME.Accent
                ghost.Text = key == "HealthBar" and "HealthBar" or (PREVIEW_SAMPLES[key] or key)
                ghost.ZIndex = 70
                ghost.Parent = PopupLayer
                addCorner(ghost, 4)
                addStroke(ghost, THEME.Accent, 1, 0)
                DragGhost = ghost
                local ma = getMouseAbs()
                local pAbs = PopupLayer.AbsolutePosition
                ghost.Position = UDim2.fromOffset(ma.X - pAbs.X - 39, ma.Y - pAbs.Y - 9)
                updateStageZoneVisuals(nil)
            end)
        end

        for _, zoneName in ipairs({ "Top", "Bottom", "Left", "Right" }) do
            local list = layout[zoneName] or {}
            local hasHpBar = false
            local textKeys: { string } = {}
            for _, key in ipairs(list) do
                if key == "HealthBar" then
                    if not isCube and cfg.HealthBar then
                        hasHpBar = true
                    end
                elseif activeValues[key] then
                    table.insert(textKeys, key)
                end
            end

            if hasHpBar then
                local barBtn = Instance.new("TextButton")
                barBtn.Text = ""
                barBtn.AutoButtonColor = false
                barBtn.BackgroundTransparency = 1
                barBtn.ZIndex = 12
                barBtn.Parent = Stage

                local barBg = Instance.new("Frame")
                barBg.BackgroundColor3 = Color3.new(0, 0, 0)
                barBg.BorderSizePixel = 0
                barBg.ZIndex = 12
                barBg.Parent = barBtn
                addCorner(barBg, 2)

                local fill = Instance.new("Frame")
                fill.BackgroundColor3 = THEME.Success
                fill.BorderSizePixel = 0
                fill.ZIndex = 12
                fill.Parent = barBg
                addCorner(fill, 2)

                if zoneName == "Left" or zoneName == "Right" then
                    local grabX = (zoneName == "Left") and (curBoxX - 12) or (curBoxX + curBoxW)
                    barBtn.Position = UDim2.fromOffset(grabX, curBoxY)
                    barBtn.Size = UDim2.fromOffset(13, curBoxH)
                    barBg.Position = UDim2.fromOffset(4, 0)
                    barBg.Size = UDim2.fromOffset(5, curBoxH)
                    fill.Position = UDim2.fromOffset(1, math.floor(curBoxH * 0.16))
                    fill.Size = UDim2.fromOffset(3, math.floor(curBoxH * 0.84) - 1)
                    table.insert(SlotMeta[zoneName], { Key = "HealthBar", CenterY = curBoxY + curBoxH * 0.5 })
                else
                    local grabY = (zoneName == "Top") and (curBoxY - 12) or (curBoxY + curBoxH - 1)
                    local grabH = (zoneName == "Top") and 13 or 11
                    barBtn.Position = UDim2.fromOffset(curBoxX, grabY)
                    barBtn.Size = UDim2.fromOffset(curBoxW, grabH)
                    barBg.Position = UDim2.fromOffset(0, 4)
                    barBg.Size = UDim2.fromOffset(curBoxW, 5)
                    fill.Position = UDim2.fromOffset(1, 1)
                    fill.Size = UDim2.fromOffset(math.floor(curBoxW * 0.84), 3)
                    table.insert(SlotMeta[zoneName], { Key = "HealthBar", CenterY = grabY + 6 })
                end
                bindDraggable(barBtn, "HealthBar")
                table.insert(DynamicItems, barBtn)
            end

            local n = #textKeys
            if n > 0 then
                local barPad = hasHpBar and 10 or 3
                local totalTextH = n * lineStep
                local sideStartY = curBoxY + math.max((curBoxH - totalTextH) * 0.5, 2)

                for idx, key in ipairs(textKeys) do
                    local info = activeValues[key]
                    local pill = Instance.new("TextButton")
                    pill.AutoButtonColor = false
                    pill.BackgroundColor3 = THEME.BgMain
                    pill.BackgroundTransparency = 0.65
                    pill.Font = Enum.Font.GothamBold
                    pill.TextSize = 11
                    pill.TextColor3 = info.Color
                    pill.Text = info.Text
                    pill.ZIndex = 13
                    pill.Parent = Stage
                    addCorner(pill, 3)

                    local yPos = 0
                    if zoneName == "Top" then
                        pill.Size = UDim2.fromOffset(118, lineStep - 1)
                        pill.TextXAlignment = Enum.TextXAlignment.Center
                        yPos = (curBoxY - barPad - 2) - (n - idx + 1) * lineStep
                        pill.Position = UDim2.fromOffset(curBoxX + curBoxW * 0.5 - 59, yPos)
                    elseif zoneName == "Bottom" then
                        pill.Size = UDim2.fromOffset(118, lineStep - 1)
                        pill.TextXAlignment = Enum.TextXAlignment.Center
                        yPos = curBoxY + curBoxH + barPad + (idx - 1) * lineStep
                        pill.Position = UDim2.fromOffset(curBoxX + curBoxW * 0.5 - 59, yPos)
                    elseif zoneName == "Left" then
                        local w = math.max(curBoxX - barPad - 8, 54)
                        pill.Size = UDim2.fromOffset(w, lineStep - 1)
                        pill.TextXAlignment = Enum.TextXAlignment.Right
                        yPos = sideStartY + (idx - 1) * lineStep
                        pill.Position = UDim2.fromOffset(curBoxX - barPad - w - 3, yPos)
                    elseif zoneName == "Right" then
                        local w = math.max(STAGE_W - (curBoxX + curBoxW + barPad + 6), 54)
                        pill.Size = UDim2.fromOffset(w, lineStep - 1)
                        pill.TextXAlignment = Enum.TextXAlignment.Left
                        yPos = sideStartY + (idx - 1) * lineStep
                        pill.Position = UDim2.fromOffset(curBoxX + curBoxW + barPad + 3, yPos)
                    end

                    table.insert(SlotMeta[zoneName], { Key = key, CenterY = yPos + lineStep * 0.5 })
                    bindDraggable(pill, key)
                    table.insert(DynamicItems, pill)
                end
            end
        end
    end

    function UI.Preview.SyncVisibility()
        local isVisuals = (CurrentTab == VisualsTab)
        local hasMeta = (UI._ActiveEspCategory ~= nil and CATEGORY_PREVIEW_META[UI._ActiveEspCategory] ~= nil)
        local show = MainWindow.Visible and isVisuals and hasMeta
        PreviewFrame.Visible = show
        if show then
            repositionPreview()
            UI.Preview.Refresh()
        end
    end

    Session.Bind(MainWindow:GetPropertyChangedSignal("AbsolutePosition"), repositionPreview)
    table.insert(UI._OnChange, UI.Preview.Refresh)

    Session.Bind(LockBtn.MouseButton1Click, function()
        DragLocked = not DragLocked
        LockBtn.Text = DragLocked and "Lock" or "Free"
        LockBtn.TextColor3 = DragLocked and THEME.Accent or THEME.TextSecondary
        lockStroke.Color = DragLocked and THEME.Accent or THEME.Border
    end)

    Session.Bind(ResetBtn.MouseButton1Click, function()
        local catKey, cfg = getActivePreviewTarget()
        local meta = CATEGORY_PREVIEW_META[catKey]
        cfg.Layout = getDefaultLayoutForCategory(catKey)
        UI.Preview.Refresh()
        UI.Notify("Preview Layout Reset", (meta and meta.Badge or catKey) .. " ESP layout restored.", "info")
    end)

    Session.Bind(UserInputService.InputChanged, function(input: InputObject)
        if not DraggingKey or input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end
        local ma = getMouseAbs()
        if DragGhost then
            local pAbs = PopupLayer.AbsolutePosition
            DragGhost.Position = UDim2.fromOffset(ma.X - pAbs.X - 39, ma.Y - pAbs.Y - 9)
        end
        local stPos = Stage.AbsolutePosition
        local rel = Vector2.new(ma.X - stPos.X, ma.Y - stPos.Y)
        if rel.X >= -18 and rel.X <= STAGE_W + 18 and rel.Y >= -18 and rel.Y <= STAGE_H + 18 then
            local z, idx, lineY = resolveZoneFromPoint(rel)
            HoverZone = z
            HoverIndex = idx
            updateStageZoneVisuals(z)
            local zb = ZONE_BOUNDS[z]
            InsertLine.Size = UDim2.fromOffset(math.min(zb.W - 8, 92), 2)
            InsertLine.Position = UDim2.fromOffset(zb.X + math.max((zb.W - math.min(zb.W - 8, 92)) * 0.5, 4), math.clamp(lineY, zb.Y + 4, zb.Y + zb.H - 4))
            InsertLine.Visible = true
        else
            HoverZone = nil
            updateStageZoneVisuals(nil)
            InsertLine.Visible = false
        end
    end)

    Session.Bind(UserInputService.InputEnded, function(input: InputObject)
        if not DraggingKey or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return
        end
        local key = DraggingKey
        DraggingKey = nil
        if DragGhost then
            DragGhost:Destroy()
            DragGhost = nil
        end
        updateStageZoneVisuals(nil)
        InsertLine.Visible = false

        if HoverZone then
            local _, cfg = getActivePreviewTarget()
            local layout = cfg.Layout
            -- Remove from prior zone first, adjusting target index if moving down within same zone
            for zName, list in pairs(layout) do
                for i = #list, 1, -1 do
                    if list[i] == key then
                        table.remove(list, i)
                        if zName == HoverZone and i < HoverIndex then
                            HoverIndex -= 1
                        end
                    end
                end
            end
            local destList = layout[HoverZone]
            local clampedIdx = math.clamp(HoverIndex, 1, #destList + 1)
            table.insert(destList, clampedIdx, key)
            UI.Preview.Refresh()
        end
        HoverZone = nil
    end)
end)()

-- ============================================================================
-- 11. INPUT HANDLING & MAIN FRAME LOOP
-- ============================================================================
local WindowVisible = true
local function setMenuVisible(vis: boolean)
    WindowVisible = vis
    MainWindow.Visible = vis
    if not vis then
        closeActivePopup()
    end
    if type(UI.Preview.SyncVisibility) == "function" then
        UI.Preview.SyncVisibility()
    end
end
Misc._TargetHud = TargetHudFrame
Misc._SetMenuVisible = setMenuVisible
Misc._GetMenuVisible = function()
    return WindowVisible
end
Combat._IsMenuOpen = Misc._GetMenuVisible

Session.Bind(MinBtn.MouseButton1Click, function()
    setMenuVisible(false)
    UI.Notify("Menu Hidden", "Press " .. formatBindName(Config.Settings.MenuKey) .. " to reopen.", "info")
end)

Session.Bind(UserInputService.InputBegan, function(input: InputObject, gameProcessed: boolean)
    local code: BindValue = (input.KeyCode ~= Enum.KeyCode.Unknown) and input.KeyCode or input.UserInputType

    -- Active keybind rebind listener
    if ListeningPicker then
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            return
        end
        local done = ListeningPicker
        ListeningPicker = nil
        if code == Enum.KeyCode.Escape or code == Enum.KeyCode.Backspace then
            done.Set(Enum.KeyCode.Unknown)
        else
            done.Set(code)
        end
        done.Refresh()
        return
    end

    if gameProcessed then
        return
    end

    KeyHoldStates[code] = true

    if code ~= Enum.KeyCode.Unknown and code == Config.Misc.PanicKey then
        Misc.SetPanicMode(not Config.Misc.PanicMode, true)
        UI.RefreshAll()
        return
    end

    if code == Config.Settings.MenuKey then
        setMenuVisible(not WindowVisible)
        return
    end

    if code ~= Enum.KeyCode.Unknown and code == Config.Misc.PassDoorKey then
        if Config.Misc.PassDoor and Config.Misc.PassDoorMode == "Toggle" then
            ToggleStates.PassDoor = not (ToggleStates.PassDoor ~= false)
            UI.Notify("Pass Door", ToggleStates.PassDoor and "Engaged" or "Standby", ToggleStates.PassDoor and "success" or "info")
        elseif Config.Misc.PassDoorMode == "Always" then
            Config.Misc.PassDoor = not Config.Misc.PassDoor
            if not Config.Misc.PassDoor then
                Misc.RestoreDoors()
            end
            UI.RefreshAll()
            UI.Notify("Pass Door", Config.Misc.PassDoor and "Enabled" or "Disabled", Config.Misc.PassDoor and "success" or "info")
        end
    end

    if code ~= Enum.KeyCode.Unknown and code == Config.Aimbot.Key then
        if Config.Aimbot.Enabled and Config.Aimbot.Mode == "Toggle" then
            ToggleStates.Aimbot = not (ToggleStates.Aimbot ~= false)
            UI.Notify("Aimbot", ToggleStates.Aimbot and "Engaged" or "Standby", ToggleStates.Aimbot and "success" or "info")
        elseif Config.Aimbot.Mode == "Always" then
            Config.Aimbot.Enabled = not Config.Aimbot.Enabled
            UI.RefreshAll()
            UI.Notify("Aimbot", Config.Aimbot.Enabled and "Enabled" or "Disabled", Config.Aimbot.Enabled and "success" or "info")
        end
    end
    if code ~= Enum.KeyCode.Unknown and code == Config.SilentAim.Key then
        if Config.SilentAim.Enabled and Config.SilentAim.Mode == "Toggle" then
            ToggleStates.SilentAim = not (ToggleStates.SilentAim ~= false)
            UI.Notify("Silent Aim", ToggleStates.SilentAim and "Engaged" or "Standby", ToggleStates.SilentAim and "success" or "info")
        elseif Config.SilentAim.Mode == "Always" then
            Config.SilentAim.Enabled = not Config.SilentAim.Enabled
            UI.RefreshAll()
            UI.Notify("Silent Aim", Config.SilentAim.Enabled and "Enabled" or "Disabled", Config.SilentAim.Enabled and "success" or "info")
        end
    end
    if code ~= Enum.KeyCode.Unknown and code == Config.Targeting.AddFriendKey then
        local plr, added = Targeting.ToggleNearestFriend()
        if plr then
            UI.Notify("Not Attack", string.format("%s %s (friend / do not attack)", plr.DisplayName, added and "added" or "removed"), added and "success" or "info")
        else
            UI.Notify("Not Attack", "No player near crosshair", "info")
        end
    end
    if code ~= Enum.KeyCode.Unknown and code == Config.TriggerBot.Key then
        if Config.TriggerBot.Enabled and Config.TriggerBot.Mode == "Toggle" then
            ToggleStates.TriggerBot = not (ToggleStates.TriggerBot ~= false)
            UI.Notify("TriggerBot", ToggleStates.TriggerBot and "Engaged" or "Standby", ToggleStates.TriggerBot and "success" or "info")
        elseif Config.TriggerBot.Mode == "Always" then
            Config.TriggerBot.Enabled = not Config.TriggerBot.Enabled
            UI.RefreshAll()
            UI.Notify("TriggerBot", Config.TriggerBot.Enabled and "Enabled" or "Disabled", Config.TriggerBot.Enabled and "success" or "info")
        end
    end
end)

Session.Bind(UserInputService.InputEnded, function(input: InputObject)
    local code: BindValue = (input.KeyCode ~= Enum.KeyCode.Unknown) and input.KeyCode or input.UserInputType
    KeyHoldStates[code] = false
end)

local fpsAccum, fpsFrames, displayFps = 0, 0, 60
local lastWmUpdate = 0

Session.Bind(RunService.RenderStepped, function(dt: number)
    local cam = Workspace.CurrentCamera
    if not cam then
        return
    end

    -- Misc subsystem (Panic Sync, Pass Door, Fast Trade, Screen Effects)
    Misc.Step()

    -- Combat loops
    stepAimbot(dt)
    stepTriggerBot()

    local panicHideVis = Config.Misc.PanicMode and Config.Misc.PanicHideVisuals
    local panicDisableCombat = Config.Misc.PanicMode and Config.Misc.PanicDisableCombat

    -- World & FOV
    World.Step(panicHideVis)

    if panicHideVis then
        Misc._HideAllVisualsNow()
        return
    end

    -- Aimbot & Silent Aim Independent FOV Circles
    local fovPos = Targeting.GetAimOrigin2D()
    local showAimFov = Config.Aimbot.ShowFOV and not panicDisableCombat and Config.Aimbot.Enabled
    local showSilentFov = Config.Aimbot.ShowFOV and not panicDisableCombat and Config.SilentAim.Enabled and Config.SilentAim.UseFOV

    if FOVCircle then
        if showAimFov then
            local fovRad = Targeting.GetEffectiveFOVRadius("Aimbot")
            if FOVCircleOutline then
                FOVCircleOutline.Position = fovPos
                FOVCircleOutline.Radius = fovRad
                FOVCircleOutline.Visible = not Config.Aimbot.FOVFilled
            end
            FOVCircle.Position = fovPos
            FOVCircle.Radius = fovRad
            FOVCircle.Color = Config.Aimbot.FOVColor
            FOVCircle.Filled = Config.Aimbot.FOVFilled
            FOVCircle.Transparency = Config.Aimbot.FOVFilled and drawTrans(0.16) or drawTrans(0.95)
            FOVCircle.Visible = true
        else
            if FOVCircleOutline then
                FOVCircleOutline.Visible = false
            end
            FOVCircle.Visible = false
        end
    end

    if Combat._SilentFOV then
        if showSilentFov then
            local sRad = Targeting.GetEffectiveFOVRadius("Silent")
            if Combat._SilentFOVOutline then
                Combat._SilentFOVOutline.Position = fovPos
                Combat._SilentFOVOutline.Radius = sRad
                Combat._SilentFOVOutline.Visible = true
            end
            Combat._SilentFOV.Position = fovPos
            Combat._SilentFOV.Radius = sRad
            Combat._SilentFOV.Color = showAimFov and Color3.fromRGB(168, 85, 247) or Config.Aimbot.FOVColor
            Combat._SilentFOV.Visible = true
        else
            if Combat._SilentFOVOutline then
                Combat._SilentFOVOutline.Visible = false
            end
            Combat._SilentFOV.Visible = false
        end
    end

    -- Silent Aim Target Indicator Line & Lock Dot
    if Config.SilentAim.Enabled and Config.SilentAim.TargetLine and not panicDisableCombat
        and isModeActive("SilentAim", Config.SilentAim.Enabled, Config.SilentAim.Mode, Config.SilentAim.Key)
    then
        local st = ActiveLockedTarget
        if Config.Aimbot.Enabled and isModeActive("Aimbot", Config.Aimbot.Enabled, Config.Aimbot.Mode, Config.Aimbot.Key) and Combat._FindSilentTarget then
            st = Combat._FindSilentTarget(Delta.GetShotOrigin(), false)
        end
        if st and st.Model.Parent then
            local predWorld = Delta.PredictAimPosition(
                Delta.GetShotOrigin(),
                st.Part,
                Config.SilentAim.Prediction,
                Config.SilentAim.DropComp,
                nil,
                st.AimPointWorld
            )
            local sp, onScr = cam:WorldToViewportPoint(predWorld)
            if onScr then
                local pt2d = Vector2.new(sp.X, sp.Y)
                if Combat._SilentLine then
                    Combat._SilentLine.From = Targeting.GetAimOrigin2D()
                    Combat._SilentLine.To = pt2d
                    Combat._SilentLine.Color = Config.Aimbot.FOVColor
                    Combat._SilentLine.Visible = true
                end
                if Combat._SilentDot then
                    Combat._SilentDot.Position = pt2d
                    Combat._SilentDot.Color = Config.Aimbot.FOVColor
                    Combat._SilentDot.Visible = true
                end
            else
                if Combat._SilentLine then Combat._SilentLine.Visible = false end
                if Combat._SilentDot then Combat._SilentDot.Visible = false end
            end
        else
            if Combat._SilentLine then Combat._SilentLine.Visible = false end
            if Combat._SilentDot then Combat._SilentDot.Visible = false end
        end
    else
        if Combat._SilentLine then Combat._SilentLine.Visible = false end
        if Combat._SilentDot then Combat._SilentDot.Visible = false end
    end

    -- ESP & Radar Renders
    local vp = cam.ViewportSize
    for _, entry in pairs(Actors) do
        renderActorESP(entry, cam, vp)
    end
    for _, tag in pairs(WorldTags) do
        renderTagESP(tag, cam, vp)
    end
    if World.RenderRadar then
        World.RenderRadar(cam, vp)
    end

    -- Target HUD
    if Config.Settings.TargetHUD and ActiveLockedTarget and ActiveLockedTarget.Model.Parent then
        local t = ActiveLockedTarget
        local dispName = t.Player and t.Player.DisplayName or t.Model.Name
        local wep = Delta.GetHeldWeaponName(t.Player, t.Model) or "Unarmed"
        TargetHudName.Text = (t.IsAI and "[AI] " or "") .. dispName
        TargetHudInfo.Text = string.format("%.0f HP  •  %.0fm  •  %s", t.Health, t.WorldDist, wep)
        local ratio = math.clamp(t.Health / t.MaxHealth, 0, 1)
        TargetHpFill.Size = UDim2.fromScale(ratio, 1)
        TargetHpFill.BackgroundColor3 = computeHealthColor(ratio)
        TargetHudFrame.Visible = true
    else
        TargetHudFrame.Visible = false
    end

    -- Watermark stats (~4 Hz)
    fpsAccum += dt
    fpsFrames += 1
    if os.clock() - lastWmUpdate >= 0.25 then
        displayFps = math.floor(fpsFrames / math.max(fpsAccum, 0.001) + 0.5)
        fpsAccum, fpsFrames = 0, 0
        lastWmUpdate = os.clock()
        if Config.Settings.Watermark then
            local pingOk, pingMs = pcall(function()
                return math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
            end)
            WatermarkText.Text = string.format("DELTA SUITE  |  %d FPS  |  %dms  |  Project Delta", displayFps, pingOk and pingMs or 0)
        end
    end
end)

ConfigMgr._ApplyUI = function()
    WatermarkFrame.Visible = Config.Settings.Watermark and not (Config.Misc.PanicMode and Config.Misc.PanicHideVisuals)
    SideFooter.Text = formatBindName(Config.Settings.MenuKey) .. " to Toggle"
    UI.ApplyGlassTheme()
    UI.RefreshAll()
    if Misc.RefreshReportsHud then
        Misc.RefreshReportsHud(true)
    end
    if type(UI.Preview.Refresh) == "function" then
        UI.Preview.Refresh()
    end
end

UI.ApplyGlassTheme()
ConfigMgr.TryAutoLoad()
UI.Notify("Delta Suite Loaded", "Combat, Visuals, World & Misc active for Project Delta.", "success")
