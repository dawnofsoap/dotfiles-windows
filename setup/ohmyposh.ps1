<#
.SYNOPSIS
    Portable OhMyPosh setup script - installs OhMyPosh, Hack Nerd Font, and configures your selected theme.

.DESCRIPTION
    Run this script on any Windows machine to get your preferred terminal setup:
    - Installs OhMyPosh via winget
    - Installs Hack Nerd Font
    - Lets you select from predefined themes (with image preview option)
    - Configures PowerShell profile with selected theme
    - Configures Windows Terminal and VS Code font settings

.PARAMETER Theme
    Directly specify a theme name to skip selection menu.

.PARAMETER ShowPreviews
    Opens theme preview images in your default browser to help you choose.

.NOTES
    Run as Administrator for font installation.
    Store this script in OneDrive, GitHub, or a USB drive for portability.
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$Theme,
    [switch]$ShowPreviews,
    [switch]$SkipFontInstall,
    [switch]$SkipProfileUpdate,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Configuration - modify these to change your preferences
$Config = @{
    FontName      = 'Hack'
    FontFamily    = 'Hack Nerd Font'
    NerdFontsBase = 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download'
    ThemesPageUrl = 'https://ohmyposh.dev/docs/themes'
    
    # Add your favorite themes here
    Themes        = @(
        @{ Name = 'kushal'; Description = 'Clean minimal theme with git status' }
        @{ Name = 'night-owl'; Description = 'Night Owl color scheme inspired theme' }
        @{ Name = 'pixelrobots'; Description = 'Pixel robots themed prompt' }
        @{ Name = 'cloud-native-azure'; Description = 'Azure cloud-focused with Kubernetes context' }
        @{ Name = 'cloud-context'; Description = 'Cloud context aware (AWS/Azure/GCP)' }
        @{ Name = 'froczh'; Description = 'Colorful powerline style theme' }
    )
}

function Write-Status {
    param([string]$Message, [string]$Type = 'Info')
    $colors = @{
        'Info'    = 'Cyan'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error'   = 'Red'
    }
    Write-Host "[$Type] " -ForegroundColor $colors[$Type] -NoNewline
    Write-Host $Message
}

