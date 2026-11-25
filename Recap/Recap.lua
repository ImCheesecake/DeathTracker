-- The monthly recap: last month on all your characters as short slides, offered
-- once by a chat line at the first login after the month ends, and from Records.
local addonName, ns = ...
local UI, H = ns.UI, ns.History
local R = {}
ns.Recap = R

local SAY_AFTER = 8
local MOST_ROWS = 5
local HIDE_AFTER = 3 * 86400
local MUSIC_SECONDS = 41.3
-- Riding at 40 with a basic mount included; riding at 60 plus a swift mount (docs/research/vendor-prices-2026-11-17.md).
local FIRST_MOUNT, EPIC_MOUNT = 100 * 10000, 1200 * 10000

local function recapStore()
    ns.db.recap = ns.db.recap or {}
    ns.db.recap.played = ns.db.recap.played or {}
    return ns.db.recap
end

-- A month's key, "2026-12".
function R.Key(t) return date("%Y-%m", t) end

function R.Bounds(key)
    local y, m = key:match("^(%d+)-(%d+)$")
    y, m = tonumber(y) or 0, tonumber(m) or 1
    return time({ year = y, month = m, day = 1, hour = 0 }),
        time({ year = m == 12 and y + 1 or y, month = m % 12 + 1, day = 1, hour = 0 })
end

function R.Before(key) return R.Key(R.Bounds(key) - 1) end

function R.Name(key) return date("%B", (R.Bounds(key))) end

function R.Played(key)
    local from, to = R.Bounds(key)
    return recapStore().played[key] or #ns.Deaths({ from = from, to = to }, 1) > 0
end

-- The last month that's over, if you played in it.
function R.Last()
    local key = R.Before(R.Key(time()))
    return R.Played(key) and key or nil
end

