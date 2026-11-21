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
            HitPart = "Head", -- Head | FaceHitBox | HeadTopHitBox | UpperTorso | HumanoidRootPart | Closest
            TeamCheck = true,
            VisibleCheck = true,
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
            HitPart = "Head",
            HitChance = 100,
            TeamCheck = true,
            VisibleCheck = true,
            IgnoreDowned = true,
            TargetAI = false,
            Prediction = true,
            DropComp = true,
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
            AddFriendKey = Enum.UserInputType.MouseButton3 :: BindValue,
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
        },
        World = {
            Fullbright = false,
            Brightness = 2.0,
            ClockTime = 13.0,
            NoFog = false,
            NoBlurDOF = false,
            CustomFOV = false,
            FOVValue = 90,
        },
        Settings = {
            MenuKey = Enum.KeyCode.RightControl :: BindValue,
            Watermark = true,
            TargetHUD = true,
            Notifications = true,
            FontSize = 13,
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

local function readPlayerClan(player: Player): string?
    local rsPlayer = Delta.GetRSPlayer(player)
    local journey = rsPlayer and rsPlayer:FindFirstChild("Status") and rsPlayer.Status:FindFirstChild("Journey")
    local clanFolder = journey and journey:FindFirstChild("Clan")
    if not clanFolder then
        return nil
    end
    local cur = clanFolder:GetAttribute("CurrentClan")
    if type(cur) == "string" and cur ~= "" then
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
        if clan.Name == myTeamName or clan:FindFirstChild(LocalPlayer.Name) then
            local ownerAttr = clan:GetAttribute("Owner")
            local ownerName = (type(ownerAttr) == "string" and ownerAttr) or clan.Name:match("^(.+)'s team$")
            if ownerName and ownerName ~= LocalPlayer.Name then
                SquadMemberCache[ownerName] = true
            end
            for _, member in ipairs(clan:GetChildren()) do
                if member.Name ~= LocalPlayer.Name then
                    SquadMemberCache[member.Name] = true
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

local PlayerMetaCache: { [Player]: { KDR: string?, Reports: number?, UpdatedAt: number } } = {}

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

function Delta.GetPlayerMeta(player: Player): (string?, number?)
    local cached = PlayerMetaCache[player]
    local now = os.clock()
    if cached and (now - cached.UpdatedAt) < 2.0 then
        return cached.KDR, cached.Reports
    end

    local rsPlayer = Delta.GetRSPlayer(player)
    local status = rsPlayer and rsPlayer:FindFirstChild("Status")
    local journey = status and status:FindFirstChild("Journey")
    local wipeStats = journey and journey:FindFirstChild("WipeStatistics")
    local statsF = (rsPlayer and (rsPlayer:FindFirstChild("Stats") or rsPlayer:FindFirstChild("StartUp"))) or nil
    local leader = player:FindFirstChild("leaderstats")
    local sources: { Instance? } = { wipeStats, journey, status, rsPlayer, player, leader, statsF }

    local kdrStr: string? = nil
    local reports: number? = nil

    -- Check ReplicatedStorage.ReportList (MostWanted & Recent use "<PlayerName>_<UserId>" with KDR & TotalFlags)
    local reportList = ReplicatedStorage:FindFirstChild("ReportList")
    if reportList then
        local repKey = player.Name .. "_" .. tostring(player.UserId)
        local mw = reportList:FindFirstChild("MostWanted")
        local rec = reportList:FindFirstChild("Recent")
        local repFolder = (mw and mw:FindFirstChild(repKey))
            or (rec and rec:FindFirstChild(repKey))
            or reportList:FindFirstChild(repKey)
        if repFolder then
            local rawKdr = repFolder:GetAttribute("KDR")
            if type(rawKdr) == "string" and rawKdr ~= "" then
                -- Project Delta stores "Kills/Deaths/Ratio" e.g. "16366/12404/1.3"
                local ratio = rawKdr:match("/([^/]+)$")
                kdrStr = ratio or rawKdr
            elseif type(rawKdr) == "number" then
                kdrStr = string.format("%.2f", rawKdr)
            end
            local flags = repFolder:GetAttribute("TotalFlags")
            if type(flags) == "number" then
                reports = flags
            end
        end
    end

    if not kdrStr then
        local kdrNum = readNumericStat(sources, { "KDR", "KD", "KillDeathRatio" })
        local kills = readNumericStat(sources, { "K_PVP", "Kills", "PlayerKills", "Eliminations" })
        local deaths = readNumericStat(sources, { "D_PVP", "Deaths" })
        if kdrNum ~= nil then
            kdrStr = string.format("%.2f", kdrNum)
        elseif kills ~= nil then
            local d = math.max(deaths or 1, 1)
            kdrStr = string.format("%.2f", kills / d)
        end
    end

    if not reports then
        reports = readNumericStat(sources, { "TotalFlags", "Reports", "ReportCount", "TotalReports" })
    end

    PlayerMetaCache[player] = { KDR = kdrStr, Reports = reports, UpdatedAt = now }
    return kdrStr, reports
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

function Delta.GetBallisticsForAmmo(ammoName: string?): ({ Velocity: number, Drop: number }, Instance?)
    local defaultVel, defaultDrop = 2200, 4.6
    if ammoName and ammoName ~= "" and AmmoTypesFolder then
        local ammoInst = AmmoTypesFolder:FindFirstChild(ammoName)
        if ammoInst then
            local vel = tonumber(ammoInst:GetAttribute("MuzzleVelocity")) or defaultVel
            local drop = tonumber(ammoInst:GetAttribute("ProjectileDrop")) or defaultDrop
            return { Velocity = vel, Drop = drop }, ammoInst
        end
    end
    return { Velocity = defaultVel, Drop = defaultDrop }, nil
end

function Delta.GetLocalBallistics(): { Velocity: number, Drop: number }
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
        return { Velocity = 2200, Drop = 4.6 }
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
    rayBudget: { Remaining: number }?
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
    local destination = targetPart.Position
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

function Delta.PredictAimPosition(
    originPos: Vector3,
    targetPart: BasePart,
    useLead: boolean,
    useDrop: boolean,
    ballisticsOverride: { Velocity: number, Drop: number }?
): Vector3
    local pos = targetPart.Position
    if not useLead and not useDrop then
        return pos
    end
    local ballistics = ballisticsOverride or Delta.GetLocalBallistics()
    local speed = math.max(ballistics.Velocity, 100)
    local vel = useLead and targetPart.AssemblyLinearVelocity or Vector3.zero
    if vel.Magnitude < 0.5 then
        vel = Vector3.zero
    end
    -- Project Delta Bullet.onStep applies fixed Vector3(0, -70, 0) * dt without drag
    local gravity = useDrop and (70 * (ballistics.Drop / 4.6)) or 0

    local t = (pos - originPos).Magnitude / speed
    local aimPos = pos
    for _ = 1, 3 do
        local future = pos + vel * t + Vector3.new(0, 0.5 * gravity * t * t, 0)
        t = (future - originPos).Magnitude / speed
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
            local info = ItemsPriceCache[item.Name]
            local props = item:FindFirstChild("ItemProperties")
            local unitPrice = (info and info.Price)
                or tonumber(item:GetAttribute("Price"))
                or (props and tonumber(props:GetAttribute("Price")))
                or 0
            local amount = tonumber(item:GetAttribute("Amount"))
                or (props and tonumber(props:GetAttribute("Amount")))
                or 1
            if unitPrice == 0 and info and (info.Type == "Key" or info.Type == "Keycard") then
                unitPrice = 5000
            end
            totalValue += unitPrice * math.max(amount, 1)
            if unitPrice > maxPrice then
                maxPrice = unitPrice
                topItemName = (info and info.Name) or item.Name
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
    ScreenPos: Vector2,
    ScreenDist: number,
    WorldDist: number,
    Health: number,
    MaxHealth: number,
}

