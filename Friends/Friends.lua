local _, ns = ...
local F = {}
ns.Friends = F

F.RECENT = 50
F.KILLERS = 8
F.ZONES = 8
F.SENT_DEATHS = 10
F.FORMAT = 7
F.AVENGE_DAYS = 7
F.ALL_KILLERS = 12

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

function F.Demo(fake)
    demo = fake and { players = {}, shared = {}, known = {}, refused = {}, recent = {}, version = 0, me = F.Me() } or nil
    return demo
end

function F.IsDemo() return demo ~= nil end

function F.Me()
    local s = store()
    if not s.me then s.me = ("%08x"):format(math.random(0, 0x7fffffff)) end
    return s.me
end

local function clean(v) return v == nil and "" or (tostring(v):gsub("[%^~,]", "")) end
F.Clean = clean
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

-- Older versions send no cause: a mob always has an npc id, a player never does, and only those two have a spell.
function F.Cause(l) return l.cause or (l.npc and "mob") or (l.spell and "player") or "unknown" end

local function gather()
    local chars, killers, killerNames, levels = {}, {}, {}, 0
    for key, c in pairs(ns.db.characters) do
        chars[key] = { name = c.name, deleted = c.deleted, class = c.class, faction = c.faction, level = c.level or 1, deaths = 0, longest = 0, pDeaths = {}, pLongest = {},
            repair = 0, ran = 0, ghost = 0, hit = 0, bg = 0, dungeon = 0, pBg = {}, pDungeon = {} }
    end
    local starts = {}
    for _, p in ipairs(F.PERIODS) do starts[p] = ns.PeriodStart(p) end
    local function countIn(t, d)
        for p, from in pairs(starts) do if d.time >= from then t[p] = (t[p] or 0) + 1 end end
    end
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
    -- A mob's tooltip name can't always be read in a dungeon.
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
        allKillers = allTop, zones = zones, format = F.FORMAT, avengedFor = {} }
    for id, a in pairs(s.avengedFor or {}) do
        if time() - a.time < F.AVENGE_DAYS * 86400 then rec.avengedFor[id] = a end
    end
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

local function avengedText(list)
    local out = {}
    for id, a in pairs(list or {}) do
        out[#out + 1] = table.concat({ clean(id), a.time, clean(a.kind), clean(a.name), clean(a.class), clean(a.zone), a.npc or "" }, ",")
    end
    return table.concat(out, "~")
end

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
            c.ghostTime or "", clean(c.hitZone), clean(c.faction), c.deleted or "" }, ",")
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
        table.concat(earlier, "~"), clean(l.cause), table.concat(zones, "~"), l.fight or "", table.concat(records, "~"), l.joke and esc(l.joke) or "", avengedText(rec.avengedFor) }, "^")
end

function F.Mine()
    local s, rec = store(), gather()
    local said = body(rec)
    if said ~= s.sent then s.version, s.sent, s.sentAt = s.version + 1, said, time() end
    rec.v, rec.sentAt = s.version, s.sentAt or time()
    return rec, rec.id .. "^" .. rec.v .. "^" .. body(rec)
end

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

local function addInto(into, from)
    for _, p in ipairs(F.PERIODS) do into[p] = (into[p] or 0) + (from and from[p] or 0) end
end

local SUMS = { "deaths", "repair", "ghost", "bg", "dungeon" }
local BESTS = { { "longest", "longestWhat", "longestZone", "longestTime" }, { "hit", "hitWhat", "hitTime", "hitZone" },
    { "ran", "ranZone", "ranTime", "runSecs" }, { "costly", "costlyWhat", "costlyTime" },
    { "ghostMost", "ghostZone", "ghostTime" }, { "dayMost", "dayMostDay" } }

