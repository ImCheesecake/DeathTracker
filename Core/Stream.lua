-- At a fresh game start, asks whether to start counting a new stream when this one has deaths and
-- deaths go to Streamer.bot.
local _, ns = ...
local UI = ns.UI

-- The game says "initial login" after a logout too; a setting we register lasts until the game
-- quits, so while it's unset the game has just started.
local RUNNING = "deathTrackerRunning"
local function gameJustStarted()
    C_CVar.RegisterCVar(RUNNING, "0")
    local started = C_CVar.GetCVar(RUNNING) ~= "1"
    C_CVar.SetCVar(RUNNING, "1")
    return started
end

local function askNewStream()
    local n = ns.StreamCount()
    if n == 0 or not ns.db.settings.streamerbot then return end
    local last = ns.Deaths({ stream = true }, 1)[1]
    local detail = ("This stream has %s so far, %s%s."):format(UI.Count(n, "death", "deaths"),
        UI.Plural(n, "", "the last one "), UI.At(last.time))
    UI.Ask("Start counting a new stream?", detail, ns.ResetStream)
end

function ns.AskResetStream() UI.Ask("Reset this stream's count to 0?", "Every death stays saved.", ns.ResetStream) end

-- Only the first time after the UI loads (a login or a /reload), not on every loading screen.
ns.OnEvent("PLAYER_ENTERING_WORLD", function(isInitialLogin, isReloadingUi)
    if (isInitialLogin or isReloadingUi) and gameJustStarted() then askNewStream() end
end)
