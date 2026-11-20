# Capture a screenshot of the running game window.
# Usage: powershell -File tools/capture.ps1 -exe build\x86_64-win32\dmengine.exe -proj build\bobtest\game.projectc -out shot.png -extra "--config=bus.start_level=18 --config=display.width=1100 --config=display.height=620"
param($exe, $proj, $out, $extra)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class W { [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
public struct RECT { public int L, T, R, B; } }
"@
$p = Start-Process -FilePath $exe -ArgumentList ($extra + " " + $proj) -PassThru -RedirectStandardOutput "$out.log" -RedirectStandardError "$out.err"
Start-Sleep -Seconds 5
$p.Refresh(); $h = $p.MainWindowHandle
[W]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 500
$r = New-Object W+RECT
[W]::GetWindowRect($h, [ref]$r) | Out-Null
$bmp = New-Object System.Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size)
$bmp.Save($out)
Stop-Process -Id $p.Id
