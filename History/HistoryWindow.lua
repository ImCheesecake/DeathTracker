local addonName, ns = ...
local UI = ns.UI

local WIDTH, HEIGHT, TOP = 760, 580, 72
local PANE = 200
local DETAILS = 300
local NEMESIS_HEIGHT = 84
local FOOTER = 48
local KILLS_AWAY = { "one kill", "two kills" }
local CAUSE_WORDS = { mob = "mobs", player = "players", fall = "falls", drown = "drowning", lava = "lava", fire = "fire",
    fatigue = "fatigue", slime = "slime", other = "other causes" }
local RANKS = { elite = "Elite", rare = "Rare", rareelite = "Rare elite", worldboss = "Boss" }
local TIME_WIDTH = 128
local TIMES = { { value = "stream", text = "This stream", word = "this stream" }, { value = "day", text = "Today", word = "today" },
    { value = "week", text = "This week", word = "this week" }, { value = "month", text = "This month", word = "this month" },
    { value = "all", text = "All time" } }
local RESETS = { { "npc", "deaths to every killer" }, { "player", "deaths to every killer" }, { "spot", "deaths at every spot" },
    { "zone", "deaths in every zone" }, { "day", "deaths on every day" }, { "from", "deaths in every stream" },
    { "death", "every death" } }

local Shell = { pages = {} }
ns.HistoryShell = Shell

local frame, page, state, current
local FOCUS = { "npc", "player", "zone", "spot", "day", "death", "from", "to" }

function Shell.AddPage(p) table.insert(Shell.pages, p) end

local function allKinds()
    local all = {}
    for _, c in ipairs(ns.CAUSES) do all[c[1]] = true end
    return all
end

local function resetFilter()
    state.causes, state.minLevel, state.maxLevel, state.focus = allKinds(), nil, nil, nil
end

local function allOn(set, keys)
    for _, k in ipairs(keys) do if not set[k] then return false end end
    return true
end

