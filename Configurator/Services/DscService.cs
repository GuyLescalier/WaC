
#nullable enable

using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading;

namespace Configurator.Services
{
    public class DscService
    {
        private Process? _currentProcess;

        [System.Runtime.Versioning.SupportedOSPlatform("windows")]
        public async Task<(string output, string error)> RunDscProcessAsync(string operation, string configContent, CancellationToken token)
        {
            var outputSb = new StringBuilder();
            var errorSb = new StringBuilder();

            // Construct the arguments string
            string dscPath = FindDscExecutable();
            if (string.IsNullOrEmpty(dscPath))
            {
                Debug.WriteLine("Error: dsc.exe not found in system PATH.");
                return ("", "Error: dsc.exe not found in system PATH. Please ensure PowerShell DSC is installed and configured correctly.");
            }

            string arguments = $"-Command \"& \"{dscPath}\" config {operation} -i @'\n{configContent}\n'@ -o json\"";

            Debug.WriteLine($"Executing powershell.exe with arguments: {arguments}");

            string powershellPath = "powershell.exe"; // powershell.exe is usually in PATH

            _currentProcess = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = powershellPath,
                    Arguments = arguments,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    StandardOutputEncoding = Encoding.UTF8,
                    StandardErrorEncoding = Encoding.UTF8
                },
                EnableRaisingEvents = true
            };

            _currentProcess.OutputDataReceived += (s, e) => { if (e.Data != null) outputSb.AppendLine(e.Data); };
            _currentProcess.ErrorDataReceived += (s, e) => { if (e.Data != null) errorSb.AppendLine(e.Data); };

            try
            {
                _currentProcess.Start();
                _currentProcess.BeginOutputReadLine();
                _currentProcess.BeginErrorReadLine();

                await _currentProcess.WaitForExitAsync(token);

                Debug.WriteLine($"DSC Process Standard Output:\n{outputSb.ToString()}");
                Debug.WriteLine($"DSC Process Standard Error:\n{errorSb.ToString()}");

                return (outputSb.ToString(), errorSb.ToString());
            }
            catch (TaskCanceledException)
            {
                Debug.WriteLine("DSC process wait was cancelled.");
                throw;
            }
            finally
            {
                _currentProcess?.Dispose();
                _currentProcess = null;
            }
        }

        public void CancelDscProcess()
        {
            if (_currentProcess != null && !_currentProcess.HasExited)
            {
                try
                {
                    _currentProcess.Kill(true); // Kill process tree
                    Debug.WriteLine("DSC process cancelled by user.");
                }
                catch (Exception ex)
                {
                    Debug.WriteLine($"Error cancelling DSC process: {ex.Message}");
                }
            }
        }

        private string FindDscExecutable()
        {
            string? pathEnv = Environment.GetEnvironmentVariable("PATH");
            if (string.IsNullOrEmpty(pathEnv))
            {
                return string.Empty;
            }

            string[] paths = pathEnv.Split(Path.PathSeparator);
            foreach (string path in paths)
            {
                string fullPath = Path.Combine(path, "dsc.exe");
                if (File.Exists(fullPath))
                {
                    return fullPath;
                }
            }
            return string.Empty;
        }
    }
}
