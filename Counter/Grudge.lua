-- The grudge warning: a player who killed you, your other characters or friends twice in the last 7 days,
-- outside battlegrounds and arenas, comes into view (target, mouse-over or nameplate): a raid warning, a
-- horn and a line in chat, only the line inside a battleground. Friends who share counts get a chat line.
local _, ns = ...
local UI, F, L = ns.UI, ns.Friends, ns.FriendsLink
local G = {}
ns.Grudge = G

G.DAYS = 7
G.DEATHS = 2         -- one kill is how the game goes; a second one, on you or a friend, makes a grudge
G.AGAIN = 600        -- seconds before the same player warns again
G.SHOWN = 8          -- the display time: held 5 seconds, then Blizzard's 3-second fade
G.POP = 40
G.HORN = { Horde = 8212, Alliance = 8174 }
G.LOOK_AGAIN = 60    -- seconds before a player who killed no one is looked up again

local warned, looked, names = {}, {}, {}
local frame

-- Whom a player killed in the last G.DAYS days: you (this character), your other characters and friends
-- who share counts, newest death first in each.
function G.Victims(name)
    local since, me = time() - G.DAYS * 86400, ns.CharacterKey()
    local v = { you = {}, alts = {}, friends = {} }
    for _, d in ipairs(ns.Deaths({ player = name, since = since, noBattle = true })) do
        table.insert(d.char == me and v.you or v.alts, d)
    end
    for _, rec in ipairs(F.Players()) do
        local list = ns.Deaths({ of = rec.id, player = name, since = since, noBattle = true })
        if #list > 0 then v.friends[#v.friends + 1] = { id = rec.id, deaths = list } end
    end
    table.sort(v.friends, function(a, b) return a.deaths[1].time > b.deaths[1].time end)
    local total = #v.you + #v.alts
    for _, f in ipairs(v.friends) do total = total + #f.deaths end
    v.any = total >= G.DEATHS
    return v
end

local function painted(name, class)
    local color = UI.ClassColor(class)
    name = UI.CharName(name)
    return color and UI.Colored(name, color) or name
end

-- A friend's character that died, in its class colour.
local function friendName(f)
    local c = f.id and F.Char(F.Record(f.id), f.deaths[1].name)
    return painted(f.deaths[1].name, f.class or (c and c.class))
end
local function ownClass(d) return (ns.db.characters[d.char] or {}).class end
G.Painted = painted

local function friendWord(f) return "your friend " .. friendName(f) end
G.FriendName = friendName

-- One other character, by name; deaths of several: nil.
local function oneAlt(alts)
    for _, d in ipairs(alts) do if d.name ~= alts[1].name then return nil end end
    return painted(alts[1].name, ownClass(alts[1]))
end

