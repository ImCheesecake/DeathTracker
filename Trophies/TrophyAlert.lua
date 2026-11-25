-- When a trophy is earned: Blizzard's achievement popup with our words (board "Trophies page"):
-- "Trophy earned", its name, its points on Blizzard's shield, the addon's icon.
local _, ns = ...
local UI, T = ns.UI, ns.Trophies

local system

local function spot() return ns.db.settings.trophyPosition end

local function dropped(frame)
    frame:StopMovingOrSizing()
    local point, _, toPoint, x, y = frame:GetPoint()
    local s = spot()
    s.point, s.toPoint, s.x, s.y = point, toPoint, x, y
    AlertFrame:UpdateAnchors()
end

local function setUp(frame, def, tier, held)
    frame.Unlocked:SetText("Trophy earned")
    frame.Name:SetText(T.Name(def, tier))
    AchievementShield_SetPoints(T.Points(def, tier), frame.Shield.Points, GameFontNormal, GameFontNormalSmall)
    frame.Shield.Points:Show()
    frame.Shield.Icon:SetAtlas("ui-achievement-shield-2", TextureKitConstants.UseAtlasSize)
    frame.Icon.Texture:SetTexture(UI.ICON)
    frame.GuildName:Hide()
    frame.GuildBorder:Hide()
    frame.GuildBanner:Hide()
    -- Blizzard's click opens the achievement with this id; without one it does nothing, so ours runs.
    frame.id = nil
    frame.held = held
    -- Blizzard fades a popup after its duration, and a second after the mouse leaves it.
    AlertFrame_SetDuration(frame, held and 86400 or nil)
    if not frame.opensTrophies then
        frame.opensTrophies = true
        frame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        frame:HookScript("OnClick", function(self, button)
            if self.held then return self:Hide() end
            if button ~= "RightButton" then ns.HistoryShell.Show("trophies") end
        end)
        frame:HookScript("OnLeave", function(self) if self.held then AlertFrame_PauseOutAnimation(self) end end)
        frame:SetMovable(true)
        frame:SetClampedToScreen(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function(self) if self.held then self:StartMoving() end end)
        frame:SetScript("OnDragStop", function(self) if self.held then dropped(self) end end)
    end
    return true
end

-- Blizzard's queue stacks every popup above the one before; once dropped somewhere, ours stack from
-- there instead and the rest of Blizzard's popups carry on where they were.
local function anchorPopups(self, relative)
    local s = spot()
    if not s.point then return self.blizzardAnchors(self, relative) end
    local below
    for frame in self.alertFramePool:EnumerateActive() do
        frame:ClearAllPoints()
        if below then
            frame:SetPoint("BOTTOM", below, "TOP", 0, 10)
        else
            frame:SetPoint(s.point, UIParent, s.toPoint, s.x, s.y)
        end
        below = frame
    end
    return relative
end

local function popUp(def, tier, held)
    if not system then
        -- The popup's shield calls AchievementShield_OnLoad, which lives in Blizzard_AchievementUI.
        if not C_AddOns.LoadAddOn("Blizzard_AchievementUI") then
            return UI.Say(("trophy earned: %s."):format(T.Name(def, tier)))
        end
        system = AlertFrame:AddQueuedAlertFrameSubSystem("AchievementAlertFrameTemplate", setUp, 2, 6)
        system.blizzardAnchors, system.AdjustAnchors = system.AdjustAnchors, anchorPopups
    end
    system:AddAlert(def, tier, held)
end
T.OnEarned(popUp)

-- /deathtracker trophy [id] [step]: the popup for any trophy, earned or not. held: it stays until
-- clicked and can be dragged to where trophies pop up (the settings' Show a trophy).
function ns.PreviewTrophy(rest, held)
    local id, step = (rest or ""):match("^(%S*)%s*(%d*)")
    local def = T.Get(id ~= "" and id or "deaths")
    if not def then return UI.Say(("no trophy called %s."):format(id)) end
    popUp(def, math.min(tonumber(step) or 1, #def.at), held)
end
