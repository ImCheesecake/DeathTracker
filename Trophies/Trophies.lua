-- Trophies (docs/trophies.md): each is checked over everything that happened, in time order. A step,
-- once earned, is kept with what earned it, unless that death is deleted.
local _, ns = ...
local UI = ns.UI
local T = {}
ns.Trophies = T

T.GROUPS = { { "general", "General" }, { "causes", "Causes" }, { "killers", "Killers" },
    { "dungeons", "Dungeons & Raids" }, { "pvp", "Player vs. Player" }, { "resurrection", "Resurrection" },
    { "streams", "Streams" }, { "friends", "Friends" } }

local HOUR, GOLD, MILE = 3600, 10000, 1760
T.FRESH = 120          -- earned by something older than this (the first run, a deleted death): no popup
T.SIDE_BY_SIDE = 10
T.ONE_FIGHT = 30
local HOGGER = 448

local defs, byId = {}, {}
T.defs = defs

-- t: names (one, or one per step), line(n) for a step's goal n, at (the steps, 1 by default),
-- step(s, e) raising s.n, hidden, parts ({ key, label }: a collection), show(n, goal), unit(n).
local function addTrophy(group, id, t)
    t.group, t.id = group, id
    t.at = t.at or { 1 }
    if type(t.line) == "string" then
        local text = t.line
        t.line = function() return text end
    end
    defs[#defs + 1], byId[id] = t, t
end

local function deathIs(pred)
    return function(s, e) if e.kind == "death" and pred(e.d, s) then s.n = s.n + 1 end end
end
local function kindCount(kind)
    return function(s, e) if e.kind == kind then s.n = s.n + 1 end end
end
local function distinct(key)
    return function(s, e)
        if e.kind ~= "death" then return end
        local k = key(e.d)
        if k ~= nil and not s.seen[k] then s.seen[k], s.n = true, s.n + 1 end
    end
end
local function collectParts(parts, key)
    local valid = {}
    for _, p in ipairs(parts) do valid[p[1]] = true end
    return distinct(function(d)
        local k = key(d)
        return valid[k] and k or nil
    end)
end
-- The most deaths sharing one key.
local function mostOf(key)
    return function(s, e)
        if e.kind ~= "death" then return end
        local k = key(e.d)
        if k == nil then return end
        s.by[k] = (s.by[k] or 0) + 1
        if s.by[k] > s.n then s.n = s.by[k] end
    end
end
local function sum(field)
    return function(s, e) if e.kind == "death" and e.d[field] then s.n = s.n + e.d[field] end end
end

local function clock(t) return date("*t", t) end
local function nth(n, word) return function() return ("Reach your %s death."):format(word or n) end end
local function timesLine(n, what) return n == 1 and what .. "." or ("%s %s times."):format(what, BreakUpLargeNumbers(n)) end
local function playerKill(d) return d.cause == "player" and not d.pet end
local function faction(d) local c = ns.db.characters[d.char] return c and c.faction end
local function class(d) local c = ns.db.characters[d.char] return c and c.class end

-- Streams count only while Streamer.bot is on: without it, the one start saved is the install.
local function streamStartOf(t) return ns.Streaming() and ns.db.streams[ns.StreamOf(t) or 0] or nil end

local CLASSES = { { "DRUID" }, { "HUNTER" }, { "MAGE" }, { "PALADIN" }, { "PRIEST" }, { "ROGUE" }, { "SHAMAN" },
    { "WARLOCK" }, { "WARRIOR" } }
for _, c in ipairs(CLASSES) do c[2] = function() return UI.ClassName(c[1]) end end

---------------------------------------------------------------- General
addTrophy("general", "deaths", { names = { "First of Many", "Graveyard Regular", "Familiar Face", "Triple Digits",
    "Still Going", "Hard Lessons", "Slow Learner" }, at = { 1, 10, 50, 100, 250, 500, 1000 },
    line = function(n) return n == 1 and "Die once." or ("Die %s times."):format(BreakUpLargeNumbers(n)) end,
    unit = function(n) return UI.Count(n, "death", "deaths") end, step = kindCount("death") })
addTrophy("general", "roughDay", { names = { "Rough Day", "Very Rough Day", "A Week in a Day" }, at = { 5, 10, 20 },
    line = function(n) return ("Die %d times in one day."):format(n) end, unit = function(n) return UI.Count(n, "death", "deaths") end,
    step = mostOf(function(d) return ns.Day(d.time) end) })
addTrophy("general", "unlucky", { names = "Unlucky Number", hidden = true, at = { 13 }, line = nth(13, "13th"), step = kindCount("death") })
addTrophy("general", "friday13", { names = "Friday the 13th", hidden = true, line = "Die on a Friday the 13th.",
    step = deathIs(function(d) local c = clock(d.time) return c.wday == 6 and c.day == 13 end) })
addTrophy("general", "alive", { names = { "Alive and Well", "Hard to Kill", "Unkillable", "Immortal" },
    at = { HOUR, 3 * HOUR, 10 * HOUR, 24 * HOUR },
    line = function(n) return ("Play %s without dying."):format(UI.Count(n / HOUR, "hour", "hours")) end,
    unit = function(n) return UI.Count(n / HOUR, "hour", "hours") end,
    show = function(n, goal) return UI.Duration(n) .. " / " .. UI.Duration(goal) end,
    step = function(s, e)
        local v = (e.kind == "death" and e.d.alive) or (e.kind == "alive" and e.seconds) or 0
        if v > s.n then s.n = v end
    end })
addTrophy("general", "tutorial", { names = "Tutorial Complete", line = "Die at level 5 or lower.",
    step = deathIs(function(d) return d.level and d.level > 0 and d.level <= 5 end) })
local TENS = {}
for i = 0, 5 do TENS[#TENS + 1] = { i, ("%d-%d"):format(i * 10 + 1, i * 10 + 10) } end
addTrophy("general", "allTheWay", { names = "All the Way Up", line = "Die at least once in every ten levels, from 1-10 to 51-60.",
    parts = TENS, at = { #TENS },
    step = collectParts(TENS, function(d) return d.level and d.level > 0 and math.floor((d.level - 1) / 10) or nil end) })
addTrophy("general", "endgame", { names = "The Endgame Begins", line = "Die at level 60.", step = deathIs(function(d) return d.level == 60 end) })
addTrophy("general", "upLate", { names = "Up Too Late", hidden = true, line = "Die between 2 and 5 in the morning.",
    step = deathIs(function(d) local h = clock(d.time).hour return h >= 2 and h < 5 end) })
addTrophy("general", "halloween", { names = "Trick, No Treat", hidden = true, line = "Die on 31 October.",
    step = deathIs(function(d) local c = clock(d.time) return c.month == 10 and c.day == 31 end) })
addTrophy("general", "zones", { names = "World Tour", at = { 5, 15, 30 }, line = function(n) return ("Die in %d zones."):format(n) end,
    unit = function(n) return UI.Count(n, "zone", "zones") end,
    step = distinct(function(d) return d.zone ~= "" and d.zone or nil end) })
addTrophy("general", "cursed", { names = "Cursed Ground", at = { 3 }, line = "Die 3 times in the same subzone.",
    step = mostOf(function(d) return d.subzone and d.subzone ~= "" and (d.zone or "") .. "|" .. d.subzone or nil end) })
addTrophy("general", "alts", { names = "Alts Die Too", at = { 2, 5, 10 }, line = function(n) return ("Die on %d characters."):format(n) end,
    unit = function(n) return UI.Count(n, "character", "characters") end, step = distinct(function(d) return d.char end) })
local SIDES = { { "Alliance", "Alliance" }, { "Horde", "Horde" } }
addTrophy("general", "bothSides", { names = "Both Sides", line = "Die on an Alliance and a Horde character.", parts = SIDES, at = { 2 },
    step = collectParts(SIDES, faction) })
addTrophy("general", "classes", { names = "Class Reunion", line = "Die on a character of every class.", parts = CLASSES, at = { #CLASSES },
    step = collectParts(CLASSES, class) })
for _, j in ipairs({ { "panic", "Don't Panic", 42, "42nd" }, { "nice", "Nice", 69, "69th" }, { "notFound", "Body Not Found", 404, "404th" },
    { "fourTwenty", "Four Twenty", 420, "420th" }, { "beast", "Number of the Beast", 666, "666th" }, { "leet", "Leet", 1337, "1,337th" },
    { "nineThousand", "Over Nine Thousand", 9001, "9,001st" } }) do
    addTrophy("general", j[1], { names = j[2], hidden = true, at = { j[3] }, line = nth(j[3], j[4]), step = kindCount("death") })
end
addTrophy("general", "leetClock", { names = "Leet O'Clock", hidden = true, line = "Die at 13:37.",
    step = deathIs(function(d) local c = clock(d.time) return c.hour == 13 and c.min == 37 end) })

---------------------------------------------------------------- Causes
for _, c in ipairs({ { "fall", "Gravity Wins", "Die from a fall." }, { "drown", "Out of Breath", "Drown." },
    { "fatigue", "Too Far Out", "Swim out until fatigue gets you." }, { "fire", "Burned", "Die to fire." },
    { "lava", "Into the Lava", "Die in lava." }, { "slime", "Slime Time", "Die in slime." }, { "self", "Own Goal", "Die to your own spell." } }) do
    addTrophy("causes", c[1], { names = c[2], line = c[3], step = deathIs(function(d) return d.cause == c[1] end) })
end
local DOORS = { { "mob", "a mob" }, { "player", "a player" }, { "fall", "a fall" }, { "drown", "drowning" }, { "fatigue", "fatigue" },
    { "fire", "fire" }, { "lava", "lava" }, { "slime", "slime" } }
addTrophy("causes", "everyDoor", { names = "Every Door to the Graveyard", parts = DOORS, at = { #DOORS },
    line = "Die to a mob, a player, a fall, drowning, fatigue, fire, lava and slime.",
    step = collectParts(DOORS, function(d) return d.cause end) })
addTrophy("causes", "sameWay", { names = { "Same Way Again", "And Again" }, at = { 3, 5 },
    line = function(n) return ("Die the same way %d times in a row."):format(n) end, unit = function(n) return n .. " in a row" end,
    step = function(s, e)
        if e.kind ~= "death" then return end
        local d, last = e.d, s.last[e.d.char]
        if d.cause == "mob" then s.last[d.char] = nil return end
        local run = last and last.cause == d.cause and last.run + 1 or 1
        s.last[d.char] = { cause = d.cause, run = run }
        if run > s.n then s.n = run end
    end })
addTrophy("causes", "crit", { names = "Critical Hit", line = "Die to a critical hit.", step = deathIs(function(d) return d.crit end) })
local SCHOOLS = { { 4, "Fire" }, { 16, "Frost" }, { 8, "Nature" }, { 32, "Shadow" }, { 64, "Arcane" }, { 2, "Holy" } }
addTrophy("causes", "magic", { names = "Every Kind of Magic", parts = SCHOOLS, at = { #SCHOOLS },
    line = "Die to Fire, Frost, Nature, Shadow, Arcane and Holy.", step = collectParts(SCHOOLS, function(d) return d.school end) })
addTrophy("causes", "overkill", { names = "Overkill", line = "Die to a hit 1,000 over your health.",
    step = deathIs(function(d) return (d.overkill or 0) >= 1000 end) })
addTrophy("causes", "lit", { names = "Lit", hidden = true, line = "Die to fire at 4:20.",
    step = deathIs(function(d) local c = clock(d.time) return d.cause == "fire" and c.min == 20 and (c.hour == 4 or c.hour == 16) end) })
addTrophy("causes", "niceHit", { names = "Nice Hit", hidden = true, line = "Die to a hit of exactly 69.", step = deathIs(function(d) return d.amount == 69 end) })
addTrophy("causes", "leetHit", { names = "Leet Hit", hidden = true, line = "Die to a hit of exactly 1,337.", step = deathIs(function(d) return d.amount == 1337 end) })

---------------------------------------------------------------- Killers
addTrophy("killers", "personal", { names = { "It's Personal", "Old Enemies", "Sworn Enemies", "Archenemies" }, at = { 3, 5, 10, 25 },
    line = function(n) return ("Get killed by the same mob %d times."):format(n) end, unit = function(n) return UI.Count(n, "kill", "kills") end,
    step = mostOf(function(d) return d.npc end) })
addTrophy("killers", "bestiary", { names = "Bestiary", at = { 10, 25, 50, 100, 200 },
    line = function(n) return ("Get killed by %d different mobs."):format(n) end, unit = function(n) return UI.Count(n, "mob", "mobs") end,
    step = distinct(function(d) return d.npc end) })
addTrophy("killers", "bestOfThree", { names = "Best of Three", line = "Get killed by the same mob twice in a row.",
    step = function(s, e)
        if e.kind ~= "death" then return end
        local d = e.d
        if d.npc and s.last[d.char] == d.npc then s.n = s.n + 1 end
        s.last[d.char] = d.npc or false
    end })
addTrophy("killers", "newNemesis", { names = "New Nemesis", line = "See a new mob take over as your nemesis.",
    step = deathIs(function(d) return d.trophy == "nemesis" end) })
addTrophy("killers", "wrongZone", { names = "Wrong Zone", line = "Get killed by a mob 5 or more levels above you.",
    step = deathIs(function(d) return d.cause == "mob" and (d.killerLevel or 0) > 0 and d.level and d.killerLevel >= d.level + 5 end) })
addTrophy("killers", "skull", { names = "The Skull Was a Hint", line = "Get killed by a skull-level mob.",
    step = deathIs(function(d) return d.cause == "mob" and d.killerLevel == -1 end) })
local ELITE = { elite = true, rareelite = true, worldboss = true }
addTrophy("killers", "elite", { names = "Gold Dragon Club", at = { 1, 10, 50 }, line = function(n) return timesLine(n, "Get killed by an elite") end,
    unit = function(n) return UI.Count(n, "elite", "elites") end, step = deathIs(function(d) return ELITE[d.killerRank or ""] end) })
addTrophy("killers", "rare", { names = "Rare Find", line = "Get killed by a rare.",
    step = deathIs(function(d) return d.killerRank == "rare" or d.killerRank == "rareelite" end) })
addTrophy("killers", "worldBoss", { names = "World Boss", line = "Get killed by a world boss.", step = deathIs(function(d) return d.killerRank == "worldboss" end) })
addTrophy("killers", "hogger", { names = "Hogger Wins", line = "Get killed by Hogger.", step = deathIs(function(d) return d.npc == HOGGER end) })
addTrophy("killers", "bounty", { names = "Bounty Hunter", line = "Collect a bounty on your nemesis.", step = kindCount("bounty") })
addTrophy("killers", "escaped", { names = "The One That Got Away", line = "Let a nemesis escape.", step = kindCount("escape") })
addTrophy("killers", "payback", { names = "Payback", line = "Collect a bounty within 10 minutes of its last kill on you.",
    step = function(s, e)
        if e.kind ~= "bounty" then return end
        for _, d in ipairs(ns.Deaths({ char = e.char, npc = e.b.npc })) do
            if d.time <= e.time then
                if e.time - d.time <= 600 then s.n = s.n + 1 end
                return
            end
        end
    end })
addTrophy("killers", "rematch", { names = "Rematch", line = "Get the same nemesis again after collecting its bounty.",
    step = function(s, e)
        if e.kind == "bounty" then s.seen[e.char .. "|" .. e.b.npc] = true
        elseif e.kind == "death" and e.d.trophy == "nemesis" and e.d.npc and s.seen[e.d.char .. "|" .. e.d.npc] then s.n = s.n + 1 end
    end })
addTrophy("killers", "family", { names = "Runs in the Family", line = "Get killed by the same mob on two characters.",
    step = function(s, e)
        if e.kind ~= "death" or not e.d.npc then return end
        local chars = s.by[e.d.npc] or {}
        s.by[e.d.npc] = chars
        if not chars[e.d.char] then
            chars[e.d.char] = true
            chars.count = (chars.count or 0) + 1
            if chars.count >= 2 then s.n = math.max(s.n, 1) end
        end
    end })

---------------------------------------------------------------- Dungeons & Raids
addTrophy("dungeons", "dungeon", { names = "Dungeon Crawler", line = "Die in a dungeon or raid.",
    step = deathIs(function(d) return d.instance == "party" or d.instance == "raid" end) })

---------------------------------------------------------------- Player vs. Player
addTrophy("pvp", "firstBlood", { names = "First Blood, Yours", line = "Get killed by a player.", step = deathIs(function(d) return d.cause == "player" end) })
addTrophy("pvp", "goodBoy", { names = "Who's a Good Boy", line = "Get killed by a player's pet.",
    step = deathIs(function(d) return d.cause == "player" and d.pet end) })
addTrophy("pvp", "youAgain", { names = { "You Again?", "Rivals", "Archrivals" }, at = { 2, 5, 10 },
    line = function(n) return ("Get killed by the same player %d times."):format(n) end, unit = function(n) return UI.Count(n, "kill", "kills") end,
    step = mostOf(function(d) return playerKill(d) and d.killer or nil end) })
addTrophy("pvp", "popular", { names = "Popular Target", at = { 5, 25, 100 },
    line = function(n) return ("Get killed by %d different players."):format(n) end, unit = function(n) return UI.Count(n, "player", "players") end,
    step = distinct(function(d) return playerKill(d) and d.killer or nil end) })
addTrophy("pvp", "camping", { names = "Camping Trip", line = "Get killed by the same player 3 times in 15 minutes.",
    step = function(s, e)
        local d = e.kind == "death" and e.d
        if not (d and playerKill(d) and d.killer) then return end
        local key = d.char .. "|" .. d.killer
        local recent = {}
        for _, t in ipairs(s.by[key] or {}) do if d.time - t <= 900 then recent[#recent + 1] = t end end
        recent[#recent + 1] = d.time
        s.by[key] = recent
        if #recent >= 3 then s.n = math.max(s.n, 1) end
    end })
addTrophy("pvp", "doubleGank", { names = "Double Gank", line = "Get killed by two different players within 5 minutes.",
    step = function(s, e)
        local d = e.kind == "death" and e.d
        if not (d and playerKill(d) and d.killer) then return end
        local last = s.last[d.char]
        if last and last.killer ~= d.killer and d.time - last.time <= 300 then s.n = math.max(s.n, 1) end
        s.last[d.char] = { killer = d.killer, time = d.time }
    end })
addTrophy("pvp", "everyClass", { names = "Every Class", line = "Get killed by a player of every class.", parts = CLASSES, at = { #CLASSES },
    step = collectParts(CLASSES, function(d) return playerKill(d) and d.killerClassFile or nil end) })
addTrophy("pvp", "bullied", { names = "Bullied", line = "Get killed by a player 10 or more levels above you.",
    step = deathIs(function(d) return playerKill(d) and (d.killerLevel or 0) > 0 and d.level and d.killerLevel >= d.level + 10 end) })

---------------------------------------------------------------- Resurrection
local function runSeconds(d) return d.runSecs or (d.ran and d.ran / UI.GHOST_SPEED) end
local function miles(n) return n / MILE end
local function milesText(n) local m = miles(n) return m < 10 and ("%.1f"):format(m) or BreakUpLargeNumbers(math.floor(m)) end
addTrophy("resurrection", "soSoon", { names = "Back So Soon?", line = "Die within a minute of coming back to life.",
    step = deathIs(function(d) return d.alive and d.alive < 60 end) })
addTrophy("resurrection", "noLight", { names = "Don't Go Into the Light", at = { 1, 10, 50 },
    line = function(n) return n == 1 and "Come back to life where you fell, without walking as a ghost."
        or ("Come back to life where you fell, without walking as a ghost, %d times."):format(n) end,
    unit = function(n) return UI.Times(n) end, step = deathIs(function(d) return d.ghost == 0 end) })
addTrophy("resurrection", "ghostTime", { names = { "Part-Time Ghost", "Full-Time Ghost", "Ghost of the Year" }, at = { HOUR, 5 * HOUR, 24 * HOUR },
    line = function(n) return ("Spend %s as a ghost in total."):format(UI.Count(n / HOUR, "hour", "hours")) end,
    unit = function(n) return UI.Count(n / HOUR, "hour", "hours") end,
    show = function(n, goal) return UI.Duration(n) .. " / " .. UI.Duration(goal) end, step = sum("ghost") })
addTrophy("resurrection", "lostGhost", { names = "Lost Ghost", line = "Spend over 10 minutes as a ghost after one death.",
    step = deathIs(function(d) return (d.ghost or 0) > 600 end) })
local MARATHON = 46112
addTrophy("resurrection", "marathon", { names = { "First Mile", "Ghost Marathon", "Hundred-Mile Haunt" }, at = { MILE, MARATHON, 100 * MILE },
    line = function(n)
        if n == MILE then return "Run a mile as a ghost in total." end
        if n == MARATHON then return "Run a marathon as a ghost in total." end
        return "Run 100 miles as a ghost in total."
    end,
    unit = function(n) return n == MARATHON and "a marathon" or UI.Count(miles(n), "mile", "miles") end,
    show = function(n, goal) return ("%s / %s miles"):format(milesText(n), milesText(goal)) end, step = sum("ran") })
addTrophy("resurrection", "sprint", { names = "Sprint Home", line = "Run back in under 15 seconds.",
    step = deathIs(function(d) return (d.runSecs or 0) > 0 and d.runSecs < 15 end) })
addTrophy("resurrection", "longWay", { names = "Long Way Home", line = "Run back for over 3 minutes.",
    step = deathIs(function(d) return (runSeconds(d) or 0) > 180 end) })
addTrophy("resurrection", "repairs", { names = { "Small Change", "Regular Customer", "Favorite Customer", "Bought the Forge" },
    at = { GOLD, 5 * GOLD, 25 * GOLD, 100 * GOLD },
    line = function(n) return ("Pay %d gold in repairs in total."):format(n / GOLD) end, unit = function(n) return (n / GOLD) .. " gold" end,
    show = function(n, goal) return UI.Money(n) .. " / " .. UI.Money(goal) end, step = sum("repair") })
addTrophy("resurrection", "pricey", { names = "Pricey Funeral", line = "Pay over 1 gold in repairs for one death.",
    step = deathIs(function(d) return (d.repair or 0) > GOLD end) })
addTrophy("resurrection", "proclaimed", { names = { "Proclaimed Dead", "Encore" }, at = { 500 * MILE, 1000 * MILE },
    line = function(n) return ("Run %s miles as a ghost in total."):format(BreakUpLargeNumbers(miles(n))) end,
    unit = function(n) return BreakUpLargeNumbers(miles(n)) .. " miles" end,
    show = function(n, goal) return ("%s / %s miles"):format(milesText(n), milesText(goal)) end, step = sum("ran") })

---------------------------------------------------------------- Streams
local function inStream(key)
    return function(d)
        local start = streamStartOf(d.time)
        return start and key(d, start) or nil
    end
end
addTrophy("streams", "quick", { names = "That Was Quick", line = "Die in the first 5 minutes of a stream.",
    step = deathIs(function(d) local start = streamStartOf(d.time) return start and d.time - start < 300 end) })
addTrophy("streams", "entertained", { names = "Chat Is Entertained", at = { 5, 10, 20 },
    line = function(n) return ("Die %d times in one stream."):format(n) end, unit = function(n) return UI.Count(n, "death", "deaths") end,
    step = mostOf(inStream(function(_, start) return start end)) })
addTrophy("streams", "dejaVu", { names = "Déjà Vu", at = { 3 }, line = "Get killed by the same mob 3 times in one stream.",
    step = mostOf(inStream(function(d, start) return d.npc and start .. "|" .. d.npc end)) })
addTrophy("streams", "variety", { names = "Variety", at = { 4 }, line = "Die 4 different ways in one stream.",
    step = function(s, e)
        if e.kind ~= "death" then return end
        local start = streamStartOf(e.time)
        if not start then return end
        local ways = s.by[start] or { count = 0 }
        s.by[start] = ways
        if not ways[e.d.cause] then
            ways[e.d.cause], ways.count = true, ways.count + 1
            if ways.count > s.n then s.n = ways.count end
        end
    end })

---------------------------------------------------------------- Friends
local function sameKiller(d, f)
    if d.npc and f.npc then return d.npc == f.npc end
    return f.killer ~= nil and ns.DeathTitle(d) == f.killer
end
addTrophy("friends", "avenger", { names = "Avenger", line = "Avenge a friend.", step = kindCount("avenger") })
addTrophy("friends", "avenged", { names = "Avenged", line = "Get avenged by a friend.", step = kindCount("avenged") })
addTrophy("friends", "respects", { names = "Paid Respects", at = { 10 }, line = "Pay respects to a friend 10 times.", step = kindCount("respectsSent") })
addTrophy("friends", "funeral", { names = "Big Funeral", at = { 5 }, line = "Have 5 friends pay respects to one of your deaths.",
    step = function(s, e)
        if e.kind ~= "respectsGot" then return end
        local who = s.by[e.f.death] or { count = 0 }
        s.by[e.f.death] = who
        if not who[e.f.id] then
            who[e.f.id], who.count = true, who.count + 1
            if who.count > s.n then s.n = who.count end
        end
    end })
-- Own deaths and friends' deaths seen so far, newest last; both trophies look back and forth in time.
local function together(window, check)
    return function(s, e)
        s.mine, s.theirs = s.mine or {}, s.theirs or {}
        if e.kind == "death" then
            s.mine[#s.mine + 1] = e.d
            if check(e.d, s.theirs, window) then s.n = math.max(s.n, 1) end
        elseif e.kind == "friendDeath" then
            s.theirs[#s.theirs + 1] = e.f
            for i = #s.mine, 1, -1 do
                local d = s.mine[i]
                if e.f.time - d.time > window then break end
                if check(d, s.theirs, window) then s.n = math.max(s.n, 1) end
            end
        end
    end
end
addTrophy("friends", "sideBySide", { names = "Side by Side", line = "Die to the same killer as a friend within 10 seconds.",
    step = together(T.SIDE_BY_SIDE, function(d, theirs, window)
        for i = #theirs, 1, -1 do
            local f = theirs[i]
            if math.abs(f.time - d.time) <= window and sameKiller(d, f) then return true end
        end
    end) })
addTrophy("friends", "partyWipe", { names = "Party Wipe", line = "Die with 2 or more friends in one fight.",
    step = together(T.ONE_FIGHT, function(d, theirs, window)
        local ids, count = {}, 0
        for _, f in ipairs(theirs) do
            if math.abs(f.time - d.time) <= window and not ids[f.id] then ids[f.id], count = true, count + 1 end
        end
        return count >= 2
    end) })
addTrophy("friends", "sharedNemesis", { names = "Shared Nemesis", line = "Get killed by a friend's nemesis.", step = kindCount("sharedNemesis") })

---------------------------------------------------------------- Checking

function T.Get(id) return byId[id] end

-- The big groups open into subgroups in the pane, as Blizzard's achievement categories do.
T.SUBGROUPS = {
    general = { { "counts", "Death counts" }, { "life", "Life and levels" }, { "characters", "Characters" }, { "time", "Time and place" } },
    causes = { { "world", "The world" }, { "hits", "Hits and magic" } },
    killers = { { "mobs", "Mobs" }, { "elites", "Elites and rares" }, { "nemesis", "Nemesis and bounty" } },
    resurrection = { { "back", "Coming back" }, { "ghost", "Ghost and run back" }, { "repairs", "Repairs" } },
}
local SUB = {
    counts = { "deaths", "roughDay", "unlucky", "panic", "nice", "notFound", "fourTwenty", "beast", "leet", "nineThousand" },
    life = { "alive", "tutorial", "allTheWay", "endgame" },
    characters = { "alts", "bothSides", "classes" },
    time = { "friday13", "upLate", "halloween", "zones", "cursed", "leetClock" },
    world = { "fall", "drown", "fatigue", "fire", "lava", "slime", "everyDoor", "sameWay", "lit" },
    hits = { "self", "crit", "magic", "overkill", "niceHit", "leetHit" },
    mobs = { "personal", "bestiary", "bestOfThree", "hogger", "family" },
    elites = { "wrongZone", "skull", "elite", "rare", "worldBoss" },
    nemesis = { "newNemesis", "bounty", "escaped", "payback", "rematch" },
    back = { "soSoon", "noLight" },
    ghost = { "ghostTime", "lostGhost", "marathon", "sprint", "longWay", "proclaimed" },
    repairs = { "repairs", "pricey" },
}
for sub, ids in pairs(SUB) do
    for _, id in ipairs(ids) do byId[id].sub = sub end
end

-- Each trophy's icon, a game icon by file ID (client data, ManifestInterfaceData, build 1.60.1.70245).
local SKULL, ELF_SKULL, SKULL2, BOOK, MAP, WATCH, TWILIGHT, NOTE = 133730, 133729, 237274, 133741, 134269, 134376, 136223, 134328
local GROUP_ICONS = { general = SKULL, causes = 136147, killers = ELF_SKULL, dungeons = 255343, pvp = 236368,
    resurrection = 135955, streams = WATCH, friends = 134149 }
local ICONS = { roughDay = 136147, unlucky = SKULL2, friday13 = SKULL2, alive = WATCH, tutorial = BOOK, allTheWay = MAP,
    endgame = 136187, upLate = TWILIGHT, halloween = SKULL2, zones = MAP, cursed = 132094, alts = 134149, bothSides = 236681,
    classes = 236448, panic = NOTE, nice = NOTE, notFound = NOTE, fourTwenty = NOTE, beast = NOTE, leet = NOTE,
    nineThousand = NOTE, leetClock = 136106, fall = 135992, drown = 135861, fatigue = 135841, fire = 135805, lava = 135830,
    slime = 134437, self = 136071, everyDoor = SKULL, sameWay = 136214, crit = 132212, magic = 135728, overkill = 132352,
    lit = 135805, niceHit = NOTE, leetHit = NOTE, bestiary = 134153, bestOfThree = 132147, wrongZone = 134442,
    skull = SKULL2, elite = 134153, rare = 134442, worldBoss = 134153, hogger = 132184, bounty = 133785, escaped = 132307,
    payback = 133785, rematch = 132147, family = 134148, goodBoy = 132184, youAgain = 236329, camping = 136207,
    doubleGank = 132147, everyClass = 236448, bullied = 132352, soSoon = 136106, ghostTime = 132293, lostGhost = 132293,
    marathon = 132307, sprint = 132307, longWay = MAP, repairs = 133057, pricey = 133785, proclaimed = 132307,
    quick = 136106, entertained = NOTE, dejaVu = 136214, variety = 135728, avenger = 135963, avenged = 135920,
    respects = 135946, funeral = 135898, partyWipe = 134148, sharedNemesis = ELF_SKULL }
function T.Icon(def) return ICONS[def.id] or GROUP_ICONS[def.group] end

-- Points as Blizzard gives them: 10 for most, 25 for a collection and a ladder's middle steps, 50
-- for a ladder's last.
function T.Points(def, tier)
    if def.parts then return 25 end
    if #def.at == 1 or tier == 1 then return 10 end
    return tier == #def.at and 50 or 25
end

function T.TotalPoints()
    local n = 0
    for _, def in ipairs(defs) do
        for tier in ipairs(T.Earned(def.id)) do n = n + T.Points(def, tier) end
    end
    return n
end

-- A trophy with one name has it as its card's title: its steps are only the goal.
function T.StepText(def, tier)
    local goal = def.unit(def.at[tier])
    if type(def.names) == "table" then return ("%s, %s"):format(T.Name(def, tier), goal) end
    return (goal:gsub("^%l", string.upper))
end

function T.PartText(part) return type(part[2]) == "function" and part[2]() or part[2] end

function T.Name(def, tier)
    if type(def.names) == "string" then return def.names end
    return def.names[math.min(math.max(tier, 1), #def.names)]
end

-- Everything a trophy can be earned by, oldest first. now: also the time played right now.
local function events(now)
    local out = {}
    for i, d in ipairs(ns.db.deaths) do out[#out + 1] = { kind = "death", d = d, time = d.time, char = d.char, order = i } end
    for _, b in ipairs(ns.db.bounties) do out[#out + 1] = { kind = "bounty", b = b, time = b.time, char = b.char } end
    for _, x in ipairs(ns.db.escapes) do out[#out + 1] = { kind = "escape", npc = x.npc, time = x.time, char = x.char } end
    for _, f in ipairs(ns.db.trophyFacts) do out[#out + 1] = { kind = f.kind, f = f, time = f.time, char = f.char } end
    if now and ns.CharacterKey() then
        out[#out + 1] = { kind = "alive", seconds = ns.AliveSeconds(now), time = now, char = ns.CharacterKey() }
    end
    table.sort(out, function(a, b)
        if a.time ~= b.time then return a.time < b.time end
        return (a.order or math.huge) < (b.order or math.huge)
    end)
    return out
end

-- Every trophy's progress (s.n, and s.seen for a collection) and the event that reached each step.
local function evaluate(now)
    local states, reached = {}, {}
    for _, def in ipairs(defs) do states[def.id], reached[def.id] = { n = 0, seen = {}, by = {}, last = {} }, {} end
    for _, e in ipairs(events(now)) do
        for _, def in ipairs(defs) do
            local s, r = states[def.id], reached[def.id]
            def.step(s, e)
            while def.at[#r + 1] and s.n >= def.at[#r + 1] do r[#r + 1] = e end
        end
    end
    return states, reached
end

local function deathExists(char, at)
    for i = #ns.db.deaths, 1, -1 do
        local d = ns.db.deaths[i]
        if d.time == at and d.char == char then return true end
    end
end

local alert = function() end
function T.OnEarned(fn) alert = fn end

T.state = {}

function T.Check()
    local db = ns.db
    local first = db.trophies == nil
    db.trophies = db.trophies or {}
    local now = time()
    local states, reached = evaluate(now)
    T.state = states
    local fresh, earned = {}, 0
    for _, def in ipairs(defs) do
        local saved = db.trophies[def.id] or {}
        for tier = 1, #def.at do
            local step = saved[tier]
            if step and step.death and not deathExists(step.char, step.death) then
                for t = tier, #def.at do saved[t] = nil end
                break
            end
        end
        for tier, e in ipairs(reached[def.id]) do
            if not saved[tier] then
                saved[tier] = { time = e.time, char = e.char, death = e.kind == "death" and e.d.time or nil,
                    npc = (e.b and e.b.npc) or e.npc }
                earned = earned + 1
                if not first and now - e.time <= T.FRESH then fresh[#fresh + 1] = { def = def, tier = tier } end
            end
        end
        db.trophies[def.id] = next(saved) and saved or nil
    end
    if first and earned > 0 then
        UI.Say(("your past deaths have earned %s. Type /trophies to see them."):format(UI.Count(earned, "trophy", "trophies")))
    end
    for _, f in ipairs(fresh) do if T.GroupShown(f.def.group) then alert(f.def, f.tier) end end
end

-- Steps earned, in order: { time, char, death, npc } each.
function T.Earned(id) return ns.db.trophies and ns.db.trophies[id] or {} end

function T.Progress(id) return T.state[id] or { n = 0, seen = {} } end

-- Something friends did that a trophy counts: kept for good (the Recent list keeps only the latest).
function T.Fact(kind, fields)
    if ns.Friends.IsDemo() then return ns.Changed() end
    local f = fields or {}
    f.kind, f.time, f.char = kind, f.time or time(), f.char or ns.CharacterKey()
    table.insert(ns.db.trophyFacts, f)
    ns.Changed()
end

function T.SharesWithAnyone()
    for id in pairs(ns.Friends.Store().players) do if ns.Friends.Shares(id) then return true end end
    return false
end

-- Streams only with Streamer.bot on, Friends once you share; a group with an earned trophy stays.
function T.GroupShown(key)
    if key == "streams" and not ns.Streaming() then return false end
    if key == "friends" and not T.SharesWithAnyone() then
        for _, def in ipairs(defs) do if def.group == "friends" and next(T.Earned(def.id)) then return true end end
        return false
    end
    return true
end

-- A hidden trophy shows once a step is earned.
function T.Shown(def) return T.GroupShown(def.group) and (not def.hidden or next(T.Earned(def.id)) ~= nil) end

-- Steps earned and steps there are, of the trophies shown (in one group, or one subgroup of it).
function T.Counts(group, sub)
    local got, all = 0, 0
    for _, def in ipairs(defs) do
        if (not group or def.group == group) and (not sub or def.sub == sub) and T.Shown(def) then
            got, all = got + #T.Earned(def.id), all + #def.at
        end
    end
    return got, all
end

ns.OnDeath(function(d)
    if not d.npc then return end
    for _, id in ipairs(ns.Friends.NemesisOf(d.npc)) do T.Fact("sharedNemesis", { id = id }) end
end)

local checking = false
ns.OnChange(function()
    if checking or not ns.db then return end
    checking = true
    C_Timer.After(0, function()
        checking = false
        T.Check()
    end)
end)
-- Played this life counts toward Hard to Kill while you play.
C_Timer.NewTicker(60, function() if ns.db and ns.CharacterKey() then T.Check() end end)