local function sameChar(a, b)
    local new, old = a, b
    if (b.level or 0) > (a.level or 0) then new, old = b, a end
    local c = {}
    for k, v in pairs(new) do c[k] = v end
    for _, f in ipairs(SUMS) do c[f] = (a[f] or 0) + (b[f] or 0) end
    for _, f in ipairs({ "pDeaths", "pBg", "pDungeon" }) do
        c[f] = {}
        addInto(c[f], a[f])
        addInto(c[f], b[f])
    end
    c.pLongest = {}
    for _, p in ipairs(F.PERIODS) do c.pLongest[p] = math.max(a.pLongest and a.pLongest[p] or 0, b.pLongest and b.pLongest[p] or 0) end
    for _, group in ipairs(BESTS) do
        local from = (old[group[1]] or 0) > (new[group[1]] or 0) and old or new
        for _, f in ipairs(group) do c[f] = from[f] end
    end
    if old.last and old.last.time > (new.last and new.last.time or 0) then c.last = old.last end
    return c
end

-- A full name is one living character on Forever, so two entries with one name are the same character: a
-- friend whose saved data was reset (a new id) or saved under a realmless key. A deleted one stays apart.
local function byName(chars)
    local out, at = {}, {}
    for _, c in ipairs(chars) do
        local key = c.name .. "#" .. (c.deleted or "")
        local i = at[key]
        if i then
            out[i] = sameChar(out[i], c)
        else
            out[#out + 1] = c
            at[key] = #out
        end
    end
    return out
end

function F.Parse(text)
    local p = split(text, "^")
    -- 29: the first format's field count; later formats only add fields at the end.
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
    rec.avengedFor = {}
    for _, a in ipairs(opt(p[41]) and split(p[41], "~") or {}) do
        local f = split(a, ",")
        if opt(f[1]) and tonumber(f[2]) then
            rec.avengedFor[f[1]] = { time = tonumber(f[2]), kind = opt(f[3]), name = opt(f[4]), class = opt(f[5]), zone = opt(f[6]), npc = tonumber(f[7]) }
        end
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
            ghostTime = tonumber(f[37]), hitZone = opt(f[38]), faction = opt(f[39]), deleted = tonumber(f[40]) }
        local cdg, cbg = split(f[26] or "", "/"), split(f[27] or "", "/")
        for i, period in ipairs(F.PERIODS) do ch.pDungeon[period], ch.pBg[period] = num(cdg[i]), num(cbg[i]) end
        if tonumber(f[19]) then ch.last = { killer = f[17], zone = opt(f[18]), time = tonumber(f[19]) } end
        local cd, cl = split(f[9] or "", "/"), split(f[10] or "", "/")
        for i, period in ipairs(F.PERIODS) do ch.pDeaths[period], ch.pLongest[period] = num(cd[i]), num(cl[i]) end
        rec.chars[#rec.chars + 1] = ch
    end
    rec.chars = byName(rec.chars)
    for _, k in ipairs(p[21] ~= "" and split(p[21], "~") or {}) do
        local f = split(k, ",")
        local npc = tonumber(f[1])
        if npc then rec.killers[#rec.killers + 1] = { npc = npc, kills = num(f[2]), name = opt(f[3]) or ns.db.npcNames[npc] } end
    end
    return rec
end

function F.Known(id)
    local s = store()
    s.known[id] = s.known[id] or {}
    return s.known[id]
end

function F.InGroup(id)
    local char = F.Known(id).char
    return char ~= nil and (UnitInParty(char) or UnitInRaid(char)) and true or false
end

local noAccount = {}
function F.Account(id)
    local k = store().known[id]
    if not (k and k.tag) then return nil end
    if not k.account and not noAccount[id] and ns.FriendsLink then
        k.account = ns.FriendsLink.AccountByTag(k.tag)
        noAccount[id] = k.account == nil
    end
    return k.account
end

function F.SharesAccount(account)
    local s = store()
    if not account or (s.stopped and s.stopped[account]) then return false end
    for id in pairs(s.shared) do
        if F.Account(id) == account then return true end
    end
    return false
end

function F.Shares(id)
    local s = store()
    if s.shared[id] then return true end
    local k = s.known[id]
    if F.SharesAccount(F.Account(id)) then return true end
    if demo then return k ~= nil and k.guild ~= nil end
    return ns.db.settings.friendsGuild == true and k ~= nil and k.guild ~= nil and k.guild == F.GuildName()
end

function F.GuildName() return IsInGuild() and GetGuildInfo("player") or nil end

function F.Share(id)
    local s, account = store(), F.Account(id)
    s.shared[id] = true
    if account and s.stopped then s.stopped[account] = nil end
end

local unshared = {}
function F.OnUnshare(fn) unshared[#unshared + 1] = fn end

local function sameAccount(id)
    local account, out = F.Account(id), { id }
    if not account then return out, nil end
    for other in pairs(store().known) do
        if other ~= id and F.Account(other) == account then out[#out + 1] = other end
    end
    return out, account
end
F.SameAccount = sameAccount

function F.Unshare(id)
    local s = store()
    local ids, account = sameAccount(id)
    if account then
        s.stopped = s.stopped or {}
        s.stopped[account] = true
    end
    for _, x in ipairs(ids) do
        s.shared[x], s.players[x] = nil, nil
        for _, fn in ipairs(unshared) do fn(x) end
    end
end

-- One Battle.net account can hold several WoW accounts, each with its own saved file and id.
function F.Ids(id)
    local s, out = store(), {}
    local account = F.Account(id)
    if account then
        for other in pairs(s.players) do
            if F.Account(other) == account and F.Shares(other) then out[#out + 1] = other end
        end
    end
    if #out == 0 then return { id } end
    table.sort(out)
    return out
end

function F.Primary(id) return F.Ids(id)[1] end

function F.Current(person)
    local ids = F.Ids(person)
    local best, seen = ids[1], -1
    for _, id in ipairs(ids) do
        if ns.FriendsLink.Online(id) then return id end
        local k = store().known[id]
        if k and (k.seen or 0) > seen then best, seen = id, k.seen or 0 end
    end
    return best
end

function F.Name(id)
    local k = F.Known(id)
    return k.tag or k.char or (store().players[id] and store().players[id].chars[1] and store().players[id].chars[1].name) or "?"
end

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

-- kind "player" or "mob"; the friend's record carries it, so a friend who missed the message sees it later.
function F.Avenged(id, kind, name, class, zone, npc)
    local s, now = store(), time()
    s.avenged, s.lastAvenged = (s.avenged or 0) + 1, { id = id, time = now }
    s.avengedFor = s.avengedFor or {}
    s.avengedFor[id] = { time = now, kind = kind, name = name, class = class, zone = zone, npc = npc }
    return now
end

-- The last time a friend avenged you, by their clock, so the same avenge never shows twice.
function F.AvengeSeen(id, at)
    local s = store()
    s.avengeSeen = s.avengeSeen or {}
    if at then s.avengeSeen[id] = math.max(s.avengeSeen[id] or 0, at) end
    return s.avengeSeen[id] or 0
end

function F.MarkSeen() for _, e in ipairs(store().recent) do e.seen = true end end

function F.Recent() return store().recent end

local function perLevel(r, char)
    if char then return char.level > 0 and char.deaths / char.level or 0 end
    return r.levels > 0 and r.deaths / r.levels or 0
end

local PER_PERIOD = { deaths = "pDeaths", longest = "pLongest", dungeon = "pDungeon", bg = "pBg" }
function F.Value(r, kind, period, char)
    local of = char or r
    if not period or period == "all" then return of[kind] or 0 end
    if not r.sentAt or r.sentAt < ns.PeriodStart(period) then return 0 end
    local t = of[PER_PERIOD[kind]]
    return t and t[period] or 0
end

function F.Char(rec, name, deleted)
    local found
    for _, c in ipairs(rec and rec.chars or {}) do
        if c.name == name and c.deleted == deleted then return c end
        found = found or c.name == name and c or nil
    end
    return found
end

local sourceLog

local function countBefore(id, t)
    local rec = store().players[id]
    if not rec then return 0 end
    if rec.logFull then
        local n = 0
        for _, d in ipairs(sourceLog(id)) do
            if d.time < t and not ns.BattleDeath(d) then n = n + 1 end
        end
        return n
    end
    if not rec.last or rec.last.time < t then return rec.deaths end
end

function F.PersonNumber(id, t, number)
    if not number then return nil end
    for _, other in ipairs(F.Ids(id)) do
        if other ~= id then
            local n = countBefore(other, t)
            if not n then return nil end
            number = number + n
        end
    end
    return number
end

local function renumbered(id, e)
    if not e then return nil end
    local copy = {}
    for k, v in pairs(e) do copy[k] = v end
    copy.number = F.PersonNumber(id, e.time or 0, e.number)
    return copy
end

local function topBy(list, key, keep)
    local byKey, out = {}, {}
    for _, x in ipairs(list) do
        local k = key(x)
        if byKey[k] then
            byKey[k].kills = (byKey[k].kills or 0) + (x.kills or 0)
            byKey[k].deaths = byKey[k].deaths and byKey[k].deaths + (x.deaths or 0)
        else
            local copy = {}
            for f, v in pairs(x) do copy[f] = v end
            byKey[k] = copy
            out[#out + 1] = copy
        end
    end
    local count = function(x) return x.kills or x.deaths or 0 end
    table.sort(out, function(a, b)
        if count(a) ~= count(b) then return count(a) > count(b) end
        return key(a) < key(b)
    end)
    for i = #out, keep + 1, -1 do out[i] = nil end
    return out
end

local function merge(ids, recs)
    local m = { id = ids[1], v = 0, deaths = 0, levels = 0, chars = {}, avenged = 0, repair = 0, ran = 0, ghost = 0, hit = 0,
        bg = 0, dungeon = 0, pDeaths = {}, pLongest = {}, pDungeon = {}, pBg = {}, earlier = {}, records = {}, logFull = true }
    local killers, all, zones = {}, {}, {}
    for i, r in ipairs(recs) do
        local id = ids[i]
        m.v, m.deaths, m.levels = m.v + r.v, m.deaths + r.deaths, m.levels + r.levels
        m.avenged, m.repair, m.ghost = m.avenged + (r.avenged or 0), m.repair + (r.repair or 0), m.ghost + (r.ghost or 0)
        m.bg, m.dungeon = m.bg + (r.bg or 0), m.dungeon + (r.dungeon or 0)
        m.format = math.min(m.format or r.format or 1, r.format or 1)
        m.got = math.min(m.got or r.got or 0, r.got or 0)
        m.logFull = m.logFull and r.logFull or nil
        m.wantLog = m.wantLog or r.wantLog
        if (r.longest or 0) > (m.longest or 0) then m.longest, m.longestChar, m.longestAt = r.longest, r.longestChar, r.longestAt end
        if (r.dayMost or 0) > (m.dayMost or 0) then m.dayMost, m.dayMostDay = r.dayMost, r.dayMostDay end
        if (r.hit or 0) > m.hit then m.hit, m.hitWhat, m.hitTime = r.hit, r.hitWhat, r.hitTime end
        if (r.ran or 0) > m.ran then m.ran, m.ranZone, m.ranTime, m.runSecs = r.ran, r.ranZone, r.ranTime, r.runSecs end
        if r.avengedAt and r.avengedAt > (m.avengedAt or 0) then m.avengedId, m.avengedAt = r.avengedId, r.avengedAt end
        local fresh = {}
        for _, p in ipairs(F.PERIODS) do fresh[p] = r.sentAt and r.sentAt >= ns.PeriodStart(p) end
        for _, p in ipairs(F.PERIODS) do
            if fresh[p] then
                m.pDeaths[p] = (m.pDeaths[p] or 0) + (r.pDeaths[p] or 0)
                m.pDungeon[p] = (m.pDungeon[p] or 0) + (r.pDungeon and r.pDungeon[p] or 0)
                m.pBg[p] = (m.pBg[p] or 0) + (r.pBg and r.pBg[p] or 0)
                m.pLongest[p] = math.max(m.pLongest[p] or 0, r.pLongest[p] or 0)
            end
        end
        m.sentAt = math.max(m.sentAt or 0, r.sentAt or 0)
        for _, c in ipairs(r.chars) do
            local copy = {}
            for k, v in pairs(c) do copy[k] = v end
            for _, f in ipairs({ "pDeaths", "pLongest", "pBg", "pDungeon" }) do
                copy[f] = {}
                for _, p in ipairs(F.PERIODS) do copy[f][p] = fresh[p] and c[f] and c[f][p] or 0 end
            end
            m.chars[#m.chars + 1] = copy
        end
        for _, k in ipairs(r.killers) do killers[#killers + 1] = k end
        for _, k in ipairs(r.allKillers or {}) do all[#all + 1] = k end
        for _, z in ipairs(r.zones or {}) do zones[#zones + 1] = z end
        for _, e in ipairs(r.earlier or {}) do m.earlier[#m.earlier + 1] = renumbered(id, e) end
        for _, e in ipairs(r.records or {}) do m.records[#m.records + 1] = renumbered(id, e) end
        if r.last and (not m.last or r.last.time > m.last.time) then m.last, m.nem = renumbered(id, r.last), r.nem end
    end
    for _, p in ipairs(F.PERIODS) do
        m.pDeaths[p], m.pDungeon[p], m.pBg[p], m.pLongest[p] = m.pDeaths[p] or 0, m.pDungeon[p] or 0, m.pBg[p] or 0, m.pLongest[p] or 0
    end
    m.chars = byName(m.chars)
    table.sort(m.chars, function(a, b) return a.name < b.name end)
    m.killers = topBy(killers, function(k) return k.npc end, F.KILLERS)
    m.allKillers = topBy(all, function(k) return k.kind .. k.key end, F.ALL_KILLERS)
    m.zones = topBy(zones, function(z) return z.zone end, F.ZONES)
    return m
end

local merged = {}
function F.Record(id)
    local s, ids = store(), F.Ids(id)
    if #ids == 1 then return s.players[ids[1]] end
    local recs, key = {}, {}
    for i, x in ipairs(ids) do
        recs[i] = s.players[x]
        key[i] = x .. ":" .. recs[i].v .. ":" .. tostring(recs[i].log) .. ":" .. (recs[i].log and #recs[i].log or 0)
    end
    key = table.concat(key, ",")
    local c = merged[ids[1]]
    if not (c and c.key == key) then
        c = { key = key, rec = merge(ids, recs) }
        merged[ids[1]] = c
    end
    return c.rec
end

local function people()
    local out, seen = {}, {}
    for id in pairs(store().players) do
        if F.Shares(id) then
            local p = F.Primary(id)
            if not seen[p] then
                seen[p] = true
                out[#out + 1] = p
            end
        end
    end
    return out
end

function F.Rows(kind, period)
    local rows = {}
    local mine = F.Mine()
    rows[1] = { rec = mine, you = true }
    for _, id in ipairs(people()) do rows[#rows + 1] = { rec = F.Record(id), id = id } end
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

function F.Players()
    local out = {}
    for _, id in ipairs(people()) do out[#out + 1] = F.Record(id) end
    table.sort(out, function(a, b)
        if a.deaths ~= b.deaths then return a.deaths > b.deaths end
        return a.id < b.id
    end)
    return out
end

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
                F.AddEvent({ kind = "death", id = rec.id, last = renumbered(rec.id, e), time = e.time })
            end
        end
        local total = F.Record(rec.id).deaths
        local before = total - (rec.deaths - old.deaths)
        changes[#changes + 1] = { kind = "death", id = rec.id, last = renumbered(rec.id, rec.last), deaths = total, before = before,
            time = rec.last.time }
        local was = F.Char(old, rec.last.char)
        if rec.nem and (was and was.nemNpc or nil) ~= rec.nem.npc then
            changes[#changes + 1] = { kind = "nemesis", id = rec.id, nem = rec.nem, zone = rec.last.zone, time = rec.last.time }
        end
        local passed, me = nil, F.Primary(rec.id)
        for _, r in ipairs(F.Rows("deaths")) do
            if r.id ~= me and r.deaths < total and r.deaths >= before and (not passed or r.deaths > passed.deaths) then
                passed = r
            end
        end
        if passed then
            changes[#changes + 1] = { kind = "passed", id = rec.id, other = passed.you and "you" or passed.id, deaths = total,
                time = rec.last.time }
        end
    end
    for i = #changes, 1, -1 do F.AddEvent(changes[i]) end
    return changes
end

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

-- A death whose text doesn't change stays the same table, so an open death stays open.
local decoded = {}
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

function F.WantDeaths(id)
    local rec = store().players[id]
    if rec then rec.wantLog = true end
end

function F.WantsDeaths(id)
    local rec = store().players[id]
    return rec ~= nil and rec.wantLog == true
end

function F.SendsDeaths(person)
    for _, id in ipairs(F.Ids(person)) do
        local rec = store().players[id]
        if not rec or (rec.format or 1) < 7 then return false end
    end
    return true
end

local function asDeath(e)
    local hit, cause = e.hits and e.hits[1], F.Cause(e)
    return { killer = (cause == "mob" or cause == "player") and e.killer or nil, npc = e.npc, zone = e.zone, time = e.time, char = e.char, name = e.char or "?",
        level = e.level, number = e.number, spell = e.spell ~= "Melee" and e.spell or nil, cause = cause,
        amount = hit and hit.amount, hits = e.hits, maxHealth = e.maxHealth, killerLevel = e.killerLevel,
        killerRace = e.killerRace, killerClass = e.killerClass, killerRank = e.killerRank, joke = e.joke }
end

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
sourceLog = function(id)
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

-- A death that stays the same table stays open in the details panel.
local mergedLogs = {}
function F.Log(id)
    local ids = F.Ids(id)
    if #ids == 1 then return sourceLog(ids[1]) end
    local lists, key = {}, {}
    for i, x in ipairs(ids) do
        lists[i] = sourceLog(x)
        key[i] = tostring(lists[i]) .. ":" .. #lists[i] .. ":" .. store().players[x].v
    end
    key = table.concat(key, ",")
    local c = mergedLogs[ids[1]]
    if c and c.key == key then return c.list end
    local list, of = {}, {}
    for i, x in ipairs(ids) do
        for _, d in ipairs(lists[i]) do
            local copy = c and c.of[d] or renumbered(x, d)
            copy.number = F.PersonNumber(x, d.time, d.number)
            of[d] = copy
            list[#list + 1] = copy
        end
    end
    table.sort(list, function(a, b) return a.time < b.time end)
    mergedLogs[ids[1]] = { key = key, list = list, of = of }
    return list
end

function F.Find(id, e)
    for _, d in ipairs(F.Log(id)) do
        if d.time == e.time and d.name == e.char then return d end
    end
    return asDeath(e)
end

function F.Partial(id)
    local rec = F.Record(id)
    return rec ~= nil and not rec.logFull
end

function F.Names(names, many)
    if many and #names >= many then return ("%s and %d friends"):format(names[1], #names - 1) end
    return ns.UI.AndList(names)
end

function F.NamesOf(ids, many)
    local list = {}
    for _, id in ipairs(ids) do list[#list + 1] = F.Name(id) end
    return F.Names(list, many)
end

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

function F.KilledFriends(npc)
    local out = {}
    for _, r in ipairs(F.Players()) do
        for _, k in ipairs(r.killers) do
            if k.npc == npc then out[#out + 1] = { id = r.id, kills = k.kills } end
        end
    end
    table.sort(out, function(a, b) return a.kills > b.kills end)
    return out
end

function F.NemesisOf(npc)
    local out = {}
    for id, r in pairs(store().players) do
        local c = F.Shares(id) and F.Char(r, F.Known(id).char)
        if c and c.nemNpc == npc then out[#out + 1] = id end
    end
    return out
end

local function addMixed(chars, into)
    local seen = {}
    for _, c in pairs(chars) do if c.faction then seen[c.faction] = true end end
    if not (seen.Horde and seen.Alliance) then return end
    for _, c in pairs(chars) do if c.faction and c.name then into[c.name] = c.faction end end
end

local factionOf, builtAt = {}, nil
function ns.CharFaction(name)
    if builtAt ~= GetTime() then
        factionOf, builtAt = {}, GetTime()
        addMixed(ns.db.characters, factionOf)
        for _, rec in ipairs(F.Players()) do addMixed(rec.chars, factionOf) end
    end
    return factionOf[name]
end
