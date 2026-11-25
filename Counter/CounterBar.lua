-- The counter as a bar at the top of the screen, a layout in place of the box: the count, the last
-- death and time played this life in a row, the nemesis in a tab hanging under it.
local _, ns = ...
local UI = ns.UI

local HEIGHT, TAB_HEIGHT, PAD, TAB_PAD = 56, 50, 18, 20
local SPLIT, LINE = 16, 28
local COUNT_GAP, LABEL_GAP = 8, 4
local LABEL = UI.LineHeight(10)
-- The longest mobs on Forever fit at full size in Cinzel 16: "Scorched Screeching Roguefeather" and
-- "Corrupted Bloodtalon Scythemaw". Longer names shrink.
local NAME_MAX = 330
-- The game sets Cinzel higher in its line than Inter (the box drops its 48 by 5).
local CINZEL_DROP = 0.1
-- How far above its box Cinzel 32's baseline sits. Cinzel's round digits (3, 5, 6, 9) dip about
-- 2 px below it, the flat ones (1, 2, 4, 7) sit on it: "deaths" lines up with the flat ones.
local CINZEL_BASE = 6

local frame, parts

-- A small label over its value ("PLAYED THIS LIFE", "23h 59m"); a name gets at most max, then a second line.
local function column(parent, font, size, max)
    local s = { label = UI.Text(parent, "body", 10, "faint"), value = UI.Text(parent, font, size, "text"), max = max }
    if max then
        s.value:SetWidth(max)
        s.value:SetWordWrap(true)
        s.value:SetMaxLines(2)
    end
    return s
end

-- How much taller than one line a column's value is: a name on two lines.
local function extra(s)
    if not (s.max and s.value:IsShown()) then return 0 end
    return math.max(0, math.ceil(s.value:GetStringHeight() - UI.LineHeight(s.value.style.size)))
end

local refresh, tick

local function createBar()
    local s = ns.db.settings
    frame = UI.Notch(TAB_HEIGHT)
    frame:SetSize(1, HEIGHT)
    frame:SetScale(s.barScale)
    UI.Movable(frame, s.barPosition, "TOP", 0, -6, { UIWidgetTopCenterContainerFrame, "BOTTOM" }, "centre")
    UI.ResizeGrip(frame, s, "barScale", 0.5, 2)
    ns.LayoutMenu(frame)
    parts = { number = UI.Text(frame, "number", 32, "text"), label = UI.Text(frame, "body", 14, "muted"),
        allTime = column(frame, "bold", 15), last = column(frame, "number", 16, NAME_MAX),
        alive = column(frame, "bold", 15), nemesis = column(frame.tab, "number", 16, NAME_MAX), dividers = {} }
    parts.last.ticks, parts.alive.ticks = true, true
    parts.alive.label:SetText(ns.ALIVE_LABEL:upper())
    parts.alive.spot = UI.TipSpot(frame, ns.ALIVE_LABEL, ns.AliveTip)
    parts.allTime.label:SetText(("All time"):upper())
    parts.texts = { parts.number, parts.label }
    for _, k in ipairs({ "allTime", "last", "alive", "nemesis" }) do
        table.insert(parts.texts, parts[k].label)
        table.insert(parts.texts, parts[k].value)
    end
    for i = 1, 3 do
        parts.dividers[i] = UI.Divider(frame, true)
        parts.dividers[i]:SetHeight(LINE)
    end
    C_Timer.NewTicker(1, function() tick() end)
    frame.parts = parts
    ns.bar = frame
end

local function width(text) return text:GetUnboundedStringWidth() end

-- Measured with every digit as 0, so a ticking time doesn't move the bar's edges each second.
local function steady(text)
    local shown = text:GetText()
    text:SetText((shown:gsub("%d", "0")))
    local w = width(text)
    text:SetText(shown)
    return w
end

local function put(parent, text, x, y)
    local s = text.style
    UI.Place(parent, text, x, math.floor(y + (s.font == "number" and s.size * CINZEL_DROP or 0) + 0.5))
end

