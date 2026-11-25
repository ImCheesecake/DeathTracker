using System;

public class CPHInline
{
    public bool Execute()
    {
        int seconds;
        if (CPH.TryGetArg("deathDelay", out seconds) && seconds > 0) CPH.Wait(seconds * 1000);
        return true;
    }
}
