local _, ns = ...
local UI = ns.UI

local WIDTH, PAD_X, PAD_Y, GAP = 300, 20, 18, 12
local INNER = WIDTH - 2 * PAD_X
local SIZE, SMALL, NUMBER_SIZE = 14, 12, 48
local LINE, LINE_GAP = UI.LineHeight(SIZE), 4
local NAME_GAP = 3
local SPLIT_GAP = 14
local BARE_GAP = 4
local HALF = (INNER - 2 * SPLIT_GAP - 1) / 2

local CAUSES = ns.CAUSES

local frame, parts

function ns.CountLabel(n, counting)
    return UI.Plural(n, "death", "deaths") .. (counting.stream and " this stream" or "")
end

function ns.CounterShows(layout)
    local s = ns.db.settings
    return s.counter and s.counterLayout == layout
end

ns.LAYOUTS = {
    { value = "bar", text = "Bar", tooltip = "The count, the last death and time played this life in one row. The nemesis hangs below it." },
    { value = "box", text = "Box", tooltip = "Every count: deaths by cause, the last two deaths, time played this life and the nemesis." },
}

function ns.AliveTip()
    if ns.Deaths({ char = ns.CharacterKey() }, 1)[1] then
        return "Time played since your last death. The clock stops while you're logged out."
    end
    return "Time played since Death Tracker started counting. The clock stops while you're logged out."
end

function ns.SetLayout(layout)
    ns.db.settings.counterLayout = layout
    ns.Changed()
end

local function isLayout(layout) return ns.db.settings.counterLayout == layout end

function ns.LayoutMenu(f)
    UI.RightClickMenu(f, function(root)
        root:CreateTitle("Layout")
        for _, l in ipairs(ns.LAYOUTS) do
            UI.MenuTooltip(root:CreateRadio(l.text, isLayout, ns.SetLayout, l.value), l.text, l.tooltip)
        end
        root:CreateDivider()
        local show = root:CreateButton("Show wanted poster", function() ns.ShowWantedPoster() end)
        if ns.CanShowWantedPoster() then
            UI.MenuTooltip(show, "Show wanted poster", "Your nemesis's poster, kept on screen until you close it.")
        else
            show:SetEnabled(false)
            UI.MenuTooltip(show, "Show wanted poster", "No nemesis yet: a mob needs 3 kills on this character.")
        end
        root:CreateButton("Open settings", function() ns.OpenOptions() end)
    end)
end

function ns.CounterStale(frame, layout)
    local on = ns.CounterShows(layout)
    return frame:IsShown() ~= on or (on and frame.bare == ns.db.settings.counterPanel), on
end

local function half(title, dim)
    local h = UI.Box(frame, HALF)
    h.label = UI.Text(h, "body", SMALL, "faint")
    h.label:SetPoint("TOPLEFT")
    h.label:SetText(title)
    h.name = UI.Text(h, "number", 16, "text")
    h.name:SetPoint("TOPLEFT", h.label, "BOTTOMLEFT", 0, -NAME_GAP)
    h.name:SetWidth(HALF)
    h.name:SetWordWrap(true)
    UI.Fit(h.name, 2, 0.75, 3)
    h.ago = UI.Text(h, "body", SMALL, "muted")
    h.ago:SetPoint("TOPLEFT", h.name, "BOTTOMLEFT", 0, -NAME_GAP)
    if dim then h:SetAlpha(0.72) end
    return h
end

local refresh, tick

local function create()
    frame = UI.Panel(WIDTH)
    frame:SetScale(ns.db.settings.counterScale)
    UI.Movable(frame, ns.db.settings.counterPosition, "TOPRIGHT", -24, -24)
    UI.ResizeGrip(frame, ns.db.settings, "counterScale", 0.5, 2)
    ns.LayoutMenu(frame)
    parts = { number = UI.Text(frame, "number", NUMBER_SIZE, "text"), label = UI.Text(frame, "body", 15, "muted"),
        causes = {}, divider = UI.Divider(frame), line = UI.Divider(frame, true) }
    -- The game sets Cinzel higher in its line than other text.
    parts.number:SetPoint("TOPLEFT", PAD_X, -PAD_Y - 5)
    parts.label:SetPoint("BOTTOMLEFT", parts.number, "BOTTOMRIGHT", 10, 11)
    for i = 1, #CAUSES do parts.causes[i] = UI.Pair(frame, SIZE, (INNER - GAP) / 2) end
    parts.halves = { half("Last death"), half("Before that", true) }
    parts.alive, parts.nemesis = UI.Pair(frame, SIZE, INNER), UI.WrapPair(frame, SIZE, INNER, "number")
    parts.aliveSpot = UI.TipSpot(parts.alive, ns.ALIVE_LABEL, ns.AliveTip)
    parts.aliveSpot:SetAllPoints()
    parts.texts = { parts.number, parts.label }
    for _, row in ipairs(parts.causes) do table.insert(parts.texts, row.label); table.insert(parts.texts, row.value) end
    for _, h in ipairs(parts.halves) do
        for _, t in ipairs({ h.label, h.name, h.ago }) do table.insert(parts.texts, t) end
    end
    for _, t in ipairs({ parts.alive.label, parts.alive.value, parts.alive.tail, parts.nemesis.label,
        parts.nemesis.value, parts.nemesis.rest }) do
        table.insert(parts.texts, t)
    end
    C_Timer.NewTicker(1, function() tick() end)
    frame.parts = parts
    ns.counter = frame
