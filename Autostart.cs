using System.Diagnostics;

namespace MSIProfileSwitcher;

/// <summary>
/// Autostart przez zadanie Harmonogramu (ONLOGON + RL HIGHEST) — uruchamia
/// elevowany .exe przy logowaniu BEZ promptu UAC. Tworzone/usuwane z Ustawien.
/// </summary>
public static class Autostart
{
    private const string TaskName = "MSIProfileSwitcher";

    private static string ExePath => Environment.ProcessPath ?? Application.ExecutablePath;

    private static int Run(string args)
    {
        var psi = new ProcessStartInfo("schtasks.exe", args)
        {
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
        };
        using var p = Process.Start(psi)!;
        p.WaitForExit();
        return p.ExitCode;
    }

    public static bool IsEnabled()
    {
        try { return Run($"/Query /TN \"{TaskName}\"") == 0; }
        catch { return false; }
    }

    public static void Set(bool enabled)
    {
        if (enabled)
            Run($"/Create /TN \"{TaskName}\" /TR \"\\\"{ExePath}\\\"\" /SC ONLOGON /RL HIGHEST /F");
        else
            Run($"/Delete /TN \"{TaskName}\" /F");
    }
}
