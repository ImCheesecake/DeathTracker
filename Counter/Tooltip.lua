local _, ns = ...
local UI = ns.UI

local function hovered(tooltip, guid)
    local kind, npc = ns.ParseGUID(guid)
    if (kind == "Creature" or kind == "Vehicle") and npc then return { npc = npc } end
    if kind ~= "Player" then return nil end
    local _, unit = tooltip:GetUnit()
    if not unit then return nil end
    local first, surname = UnitName(unit)
    if issecretvalue(first) or issecretvalue(surname) then return nil end
    return { player = NameUtil.GetFullNameWithoutRealm(first, surname) }
end

local function addLines(tooltip, data)
    local guid, key = data and data.guid, ns.CharacterKey()
    if not ns.db.settings.tooltips or not key or not guid or issecretvalue(guid) then return end
    local killer = hovered(tooltip, guid)
    if not killer then return end
    local all = #ns.Deaths(killer)
    if all == 0 then return end
    killer.char = key
    local mine = ns.Deaths(killer)
    if #mine > 0 then
        if killer.npc and ns.Nemesis({ char = key }) == killer.npc then
            UI.TipLine(tooltip, ("Your nemesis: killed you %s"):format(UI.Times(#mine)), UI.COLOR.trophy)
            UI.TipLine(tooltip, ns.BountyLine(key, killer.npc), UI.COLOR.trophy)
        else
            UI.TipLine(tooltip, ("Killed you %s, last %s"):format(UI.Times(#mine), UI.Date(mine[1].time)),
                UI.CauseColor(killer.npc and "mob" or "player"))
        end
    end
    if all > #mine then
        UI.TipLine(tooltip, ("Killed your other characters %s"):format(UI.Times(all - #mine)), UI.COLOR.muted)
    end
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, addLines)
