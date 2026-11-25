-- Asking to share death counts: the menu of players online with Death Tracker, "Share death counts"
-- in Blizzard's right-click menus, the Yes/No popup on the other side, and where to turn on the guild.
local _, ns = ...
local F, L, UI = ns.Friends, ns.FriendsLink, ns.UI
local A = {}
ns.FriendsAsk = A

A.LOOKING = 1            -- seconds the menu says "Looking..." while answers come in
A.NO_ANSWER = 120
A.REFUSED_FOR = 24 * 60 * 60

local asked = {}         -- player id -> true once asked this session; a late yes still counts
local waiting = {}       -- player id -> true while the 2 minutes run

-- "Ashka" for a Battle.net friend, else the character's name.
local function who(id) return F.Name(id) end

-- Where a player online with Death Tracker shows in the menu.
function A.GroupOf(id)
    local r = L.Online(id)
    if not r then return nil end
    if r.bn then return "Battle.net" end
    local k = F.Known(id)
    if k.char and C_FriendList.GetFriendInfo(k.char) then return "Friends" end
    if k.char and (UnitInParty(k.char) or UnitInRaid(k.char)) then return "Group" end
end

A.GROUPS = { "Battle.net", "Friends", "Group" }

-- Online players with Death Tracker who don't share with you yet, by group.
function A.Choices()
    local out = { ["Battle.net"] = {}, Friends = {}, Group = {} }
    for _, p in ipairs(L.OnlinePlayers()) do
        local g = A.GroupOf(p.id)
        if g and not F.Store().shared[p.id] then table.insert(out[g], p.id) end
    end
    for _, list in pairs(out) do table.sort(list, function(a, b) return who(a) < who(b) end) end
    return out
end

function A.Ask(id)
    if waiting[id] or F.Store().shared[id] then return end
    if not L.SendTo(id, "A^" .. F.Me()) then return end
    asked[id], waiting[id] = true, true
    UI.Say(("Asked %s to share death counts."):format(who(id)))
    F.AddEvent({ kind = "asked", id = id, seen = true })
    C_Timer.After(A.NO_ANSWER, function()
        if not waiting[id] then return end
        waiting[id] = nil
        UI.Say(("%s didn't answer. Ask again later."):format(who(id)))
    end)
end

local function shareWith(id)
    F.Share(id)
    L.Exchange(id)
    ns.Changed()
end

-- Where the Recent tab says a share came from.
local function how(id) return F.Known(id).tag and "Battle.net" or "Friend" end

L.On("A", function(id)
    if not A.GroupOf(id) then return end
    local s = F.Store()
    if s.shared[id] then return L.SendTo(id, "Y^" .. F.Me()) end
    if s.refused[id] and time() - s.refused[id] < A.REFUSED_FOR then return L.SendTo(id, "N^" .. F.Me()) end
    F.WhenFree(function()
        local k = F.Known(id)
        local detail = k.tag and k.char and ("%s (%s) is asking. You'd see each other's deaths on the Friends page."):format(k.tag, k.char)
            or "They're asking. You'd see each other's deaths on the Friends page."
        UI.Ask(("Share death counts with %s?"):format(who(id)), detail, function()
            L.SendTo(id, "Y^" .. F.Me())
            shareWith(id)
            F.AddEvent({ kind = "shared", id = id, how = how(id) })
        end, function()
            s.refused[id] = time()
            L.SendTo(id, "N^" .. F.Me())
        end)
    end)
end)

L.On("Y", function(id)
    if not asked[id] and not F.Store().shared[id] then return end
    local first = not F.Store().shared[id]
    asked[id], waiting[id] = nil, nil
    shareWith(id)
    if first then
        UI.Say(("%s is now sharing death counts with you."):format(who(id)))
        F.AddEvent({ kind = "shared", id = id, how = how(id) })
    end
end)

L.On("N", function(id)
    if not asked[id] then return end
    asked[id], waiting[id] = nil, nil
    UI.Say(("%s said no."):format(who(id)))
    F.AddEvent({ kind = "declined", id = id })
end)

function A.StopSharing(id)
    L.SendTo(id, "S^" .. F.Me())
    F.Unshare(id)
    ns.Changed()
end

L.On("S", function(id)
    F.Unshare(id)
    ns.Changed()
end)

A.GUILD_SETTING = "Share death counts with my guild"

local function guildmates()
    local n, guild = 0, F.GuildName()
    for _, k in pairs(F.Store().known) do
        if guild and k.inGuild == guild then n = n + 1 end
    end
    return n
end

-- While guild sharing is off and guildmates use Death Tracker: where to turn it on, else nil.
function A.GuildHint()
    local n = guildmates()
    if ns.db.settings.friendsGuild or n == 0 then return nil end
    return ("%s Death Tracker. Tick \"%s\" in the settings to see their deaths."):format(
        UI.Plural(n, "1 guildmate uses", n .. " guildmates use"), A.GUILD_SETTING)
end

L.On("hello", function()
    local hint = not ns.db.settings.friendsGuildAsked and A.GuildHint()
    if not hint then return end
    ns.db.settings.friendsGuildAsked = true
    UI.Say(hint)
end)

function A.SetGuild(on)
    ns.db.settings.friendsGuild, ns.db.settings.friendsGuildAsked = on, true
    if IsInGuild() then L.Hello({ channel = "GUILD" }, true) end
    ns.Changed()
end

-- The menu "Share with a friend" opens: who is online with Death Tracker and not sharing yet.
function A.FillMenu(root, looking)
    root:CreateTitle("Online with Death Tracker")
    if looking then return root:CreateTitle("Looking...") end
    local choices, any = A.Choices(), false
    for _, group in ipairs(A.GROUPS) do
        if #choices[group] > 0 then
            any = true
            root:CreateTitle(group)
            for _, id in ipairs(choices[group]) do
                local k = F.Known(id)
                local name = k.tag and UI.FriendName(k.tag, k.char or "")
                    or UI.Colored(k.char or who(id), UI.ClassColor(k.class) or UI.COLOR.text)
                root:CreateButton(name, function() A.Ask(id) end)
            end
        end
    end
    if not any then root:CreateTitle("No one online has Death Tracker.") end
end

-- The player a right-click menu is about, if they're online with Death Tracker and not sharing yet.
local function playerIn(contextData)
    local gameAccount
    if contextData.bnetIDAccount then
        local a = C_BattleNet.GetAccountInfoByID(contextData.bnetIDAccount)
        gameAccount = a and a.gameAccountInfo and a.gameAccountInfo.gameAccountID
    end
    local name = contextData.unit and UnitName(contextData.unit) and NameUtil.GetFullNameWithoutRealm(UnitName(contextData.unit))
        or contextData.name
    for _, p in ipairs(L.OnlinePlayers()) do
        local match = (gameAccount and p.route.bn == gameAccount) or (name and p.route.name == name)
        if match and not F.Store().shared[p.id] and A.GroupOf(p.id) then return p.id end
    end
end

local function addToMenu(_, root, contextData)
    local id = contextData and playerIn(contextData)
    if not id then return end
    local button = MenuUtil.CreateButton("Share death counts", function() A.Ask(id) end)
    for i, element in root:EnumerateElementDescriptions() do
        if MenuUtil.GetElementText(element) == WHISPER then return root:Insert(button, i + 1) end
    end
    root:Insert(button)
end

for _, which in ipairs({ "BN_FRIEND", "FRIEND", "PARTY", "RAID_PLAYER", "PLAYER" }) do
    Menu.ModifyMenu("MENU_UNIT_" .. which, addToMenu)
end