end

function refresh()
    if not frame then create() end
    local on = ns.CounterShows("box")
    frame:SetShown(on)
    if not on then return end
    local bare = not ns.db.settings.counterPanel
    if frame.bare ~= bare then
        frame.bare = bare
        UI.Bare(frame, parts.texts, bare)
    end

    local counting = ns.Counting()
    local byCause, count = ns.CauseCounts(counting), 0
    for _, n in pairs(byCause) do count = count + n end
    parts.number:SetText(count)
    parts.label:SetText(ns.CountLabel(count, counting))
    local y = PAD_Y + NUMBER_SIZE + GAP
    local shown = 0
    for i, c in ipairs(CAUSES) do
        local n, row = byCause[c[1]], parts.causes[i]
        row:SetShown(n ~= nil)
        if n then
            row:Set(c[2], n)
            UI.Place(frame, row, PAD_X + shown % 2 * (INNER + GAP) / 2, y + math.floor(shown / 2) * (LINE + LINE_GAP))
            shown = shown + 1
        end
    end
    if shown > 0 then y = y + math.ceil(shown / 2) * (LINE + LINE_GAP) - LINE_GAP + GAP end

    local recent, tallest = ns.Deaths(counting, 2), 0
    parts.recent = recent
    local scale = 1
    for i, h in ipairs(parts.halves) do
        local d = recent[i]
        h:SetShown(d ~= nil)
        if d then
            h.name:SetText(ns.DeathTitle(d))
            UI.Tint(h.name, UI.CauseColor(d.cause))
            h.ago:SetText(UI.Since(d.time))
            scale = math.min(scale, h.name:GetTextScale())
        end
    end
    for i, h in ipairs(parts.halves) do
        if recent[i] then
            h.name:SetTextScale(scale)
            local small = UI.LineHeight(SMALL)
            local height = small + NAME_GAP + h.name:GetStringHeight() + NAME_GAP + small
            h:SetHeight(height)
            tallest = math.max(tallest, height)
        end
    end
    parts.divider:SetShown(#recent > 0 and not bare)
    parts.line:SetShown(#recent > 1 and not bare)
    if #recent > 0 then
        UI.PlaceAcross(frame, parts.divider, PAD_X, y)
        y = y + (bare and BARE_GAP or 1 + GAP)
        UI.Place(frame, parts.halves[1], PAD_X, y)
        UI.Place(frame, parts.halves[2], PAD_X + HALF + 2 * SPLIT_GAP + 1, y)
        UI.Place(frame, parts.line, PAD_X + HALF + SPLIT_GAP, y)
        parts.line:SetHeight(tallest)
        y = y + tallest + GAP
    end

    parts.alive:Set(ns.ALIVE_LABEL, UI.Duration(ns.AliveSeconds()))
    UI.Place(frame, parts.alive, PAD_X, y)
    y = y + LINE
    local _, name = ns.CharacterNemesis()
    parts.nemesis:SetShown(name ~= nil)
    if name then
        parts.nemesis:Set("Nemesis", name)
        UI.Tint(parts.nemesis.value, UI.CauseColor("mob"))
        UI.Tint(parts.nemesis.rest, UI.CauseColor("mob"))
        UI.Place(frame, parts.nemesis, PAD_X, y + LINE_GAP)
        y = y + LINE_GAP + parts.nemesis:GetHeight()
    end
    frame:SetHeight(y + PAD_Y)
end

function tick()
    local stale, on = ns.CounterStale(frame, "box")
    if stale then return refresh() end
    if not on then return end
    parts.alive:Set(ns.ALIVE_LABEL, UI.Duration(ns.AliveSeconds()))
    for i, d in ipairs(parts.recent) do parts.halves[i].ago:SetText(UI.Since(d.time)) end
end

ns.OnChange(refresh)
