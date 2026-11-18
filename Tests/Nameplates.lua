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
    function methods:GetEffectiveAlpha() return self.alpha end
    function methods:SetAlpha(value) self.alpha = value end
    function methods:SetAlphaFromBoolean(value, yes, no) self.alpha = Unwrap(value) and yes or no end
    function methods:GetFrameLevel() return self.level end
    function methods:SetFrameLevel(value) self.level = value end
    function methods:GetFrameStrata() return "MEDIUM" end
    function methods:SetFrameStrata(value) self.strata = value end
    function methods:EnableMouse(value) self.mouse = value end
    function methods:SetClipsChildren(value) self.clipped = value end
    function methods:SetIgnoringChildrenForBounds(value)
        if controls.noGate then error("bounds unsupported") end
        self.ignoreBounds = value
    end
    function methods:SetParent(parent) self.parent = parent end
    function methods:SetAllPoints(target) self.allPoints = target end
    function methods:SetPoint(point, relative, ...)
        if controls.rejectThresholdAnchor and relative and relative.kind == "Texture" and point == "LEFT" then
            error("threshold clip anchor rejected")
        end
        self.point = { point, relative, ... }
        self.points = self.points or {}
        self.points[point] = self.point
    end
    function methods:ClearAllPoints()
        self.point, self.points, self.allPoints = nil, nil, nil
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
        self.minimum, self.maximum = minimum, maximum
        self.rangeWrites = (self.rangeWrites or 0) + 1
        counts.ranges = counts.ranges + 1
        if self.value and not IsSecret(maximum) and not IsSecret(self.value) then
            self.value = math.max(minimum, math.min(maximum, self.value))
        end
    end
    function methods:SetValue(value)
        if controls.rejectSecretBarValue and IsSecret(value) then error("secret bar value rejected") end
        if self.minimum and not IsSecret(value) and not IsSecret(self.maximum) then
            value = math.max(self.minimum, math.min(self.maximum, value))
        end
        self.value = value
        self.valueWrites = (self.valueWrites or 0) + 1
        counts.values = counts.values + 1
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
            if controls.curveFailure then error("curve unavailable") end
            if IsSecret(value) then return Secret("alpha", 1) end
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
        C_CurveUtil = { CreateCurve = Curve },
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
            iconCooldown = "SHOW", minExecutePercent = 5, location = "ANY",
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

