local addonName, ns = ...
local L = ns.L
local windowAppearance = Sintezza_Theme:NewWindowPreferences(function() return ns.db end)
if Sintezza_Theme.RegisterGlobalWindowPreferences then
    Sintezza_Theme:RegisterGlobalWindowPreferences("Sintezza Execute", windowAppearance)
end
local MAX_HEALTH, SAMPLE_DAMAGE = 1800, 600
ns.PREVIEW_COOLDOWN = 6
local healthPercent, cooldownStart, scenario = 20, nil, "combat"
local ui, category
local cooldownFeedback = {
    HIDE = L.WAIT_COOLDOWN,
    DIM = L.DIMMED_COOLDOWN,
    SHOW = L.VISIBLE_COOLDOWN,
    TIMER = L.TIMER_COOLDOWN,
}

local function TextureLabel(texture, label)
    return ("|T%s:16:16|t %s"):format(tostring(texture), label)
end

local function PreviewThreshold(rule)
    local minimum = rule and not rule.percent and (ns.minimum or SAMPLE_DAMAGE)
    return ns.threshold or ns.Threshold(minimum, ns.db.margin), minimum
end

local function StopCooldownTest(button)
    cooldownStart = nil
    button:SetScript("OnUpdate", nil)
    button.seconds = nil
    button.text:SetText(L.TEST_COOLDOWN)
    ui.cooldownProgress:Hide()
    ui.cooldownStatus:Hide()
end

local function UpdateCooldownTest(button)
    local remaining = cooldownStart + ns.PREVIEW_COOLDOWN - GetTime()
    if remaining <= 0 then
        StopCooldownTest(button)
        ui.cooldownStatus:SetText(L.TEST_COOLDOWN_DONE)
        ui.cooldownStatus:Show()
        ns.RefreshPreview()
        return
    end
    ui.cooldownProgress:SetValue(remaining)
    local seconds = math.ceil(remaining)
    if button.seconds ~= seconds then
        button.seconds = seconds
        ui.cooldownStatus:SetText(L.TEST_COOLDOWN_RUNNING:format(seconds))
    end
end

function ns.RefreshPreview()
    if not ui or not ui.panel:IsVisible() then return end
    if ui.detected then
        local label = ns.spellName or (ns.spellID and L.LOADING_ABILITY or L.NO_EXECUTE)
        ui.detected:SetText(ns.spellTexture and TextureLabel(ns.spellTexture, label) or label)
    end
    if ui.refreshControls and (ui.class ~= ns.class or ui.spellTexture ~= ns.spellTexture) then
        local reflow = ui.class ~= ns.class
        ui.class, ui.spellTexture = ns.class, ns.spellTexture
        ui.refreshControls(reflow)
    end
    if not ui.preview:IsVisible() then return end
    local db = ns.db
    local rule = ns.rule
    local percent = rule and rule.percent
    local threshold, minimum = PreviewThreshold(rule)
    local current = math.floor(MAX_HEALTH * healthPercent / 100)
    local measured = percent and healthPercent or current
    local canTestCooldown = threshold ~= nil and threshold > 0
    if not canTestCooldown and cooldownStart then StopCooldownTest(ui.testCooldown) end
    local onCooldown = cooldownStart and GetTime() < cooldownStart + ns.PREVIEW_COOLDOWN
    local enabled = db.enabled and (db.showZone or db.showMarker or db.showIcon)
    local meetsConditions = ns.PassesDisplayConditions(db, scenario ~= "outsideCombat", scenario == "instance")
    ui.bar:SetValue(current)
    ui.hp:SetText(("%d / %d"):format(current, MAX_HEALTH))
    if threshold and enabled and meetsConditions then
        ns.DrawOverlay(ui.overlay, ui.bar, ui.bar, percent and 100 or MAX_HEALTH, measured, threshold,
            ns.texture, not onCooldown, nil, nil, nil, onCooldown and cooldownStart)
    else
        ns.HideOverlay(ui.overlay)
    end
    local status
    if not threshold then status = L.NO_EXECUTE
    elseif not enabled then status = L.DISABLED
    elseif not meetsConditions then status = L.FILTERED_CONDITIONS
    elseif not ns.InExecuteRange(measured, threshold, rule) then status = L.ABOVE
    elseif onCooldown then status = db.showIcon and cooldownFeedback[db.iconCooldown] or L.TEST_ICON_OFF
    else status = rule.exclusive and L.IN_PHASE or L.IN_RANGE end
    local summary = threshold and (percent and (rule.exclusive and L.PHASE_THRESHOLD or L.PERCENT_THRESHOLD) or L.THRESHOLD)
    ui.result:SetText(summary and (status .. " · " .. summary:format(threshold)) or status)
    ui.damage:SetText(minimum and (ns.minimum and L.MINIMUM or L.SAMPLE):format(minimum)
        or (rule and rule.exclusive and L.PHASE_HELP) or "")
    ui.testCooldown:SetEnabled(canTestCooldown)
    if ns.class == "PRIEST" and ns.originalLoaded then ui.notice:SetText(L.ORIGINAL)
    elseif minimum and not ns.minimum then ui.notice:SetText(ns.unreadableDamage and L.UNREADABLE_DAMAGE or L.WAIT_TOOLTIP)
    else ui.notice:SetText("") end
