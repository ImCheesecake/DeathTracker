using System;
using System.Threading;

public class CPHInline
{
    static readonly object Gate = new object();

    public bool Execute()
    {
        int back = CPH.GetGlobalVar<int>("deathTrackerTwitchBack", false);
        Thread.Sleep(30000);
        lock (Gate)
        {
            if (CPH.GetGlobalVar<int>("deathTrackerTwitchBack", false) != back) return false;
            if (CPH.GetGlobalVar<bool>("deathTrackerTwitchWarned", false)) return false;
            CPH.SetGlobalVar("deathTrackerTwitchWarned", true, false);
        }
        return true;
    }
}