local function causeKeys()
    local out = {}
    for _, c in ipairs(ns.CAUSES) do out[#out + 1] = c[1] end
    return out
end

local function shellDefault()
    return allOn(state.causes, causeKeys()) and not state.minLevel and not state.maxLevel and not state.focus
end

local function hasStreams() return ns.Streaming() and not (current and current.noStream) and not state.friend end

local function timePick()
    local t = state.time or (ns.Streaming() and "stream" or "all")
    if t == "stream" and not hasStreams() then return "all" end
    return t
end

local function timePicks()
    local out = {}
    for _, t in ipairs(TIMES) do if t.value ~= "stream" or hasStreams() then out[#out + 1] = t end end
    return out
end

local function timeOf(value)
    for _, t in ipairs(TIMES) do if t.value == value then return t end end
end

function Shell.Period()
    local t = timePick()
    return t == "stream" and "all" or t
end

function Shell.TimeWord() return timeOf(timePick()).word end

local function menuFilter()
    local f = { causes = not allOn(state.causes, causeKeys()) and state.causes or nil, minLevel = state.minLevel,
        maxLevel = state.maxLevel, ruleset = state.ruleset }
    local t = timePick()
    if t == "stream" then f.stream = true elseif t ~= "all" then f.since = ns.PeriodStart(t) end
    for _, k in ipairs(FOCUS) do f[k] = state.focus and state.focus[k] end
    return f
end

function Shell.Filter()
    local f = menuFilter()
    f.char, f.of, f.name = state.char, state.friend, state.friendChar
    return f
end

local function resetWords(focus)
    local found
    for _, r in ipairs(RESETS) do
        if focus[r[1]] ~= nil and not (r[1] == "zone" and focus.spot) then
            if found then return RESETS[#RESETS][2] end
            found = r[2]
        end
    end
    return found or RESETS[#RESETS][2]
end

local function resetTip()
    if not state.focus then return "Shows every cause and level again." end
    local text, t = ("Shows %s, every cause and every level again."):format(resetWords(state.focus)), timePick()
    if t ~= "all" then text = ("%s %s stays."):format(text, timeOf(t).text) end
    return text
end

function Shell.Char() return state.char end

function Shell.PickedChar(key)
    key = key or state.char
    if key then return key end
    local only = next(ns.db.characters)
    if only and not next(ns.db.characters, only) then return only end
end

Shell.NoFilter = shellDefault

function Shell.YourKey(name)
    for key, c in pairs(ns.db.characters) do if c.name == name then return key end end
end

function Shell.Friend() return state.friend, state.friendChar end

function Shell.FriendName() return state.friendChar or ns.Friends.Name(state.friend) end

function Shell.Whom() return state.friend and Shell.FriendName() or "you" end
function Shell.Whose() return state.friend and "their" or "your" end

function Shell.Group() return state.group end

local refresh, showDetails

function Shell.Pick(pick, page)
    state.friend, state.friendChar, state.char, state.ruleset = pick.friend and ns.Friends.Primary(pick.friend), pick.friendChar, pick.char, nil
    if not pick.friend then state.compare = nil end
    if page then return Shell.Show(page) end
    refresh()
end

function Shell.Comparing() return state.compare and state.friend ~= nil end

function Shell.SetComparing(on)
    state.compare = on or nil
    refresh()
end

function Shell.FriendColor(id)
    local F, L = ns.Friends, ns.FriendsLink
    if F.IsGuildOnly(id) then
        local rec = F.Record(id)
        return UI.ClassColor(rec and rec.chars[1] and rec.chars[1].class) or UI.FriendColor("character")
    end
    if not L.Online(F.Current(id)) and not L.Battleground(id) then return UI.FriendColor("offline") end
    return UI.FriendColor(F.Known(id).tag and "bnet" or "character")
end

function Shell.ColoredName(id) return UI.Colored(ns.Friends.Name(id), Shell.FriendColor(id)) end

function Shell.CharacterLine(d)
    local ruleset = ns.Ruleset(d.char)
    return ruleset and ("%s, %s realm"):format(UI.CharName(d.name), ruleset) or UI.CharName(d.name)
end

local function showing()
    local parts = {}
    if state.friend then
        local who = Shell.ColoredName(state.friend)
        if state.friendChar then
            local c = ns.Friends.Char(ns.Friends.Record(state.friend), state.friendChar)
            who = who .. "'s " .. UI.Colored(UI.CharName(state.friendChar), UI.ClassColor(c and c.class) or UI.COLOR.text)
        end
        local own = current.FriendShowing and current.FriendShowing(who)
        if own then return own end
        parts[1] = who
    elseif state.char then
        local c = ns.db.characters[state.char]
        parts[#parts + 1] = UI.Colored(UI.CharName(c.name), UI.ClassColor(c.class) or UI.COLOR.text)
    elseif state.ruleset then
        parts[#parts + 1] = state.ruleset .. " characters"
    end
    if state.focus then parts[#parts + 1] = state.focus.text end
    local f = menuFilter()
    if f.causes then
        local on, off = {}, {}
        for _, c in ipairs(ns.CAUSES) do
            local side = state.causes[c[1]] and on or off
            side[#side + 1] = CAUSE_WORDS[c[1]]
        end
        if #off < #on then
            parts[#parts + 1] = ("%s but %s"):format(current.every, UI.AndList(off))
        elseif #on > 0 then
            parts[#parts + 1] = table.concat(on, ", ")
        end
    end
    if state.minLevel and state.maxLevel then
        parts[#parts + 1] = ("levels %d to %d"):format(state.minLevel, state.maxLevel)
    elseif state.minLevel then
        parts[#parts + 1] = ("level %d and up"):format(state.minLevel)
    elseif state.maxLevel then
        parts[#parts + 1] = ("up to level %d"):format(state.maxLevel)
    end
    local word = Shell.TimeWord()
    return "Showing " .. (#parts == 0 and current.every or table.concat(parts, ", ")) .. (word and " " .. word or "")
end

function Shell.KillerLine(d)
    local level = d.killerLevel and (d.killerLevel < 0 and "level ??" or "level " .. d.killerLevel)
    local who
    if d.cause == "player" and d.killerClass then
        who = d.killerRace and (d.killerRace .. " " .. d.killerClass) or d.killerClass
    elseif d.killerRank then
        who = RANKS[d.killerRank]
    end
    if who and level then return who .. ", " .. level end
    return who or (level and level:gsub("^l", "L"))
end

local function shellMenu(root)
    local cause = root:CreateButton("Cause")
    local function setAll(on)
        for _, k in ipairs(causeKeys()) do state.causes[k] = on end
        refresh()
        return MenuResponse.Refresh
    end
    cause:CreateButton(CHECK_ALL, function() return setAll(true) end)
    cause:CreateButton(UNCHECK_ALL, function() return setAll(false) end)
    cause:CreateDivider()
    for _, c in ipairs(ns.CAUSES) do
        cause:CreateCheckbox(c[2], function(key) return state.causes[key] end,
            function(key) state.causes[key] = not state.causes[key] end, c[1])
    end
    root:CreateTitle("Level")
    root:CreateTemplate("LevelRangeFrameTemplate"):AddInitializer(function(range)
        range:Reset()
        if state.minLevel then range:SetMinLevel(state.minLevel) end
        if state.maxLevel then range:SetMaxLevel(state.maxLevel) end
        range:SetLevelRangeChangedCallback(function(minLevel, maxLevel)
            state.minLevel = minLevel > 0 and minLevel or nil
            state.maxLevel = maxLevel > 0 and maxLevel or nil
            page.filter:ValidateResetState()
            refresh()
        end)
    end)
end

local function buildCharacter(row)
    UI.PaneRow(row, PANE - 16)
    row:SetScript("OnClick", function(self, button)
        if button == "RightButton" then return end
        local item = self.item
        state.friend, state.friendChar, state.char, state.ruleset = item.friend, item.friendChar, item.key, nil
        if not item.friend then state.compare = nil end
        if current.key == "friends" then return Shell.Show(item.friend and "records" or "deaths") end
        refresh()
    end)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    UI.RightClickMenu(row, function(root)
        local id = row.item.friend
        local name = ns.Friends.Name(id)
        root:CreateButton(("Stop sharing with %s"):format(name), function()
            UI.Ask(("Stop sharing death counts with %s?"):format(name), "You leave each other's lists. You can ask again later.",
                function() ns.FriendsAsk.StopSharing(id) end)
        end)
    end, function(self) return self.item.friend ~= nil and not ns.Friends.IsGuildOnly(self.item.friend) end)
end

local function buildRealm(row)
    UI.PaneHeading(row)
    row:SetScript("OnClick", function(self)
        local item = self.item
        if item.group then
            state.group = state.group ~= item.group and item.group or nil
        else
            state.friend, state.friendChar, state.compare, state.char, state.ruleset = nil, nil, nil, nil, item.ruleset
            if current.key == "friends" then return Shell.Show("deaths") end
        end
        refresh()
    end)
end

local function realmTip(row, item)
    if item.group then
        if state.group == item.group then return UI.HelpTip(row, item.text, "Show everyone again.") end
        return UI.HelpTip(row, item.text, item.group == "guild" and "Show only your guild." or "Show only your friends.")
    end
    local whose = item.count == 1 and ("your %s character"):format(item.ruleset)
        or ("your %d %s characters"):format(item.count, item.ruleset)
    UI.HelpTip(row, item.text, ("Show deaths on %s."):format(whose))
end

local function fillCharacter(row, item)
    UI.FillPaneRow(row, item.name, item.color, item.level, item.deaths, item.selected, item.indent, item.faction)
end

local function bothFactions(chars)
    local seen = {}
    for _, c in pairs(chars) do if c.faction then seen[c.faction] = true end end
    return seen.Horde and seen.Alliance or false
end

local function characterTip(row, item)
    local onFriends = current.key == "friends"
    if item.friendChar then
        return UI.HelpTip(row, item.name, (onFriends and "Show %s's records." or "Show only %s's deaths."):format(item.name))
    end
    if item.friend then
        local names = {}
        for _, c in ipairs(item.chars) do names[#names + 1] = UI.CharName(c.name) .. " " .. c.level end
        local help = (onFriends and "Show %s's records." or #item.chars > 1 and "Show %s's deaths on every character."
            or "Show %s's deaths."):format(item.name)
        if not ns.Friends.IsGuildOnly(item.friend) then help = help .. "\nRight-click to stop sharing." end
        local lines = { UI.TipPair("Characters", table.concat(names, ", ")) }
        local where = not ns.FriendsLink.Online(ns.Friends.Current(item.friend)) and ns.FriendsLink.Battleground(item.friend)
        if where then
            lines[2] = ("In %s. Death Tracker can't reach anyone in a battleground, so their deaths there show up when they leave."):format(where)
        end
        return UI.Tooltip(row, item.name, item.color, lines, help)
    end
    UI.HelpTip(row, item.name, item.key and ("Show only %s's deaths."):format(item.name) or "Show deaths on every character.")
end

local function characterItems()
    local f = menuFilter()
    f.ruleset = nil
    local byRuleset, total, mixed = {}, 0, bothFactions(ns.db.characters)
    for key, c in pairs(ns.db.characters) do
        local r = ns.Ruleset(key) or "Other"
        f.char = key
        byRuleset[r] = byRuleset[r] or {}
        table.insert(byRuleset[r], { kind = "character", key = key, name = c.name, level = c.level, faction = mixed and c.faction or nil,
            color = UI.ClassColor(c.class), deaths = #ns.Deaths(f), selected = not state.friend and state.char == key })
        total = total + 1
    end
    f.char = nil
    local items = {}
    if total > 1 then
        items[1] = { kind = "character", name = "All characters", deaths = #ns.Deaths(f),
            selected = not state.friend and not state.char and not state.ruleset }
    end
    local order = {}
    for r in pairs(byRuleset) do order[#order + 1] = r end
    table.sort(order, function(a, b) return a > b end)
    for _, r in ipairs(order) do
        local chars = byRuleset[r]
        table.sort(chars, function(a, b)
            if a.deaths ~= b.deaths then return a.deaths > b.deaths end
            return a.name < b.name
        end)
        if total == 1 then chars[1].selected = not state.friend end
        local heading = r .. " realm"
        if total > 6 then heading = ("%s, %s"):format(heading, UI.Count(#chars, "character", "characters")) end
        items[#items + 1] = { kind = #order > 1 and "realm" or "heading", text = heading, ruleset = r, count = #chars,
            selected = not state.friend and state.ruleset == r and not state.char }
        for _, c in ipairs(chars) do items[#items + 1] = c end
    end
    return items
end

local function guildHint() return current.key == "friends" and ns.FriendsAsk.GuildHint() or nil end

local function friendItems(items)
    local F = ns.Friends
    local groups = { { group = "friends", text = "Friends", rows = {} }, { group = "guild", text = "Guild", rows = {} } }
    for _, rec in ipairs(F.Players()) do
        local g = F.IsGuildOnly(rec.id) and groups[2] or groups[1]
        g.rows[#g.rows + 1] = rec
    end
    local both = #groups[1].rows > 0 and #groups[2].rows > 0
    if not both then state.group = nil end
    local period = Shell.Period()
    for _, g in ipairs(groups) do
        if #g.rows > 0 then
            items[#items + 1] = { kind = both and current.key == "friends" and "realm" or "heading", text = g.text, group = g.group,
                selected = state.group == g.group }
            for _, rec in ipairs(g.rows) do
                local id = rec.id
                local several = #rec.chars > 1
                items[#items + 1] = { kind = "character", friend = id, name = F.Name(id), color = Shell.FriendColor(id), chars = rec.chars,
                    level = F.IsGuildOnly(id) and rec.chars[1] and rec.chars[1].level or nil, deaths = F.Value(rec, "deaths", period),
                    selected = state.friend == id and not (several and state.friendChar) }
                if several and state.friend == id then
                    local mixed = bothFactions(rec.chars)
                    for _, c in ipairs(rec.chars) do
                        items[#items + 1] = { kind = "character", friend = id, friendChar = c.name, name = c.name, indent = true,
                            faction = mixed and c.faction or nil,
                            color = UI.ClassColor(c.class), level = c.level, deaths = F.Value(rec, "deaths", period, c),
                            selected = state.friendChar == c.name }
                    end
                end
            end
        end
    end
    if guildHint() and #groups[2].rows == 0 then items[#items + 1] = { kind = "heading", text = "Guild" } end
    return items
end

local SECTION_GAP = 10
local function withGaps(items)
    local out = {}
    for i, item in ipairs(items) do
        if i > 1 and (item.kind == "heading" or item.kind == "realm") then out[#out + 1] = { kind = "heading" } end
        out[#out + 1] = item
    end
    return out
end

local NO_NEMESIS = "None yet"
local function nemesisLines(f)
    local char = Shell.PickedChar(f.char)
    if not char then return nil end
    local npc, name, kills, fresh = ns.Nemesis({ char = char }, 1)
    if not npc then return NO_NEMESIS, "" end
    if fresh < ns.NEMESIS_KILLS then
        return NO_NEMESIS, ("%s is %s away"):format(name, KILLS_AWAY[ns.NEMESIS_KILLS - fresh] or "close")
    end
    return name, ("%d kills, the last %s"):format(kills, UI.Ago(ns.Deaths({ char = char, npc = npc }, 1)[1].time))
end

local function friendNemesis()
    local rec = ns.Friends.Record(state.friend)
    local name, kills
    if state.friendChar then
        local c = ns.Friends.Char(rec, state.friendChar)
        name, kills = c.nemName, c.nemKills
    elseif rec.nem then
        name, kills = rec.nem.name, rec.nem.kills
    end
    if not name then return NO_NEMESIS, "" end
    return name, UI.Count(kills or 0, "kill", "kills")
end

local function buildShell()
    local inset = frame.Inset
    page = {}
    page.time = UI.Dropdown(frame, TIME_WIDTH, timePicks, timePick, function(value)
        state.time = value
        refresh()
    end)
    page.time:SetPoint("TOPLEFT", frame, "TOPLEFT", 80, -40)
    page.filter = UI.FilterButton(frame, shellMenu, shellDefault, resetFilter, function() refresh() end, resetTip)
    page.filter:SetPoint("LEFT", page.time, "RIGHT", 10, 0)
    page.showing = UI.GameText(frame, "normal", "muted")

    page.pane = UI.Box(inset, PANE)
    page.pane:SetPoint("TOPLEFT")
    page.pane:SetPoint("BOTTOMLEFT")
    local split = UI.Divider(inset, true)
    split:SetPoint("TOPLEFT", PANE, 0)
    split:SetPoint("BOTTOMLEFT", PANE, 0)
    page.characters = UI.List(page.pane, {
        character = { template = "Button", extent = 24, build = buildCharacter, fill = fillCharacter, tip = characterTip },
        heading = { template = "Frame", extent = function(item) return item.text and 24 or SECTION_GAP end,
            build = UI.PaneHeading, fill = UI.FillPaneHeading },
        -- Its own frame type: a list reuses a frame for any kind of the same type.
        realm = { template = "CheckButton", extent = 24, build = buildRealm, fill = UI.FillPaneHeading, tip = realmTip } }, 2)
    page.characters.box:SetPoint("TOPLEFT", 8, -12)
    page.characters.Fit(PANE - 16)
    page.nemesisLine = UI.Divider(page.pane)
    page.nemesisLabel = UI.GameText(page.pane, "small", "faint")
    page.nemesisLabel:SetText("Nemesis")
    page.nemesisName = UI.GameText(page.pane, "normal", "text")
    page.nemesisName:SetPoint("TOPLEFT", page.nemesisLabel, "BOTTOMLEFT", 0, -3)
    page.nemesisName:SetWidth(PANE - 32)
    page.nemesisName:SetJustifyH("LEFT")
    page.nemesisName:SetWordWrap(true)
    page.nemesisNote = UI.GameText(page.pane, "small", "muted")
    page.nemesisNote:SetPoint("TOPLEFT", page.nemesisName, "BOTTOMLEFT", 0, -3)
    page.nemesisNote:SetWidth(PANE - 32)
    page.guildNote = UI.GameText(page.pane, "small", "muted")
    page.guildNote:SetWidth(PANE - 32)
    page.guildLink = UI.Button(page.pane, "Open settings", 110, 22, function() ns.OpenOptions("friendsGuild") end)
    page.guildLink:SetPoint("TOPLEFT", page.guildNote, "BOTTOMLEFT", 0, -6)
    page.guildLink:SetScript("OnEnter", function(self)
        UI.HelpTip(self, "Open settings", "Opens Death Tracker's settings. The guild box glows until you click it.")
    end)
    page.guildLink:SetScript("OnLeave", UI.HideTooltip)

    page.right = UI.Box(inset, 1)
    page.right:SetPoint("TOPLEFT", PANE + 1, 0)
    page.right:SetPoint("BOTTOMRIGHT")
    frame.pages = {}
    for _, p in ipairs(Shell.pages) do
        local content = UI.Box(page.right, 1)
        content:SetPoint("TOPLEFT")
        content:SetPoint("BOTTOMRIGHT")
        local parts = p.Build(content)
        parts.content = content
        if p.BuildPane then
            parts.pane = UI.Box(page.pane, 1)
            parts.pane:SetAllPoints()
            p.BuildPane(parts.pane)
        end
        if p.BuildFooter then
            parts.footer = UI.Box(page.pane, FOOTER)
            parts.footer:SetPoint("BOTTOMLEFT")
            parts.footer:SetPoint("BOTTOMRIGHT")
            p.BuildFooter(parts.footer)
        end
        if parts.beside then parts.beside:SetPoint("LEFT", page.filter, "RIGHT", 10, 0) end
        frame.pages[p.key] = parts
    end
    page.details = UI.DetailsPanel(inset, DETAILS)
    page.details:SetPoint("TOPRIGHT")
    page.details:SetPoint("BOTTOMRIGHT")
    page.details:Hide()
    page.empty = UI.GameText(page.right, "normal", "text")
    page.empty:SetPoint("BOTTOM", page.right, "CENTER", 0, 2)
    page.emptyNote = UI.GameText(page.right, "small", "muted")
    page.emptyNote:SetPoint("TOP", page.right, "CENTER", 0, -4)
end

local function ownPane()
    for _, p in ipairs(Shell.pages) do
        local parts = frame.pages[p.key]
        if parts.pane then parts.pane:SetShown(p == current) end
        if parts.footer then parts.footer:SetShown(p == current) end
    end
    local own = current.RefreshPane ~= nil
    for _, t in ipairs({ page.characters.box, page.nemesisLine, page.nemesisLabel, page.nemesisName,
        page.nemesisNote, page.guildNote, page.guildLink }) do
        if own then t:Hide() else t:Show() end
    end
    if own then current.RefreshPane() end
    return own
end

local function refreshPane()
    if ownPane() then return end
    local items = withGaps(friendItems(characterItems()))
    page.characters.Set(items)
    local name, note
    if state.friend and not current.BuildFooter then
        name, note = friendNemesis()
    elseif not current.BuildFooter then
        name, note = nemesisLines(Shell.Filter())
    end
    local hint = guildHint()
    page.guildNote:SetText(hint or "")
    page.guildNote:SetShown(hint ~= nil)
    page.guildLink:SetShown(hint ~= nil)
    local hintHeight = hint and page.guildNote:GetStringHeight() + 4 + page.guildLink:GetHeight() + 8 or 0
    page.nemesisName:SetText(name or "")
    local wrapped = name and math.max(0, page.nemesisName:GetStringHeight() - UI.LineHeight((select(2, page.nemesisName:GetFont())))) or 0
    local room = HEIGHT - TOP - 16 - 12 - (name and NEMESIS_HEIGHT + wrapped or 0) - (current.BuildFooter and FOOTER or 0) - hintHeight
    local height = math.min(page.characters.Height(items), room)
    page.characters.box:SetHeight(height)
    if hint then UI.Place(page.pane, page.guildNote, 16, 12 + height + 2) end
    for _, t in ipairs({ page.nemesisLine, page.nemesisLabel, page.nemesisName, page.nemesisNote }) do t:SetShown(name ~= nil) end
    if not name then return end
    UI.Place(page.pane, page.nemesisLine, 16, 12 + height + 16)
    page.nemesisLine:SetWidth(PANE - 32)
    UI.Place(page.pane, page.nemesisLabel, 16, 12 + height + 28)
    UI.Tint(page.nemesisName, name == NO_NEMESIS and UI.COLOR.text or UI.CauseColor("mob"))
    page.nemesisNote:SetText(note)
end

function refresh()
    if state.char and not ns.db.characters[state.char] then state.char = nil end
    if state.ruleset then
        local any = false
        for key in pairs(ns.db.characters) do any = any or ns.Ruleset(key) == state.ruleset end
        if not any then state.ruleset = nil end
    end
    local friendRec = state.friend and ns.Friends.Shares(state.friend) and ns.Friends.Record(state.friend)
    if not friendRec then state.friend, state.friendChar, state.compare = nil, nil, nil end
    if state.friendChar and not ns.Friends.Char(friendRec, state.friendChar) then state.friendChar = nil end
    if state.friend then ns.FriendsLink.WantDeaths(state.friend) end
    page.time:GenerateMenu()
    page.time:SetShown(not current.noTime)
    page.filter:SetShown(not current.noFilter)
    page.filter:ValidateResetState()
    page.showing:SetText(current.Showing and current.Showing() or showing())
    refreshPane()
    local any = current.Refresh(ns.Deaths(Shell.Filter()))
    local beside = frame.pages[current.key].beside
    if current.noTime then
        page.showing:SetPoint("LEFT", page.time, "LEFT")
    elseif beside and beside:IsShown() then
        page.showing:SetPoint("LEFT", beside, "RIGHT", 16, 0)
    else
        page.showing:SetPoint("LEFT", current.noFilter and page.time or page.filter, "RIGHT", 16, 0)
    end
    showDetails()
    page.empty:SetShown(not any)
    page.emptyNote:SetShown(not any)
    if not any then
        local e, t = current.empty, timePick()
        if state.friend and #ns.Deaths({ of = state.friend, name = state.friendChar }, 1) == 0 then
            page.empty:SetText(("%s has no deaths yet."):format(Shell.FriendName()))
            page.emptyNote:SetText("")
        elseif not shellDefault() then
            page.empty:SetText(e[3])
            page.emptyNote:SetText(e[4])
        elseif t ~= "all" and not current.noFilter then
            page.empty:SetText(("No deaths %s."):format(timeOf(t).word))
            page.emptyNote:SetText("Pick a longer time to see older deaths.")
        else
            page.empty:SetText(e[1])
            page.emptyNote:SetText(e[2])
        end
    end
end
Shell.Refresh = function() refresh() end

function showDetails()
    local sel = state.details
    local open = sel ~= nil and current.Details ~= nil
    if open then
        page.details:Begin()
        open = current.Details(page.details, sel) ~= false
        if open then page.details:Done() else state.details = nil end
    end
    local width = WIDTH + (open and DETAILS or 0)
    if frame:GetWidth() ~= width then
        local left, top = frame:GetLeft(), frame:GetTop()
        if left and top then
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        end
        frame:SetWidth(width)
    end
    page.right:SetPoint("BOTTOMRIGHT", open and -DETAILS or 0, 0)
    page.details:SetShown(open)
end

function Shell.Selected() return state.details end

function Shell.ShowDetails(sel, same)
    if state.details and same and same(state.details) then state.details = nil else state.details = sel end
    refresh()
end

function Shell.DeathPick(panel, d, whose)
    local of = whose and whose.of or not whose and state.friend
    local c = of and ns.Friends.Char(ns.Friends.Record(of), d.name) or ns.db.characters[d.char]
    local who = UI.CharName(d.name) .. (d.level and " " .. UI.Colored(d.level, UI.COLOR.faint) or "")
    panel:Pick(who, c and UI.ClassColor(c.class) or UI.COLOR.text, UI.At(d.time, true),
        function() Shell.Focus({ death = d, of = whose and whose.of, mine = whose and whose.mine }) end,
        "Show this death", "Opens it on the Deaths page.")
end

function Shell.FocusButton(panel, label, focus, what)
    panel:Button(label, function() Shell.Focus(focus) end, label, ("Filters the list to every death %s."):format(what))
end

local function showPage(p)
    if not p.deathList then state.focus = nil end
    if p ~= current then state.details = nil end
    current = p
    frame:SetTitle(p.title)
    for i, other in ipairs(Shell.pages) do
        frame.pages[other.key].content:SetShown(other == p)
        frame.sideTabs[i]:SetChecked(other == p)
    end
    refresh()
    for _, other in ipairs(Shell.pages) do if other.Shown then other.Shown(other == p) end end
end

function Shell.Focus(focus)
    if focus and (focus.of or focus.mine) then state.friend, state.friendChar, state.compare = focus.of and ns.Friends.Primary(focus.of), nil, nil end
    local one = focus and focus.death
    for _, k in ipairs(FOCUS) do if k ~= "death" and focus and focus[k] ~= nil then one = nil end end
    state.focus = not one and focus or nil
    if one then
        local theirs = false
        for _, d in ipairs(state.friend and ns.Friends.Log(state.friend) or {}) do theirs = theirs or d == one end
        if not theirs then state.friend, state.friendChar, state.compare = nil, nil, nil end
        local listed = false
        for _, d in ipairs(ns.Deaths(Shell.Filter())) do listed = listed or d == one end
        if not listed then
            resetFilter()
            state.time, state.char, state.ruleset, state.friendChar = "all", nil, nil, nil
        end
    end
    for _, p in ipairs(Shell.pages) do if p.deathList then showPage(p) end end
    if one then
        state.details = { kind = "death", death = one, reveal = true }
        refresh()
    end
end

local function createWindow()
    state = {}
    resetFilter()
    frame = UI.Window(addonName .. "History", WIDTH, HEIGHT, TOP, ns.db.settings.historyPosition)
    frame:SetScale(ns.db.settings.historyScale)
    UI.ResizeGrip(frame, ns.db.settings, "historyScale", 0.6, 1.2)
    buildShell()
    for _, p in ipairs(Shell.pages) do p.tab = UI.SideTab(frame, p.icon, p.title, p.tip, function() showPage(p) end, p.Note) end
    frame.page, frame.state = page, state
    UI.RoundToPixels(frame)
    frame:HookScript("OnShow", function() refresh() end)
    frame:HookScript("OnHide", function() state.details = nil end)
    showPage(Shell.pages[1])
    ns.historyWindow = frame
end

function Shell.Current() return current end

function Shell.Show(key)
    if not frame then createWindow() end
    frame:Show()
    for _, p in ipairs(Shell.pages) do if p.key == key then showPage(p) end end
end

function ns.OpenHistory(focus)
    if not frame then createWindow() end
    frame:Show()
    Shell.Focus(focus)
end

function ns.ToggleHistory()
    if not frame then createWindow() end
    frame:SetShown(not frame:IsShown())
end

ns.OnChange(function() if frame and frame:IsShown() then refresh() end end)

SLASH_DEATHTRACKER1 = "/deathtracker"
SLASH_DEATHTRACKER2 = "/deaths"
SlashCmdList.DEATHTRACKER = function(msg)
    local command, rest = (msg or ""):match("^(%S*)%s*(.-)%s*$")
    if command == "poster" then return ns.PreviewPoster(rest) end
    -- Testing/ never ships, so players get the Friends page and no recap demo.
    if command == "friends" then
        if ns.FriendsDemo then return ns.FriendsDemo(rest) end
        return Shell.Show("friends")
    end
    if command == "trophy" then return ns.PreviewTrophy(rest) end
    if command == "card" then return ns.PreviewCard(rest) end
    if command == "recap" and ns.RecapDemo then return ns.RecapDemo(rest) end
    if command == "road" and ns.RoadDemo then return ns.RoadDemo() end
    if command == "grudge" and ns.GrudgeDemo then return ns.GrudgeDemo() end
    ns.ToggleHistory()
end
