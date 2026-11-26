local _, ns = ...
local F = ns.Friends
local L = {}
ns.FriendsLink = L

L.PREFIX = "DeathTracker"
L.PIECE = 200        -- a message holds 255 bytes with its header
L.GAP = 0.15         -- Blizzard throttles a burst
L.RETRY = 1
L.HAVE_EACH = 12
L.PIECES_KEPT = 60
L.DEATHS_EACH = 8

local online = {}
local wants = {}
local greeted = {}
local pieces = {}
local handlers = {}
local queue, bulk, sending = {}, {}, false
local bulkFor = {}

local function routeKey(r) return r.bn and ("bn" .. r.bn) or r.name and ("w" .. r.name) or r.channel end

L.DROPS_KEPT = 10

local function drop(id, why, result)
    local route = online[id]
    if not route then return end
    greeted[routeKey(route)] = nil
    online[id] = nil
    local s = F.Store()
    s.drops = s.drops or {}
    table.insert(s.drops, { id = id, why = why, result = result, route = routeKey(route), at = time() })
    while #s.drops > L.DROPS_KEPT do table.remove(s.drops, 1) end
end

-- Enum.SendAddonMessageResult: AddonMessageThrottle, ChannelThrottle; TargetRequired, TargetOffline.
local THROTTLED = { [3] = true, [8] = true }
local OFFLINE = { [6] = true, [12] = true }

-- An addon whisper to a player who logged off returns Success; the server answers a moment later
-- with Blizzard's yellow "No player named" line.
L.MISSED_FOR = 10
local whispered = {}

local pump
local function sendNow(item)
    local r = item.route
    if r.bn then return C_BattleNet.SendGameData(r.bn, L.PREFIX, item.text) end
    if r.name then
        whispered[r.name:lower()] = GetTime()
        return C_ChatInfo.SendAddonMessage(L.PREFIX, item.text, "WHISPER", r.name)
    end
    return C_ChatInfo.SendAddonMessage(L.PREFIX, item.text, r.channel)
end

pump = function()
    local item = table.remove(queue, 1) or table.remove(bulk, 1)
    if not item then sending = false return end
    local result = sendNow(item)
    if THROTTLED[result] then
        table.insert(item.bulk and bulk or queue, 1, item)
        return C_Timer.After(L.RETRY, pump)
    end
    if item.bulk then
        local key = routeKey(item.route)
        bulkFor[key] = bulkFor[key] - 1
        if bulkFor[key] == 0 then bulkFor[key] = nil end
    end
    if OFFLINE[result] and item.id then drop(item.id, "send", result) end
    C_Timer.After(L.GAP, pump)
end

