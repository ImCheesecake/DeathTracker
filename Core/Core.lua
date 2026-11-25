local addonName, ns = ...

local charKey, char
local ready = false
local pending = false
local sessionStart
local entered = false
local listeners = { change = {}, death = {}, dying = {}, bounty = {}, payment = {} }
local hooks = {}

ns.DEFAULTS = { streamerbot = false, counter = true, counterPanel = true, counterLayout = "box",
    counterAllTime = true, allTimePerCharacter = false, chatDelay = 0, card = true, cardBattlegrounds = false, counterScale = 1, barScale = 1,
    cardScale = 0.6, posterScale = 1, historyScale = 1, tooltips = true, grudge = true, poster = true, posterSounds = true, posterKept = false, minimapButton = true,
    recapMusic = true }

function ns.OnChange(fn) table.insert(listeners.change, fn) end
function ns.OnDeath(fn) table.insert(listeners.death, fn) end
function ns.OnDying(fn) table.insert(listeners.dying, fn) end
function ns.OnBounty(fn) table.insert(listeners.bounty, fn) end
function ns.OnPayment(fn) table.insert(listeners.payment, fn) end
local function notify(kind, ...) for _, fn in ipairs(listeners[kind]) do fn(...) end end
local function changed() notify("change") end
ns.Changed = changed

