using System;
using System.Collections.Generic;

public class CPHInline
{
    static readonly Dictionary<string, string> NoDeathsYet = new Dictionary<string, string>
    {
        { "deathsThisStream", "0" }, { "deathsAllTime", "0" }, { "deathNemesis", "" }, { "deathNemesisKills", "0" },
        { "deathsAllTimeCharacter", "" },
    };

    public bool Execute()
    {
        CPH.EnableCommand("DEATHS_COMMAND_ID");
        CPH.EnableCommand("NEMESIS_COMMAND_ID");
        foreach (var count in NoDeathsYet)
            if (CPH.GetGlobalVar<string>(count.Key, true) == null) CPH.SetGlobalVar(count.Key, count.Value, true);
        CPH.SetGlobalVar("deathTrackerAnnounce", true, false);
        CPH.RunActionById("READ_LOG_ID", false);
        return true;
    }
}
