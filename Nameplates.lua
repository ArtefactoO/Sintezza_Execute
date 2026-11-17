-- Status-bar threshold, clipped icon and health-bar detection adapted from Shadowpriest: Execute and DoesItDie.
-- See LICENSE.txt for the MIT notices.
local _, ns = ...
local shared = Sintezza_Theme
local WHITE = "Interface\\Buttons\\WHITE8X8"
local ICON_TRAVEL = 10000
local ZONE_ALPHA = .35
local units, overlays = {}, setmetatable({}, { __mode = "k" })
local cooldownSpell, lastReady, lastDuration
local healthCurve, healthCurveThreshold
local maxHealthCurve, maxHealthCurveLimit
local percentCurve, percentCurveRule
local driver = CreateFrame("Frame")
driver:Hide()

local function PlainCall(fn, ...)
    local ok, value = pcall(fn, ...)
    if ok and not ns.IsSecret(value) then return value end
end

local function Visible(frame)
    return frame and PlainCall(frame.IsForbidden, frame) == false and PlainCall(frame.IsVisible, frame) == true
end

local function VisibleBar(frame)
    if not Visible(frame) then return false end
    local alpha = PlainCall(frame.GetEffectiveAlpha, frame)
    return alpha == nil or alpha > .01
end

local function FindBar(plate, unit)
    local eui = EllesmereNameplates_NS
    local custom = type(eui) == "table" and type(eui.plates) == "table" and eui.plates[unit]
    if type(custom) == "table" and custom.nameplate == plate and custom.health then
        -- A hidden Ellesmere bar still owns this plate.
        if Visible(custom.health) then return custom, custom.health, custom.health, false, true end
        return
    end
    local frame = plate.UnitFrame
    if not frame then return plate, plate, plate, true end
    local container = frame.HealthBarsContainer
    local bar = frame.healthBar or (container and container.healthBar) or frame.HealthBar
    if VisibleBar(bar) then
        return plate, bar, bar
    end
    return plate, plate, plate, true
end

local function InvisibleBar(parent)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetStatusBarTexture(WHITE)
    bar:SetStatusBarColor(0, 0, 0, 0)
    bar:EnableMouse(false)
    return bar
end

local function SetPulsePlaying(group, play)
    if not group or group:IsPlaying() == play then return end
    if play then group:Play() else group:Stop() end
end

local function CreatePulse(region, kind)
    local group = region:CreateAnimationGroup()
    group:SetLooping("BOUNCE")
    local animation = group:CreateAnimation(kind)
    animation:SetDuration(.55)
    animation:SetSmoothing("IN_OUT")
    if kind == "Scale" then
        animation:SetOrigin("CENTER", 0, 0)
        animation:SetScaleFrom(1, 1)
        animation:SetScaleTo(1.16, 1.16)
    else
        animation:SetFromAlpha(.35)
        animation:SetToAlpha(1)
    end
    return group
end

local function UpdatePulse(w)
    local db = ns.db
    local mode = db.iconPulse
    local animate = mode ~= "OFF" and shared.animateControls ~= false
        and PlainCall(w.window.IsVisible, w.window) == true
    local scale = animate and (mode == "ICON" or mode == "BOTH")
    local glow = animate and w.showGlow and db.glowOpacity > 0 and (mode == "GLOW" or mode == "BOTH")
    if scale and not w.scalePulse then w.scalePulse = CreatePulse(w.iconFrame, "Scale") end
    if glow and not w.glowPulse then w.glowPulse = CreatePulse(w.glow, "Alpha") end
    SetPulsePlaying(w.scalePulse, scale)
    SetPulsePlaying(w.glowPulse, glow)
end

