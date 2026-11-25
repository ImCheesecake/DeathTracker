-- The wanted poster, in a spot of its own: when a mob becomes your nemesis or kills you again (once
-- a session, or once a stream with Streamer.bot), stamped when you or your party kill one (once until
-- it kills you again). Kept on screen, it stays up and follows your nemesis.
local _, ns = ...
local UI = ns.UI

local W, H, MODEL_W, MODEL_H, SIDE, DROP = 260, 354, 200, 136, 28, 6
local TROLL_GONG, STAY_DOWN, BOSS_DEFEATED, STAMP_AT, JOLT = 4654, 5781, 50111, 1, 3
local MISSION_FAILED = 43503
local LEFT_OF_CARD, BELOW_TOP = -334, -280
local WHY = { new = "YOUR NEW NEMESIS", again = "STILL AT LARGE", bounty = "YOUR NEMESIS", kept = "YOUR NEMESIS",
    escaped = "YOUR OLD NEMESIS" }
local NEMESIS_KINDS = { new = true, again = true, kept = true }
local poster, pop, slamFor, showing, modelSize, held
local thisSession = {}

local function kept() return ns.db.settings.posterKept end

local function tip(self)
    UI.Tooltip(self, self.name, UI.CauseColor("mob"), { ("Killed you %s"):format(UI.Times(self.kills)) },
        ("Show every death to %s."):format(self.name))
end

-- "Kill 2 more to collect the bounty", or once for a rare, an elite or a boss.
function ns.BountyLine(char, npc)
    local left, owed = ns.BountyLeft(char, npc)
    if owed == 1 then return "Kill it once to collect the bounty" end
    return ("Kill %d more to collect the bounty"):format(math.max(left, 1))
end

local function red(text) return UI.Colored(text, UI.COLOR.stamp) end

local function close()
    ns.db.settings.posterKept, held, ns.db.posterStamp = false, false, nil
    poster:Hide()
end

local function menu(root)
    root:CreateTitle("Wanted poster")
    UI.MenuTooltip(root:CreateCheckbox("Keep on screen", kept, function()
        ns.db.settings.posterKept = not kept()
    end), "Keep on screen", "Stays up until you close it, even after a reload. Shows your nemesis as it changes.")
    root:CreateDivider()
    root:CreateButton("Close", close)
end

local function build()
    local p = UI.Parchment(UIParent, W, H, tip, function(self)
        ns.OpenHistory({ npc = self.npc, text = "deaths to " .. self.name })
    end)
    p:SetFrameStrata("HIGH")
    UI.Shadow(p, DROP)
    local parts = {
        why = UI.QuestText(p, "body", 11),
        title = UI.QuestText(p, "title", 34),
        name = UI.QuestText(p, "title", 20),
        lines = UI.QuestText(p, "body", 13),
        divider = UI.Divider(p, false, UI.COLOR.parchmentLine),
        cost = UI.QuestText(p, "body", 12),
        close = UI.CloseButton(p, "Close this poster", close, "UIPanelCloseButton"),
    }
    parts.model, parts.creature = UI.Model(p, MODEL_W, MODEL_H)
    parts.stamp, parts.slam = UI.Stamp(p, "BOUNTY\nCOLLECTED")
    parts.escaped = UI.Stamp(p, "ESCAPED", UI.COLOR.ink)
    parts.escaped:SetPoint("CENTER", parts.model)
    UI.PlaceAcross(p, parts.why, 10, 20)
    UI.PlaceAcross(p, parts.title, 10, 34)
    UI.Place(p, parts.model, (W - MODEL_W) / 2, 80)
    UI.PlaceAcross(p, parts.name, 10, 218)
    UI.PlaceAcross(p, parts.lines, SIDE, 248)
    parts.stamp:SetPoint("CENTER", parts.model)
    parts.close:SetPoint("TOPRIGHT", -4, -4)
    parts.title:SetText("WANTED")
    parts.name:SetWidth(W - 20)
    parts.name:SetWordWrap(false)
    UI.Fit(parts.name, 1, 0.65)
    parts.lines:SetSpacing(4)
    p.parts = parts
    local scale = ns.db.settings.posterScale
    p:SetScale(scale)
    UI.Movable(p, ns.db.settings.posterPosition, "TOP", LEFT_OF_CARD / scale, BELOW_TOP / scale)
    UI.ResizeGrip(p, ns.db.settings, "posterScale", 0.6, 1.2)
    UI.RightClickMenu(p, menu)
    pop = UI.Toast(p, parts.close, function() return kept() or held end)
    poster, ns.poster = p, p
end