function Test-AdminPrivilege {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Show-ThemePreviewImages {
    param([array]$Themes)
    
    Write-Status "Opening theme previews in your browser..."
    Write-Host ""
    
    foreach ($theme in $Themes) {
        $themeUrl = "$($Config.ThemesPageUrl)#$($theme.Name)"
        Start-Process $themeUrl
        Start-Sleep -Milliseconds 800
    }
    
    Write-Host "Preview pages opened in your browser." -ForegroundColor Green
    Write-Host "Each tab will jump to the theme's preview image." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Press any key to continue..." -ForegroundColor Cyan
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    Write-Host ""
}

function Show-ThemePreviewSingleImage {
    param([string]$ThemeName)
    
    $themeUrl = "$($Config.ThemesPageUrl)#$ThemeName"
    Write-Status "Opening preview for '$ThemeName'..."
    Start-Process $themeUrl
}

function Get-ThemeSelection {
    Write-Host ""
    Write-Host ('=' * 60) -ForegroundColor Cyan
    Write-Host "  Available Themes" -ForegroundColor Cyan
    Write-Host ('=' * 60) -ForegroundColor Cyan
    Write-Host ""
    
    for ($i = 0; $i -lt $Config.Themes.Count; $i++) {
        $theme = $Config.Themes[$i]
        Write-Host "  [$($i + 1)] " -ForegroundColor Yellow -NoNewline
        Write-Host "$($theme.Name)" -ForegroundColor White -NoNewline
        Write-Host " - $($theme.Description)" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "  [A] " -ForegroundColor Magenta -NoNewline
    Write-Host "Show ALL preview images in browser" -ForegroundColor White
    Write-Host "  [P] " -ForegroundColor Magenta -NoNewline
    Write-Host "Preview a specific theme (enter number after)" -ForegroundColor White
    Write-Host "  [Q] " -ForegroundColor Red -NoNewline
    Write-Host "Quit" -ForegroundColor White
    Write-Host ""
    
    while ($true) {
        $selection = Read-Host "Select theme (1-$($Config.Themes.Count)), [A]ll previews, [P]review #, or [Q]uit"
        
        if ($selection -eq 'Q' -or $selection -eq 'q') {
            Write-Status "Setup cancelled by user." -Type Warning
            exit 0
        }
        
        if ($selection -eq 'A' -or $selection -eq 'a') {
            Show-ThemePreviewImages -Themes $Config.Themes
            continue
        }
        
        if ($selection -match '^[Pp]\s*(\d+)$') {
            $previewNum = [int]$Matches[1]
            if ($previewNum -ge 1 -and $previewNum -le $Config.Themes.Count) {
                Show-ThemePreviewSingleImage -ThemeName $Config.Themes[$previewNum - 1].Name
            }
            else {
                Write-Host "Invalid preview number. Enter P followed by 1-$($Config.Themes.Count)" -ForegroundColor Red
            }
            continue
        }
        
        if ($selection -eq 'P' -or $selection -eq 'p') {
            $previewNum = Read-Host "Enter theme number to preview (1-$($Config.Themes.Count))"
            if ($previewNum -match '^\d+$') {
                $num = [int]$previewNum
                if ($num -ge 1 -and $num -le $Config.Themes.Count) {
                    Show-ThemePreviewSingleImage -ThemeName $Config.Themes[$num - 1].Name
                }
                else {
                    Write-Host "Invalid number." -ForegroundColor Red
                }
            }
            continue
        }
        
        if ($selection -match '^\d+$') {
            $num = [int]$selection
            if ($num -ge 1 -and $num -le $Config.Themes.Count) {
                $selectedTheme = $Config.Themes[$num - 1]
                Write-Host ""
                Write-Status "Selected theme: $($selectedTheme.Name)" -Type Success
                return $selectedTheme.Name
            }
        }
        
        Write-Host "Invalid selection. Please enter 1-$($Config.Themes.Count), A, P#, or Q" -ForegroundColor Red
    }
}

function Install-OhMyPosh {
    Write-Status "Checking OhMyPosh installation..."
    
    $ohMyPosh = Get-Command oh-my-posh -ErrorAction SilentlyContinue
    
    if ($ohMyPosh -and -not $Force) {
        Write-Status "OhMyPosh already installed at: $($ohMyPosh.Source)" -Type Success
        return
    }
    
    Write-Status "Installing OhMyPosh via winget..."
    
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Status "winget not found. Attempting alternative installation..." -Type Warning
        Set-ExecutionPolicy Bypass -Scope Process -Force
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://ohmyposh.dev/install.ps1'))
    }
    else {
        winget install JanDeDobbeleer.OhMyPosh -s winget --accept-package-agreements --accept-source-agreements
    }
    
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + 
                [System.Environment]::GetEnvironmentVariable("Path", "User")
    
    if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
        Write-Status "OhMyPosh installed successfully!" -Type Success
    }
    else {
        Write-Status "OhMyPosh installation may require a terminal restart" -Type Warning
    }
}

