-- The history window's numbers, worked out from the saved deaths: the Deaths list (Core's filter),
-- killers, zones, records and a row per character. No frames here; the window draws these.
local _, ns = ...
local H = {}
ns.History = H

H.Deaths, H.Causes = ns.Deaths, ns.CauseCounts

-- Deaths grouped by keyOf(d) (nil leaves a death out), groups in the order first seen.
local function group(deaths, keyOf)
    local byKey, out = {}, {}
    for _, d in ipairs(deaths) do
        local key = keyOf(d)
        if key ~= nil then
            if not byKey[key] then
                byKey[key] = { key = key, deaths = {} }
                out[#out + 1] = byKey[key]
            end
            table.insert(byKey[key].deaths, d)
        end
    end
    return out
end

-- A tie keeps the value seen first: deaths come newest first, so the latest.
local function ranked(deaths, valueOf)
    local n, first, out = {}, {}, {}
    for _, d in ipairs(deaths) do
        local v = valueOf(d)
        if v ~= nil then
            if not n[v] then out[#out + 1], first[v] = v, #out + 1 end
            n[v] = (n[v] or 0) + 1
        end
    end
    table.sort(out, function(a, b)
        if n[a] ~= n[b] then return n[a] > n[b] end
        return first[a] < first[b]
    end)
    return out, n
end

local function most(deaths, valueOf) return (ranked(deaths, valueOf))[1] end

-- The value most deaths share, and how many share it.
function H.Most(deaths, valueOf)
    local values, n = ranked(deaths, valueOf)
    return values[1], values[1] and n[values[1]] or 0
end

local function spellOf(d) return d.spell or "Melee" end
local function zoneOf(d) return d.zone end
local function placeOf(d) return d.subzone and d.subzone ~= "" and d.subzone or d.zone end
-- A pet's kill is left out: its owner isn't known.
local function playerOf(d) return d.cause == "player" and not d.pet and d.killer or nil end

-- Most first; a tie goes to the latest.
local function byMost(list, field)
    table.sort(list, function(a, b)
        if a[field] ~= b[field] then return a[field] > b[field] end
        return a.last > b.last
    end)
    return list
end

function H.Mobs(f)
    local out = {}
    for _, g in ipairs(group(H.Deaths(f), function(d) return d.cause == "mob" and d.npc or nil end)) do
        out[#out + 1] = { npc = g.key, name = ns.db.npcNames[g.key] or g.deaths[1].killer, kills = #g.deaths,
            last = g.deaths[1].time, spell = most(g.deaths, spellOf), spells = (ranked(g.deaths, spellOf)),
            zone = most(g.deaths, zoneOf), place = most(g.deaths, placeOf), deaths = g.deaths }
    end
    return byMost(out, "kills")
end

function H.Players(f)
    local out = {}
    for _, g in ipairs(group(H.Deaths(f), playerOf)) do
        out[#out + 1] = { name = g.key, kills = #g.deaths, last = g.deaths[1].time,
            class = most(g.deaths, function(d) return d.killerClass end),
            classFile = most(g.deaths, function(d) return d.killerClassFile end),
            race = most(g.deaths, function(d) return d.killerRace end), spells = (ranked(g.deaths, spellOf)),
            zone = most(g.deaths, zoneOf), place = most(g.deaths, placeOf), deaths = g.deaths }
    end
    return byMost(out, "kills")
end

function H.KillsOn(deaths)
    local names, n = ranked(deaths, function(d) return d.name end)
    table.sort(names, function(a, b)
        if n[a] ~= n[b] then return n[a] > n[b] end
        return a < b
    end)
    local out = {}
    for i, name in ipairs(names) do out[i] = { name = name, kills = n[name] } end
    return out
end

-- Who killed you: a mob by the game's name, a player by name; a pet's kill and a fall have none.
local function killerOf(d)
    if d.cause == "mob" and d.npc then return ns.db.npcNames[d.npc] or d.killer end
    return playerOf(d)
end

local function spotOf(d) return d.subzone ~= "" and d.subzone or nil end

local function place(deaths)
    local toPlayers = 0
    for _, d in ipairs(deaths) do if d.cause == "player" then toPlayers = toPlayers + 1 end end
    local killers, kills = ranked(deaths, killerOf)
    return { deaths = #deaths, toPlayers = toPlayers, last = deaths[1].time, killer = killers[1],
        killerKills = killers[1] and kills[killers[1]] }
end

function H.Zones(f)
    local out = {}
    for _, g in ipairs(group(H.Deaths(f), zoneOf)) do
        local z = place(g.deaths)
        z.zone = g.key
        local names, n = ranked(g.deaths, spotOf)
        z.spots = {}
        for i, name in ipairs(names) do z.spots[i] = { name = name, deaths = n[name] } end
        out[#out + 1] = z
    end
    return byMost(out, "deaths")
end

-- A spot is a subzone; a death with none isn't in one.
function H.Spots(f)
    local out = {}
    local keyOf = function(d) return d.subzone and d.subzone ~= "" and d.zone .. "|" .. d.subzone or nil end
    for _, g in ipairs(group(H.Deaths(f), keyOf)) do
        local s = place(g.deaths)
        s.spot, s.zone = g.deaths[1].subzone, g.deaths[1].zone
        out[#out + 1] = s
    end
    return byMost(out, "deaths")
end

local HOUR = 3600

local function lowest(oldestFirst, valueOf)
    local best, bestValue
    for _, d in ipairs(oldestFirst) do
        local v = valueOf(d)
        if v and v > 0 and (not bestValue or v < bestValue) then best, bestValue = d, v end
    end
    return best and { death = best, value = bestValue }
end

-- The death with the highest value; a tie keeps the earliest, which set the record first.
local function highest(oldestFirst, valueOf)
    local best, bestValue
    for _, d in ipairs(oldestFirst) do
        local v = valueOf(d)
        if v and v > 0 and (not bestValue or v > bestValue) then best, bestValue = d, v end
    end
    return best and { death = best, value = bestValue }
end

-- Every record over the deaths the filter keeps. A stream runs from its start to the next one; the
-- fewest waits for a stream to be over.
function H.Records(f)
    local deaths = H.Deaths(f)
    local oldestFirst = {}
    for i = #deaths, 1, -1 do oldestFirst[#oldestFirst + 1] = deaths[i] end
    local r = {
        longestLife = highest(oldestFirst, function(d) return d.alive end),
        hardestHit = highest(oldestFirst, function(d) return d.amount end),
        mostExpensive = highest(oldestFirst, function(d) return d.repair end),
        longestRun = highest(oldestFirst, function(d) return d.ran end),
        longestGhost = highest(oldestFirst, function(d) return d.ghost end),
        shortestLife = lowest(oldestFirst, function(d) return d.alive end),
        deaths = #deaths,
        where = { open = 0, dungeon = 0, raid = 0, battle = 0 },
    }
    local first = 1
    for i, d in ipairs(oldestFirst) do
        while d.time - oldestFirst[first].time >= HOUR do first = first + 1 end
        if not r.mostInHour or i - first + 1 > r.mostInHour.deaths then
            r.mostInHour = { deaths = i - first + 1, from = oldestFirst[first].time, to = oldestFirst[first].time + HOUR }
        end
    end
    -- Without dying means any death on the characters and time kept, whatever the cause or level
    -- filters pick; the time since the last death is a stretch too, still going.
    local every = {}
    for _, d in ipairs(H.Deaths({ char = f.char, name = f.name, of = f.of, ruleset = f.ruleset, since = f.since, stream = f.stream })) do table.insert(every, 1, d) end
    local last = every[#every]
    if last then r.longestWithout = { value = time() - last.time, from = last.time, death = last, still = true } end
    for i = 2, #every do
        local gap = every[i].time - every[i - 1].time
        if gap > r.longestWithout.value then
            r.longestWithout = { value = gap, from = every[i - 1].time, to = every[i].time, death = every[i] }
        end
    end
    for _, d in ipairs(deaths) do
        local k = ns.BattleDeath(d) and "battle" or d.instance == "party" and "dungeon" or d.instance == "raid" and "raid" or "open"
        r.where[k] = r.where[k] + 1
    end
    for _, g in ipairs(group(oldestFirst, function(d) return ns.Day(d.time) end)) do
        if not r.mostInDay or #g.deaths > r.mostInDay.deaths then
            local killers, kills = ranked(g.deaths, killerOf)
            r.mostInDay = { day = g.key, deaths = #g.deaths, name = most(g.deaths, function(d) return d.name end),
                killer = killers[1], killerKills = killers[1] and kills[killers[1]] }
        end
    end
    local starts, current = ns.db.streams, #ns.db.streams
    for _, g in ipairs(f.of and {} or group(oldestFirst, function(d) return ns.StreamOf(d.time) end)) do
        local stream = { from = starts[g.key], to = starts[g.key + 1], deaths = #g.deaths }
        if not r.mostInStream or stream.deaths > r.mostInStream.deaths then r.mostInStream = stream end
        if g.key ~= current and (not r.fewestInStream or stream.deaths < r.fewestInStream.deaths) then
            r.fewestInStream = stream
        end
        for _, p in ipairs(group(g.deaths, playerOf)) do
            if not r.mostByOnePlayer or #p.deaths > r.mostByOnePlayer.kills then
                r.mostByOnePlayer = { name = p.key, kills = #p.deaths, from = stream.from, to = stream.to }
            end
        end
    end
    return r
end

-- Who killed you most over these deaths: { name, cause, kills }, most first, at most n.
function H.TopKillers(deaths, n)
    local names, kills = ranked(deaths, killerOf)
    local cause = {}
    for _, d in ipairs(deaths) do
        local k = killerOf(d)
        if k and not cause[k] then cause[k] = d.cause end
    end
    local out = {}
    for i = 1, math.min(n, #names) do out[i] = { name = names[i], cause = cause[names[i]], kills = kills[names[i]] } end
    return out
end

-- Blizzard's own icons for what isn't a spell (Blizzard_DeathRecap's GetEventInfo).
local ENV_ICONS = { DROWNING = "spell_shadow_demonbreath", FALLING = "ability_rogue_quickrecovery", FIRE = "spell_fire_fire",
    LAVA = "spell_fire_fire", SLIME = "inv_misc_slime_01", FATIGUE = "ability_creature_cursed_05" }
H.ENV_ICONS = ENV_ICONS
local ENV_NAMES = { DROWNING = "Drowning", FALLING = "Falling", FIRE = "Fire", LAVA = "Lava", SLIME = "Slime", FATIGUE = "Fatigue" }

local SLOW_FALL = 130

function H.HitIcon(h)
    local feather = h.env == "FALLING" and C_Spell.GetSpellTexture(SLOW_FALL)
    if feather then return feather end
    if h.env then return "Interface\\Icons\\" .. (ENV_ICONS[h.env] or ENV_ICONS.FATIGUE) end
    local id = h.melee and Constants.DeathRecapConsts.SWING_DAMAGE_SPELL_ID or h.spellId
    return id and C_Spell.GetSpellTexture(id) or nil
end

function H.HitName(h)
    if h.env then return ENV_NAMES[h.env] or "Something" end
    return h.spell or "Melee"
end

-- Who dealt a hit: a mob by the game's own name (the recap's carries a random word).
function H.HitSource(h) return h.npc and ns.db.npcNames[h.npc] or h.source end

-- The last hits of the fight that killed you, each with the health it left (the bar), and the whole fight's
-- numbers: how long it took, the damage that landed, the attackers. The recap's health is yours when the
-- hit came in.
ns.MOST_HITS = 5
function H.Fight(d)
    local hits = d.hits
    if not hits or #hits == 0 then return nil end
    local most = d.maxHealth
    local f = { hits = {}, damage = 0, deadIn = hits[#hits].before, attackers = 0 }
    local seen = {}
    for i, h in ipairs(hits) do
        f.damage = f.damage + (h.amount or 0)
        -- A fall, drowning or hidden caster has no source: not an attacker.
        local who = H.HitSource(h)
        if who and not seen[who] then seen[who], f.attackers = true, f.attackers + 1 end
        if i <= ns.MOST_HITS then
            local left = i == 1 and 0 or h.hp and math.max(0, h.hp - (h.amount or 0)) or nil
            f.hits[i] = { hit = h, name = H.HitName(h), icon = H.HitIcon(h), source = H.HitSource(h),
                part = left and most and math.min(1, left / most) or nil }
        end
    end
    -- A friend's death carries only the hits listed, and the whole fight's numbers beside them.
    local sum = d.sum
    if sum then f.damage, f.deadIn, f.attackers = sum.damage, sum.deadIn, sum.attackers end
    f.several = f.attackers > 1
    return f
end

-- A killer's hits on you over its deaths: each spell once, how often it hit and its biggest. Deaths saved
-- before the recap's hits were kept give their killing blow.
function H.KillerHits(deaths, isKiller)
    local bySpell, out = {}, {}
    local function addSpell(name, icon, amount)
        local s = bySpell[name]
        if not s then
            s = { name = name, icon = icon, hits = 0, biggest = 0 }
            bySpell[name] = s
            out[#out + 1] = s
        end
        s.hits, s.biggest = s.hits + 1, math.max(s.biggest, amount or 0)
    end
    for _, d in ipairs(deaths) do
        if d.hits then
            for _, h in ipairs(d.hits) do
                if isKiller(h) then addSpell(H.HitName(h), H.HitIcon(h), h.amount) end
            end
        else
            addSpell(d.spell or "Melee", nil, d.amount)
        end
    end
    table.sort(out, function(a, b)
        if a.hits ~= b.hits then return a.hits > b.hits end
        return a.biggest > b.biggest
    end)
    return out
end

function H.Totals(f)
    local t = { ghost = 0, ran = 0, repair = 0 }
    for _, d in ipairs(H.Deaths(f)) do
        t.ghost, t.ran, t.repair = t.ghost + (d.ghost or 0), t.ran + (d.ran or 0), t.repair + (d.repair or 0)
    end
    return t
end

function H.Characters(f)
    f = f or {}
    local out = {}
    for _, g in ipairs(group(H.Deaths(f), function(d) return d.char end)) do
        local c = ns.db.characters[g.key] or {}
        local longest = highest(g.deaths, function(d) return d.alive end)
        out[#out + 1] = { key = g.key, name = c.name or g.deaths[1].name, level = c.level, deaths = #g.deaths,
            longestLife = longest and longest.value or 0, last = g.deaths[1].time }
    end
    return byMost(out, "deaths")
end
