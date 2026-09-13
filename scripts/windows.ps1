[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][string]$Settings,
    [Parameter(Mandatory)][string]$Fonts
)

$ErrorActionPreference = 'Stop'
$fontsDirectory = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$fontsKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
$entries = @(
    @{ File = 'HackGenConsoleNF-Regular.ttf'; Name = 'HackGen Console NF (TrueType)' },
    @{ File = 'HackGenConsoleNF-Bold.ttf'; Name = 'HackGen Console NF Bold (TrueType)' },
    @{ File = 'HackGen35ConsoleNF-Regular.ttf'; Name = 'HackGen35 Console NF (TrueType)' },
    @{ File = 'HackGen35ConsoleNF-Bold.ttf'; Name = 'HackGen35 Console NF Bold (TrueType)' }
)

# Validate all sources before writing any Windows state.
if (-not (Test-Path -LiteralPath $Settings -PathType Leaf)) {
    throw "Terminal settings not found: $Settings"
}
foreach ($entry in $entries) {
    $matches = @(Get-ChildItem -LiteralPath $Fonts -Filter $entry.File -File -Recurse)
    if ($matches.Count -ne 1) { throw "Expected one font source: $($entry.File)" }
    $entry.Source = $matches[0].FullName
}

foreach ($entry in $entries) {
    $destination = Join-Path $fontsDirectory $entry.File
    if ($PSCmdlet.ShouldProcess($destination, 'Install and register font')) {
        New-Item -ItemType Directory -Force -Path $fontsDirectory | Out-Null
        Copy-Item -LiteralPath $entry.Source -Destination $destination -Force
        New-Item -Force -Path $fontsKey | Out-Null
        New-ItemProperty -Path $fontsKey -Name $entry.Name -PropertyType String -Value $destination -Force | Out-Null
    }
}

foreach ($package in @('Microsoft.WindowsTerminal_8wekyb3d8bbwe', 'Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe')) {
    $directory = Join-Path $env:LOCALAPPDATA "Packages\$package\LocalState"
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) { continue }
    $destination = Join-Path $directory 'settings.json'
    if ((Test-Path -LiteralPath $destination) -and
        ((Get-FileHash -LiteralPath $destination).Hash -eq (Get-FileHash -LiteralPath $Settings).Hash)) { continue }
    if ($PSCmdlet.ShouldProcess($destination, 'Back up and install Terminal settings')) {
        if ((Test-Path -LiteralPath $destination) -and -not (Test-Path -LiteralPath "$destination.pre-mise")) {
            Copy-Item -LiteralPath $destination -Destination "$destination.pre-mise"
        }
        Copy-Item -LiteralPath $Settings -Destination $destination -Force
    }
}
