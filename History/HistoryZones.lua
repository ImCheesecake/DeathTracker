-- The history window's Zones page: where you die most, by zone and by spot (a subzone).
local _, ns = ...
local UI = ns.UI
local Shell = ns.HistoryShell
local H = ns.History

local MAP = "Interface\\Icons\\INV_Misc_Map_01"
local TOP_SPOTS = 3

local parts

local function toPlayers(p) return p.toPlayers > 0 and ("%d to players"):format(p.toPlayers) or nil end

local function zoneLine(z)
    local spot = z.spots[1] and "most at " .. z.spots[1].name or nil
    return UI.Capital(UI.Join(toPlayers(z), spot))
end

local function samePlace(p)
    return function(sel) return sel.kind == "place" and sel.zone == p.zone and sel.spot == p.spot end
end

local function placePicked(item)
    local sel = Shell.Selected()
    return sel ~= nil and samePlace(item.place)(sel)
end

local function fillPlace(row, item)
    local p = item.place
    row.title:SetText(p.spot or p.zone)
    row.right:SetText(UI.Count(p.deaths, "death", "deaths"))
    row.line2:SetText(p.spot and UI.Join(p.zone, toPlayers(p)) or zoneLine(p))
    row.right2:SetText("last " .. UI.At(p.last, true))
    row.tint = placePicked(item) and UI.COLOR.selected or nil
end

local function buildPlace(row)
    UI.RowLines(row)
    row:SetScript("OnClick", function(self)
        if self.item.kind ~= "place" then return end
        local p = self.item.place
        Shell.ShowDetails({ kind = "place", zone = p.zone, spot = p.spot }, samePlace(p))
    end)
end

local function placeTip(row, item)
    local p, lines = item.place, {}
    if p.spot then lines[#lines + 1] = UI.TipPair("Zone", p.zone) end
    lines[#lines + 1] = UI.TipPair("Deaths", UI.Join(p.deaths, toPlayers(p)))
    if p.spots and p.spots[1] then
        local top = {}
        for i = 1, math.min(TOP_SPOTS, #p.spots) do top[i] = p.spots[i].name .. " " .. p.spots[i].deaths end
        lines[#lines + 1] = UI.TipPair("Deadliest spots", table.concat(top, ", "))
    end
    if p.killer then lines[#lines + 1] = UI.TipPair("Killed " .. Shell.Whom() .. " most", p.killer .. " " .. p.killerKills) end
    local help = ("Click to show what kills %s %s %s."):format(Shell.Whom(), p.spot and "at" or "in", p.spot or p.zone)
    UI.Tooltip(row, p.spot or p.zone, UI.COLOR.white, lines, placePicked(item) and "Click to close the details." or help)
end

local LAST_SHOWN = 3

-- A zone or spot: who died there, what killed you most, its deadliest spots, its latest deaths.
local function placeDetails(panel, sel)
    if sel.kind ~= "place" then return false end
    local f = Shell.Filter()
    f.zone, f.spot = sel.zone, sel.spot
    local deaths = ns.Deaths(f)
    if #deaths == 0 then return false end
    local p
    for _, z in ipairs(sel.spot and H.Spots(Shell.Filter()) or H.Zones(Shell.Filter())) do
        if z.zone == sel.zone and z.spot == sel.spot then p = z end
    end
    panel:Title(sel.spot or sel.zone, UI.COLOR.white)
    local names = {}
    for _, c in ipairs(H.KillsOn(deaths)) do names[#names + 1] = c.name end
    local who = #names > 2 and ("%s and %d others died here"):format(names[1], #names - 1)
        or (table.concat(names, " and ") .. " died here")
    panel:Line(sel.spot and sel.zone .. ". " .. who or who)
    local toPlayers = 0
    for _, d in ipairs(deaths) do if d.cause == "player" then toPlayers = toPlayers + 1 end end
    panel:Stats({ { "Deaths", #deaths }, { "To players", toPlayers }, { "Last", UI.Capital(UI.Date(deaths[1].time)) } })
    local killers = H.TopKillers(deaths, 3)
    if #killers > 0 then
        panel:Label(("Killed %s most here"):format(Shell.Whom()))
        for _, k in ipairs(killers) do panel:Pick(k.name, UI.CauseColor(k.cause), k.kills) end
    end
    if p and p.spots and #p.spots > 0 then
        panel:Label("Deadliest spots")
        for i = 1, math.min(TOP_SPOTS, #p.spots) do panel:Pick(p.spots[i].name, UI.COLOR.text, p.spots[i].deaths) end
    end
    panel:Label("Latest deaths here")
    for i = 1, math.min(LAST_SHOWN, #deaths) do Shell.DeathPick(panel, deaths[i]) end
    local place = sel.spot or sel.zone
    local focus = { zone = sel.zone, spot = sel.spot, text = (sel.spot and "deaths at " or "deaths in ") .. place }
    local where = (sel.spot and "at " or "in ") .. place
    Shell.FocusButton(panel, "Show deaths " .. where, focus, where)
end

local function buildZones(content)
    parts = { content = content }
    parts.view = UI.TabbedList(content, { "Zones", "Spots" },
        { place = { template = "Button", extent = 40, build = buildPlace, fill = fillPlace, tip = placeTip },
            note = { template = "Frame", extent = 30, build = UI.GroupRow, fill = UI.FillNote } }, Shell.Refresh)
    parts.tabs, parts.list = parts.view.tabs, parts.view.list
    return parts
end

local function placeItems(places)
    local out = {}
    for i, p in ipairs(places) do out[i] = { kind = "place", place = p } end
    return out
end

local function refreshZones()
    local f = Shell.Filter()
    return parts.view.Show({ placeItems(H.Zones(f)), placeItems(H.Spots(f)) })
end

Shell.AddPage({ key = "zones", title = "Zones", icon = MAP, tip = "Where you die most.", every = "every zone",
    empty = { "No deaths yet.", "The zones you die in show here.",
        "No deaths match the filter.", "The red X on Filter shows every zone again." },
    Build = buildZones, Refresh = refreshZones, Details = placeDetails })