end

local function StackSlider(row)
    row:SetHeight(40)
    row.label:ClearAllPoints()
    row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
    row.label:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -2)
    row.slider:ClearAllPoints()
    row.slider:SetPoint("BOTTOMLEFT", row)
    row.slider:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -48, 0)
end

local function BuildPreview(frame, parent, W, T)
    local card = W:Section(parent, L.PREVIEW, nil, "settings")
    card:SetPoint("TOPRIGHT", parent)
    card:SetPoint("BOTTOMRIGHT", parent)
    card:SetWidth(320)
    local scenarioRow = W:ChoiceRow(card, L.SCENARIO, { combat = L.IN_COMBAT,
        outsideCombat = L.OUT_OF_COMBAT, instance = L.DUNGEON_COMBAT }, function() return scenario end,
        function(value) scenario = value; ns.RefreshPreview() end, { combat = 1, outsideCombat = 2, instance = 3 })
    scenarioRow:SetPoint("TOPLEFT", 0, -card.headerHeight)
    scenarioRow:SetPoint("TOPRIGHT", 0, -card.headerHeight)
    local stage = CreateFrame("Frame", nil, card, "BackdropTemplate")
    stage:SetPoint("TOPLEFT", scenarioRow, "BOTTOMLEFT", 0, -6)
    stage:SetPoint("TOPRIGHT", scenarioRow, "BOTTOMRIGHT", 0, -6)
    stage:SetHeight(132)
    T:Backdrop(stage, T.input, T.lineSoft)
    T:Surface(stage, .48, .34, T.frameAccent, "window-brush.tga")
    local stageInset, iconSpace = 12, 114
    local bar = CreateFrame("StatusBar", nil, stage)
    bar:SetPoint("LEFT", stage, "LEFT", stageInset, -3)
    bar:SetPoint("RIGHT", stage, "RIGHT", -iconSpace, -3)
    bar:SetHeight(22)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetStatusBarColor(.62, .21, .22)
    bar:SetMinMaxValues(0, MAX_HEALTH)
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(bar)
    bg:SetColorTexture(.15, .08, .09)
    local name = W:Label(stage, L.DUMMY, 11, T.text)
    name:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 4)
    local overlay = ns.CreateOverlay(stage)
    local textLayer = CreateFrame("Frame", nil, stage)
    textLayer:SetAllPoints(bar)
    textLayer:SetFrameLevel(bar:GetFrameLevel() + 8)
    local hp = W:Label(textLayer, "", 10, T.text)
    hp:SetPoint("CENTER")
    hp:SetShadowOffset(1, -1)
    local cooldownStatus = W:Label(stage, "", 10, T.text)
    cooldownStatus:SetPoint("BOTTOMLEFT", stage, "BOTTOMLEFT", stageInset, 17)
    cooldownStatus:SetPoint("BOTTOMRIGHT", stage, "BOTTOMRIGHT", -iconSpace, 17)
    cooldownStatus:SetJustifyH("LEFT")
    cooldownStatus:Hide()
    local cooldownProgress = CreateFrame("StatusBar", nil, stage)
    cooldownProgress:SetPoint("BOTTOMLEFT", stage, "BOTTOMLEFT", stageInset, 10)
    cooldownProgress:SetPoint("BOTTOMRIGHT", stage, "BOTTOMRIGHT", -iconSpace, 10)
    cooldownProgress:SetHeight(4)
    cooldownProgress:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    cooldownProgress:SetMinMaxValues(0, ns.PREVIEW_COOLDOWN)
    local progressBackground = cooldownProgress:CreateTexture(nil, "BACKGROUND")
    progressBackground:SetAllPoints()
    Sintezza_Theme:Tint(cooldownProgress, "SetStatusBarColor", T.accent)
    Sintezza_Theme:Tint(progressBackground, "SetColorTexture", T.lineSoft)
    cooldownProgress:Hide()
    local healthRow = W:SliderRow(card, L.HEALTH, 1, 100, 1, function() return healthPercent end,
        function(value) healthPercent = value; ns.RefreshPreview() end, "%")
    StackSlider(healthRow)
    healthRow:HookScript("OnHide", function() healthRow.edit:ClearFocus() end)
    healthRow:SetPoint("TOPLEFT", stage, "BOTTOMLEFT", 0, -12)
    healthRow:SetPoint("TOPRIGHT", stage, "BOTTOMRIGHT", 0, -12)
    local testCooldown = W:Button(card, L.TEST_COOLDOWN, function(button)
        local rule = ns.rule
        local threshold = PreviewThreshold(rule)
        if not threshold or threshold <= 0 then return end
        local atThreshold = rule.percent and threshold or threshold * 100 / MAX_HEALTH
        local inRangePercent = rule.exclusive and math.ceil(atThreshold) - 1 or math.floor(atThreshold)
        healthPercent = math.max(1, math.min(healthPercent, inRangePercent))
        healthRow:Refresh()
        cooldownStart = GetTime()
        button.text:SetText(L.TEST_COOLDOWN_RESTART)
        cooldownProgress:Show()
        cooldownStatus:Show()
        UpdateCooldownTest(button)
        button:SetScript("OnUpdate", UpdateCooldownTest)
        ns.RefreshPreview()
    end)
    testCooldown:HookScript("OnHide", StopCooldownTest)
    testCooldown:SetPoint("TOPLEFT", healthRow, "BOTTOMLEFT", 0, -8)
    testCooldown:SetPoint("TOPRIGHT", healthRow, "BOTTOMRIGHT", 0, -8)
    local result = W:Label(card, "", 11, T.text)
    result:SetPoint("TOPLEFT", testCooldown, "BOTTOMLEFT", 0, -13)
    result:SetPoint("TOPRIGHT", testCooldown, "BOTTOMRIGHT", 0, -13)
    result:SetWordWrap(true)
    local damage = W:Label(card, "", 11, T.muted)
    damage:SetPoint("TOPLEFT", result, "BOTTOMLEFT", 0, -6)
    damage:SetPoint("TOPRIGHT", result, "BOTTOMRIGHT", 0, -6)
    damage:SetWordWrap(true)
    local notice = W:Label(card, "", 11, T.muted)
    notice:SetPoint("TOPLEFT", damage, "BOTTOMLEFT", 0, -8)
    notice:SetPoint("TOPRIGHT", damage, "BOTTOMRIGHT", 0, -8)
    notice:SetWordWrap(true)
    ui = { panel = frame, preview = card, bar = bar, overlay = overlay, hp = hp,
        result = result, damage = damage, notice = notice, testCooldown = testCooldown,
        cooldownStatus = cooldownStatus, cooldownProgress = cooldownProgress }
