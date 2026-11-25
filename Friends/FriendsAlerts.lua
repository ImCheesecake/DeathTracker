local _, ns = ...
local UI, F, L = ns.UI, ns.Friends, ns.FriendsLink
local FA = {}
ns.FriendsAlerts = FA

FA.FRESH = 60
FA.MERGE = 10
FA.QUIET = 30
FA.HOLD = 5
FA.MILESTONE = 50
FA.AWAY_WAIT = 5
FA.MANY = 4
FA.SOUND = 165950      -- SOUNDKIT.UI_ADVENTURES_DEATH_FRIENDLY

local SMALL, SMALL_BUTTON, SMALL_MAX, CARD, CARD_MAX, PAD, CLOSE = 420, 580, 700, 480, 620, 16, 34
local BUTTON_W, BUTTON_H, ICON, ICON_GAP, EDGE = 120, 26, 52, 10, 14
FA.RESPECTS_ICON = "Interface\\Icons\\INV_Misc_Candle_03"
FA.DEATH_ICON = "Interface\\Icons\\INV_Misc_Bone_Skull_01"
local frame, parts, pop
local lastPopup, merged = -math.huge, nil
local away, awayPending = {}, false

local function createPopup()
    local s = ns.db.settings
    s.friendPopupPosition = s.friendPopupPosition or {}
    frame = UI.Panel(SMALL, "card")
    UI.Movable(frame, s.friendPopupPosition, "TOP", 0, -440)
    frame:SetFrameStrata("HIGH")
    parts = {
        one = UI.Text(frame, "body", 15, "text"),
        two = UI.Text(frame, "body", 13, "muted"),
        quip = UI.Text(frame, "italic", 14, "joke"),
        kind = UI.Text(frame, "bold", 13, "text"),
        title = UI.Text(frame, "number", 32, "text"),
        detail = UI.Text(frame, "body", 14, "muted"),
    }
    parts.title:SetWidth(CARD - 2 * PAD)
    parts.title:SetWordWrap(false)
    UI.Fit(parts.title, 1, 0.7)
    parts.iconFrame, parts.icon = UI.FramedIcon(frame, ICON)
    parts.iconFrame:SetPoint("LEFT", 8, 0)
    parts.respects = UI.Button(frame, "Pay respects", BUTTON_W, BUTTON_H, function(self)
        local targets, clicking = self.targets or {}, true
        for _, target in ipairs(targets) do
            L.SendTo(target.id, ("P^%s^%d"):format(F.Me(), target.time), function()
                ns.Trophies.Fact("respectsSent", { id = target.id })
                if self.targets ~= targets then return end
                if clicking then UI.HideTooltip() end
                self:SetText("Respects paid")
                self:Disable()
            end)
        end
        clicking = false
    end, "Pay respects", function() return parts.respects.tipText end)
    parts.close = UI.CloseButton(frame, "Close", function() frame:Hide() end)
    parts.close:SetPoint("TOPRIGHT", -4, -4)
    parts.close:Hide()
    pop = UI.Toast(frame, parts.close, nil, FA.HOLD)
    frame:Hide()
    FA.frame, FA.parts = frame, parts
end

