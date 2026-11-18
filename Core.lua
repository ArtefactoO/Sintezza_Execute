local addon, ns = ...
local events = CreateFrame("Frame")
local LEGACY_ZONE = { .60, .32, .91, .45 }
local LEGACY_MARKER = { .89, .71, 1, 1 }
local ANCHORS = { AUTO = true, FULL = true, BOTTOM = true, CENTER = true, TOP = true }
local COOLDOWNS = { SHOW = true, HIDE = true, TIMER = true, DIM = true }
local LOCATIONS = { ANY = true, INSIDE = true, OUTSIDE = true }
local PULSES = { OFF = true, ICON = true, GLOW = true, BOTH = true }
local pendingAbility, requestedRank

local function Number(value, fallback, minimum, maximum)
    if type(value) ~= "number" or value ~= value then return fallback end
    return math.max(minimum, math.min(maximum, value))
end

local function Color(value, fallback)
    if type(value) ~= "table" then return end
    local result = {}
    for i = 1, 4 do
        result[i] = Number(value[i], fallback[i], 0, 1)
    end
    return result
end

local function SameColor(color, other)
    return type(color) == "table"
        and color[1] == other[1] and color[2] == other[2] and color[3] == other[3] and color[4] == other[4]
end

local function InitializeDatabase()
    local db = type(Sintezza_ExecuteDB) == "table" and Sintezza_ExecuteDB or {}
    local old = Sintezza_UIDB or StandaloneUIDB
    if not db.version and type(old) == "table" and type(old.activeProfile) == "string" then
        local legacy = type(old.executeArchive) == "table" and old.executeArchive[old.activeProfile]
        if not legacy and type(old.profiles) == "table" then
            local profile = old.profiles[old.activeProfile]
            local modules = type(profile) == "table" and profile.modules
            local plates = type(modules) == "table" and modules.nameplates
            legacy = type(plates) == "table" and plates
        end
        local style = type(legacy) == "table" and legacy.executeMarkerStyle
        if type(style) == "table" then
            local c = style.color
            local defaultColor = type(c) == "table" and c[1] == .788 and c[2] == .737 and c[3] == .639 and c[4] == .70
            if style.width ~= 1 or style.height ~= 5 or style.anchor ~= "BOTTOM" or not defaultColor then
                db.markerStyle = style
            end
        end
    end
    local style = type(db.markerStyle) == "table" and db.markerStyle or {}
    if db.version == 1 then
        if db.showMarker == nil then db.showMarker = db.showZone ~= false end
        if SameColor(db.zoneColor, LEGACY_ZONE) then db.zoneColor = nil end
        if SameColor(style.color, LEGACY_MARKER) then style.color = nil end
    end
    if (db.version == 1 or db.version == 2) and style.anchor == "FULL" then
        style.anchor = "AUTO"
        if style.width == 2 then style.width = 1 end
    end
    if not COOLDOWNS[db.iconCooldown] then db.iconCooldown = db.hideCooldown == false and "SHOW" or "HIDE" end
    db.hideCooldown = nil
    db.minExecutePercent = nil
    db.version = 8
    if type(db.enabled) ~= "boolean" then db.enabled = true end
    if type(db.showZone) ~= "boolean" then db.showZone = true end
    if type(db.showMarker) ~= "boolean" then db.showMarker = true end
    if type(db.showIcon) ~= "boolean" then db.showIcon = true end
    local validIcon
    for _, choice in ipairs(ns.iconChoices) do
        if db.iconSource == choice then validIcon = true; break end
    end
    if not validIcon then db.iconSource = "AUTO" end
    if type(db.showIconBorder) ~= "boolean" then db.showIconBorder = true end
    if not PULSES[db.iconPulse] then db.iconPulse = "OFF" end
    db.combatOnly = db.combatOnly == true
    if not LOCATIONS[db.location] then
        db.location = db.hideInInstances == true and "OUTSIDE" or "ANY"
    end
    db.hideInInstances = nil
    if type(db.showGlow) ~= "boolean" then db.showGlow = true end
    db.iconSize = Number(db.iconSize, 30, 14, 54)
    db.iconOffsetX = Number(db.iconOffsetX, 0, -40, 40)
    db.iconOffsetY = Number(db.iconOffsetY, 0, -35, 35)
    db.glowOpacity = Number(db.glowOpacity, 70, 0, 100)
    db.glowColor = Color(db.glowColor, { 1, 1, 1, 1 })
    db.minimap = type(db.minimap) == "table" and db.minimap or {}
    db.minimap.hide = db.minimap.hide == true
    db.minimap.minimapPos = Number(db.minimap.minimapPos, 195, -360, 360)
    db.margin = math.floor(Number(db.margin, 0, 0, 50))
    db.zoneColor = Color(db.zoneColor, LEGACY_ZONE)
    db.markerStyle = {
        anchor = ANCHORS[style.anchor] and style.anchor or "AUTO",
        width = Number(style.width, 1, 1, 6),
        height = Number(style.height, 5, 2, 20),
        color = Color(style.color, LEGACY_MARKER),
    }
    Sintezza_ExecuteDB, ns.db = db, db
