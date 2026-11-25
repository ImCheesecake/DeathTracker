-- The addon's page in Blizzard's options window (Esc, Options, AddOns): what shows on screen,
-- the Streamer.bot line, and resetting or deleting the counts.
local addonName, ns = ...
local UI = ns.UI

local function deaths(n) return UI.Count(n, "death", "deaths") end

local function characters() return UI.Count(#ns.History.Characters({}), "character", "characters") end

local function check(key, label, tooltip, under, after)
    return { kind = "check", key = key, label = label, tooltip = tooltip, under = under, default = ns.DEFAULTS[key],
        get = function() return ns.db.settings[key] end,
        set = function(on)
            if ns.db.settings[key] == on then return end
            ns.db.settings[key] = on
            if after then after(on) end
        end }
end

local function header(label) return { kind = "header", label = label } end

local function cardOn() return ns.db.settings.card end
local function posterOn() return ns.db.settings.card and ns.db.settings.poster end
local CARD_OFF = "Turn on Show the death card to preview it."

-- Blizzard's options window sits over the card and the poster, so it closes first.
local function preview(kind)
    HideUIPanel(SettingsPanel)
    ns.Preview(kind)
end

-- The live counts go in the tooltips, which are built on mouse-over.
local function button(label, text, tooltip, click, isOn)
    return { kind = "button", label = label, text = text, tooltip = tooltip, click = click, isOn = isOn }
end

ns.OnEvent("PLAYER_LOGIN", function()
    local counter = check("counter", "Show the corner counter",
        "Deaths on this character, the last two deaths and time played this life. With Streamer.bot on, this stream's deaths.")
    local card = check("card", "Show the death card", "The card that shows what killed you, for 7 seconds.")
    local poster = check("poster", "Show the wanted poster",
        "When a mob becomes your nemesis, when it kills you again, and when you kill one.", card)
    local streamer = check("streamerbot", "Send each death to Streamer.bot",
        "Writes each death to the game's log for Streamer.bot to read. The counter and the card switch to this "
            .. "stream, starting at 0.", nil, ns.StreamerbotChanged)
    local importCode = button("Streamer.bot import", "Show import code", function()
        return "The code to paste into Streamer.bot's Import window. Sets up the chat line, !deaths and !nemesis."
    end, function()
        ns.db.importSeen = ns.STREAMERBOT_IMPORT_ID
        local function key(k) return UI.Colored(k, UI.COLOR.text) end
        UI.CopyBox("Streamer.bot import code", ns.STREAMERBOT_IMPORT,
            ("Press %s to copy it. Then in Streamer.bot: %s, paste it into Import String, click %s, then %s when it "
                .. "asks to run the setup."):format(key("Ctrl+C"), key("Import"), key("Import"), key("Yes")))
    end)
    -- The addon can't see what Streamer.bot holds, only which code was last opened here.
    function importCode.isNew() return ns.Streaming() and ns.db.importSeen ~= ns.STREAMERBOT_IMPORT_ID end
    function importCode.note() return importCode.isNew() and "This update changed the code. Import it again." or nil end
    local allTime = check("counterAllTime", "Show all-time deaths", "Your deaths of all time, beside this stream's count.",
        streamer, ns.Changed)
    local friendSound = check("friendSound", "Play a sound when a friend dies",
        "A short sound with the popup, so you notice it while you play.")
    function friendSound.isOn() return ns.db.settings.friendDeath ~= "off" end
    local defs = {
        header("On screen"),
        counter,
        check("counterPanel", "Show the counter's background", "Off: no background, and every text gets a dark outline.",
            counter),
        { kind = "dropdown", label = "Counter layout", tooltip = "The same choice as right-clicking the counter.",
            under = counter, default = ns.DEFAULTS.counterLayout, choices = ns.LAYOUTS,
            get = function() return ns.db.settings.counterLayout end, set = ns.SetLayout },
        card,
        check("cardBattlegrounds", "Show it in BGs and arenas",
            "The death card in battlegrounds and arenas. Off: no card there. Every death still counts.", card),
        { kind = "dropdown", label = "When a friend dies",
            tooltip = "Off: nothing.\nSmall: a small popup.\nCard: a smaller death card.\n\n"
                .. "The Friends page counts every death either way.",
            default = ns.DEFAULTS.friendDeath, choices = {
                { value = "off", text = "Off" }, { value = "small", text = "Small" }, { value = "card", text = "Card" } },
            get = function() return ns.db.settings.friendDeath end,
            set = function(value) ns.db.settings.friendDeath = value end },
        friendSound,
        check("friendsGuild", ns.FriendsAsk.GUILD_SETTING,
            "Guildmates who use Death Tracker show up under Guild on the Friends page. Their deaths never pop up, they "
                .. "only go in the Recent tab.", nil, function(on) ns.FriendsAsk.SetGuild(on) end),
        poster,
        check("posterSounds", "Play the poster's sounds",
            "A troll gong when a poster goes up. When you collect a bounty: \"Stay down.\", then Blizzard's boss "
                .. "defeated sound as the stamp lands.", poster),
        check("recapMusic", "Play music with the monthly recap",
            "Rocky Road to Dublin while the recap plays, at your game's music volume."),
        check("tooltips", "Show deaths in tooltips", "A mob or player's tooltip says how often they have killed you."),
        check("minimapButton", "Show the minimap button",
            "Shows or hides the Death Tracker button on the minimap.",
            nil, function(on) ns.ShowMinimapButton(on) end),
        { kind = "buttons", label = "Preview", buttons = {
            { text = "Show a death", isOn = cardOn, click = function() preview("new") end, tooltip = function()
                if not cardOn() then return CARD_OFF end
                return "Closes the settings and shows the death card and the wanted poster until you close them. "
                    .. "Drag them to move them, or their corner to resize. Nothing is counted."
            end },
            { text = "Show a bounty", isOn = posterOn, click = function() preview("bounty") end, tooltip = function()
                if not cardOn() then return CARD_OFF end
                if not posterOn() then return "Turn on Show the wanted poster to preview it." end
                return "Closes the settings and shows the wanted poster stamped \"Bounty collected\", as when you "
                    .. "kill your nemesis."
            end },
            { text = "Show a trophy", click = function()
                HideUIPanel(SettingsPanel)
                ns.PreviewTrophy("deaths 2", true)
            end, tooltip = function()
                return "Closes the settings and shows a trophy popup until you click it. Drag it where you "
                    .. "want trophies to pop up. Nothing is earned."
            end },
            { text = "Show a recap", click = function()
                HideUIPanel(SettingsPanel)
                ns.Recap.Toast(ns.Recap.Key(time()))
            end, tooltip = function()
                return "Closes the settings and shows the monthly recap popup for this month so far. Click it to play "
                    .. "the recap."
            end },
        } },

        header("Stream"),
        streamer,
        allTime,
        check("allTimePerCharacter", "Count per character", "All time counts only the character you're "
            .. "logged in on, so each alt has its own. Off: every character together. Every death is still saved and "
            .. "shows in the history window. !deaths names the character once you import the code from Show import code "
            .. "again.", allTime, ns.AllTimeChanged),
        { kind = "slider", label = "Wait before posting in chat",
            tooltip = "Viewers see your stream a few seconds late. A death waits this long before it's posted, so chat "
                .. "doesn't spoil it. 0 posts at once. Import the code from Show import code again to use it.",
            under = streamer, default = ns.DEFAULTS.chatDelay, min = 0, max = 30, step = 1,
            format = function(seconds) return SECOND_ONELETTER_ABBR:format(seconds) end,
            get = function() return ns.db.settings.chatDelay end,
            set = function(seconds) ns.db.settings.chatDelay = math.floor(seconds + 0.5) end },
        importCode,
        button("This stream", "Reset stream count", function()
            if not ns.Streaming() then return "Turn on Send each death to Streamer.bot to count by stream." end
            return ("%s this stream. Sets the count to 0; every death stays saved."):format(deaths(ns.StreamCount()))
        end, function() ns.AskResetStream() end, ns.Streaming),

        header("Saved deaths"),
        -- Deaths saved by older versions have no number.
        button("Last death", "Delete last death", function()
            local d = ns.Deaths({}, 1)[1]
            if not d then return "No saved deaths." end
            return ("%s%s, %s, on %s. Deletes just this death."):format(d.number and ("Death #%d: "):format(d.number) or "",
                ns.DeathTitle(d), UI.Ago(d.time), d.name)
        end, function()
            local d = ns.Deaths({}, 1)[1]
            if not d then return end
            UI.Ask(d.number and ("Delete death #%d?"):format(d.number) or "Delete this death?",
                ("%s, %s. This can't be undone."):format(ns.DeathTitle(d), UI.Ago(d.time)), function() ns.DeleteDeath(d) end)
        end),
        button("All characters", "Delete all deaths", function()
            return ("%s on %s. Deletes every saved death on every character."):format(deaths(ns.TotalCount()),
                characters())
        end, function()
            UI.Ask(("Delete all %s?"):format(deaths(ns.TotalCount())), "This can't be undone.", ns.DeleteAllDeaths)
        end),
    }
    local title = C_AddOns.GetAddOnMetadata(addonName, "Title")
    local page
    page = UI.OptionsPage(title, defs, function()
        UI.Ask("Put Death Tracker's settings back to their defaults?", "Every death stays saved.",
            function() page.OnDefault() end)
    end)
    ns.optionsPage = page
    local category = Settings.RegisterCanvasLayoutCategory(page, title)
    Settings.RegisterAddOnCategory(category)
    function ns.OpenOptions(key)
        Settings.OpenToCategory(category:GetID())
        if key then page.Glow(key) end
    end
end)
