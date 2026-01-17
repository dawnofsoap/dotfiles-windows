<#
.SYNOPSIS
    Main installer - runs all setup scripts

.DESCRIPTION
    Sets up a fresh Windows machine with:
    - Applications (via winget)
    - Git configuration
    - PowerShell modules
    - OhMyPosh with Nerd Font

.PARAMETER Parallel
    Install apps and modules in parallel (faster)

.PARAMETER SkipApps
    Skip application installation

.PARAMETER SkipGit
    Skip git configuration

.PARAMETER SkipModules
    Skip PowerShell module installation

.PARAMETER SkipOhMyPosh
    Skip OhMyPosh setup

.EXAMPLE
    # Run from web
    iex (irm "https://raw.githubusercontent.com/dawnofsoap/dotfiles-windows/main/install.ps1")
    
    # Run locally with parallel
    .\install.ps1 -Parallel
    
    # Skip certain steps
    .\install.ps1 -SkipApps -SkipModules
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [switch]$Parallel,
    [switch]$SkipApps,
    [switch]$SkipGit,
    [switch]$SkipModules,
    [switch]$SkipOhMyPosh
)

$ErrorActionPreference = 'Stop'

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

# Header
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  dotfiles-windows installer" -ForegroundColor Cyan
Write-Host "  github.com/dawnofsoap/dotfiles-windows" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($Parallel) {
    Write-Host "  Mode: Parallel installation (faster)" -ForegroundColor Green
    Write-Host ""
}

# Check for admin
if (-not (Test-AdminPrivilege)) {
    Write-Status "Not running as Administrator. Some features may be limited." -Type Warning
    Write-Status "For full functionality, run PowerShell as Administrator." -Type Warning
    Write-Host ""
}

# Determine script location
$ScriptRoot = $PSScriptRoot
if (-not $ScriptRoot) {
    Write-Status "Downloading dotfiles..."
    
    $tempDir = Join-Path $env:TEMP "dotfiles-windows"
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force
    }
    
    git clone https://github.com/dawnofsoap/dotfiles-windows.git $tempDir 2>$null
    
    if (-not (Test-Path $tempDir)) {
        Write-Status "Git not found, downloading via web..."
        $zipUrl = "https://github.com/dawnofsoap/dotfiles-windows/archive/refs/heads/main.zip"
        $zipPath = Join-Path $env:TEMP "dotfiles.zip"
        
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath
        Expand-Archive -Path $zipPath -DestinationPath $env:TEMP -Force
        $tempDir = Join-Path $env:TEMP "dotfiles-windows-main"
        Remove-Item $zipPath -Force
    }
    
    $ScriptRoot = $tempDir
}

$setupDir = Join-Path $ScriptRoot "setup"
$totalSteps = 4 - @($SkipApps, $SkipGit, $SkipModules, $SkipOhMyPosh).Where({ $_ }).Count
$currentStep = 0

# Run setup scripts
if (-not $SkipApps) {
    $currentStep++
    Write-Host ""
    Write-Host "Step $currentStep/$totalSteps : Applications" -ForegroundColor Yellow
    Write-Host ("-" * 40) -ForegroundColor Yellow
    
    # Apps always run parallel (they're independent)
    & "$setupDir\apps.ps1" -Parallel
}

if (-not $SkipGit) {
    $currentStep++
    Write-Host ""
    Write-Host "Step $currentStep/$totalSteps : Git Configuration" -ForegroundColor Yellow
    Write-Host ("-" * 40) -ForegroundColor Yellow
    & "$setupDir\git.ps1"
}

if (-not $SkipModules) {
    $currentStep++
    Write-Host ""
    Write-Host "Step $currentStep/$totalSteps : PowerShell Modules" -ForegroundColor Yellow
    Write-Host ("-" * 40) -ForegroundColor Yellow
    
    # Modules use parallel flag (some have dependencies)
    if ($Parallel) {
        & "$setupDir\modules.ps1" -Parallel
    }
    else {
        & "$setupDir\modules.ps1"
    }
}

if (-not $SkipOhMyPosh) {
    $currentStep++
    Write-Host ""
    Write-Host "Step $currentStep/$totalSteps : OhMyPosh Setup" -ForegroundColor Yellow
    Write-Host ("-" * 40) -ForegroundColor Yellow
    & "$setupDir\ohmyposh.ps1"
}

# Done
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Restart your terminal"
Write-Host "  2. If running as Admin, fonts should work"
Write-Host "  3. Customize scripts in: $ScriptRoot"
Write-Host ""