---@param targets table?
local function respectsFor(targets)
    local b = parts.respects
    b.targets = targets
    b:SetShown(targets ~= nil)
    if not targets then return end
    b:SetText("Pay respects")
    b:Enable()
    local names = {}
    for _, t in ipairs(targets) do names[#names + 1] = F.Name(t.id) end
    b.tipText = (#names == 1 and "%s gets a small popup saying you did." or "%s get a small popup saying you did.")
        :format(table.concat(names, " and ")) .. " Nothing is said in chat."
end

local function arrange(card, gold, icon)
    for _, k in ipairs({ "one", "two" }) do parts[k]:SetShown(not card) end
    parts.quip:SetShown(parts.hasQuip == true)
    for _, k in ipairs({ "kind", "title", "detail" }) do parts[k]:SetShown(card) end
    parts.iconFrame:SetShown(icon ~= nil)
    parts.icon:SetShown(icon ~= nil)
    if icon then parts.icon:SetTexture(icon) end
    UI.Edge(frame, gold and UI.COLOR.trophy)
    local button = parts.respects:IsShown()
    local left = icon and 8 + ICON + ICON_GAP or PAD
    local beside = left + PAD + (button and BUTTON_W + 14 or 0) + (button and not card and CLOSE - PAD or 0)
    local width
    if card then
        local longest = math.max(parts.detail:GetUnboundedStringWidth(), parts.quip:IsShown() and parts.quip:GetUnboundedStringWidth() or 0)
        width = math.min(CARD_MAX, math.max(CARD, math.ceil(longest) + beside + 12))
    else
        local longest = math.max(parts.one:GetUnboundedStringWidth(), parts.two:GetUnboundedStringWidth(),
            parts.quip:IsShown() and parts.quip:GetUnboundedStringWidth() or 0)
        width = math.min(SMALL_MAX, math.max(button and SMALL_BUTTON or SMALL, math.ceil(longest) + beside))
    end
    frame:SetWidth(width)
    local inner = width - beside
    parts.respects:ClearAllPoints()
    if card then
        for _, k in ipairs({ "kind", "title" }) do parts[k]:SetWidth(width - 2 * PAD) end
        parts.detail:SetWidth(inner)
        parts.quip:SetWidth(inner)
        parts.quip:SetJustifyH("LEFT")
        parts.title:ScaleTextToFit()
        UI.Place(frame, parts.kind, PAD + 6, 18)
        UI.Place(frame, parts.title, PAD + 6, 18 + 22)
        UI.Place(frame, parts.detail, PAD + 6, 18 + 22 + 44)
        local quipAt = 18 + 22 + 44 + math.ceil(parts.detail:GetStringHeight()) + 6
        UI.Place(frame, parts.quip, PAD + 6, quipAt)
        parts.respects:SetPoint("BOTTOMRIGHT", -PAD - 6, 18)
        frame:SetHeight(parts.quip:IsShown() and quipAt + math.ceil(parts.quip:GetStringHeight()) + 20 or quipAt + 14)
    else
        for _, k in ipairs({ "one", "two", "quip" }) do
            parts[k]:SetWidth(inner)
            parts[k]:SetJustifyH(icon and "LEFT" or "CENTER")
        end
        local below = EDGE + math.ceil(parts.one:GetStringHeight()) + 4
        local quipAt = below + math.ceil(parts.two:GetStringHeight()) + 5
        local height = (parts.quip:IsShown() and quipAt + math.ceil(parts.quip:GetStringHeight()) or quipAt - 5) + EDGE
        local top = icon and math.max(0, math.floor((ICON + 16 - height) / 2)) or 0
        UI.Place(frame, parts.one, left, EDGE + top)
        UI.Place(frame, parts.two, left, below + top)
        UI.Place(frame, parts.quip, left, quipAt + top)
        parts.respects:SetPoint("RIGHT", -CLOSE, 0)
        frame:SetHeight(icon and math.max(height, ICON + 16) or height)
    end
end

---@param targets table?
---@param icon string?
---@param quip string?
function FA.Small(line1, line2, targets, gold, icon, quip)
    if not frame then createPopup() end
    respectsFor(targets)
    parts.one:SetText(line1)
    parts.two:SetText(line2)
    parts.quip:SetText(quip or "")
    parts.hasQuip = quip ~= nil and quip ~= ""
    arrange(false, gold, icon)
    pop()
end

function FA.ClassName(id) return UI.Colored(F.Name(id), UI.ClassColor(F.Known(id).class) or UI.COLOR.text) end

---@param number number? which death, as friends were sent it; counted when left out
function FA.PaidRespects(name, d, number)
    number = number or F.DeathNumber(d)
    local spell = (d.cause == "mob" or d.cause == "player") and (d.spell or "Melee") or nil
    local rest = UI.Join(spell, d.zone)
    FA.Small(name .. UI.Muted(" paid respects"),
        UI.Muted(("Your death #%d to "):format(number)) .. UI.KillerName(ns.DeathTitle(d), d.cause)
            .. (rest ~= "" and UI.Muted(", " .. rest) or ""), nil, nil, FA.RESPECTS_ICON)
end

---@param targets table?
---@param quip string?
function FA.Card(kind, titleColor, title, detail, targets, gold, quip)
    if not frame then createPopup() end
    respectsFor(targets)
    parts.quip:SetText(quip or "")
    parts.hasQuip = quip ~= nil and quip ~= ""
    parts.kind:SetText(UI.Spaced(kind:upper(), "hair"))
    UI.Tint(parts.kind, gold and UI.COLOR.trophy or UI.COLOR.faint)
    parts.title:SetText(title)
    UI.Tint(parts.title, titleColor)
    parts.detail:SetText(detail)
    arrange(true, gold)
    pop()
end

local function deathLine(id, l)
    return ("%s died to %s in %s, death #%d."):format(F.Name(id), l.killer, l.zone or "?", l.number or 0)
end

function FA.FriendSound()
    if ns.db.settings.friendSound then PlaySound(FA.SOUND) end
end
local friendSound = FA.FriendSound

local function cardDetail(l)
    local where = ("in %s, at level %d"):format(l.zone or "?", l.level or 0)
    return l.spell and (l.spell .. " " .. where) or UI.Capital(where)
end

local function friendDied(id, l)
    local setting = ns.db.settings.friendDeath
    local now = time()
    if merged and now - merged.at <= FA.MERGE then
        table.insert(merged.ids, id)
        table.insert(merged.targets, { id = id, time = l.time })
        merged.at = now
        local killers, seen = {}, {}
        table.insert(merged.deaths, l)
        for _, d in ipairs(merged.deaths) do
            if not seen[d.killer or "?"] then
                seen[d.killer or "?"] = true
                killers[#killers + 1] = UI.KillerName(d.killer, F.Cause(d))
            end
        end
        return FA.Small(F.NamesOf(merged.ids, FA.MANY) .. UI.Muted(" died to ") .. UI.AndList(killers),
            l.zone or "", merged.targets, nil, FA.DEATH_ICON)
    end
    if now - lastPopup < FA.QUIET then return UI.Say(deathLine(id, l)) end
    lastPopup = now
    friendSound()
    local targets = { { id = id, time = l.time } }
    merged = { ids = { id }, targets = targets, deaths = { l }, at = now }
    local rare = l.number and l.number % FA.MILESTONE == 0
    if setting == "card" or rare then
        return FA.Card(("%s, death #%d, killed by"):format(F.Name(id), l.number or 0),
            UI.CauseColor(F.Cause(l)), l.killer, cardDetail(l), targets, rare, l.joke)
    end
    FA.Small(F.Name(id) .. UI.Muted(" died to ") .. UI.KillerName(l.killer, F.Cause(l)),
        UI.Join(UI.CharName(l.char), l.spell, l.zone, l.number and "death #" .. l.number), targets, nil, FA.DEATH_ICON, l.joke)
end

local function newNemesis(id, c, l)
    lastPopup = time()
    merged = nil
    friendSound()
    FA.Card(("%s's new nemesis"):format(F.Name(id)), UI.CauseColor("mob"), c.nem.name or "?",
        ("Killed %s %s, in %s"):format(F.Name(id), UI.Times(c.nem.kills), c.zone or "?"), { { id = id, time = l.time } }, true)
end

local function awayLine()
    awayPending = false
    local parts2 = {}
    for id, n in pairs(away) do parts2[#parts2 + 1] = { name = F.Name(id), n = n } end
    away = {}
    if #parts2 == 0 then return end
    table.sort(parts2, function(a, b) return a.n > b.n end)
    local words = {}
    for i, p in ipairs(parts2) do
        words[i] = ("%s %s"):format(p.name, i == 1 and "died " .. UI.Times(p.n) or UI.Times(p.n))
    end
    local text = #words == 1 and words[1] or table.concat(words, ", ", 1, #words - 1) .. " and " .. words[#words]
    UI.Say(("While you were away, %s."):format(text))
end

local function caughtUp(id, n)
    away[id] = (away[id] or 0) + n
    if awayPending then return end
    awayPending = true
    C_Timer.After(FA.AWAY_WAIT, awayLine)
end

function FA.ResetQuiet() lastPopup, merged = -math.huge, nil end

function FA.OnRecord(rec, changes)
    if F.IsGuildOnly(rec.id) then return end
    local nemesis
    for _, c in ipairs(changes) do if c.kind == "nemesis" then nemesis = c end end
    for _, c in ipairs(changes) do
        if c.kind == "death" then
            local l, id = c.last, c.id
            ns.Trophies.Fact("friendDeath", { id = id, killer = l.killer, npc = l.npc, time = l.time })
            if time() - l.time > FA.FRESH then
                caughtUp(id, c.deaths - (c.before or c.deaths - 1))
            elseif ns.db.settings.friendDeath ~= "off" and not F.InGroup(id) and not ns.InBattle() then
                F.WhenFree(function()
                    if nemesis then return newNemesis(id, nemesis, l) end
                    friendDied(id, l)
                end)
            end
        elseif c.kind == "passed" then
            UI.Say(("%s passed %s for most deaths (%d)."):format(F.Name(c.id), c.other == "you" and "you" or F.Name(c.other), c.deaths))
        end
    end
end
L.On("record", FA.OnRecord)

ns.OnEvent("PARTY_KILL", function(attacker, target)
    if issecretvalue(target) or issecretvalue(attacker) or attacker ~= UnitGUID("player") then return end
    local _, npc = ns.ParseGUID(target)
    if not npc then return end
    for _, id in ipairs(F.NemesisOf(npc)) do
        local rec = F.Store().players[id]
        local zone = GetRealZoneText() or ""
        if not F.InGroup(id) then
            L.SendTo(id, ("G^%s^%d^%s"):format(F.Me(), npc, zone:gsub("%^", "")), function()
                local mob = F.Char(rec, F.Known(id).char).nemName
                F.AddEvent({ kind = "avengedBy", id = id, mob = mob, npc = npc, zone = zone })
                F.Avenged(id)
                ns.Trophies.Fact("avenger", { id = id })
                FA.Small(UI.Muted("You avenged ") .. F.Name(id),
                    UI.Muted("Killed ") .. UI.MobName(mob or "?") .. UI.Muted((", %s's nemesis, in %s"):format(F.Name(id), zone)), nil, true)
            end)
        end
    end
end)

L.On("G", function(id, p)
    local npc, name = ns.CharacterNemesis()
    if not npc or npc ~= tonumber(p[3]) or ns.InBattle() or F.InGroup(id) then return end
    F.AddEvent({ kind = "avenged", id = id, mob = name, npc = npc, zone = p[4] })
    FA.Small(F.Name(id) .. " " .. UI.Colored("avenged you", UI.COLOR.trophy),
        UI.Muted("Killed ") .. UI.MobName(name) .. UI.Muted(", your nemesis. Its bounty is still yours."), nil, true)
    ns.Trophies.Fact("avenged", { id = id })
end)

L.On("P", function(id, p)
    local at = tonumber(p[3])
    for _, d in ipairs(ns.Deaths({}, 50)) do
        if d.time == at then
            F.AddEvent({ kind = "respects", id = id, killer = ns.DeathTitle(d), cause = d.cause, at = at })
            if not ns.InBattle() then FA.PaidRespects(FA.ClassName(id), d) end
            return ns.Trophies.Fact("respectsGot", { death = at, id = id })
        end
    end
end)