function ns.CreateOverlay(host)
    local root = CreateFrame("Frame", nil, host)
    root:SetAllPoints(host)
    root:EnableMouse(false)
    local marker = InvisibleBar(root)
    local span = marker:GetStatusBarTexture()
    local zone = marker:CreateTexture(nil, "ARTWORK")
    zone:SetAllPoints(span)
    local edge = marker:CreateTexture(nil, "OVERLAY")
    local window = CreateFrame("Frame", nil, root)
    window:EnableMouse(false)
    window:SetClipsChildren(true)
    local supportsGate = window.SetIgnoringChildrenForBounds
        and pcall(window.SetIgnoringChildrenForBounds, window, true)
    local gate, clip
    if supportsGate then
        gate = InvisibleBar(window)
        gate:SetPoint("RIGHT", window, "RIGHT")
        clip = CreateFrame("Frame", nil, gate)
        clip:EnableMouse(false)
        clip:SetClipsChildren(true)
        clip:SetIgnoringChildrenForBounds(true)
        clip:SetPoint("RIGHT", gate:GetStatusBarTexture(), "RIGHT")
    end
    local holder = CreateFrame("Frame", nil, window)
    holder:SetPoint("RIGHT", window, "RIGHT")
    local glow = holder:CreateTexture(nil, "ARTWORK")
    glow:SetAllPoints(holder)
    glow:SetTexture(ns.Media .. "GlowSoft")
    glow:SetBlendMode("ADD")
    local iconFrame = CreateFrame("Frame", nil, holder)
    iconFrame:SetPoint("CENTER")
    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(iconFrame)
    icon:SetTexCoord(.06, .94, .06, .94)
    local border = ns.Theme:FrameIcon(iconFrame, icon)
    marker:Hide()
    window:Hide()
    local overlay = { root = root, marker = marker, span = span, zone = zone, edge = edge, window = window, gate = gate, clip = clip,
        holder = holder, iconFrame = iconFrame, icon = icon, border = border, glow = glow }
    window:SetScript("OnHide", function()
        SetPulsePlaying(overlay.scalePulse, false)
        SetPulsePlaying(overlay.glowPulse, false)
    end)
    return overlay
end

local function Hide(w)
    w.marker:Hide()
    w.window:Hide()
end
ns.HideOverlay = Hide

local function Attach(w, bar, anchor, matchStrata, db)
    local x, y = db.iconOffsetX, db.iconOffsetY
    if w.bar == bar and w.anchor == anchor and w.matchStrata == matchStrata and w.x == x and w.y == y then return end
    w.marker:ClearAllPoints()
    w.marker:SetAllPoints(bar)
    w.window:ClearAllPoints()
    w.window:SetPoint("LEFT", anchor, "RIGHT", 1 + x, y)
    if matchStrata then
        local strata = PlainCall(bar.GetFrameStrata, bar)
        if type(strata) == "string" then
            w.marker:SetFrameStrata(strata)
            w.window:SetFrameStrata(strata)
        end
    end
    w.bar, w.anchor, w.matchStrata, w.level = bar, anchor, matchStrata, nil
    w.x, w.y = x, y
end

local function UpdateStyle(w, bar, db)
    local level = PlainCall(bar.GetFrameLevel, bar)
    if type(level) == "number" and w.level ~= level then
        w.marker:SetFrameLevel(level + 5)
        w.window:SetFrameLevel(level + 20)
        w.level = level
    end
    if w.iconSize ~= db.iconSize then
        local size = db.iconSize + 16
        w.window:SetSize(size, size)
        w.holder:SetSize(size, size)
        if w.gate then
            w.gate:SetSize(ICON_TRAVEL, size)
            w.clip:SetSize(size, size)
        end
        w.iconFrame:SetSize(db.iconSize, db.iconSize)
        w.iconSize = db.iconSize
    end
    local nativeIcon = db.iconSource == "AUTO"
    if w.nativeIcon ~= nativeIcon then
        local crop = nativeIcon and .06 or 0
        w.icon:SetTexCoord(crop, 1 - crop, crop, 1 - crop)
        w.nativeIcon = nativeIcon
    end
    local showBorder, showGlow = nativeIcon and db.showIconBorder, nativeIcon and db.showGlow
    if w.showIconBorder ~= showBorder then
        w.border:SetShown(showBorder)
        w.showIconBorder = showBorder
    end
    if w.showGlow ~= showGlow or w.glowColor ~= db.glowColor or w.glowOpacity ~= db.glowOpacity then
        w.glow:SetShown(showGlow)
        shared:Tint(w.glow, "SetVertexColor", db.glowColor or ns.Theme.accent, db.glowOpacity / 100)
        w.showGlow, w.glowColor, w.glowOpacity = showGlow, db.glowColor, db.glowOpacity
    end
    local reversed = PlainCall(bar.GetReverseFill, bar) == true
    local style = db.markerStyle
    if w.reversed == reversed and w.style == style and w.zoneColor == db.zoneColor and w.showZone == db.showZone then return end
    local far = reversed and "LEFT" or "RIGHT"
    local anchor, width = style.anchor, style.width
    if anchor == "AUTO" then anchor = db.showZone and "FULL" or "BOTTOM" end
    w.marker:SetReverseFill(reversed)
    w.edge:ClearAllPoints()
    if anchor == "FULL" then
        w.edge:SetPoint("TOP" .. far, w.span, "TOP" .. far)
        w.edge:SetPoint("BOTTOM" .. far, w.span, "BOTTOM" .. far)
        w.edge:SetWidth(width)
    else
        local at = anchor == "CENTER" and far or anchor .. far
        local offset = anchor == "TOP" and -2 or anchor == "BOTTOM" and 2 or 0
        w.edge:SetPoint(at, w.span, at, 0, offset)
        w.edge:SetSize(width, style.height)
    end
    shared:Tint(w.zone, "SetColorTexture", db.zoneColor or ns.Theme.accent, not db.zoneColor and ZONE_ALPHA or nil)
    shared:Tint(w.edge, "SetColorTexture", style.color or ns.Theme.muted)
    w.reversed, w.style, w.zoneColor, w.showZone = reversed, style, db.zoneColor, db.showZone
