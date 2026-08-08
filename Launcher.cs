using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;

class Program
{
    static void Main(string[] args)
    {
        try
        {
            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            
            // Check for Godot executable in current dir or fallback location
            string godotExe = Path.Combine(baseDir, "GodotEngine.exe");
            if (!File.Exists(godotExe))
            {
                godotExe = Path.Combine(baseDir, "Godot.exe");
            }
            if (!File.Exists(godotExe))
            {
                godotExe = @"C:\tools\Godot\Godot_v4.7.1-stable_mono_win64.exe";
            }

            // Check for PCK file in current dir
            string pckFile = Path.Combine(baseDir, "MazeLabyrinth.pck");
            if (!File.Exists(pckFile))
            {
                pckFile = Path.Combine(baseDir, "export", "MazeLabyrinth.pck");
            }

            if (!File.Exists(godotExe) || !File.Exists(pckFile))
            {
                // Fallback: extract embedded resources if bundled
                string tempDir = Path.Combine(Path.GetTempPath(), "MazeLabyrinthGame");
                Directory.CreateDirectory(tempDir);
                
                if (!File.Exists(godotExe))
                {
                    godotExe = Path.Combine(tempDir, "GodotEngine.exe");
                    ExtractResource("GodotEngine.exe", godotExe);
                }
                
                if (!File.Exists(pckFile))
                {
                    pckFile = Path.Combine(tempDir, "MazeLabyrinth.pck");
                    ExtractResource("MazeLabyrinth.pck", pckFile);
                }
            }

            ProcessStartInfo startInfo = new ProcessStartInfo();
            startInfo.FileName = godotExe;
            startInfo.Arguments = "--main-pack \"" + pckFile + "\"";
            startInfo.UseShellExecute = false;

            Process proc = Process.Start(startInfo);
        }
        catch (Exception ex)
        {
            // Ignore error
        }
    }

    static void ExtractResource(string resourceName, string outputPath)
    {
        try
        {
            Assembly assembly = Assembly.GetExecutingAssembly();
            using (Stream stream = assembly.GetManifestResourceStream(resourceName))
            {
                if (stream != null)
                {
                    using (FileStream fs = new FileStream(outputPath, FileMode.Create))
                    {
                        stream.CopyTo(fs);
                    }
                }
            }
        }
        catch
        {
        }
    }
}