function Targeting.GetEffectiveFOVRadius(): number
    local base = Config.Targeting.FOV
    if not Config.Targeting.DynamicFOV then
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
    local maxPx = math.max(Targeting.GetEffectiveFOVRadius(), 220)
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
    IgnoreDowned: boolean,
    TargetAI: boolean,
    UseFOV: boolean,
    MaxDistance: number,
    RayOrigin: Vector3?,
    AimPoint: string?,
    AimParts: { string }?,
    VisibleFallback: boolean?,
    Wallbang: WallbangConfig?,
    RaycastBudget: number?,
    AllowRandom: boolean?,
}): TargetResult?
    local cam = Workspace.CurrentCamera
    if not cam then
        return nil
    end

    local aim2D = Targeting.GetAimOrigin2D()
    local fovRadius = opts.UseFOV and Targeting.GetEffectiveFOVRadius() or math.huge
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
        if not model.Parent then
            continue
        end
        if entry.IsAI and not opts.TargetAI then
            continue
        end
        if not entry.IsAI and entry.Player then
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
        if not onScreen then
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

    table.sort(candidates, function(a, b)
        return a.ScreenDist < b.ScreenDist
    end)

    local budget = { Remaining = math.max(1, opts.RaycastBudget or Config.Targeting.RaycastBudget or 6) }
    for _, cand in ipairs(candidates) do
        if not opts.VisibleCheck then
            return {
                Model = cand.Model,
                Player = cand.Entry.Player,
                IsAI = cand.Entry.IsAI,
                Part = cand.PrimaryPart,
                ScreenPos = cand.ScreenPos,
                ScreenDist = cand.ScreenDist,
                WorldDist = cand.WorldDist,
                Health = cand.Health,
                MaxHealth = cand.MaxHealth,
            }
        end

        for idx, part in ipairs(cand.Parts) do
            if budget.Remaining <= 0 then
                break
            end
            if idx > 1 and not opts.VisibleFallback and opts.AimPoint ~= "Random" then
                break
            end
            if Delta.IsPartVisible(cand.Model, part, visOrigin, opts.Wallbang, budget) then
                local sp, onScr = cam:WorldToViewportPoint(part.Position)
                local p2d = onScr and Vector2.new(sp.X, sp.Y) or cand.ScreenPos
                local sd = onScr and (p2d - aim2D).Magnitude or cand.ScreenDist
                if not opts.UseFOV or sd <= fovRadius then
                    return {
                        Model = cand.Model,
                        Player = cand.Entry.Player,
                        IsAI = cand.Entry.IsAI,
                        Part = part,
                        ScreenPos = p2d,
                        ScreenDist = sd,
                        WorldDist = (part.Position - camPos).Magnitude,
                        Health = cand.Health,
                        MaxHealth = cand.MaxHealth,
                    }
                end
            end
        end

        if budget.Remaining <= 0 then
            break
        end
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
        TargetAI = Config.Targeting.TargetAI,
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
    })
end

do
    local modulesFolder = ReplicatedStorage:FindFirstChild("Modules")
    local fpsInst = modulesFolder and modulesFolder:FindFirstChild("FPS")
    local bulletInst = fpsInst and fpsInst:FindFirstChild("Bullet")
    local okBullet, BulletMod = pcall(require, bulletInst :: any)

    if okBullet and type(BulletMod) == "table" and type(BulletMod.CreateBullet) == "function" then
        local origCreateBullet = BulletMod.CreateBullet

        local function wrappedCreateBullet(...)
            local args = table.pack(...)
            local restoredParts: { { Part: BasePart, PrevCF: CFrame } } = {}
            local restoredAmmo: { Inst: Instance, PrevDev: any }? = nil

            if Session.IsAlive() and isModeActive("SilentAim", Config.SilentAim.Enabled, Config.SilentAim.Mode, Config.SilentAim.Key) then
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

                        local usePred = Config.SilentAim.Prediction
                        local aimPos = Delta.PredictAimPosition(shotOrigin, target.Part, usePred, usePred, ammoBallistics)
                        local aimVec = aimPos - shotOrigin

                        if aimVec.Magnitude > 1e-4 then
                            local aimUnit = aimVec.Unit
                            local cam = Workspace.CurrentCamera
                            local camLook = cam and cam.CFrame.LookVector or aimUnit

                            -- Prevent fireBullet random cone dispersion from ruining guaranteed Silent Aim shots
                            if ammoInst and not Config.WeaponMods.NoSpread then
                                local prevDev = ammoInst:GetAttribute("AccuracyDeviation")
                                if type(prevDev) == "number" and prevDev > 0 then
                                    restoredAmmo = { Inst = ammoInst, PrevDev = prevDev }
                                    ammoInst:SetAttribute("AccuracyDeviation", 0)
                                end
                            end

                            -- Redirect arg #5 (Project Delta CreateBullet AimPart) and fallback aim/muzzle CFrames along exact shotOrigin->aimPos ray
                            local touched: { [BasePart]: boolean } = {}
                            for i = 1, args.n do
                                local arg = args[i]
                                if typeof(arg) == "Instance" and arg:IsA("BasePart") and not touched[arg] then
                                    local lname = arg.Name:lower()
                                    if i == 5 or lname:find("aim") or lname:find("muzzle") or lname:find("barrel") or lname:find("fire") then
                                        touched[arg] = true
                                        table.insert(restoredParts, { Part = arg, PrevCF = arg.CFrame })
                                        arg.CFrame = CFrame.lookAt(arg.Position, arg.Position + aimUnit)
                                    end
                                elseif typeof(arg) == "CFrame" then
                                    if i == 5 or arg.LookVector:Dot(camLook) > 0.25 then
                                        args[i] = CFrame.lookAt(arg.Position, arg.Position + aimUnit)
                                    end
                                end
                            end

                            ActiveLockedTarget = target
                        end
                    end
                end
            end

            local results = table.pack(pcall(origCreateBullet, table.unpack(args, 1, args.n)))
            for _, rec in ipairs(restoredParts) do
                if rec.Part.Parent then
                    rec.Part.CFrame = rec.PrevCF
                end
            end
            if restoredAmmo and restoredAmmo.Inst.Parent and not Config.WeaponMods.NoSpread then
                restoredAmmo.Inst:SetAttribute("AccuracyDeviation", restoredAmmo.PrevDev)
            end
            if not results[1] then
                error(results[2])
            end
            return table.unpack(results, 2, results.n)
        end

        BulletMod.CreateBullet = wrappedCreateBullet
        Session.OnStop(function()
            if BulletMod.CreateBullet == wrappedCreateBullet then
                BulletMod.CreateBullet = origCreateBullet
            end
        end)
    end
end

-- 6D. Aimbot Step (stabilized Camera slerp + Mouse fractional accumulator to prevent wobble)
local mouseAccumX, mouseAccumY = 0, 0
local lastTriggerShotAt = 0