local function ThresholdClipLeft(overlay, bar, width)
    local display = overlay.display
    assert(display.clipped)
    local clipAnchor = display.points.LEFT
    local fill = clipAnchor[2]
    local gate = fill.parent
    assert(clipAnchor[3] == "RIGHT" and fill == gate.barTexture)
    assert(gate.points.LEFT[2] == bar and gate.points.RIGHT[2] == bar)
    local left = gate.points.LEFT[4]
    local right = width + gate.points.RIGHT[4]
    local ratio = (gate.value.value - gate.minimum) / (gate.maximum - gate.minimum)
    return left + (right - left) * math.max(0, math.min(1, ratio))
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
    for _ = 1, 40 do Draw(1800, 200, 600, true) end
    local stableRanges, stableValues = overlay.marker.rangeWrites, overlay.marker.valueWrites
    Check(overlay.marker.value == 600 and overlay.window.shown, "visible below threshold")
    Draw(400, 100, 600, true)
    Draw(1800, 200, 600, true)
    Check(overlay.marker.value == 600, "threshold must be reapplied after range clamping")
    Draw(1800, 200, 550, true)
    Check(overlay.marker.value == 550, "changed damage threshold")
    Draw(1800, 900, 550, true)
    Check(not overlay.window.shown and overlay.marker.shown, "above threshold keeps marker")
    ns.db.showMarker, ns.db.showZone = false, false
    Draw(1800, 200, 550, true)
    Check(not overlay.marker.shown and overlay.window.shown, "icon-only setting")
    ns.db.showMarker, ns.db.showZone = true, true
    Draw(1800, 200, 550, true)
    Check(overlay.marker.shown, "restored marker")
    local beforeSecret = overlay.marker.rangeWrites
    local hiddenMax, hiddenHealth = Secret("maximum", 1800), Secret("health", 200)
    Draw(hiddenMax, hiddenHealth, 550, true)
    Draw(hiddenMax, hiddenHealth, 550, true)
    Check(overlay.marker.rangeWrites == beforeSecret + 2, "secret range is never compared or cached")
    Draw(1800, 200, 550, true)
    Check(overlay.marker.maximum == 1800, "public range after secret range")
    controls.curveFailure = true
    Draw(1800, hiddenHealth, 550, true)
    Check(overlay.useGate and overlay.holder.alpha == 1, "clipping fallback for hidden health")
    controls.curveFailure = false
    Draw(1800, 200, 550, true)
    Check(not overlay.useGate, "public health returns from clipping fallback")
    for _, mode in ipairs({ "HIDE", "DIM", "SHOW", "TIMER" }) do
        ns.db.iconCooldown = mode
        Draw(1800, 200, 550, false, {}, 1)
        if mode == "HIDE" then Check(not overlay.window.shown, "hidden on cooldown") end
        if mode == "DIM" then Check(overlay.window.alpha == .35, "dim on cooldown") end
        if mode == "TIMER" then Check(overlay.cooldown.shown, "preview cooldown timer") end
        Draw(1800, 200, 550, true)
        Check(overlay.window.shown, "ready after cooldown")
        Draw(1800, 200, 550, Secret("ready", false), {})
    end
    ns.db.iconCooldown = "SHOW"
    ns.rule = { percent = 20 }
    controls.percent = .2
    Draw(100, nil, 20, true, nil, nil, "nameplate1")
    Check(overlay.holder.alpha == 1, "inclusive 20 percent")
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
    local live, state, livePlate, liveBar, MakeSecret, _, env = NewContext(addon)
    local created
    local create = live.CreateOverlay
    live.CreateOverlay = function(parent)
        created = create(parent)
        return created
    end
    live.AddPlate("nameplate1")
    Check(created and created.window.shown, "Blizzard live overlay")
    state.dead = true
    live.RefreshPlates()
    Check(not created.window.shown, "dead unit is hidden")
    state.dead = false
    local customBar = liveBar
    env.EllesmereNameplates_NS = { plates = { nameplate1 = { nameplate = livePlate, health = customBar } } }
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
    live.db.iconCooldown, live.db.minExecutePercent = "SHOW", 10
    state.combat = true
    state.maximum = MakeSecret("max", 6000)
    live.RefreshPlates()
    Check(created.marker.parent == created.display and created.window.parent == created.display,
        "marker and icon share the clipping frame")
    Check(created.marker.shown and created.window.shown and ThresholdClipLeft(created, customBar, 120) <= 0,
        "secret maximum at exactly 10 percent shows the overlay")
    local filter = created.maxHealthGate
    Check(rawequal(filter.value, state.maximum) and filter.rangeWrites == 1,
        "filter sends the hidden health directly to the bar")
    state.maximum = MakeSecret("max", 6001)
    live.RefreshPlates()
    Check(ThresholdClipLeft(created, customBar, 120) > 120 + 1 + 40 + 70 and filter.rangeWrites == 1,
        "one HP over the limit clips even the largest outward-offset icon")
    live.db.minExecutePercent = 5
    live.RefreshPlates()
    Check(filter.minimum == 12000 and filter.maximum == 12001 and ThresholdClipLeft(created, customBar, 120) <= 0,
        "changing the existing setting moves the cutoff on the current plate")
    live.db.minExecutePercent = 0
    live.RefreshPlates()
    Check(not created.display.clipped and created.marker.shown and created.window.shown,
        "zero disables the secret-health filter")
    live.db.minExecutePercent = 10
    state.rejectThresholdAnchor = true
    live.RefreshPlates()
    Check(not created.display.clipped and not created.marker.shown and created.window.shown,
        "a rejected anchor hides the marker and fill and preserves the combat icon")
    env.UnitClassification = function() return "worldboss" end
    live.RefreshPlates()
    Check(not created.marker.shown and not created.window.shown, "a rejected anchor preserves the boss fallback")
    env.UnitClassification, state.rejectThresholdAnchor = nil, false
    live.RefreshPlates()
    Check(ThresholdClipLeft(created, customBar, 120) > 120,
        "a later successful reattachment restores the filter")
    state.rejectSecretBarValue = true
    live.RefreshPlates()
    Check(not created.display.clipped and not created.marker.shown and created.window.shown,
        "a rejected value after successful clipping clears stale clipping")
    state.rejectSecretBarValue = false
    state.maximum = 6000
    live.RefreshPlates()
    Check(not created.display.clipped and created.marker.shown, "public health at the cutoff uses the direct filter")
    state.maximum = 6001
    live.RefreshPlates()
    Check(not created.marker.shown and not created.window.shown, "public health above the cutoff hides the overlay")
    state.maximum = MakeSecret("max", 6001)
    live.RemovePlate("nameplate1")
    live.AddPlate("nameplate1")
    Check(ThresholdClipLeft(created, customBar, 120) > 120, "reused nameplate applies the current hidden maximum")
    local unsupported, missing, host, emptyBar, Hidden = NewContext(addon)
    missing.noGate, missing.curveFailure = true, true
    local withoutGate = unsupported.CreateOverlay(host)
    unsupported.DrawOverlay(withoutGate, emptyBar, emptyBar, 1800, Hidden("health", 200),
        600, "spell", true)
    Check(not withoutGate.window.shown, "unsupported secret-health fallback hides the icon")
    return { snapshots = table.concat(results, "\n"), ranges = stableRanges,
        values = stableValues, assertions = assertions }
end
