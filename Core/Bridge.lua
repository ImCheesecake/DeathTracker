-- The lines Streamer.bot reads: one per death (and a status line at login and on a stream reset), each
-- after a line naming the character All time counts; written to Logs\General.log through C_Log.LogMessage.
local _, ns = ...

-- The game holds General.log until ~50 KB are waiting (docs/ingame-tests-2026-10-22.md). This
-- filler pushes the line out at once; one log line holds at most 4,089 characters.
local FILLER = strrep("x", 4000)
local FILLER_LINES = 16

local function field(v)
    if v == nil then return "" end
    return (tostring(v):gsub("[;\r\n]", ","))
end

local function join(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = field((select(i, ...))) end
    return table.concat(parts, ";")
end

-- The wait goes in only above 0: an import from before it reads only lines without it.
local function buildLine(kind, d, counts, title, wait)
    return join("DeathTracker", "1", kind, counts.total, d.name, d.level, d.cause, d.killer, d.npc, d.spell, d.zone,
        counts.stream, counts.nemesis, counts.nemesisKills, title, d.joke)
        .. (wait and wait > 0 and ";" .. wait or "") .. ";END"
end

function ns.DeathLine(d, counts, wait) return buildLine("death", d, counts, ns.DeathTitle(d), wait) end
function ns.StatusLine(who, counts) return buildLine("status", who, counts) end

-- An import from before Count per character skips this line: it isn't 17 or 18 fields.
function ns.AllTimeLine(counts) return join("DeathTracker", "1", "allTime", counts.character) .. ";END" end

local function send(counts, line)
    C_Log.LogMessage(ns.AllTimeLine(counts))
    C_Log.LogMessage(line)
    for _ = 1, FILLER_LINES do C_Log.LogMessage(FILLER) end
end

function ns.SendDeath(d)
    if not ns.db.settings.streamerbot then return end
    local counts = ns.Counts()
    send(counts, ns.DeathLine(d, counts, ns.db.settings.chatDelay))
end

function ns.SendStatus(who)
    if not ns.db.settings.streamerbot then return end
    local counts = ns.Counts()
    send(counts, ns.StatusLine(who, counts))
end