local function stepAimbot(dt: number)
    local active = isModeActive("Aimbot", Config.Aimbot.Enabled, Config.Aimbot.Mode, Config.Aimbot.Key)
    if not active then
        mouseAccumX, mouseAccumY = 0, 0
        if isModeActive("SilentAim", Config.SilentAim.Enabled, Config.SilentAim.Mode, Config.SilentAim.Key) then
            ActiveLockedTarget = findSilentAimTarget(Delta.GetShotOrigin())
        else
            ActiveLockedTarget = nil
        end
        return
    end

    local target = Targeting.FindBestTarget({
        HitPart = Config.Aimbot.HitPart,
        TeamCheck = Config.Aimbot.TeamCheck,
        VisibleCheck = Config.Aimbot.VisibleCheck,
        IgnoreDowned = Config.Aimbot.IgnoreDowned,
        TargetAI = Config.Aimbot.TargetAI,
        UseFOV = true,
        MaxDistance = Config.Aimbot.MaxDistance,
    })

    ActiveLockedTarget = target
    if not target then
        mouseAccumX, mouseAccumY = 0, 0
        return
    end

    local cam = Workspace.CurrentCamera
    if not cam then
        return
    end

    local aimWorld = Delta.PredictAimPosition(cam.CFrame.Position, target.Part, Config.Aimbot.Prediction, Config.Aimbot.DropComp)

    if Config.Aimbot.Method == "Mouse" and type(mousemoverel) == "function" then
        local sp, onScreen = cam:WorldToViewportPoint(aimWorld)
        if not onScreen then
            return
        end
        local cur2D = Targeting.GetAimOrigin2D()
        local dx = sp.X - cur2D.X
        local dy = sp.Y - cur2D.Y

        -- Deadzone prevents sub-pixel oscillation from fighting mouse sensitivity
        if math.abs(dx) < 1.5 and math.abs(dy) < 1.5 then
            mouseAccumX, mouseAccumY = 0, 0
            return
        end

        local factor = 1 - math.clamp(Config.Aimbot.Smoothness / 100, 0, 0.96)
        local gain = math.clamp(factor * (dt * 60) * 0.45, 0.04, 0.85) * Config.Aimbot.MouseSens
        mouseAccumX += dx * gain
        mouseAccumY += dy * gain

        local stepX = math.modf(mouseAccumX)
        local stepY = math.modf(mouseAccumY)
        if stepX ~= 0 or stepY ~= 0 then
            mouseAccumX -= stepX
            mouseAccumY -= stepY
            pcall(mousemoverel, math.clamp(stepX, -65, 65), math.clamp(stepY, -65, 65))
        end
    else
        local targetCF = CFrame.lookAt(cam.CFrame.Position, aimWorld)
        local smooth = math.clamp(Config.Aimbot.Smoothness / 100, 0, 0.97)
        if smooth <= 0.01 then
            cam.CFrame = targetCF
        else
            local alpha = 1 - math.pow(smooth, math.clamp(dt * 12, 0.01, 2.0))
            cam.CFrame = cam.CFrame:Lerp(targetCF, math.clamp(alpha, 0.02, 1))
        end
    end
end

-- 6E. TriggerBot Step
local function stepTriggerBot()
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

    local origin = unitRay.Origin
    local dir = unitRay.Direction * Config.Aimbot.MaxDistance
    local hitInst: Instance? = nil

    for _ = 1, 4 do
        params.FilterDescendantsInstances = ignore
        local res = Workspace:Raycast(origin, dir, params)
        if not res then
            break
        end
        local part = res.Instance
        if part:IsA("BasePart") and (part.Transparency >= 0.95 or not part.CanCollide) then
            local model = part:FindFirstAncestorOfClass("Model")
            if model and Actors[model] then
                hitInst = model
                break
            end
            table.insert(ignore, part)
            origin = res.Position + unitRay.Direction * 0.1
        else
            hitInst = part:FindFirstAncestorOfClass("Model")
            break
        end
    end

    if hitInst and hitInst:IsA("Model") then
        local entry = Actors[hitInst]
        if not entry then
            return
        end
        if entry.IsAI and not Config.TriggerBot.TargetAI then
            return
        end
        if entry.Player then
            if Config.TriggerBot.TeamCheck and Delta.IsTeammate(entry.Player) then
                return
            end
            if Config.TriggerBot.IgnoreDowned and Delta.IsPlayerDowned(entry.Player, hitInst) then
                return
            end
        end
        local hum = hitInst:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 and type(mouse1press) == "function" and type(mouse1release) == "function" then
            lastTriggerShotAt = now
            pcall(mouse1press)
            task.delay(0.03, function()
                pcall(mouse1release)
            end)
        end
    end
end

-- ============================================================================
-- 7. WORLD & LIGHTING ENGINE (WITH CLEAN BACKUP/RESTORE)
-- ============================================================================
local World = {}

local LightingBackup = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
}

local AtmosphereInst: Atmosphere? = Lighting:FindFirstChildOfClass("Atmosphere")
local AtmosphereBackup = AtmosphereInst and {
    Density = AtmosphereInst.Density,
    Haze = AtmosphereInst.Haze,
    Glare = AtmosphereInst.Glare,
    Offset = AtmosphereInst.Offset,
} or nil

local BLUR_EFFECT_NAMES = { "ADS_DOF", "DDOF", "DepthOfFieldInteraction", "WaterBlur", "InventoryBlur", "HurtEffect", "LowHealthEffect" }
local EffectEnabledBackup: { [PostEffect]: boolean } = {}
for _, name in ipairs(BLUR_EFFECT_NAMES) do
    local eff = Lighting:FindFirstChild(name)
    if eff and eff:IsA("PostEffect") then
        EffectEnabledBackup[eff] = eff.Enabled
    end
end
local FullbrightEffect = Lighting:FindFirstChild("Fullbright")
local FullbrightBackupEnabled = (FullbrightEffect and FullbrightEffect:IsA("ColorCorrectionEffect")) and FullbrightEffect.Enabled or false

local OriginalFOV = Workspace.CurrentCamera and Workspace.CurrentCamera.FieldOfView or 70
local AppliedFullbright = false
local AppliedNoFog = false
local AppliedNoBlur = false
local AppliedFOV = false

function World.Step()
    if Config.World.Fullbright then
        AppliedFullbright = true
        Lighting.Brightness = Config.World.Brightness
        Lighting.ClockTime = Config.World.ClockTime
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(140, 140, 140)
        Lighting.OutdoorAmbient = Color3.fromRGB(165, 165, 165)
        if FullbrightEffect and FullbrightEffect:IsA("ColorCorrectionEffect") then
            FullbrightEffect.Enabled = false
        end
    elseif AppliedFullbright then
        AppliedFullbright = false
        Lighting.Brightness = LightingBackup.Brightness
        Lighting.ClockTime = LightingBackup.ClockTime
        Lighting.GlobalShadows = LightingBackup.GlobalShadows
        Lighting.Ambient = LightingBackup.Ambient
        Lighting.OutdoorAmbient = LightingBackup.OutdoorAmbient
        if FullbrightEffect and FullbrightEffect:IsA("ColorCorrectionEffect") then
            FullbrightEffect.Enabled = FullbrightBackupEnabled
        end
    end

    if Config.World.NoFog then
        AppliedNoFog = true
        Lighting.FogEnd = 1000000
        if AtmosphereInst then
            AtmosphereInst.Density = 0
            AtmosphereInst.Haze = 0
            AtmosphereInst.Glare = 0
        end
    elseif AppliedNoFog then
        AppliedNoFog = false
        Lighting.FogEnd = LightingBackup.FogEnd
        if AtmosphereInst and AtmosphereBackup then
            AtmosphereInst.Density = AtmosphereBackup.Density
            AtmosphereInst.Haze = AtmosphereBackup.Haze
            AtmosphereInst.Glare = AtmosphereBackup.Glare
        end
    end

    if Config.World.NoBlurDOF then
        AppliedNoBlur = true
        for eff in pairs(EffectEnabledBackup) do
            if eff.Parent then
                eff.Enabled = false
            end
        end
    elseif AppliedNoBlur then
        AppliedNoBlur = false
        for eff, orig in pairs(EffectEnabledBackup) do
            if eff.Parent then
                eff.Enabled = orig
            end
        end
    end

    local cam = Workspace.CurrentCamera
    if cam then
        if Config.World.CustomFOV then
            AppliedFOV = true
            cam.FieldOfView = Config.World.FOVValue
        elseif AppliedFOV then
            AppliedFOV = false
            cam.FieldOfView = OriginalFOV
        end
    end
end

function World.RestoreAll()
    Config.World.Fullbright = false
    Config.World.NoFog = false
    Config.World.NoBlurDOF = false
    Config.World.CustomFOV = false
    World.Step()