end

function ns.GetZoneColor()
    local color = ns.Theme.accent
    return ns.db.zoneColor or { color[1], color[2], color[3], ZONE_ALPHA }
end

local function DrawCooldown(w, duration, previewStart)
    if not duration and not previewStart then
        if w.cooldown then w.cooldown:Hide() end
        return
    end
    if not w.cooldown then
        local ok, frame = pcall(CreateFrame, "Cooldown", nil, w.iconFrame, "CooldownFrameTemplate")
        if not ok or not frame then return end
        frame:SetAllPoints(w.icon)
        frame:SetFrameLevel(w.iconFrame:GetFrameLevel() + 1)
        frame:EnableMouse(false)
        frame:SetDrawEdge(false)
        if frame.SetHideCountdownNumbers then frame:SetHideCountdownNumbers(false) end
        w.cooldown = frame
    end
    local frame, ok = w.cooldown
    if frame.SetDrawSwipe and w.cooldownSwipe ~= w.nativeIcon then
        frame:SetDrawSwipe(w.nativeIcon)
        w.cooldownSwipe = w.nativeIcon
    end
    if previewStart then
        ok = pcall(frame.SetCooldown, frame, previewStart, ns.PREVIEW_COOLDOWN)
    elseif frame.SetCooldownFromDurationObject then
        ok = pcall(frame.SetCooldownFromDurationObject, frame, duration)
    end
    frame:SetShown(ok == true)
end

local function ApplyHealthAlpha(holder, health, threshold)
    if not healthCurve or healthCurveThreshold ~= threshold then
        local curve = C_CurveUtil.CreateCurve()
        curve:SetType(Enum.LuaCurveType.Step)
        curve:AddPoint(0, 0)
        curve:AddPoint(.5, 1)
        curve:AddPoint(threshold + .5, 0)
        healthCurve, healthCurveThreshold = curve, threshold
    end
    holder:SetAlpha(healthCurve:Evaluate(health))
end

local function PercentAlpha(unit, rule)
    if not percentCurve or percentCurveRule ~= rule then
        local curve = C_CurveUtil.CreateCurve()
        curve:SetType(Enum.LuaCurveType.Step)
        curve:AddPoint(0, 0)
        curve:AddPoint(1e-8, 1)
        -- A step switches at the boundary. Move it past the inclusive 20% point.
        curve:AddPoint(rule.percent / 100 + (rule.exclusive and 0 or 1e-8), 0)
        percentCurve, percentCurveRule = curve, rule
    end
    return UnitHealthPercent(unit, false, percentCurve)
end

local function UpdateIconHealth(w, health, threshold, percentUnit)
    local useGate = false
    if percentUnit then
        local ok, alpha = pcall(PercentAlpha, percentUnit, ns.rule)
        if not ok then return false end
        if not ns.IsSecret(alpha) and (type(alpha) ~= "number" or alpha <= 0) then return false end
        if not pcall(w.holder.SetAlpha, w.holder, alpha) then return false end
    elseif ns.IsSecret(health) then
        if threshold <= 0 then return false end
        if not pcall(ApplyHealthAlpha, w.holder, health, threshold) then
            if not w.gate then return false end
            w.gate:SetMinMaxValues(0, health)
            w.gate:SetValue(threshold)
            useGate = true
            w.holder:SetAlpha(1)
        end
    else
        if not ns.InExecuteRange(health, threshold, ns.rule) then return false end
        w.holder:SetAlpha(1)
    end
    if w.useGate ~= useGate then
        -- Only the clipping frame follows the fill. The icon stays anchored to the window.
        w.holder:SetParent(useGate and w.clip or w.window)
        w.holder:ClearAllPoints()
        w.holder:SetPoint("RIGHT", w.window, "RIGHT")
        w.useGate = useGate
    end
    return true
