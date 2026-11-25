local _, ns = ...
local UI = ns.UI
local Shell = ns.HistoryShell
local H = ns.History

local SWORDS = "Interface\\Icons\\Ability_DualWield"

local parts

local function spellsLine(spells)
    if #spells < 2 then return spells[1] end
    return table.concat(spells, ", ", 1, #spells - 1) .. " and " .. spells[#spells]
end

local function killerMatch(k, player)
    return function(sel) return sel.kind == "killer" and sel.player == player and (player and sel.name == k.name or sel.npc == k.npc) end
end

local function buildKiller(row)
    UI.RowLines(row)
    row:SetScript("OnClick", function(self)
        if self.item.kind ~= "killer" then return end
        local k, player = self.item.killer, self.item.player
        Shell.ShowDetails({ kind = "killer", player = player, npc = not player and k.npc or nil, name = k.name }, killerMatch(k, player))
    end)
end

local function killerPicked(item)
    local sel = Shell.Selected()
    return sel ~= nil and killerMatch(item.killer, item.player)(sel)
end

local function nameColor(item)
    if not item.player then return UI.CauseColor("mob") end
    return UI.ClassColor(item.killer.classFile) or UI.CauseColor("player")
end

local function fillKiller(row, item)
    local k = item.killer
    row.title:SetText(k.name)
    UI.Tint(row.title, nameColor(item))
    row.right:SetText(UI.Count(k.kills, "kill", "kills"))
    local bits = {}
    if item.player and k.class then bits[#bits + 1] = k.race and (k.race .. " " .. k.class) or k.class end
    bits[#bits + 1] = spellsLine(k.spells)
    bits[#bits + 1] = k.place
    row.line2:SetText(table.concat(bits, ", "))
    row.right2:SetText("last " .. UI.At(k.last, true))
    row.tint = killerPicked(item) and UI.COLOR.selected or nil
end

local function killerTip(row, item)
    local k, lines = item.killer, {}
    lines[#lines + 1] = Shell.KillerLine(k.deaths[1])
    local f = Shell.Filter()
    if not f.char and not f.name then
        local on = {}
        for _, c in ipairs(H.KillsOn(k.deaths)) do on[#on + 1] = UI.CharName(c.name) .. " " .. c.kills end
        lines[#lines + 1] = UI.TipPair("Kills on", table.concat(on, ", "))
    end
    if k.zone then lines[#lines + 1] = UI.TipPair("Most kills in", k.zone) end
    UI.Tooltip(row, k.name, nameColor(item), lines,
        killerPicked(item) and "Click to close the details." or ("Click to show how %s kills %s."):format(k.name, Shell.Whom()))
end

local KILLS_SHOWN = 6

local function fastest(deaths)
    local best
    for _, d in ipairs(deaths) do
        local fight = H.Fight(d)
        if fight and #fight.hits > 1 and fight.deadIn and (not best or fight.deadIn < best) then best = fight.deadIn end
    end
    return best
end

-- An older Recent event's mob has no NPC id, so it is found by its name.
local function findKiller(sel)
    local f = sel.of and { of = sel.of } or sel.mine and {} or Shell.Filter()
    for _, k in ipairs(sel.player and H.Players(f) or H.Mobs(f)) do
        if (sel.player and k.name == sel.name) or (not sel.player and (sel.npc and k.npc == sel.npc or not sel.npc and k.name == sel.name)) then
            return { killer = k, player = sel.player }
        end
    end
end
Shell.FindKiller = findKiller

local function killerDetails(panel, sel)
    if sel.kind ~= "killer" then return false end
    local item = findKiller(sel)
    if not item then return false end
    local whose = (sel.of or sel.mine) and { of = sel.of, mine = sel.mine } or nil
    local whom = sel.of and ns.Friends.Name(sel.of) or sel.mine and "you" or Shell.Whom()
    local k = item.killer
    panel:Title(k.name, nameColor(item))
    panel:Line(UI.Join(Shell.KillerLine(k.deaths[1]), k.zone), "white")
    local stats = { { "Kills", k.kills } }
    local quick = fastest(k.deaths)
    if quick then stats[#stats + 1] = { k.kills > 1 and "Fastest" or "Dead in", ("%.1f s"):format(quick) } end
    stats[#stats + 1] = { "Last", UI.Capital(UI.Date(k.last)) }
    panel:Stats(stats)
    panel:Label(("How %s %s"):format(item.player and "they hit" or "it hits", whom))
    local isKiller = item.player and function(h) return h.source == k.name end or function(h) return h.npc == k.npc end
    for i, s in ipairs(H.KillerHits(k.deaths, isKiller)) do
        if i > 4 then break end
        panel:Hit({ icon = s.icon, name = s.name, amount = "",
            note = ("%s, biggest %s"):format(UI.Count(s.hits, "hit", "hits"), BreakUpLargeNumbers(s.biggest)) })
    end
    panel:Label(item.player and "Deaths they caused" or "Deaths it caused")
    for i, d in ipairs(k.deaths) do
        if i > KILLS_SHOWN then break end
        Shell.DeathPick(panel, d, whose)
    end
    local focus = { npc = not item.player and k.npc or nil, player = item.player and k.name or nil, text = "deaths to " .. k.name,
        of = sel.of, mine = sel.mine }
    Shell.FocusButton(panel, "Show deaths to " .. k.name, focus, k.name .. " caused")
end

local function buildKillers(content)
    parts = { content = content }
    parts.view = UI.TabbedList(content, { "Mobs", "Players" },
        { killer = { template = "Button", extent = 40, build = buildKiller, fill = fillKiller, tip = killerTip },
            note = { template = "Frame", extent = 30, build = UI.GroupRow, fill = UI.FillNote } }, Shell.Refresh)
    parts.tabs, parts.list = parts.view.tabs, parts.view.list
    return parts
end

local function killerItems(killers, player)
    local out = {}
    for i, k in ipairs(killers) do out[i] = { kind = "killer", killer = k, player = player } end
    return out
end

local function refreshKillers()
    local f = Shell.Filter()
    return parts.view.Show({ killerItems(H.Mobs(f), false), killerItems(H.Players(f), true) })
end

Shell.AddPage({ key = "killers", title = "Killers", icon = SWORDS, tip = "Who killed you most: mobs and players.",
    every = "every killer",
    empty = { "No killers yet.", "Every mob and player that kills you is listed here.",
        "No killers match the filter.", "The red X on Filter shows every killer again." },
    Build = buildKillers, Refresh = refreshKillers, Details = killerDetails })
Shell.KillerDetails = killerDetails