function Install-NerdFont {
    if ($SkipFontInstall) {
        Write-Status "Skipping font installation (SkipFontInstall specified)" -Type Warning
        return
    }
    
    if (-not (Test-AdminPrivilege)) {
        Write-Status "Font installation requires Administrator privileges. Run script as Admin or use -SkipFontInstall" -Type Warning
        return
    }
    
    Write-Status "Checking for $($Config.FontFamily)..."
    
    $installedFonts = (New-Object System.Drawing.Text.InstalledFontCollection).Families.Name
    if ($installedFonts -contains $Config.FontFamily -and -not $Force) {
        Write-Status "$($Config.FontFamily) already installed!" -Type Success
        return
    }
    
    Write-Status "Downloading $($Config.FontName) Nerd Font..."
    
    $tempDir = Join-Path $env:TEMP "NerdFonts_$(Get-Date -Format 'yyyyMMddHHmmss')"
    $zipPath = Join-Path $tempDir "$($Config.FontName).zip"
    
    try {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        
        $downloadUrl = "$($Config.NerdFontsBase)/$($Config.FontName).zip"
        
        try {
            Start-BitsTransfer -Source $downloadUrl -Destination $zipPath -ErrorAction Stop
        }
        catch {
            Write-Status "BITS transfer failed, using WebClient..." -Type Warning
            (New-Object System.Net.WebClient).DownloadFile($downloadUrl, $zipPath)
        }
        
        Write-Status "Extracting fonts..."
        Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force
        
        Write-Status "Installing fonts..."
        $shellApp = New-Object -ComObject Shell.Application
        $fontsFolder = $shellApp.Namespace(0x14)
        
        $fontFiles = Get-ChildItem -Path $tempDir -Include '*.ttf', '*.otf' -Recurse
        $installed = 0
        
        foreach ($font in $fontFiles) {
            if ($font.Name -match 'Windows Compatible|NerdFontPropo|NerdFontMono') {
                continue
            }
            
            try {
                $fontsFolder.CopyHere($font.FullName, 0x10)
                $installed++
            }
            catch { }
        }
        
        Write-Status "$installed font files installed successfully!" -Type Success
    }
    finally {
        if (Test-Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Update-PowerShellProfile {
    param([string]$ThemeName)
    
    if ($SkipProfileUpdate) {
        Write-Status "Skipping profile update (SkipProfileUpdate specified)" -Type Warning
        return
    }
    
    Write-Status "Configuring PowerShell profile with theme: $ThemeName..."
    
    $profilePath = $PROFILE.CurrentUserAllHosts
    $profileDir = Split-Path $profilePath -Parent
    
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }
    
    $ohMyPoshInit = @"

# OhMyPosh Configuration - Added by Install-OhMyPoshSetup.ps1
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh --config `"`$env:POSH_THEMES_PATH\$ThemeName.omp.json`" | Invoke-Expression
}
"@
    
    if (Test-Path $profilePath) {
        $profileContent = Get-Content $profilePath -Raw
        
        if ($profileContent -match 'oh-my-posh init') {
            if ($Force) {
                Write-Status "Removing existing OhMyPosh configuration..." -Type Warning
                $profileContent = $profileContent -replace '(?ms)# OhMyPosh Configuration.*?Invoke-Expression\s*\}', ''
                $profileContent = $profileContent -replace "oh-my-posh init pwsh.*Invoke-Expression", ''
                Set-Content -Path $profilePath -Value $profileContent.Trim()
            }
            else {
                Write-Status "OhMyPosh already configured in profile. Use -Force to overwrite." -Type Warning
                return
            }
        }
    }
    
    Add-Content -Path $profilePath -Value $ohMyPoshInit
    
    Write-Status "Profile updated at: $profilePath" -Type Success
}

function Update-WindowsTerminalSettings {
    Write-Status "Checking Windows Terminal configuration..."
    
    $wtSettingsPaths = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
    )
    
    $wtSettingsPath = $wtSettingsPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    
    if (-not $wtSettingsPath) {
        Write-Status "Windows Terminal settings not found." -Type Warning
        return
    }
    
    try {
        $settings = Get-Content $wtSettingsPath -Raw | ConvertFrom-Json
        
        $currentFont = $settings.profiles.defaults.font.face
        
        if ($currentFont -eq $Config.FontFamily -and -not $Force) {
            Write-Status "Windows Terminal already configured with $($Config.FontFamily)" -Type Success
            return
        }
        
        $backupPath = "$wtSettingsPath.backup_$(Get-Date -Format 'yyyyMMddHHmmss')"
        Copy-Item $wtSettingsPath $backupPath
        Write-Status "Settings backed up to: $backupPath"
        
        if (-not $settings.profiles.defaults) {
            $settings.profiles | Add-Member -NotePropertyName 'defaults' -NotePropertyValue @{} -Force
        }
        
        if (-not $settings.profiles.defaults.font) {
            $settings.profiles.defaults | Add-Member -NotePropertyName 'font' -NotePropertyValue @{} -Force
        }
        
        $settings.profiles.defaults.font | Add-Member -NotePropertyName 'face' -NotePropertyValue $Config.FontFamily -Force
        
        $settings | ConvertTo-Json -Depth 100 | Set-Content $wtSettingsPath -Encoding UTF8
        
        Write-Status "Windows Terminal configured to use $($Config.FontFamily)" -Type Success
    }
    catch {
        Write-Status "Failed to update Windows Terminal settings: $_" -Type Error
    }
}

function Update-VSCodeSettings {
    Write-Status "Checking VS Code configuration..."
    
    $vsCodeSettingsPaths = @(
        "$env:APPDATA\Code\User\settings.json",
        "$env:APPDATA\Code - Insiders\User\settings.json"
    )
    
    foreach ($vsCodeSettingsPath in $vsCodeSettingsPaths) {
        if (-not (Test-Path $vsCodeSettingsPath)) {
            continue
        }
        
        $appName = if ($vsCodeSettingsPath -match 'Insiders') { 'VS Code Insiders' } else { 'VS Code' }
        
        try {
            $settingsContent = Get-Content $vsCodeSettingsPath -Raw -ErrorAction Stop
            
            # Check if font is already set
            if ($settingsContent -match '"terminal\.integrated\.fontFamily"\s*:\s*"Hack Nerd Font"' -and -not $Force) {
                Write-Status "$appName already configured with $($Config.FontFamily)" -Type Success
                continue
            }
            
            # Backup
            $backupPath = "$vsCodeSettingsPath.backup_$(Get-Date -Format 'yyyyMMddHHmmss')"
            Copy-Item $vsCodeSettingsPath $backupPath
            
            # Check if the setting already exists
            if ($settingsContent -match '"terminal\.integrated\.fontFamily"') {
                # Replace existing setting
                $settingsContent = $settingsContent -replace '"terminal\.integrated\.fontFamily"\s*:\s*"[^"]*"', "`"terminal.integrated.fontFamily`": `"$($Config.FontFamily)`""
            }
            else {
                # Add new setting after the opening brace
                $settingsContent = $settingsContent -replace '^\s*\{', "{`n    `"terminal.integrated.fontFamily`": `"$($Config.FontFamily)`","
            }
            
            Set-Content $vsCodeSettingsPath -Value $settingsContent -Encoding UTF8
            
            Write-Status "$appName configured to use $($Config.FontFamily)" -Type Success
            Write-Status "Restart VS Code for font changes to take effect" -Type Warning
        }
        catch {
            Write-Status "Failed to update $appName settings: $_" -Type Warning
            Write-Status "Set 'terminal.integrated.fontFamily' to '$($Config.FontFamily)' manually" -Type Warning
        }
    }
}