local RECAP_KEYS = { "event", "timestamp", "amount", "sourceGUID", "environmentalType" }
local function recapID(e)
    if not e then return nil end
    local parts = {}
    for _, k in ipairs(RECAP_KEYS) do
        local v = e[k]
        parts[#parts + 1] = (v == nil or issecretvalue(v)) and "?" or tostring(v)
    end
    return table.concat(parts, "|")
end

ns.ALIVE_LABEL = "Played this life"

function ns.AliveSeconds(now)
    return char.alive + (sessionStart and (now or time()) - sessionStart or 0)
end

ns.CAUSES = { { "mob", "Mobs" }, { "player", "Players" }, { "fall", "Falls" }, { "drown", "Drowning" },
    { "lava", "Lava" }, { "fire", "Fire" }, { "fatigue", "Fatigue" }, { "slime", "Slime" }, { "other", "Other" } }
local OTHER = { self = true, unknown = true, other = true }
function ns.CauseKind(cause) return OTHER[cause] and "other" or cause end

-- Forever's realm names end in their ruleset ("CAMWOWEU5Realm8PvP"); so does a character's key.
function ns.Ruleset(charKey) return charKey and charKey:match("%d(%a+)$") end

local function matches(d, f, since)
    return d.time >= since
        and (not f.char or d.char == f.char)
        and (not f.name or d.name == f.name)
        and (not f.cause or ns.CauseKind(d.cause) == f.cause)
        and (not f.causes or f.causes[ns.CauseKind(d.cause)])
        and (not f.ruleset or ns.Ruleset(d.char) == f.ruleset)
        and (not f.minLevel or (d.level or 0) >= f.minLevel)
        and (not f.maxLevel or (d.level or 0) <= f.maxLevel)
        and (not f.npc or d.npc == f.npc)
        and (not f.player or (d.cause == "player" and not d.pet and d.killer == f.player))
        and (not f.zone or d.zone == f.zone)
        and (not f.spot or d.subzone == f.spot)
        and (not f.day or ns.Day(d.time) == f.day)
        and (not f.death or d == f.death)
        and (not f.from or d.time >= f.from)
        and (not f.to or d.time < f.to)
        and (not f.since or d.time >= f.since)
        and (not f.noBattle or not ns.BattleDeath(d))
end

function ns.Deaths(f, n)
    local list = f.of and ns.Friends.Log(f.of) or ns.db.deaths
    local since, out = f.stream and not f.of and ns.StreamStart() or 0, {}
    for i = #list, 1, -1 do
        if #out == n then break end
        local d = list[i]
        if matches(d, f, since) then out[#out + 1] = d end
    end
    return out
end

function ns.CauseCounts(f)
    local out = {}
    for _, d in ipairs(ns.Deaths(f)) do
        local kind = ns.CauseKind(d.cause)
        out[kind] = (out[kind] or 0) + 1
    end
    return out
end

function ns.StreamCount() return #ns.Deaths({ stream = true }) end

function ns.Streaming() return ns.db.settings.streamerbot end

function ns.Counting()
    if ns.Streaming() then return { stream = true } end
    return { char = charKey }
end

function ns.CharacterNemesis() return ns.Nemesis({ char = charKey }) end

function ns.CountedDeaths() return #ns.Deaths(ns.Counting()) end

function ns.TotalCount() return #ns.db.deaths end

function ns.AllTimeCount()
    if ns.db.settings.allTimePerCharacter then return #ns.Deaths({ char = charKey }) end
    return ns.TotalCount()
end

function ns.InBattle()
    local _, instance = IsInInstance()
    return instance == "pvp" or instance == "arena"
end

function ns.CharacterKey() return charKey end

local TITLES = { fall = "Fall damage", drown = "Drowning", lava = "Lava", fire = "Fire", fatigue = "Fatigue",
    slime = "Slime", unknown = "Something", other = "Something" }

-- A killer's name can be secret (dungeons, bosses).
function ns.DeathTitle(d, withSpell)
    local title = TITLES[d.cause] or d.killer or (d.cause == "self" and d.name) or "Something"
    if withSpell and d.spell and not TITLES[d.cause] then title = title .. "'s " .. d.spell end
    return title
end

-- Older deaths without d.instance are told by their English zone name.
local BATTLE_ZONES = { ["Alterac Valley"] = true, ["Warsong Gulch"] = true, ["Arathi Basin"] = true,
    ["Darkspear Islands"] = true, ["Battle for Gilneas"] = true, ["Hyjal Crater"] = true }
function ns.BattleZone(zone) return BATTLE_ZONES[zone] == true end

function ns.BattleDeath(d)
    return d.instance == "pvp" or d.instance == "arena" or (d.instance == nil and ns.BattleZone(d.zone))
end

local function readable(v) return type(v) == "string" and not issecretvalue(v) and v ~= "" end

-- Forever adds a random word to mob names in the Death Recap ("Azuregos Herbaliser"); the unit's
-- own name (its tooltip, the target) has none.
local function learnName(npc, guid, recapName)
    local data = C_TooltipInfo.GetHyperlink("unit:" .. guid)
    local first = data and data.lines and data.lines[1] and data.lines[1].leftText
    if readable(first) and recapName and (recapName == first or recapName:sub(1, #first + 1) == first .. " ") then
        ns.db.npcNames[npc] = first
    end
end

local HORDE = { Orc = true, Scourge = true, Tauren = true, Troll = true, BloodElf = true, Goblin = true }

local function learnPlayer(d, guid)
    local class, classFile, raceName, race = GetPlayerInfoByGUID(guid)
    if readable(class) then d.killerClass = class end
    if readable(classFile) then d.killerClassFile = classFile end
    if readable(raceName) then d.killerRace = raceName end
    if readable(race) then d.killerFaction = HORDE[race] and "Horde" or "Alliance" end
end

local function unitFor(guid)
    local unit = UnitTokenFromGUID(guid)
    if unit and canaccessvalue(unit) then return unit end
    local target = UnitGUID("target")
    if target and canaccessvalue(target) and target == guid then return "target" end
end

-- UnitLevel gives a skull level as -1.
local function learnLevel(d, guid)
    local unit = unitFor(guid)
    if not unit then return end
    local level, rank = UnitLevel(unit), UnitClassification(unit)
    if type(level) == "number" and not issecretvalue(level) then d.killerLevel = level end
    if readable(rank) and rank ~= "normal" then d.killerRank = rank end
end

local function trophyFor(d)
    if #ns.db.deaths == 0 then return nil end
    local longest = 0
    for _, p in ipairs(ns.db.deaths) do longest = math.max(longest, p.alive or 0) end
    if d.alive > longest then return "longest" end
end

local function killedBy(npc) return ns.Deaths({ npc = npc }, 1)[1] ~= nil end

local function learnTarget()
    local guid, name = UnitGUID("target"), UnitName("target")
    if not (readable(guid) and readable(name)) then return end
    local kind, npc = ns.ParseGUID(guid)
    if (kind == "Creature" or kind == "Vehicle") and npc and ns.db.npcNames[npc] ~= name and killedBy(npc) then
        ns.db.npcNames[npc] = name
        return true
    end
end

local VERSION = 6
local function upgrade(db)
    db.version = db.version or 0
    if db.version < 1 then
        for npc in pairs(db.npcNames) do
            if not killedBy(npc) then db.npcNames[npc] = nil end
        end
    end
    if db.version < 2 then
        db.streams = { db.streamStart or time() }
        db.streamStart = nil
    end
    if db.version < 3 then
        if db.settings.counterBar then db.settings.counterLayout = "bar" end
        db.settings.counterBar = nil
    end
    if db.version < 4 then
        for _, d in ipairs(db.deaths) do
            if d.trophy == "level" then d.trophy = nil end
        end
    end
    if db.version < 5 then
        local list = {}
        for key, at in pairs(db.bounties) do
            local who, npc = key:match("^(.+)|(%d+)$")
            if who then list[#list + 1] = { char = who, npc = tonumber(npc), time = at } end
        end
        table.sort(list, function(a, b) return a.time < b.time end)
        db.bounties = list
    end
    if db.version < 6 then
        for _, d in ipairs(db.deaths) do
            if d.trophy == "milestone" then d.trophy = nil end
        end
        local f = db.friends
        if f and (f.avenged or 0) > 0 and f.lastAvenged then
            table.insert(db.trophyFacts, { kind = "avenger", time = f.lastAvenged.time })
        end
    end
    db.version = VERSION
end

function ns.StreamStart() return ns.db.streams[#ns.db.streams] end

function ns.StreamOf(t)
    local starts = ns.db.streams
    for i = #starts, 1, -1 do
        if t >= starts[i] then return i end
    end
end

function ns.Day(t) return date("%Y-%m-%d", t) end

function ns.DayNoon(day)
    local y, m, d = day:match("(%d+)-(%d+)-(%d+)")
    return time({ year = tonumber(y) or 1970, month = tonumber(m) or 1, day = tonumber(d) or 1, hour = 12 })
end

function ns.PeriodStart(period)
    local c = date("*t", time())
    local dayStart = time({ year = c.year, month = c.month, day = c.day, hour = 0 })
    if period == "day" then return dayStart end
    if period == "week" then
        local monday = date("*t", dayStart)
        return time({ year = monday.year, month = monday.month, day = monday.day - (tonumber(date("%w", dayStart)) + 6) % 7, hour = 0 })
    end
    return time({ year = c.year, month = c.month, day = 1, hour = 0 })
end

local function retiredAt(key)
    local at = 0
    for _, b in ipairs(ns.db.bounties) do
        if b.char == key and b.time > at then at = b.time end
    end
    return at
end

ns.NEMESIS_KILLS = 3
ns.NEMESIS_WINDOW = 10
local NOT_OPEN_WORLD = { party = true, raid = true, pvp = true, arena = true }
function ns.Nemesis(f, least)
    if not (f and f.char) then return nil end
    local since = retiredAt(f.char)
    local fresh, total, names, best = {}, {}, {}, nil
    local deaths = ns.Deaths(f)
    local window, counted = {}, 0
    for _, d in ipairs(deaths) do
        if counted < ns.NEMESIS_WINDOW and not NOT_OPEN_WORLD[d.instance or ""] then
            window[d], counted = true, counted + 1
        end
    end
    for i = #deaths, 1, -1 do
        local d = deaths[i]
        if d.npc then
            total[d.npc] = (total[d.npc] or 0) + 1
            names[d.npc] = d.killer or names[d.npc]
            if d.time > since and window[d] then
                fresh[d.npc] = (fresh[d.npc] or 0) + 1
                if not best or fresh[d.npc] > fresh[best] then best = d.npc end
            end
        end
    end
    local c = ns.db.characters[f.char]
    local current = c and c.nemesis
    if best and current and fresh[current] == fresh[best] then best = current end
    if best and fresh[best] >= (least or ns.NEMESIS_KILLS) then
        return best, ns.db.npcNames[best] or names[best], total[best], fresh[best]
    end
end

function ns.Trophy(d)
    local kills = 0
    for _, p in ipairs(ns.db.deaths) do
        if d.npc and p.npc == d.npc and p.char == d.char then kills = kills + 1 end
        if p == d then break end
    end
    if d.trophy == "longest" then
        return "Longest life yet", ("Played %s without dying"):format(ns.UI.Duration(d.alive))
    elseif d.trophy == "nemesis" then
        return "New nemesis", ("%s, %s"):format(ns.db.npcNames[d.npc] or d.killer,
            ns.UI.Count(d.kills or kills, "kill", "kills"))
    end
end

function ns.Counts()
    local _, name, kills = ns.CharacterNemesis()
    return { total = ns.AllTimeCount(), stream = ns.StreamCount(), nemesis = name, nemesisKills = kills,
        character = ns.db.settings.allTimePerCharacter and char.name or nil }
end

local function sendStatus()
    ns.SendStatus({ name = char.name, level = UnitLevel("player"), zone = GetRealZoneText() })
end

function ns.ResetStream()
    table.insert(ns.db.streams, time())
    sendStatus()
    changed()
end

function ns.AllTimeChanged()
    sendStatus()
    changed()
end

function ns.StreamerbotChanged(on)
    if on then return ns.ResetStream() end
    changed()
end

function ns.DeleteAllDeaths()
    wipe(ns.db.deaths)
    wipe(ns.db.runs)
    wipe(ns.db.payments)
    for _, c in pairs(ns.db.characters) do c.nemesis = nil end
    sendStatus()
    changed()
end

function ns.DeleteDeath(d)
    for i = #ns.db.deaths, 1, -1 do
        if ns.db.deaths[i] == d then
            local before = ns.Nemesis({ char = d.char })
            table.remove(ns.db.deaths, i)
            local after, c = ns.Nemesis({ char = d.char }), ns.db.characters[d.char]
            if before and before ~= after then ns.db.payments[d.char .. "|" .. before] = nil end
            if c then c.nemesis = after end
            local run = ns.db.runs[d.char]
            if run and run.time == d.time then ns.db.runs[d.char] = nil end
            sendStatus()
            changed()
            return
        end
    end
end

local function maxHealth()
    local v = C_DeathRecap.GetRecapMaxHealth()
    if type(v) == "number" and not issecretvalue(v) and v > 0 then return v end
end

local function record(at, e, events)
    local d = ns.Classify(e, UnitGUID("player"))
    if events then
        local hits = ns.RecapHits(events)
        if #hits > 0 then d.hits, d.maxHealth = hits, maxHealth() end
    end
    if d.guid and d.npc then
        learnName(d.npc, d.guid, d.killer)
        d.killer = ns.db.npcNames[d.npc] or d.killer
    elseif d.guid then
        learnPlayer(d, d.guid)
    end
    if d.guid then learnLevel(d, d.guid) end
    d.guid = nil
    d.char, d.name, d.time = charKey, char.name, at
    d.level, d.zone, d.subzone = UnitLevel("player"), GetRealZoneText(), GetSubZoneText()
    local _, instance = IsInInstance()
    if NOT_OPEN_WORLD[instance] then d.instance = instance end
    d.alive = ns.AliveSeconds(at)
    char.alive, sessionStart = 0, nil
    d.trophy = trophyFor(d)
    local nemesisBefore = ns.CharacterNemesis()
    ns.db.deaths[#ns.db.deaths + 1] = d
    d.number = ns.CountedDeaths()
    local nemesisNow, nemesisName = ns.CharacterNemesis()
    char.nemesis = nemesisNow
    if not d.trophy and d.npc and nemesisNow == d.npc and nemesisBefore ~= d.npc and nemesisName then
        d.trophy = "nemesis"
    end
    local escaped = nemesisBefore and nemesisNow ~= nemesisBefore and nemesisBefore or nil
    if escaped then
        table.insert(ns.db.escapes, { char = charKey, npc = escaped, time = at })
        ns.db.payments[charKey .. "|" .. escaped] = nil
    end
    if e then ns.db.lastRecap = recapID(e) end
    pending = false
    local function tell(kind)
        d.joke = ns.Joke(d, kind)
        ns.SendDeath(d)
        changed()
        notify("death", d, nemesisBefore, escaped)
    end
    if d.cause == "mob" and d.npc then ns.MobKind(d.npc, tell) else tell() end
end

-- The Death Recap can come late, or still hold the previous death.
local RECAP_WAIT, RECAP_RETRY = 0.3, 0.7
-- The killing blow's timestamp is Unix time, within a second of PLAYER_DEAD.
local RECAP_AGE = 5
local function readRecap(at, last)
    local events = C_DeathRecap.HasRecapEvents() and C_DeathRecap.GetRecapEvents()
    local e = events and events[1]
    local stamp = e and ns.Readable(e["timestamp"])
    if stamp and stamp < at - RECAP_AGE then e = nil end
    if e and recapID(e) ~= ns.db.lastRecap then
        record(at, e, events)
    elseif last then
        record(at, nil)
    else
        C_Timer.After(RECAP_RETRY, function() readRecap(at, true) end)
    end
end

local function onDead()
    -- PLAYER_DEAD can fire again while dead.
    if not ready or pending or UnitIsFeignDeath("player") then return end
    local at = time()
    ready, pending = false, true
    notify("dying", at)
    C_Timer.After(RECAP_WAIT, function() readRecap(at, false) end)
end

-- Forever's realm name can come back empty (GetRealmName() too). Forever refuses a name taken on
-- the other ruleset, so a name is one character.
local function realmOf(name)
    local realm = GetNormalizedRealmName()
    if realm and realm ~= "" then
        ns.db.realms[name] = realm
        return realm
    end
    if ns.db.realms[name] then return ns.db.realms[name] end
    for key, c in pairs(ns.db.characters) do
        local known = key:sub(#name + 2)
        if c.name == name and key:sub(1, #name + 1) == name .. "-" and known ~= "" then return known end
    end
    return ""
end

local function adopt(from, to)
    local old, new = ns.db.characters[from], ns.db.characters[to]
    ns.db.characters[from] = nil
    local last = { [from] = 0, [to] = 0 }
    for _, d in ipairs(ns.db.deaths) do
        if last[d.char] then last[d.char] = math.max(last[d.char], d.time or 0) end
    end
    if last[from] > last[to] then
        new.alive = old.alive or 0
    elseif last[from] == 0 then
        new.alive = (new.alive or 0) + (old.alive or 0)
    end
    for _, list in ipairs({ ns.db.deaths, ns.db.escapes, ns.db.bounties, ns.db.trophyFacts }) do
        for _, e in ipairs(list) do
            if e.char == from then e.char = to end
        end
    end
    local moved = {}
    for key, left in pairs(ns.db.payments) do
        local npc = key:match("^" .. from:gsub("%p", "%%%0") .. "|(.+)$")
        if npc then moved[npc] = left end
    end
    for npc, left in pairs(moved) do
        ns.db.payments[from .. "|" .. npc] = nil
        ns.db.payments[to .. "|" .. npc] = left
    end
end

local function adoptAll()
    for key, c in pairs(ns.db.characters) do
        if c.name and key == c.name .. "-" then
            local realm = ns.db.realms[c.name]
            for full, other in pairs(ns.db.characters) do
                if not realm and other.name == c.name and full ~= key then realm = full:sub(#key + 1) end
            end
            if realm and ns.db.characters[key .. realm] then adopt(key, key .. realm) end
        end
    end
end

local function onEnterWorld()
    local name = NameUtil.GetFullNameWithoutRealm(UnitName("player"))
    charKey = name .. "-" .. realmOf(name)
    char = ns.db.characters[charKey] or { alive = 0 }
    ns.db.characters[charKey] = char
    adoptAll()
    char.name, char.level, char.faction = name, UnitLevel("player"), UnitFactionGroup("player")
    char.class = select(2, UnitClass("player"))
    ready = not UnitIsDeadOrGhost("player")
    if ready then sessionStart = sessionStart or time() end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_DEAD")
events:RegisterEvent("PLAYER_ALIVE")
events:RegisterEvent("PLAYER_UNGHOST")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= addonName then return end
        DeathTrackerDB = DeathTrackerDB or {}
        local db = DeathTrackerDB
        db.deaths = db.deaths or {}
        db.characters = db.characters or {}
        db.npcNames = db.npcNames or {}
        db.mobBodies, db.mobKinds = db.mobBodies or {}, nil
        db.jokesShown = db.jokesShown or {}
        db.runs = db.runs or {}
        db.bounties = db.bounties or {}
        db.escapes = db.escapes or {}
        db.payments = db.payments or {}
        db.trophyFacts = db.trophyFacts or {}
        db.realms = db.realms or {}
        db.settings = db.settings or {}
        for k, v in pairs(ns.DEFAULTS) do
            if db.settings[k] == nil then db.settings[k] = v end
        end
        db.settings.cardPosition = db.settings.cardPosition or {}
        db.settings.posterPosition = db.settings.posterPosition or {}
        db.settings.trophyPosition = db.settings.trophyPosition or {}
        db.minimap = db.minimap or {}
        db.settings.counterPosition = db.settings.counterPosition or {}
        db.settings.barPosition = db.settings.barPosition or {}
        db.settings.historyPosition = db.settings.historyPosition or {}
        ns.db = db
        upgrade(db)
        events:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_ENTERING_WORLD" then
        onEnterWorld()
        -- PLAYER_ENTERING_WORLD fires on every loading screen, not only once per UI load.
        if not entered then
            entered = true
            sendStatus()
        end
        changed()
    elseif event == "PLAYER_DEAD" then
        onDead()
    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        if char and not UnitIsDeadOrGhost("player") then
            ready = true
            sessionStart = sessionStart or time()
        end
    elseif event == "PLAYER_LEVEL_UP" then
        if char then char.level = ... end
    elseif event == "PLAYER_TARGET_CHANGED" then
        if char and learnTarget() then changed() end
    elseif event == "PLAYER_LOGOUT" then
        if char then char.alive, sessionStart = ns.AliveSeconds(), nil end
    end
    for _, fn in ipairs(hooks[event] or {}) do fn(...) end
end)

function ns.OnEvent(event, fn)
    hooks[event] = hooks[event] or {}
    table.insert(hooks[event], fn)
    events:RegisterEvent(event)
end

local PAY_ONCE = { elite = true, rare = true, rareelite = true, worldboss = true }
ns.BOUNTY_MOST = 3
function ns.BountyLeft(key, npc)
    local _, _, _, fresh = ns.Nemesis({ char = key })
    local last = ns.Deaths({ char = key, npc = npc }, 1)[1]
    local owed = last and PAY_ONCE[last.killerRank or ""] and 1 or math.min(fresh or 1, ns.BOUNTY_MOST)
    return owed - (ns.db.payments[key .. "|" .. npc] or 0), owed
end

ns.OnEvent("PARTY_KILL", function(_, target)
    if issecretvalue(target) or not charKey then return end
    local _, npc = ns.ParseGUID(target)
    if not npc or ns.CharacterNemesis() ~= npc then return end
    local left = ns.BountyLeft(charKey, npc)
    local key = charKey .. "|" .. npc
    if left > 1 then
        ns.db.payments[key] = (ns.db.payments[key] or 0) + 1
        notify("payment", charKey, npc)
        return changed()
    end
    ns.db.payments[key] = nil
    notify("bounty", charKey, npc)
    table.insert(ns.db.bounties, { char = charKey, npc = npc, time = time() })
    sendStatus()
    changed()
end)