end

function ns.ApplySettings()
    if not ns.db then return end
    local rule = ns.rule
    ns.threshold = rule and (rule.percent or ns.Threshold(ns.minimum, ns.db.margin))
    ns.texture = ns.IconTexture(ns.db.iconSource)
    ns.RefreshPlates()
    ns.RefreshPreview()
end

function ns.RefreshAbility(checkRank)
    if not ns.db then return end
    if checkRank then
        local _, class = UnitClass("player")
        if not ns.IsSecret(class) and type(class) == "string" then ns.class = class end
        local id, rule = ns.FindExecute(ns.class)
        if id ~= ns.spellID then
            ns.spellID, ns.minimum, ns.spellName, ns.spellTexture = id, nil, nil, nil
            ns.unreadableDamage = nil
            requestedRank = nil
        end
        ns.rule = rule
    end
    local id, rule = ns.spellID, ns.rule
    if id then
        if checkRank or not (ns.spellName and ns.spellTexture) then
            local name, texture = ns.SpellAppearance(id)
            ns.spellName, ns.spellTexture = name or ns.spellName, texture or ns.spellTexture
        end
        if not rule.percent then
            local ok, description = pcall(C_Spell and C_Spell.GetSpellDescription, id)
            if ok and not ns.IsSecret(description) and type(description) == "string" and description ~= "" then
                ns.minimum = ns.ParseMinimum(description) or ns.minimum
                ns.unreadableDamage = ns.minimum == nil
            end
        end
        if requestedRank ~= id and not (ns.spellName and ns.spellTexture and (rule.percent or ns.minimum)) then
            requestedRank = id
            pcall(C_Spell and C_Spell.RequestLoadSpellData, id)
        end
    end
    ns.ApplySettings()
end

local function QueueAbility()
    if pendingAbility then return end
    pendingAbility = true
    C_Timer.After(.05, function()
        pendingAbility = nil
        ns.RefreshAbility(true)
    end)
end

local function RegisterEvents()
    for _, event in ipairs({
        "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
        "SPELLS_CHANGED", "SPELL_TEXT_UPDATE", "SPELL_DATA_LOAD_RESULT", "SPELL_POWER_CHANGED",
        "PLAYER_EQUIPMENT_CHANGED", "UPDATE_SHAPESHIFT_FORM", "CHARACTER_POINTS_CHANGED",
        "PLAYER_DAMAGE_DONE_MODS", "PLAYER_LEVEL_UP", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
        "ZONE_CHANGED_NEW_AREA", "SPELL_UPDATE_COOLDOWN", "TRAIT_CONFIG_UPDATED", "ACTIVE_COMBAT_CONFIG_CHANGED",
        "PLAYER_TALENT_UPDATE", "LEARNED_SPELL_IN_TAB",
    }) do
        pcall(events.RegisterEvent, events, event)
    end
    if ns.class == "PRIEST" then pcall(events.RegisterUnitEvent, events, "UNIT_AURA", "player") end
end

events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, arg)
    if event == "ADDON_LOADED" then
        if arg == addon then
            ns.Media = "Interface\\AddOns\\" .. addon .. "\\Textures\\"
            ns.Theme = Sintezza_Theme:ForAddon()
            local ok, loaded = pcall(C_AddOns and C_AddOns.IsAddOnLoaded, "ShadowpriestExecute")
            ns.originalLoaded = ok and not ns.IsSecret(loaded) and loaded == true
            InitializeDatabase()
            ns.RefreshAbility(true)
            RegisterEvents()
            ns.RegisterOptions()
            ns.InitializeMinimap()
            ns.ReseedPlates()
        elseif arg == "ShadowpriestExecute" then
            ns.originalLoaded = true
            ns.RefreshPlates()
            ns.RefreshPreview()
            self:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        ns.AddPlate(arg)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        if not ns.IsSecret(arg) and type(arg) == "string" then ns.RemovePlate(arg) end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_LOGIN" then
        ns.RefreshAbility(true)
        ns.ReseedPlates()
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        if ns.db.showIcon and ns.db.iconCooldown ~= "SHOW" then ns.RefreshPlates(true) end
    elseif event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" or event == "ZONE_CHANGED_NEW_AREA" then
        ns.RefreshPlates()
        if ns.class == "PRIEST" then QueueAbility() end
    else
        QueueAbility()
    end
end)
