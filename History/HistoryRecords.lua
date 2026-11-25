-- The history window's Records page: bests and worsts, each a click away from the deaths behind it.
-- With a friend picked in the pane: their records, and beside yours to compare.
local _, ns = ...
local UI = ns.UI
local Shell = ns.HistoryShell
local H = ns.History

local BOOK = "Interface\\Icons\\INV_Misc_Book_09"
local ORDER = { "longestLife", "hardestHit", "mostInDay", "mostExpensive", "longestRun", "longestGhost" }
-- Your own page: every record, then where you died (board "Records, more rows").
local OWN = { "longestLife", "shortestLife", "hardestHit", "mostExpensive", "longestRun", "longestGhost", "mostInDay",
    "mostInHour", "longestWithout", "perLevel" }
local WHERE = { { "open", "Open world", "the open world" }, { "dungeon", "Dungeons", "dungeons" }, { "raid", "Raids", "raids" },
    { "battle", "Battlegrounds", "battlegrounds and arenas" } }
local TITLES = { longestLife = "Longest life", shortestLife = "Shortest life", mostInHour = "Most deaths in an hour",
    longestWithout = "Longest without dying", perLevel = "Deaths per level", hardestHit = "Hardest killing blow", mostInDay = "Most deaths in a day",
    mostExpensive = "Most expensive death", longestRun = "Longest run back", longestGhost = "Longest as a ghost" }
local COLUMN = 120
local WATCH_PAD = 30

local parts
local mine   -- your side of the compare: one of your characters' names, or nil for every one

local function valueText(key, value)
    if key == "longestLife" or key == "shortestLife" or key == "longestGhost" then return UI.Duration(value) end
    if key == "hardestHit" then return BreakUpLargeNumbers(value) end
    if key == "mostExpensive" then return UI.Money(value) end
    if key == "longestRun" then return UI.Yards(value) end
    return value
end

-- withSpell: the death names the spell that ended it ("Lord Kazzak's Shadow Bolt Volley").
local function deathRecord(key, r, withSpell)
    local d = r.death
    return { kind = "record", title = TITLES[key], value = valueText(key, r.value),
        lines = { UI.TipPair("Character", Shell.CharacterLine(d)),
            UI.TipPair("Death", UI.Join(ns.DeathTitle(d, withSpell), d.zone, UI.At(d.time))) },
        help = "Show that death.", focus = { death = d, text = "the death " .. UI.At(d.time) } }
end

-- player: the record is that player's kills in the stream.
local function streamRecord(title, s, value, player)
    local name = "the stream of " .. UI.Date(s.from, "%a")
    local item = { kind = "record", title = title, value = value, lines = { UI.TipPair("Started", UI.At(s.from)) }, help = "Show every death in that stream.",
        focus = { from = s.from, to = s.to, text = name } }
    if player then
        table.insert(item.lines, 1, UI.TipPair("Player", player))
        item.help = ("Show every death to %s in that stream."):format(player)
        item.focus.player, item.focus.text = player, ("deaths to %s in %s"):format(player, name)
    end
    return item
end