end

-- ============================================================================
-- 8. VISUALS & ESP RENDERING (DRAWING API + POOLED CHAMS)
-- ============================================================================
local HasDrawing = (type(Drawing) == "table" and type(Drawing.new) == "function")

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
    local px, py = math.floor(x + 0.5), math.floor(y + 0.5)
    local pw, ph = math.max(math.floor(w + 0.5), 6), math.max(math.floor(h + 0.5), 6)
    local lenX = math.max(math.floor(pw * 0.28), 4)
    local lenY = math.max(math.floor(ph * 0.22), 4)
    local coords = {
        { Vector2.new(px, py), Vector2.new(px + lenX, py) },
        { Vector2.new(px, py), Vector2.new(px, py + lenY) },
        { Vector2.new(px + pw, py), Vector2.new(px + pw - lenX, py) },
        { Vector2.new(px + pw, py), Vector2.new(px + pw, py + lenY) },
        { Vector2.new(px, py + ph), Vector2.new(px + lenX, py + ph) },
        { Vector2.new(px, py + ph), Vector2.new(px, py + ph - lenY) },
        { Vector2.new(px + pw, py + ph), Vector2.new(px + pw - lenX, py + ph) },
        { Vector2.new(px + pw, py + ph), Vector2.new(px + pw, py + ph - lenY) },
    }
    for i = 1, 8 do
        local p1, p2 = coords[i][1], coords[i][2]
        local out = outlines and outlines[i]
        if out then
            out.From = p1
            out.To = p2
            out.Visible = true
        end
        local line = lines[i]
        if line then
            line.From = p1
            line.To = p2
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
            d.BoxFill.Size = Vector2.new(pw, ph)
            d.BoxFill.Position = Vector2.new(px, py)
            d.BoxFill.Color = color
            d.BoxFill.Visible = true
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
            d.BoxFill.Size = Vector2.new(pw, ph)
            d.BoxFill.Position = Vector2.new(px, py)
            d.BoxFill.Color = color
            d.BoxFill.Visible = true
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

local function updateSkeletonVisual(d: { [string]: any }, model: Instance, cam: Camera, color: Color3, enabled: boolean)
    if enabled and model:IsA("Model") then
        for i, pair in ipairs(BONE_PAIRS) do
            local line = d.Bones[i]
            local p1 = model:FindFirstChild(pair[1])
            local p2 = model:FindFirstChild(pair[2])
            if line and p1 and p1:IsA("BasePart") and p2 and p2:IsA("BasePart") then
                local v1, ok1 = cam:WorldToViewportPoint(p1.Position)
                local v2, ok2 = cam:WorldToViewportPoint(p2.Position)
                if ok1 and ok2 then
                    line.From = Vector2.new(v1.X, v1.Y)
                    line.To = Vector2.new(v2.X, v2.Y)
                    line.Color = color
                    line.Visible = true
                else
                    line.Visible = false
                end
            elseif line then
                line.Visible = false
            end
        end
    else
        for i = 1, #BONE_PAIRS do
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

    local topAnchor = (head and head.Position or root.Position) + Vector3.new(0, 0.72, 0)
    local botAnchor = root.Position - Vector3.new(0, 2.85, 0)
    local feet = { model:FindFirstChild("LeftFoot"), model:FindFirstChild("RightFoot") }
    local lowY = math.huge
    for _, f in ipairs(feet) do
        if f and f:IsA("BasePart") then
            lowY = math.min(lowY, f.Position.Y - 0.35)
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
    local minWidth = math.max(boxH * 0.56, 8)
    local measuredW = (maxX > minX) and (maxX - minX + boxH * 0.14) or minWidth
    local boxW = math.clamp(math.max(measuredW, minWidth), 8, math.max(boxH * 1.15, 24))
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
    return true, minX, minY, math.clamp(maxX - minX, 8, 900), math.clamp(maxY - minY, 8, 900)
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

local function createDrawLinePool(count: number, thickness: number, color: Color3?): { any }
    local arr = {}
    for i = 1, count do
        local props: { [string]: any } = { Thickness = thickness, Visible = false }
        if color then
            props.Color = color
        end
        arr[i] = newDraw("Line", props)
    end
    return arr
end

CreateActorDrawings = function()
    local d: { [string]: any } = {
        BoxFill = newDraw("Square", { Thickness = 1, Filled = true, Transparency = 0.08, Visible = false }),
        BoxOutline = newDraw("Square", { Thickness = 2.8, Filled = false, Color = Color3.new(0, 0, 0), Visible = false }),
        CornerOutlines = createDrawLinePool(8, 3.0, Color3.new(0, 0, 0)),
        Box = newDraw("Square", { Thickness = 1.2, Filled = false, Visible = false }),
        Corners = createDrawLinePool(8, 1.3),
        Bones = createDrawLinePool(#BONE_PAIRS, 1.4),
        HpBg = newDraw("Square", { Thickness = 1, Filled = true, Color = Color3.new(0, 0, 0), Visible = false }),
        HpFill = newDraw("Square", { Thickness = 1, Filled = true, Visible = false }),
        Tracer = newDraw("Line", { Thickness = 1.1, Transparency = 0.72, Visible = false }),
        Labels = {},
        ArrowOutline = newDraw("Triangle", { Filled = true, Color = Color3.new(0, 0, 0), Visible = false }),
        Arrow = newDraw("Triangle", { Filled = true, Visible = false }),
    }
    for _, key in ipairs(ACTOR_LABEL_KEYS) do
        d.Labels[key] = newDraw("Text", { Center = true, Outline = true, Size = 13, Font = 2, Visible = false })
    end
    return d
end

local function hideDrawingsTable(d: { [string]: any }, hl: Highlight?, keepArrow: boolean?)
    for k, v in pairs(d) do
        if keepArrow and (k == "Arrow" or k == "ArrowOutline") then
            continue
        end
        if k == "Corners" or k == "CornerOutlines" or k == "Bones" then
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
        if k == "Corners" or k == "CornerOutlines" or k == "Bones" then
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
        BoxFill = newDraw("Square", { Thickness = 1, Filled = true, Transparency = 0.08, Visible = false }),
        BoxOutline = newDraw("Square", { Thickness = 2.8, Filled = false, Color = Color3.new(0, 0, 0), Visible = false }),
        CornerOutlines = createDrawLinePool(8, 3.0, Color3.new(0, 0, 0)),
        Box = newDraw("Square", { Thickness = 1.2, Filled = false, Visible = false }),
        Corners = createDrawLinePool(8, 1.3),
        Bones = createDrawLinePool(#BONE_PAIRS, 1.3),
        DotOutline = newDraw("Circle", { Filled = true, Radius = 4.4, NumSides = 14, Color = Color3.new(0, 0, 0), Visible = false }),
        Dot = newDraw("Circle", { Filled = true, Radius = 2.7, NumSides = 14, Visible = false }),
        Tracer = newDraw("Line", { Thickness = 1.1, Transparency = 0.72, Visible = false }),
        Labels = {},
        ArrowOutline = newDraw("Triangle", { Filled = true, Color = Color3.new(0, 0, 0), Visible = false }),
        Arrow = newDraw("Triangle", { Filled = true, Visible = false }),
    }
    for _, key in ipairs(TAG_LABEL_KEYS) do
        d.Labels[key] = newDraw("Text", { Center = true, Outline = true, Size = 13, Font = 2, Visible = false })
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
                local barW = 3
                local barX = math.floor(((zoneName == "Left") and (boxX - 6) or (boxX + boxW + 3)) + 0.5)
                local fillH = math.max(math.floor(boxH * hpRatio + 0.5), 1)
                d.HpBg.Position = Vector2.new(barX - 1, boxY - 1)
                d.HpBg.Size = Vector2.new(barW + 2, boxH + 2)
                d.HpBg.Visible = true
                d.HpFill.Position = Vector2.new(barX, boxY + (boxH - fillH))
                d.HpFill.Size = Vector2.new(barW, fillH)
                d.HpFill.Color = computeHealthColor(hpRatio)
                d.HpFill.Visible = true
            else
                local barH = 3
                local barY = math.floor(((zoneName == "Top") and (boxY - 6) or (boxY + boxH + 3)) + 0.5)
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
            local barPad = hasHpBar and 7 or 3
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

    local isTeam = (not isAI and entry.Player ~= nil) and Delta.IsTeammate(entry.Player :: Player) or false
    if not isAI and Config.PlayerESP.TeamCheck and isTeam then
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
    if cfg.Name then
        local title = (not isAI and entry.Player) and entry.Player.DisplayName or model.Name
        if isAI then
            title = "[NPC] " .. title
        end
        values.Name = { Text = title, Color = primaryColor, Size = fontSize }
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
            local kdrStr, repCount = Delta.GetPlayerMeta(entry.Player)
            if Config.PlayerESP.KDR then
                values.KDR = { Text = "KDR: " .. (kdrStr or "N/A"), Color = Color3.fromRGB(148, 163, 184), Size = math.max(fontSize - 2, 10) }
            end
            if Config.PlayerESP.Reports then
                values.Reports = { Text = "Rep: " .. tostring(repCount or 0), Color = (repCount and repCount > 0) and Config.PlayerESP.DownedColor or Color3.fromRGB(148, 163, 184), Size = math.max(fontSize - 2, 10) }
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

    updateSkeletonVisual(d, model, cam, primaryColor, cfg.Skeleton)
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
        if tag.CachedSub ~= "" then
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
        d.Tracer.Visible = false
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
        updateSkeletonVisual(d, tag.Instance, cam, color, cfg.Skeleton == true)
    else
        updateSkeletonVisual(d, tag.Instance, cam, color, false)
    end
end

-- HUD FOV Circle
local FOVCircle = newDraw("Circle", { Thickness = 1.4, NumSides = 64, Filled = false, Visible = false })

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

Session.OnStop(function()
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
    if FOVCircle then
        pcall(function() FOVCircle:Remove() end)
    end
end)

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

function UI.Notify(title: string, desc: string, kind: ("info" | "success" | "warn")?)
    if not Config.Settings.Notifications or not Session.IsAlive() then
        return
    end
    local accent = kind == "success" and THEME.Success or (kind == "warn" and Color3.fromRGB(245, 158, 11) or THEME.Accent)
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
MainWindow.ClipsDescendants = true
MainWindow.Parent = ScreenGui
addCorner(MainWindow, 10)
addStroke(MainWindow, THEME.Border, 1.2, 0)

-- Sidebar Navigation
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 168, 1, 0)
Sidebar.BackgroundColor3 = THEME.BgSidebar
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainWindow

