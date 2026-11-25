-- Friends' death counts: your own record, the ones friends sent, the leaderboard and the Recent list.
-- No frames and no sending here (FriendsLink.lua sends, the Friends page and popups draw).
local _, ns = ...
local F = {}
ns.Friends = F

F.RECENT = 50
F.KILLERS = 8
F.ZONES = 8
F.SENT_DEATHS = 10    -- a record carries this many of the newest deaths, for Recent after time away
F.FORMAT = 7         -- what a record holds; a later format only adds fields at the end of each list; 7 sends deaths
F.ALL_KILLERS = 12

-- friendDeath: "off", "small" or "card". friendsGuild: the guild switch; friendsGuildAsked: its one chat line shown, or the switch used.
ns.DEFAULTS.friendDeath = "small"
ns.DEFAULTS.friendSound = true
ns.DEFAULTS.friendsGuild = false
ns.DEFAULTS.friendsGuildAsked = false

local demo
local function store()
    if demo then return demo end
    local s = ns.db.friends
    if not s then
        s = { players = {}, shared = {}, known = {}, refused = {}, recent = {}, version = 0 }
        ns.db.friends = s
    end
    return s
end
F.Store = store

-- Fake friends for testing in game (/deathtracker friends demo): held in memory, never saved.
function F.Demo(fake)
    demo = fake and { players = {}, shared = {}, known = {}, refused = {}, recent = {}, version = 0, me = F.Me() } or nil
    return demo
end

function F.IsDemo() return demo ~= nil end

-- Picked the first time it's needed, so nothing else's random numbers move before then.
function F.Me()
    local s = store()
    if not s.me then s.me = ("%08x"):format(math.random(0, 0x7fffffff)) end
    return s.me
end

-- Message fields can't hold the separators.
local function clean(v) return v == nil and "" or (tostring(v):gsub("[%^~,]", "")) end
-- Text that keeps every character: the separators travel as %XX.
local function esc(v) return (tostring(v):gsub("[%%,;@%^~]", function(c) return ("%%%02X"):format(c:byte()) end)) end
local function unesc(v) return (v:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)) end
local function num(v) return tonumber(v) or 0 end
local function opt(v) if v ~= nil and v ~= "" then return v end end

F.PERIODS = { "day", "week", "month" }

local function periods(t)
    local out = {}
    for i, p in ipairs(F.PERIODS) do out[i] = t and t[p] or 0 end
    return out
end

-- What the details panel shows of a death, in one field: "most;damage;deadIn;attackers;killer;hit;hit",
-- the killer "level@race@class@rank", each hit the panel lists "spell@id@amount@overkill@hp@before@source@npc@crit@melee@env".
local function hitText(v) return (clean(v):gsub("[;@]", "")) end
local function decimal(v, places) return v and ("%." .. places .. "f"):format(v) or "" end

local function fightOf(d)
    local f = ns.History.Fight(d)
    local who = table.concat({ d.killerLevel or "", hitText(d.killerRace), hitText(d.killerClass), hitText(d.killerRank) }, "@")
    local out = { d.maxHealth or "", f and f.damage or "", f and decimal(f.deadIn, 1) or "", f and f.attackers or "", who }
    for _, x in ipairs(f and f.hits or {}) do
        local h = x.hit
        out[#out + 1] = table.concat({ hitText(h.spell), h.spellId or "", h.amount or "", h.overkill or "", h.hp or "",
            decimal(h.before, 1), f.several and hitText(x.source) or "", h.npc or "", h.crit and 1 or "", h.melee and 1 or "",
            hitText(h.env) }, "@")
    end
    return table.concat(out, ";")
end

-- Which death it is, as your record numbers them for friends: every character, battlegrounds apart.
function F.DeathNumber(d)
    local n = 0
    for _, x in ipairs(ns.db.deaths) do
        if not ns.BattleDeath(x) and x.time <= d.time then n = n + 1 end
    end
    return n
end

local function lastDeath(d, total)
    local spell = (d.cause == "mob" or d.cause == "player") and (d.spell or "Melee") or nil
    return { killer = ns.DeathTitle(d), npc = d.npc, zone = d.zone, time = d.time, char = d.name,
        level = d.level, number = total, spell = spell, cause = d.cause, fight = fightOf(d), joke = d.joke }
end

-- What killed a friend. Older versions send no cause; a mob always has an npc id and a player never
-- does (Classify.lua), and only those two have a spell.
function F.Cause(l) return l.cause or (l.npc and "mob") or (l.spell and "player") or "unknown" end