-- The rows under "<name> is near.": "They killed you 2 times" / "and your friend Grimtusk once"; several
-- friends: "and 3 of your friends". named: one other character by its name.
function G.Rows(v, named)
    local parts = {}
    if #v.you > 0 then parts[#parts + 1] = "you " .. UI.Times(#v.you) end
    if #v.alts > 0 then
        parts[#parts + 1] = (named and oneAlt(v.alts) or "your other characters") .. " " .. UI.Times(#v.alts)
    end
    if #v.friends == 1 then
        parts[#parts + 1] = friendWord(v.friends[1]) .. " " .. UI.Times(#v.friends[1].deaths)
    elseif #v.friends > 1 then
        parts[#parts + 1] = ("%d of your friends"):format(#v.friends)
    end
    local rows = { "They killed " .. parts[1] }
    if #parts > 1 then rows[2] = "and " .. UI.AndList({ unpack(parts, 2) }) end
    return rows
end

local function last(d) return (", last time %s in %s"):format(UI.Date(d.time), d.zone or "?") end

-- After a part with its own commas ("you once, last time today in Duskwood"), the last "and" takes one too.
local function andList(parts)
    local text = UI.AndList(parts)
    if #parts > 1 and parts[1]:find(",") then
        text = table.concat(parts, ", ", 1, #parts - 1) .. ", and " .. parts[#parts]
    end
    return text
end

-- The chat line names everyone; the first one named says when and where.
function G.ChatLine(name, v)
    local parts = {}
    if #v.you > 0 then parts[#parts + 1] = "you " .. UI.Times(#v.you) .. last(v.you[1]) end
    local alts, order = {}, {}
    for _, d in ipairs(v.alts) do
        if not alts[d.name] then order[#order + 1] = d.name end
        alts[d.name] = alts[d.name] or { n = 0, d = d }
        alts[d.name].n = alts[d.name].n + 1
    end
    for _, alt in ipairs(order) do
        local a = alts[alt]
        parts[#parts + 1] = painted(alt, ownClass(a.d)) .. " " .. UI.Times(a.n) .. (#parts == 0 and last(a.d) or "")
    end
    local friends = {}
    for _, f in ipairs(v.friends) do
        local first = #parts == 0 and #friends == 0
        friends[#friends + 1] = (#v.friends == 1 and friendWord(f) or friendName(f)) .. " " .. UI.Times(#f.deaths)
            .. (first and last(f.deaths[1]) or "")
    end
    if #friends == 1 then
        parts[#parts + 1] = friends[1]
    elseif #friends > 1 then
        friends[1] = "your friends " .. friends[1]
        parts[#parts + 1] = UI.AndList(friends)
    end
    return ("%s is near. They killed %s."):format(name, andList(parts))
end

function G.Show(name, v, classFile)
    local shown = painted(name, classFile)
    if ns.InBattle() then return UI.Say(G.ChatLine(shown, v)) end
    frame = frame or UI.RaidWarning(G.POP)
    frame:Warn(shown .. " is near.\n" .. table.concat(G.Rows(v), "\n") .. ".", G.SHOWN)
    PlaySound(G.HORN[UnitFactionGroup("player")] or G.HORN.Alliance)
    UI.Say(G.ChatLine(shown, v))
end

-- Who to name to friends, with its class: you, else the character it killed, else the friend.
local function victimOf(v)
    if #v.you > 0 then return v.you[1].name, #v.you, ownClass(v.you[1]) end
    if #v.alts > 0 then return v.alts[1].name, #v.alts, ownClass(v.alts[1]) end
    local f = v.friends[1]
    local c = f.id and F.Char(F.Record(f.id), f.deaths[1].name)
    return f.deaths[1].name, #f.deaths, f.class or (c and c.class)
end

local function tellFriends(name, v, classFile)
    local victim, n, victimClass = victimOf(v)
    local zone = GetRealZoneText() or ""
    for id in pairs(F.Store().players) do
        if F.Shares(id) and not F.InGroup(id) and L.Online(id) then
            L.SendTo(id, ("K^%s^%s^%s^%s^%d^%s^%s"):format(F.Me(), F.Clean(name), F.Clean(zone), F.Clean(victim), n,
                F.Clean(classFile), F.Clean(victimClass)))
        end
    end
end

function G.Check(name, classFile)
    local now = time()
    if (warned[name] and now - warned[name] < G.AGAIN) or (looked[name] and now - looked[name] < G.LOOK_AGAIN) then
        return
    end
    looked[name] = now
    local v = G.Victims(name)
    if not v.any then return end
    warned[name] = now
    G.Show(name, v, classFile)
    if not ns.InBattle() then tellFriends(name, v, classFile) end
end

-- Revenge reads the name here: PARTY_KILL gives only the GUID.
function G.Known(guid) return names[guid] end

local function seen(unit)
    local player, enemy = UnitIsPlayer(unit), UnitCanAttack("player", unit)
    if issecretvalue(player) or issecretvalue(enemy) or not player or not enemy then return end
    local first, surname = UnitName(unit)
    if not first or issecretvalue(first) or issecretvalue(surname) then return end
    local _, classFile = UnitClass(unit)
    local name, guid = NameUtil.GetFullNameWithoutRealm(first, surname), UnitGUID(unit)
    classFile = not issecretvalue(classFile) and classFile or nil
    if guid and not issecretvalue(guid) then names[guid] = { name = name, class = classFile } end
    if ns.db.settings.grudge then G.Check(name, classFile) end
end

ns.OnEvent("PLAYER_TARGET_CHANGED", function() seen("target") end)
ns.OnEvent("UPDATE_MOUSEOVER_UNIT", function() seen("mouseover") end)
ns.OnEvent("NAME_PLATE_UNIT_ADDED", seen)

-- A friend saw a player who killed one of you: "Jugger Stormhammer is near Grimtusk in Duskwood. They killed you 3 times."
-- mine: how often it killed you (any character) lately; else the friend's count for victim. Names come painted.
function G.FriendLine(name, friend, zone, victim, n, mine)
    local killed = mine > 0 and "you " .. UI.Times(mine) or victim .. " " .. UI.Times(n)
    return ("%s is near %s in %s. They killed %s."):format(name, friend, zone, killed)
end

L.On("K", function(id, p)
    if not ns.db.settings.grudge or not F.Shares(id) then return end
    local name, zone, victim, n = p[3], p[4], p[5], tonumber(p[6]) or 0
    if not name or name == "" then return end
    local mine = #ns.Deaths({ player = name, since = time() - G.DAYS * 86400, noBattle = true })
    local k = F.Known(id)
    UI.Say(G.FriendLine(painted(name, p[7] ~= "" and p[7] or nil), painted(k.char or F.Name(id), k.class),
        zone ~= "" and zone or "?", painted(victim ~= "" and victim or "?", p[8] ~= "" and p[8] or nil), n, mine))
end)

-- The settings' Preview: a player who killed you twice, nothing saved or sent.
function G.Preview()
    local d = { name = "you", time = time() - 86400, zone = "Duskwood" }
    G.Show("Jugger Stormhammer", { you = { d, d }, alts = {}, friends = {} }, "SHAMAN")
end