-- The characters the filter keeps, yours or a friend's: their levels together, and each one's name and level.
local function levelsOf(f)
    local chars, sum = {}, 0
    if f.of then
        for _, c in ipairs(ns.Friends.Store().players[f.of].chars) do
            if not f.name or c.name == f.name then chars[#chars + 1] = c end
        end
    else
        for key, c in pairs(ns.db.characters) do
            if (not f.char or key == f.char) and (not f.ruleset or ns.Ruleset(key) == f.ruleset) then chars[#chars + 1] = c end
        end
    end
    for _, c in ipairs(chars) do sum = sum + (c.level or 1) end
    table.sort(chars, function(a, b)
        if (a.level or 1) ~= (b.level or 1) then return (a.level or 1) > (b.level or 1) end
        return a.name < b.name
    end)
    local names = {}
    for i, c in ipairs(chars) do names[i] = c.name .. " " .. (c.level or 1) end
    return sum, table.concat(names, ", ")
end

local function hourRecord(m)
    if m.deaths < 2 then
        return { kind = "record", title = TITLES.mostInHour, value = m.deaths, lines = { ("1 death: no two of %s deaths are within an hour."):format(Shell.Whose()) } }
    end
    return { kind = "record", title = TITLES.mostInHour, value = m.deaths,
        lines = { ("%s, %s from %s."):format(UI.Count(m.deaths, "death", "deaths"), UI.Date(m.from, "%a"), date("%H:%M", m.from)) },
        help = "Show those deaths.", focus = { from = m.from, to = m.to, text = "deaths in the hour from " .. UI.At(m.from) } }
end

local function withoutRecord(w, f)
    local whom = (f.name or f.char) and "on " .. (f.name or ns.db.characters[f.char].name) or "on every character"
    local item = { kind = "record", title = TITLES.longestWithout, value = UI.Duration(w.value),
        focus = { death = w.death, text = "the death " .. UI.At(w.death.time) } }
    if w.still then
        item.lines, item.help = { ("Since %s, %s. Still going."):format(UI.At(w.from), whom) }, ("Show %s last death."):format(Shell.Whose())
    else
        item.lines = { ("From %s to %s, %s."):format(UI.At(w.from), UI.At(w.to), whom) }
        item.help = "Show the death that ended it."
    end
    return item
end

local function recordItems(r, f)
    local items = {}
    for _, key in ipairs(OWN) do
        if key == "mostInHour" and r.mostInHour then
            items[#items + 1] = hourRecord(r.mostInHour)
        elseif key == "longestWithout" and r.longestWithout then
            items[#items + 1] = withoutRecord(r.longestWithout, f)
        elseif key == "perLevel" and r.deaths > 0 and levelsOf(f) > 0 then
            local levels, names = levelsOf(f)
            items[#items + 1] = { kind = "record", title = TITLES.perLevel, value = ("%.2f"):format(r.deaths / levels),
                lines = { ("%s over %s: %s."):format(UI.Count(r.deaths, "death", "deaths"), UI.Count(levels, "level", "levels"), names) } }
        elseif r[key] and key == "mostInDay" then
            local m = r.mostInDay
            local day = UI.Date(ns.DayNoon(m.day), "%a")
            local summary = ("%s on %s"):format(UI.Count(m.deaths, "death", "deaths"), day)
            if m.killer and m.killerKills > 1 then summary = ("%s, %d to %s"):format(summary, m.killerKills, m.killer) end
            items[#items + 1] = { kind = "record", title = TITLES[key], value = m.deaths,
                lines = { UI.TipPair("Character", m.name), summary .. "." },
                help = "Show every death that day.", focus = { day = m.day, text = "deaths on " .. day } }
        elseif r[key] then
            items[#items + 1] = deathRecord(key, r[key], key == "hardestHit")
        end
    end
    if r.deaths > 0 then
        items[#items + 1] = { kind = "heading", title = ("Where %s died"):format(Shell.Whom()) }
        for _, w in ipairs(WHERE) do
            local n = r.where[w[1]]
            items[#items + 1] = { kind = "record", title = w[2], value = n,
                lines = { n > 0 and ("%s in %s."):format(UI.Count(n, "death", "deaths"), w[3]) or ("No deaths in %s yet."):format(w[3]) } }
        end
    end
    if ns.Streaming() and r.mostInStream then
        items[#items + 1] = { kind = "heading", title = "Streams" }
        items[#items + 1] = streamRecord("Most deaths in a stream", r.mostInStream, r.mostInStream.deaths)
        if r.fewestInStream then
            items[#items + 1] = streamRecord("Fewest deaths in a stream", r.fewestInStream, r.fewestInStream.deaths)
        end
        local p = r.mostByOnePlayer
        if p then items[#items + 1] = streamRecord("Most kills by one player in a stream", p, p.kills, p.name) end
    end
    return items
end

-- One side of the compare: { f = its filter, rec = its record, char = one of its characters }.
local function sideRecords(side)
    local f = {}
    for k, v in pairs(side.f) do f[k] = v end
    f.noBattle = true
    return f, H.Records(f)
end

local function recordLine(key, e)
    if not e then return nil end
    if key == "mostInDay" then return ("%s on %s."):format(UI.Count(e.deaths, "death", "deaths"), UI.Date(ns.DayNoon(e.day), "%a")) end
    local d = e.death
    return UI.Join(d.name, ns.DeathTitle(d, key == "hardestHit"), d.zone, UI.At(d.time))
end

local function bestValue(key, e) return e and (key == "mostInDay" and e.deaths or e.value) end

local function versusRows(a, b, names)
    local items = {}
    local fa, ra = sideRecords(a)
    local fb, rb = sideRecords(b)
    local function pair(title, them, mine, themN, mineN, tip)
        items[#items + 1] = { kind = "versus", title = title, them = them, mine = mine, themN = themN or 0, mineN = mineN or 0,
            lines = { tip } }
    end
    pair("Deaths", ra.deaths, rb.deaths, ra.deaths, rb.deaths)
    local la, lb = levelsOf(fa), levelsOf(fb)
    local x, y = la > 0 and ra.deaths / la or 0, lb > 0 and rb.deaths / lb or 0
    pair("Deaths per level", ("%.2f"):format(x), ("%.2f"):format(y), x, y)
    local function nem(side)
        if side.char then return side.char.nemName, side.char.nemKills end
        return side.rec.nem and side.rec.nem.name, side.rec.nem and side.rec.nem.kills
    end
    local xn, xk = nem(a)
    local yn, yk = nem(b)
    local function nemLine(n, k, who) return ("%s: %s"):format(who, n and UI.Join(n, UI.Count(k or 0, "kill", "kills")) or "none yet") end
    items[#items + 1] = { kind = "versus", title = "Nemesis", them = xn or "None yet", mine = yn or "None yet", themN = 0, mineN = 0,
        lines = { nemLine(xn, xk, names[1]), nemLine(yn, yk, names[2]) },
        themColor = xn and UI.CauseColor("mob") or UI.COLOR.faint, mineColor = yn and UI.CauseColor("mob") or UI.COLOR.faint }
    for _, key in ipairs(ORDER) do
        local ea, eb = ra[key], rb[key]
        local function side(e) return e and valueText(key, bestValue(key, e)) or "None yet" end
        local function sideLine(e, who) return ("%s: %s"):format(who, recordLine(key, e) or "none yet") end
        items[#items + 1] = { kind = "versus", title = TITLES[key], them = side(ea), mine = side(eb),
            themN = bestValue(key, ea) or 0, mineN = bestValue(key, eb) or 0, lines = { sideLine(ea, names[1]), sideLine(eb, names[2]) } }
    end
    local ta, tb = H.Totals(fa), H.Totals(fb)
    local function money(v) return v > 0 and UI.Money(v) or "None yet" end
    local function life(v) return v > 0 and UI.Duration(v) or "None yet" end
    pair("Repair bills", money(ta.repair), money(tb.repair), ta.repair, tb.repair, "Every repair bill after a death, together.")
    pair("Time as a ghost", life(ta.ghost), life(tb.ghost), ta.ghost, tb.ghost, "Every minute spent dead, together.")
    local da, db = ns.Deaths(a.f, 1)[1], ns.Deaths(b.f, 1)[1]
    local function lastLine(d, who) return ("%s: %s"):format(who, d and UI.Join(ns.DeathTitle(d), d.zone, UI.Date(d.time)) or "none yet") end
    items[#items + 1] = { kind = "versus", title = "Last death", them = da and UI.Date(da.time) or "None yet",
        mine = db and UI.Date(db.time) or "None yet", themN = da and da.time or 0, mineN = db and db.time or 0,
        lines = { lastLine(da, names[1]), lastLine(db, names[2]) },
        focus = da and { death = da }, help = da and ("Click to show %s's last death."):format(names[1]) }
    local function battles(f)
        local n = 0
        for _, d in ipairs(ns.Deaths(f)) do if ns.BattleDeath(d) then n = n + 1 end end
        return n
    end
    local ba, bb = battles(a.f), battles(b.f)
    pair("Battleground deaths", ba, bb, ba, bb, "Deaths in battlegrounds and arenas. No other row counts them.")
    return items
end

local function versusItems(id, name)
    local F = ns.Friends
    local rec, yours = F.Store().players[id], F.Mine()
    if mine and not Shell.YourKey(mine) then mine = nil end
    local theirs, own = Shell.Filter(), Shell.Filter()
    own.of, own.name, own.char = nil, nil, mine and Shell.YourKey(mine)
    return versusRows({ f = theirs, rec = rec, char = name and F.Char(rec, name) },
        { f = own, rec = yours, char = mine and F.Char(yours, mine) }, { Shell.FriendName(), mine or "You" })
end

local function buildRecord(row)
    UI.StatRow(row)
    row:SetScript("OnClick", function(self) if self.item.focus then Shell.Focus(self.item.focus) end end)
end

local function fillRecord(row, item)
    row.label:SetText(item.title)
    row.value:SetText(item.value)
end

local function recordTip(row, item) UI.Tooltip(row, item.title, UI.COLOR.white, item.lines, item.help) end

local function fillStreams(row, item)
    row.title:SetText(item.title)
    row.summary:SetText("")
end

local function buildVersus(row)
    UI.StatRow(row)
    row.them = UI.GameText(row, "normal", "text")
    row.them:SetPoint("TOPRIGHT", -8 - COLUMN, -7)
    row:SetScript("OnClick", function(self) if self.item.focus then Shell.Focus(self.item.focus) end end)
end

local function fillVersus(row, item)
    row.label:SetText(item.title)
    row.them:SetText(item.them)
    row.value:SetText(item.mine)
    local lead = item.themN ~= item.mineN and (item.themN > item.mineN and "them" or "mine")
    UI.Tint(row.them, item.themColor or (lead == "mine" and UI.COLOR.faint or UI.COLOR.text))
    UI.Tint(row.value, item.mineColor or (lead == "them" and UI.COLOR.faint or UI.COLOR.text))
end

local function yourChoices()
    local out = { { value = "", text = "You" } }
    for _, c in ipairs(ns.Friends.Mine().chars) do out[#out + 1] = { value = c.name, text = c.name } end
    return out
end

local function buildRecords(content)
    parts = { content = content }
    parts.list = UI.List(content, {
        record = { template = "Button", extent = UI.STAT_ROW, build = buildRecord, fill = fillRecord, tip = recordTip },
        heading = { template = "Frame", extent = 30, build = UI.GroupRow, fill = fillStreams } })
    parts.tabs = UI.Tabs(content, { "", "Compare with you" }, function(id) Shell.SetComparing(id == 2) end)
    parts.tabs:SetPoint("TOPLEFT", 16, -10)
    parts.tabLine = UI.Divider(content)
    UI.Place(content, parts.tabLine, 0, 42)
    parts.tabLine:SetPoint("RIGHT")
    parts.versus = UI.List(content, {
        versus = { template = "Button", extent = UI.STAT_ROW, build = buildVersus, fill = fillVersus, tip = recordTip } })
    parts.versus.box:SetPoint("TOPLEFT", 16, -86)
    parts.versus.box:SetPoint("BOTTOMRIGHT", -24, 10)
    parts.yours = UI.Dropdown(content, COLUMN - 10, yourChoices, function() return mine or "" end, function(v)
        mine = v ~= "" and v or nil
        Shell.Refresh()
    end)
    parts.yours:SetPoint("TOPRIGHT", -26, -56)
    parts.theirs = UI.GameText(content, "normal", "text")
    parts.theirs:SetPoint("TOPRIGHT", -32 - COLUMN, -60)
    parts.beside = UI.Button(content, "", 120, 22, function(self)
        if self.road then return ns.Recap.PlayRoad(self.road) end
        ns.Recap.Play(self.key)
    end)
    parts.beside:SetScript("OnEnter", function(self)
        local what = self.road and ("%s's deaths from level %d to 60"):format(ns.db.characters[self.road].name, ns.Recap.RoadFrom(self.road))
            or ("Every death in %s, on all your characters,"):format(ns.Recap.Name(self.key))
        UI.HelpTip(self, self:GetText(), what .. " in short slides. Click left to go back, right to skip ahead. Esc closes.", "ANCHOR_TOP")
    end)
    parts.beside:SetScript("OnLeave", UI.HideTooltip)
    return parts
end

local function refreshWatch()
    local char = not Shell.Friend() and Shell.PickedChar()
    local road = char and ns.Recap.ReachedAt(char) and char or nil
    local key = not Shell.Friend() and not road and ns.Recap.Offer() or nil
    parts.beside:SetShown(key ~= nil or road ~= nil)
    if not (key or road) then return end
    parts.beside.key, parts.beside.road = key, road
    parts.beside:SetText(road and ns.Recap.RoadLabel() or ns.Recap.PlayLabel(key))
    parts.beside:SetWidth(parts.beside:GetTextWidth() + WATCH_PAD)
end

local function refreshRecords()
    refreshWatch()
    local id = Shell.Friend()
    local comparing = Shell.Comparing()
    for _, t in ipairs({ parts.versus.box, parts.yours, parts.theirs }) do t:SetShown(comparing) end
    parts.tabs:SetShown(id ~= nil)
    parts.tabLine:SetShown(id ~= nil)
    if id then
        parts.tabs.SetLabels({ Shell.FriendName(), "Compare with you" })
        parts.tabs:SetTab(comparing and 2 or 1)
    end
    parts.list.box:ClearAllPoints()
    parts.list.box:SetPoint("TOPLEFT", 16, id and -48 or -12)
    parts.list.box:SetPoint("BOTTOMRIGHT", -24, 10)
    local items
    if comparing then
        parts.list.box:Hide()
        parts.yours:GenerateMenu()
        parts.theirs:SetText(Shell.FriendName())
        UI.Tint(parts.theirs, Shell.FriendColor(id))
        items = versusItems(id, select(2, Shell.Friend()))
        parts.versus.Set(items)
        return #items > 0
    end
    items = recordItems(H.Records(Shell.Filter()), Shell.Filter())
    local any = #items > 0
    parts.list.box:SetShown(any)
    if any then parts.list.Set(items) end
    return any
end

local function friendShowing(name)
    if not Shell.Comparing() then return nil end
    local word = Shell.TimeWord()
    return ("Showing %s and you"):format(name) .. (word and " " .. word or "")
end

Shell.AddPage({ key = "records", title = "Records", icon = BOOK, tip = "Your bests and worsts: longest life, most deaths in a day.",
    every = "every death",
    empty = { "No records yet.", "Your longest life, worst day and more show here after your first death.",
        "No records match the filter.", "The red X on Filter shows every record again." },
    Build = buildRecords, Refresh = refreshRecords, FriendShowing = friendShowing })
