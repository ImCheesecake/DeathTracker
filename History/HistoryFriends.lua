local _, ns = ...
local UI = ns.UI
local Shell = ns.HistoryShell
local F, L, A = ns.Friends, ns.FriendsLink, ns.FriendsAsk

local ICON = "Interface\\Icons\\INV_Misc_GroupLooking"
local TABS = { "Most deaths", "Longest life", "Records", "Recent" }
local KINDS = { "deaths", "longest" }
local RECORDS, RECENT = 3, 4
local HOUR = 3600

local P = { tab = 1 }
local page

local function you()
    local c = ns.db.characters[ns.CharacterKey()] or {}
    return c
end

local function when(t)
    if time() - t < HOUR then return UI.Ago(t) end
    local day = UI.Date(t)
    if day == "today" or day == "yesterday" then return UI.At(t, true) end
    return day
end

local function value(row, kind)
    if kind == "longest" then return row.value > 0 and UI.Duration(row.value) or "None yet" end
    return UI.Count(row.value, "death", "deaths")
end

local function whoLine(row)
    if row.you then
        local c = you()
        return UI.CharacterLine(c.name, c.class, UnitLevel("player"), GetRealZoneText())
    end
    local k = F.Known(F.Current(row.id))
    local where = not L.Online(F.Current(row.id)) and L.Battleground(row.id)
    if not L.Online(F.Current(row.id)) and not where and not F.IsGuildOnly(row.id) then
        return UI.Colored(("Offline, last on %s"):format(UI.CharName(k.char) or "?"), UI.FriendColor("offline"))
    end
    return UI.CharacterLine(k.tag and k.char or nil, k.class, k.level, where or F.IsGuildOnly(row.id) and UI.Join(k.zone, "guild") or k.zone)
end

local function playing(row)
    if row.you then return you().name, GetRealZoneText() end
    local k = F.Known(F.Current(row.id))
    if L.Online(F.Current(row.id)) or F.IsGuildOnly(row.id) then return k.char, k.zone end
end

local function sinceLine(row)
    local last = row.rec.last
    if not row.you and not L.Online(F.Current(row.id)) and L.Battleground(row.id) then return "in a battleground" end
    if not row.you and not L.Online(F.Current(row.id)) and row.rec.got then return "count from " .. UI.Ago(row.rec.got) end
    return last and "last died " .. when(last.time) or "no deaths yet"
end

local function sameDeath(e)
    for _, other in ipairs(F.Recent()) do
        if other.kind == "death" and other.id == e.id and other.time == e.time then return other.last end
    end
end

local function yourDeath(at)
    for _, d in ipairs(ns.Deaths({})) do if d.time == at then return d end end
end

local function target(e)
    local sel
    if e.kind == "death" then
        sel = { kind = "death", death = e.last, of = e.id }
    elseif e.kind == "passed" then
        local d = sameDeath(e)
        sel = d and { kind = "death", death = d, of = e.id }
    elseif e.kind == "respects" then
        local d = e.at and yourDeath(e.at)
        sel = d and { kind = "death", death = d, mine = true }
    elseif e.kind == "nemesis" then
        sel = { kind = "killer", npc = e.nem.npc, name = e.nem.name, of = e.id }
    elseif e.kind == "avenged" or e.kind == "avengedBy" then
        sel = { kind = "killer", player = e.player ~= nil, npc = not e.player and e.npc or nil, name = e.player or e.mob,
            of = e.kind == "avengedBy" and e.id or nil, mine = e.kind == "avenged" }
    end
    if sel and sel.kind == "killer" and not Shell.FindKiller(sel) then return nil end
    if sel then sel.event = e end
    return sel
end

local HOW = { Guild = "the guild", ["Battle.net"] = "Battle.net", Friend = "your friends list" }
local function recordsOf(e) return e.kind == "shared" and F.Shares(e.id) and F.Record(e.id) ~= nil end

