# Capture a screenshot of the running game window (works even if another window covers it).
# Usage: powershell -File tools/capture.ps1 -exe build\x86_64-win32\dmengine.exe -proj build\bobtest\game.projectc -out shot.png -extra "--config=bus.start_level=18 --config=display.width=1100 --config=display.height=620" [-wait 5]
param($exe, $proj, $out, $extra = "", $wait = 5)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class W {
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  public struct RECT { public int L, T, R, B; }
}
"@
$p = Start-Process -FilePath $exe -ArgumentList ($extra + " " + $proj) -PassThru -RedirectStandardOutput "$out.log" -RedirectStandardError "$out.err"
Start-Sleep -Seconds $wait
$p.Refresh(); $h = $p.MainWindowHandle
$r = New-Object W+RECT
[W]::GetClientRect($h, [ref]$r) | Out-Null
$bmp = New-Object System.Drawing.Bitmap ([Math]::Max(1, $r.R - $r.L)), ([Math]::Max(1, $r.B - $r.T))
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
[W]::PrintWindow($h, $hdc, 3) | Out-Null   # 1 = client only, 2 = full content (GL/DX)
$g.ReleaseHdc($hdc)
$bmp.Save($out)
Stop-Process -Id $p.Id