local function worstDay(m, deaths)
    local byDay = {}
    for _, d in ipairs(deaths) do
        local day = tonumber(date("%d", d.time))
        m.days[day] = m.days[day] + 1
        byDay[day] = byDay[day] or {}
        table.insert(byDay[day], d)
    end
    for day = 1, #m.days do
        local list = byDay[day]
        if list and #list >= 2 and (not m.worst or #list > #m.worst.deaths) then m.worst = { day = day, deaths = list } end
    end
    local w = m.worst
    if not w then return end
    w.time, w.span = w.deaths[#w.deaths].time, w.deaths[1].time - w.deaths[#w.deaths].time
    w.zone, w.zoneDeaths = H.Most(w.deaths, function(d) return d.zone end)
    local killer = H.TopKillers(w.deaths, 1)[1]
    if killer and killer.kills >= 2 then w.killer, w.killerKills = UI.KillerName(killer.name, killer.cause), killer.kills end
end

-- Everything the slides say about one month.
function R.Month(key)
    local from, to = R.Bounds(key)
    local f = { from = from, to = to }
    local deaths = ns.Deaths(f)
    local m = { key = key, name = R.Name(key), year = date("%Y", from), deaths = #deaths, days = {}, from = from,
        during = "in " .. R.Name(key), nemesisLabel = "NEMESIS OF THE MONTH" }
    for day = 1, tonumber(date("%d", to - 1)) do m.days[day] = 0 end
    worstDay(m, deaths)
    m.characters = H.Characters(f)
    local before = R.Before(key)
    if R.Played(before) then
        local bFrom, bTo = R.Bounds(before)
        m.before = { name = R.Name(before), deaths = #ns.Deaths({ from = bFrom, to = bTo }) }
    elseif #ns.Deaths({ to = from }, 1) == 0 then
        m.first = true
    end
    return R.Fill(m, f, deaths)
end

-- What any recap says over these deaths: the nemesis, the worst zone, time dead, the repair bills and
-- the longest life. m.characters must be set.
function R.Fill(m, f, deaths)
    local mob = H.Mobs(f)[1]
    if mob and mob.kills >= 2 then
        local victim, onIt = H.Most(mob.deaths, function(d) return d.char end)
        m.nemesis = { npc = mob.npc, name = mob.name, kills = mob.kills, zone = mob.zone,
            victim = onIt == mob.kills and #m.characters > 1 and victim or nil }
    end
    local zone = H.Zones(f)[1]
    if zone then m.zone = { name = zone.zone, deaths = zone.deaths } end
    local totals = H.Totals(f)
    m.ghost, m.repair, m.bills = totals.ghost, totals.repair, 0
    for _, d in ipairs(deaths) do
        if (d.repair or 0) > 0 then
            m.bills = m.bills + 1
            if not m.bill or d.repair > m.bill.repair then m.bill = d end
        end
    end
    local life = H.Records(f).longestLife
    if life then
        local d = life.death
        local previous = ns.Deaths({ char = d.char, to = d.time }, 1)[1]
        m.life = { seconds = life.value, death = d, from = previous and previous.level, to = d.level }
    end
    return m
end

function R.ClassColor(key)
    local c = ns.db.characters[key]
    return c and UI.ClassColor(c.class) or UI.COLOR.text
end

local function compareLine(m)
    if m.first then return "Your first month with Death Tracker." end
    if not m.before then return nil end
    local diff = m.deaths - m.before.deaths
    if diff == 0 then return ("As many as %s."):format(m.before.name) end
    return ("%d %s than %s."):format(math.abs(diff), diff < 0 and "fewer" or "more", m.before.name)
end

local function compareShort(m)
    if not m.before then return nil end
    local diff = m.deaths - m.before.deaths
    if diff == 0 then return "As many" end
    return ("%d %s"):format(math.abs(diff), diff < 0 and "fewer" or "more")
end

local function dayName(t) return (date("%A %d %B", t):gsub(" 0", " ")) end
local function shortDay(t) return date("%A ", t) .. UI.Ordinal(tonumber(date("%d", t))) end

local function spanText(seconds)
    if seconds < 3600 then return "within an hour" end
    local hours = math.floor(seconds / 3600 + 0.5)
    return ("in %d %s"):format(hours, UI.Plural(hours, "hour", "hours"))
end

local function worstSlide(m)
    local w = m.worst
    local where = w.zoneDeaths == #w.deaths and (", all in %s"):format(w.zone)
        or w.zoneDeaths * 2 > #w.deaths and (", most in %s"):format(w.zone) or ""
    local text = ("%d deaths %s%s."):format(#w.deaths, spanText(w.span), where)
    if w.killer then text = text .. ("\n%s took %d of them."):format(w.killer, w.killerKills) end
    return { label = "YOUR WORST DAY", title = dayName(w.time), titleSize = 36, lines = { { text = text } },
        roast = R.Roast("worst", { deaths = #w.deaths }) }
end

local function charactersSlide(m)
    local top = m.characters[1]
    local rows, rest, restDeaths = {}, 0, 0
    for k, c in ipairs(m.characters) do
        if k <= MOST_ROWS then
            local name = UI.Colored(c.name, R.ClassColor(c.key)) .. (c.level and UI.Colored(" level " .. c.level, UI.COLOR.faint) or "")
            rows[k] = { name = name, value = c.deaths, tint = k == 1 }
        else
            rest, restDeaths = rest + 1, restDeaths + c.deaths
        end
    end
    return { label = "WHO DIED MOST", title = top.name, titleColor = R.ClassColor(top.key), titleSize = 36, top = true, secs = 5,
        lines = { { text = ("%d of the %d."):format(top.deaths, m.deaths) } }, rows = rows,
        more = rest > 0 and ("%s, %s"):format(UI.Count(rest, "more character", "more characters"), UI.Count(restDeaths, "death", "deaths")) or nil,
        roast = R.Roast("most", { name = UI.Colored(top.name:match("^%S+"), R.ClassColor(top.key)), full = UI.Colored(top.name, R.ClassColor(top.key)),
            deaths = top.deaths, half = top.deaths * 2 >= m.deaths }) }
end

function R.CausedBy(d)
    return UI.KillerName(d.cause == "mob" and d.npc and ns.db.npcNames[d.npc] or ns.DeathTitle(d), d.cause)
end

function R.LifeSlide(m)
    local l, d = m.life, m.life.death
    local levels = l.from and l.to and l.from < l.to and ("Level %d to %d without dying once."):format(l.from, l.to)
        or ("Level %d, without dying once."):format(l.to or 1)
    return { label = "YOUR LONGEST LIFE", title = UI.Duration(l.seconds), titleSize = 50, lines = {
        { text = levels .. ("\nEnded by %s in %s."):format(R.CausedBy(d), d.zone or "") } }, roast = R.Roast("life", { seconds = l.seconds }) }
end

function R.MountLine(copper)
    local price, mount = FIRST_MOUNT, "a first mount"
    if copper >= FIRST_MOUNT then price, mount = EPIC_MOUNT, "an epic mount" end
    local share = math.floor(copper * 100 / price)
    if share < 1 then return "Not even 1% of a first mount." end
    return ("That's %d%% of %s."):format(share, mount)
end

function R.CostSlide(m)
    local lines = { { text = ("spent on repairs %s."):format(m.during) } }
    if m.bills > 1 then
        lines[2] = { text = ("The worst bill: %s, to %s."):format(UI.Money(m.bill.repair), R.CausedBy(m.bill)) }
    end
    return { label = "THE COST", title = UI.Money(m.repair), titleSize = 50, lines = lines, roast = R.MountLine(m.repair) }
end

function R.NemesisSlide(m)
    local n, victim = m.nemesis, nil
    for _, c in ipairs(m.characters) do
        if c.key == n.victim then victim = UI.Colored(c.name, R.ClassColor(c.key)) end
    end
    return { npc = n.npc, label = m.nemesisLabel, title = n.name, titleColor = UI.CauseColor("mob"), titleSize = 40, secs = 5,
        lines = { { text = ("Killed %s %s.\n%s."):format(victim or "you", UI.Times(n.kills), n.zone or "") } },
        roast = R.Roast("nemesis", { killer = UI.MobName(n.name), kills = n.kills }) }
end

-- The last slide, made to screenshot: the count in the corner and each { label, value } that has a value.
function R.Summary(m, label, title, titleColor, entries)
    local grid = {}
    for _, e in ipairs(entries) do if e[2] then grid[#grid + 1] = { label = e[1], value = e[2] } end end
    return { label = label, title = title, titleColor = titleColor, titleSize = 30, top = true, secs = 7,
        corner = { count = m.deaths, word = UI.Plural(m.deaths, "death", "deaths") }, grid = #grid > 0 and grid or nil }
end

function R.NemesisEntry(m) return { "Nemesis", m.nemesis and ("%s, %d"):format(UI.MobName(m.nemesis.name), m.nemesis.kills) } end

local function summarySlide(m, title, one)
    local top = m.characters[1]
    local died = one and m.life and { "Longest life", UI.Duration(m.life.seconds) }
        or { "Died most", top and ("%s, %d"):format(UI.Colored(top.name, R.ClassColor(top.key)), top.deaths) }
    return R.Summary(m, m.label, title, one and R.ClassColor(top.key) or nil, {
        { "Since " .. (m.before and m.before.name or ""), compareShort(m) },
        { "Worst day", m.worst and ("%s, %d deaths"):format(shortDay(m.worst.time), #m.worst.deaths) },
        died,
        R.NemesisEntry(m),
        { "Worst zone", m.zone and ("%s, %d"):format(m.zone.name, m.zone.deaths) },
        { "Time dead", m.ghost > 0 and UI.Duration(m.ghost) or nil },
        { "Repair bills", m.repair > 0 and UI.Money(m.repair) or nil },
    })
end

function R.Slides(key)
    local m = R.Month(key)
    m.label = (m.name .. " " .. m.year):upper()
    local out = {}
    if m.deaths == 0 then
        local n = 0
        for _ in pairs(ns.db.characters) do n = n + 1 end
        local any = n > 1 and (", on any of your %d characters"):format(n) or ""
        out[1] = { label = "THE COUNT", title = "Not once.", titleSize = 50, lines = { { text = ("No deaths in %s%s."):format(m.name, any) } },
            roast = R.Roast("none", {}) }
        out[2] = summarySlide(m, "Your " .. m.name)
        return out
    end
    local one = #m.characters == 1 and m.characters[1]
    local title = one and ("%s's %s"):format(one.name, m.name) or "Your " .. m.name
    out[#out + 1] = { label = m.label, title = title, titleColor = one and R.ClassColor(one.key) or nil, titleSize = one and 40 or 46,
        lines = { { text = one and "Every death this month. Here's how it went."
            or ("Every death on your %d characters. Here's how it went."):format(#m.characters) } },
        roast = R.Roast("start", { deaths = m.deaths }) }
    local compare = compareLine(m)
    out[#out + 1] = { label = "THE COUNT", count = m.deaths, countWord = UI.Plural(m.deaths, "death", "deaths") .. " in " .. m.name, secs = 5,
        lines = compare and { { text = compare, color = UI.COLOR.text } } or nil,
        roast = R.Roast("count", { diff = m.before and m.deaths - m.before.deaths, first = m.first }),
        bars = { values = m.days, pick = m.worst and m.worst.day, left = "1 " .. date("%b", m.from), right = tostring(#m.days),
            mid = m.worst and shortDay(m.worst.time) or nil } }
    if m.worst then out[#out + 1] = worstSlide(m) end
    if not one then
        out[#out + 1] = charactersSlide(m)
    elseif m.life then
        out[#out + 1] = R.LifeSlide(m)
    end
    if m.nemesis then out[#out + 1] = R.NemesisSlide(m) end
    if m.repair > 0 then out[#out + 1] = R.CostSlide(m) end
    out[#out + 1] = summarySlide(m, title, one)
    return out
end

local show, play
function R.PlayLabel(key) return ("Play %s recap"):format(R.Name(key)) end

-- Records offers the last month that's over until a few days after it was played.
function R.Offer()
    local key = R.Last()
    local played = key and recapStore().watched and recapStore().watched[key]
    if played and time() - played >= HIDE_AFTER then return nil end
    return key
end

-- PlayMusic repeats a file after a pause; the song plays once, then the zone's music comes back.
local tune = 0
local function stopMusic()
    tune = tune + 1
    StopMusic()
end

local function playMusic()
    stopMusic()
    local mine = tune
    PlayMusic(UI.RECAP_MUSIC)
    C_Timer.After(MUSIC_SECONDS, function() if tune == mine then stopMusic() end end)
end

function R.Show(slides)
    if not play then
        show, play = UI.SlideShow(addonName .. "Recap", recapStore())
        show:HookScript("OnHide", stopMusic)
    end
    if ns.db.settings.recapMusic then playMusic() end
    play(slides)
    return show
end

function R.Play(key)
    local db = recapStore()
    db.watched = db.watched or {}
    db.watched[key] = db.watched[key] or time()
    return R.Show(R.Slides(key))
end

function R.ChatLine(key)
    local from, to = R.Bounds(key)
    local n, name = #ns.Deaths({ from = from, to = to }), R.Name(key)
    local link = UI.ChatLink(R.PlayLabel(key), "recap", key)
    if n == 0 then return ("No deaths in %s. %s"):format(name, link) end
    return ("%s in %s. %s"):format(UI.Count(n, "death", "deaths"), name, link)
end

UI.OnChatLink("recap", function(key) R.Play(key) end)

ns.OnEvent("PLAYER_ENTERING_WORLD", function()
    local db = recapStore()
    local now = R.Key(time())
    db.played[now] = true
    local last = R.Before(now)
    if db.offered == last then return end
    db.offered = last
    if not R.Played(last) then return end
    C_Timer.After(SAY_AFTER, function()
        UI.Say(R.ChatLine(last))
        R.Toast(last)
    end)
end)
