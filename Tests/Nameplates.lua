local function NewContext(addon)
    local controls = { health = 200, maximum = 1800, exists = true, ready = true }
    local counts = { ranges = 0, values = 0 }
    local realType = type
    local secretMeta = {
        __lt = function() error("secret ordering") end,
        __le = function() error("secret ordering") end,
        __eq = function() error("secret equality") end,
    }
    local function Secret(name, value)
        return setmetatable({ secret = true, name = name, value = value }, secretMeta)
    end
    local function IsSecret(value)
        return realType(value) == "table" and getmetatable(value) == secretMeta
    end
    local function Unwrap(value)
        if IsSecret(value) then return value.value end
        return value
    end
    local methods = {}
    local function Object(kind, parent)
        return setmetatable({ kind = kind, parent = parent, shown = true, alpha = 1, level = 10, scripts = {} },
            { __index = methods })
    end
    function methods:SetScript(event, callback) self.scripts[event] = callback end
    function methods:HookScript(event, callback)
        local original = self.scripts[event]
        self.scripts[event] = function(frame, ...)
            if original then original(frame, ...) end
            callback(frame, ...)
        end
    end
    function methods:Hide()
        local wasShown = self.shown
        self.shown = false
        if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function methods:Show() self.shown = true end
    function methods:SetShown(value) if value then self:Show() else self:Hide() end end
    function methods:IsVisible()
        return self.shown and (not self.parent or self.parent:IsVisible())
    end
    function methods:IsForbidden() return false end
    function methods:GetEffectiveAlpha()
        local inherited = self.parent and self.parent:GetEffectiveAlpha() or 1
        if IsSecret(self.alpha) then return self.alpha end
        if IsSecret(inherited) then return inherited end
        return self.alpha * inherited
    end
    function methods:GetAlpha() return self.alpha end
    function methods:SetAlpha(value)
        self.alpha = value
        if self.afterSetAlpha then self.afterSetAlpha(self, value) end
    end
    function methods:GetScale() return self.scale or 1 end
    function methods:SetIgnoreParentScale(value) self.ignoreParentScale = value end
    function methods:GetEffectiveScale()
        local inherited = not self.ignoreParentScale and self.parent and self.parent:GetEffectiveScale() or 1
        return self:GetScale() * inherited
    end
    function methods:SetScale(value)
        self.scale = value
        if self.afterScale then self.afterScale(self, value) end
    end
    function methods:SetAlphaFromBoolean(value, yes, no)
        self.alpha = Unwrap(value) and yes or no
        if self.afterSetAlphaFromBoolean then self.afterSetAlphaFromBoolean(self, value, yes, no) end
    end
    function methods:GetFrameLevel() return self.level end
    function methods:SetFrameLevel(value) self.level = value end
    function methods:GetFrameStrata()
        return self.strata or (self.parent and self.parent:GetFrameStrata()) or "MEDIUM"
    end
    function methods:SetFrameStrata(value) self.strata = value end
    function methods:EnableMouse(value) self.mouse = value end
    function methods:SetClipsChildren(value) self.clipped = value end
    function methods:SetIgnoringChildrenForBounds(value)
        if controls.noGate then error("bounds unsupported") end
        self.ignoreBounds = value
    end
    function methods:SetParent(parent) self.parent = parent end
    function methods:SetAllPoints(target) self.allPoints = target end
    function methods:SetPoint(...) self.point = { ... } end
    function methods:ClearAllPoints()
        self.point, self.allPoints = nil, nil
    end
    function methods:SetSize(width, height) self.width, self.height = width, height end
    function methods:SetWidth(width) self.width = width end
    function methods:SetHeight(height) self.height = height end
    function methods:SetReverseFill(value) self.reversed = value end
    function methods:GetReverseFill() return self.reversed end
    function methods:SetStatusBarTexture(texture)
        self.barTexture = Object("Texture", self)
        self.barTexture.texture = texture
    end
    function methods:GetStatusBarTexture() return self.barTexture end
    function methods:SetStatusBarColor(...) self.color = { ... } end
    function methods:SetColorTexture(...) self.color = { ... } end
    function methods:SetVertexColor(...) self.color = { ... } end
    function methods:SetTexture(value) self.texture = value end
    function methods:SetTexCoord(...) self.texCoord = { ... } end
    function methods:SetBlendMode(mode) self.blend = mode end
    function methods:CreateTexture() return Object("Texture", self) end
    function methods:SetMinMaxValues(minimum, maximum)
        if self.rejectSecretRange and IsSecret(maximum) then error("secret range rejected") end
        self.minimum, self.maximum = minimum, maximum
        self.rangeWrites = (self.rangeWrites or 0) + 1
        counts.ranges = counts.ranges + 1
        if self.value and not IsSecret(maximum) and not IsSecret(self.value) then
            self.value = math.max(minimum, math.min(maximum, self.value))
        end
    end
    function methods:SetValue(value)
        if self.minimum and not IsSecret(value) and not IsSecret(self.maximum) then
            value = math.max(self.minimum, math.min(self.maximum, value))
        end
        self.value = value
        self.valueWrites = (self.valueWrites or 0) + 1
        counts.values = counts.values + 1
    end
    function methods:GetClipOverlap(clip)
        local minimum, maximum, value = Unwrap(self.minimum), Unwrap(self.maximum), Unwrap(self.value)
        local fill = math.max(0, math.min(1, (value - minimum) / (maximum - minimum)))
        assert(self.point[1] == "RIGHT" and clip.point[1] == "RIGHT")
        local inset = self.reversed and fill or (1 - fill)
        assert(clip.point[3] == (self.reversed and "LEFT" or "RIGHT"))
        return math.max(0, clip.width - inset * self.width)
    end
    function methods:SetDrawEdge(value) self.drawEdge = value end
    function methods:SetHideCountdownNumbers(value) self.hideNumbers = value end
    function methods:SetDrawSwipe(value) self.swipe = value end
    function methods:SetCooldown(start, duration) self.cooldown = { start, duration } end
    function methods:SetCooldownFromDurationObject(duration)
        self.duration = duration
        if controls.durationFailure then error("duration unavailable") end
    end
    local function Curve()
        local curve = { points = {} }
        function curve:SetType(value) self.kind = value end
        function curve:AddPoint(x, y) self.points[#self.points + 1] = { x, y } end
        function curve:Evaluate(value)
            if IsSecret(value) then error("curve cannot evaluate a secret input") end
            local result = self.points[1][2]
            for _, point in ipairs(self.points) do
                if value >= point[1] then result = point[2] end
            end
            return result
        end
        return curve
    end
    local theme = { accent = { 1, .7, .3, 1 }, muted = { .7, .6, .5, 1 } }
    function theme:FrameIcon(parent) return Object("Frame", parent) end
    local shared = { animateControls = true }
    function shared:Tint(target, method, color, alpha)
        target[method](target, color[1], color[2], color[3], alpha or color[4])
    end
    local environment = setmetatable({
        Sintezza_Theme = shared, Enum = { LuaCurveType = { Step = 1 } },
        UIParent = Object("Frame"),
        C_CurveUtil = { CreateCurve = Curve },
        hooksecurefunc = function(frame, method, callback)
            if method == "SetScale" then
                frame.afterScale = callback
            else
                frame["after" .. method] = callback
            end
        end,
        GetLocale = function() return "enUS" end,
        issecretvalue = IsSecret,
        type = function(value) return IsSecret(value) and "number" or realType(value) end,
        C_Spell = {
            GetSpellCooldown = function() return controls.cooldownInfo end,
            GetSpellCooldownDuration = function() return controls.duration end,
        },
        InCombatLockdown = function() return controls.combat end,
        IsInInstance = function() return controls.inside, controls.instanceKind end,
        UnitCanAttack = function() return true end,
        UnitIsDead = function() return controls.dead end,
        UnitCreatureType = function() return nil, controls.creatureType end,
        UnitHealthMax = function() return controls.maximum end,
        UnitHealth = function() return controls.health end,
        UnitExists = function() return controls.exists end,
        UnitHealthPercent = function(_, _, curve) return curve:Evaluate(controls.percent or .1) end,
    }, { __index = _G })
    environment.CreateFrame = function(kind, _, parent)
        return Object(kind, parent)
    end
    local plate = Object("Frame")
    local healthBar = Object("StatusBar", plate)
    plate.UnitFrame = { healthBar = healthBar }
    environment.C_NamePlate = { GetNamePlateForUnit = function() return plate end }
    local ns = {
        Theme = theme, Media = "Media/", rule = {}, class = "PRIEST", spellID = 1309636,
        threshold = 600, texture = "spell",
        db = {
            enabled = true, showZone = true, showMarker = true, showIcon = true,
            iconSource = "AUTO", showIconBorder = true, showGlow = true,
            glowOpacity = 70, iconSize = 30, iconOffsetX = 0, iconOffsetY = 0,
            iconPulse = "OFF", markerStyle = { anchor = "AUTO", width = 1, height = 5 },
            iconCooldown = "SHOW", location = "ANY",
        },
        RefreshAbility = function() end,
    }
    local function Load(name)
        local chunk = assert(loadfile(addon .. "/" .. name))
        setfenv(chunk, environment)
        chunk("Sintezza_Execute", ns)
    end
    Load("Damage.lua")
    Load("Nameplates.lua")
    return ns, controls, plate, healthBar, Secret, counts, environment
end

local assertions = 0
local function Check(value, message)
    assertions = assertions + 1
    assert(value, message)
end

local function Snapshot(overlay)
    local function Value(value)
        if type(value) == "table" and value.secret then return "secret:" .. value.name end
        return value
    end
    return table.concat({
        tostring(overlay.marker.shown), tostring(Value(overlay.marker.minimum)),
        tostring(Value(overlay.marker.maximum)), tostring(Value(overlay.marker.value)),
        tostring(overlay.window.shown), tostring(Value(overlay.window.alpha)),
        tostring(Value(overlay.holder.alpha)), tostring(overlay.icon.texture),
        tostring(overlay.useGate), tostring(overlay.cooldown and overlay.cooldown.shown),
        tostring(overlay.cooldown and overlay.cooldown.swipe),
    }, "|")
end

return function(addon)
    assertions = 0
    local ns, controls, plate, bar, Secret = NewContext(addon)
    local overlay = ns.CreateOverlay(plate)
    local results = {}
    local function Draw(maximum, health, threshold, ready, duration, preview, percentUnit)
        ns.DrawOverlay(overlay, bar, bar, maximum, health, threshold, "spell", ready,
            false, false, duration, preview, percentUnit)
        results[#results + 1] = Snapshot(overlay)
    end
    for _ = 1, 40 do Draw(1800, 900, 600, true) end
    local stableRanges, stableValues = overlay.marker.rangeWrites, overlay.marker.valueWrites
    Check(overlay.marker.value == 600 and overlay.marker.shown and not overlay.window.shown, "marker above the threshold")
    Draw(1800, 360, 406, true)
    Check(overlay.marker.shown and overlay.marker.value == 406 and overlay.window.shown,
        "damaged target still needs a marker when full health is above the threshold")
    Draw(600, 600, 600, true)
    Check(overlay.marker.shown and overlay.window.shown, "full-health kill keeps the enabled marker")
    ns.db.showIcon = false
    Draw(400, 100, 600, true)
    Check(overlay.marker.shown and not overlay.window.shown, "icon disabled keeps the marker")
    Draw(1800, 200, 600, true)
    Check(overlay.marker.value == 600, "threshold must be reapplied after range clamping")
    ns.db.showIcon = true
    Draw(1800, 900, 550, true)
    Check(not overlay.window.shown and overlay.marker.shown and overlay.marker.value == 550, "damage threshold tracks the setting")
    ns.db.showMarker, ns.db.showZone = false, false
    Draw(1800, 200, 550, true)
    Check(not overlay.marker.shown and overlay.window.shown, "icon-only setting")
    ns.db.showZone = true
    Draw(1800, 200, 550, true)
    Check(overlay.zone.shown and not overlay.edge.shown and overlay.window.shown, "fill is independent of the marker toggle")
    ns.db.showMarker, ns.db.showZone = true, true
    Draw(1800, 900, 550, true)
    Check(overlay.marker.shown, "restored marker")
    local beforeSecret = overlay.marker.rangeWrites
    local hiddenMax, hiddenHealth = Secret("maximum", 1800), Secret("health", 200)
    Draw(hiddenMax, hiddenHealth, 550, true)
    Draw(hiddenMax, hiddenHealth, 550, true)
    Check(overlay.marker.rangeWrites == beforeSecret + 2, "secret range is never compared or cached")
    Draw(1800, 900, 550, true)
    Check(overlay.marker.maximum == 1800, "public range after secret range")
    local hiddenFull = Secret("maximum", 550)
    Draw(Secret("maximum", 551), hiddenHealth, 550, true)
    Check(overlay.useGate and overlay.holder.alpha == 1, "clipping fallback for hidden health")
    Draw(1800, Secret("health above threshold", 551), 550, true)
    Check(overlay.gate:GetClipOverlap(overlay.clip) == 0, "one secret HP above the threshold clips the entire icon")
    Draw(1800, Secret("health at threshold", 550), 550, true)
    Check(overlay.gate:GetClipOverlap(overlay.clip) == overlay.clip.width, "the exact threshold reveals the entire icon")
    Draw(1800, hiddenHealth, 550, true)
    Check(overlay.gate:GetClipOverlap(overlay.clip) == overlay.clip.width, "health below the threshold keeps the entire icon")
    Draw(hiddenFull, hiddenHealth, 550, true)
    Check(overlay.marker.shown and overlay.window.shown, "hidden maximum within a single hit keeps the marker")
    ns.db.iconCooldown = "HIDE"
    Draw(hiddenFull, hiddenHealth, 550, false)
    Check(overlay.marker.shown and not overlay.window.shown, "hidden HP with the icon on cooldown keeps the marker")
    Draw(hiddenFull, hiddenHealth, 550, Secret("ready", false))
    Check(overlay.marker.shown and overlay.window.alpha == 0, "secret cooldown only hides the icon")
    ns.db.iconCooldown = "SHOW"
    Draw(1800, 200, 550, true)
    Check(not overlay.useGate, "public health returns from clipping fallback")
    for _, mode in ipairs({ "HIDE", "DIM", "SHOW", "TIMER" }) do
        ns.db.iconCooldown = mode
        Draw(550, 200, 550, false, {}, 1)
        if mode == "HIDE" then Check(not overlay.window.shown and overlay.marker.shown, "cooldown keeps the marker") end
        if mode == "DIM" then Check(overlay.window.alpha == .35 and overlay.marker.shown, "dim icon preserves marker") end
        if mode == "TIMER" then Check(overlay.cooldown.shown and overlay.marker.shown, "preview timer preserves marker") end
        Draw(550, 200, 550, true)
        Check(overlay.window.shown and overlay.marker.shown, "icon returns after cooldown without hiding the marker")
        Draw(550, 200, 550, Secret("ready", false), {})
        if mode == "HIDE" then
            Check(overlay.marker.alpha == 1 and overlay.window.alpha == 0, "hidden cooldown with public HP keeps the marker")
            Draw(550, 200, 550, Secret("ready", true))
            Check(overlay.marker.alpha == 1 and overlay.window.alpha == 1, "secret ready state only affects the icon")
        end
    end
    ns.db.iconCooldown = "SHOW"
    ns.rule = { percent = 20 }
    controls.percent = .2
    Draw(100, nil, 20, true, nil, nil, "nameplate1")
    Check(overlay.holder.alpha == 1 and overlay.marker.shown, "inclusive 20 percent preserves class marker")
    controls.percent = .21
    Draw(100, nil, 20, true, nil, nil, "nameplate1")
    Check(not overlay.window.shown, "above percentage threshold")
    ns.rule = { percent = 35, exclusive = true }
    controls.percent = .35
    Draw(100, nil, 35, true, nil, nil, "nameplate1")
    Check(not overlay.window.shown, "exclusive 35 percent")
    controls.percent = .34
    Draw(100, nil, 35, true, nil, nil, "nameplate1")
    Check(overlay.holder.alpha == 1, "below 35 percent")
    local live, state, livePlate, _, MakeSecret, _, env = NewContext(addon)
    local created
    local create = live.CreateOverlay
    live.CreateOverlay = function(...)
        created = create(...)
        return created
    end
    live.AddPlate("nameplate1")
    Check(created and created.window.shown, "Blizzard live overlay")
    state.dead = true
    live.RefreshPlates()
    Check(not created.window.shown, "dead unit is hidden")
    state.dead = false
    livePlate:SetFrameStrata("LOW")
    local customPlate = env.CreateFrame("Frame", nil, livePlate)
    local customBar = env.CreateFrame("StatusBar", nil, customPlate)
    customPlate.nameplate, customPlate.health = livePlate, customBar
    env.EllesmereNameplates_NS = { plates = { nameplate1 = customPlate } }
    state.maximum, state.health, live.threshold = MakeSecret("max", 5211), 5211, 406
    live.RefreshPlates()
    Check(created.marker.shown and created.edge.shown and not created.window.shown
        and created.marker.strata == "HIGH" and created.root.strata == "MEDIUM"
        and created.marker:GetFrameLevel() > customBar:GetFrameLevel(),
        "Ellesmere threshold renders above the health fill before the icon triggers")
    Check(created.marker.parent == created.markerLayer and created.markerLayer.parent == env.UIParent
        and created.markerLayer.allPoints == created.root and created.marker.allPoints == customBar
        and created.root.parent == livePlate and created.window.parent == created.root,
        "Ellesmere marker escapes the native plate while the icon stays with it")
    livePlate:SetScale(1.1)
    livePlate:SetAlpha(.8)
    customPlate:SetScale(1.12)
    Check(created.root:GetScale() == 1.12, "overlay tracks the first scale change before the next refresh")
    Check(created.markerLayer:GetEffectiveScale() == customPlate:GetEffectiveScale(),
        "lifted marker follows effective scale between refreshes")
    customPlate:SetAlpha(.45)
    Check(created.markerLayer:GetAlpha() == customPlate:GetEffectiveAlpha(),
        "lifted marker follows dimmed native opacity immediately")
    live.RefreshPlates()
    Check(created.root:GetScale() == 1.12 and created.root:GetAlpha() == .45,
        "Ellesmere overlay follows deselected opacity and plate scale")
    customPlate:SetAlphaFromBoolean(MakeSecret("selected", true), 1, .45)
    Check(created.markerLayer:GetAlpha() == .8, "lifted marker follows the selected state without waiting for refresh")
    customPlate:SetScale(1.35)
    Check(created.root:GetScale() == 1.35, "overlay tracks animated scale between health refreshes")
    local opaqueAlpha = MakeSecret("alpha", 1)
    customPlate:SetAlpha(opaqueAlpha)
    live.RefreshPlates()
    Check(created.root:GetScale() == 1.35 and rawequal(created.root:GetAlpha(), opaqueAlpha),
        "selected scale and secret opacity reach only the owned overlay")
    Check(rawequal(created.markerLayer:GetAlpha(), opaqueAlpha), "lifted marker accepts secret effective opacity")
    local replacement = env.CreateFrame("Frame")
    env.C_NamePlate.GetNamePlateForUnit = function() return replacement end
    customPlate.nameplate = replacement
    customPlate:SetParent(replacement)
    live.RefreshPlates()
    Check(created.root.parent == replacement and created.marker.allPoints == customBar,
        "a pooled Ellesmere plate reconnects its overlay to the new native nameplate")
    state.maximum, state.health, live.threshold = 1800, 200, 600
    live.RefreshPlates()
    customPlate:Hide()
    Check(not created.marker.shown and not created.window.shown, "hidden owner immediately hides the lifted artwork")
    customPlate:Show()
    live.RefreshPlates()
    customBar:Hide()
    live.RefreshPlates()
    Check(not created.window.shown, "hidden Ellesmere bar keeps ownership")
    customBar:Show()
    live.RefreshPlates()
    Check(created.window.shown, "Ellesmere live overlay restored")
    live.RemovePlate("nameplate1")
    Check(not created.window.shown, "removed plate hides overlay")
    live.db.combatOnly = true
    state.combat = false
    live.AddPlate("nameplate1")
    Check(not created.window.shown, "combat filter")
    state.combat = true
    live.RefreshPlates()
    Check(created.window.shown, "combat filter allows combat")
    live.db.location, state.inside, state.instanceKind = "INSIDE", false, "none"
    live.RefreshPlates()
    Check(not created.window.shown, "instance filter")
    state.inside, state.instanceKind = true, "party"
    live.RefreshPlates()
    Check(created.window.shown, "dungeon filter")
    live.db.location, live.db.combatOnly = "ANY", false
    live.db.iconCooldown = "HIDE"
    state.cooldownInfo = { isActive = false }
    live.RefreshPlates(true)
    Check(created.window.shown, "ready cooldown flag")
    state.cooldownInfo = { isActive = true, isOnGCD = false }
    live.RefreshPlates(true)
    Check(not created.window.shown, "real cooldown flag")
    state.cooldownInfo = nil
    live.RefreshPlates()
    Check(not created.window.shown, "missing data keeps last confirmed cooldown")
    state.cooldownInfo = { isActive = true, isOnGCD = true }
    live.RefreshPlates(true)
    Check(created.window.shown, "global cooldown preserves ready state")
    live.db.iconCooldown, live.db.minExecutePercent = "SHOW", 100
    state.combat = true
    state.maximum, state.health = 30000, 900
    live.RefreshPlates()
    Check(created.marker.shown and created.edge.shown and not created.window.shown,
        "a large public maximum and an obsolete saved percent never suppress the marker")
    state.maximum, state.health = MakeSecret("max", 30000), MakeSecret("health", 600)
    live.RefreshPlates()
    Check(created.marker.shown and rawequal(created.marker.maximum, state.maximum) and created.window.shown,
        "a large secret maximum never suppresses the marker or an eligible icon")
    created.marker.rejectSecretRange = true
    live.RefreshPlates()
    Check(not created.marker.shown and created.window.shown, "a rejected marker range does not hide the icon")
    state.maximum = 0
    live.RefreshPlates()
    Check(not created.marker.shown and created.window.shown, "an unavailable maximum does not hide the icon")
    state.maximum = 30000
    live.RefreshPlates()
    Check(created.marker.shown and created.marker.maximum == 30000, "the marker recovers when maximum health returns")
    live.RemovePlate("nameplate1")
    created.root.strata, created.marker.strata, created.window.strata = nil, nil, nil
    live.AddPlate("nameplate1")
    Check(created.root.strata == "MEDIUM" and created.marker.strata == "HIGH" and created.window.strata == "MEDIUM",
        "reused Ellesmere nameplate restores the overlay strata")
    local summons, summon, _, _, Private = NewContext(addon)
    local summonOverlay
    local createSummon = summons.CreateOverlay
    summons.CreateOverlay = function(...)
        summonOverlay = createSummon(...)
        return summonOverlay
    end
    summon.combat, summon.maximum, summon.health = true, 5, 5
    summon.creatureType = 11
    summons.AddPlate("nameplate1")
    Check(not summonOverlay, "totem type is excluded even when its full health is in execute range")
    summons.RemovePlate("nameplate1")
    summon.creatureType = 1
    summons.AddPlate("nameplate1")
    Check(summonOverlay.marker.shown and summonOverlay.window.shown, "a beast on the recycled token gets the enabled indicator")
    summons.RemovePlate("nameplate1")
    summon.creatureType = Private("creature type", 11)
    summons.AddPlate("nameplate1")
    Check(summonOverlay.window.shown, "a secret type is left unclassified")
    summon.creatureType = 11
    summons.RefreshPlates()
    Check(not summonOverlay.marker.shown and not summonOverlay.window.shown,
        "a newly readable totem type hides any previous overlay")
    local unsupported, missing, host, emptyBar, Hidden = NewContext(addon)
    local protected = unsupported.CreateOverlay(host)
    protected.gate.SetValue = function() error("secret value unavailable") end
    unsupported.DrawOverlay(protected, emptyBar, emptyBar, Hidden("maximum", 600), Hidden("health", 200),
        600, "spell", true)
    Check(protected.marker.shown and not protected.window.shown,
        "a rejected icon clip keeps the marker")
    missing.noGate = true
    local withoutGate = unsupported.CreateOverlay(host)
    unsupported.DrawOverlay(withoutGate, emptyBar, emptyBar, 1800, Hidden("health", 200),
        600, "spell", true)
    Check(not withoutGate.window.shown, "unsupported secret-health fallback hides the icon")
    return { snapshots = table.concat(results, "\n"), ranges = stableRanges,
        values = stableValues, assertions = assertions }
end