local function enqueue(route, text, id, isBulk)
    if isBulk then
        bulk[#bulk + 1] = { route = route, text = text, id = id, bulk = true }
        bulkFor[routeKey(route)] = (bulkFor[routeKey(route)] or 0) + 1
    else
        queue[#queue + 1] = { route = route, text = text, id = id }
    end
    if not sending then
        sending = true
        pump()
    end
end
L.Send = enqueue

function L.On(kind, fn)
    handlers[kind] = handlers[kind] or {}
    table.insert(handlers[kind], fn)
end

local function emit(kind, ...)
    for _, fn in ipairs(handlers[kind] or {}) do fn(...) end
end

local function bare(text) return ((text or ""):gsub("%^", "")) end

local accountOf

local function hello(route, reply, guild)
    local name = NameUtil.GetFullNameWithoutRealm(UnitName("player"))
    local whole = route.bn and F.SharesAccount(accountOf(route.bn))
    enqueue(route, table.concat({ "H", F.Me(), reply and 1 or 0, ns.db.settings.friendsGuild and 1 or 0,
        bare(name), select(2, UnitClass("player")) or "", UnitLevel("player"),
        (guild or route.channel == "GUILD") and bare(F.GuildName()) or "", whole and 1 or 0 }, "^"))
end
L.Hello = hello

local function zoneTo(route) enqueue(route, "Z^" .. F.Me() .. "^" .. bare(GetRealZoneText())) end

---@param wire string
local function recordTo(route, id, wire)
    local key = id .. ":" .. wire:match("^[^%^]+%^(%d+)")
    local n = math.ceil(#wire / L.PIECE)
    for i = 1, n do
        enqueue(route, ("R^%s^%d^%d^%s"):format(key, i, n, wire:sub((i - 1) * L.PIECE + 1, i * L.PIECE)), id)
    end
end

local function askDeaths(id, route)
    if route.demo then return end
    local count, newest = F.Holding(id)
    enqueue(route, ("W^%s^%d^%d"):format(F.Me(), count, newest))
end

local function deathsTo(route, count, newest)
    local all, me = ns.db.deaths, F.Me()
    if bulkFor[routeKey(route)] then return end
    local from = count > 0 and all[count] and all[count].time == newest and count + 1 or 1
    if from > #all and (from > 1 or count == 0) then return end
    for start = from, math.max(from, #all), L.DEATHS_EACH do
        local texts = {}
        for i = start, math.min(#all, start + L.DEATHS_EACH - 1) do texts[#texts + 1] = F.DeathText(all[i]) end
        local body, key = table.concat(texts, "~"), ("%s:%d:%d"):format(me, start, #all)
        local n = math.max(1, math.ceil(#body / L.PIECE))
        for i = 1, n do enqueue(route, ("D^%s^%d^%d^%s"):format(key, i, n, body:sub((i - 1) * L.PIECE + 1, i * L.PIECE)), nil, true) end
    end
end

local asked = {}
function L.WantDeaths(person)
    for _, id in ipairs(F.Ids(person)) do
        if not (F.WantsDeaths(id) and asked[id]) then
            F.WantDeaths(id)
            local route = L.Online(id)
            if route and not route.demo then
                asked[id] = true
                askDeaths(id, route)
            end
        end
    end
end

local function have(route)
    local s, list = F.Store(), {}
    for id in pairs(s.shared) do list[#list + 1] = id .. ":" .. (s.players[id] and s.players[id].v or 0) end
    for id in pairs(s.known) do
        if not s.shared[id] and F.Shares(id) then list[#list + 1] = id .. ":" .. (s.players[id] and s.players[id].v or 0) end
    end
    table.sort(list)
    for i = 1, math.max(#list, 1), L.HAVE_EACH do
        enqueue(route, "V^" .. F.Me() .. "^" .. table.concat(list, "~", i, math.min(i + L.HAVE_EACH - 1, #list)))
    end
    zoneTo(route)
end

function L.BattleNetFriends()
    local out = {}
    for i = 1, BNGetNumFriends() do
        for j = 1, C_BattleNet.GetFriendNumGameAccounts(i) do
            local g = C_BattleNet.GetFriendGameAccountInfo(i, j)
            if g and g.isOnline and g.clientProgram == BNET_CLIENT_WOW and g.wowProjectID == WOW_PROJECT_ID then
                out[#out + 1] = { bn = g.gameAccountID, account = i, char = g.characterName }
            end
        end
    end
    return out
end

-- Never the account name: for a Real ID friend it's their real name.
local function tagOf(account)
    local a = C_BattleNet.GetFriendAccountInfo(account)
    return a and a.battleTag and a.battleTag:match("^([^#]+)")
end

function L.TagOf(gameAccountID)
    for _, g in ipairs(L.BattleNetFriends()) do
        if g.bn == gameAccountID then return tagOf(g.account) end
    end
end

accountOf = function(gameAccountID)
    for _, g in ipairs(L.BattleNetFriends()) do
        if g.bn == gameAccountID then
            local a = C_BattleNet.GetFriendAccountInfo(g.account)
            return a and a.battleTag
        end
    end
end
L.AccountOf = accountOf

function L.AccountByTag(tag)
    local found
    for i = 1, BNGetNumFriends() do
        local a = C_BattleNet.GetFriendAccountInfo(i)
        if a and a.battleTag and a.battleTag:match("^([^#]+)") == tag then
            if found then return nil end
            found = a.battleTag
        end
    end
    return found
end

local function candidates()
    local out = L.BattleNetFriends()
    for i = 1, C_FriendList.GetNumFriends() do
        local f = C_FriendList.GetFriendInfoByIndex(i)
        if f and f.connected and f.name then out[#out + 1] = { name = f.name } end
    end
    if IsInGroup() then out[#out + 1] = { channel = IsInRaid() and "RAID" or "PARTY" } end
    if IsInGuild() then out[#out + 1] = { channel = "GUILD" } end
    return out
end

function L.Greet(all)
    for _, route in ipairs(candidates()) do
        local key = routeKey(route)
        if all or not greeted[key] then
            greeted[key] = true
            hello(route, false)
        end
    end
end

local function stillOnline(route)
    if route.demo then return F.IsDemo(), "demo" end
    if route.bn then
        local g = C_BattleNet.GetGameAccountInfoByID(route.bn)
        return g ~= nil and g.isOnline, "battlenet"
    end
    local f = C_FriendList.GetFriendInfo(route.name)
    return not f or f.connected, "friendslist"
end

local function prune()
    for id, route in pairs(online) do
        local ok, why = stillOnline(route)
        if not ok then drop(id, why) end
    end
end

-- In a match addon messages are locked both ways, so a friend's Death Tracker can't answer there;
-- Blizzard's friends list still says where they are.
local BATTLEGROUNDS_FOR = 30
local battlegrounds, battlegroundsAt
function L.Battleground(id)
    local k = F.Store().known[id]
    if not (k and k.tag) then return nil end
    if not battlegroundsAt or GetTime() - battlegroundsAt > BATTLEGROUNDS_FOR then
        battlegrounds, battlegroundsAt = {}, GetTime()
        for _, g in ipairs(L.BattleNetFriends()) do
            local tag, info = tagOf(g.account), C_BattleNet.GetGameAccountInfoByID(g.bn)
            if tag and info and ns.BattleZone(info.areaName) then battlegrounds[tag] = info.areaName end
        end
    end
    return battlegrounds[k.tag]
end

function L.Online(id)
    local route = online[id]
    if not route then return nil end
    local ok, why = stillOnline(route)
    if ok then return route end
    drop(id, why)
end

function L.OnlinePlayers()
    prune()
    local out = {}
    for id, route in pairs(online) do out[#out + 1] = { id = id, route = route } end
    return out
end

function L.Pretend(id) online[id] = { demo = true } end

local function reachFor(id)
    local k, out = F.Store().known[id], {}
    if not k then return out end
    for _, g in ipairs(L.BattleNetFriends()) do
        if k.tag and tagOf(g.account) == k.tag then out[#out + 1] = { bn = g.bn } end
    end
    local f = k.char and C_FriendList.GetFriendInfo(k.char)
    if f and f.connected then out[#out + 1] = { name = k.char } end
    return out
end

L.WAIT = 30
local waiting = {}

function L.SendTo(id, text, onSent)
    local route = L.Online(id)
    if route then
        if not route.demo then enqueue(route, text, id) end
        if onSent then onSent() end
        return true
    end
    if not onSent then return false end
    local list = {}
    for _, w in ipairs(waiting[id] or {}) do
        if GetTime() - w.at <= L.WAIT then
            if w.text == text then return false end
            list[#list + 1] = w
        end
    end
    list[#list + 1] = { text = text, onSent = onSent, at = GetTime() }
    waiting[id] = list
    for _, r in ipairs(reachFor(id)) do
        greeted[routeKey(r)] = true
        hello(r, false)
    end
    return false
end

local function sendWaiting(id)
    local route, list = online[id], waiting[id]
    if not (route and list) then return end
    waiting[id] = nil
    for _, w in ipairs(list) do
        if GetTime() - w.at <= L.WAIT then
            enqueue(route, w.text, id)
            w.onSent()
        end
    end
end

function L.Broadcast()
    if not next(online) then return end
    local me, wire = F.Me(), nil
    for id, route in pairs(online) do
        if wants[id] and wants[id][me] and F.Shares(id) then
            wire = wire or select(2, F.Mine())
            recordTo(route, me, wire)
        end
    end
end

function L.Exchange(id)
    local route = L.Online(id)
    if route then have(route) end
end

F.OnUnshare(function(id) wants[id] = nil end)

local function direct(route, sender)
    if not route.channel then return route end
    return sender and { name = sender }
end

local function trusted(id, from)
    return id ~= nil and online[id] ~= nil and routeKey(online[id]) == routeKey(from)
end

local receive = {}

function receive.H(route, p, sender)
    local id, from = p[2], direct(route, sender)
    if not id or id == F.Me() or not from then return end
    local now = online[id]
    if from.bn or not now or not now.bn then online[id] = from end
    if not trusted(id, from) then return end
    local k = F.Known(id)
    k.char, k.class, k.level, k.seen = p[5], p[6] ~= "" and p[6] or nil, tonumber(p[7]), time()
    if from.bn then k.tag, k.account = L.TagOf(from.bn) or k.tag, accountOf(from.bn) or k.account end
    -- Over Battle.net, Blizzard names the sender's account, so a share made from any of our WoW accounts holds here too.
    if from.bn and p[9] == "1" and not F.Shares(id) and k.account and not (F.Store().stopped or {})[k.account] then
        F.Share(id)
        F.AddEvent({ kind = "shared", id = id, how = "Battle.net" })
    end
    if route.channel == "GUILD" or p[8] ~= "" then
        local before, guild = F.Shares(id), F.GuildName()
        k.inGuild = guild and p[8] == guild and guild or nil
        k.guild = p[4] == "1" and k.inGuild or nil
        if not before and F.Shares(id) then F.AddEvent({ kind = "shared", id = id, how = "Guild" }) end
    end
    if p[3] == "0" then hello(from, true, k.inGuild ~= nil) end
    if F.Shares(id) then
        have(from)
        if F.WantsDeaths(id) then askDeaths(id, from) end
    end
    sendWaiting(id)
    emit("hello", id)
end

function receive.Z(route, p, sender)
    local id = p[2]
    if trusted(id, direct(route, sender)) and F.Shares(id) then F.Known(id).zone = p[3] end
end

function receive.V(route, p, sender)
    local from, to = p[2], direct(route, sender)
    if not trusted(from, to) or not F.Shares(from) then return end
    wants[from] = wants[from] or {}
    local s, me = F.Store(), F.Me()
    for pair in (p[3] or ""):gmatch("[^~]+") do
        local id, v = pair:match("^(.+):(%d+)$")
        if id then
            wants[from][id] = true
            v = tonumber(v)
            if id == me then
                local rec, wire = F.Mine()
                if rec.v > v then recordTo(to, me, wire) end
            elseif F.Shares(id) and s.players[id] and s.players[id].v > v and s.players[id].wire then
                recordTo(to, id, s.players[id].wire)
            end
        end
    end
end

function receive.W(route, p, sender)
    local from, to = p[2], direct(route, sender)
    if trusted(from, to) and F.Shares(from) then deathsTo(to, tonumber(p[3]) or 0, tonumber(p[4]) or 0) end
end

local function piecesFor(slot)
    local now = time()
    for key, got in pairs(pieces) do
        if now - got.at > L.PIECES_KEPT then pieces[key] = nil end
    end
    pieces[slot] = pieces[slot] or { count = 0, at = now }
    return pieces[slot]
end

function receive.R(route, p, sender, text)
    local key, i, n = p[2], tonumber(p[3]), tonumber(p[4])
    if not (key and i and n) or i < 1 or i > n then return end
    local slot = routeKey(route) .. (sender or "") .. key
    local got = piecesFor(slot)
    if not got[i] then got[i], got.count = text:match("^R%^[^%^]+%^%d+%^%d+%^(.*)$") or "", got.count + 1 end
    if got.count < n then return end
    pieces[slot] = nil
    local wire = table.concat(got, "", 1, n)
    local rec = F.Parse(wire)
    if not rec then return end
    rec.wire = wire
    local changes = F.Take(rec)
    if not changes then return end
    for peer, r in pairs(online) do
        if peer ~= rec.id and F.Shares(peer) and wants[peer] and wants[peer][rec.id] and routeKey(r) ~= routeKey(route) then
            recordTo(r, rec.id, wire)
        end
    end
    local owner = L.Online(rec.id)
    if owner and F.WantsDeaths(rec.id) then askDeaths(rec.id, owner) end
    emit("record", rec, changes)
    ns.Changed()
end

function receive.D(route, p, sender, text)
    local key, i, n = p[2], tonumber(p[3]), tonumber(p[4])
    local owner, from, total = (key or ""):match("^(.-):(%d+):(%d+)$")
    if not (owner and i and n) or i < 1 or i > n or not trusted(owner, direct(route, sender)) or not F.Shares(owner) then return end
    local slot = "D" .. routeKey(route) .. (sender or "") .. key
    local got = piecesFor(slot)
    if not got[i] then got[i], got.count = text:match("^D%^[^%^]+%^%d+%^%d+%^(.*)$") or "", got.count + 1 end
    if got.count < n then return end
    pieces[slot] = nil
    if F.TakeDeathsText(owner, tonumber(from), tonumber(total), table.concat(got, "", 1, n)) then ns.Changed() end
end

local function dispatch(route, text, sender)
    local p = {}
    for field in (text .. "^"):gmatch("(.-)%^") do p[#p + 1] = field end
    local fn = receive[p[1]]
    if fn then return fn(route, p, sender, text) end
    if handlers[p[1]] and trusted(p[2], direct(route, sender)) then emit(p[1], p[2], p) end
end

C_ChatInfo.RegisterAddonMessagePrefix(L.PREFIX)

local GREET_AFTER = 5
local inBattle = false
-- No addon message crosses a battleground's walls: leaving one, greet every friend again to catch up.
ns.OnEvent("PLAYER_ENTERING_WORLD", function()
    local left = inBattle and not ns.InBattle()
    inBattle = ns.InBattle()
    C_Timer.After(GREET_AFTER, function() L.Greet(left) end)
end)
ns.OnEvent("CHAT_MSG_ADDON", function(prefix, text, channel, sender)
    if prefix ~= L.PREFIX then return end
    if channel == "WHISPER" then return dispatch({ name = sender }, text, sender) end
    dispatch({ channel = channel }, text, sender)
end)
ns.OnEvent("BN_CHAT_MSG_ADDON", function(prefix, text, _, gameAccountID)
    if prefix == L.PREFIX then dispatch({ bn = gameAccountID }, text) end
end)
-- GROUP_ROSTER_UPDATE comes in bursts (every join, leave and loot setting).
local GROUP_SETTLE = 3
local groupPending = false
ns.OnEvent("GROUP_ROSTER_UPDATE", function()
    if groupPending then return end
    groupPending = true
    C_Timer.After(GROUP_SETTLE, function()
        groupPending = false
        if IsInGroup() then hello({ channel = IsInRaid() and "RAID" or "PARTY" }, false) end
    end)
end)
ns.OnEvent("BN_FRIEND_INFO_CHANGED", function()
    battlegroundsAt = nil
    L.Greet()
end)
ns.OnEvent("FRIENDLIST_UPDATE", function() L.Greet() end)
ns.OnEvent("ZONE_CHANGED_NEW_AREA", function()
    for id, route in pairs(online) do
        if F.Shares(id) then zoneTo(route) end
    end
end)
ns.OnDeath(function() C_Timer.After(1, L.Broadcast) end)

local function missed(text)
    if type(text) ~= "string" or issecretvalue(text) then return nil end
    local line = text:lower()
    for name, at in pairs(whispered) do
        if GetTime() - at > L.MISSED_FOR then
            whispered[name] = nil
        elseif line == ERR_CHAT_PLAYER_NOT_FOUND_S:format(name):lower() then
            return name
        end
    end
end

local function unqueue(list, name)
    for i = #list, 1, -1 do
        local r = list[i].route
        if r.name and r.name:lower() == name then
            if list[i].bulk then bulkFor[routeKey(r)] = nil end
            table.remove(list, i)
        end
    end
end

ns.OnEvent("CHAT_MSG_SYSTEM", function(text)
    local name = missed(text)
    if not name then return end
    for id, route in pairs(online) do
        if route.name and route.name:lower() == name then drop(id, "whisper") end
    end
    unqueue(queue, name)
    unqueue(bulk, name)
end)
ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_SYSTEM", function(_, _, text) return missed(text) ~= nil end)