local function fill(char, npc, kind, place, display, who, escapedName)
    showing = { char, npc, kind, place, display, who, escapedName }
    local parts = poster.parts
    local deaths = ns.Deaths({ char = char, npc = npc })
    local name, kills = ns.db.npcNames[npc] or (deaths[1] and deaths[1].killer), #deaths
    if who then name, kills = who.name, who.kills end
    name = name or (display and "Display " .. display or "NPC " .. npc)
    local repair = 0
    for _, d in ipairs(deaths) do repair = repair + (d.repair or 0) end
    poster.npc, poster.name, poster.kills = npc, name, kills
    parts.why:SetText(WHY[kind])
    parts.name:SetText(name)
    parts.name:ScaleTextToFit()
    local faded = kind == "bounty" or kind == "escaped"
    parts.creature(npc, faded and 0.45 or 1, modelSize, display)
    parts.stamp:Hide()
    parts.escaped:SetShown(kind == "escaped")
    local lines = { ("Killed you %s"):format(UI.Times(kills)) }
    if kind == "escaped" then
        lines[2] = ("Last killed you at level %d"):format(deaths[1] and deaths[1].level or UnitLevel("player"))
    else
        if escapedName then
            lines[2] = red(("%s escaped"):format(escapedName))
        elseif NEMESIS_KINDS[kind] and npc > 0 and not who then
            lines[2] = red(ns.BountyLine(char, npc))
        end
        lines[#lines + 1] = (kind == "bounty" and "Slain in %s" or "Last seen in %s"):format(place or "?")
    end
    parts.lines:SetText(table.concat(lines, "\n"))
    local low = #lines > 2 and 20 or 0
    UI.PlaceAcross(poster, parts.divider, 44, 292 + low)
    UI.PlaceAcross(poster, parts.cost, SIDE, 304 + low - (low > 0 and 4 or 0))
    parts.cost:SetText(kind == "escaped" and "It got away. No bounty." or ("Cost you %s in repairs"):format(UI.Money(repair)))
    local bottom = kind == "escaped" or repair > 0
    parts.cost:SetShown(bottom)
    parts.divider:SetShown(bottom)
end

local function raise(char, npc, kind, place, who, escapedName)
    if not poster then build() end
    slamFor, held = nil, false
    fill(char, npc, kind, place, who and who.display, who, escapedName)
    pop()
end

local function wanted(d, kind, who, escapedName)
    raise(d.char, d.npc, kind, d.zone, who, escapedName)
    if ns.db.settings.posterSounds then PlaySound(TROLL_GONG) end
end

local function collect(char, npc, who)
    raise(char, npc, "bounty", GetRealZoneText(), who)
    local sound, this = ns.db.settings.posterSounds, {}
    slamFor = this
    if sound then PlaySound(STAY_DOWN) end
    C_Timer.After(STAMP_AT, function()
        if slamFor ~= this or not poster:IsShown() then return end
        poster.parts.slam(function()
            if sound then PlaySound(BOSS_DEFEATED) end
            UI.Offset(poster, -JOLT)
            C_Timer.After(0.1, function() if slamFor == this then UI.Offset(poster, 0) end end)
        end)
    end)
end

local function shownStore()
    if not ns.Streaming() then return thisSession, true end
    ns.db.wantedShown = ns.db.wantedShown or {}
    return ns.db.wantedShown, ns.StreamStart()
end

local function which(d, before)
    if not d.npc or ns.Nemesis({ char = d.char }) ~= d.npc then return nil end
    if before ~= d.npc then return "new" end
    return "again"
end

local function lastZone(char, npc) return ns.Deaths({ char = char, npc = npc }, 1)[1].zone end

local function escapedName(npc)
    local last = ns.Deaths({ npc = npc }, 1)[1]
    return ns.db.npcNames[npc] or (last and last.killer) or "Your nemesis"
end

local function escape(char, npc)
    raise(char, npc, "escaped", lastZone(char, npc))
    if ns.db.settings.posterSounds then PlaySound(MISSION_FAILED) end
end

local function onDeath(d, before, escaped)
    local kind = which(d, before)
    local shows = kept() or (ns.db.settings.poster and ns.CardShows())
    if escaped and kind ~= "new" then
        if not shows then return end
        -- Another mob took over on a death it didn't cause: its poster, saying the old one escaped.
        local now = ns.CharacterNemesis()
        if not now then return escape(d.char, escaped) end
        raise(d.char, now, "new", lastZone(d.char, now), nil, escapedName(escaped))
        if ns.db.settings.posterSounds then PlaySound(TROLL_GONG) end
        return
    end
    if not kind then return end
    local gone = escaped and escapedName(escaped) or nil
    if kept() then return wanted(d, kind == "new" and "new" or "kept", nil, gone) end
    if not (ns.db.settings.poster and ns.CardShows()) then return end
    local shown, key = shownStore()
    local mob = d.char .. "|" .. d.npc
    if kind == "again" and shown[mob] == key then return end
    shown[mob] = key
    wanted(d, kind, nil, gone)
end

local function onPayment(char, npc)
    if kept() or (ns.db.settings.poster and ns.CardShows()) then raise(char, npc, "kept", lastZone(char, npc)) end
end

local function onBounty(char, npc)
    if kept() then ns.db.posterStamp = { char = char, npc = npc, zone = GetRealZoneText() } end
    if kept() or (ns.db.settings.poster and ns.CardShows()) then collect(char, npc) end
end

-- Kept, the poster shows the nemesis, or the bounty stamped on it until closed, after a reload too.
local function showKept()
    local char = ns.CharacterKey()
    local npc, stamp = ns.Nemesis({ char = char }), ns.db.posterStamp
    if npc then
        ns.db.posterStamp = nil
        return raise(char, npc, "kept", lastZone(char, npc))
    end
    if stamp and stamp.char == char then
        raise(char, stamp.npc, "bounty", stamp.zone)
        poster.parts.stamp:Show()
    end
end

-- Kept, it follows the nemesis when deaths are deleted too; a collected bounty stays until closed.
local function onChange()
    if held or not (kept() and poster and poster:IsShown()) then return end
    local npc, collected = ns.CharacterNemesis(), showing[3] == "bounty"
    if not npc then
        if not collected then poster:Hide() end
    elseif npc ~= poster.npc or collected then
        showKept()
    else
        fill(showing[1], npc, showing[3], lastZone(showing[1], npc))
    end
end

function ns.CanShowWantedPoster() return ns.CharacterNemesis() ~= nil end

function ns.ShowWantedPoster()
    ns.db.settings.posterKept = true
    showKept()
end

local EXAMPLE = { npc = 5841, display = 9533, name = "Rocklance", kills = 3, level = 17, zone = "The Barrens",
    kind = "centaur" }

local function previewDeath()
    local char = ns.CharacterKey()
    local npc = ns.Nemesis({ char = char })
    local last = npc and ns.Deaths({ char = char, npc = npc }, 1)[1]
    if last then
        local d = {}
        for k, v in pairs(last) do d[k] = v end
        return d
    end
    local e = EXAMPLE
    return { char = char, npc = e.npc, cause = "mob", killer = e.name, killerLevel = e.level, zone = e.zone,
        level = UnitLevel("player"), number = e.kills, kills = e.kills,
        joke = ns.Joke({ cause = "mob", killer = e.name }, e.kind) }, e
end

-- kind: new, again or bounty; up until closed, whatever the once-only rules say. Nothing is saved.
function ns.Preview(kind)
    local d, who = previewDeath()
    if kind == "bounty" then
        collect(d.char, d.npc, who)
    else
        if kind == "new" then d.trophy = "nemesis" end
        ns.ShowCard(d, true)
        if not ns.db.settings.poster then return end
        wanted(d, kind, who)
    end
    held = true
end

-- For testing in game: /deathtracker poster new, again or bounty as the Preview buttons do, escaped
-- and paid (a kill that pays part of the bounty); size <n> is the share of its box the model fills
-- (0.9), and mob <NPC ID> or display <display ID> shows any model on it.
local PREVIEW = { new = true, again = true, bounty = true }
function ns.PreviewPoster(args)
    local kind, value = args:match("^(%S*)%s*(.-)$")
    if kind == "size" and tonumber(value) then
        modelSize = tonumber(value)
        if poster and poster:IsShown() and showing then fill(unpack(showing)) end
        return print("Death Tracker: model size " .. value)
    end
    local id = tonumber(value)
    if (kind == "mob" or kind == "display") and id then
        if not poster then build() end
        local char = ns.CharacterKey()
        local last = kind == "mob" and ns.Deaths({ char = char, npc = id }, 1)[1]
        fill(char, kind == "mob" and id or 0, "again", last and last.zone or "?", kind == "display" and id or nil)
        pop()
        held = true
        if ns.db.settings.posterSounds then PlaySound(TROLL_GONG) end
        return
    end
    if kind == "escaped" or kind == "paid" then
        local d, who = previewDeath()
        raise(d.char, d.npc, kind == "escaped" and "escaped" or "kept", d.zone, who)
        held = true
        if kind == "escaped" and ns.db.settings.posterSounds then PlaySound(MISSION_FAILED) end
        return
    end
    if not PREVIEW[kind] then
        return print("Death Tracker: /deathtracker poster new, again, bounty, escaped, paid, size <n>, mob <NPC ID> or display <ID>")
    end
    ns.Preview(kind)
end

local entered = false
ns.OnEvent("PLAYER_ENTERING_WORLD", function()
    if entered then return end
    entered = true
    if kept() then showKept() end
end)
ns.OnDeath(onDeath)
ns.OnBounty(onBounty)
ns.OnPayment(onPayment)
ns.OnChange(onChange)