local function opened(e)
    local sel = Shell.Selected()
    return sel ~= nil and sel.event == e
end

local function clicks(row)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
        local item = self.item
        if button ~= "LeftButton" then return end
        if item.kind == "event" then
            if recordsOf(item.event) then return Shell.Pick({ friend = item.event.id }, "records") end
            local sel = target(item.event)
            if sel then Shell.ShowDetails(sel, function(other) return other.event == item.event end) end
            return
        end
        if item.kind == "char" then
            if item.mine then return Shell.Pick({ char = Shell.YourKey(item.char.name) }, "records") end
            return Shell.Pick({ friend = item.owner, friendChar = item.char.name }, "records")
        end
        if item.row then Shell.Pick({ friend = item.row.id }, "records") end
    end)
    UI.RightClickMenu(row, function(root)
        local id = row.item.row.id
        local name = F.Name(id)
        root:CreateButton(("Stop sharing with %s"):format(name), function()
            UI.Ask(("Stop sharing death counts with %s?"):format(name), "You leave each other's lists. You can ask again later.",
                function() A.StopSharing(id) end)
        end)
    end, function(self)
        local id = self.item.row and self.item.row.id
        return id ~= nil and not F.IsGuildOnly(id)
    end)
end

-- The list reuses a Button row for any kind of the same frame type, so each fill sets every part.
local function buildRanked(row)
    UI.RankedRow(row)
    row.note = UI.GameText(row, "small", "muted")
    row.note:SetPoint("RIGHT", row.right, "LEFT", -16, 0)
    row.charLine = UI.GameText(row, "small", "text")
    row.charLine:SetPoint("LEFT", 44, 0)
    clicks(row)
end

local function clear(row, keep)
    for _, k in ipairs({ "rank", "title", "line2", "right2", "note", "charLine" }) do
        if not keep[k] then row[k]:SetText("") end
    end
    UI.Tint(row.right, UI.COLOR.text)
    row.tint = nil
end

local function indent(row, x)
    row.title:SetPoint("TOPLEFT", x, -7)
    row.line2:SetPoint("TOPLEFT", x, -23)
end

local function nameOf(r)
    return r.you and "You" or F.Name(r.id), r.you and UI.FriendColor("bnet") or Shell.FriendColor(r.id)
end

local function picked(r)
    local id = Shell.Friend()
    if r.you then return id == nil end
    return id == r.id
end

local function fillPlayer(row, item)
    local r = item.row
    local name, color = nameOf(r)
    indent(row, 30)
    row.rank:SetText(r.rank)
    row.title:SetText(name)
    UI.Tint(row.title, color)
    row.right:SetText(value(r, KINDS[P.tab]))
    UI.Tint(row.right, UI.COLOR.text)
    row.line2:SetText(whoLine(r))
    row.right2:SetText(sinceLine(r))
    row.note:SetText("")
    row.charLine:SetText("")
    row.tint = picked(r) and UI.COLOR.selected or nil
end

local function fillAccount(row, item)
    local r = item.row
    local name, color = nameOf(r)
    indent(row, 30)
    row.rank:SetText(r.rank)
    row.title:SetText(name)
    UI.Tint(row.title, color)
    row.right:SetText(value(r, KINDS[P.tab]))
    UI.Tint(row.right, UI.COLOR.text)
    row.note:SetText(sinceLine(r))
    row.line2:SetText("")
    row.right2:SetText("")
    row.charLine:SetText("")
    row.tint = picked(r) and UI.COLOR.selected or nil
end