local SideSep = Instance.new("Frame")
SideSep.Position = UDim2.new(1, -1, 0, 0)
SideSep.Size = UDim2.new(0, 1, 1, 0)
SideSep.BackgroundColor3 = THEME.Border
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
HeaderBar.BorderSizePixel = 0
HeaderBar.Parent = MainWindow

local HeaderSep = Instance.new("Frame")
HeaderSep.Position = UDim2.new(0, 0, 1, -1)
HeaderSep.Size = UDim2.new(1, 0, 0, 1)
HeaderSep.BackgroundColor3 = THEME.Border
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
            BackgroundTransparency = on and 0 or 1,
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

function UI.AddSection(tab: TabObj, colSide: "Left" | "Right", title: string): Frame
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, -4, 0, 32)
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.BackgroundColor3 = THEME.BgCard
    card.Parent = (colSide == "Right") and tab.Right or tab.Left
    addCorner(card, 8)
    addStroke(card, THEME.Border, 1, 0.15)

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

function UI.AddDropdown(sec: Frame, label: string, options: { string }, getter: () -> string, setter: (string) -> ())
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
    btn.AutoButtonColor = false
    btn.Parent = holder
    addCorner(btn, 6)
    addStroke(btn, THEME.Border, 1, 0.2)

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
        local menu = Instance.new("Frame")
        menu.Position = UDim2.fromOffset(btn.AbsolutePosition.X, btn.AbsolutePosition.Y + btn.AbsoluteSize.Y + 4)
        menu.Size = UDim2.fromOffset(btn.AbsoluteSize.X, math.min(#options * 26 + 8, 220))
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

        for _, opt in ipairs(options) do
            local ob = Instance.new("TextButton")
            ob.Size = UDim2.new(1, 0, 0, 24)
            ob.BackgroundColor3 = (opt == getter()) and THEME.BgHover or THEME.BgSidebar
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
        Color3.fromRGB(239, 68, 68),
        Color3.fromRGB(34, 197, 94),
        Color3.fromRGB(245, 158, 11),
        Color3.fromRGB(168, 85, 247),
        Color3.fromRGB(250, 204, 21),
        Color3.fromRGB(251, 146, 60),
        Color3.fromRGB(45, 212, 191),
        Color3.fromRGB(244, 63, 94),
        Color3.fromRGB(255, 255, 255),
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
        local pop = Instance.new("Frame")
        pop.Position = UDim2.fromOffset(swatch.AbsolutePosition.X - 118, swatch.AbsolutePosition.Y + 24)
        pop.Size = UDim2.fromOffset(152, 64)
        pop.BackgroundColor3 = THEME.BgSidebar
        pop.ZIndex = 65
        pop.Parent = PopupLayer
        addCorner(pop, 7)
        addStroke(pop, THEME.Border, 1, 0)

        local grid = Instance.new("UIGridLayout")
        grid.CellSize = UDim2.fromOffset(22, 22)
        grid.CellPadding = UDim2.fromOffset(6, 6)
        grid.Parent = pop
        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 7)
        pad.PaddingLeft = UDim.new(0, 9)
        pad.Parent = pop

        for _, col in ipairs(PRESETS) do
            local b = Instance.new("TextButton")
            b.BackgroundColor3 = col
            b.Text = ""
            b.AutoButtonColor = false
            b.ZIndex = 66
            b.Parent = pop
            addCorner(b, 5)
            b.MouseButton1Click:Connect(function()
                setter(col)
                swatch.BackgroundColor3 = col
                closeActivePopup()
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

function UI.AddButton(sec: Frame, label: string, style: ("normal" | "danger")?, onClick: () -> ())
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 28)
    btn.BackgroundColor3 = style == "danger" and Color3.fromRGB(70, 22, 29) or THEME.BgControl
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.TextColor3 = style == "danger" and Color3.fromRGB(252, 165, 165) or THEME.TextPrimary
    btn.Text = label
    btn.AutoButtonColor = false
    btn.Parent = sec
    addCorner(btn, 6)
    addStroke(btn, style == "danger" and THEME.Danger or THEME.Border, 1, 0.35)

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

function UI.AddToggleWithConfig(
    sec: Frame,
    label: string,
    getter: () -> boolean,
    setter: (boolean) -> (),
    buildPopover: (pop: Frame, anchorBtn: TextButton) -> ()
)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 24)
    row.BackgroundTransparency = 1
    row.Parent = sec

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -76, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 12
    lbl.TextColor3 = THEME.TextPrimary
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = label
    lbl.Parent = row

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
        if ActivePopup then
            closeActivePopup()
            return
        end
        IgnoreNextPopupDismiss = true
        local pop = Instance.new("Frame")
        pop.Size = UDim2.fromOffset(224, 128)
        pop.BackgroundColor3 = THEME.BgSidebar
        pop.ZIndex = 65
        pop.Parent = PopupLayer
        addCorner(pop, 8)
        addStroke(pop, THEME.Accent, 1, 0.45)

        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 8)
        pad.PaddingBottom = UDim.new(0, 8)
        pad.PaddingLeft = UDim.new(0, 10)
        pad.PaddingRight = UDim.new(0, 10)
        pad.Parent = pop

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 6)
        layout.Parent = pop

        buildPopover(pop, gearBtn)

        local layerSize = PopupLayer.AbsoluteSize
        local pw, ph = pop.Size.X.Offset, pop.Size.Y.Offset
        local px = math.clamp(gearBtn.AbsolutePosition.X - pw + 26, 8, math.max(8, layerSize.X - pw - 8))
        local py = gearBtn.AbsolutePosition.Y + 24
        if layerSize.Y > 0 and py + ph > layerSize.Y - 8 then
            py = math.max(8, gearBtn.AbsolutePosition.Y - ph - 4)
        end
        pop.Position = UDim2.fromOffset(px, py)
        ActivePopup = pop
    end)
