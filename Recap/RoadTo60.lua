-- Road to 60: one character's deaths on the way to 60 as recap slides, offered once when it gets
-- there (a chat line and the popup), and from Records with that character picked.
local _, ns = ...
local UI, H, R = ns.UI, ns.History, ns.Recap

local LEVEL = 60
local SAY_AFTER = 8
local FEW = 3
local MOST_ROWS = 5
local BRAWLER = 0.8
local TOTAL_DEATHS = 60
local TYPES = {
    mob = { "The Brawler", "%d%% of your deaths were to mobs.", "ability_dualwield" },
    player = { "The Hunted", "%d%% of your deaths were to players.", "ability_hunter_markedfordeath" },
    fall = { "The Faller", "%d%% of your deaths were gravity.", "spell_magic_featherfall" },
    drown = { "The Sinker", "%d%% of your deaths were in water.", H.ENV_ICONS.DROWNING },
    lava = { "The Lava Diver", "%d%% of your deaths were in lava.", "spell_shaman_lavaburst" },
    fire = { "The Kindling", "%d%% of your deaths were fire.", H.ENV_ICONS.FIRE },
    fatigue = { "The Explorer", "%d%% of your deaths were at the edge of the map.", H.ENV_ICONS.FATIGUE },
    slime = { "The Slimed", "%d%% of your deaths were slime.", H.ENV_ICONS.SLIME },
    other = { "The Mystery", "%d%% of your deaths were a mystery.", "inv_misc_questionmark" },
}

function R.ReachedAt(key)
    local c = ns.db.characters[key]
    return c and c.reached60
end

function R.RoadLabel() return "Play road to 60" end

function R.RoadFrom(key)
    local c = ns.db.characters[key]
    return c and c.roadFrom or 1
end

local function way(from) return from > 1 and ("from level %d to 60"):format(from) or "on the way to 60" end

local function percent(n, of) return math.floor(n * 100 / of + 0.5) end