function Show-PostInstallInstructions {
    param([string]$ThemeName)
    
    Write-Host ""
    Write-Host ('=' * 60) -ForegroundColor Cyan
    Write-Host "  Setup Complete!" -ForegroundColor Green
    Write-Host ('=' * 60) -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Theme: $ThemeName" -ForegroundColor Cyan
    Write-Host "Font:  $($Config.FontFamily)" -ForegroundColor Cyan
    Write-Host ""
    
    # Auto-reload profile
    Write-Status "Reloading PowerShell profile..."
    try {
        $profilePath = $PROFILE.CurrentUserAllHosts
        if (Test-Path $profilePath) {
            . $profilePath
            Write-Status "Profile reloaded - theme should now be active!" -Type Success
        }
    }
    catch {
        Write-Status "Could not auto-reload profile. Please restart your terminal." -Type Warning
    }
    
    Write-Host ""
    Write-Host "To change themes later, run:" -ForegroundColor Gray
    Write-Host "  .\Install-OhMyPoshSetup.ps1 -Force" -ForegroundColor White
    Write-Host ""
}

# Main execution
Write-Host ""
Write-Host "OhMyPosh Portable Setup" -ForegroundColor Cyan
Write-Host "=======================" -ForegroundColor Cyan
Write-Host ""

try {
    $selectedTheme = $null
    
    if ($Theme) {
        $validTheme = $Config.Themes | Where-Object { $_.Name -eq $Theme }
        if ($validTheme) {
            $selectedTheme = $Theme
            Write-Status "Using specified theme: $selectedTheme" -Type Success
        }
        else {
            Write-Status "Theme '$Theme' not in configured list. Available: $($Config.Themes.Name -join ', ')" -Type Warning
            $selectedTheme = Get-ThemeSelection
        }
    }
    elseif ($ShowPreviews) {
        Show-ThemePreviewImages -Themes $Config.Themes
        $selectedTheme = Get-ThemeSelection
    }
    else {
        $selectedTheme = Get-ThemeSelection
    }
    
    Install-OhMyPosh
    Install-NerdFont
    Update-PowerShellProfile -ThemeName $selectedTheme
    Update-WindowsTerminalSettings
    Update-VSCodeSettings
    Show-PostInstallInstructions -ThemeName $selectedTheme
}
catch {
    Write-Status "Setup failed: $_" -Type Error
    throw
}
