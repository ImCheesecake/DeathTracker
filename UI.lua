local addonName, ns = ...
local UI = {}
ns.UI = UI

local MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"
UI.ICON = MEDIA .. "Icon"
UI.RECAP_MUSIC = MEDIA .. "RecapMusic.ogg"

UI.FONT = {
    number = MEDIA .. "Fonts\\Cinzel-Bold.ttf",
    body = MEDIA .. "Fonts\\Inter-Regular.ttf",
    bold = MEDIA .. "Fonts\\Inter-SemiBold.ttf",
    italic = MEDIA .. "Fonts\\Inter-Italic.ttf",
}

-- Our fonts are Latin only (Inter also has Cyrillic), so other alphabets come from the game's own fonts.
local OTHER_ALPHABETS = {
    russian = "Fonts\\FRIZQT___CYR.TTF",
    korean = "Fonts\\2002.TTF",
    simplifiedchinese = "Fonts\\ARKai_T.ttf",
    traditionalchinese = "Fonts\\blei00d.TTF",
}
local CYRILLIC = { body = true, bold = true, italic = true }

local families = {}
local function family(font, size, flags)
    local key = font .. size .. flags
    if not families[key] then
        local members = { { alphabet = "roman", file = UI.FONT[font], height = size, flags = flags } }
        for alphabet, file in pairs(OTHER_ALPHABETS) do
            if alphabet == "russian" and CYRILLIC[font] then file = UI.FONT[font] end
            members[#members + 1] = { alphabet = alphabet, file = file, height = size, flags = flags }
        end
        families[key] = CreateFontFamily(addonName .. "_" .. key, members)
    end
    return families[key]
end

local function rgb(hex, a)
    return { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255,
             tonumber(hex:sub(5, 6), 16) / 255, a or 1 }
end
UI.COLOR = {
    text = rgb("f4efe2"),
    muted = rgb("c4bdad"),
    panel = rgb("0c0c0e", 0.85),
    border = rgb("3f3a2c"),
    divider = rgb("3a3528"),
    faint = rgb("9a9486"),
    cardPanel = rgb("0c0c0e", 0.93),
    cardBorder = rgb("5a4e33"),
    joke = rgb("e2c46b"),
    trophy = rgb("e8c766"),
    hover = rgb("24262b"),
    selected = rgb("2c2820"),
    gone = rgb("1d1e22"),
    fresh = rgb("2c2820", 0.5),
    white = rgb("ffffff"),
    shaman = rgb("3a96f0"),
    wash = rgb("000000", 0.45),
    barTrack = rgb("000000", 0.55),
    barFill = rgb("1e631e"),
    barEdge = rgb("4a3f29"),
    barOutline = rgb("000000"),
    parchmentLine = rgb("8a6a3c"),
    slideBar = rgb("4a4436"),
    link = rgb("71d5ff"),
    shadow = rgb("000000", 0.8),
    stamp = rgb("6e0e0e"),
    ink = rgb("4a3a22"),
    cause = {
        mob = rgb("f08a5d"), player = rgb("c79bff"), fall = rgb("8ec5ff"), drown = rgb("3fc8b4"),
        lava = rgb("ff7a1f"), fire = rgb("ff4f6e"), fatigue = rgb("b4bcc8"), slime = rgb("9ad35a"),
        self = rgb("f2a0c4"), unknown = rgb("9aa0a6"), other = rgb("9aa0a6"),
    },
}

local function rounded(frame, file, color, layer)
    local t = frame:CreateTexture(nil, layer)
    t:SetTexture(MEDIA .. file)
    t:SetTextureSliceMargins(8, 8, 8, 8)
    t:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    t:SetAllPoints()
    t:SetVertexColor(unpack(color))
    return t
end

function UI.Edge(panel, color) panel.border:SetVertexColor(unpack(color or UI.COLOR.cardBorder)) end

function UI.Panel(width, look)
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetWidth(width)
    f.fill = rounded(f, "PanelFill", look == "card" and UI.COLOR.cardPanel or UI.COLOR.panel, "BACKGROUND")
    f.border = rounded(f, "PanelBorder", look == "card" and UI.COLOR.cardBorder or UI.COLOR.border, "BORDER")
    f.backdrop = { f.fill, f.border }
    return f
end

local function line(frame, color)
    local t = frame:CreateTexture(nil, "BORDER")
    t:SetColorTexture(unpack(color))
    t:SetSize(1, 1)
    return t
end

local function edge(frame) return line(frame, UI.COLOR.border) end

UI.JOIN = 10
local function curve(tab, file, color, layer, side)
    local t = tab:CreateTexture(nil, layer)
    t:SetTexture(MEDIA .. file)
    t:SetSize(16, 16)
    t:SetVertexColor(unpack(color))
    if side > 0 then
        t:SetTexCoord(1, 0, 0, 1)
        t:SetPoint("TOPRIGHT", tab, "TOPRIGHT", UI.JOIN, 1)
    else
        t:SetPoint("TOPLEFT", tab, "TOPLEFT", -UI.JOIN, 1)
    end
    return t
end

function UI.Notch(tabHeight)
    local f = CreateFrame("Frame", nil, UIParent)
    f.fill = rounded(f, "PanelFill", UI.COLOR.panel, "BACKGROUND")
    f.border = rounded(f, "PanelBorderOpen", UI.COLOR.border, "BORDER")
    f.bottom = { edge(f), edge(f) }
    f.bottom[1]:SetPoint("BOTTOMLEFT", 8, 0)
    f.bottom[2]:SetPoint("BOTTOMRIGHT", -8, 0)
    local tab = CreateFrame("Frame", nil, f)
    tab:SetSize(1, tabHeight)
    tab:SetPoint("TOP", f, "BOTTOM", 0, 0)
    tab.fill = rounded(tab, "TabFill", UI.COLOR.panel, "BACKGROUND")
    tab.border = rounded(tab, "TabBorder", UI.COLOR.border, "BORDER")
    tab.border:ClearAllPoints()
    tab.border:SetPoint("TOPLEFT", 0, -UI.JOIN)
    tab.border:SetPoint("BOTTOMRIGHT")
    f.fills, f.lines = { f.fill, tab.fill }, { f.border, f.bottom[1], f.bottom[2], tab.border }
    for _, side in ipairs({ -1, 1 }) do
        table.insert(f.fills, curve(tab, "JoinFill", UI.COLOR.panel, "BACKGROUND", side))
        table.insert(f.lines, curve(tab, "JoinBorder", UI.COLOR.border, "BORDER", side))
    end
    f.backdrop = f.fills
    tab:EnableMouse(true)
    tab:RegisterForDrag("LeftButton")
    for _, script in ipairs({ "OnDragStart", "OnDragStop", "OnMouseUp" }) do
        tab:SetScript(script, function(_, ...)
            local run = f:GetScript(script)
            if run then run(f, ...) end
        end)
    end
    f.tab = tab
    return f
end

function UI.ShapeNotch(f, tabWidth)
    local width = f:GetWidth()
    f.tab:SetShown(tabWidth ~= nil)
    f.bottom[2]:SetShown(tabWidth ~= nil)
    if not tabWidth then
        f.bottom[1]:SetWidth(width - 16)
        return
    end
    f.tab:SetWidth(tabWidth)
    local side = (width - tabWidth) / 2 - UI.JOIN - 8
    f.bottom[1]:SetWidth(side)
    f.bottom[2]:SetWidth(side)
end

local GAME_FONT = { small = "GameFontHighlightSmall", normal = "GameFontHighlight", large = "GameFontHighlightLarge" }
function UI.GameText(parent, size, color)
    local t = parent:CreateFontString(nil, "OVERLAY", GAME_FONT[size])
    t:SetJustifyH("LEFT")
    t:SetTextColor(unpack(UI.COLOR[color]))
    return t
end

function UI.Text(parent, font, size, color)
    local t = parent:CreateFontString(nil, "OVERLAY")
    t:SetFontObject(family(font, size, ""))
    t:SetTextColor(unpack(UI.COLOR[color]))
    t:SetJustifyH("LEFT")
    t.style = { font = font, size = size, color = color }
    return t
end

function UI.Bare(panel, texts, on)
    for _, t in ipairs(panel.backdrop) do t:SetShown(not on) end
    for _, t in ipairs(texts) do
        local s = t.style
        t:SetFontObject(family(s.font, s.size, on and "OUTLINE" or ""))
        t:SetShadowColor(0, 0, 0, on and s.size < 20 and 0.8 or 0)
        t:SetShadowOffset(1, -1)
        t:SetTextColor(unpack(UI.COLOR[on and "text" or s.color]))
    end
end

function UI.Fit(text, lines, smallest, most)
    Mixin(text, AutoScalingFontStringMixin)
    text:SetMaxLines(lines)
    -- The mixin reads its full size from GetLineHeight(), which is 0 in game while the text is empty.
    local _, size = text:GetFont()
    text.baseLineHeight = Round(size)
    text:SetMinLineHeight(Round(size * smallest))
    if not most then return end
    local fit = text.ScaleTextToFit
    function text:ScaleTextToFit()
        self:SetMaxLines(lines)
        fit(self)
        if self:IsTruncated() then
            self:SetMaxLines(most)
            fit(self)
        end
    end
end

-- The fonts' own line height: 1.21 times the size, a title's 1.1.
function UI.LineHeight(size, factor) return math.floor(size * (factor or 1.21) + 0.5) end

function UI.Plural(n, one, many) return n == 1 and one or many end

function UI.Times(n) return n == 1 and "once" or ("%d times"):format(n) end

function UI.Count(n, one, many) return ("%d %s"):format(n, UI.Plural(n, one, many)) end

function UI.CauseColor(cause) return UI.COLOR.cause[cause] or UI.COLOR.cause.unknown end

local durations = CreateFromMixins(SecondsFormatterMixin)
durations:Init(0, SecondsFormatter.Abbreviation.OneLetter)
durations:SetStripIntervalWhitespace(true)
-- Without this hook Blizzard's formatter skips a zero unit: 8 h 0 min 37 s reads "8h 37s".
function durations:GetMinInterval(seconds)
    local unit = SecondsFormatter.Interval
    if seconds >= 86400 then return unit.Hours end
    if seconds >= 3600 then return unit.Minutes end
    return unit.Seconds
end
function UI.Duration(seconds) return durations:Format(seconds) end

-- A ghost runs 7 yards a second plus the Ghost aura's 25%.
UI.GHOST_SPEED = 8.75
function UI.RunText(yards, seconds)
    if seconds and seconds > 0 then return UI.Duration(seconds) end
    return "about " .. UI.Duration(math.max(1, math.floor((yards or 0) / UI.GHOST_SPEED + 0.5)))
end

function UI.AndList(words)
    if #words == 1 then return words[1] end
    return table.concat(words, ", ", 1, #words - 1) .. " and " .. words[#words]
end

function UI.Yards(yards) return BreakUpLargeNumbers(math.floor((yards or 0) + 0.5)) .. " yards" end

function UI.Since(when) return UI.Duration(time() - when) .. " ago" end

function UI.Ago(when)
    local s = time() - when
    local m, h, d = math.floor(s / 60), math.floor(s / 3600), math.floor(s / 86400)
    if s < 60 then return "just now" end
    if s < 3600 then return m .. " min ago" end
    if s < 3 * 3600 then
        local rest = m - h * 60
        return rest > 0 and ("%d h %d min ago"):format(h, rest) or (h .. " h ago")
    end
    if s < 86400 then return h .. " h ago" end
    if s < 2 * 86400 then return "yesterday" end
    if s < 7 * 86400 then return d .. " days ago" end
    if s < 60 * 86400 then return math.floor(d / 7) .. " weeks ago" end
    return "on " .. (date("%d %b", when):gsub("^0", ""))
end

function UI.Date(when, weekday)
    if not weekday then
        local day = ns.Day(when)
        if day == ns.Day(time()) then return "today" end
        if day == ns.Day(time() - 86400) then return "yesterday" end
    end
    local format = (weekday and weekday .. " " or "") .. "%d %b" .. (date("%Y", when) == date("%Y") and "" or " %Y")
    local text = date(format, when):gsub("^0", ""):gsub(" 0", " ")
    return text
end

function UI.At(when, bare)
    local day = UI.Date(when)
    local on = (bare or day == "today" or day == "yesterday") and "" or "on "
    return on .. day .. (bare and " " or " at ") .. date("%H:%M", when)
end

function UI.AtTime(when) return UI.Date(when) .. " at " .. date("%H:%M", when) end

function UI.Moment(when) return UI.Capital(UI.Date(when)) .. ", " .. date("%H:%M", when) end

function UI.Named(name, ...)
    local rest = UI.Join(...)
    if not name then return rest end
    local named = UI.Colored(name, UI.COLOR.text)
    return rest == "" and named or named .. ", " .. rest
end

function UI.Capital(text) return (text:gsub("^%l", string.upper)) end

function UI.ClassColor(classFile)
    if classFile == "SHAMAN" then return UI.COLOR.shaman end
    local c = classFile and C_ClassColor.GetClassColor(classFile)
    return c and { c.r, c.g, c.b, 1 }
end

function UI.Colored(text, color) return CreateColor(unpack(color)):WrapTextInColorCode(text) end

function UI.Muted(text) return UI.Colored(text, UI.COLOR.muted) end
function UI.KillerName(text, cause) return UI.Colored(text, UI.CauseColor(cause)) end
function UI.MobName(text) return UI.KillerName(text, "mob") end

local FRIENDS = { bnet = { "FRIENDS_BNET_NAME_COLOR", "82c5ff" }, character = { "FRIENDS_WOW_NAME_COLOR", "fde05c" },
    offline = { false, "8f8f8f" } }
function UI.FriendColor(kind)
    local c = FRIENDS[kind][1] and _G[FRIENDS[kind][1]]
    if c then return { c.r, c.g, c.b, 1 } end
    return rgb(FRIENDS[kind][2])
end

function UI.LabelColor()
    local c = NORMAL_FONT_COLOR
    return { c.r, c.g, c.b, 1 }
end

local classNames
function UI.ClassName(classFile)
    if not classNames then
        classNames = {}
        for i = 1, 20 do
            local name, file = GetClassInfo(i)
            if file then classNames[file] = name end
        end
    end
    return classNames[classFile] or ""
end

function UI.CharacterLine(name, class, level, where)
    local parts = {}
    if name then parts[1] = UI.Colored(UI.CharName(name), UI.FriendColor("character")) end
    if level then parts[#parts + 1] = UI.Colored("Lvl " .. level, UI.COLOR.white) end
    if class then parts[#parts + 1] = UI.Colored(UI.ClassName(class), UI.ClassColor(class) or UI.COLOR.text) end
    local line = table.concat(parts, " ")
    if where and where ~= "" then line = line .. "  " .. UI.Colored(where, UI.FriendColor("offline")) end
    return line
end

-- Blizzard's raid warning in a frame of our own, as RareScanner does on Forever, so Blizzard's own (an
-- Edit Mode frame) stays untouched; in Cinzel with an outline. Each line pops to maxHeight, holds for
-- seconds minus Blizzard's 3-second fade, then fades.
function UI.RaidWarning(maxHeight)
    local f = CreateFrame("Frame", nil, UIParent, "RaidWarningFrameTemplate")
    f:SetPoint("TOP", 0, -182)
    f:UnregisterAllEvents()
    f.maxTextHeight = maxHeight
    function f:Warn(text, seconds)
        self:AddMessage(text, ChatTypeInfo.RAID_WARNING, seconds)
        self:GetLowestMessage():SetFontObject(family("number", 20, "OUTLINE"))
    end
    return f
end

function UI.Say(text)
    local c = ChatTypeInfo.SYSTEM
    DEFAULT_CHAT_FRAME:AddMessage("Death Tracker: " .. text, c.r, c.g, c.b)
end

-- Blizzard hands an addon's own links ("addon:...") to EventRegistry's SetItemRef.
local chatLinks = {}
function UI.ChatLink(text, kind, value)
    return UI.Colored(("|Haddon:%s:%s:%s|h[%s]|h"):format(addonName, kind, value, text), UI.COLOR.link)
end

function UI.OnChatLink(kind, fn) chatLinks[kind] = fn end

EventRegistry:RegisterCallback("SetItemRef", function(_, link)
    local prefix, addon, kind, value = strsplit(":", link)
    if prefix == "addon" and addon == addonName and chatLinks[kind] then chatLinks[kind](value) end
end)

function UI.Ask(question, detail, onYes, onNo)
    StaticPopup_ShowCustomGenericConfirmation({ text = question .. "\n%s",
        text_arg1 = UI.Colored(detail, UI.COLOR.muted), callback = onYes, cancelCallback = onNo })
end

-- Blizzard's popup puts its own edit box after its text, so ours goes in under the title.
local COPY_POPUP = addonName .. "_COPY"
local copy
function UI.CopyBox(title, text, help)
    if not copy then
        StaticPopupDialogs[COPY_POPUP] = { text = "%s", button1 = CLOSE, hideOnEscape = 1, timeout = 0,
            whileDead = 1, wideText = 1 }
        copy = CreateFrame("Frame")
        copy:SetWidth(340)
        local box = CreateFrame("EditBox", nil, copy, "InputBoxTemplate")
        box:SetSize(330, 24)
        box:SetPoint("TOP", 0, -4)
        box:SetAutoFocus(false)
        box:SetMaxLetters(0)   -- no limit
        box:SetScript("OnTextChanged", function(self, userInput)
            if userInput then
                self:SetText(copy.text)
                self:HighlightText()
            end
        end)
        box:SetScript("OnMouseUp", function(self) self:HighlightText() end)
        box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        box:SetScript("OnEscapePressed", function() StaticPopup_Hide(COPY_POPUP) end)
        box:SetScript("OnEnterPressed", function() StaticPopup_Hide(COPY_POPUP) end)
        local line = copy:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        line:SetWidth(340)
        line:SetPoint("TOP", box, "BOTTOM", 0, -12)
        UI.Tint(line, UI.COLOR.muted)
        copy.box, copy.help = box, line
    end
    copy.text = text
    copy.help:SetText(help)
    copy:SetHeight(4 + 24 + 12 + copy.help:GetStringHeight() + 4)
    if StaticPopup_Show(COPY_POPUP, title, nil, nil, copy) then
        copy.box:SetText(text)
        copy.box:SetFocus()
        copy.box:HighlightText()
    end
end

function UI.Place(frame, region, x, y)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
end

function UI.PlaceAcross(frame, region, x, y)
    UI.Place(frame, region, x, y)
    region:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -x, -y)
end

local function hideTooltip() GameTooltip:Hide() end
UI.HideTooltip = hideTooltip

local function showTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(self.tooltip)
    GameTooltip:Show()
end

local function tipLines(tooltip, title, text)
    GameTooltip_SetTitle(tooltip, title)
    GameTooltip_AddNormalLine(tooltip, text, true)
end

-- A drag moves a Movable frame with the same button, so only a press that never started a drag clicks.
function UI.LeftClick(frame, onClick)
    frame:HookScript("OnMouseDown", function(self) self.dragged = false end)
    frame:HookScript("OnDragStart", function(self) self.dragged = true end)
    frame:HookScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and not self.dragged and self:IsMouseOver() then onClick() end
    end)
end

function UI.RightClickMenu(frame, fill, has)
    frame:SetScript("OnMouseUp", function(self, button)
        if button ~= "RightButton" or (has and not has(self)) then return end
        MenuUtil.CreateContextMenu(self, function(_, root) fill(root) end)
    end)
end

function UI.MenuTooltip(element, title, text)
    element:SetTooltip(function(tooltip) tipLines(tooltip, title, text) end)
end

-- Game text has no letter spacing.
local SPACES = { hair = "\226\128\138", thin = "\226\128\137" }
function UI.Spaced(text, width)
    return (text:gsub("[^\128-\191][\128-\191]*", "%0" .. SPACES[width]):sub(1, -4))
end

function UI.Tint(text, color) text:SetTextColor(unpack(color)) end

local dividers = setmetatable({}, { __mode = "k" })

local function fitDivider(line)
    local pixel = PixelUtil.GetNearestPixelSize(1, line:GetEffectiveScale(), 1)
    if dividers[line] == "vertical" then line:SetWidth(pixel) else line:SetHeight(pixel) end
end

function UI.FitDividers()
    for line in pairs(dividers) do fitDivider(line) end
end

-- The game rounds each texture corner to a screen pixel, so anything laid out between pixels comes
-- out a pixel thicker or thinner and shifts while resizing.
local function pixelRegion(region)
    region:SetRoundLayoutToNearestPixel(true)
    if region.SetSnapToPixelGrid then
        region:SetSnapToPixelGrid(false)
        region:SetTexelSnappingBias(0)
    end
end

function UI.RoundToPixels(frame)
    pixelRegion(frame)
    for _, region in ipairs({ frame:GetRegions() }) do pixelRegion(region) end
    for _, child in ipairs({ frame:GetChildren() }) do UI.RoundToPixels(child) end
end

local scaleWatch = CreateFrame("Frame")
scaleWatch:RegisterEvent("UI_SCALE_CHANGED")
scaleWatch:RegisterEvent("DISPLAY_SIZE_CHANGED")
scaleWatch:SetScript("OnEvent", function() UI.FitDividers() end)

function UI.Divider(parent, vertical, color)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(unpack(color or UI.COLOR.divider))
    dividers[t] = vertical and "vertical" or "horizontal"
    t:SetRoundLayoutToNearestPixel(true)
    fitDivider(t)
    return t
end

local ROUND_TEXTURE = 32
local function roundedPieces(f, kind, radius, layer, inset, to)
    inset, to = inset or 0, to or f
    local file, s, e = MEDIA .. "Round" .. kind .. radius, radius / ROUND_TEXTURE, 1 - radius / ROUND_TEXTURE
    local box = { pieces = {} }
    local function piece(left, right, top, bottom)
        local t = f:CreateTexture(nil, layer or "BACKGROUND")
        t:SetTexture(file)
        t:SetTexCoord(left, right, top, bottom)
        box.pieces[#box.pieces + 1] = t
        return t
    end
    local tl, tr, bl, br = piece(0, s, 0, s), piece(e, 1, 0, s), piece(0, s, e, 1), piece(e, 1, e, 1)
    for _, corner in ipairs({ { tl, "TOPLEFT", -inset }, { tr, "TOPRIGHT", -inset }, { bl, "BOTTOMLEFT", inset },
        { br, "BOTTOMRIGHT", inset } }) do
        corner[1]:SetSize(radius, radius)
        corner[1]:SetPoint(corner[2], to, corner[2], 0, corner[3])
    end
    local function between(t, a, aPoint, b, bPoint)
        t:SetPoint("TOPLEFT", a, aPoint)
        t:SetPoint("BOTTOMRIGHT", b, bPoint)
    end
    between(piece(s, e, 0, s), tl, "TOPRIGHT", tr, "BOTTOMLEFT")
    between(piece(s, e, e, 1), bl, "TOPRIGHT", br, "BOTTOMLEFT")
    between(piece(0, s, s, e), tl, "BOTTOMLEFT", bl, "TOPRIGHT")
    between(piece(e, 1, s, e), tr, "BOTTOMLEFT", br, "TOPRIGHT")
    between(piece(s, e, s, e), tl, "BOTTOMRIGHT", br, "TOPLEFT")
    function box:SetColor(color)
        self.color = color
        for _, t in ipairs(self.pieces) do t:SetVertexColor(unpack(color)) end
    end
    function box:SetShown(on)
        self.shown = on and true or false
        for _, t in ipairs(self.pieces) do t:SetShown(on) end
    end
    return box
end

function UI.RoundedFill(f, radius, layer, inset, to) return roundedPieces(f, "Fill", radius, layer, inset, to) end

function UI.RoundedEdge(f, radius, layer, to) return roundedPieces(f, "Edge", radius, layer, 0, to) end

local ROW_RADIUS = 6
function UI.RowFill(row, color)
    local fill = UI.RoundedFill(row, ROW_RADIUS, nil, 1)
    if color then fill:SetColor(color) end
    return fill
end

function UI.Parchment(parent, width, height, tip, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, height)
    local t = b:CreateTexture(nil, "BACKGROUND")
    t:SetAtlas("QuestBG-Parchment")
    t:SetAllPoints()
    b:SetScript("OnEnter", function(self) tip(self) end)
    b:SetScript("OnLeave", hideTooltip)
    b:SetScript("OnClick", onClick)
    return b
end

function UI.QuestText(parent, kind, size)
    local t = parent:CreateFontString(nil, "OVERLAY", kind == "title" and "QuestTitleFont" or "QuestFont")
    local file, _, flags = t:GetFont()
    t:SetFont(file, size, flags or "")
    t:SetJustifyH("CENTER")
    return t
end

UI.SHADOW = { edge = 16, margin = 24 }
function UI.Shadow(frame, drop)
    local edge, margin = UI.SHADOW.edge, UI.SHADOW.margin
    local t = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    t:SetTexture(MEDIA .. "Shadow")
    t:SetTextureSliceMargins(margin, margin, margin, margin)
    t:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    t:SetVertexColor(unpack(UI.COLOR.shadow))
    t:SetPoint("TOPLEFT", -edge, edge - drop)
    t:SetPoint("BOTTOMRIGHT", edge, -edge - drop)
    return t
end

-- Media/Stamp's frame is drawn tilted; the text turns to match.
UI.STAMP_TILT = 12
local SLAM = { from = 2.5, time = 0.2, fade = 0.1 }
function UI.Stamp(parent, text, color)
    color = color or UI.COLOR.stamp
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(256, 128)
    f:SetFrameLevel(parent:GetFrameLevel() + 10)
    local t = f:CreateTexture(nil, "ARTWORK")
    t:SetTexture(MEDIA .. "Stamp")
    t:SetAllPoints()
    t:SetVertexColor(unpack(color))
    f.text = UI.QuestText(f, "title", 26)
    f.text:SetPoint("CENTER")
    f.text:SetTextColor(unpack(color))
    f.text:SetShadowColor(0, 0, 0, 0)
    f.text:SetRotation(math.rad(UI.STAMP_TILT))
    f.text:SetText(text)
    f:Hide()
    local drop = f:CreateAnimationGroup()
    local grow = drop:CreateAnimation("Scale")
    grow:SetScaleFrom(SLAM.from, SLAM.from)
    grow:SetScaleTo(1, 1)
    grow:SetDuration(SLAM.time)
    grow:SetSmoothing("IN")
    local fade = drop:CreateAnimation("Alpha")
    fade:SetFromAlpha(0)
    fade:SetToAlpha(1)
    fade:SetDuration(SLAM.fade)
    local hit
    drop:SetScript("OnFinished", function() if hit then hit() end end)
    return f, function(onHit)
        hit = onHit
        f:Show()
        drop:Play()
    end
end

local RANK_ATLAS = { elite = "nameplates-icon-elite-gold", worldboss = "nameplates-icon-elite-gold",
    rareelite = "nameplates-icon-elite-silver", rare = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star" }
function UI.RankMark(parent, size)
    local t = parent:CreateTexture(nil, "OVERLAY")
    t:SetSize(size, size)
    t:Hide()
    return t
end

function UI.SetRank(mark, rank)
    local atlas = RANK_ATLAS[rank]
    mark:SetShown(atlas ~= nil)
    if atlas then mark:SetAtlas(atlas) end
    return atlas ~= nil
end

function UI.RankMarkup(rank, size)
    local atlas = RANK_ATLAS[rank]
    return atlas and CreateAtlasMarkup(atlas, size, size) .. " " or ""
end

-- A PlayerModel answers for an NPC ID only once the mob's model loads, a moment later.
function UI.CreatureProbe(parent, tries)
    local probe = CreateFrame("PlayerModel", nil, parent)
    probe:SetSize(1, 1)
    probe:SetAlpha(0)
    local latest, waiting
    ---@param npc number?
    local function ask(npc, read, done)
        local this, dropped = {}, waiting
        latest, waiting = this, nil
        if dropped then dropped(nil) end
        if not npc then return end
        probe:ClearModel()
        probe:SetCreature(npc)
        local left = tries
        local function try()
            if latest ~= this then return end
            local value = read(probe)
            left = left - 1
            if value and value > 0 or left <= 0 then
                waiting = nil
                return done(value and value > 0 and value or nil)
            end
            C_Timer.After(0.1, try)
        end
        waiting = done
        try()
    end
    return ask
end

-- Transform3DPointTo2D gives screen pixels from the frame's bottom left (as PartyPoseUI reads it).
local function fitScale(scene, actor, fill)
    local x1, y1, z1, x2, y2, z2 = actor:GetActiveBoundingBox()
    if not z2 or z2 <= z1 then return end
    local px, py, pz = actor:GetPosition()
    local rx, ry, rz = scene:GetCameraRight()
    local w, h, ui = scene:GetWidth() / 2, scene:GetHeight() / 2, scene:GetEffectiveScale()
    for _ = 1, 2 do
        local scale = actor:GetScale()
        local r, half, reachX, reachY = math.max(x2 - x1, y2 - y1) / 2 * scale, (z2 - z1) / 2 * scale, 0, 0
        for _, p in ipairs({ { 0, 0, half }, { 0, 0, -half }, { rx * r, ry * r, rz * r }, { -rx * r, -ry * r, -rz * r } }) do
            local sx, sy = scene:Transform3DPointTo2D(px + p[1], py + p[2], pz + p[3])
            if not sx then return end
            reachX, reachY = math.max(reachX, math.abs(sx / ui - w)), math.max(reachY, math.abs(sy / ui - h))
        end
        if reachX <= 0 or reachY <= 0 then return end
        actor:SetScale(scale * fill * math.min(w / reachX, h / reachY))
    end
    return actor:GetScale()
end

-- A scene actor needs a display ID; the probe gives it for an NPC ID.
local PET_SCENE = 753
UI.MODEL_FILL = 0.9
function UI.Model(parent, width, height)
    local scene = CreateFrame("ModelScene", nil, parent, "ModelSceneMixinTemplate")
    scene:SetSize(width, height)
    scene:EnableMouse(false)
    local ask = UI.CreatureProbe(scene, 20)
    local function fit(display, alpha, fill)
        scene:TransitionToModelSceneID(PET_SCENE, CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_DISCARD, true)
        local actor = scene:GetActorByTag("pet")
        if not actor then return end
        local function loaded()
            local scale = fitScale(scene, actor, fill or UI.MODEL_FILL)
            if scale then actor:SetRequestedScale(scale) end
        end
        actor:SetUseCenterForOrigin(true, true, true)
        actor:SetPosition(scene:GetActiveCamera():GetTarget())
        actor:SetNormalizedScaleAggressiveness(0)
        actor:SetOnModelLoadedCallback(loaded)
        actor:SetModelByCreatureDisplayID(display)
        actor:SetAlpha(alpha)
        if actor:IsLoaded() then loaded() end
    end
    return scene, function(npc, alpha, fill, display)
        if display then
            ask(nil)
            return fit(display, alpha, fill)
        end
        ask(npc, function(probe) return probe:GetDisplayInfo() end, function(found)
            if found then fit(found, alpha, fill) end
        end)
    end
end

function UI.Box(parent, width)
    local b = CreateFrame("Frame", nil, parent)
    b:SetSize(width, 1)
    return b
end

function UI.CloseButton(parent, tooltip, onClick, template)
    local b = CreateFrame("Button", nil, parent, template)
    b.tooltip = tooltip
    if template then
        b:SetScript("OnEnter", showTooltip)
        b:SetScript("OnLeave", hideTooltip)
        b:SetScript("OnClick", onClick)
        return b
    end
    b:SetSize(28, 28)
    local x = UI.Text(b, "body", 20, "muted")
    x:SetPoint("CENTER")
    x:SetText("\195\151")
    b:SetScript("OnEnter", function(self)
        UI.Tint(x, UI.COLOR.text)
        showTooltip(self)
    end)
    b:SetScript("OnLeave", function()
        UI.Tint(x, UI.COLOR.muted)
        hideTooltip()
    end)
    b:SetScript("OnClick", onClick)
    return b
end

-- The game doesn't draw a frame without a width, nor what's in it.
---@class DeathTrackerRow: Frame
---@field Set fun(self: DeathTrackerRow, ...: any)
---@field label FontString
---@field value FontString
---@field tail FontString
---@field text FontString
---@field rest FontString

---@return DeathTrackerRow
function UI.Row(parent, width, gap, parts)
    local r = CreateFrame("Frame", nil, parent) --[[@as DeathTrackerRow]]
    local tallest = 0
    for i, p in ipairs(parts) do
        local t = UI.Text(r, p[2], p[3], p[4])
        if i == 1 then t:SetPoint("LEFT") else t:SetPoint("BOTTOMLEFT", r[parts[i - 1][1]], "BOTTOMRIGHT", gap, 0) end
        r[p[1]] = t
        tallest = math.max(tallest, p[3])
    end
    r:SetSize(width, UI.LineHeight(tallest))
    function r:Set(...)
        for i, p in ipairs(parts) do self[p[1]]:SetText(select(i, ...) or "") end
    end
    return r
end

---@return DeathTrackerRow
function UI.Pair(parent, size, width)
    return UI.Row(parent, width, size * 0.3, {
        { "label", "body", size, "muted" }, { "value", "bold", size, "text" }, { "tail", "body", size, "muted" } })
end

function UI.WrapPair(parent, size, width, font)
    font = font or "bold"
    local r = UI.Row(parent, width, size * 0.3, { { "label", "body", size, "muted" }, { "value", font, size, "text" } })
    local line, gap = UI.LineHeight(size), size * 0.3
    r.rest = UI.Text(r, font, size, "text")
    r.rest:SetPoint("TOPLEFT", 0, -line)
    r.label:ClearAllPoints()
    r.label:SetPoint("TOPLEFT")
    function r:Set(label, value)
        self.label:SetText(label)
        local room, words, rest = width - self.label:GetUnboundedStringWidth() - gap, {}, {}
        for word in value:gmatch("%S+") do
            local into = #rest == 0 and words or rest
            into[#into + 1] = word
            self.value:SetText(table.concat(words, " "))
            if into == words and #words > 1 and self.value:GetUnboundedStringWidth() > room then
                rest[1] = table.remove(words)
            end
        end
        self.value:SetText(table.concat(words, " "))
        self.rest:SetText(table.concat(rest, " "))
        self.rest:SetShown(#rest > 0)
        self:SetHeight(#rest > 0 and 2 * line or line)
    end
    return r
end

local function topCentre(frame)
    local s = frame:GetScale()
    return { point = "TOP", x = frame:GetLeft() + frame:GetWidth() / 2 - UIParent:GetWidth() / 2 / s,
        y = frame:GetTop() - UIParent:GetTop() / s }
end

function UI.Home(store, point, x, y, under)
    if store.point then return { point = store.point, x = store.x, y = store.y } end
    return { point = point, x = x, y = y, to = under and under[1], toPoint = under and under[2] }
end

function UI.Movable(frame, store, point, x, y, under, grow)
    frame.home = UI.Home(store, point, x, y, under)
    frame.spot, frame.grow = store, grow
    UI.Offset(frame, 0)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local h
        if grow == "centre" then
            h = topCentre(self)
        else
            local p, _, _, px, py = self:GetPoint()
            h = { point = p, x = px, y = py }
        end
        store.point, store.x, store.y = h.point, h.x, h.y
        self.home = h
        UI.Offset(self, 0)
    end)
end

-- The template would resize the frame; its start and stop hooks turn the drag into a scale instead.
function UI.ResizeGrip(frame, store, key, min, max)
    local g = CreateFrame("Button", nil, frame, "PanelResizeButtonTemplate")
    g:SetPoint("BOTTOMRIGHT", -3, 3)
    g:SetFrameLevel(frame:GetFrameLevel() + 10)
    g:Init(frame, 0, 0)
    g.tooltip = "Drag to resize"
    g:HookScript("OnEnter", showTooltip)
    g:HookScript("OnLeave", hideTooltip)
    local drag
    frame.onResizeStartCallback = function()
        local s = frame:GetScale()
        drag = { cursor = GetCursorPosition() / UIParent:GetEffectiveScale(), width = frame:GetWidth() * s,
            left = frame:GetLeft() * s, top = frame:GetTop() * s }
        return false
    end
    frame.onResizeStopCallback = function() return false end
    g.resizeStoppedCallback = function()
        drag = nil
        store[key] = frame:GetScale()
        if frame.grow == "centre" then
            frame.home = topCentre(frame)
            UI.Offset(frame, 0)
        end
        local h, spot = frame.home, frame.spot
        spot.point, spot.x, spot.y = h.point, h.x, h.y
    end
    g:SetScript("OnUpdate", function(self)
        self:SetAlpha((drag or frame:IsMouseOver()) and 1 or 0)
        if not drag then return end
        local width = drag.width + GetCursorPosition() / UIParent:GetEffectiveScale() - drag.cursor
        local scale = math.min(max, math.max(min, width / frame:GetWidth()))
        frame:SetScale(scale)
        UI.FitDividers()
        frame.home = { point = "TOPLEFT", x = drag.left / scale, y = (drag.top - UIParent:GetTop()) / scale }
        UI.Offset(frame, 0)
    end)
    frame.grip = g
    return g
end

local TOAST = { rise = 0.35, hold = 7, fade = 0.8, height = 16 }
function UI.Toast(frame, close, stays, hold)
    local age, risen = 0, false
    hold = hold or TOAST.hold
    frame:SetScript("OnUpdate", function(self, elapsed)
        local over = self:IsMouseOver()
        close:SetShown(over)
        if (over or (stays and stays())) and age >= TOAST.rise then
            age = math.min(age, TOAST.rise + hold)
        else
            age = age + elapsed
        end
        if age < TOAST.rise then
            self:SetAlpha(age / TOAST.rise)
            UI.Offset(self, -TOAST.height * (1 - age / TOAST.rise))
        elseif age < TOAST.rise + hold then
            self:SetAlpha(1)
            if not risen then
                risen = true
                UI.Offset(self, 0)
            end
        elseif age < TOAST.rise + hold + TOAST.fade then
            self:SetAlpha(1 - (age - TOAST.rise - hold) / TOAST.fade)
        else
            self:Hide()
        end
    end)
    return function()
        age, risen = 0, false
        frame:SetAlpha(0)
        UI.Offset(frame, -TOAST.height)
        frame:Show()
    end
end

function UI.Offset(frame, dy)
    local h = frame.home
    frame:ClearAllPoints()
    frame:SetPoint(h.point, h.to or UIParent, h.toPoint or h.point, h.x, h.y + dy)
end

-- Never Blizzard's settings list: its rows are shared by every page, and once an addon fills them,
-- the Discord checkbox on the Audio page is blocked and blames the addon.
local OPTION = { row = 26, header = 45, gap = 9, pad = 10, indent = 15, button = 200, buttonPad = 32, buttonGap = 8 }

local function optionOn(def)
    if def.isOn and not def.isOn() then return false end
    local parent = def.under
    while parent do
        if not parent.get() then return false end
        parent = parent.under
    end
    return true
end

local function optionTip(owner, def)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT", -10, 0)
    tipLines(GameTooltip, def.label, type(def.tooltip) == "function" and def.tooltip() or def.tooltip)
    local note = def.note and def.note()
    if note then GameTooltip_AddColoredLine(GameTooltip, note, GREEN_FONT_COLOR, true) end
    GameTooltip:Show()
end

local function optionLabel(row, frame, def)
    local text = frame:CreateFontString(nil, "OVERLAY", def.under and "GameFontNormalSmall" or "GameFontNormal")
    text:SetJustifyH("LEFT")
    text:SetWordWrap(true)
    text:SetMaxLines(2)
    local depth, up = 0, def.under
    while up do depth, up = depth + 1, up.under end
    row.textX = depth * OPTION.indent + 37
    text:SetPoint("LEFT", row.textX, 0)
    text:SetPoint("RIGHT", frame, "CENTER", -85, 0)
    text:SetText(def.label)
    local hover = CreateFrame("Frame", nil, frame)
    hover:SetPoint("TOPLEFT")
    hover:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", -80, 0)
    local glow = hover:CreateTexture(nil, "BACKGROUND", "HoverBackgroundTemplate")
    hover:SetScript("OnEnter", function(self)
        glow:Show()
        optionTip(self, def)
    end)
    hover:SetScript("OnLeave", function()
        glow:Hide()
        hideTooltip()
    end)
    row.text, row.hover = text, hover
end

local OPTION_ROW = {}

function OPTION_ROW.header(_, frame, def)
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", 7, -16)
    title:SetText(def.label)
end

-- The template's tooltip writes to SettingsTooltip, which other pages share and our code would
-- taint, so the row's highlight is ours to show.
function OPTION_ROW.check(row, frame, def, refresh)
    optionLabel(row, frame, def)
    local box = CreateFrame("CheckButton", nil, frame, "SettingsCheckboxTemplate")
    box:SetPoint("LEFT", frame, "CENTER", -80, 0)
    box:SetScript("OnEnter", function(self)
        self.HoverBackground:Show()
        optionTip(self, def)
    end)
    box:SetScript("OnLeave", function(self)
        self.HoverBackground:Hide()
        hideTooltip()
    end)
    box:SetScript("OnClick", function(self)
        local on = self:GetChecked() and true or false
        PlaySound(on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        def.set(on)
        refresh()
    end)
    row.hover:SetScript("OnMouseUp", function()
        if box:IsEnabled() then box:Click() end
    end)
    row.control = box
end

function UI.Button(parent, text, width, height, onClick, title, tip)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, height)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    if title then
        button:SetScript("OnEnter", function(self) UI.HelpTip(self, title, tip, "ANCHOR_TOP") end)
        button:SetScript("OnLeave", UI.HideTooltip)
    end
    return button
end

-- Blizzard runs fill(root) whenever the button shows, not only on a click, so it only reads.
function UI.MenuButton(parent, text, width, height, fill, onOpen)
    local b = CreateFrame("DropdownButton", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, height)
    b:SetText(text)
    b:SetupMenu(function(_, root) fill(root) end)
    b:SetMenuAnchor(AnchorUtil.CreateAnchor("BOTTOMLEFT", b, "TOPLEFT", 0, 4))
    function b.Refresh() if b:IsMenuOpen() then b:GenerateMenu() end end
    if onOpen then b:RegisterCallback(DropdownButtonMixin.Event.OnMenuOpen, onOpen, b) end
    return b
end

local function optionButton(frame, def, width, x, refresh)
    local button = UI.Button(frame, def.text, width, OPTION.row, function()
        def.click()
        if refresh then refresh() end
    end)
    button:SetPoint("LEFT", frame, "CENTER", x, 0)
    button:SetMotionScriptsWhileDisabled(true)
    button:SetScript("OnEnter", function(self) optionTip(self, def) end)
    button:SetScript("OnLeave", hideTooltip)
    return button
end

function OPTION_ROW.button(row, frame, def, refresh)
    optionLabel(row, frame, def)
    row.control = optionButton(frame, def, OPTION.button, -40, refresh)
    if def.isNew then
        row.newLabel = CreateFrame("Frame", nil, frame, "NewFeatureLabelNoAnimateTemplate")
        row.newLabel:SetPoint("LEFT", row.control, "RIGHT", 8, 0)
    end
end

function OPTION_ROW.buttons(row, frame, def)
    optionLabel(row, frame, def)
    row.buttons = {}
    for i, b in ipairs(def.buttons) do
        local button = optionButton(frame, { label = b.text, text = b.text, tooltip = b.tooltip, click = b.click }, 0, -40)
        button:SetWidth(button:GetTextWidth() + OPTION.buttonPad)
        row.buttons[i] = { isOn = b.isOn, button = button }
    end
    function row.Fit(width)
        local room, x, top = width / 2 + 40 - OPTION.buttonGap, 0, 0
        for _, b in ipairs(row.buttons) do
            local w = b.button:GetWidth()
            if x > 0 and x + w > room then x, top = 0, top + OPTION.row + OPTION.buttonGap end
            b.button:ClearAllPoints()
            b.button:SetPoint("TOPLEFT", frame, "TOP", -40 + x, -top)
            x = x + w + OPTION.buttonGap
        end
        local height = top + OPTION.row
        row.text:SetPoint("LEFT", row.textX, (height - OPTION.row) / 2)
        row.text:SetPoint("RIGHT", frame, "CENTER", -85, (height - OPTION.row) / 2)
        return height
    end
end

function UI.Dropdown(parent, width, choices, get, set)
    local d = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    d:SetWidth(width)
    d:SetupMenu(function(_, root)
        for _, c in ipairs(type(choices) == "function" and choices() or choices) do
            root:CreateRadio(c.text, function(value) return get() == value end, set, c.value)
        end
    end)
    return d
end

function OPTION_ROW.dropdown(row, frame, def)
    optionLabel(row, frame, def)
    local d = UI.Dropdown(frame, 160, def.choices, def.get, def.set)
    d:SetPoint("LEFT", frame, "CENTER", -80, 0)
    d:HookScript("OnEnter", function(self) optionTip(self, def) end)
    d:HookScript("OnLeave", hideTooltip)
    row.control = d
end

function OPTION_ROW.slider(row, frame, def)
    optionLabel(row, frame, def)
    local s = CreateFrame("Frame", nil, frame, "MinimalSliderWithSteppersTemplate")
    s:SetWidth(250)
    s:SetPoint("LEFT", frame, "CENTER", -80, 3)
    local right = MinimalSliderWithSteppersMixin.Label.Right
    s:Init(def.get(), def.min, def.max, (def.max - def.min) / def.step,
        { [right] = CreateMinimalSliderFormatter(right, def.format) })
    s:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value) def.set(value) end, row)
    s.Slider:HookScript("OnEnter", function(self) optionTip(self, def) end)
    s.Slider:HookScript("OnLeave", hideTooltip)
    row.control = s
end

function UI.OptionsPage(title, defs, onDefaults)
    local page = CreateFrame("Frame")
    page:Hide()
    page.rows = {}
    function page.Refresh()
        for _, row in ipairs(page.rows) do
            local def, on = row.def, optionOn(row.def)
            if row.text then
                row.text:SetFontObject(on and (def.under and "GameFontNormalSmall" or "GameFontNormal")
                    or (def.under and "GameFontDisableSmall" or "GameFontDisable"))
            end
            if def.kind == "check" then row.control:SetChecked(def.get() and true or false) end
            if def.kind == "dropdown" then row.control:GenerateMenu() end
            if def.kind == "slider" then row.control:SetValue(def.get()) end
            if row.control then row.control:SetEnabled(on) end
            if row.newLabel then row.newLabel:SetShown(def.isNew()) end
            for _, b in ipairs(row.buttons or {}) do b.button:SetEnabled(on and (not b.isOn or b.isOn())) end
        end
    end
    local heading = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    heading:SetPoint("TOPLEFT", 7, -22)
    heading:SetText(title)
    local line = page:CreateTexture(nil, "ARTWORK")
    line:SetAtlas("Options_HorizontalDivider", true)
    line:SetPoint("TOP", 0, -50)
    local defaults = UI.Button(page, SETTINGS_DEFAULTS, 96, 22, onDefaults)
    defaults:SetPoint("TOPRIGHT", -36, -16)
    page.defaults = defaults

    local box, content, scroll = UI.ScrollArea(page)
    box:SetPoint("TOPLEFT", 0, -52)
    box:SetPoint("BOTTOMRIGHT", -26, 10)
    for i, def in ipairs(defs) do
        local frame = CreateFrame("Frame", nil, content)
        local row = { def = def, frame = frame }
        OPTION_ROW[def.kind](row, frame, def, page.Refresh)
        page.rows[i] = row
    end
    local function layoutRows(width)
        local y = OPTION.pad
        for _, row in ipairs(page.rows) do
            local height = row.def.kind == "header" and OPTION.header or OPTION.row
            if row.Fit then height = row.Fit((width or 0) - 30) end
            row.frame:ClearAllPoints()
            row.frame:SetPoint("TOPLEFT", 10, -y)
            row.frame:SetPoint("RIGHT", -20, 0)
            row.frame:SetHeight(height)
            y = y + height + OPTION.gap
        end
        content:SetHeight(y)
    end
    layoutRows(content:GetWidth())
    content:HookScript("OnSizeChanged", function(_, width) layoutRows(width) end)
    scroll()
    -- Blizzard's options window calls these: as the page shows, and from its "reset all settings".
    page.OnRefresh = page.Refresh
    page.OnDefault = function()
        for _, row in ipairs(page.rows) do
            if row.def.default ~= nil then row.def.set(row.def.default) end
        end
        page.Refresh()
    end
    page.Refresh()
    function page.Glow(key)
        for _, row in ipairs(page.rows) do
            if row.def.key == key then
                if not row.glow then
                    row.glow = UI.Glow(row.control)
                    row.control:HookScript("OnClick", function() row.glow:Hide() end)
                end
                row.glow:Show()
            end
        end
    end
    page:SetScript("OnHide", function()
        for _, row in ipairs(page.rows) do
            if row.glow then row.glow:Hide() end
        end
    end)
    return page
end

function UI.Window(name, width, height, top, store)
    local f = CreateFrame("Frame", name, UIParent, "ButtonFrameTemplate")
    f:SetSize(width, height)
    f:SetToplevel(true)
    f:SetPortraitToAsset(UI.ICON)
    ButtonFrameTemplate_HideButtonBar(f)
    FrameTemplate_SetAtticHeight(f, top)
    f.Inset.Bg:SetTexture("Interface\\Collections\\CollectionsBackgroundTile", "REPEAT", "REPEAT")
    f.wash = f.Inset:CreateTexture(nil, "BACKGROUND", nil, -4)
    f.wash:SetAllPoints(f.Inset.Bg)
    f.wash:SetColorTexture(unpack(UI.COLOR.wash))
    UI.Movable(f, store, "CENTER", 0, 0)
    table.insert(UISpecialFrames, name)
    f:Hide()
    f.sideTabs = {}
    return f
end

function UI.SideTab(window, icon, title, text, onClick, note)
    local t = CreateFrame("Frame", nil, window, "LargeSideTabButtonTemplate")
    local above = window.sideTabs[#window.sideTabs]
    if above then t:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -2) else t:SetPoint("TOPLEFT", window, "TOPRIGHT", 0, -30) end
    t.Icon:SetTexture(icon)
    t:SetFillToInterior(true)
    t.tooltipText = title
    function t:GetTooltipTextSetupFunction()
        return function(tooltip)
            local line, body = note and note(), type(text) == "function" and text() or text
            if line then
                GameTooltip_SetTitle(tooltip, title)
                UI.TipLine(tooltip, line, UI.COLOR.white)
                GameTooltip_AddNormalLine(tooltip, body, true)
            else
                tipLines(tooltip, title, body)
            end
            return true
        end
    end
    t:SetCustomOnMouseUpHandler(function(self, button, upInside)
        if button ~= "LeftButton" or not upInside then return end
        for _, other in ipairs(window.sideTabs) do other:SetChecked(other == self) end
        onClick()
    end)
    table.insert(window.sideTabs, t)
    t:SetChecked(#window.sideTabs == 1)
    return t
end

function UI.TextButton(parent, text, onClick, title, tip)
    local b = CreateFrame("Button", nil, parent)
    b.label = UI.Text(b, "body", 13, "trophy")
    b.label:SetPoint("CENTER")
    function b:SetLabel(label, tipTitle)
        self.label:SetText(label)
        self:SetSize(self.label:GetUnboundedStringWidth() + 4, 18)
        self.title = tipTitle
    end
    b:SetLabel(text, title)
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self)
        UI.Tint(self.label, UI.COLOR.white)
        if self.title then UI.HelpTip(self, self.title, tip) end
    end)
    b:SetScript("OnLeave", function(self)
        UI.Tint(self.label, UI.COLOR.trophy)
        hideTooltip()
    end)
    return b
end

---@param around table? the region to glow around; the frame itself when left out
function UI.Glow(frame, around)
    local glow = frame:CreateTexture(nil, "OVERLAY")
    glow:SetAtlas("bags-glow-white")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(unpack(UI.COLOR.trophy))
    glow:SetPoint("TOPLEFT", around or frame, "TOPLEFT", -4, 4)
    glow:SetPoint("BOTTOMRIGHT", around or frame, "BOTTOMRIGHT", 4, -4)
    local pulse = glow:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.3)
    fade:SetDuration(0.8)
    glow:HookScript("OnShow", function() pulse:Play() end)
    glow:HookScript("OnHide", function() pulse:Stop() end)
    glow:Hide()
    return glow
end

function UI.HelpTip(owner, title, text, anchor)
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    tipLines(GameTooltip, title, type(text) == "function" and text() or text)
    GameTooltip:Show()
end

local function hoverTip(frame, title, text)
    frame:HookScript("OnEnter", function(self) UI.HelpTip(self, title, text, "ANCHOR_BOTTOM") end)
    frame:HookScript("OnLeave", hideTooltip)
end

-- A frame takes the clicks under it even with only mouse motion on; propagating passes them on.
function UI.TipSpot(parent, title, text)
    local f = CreateFrame("Frame", nil, parent)
    f:SetMouseMotionEnabled(true)
    f:SetPropagateMouseClicks(true)
    hoverTip(f, title, text)
    return f
end

function UI.FilterButton(parent, fill, isDefault, reset, changed, resetTip)
    local b = CreateFrame("DropdownButton", nil, parent, "WowStyle1FilterDropdownTemplate")
    b:SetupMenu(function(_, root) fill(root) end)
    b:SetIsDefaultCallback(isDefault)
    b:SetDefaultCallback(function()
        reset()
        changed()
    end)
    b:SetUpdateCallback(changed)
    hoverTip(b, "Filter", "Choose which deaths to show.")
    hoverTip(b.ResetButton, "Reset filters", resetTip or "Shows every cause and level again.")
    return b
end

function UI.Total(parent, label, tipTitle, tipText)
    local t = CreateFrame("Frame", nil, parent)
    t.label = UI.GameText(t, "small", "faint")
    t.label:SetPoint("TOPLEFT")
    t.label:SetText(label:upper())
    t.value = UI.GameText(t, "large", "text")
    t.value:SetPoint("TOPLEFT", t.label, "BOTTOMLEFT", 0, -4)
    t:SetSize(1, 34)
    if tipTitle then
        t:EnableMouse(true)
        hoverTip(t, tipTitle, tipText)
    end
    function t:Set(value)
        self.value:SetText(value)
        self:SetWidth(math.ceil(math.max(self.value:GetUnboundedStringWidth(), self.label:GetUnboundedStringWidth())))
    end
    return t
end

function UI.Money(copper) return GetMoneyString(copper, true) end

local BIG_COINS = { "Coin-Gold", "Coin-Silver", "Coin-Copper" }
local BIG_COIN, BIG_COIN_DROP, BIG_COIN_GAP = 20, 0, 3
-- An inline texture's size and offsets grow with the font: one unit is the font size / 12.15
-- (measured: "20" drew 82 wide at 50 pt and 26 at 16 pt).
local INLINE_UNIT = 12.15

-- GetMoneyString draws its 16 px coins as tall as the text; Forever's largest coins are these 20 px atlases.
function UI.BigMoney(copper, fontSize)
    if C_CVar.GetCVarBool("colorblindMode") then return UI.Money(copper) end
    local unit = fontSize / INLINE_UNIT
    local size, gap, drop = Round(BIG_COIN / unit), Round(BIG_COIN_GAP / unit), Round(BIG_COIN_DROP / unit)
    local amounts, parts = { math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100 }, {}
    for i, n in ipairs(amounts) do
        if n > 0 or (i == 3 and #parts == 0) then
            parts[#parts + 1] = BreakUpLargeNumbers(n) .. CreateAtlasMarkup(BIG_COINS[i], size, size, gap, drop)
        end
    end
    return table.concat(parts, " ")
end

function UI.Ordinal(n)
    local tens = n % 100
    return n .. ((tens >= 11 and tens <= 13) and "th" or ({ "st", "nd", "rd" })[n % 10] or "th")
end

function UI.TipPair(label, value) return UI.Colored(label, UI.COLOR.muted) .. " " .. UI.Colored(value, UI.COLOR.white) end

function UI.IconMarkup(icon, size) return CreateSimpleTextureMarkup(icon, size, size) end

function UI.TipLine(tooltip, text, color) GameTooltip_AddColoredLine(tooltip, text, CreateColor(unpack(color))) end

-- GameTooltip_SetTitle's own default color is white, not Blizzard's gold.
function UI.Tooltip(owner, title, color, lines, help, anchor)
    if type(anchor) == "table" then
        GameTooltip:SetOwner(owner, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("TOPLEFT", owner, "TOPRIGHT", anchor:GetRight() - owner:GetRight() + 4, 0)
    elseif anchor then
        GameTooltip:SetOwner(owner, anchor)
    else
        GameTooltip:SetOwner(owner, "ANCHOR_CURSOR_RIGHT", 12, -12)
    end
    GameTooltip_SetTitle(GameTooltip, title, color and CreateColor(unpack(color)) or NORMAL_FONT_COLOR)
    for _, l in ipairs(lines) do
        local text, c = l, UI.COLOR.white
        if type(l) == "table" then text, c = l[1], l[2] or c end
        if type(l) == "table" and l.right then
            local both = CreateColor(unpack(c))
            GameTooltip_AddColoredDoubleLine(GameTooltip, text, l.right, both, both, false)
        else
            UI.TipLine(GameTooltip, text, c)
        end
    end
    if help then GameTooltip_AddNormalLine(GameTooltip, help, true) end
    GameTooltip:Show()
end

function UI.Join(...)
    local out = {}
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if v ~= nil then out[#out + 1] = v end
    end
    return table.concat(out, ", ")
end

function UI.RowLines(row, rightSize)
    row.title = UI.GameText(row, "normal", "text")
    row.title:SetPoint("TOPLEFT", 8, -7)
    row.right = UI.GameText(row, rightSize or "small", "text")
    row.right:SetPoint("TOPRIGHT", -8, rightSize == "large" and -5 or -8)
    row.right2 = UI.GameText(row, "small", "muted")
    row.right2:SetPoint("TOPRIGHT", -8, -23)
    row.line2 = UI.GameText(row, "small", "muted")
    row.line2:SetPoint("TOPLEFT", 8, -23)
    row.line2:SetPoint("RIGHT", row.right2, "LEFT", -12, 0)
    row.line2:SetWordWrap(false)
end

UI.STAT_ROW = 32
function UI.StatRow(row)
    row.label = UI.GameText(row, "normal", "muted")
    row.label:SetPoint("TOPLEFT", 8, -7)
    UI.Tint(row.label, UI.LabelColor())
    row.value = UI.GameText(row, "normal", "text")
    row.value:SetPoint("TOPRIGHT", -8, -7)
    row.line = UI.Divider(row)
    row.line:SetPoint("BOTTOMLEFT", 4, 0)
    row.line:SetPoint("BOTTOMRIGHT", -4, 0)
end

function UI.PaneRow(row, width)
    row.width = width
    row.name = UI.GameText(row, "normal", "text")
    row.name:SetPoint("LEFT", 8, 0)
    row.name:SetWordWrap(false)
    row.faction = row:CreateTexture(nil, "ARTWORK")
    row.faction:SetSize(UI.FACTION_ICON, UI.FACTION_ICON)
    row.level = UI.GameText(row, "small", "faint")
    row.level:SetPoint("LEFT", row.name, "RIGHT", 5, 0)
    row.count = UI.GameText(row, "normal", "text")
    row.count:SetPoint("RIGHT", -8, 0)
end

UI.FACTION_ICON = 18
UI.FACTION_ATLAS = { Alliance = "UI-HUD-UnitFrame-Player-PVP-AllianceIcon", Horde = "UI-HUD-UnitFrame-Player-PVP-HordeIcon" }
UI.FACTION_ASPECT = { Alliance = 28 / 41, Horde = 1 }
UI.FACTION_INLINE = 14

function UI.FactionMarkup(faction)
    local atlas = faction and UI.FACTION_ATLAS[faction]
    if not atlas then return "" end
    return CreateAtlasMarkup(atlas, math.floor(UI.FACTION_INLINE * UI.FACTION_ASPECT[faction] + 0.5), UI.FACTION_INLINE) .. " "
end

function UI.CharName(name)
    if not name then return nil end
    return UI.FactionMarkup(ns.CharFaction and ns.CharFaction(name)) .. name
end

function UI.FillPaneRow(row, name, color, level, count, selected, indent, faction, gone)
    local atlas = faction and UI.FACTION_ATLAS[faction]
    local left, width = (indent and not atlas) and 20 or 8, row:GetWidth() > 0 and row:GetWidth() or row.width
    row.faction:SetShown(atlas ~= nil)
    if atlas then
        row.faction:SetAtlas(atlas)
        row.faction:SetSize(UI.FACTION_ICON * UI.FACTION_ASPECT[faction], UI.FACTION_ICON)
        row.faction:SetPoint("LEFT", left + (UI.FACTION_ICON - UI.FACTION_ICON * UI.FACTION_ASPECT[faction]) / 2, 0)
        left = left + UI.FACTION_ICON + 3
    end
    row.name:SetPoint("LEFT", left, 0)
    row.name:SetText(name)
    UI.Tint(row.name, color or UI.COLOR.text)
    row.level:SetText(level or "")
    row.count:SetText(count)
    local room = width - left - 8 - row.count:GetUnboundedStringWidth() - 10
        - ((level or "") ~= "" and row.level:GetUnboundedStringWidth() + 5 or 0)
    row.name:SetWidth(math.max(0, math.min(math.ceil(row.name:GetUnboundedStringWidth()) + 1, math.floor(room))))
    row.tint = selected and UI.COLOR.selected or gone and UI.COLOR.gone or nil
end

function UI.FriendName(tag, char)
    local name = UI.Colored(tag and "(" .. char .. ")" or char, UI.FriendColor("character"))
    return tag and UI.Colored(tag, UI.FriendColor("bnet")) .. " " .. name or name
end

function UI.PaneHeading(row)
    row.text = UI.GameText(row, "normal", "muted")
    row.text:SetPoint("BOTTOMLEFT", 8, 5)
    row.line = UI.Divider(row)
    row.line:SetPoint("BOTTOMLEFT", 8, 1)
    row.line:SetPoint("BOTTOMRIGHT", -8, 1)
end

function UI.FillPaneHeading(row, item)
    row.text:SetText(item.text or "")
    row.line:SetShown(item.text ~= nil)
    row.tint = item.selected and UI.COLOR.selected or nil
end

function UI.FillNote(row, item)
    row.title:SetText("")
    row.summary:SetText(item.text)
    UI.Tint(row.summary, UI.COLOR.faint)
    row.line:Hide()
end

function UI.FillGroupHeading(row, title, summary)
    row.title:SetText(title)
    row.summary:SetText(summary)
    UI.Tint(row.summary, UI.COLOR.muted)
    row.line:Show()
end

function UI.RankedRow(row)
    UI.RowLines(row)
    row.rank = UI.GameText(row, "normal", "faint")
    row.rank:SetPoint("TOPLEFT", 8, -7)
    row.title:SetPoint("TOPLEFT", 30, -7)
    row.line2:SetPoint("TOPLEFT", 30, -23)
end

function UI.GroupRow(row)
    row.title = UI.GameText(row, "normal", "text")
    row.title:SetPoint("BOTTOMLEFT", 0, 7)
    row.summary = UI.GameText(row, "small", "muted")
    row.summary:SetPoint("BOTTOMLEFT", row.title, "BOTTOMRIGHT", 10, 0)
    row.line = UI.Divider(row)
    UI.Place(row, row.line, 0, 29)
    row.line:SetPoint("RIGHT")
end

function UI.Tabs(parent, names, onPick)
    local t = CreateFrame("Frame", nil, parent, "TabSystemTemplate")
    -- OnLoad already made its pool with the default tabs, which hang below a frame.
    t.tabTemplate = "TabSystemTopButtonTemplate"
    t:OnLoad()
    for i, name in ipairs(names) do
        t:AddTab(name)
        local tab = t:GetTabButton(i)
        -- Blizzard sizes a tab to its text plus 10, so a long label touches its edges.
        tab.textPadding = 20
        tab.Text:SetWidth(0)
        tab:UpdateTabWidth()
    end
    t:SetTabSelectedCallback(function(id, isUserAction) if isUserAction then onPick(id) end end)
    t:SetTab(1)
    function t.SetLabels(labels)
        for i, label in ipairs(labels) do
            local tab = t:GetTabButton(i)
            -- UpdateTabWidth measures the text, which keeps the width it was given last.
            tab.Text:SetWidth(0)
            tab.tabText = label
            tab:SetText(label)
            tab:UpdateTabWidth()
        end
        t:MarkDirty()
    end
    return t
end

function UI.TabbedList(parent, names, kinds, onPick, labelOf, emptyOf)
    local view = { pick = 1 }
    view.tabs = UI.Tabs(parent, names, function(id)
        view.pick = id
        onPick()
    end)
    view.tabs:SetPoint("TOPLEFT", 16, -10)
    view.line = UI.Divider(parent)
    UI.Place(parent, view.line, 0, 42)
    view.line:SetPoint("RIGHT")
    view.list = UI.List(parent, kinds)
    view.none = UI.GameText(parent, "normal", "muted")
    view.none:SetPoint("TOPLEFT", 24, -60)
    function view.Show(lists)
        view.none:Hide()
        local filled, pick = 0, nil
        for i, items in ipairs(lists) do
            if #items > 0 then filled, pick = filled + 1, pick or i end
        end
        local tabbed = filled > 1
        view.tabs:SetShown(tabbed)
        view.line:SetShown(tabbed)
        if tabbed then
            local labels = {}
            for i, items in ipairs(lists) do
                labels[i] = labelOf and labelOf(i, items) or names[i] .. " " .. UI.Colored(#items, UI.COLOR.faint)
            end
            view.tabs.SetLabels(labels)
            if #lists[view.pick] > 0 then pick = view.pick end
            if pick ~= view.pick and emptyOf then
                view.list.box:Hide()
                view.none:SetText(emptyOf(view.pick))
                view.none:Show()
                return true
            end
        end
        view.list.box:SetShown(pick ~= nil)
        if not pick then return false end
        view.list.box:ClearAllPoints()
        view.list.box:SetPoint("TOPLEFT", 16, tabbed and -48 or -12)
        view.list.box:SetPoint("BOTTOMRIGHT", -24, 10)
        view.list.Set(lists[pick])
        return true
    end
    return view
end

local function barWhenNeeded(box, bar)
    local function fit() bar:SetShown(box:IsShown() and box:HasScrollableExtent()) end
    local owner = {}
    box:RegisterCallback(BaseScrollBoxEvents.OnLayout, fit, owner)
    box:RegisterCallback(BaseScrollBoxEvents.OnSizeChanged, fit, owner)
    box:HookScript("OnShow", fit)
    box:HookScript("OnHide", fit)
    fit()
end

UI.WHEEL_STEP = 30
function UI.ScrollArea(parent)
    local box = CreateFrame("Frame", nil, parent, "WowScrollBox")
    local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
    bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 6, 0)
    bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 6, 0)
    local content = CreateFrame("Frame", nil, box)
    content.scrollable = true
    box:HookScript("OnSizeChanged", function(_, width) content:SetWidth(width) end)
    return box, content, function()
        local view = CreateScrollBoxLinearView()
        -- Blizzard's view steps the wheel by its first frame's height; ours holds one frame, the whole page.
        view:SetPanExtent(UI.WHEEL_STEP)
        ScrollUtil.InitScrollBoxWithScrollBar(box, bar, view)
        barWhenNeeded(box, bar)
    end
end

function UI.List(parent, kinds, barGap)
    local anyTip = false
    for _, k in pairs(kinds) do anyTip = anyTip or k.tip ~= nil end
    local list = {}
    list.bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
    list.box = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
    list.bar:SetPoint("TOPLEFT", list.box, "TOPRIGHT", barGap or 8, 0)
    list.bar:SetPoint("BOTTOMLEFT", list.box, "BOTTOMRIGHT", barGap or 8, 0)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtentCalculator(function(_, item)
        local extent = kinds[item.kind].extent
        return type(extent) == "function" and extent(item) or extent
    end)
    local function shade(row, over)
        if row.lit then
            row.lit:SetShown(over)
            over = false
        end
        local color = over and UI.COLOR.hover or row.tint
        row.fill:SetShown(color ~= nil)
        if color then row.fill:SetColor(color) end
    end
    view:SetElementFactory(function(factory, item)
        local kind = kinds[item.kind]
        factory(kind.template, function(row, data)
            -- A frame is reused for any kind with its template, so its tooltip is the kind it shows now.
            if not row.fill then
                row.fill = UI.RowFill(row)
                if anyTip then
                    row:SetScript("OnEnter", function(self)
                        local tip = kinds[self.item.kind].tip
                        shade(self, tip ~= nil)
                        if tip then tip(self, self.item) end
                    end)
                    row:SetScript("OnLeave", function(self)
                        shade(self, false)
                        hideTooltip()
                    end)
                end
                kind.build(row)
            end
            row.item = data
            kind.fill(row, data)
            UI.RoundToPixels(row)
            shade(row, kind.tip ~= nil and row:IsMouseOver())
        end)
    end)
    ScrollUtil.InitScrollBoxListWithScrollBar(list.box, list.bar, view)
    barWhenNeeded(list.box, list.bar)
    function list.Set(items)
        list.items = items
        list.box:SetDataProvider(CreateDataProvider(items), ScrollBoxConstants.RetainScrollPosition)
    end
    function list.Fit(width)
        local function size()
            local w = width - (list.bar:IsShown() and list.bar:GetWidth() + (barGap or 8) or 0)
            if list.box:GetWidth() == w then return end
            list.box:SetWidth(w)
            if list.items then list.Set(list.items) end
        end
        list.bar:HookScript("OnShow", size)
        list.bar:HookScript("OnHide", size)
        size()
    end
    function list.Reveal(matches)
        if list.box.ScrollToElementDataByPredicate then
            list.box:ScrollToElementDataByPredicate(matches, ScrollBoxConstants.AlignCenter)
        end
    end
    function list.Height(items)
        local h = 0
        for _, item in ipairs(items) do
            local extent = kinds[item.kind].extent
            h = h + (type(extent) == "function" and extent(item) or extent)
        end
        return h
    end
    return list
end

-- Blizzard's achievement rows read real achievement IDs, so these are our own frames.
local function atlas(parent, name, layer, sub)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub)
    t:SetAtlas(name)
    return t
end

local function checkMark(parent)
    local t = atlas(parent, "worldquest-tracker-checkmark", "OVERLAY")
    t:SetSize(12, 11)
    return t
end

function UI.Fraction(n, goal) return ("%s / %s"):format(BreakUpLargeNumbers(n), BreakUpLargeNumbers(goal)) end

local BAR_RADIUS = 4
function UI.ProgressBar(parent, width, height)
    local b = CreateFrame("Frame", nil, parent)
    b:SetSize(width, height or 14)
    UI.RoundedFill(b, BAR_RADIUS, "BACKGROUND"):SetColor(UI.COLOR.barTrack)
    UI.RoundedEdge(b, BAR_RADIUS, "ARTWORK"):SetColor(UI.COLOR.barEdge)
    local outside = b:CreateTexture()
    outside:SetPoint("TOPLEFT", -1, 1)
    outside:SetPoint("BOTTOMRIGHT", 1, -1)
    UI.RoundedEdge(b, BAR_RADIUS + 1, "ARTWORK", outside):SetColor(UI.COLOR.barOutline)
    b.fill = b:CreateTexture()
    b.fill:SetPoint("TOPLEFT", 1, -1)
    b.fill:SetPoint("BOTTOMLEFT", 1, 1)
    b.green = UI.RoundedFill(b, BAR_RADIUS - 1, "BORDER", 0, b.fill)
    b.green:SetColor(UI.COLOR.barFill)
    b.squareEnd = b:CreateTexture(nil, "BORDER")
    b.squareEnd:SetColorTexture(unpack(UI.COLOR.barFill))
    b.squareEnd:SetPoint("TOPLEFT", b.fill, "TOP")
    b.squareEnd:SetPoint("BOTTOMRIGHT", b.fill)
    b.text = UI.GameText(b, "small", "white")
    b.text:SetAllPoints()
    b.text:SetJustifyH("CENTER")
    b.text:SetJustifyV("MIDDLE")
    function b:Set(n, goal, text)
        local part = math.min(n, goal) / math.max(goal, 1)
        self.fill:SetWidth(math.max(part * (width - 2), 2 * (BAR_RADIUS - 1)))
        self.green:SetShown(part > 0)
        self.squareEnd:SetShown(part > 0 and part < 1)
        self.text:SetText(text or UI.Fraction(n, goal))
    end
    return b
end

local DETAIL = { pad = 14, hit = 46, hitShort = 34, pick = 20, icon = 32, text = 36, gap = 8 }
function UI.DetailsPanel(parent, width)
    local p = CreateFrame("Frame", nil, parent)
    p:SetWidth(width)
    p.line = UI.Divider(p, true)
    p.line:SetPoint("TOPLEFT")
    p.line:SetPoint("BOTTOMLEFT")
    local box, content, scroll = UI.ScrollArea(p)
    box:SetPoint("TOPLEFT", 1, -4)
    box:SetPoint("BOTTOMRIGHT", -16, 8)
    scroll()
    local inner = width - 17 - 2 * DETAIL.pad
    local pools, used, y = {}, {}, 0
    p.pools = pools
    local spells, clicks = {}, {}

    local function reuse(kind, make)
        pools[kind] = pools[kind] or {}
        used[kind] = (used[kind] or 0) + 1
        local f = pools[kind][used[kind]]
        if not f then
            f = make()
            pools[kind][used[kind]] = f
        end
        f:Show()
        return f
    end

    local function putNext(f, height, gapAfter)
        UI.Place(content, f, DETAIL.pad, y)
        y = y + height + (gapAfter or 0)
    end

    local function text(size, color)
        return function()
            local t = UI.GameText(content, size, color)
            t:SetWidth(inner)
            t:SetWordWrap(true)
            return t
        end
    end

    function p:Begin()
        for _, pool in pairs(pools) do for _, f in ipairs(pool) do f:Hide() end end
        used, y = {}, DETAIL.pad
    end

    function p:Title(value, color)
        local t = reuse("title", text("large", "text"))
        t:SetText(value)
        UI.Tint(t, color or UI.COLOR.text)
        putNext(t, t:GetStringHeight(), 3)
    end

    function p:Line(value, color)
        local t = reuse("line", text("small", "muted"))
        t:SetText(value)
        UI.Tint(t, UI.COLOR[color or "muted"])
        putNext(t, t:GetStringHeight(), 2)
    end

    function p:Quip(value)
        local t = reuse("quip", function()
            local q = UI.Text(content, "italic", 14, "joke")
            q:SetWidth(inner)
            q:SetWordWrap(true)
            return q
        end)
        t:SetText(value)
        y = y + 6
        putNext(t, t:GetStringHeight(), 2)
    end

    function p:Stats(stats)
        y = y + DETAIL.gap - 2
        local top = reuse("rule", function() return UI.Divider(content) end)
        top:SetWidth(inner)
        putNext(top, 1, DETAIL.gap)
        local x = DETAIL.pad
        for _, s in ipairs(stats) do
            local t = reuse("stat", function() return UI.Total(content, "") end)
            t.label:SetText(s[1]:upper())
            t:Set(s[2])
            UI.Place(content, t, x, y)
            x = x + t:GetWidth() + 20
        end
        y = y + 34 + DETAIL.gap
        local bottom = reuse("rule", function() return UI.Divider(content) end)
        bottom:SetWidth(inner)
        putNext(bottom, 1, DETAIL.gap)
    end

    function p:Label(value)
        local t = reuse("label", text("small", "faint"))
        t:SetText(value)
        y = y + 8
        putNext(t, t:GetStringHeight(), 8)
    end

    function p:Space(px) y = y + px end

    function p:Hit(hit)
        local r = reuse("hit", function()
            local f = CreateFrame("Frame", nil, content)
            f:SetSize(inner, DETAIL.hit)
            local frame, icon = UI.FramedIcon(f, DETAIL.icon)
            frame:SetPoint("TOPLEFT", -3, 0)
            icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            f.frame, f.icon = frame, icon
            f.name = UI.GameText(f, "normal", "white")
            f.amount = UI.GameText(f, "normal", "text")
            f.name:SetPoint("RIGHT", f.amount, "LEFT", -8, 0)
            f.name:SetWordWrap(false)
            f.note = UI.GameText(f, "small", "faint")
            f.note:SetWordWrap(true)
            f.bar = UI.ProgressBar(f, inner - DETAIL.text, 8)
            f:SetScript("OnEnter", function(self)
                local spell = spells[self]
                if not spell then return end
                GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                GameTooltip:SetSpellByID(spell.id)
                if spell.tipLine then UI.TipLine(GameTooltip, spell.tipLine, UI.COLOR.muted) end
                GameTooltip:Show()
            end)
            f:SetScript("OnLeave", hideTooltip)
            return f
        end)
        spells[r] = hit.spellId and { id = hit.spellId, tipLine = hit.tipLine } or nil
        r:EnableMouse(hit.spellId ~= nil)
        r.icon:SetTexture(hit.icon)
        r.icon:SetShown(hit.icon ~= nil)
        r.frame:SetShown(hit.icon ~= nil)
        local left = hit.icon and DETAIL.text or 0
        local nameY = (hit.note or "") == "" and -9 or -4
        r.name:SetPoint("TOPLEFT", left, nameY)
        r.amount:SetPoint("TOPRIGHT", 0, nameY)
        r.note:SetPoint("TOPLEFT", left, -19)
        r.note:SetWidth(inner - left)
        r.note:SetText("A")
        local oneLine = r.note:GetStringHeight()
        r.note:SetText(hit.note or "")
        local extra = math.max(0, r.note:GetStringHeight() - oneLine)
        r.bar:SetPoint("TOPLEFT", left, -36 - extra)
        r.name:SetText(hit.name)
        r.amount:SetText(hit.amount or "")
        r.bar:SetShown(hit.part ~= nil)
        if hit.part then r.bar:Set(hit.part * 100, 100, "") end
        local height = (hit.part and DETAIL.hit or DETAIL.hitShort) + extra
        r:SetHeight(height)
        putNext(r, height, 6)
    end

    function p:Pick(left, color, right, onClick, tipTitle, tip)
        local r = reuse("pick", function()
            local f = CreateFrame("Button", nil, content)
            f:SetSize(inner + 8, DETAIL.pick)
            f.fill = UI.RowFill(f, UI.COLOR.hover)
            f.fill:SetShown(false)
            f.left = UI.GameText(f, "normal", "text")
            f.left:SetPoint("LEFT", 4, 0)
            f.right = UI.GameText(f, "normal", "text")
            f.right:SetPoint("RIGHT", -4, 0)
            f.left:SetPoint("RIGHT", f.right, "LEFT", -8, 0)
            f.left:SetWordWrap(false)
            f:SetScript("OnEnter", function(self)
                local c = clicks[self]
                if not c then return end
                self.fill:SetShown(true)
                if c.tipTitle then UI.HelpTip(self, c.tipTitle, c.tip) end
            end)
            f:SetScript("OnLeave", function(self)
                self.fill:SetShown(false)
                hideTooltip()
            end)
            f:SetScript("OnClick", function(self) if clicks[self] then clicks[self].onClick() end end)
            return f
        end)
        r.left:SetText(left)
        UI.Tint(r.left, color or UI.COLOR.text)
        r.right:SetText(right or "")
        clicks[r] = onClick and { onClick = onClick, tipTitle = tipTitle, tip = tip } or nil
        r:EnableMouse(onClick ~= nil)
        UI.Place(content, r, DETAIL.pad - 4, y)
        y = y + DETAIL.pick + 1
    end

    function p:Button(label, onClick, tipTitle, tip)
        local b = reuse("button", function() return UI.Button(content, "", 100, 22, function() end) end)
        b:SetText(label)
        b:SetWidth(math.min(inner, b:GetTextWidth() + 28))
        b:SetScript("OnClick", onClick)
        b:SetScript("OnEnter", function(self) UI.HelpTip(self, tipTitle, tip, "ANCHOR_TOP") end)
        b:SetScript("OnLeave", hideTooltip)
        y = y + DETAIL.gap
        putNext(b, 22)
    end

    function p:Done()
        content:SetHeight(y + DETAIL.pad)
        if box.FullUpdate then box:FullUpdate(true) end
        if box.ScrollToBegin then box:ScrollToBegin() end
    end

    return p
end

local SHIELDS = "Interface\\AchievementFrame\\UI-Achievement-Shields"

function UI.ShieldMarkup(size) return CreateTextureMarkup(SHIELDS, 128, 128, size, size, 0, 0.5, 0, 0.5) end
UI.CARD = 80
UI.CARD_CELL = 22
UI.CARD_CELLS = 10
local CARD_PAD, CELL_GAP, CARD_TEXT, CARD_RIGHT = 8, 4, 74, 70
local CARD_NAME, CARD_LINE, CARD_BAR, CARD_GAP = 14, 12, 14, 7

local CELL_LEFT, CELL_RIGHT, CHECK_GAP = 8, 6, 4

function UI.CardHeight(cells) return UI.CARD + math.ceil(cells / 2) * (UI.CARD_CELL + CELL_GAP) + CARD_PAD end

local function cardCells(row, c)
    c.cells = {}
    for i = 1, UI.CARD_CELLS do
        local cell = CreateFrame("Frame", nil, row)
        cell:SetHeight(UI.CARD_CELL)
        cell.bg = atlas(cell, "Legacy-Challenge-Cards-Bar", "BACKGROUND")
        cell.bg:SetAllPoints()
        cell.text = UI.GameText(cell, "small", "white")
        cell.text:SetPoint("LEFT", CELL_LEFT, 0)
        UI.Fit(cell.text, 1, 0.7)
        cell.check = checkMark(cell)
        cell.check:SetPoint("RIGHT", -CELL_RIGHT, 0)
        if i % 2 == 1 then
            cell:SetPoint("TOPLEFT", row, "TOPLEFT", CARD_TEXT, -(UI.CARD + (i - 1) / 2 * (UI.CARD_CELL + CELL_GAP)))
        else
            cell:SetPoint("TOPLEFT", c.cells[i - 1], "TOPRIGHT", CELL_GAP, 0)
        end
        c.cells[i] = cell
    end
    row:HookScript("OnSizeChanged", function(_, width)
        c.ribbon:SetWidth(width * 0.78)
        for _, cell in ipairs(c.cells) do
            cell:SetWidth((width - 2 * CARD_TEXT - CELL_GAP) / 2)
            cell.text:SetWidth(cell:GetWidth() - CELL_LEFT - CHECK_GAP - cell.check:GetWidth() - CELL_RIGHT)
            cell.text:ScaleTextToFit()
        end
    end)
end

function UI.FramedIcon(parent, size)
    local frame = atlas(parent, "Legacy-Tree-Frame-icon-frame", "OVERLAY")
    frame:SetSize(size, size)
    local icon = parent:CreateTexture(nil, "ARTWORK")
    local inner = math.floor(size * 42 / 58 + 0.5)
    icon:SetSize(inner, inner)
    icon:SetPoint("CENTER", frame)
    return frame, icon
end

local WIN = { shineW = 92, delay = 0.3, sweep = 0.9, fade = 0.3, shine = 0.9 }

-- A win on a popup: its framed icon glowing, one shine across.
function UI.Win(frame, icon)
    local glow = UI.Glow(frame, icon)
    local shine = atlas(frame, "Evergreen-toast-celebration-Shine", "OVERLAY")
    shine:SetBlendMode("ADD")
    shine:SetWidth(WIN.shineW)
    shine:SetPoint("TOPRIGHT", frame, "TOPLEFT")
    shine:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT")
    shine:SetAlpha(0)
    local sweep = shine:CreateAnimationGroup()
    local move = sweep:CreateAnimation("Translation")
    move:SetStartDelay(WIN.delay)
    move:SetDuration(WIN.sweep)
    move:SetSmoothing("IN_OUT")
    local show = sweep:CreateAnimation("Alpha")
    show:SetStartDelay(WIN.delay)
    show:SetDuration(WIN.fade)
    show:SetFromAlpha(0)
    show:SetToAlpha(WIN.shine)
    local hide = sweep:CreateAnimation("Alpha")
    hide:SetStartDelay(WIN.delay + WIN.sweep - WIN.fade)
    hide:SetDuration(WIN.fade)
    hide:SetFromAlpha(WIN.shine)
    hide:SetToAlpha(0)
    local win = {}
    function win.Show(on)
        glow:SetShown(on)
        shine:SetShown(on)
    end
    function win.Play()
        sweep:Stop()
        move:SetOffset(frame:GetWidth() + WIN.shineW, 0)
        sweep:Play()
    end
    win.Show(false)
    return win
end

function UI.TrophyCard(row)
    local c = {}
    c.bg = atlas(row, "Legacy-Challenge-Cards", "BACKGROUND")
    c.bg:SetPoint("TOPLEFT")
    c.bg:SetPoint("BOTTOMRIGHT", 0, 2)
    c.ribbon = atlas(row, "Legacy-Challenge-Cards-Ribbon-Brown", "BORDER")
    c.ribbon:SetPoint("TOPLEFT", 4, -4)
    c.ribbon:SetHeight(18)
    c.iconFrame, c.icon = UI.FramedIcon(row, 58)
    c.iconFrame:SetPoint("TOPLEFT", 8, -11)
    c.title = UI.GameText(row, "normal", "white")
    c.title:SetPoint("TOPLEFT", CARD_TEXT, -10)
    c.line = UI.GameText(row, "small", "muted")
    c.line:SetPoint("TOPLEFT", CARD_TEXT, -30)
    c.line:SetPoint("RIGHT", row, "RIGHT", -CARD_RIGHT, 0)
    c.line:SetWordWrap(false)
    c.bar = UI.ProgressBar(row, 250)
    c.bar:SetPoint("TOPLEFT", CARD_TEXT + 4, -52)
    c.shield = row:CreateTexture(nil, "ARTWORK")
    c.shield:SetTexture(SHIELDS)
    c.shield:SetSize(52, 52)
    c.shield:SetPoint("TOPRIGHT", -12, -21)
    -- The shield's dark plate sits above its middle: the number raised to it.
    c.points = UI.GameText(row, "normal", "white")
    c.points:SetPoint("CENTER", c.shield, "CENTER", 0, 4)
    c.dateBg = atlas(row, "Legacy-Challenge-Cards-Date-BG", "BORDER")
    c.dateBg:SetSize(104, 17)
    c.dateBg:SetPoint("TOPRIGHT", -3, -2)
    c.check = checkMark(row)
    c.check:SetPoint("RIGHT", c.dateBg, "RIGHT", -5, 0)
    c.date = UI.GameText(row, "small", "white")
    c.date:SetPoint("RIGHT", c.check, "LEFT", -4, 0)
    c.lit = atlas(row, "Legacy-Challenge-Cards", "BACKGROUND", 1)
    c.lit:SetAllPoints(c.bg)
    c.lit:SetBlendMode("ADD")
    c.lit:SetAlpha(0.3)
    c.lit:Hide()
    row.lit = c.lit
    c.selected = atlas(row, "Legacy-Challenge-Cards-selected", "OVERLAY", 7)
    c.selected:SetPoint("TOPLEFT", -2, 2)
    c.selected:SetPoint("BOTTOMRIGHT", 2, 0)
    cardCells(row, c)
    function c:Set(t)
        local card = t.earned and "Legacy-Challenge-Cards" or "Legacy-Challenge-Cards-Disable"
        self.bg:SetAtlas(card)
        self.lit:SetAtlas(card)
        self.ribbon:SetAtlas(t.earned and "Legacy-Challenge-Cards-Ribbon-Brown" or "Legacy-Challenge-Cards-Ribbon-Brown-Disable")
        self.icon:SetTexture(t.icon)
        self.icon:SetDesaturated(not t.earned)
        self.title:SetText(t.name)
        UI.Tint(self.title, t.earned and UI.COLOR.white or UI.COLOR.muted)
        self.line:SetText(t.line)
        UI.Tint(self.line, t.earned and UI.COLOR.text or UI.COLOR.faint)
        self.bar:SetShown(t.progress ~= nil)
        if t.progress then self.bar:Set(t.progress[1], t.progress[2], t.progress[3]) end
        local block = CARD_NAME + CARD_GAP + CARD_LINE + (t.progress and CARD_GAP + CARD_BAR or 0)
        local y = -math.floor((UI.CARD - block) / 2)
        self.title:SetPoint("TOPLEFT", CARD_TEXT, y)
        self.line:SetPoint("TOPLEFT", CARD_TEXT, y - CARD_NAME - CARD_GAP)
        self.bar:SetPoint("TOPLEFT", CARD_TEXT + 4, y - CARD_NAME - CARD_LINE - 2 * CARD_GAP)
        if t.earned then self.shield:SetTexCoord(0, 0.5, 0, 0.5) else self.shield:SetTexCoord(0.5, 1, 0, 0.5) end
        self.points:SetText(t.points)
        UI.Tint(self.points, t.earned and UI.COLOR.white or UI.COLOR.muted)
        for _, part in ipairs({ self.dateBg, self.check, self.date }) do part:SetShown(t.date ~= nil) end
        self.date:SetText(t.date or "")
        UI.Tint(self.date, UI.LabelColor())
        self.selected:SetShown(t.open == true)
        for i, cell in ipairs(self.cells) do
            local part = t.open and t.cells and t.cells[i]
            cell:SetShown(part ~= nil and part ~= false)
            if part then
                cell.text:SetText(part[1])
                UI.Tint(cell.text, part[2] and UI.COLOR.white or UI.COLOR.faint)
                cell.check:SetShown(part[2] == true)
            end
        end
    end
    row.card = c
    return c
end

function UI.TabRow(row)
    row.tab = atlas(row, "Legacy-Challenge-Left-Sub-Tab", "BACKGROUND")
    row.tab:SetPoint("TOPLEFT", 0, -1)
    row.tab:SetPoint("BOTTOMRIGHT", 0, 1)
    row.name = UI.GameText(row, "normal", "text")
    row.name:SetPoint("LEFT", row.tab, "LEFT", 10, 0)
    row.count = UI.GameText(row, "small", "muted")
    row.count:SetPoint("RIGHT", -10, 0)
end

function UI.FillTabRow(row, name, count, selected, indent)
    row.tab:SetPoint("TOPLEFT", indent and 8 or 0, -1)
    row.tab:SetAtlas(selected and "Legacy-Challenge-Left-Sub-Tab-selected" or "Legacy-Challenge-Left-Sub-Tab")
    row.name:SetText(name)
    UI.Tint(row.name, (selected or indent) and UI.COLOR.white or UI.LabelColor())
    row.count:SetText(count)
end

local SHOW = { width = 560, height = 330, padX = 36, padTop = 38, padBottom = 28, gap = 10, rise = 10, grow = 0.6,
    fade = 0.4, model = 210, modelHeight = 264, bars = 50, barGap = 3, roastGap = 14, icon = 72, iconGap = 16, row = 26, rowGap = 2, rowPad = 12, rowsAfter = 10, secs = 4, back = 1 / 3,
    corner = 120, cell = 34, cellGap = 12, cellGapTight = 7, colGap = 26, track = 3, trackGap = 4, titleMin = 18 }

local function ease(p)
    p = math.max(0, math.min(1, p))
    return 1 - (1 - p) ^ 3
end

---@class DeathTrackerSlidePiece: Frame
---@field bars table[]
---@field left FontString
---@field mid FontString
---@field right FontString
---@field tint table
---@field num FontString
---@field word FontString
---@field name FontString
---@field value FontString
---@field label FontString
---@field icon Texture

---@return DeathTrackerSlidePiece
local function slidePiece(s, kind, make)
    s.pool[kind] = s.pool[kind] or {}
    s.n[kind] = (s.n[kind] or 0) + 1
    local p = s.pool[kind][s.n[kind]]
    if not p then
        p = CreateFrame("Frame", nil, s) --[[@as DeathTrackerSlidePiece]]
        make(p)
        s.pool[kind][s.n[kind]] = p
    end
    p:Show()
    return p
end

local function slideText(s, font, size, color, value, width)
    local p = slidePiece(s, font .. size, function(p)
        p.text = UI.Text(p, font, size, "text")
        p.text:SetPoint("TOPLEFT")
    end)
    p.text:SetWidth(width)
    p.text:SetText(value)
    UI.Tint(p.text, color)
    local h = p.text:GetStringHeight()
    p:SetSize(width, h)
    return p, h
end

local function slideBars(s, b, width)
    local p = slidePiece(s, "bars", function(p) p.bars = {} end)
    p:SetSize(width, SHOW.bars)
    local n, most = #b.values, 1
    for _, v in ipairs(b.values) do most = math.max(most, v) end
    local barWidth = (width - SHOW.barGap * (n - 1)) / n
    local per = math.min(11, SHOW.bars / most)
    for k = 1, math.max(n, #p.bars) do
        if k <= n and not p.bars[k] then p.bars[k] = p:CreateTexture(nil, "ARTWORK") end
        local bar = p.bars[k]
        bar:SetShown(k <= n)
        if k <= n then
            bar:SetColorTexture(unpack(k == b.pick and UI.COLOR.text or UI.COLOR.slideBar))
            bar:SetWidth(barWidth)
            bar:ClearAllPoints()
            bar:SetPoint("BOTTOMLEFT", (k - 1) * (barWidth + SHOW.barGap), 0)
            bar.full = math.max(2, b.values[k] * per)
        end
    end
    local tick = function(age)
        for k = 1, n do
            local grown = ease((age - 0.9 - (k - 1) * 0.03) / 0.3)
            p.bars[k]:SetShown(grown > 0)
            p.bars[k]:SetHeight(math.max(1, p.bars[k].full * grown))
        end
    end
    local under = slidePiece(s, "barLabels", function(q)
        q.left, q.mid, q.right = UI.Text(q, "body", 12, "faint"), UI.Text(q, "body", 12, "text"), UI.Text(q, "body", 12, "faint")
        q.left:SetPoint("TOPLEFT")
        q.mid:SetPoint("TOP")
        q.right:SetPoint("TOPRIGHT")
    end)
    under.left:SetText(b.left)
    under.mid:SetText(b.mid or "")
    under.right:SetText(b.right)
    under:SetSize(width, UI.LineHeight(12))
    return p, tick, under
end

local function slideRow(s, r, width)
    local p = slidePiece(s, "row", function(p)
        p.tint = UI.RowFill(p, UI.COLOR.hover)
        p.name = UI.Text(p, "body", 15, "text")
        p.name:SetPoint("LEFT", SHOW.rowPad, 0)
        p.value = UI.Text(p, "body", 15, "text")
        p.value:SetPoint("RIGHT", -SHOW.rowPad, 0)
    end)
    p.tint:SetShown(r.tint == true)
    p.name:SetText(r.name)
    p.value:SetText(r.value)
    p:SetSize(width, SHOW.row)
    return p
end

local function slideCount(s, d, width)
    local p = slidePiece(s, "count", function(p)
        p.num = UI.Text(p, "number", 72, "text")
        p.num:SetPoint("TOPLEFT")
        p.word = UI.Text(p, "body", 19, "muted")
        p.word:SetPoint("BOTTOMLEFT", p.num, "BOTTOMRIGHT", 14, 13)
    end)
    p.word:SetText(d.countWord)
    p:SetSize(width, UI.LineHeight(72, 1.1))
    return p, function(age)
        p.num:SetText(tostring(math.floor(d.count * ease((age - 0.4) / 1.4) + 0.5)))
        p.word:SetAlpha(ease((age - 0.7) / SHOW.grow))
    end
end

local function slideCorner(s, corner)
    local p = slidePiece(s, "corner", function(p)
        p.num = UI.Text(p, "number", 40, "text")
        p.num:SetPoint("TOPRIGHT")
        p.num:SetJustifyH("RIGHT")
        p.word = UI.Text(p, "body", 13, "faint")
        p.word:SetPoint("TOPRIGHT", p.num, "BOTTOMRIGHT", 0, -2)
    end)
    p.num:SetText(corner.count)
    p.word:SetText(corner.word)
    p:SetSize(SHOW.corner, UI.LineHeight(40, 1.1) + 18)
    return p
end

local function slideCell(s, c, width)
    local p = slidePiece(s, "cell", function(p)
        p.label = UI.Text(p, "body", 12, "faint")
        p.label:SetPoint("TOPLEFT")
        p.value = UI.Text(p, "body", 15, "text")
        p.value:SetPoint("TOPLEFT", p.label, "BOTTOMLEFT", 0, -2)
    end)
    p.label:SetText(c.label)
    p.value:SetWidth(width)
    p.value:SetText(c.value)
    UI.Tint(p.value, c.color or UI.COLOR.text)
    local h = SHOW.cell + p.value:GetStringHeight() - UI.LineHeight(15)
    p:SetSize(width, h)
    return p, h
end

local function placeSlide(s, d, room, titleSize, cellGap)
    for _, list in pairs(s.pool) do for _, p in ipairs(list) do p:Hide() end end
    s.n, s.items, s.ticks = {}, {}, {}
    local full = SHOW.width - 2 * SHOW.padX
    local x, width, y = 0, full, 0
    s.scene:SetShown(d.npc ~= nil)
    if d.npc then
        s.creature(d.npc, 1)
        x = SHOW.model + 20
        width = full - x
    end
    local function item(p, ix, iy, delay) s.items[#s.items + 1] = { frame = p, x = ix, y = iy, delay = delay } end
    local function stackPiece(p, h, delay, gap, dx)
        if #s.items > 0 then y = y + (gap or SHOW.gap) end
        item(p, x + (dx or 0), y, delay)
        y = y + h
    end
    local function stackText(font, size, color, value, w, delay, gap)
        local p, h = slideText(s, font, size, color, value, w)
        stackPiece(p, h, delay, gap)
    end
    local textWidth = d.corner and width - SHOW.corner or width
    local icon = d.icon or d.iconAtlas
    if icon then
        local p = slidePiece(s, "icon", function(p)
            local frame
            frame, p.icon = UI.FramedIcon(p, SHOW.icon)
            frame:SetPoint("CENTER")
        end)
        p:SetSize(SHOW.icon, SHOW.icon)
        if d.iconAtlas then p.icon:SetAtlas(d.iconAtlas) else p.icon:SetTexture(d.icon) end
        item(p, 0, 0, 0.15)
        x = SHOW.icon + SHOW.iconGap
        textWidth = width - x
    end
    if d.label then stackText("bold", 13, UI.COLOR.faint, UI.Spaced(d.label, "thin"), textWidth, 0.15) end
    local cut, wrapped = false, false
    if d.title then
        local p, h = slideText(s, "number", titleSize, d.titleColor or UI.COLOR.text, d.title, textWidth)
        stackPiece(p, h, 0.35)
        cut, wrapped = p.text:IsTruncated(), h > UI.LineHeight(titleSize, 1.1) * 1.5
    end
    if icon then x, y = 0, math.max(y, SHOW.icon) end
    if d.count then
        local p, tick = slideCount(s, d, width)
        stackPiece(p, p:GetHeight(), 0.35)
        s.ticks[#s.ticks + 1] = tick
    end
    for _, l in ipairs(d.lines or {}) do
        stackText("body", 17, l.color or UI.COLOR.muted, l.text, width, 0.7)
    end
    if d.bars then
        local p, tick, under = slideBars(s, d.bars, width)
        stackPiece(p, SHOW.bars, 0, 6)
        s.ticks[#s.ticks + 1] = tick
        stackPiece(under, under:GetHeight(), 1.5, 4)
    end
    for k, r in ipairs(d.rows or {}) do stackPiece(slideRow(s, r, width), SHOW.row, 0.9 + (k - 1) * 0.12, k == 1 and SHOW.rowsAfter or SHOW.rowGap) end
    if d.more then
        local p, h = slideText(s, "body", 14, UI.COLOR.faint, d.more, width - 2 * SHOW.rowPad)
        stackPiece(p, h, 0.9 + #(d.rows or {}) * 0.12, SHOW.rowGap, SHOW.rowPad)
    end
    if d.roast then stackText("italic", 17, UI.COLOR.joke, d.roast, width, 1.6, SHOW.roastGap) end
    if d.corner then
        local p = slideCorner(s, d.corner)
        item(p, full - SHOW.corner, 0, 0.35)
        y = math.max(y, p:GetHeight())
    end
    if d.grid then
        local line = slidePiece(s, "gridLine", function(p)
            p.line = UI.Divider(p)
            p.line:SetAllPoints()
        end)
        line:SetSize(width, 1)
        stackPiece(line, 1, 0.7, 12)
        local top, colWidth = y + 14, (width - SHOW.colGap) / 2
        for k = 1, #d.grid, 2 do
            local tallest = 0
            for col = 0, 1 do
                local c = d.grid[k + col]
                if c then
                    local p, h = slideCell(s, c, colWidth)
                    item(p, x + col * (colWidth + SHOW.colGap), top, 0.4 + (k + col - 1) * 0.12)
                    tallest = math.max(tallest, h)
                end
            end
            top = top + tallest + cellGap
        end
        y = top - cellGap
    end
    local shift = d.top and 0 or math.max(0, (room - y) / 2)
    for _, it in ipairs(s.items) do it.y = it.y + shift end
    return y, cut, wrapped
end

local function layoutSlide(s, d, room)
    local fit, size, gap = SHOW.height - SHOW.padTop - SHOW.padBottom, d.titleSize or 44, SHOW.cellGap
    local y, cut, wrapped = placeSlide(s, d, room, size, gap)
    if d.grid and y > fit then
        gap = SHOW.cellGapTight
        y, cut, wrapped = placeSlide(s, d, room, size, gap)
    end
    while (cut or wrapped and y > fit) and size > SHOW.titleMin do
        size = size - 1
        y, cut, wrapped = placeSlide(s, d, room, size, gap)
    end
    return y
end

function UI.SlideShow(name, store)
    local f = CreateFrame("Frame", name, UIParent)
    f:SetSize(SHOW.width, SHOW.height)
    UI.Movable(f, store, "CENTER", 0, 40)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:Hide()
    rounded(f, "PanelFill", UI.COLOR.cardPanel, "BACKGROUND")
    rounded(f, "PanelBorder", UI.COLOR.cardBorder, "BORDER")
    UI.Shadow(f, 4)
    table.insert(UISpecialFrames, name)
    f.close = UI.CloseButton(f, CLOSE, function() f:Hide() end)
    f.close:SetPoint("TOPRIGHT", -6, -4)
    local segs, frames, slides, index, age = {}, {}, {}, 0, 0
    local function slideFrame(i)
        if not frames[i] then
            local s = CreateFrame("Frame", nil, f)
            s:SetPoint("TOPLEFT", SHOW.padX, -SHOW.padTop)
            s:SetPoint("BOTTOMRIGHT", -SHOW.padX, SHOW.padBottom)
            s.pool = {}
            s.scene, s.creature = UI.Model(s, SHOW.model, SHOW.modelHeight)
            s.scene:SetPoint("LEFT")
            frames[i] = s
        end
        return frames[i]
    end
    local function riseItems(s)
        for _, it in ipairs(s.items) do
            local grown = ease((age - it.delay) / SHOW.grow)
            it.frame:SetAlpha(grown)
            it.frame:SetPoint("TOPLEFT", s, "TOPLEFT", it.x, -it.y - SHOW.rise * (1 - grown))
        end
        for _, tick in ipairs(s.ticks) do tick(age) end
        if s.scene:IsShown() then
            local actor = s.scene:GetActorByTag("pet")
            if actor then actor:SetYaw(age * 0.5) end
        end
    end
    local function progress()
        for k, seg in ipairs(segs) do
            local part = k < index and 1 or k == index and math.min(1, age / (slides[k].secs or SHOW.secs)) or 0
            seg.fill:SetShown(k <= #slides and part > 0)
            seg.fill:SetWidth(math.max(1, seg.width * part))
        end
    end
    local function go(i)
        if frames[index] then frames[index]:Hide() end
        index, age = i, 0
        local s = slideFrame(i)
        layoutSlide(s, slides[i], f:GetHeight() - SHOW.padTop - SHOW.padBottom)
        s:SetAlpha(0)
        s:Show()
        riseItems(s)
        progress()
    end
    f:SetScript("OnUpdate", function(_, elapsed)
        age = age + elapsed
        local s = frames[index]
        s:SetAlpha(math.min(1, age / SHOW.fade))
        riseItems(s)
        progress()
        if index < #slides and age >= (slides[index].secs or SHOW.secs) then go(index + 1) end
    end)
    -- The game still sends OnMouseUp when a drag ends.
    f:HookScript("OnDragStart", function() f.dragged = true end)
    f:SetScript("OnMouseUp", function(_, button)
        if f.dragged then f.dragged = nil return end
        if button ~= "LeftButton" then return end
        local x = GetCursorPosition() / UIParent:GetEffectiveScale() - f:GetLeft()
        if x < f:GetWidth() * SHOW.back then go(math.max(1, index - 1))
        elseif index < #slides then go(index + 1) end
    end)
    function f.Showing() return index, #slides, frames[index] end
    return f, function(list)
        slides = list
        local width = (SHOW.width - 16 - 44 - SHOW.trackGap * (#list - 1)) / #list
        for k = 1, math.max(#list, #segs) do
            if not segs[k] then
                local seg = { track = f:CreateTexture(nil, "ARTWORK"), fill = f:CreateTexture(nil, "OVERLAY") }
                seg.track:SetColorTexture(unpack(UI.COLOR.divider))
                seg.fill:SetColorTexture(unpack(UI.COLOR.text))
                seg.fill:SetAlpha(0.85)
                seg.track:SetHeight(SHOW.track)
                seg.fill:SetHeight(SHOW.track)
                seg.fill:SetPoint("TOPLEFT", seg.track)
                segs[k] = seg
            end
            local seg = segs[k]
            seg.track:SetShown(k <= #list)
            seg.width = width
            seg.track:SetWidth(width)
            seg.track:SetPoint("TOPLEFT", f, "TOPLEFT", 16 + (k - 1) * (width + SHOW.trackGap), -14)
        end
        local tallest = 0
        for i, d in ipairs(list) do tallest = math.max(tallest, layoutSlide(slideFrame(i), d, 0)) end
        f:SetHeight(math.max(SHOW.height, math.ceil(tallest) + SHOW.padTop + SHOW.padBottom))
        for _, s in pairs(frames) do s:Hide() end
        index = 0
        f:Show()
        go(1)
    end
end