local function deathType(m, f)
    local counts, order = ns.CauseCounts(f), {}
    for _, c in ipairs(ns.CAUSES) do
        if (counts[c[1]] or 0) > 0 then order[#order + 1] = { kind = c[1], label = c[2], n = counts[c[1]] } end
    end
    table.sort(order, function(a, b) return a.n > b.n end)
    local pick = order[1]
    if (counts.mob or 0) <= m.deaths * BRAWLER then
        for _, c in ipairs(order) do if c.kind ~= "mob" then pick = c break end end
    end
    return { kind = pick.kind, share = percent(pick.n, m.deaths), order = order }
end

local function friendRows(m)
    local rows, below = {}, 0
    for _, row in ipairs(ns.Friends.Rows("deaths")) do
        if not row.you then
            rows[#rows + 1] = { name = ns.HistoryShell.ColoredName(row.id), value = row.value }
            if row.value < m.deaths then below = below + 1 end
        end
    end
    if #rows == 0 then return nil end
    local you = { name = UI.Colored(m.name, m.color) .. UI.Colored(" (you)", UI.COLOR.faint), value = m.deaths, tint = true }
    rows[#rows + 1] = you
    table.sort(rows, function(a, b) return a.value > b.value end)
    local shown = {}
    for i = 1, math.min(MOST_ROWS, #rows) do shown[i] = rows[i] end
    local inside = false
    for _, r in ipairs(shown) do inside = inside or r == you end
    if not inside then shown[MOST_ROWS] = you end
    return { rows = shown, friends = #rows - 1, below = below }
end

-- at: the moment it counts to, now to test before 60.
function R.Road(key, at)
    local c = ns.db.characters[key]
    if not c then return nil end
    local f = { char = key, to = (at or c.reached60 or time()) + 1 }
    local deaths = ns.Deaths(f)
    local m = { key = key, name = c.name, color = R.ClassColor(key), deaths = #deaths, levels = {}, from = R.RoadFrom(key),
        during = "on the way to 60", nemesisLabel = "YOUR NEMESIS", characters = H.Characters(f), first = deaths[#deaths] }
    for level = 1, LEVEL do m.levels[level] = 0 end
    for _, d in ipairs(deaths) do
        local level = math.max(m.from, math.min(LEVEL, d.level or m.from))
        m.levels[level] = m.levels[level] + 1
        if not m.worstLevel or m.levels[level] > m.levels[m.worstLevel]
            or m.levels[level] == m.levels[m.worstLevel] and level < m.worstLevel then m.worstLevel = level end
    end
    R.Fill(m, f, deaths)
    m.ran = H.Totals(f).ran
    if m.deaths >= FEW then
        m.type = deathType(m, f)
        local top = m.zone and H.TopKillers(ns.Deaths({ char = key, to = f.to, zone = m.zone.name }), 1)[1]
        if top and top.kills >= 2 then m.zone.killer, m.zone.kills = UI.KillerName(top.name, top.cause), top.kills end
    else
        m.nemesis, m.zone = nil, nil
    end
    if m.deaths < 2 then m.life = nil end
    m.friends = friendRows(m)
    return m
end

local function where(d) return ("Level %d, %s."):format(d.level or 1, d.zone or "") end

-- "An Orc Rogue.", from what a player kill saved.
local function whoKilled(d)
    local who = d.killerRace and d.killerClass and (d.killerRace .. " " .. d.killerClass) or d.killerClass
    if not who then return "" end
    return (" %s %s."):format(who:find("^[AEIOU]") and "An" or "A", who)
end

local function countSlide(m)
    local n, values = m.levels[m.worstLevel], {}
    for level = m.from, LEVEL do values[#values + 1] = m.levels[level] end
    local s = { label = "THE COUNT", count = m.deaths, countWord = (m.deaths == 1 and "death " or "deaths ") .. way(m.from), secs = 5,
        bars = { values = values, pick = m.worstLevel - m.from + 1, left = "Level " .. m.from, right = tostring(LEVEL),
            mid = ("Level %d: %s"):format(m.worstLevel, UI.Count(n, "death", "deaths")) },
        roast = R.Roast("roadCount", { deaths = m.deaths, level = m.worstLevel, worst = n }) }
    if m.deaths == 1 then
        s.lines = { { text = ("Just one. %s, level %d, %s."):format(R.CausedBy(m.first), m.first.level or 1, m.first.zone or ""), color = UI.COLOR.text } }
    end
    return s
end

local function typeSlide(m)
    local t, rows = m.type, {}
    for i, c in ipairs(t.order) do
        if i <= 4 then rows[i] = { name = UI.Colored(c.label, UI.CauseColor(c.kind)), value = percent(c.n, m.deaths) .. "%", tint = c.kind == t.kind } end
    end
    return { label = "YOUR DEATH TYPE", title = TYPES[t.kind][1], titleSize = 40, top = true, secs = 5, icon = "Interface\\Icons\\" .. TYPES[t.kind][3],
        lines = { { text = TYPES[t.kind][2]:format(t.share) } }, rows = rows,
        roast = R.Roast("type", {}) }
end

local function zoneSlide(m)
    local z = m.zone
    local text = UI.Count(z.deaths, "death.", "deaths.")
    if z.killer then text = text .. (" %d of them to %s."):format(z.kills, z.killer) end
    return { label = "WHERE YOU DIED MOST", title = z.name, titleSize = 40, lines = { { text = text } },
        roast = R.Roast("zone", { zone = z.name }) }
end

local function deadSlide(m)
    local text = "as a ghost."
    if (m.ran or 0) > 0 then text = text .. (" You ran %s back to your body."):format(UI.Yards(m.ran)) end
    return { label = "TIME SPENT DEAD", title = UI.Duration(m.ghost), titleSize = 50, lines = { { text = text } },
        roast = R.Roast("dead", {}) }
end

local function friendsSlide(m)
    local fr = m.friends
    return { label = "AMONG YOUR FRIENDS", title = ("You died more than %d of your %s."):format(fr.below, UI.Count(fr.friends, "friend", "friends")),
        titleSize = 26, top = true, secs = 5, rows = fr.rows,
        roast = R.Roast("friends", { half = fr.below * 2 >= fr.friends }) }
end

local function roadSummary(m)
    return R.Summary(m, "ROAD TO 60", m.name, m.color, {
        R.NemesisEntry(m),
        { "Worst zone", m.zone and m.zone.name },
        { "Death type", m.type and TYPES[m.type.kind][1] },
        { "Longest life", m.life and UI.Duration(m.life.seconds) },
        { "Time dead", m.ghost > 0 and UI.Duration(m.ghost) or nil },
        { "Repair bills", m.repair > 0 and UI.Money(m.repair) or nil },
    })
end

function R.RoadSlides(key, at)
    local m = R.Road(key, at)
    if not m then return nil end
    local out = {}
    if m.deaths == 0 then
        out[1] = { label = "THE COUNT", title = "Not once.", titleSize = 50,
            lines = { { text = ("%s reached 60 without dying."):format(UI.Colored(m.name, m.color)) } }, roast = R.Roast("none", {}) }
        out[2] = roadSummary(m)
        return out
    end
    out[#out + 1] = { label = "LEVEL 60", title = ("%s's road to 60"):format(m.name), titleColor = m.color, titleSize = 40,
        lines = { { text = m.from > 1 and ("Every death since level %d. Here's how it went."):format(m.from)
            or "Every death on the way. Here's how it went." } }, roast = R.Roast("start", { deaths = m.deaths }) }
    out[#out + 1] = countSlide(m)
    local byPlayer = m.first.cause == "player"
    out[#out + 1] = { label = "YOUR FIRST DEATH", title = R.CausedBy(m.first), titleSize = 40,
        lines = { { text = where(m.first) .. (byPlayer and whoKilled(m.first) or "") } },
        npc = m.first.cause == "mob" and m.first.npc or nil,
        iconAtlas = byPlayer and m.first.killerClassFile and "classicon-" .. m.first.killerClassFile:lower() or nil,
        roast = R.Roast("first", { level = m.first.level or 1, killer = R.CausedBy(m.first) }) }
    if m.nemesis then out[#out + 1] = R.NemesisSlide(m) end
    if m.zone then out[#out + 1] = zoneSlide(m) end
    if m.type then out[#out + 1] = typeSlide(m) end
    if m.ghost > 0 then out[#out + 1] = deadSlide(m) end
    if m.repair > 0 then out[#out + 1] = R.CostSlide(m) end
    if m.life then out[#out + 1] = R.LifeSlide(m) end
    if m.friends then out[#out + 1] = friendsSlide(m) end
    out[#out + 1] = roadSummary(m)
    return out
end

-- A link or popup can outlive the character's saved data.
function R.PlayRoad(key, at)
    local slides = R.RoadSlides(key, at)
    if slides then return R.Show(slides) end
end

function R.RoadLine(key, at)
    local n = #ns.Deaths({ char = key, to = (at or R.ReachedAt(key) or time()) + 1 })
    local link = UI.ChatLink(R.RoadLabel(), "road", key)
    if n == 0 then return ("60 without a single death. %s"):format(link) end
    return ("%s %s. %s"):format(UI.Count(n, "death", "deaths"), way(R.RoadFrom(key)), link)
end

function R.OfferRoad(key, at)
    UI.Say(R.RoadLine(key, at))
    R.Alert("Road to 60 ready", R.RoadLabel(), function() R.PlayRoad(key, at) end)
end

UI.OnChatLink("road", function(key) R.PlayRoad(key) end)

-- Blizzard's count has every death; fewer saved means the addon came later, at its first saved death.
local function startLevel(key)
    local saved = ns.Deaths({ char = key })
    if #saved == 0 or #saved >= ns.Statistic(TOTAL_DEATHS) then return 1 end
    return saved[#saved].level or 1
end

local function arrive(key, at)
    local c = ns.db.characters[key]
    if not c or c.reached60 then return end
    c.reached60, c.roadFrom = at, startLevel(key)
    R.OfferRoad(key)
end

-- A 60 without one (from before this version): it ends at its first saved death at 60.
local function catchUp(key)
    local deaths, reached, before = ns.Deaths({ char = key }), time(), 0
    for i = #deaths, 1, -1 do
        if (deaths[i].level or 0) >= LEVEL then reached = deaths[i].time - 1 break end
        before = before + 1
    end
    if before > 0 then arrive(key, reached) end
end

ns.OnEvent("PLAYER_LEVEL_UP", function(level)
    local key, at = ns.CharacterKey(), time()
    if level == LEVEL and key then C_Timer.After(SAY_AFTER, function() arrive(key, at) end) end
end)

ns.OnEvent("PLAYER_ENTERING_WORLD", function()
    local key = ns.CharacterKey()
    local c = key and ns.db.characters[key]
    if c and c.level == LEVEL and not c.reached60 then C_Timer.After(SAY_AFTER, function() catchUp(key) end) end
end)
