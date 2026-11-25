local _, ns = ...
local UI = ns.UI
local Shell = ns.HistoryShell
local H = ns.History

local RIGHT = 64
local SKULL = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01"
local TIP_HITS = 3

local parts

local function dayLabel(day)
    if day == ns.Day(time()) then return "Today" end
    if day == ns.Day(time() - 86400) then return "Yesterday" end
    return UI.Date(ns.DayNoon(day), "%A")
end

local function fillDay(row, item)
    UI.FillGroupHeading(row, dayLabel(item.day), UI.Count(item.deaths, "death", "deaths"))
end

local function howLine(d)
    local where = d.subzone and d.subzone ~= "" and d.subzone or d.zone
    local amount = d.amount and BreakUpLargeNumbers(d.amount)
    local how
    if d.cause == "fall" and amount then
        how = ("Fell for %s damage"):format(amount)
    elseif d.cause == "mob" or d.cause == "player" or d.cause == "self" then
        how = d.spell or "Melee"
        if amount then how = ("%s for %s damage"):format(how, amount) end
    end
    if how and where then return how .. ", " .. where end
    return how or where or ""
end

local function buildDeath(row)
    row.killer = UI.GameText(row, "normal", "text")
    row.killer:SetPoint("TOPLEFT", 8, -7)
    row.time = UI.GameText(row, "small", "muted")
    row.time:SetPoint("TOPRIGHT", -8, -8)
    row.trophy = UI.GameText(row, "small", "trophy")
    row.trophy:SetAlpha(0.85)
    row.trophy:SetPoint("TOPRIGHT", row, "TOPRIGHT", -(RIGHT + 20), -8)
    row.how = UI.GameText(row, "small", "muted")
    row.how:SetPoint("TOPLEFT", 8, -23)
    row.how:SetPoint("RIGHT", row, "RIGHT", -(RIGHT + 20), 0)
    row.how:SetWordWrap(false)
    row.repair = UI.GameText(row, "small", "text")
    row.repair:SetPoint("TOPRIGHT", -8, -23)
    row:SetScript("OnClick", function(self)
        local d = self.item.death
        if self.item.kind ~= "death" then return end
        Shell.ShowDetails({ kind = "death", death = d }, function(sel) return sel.death == d end)
    end)
end

local function deathPicked(d)
    local sel = Shell.Selected()
    return sel ~= nil and sel.death == d
end

local function fillDeath(row, item)
    local d = item.death
    row.killer:SetText(ns.DeathTitle(d))
    UI.Tint(row.killer, UI.CauseColor(d.cause))
    row.trophy:SetText((ns.Trophy(d)) or "")
    local how = howLine(d)
    local f = Shell.Filter()
    if f.char or f.name then
        row.how:SetText(how)
    else
        row.how:SetText(UI.Named(UI.CharName(d.name), how ~= "" and (how:gsub("^Fell", "fell")) or nil))
    end
    row.time:SetText(date("%H:%M", d.time))
    row.repair:SetText(d.repair and UI.Money(d.repair) or "")
    row.tint = deathPicked(d) and UI.COLOR.selected or nil
end

local function killsLine(d, of, whom)
    local who = (d.cause == "mob" and d.npc and { npc = d.npc })
        or (d.cause == "player" and not d.pet and d.killer and { player = d.killer })
    if not who then return nil end
    who.of = of
    local n = #ns.Deaths(who)
    local text = UI.Times(n)
    if ns.Streaming() and not who.of then
        who.stream = true
        local here = #ns.Deaths(who)
        if here > 0 then text = ("%s, %d this stream"):format(text, here) end
    end
    return UI.TipPair("Killed " .. whom, text)
end

local function deathColor(d)
    return d.cause == "player" and UI.ClassColor(d.killerClassFile) or UI.CauseColor(d.cause)
end

