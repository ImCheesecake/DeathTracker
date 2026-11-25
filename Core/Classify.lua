-- Turns the Death Recap's killing blow into a cause: fall, drown, mob, player and so on, with the
-- killer, its NPC ID, the spell and how it hit; and keeps the last hits of the fight.
local _, ns = ...

local ENVIRONMENT = { FALLING = "fall", DROWNING = "drown", FATIGUE = "fatigue", FIRE = "fire",
    LAVA = "lava", SLIME = "slime" }

local FLAG = Enum.CombatLogObject

-- A secret value errors when compared, so every field goes through this first.
function ns.Readable(v)
    if v == nil or issecretvalue(v) then return nil end
    return v
end
local open = ns.Readable

-- A server statistic as a number: its text is "--" for none yet, a large count with commas.
function ns.Statistic(id) return tonumber((tostring(open(GetStatistic(id)) or ""):gsub("%D", ""))) or 0 end

local function has(flags, mask) return bit.band(flags, mask) ~= 0 end

-- "Creature-0-6849-0-7-1554-00005923BB": the kind is the first word, the NPC ID the sixth.
-- Forever scrambles the server and spawn parts, not the NPC ID.
local function parseGUID(guid)
    if not guid then return nil end
    local kind, _, _, _, _, id = strsplit("-", guid)
    return kind, tonumber(id)
end
ns.ParseGUID = parseGUID

-- The hits of the fight that killed you, newest first, from the Death Recap's events (newest first too).
-- A fight ends at a gap of FIGHT_GAP seconds without damage, so an earlier pull is left out.
-- hp: your health as the recap gives it with the hit; amount: what landed, the overkill taken off.
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
        -- The flags are the surest: a hunter's pet is player-controlled, a mob's pet isn't. A totem or
        -- guardian counts as a pet, as Blizzard's own combat log filter has it (COMBATLOG_FILTER_MY_PET).
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
