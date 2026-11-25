local _, ns = ...

local ENVIRONMENT = { FALLING = "fall", DROWNING = "drown", FATIGUE = "fatigue", FIRE = "fire",
    LAVA = "lava", SLIME = "slime" }

local FLAG = Enum.CombatLogObject

-- A secret value errors when compared.
function ns.Readable(v)
    if v == nil or issecretvalue(v) then return nil end
    return v
end
local open = ns.Readable

-- GetStatistic's text is "--" for none yet, and a large count has commas.
function ns.Statistic(id) return tonumber((tostring(open(GetStatistic(id)) or ""):gsub("%D", ""))) or 0 end

local function has(flags, mask) return bit.band(flags, mask) ~= 0 end

local function parseGUID(guid)
    if not guid then return nil end
    local kind, _, _, _, _, id = strsplit("-", guid)
    return kind, tonumber(id)
end
ns.ParseGUID = parseGUID

-- The Death Recap's events come newest first.
ns.FIGHT_GAP = 5
function ns.RecapHits(events)
    local hits, last, death = {}, nil, nil
    for _, e in ipairs(events or {}) do
        local at, amount = open(e.timestamp), open(e.amount)
        if at and last and last - at > ns.FIGHT_GAP then break end
        death, last = death or at, at or last
        local event, overkill = open(e.event), open(e.overkill) or 0
        local guid = open(e.sourceGUID)
        local kind, id = parseGUID(guid)
        local env = event == "ENVIRONMENTAL_DAMAGE" and open(e.environmentalType) or nil
        hits[#hits + 1] = { spell = open(e.spellName), spellId = open(e.spellId), melee = event == "SWING_DAMAGE" or nil,
            env = env and env:upper(), source = not open(e.hideCaster) and open(e.sourceName) or nil,
            npc = (kind == "Creature" or kind == "Vehicle") and id or nil, crit = open(e.critical) or nil,
            amount = amount and math.max(0, amount - math.max(0, overkill)), overkill = overkill > 0 and overkill or nil,
            hp = open(e.currentHP), before = at and death and death - at or nil }
    end
    return hits
end

function ns.Classify(e, myGUID)
    if not e then return { cause = "unknown" } end
    local event = open(e.event)
    if event == "ENVIRONMENTAL_DAMAGE" then
        local kind = open(e.environmentalType)
        return { cause = kind and ENVIRONMENT[kind:upper()] or "other", amount = open(e.amount) }
    end

    local guid, flags = open(e.sourceGUID), open(e.sourceFlags)
    local kind, id = parseGUID(guid)
    local c = { killer = open(e.sourceName), spell = open(e.spellName), melee = event == "SWING_DAMAGE" or nil,
        ranged = event == "RANGE_DAMAGE" or nil, amount = open(e.amount), overkill = open(e.overkill),
        school = open(e.school), crit = open(e.critical) or nil }
    if open(e.hideCaster) or not (guid or flags) or (flags and has(flags, FLAG.None) and not guid) then
        c.cause, c.killer = "unknown", nil
    elseif guid and guid == myGUID then
        c.cause = "self"
    elseif flags then
        -- A hunter's pet is player-controlled, a mob's pet isn't; Blizzard counts totems and guardians as pets.
        if has(flags, FLAG.ControlPlayer) then
            c.cause, c.pet, c.guid = "player", (has(flags, FLAG.TypePet) or has(flags, FLAG.TypeGuardian)) or nil, guid
        elseif has(flags, FLAG.TypeObject) or kind == "GameObject" then
            c.cause, c.killer = "unknown", nil
        else
            c.cause, c.npc, c.guid = "mob", id, guid
        end
    elseif kind == "Player" or kind == "Pet" then
        c.cause, c.pet, c.guid = "player", kind == "Pet" or nil, guid
    elseif kind == "Creature" or kind == "Vehicle" then
        c.cause, c.npc, c.guid = "mob", id, guid
    else
        c.cause, c.killer = "unknown", nil
    end
    return c
end
