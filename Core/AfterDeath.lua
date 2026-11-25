-- What a death cost, saved with it once the player is alive again: the time as a ghost, the yards run back,
-- the repair bill (the durability lost to the death and the resurrection) and how you came back.
local _, ns = ...

local SAMPLE_SECONDS = 1
-- The server's resurrection counters: priests, Rebirth, Revive, shamans, paladins, soulstones.
local REZ_STATS = { 796, 798, 1229, 799, 800, 801 }
local TELEPORT = 60     -- yards in one step: a teleport, not running
local MOVED = 1         -- yards in one step: running, not standing still
local cost
local stale = true

local function rezCounts()
    local out = {}
    for _, id in ipairs(REZ_STATS) do out[id] = ns.Statistic(id) end
    return out
end

local function repairCost()
    local total = 0
    for slot = 1, 19 do
        local data = C_TooltipInfo.GetInventoryItem("player", slot)
        local c = data and data.repairCost
        if type(c) == "number" and not issecretvalue(c) then total = total + c end
    end
    return total
end

-- The death being followed, saved per character so a /reload or a logout as a ghost keeps it.
local function current()
    local key = ns.CharacterKey()
    return key and ns.db.runs[key], key
end

local function risen(before)
    if not before then return nil end
    local now, up = rezCounts(), {}
    for _, id in ipairs(REZ_STATS) do
        if now[id] > (before[id] or 0) then up[#up + 1] = id end
    end
    return #up > 0 and up or nil
end

local finishing = {}   -- runs waiting to be written; not saved, so a /reload finishes them again
local DUNGEON = { party = true, raid = true }

-- A ghost walking into a dungeon's portal comes back alive with no call to hook.
local function walkedIn(run)
    local _, kind = IsInInstance()
    if run.released and not run.back and DUNGEON[kind] then run.back = { how = "portal" } end
end

local function finish()
    local run, key = current()
    if not run or finishing[run] then return end
    finishing[run] = true
    walkedIn(run)
    -- The resurrection's durability loss arrives just after it. The run stays saved until then.
    C_Timer.After(2, function()
        finishing[run] = nil
        walkedIn(run)
        if ns.db.runs[key] == run then ns.db.runs[key] = nil end
        for i = #ns.db.deaths, 1, -1 do
            local d = ns.db.deaths[i]
            if d.char == key and d.time == run.time then
                d.ghost, d.ran, d.runSecs = run.ghost, math.floor(run.yards + 0.5), run.running
                if run.cost then d.repair = math.max(0, repairCost() - run.cost) end
                local stats = risen(run.rez)
                if run.back or stats then
                    d.back = run.back or {}
                    d.back.stats = stats
                end
                return
            end
        end
    end)
end

local function tick()
    if stale and not UnitIsDeadOrGhost("player") then cost, stale = repairCost(), false end
    local run = current()
    if not (run and UnitIsGhost("player")) then return end
    -- By the clock, so a late tick still counts; a longer gap is time logged out.
    local now = time()
    local gap = run.at and now - run.at
    if gap and gap <= 5 then run.ghost = run.ghost + gap end
    run.at = now
    -- No position in dungeons and battlegrounds.
    local x, y, _, map = UnitPosition("player")
    if type(x) ~= "number" or issecretvalue(x) or issecretvalue(y) or issecretvalue(map) then
        run.x = nil
        return
    end
    if run.x and run.map == map then
        local step = math.sqrt((x - run.x) ^ 2 + (y - run.y) ^ 2)
        if step < TELEPORT then
            run.yards = run.yards + step
            -- The seconds spent running, so the run back reads as time at any speed the player has.
            if step >= MOVED and gap and gap <= 5 then run.running = (run.running or 0) + gap end
        end
    end
    run.x, run.y, run.map = x, y, map
end

ns.OnEvent("UPDATE_INVENTORY_DURABILITY", function() stale = true end)
ns.OnEvent("PLAYER_EQUIPMENT_CHANGED", function() stale = true end)
ns.OnDying(function(at)
    local key = ns.CharacterKey()
    if key then ns.db.runs[key] = { time = at, ghost = 0, yards = 0, cost = cost, rez = rezCounts() } end
end)

local function cameBack(back)
    local run = current()
    if run then run.back = back end
end

ns.OnEvent("RESURRECT_REQUEST", function(name)
    local run = current()
    if run then run.offer = ns.Readable(name) end
end)
hooksecurefunc("AcceptResurrect", function()
    local run = current()
    if run then cameBack({ how = "player", by = ns.Readable(ResurrectGetOfferer()) or run.offer }) end
end)
hooksecurefunc(C_DeathInfo, "UseSelfResurrectOption", function(kind, id)
    local back = { how = "self", kind = ns.Readable(kind), id = ns.Readable(id) }
    for _, o in ipairs(C_DeathInfo.GetSelfResurrectOptions() or {}) do
        if back.id and ns.Readable(o.id) == back.id and ns.Readable(o.optionType) == back.kind then back.by = ns.Readable(o.name) end
    end
    cameBack(back)
end)
hooksecurefunc(C_PlayerInteractionManager, "ConfirmationInteraction", function(kind)
    if ns.Readable(kind) == Enum.PlayerInteractionType.SpiritHealer then cameBack({ how = "healer" }) end
end)
hooksecurefunc("AcceptAreaSpiritHeal", function() cameBack({ how = "healer" }) end)
hooksecurefunc("RetrieveCorpse", function() cameBack({ how = "corpse" }) end)
-- PLAYER_ALIVE also fires on releasing as a ghost; alive and not a ghost: rezzed at the body.
ns.OnEvent("PLAYER_ALIVE", function()
    if not UnitIsGhost("player") then return finish() end
    local run = current()
    if run then run.at, run.released = time(), true end
end)
ns.OnEvent("PLAYER_UNGHOST", finish)
ns.OnEvent("PLAYER_ENTERING_WORLD", function()
    stale = true
    if not UnitIsDeadOrGhost("player") then finish() end
end)
C_Timer.NewTicker(SAMPLE_SECONDS, tick)
