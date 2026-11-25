local _, ns = ...
local UI = ns.UI

local WIDTH, MIN_WIDTH, PAD_X, PAD_TOP, PAD_BOTTOM, GAP = 640, 420, 32, 26, 28, 10
local INNER = WIDTH - 2 * PAD_X
local TROPHY_GAP = 12
local MARK, MARK_GAP = 44, 8
-- Cinzel's capitals sit high in their line.
local MARK_RISE = 7

local frame, lines, divider, pop, held

-- A frame's position is in its own scale.
function ns.CardSpot()
    local s = ns.db.settings
    return s.cardPosition, "TOP", 0, -280 / s.cardScale
end

function ns.CardShows()
    return ns.db.settings.card and not (ns.InBattle() and not ns.db.settings.cardBattlegrounds)
end

local function createCard()
    frame = UI.Panel(WIDTH, "card")
    frame:SetScale(ns.db.settings.cardScale)
    UI.Movable(frame, ns.CardSpot())
    UI.ResizeGrip(frame, ns.db.settings, "cardScale", 0.3, 1.2)
    frame:SetFrameStrata("HIGH")
    lines = {
        kind = UI.Text(frame, "bold", 18, "text"),
        title = UI.Text(frame, "number", 46, "text"),
        detail = UI.Text(frame, "body", 18, "muted"),
        quip = UI.Text(frame, "italic", 20, "joke"),
    }
    for _, t in pairs(lines) do
        t:SetWidth(INNER)
        t:SetWordWrap(false)
    end
    UI.Fit(lines.title, 1, 0.7)
    lines.mark = UI.RankMark(frame, MARK)
    divider = UI.Divider(frame)
    local trophy = UI.Row(frame, INNER, TROPHY_GAP, { { "label", "bold", 13, "trophy" }, { "text", "body", 17, "text" } })
    lines.trophy, lines.trophyLabel, lines.trophyText = trophy, trophy.label, trophy.text
    lines.close = UI.CloseButton(frame, "Close this card", function()
        held = false
        frame:Hide()
    end)
    lines.close:SetPoint("TOPRIGHT", -8, -8)
    lines.close:Hide()
    pop = UI.Toast(frame, lines.close, function() return held end)
    frame.lines = lines
    frame:Hide()
    ns.card = frame
end

local function stack(region, y, height)
    UI.Place(frame, region, PAD_X, y)
    return y + height
end

local function details(d)
    local where = ("in %s, at level %d"):format(d.zone or "?", d.level or 0)
    if d.cause == "mob" or d.cause == "player" then
        local how = (d.spell or "Melee") .. " " .. where
        return d.killerClass and (d.killerClass .. ", " .. how) or how
    elseif d.cause == "self" then
        return ("Own %s %s"):format(d.spell or "spell", where)
    elseif d.cause == "fall" and d.amount then
        return ("Fell for %d damage %s"):format(d.amount, where)
    end
    return UI.Capital(where)
end

local function show(d, hold)
    if not ns.CardShows() then
        if frame then frame:Hide() end
        return
    end
    if not frame then createCard() end
    lines.kind:SetText(UI.Spaced(("DEATH #%d, KILLED BY"):format(d.number), "hair"))
    UI.Tint(lines.kind, UI.COLOR.faint)
    lines.title:SetText(ns.DeathTitle(d))
    UI.Tint(lines.title, UI.CauseColor(d.cause))
    local shift = UI.SetRank(lines.mark, d.killerRank) and MARK + MARK_GAP or 0
    lines.detail:SetText(details(d))
    lines.quip:SetText(d.joke)
    local label, text = ns.Trophy(d)
    if label then lines.trophy:Set(UI.Spaced(label:upper(), "thin"), text) end

    local widest = 0
    for _, t in ipairs({ lines.kind, lines.title, lines.detail, lines.quip }) do
        widest = math.max(widest, t:GetUnboundedStringWidth() / t:GetTextScale() + (t == lines.title and shift or 0))
    end
    if label then
        widest = math.max(widest, lines.trophyLabel:GetUnboundedStringWidth() + TROPHY_GAP
            + lines.trophyText:GetUnboundedStringWidth())
    end
    local width = math.min(WIDTH, math.max(MIN_WIDTH, math.ceil(widest) + 2 * PAD_X))
    frame:SetWidth(width)
    for _, t in ipairs({ lines.kind, lines.title, lines.detail, lines.quip, lines.trophy }) do t:SetWidth(width - 2 * PAD_X) end
    lines.title:SetWidth(width - 2 * PAD_X - shift)
    lines.title:ScaleTextToFit()

    local y = stack(lines.kind, PAD_TOP, UI.LineHeight(18)) + GAP
    local titleLine = UI.LineHeight(46, 1.1)
    UI.Place(frame, lines.title, PAD_X + shift, y)
    UI.Place(frame, lines.mark, PAD_X, y + math.floor((titleLine - MARK) / 2) - MARK_RISE)
    y = y + titleLine + GAP
    y = stack(lines.detail, y, UI.LineHeight(18)) + GAP
    y = stack(lines.quip, y, UI.LineHeight(20))
    divider:SetShown(label ~= nil)
    lines.trophy:SetShown(label ~= nil)
    if label then
        y = y + 6
        UI.PlaceAcross(frame, divider, PAD_X, y)
        y = stack(lines.trophy, y + 1 + TROPHY_GAP, lines.trophy:GetHeight()) + PAD_BOTTOM - 6
    else
        y = y + PAD_BOTTOM
    end
    frame:SetHeight(y)
    held = hold
    pop()
end

ns.ShowCard = show
ns.OnDeath(function(d) show(d, false) end)

local EXAMPLES = {
    mob = { killer = "Kobold Miner", spell = "Melee", zone = "Elwynn Forest", level = 9 },
    player = { killer = "Lil Dusk", spell = "Sinister Strike", zone = "Stranglethorn Vale", level = 38 },
    fall = { zone = "Thousand Needles", level = 34, amount = 412 },
    drown = { zone = "Loch Modan", level = 22 }, lava = { zone = "Searing Gorge", level = 48 },
    fire = { zone = "Burning Steppes", level = 52 }, fatigue = { zone = "Westfall", level = 14 },
    slime = { zone = "Undercity", level = 30 },
}
function ns.PreviewCard(cause)
    local e = EXAMPLES[cause]
    if not e then return print("Death Tracker: /deathtracker card mob, player, fall, drown, lava, fire, fatigue or slime") end
    local d = { cause = cause, number = 47, time = time() }
    for k, v in pairs(e) do d[k] = v end
    d.joke = ns.Joke(d)
    show(d, true)
end