end

local function addPopupSlider(pop: Frame, label: string, minVal: number, maxVal: number, step: number, suffix: string, getter: () -> number, setter: (number) -> ())
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

-- ============================================================================
-- 10. POPULATE TABS (COMBAT, VISUALS, SETTINGS ONLY)
-- ============================================================================
local CombatTab = UI.AddTab("Combat")
local VisualsTab = UI.AddTab("Visuals")
local SettingsTab = UI.AddTab("Settings")

-- ---- COMBAT TAB ----
do
    local secAim = UI.AddSection(CombatTab, "Left", "Aimbot")
    UI.AddToggle(secAim, "Enable Aimbot", function() return Config.Aimbot.Enabled end, function(v) Config.Aimbot.Enabled = v end,
        function() return Config.Aimbot.Key end, function(k) Config.Aimbot.Key = k end)
    UI.AddDropdown(secAim, "Activation Mode", { "Hold", "Toggle", "Always" }, function() return Config.Aimbot.Mode end, function(v) Config.Aimbot.Mode = v end)
    UI.AddDropdown(secAim, "Aim Method", { "Camera", "Mouse" }, function() return Config.Aimbot.Method end, function(v) Config.Aimbot.Method = v end)
    UI.AddDropdown(secAim, "Target Hitbox", { "Head", "FaceHitBox", "HeadTopHitBox", "UpperTorso", "HumanoidRootPart", "Closest" },
        function() return Config.Aimbot.HitPart end, function(v) Config.Aimbot.HitPart = v end)
    UI.AddSlider(secAim, "Smoothness", 0, 95, 1, "%", function() return Config.Aimbot.Smoothness end, function(v) Config.Aimbot.Smoothness = v end)
    UI.AddSlider(secAim, "Mouse Gain", 0.2, 3.0, 0.1, "x", function() return Config.Aimbot.MouseSens end, function(v) Config.Aimbot.MouseSens = v end)
    UI.AddSlider(secAim, "Max Distance", 100, 1500, 25, "m", function() return Config.Aimbot.MaxDistance end, function(v) Config.Aimbot.MaxDistance = v end)
    UI.AddToggle(secAim, "Team / Clan Check", function() return Config.Aimbot.TeamCheck end, function(v) Config.Aimbot.TeamCheck = v end)
    UI.AddToggle(secAim, "Visible Check", function() return Config.Aimbot.VisibleCheck end, function(v) Config.Aimbot.VisibleCheck = v end)
    UI.AddToggle(secAim, "Ignore Downed", function() return Config.Aimbot.IgnoreDowned end, function(v) Config.Aimbot.IgnoreDowned = v end)
    UI.AddToggle(secAim, "Target AI / Bots", function() return Config.Aimbot.TargetAI end, function(v) Config.Aimbot.TargetAI = v end)
    UI.AddToggle(secAim, "Lead Prediction", function() return Config.Aimbot.Prediction end, function(v) Config.Aimbot.Prediction = v end)
    UI.AddToggle(secAim, "Bullet Drop Comp", function() return Config.Aimbot.DropComp end, function(v) Config.Aimbot.DropComp = v end)

    local secFov = UI.AddSection(CombatTab, "Left", "FOV Circle")
    UI.AddToggle(secFov, "Show FOV Circle", function() return Config.Aimbot.ShowFOV end, function(v) Config.Aimbot.ShowFOV = v end)
    UI.AddSlider(secFov, "FOV Radius", 25, 500, 5, "px", function() return Config.Targeting.FOV end, function(v)
        if v ~= Config.Targeting.FOV then
            Config.Targeting.FOV = v
            Config.Aimbot.FOVRadius = v
            UI.RefreshAll()
        end
    end)
    UI.AddToggle(secFov, "Scale With Zoom", function() return Config.Targeting.DynamicFOV end, function(v)
        Config.Targeting.DynamicFOV = v
        Config.Aimbot.FOVDynamic = v
        UI.RefreshAll()
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
    UI.AddToggle(secSilent, "Wall Check", function() return Config.SilentAim.VisibleCheck end, function(v) Config.SilentAim.VisibleCheck = v end)
    UI.AddToggle(secSilent, "Target AI / Bots", function() return Config.Targeting.TargetAI end, function(v)
        Config.Targeting.TargetAI = v
        Config.SilentAim.TargetAI = v
        UI.RefreshAll()
    end)
    UI.AddToggle(secSilent, "Ballistic Prediction", function() return Config.SilentAim.Prediction end, function(v) Config.SilentAim.Prediction = v end)

    local secTargeting = UI.AddSection(CombatTab, "Right", "Targeting")
    UI.AddSlider(secTargeting, "FOV", 25, 500, 5, "", function() return Config.Targeting.FOV end, function(v)
        if v ~= Config.Targeting.FOV then
            Config.Targeting.FOV = v
            Config.Aimbot.FOVRadius = v
            UI.RefreshAll()
        end
    end)
    UI.AddToggle(secTargeting, "Dynamic FOV", function() return Config.Targeting.DynamicFOV end, function(v)
        Config.Targeting.DynamicFOV = v
        Config.Aimbot.FOVDynamic = v
        UI.RefreshAll()
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
    UI.AddToggle(secTargeting, "Target AI", function() return Config.Targeting.TargetAI end, function(v)
        Config.Targeting.TargetAI = v
        Config.SilentAim.TargetAI = v
        UI.RefreshAll()
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
    UI.AddKeybindRow(secTargeting, "Add Friend", function() return Config.Targeting.AddFriendKey end, function(k)
        Config.Targeting.AddFriendKey = k
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
    UI.AddSlider(secTrig, "Fire Delay", 20, 250, 5, "ms", function() return Config.TriggerBot.DelayMs end, function(v) Config.TriggerBot.DelayMs = v end)
    UI.AddToggle(secTrig, "Only When ADS", function() return Config.TriggerBot.OnlyADS end, function(v) Config.TriggerBot.OnlyADS = v end)
    UI.AddToggle(secTrig, "Team Check", function() return Config.TriggerBot.TeamCheck end, function(v) Config.TriggerBot.TeamCheck = v end)
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
        UI.AddToggle(p, "Reports", function() return Config.PlayerESP.Reports end, function(v) Config.PlayerESP.Reports = v end)
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

    local secExit = UI.AddSection(VisualsTab, "Left", "Extractions")
    UI.AddToggle(secExit, "Extraction Locations ESP", function() return Config.ExitESP.Enabled end, function(v) Config.ExitESP.Enabled = v end)
    UI.AddSlider(secExit, "Max Distance", 100, 3000, 50, "m", function() return Config.ExitESP.MaxDistance end, function(v) Config.ExitESP.MaxDistance = v end)
    UI.AddColorPicker(secExit, "Extraction Color", function() return Config.ExitESP.Color end, function(c) Config.ExitESP.Color = c end)

    local secWorld = UI.AddSection(VisualsTab, "Left", "World & Vision")
    UI.AddToggle(secWorld, "Fullbright", function() return Config.World.Fullbright end, function(v) Config.World.Fullbright = v end)
    UI.AddSlider(secWorld, "Brightness", 1, 5, 0.2, "", function() return Config.World.Brightness end, function(v) Config.World.Brightness = v end)
    UI.AddSlider(secWorld, "Clock Time", 0, 24, 0.5, "h", function() return Config.World.ClockTime end, function(v) Config.World.ClockTime = v end)
    UI.AddToggle(secWorld, "No Fog / Clear Air", function() return Config.World.NoFog end, function(v) Config.World.NoFog = v end)
    UI.AddToggle(secWorld, "No Blur / Visor DOF", function() return Config.World.NoBlurDOF end, function(v) Config.World.NoBlurDOF = v end)
    UI.AddToggle(secWorld, "Custom FOV Override", function() return Config.World.CustomFOV end, function(v) Config.World.CustomFOV = v end)
    UI.AddSlider(secWorld, "Field of View", 60, 120, 1, "deg", function() return Config.World.FOVValue end, function(v) Config.World.FOVValue = v end)
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
        WatermarkFrame.Visible = v
    end)
    UI.AddToggle(secUI, "Target Info HUD", function() return Config.Settings.TargetHUD end, function(v) Config.Settings.TargetHUD = v end)
    UI.AddToggle(secUI, "Notifications", function() return Config.Settings.Notifications end, function(v) Config.Settings.Notifications = v end)
    UI.AddSlider(secUI, "ESP Font Size", 10, 18, 1, "px", function() return Config.Settings.FontSize end, function(v) Config.Settings.FontSize = v end)

    local secSess = UI.AddSection(SettingsTab, "Right", "Session Control")
    UI.AddButton(secSess, "Restore World & Weapons", "normal", function()
        Config.WeaponMods.NoRecoil = false
        Config.WeaponMods.NoSpread = false
        Config.WeaponMods.NoSway = false
        Config.WeaponMods.FastADS = false
        Config.WeaponMods.NoScopeDOF = false
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
        Delta.ClearFriends()
        Combat.RestoreAllWeaponMods()
        World.RestoreAll()
        WatermarkFrame.Visible = Config.Settings.Watermark
        SideFooter.Text = formatBindName(Config.Settings.MenuKey) .. " to Toggle"
        UI.RefreshAll()
        UI.Notify("Config Reset", "All settings restored to defaults.", "info")
    end)
    UI.AddButton(secSess, "Unload Delta Suite", "danger", function()
        Session.Stop()
    end)
end

-- ============================================================================
-- 10B. INTERACTIVE 4-ZONE ESP PREVIEW PANEL (CHARACTER & LOOT CUBE)
-- ============================================================================
do
    local PreviewFrame = Instance.new("Frame")
    PreviewFrame.Name = "EspPreviewPanel"
    PreviewFrame.Size = UDim2.fromOffset(282, 490)
    PreviewFrame.BackgroundColor3 = THEME.BgMain
    PreviewFrame.ClipsDescendants = true
    PreviewFrame.Visible = false
    PreviewFrame.ZIndex = 20
    PreviewFrame.Parent = ScreenGui
    addCorner(PreviewFrame, 10)
    addStroke(PreviewFrame, THEME.Border, 1.2, 0)

    local PHeader = Instance.new("Frame")
    PHeader.Size = UDim2.new(1, 0, 0, 42)
    PHeader.BackgroundColor3 = THEME.BgHeader
    PHeader.BorderSizePixel = 0
    PHeader.Parent = PreviewFrame

    local PHeaderSep = Instance.new("Frame")
    PHeaderSep.Position = UDim2.new(0, 0, 1, -1)
    PHeaderSep.Size = UDim2.new(1, 0, 0, 1)
    PHeaderSep.BackgroundColor3 = THEME.Border
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
    Stage.ClipsDescendants = true
    Stage.Parent = PreviewFrame
    addCorner(Stage, 8)
    addStroke(Stage, THEME.Border, 1, 0.2)

    local stageGrad = Instance.new("UIGradient")
    stageGrad.Rotation = 90
    stageGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(16, 21, 31)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(10, 13, 20)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 20, 29)),
    })
    stageGrad.Parent = Stage

    -- Pedestal plate underneath dummy / cube
    local Pedestal = Instance.new("Frame")
    Pedestal.AnchorPoint = Vector2.new(0.5, 0.5)
    Pedestal.Position = UDim2.fromOffset(curBoxX + curBoxW * 0.5, curBoxY + curBoxH - 2)
    Pedestal.Size = UDim2.fromOffset(112, 22)
    Pedestal.BackgroundColor3 = Color3.fromRGB(22, 29, 43)
    Pedestal.BackgroundTransparency = 0.25
    Pedestal.ZIndex = 2
    Pedestal.Parent = Stage
    addCorner(Pedestal, 11)
    addStroke(Pedestal, THEME.Border, 1, 0.2)

    -- 3D ViewportFrame in center (switches between R15 Character & Isometric Loot Cube)
    local CharViewport = Instance.new("ViewportFrame")
    CharViewport.Position = UDim2.fromOffset(curBoxX - 18, curBoxY - 12)
    CharViewport.Size = UDim2.fromOffset(curBoxW + 36, curBoxH + 22)
    CharViewport.BackgroundTransparency = 1
    CharViewport.Ambient = Color3.fromRGB(170, 182, 204)
    CharViewport.LightColor = Color3.fromRGB(255, 255, 255)
    CharViewport.LightDirection = Vector3.new(-0.35, -0.75, -0.55)
    CharViewport.ZIndex = 3
    CharViewport.Parent = Stage

    local WorldM = Instance.new("WorldModel")
    WorldM.Parent = CharViewport

    local DummyCam = Instance.new("Camera")
    DummyCam.FieldOfView = 38
    DummyCam.CFrame = CFrame.lookAt(Vector3.new(0, 0.25, 7.6), Vector3.new(0, 0.1, 0))
    DummyCam.Parent = CharViewport
    CharViewport.CurrentCamera = DummyCam

    local DummyParts: { BasePart } = {}
    do
        local rigSpecs = {
            { "Head", Vector3.new(1.12, 1.12, 1.12), Vector3.new(0, 2.08, 0) },
            { "UpperTorso", Vector3.new(1.88, 1.25, 0.96), Vector3.new(0, 0.85, 0) },
            { "LowerTorso", Vector3.new(1.76, 0.72, 0.92), Vector3.new(0, -0.14, 0) },
            { "LeftArm", Vector3.new(0.86, 1.92, 0.88), Vector3.new(-1.44, 0.48, 0) },
            { "RightArm", Vector3.new(0.86, 1.92, 0.88), Vector3.new(1.44, 0.48, 0) },
            { "LeftLeg", Vector3.new(0.88, 1.95, 0.92), Vector3.new(-0.49, -1.52, 0) },
            { "RightLeg", Vector3.new(0.88, 1.95, 0.92), Vector3.new(0.49, -1.52, 0) },
        }
        for _, spec in ipairs(rigSpecs) do
            local p = Instance.new("Part")
            p.Name = spec[1]
            p.Size = spec[2]
            p.Position = spec[3]
            p.Anchored = true
            p.Material = Enum.Material.SmoothPlastic
            p.Color = Color3.fromRGB(36, 44, 61)
            p.Parent = WorldM
            table.insert(DummyParts, p)
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

    -- Subtle Translucent Fill, Box, Corners, Tracer & Arrow Overlays
    local BoxFillFrame = Instance.new("Frame")
    BoxFillFrame.Position = UDim2.fromOffset(curBoxX, curBoxY)
    BoxFillFrame.Size = UDim2.fromOffset(curBoxW, curBoxH)
    BoxFillFrame.BackgroundColor3 = THEME.Accent
    BoxFillFrame.BackgroundTransparency = 0.9
    BoxFillFrame.BorderSizePixel = 0
    BoxFillFrame.ZIndex = 5
    BoxFillFrame.Visible = false
    BoxFillFrame.Parent = Stage

    local BoxOutlineFrame = Instance.new("Frame")
    BoxOutlineFrame.Position = UDim2.fromOffset(curBoxX, curBoxY)
    BoxOutlineFrame.Size = UDim2.fromOffset(curBoxW, curBoxH)
    BoxOutlineFrame.BackgroundTransparency = 1
    BoxOutlineFrame.ZIndex = 6
    BoxOutlineFrame.Visible = false
    BoxOutlineFrame.Parent = Stage
    local boxStroke = addStroke(BoxOutlineFrame, THEME.Accent, 1.5, 0)

    local CornerFrames: { Frame } = {}
    for _ = 1, 8 do
        local f = Instance.new("Frame")
        f.BorderSizePixel = 0
        f.ZIndex = 7
        f.Visible = false
        f.Parent = Stage
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
        line.ZIndex = 5
        line.Visible = false
        line.Parent = Stage
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
            CharViewport.Position = UDim2.fromOffset(curBoxX - 18, curBoxY - 12)
            CharViewport.Size = UDim2.fromOffset(curBoxW + 36, curBoxH + 22)
            Pedestal.Size = UDim2.fromOffset(112, 22)
        end
        Pedestal.Position = UDim2.fromOffset(curBoxX + curBoxW * 0.5, curBoxY + curBoxH - 2)
        BoxFillFrame.Position = UDim2.fromOffset(curBoxX, curBoxY)
        BoxFillFrame.Size = UDim2.fromOffset(curBoxW, curBoxH)
        BoxOutlineFrame.Position = UDim2.fromOffset(curBoxX, curBoxY)
        BoxOutlineFrame.Size = UDim2.fromOffset(curBoxW, curBoxH)

        if isCube then
            for _, p in ipairs(DummyParts) do
                p.Parent = nil
            end
            for _, p in ipairs(CubeParts) do
                p.Parent = WorldM
            end
        else
            for _, p in ipairs(CubeParts) do
                p.Parent = nil
            end
            for _, p in ipairs(DummyParts) do
                p.Parent = WorldM
            end
        end

        local cw, ch = isCube and 20 or 18, isCube and 20 or 22
        local cSpecs = {
            { curBoxX, curBoxY, cw, 2 }, { curBoxX, curBoxY, 2, ch },
            { curBoxX + curBoxW - cw, curBoxY, cw, 2 }, { curBoxX + curBoxW - 2, curBoxY, 2, ch },
            { curBoxX, curBoxY + curBoxH - 2, cw, 2 }, { curBoxX, curBoxY + curBoxH - ch, 2, ch },
            { curBoxX + curBoxW - cw, curBoxY + curBoxH - 2, cw, 2 }, { curBoxX + curBoxW - 2, curBoxY + curBoxH - ch, 2, ch },
        }
        for i, sp in ipairs(cSpecs) do
            local cf = CornerFrames[i]
            cf.Position = UDim2.fromOffset(sp[1], sp[2])
            cf.Size = UDim2.fromOffset(sp[3], sp[4])
        end

        local skPadX = isCube and curBoxW * 0.14 or 0
        local skPadY = isCube and curBoxH * 0.08 or 0
        local skX, skY = curBoxX + skPadX, curBoxY + skPadY
        local skW, skH = curBoxW - skPadX * 2, curBoxH - skPadY * 2
        for i, seg in ipairs(SKEL_NORM_SEGS) do
            local p1 = Vector2.new(skX + seg[1].X * skW, skY + seg[1].Y * skH)
            local p2 = Vector2.new(skX + seg[2].X * skW, skY + seg[2].Y * skH)
            local diff = p2 - p1
            local line = SkelLines[i]
            line.Position = UDim2.fromOffset((p1.X + p2.X) * 0.5, (p1.Y + p2.Y) * 0.5)
            line.Size = UDim2.fromOffset(math.max(diff.Magnitude, 2), 1.6)
            line.Rotation = math.deg(math.atan2(diff.Y, diff.X))
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
        Reports = "Rep: 1",
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
                    map.Reports = { Text = "Rep: 1", Color = Config.PlayerESP.DownedColor }
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

        -- Dummy / Cube appearance (Chams / Highlights vs Default)
        if isCube then
            local lidCol = chamsOn and chamsCol:Lerp(Color3.new(1, 1, 1), 0.14) or Color3.fromRGB(48, 59, 80)
            local bandCol = chamsOn and (cfg.ChamsOutline or Color3.new(1, 1, 1)) or primaryCol:Lerp(Color3.fromRGB(48, 59, 80), 0.45)
            if CubeParts[1] then CubeParts[1].Color = chamsOn and chamsCol or Color3.fromRGB(36, 44, 61) end
            if CubeParts[2] then CubeParts[2].Color = lidCol end
            if CubeParts[3] then CubeParts[3].Color = bandCol end
        else
            for _, part in ipairs(DummyParts) do
                part.Color = chamsOn and chamsCol or Color3.fromRGB(36, 44, 61)
            end
        end
        CharViewport.ImageColor3 = chamsOn and chamsCol or Color3.new(1, 1, 1)

        -- Fill, Box & Corners
        BoxFillFrame.Visible = (cfg.Box == "2D" or cfg.Box == "Corner")
        BoxFillFrame.BackgroundColor3 = primaryCol
        BoxOutlineFrame.Visible = (cfg.Box == "2D")
        boxStroke.Color = primaryCol
        for _, cf in ipairs(CornerFrames) do
            cf.Visible = (cfg.Box == "Corner")
            cf.BackgroundColor3 = primaryCol
        end

        -- Skeleton overlay (Player, Npc, Corpse)
        local showSkel = (cfg.Skeleton == true) and (not isCube or catKey == "Corpse")
        for _, sk in ipairs(SkelLines) do
            sk.Visible = showSkel
            sk.BackgroundColor3 = primaryCol
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
end

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
        if code == Enum.KeyCode.Escape or code == Enum.KeyCode.Backspace then
            ListeningPicker.Set(Enum.KeyCode.Unknown)
        else
            ListeningPicker.Set(code)
        end
        local done = ListeningPicker
        ListeningPicker = nil
        done.Refresh()
        return
    end

    if gameProcessed then
        return
    end

    KeyHoldStates[code] = true

    if code == Config.Settings.MenuKey then
        setMenuVisible(not WindowVisible)
        return
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
            UI.Notify("Friends", string.format("%s %s whitelist", plr.DisplayName, added and "added to" or "removed from"), added and "success" or "info")
        else
            UI.Notify("Friends", "No player near crosshair", "info")
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

    -- Combat loops
    stepAimbot(dt)
    stepTriggerBot()

    -- World & FOV
    World.Step()

    -- FOV Circle
    if FOVCircle then
        if Config.Aimbot.ShowFOV and (Config.Aimbot.Enabled or Config.SilentAim.Enabled) then
            FOVCircle.Position = Targeting.GetAimOrigin2D()
            FOVCircle.Radius = Targeting.GetEffectiveFOVRadius()
            FOVCircle.Color = Config.Aimbot.FOVColor
            FOVCircle.Filled = Config.Aimbot.FOVFilled
            FOVCircle.Transparency = Config.Aimbot.FOVFilled and 0.14 or 0.9
            FOVCircle.Visible = true
        else
            FOVCircle.Visible = false
        end
    end

    -- ESP Renders
    local vp = cam.ViewportSize
    for _, entry in pairs(Actors) do
        renderActorESP(entry, cam, vp)
    end
    for _, tag in pairs(WorldTags) do
        renderTagESP(tag, cam, vp)
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

UI.Notify("Delta Suite Loaded", "Combat & Visuals active for Project Delta.", "success")
