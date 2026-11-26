local _, ns = ...
local UI, F, L, G, FA = ns.UI, ns.Friends, ns.FriendsLink, ns.Grudge, ns.FriendsAlerts
local R = {}
ns.Revenge = R

local function friendNames(friends)
    if #friends >= FA.MANY then return ("%d friends"):format(#friends) end
    local names = {}
    for i, f in ipairs(friends) do names[i] = G.FriendName(f) end
    return UI.AndList(names)
end

local function deathsOf(friends)
    local n = 0
    for _, f in ipairs(friends) do n = n + #f.deaths end
    return n
end

function R.Show(name, v, classFile)
    local killer = G.Painted(name, classFile)
    if #v.you + #v.alts > 0 then
        FA.Revenge(killer, table.concat(G.Rows(v, true), " "))
    else
        FA.YouAvenged(friendNames(v.friends),
            UI.Muted("Killed ") .. killer .. UI.Muted((", who killed them %s"):format(UI.Times(deathsOf(v.friends)))))
    end
end

function R.ShowAvenged(friend, name, classFile, n)
    FA.AvengedYou(friend, UI.Muted("Killed ") .. G.Painted(name, classFile) .. UI.Muted((", who killed you %s"):format(UI.Times(n))))
end

local function avenge(name, classFile, friends)
    local zone = GetRealZoneText() or ""
    for _, f in ipairs(friends) do
        local id, n = f.id, #f.deaths
        L.SendTo(id, ("V^%s^%s^%s^%s"):format(F.Me(), F.Clean(name), F.Clean(classFile), F.Clean(zone)), function()
            F.AddEvent({ kind = "avengedBy", id = id, player = name, class = classFile, n = n, zone = zone })
            F.Avenged(id)
            ns.Trophies.Fact("avenger", { id = id })
        end)
    end
end

ns.OnEvent("PARTY_KILL", function(attacker, target)
    if issecretvalue(attacker) or issecretvalue(target) or attacker ~= UnitGUID("player") then return end
    local who = G.Known(target)
    if not who then return end
    local v = G.Victims(who.name)
    if not v.any then return end
    -- Blizzard blocks addon messages inside a battleground, so friends can't be told they were avenged there.
    if ns.InBattle() then v.friends = {} end
    if #v.you + #v.alts + #v.friends == 0 then return end
    R.Show(who.name, v, who.class)
    avenge(who.name, who.class, v.friends)
end)

L.On("V", function(id, p)
    local name = p[3]
    if not name or name == "" or ns.InBattle() then return end
    local n = #ns.Deaths({ player = name, since = time() - G.DAYS * 86400, noBattle = true })
    if n == 0 then return end
    local classFile = p[4] ~= "" and p[4] or nil
    F.AddEvent({ kind = "avenged", id = id, player = name, class = classFile, n = n, zone = p[5] })
    R.ShowAvenged(FA.ClassName(id), name, classFile, n)
    ns.Trophies.Fact("avenged", { id = id })
end)