end

function ns.DrawOverlay(w, bar, anchor, maxHealth, health, threshold, texture, ready, iconOnly, matchStrata,
    duration, previewStart, percentUnit)
    local db = ns.db
    Attach(w, bar, anchor, matchStrata, db)
    UpdateStyle(w, bar, db)
    if (db.showZone or db.showMarker) and not iconOnly then
        w.zone:SetShown(db.showZone)
        w.edge:SetShown(db.showMarker)
        local secretMaximum = ns.IsSecret(maxHealth)
        if secretMaximum or w.markerMaximum ~= maxHealth or w.markerThreshold ~= threshold then
            w.marker:SetMinMaxValues(0, maxHealth)
            w.marker:SetValue(threshold)
            w.markerMaximum = not secretMaximum and maxHealth or nil
            w.markerThreshold = threshold
        end
        w.marker:Show()
    else
        w.marker:Hide()
    end
    if not db.showIcon or not UpdateIconHealth(w, health, threshold, percentUnit) then
        w.window:Hide()
        return
    end
    if texture ~= w.texture then
        w.icon:SetTexture(texture)
        w.texture = texture
    end
    local cooldownMode = db.iconCooldown
    if (cooldownMode == "HIDE" or cooldownMode == "DIM") and ns.IsSecret(ready) then
        local coolingAlpha = cooldownMode == "HIDE" and 0 or .35
        pcall(w.window.SetAlphaFromBoolean, w.window, ready, 1, coolingAlpha)
    elseif cooldownMode == "HIDE" and ready ~= true then
        w.window:Hide()
        return
    else
        w.window:SetAlpha(cooldownMode == "DIM" and ready == false and .35 or 1)
    end
    if cooldownMode == "TIMER" and (ns.IsSecret(ready) or ready ~= true) then
        DrawCooldown(w, duration, previewStart)
    elseif w.cooldown then
        w.cooldown:Hide()
    end
    w.window:Show()
    UpdatePulse(w)
end

local function ApplyMaxHealthAlpha(root, maxHealth, limit)
    if not maxHealthCurve or maxHealthCurveLimit ~= limit then
        local curve = C_CurveUtil.CreateCurve()
        curve:SetType(Enum.LuaCurveType.Step)
        curve:AddPoint(0, 1)
        curve:AddPoint(limit + .5, 0)
        maxHealthCurve, maxHealthCurveLimit = curve, limit
    end
    root:SetAlpha(maxHealthCurve:Evaluate(maxHealth))
end

local function DrawUnit(unit, entry, ready, duration, limit)
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not Visible(plate) or PlainCall(UnitCanAttack, "player", unit) == false
        or PlainCall(UnitIsDead, unit) == true then return end
    local host, bar, anchor, iconOnly, matchStrata = FindBar(plate, unit)
    if not host then return end
    local percentUnit, maxHealth, health, secretMax
    if ns.rule.percent then
        percentUnit, maxHealth = unit, 100
    else
        maxHealth, health = UnitHealthMax(unit), UnitHealth(unit, false)
        if type(maxHealth) ~= "number" or type(health) ~= "number" then return end
        secretMax = ns.IsSecret(maxHealth)
        if not secretMax and (maxHealth <= 0 or (limit and maxHealth > limit)) then return end
    end
    local w = overlays[host]
    if not w then
        w = ns.CreateOverlay(host)
        overlays[host] = w
    elseif w.unit ~= unit then
        Hide(w)
    end
    if entry.overlay and entry.overlay ~= w and entry.overlay.unit == unit then Hide(entry.overlay) end
    entry.overlay, w.unit = w, unit
    if limit and secretMax then
        if not pcall(ApplyMaxHealthAlpha, w.root, maxHealth, limit) then
            if PlainCall(UnitIsBossMob, unit) == true or PlainCall(UnitClassification, unit) == "worldboss" then return end
            w.root:SetAlpha(1)
        end
    else
        w.root:SetAlpha(1)
    end
    ns.DrawOverlay(w, bar, anchor, maxHealth, health, ns.threshold, ns.texture, ready, iconOnly, matchStrata,
        duration, nil, percentUnit)
    return true
