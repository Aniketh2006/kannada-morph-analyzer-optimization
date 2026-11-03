# Records the exact test environment next to the results.
# Run in PowerShell from the repository root, BEFORE and AFTER a benchmark session:
#   powershell -ExecutionPolicy Bypass -File scripts\env_snapshot_windows.ps1 before
#   powershell -ExecutionPolicy Bypass -File scripts\env_snapshot_windows.ps1 after
param([string]$Tag = "snapshot")
$out = "environment_windows_$Tag.txt"
$os  = Get-CimInstance Win32_OperatingSystem
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$cs  = Get-CimInstance Win32_ComputerSystem
$bat = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
$def = try { (Get-MpPreference).DisableRealtimeMonitoring } catch { "unknown" }
$perl = (& perl -e 'print "$^V  ($^X)"')
$arch = (& perl -MConfig -e 'print $Config{archname}, "  threads=", ($Config{useithreads}||"no")')
$mce  = (& perl -MMCE -e 'print $MCE::VERSION' 2>$null)
if (-not $mce) { $mce = "NOT INSTALLED" }
$sha = { param($f) $b = [IO.File]::ReadAllBytes((Resolve-Path $f)) | Where-Object { $_ -ne 13 }
         -join ([Security.Cryptography.SHA256]::Create().ComputeHash([byte[]]$b) | ForEach-Object { $_.ToString("x2") }) }
$lines = @(
 "timestamp        : $(Get-Date -Format o)",
 "device           : $($cs.Manufacturer) $($cs.Model)",
 "os               : $($os.Caption) $($os.Version) build $($os.BuildNumber)",
 "cpu model        : $($cpu.Name.Trim())",
 "cores / threads  : $($cpu.NumberOfCores) / $($cpu.NumberOfLogicalProcessors)   max MHz: $($cpu.MaxClockSpeed)",
 "memory           : $([math]::Round($cs.TotalPhysicalMemory/1GB,2)) GB",
 "power plan       : $((powercfg /getactivescheme) -replace '^.*: ','')",
 "power source     : $(if ($bat) { if ($bat.BatteryStatus -eq 2) {'AC connected'} else {'ON BATTERY'} } else {'no battery / unknown'})",
 "defender realtime: DisableRealtimeMonitoring = $def",
 "perl             : $perl",
 "perl archname    : $arch",
 "MCE version      : $mce",
 "dict_all.txt     : $((& $sha 'dict_all.txt').Substring(0,16)) (CR stripped)",
 "words file       : $((& $sha 'random_words_100.txt').Substring(0,16)) (CR stripped)"
)
$lines | Out-File -FilePath $out -Encoding utf8
$lines
Write-Host "saved: $out"
