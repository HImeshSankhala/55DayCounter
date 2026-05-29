using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Windows.Forms;

namespace DaysCounterInstaller
{
    internal static class Program
    {
        [STAThread]
        private static int Main()
        {
            Application.EnableVisualStyles();
            const string productName = "DaysCounter";
            string tempDir = Path.Combine(Path.GetTempPath(), "DaysCounterInstaller-" + Guid.NewGuid().ToString("N"));

            try
            {
                Directory.CreateDirectory(tempDir);

                using (Stream payload = Assembly.GetExecutingAssembly().GetManifestResourceStream("AppPayload"))
                {
                    if (payload == null)
                    {
                        MessageBox.Show("Installer payload is missing.", productName + " Installer", MessageBoxButtons.OK, MessageBoxIcon.Error);
                        return 1;
                    }

                    string zipPath = Path.Combine(tempDir, "payload.zip");
                    using (FileStream output = File.Create(zipPath))
                    {
                        payload.CopyTo(output);
                    }

                    ZipFile.ExtractToDirectory(zipPath, tempDir);
                }

                string installerScript = Path.Combine(tempDir, "Install-DaysCounter.ps1");
                if (!File.Exists(installerScript))
                {
                    MessageBox.Show("Install-DaysCounter.ps1 was not found in the installer payload.", productName + " Installer", MessageBoxButtons.OK, MessageBoxIcon.Error);
                    return 1;
                }

                ProcessStartInfo startInfo = new ProcessStartInfo();
                startInfo.FileName = "powershell.exe";
                startInfo.Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + installerScript + "\"";
                startInfo.WorkingDirectory = tempDir;
                startInfo.UseShellExecute = false;

                using (Process process = Process.Start(startInfo))
                {
                    process.WaitForExit();
                    if (process.ExitCode != 0)
                    {
                        MessageBox.Show("The installer did not finish successfully. Exit code: " + process.ExitCode, productName + " Installer", MessageBoxButtons.OK, MessageBoxIcon.Error);
                        return process.ExitCode;
                    }
                }

                MessageBox.Show(productName + " was installed successfully.", productName + " Installer", MessageBoxButtons.OK, MessageBoxIcon.Information);
                return 0;
            }
            catch (Exception ex)
            {
                MessageBox.Show(ex.Message, productName + " Installer", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return 1;
            }
            finally
            {
                try
                {
                    if (Directory.Exists(tempDir))
                    {
                        Directory.Delete(tempDir, true);
                    }
                }
                catch
                {
                    // Temporary cleanup failure should not make a successful install look failed.
                }
            }
        }
    }
}
