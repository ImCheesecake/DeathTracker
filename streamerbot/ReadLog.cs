using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Win32;

public class CPHInline
{
    static readonly Dictionary<string, int> Counts = new Dictionary<string, int>
    {
        { "deathsAllTime", 3 }, { "deathsThisStream", 11 }, { "deathNemesis", 12 }, { "deathNemesisKills", 13 },
    };

    static readonly Dictionary<string, int> Death = new Dictionary<string, int>
    {
        { "Character", 4 }, { "Level", 5 }, { "Cause", 6 }, { "Killer", 7 },
        { "Spell", 9 }, { "Zone", 10 }, { "Title", 14 }, { "Joke", 15 },
    };

    const int DelayField = 16;
    const int AllTimeCharacterField = 3;

    CancellationTokenSource stop;

    public void Init()
    {
        stop = new CancellationTokenSource();
        CancellationToken token = stop.Token;
        Task.Run(async () =>
        {
            while (!token.IsCancellationRequested)
            {
                try
                {
                    await Task.Delay(1000, token);
                    CPH.RunActionById("READ_LOG_ID", false);
                }
                catch (Exception) { }
            }
        });
    }

    public void Dispose()
    {
        if (stop != null) stop.Cancel();
    }

    public bool Execute()
    {
        string path = LogFile();
        bool announce = CPH.GetGlobalVar<bool>("deathTrackerAnnounce", false);
        if (announce)
        {
            CPH.UnsetGlobalVar("deathTrackerAnnounce", false);
            Announce(path);
        }
        if (path == null || !File.Exists(path)) return false;
        long length = new FileInfo(path).Length;

        string[] saved = (CPH.GetGlobalVar<string>("deathTrackerRead", false) ?? "").Split('|');
        bool known = saved.Length == 2 && saved[0] == path;
        long offset = known ? long.Parse(saved[1]) : length;
        if (length < offset) offset = 0;

        int used;
        if (announce || !known)
            foreach (string line in WholeLines(path, 0, offset, out used))
                if (line.Contains("DeathTracker;1;allTime;")) Handle(line);

        if (length > offset)
        {
            foreach (string line in WholeLines(path, offset, length, out used)) Handle(line);
            offset += used;
        }
        CPH.SetGlobalVar("deathTrackerRead", path + "|" + offset, false);
        return true;
    }

    string[] WholeLines(string path, long from, long to, out int used)
    {
        used = 0;
        byte[] bytes = new byte[to - from];
        int read = 0;
        using (var file = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
        {
            file.Seek(from, SeekOrigin.Begin);
            int n;
            while (read < bytes.Length && (n = file.Read(bytes, read, bytes.Length - read)) > 0) read += n;
        }
        int end = Array.LastIndexOf(bytes, (byte)'\n', Math.Max(read - 1, 0));
        if (read == 0 || end < 0) return new string[0];
        used = end + 1;
        return Encoding.UTF8.GetString(bytes, 0, end).Split('\n');
    }

    void Announce(string path)
    {
        if (path != null && File.Exists(path))
            CPH.ShowToastNotification("Death Tracker", "Reads " + path);
        else if (path != null && Directory.Exists(Path.GetDirectoryName(Path.GetDirectoryName(path))))
            CPH.ShowToastNotification("Death Tracker", "Will read " + path + " once WoW has run.");
        else
            CPH.RunActionById("SET_LOG_ID", false);
    }

    string LogFile()
    {
        string chosen = CPH.GetGlobalVar<string>("deathTrackerLogFile", true);
        if (!string.IsNullOrEmpty(chosen)) return chosen;
        string install = Registry.GetValue(@"HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft",
            "InstallPath", null) as string;
        if (string.IsNullOrEmpty(install)) return null;
        var folder = new DirectoryInfo(install.TrimEnd('\\', '/'));
        if (folder.Name.StartsWith("_") && folder.Parent != null) folder = folder.Parent;
        return Path.Combine(folder.FullName, "_forever_", "Logs", "General.log");
    }

    void Handle(string line)
    {
        int at = line.IndexOf("[Lua] DeathTracker;1;", StringComparison.Ordinal);
        if (at < 0) return;
        string[] f = line.Substring(at + 6).TrimEnd('\r').Split(';');
        if (f.Length == 5 && f[2] == "allTime" && f[4] == "END")
        {
            CPH.SetGlobalVar("deathsAllTimeCharacter", f[AllTimeCharacterField], true);
            return;
        }
        if ((f.Length != 17 && f.Length != 18) || f[f.Length - 1] != "END" || (f[2] != "death" && f[2] != "status")) return;

        foreach (var c in Counts)
        {
            CPH.SetGlobalVar(c.Key, f[c.Value], true);
            CPH.SetArgument(c.Key, f[c.Value]);
        }
        if (f[2] != "death") return;

        foreach (var d in Death)
        {
            CPH.SetArgument("death" + d.Key, f[d.Value]);
            CPH.SetGlobalVar("lastDeath" + d.Key, f[d.Value], true);
        }
        int delay;
        if (f.Length != 18 || !int.TryParse(f[DelayField], out delay)) delay = 0;
        CPH.SetArgument("deathDelay", delay);
        CPH.RunActionById("ON_DEATH_ID", false);
    }
}