end

local function HasCooldownState(ready)
    return ns.IsSecret(ready) or type(ready) == "boolean"
end

local function PlateCooldown(spellID, fromCooldownEvent, showTimer)
    if cooldownSpell ~= spellID then
        cooldownSpell, lastReady, lastDuration = spellID, nil, nil
    end
    local ready = ns.ReadCooldownFlags(spellID, fromCooldownEvent)
    if ready == true then
        lastReady, lastDuration = true, nil
        return true
    end
    if ready == false then lastReady = false end

    local needsState = ready == nil and (fromCooldownEvent or not HasCooldownState(lastReady))
    local cooling = ns.IsSecret(lastReady) or lastReady == false
    if needsState or (showTimer and cooling and (fromCooldownEvent or not lastDuration)) then
        local duration = ns.CooldownDuration(spellID)
        if needsState then
            local observed = ns.CooldownReady(duration)
            if HasCooldownState(observed) then lastReady = observed end
        end
        if showTimer and duration then lastDuration = duration end
    end
    if not HasCooldownState(lastReady) then return true end
    return lastReady, lastDuration
end

function ns.RefreshPlates(fromCooldownEvent)
    if ns.PerfBridge then ns.PerfBridge.Count("refresh") end
    local db = ns.db
    local enabled = db and db.enabled and not (ns.class == "PRIEST" and ns.originalLoaded) and ns.spellID
        and (db.showZone or db.showMarker or db.showIcon)
    if enabled then
        local inCombat = not db.combatOnly or PlainCall(InCombatLockdown) == true
        local inDungeonOrRaid = false
        if db.location ~= "ANY" then
            local ok, _, kind = pcall(IsInInstance)
            inDungeonOrRaid = ok and not ns.IsSecret(kind) and (kind == "party" or kind == "raid")
        end
        enabled = ns.PassesDisplayConditions(db, inCombat, inDungeonOrRaid)
    end
    local active = not not (enabled and next(units))
    driver:SetShown(active)
    local ready, duration
    if not (db and db.showIcon and db.iconCooldown ~= "SHOW" and ns.spellID) then
        cooldownSpell, lastReady, lastDuration = nil, nil, nil
    elseif ns.rule.noCooldown then
        ready = true
    elseif active or fromCooldownEvent then
        ready, duration = PlateCooldown(ns.spellID, fromCooldownEvent, db.iconCooldown == "TIMER")
    end
    if not enabled or not ns.threshold then
        for _, w in pairs(overlays) do Hide(w) end
        return
    end
    if not active then return end
    local limit
    if not ns.rule.percent then limit = ns.MaxHealthLimit(ns.threshold, db.minExecutePercent) end
    for unit, entry in pairs(units) do
        local ok, drawn = pcall(DrawUnit, unit, entry, ready, duration, limit)
        if (not ok or not drawn) and entry.overlay and entry.overlay.unit == unit then Hide(entry.overlay) end
    end
end

function ns.RemovePlate(unit)
    local entry = units[unit]
    if not entry then return end
    if entry.overlay and entry.overlay.unit == unit then
        Hide(entry.overlay)
        entry.overlay.unit = nil
    end
    units[unit] = nil
    if not next(units) then
        driver:Hide()
    end
end

function ns.AddPlate(unit)
    if ns.IsSecret(unit) or type(unit) ~= "string" or not unit:match("^nameplate%d+$") then return end
    if not units[unit] then units[unit] = {} end
    ns.RefreshPlates()
end

function ns.ReseedPlates()
    for unit in pairs(units) do ns.RemovePlate(unit) end
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return end
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if PlainCall(UnitExists, unit) == true then units[unit] = {} end
    end
    ns.RefreshPlates()
end

local sinceDraw, sinceDamage = 0, 0
driver:SetScript("OnUpdate", function(_, elapsed)
    sinceDraw, sinceDamage = sinceDraw + elapsed, sinceDamage + elapsed
    if sinceDraw < .10 then return end
    sinceDraw = 0
    if sinceDamage >= .5 and ns.class == "PRIEST" then
        sinceDamage = 0
        ns.RefreshAbility()
    else
        ns.RefreshPlates()
    end
end)