local function deathTipFor(row, d, of, whom, open)
    local lines = {}
    local function add(text) if text then lines[#lines + 1] = text end end
    add(Shell.KillerLine(d))
    add(killsLine(d, of, whom))
    add(UI.TipPair("Character", Shell.CharacterLine(d)))
    if d.alive then add(UI.TipPair(ns.ALIVE_LABEL, UI.Duration(d.alive))) end
    if d.ghost and d.ghost > 0 then add(UI.TipPair("Ghost for", UI.Duration(d.ghost))) end
    if d.ran and d.ran > 0 then add(UI.TipPair("Ran back", UI.RunText(d.ran, d.runSecs))) end
    local fight = H.Fight(d)
    if fight then
        lines[#lines + 1] = { " ", UI.COLOR.white }
        lines[#lines + 1] = { "Last hits", UI.COLOR.muted }
        for i = 1, math.min(TIP_HITS, #fight.hits) do
            local h = fight.hits[i]
            lines[#lines + 1] = { (h.icon and UI.IconMarkup(h.icon, 14) .. " " or "") .. h.name, UI.COLOR.white,
                right = h.hit.amount and BreakUpLargeNumbers(h.hit.amount) or "" }
        end
    end
    UI.Tooltip(row, UI.RankMarkup(d.killerRank, 16) .. ns.DeathTitle(d), deathColor(d), lines,
        open and "Click to close the details." or "Click to show this death's details.")
end
Shell.DeathTip = deathTipFor

local function deathTip(row, item)
    deathTipFor(row, item.death, Shell.Friend(), Shell.Whom(), deathPicked(item.death))
end

local function levelLine(d, whom)
    local line = Shell.KillerLine(d)
    local gap = d.killerLevel and d.killerLevel > 0 and d.level and d.killerLevel - d.level
    if line and gap and gap > 0 then
        line = ("%s, %d %s above %s"):format(line, gap, UI.Plural(gap, "level", "levels"), whom)
    end
    return line
end

local function whereLine(d)
    local where = d.subzone and d.subzone ~= "" and d.subzone or d.zone or "?"
    local verb = d.killer and ("Killed %s in %s"):format(UI.CharName(d.name), where) or ("%s died in %s"):format(UI.CharName(d.name), where)
    return verb .. ", " .. UI.At(d.time, true)
end

local function seconds(s) return ("%.1f s"):format(s) end

local function fightStats(d, fight)
    if not fight then return d.amount and { { "Damage", BreakUpLargeNumbers(d.amount) } } or nil end
    local stats = {}
    if #fight.hits > 1 and fight.deadIn then stats[#stats + 1] = { "Dead in", seconds(fight.deadIn) } end
    stats[#stats + 1] = { "Damage", BreakUpLargeNumbers(fight.damage) }
    if fight.several then
        stats[#stats + 1] = { "Attackers", fight.attackers }
    end
    return stats
end

local function hitNote(fight, i)
    local h = fight.hits[i].hit
    local biggest = true
    for _, other in ipairs(fight.hits) do
        if (other.hit.amount or 0) > (h.amount or 0) then biggest = false end
    end
    local who = fight.several and fight.hits[i].source or nil
    local when = i == 1 and (who and "killing blow" or "Killing blow") or (h.before and seconds(h.before) .. " before") or nil
    if i == 1 and h.overkill then when = ("%s, %s overkill"):format(when, BreakUpLargeNumbers(h.overkill)) end
    local note = UI.Join(who, when)
    if biggest and #fight.hits > 1 and i > 1 then note = note .. ", biggest hit" end
    if h.crit then note = note .. ", critical" end
    return note
end

local function killingBlow(panel, d, why)
    panel:Label("Killing blow")
    local fall = d.cause == "fall"
    panel:Hit({ icon = H.HitIcon({ melee = not d.spell and not fall or nil, env = fall and "FALLING" or nil }),
        name = d.spell or (fall and "Falling") or "Melee",
        amount = d.amount and BreakUpLargeNumbers(d.amount) or "" })
    panel:Space(4)
    panel:Line(why, "faint")
end

local function fightPart(panel, d, whose, why)
    local fight = H.Fight(d)
    local stats = fightStats(d, fight)
    if stats and #stats > 1 then panel:Stats(stats) end
    if fight then
        panel:Label(("Last hits, with %s health after each"):format(whose))
        for i, h in ipairs(fight.hits) do
            local amount = h.hit.amount and BreakUpLargeNumbers(h.hit.amount) or ""
            panel:Hit({ icon = h.icon, name = h.name, note = hitNote(fight, i), part = h.part, spellId = h.hit.spellId,
                amount = amount, tipLine = h.hit.before and ("%s damage, %s before death"):format(amount, seconds(h.hit.before)) })
        end
    elseif d.cause ~= "unknown" then
        killingBlow(panel, d, why)
    end
end

local function deathDetails(panel, sel)
    if sel.kind ~= "death" then return false end
    local d, theirs = sel.death, sel.of or not sel.mine and Shell.Friend()
    if sel.of and not sel.logged then
        d = ns.Friends.Find(sel.of, d)
    elseif not sel.of and not sel.mine then
        local listed = false
        for _, p in ipairs(ns.Deaths(Shell.Filter())) do listed = listed or p == d end
        if not listed then return false end
    end
    panel:Title(ns.DeathTitle(d), UI.CauseColor(d.cause))
    local who = levelLine(d, theirs and UI.CharName(d.name) or "you")
    if who then panel:Line(who, "white") end
    panel:Line(whereLine(d))
    if d.joke then panel:Quip(d.joke) end
    fightPart(panel, d, theirs and "their" or "your", theirs and "Sent without its last hits." or "Older deaths saved only the killing blow.")
    panel:Space(12)
    if d.alive then panel:Line(UI.TipPair(ns.ALIVE_LABEL, UI.Duration(d.alive))) end
    if d.ghost and d.ghost > 0 then panel:Line(UI.TipPair("Ghost for", UI.Duration(d.ghost))) end
    if d.ran and d.ran > 0 then panel:Line(UI.TipPair("Ran back", UI.RunText(d.ran, d.runSecs))) end
    if d.repair then panel:Line(UI.TipPair("Repair bill", d.repair > 0 and UI.Money(d.repair) or "none")) end
    local name = ns.DeathTitle(d)
    local focus = (d.cause == "mob" and d.npc and { npc = d.npc }) or (d.cause == "player" and not d.pet and d.killer and { player = d.killer })
    if focus and not sel.of then
        focus.text, focus.mine = "deaths to " .. name, sel.mine
        Shell.FocusButton(panel, "Show deaths to " .. name, focus, name .. " caused")
    end
end

local function deathItems(deaths)
    local items, day = {}, nil
    for _, d in ipairs(deaths) do
        local key = ns.Day(d.time)
        if not day or day.day ~= key then
            day = { kind = "day", day = key, deaths = 0 }
            items[#items + 1] = day
        end
        day.deaths = day.deaths + 1
        items[#items + 1] = { kind = "death", death = d }
    end
    return items
end

local function buildDeaths(content)
    parts = { content = content }
    parts.totals = {
        UI.Total(content, "deaths"),
        UI.Total(content, "repair bills", "Repair bills", function()
            return ("What %s deaths cost in repairs: the gear's repair cost before each death and after. A death to a player costs nothing."):format(Shell.Whose())
        end),
        UI.Total(content, "as a ghost", "Spent as a ghost", function()
            return ("Time from releasing %s spirit to coming back to life."):format(Shell.Whose())
        end),
        UI.Total(content, "longest life", "Longest life", function()
            local l = parts.longest
            if not l then
                return ("The longest %s played without dying. These deaths don't say how long each life lasted."):format(Shell.Whom())
            end
            if not l.name then
                local word = Shell.TimeWord()
                return ("The longest %s played without dying%s."):format(Shell.Whom(), word and " " .. word or "")
            end
            local text = ("The longest %s played without dying, on the characters shown. %s"):format(Shell.Whom(), UI.CharName(l.name))
            if l.what and l.time then text = ("%s, before %s %s"):format(text, l.what, UI.At(l.time)) end
            return text .. "."
        end),
    }
    parts.totalLines = {}
    for i = 2, #parts.totals do
        local l = UI.Divider(content, true)
        l:SetHeight(34)
        parts.totalLines[i] = l
    end
    parts.deaths = UI.List(content, {
        day = { template = "Frame", extent = 30, build = UI.GroupRow, fill = fillDay },
        death = { template = "Button", extent = 40, build = buildDeath, fill = fillDeath, tip = deathTip },
        note = { template = "Frame", extent = 30, build = UI.GroupRow, fill = UI.FillNote } })
    parts.deaths.box:SetPoint("TOPLEFT", 16, -60)
    parts.deaths.box:SetPoint("BOTTOMRIGHT", -24, 10)
    return parts
end

local function placeTotals()
    local x = 16
    for i, t in ipairs(parts.totals) do
        if i > 1 then
            UI.Place(parts.content, parts.totalLines[i], x + 16, 14)
            x = x + 33
        end
        UI.Place(parts.content, t, x, 14)
        x = x + t:GetWidth()
    end
end

local function showDeaths(items)
    parts.deaths.Set(items)
    local sel = Shell.Selected()
    if sel and sel.reveal then
        sel.reveal = nil
        parts.deaths.Reveal(function(item) return item.death == sel.death end)
    end
end

local function refreshDeaths(deaths)
    local any = #deaths > 0
    for _, t in ipairs(parts.totals) do t:SetShown(any) end
    for i = 2, #parts.totals do parts.totalLines[i]:SetShown(any) end
    parts.deaths.box:SetShown(any)
    if not any then return false end
    local count, repair, ghost, longest, life = #deaths, 0, 0, nil, nil
    for _, d in ipairs(deaths) do
        repair, ghost = repair + (d.repair or 0), ghost + (d.ghost or 0)
        if d.alive and (not longest or d.alive > longest.alive) then longest = d end
    end
    if longest then life = { value = longest.alive, name = longest.name, what = ns.DeathTitle(longest), time = longest.time } end
    local id, name = Shell.Friend()
    local repairText, ghostText = UI.Money(repair), UI.Duration(ghost)
    -- A friend on 1.4.x sends only totals, a few periods and their newest deaths: the rest stays blank.
    if id and ns.Friends.Partial(id) then
        local F = ns.Friends
        local rec = F.Record(id)
        local c = name and F.Char(rec, name)
        local of, top, period = c or rec, c or F.Char(rec, rec.longestChar), Shell.Period()
        repairText, ghostText, life = "", "", nil
        if Shell.NoFilter() and period == "all" then
            count, repairText, ghostText = F.Value(rec, "deaths", "all", c), UI.Money(of.repair or 0), UI.Duration(of.ghost or 0)
            life = (of.longest or 0) > 0 and { value = of.longest, name = c and c.name or rec.longestChar,
                what = top and top.longestWhat, time = c and c.longestTime or rec.longestAt } or nil
        elseif Shell.NoFilter() then
            count = F.Value(rec, "deaths", period, c)
            local best = F.Value(rec, "longest", period, c)
            life = best > 0 and { value = best } or nil
        end
    end
    parts.totals[1]:Set(count)
    parts.totals[2]:Set(repairText)
    parts.totals[3]:Set(ghostText)
    parts.longest = life
    parts.totals[4]:Set(life and UI.Duration(life.value) or "")
    placeTotals()
    local items = deathItems(deaths)
    if id and ns.Friends.Partial(id) then
        local F, text = ns.Friends, nil
        if not F.SendsDeaths(id) then
            text = ("%s is on an older Death Tracker: only their newest %d deaths show."):format(F.Name(id), F.SENT_DEATHS)
        elseif ns.FriendsLink.Online(F.Current(id)) then
            text = ("Getting %s's deaths…"):format(F.Name(id))
        else
            text = ("%s's deaths arrive the next time you're both online."):format(F.Name(id))
        end
        items[#items + 1] = { kind = "note", text = text }
    end
    showDeaths(items)
    return true
end

Shell.AddPage({ key = "deaths", deathList = true, title = "Deaths", icon = SKULL, tip = "Every death, newest first.", every = "every death",
    empty = { "No deaths yet.", "Every death, on every character, is saved here.",
        "No deaths match the filter.", "The red X on Filter shows every death again." },
    Build = buildDeaths, Refresh = refreshDeaths, Details = deathDetails })
Shell.DeathDetails = deathDetails
