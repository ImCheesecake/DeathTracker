local _, ns = ...
local UI, T = ns.UI, ns.Trophies
local Shell = ns.HistoryShell

local CUP = "Interface\\Icons\\INV_Misc_Trophy_Argent"
local SUMMARY_CARDS = 2
local ALMOST_CARDS = 3
local CARD_GAP = 6
local P = { group = "summary" }
local page

local function steps(def) return T.Earned(def.id) end
local function complete(def) return #steps(def) >= #def.at end

local function stepDeath(step)
    if not step.death then return nil end
    for _, d in ipairs(ns.Deaths({ char = step.char })) do
        if d.time == step.death then return d end
    end
end

local function charName(key)
    local c = ns.db.characters[key]
    return c and UI.CharName(c.name) or key
end

local function mobName(npc)
    local d = ns.Deaths({ npc = npc }, 1)[1]
    return ns.db.npcNames[npc] or (d and d.killer) or "?"
end

local function cellsOf(def)
    local out = {}
    if def.parts then
        local seen = T.Progress(def.id).seen
        for _, p in ipairs(def.parts) do out[#out + 1] = { T.PartText(p), seen[p[1]] ~= nil } end
    elseif #def.at > 1 then
        local earned = steps(def)
        for t in ipairs(def.at) do out[#out + 1] = { T.StepText(def, t), earned[t] ~= nil } end
    end
    return out
end

local function tierOf(item)
    if item.tier then return item.tier, true end
    local got = #steps(item.def)
    if complete(item.def) then return got, true end
    return got + 1, false
end

local function progressOf(def, goal)
    local n = T.Progress(def.id).n
    if goal <= 1 or n <= 0 then return nil end
    return { math.min(n, goal), goal, def.show and def.show(n, goal) or nil }
end

local function focusOf(def, tier)
    local step = steps(def)[tier]
    if not step then return nil end
    local d = stepDeath(step)
    if d then return { death = d, text = "the death " .. UI.At(d.time) }, "Show that death." end
    if step.npc then
        local name = mobName(step.npc)
        return { npc = step.npc, text = "deaths to " .. name }, ("Show every death to %s."):format(name)
    end
end

local function fillCard(row, item)
    local def = item.def
    local tier, earned = tierOf(item)
    local goal = def.at[tier]
    item.cells = cellsOf(def)
    item.focus, item.help = nil, nil
    if earned and #item.cells == 0 then item.focus, item.help = focusOf(def, tier) end
    row.card:Set({ earned = earned, name = T.Name(def, tier), line = def.line(goal), icon = T.Icon(def), points = T.Points(def, tier),
        date = earned and UI.Moment(steps(def)[tier].time) or nil, progress = not earned and progressOf(def, goal) or nil,
        open = P.open == def.id, cells = item.cells })
end

local function buildCard(row)
    UI.TrophyCard(row)
    row:SetScript("OnClick", function(self)
        local item = self.item
        if #item.cells > 0 then
            P.open = P.open ~= item.def.id and item.def.id or nil
            return Shell.Refresh()
        end
        if item.focus then Shell.Focus(item.focus) end
    end)
end

local function cardTip(row, item)
    local def = item.def
    local tier, earned = tierOf(item)
    local lines = { def.line(def.at[tier]) }
    local step = earned and steps(def)[tier]
    if step then
        lines[#lines + 1] = UI.TipPair("Earned by", ("%s, %s"):format(charName(step.char), UI.At(step.time)))
        local d = stepDeath(step)
        if d then
            lines[#lines + 1] = UI.TipPair("Death", UI.Join(ns.DeathTitle(d), d.zone))
        elseif step.npc then
            lines[#lines + 1] = UI.TipPair("Bounty", mobName(step.npc))
        end
    end
    UI.Tooltip(row, T.Name(def, tier), earned and UI.COLOR.trophy or UI.COLOR.white, lines, item.help, ns.historyWindow)
end

local function cardHeight(item)
    if P.open == item.def.id then return UI.CardHeight(#cellsOf(item.def)) + CARD_GAP end
    return UI.CARD + CARD_GAP
end

local TEXT_HEIGHT = { heading = 30, hidden = 24 }
local function buildText(row)
    row.title = UI.GameText(row, "normal", "text")
    row.title:SetPoint("TOPLEFT", 8, -8)
    row.line = UI.Divider(row)
    row.line:SetPoint("BOTTOMLEFT", 8, 3)
    row.line:SetPoint("BOTTOMRIGHT", -8, 3)
end

local function fillText(row, item)
    row.title:SetText(item.style == "bar" and "" or item.title)
    UI.Tint(row.title, item.style == "hidden" and UI.COLOR.faint or UI.COLOR.text)
    row.line:SetShown(item.style == "heading")
end

local function buildTrophies(content)
    page = { content = content }
    page.list = UI.List(content, {
        card = { template = "Button", extent = cardHeight, build = buildCard, fill = fillCard, tip = cardTip },
        text = { template = "Frame", extent = function(item) return TEXT_HEIGHT[item.style] end, build = buildText, fill = fillText } })
    page.list.box:SetPoint("TOPLEFT", 12, -10)
    page.list.box:SetPoint("BOTTOMRIGHT", -24, 10)
    return page
end

local function summaryItems()
    local recent, items = {}, { { kind = "text", style = "heading", title = "Earned lately" } }
    for _, def in ipairs(T.defs) do
        if T.Shown(def) then
            for t, step in ipairs(steps(def)) do recent[#recent + 1] = { def = def, tier = t, time = step.time } end
        end
    end
    table.sort(recent, function(a, b) return a.time > b.time end)
    if #recent == 0 then items[#items + 1] = { kind = "text", style = "hidden", title = "Your first death earns First of Many." } end
    for i = 1, math.min(SUMMARY_CARDS, #recent) do items[#items + 1] = { kind = "card", def = recent[i].def, tier = recent[i].tier } end
    local close = {}
    for i, def in ipairs(T.defs) do
        if T.Shown(def) and not complete(def) then
            local share = T.Progress(def.id).n / def.at[#steps(def) + 1]
            if share > 0 then close[#close + 1] = { def = def, share = math.min(share, 1), order = i } end
        end
    end
    table.sort(close, function(a, b)
        if a.share ~= b.share then return a.share > b.share end
        return a.order < b.order
    end)
    if #close > 0 then items[#items + 1] = { kind = "text", style = "heading", title = "Almost there" } end
    for i = 1, math.min(ALMOST_CARDS, #close) do items[#items + 1] = { kind = "card", def = close[i].def } end
    return items
end

local function cardsOf(items, group, sub)
    local earned, todo, hidden = {}, {}, 0
    for i, def in ipairs(T.defs) do
        if def.group == group and (not sub or def.sub == sub) then
            if def.hidden and #steps(def) == 0 then
                hidden = hidden + 1
            elseif T.Shown(def) and complete(def) then
                earned[#earned + 1] = { def = def, time = steps(def)[#def.at].time, order = i }
            elseif T.Shown(def) then
                local goal = def.at[#steps(def) + 1]
                todo[#todo + 1] = { def = def, share = math.min(T.Progress(def.id).n / goal, 1), order = i }
            end
        end
    end
    table.sort(earned, function(a, b)
        if a.time ~= b.time then return a.time > b.time end
        return a.order < b.order
    end)
    table.sort(todo, function(a, b)
        if a.share ~= b.share then return a.share > b.share end
        return a.order < b.order
    end)
    for _, e in ipairs(earned) do items[#items + 1] = { kind = "card", def = e.def } end
    for _, e in ipairs(todo) do items[#items + 1] = { kind = "card", def = e.def } end
    if hidden > 0 then
        items[#items + 1] = { kind = "text", style = "hidden", title = UI.Count(hidden, "hidden trophy", "hidden trophies") }
    end
end

local function groupItems()
    local items, subs = {}, T.SUBGROUPS[P.group]
    if not subs or P.sub then
        cardsOf(items, P.group, P.sub)
        return items
    end
    for _, sub in ipairs(subs) do
        items[#items + 1] = { kind = "text", style = "heading", title = sub[2] }
        cardsOf(items, P.group, sub[1])
    end
    return items
end

-- Anchored to the window, which exists only once the page first shows, but parented to the page's
-- content so it hides with the page.
local function topBar()
    local top = page.top
    if not top then
        top = UI.Box(page.content, 1)
        top:SetPoint("TOPLEFT", ns.historyWindow, "TOPLEFT", 84, -38)
        top:SetPoint("TOPRIGHT", ns.historyWindow, "TOPRIGHT", -14, -38)
        top:SetHeight(22)
        top.name = UI.GameText(top, "normal", "white")
        top.name:SetPoint("LEFT")
        UI.Tint(top.name, UI.LabelColor())
        top.bar = UI.ProgressBar(top, 240, 18)
        top.bar:SetPoint("LEFT", top.name, "RIGHT", 14, 0)
        top.points = UI.Text(top, "number", 19, "text")
        top.points:SetPoint("RIGHT")
        top.label = UI.GameText(top, "normal", "muted")
        top.label:SetPoint("RIGHT", top.points, "LEFT", -6, 0)
        page.top = top
    end
    local name = "Trophies earned"
    if P.group ~= "summary" then
        for _, g in ipairs(T.GROUPS) do if g[1] == P.group then name = g[2] end end
        for _, sub in ipairs(T.SUBGROUPS[P.group] or {}) do if sub[1] == P.sub then name = sub[2] end end
    end
    top.name:SetText(name)
    local got, all = T.Counts(P.group ~= "summary" and P.group or nil, P.sub)
    top.bar:Set(got, all)
    top.label:SetText("Trophy points")
    top.points:SetText(BreakUpLargeNumbers(T.TotalPoints()) .. " " .. UI.ShieldMarkup(18))
end

local function refreshTrophies()
    if P.group ~= "summary" and not T.GroupShown(P.group) then P.group, P.sub = "summary", nil end
    local items = P.group == "summary" and summaryItems() or groupItems()
    page.list.Set(items)
    if ns.historyWindow then topBar() end
    return true
end

local function buildGroup(row)
    UI.TabRow(row)
    row:SetScript("OnClick", function(self)
        local item = self.item
        if item.sub then
            P.sub = item.sub
        else
            P.group, P.sub = item.key, nil
        end
        P.open = nil
        Shell.Refresh()
    end)
end

local function fillGroup(row, item)
    local picked = item.sub and P.sub == item.sub or (not item.sub and P.group == item.key and not P.sub)
    UI.FillTabRow(row, item.text, item.count, picked, item.sub ~= nil)
end

local function counted(group, sub) return UI.Fraction(T.Counts(group, sub)) end

local function buildGroups(box)
    page.groups = UI.List(box, { group = { template = "Button", extent = 30,
        build = buildGroup, fill = fillGroup } }, 2)
    page.groups.box:SetPoint("TOPLEFT", 8, -12)
    page.groups.box:SetPoint("BOTTOMRIGHT", -8, 12)
end

local function refreshGroups()
    local items = { { kind = "group", key = "summary", text = "Summary", count = counted() } }
    for _, g in ipairs(T.GROUPS) do
        if T.GroupShown(g[1]) then
            items[#items + 1] = { kind = "group", key = g[1], text = g[2], count = counted(g[1]) }
            if P.group == g[1] then
                for _, sub in ipairs(T.SUBGROUPS[g[1]] or {}) do
                    items[#items + 1] = { kind = "group", key = g[1], sub = sub[1], text = sub[2], count = counted(g[1], sub[1]) }
                end
            end
        end
    end
    page.groups.Set(items)
end

local trophiesPage = { key = "trophies", title = "Trophies", icon = CUP,
    tip = function() return ("What your deaths have earned you: %d of %d."):format(T.Counts()) end,
    noTime = true, noFilter = true, noStream = true,
    Showing = function() return "" end,
    empty = { "", "", "", "" },
    Build = buildTrophies, Refresh = refreshTrophies, BuildPane = buildGroups, RefreshPane = refreshGroups }
Shell.AddPage(trophiesPage)

SLASH_DEATHTRACKERTROPHIES1 = "/trophies"
SlashCmdList.DEATHTRACKERTROPHIES = function() Shell.Show("trophies") end