local function playerTip(row, item)
    local r, lines = item.row, {}
    for _, c in ipairs(r.rec.chars) do
        lines[#lines + 1] = { UI.CharacterLine(c.name, c.class, c.level) .. UI.Muted(": ") .. UI.Count(c.deaths, "death", "deaths"), UI.COLOR.white }
    end
    local where = not r.you and not L.Online(F.Current(r.id)) and L.Battleground(r.id)
    if where and r.rec.got then
        lines[#lines + 1] = { ("In %s. Counts as of %s: Death Tracker can't reach anyone in a battleground, so they catch up when %s leaves."):format(
            where, UI.Ago(r.rec.got), F.Name(r.id)), UI.COLOR.muted }
    elseif not r.you and not L.Online(F.Current(r.id)) and r.rec.got then
        lines[#lines + 1] = { ("Counts as of %s, the last time you were both online."):format(UI.Ago(r.rec.got)), UI.COLOR.muted }
    end
    local help = "Show your records."
    if not r.you then
        help = ("Show %s's records."):format(F.Name(r.id))
        if not F.IsGuildOnly(r.id) then help = help .. "\nRight-click to stop sharing." end
    end
    UI.Tooltip(row, r.you and "You" or F.Name(r.id), nil, lines, help)
end

local function fillChar(row, item)
    local c = item.char
    clear(row, { charLine = true })
    row.charLine:SetText(UI.CharacterLine(c.name, c.class, c.level, item.where))
    row.right:SetText(value({ value = item.value }, KINDS[P.tab]))
    local id, char = Shell.Friend()
    local key = Shell.Char()
    local mine = item.mine and not id and key and ns.db.characters[key].name == c.name
    if mine or (not item.mine and id == item.owner and char == c.name) then row.tint = UI.COLOR.selected end
end

local function charTip(row, item)
    UI.HelpTip(row, item.char.name, ("Show %s's records."):format(item.char.name))
end

local function eventLines(e)
    local name = e.id and F.Name(e.id) or ""
    local who = e.id and Shell.ColoredName(e.id) or ""
    if e.kind == "death" then
        local l = e.last
        return who .. UI.Muted(" died to ") .. UI.KillerName(l.killer, F.Cause(l)), UI.Muted(UI.Join(UI.CharName(l.char), l.spell, l.zone, l.number and "death #" .. l.number)),
            name .. " died to " .. l.killer
    elseif e.kind == "nemesis" then
        return who .. UI.Muted(" has a new nemesis: ") .. UI.MobName(e.nem.name or "?"),
            UI.Muted(UI.Join(("Killed %s %s"):format(name, UI.Times(e.nem.kills)), e.zone)), name .. " has a new nemesis"
    elseif e.kind == "passed" then
        local other = e.other == "you" and "you" or F.Name(e.other)
        local whom = e.other == "you" and "you" or Shell.ColoredName(e.other)
        return who .. UI.Muted(" passed ") .. whom, UI.Muted(("Most deaths, now %d"):format(e.deaths)), name .. " passed " .. other
    elseif e.kind == "respects" then
        return who .. UI.Muted(" paid respects"), UI.Muted("For your death to ") .. UI.KillerName(e.killer or "?", e.cause), name .. " paid respects"
    elseif e.kind == "avenged" and e.player then
        return who .. UI.Muted(" avenged you"), UI.Muted("Killed ") .. ns.Grudge.Painted(e.player, e.class)
            .. UI.Muted((", who killed you %s, in %s"):format(UI.Times(e.n or 1), e.zone or "?")), name .. " avenged you"
    elseif e.kind == "avenged" then
        return who .. UI.Muted(" avenged you"), UI.Muted(("Killed %s, your nemesis, in %s"):format(e.mob or "?", e.zone or "?")),
            name .. " avenged you"
    elseif e.kind == "avengedBy" and e.player then
        return UI.Muted("You avenged ") .. who, UI.Muted("Killed ") .. ns.Grudge.Painted(e.player, e.class)
            .. UI.Muted((", who killed them %s, in %s"):format(UI.Times(e.n or 1), e.zone or "?")), "You avenged " .. name
    elseif e.kind == "avengedBy" then
        return UI.Muted("You avenged ") .. who, UI.Muted(("Killed %s, their nemesis, in %s"):format(e.mob or "?", e.zone or "?")),
            "You avenged " .. name
    elseif e.kind == "shared" then
        return who .. UI.Muted(" shares death counts with you now"), UI.Muted(e.how or ""), name .. " shares death counts with you now"
    elseif e.kind == "asked" then
        return UI.Muted("You asked ") .. who .. UI.Muted(" to share death counts"), "", "You asked " .. name
    elseif e.kind == "declined" then
        return who .. UI.Muted(" said no"), UI.Muted("To sharing death counts"), name .. " said no"
    end
    return name, "", name
end

local function fillEvent(row, item)
    local line1, line2 = eventLines(item.event)
    clear(row, {})
    indent(row, 8)
    row.title:SetText(line1)
    UI.Tint(row.title, UI.COLOR.text)
    row.line2:SetText(line2)
    row.right:SetText(when(item.event.time))
    UI.Tint(row.right, UI.COLOR.muted)
    row.tint = opened(item.event) and UI.COLOR.selected or item.unseen and UI.COLOR.fresh or nil
end

local function eventTip(row, item)
    local e = item.event
    local sel, name, lines = target(e), F.Name(e.id), {}
    if e.kind == "nemesis" then
        local d = sameDeath(e)
        if d and d.char then lines[#lines + 1] = UI.TipPair("Character", UI.CharName(d.char)) end
        lines[#lines + 1] = UI.TipPair("Since", UI.AtTime(e.time))
    elseif e.kind == "respects" then
        if sel then lines[#lines + 1] = UI.TipPair("Your death", UI.Join(UI.CharName(sel.death.name), UI.AtTime(sel.death.time))) end
        lines[#lines + 1] = UI.TipPair("Paid", UI.AtTime(e.time))
    elseif e.kind == "passed" then
        lines[#lines + 1] = UI.TipPair("Passed " .. (e.other == "you" and "you" or F.Name(e.other)), UI.AtTime(e.time))
    elseif e.kind == "avenged" or e.kind == "avengedBy" then
        lines[#lines + 1] = UI.TipPair("Killed", UI.AtTime(e.time))
    elseif e.kind == "death" then
        return Shell.DeathTip(row, F.Find(e.id, e.last), e.id, name, opened(e))
    elseif e.kind == "shared" then
        lines[#lines + 1] = UI.TipPair("Through", HOW[e.how] or e.how or "?")
        lines[#lines + 1] = UI.TipPair("Since", UI.AtTime(e.time))
    elseif e.kind == "asked" or e.kind == "declined" then
        lines[#lines + 1] = UI.TipPair(e.kind == "asked" and "Asked" or "Said no", UI.AtTime(e.time))
    else
        return
    end
    local help
    if e.kind == "shared" and recordsOf(e) then
        help = ("Click to show %s's records."):format(name)
    elseif sel and opened(e) then
        help = "Click to close the details."
    elseif sel and e.kind == "passed" then
        help = ("Click to show the death that put %s ahead."):format(name)
    elseif sel and e.kind == "respects" then
        help = ("Click to show your death to %s."):format(ns.DeathTitle(sel.death))
    elseif sel then
        help = ("Click to show how %s kills %s."):format(Shell.FindKiller(sel).killer.name, sel.mine and "you" or name)
    end
    UI.Tooltip(row, name, Shell.FriendColor(e.id), lines, help)
end

local function deathsText(v) return UI.Count(v, "death", "deaths") end
local RECORD_ROWS = {
    { label = "Most deaths", period = "deaths", text = deathsText },
    { label = "Longest life", period = "longest", text = UI.Duration, death = "longestTime" },
    { label = "Most dungeon deaths", period = "dungeon", text = deathsText },
    { label = "Most battleground deaths", period = "bg", text = deathsText },
    { label = "Deadliest nemesis", of = "nemKills", mob = true,
        text = function(v, c, inRow)
            local name = c.nemName or "?"
            return ("%s, %s"):format(inRow and UI.MobName(name) or name, UI.Count(v, "kill", "kills"))
        end },
    { label = "Most spent on repairs", of = "repair", text = UI.Money },
    { label = "Longest run back", of = "ran", text = function(v) return UI.Yards(v) end, death = "ranTime",
        detail = function(c) return c.ranZone, c.ranTime end },
    { label = "Most time as a ghost", of = "ghost", text = UI.Duration },
    { label = "Hardest killing blow", of = "hit", death = "hitTime", text = function(v, c)
        return c.hitWhat and ("%s, %s"):format(BreakUpLargeNumbers(v), c.hitWhat) or BreakUpLargeNumbers(v) end,
        detail = function(c) return nil, c.hitTime end },
    { label = "Most deaths per level", of = function(r, c) return F.PerLevel(r, c) end,
        text = function(v) return ("%.2f"):format(v) end },
    { label = "Most deaths in a day", of = "dayMost", text = deathsText,
        detail = function(c) return nil, c.dayMostDay and ns.DayNoon(c.dayMostDay) end },
}

local function recordValue(r, c, def)
    if def.period then return F.Value(r, def.period, Shell.Period(), c) end
    if type(def.of) == "function" then return def.of(r, c) end
    return c[def.of] or 0
end

local function inScope(row)
    local group = Shell.Group()
    if row.you or not group then return true end
    return (group == "guild") == F.IsGuildOnly(row.id)
end

local function holderText(e)
    if e.row.you then return UI.FriendName("You", UI.CharName(e.char.name)) end
    return UI.FriendName(F.Known(e.row.id).tag and F.Name(e.row.id), UI.CharName(e.char.name))
end

local function heldItems()
    local items = {}
    for _, def in ipairs(RECORD_ROWS) do
        if def.period or Shell.Period() == "all" then
            local ranked = {}
            for _, row in ipairs(F.Rows("deaths")) do
                for _, c in ipairs(inScope(row) and row.rec.chars or {}) do
                    local v = recordValue(row.rec, c, def)
                    if v > 0 then ranked[#ranked + 1] = { row = row, char = c, value = v } end
                end
            end
            table.sort(ranked, function(a, b) return a.value > b.value end)
            if #ranked > 0 then items[#items + 1] = { kind = "record", def = def, ranked = ranked } end
        end
    end
    return items
end

local function recordDeath(top, at)
    local list = top.row.you and ns.Deaths({}) or F.Log(top.row.id)
    for _, d in ipairs(list) do if d.time == at and d.name == top.char.name then return d end end
end

local function recordTarget(item)
    local top, def = item.ranked[1], item.def
    local of, mine = not top.row.you and top.row.id or nil, top.row.you or nil
    local sel
    if def.death and Shell.Period() == "all" then
        local d = top.char[def.death] and recordDeath(top, top.char[def.death])
        if not d then return nil end
        sel = { kind = "death", death = d, of = of, mine = mine, logged = true }
    elseif def.mob then
        sel = { kind = "killer", npc = top.char.nemNpc, name = top.char.nemName, of = of, mine = mine }
        if not Shell.FindKiller(sel) then return nil end
    else
        return { records = true }
    end
    sel.record = def
    return sel
end

local function recordOpen(item)
    local sel = Shell.Selected()
    return sel ~= nil and sel.record == item.def
end

local function openRecord(item)
    local sel, top = recordTarget(item), item.ranked[1]
    if not sel then return end
    if not sel.records then return Shell.ShowDetails(sel, function(other) return other.record == item.def end) end
    if top.row.you then return Shell.Pick({ char = Shell.YourKey(top.char.name) }, "records") end
    Shell.Pick({ friend = top.row.id, friendChar = top.char.name }, "records")
end

local HOLDER_X = 180
local function buildHeld(row)
    UI.StatRow(row)
    row:EnableMouse(true)
    row:SetScript("OnMouseUp", function(self, button) if button == "LeftButton" then openRecord(self.item) end end)
    row.holder = UI.GameText(row, "normal", "text")
    row.holder:SetPoint("TOPLEFT", HOLDER_X, -7)
    row.label:SetPoint("RIGHT", row.holder, "LEFT", -12, 0)
    row.label:SetJustifyH("LEFT")
end

local function fillHeld(row, item)
    local top = item.ranked[1]
    row.label:SetText(item.def.label)
    row.holder:SetText(holderText(top))
    row.value:SetText(item.def.text(top.value, top.char, true))
    row.tint = recordOpen(item) and UI.COLOR.selected or nil
end

local function recordHelp(item)
    local sel, top = recordTarget(item), item.ranked[1]
    local whose = top.row.you and "your" or F.Name(top.row.id) .. "'s"
    if not sel then return nil end
    if recordOpen(item) then return "Click to close the details." end
    if sel.records then return ("Click to show %s records."):format(whose) end
    if sel.kind == "killer" then
        return ("Click to show how %s kills %s."):format(Shell.FindKiller(sel).killer.name, top.row.you and "you" or F.Name(top.row.id))
    end
    return top.row.you and "Click to show your death." or ("Click to show %s's death."):format(top.char.name)
end

local TIP_PLACES = 3
local function heldLine(n, e, def)
    local where, at
    if def.detail then where, at = def.detail(e.char) end
    return ("%d. %s: %s"):format(n, holderText(e), UI.Join(def.text(e.value, e.char), where, at and UI.Date(at)))
end

local function heldTip(row, item)
    local lines, youShown = {}, false
    for n, e in ipairs(item.ranked) do
        if n <= TIP_PLACES or (e.row.you and not youShown) then
            lines[#lines + 1] = heldLine(n, e, item.def)
            youShown = youShown or e.row.you
        end
        if n >= TIP_PLACES and youShown then break end
    end
    UI.Tooltip(row, item.def.label, nil, lines, recordHelp(item))
end

local function tabLabel(i)
    local unseen = F.Unseen()
    if i == RECENT and unseen > 0 then return "Recent " .. UI.Colored(unseen .. " new", UI.COLOR.faint) end
    return TABS[i]
end

local function tabEmpty(i)
    if i == RECORDS then return "No records yet." end
    if i == RECENT then
        local word = Shell.TimeWord()
        return word and ("Nothing happened %s."):format(word) or "Nothing has happened yet."
    end
    return ("No deaths %s."):format(Shell.TimeWord() or "yet")
end

local function buildPage(content)
    page = { content = content }
    page.view = UI.TabbedList(content, TABS, {
        player = { template = "Button", extent = 40, build = buildRanked, fill = fillPlayer, tip = playerTip },
        account = { template = "Button", extent = 26, build = buildRanked, fill = fillAccount, tip = playerTip },
        char = { template = "Button", extent = 22, build = buildRanked, fill = fillChar, tip = charTip },
        event = { template = "Button", extent = 40, build = buildRanked, fill = fillEvent, tip = eventTip },
        record = { template = "Frame", extent = UI.STAT_ROW, build = buildHeld, fill = fillHeld, tip = heldTip } },
        function()
            P.tab = page.view.pick
            Shell.Refresh()
        end, tabLabel, tabEmpty)
    page.tabs, page.list = page.view.tabs, page.view.list
    return page
end

local lookingUntil = 0
local function fillShareMenu(root) A.FillMenu(root, GetTime() < lookingUntil) end

local function openShareMenu()
    lookingUntil = GetTime() + A.LOOKING
    L.Greet(true)
    page.share.Refresh()
    C_Timer.After(A.LOOKING, function() page.share.Refresh() end)
end

local function buildFooter(box)
    page.share = UI.MenuButton(box, "Share with a friend", 150, 22, fillShareMenu, openShareMenu)
    page.share:SetPoint("BOTTOM", 0, 14)
    page.share:SetScript("OnEnter", function(self)
        UI.HelpTip(self, "Share with a friend", "Ask a friend who uses Death Tracker. Once they say yes, you see each other's deaths.")
    end)
    page.share:SetScript("OnLeave", UI.HideTooltip)
end

local function addPlayer(items, r, i)
    local several = #r.rec.chars > 1 and (r.you or F.Known(r.id).tag ~= nil)
    items[#items + 1] = { kind = several and "account" or "player", row = r }
    if not several then return end
    local chars, now, where = {}, playing(r)
    for _, c in ipairs(r.rec.chars) do
        local v = F.Value(r.rec, KINDS[i], Shell.Period(), c)
        if v > 0 then
            chars[#chars + 1] = { kind = "char", char = c, value = v, where = c.name == now and where or nil,
                owner = r.id, mine = r.you }
        end
    end
    table.sort(chars, function(a, b) return a.value > b.value end)
    for _, c in ipairs(chars) do items[#items + 1] = c end
end

local function tabItems(i)
    if i == RECORDS then return heldItems() end
    if i == RECENT then
        local items, period = {}, Shell.Period()
        local from = period ~= "all" and ns.PeriodStart(period) or 0
        for _, e in ipairs(F.Recent()) do
            if e.time >= from then items[#items + 1] = { kind = "event", event = e, unseen = not e.seen } end
        end
        return items
    end
    local items, rank = {}, 0
    for _, r in ipairs(F.Rows(KINDS[i], Shell.Period())) do
        if inScope(r) then
            rank = rank + 1
            r.rank = rank
            addPlayer(items, r, i)
        end
    end
    return items
end

local function refresh()
    if #F.Rows("deaths") < 2 then return page.view.Show({}) end
    P.tab = page.view.pick
    local lists = {}
    for i = 1, #TABS do lists[i] = tabItems(i) end
    if P.tab == RECENT then F.MarkSeen() end
    return page.view.Show(lists)
end

local friendsPage
local function glow()
    local tab = friendsPage.tab
    if not tab then return end
    tab.glow = tab.glow or UI.Glow(tab)
    tab.glow:SetShown(F.Unseen() > 0 and Shell.Current() ~= friendsPage)
end

local function note()
    local unseen, words = F.Unseen(), {}
    if unseen == 0 then return nil end
    for _, e in ipairs(F.Recent()) do
        if #words == 2 then break end
        if not e.seen then words[#words + 1] = select(3, eventLines(e)) end
    end
    return ("%d new: %s."):format(unseen, table.concat(words, ", "))
end

friendsPage = { key = "friends", title = "Friends", icon = ICON, tip = "Your friends' deaths, side by side.",
    Note = note, noFilter = true, noStream = true,
    Showing = function()
        if P.tab == RECENT then return "Showing what happened " .. (Shell.TimeWord() or "lately") end
        local word, group = Shell.TimeWord(), Shell.Group()
        local what = P.tab == RECORDS and "records" or P.tab == 2 and "longest lives" or "deaths"
        local text = "Showing " .. what .. (group and " for your " .. group or "") .. (word and " " .. word or "")
        if text == "Showing records" then return "Showing every record" end
        return text == "Showing deaths" and "Showing every friend" or text
    end,
    empty = { "No friends yet.", "Share with a friend, and their deaths show up here.",
        "No friends yet.", "Share with a friend, and their deaths show up here." },
    Build = buildPage, Refresh = refresh, BuildFooter = buildFooter,
    Details = function(panel, sel)
        if sel.kind == "killer" then return Shell.KillerDetails(panel, sel) end
        return Shell.DeathDetails(panel, sel)
    end,
    Shown = function() glow() end }
Shell.AddPage(friendsPage)

ns.OnChange(function() if friendsPage.tab then glow() end end)
