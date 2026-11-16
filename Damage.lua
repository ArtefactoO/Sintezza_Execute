-- Rank selection and threshold model adapted from Shadowpriest: Execute (MIT, goerkel).
local _, ns = ...
local locale = GetLocale()
local rules = {
    PRIEST = { ranks = { 1309636, 1309635, 1309633, 1309595 } },
    WARRIOR = { ranks = { 20662, 20661, 20660, 20658, 5308 }, percent = 20, noCooldown = true },
    PALADIN = { ranks = { 24239, 24274, 24275 }, percent = 20 },
    WARLOCK = { ranks = { 17924, 6353 }, percent = 35, exclusive = true, talentNode = 105897 },
}
ns.iconChoices = { "AUTO", "Skull", "Axe", "Dagger", "Scythe", "Hammer", "Slash" }

local rangeJoiners = {
    deDE = { "%s+bis%s+" },
    frFR = { "%s+à%s+", "%s+et%s+" },
    esES = { "%s+a%s+", "%s+y%s+" },
    esMX = { "%s+a%s+", "%s+y%s+" },
    itIT = { "%s+a%s+", "%s+e%s+" },
    ptBR = { "%s+a%s+", "%s+e%s+" },
    koKR = { "%s*에서%s*" },
    zhCN = { "%s*至%s*", "%s*到%s*" },
    zhTW = { "%s*至%s*", "%s*到%s*" },
}

function ns.IsSecret(value)
    return issecretvalue and issecretvalue(value) == true
end

local function ReadableCall(fn, ...)
    local ok, value = pcall(fn, ...)
    if ok and not ns.IsSecret(value) then return value end
end

local function HasTalent(nodeID)
    local spec = C_SpecializationInfo
    local group = ReadableCall(spec and spec.GetActiveSpecGroup)
    if type(group) ~= "number" then return false end
    local config = ReadableCall(spec.GetCombatConfigIDForSpecGroup, group)
    if type(config) ~= "number" or config <= 0 then return false end
    local node = ReadableCall(C_Traits and C_Traits.GetNodeInfo, config, nodeID)
    -- currentRank also counts changes staged in the talent window.
    local rank = node and node.activeRank
    return not ns.IsSecret(rank) and type(rank) == "number" and rank > 0
end

function ns.FindExecute(class)
    local rule = rules[class]
    local book = C_SpellBook
    local known = book and (book.IsSpellKnown or book.IsSpellInSpellBook)
    if not rule or not known then return end
    for _, id in ipairs(rule.ranks) do
        if ReadableCall(known, id) == true then
            if not rule.talentNode or HasTalent(rule.talentNode) then return id, rule end
            return
        end
    end
end

function ns.ParseMinimum(description)
    if ns.IsSecret(description) or type(description) ~= "string" then return end
    local text = description:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|n", "\n")
    text = text:gsub(" ", " "):gsub(" ", " "):gsub("–", "-"):gsub("—", "-"):match("^[^\r\n]+") or ""
    text = text:gsub("(%d)[,. ](%d%d%d)", "%1%2"):gsub("(%d)[,. ](%d%d%d)", "%1%2")
    local low, high
    if locale == "ruRU" then
        low, high = text:match("(%d+)%s*%-%s*(%d+)%s*ед%.?%s*урона")
        if not low then low, high = text:match("(%d+)%s+до%s+(%d+)%s*ед%.?%s*урона") end
        if not low then low, high = text:match("(%d+)%s*%-%s*(%d+)%s+урона") end
        if not low then low, high = text:match("(%d+)%s+до%s+(%d+)%s+урона") end
    end
    if not low then low, high = text:match("(%d+)%s+to%s+(%d+)%s+Shadow damage") end
    if not low then low, high = text:match("(%d+)%s*%-%s*(%d+)%s+Shadow damage") end
    if not low and rangeJoiners[locale] then
        -- Shadow Word: Death describes its damage first. Ignore numbers later in the tooltip.
        local firstDigit = text:find("%d")
        if not firstDigit then return end
        local range = text:sub(firstDigit):gsub("～", "-"):gsub("〜", "-"):gsub("~", "-")
        local after
        low, high, after = range:match("^(%d+)%s*%-%s*(%d+)()")
        for _, joiner in ipairs(rangeJoiners[locale]) do
            if low then break end
            low, high, after = range:match("^(%d+)" .. joiner .. "(%d+)()")
        end
        local tail = after and range:sub(after) or ""
        if tail:match("^%s*%%") or tail:match("^[,.]%d") or tail:find("^%s*％") then return end
    end
    low, high = tonumber(low), tonumber(high)
    if low and high and low > 0 and low <= high and high <= 999999999 then return low end
end

function ns.Threshold(minimum, margin)
    if minimum then return math.floor(minimum * (100 - margin) / 100) end
end

function ns.MaxHealthLimit(threshold, percent)
    if percent > 0 then return math.floor(threshold * 100 / percent) end
end

function ns.PassesDisplayConditions(db, inCombat, inDungeonOrRaid)
    if db.combatOnly and not inCombat then return false end
    if db.location == "INSIDE" then return inDungeonOrRaid == true end
    if db.location == "OUTSIDE" then return inDungeonOrRaid ~= true end
    return true
end

function ns.SpellAppearance(id)
    local spell = C_Spell
    return ReadableCall(spell and spell.GetSpellName, id), ReadableCall(spell and spell.GetSpellTexture, id)
end

function ns.IconTexture(choice)
    if choice == "AUTO" then return ns.spellTexture or ns.Media .. "Icon" end
    return ns.Media .. "Execute" .. choice
end

function ns.InExecuteRange(health, threshold, rule)
    if health <= 0 then return false end
    if rule.exclusive then return health < threshold end
    return health <= threshold
end

function ns.CooldownDuration(id)
    local ok, duration = pcall(C_Spell and C_Spell.GetSpellCooldownDuration, id, true)
    if not ok or ns.IsSecret(duration) or duration == nil then return end
    return duration
end

function ns.ReadCooldownFlags(id, fromCooldownEvent)
    local info = ReadableCall(C_Spell and C_Spell.GetSpellCooldown, id)
    if type(info) ~= "table" then return end
    local active = info.isActive
    if ns.IsSecret(active) or type(active) ~= "boolean" then return end
    if not active then return true end
    if fromCooldownEvent then
        -- isOnGCD is reliable only while handling SPELL_UPDATE_COOLDOWN.
        local gcd = info.isOnGCD
        if not ns.IsSecret(gcd) and type(gcd) == "boolean" then return gcd end
    end
end

function ns.CooldownReady(duration)
    if not duration then return end
    local got, ready = pcall(function() return duration:IsZero() end)
    if got and (ns.IsSecret(ready) or type(ready) == "boolean") then return ready end
end