end

local function BuildNameplateSettings(parent, W, T)
    local db = ns.db
    local rows, refreshers = {}, {}
    local scroll, body, scrollbar = W:ScrollFrame(parent)
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT", ui.preview, "BOTTOMLEFT", -30, 0)
    scrollbar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 5, 0)
    scrollbar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 5, 0)
    scroll:HookScript("OnSizeChanged", function(self, width)
        body:SetWidth(math.max(1, width))
        self:RefreshRange()
    end)
    body:SetWidth(math.max(1, scroll:GetWidth()))

    local function Layout()
        local y = 0
        for _, entry in ipairs(rows) do
            local row = entry.row
            local shown = not entry.visible or entry.visible()
            if shown then
                row:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -y)
                row:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, -y)
                y = y + row:GetHeight() + 4
            end
            row:SetShown(shown)
        end
        body:SetHeight(math.max(1, y))
        scroll:RefreshRange()
    end
    local function Add(row, available, visible)
        rows[#rows + 1] = { row = row, visible = visible }
        if available then W:BindAvailability(row, available) end
        if row.Refresh then refreshers[#refreshers + 1] = row end
        return row
    end
    local function RefreshRows()
        for _, row in ipairs(refreshers) do row:Refresh(false) end
    end
    local function Apply()
        ns.ApplySettings()
        RefreshRows()
    end
    local function Set(key)
        return function(value) db[key] = value; Apply() end
    end
    local function Get(key)
        return function() return db[key] end
    end
    local function Toggle(label, key, available, help)
        local row = W:Toggle(body, label, Get(key), Set(key))
        if W.Help and help then W:Help(row, help) end
        Add(row, available)
    end
    local function Slider(label, minimum, maximum, get, set, suffix, available, help, visible)
        local row = W:SliderRow(body, label, minimum, maximum, 1, get, set, suffix)
        row:HookScript("OnHide", function() row.edit:ClearFocus() end)
        if W.Help and help then W:Help(row, help) end
        Add(row, available, visible)
    end
    local function Color(label, get, set, available)
        local row = Add(W:ColorRow(body, label, get, set), available)
        row.label:SetPoint("RIGHT", row, "RIGHT", -48, 0)
        Sintezza_Theme:TrackAppearance(row, "executeColor", function(owner) owner:Refresh() end)
    end
    local function Style(key)
        return function(value)
            local old = db.markerStyle
            local style = { anchor = old.anchor, width = old.width, height = old.height, color = old.color }
            style[key] = value
            db.markerStyle = style
            Apply()
        end
    end
    local function MarkerOn() return db.showMarker end
    local function IconOn() return db.showIcon end
    local function NativeIconOn() return db.showIcon and db.iconSource == "AUTO" end
    local function GlowOn() return NativeIconOn() and db.showGlow end
    local function DamageThreshold() return ns.class == "PRIEST" end
    local function Heading(label)
        local section = W:Section(body, label, nil, "settings")
        section:SetHeight(section.headerHeight)
        Add(section)
    end

    Heading(L.ABILITY)
    local abilityRow = Add(W:SettingRow(body, L.DETECTED_ABILITY))
    abilityRow.label:SetPoint("RIGHT", abilityRow, "CENTER", -4, 0)
    ui.detected = W:Label(abilityRow, "", 11, T.text)
    ui.detected:SetPoint("LEFT", abilityRow, "CENTER", 4, 0)
    ui.detected:SetPoint("RIGHT", abilityRow, "RIGHT", -4, 0)
    ui.detected:SetJustifyH("RIGHT")
    ui.detected:SetWordWrap(false)
    Slider(L.MARGIN, 0, 50, Get("margin"), Set("margin"), "%", nil, L.MARGIN_HELP, DamageThreshold)
    Heading(L.WHEN)
    Toggle(L.ENABLED, "enabled")
    Toggle(L.COMBAT_ONLY, "combatOnly")
    Add(W:ChoiceRow(body, L.LOCATION, { ANY = L.ANYWHERE, INSIDE = L.INSIDE, OUTSIDE = L.OUTSIDE },
        Get("location"), Set("location"), { ANY = 1, INSIDE = 2, OUTSIDE = 3 }))

    Heading(L.FILL_MARKER)
    Toggle(L.ZONE, "showZone")
    Color(L.COLOR, ns.GetZoneColor, Set("zoneColor"), Get("showZone"))
    Toggle(L.MARKER, "showMarker", nil, L.MARKER_HELP)
    Color(L.MARKER_COLOR, function() return db.markerStyle.color or T.muted end, Style("color"), MarkerOn)
    Add(W:ChoiceRow(body, L.MARKER_ANCHOR, { AUTO = L.AUTO, FULL = L.FULL, BOTTOM = L.BOTTOM,
        CENTER = L.CENTER, TOP = L.TOP }, function() return db.markerStyle.anchor end, Style("anchor"),
        { AUTO = 1, FULL = 2, BOTTOM = 3, CENTER = 4, TOP = 5 }), MarkerOn)
    Slider(L.MARKER_WIDTH, 1, 6, function() return db.markerStyle.width end, Style("width"), nil, MarkerOn)
    Slider(L.MARKER_HEIGHT, 2, 20, function() return db.markerStyle.height end, Style("height"), nil,
        function()
            local anchor = db.markerStyle.anchor
            return db.showMarker and anchor ~= "FULL" and not (anchor == "AUTO" and db.showZone)
        end)

    Heading(L.ICON_SECTION)
    Toggle(L.ICON, "showIcon")
    local order = {}
    for index, choice in ipairs(ns.iconChoices) do order[choice] = index end
    local function IconOptions()
        local choices = {}
        for _, choice in ipairs(ns.iconChoices) do
            choices[choice] = TextureLabel(ns.IconTexture(choice), L.ICON_CHOICES[choice])
        end
        return choices
    end
    local iconChoice = Add(W:ChoiceRow(body, L.ICON_SOURCE, IconOptions, Get("iconSource"), Set("iconSource"), order), IconOn)
    iconChoice.button:SetWidth(198)
    iconChoice.button.stepFromKeyboard = nil
    Toggle(L.ICON_BORDER, "showIconBorder", NativeIconOn)
    Add(W:ChoiceRow(body, L.ICON_COOLDOWN, { SHOW = L.COOLDOWN_SHOW, HIDE = L.COOLDOWN_HIDE,
        DIM = L.COOLDOWN_DIM, TIMER = L.COOLDOWN_TIMER }, Get("iconCooldown"), Set("iconCooldown"),
        { DIM = 1, HIDE = 2, SHOW = 3, TIMER = 4 }), function() return IconOn() and ns.class ~= "WARRIOR" end)
    Slider(L.ICON_SIZE, 14, 54, Get("iconSize"), Set("iconSize"), nil, IconOn)
    Slider(L.ICON_X, -40, 40, Get("iconOffsetX"), Set("iconOffsetX"), nil, IconOn)
    Slider(L.ICON_Y, -35, 35, Get("iconOffsetY"), Set("iconOffsetY"), nil, IconOn)
    Heading(L.ICON_EFFECTS)
    Toggle(L.GLOW, "showGlow", NativeIconOn)
    local glowColor = W:ColorSwatch(body, L.GLOW_COLOR, function()
        local color = db.glowColor or T.accent
        return { color[1], color[2], color[3], 1 }
    end, function(r, g, b)
        Set("glowColor")({ r, g, b, 1 })
    end)
    function glowColor:SetAvailable(available)
        self:SetEnabled(available)
        self:SetAlpha(available and 1 or .38)
        if not available then W:CloseColorPicker(self) end
    end
    Add(glowColor, GlowOn)
    Sintezza_Theme:TrackAppearance(glowColor, "executeGlowColor", function(owner) owner:Refresh() end)
    Slider(L.GLOW_OPACITY, 0, 100, Get("glowOpacity"), Set("glowOpacity"), "%", GlowOn)
    local pulse = Add(W:ChoiceRow(body, L.ICON_PULSE, { OFF = L.PULSE_OFF, ICON = L.PULSE_ICON,
        GLOW = L.PULSE_GLOW, BOTH = L.PULSE_BOTH }, Get("iconPulse"), Set("iconPulse"),
        { OFF = 1, ICON = 2, GLOW = 3, BOTH = 4 }), IconOn)
    if W.Help then W:Help(pulse, L.PULSE_HINT) end
    Layout()

    ui.refreshControls = function(reflow)
        if reflow then Layout() end
        RefreshRows()
    end
    parent:HookScript("OnShow", function()
        RefreshRows()
        ns.RefreshPreview()
    end)
end

local function Build()
    local T = ns.Theme
    local W = Sintezza_Theme:CreateWidgets(T)
    local frame = CreateFrame("Frame", "Sintezza_ExecuteOptions", UIParent, "BackdropTemplate")
    frame:Hide()
    frame:SetSize(800, 544)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    T:WindowSurface(frame)
    local header = W:WindowHeader(frame, { title = L.TITLE, addonName = addonName, icon = ns.Media .. "Icon" })
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        if windowAppearance:CanMove() then frame:StartMoving() end
    end)
    header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    frame:HookScript("OnHide", function() frame:StopMovingOrSizing() end)
    if UISpecialFrames then table.insert(UISpecialFrames, frame:GetName()) end
    local selected = "nameplate"
    local pages = {}
    local keys = { "nameplate", "window" }
    local labels = { L.NAMEPLATE, L.WINDOW_MINIMAP }
    local tabs = W:Segmented(frame, labels, keys, function() return selected end, function(key)
        if selected == key then return end
        pages[selected]:Hide()
        selected = key
        pages[key]:Show()
    end, true)
    tabs:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 12, -4)
    tabs:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -12, -4)
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", tabs, "BOTTOMLEFT", 10, -12)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 16)
    local nameplate = CreateFrame("Frame", nil, content)
    nameplate:SetAllPoints()
    BuildPreview(frame, nameplate, W, T)
    BuildNameplateSettings(nameplate, W, T)
    pages.nameplate = nameplate

    local window = Sintezza_Theme:CreateWindowOptions(content, T, {
        windows = { { prefs = windowAppearance } },
        getMinimap = function() return not ns.db.minimap.hide end,
        setMinimap = ns.SetMinimapShown,
    })
    -- The shared panel applies its own row insets.
    window:SetPoint("TOPLEFT", -W.CONTROL_INSET, 0)
    window:SetPoint("TOPRIGHT", W.CONTROL_INSET, 0)
    window:Hide()
    pages.window = window
    tabs:Refresh()
    Sintezza_Theme:TrackAppearance(frame, "executePreview", ns.RefreshPreview)
    windowAppearance:Bind(frame, { resize = { minWidth = 760, minHeight = 500, maxWidth = 1300, maxHeight = 920 } })
end

function ns.GetSettingsWindow()
    return ui and ui.panel
end

function ns.OpenSettings()
    if not ui then Build() end
    local frame = ui.panel
    windowAppearance:ApplyTo(frame)
    frame:Show()
    frame:Raise()
    ns.RefreshPreview()
end

function ns.RegisterOptions()
    if not category then
        category = Sintezza_Theme:RegisterLauncherPage({
            title = L.TITLE, icon = ns.Media .. "Icon", buttonLabel = L.OPEN,
            open = ns.OpenSettings, appearance = ns.Theme,
        })
    end
    SLASH_SINTEZZA_EXECUTE1 = "/sexecute"
    SLASH_SINTEZZA_EXECUTE2 = "/sintezza_execute"
    if not ns.originalLoaded then
        SLASH_SINTEZZA_EXECUTE3 = "/spx"
        SLASH_SINTEZZA_EXECUTE4 = "/spexecute"
        SLASH_SINTEZZA_EXECUTE5 = "/tods"
    end
    SlashCmdList.SINTEZZA_EXECUTE = ns.OpenSettings
end
