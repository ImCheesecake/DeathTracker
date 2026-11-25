using System;
using System.Drawing;
using System.IO;
using System.Threading;
using System.Windows.Forms;

public class CPHInline
{
    public bool Execute()
    {
        string current = CPH.GetGlobalVar<string>("deathTrackerLogFile", true);
        if (string.IsNullOrEmpty(current))
            current = (CPH.GetGlobalVar<string>("deathTrackerRead", false) ?? "").Split('|')[0];
        string folder = current == "" ? null : Path.GetDirectoryName(current);

        string chosen = null;
        var thread = new Thread(() =>
        {
            Rectangle screen = Screen.PrimaryScreen.WorkingArea;
            using (var owner = new Form
            {
                TopMost = true, ShowInTaskbar = false, FormBorderStyle = FormBorderStyle.None, Opacity = 0,
                StartPosition = FormStartPosition.Manual, Size = new Size(1, 1),
                Location = new Point(screen.Left + screen.Width / 2, screen.Top + screen.Height / 2),
            })
            using (var dialog = new OpenFileDialog
            {
                Title = "Death Tracker: choose WoW's General.log",
                Filter = "General.log|General.log|Log files (*.log)|*.log",
                FileName = "General.log",
            })
            {
                if (folder != null && Directory.Exists(folder)) dialog.InitialDirectory = folder;
                owner.Show();
                owner.Activate();
                if (dialog.ShowDialog(owner) == DialogResult.OK) chosen = dialog.FileName;
            }
        });
        thread.SetApartmentState(ApartmentState.STA);
        thread.Start();
        thread.Join();

        if (chosen == null)
        {
            CPH.ShowToastNotification("Death Tracker", current == ""
                ? "No General.log chosen. To choose it: Death Tracker: set General.log, right-click its trigger, Test Trigger."
                : "Still reads " + current);
            return false;
        }
        CPH.SetGlobalVar("deathTrackerLogFile", chosen, true);
        CPH.ShowToastNotification("Death Tracker", "Reads " + chosen);
        return true;
    }
}
