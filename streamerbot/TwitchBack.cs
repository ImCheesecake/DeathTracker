using System;

public class CPHInline
{
    public bool Execute()
    {
        CPH.SetGlobalVar("deathTrackerTwitchBack", CPH.GetGlobalVar<int>("deathTrackerTwitchBack", false) + 1, false);
        bool warned = CPH.GetGlobalVar<bool>("deathTrackerTwitchWarned", false);
        CPH.UnsetGlobalVar("deathTrackerTwitchWarned", false);
        return warned;
    }
}
