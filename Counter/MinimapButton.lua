-- The minimap button (LibDBIcon, which players can drag around the minimap's edge) and the entry in
-- Blizzard's addon button: the same clicks and the same tooltip.
local addonName, ns = ...
local UI = ns.UI

local DBIcon = LibStub("LibDBIcon-1.0")
local CLICKS = { "Left-click: Open / close", "Right-click: Settings" }

local function click(button)
    if button == "RightButton" then return ns.OpenOptions() end
    ns.ToggleHistory()
end

local function clickTip(owner, draggable)
    local lines = { unpack(CLICKS) }
    if draggable then lines[#lines + 1] = "Drag: Move" end
    UI.Tooltip(owner, "Death Tracker", nil, lines, nil, "ANCHOR_LEFT")
end

function ns.ShowMinimapButton(on)
    ns.db.minimap.hide = not on
    if on then DBIcon:Show(addonName) else DBIcon:Hide(addonName) end
end

ns.OnEvent("PLAYER_LOGIN", function()
    local launcher = LibStub("LibDataBroker-1.1"):NewDataObject(addonName, {
        type = "launcher", label = "Death Tracker", icon = UI.ICON,
        OnClick = function(_, button) click(button) end,
        OnEnter = function(owner) clickTip(owner, true) end,
        OnLeave = UI.HideTooltip,
    })
    ns.db.minimap.hide = not ns.db.settings.minimapButton
    DBIcon:Register(addonName, launcher, ns.db.minimap)
end)

-- Blizzard's addon button calls these by the names in the .toc.
function DeathTracker_OnAddonCompartmentClick(_, button) click(button) end
function DeathTracker_OnAddonCompartmentEnter(_, button) clickTip(button, false) end
function DeathTracker_OnAddonCompartmentLeave() UI.HideTooltip() end