-- The label centred over its value.
local function placeColumn(parent, s, x, height)
    local y = math.floor((height - LABEL - LABEL_GAP - UI.LineHeight(s.value.style.size) - extra(s)) / 2)
    local label, value = steady(s.label), s.max and math.min(width(s.value), s.max) or steady(s.value)
    if s.max then s.value:SetJustifyH(width(s.value) > s.max and "CENTER" or "LEFT") end
    -- Blizzard's formatter drops a zero unit ("16m" at 16m 0s): a ticking time never narrows its column.
    local column = math.max(label, value, s.ticks and s.widest or 0)
    if s.ticks then s.widest = column end
    put(parent, s.label, x + math.floor((column - label) / 2 + 0.5), y)
    put(parent, s.value, x + math.floor((column - value) / 2 + 0.5), y + LABEL + LABEL_GAP)
    if s.spot then
        UI.Place(parent, s.spot, x, 0)
        s.spot:SetSize(column, height)
    end
    return column
end

local function row(x, height)
    local p = parts
    put(frame, p.number, x, (height - UI.LineHeight(32)) / 2)
    p.label:ClearAllPoints()
    p.label:SetPoint("BOTTOMLEFT", p.number, "BOTTOMRIGHT", COUNT_GAP, CINZEL_BASE)
    x = x + width(p.number) + COUNT_GAP + width(p.label)
    local shown = 0
    for _, k in ipairs({ "allTime", "last", "alive" }) do
        if p[k].value:IsShown() then
            shown = shown + 1
            UI.Place(frame, p.dividers[shown], x + SPLIT, (height - LINE) / 2)
            p.dividers[shown]:Show()
            x = x + 2 * SPLIT + 1
            x = x + placeColumn(frame, p[k], x, height)
        end
    end
    for i = shown + 1, #p.dividers do p.dividers[i]:Hide() end
    return x
end

-- The tab needs room for its joins; a bar narrower than that widens, its row centred.
local function layout()
    local tab
    local height, tabHeight = HEIGHT + extra(parts.last), TAB_HEIGHT + (parts.hasNemesis and extra(parts.nemesis) or 0)
    frame:SetHeight(height)
    frame.tab:SetHeight(tabHeight)
    if parts.hasNemesis then tab = math.ceil(2 * TAB_PAD + placeColumn(frame.tab, parts.nemesis, TAB_PAD, tabHeight)) end
    local w = math.ceil(row(PAD, height) + PAD)
    local least = tab and tab + 2 * (UI.JOIN + 8) or 0
    if w < least then
        row(PAD + (least - w) / 2, height)
        w = least
    end
    if tab and (w - tab) % 2 == 1 then tab = tab + 1 end
    frame:SetWidth(w)
    UI.ShapeNotch(frame, tab)
end

local function times()
    parts.alive.value:SetText(UI.Duration(ns.AliveSeconds()))
    if parts.lastDeath then parts.last.label:SetText(("Last death, " .. UI.Since(parts.lastDeath.time)):upper()) end
end

local function showColumn(s, on)
    s.label:SetShown(on)
    s.value:SetShown(on)
end

function refresh()
    if not frame then createBar() end
    local on = ns.CounterShows("bar")
    frame:SetShown(on)
    if not on then return end
    local s = ns.db.settings
    local bare = not s.counterPanel
    if frame.bare ~= bare then
        frame.bare = bare
        UI.Bare(frame, parts.texts, bare)
    end

    local counting = ns.Counting()
    local count = ns.CountedDeaths()
    parts.number:SetText(count)
    parts.label:SetText(UI.Plural(count, "death", "deaths"))
    local allTime = s.streamerbot and s.counterAllTime
    showColumn(parts.allTime, allTime)
    if allTime then parts.allTime.value:SetText(BreakUpLargeNumbers(ns.AllTimeCount())) end

    local last = ns.Deaths(counting, 1)[1]
    if last ~= parts.lastDeath then
        parts.last.widest, parts.alive.widest = nil, nil
    end
    parts.lastDeath = last
    showColumn(parts.last, last ~= nil)
    if last then
        parts.last.value:SetText(ns.DeathTitle(last))
        UI.Tint(parts.last.value, UI.CauseColor(last.cause))
    end

    local _, name, kills = ns.CharacterNemesis()
    parts.hasNemesis = name ~= nil
    if name then
        parts.nemesis.label:SetText(("Nemesis, " .. UI.Count(kills, "kill", "kills")):upper())
        parts.nemesis.value:SetText(name)
        UI.Tint(parts.nemesis.value, UI.CauseColor("mob"))
    end
    times()
    layout()
end

-- Each second only the times change.
function tick()
    local stale, on = ns.CounterStale(frame, "bar")
    if stale then return refresh() end
    if not on then return end
    times()
    layout()
end

ns.OnChange(refresh)