-- Everything one player shares, from their own saved deaths.
local function gather()
    local chars, killers, killerNames, levels = {}, {}, {}, 0
    for key, c in pairs(ns.db.characters) do
        chars[key] = { name = c.name, class = c.class, level = c.level or 1, deaths = 0, longest = 0, pDeaths = {}, pLongest = {},
            repair = 0, ran = 0, ghost = 0, hit = 0, bg = 0, dungeon = 0, pBg = {}, pDungeon = {} }
    end
    local starts = {}
    for _, p in ipairs(F.PERIODS) do starts[p] = ns.PeriodStart(p) end
    local function countIn(t, d)
        for p, from in pairs(starts) do if d.time >= from then t[p] = (t[p] or 0) + 1 end end
    end
    -- Battlegrounds and arenas count apart, so a player who lives in them doesn't swamp the rest.
    -- Dungeons and raids count in the deaths, and apart too (only those saved with d.instance).
    local deaths, bg, dungeon, pBg, pDungeon, zoneDeaths = {}, 0, 0, {}, {}, {}
    local all = {}
    for _, d in ipairs(ns.db.deaths) do
        local c = chars[d.char]
        if ns.BattleDeath(d) then
            bg = bg + 1
            countIn(pBg, d)
            if c then c.bg = c.bg + 1; countIn(c.pBg, d) end
        else
            deaths[#deaths + 1] = d
            if d.instance == "party" or d.instance == "raid" then
                dungeon = dungeon + 1
                countIn(pDungeon, d)
                if c then c.dungeon = c.dungeon + 1; countIn(c.pDungeon, d) end
            end
            local kind = ns.CauseKind(d.cause)
            local k = kind == "mob" and d.npc and "m" .. d.npc or kind == "player" and not d.pet and d.killer and "p" .. d.killer
                or kind ~= "mob" and kind ~= "player" and "w" .. kind or nil
            if k then
                all[k] = all[k] or { kind = k:sub(1, 1), key = k:sub(2), kills = 0,
                    name = kind == "mob" and ns.db.npcNames[d.npc] or kind == "player" and d.killer or ns.DeathTitle(d) }
                all[k].kills = all[k].kills + 1
            end
        end
    end
    for _, d in ipairs(deaths) do
        local c = chars[d.char]
        if c then
            c.deaths, c.longest = c.deaths + 1, math.max(c.longest, d.alive or 0)
            if (d.amount or 0) > c.hit then c.hitWhat, c.hitTime = ns.DeathTitle(d, true), d.time end
            if (d.ran or 0) > c.ran then c.ranZone, c.ranTime, c.runSecs = d.zone, d.time, d.runSecs end
            c.repair, c.ran = c.repair + (d.repair or 0), math.max(c.ran, d.ran or 0)
            c.ghost, c.hit = c.ghost + (d.ghost or 0), math.max(c.hit, d.amount or 0)
            c.days = c.days or {}
            local day = ns.Day(d.time)
            c.days[day] = (c.days[day] or 0) + 1
            if c.days[day] > (c.dayMost or 0) then c.dayMost, c.dayMostDay = c.days[day], day end
            c.lastKiller, c.lastZone, c.lastTime = ns.DeathTitle(d), d.zone, d.time
            c.last = { killer = c.lastKiller, zone = d.zone, time = d.time }
            for p, from in pairs(starts) do
                if d.time >= from then
                    c.pDeaths[p] = (c.pDeaths[p] or 0) + 1
                    c.pLongest[p] = math.max(c.pLongest[p] or 0, d.alive or 0)
                end
            end
        end
        if d.npc then
            killers[d.npc] = (killers[d.npc] or 0) + 1
            killerNames[d.npc] = killerNames[d.npc] or d.killer
        end
        if d.zone then zoneDeaths[d.zone] = (zoneDeaths[d.zone] or 0) + 1 end
    end
    local list = {}
    for key, c in pairs(chars) do
        levels = levels + c.level
        local npc, name, kills = ns.Nemesis({ char = key })
        c.nemNpc, c.nemName, c.nemKills = npc, name, kills
        local cr = ns.History.Records({ char = key, noBattle = true })
        if cr.longestLife then
            local ld = cr.longestLife.death
            c.longestWhat, c.longestZone, c.longestTime = ns.DeathTitle(ld), ld.zone, ld.time
        end
        if cr.mostExpensive then
            c.costly, c.costlyWhat, c.costlyTime = cr.mostExpensive.value, ns.DeathTitle(cr.mostExpensive.death), cr.mostExpensive.death.time
        end
        if cr.longestGhost then
            c.ghostMost, c.ghostZone, c.ghostTime = cr.longestGhost.value, cr.longestGhost.death.zone, cr.longestGhost.death.time
        end
        if cr.hardestHit then c.hitZone = cr.hardestHit.death.zone end
        list[#list + 1] = c
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    local top = {}
    -- A mob's tooltip name can't always be read (in a dungeon): then the name its death saved.
    for npc, kills in pairs(killers) do
        top[#top + 1] = { npc = npc, kills = kills, name = ns.db.npcNames[npc] or killerNames[npc] }
    end
    table.sort(top, function(a, b)
        if a.kills ~= b.kills then return a.kills > b.kills end
        return a.npc < b.npc
    end)
    for i = #top, F.KILLERS + 1, -1 do top[i] = nil end
    local zones = {}
    for zone, n in pairs(zoneDeaths) do zones[#zones + 1] = { zone = zone, deaths = n } end
    table.sort(zones, function(a, b)
        if a.deaths ~= b.deaths then return a.deaths > b.deaths end
        return a.zone < b.zone
    end)
    for i = #zones, F.ZONES + 1, -1 do zones[i] = nil end
    local allTop = {}
    for _, k in pairs(all) do allTop[#allTop + 1] = k end
    table.sort(allTop, function(a, b)
        if a.kills ~= b.kills then return a.kills > b.kills end
        return a.kind .. a.key < b.kind .. b.key
    end)
    for i = #allTop, F.ALL_KILLERS + 1, -1 do allTop[i] = nil end
    local r, totals = ns.History.Records({ noBattle = true }), ns.History.Totals({ noBattle = true })
    local s = store()
    local rec = { id = F.Me(), deaths = #deaths, levels = levels, chars = list, killers = top, avenged = s.avenged or 0,
        avengedId = s.lastAvenged and s.lastAvenged.id, avengedAt = s.lastAvenged and s.lastAvenged.time,
        repair = totals.repair, ghost = totals.ghost, ran = r.longestRun and r.longestRun.value or 0,
        hit = r.hardestHit and r.hardestHit.value or 0, bg = bg, dungeon = dungeon, pBg = pBg, pDungeon = pDungeon,
        allKillers = allTop, zones = zones, format = F.FORMAT }
    if r.hardestHit then rec.hitWhat, rec.hitTime = ns.DeathTitle(r.hardestHit.death, true), r.hardestHit.death.time end
    if r.longestRun then
        rec.ranZone, rec.ranTime, rec.runSecs = r.longestRun.death.zone, r.longestRun.death.time, r.longestRun.death.runSecs
    end
    if r.longestLife then
        rec.longest, rec.longestChar, rec.longestAt = r.longestLife.value, r.longestLife.death.name, r.longestLife.death.time
    end
    if r.mostInDay then rec.dayMost, rec.dayMostDay = r.mostInDay.deaths, r.mostInDay.day end
    rec.pDeaths, rec.pLongest = {}, {}
    for _, p in ipairs(F.PERIODS) do
        local from, n, best = ns.PeriodStart(p), 0, 0
        for _, d in ipairs(deaths) do
            if d.time >= from then n, best = n + 1, math.max(best, d.alive or 0) end
        end
        rec.pDeaths[p], rec.pLongest[p] = n, best
    end
    rec.earlier = {}
    for i = math.max(1, #deaths - F.SENT_DEATHS + 1), #deaths - 1 do rec.earlier[#rec.earlier + 1] = lastDeath(deaths[i], i) end
    local d = deaths[#deaths]
    if d then
        rec.last = lastDeath(d, #deaths)
        local npc, name, kills = ns.Nemesis({ char = d.char })
        if npc then rec.nem = { npc = npc, name = name, kills = kills } end
    end
    -- The deaths the records name, for their details on a friend's screen; the newest are there already.
    local sent, number = {}, {}
    for _, e in ipairs(rec.earlier) do sent[e.time .. e.char] = true end
    if rec.last then sent[rec.last.time .. rec.last.char] = true end
    for i, x in ipairs(deaths) do number[x.time .. x.name] = i end
    rec.records = {}
    for _, c in ipairs(list) do
        for _, at in ipairs({ c.hitTime, c.ranTime, c.longestTime, c.costlyTime, c.ghostTime }) do
            local i = number[at .. c.name]
            if i and not sent[at .. c.name] then
                sent[at .. c.name] = true
                rec.records[#rec.records + 1] = lastDeath(deaths[i], i)
            end
        end
    end
    return rec
end

-- One death in a list of the record: the newest before the last, or one a record names.
local function deathText(e)
    return table.concat({ clean(e.killer), e.npc or "", clean(e.zone), e.time or "", clean(e.char), e.level or "",
        e.number or "", clean(e.spell), clean(e.cause), e.fight or "", e.joke and esc(e.joke) or "" }, ",")
end

local function body(rec)
    local chars, killers = {}, {}
    for _, c in ipairs(rec.chars) do
        chars[#chars + 1] = table.concat({ clean(c.name), clean(c.class), c.level, c.deaths,
            c.nemNpc or "", clean(c.nemName), c.nemKills or "", c.longest or 0, table.concat(periods(c.pDeaths), "/"),
            table.concat(periods(c.pLongest), "/"), c.repair or 0, c.ran or 0, c.ghost or 0, c.hit or 0, c.dayMost or "",
            clean(c.dayMostDay), clean(c.lastKiller), clean(c.lastZone), c.lastTime or "", c.bg or 0, clean(c.hitWhat),
            c.hitTime or "", clean(c.ranZone), c.ranTime or "", c.dungeon or 0, table.concat(periods(c.pDungeon or {}), "/"),
            table.concat(periods(c.pBg or {}), "/"), c.runSecs or "", clean(c.longestWhat), clean(c.longestZone),
            c.longestTime or "", c.costly or 0, clean(c.costlyWhat), c.costlyTime or "", c.ghostMost or 0, clean(c.ghostZone),
            c.ghostTime or "", clean(c.hitZone) }, ",")
    end
    for _, k in ipairs(rec.killers) do killers[#killers + 1] = table.concat({ k.npc, k.kills, clean(k.name) }, ",") end
    local all = {}
    for _, k in ipairs(rec.allKillers or {}) do
        all[#all + 1] = table.concat({ k.kind, clean(k.key), k.kills, clean(k.name) }, ",")
    end
    local earlier, records = {}, {}
    for _, e in ipairs(rec.earlier or {}) do earlier[#earlier + 1] = deathText(e) end
    for _, e in ipairs(rec.records or {}) do records[#records + 1] = deathText(e) end
    local zones = {}
    for _, z in ipairs(rec.zones or {}) do zones[#zones + 1] = clean(z.zone) .. "," .. z.deaths end
    local l, n = rec.last or {}, rec.nem or {}
    return table.concat({ rec.deaths, rec.levels, rec.longest or "", clean(rec.longestChar), rec.longestAt or "",
        rec.dayMost or "", clean(rec.dayMostDay), clean(l.killer), l.npc or "", clean(l.zone), l.time or "",
        clean(l.char), l.level or "", l.number or "", n.npc or "", clean(n.name), n.kills or "",
        table.concat(chars, "~"), table.concat(killers, "~"), clean(l.spell), rec.avenged or 0, clean(rec.avengedId),
        rec.avengedAt or "", table.concat(periods(rec.pDeaths), ","), table.concat(periods(rec.pLongest), ","), rec.sentAt or "",
        table.concat({ rec.repair or 0, rec.ran or 0, rec.ghost or 0, rec.hit or 0 }, ","),
        table.concat({ rec.bg or 0, clean(rec.hitWhat), rec.hitTime or "", clean(rec.ranZone), rec.ranTime or "" }, ","),
        F.FORMAT, table.concat({ rec.dungeon or 0, table.concat(periods(rec.pDungeon or {}), "/"),
            table.concat(periods(rec.pBg or {}), "/") }, ","), table.concat(all, "~"), rec.runSecs or "",
        table.concat(earlier, "~"), clean(l.cause), table.concat(zones, "~"), l.fight or "", table.concat(records, "~"), l.joke and esc(l.joke) or "" }, "^")
end

-- Your record; its version goes up whenever what it says changes (a death, a deleted death, a level).
function F.Mine()
    local s, rec = store(), gather()
    local said = body(rec)
    if said ~= s.sent then s.version, s.sent, s.sentAt = s.version + 1, said, time() end
    rec.v, rec.sentAt = s.version, s.sentAt or time()
    return rec, rec.id .. "^" .. rec.v .. "^" .. body(rec)
end

-- sep is one plain character.
local function split(text, sep)
    local out = {}
    for part in (text .. sep):gmatch("(.-)%" .. sep) do out[#out + 1] = part end
    return out
end

local function fightFrom(text, death)
    local parts = opt(text) and split(text, ";")
    if not parts or #parts < 5 then return end
    local who = split(parts[5], "@")
    death.killerLevel, death.killerRace, death.killerClass, death.killerRank = tonumber(who[1]), opt(who[2]), opt(who[3]), opt(who[4])
    if not tonumber(parts[2]) then return end
    death.maxHealth = tonumber(parts[1])
    death.sum = { damage = num(parts[2]), deadIn = tonumber(parts[3]), attackers = num(parts[4]) }
    death.hits = {}
    for i = 6, #parts do
        local f = split(parts[i], "@")
        death.hits[#death.hits + 1] = { spell = opt(f[1]), spellId = tonumber(f[2]), amount = tonumber(f[3]),
            overkill = tonumber(f[4]), hp = tonumber(f[5]), before = tonumber(f[6]), source = opt(f[7]), npc = tonumber(f[8]),
            crit = f[9] == "1" or nil, melee = f[10] == "1" or nil, env = opt(f[11]) }
    end
end

local function deathsFrom(text)
    local out = {}
    for _, e in ipairs(opt(text) and split(text, "~") or {}) do
        local f = split(e, ",")
        if opt(f[1]) and tonumber(f[4]) then
            out[#out + 1] = { killer = f[1], npc = tonumber(f[2]), zone = opt(f[3]), time = num(f[4]), char = opt(f[5]),
                level = tonumber(f[6]), number = tonumber(f[7]), spell = opt(f[8]), cause = opt(f[9]) }
            fightFrom(f[10], out[#out])
            out[#out].joke = opt(f[11]) and unesc(f[11])
        end
    end
    return out
end

function F.Parse(text)
    local p = split(text, "^")
    -- Fields only ever get added at the end: a record from a later version reads as far as this one
    -- knows, one from an earlier version reads what it has (29: the first test builds).
    if #p < 29 or not tonumber(p[2]) then return nil end
    local rec = { id = p[1], v = num(p[2]), deaths = num(p[3]), levels = num(p[4]), longest = tonumber(p[5]),
        longestChar = opt(p[6]), longestAt = tonumber(p[7]), dayMost = tonumber(p[8]), dayMostDay = opt(p[9]),
        chars = {}, killers = {}, avenged = num(p[23]), avengedId = opt(p[24]), avengedAt = tonumber(p[25]),
        pDeaths = {}, pLongest = {}, sentAt = tonumber(p[28]) }
    local extra = split(p[29], ",")
    rec.repair, rec.ran, rec.ghost, rec.hit = num(extra[1]), num(extra[2]), num(extra[3]), num(extra[4])
    local more = split(p[30] or "", ",")
    rec.bg, rec.hitWhat, rec.hitTime = num(more[1]), opt(more[2]), tonumber(more[3])
    rec.ranZone, rec.ranTime = opt(more[4]), tonumber(more[5])
    rec.format = tonumber(p[31]) or 1
    local where = split(p[32] or "", ",")
    rec.dungeon, rec.pDungeon, rec.pBg = num(where[1]), {}, {}
    local wd, wb = split(where[2] or "", "/"), split(where[3] or "", "/")
    for i, period in ipairs(F.PERIODS) do rec.pDungeon[period], rec.pBg[period] = num(wd[i]), num(wb[i]) end
    rec.runSecs = tonumber(p[34])
    rec.zones = {}
    for _, z in ipairs(opt(p[37]) and split(p[37], "~") or {}) do
        local f = split(z, ",")
        if opt(f[1]) then rec.zones[#rec.zones + 1] = { zone = f[1], deaths = num(f[2]) } end
    end
    rec.allKillers = {}
    for _, k in ipairs(opt(p[33]) and split(p[33], "~") or {}) do
        local f = split(k, ",")
        if opt(f[1]) and opt(f[2]) then
            rec.allKillers[#rec.allKillers + 1] = { kind = f[1], key = f[2], kills = num(f[3]), name = opt(f[4]) }
        end
    end
    local pd, pl = split(p[26], ","), split(p[27], ",")
    for i, period in ipairs(F.PERIODS) do rec.pDeaths[period], rec.pLongest[period] = num(pd[i]), num(pl[i]) end
    if opt(p[10]) then
        rec.last = { killer = p[10], npc = tonumber(p[11]), zone = opt(p[12]), time = num(p[13]), char = opt(p[14]),
            level = tonumber(p[15]), number = tonumber(p[16]), spell = opt(p[22]), cause = opt(p[36]) }
        fightFrom(p[38], rec.last)
        rec.last.joke = opt(p[40]) and unesc(p[40])
    end
    rec.earlier, rec.records = deathsFrom(p[35]), deathsFrom(p[39])
    if tonumber(p[17]) then rec.nem = { npc = tonumber(p[17]), name = opt(p[18]), kills = num(p[19]) } end
    for _, c in ipairs(p[20] ~= "" and split(p[20], "~") or {}) do
        local f = split(c, ",")
        local ch = { name = f[1], class = opt(f[2]), level = num(f[3]), deaths = num(f[4]),
            nemNpc = tonumber(f[5]), nemName = opt(f[6]), nemKills = tonumber(f[7]), longest = num(f[8]), pDeaths = {}, pLongest = {},
            repair = num(f[11]), ran = num(f[12]), ghost = num(f[13]), hit = num(f[14]), dayMost = tonumber(f[15]),
            dayMostDay = opt(f[16]), bg = num(f[20]), hitWhat = opt(f[21]), hitTime = tonumber(f[22]), ranZone = opt(f[23]),
            ranTime = tonumber(f[24]), dungeon = num(f[25]), pDungeon = {}, pBg = {}, runSecs = tonumber(f[28]),
            longestWhat = opt(f[29]), longestZone = opt(f[30]), longestTime = tonumber(f[31]), costly = num(f[32]),
            costlyWhat = opt(f[33]), costlyTime = tonumber(f[34]), ghostMost = num(f[35]), ghostZone = opt(f[36]),
            ghostTime = tonumber(f[37]), hitZone = opt(f[38]) }
        local cdg, cbg = split(f[26] or "", "/"), split(f[27] or "", "/")
        for i, period in ipairs(F.PERIODS) do ch.pDungeon[period], ch.pBg[period] = num(cdg[i]), num(cbg[i]) end
        if tonumber(f[19]) then ch.last = { killer = f[17], zone = opt(f[18]), time = tonumber(f[19]) } end
        local cd, cl = split(f[9] or "", "/"), split(f[10] or "", "/")
        for i, period in ipairs(F.PERIODS) do ch.pDeaths[period], ch.pLongest[period] = num(cd[i]), num(cl[i]) end
        rec.chars[#rec.chars + 1] = ch
    end
    for _, k in ipairs(p[21] ~= "" and split(p[21], "~") or {}) do
        local f = split(k, ",")
        local npc = tonumber(f[1])
        if npc then rec.killers[#rec.killers + 1] = { npc = npc, kills = num(f[2]), name = opt(f[3]) or ns.db.npcNames[npc] } end
    end
    return rec
end

-- What you know of a player beyond their record: who they are now and where.
function F.Known(id)
    local s = store()
    s.known[id] = s.known[id] or {}
    return s.known[id]
end

function F.Shares(id)
    local s = store()
    if s.shared[id] then return true end
    local k = s.known[id]
    if demo then return k ~= nil and k.guild ~= nil end
    return ns.db.settings.friendsGuild == true and k ~= nil and k.guild ~= nil and k.guild == F.GuildName()
end

function F.GuildName() return IsInGuild() and GetGuildInfo("player") or nil end

function F.Share(id) store().shared[id] = true end

local unshared = {}
function F.OnUnshare(fn) unshared[#unshared + 1] = fn end

function F.Unshare(id)
    local s = store()
    s.shared[id], s.players[id] = nil, nil
    for _, fn in ipairs(unshared) do fn(id) end
end

-- A friend's display name: their BattleTag without the numbers, else the character they play now.
function F.Name(id)
    local k = F.Known(id)
    return k.tag or k.char or (store().players[id] and store().players[id].chars[1] and store().players[id].chars[1].name) or "?"
end

-- Shared only through the guild switch, and neither a Battle.net friend nor on your friends list: a
-- guildmate who is also a friend counts as a friend (popups and all).
function F.IsGuildOnly(id)
    if store().shared[id] then return false end
    local k = store().known[id] or {}
    if k.tag then return false end
    return not (k.char and C_FriendList.GetFriendInfo(k.char))
end

function F.AddEvent(e)
    local list = store().recent
    e.time = e.time or time()
    local at = 1
    while list[at] and list[at].time > e.time do at = at + 1 end
    table.insert(list, at, e)
    for i = #list, F.RECENT + 1, -1 do list[i] = nil end
end

function F.Unseen()
    local n = 0
    for _, e in ipairs(store().recent) do if not e.seen then n = n + 1 end end
    return n
end

-- You killed a friend's nemesis: the Avenged tab counts it.
function F.Avenged(id)
    local s = store()
    s.avenged, s.lastAvenged = (s.avenged or 0) + 1, { id = id, time = time() }
end

function F.MarkSeen() for _, e in ipairs(store().recent) do e.seen = true end end

function F.Recent() return store().recent end

-- A record's deaths per level, or one character's when char is given.
local function perLevel(r, char)
    if char then return char.level > 0 and char.deaths / char.level or 0 end
    return r.levels > 0 and r.deaths / r.levels or 0
end

-- A record's (or one of its characters') deaths, longest life, dungeon or battleground deaths in a
-- period ("all", "day", "week", "month"); a record sent before the period began counts nothing in it.
local PER_PERIOD = { deaths = "pDeaths", longest = "pLongest", dungeon = "pDungeon", bg = "pBg" }
function F.Value(r, kind, period, char)
    local of = char or r
    if not period or period == "all" then return of[kind] or 0 end
    if not r.sentAt or r.sentAt < ns.PeriodStart(period) then return 0 end
    local t = of[PER_PERIOD[kind]]
    return t and t[period] or 0
end

function F.Char(rec, name)
    for _, c in ipairs(rec and rec.chars or {}) do if c.name == name then return c end end
end

-- One row per player you share with, and you. kind: "deaths", "perLevel", "longest" or "avenged";
-- period, for deaths and longest life: "all" (or nil), "day", "week" or "month".
function F.Rows(kind, period)
    local s, rows = store(), {}
    local mine = F.Mine()
    rows[1] = { rec = mine, you = true }
    for id, r in pairs(s.players) do
        if F.Shares(id) then rows[#rows + 1] = { rec = r, id = id } end
    end
    local value = kind == "perLevel" and perLevel or kind == "avenged" and function(r) return r.avenged or 0 end
        or function(r) return F.Value(r, kind, period) end
    for _, row in ipairs(rows) do row.value, row.deaths = value(row.rec), row.rec.deaths end
    table.sort(rows, function(a, b)
        if a.value ~= b.value then return a.value > b.value end
        return (a.you and "" or F.Name(a.id)) < (b.you and "" or F.Name(b.id))
    end)
    for i, row in ipairs(rows) do row.rank = i end
    return rows
end

F.PerLevel = perLevel

-- Players you share with, for the pane: Battle.net and other friends, then the guild.
function F.Players()
    local out = {}
    for id, r in pairs(store().players) do
        if F.Shares(id) then out[#out + 1] = r end
    end
    table.sort(out, function(a, b) return a.deaths > b.deaths end)
    return out
end

-- Takes a record a friend sent or passed on. Returns what changed, newest first, or nil when it
-- isn't newer than the one already held or isn't someone you share with.
function F.Take(rec)
    local s = store()
    if not rec or rec.id == F.Me() or not F.Shares(rec.id) then return nil end
    local old = s.players[rec.id]
    if old and old.v >= rec.v then return nil end
    rec.got = time()
    if old then
        rec.log, rec.logFull, rec.logNewest, rec.wantLog = old.log, old.logFull, old.logNewest, old.wantLog
    end
    s.players[rec.id] = rec
    -- Recent keeps its own copy of each death; a newer record can carry the hits an older one didn't.
    local sent = {}
    for _, e in ipairs(rec.earlier or {}) do sent[e.time] = e end
    if rec.last then sent[rec.last.time] = rec.last end
    for _, ev in ipairs(s.recent) do
        local l = ev.id == rec.id and ev.kind == "death" and ev.last
        local got = l and not l.hits and sent[l.time]
        if got and got.hits then l.hits, l.maxHealth, l.sum = got.hits, got.maxHealth, got.sum end
    end
    local changes = {}
    -- A deleted newest death changes the last one too, and lowers the count: that isn't news.
    if old and rec.last and (not old.last or (old.last.time ~= rec.last.time and rec.deaths >= old.deaths)) then
        local seen = old.last and old.last.time
        for _, e in ipairs(rec.earlier or {}) do
            if seen and e.time > seen or not seen and (e.number or 0) > old.deaths then
                F.AddEvent({ kind = "death", id = rec.id, last = e, time = e.time })
            end
        end
        changes[#changes + 1] = { kind = "death", id = rec.id, last = rec.last, deaths = rec.deaths, before = old.deaths,
            time = rec.last.time }
        local was = F.Char(old, rec.last.char)
        if rec.nem and (was and was.nemNpc or nil) ~= rec.nem.npc then
            changes[#changes + 1] = { kind = "nemesis", id = rec.id, nem = rec.nem, zone = rec.last.zone, time = rec.last.time }
        end
        local passed
        for _, r in ipairs(F.Rows("deaths")) do
            if r.id ~= rec.id and r.deaths < rec.deaths and r.deaths >= old.deaths and (not passed or r.deaths > passed.deaths) then
                passed = r
            end
        end
        if passed then
            changes[#changes + 1] = { kind = "passed", id = rec.id, other = passed.you and "you" or passed.id, deaths = rec.deaths,
                time = rec.last.time }
        end
    end
    for i = #changes, 1, -1 do F.AddEvent(changes[i]) end
    return changes
end

-- Each field of a saved death and of each hit, with its kind: s text, n number, b true or nothing.
local DEATH_FIELDS = { { "char", "s" }, { "name", "s" }, { "time", "n" }, { "level", "n" }, { "zone", "s" }, { "subzone", "s" },
    { "cause", "s" }, { "killer", "s" }, { "npc", "n" }, { "spell", "s" }, { "amount", "n" }, { "alive", "n" }, { "ghost", "n" },
    { "ran", "n" }, { "runSecs", "n" }, { "repair", "n" }, { "instance", "s" }, { "pet", "b" }, { "killerClassFile", "s" },
    { "killerFaction", "s" }, { "number", "n" }, { "trophy", "s" }, { "joke", "s" }, { "school", "n" }, { "crit", "b" },
    { "overkill", "n" }, { "melee", "b" }, { "killerLevel", "n" }, { "killerRace", "s" }, { "killerClass", "s" },
    { "killerRank", "s" }, { "maxHealth", "n" } }
local BACK_FIELDS = { { "how", "s" }, { "by", "s" }, { "kind", "n" }, { "id", "n" } }
local HIT_FIELDS = { { "spell", "s" }, { "spellId", "n" }, { "amount", "n" }, { "overkill", "n" }, { "hp", "n" }, { "before", "n" },
    { "source", "s" }, { "npc", "n" }, { "crit", "b" }, { "melee", "b" }, { "env", "s" } }

local function fieldsText(t, fields, sep)
    local out = {}
    for i, f in ipairs(fields) do
        local v = t and t[f[1]]
        if v == nil then out[i] = ""
        elseif f[2] == "b" then out[i] = v and "1" or ""
        elseif f[2] == "n" then out[i] = tonumber(v) and ("%.10g"):format(tonumber(v)) or ""
        else out[i] = esc(v) end
    end
    return table.concat(out, sep)
end

local function fieldsFrom(text, fields, sep, into)
    local parts = split(text or "", sep)
    for i, f in ipairs(fields) do
        local v = parts[i]
        if f[2] == "b" then into[f[1]] = v == "1" or nil
        elseif f[2] == "n" then into[f[1]] = tonumber(v)
        else into[f[1]] = opt(v) and unesc(v) end
    end
    return into
end

function F.DeathText(d)
    local hits = {}
    for i, h in ipairs(d.hits or {}) do hits[i] = fieldsText(h, HIT_FIELDS, "@") end
    return table.concat({ fieldsText(d, DEATH_FIELDS, ","), fieldsText(d.back, BACK_FIELDS, ","), table.concat(hits, ";") }, ",")
end

function F.DeathFrom(text)
    local parts = split(text, ",")
    local n = #DEATH_FIELDS
    if #parts < n + #BACK_FIELDS then return nil end
    local d = fieldsFrom(table.concat(parts, ",", 1, n), DEATH_FIELDS, ",", {})
    if not d.time then return nil end
    d.name = d.name or "?"
    local back = fieldsFrom(table.concat(parts, ",", n + 1, n + #BACK_FIELDS), BACK_FIELDS, ",", {})
    if back.how then d.back = back end
    local hits = parts[n + #BACK_FIELDS + 1]
    if opt(hits) then
        d.hits = {}
        for i, h in ipairs(split(hits, ";")) do d.hits[i] = fieldsFrom(h, HIT_FIELDS, "@", {}) end
    end
    return d
end

-- A friend's deaths are kept as the text they came in, oldest first, and read back when their pages open;
-- a death whose text doesn't change stays the same table, so an open death stays open.
local decoded = {}   -- id -> { log, n, newest: the texts read; list: their deaths; of: text -> death }
local function keepTexts(rec, texts, from, total)
    local log = from == 1 and {} or rec.log or {}
    for i, t in ipairs(texts) do log[from + i - 1] = t end
    for i = #log, total + 1, -1 do log[i] = nil end
    local newest = log[#log] and F.DeathFrom(log[#log])
    rec.log, rec.logFull, rec.logNewest = log, #log == total or nil, newest and newest.time
end

function F.TakeDeaths(id, list, from, total)
    local rec = store().players[id]
    if not rec then return end
    local texts = {}
    for i, d in ipairs(list) do texts[i] = F.DeathText(d) end
    keepTexts(rec, texts, from, total)
end

-- One batch as it travels; a batch that doesn't follow on from the deaths held is left out.
function F.TakeDeathsText(id, from, total, text)
    local rec = store().players[id]
    if not rec or (from ~= 1 and from ~= #(rec.log or {}) + 1) then return false end
    local texts = opt(text) and split(text, "~") or {}
    for _, t in ipairs(texts) do
        if not F.DeathFrom(t) then return false end
    end
    keepTexts(rec, texts, from, total)
    return true
end

function F.Holding(id)
    local rec = store().players[id]
    return rec and rec.log and #rec.log or 0, rec and rec.logNewest or 0
end

-- You opened this friend in the window: their deaths are asked for from now on.
function F.WantDeaths(id)
    local rec = store().players[id]
    if rec then rec.wantLog = true end
end

function F.WantsDeaths(id)
    local rec = store().players[id]
    return rec ~= nil and rec.wantLog == true
end

-- Their Death Tracker sends deaths, so the rest are on the way.
function F.SendsDeaths(id)
    local rec = store().players[id]
    return rec ~= nil and (rec.format or 1) >= 7
end

local function asDeath(e)
    local hit, cause = e.hits and e.hits[1], F.Cause(e)
    return { killer = (cause == "mob" or cause == "player") and e.killer or nil, npc = e.npc, zone = e.zone, time = e.time, char = e.char, name = e.char or "?",
        level = e.level, number = e.number, spell = e.spell ~= "Melee" and e.spell or nil, cause = cause,
        amount = hit and hit.amount, hits = e.hits, maxHealth = e.maxHealth, killerLevel = e.killerLevel,
        killerRace = e.killerRace, killerClass = e.killerClass, killerRank = e.killerRank, joke = e.joke }
end

-- A record from a version that doesn't send every death: the deaths it carries, as saved deaths.
local function recordDeaths(rec)
    local seen, out = {}, {}
    local function keep(e)
        if not e or not e.time or seen[e.time .. (e.char or "")] then return end
        seen[e.time .. (e.char or "")] = true
        out[#out + 1] = asDeath(e)
    end
    for _, e in ipairs(rec.earlier or {}) do keep(e) end
    keep(rec.last)
    for _, e in ipairs(rec.records or {}) do keep(e) end
    table.sort(out, function(a, b) return a.time < b.time end)
    return out
end

local fromRecord = setmetatable({}, { __mode = "k" })
function F.Log(id)
    local rec = store().players[id]
    if not rec then return {} end
    if rec.logFull then
        local c = decoded[id]
        if not (c and c.log == rec.log and c.n == #rec.log and c.newest == rec.logNewest) then
            local list, of = {}, {}
            for i, t in ipairs(rec.log) do
                of[t] = c and c.of[t] or F.DeathFrom(t)
                list[i] = of[t]
            end
            c = { log = rec.log, n = #rec.log, newest = rec.logNewest, list = list, of = of }
            decoded[id] = c
        end
        return c.list
    end
    fromRecord[rec] = fromRecord[rec] or recordDeaths(rec)
    return fromRecord[rec]
end

function F.Find(id, e)
    for _, d in ipairs(F.Log(id)) do
        if d.time == e.time and d.name == e.char then return d end
    end
    return asDeath(e)
end

function F.Partial(id)
    local rec = store().players[id]
    return rec ~= nil and not rec.logFull
end

-- "Morwenna, Grimtusk and Kaelthorn"; names may start with "you". With many, from that many on:
-- "Morwenna and 3 friends".
function F.Names(names, many)
    if many and #names >= many then return ("%s and %d friends"):format(names[1], #names - 1) end
    return ns.UI.AndList(names)
end

function F.NamesOf(ids, many)
    local list = {}
    for _, id in ipairs(ids) do list[#list + 1] = F.Name(id) end
    return F.Names(list, many)
end

-- Popups wait until you're out of combat, alive and out of a battleground.
local waiting = {}
local function free() return not InCombatLockdown() and not UnitIsDeadOrGhost("player") and not ns.InBattle() end

function F.WhenFree(fn)
    if free() then return fn() end
    waiting[#waiting + 1] = fn
end

local function flush()
    if not free() then return end
    local list = waiting
    waiting = {}
    for _, fn in ipairs(list) do fn() end
end
for _, event in ipairs({ "PLAYER_REGEN_ENABLED", "PLAYER_UNGHOST", "PLAYER_ALIVE", "ZONE_CHANGED_NEW_AREA" }) do
    ns.OnEvent(event, flush)
end

-- How often a mob (NPC ID) has killed each friend: { { id, kills } }, most first.
function F.KilledFriends(npc)
    local out = {}
    for id, r in pairs(store().players) do
        if F.Shares(id) then
            for _, k in ipairs(r.killers) do
                if k.npc == npc then out[#out + 1] = { id = id, kills = k.kills } end
            end
        end
    end
    table.sort(out, function(a, b) return a.kills > b.kills end)
    return out
end

-- Friends whose nemesis that mob is, on the character they play now.
function F.NemesisOf(npc)
    local out = {}
    for id, r in pairs(store().players) do
        local c = F.Shares(id) and F.Char(r, F.Known(id).char)
        if c and c.nemNpc == npc then out[#out + 1] = id end
    end
    return out
end
