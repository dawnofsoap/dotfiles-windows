<#
.SYNOPSIS
    Install applications via winget with progress tracking

.PARAMETER Core
    Install core apps only (Git, PowerShell, VS Code, etc.)

.PARAMETER Dev
    Include development tools (Docker, Python, WSL, etc.)

.PARAMETER IT
    Include IT/Infrastructure tools (RustDesk, AzCopy, etc.)

.PARAMETER All
    Install everything (excluding RSAT unless -IncludeRSAT specified)

.PARAMETER IncludeRSAT
    Include RSAT tools (slow - downloads from Windows Update)

.PARAMETER Parallel
    Install apps in parallel (faster)

.EXAMPLE
    .\apps.ps1 -Core -IT           # Core + IT tools (no RSAT)
    .\apps.ps1 -IT -IncludeRSAT    # IT tools with RSAT
    .\apps.ps1 -All                # Everything except RSAT
    .\apps.ps1                     # Interactive selection
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [switch]$Core,
    [switch]$Dev,
    [switch]$IT,
    [switch]$All,
    [switch]$IncludeRSAT,
    [switch]$Parallel,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# ============================================
# APP DEFINITIONS
# ============================================

$CoreApps = @(
    @{ Id = 'Microsoft.PowerShell'; Name = 'PowerShell 7' }
    @{ Id = 'Microsoft.WindowsTerminal'; Name = 'Windows Terminal' }
    @{ Id = 'Microsoft.VisualStudioCode'; Name = 'VS Code' }
    @{ Id = 'Git.Git'; Name = 'Git' }
    @{ Id = 'M2Team.NanaZip'; Name = 'NanaZip' }
    @{ Id = 'Bitwarden.Bitwarden'; Name = 'Bitwarden' }
)

$DevApps = @(
    @{ Id = 'Python.Python.3.12'; Name = 'Python 3.12' }
    @{ Id = 'Docker.DockerDesktop'; Name = 'Docker Desktop' }
    @{ Id = 'Microsoft.DotNet.SDK.8'; Name = '.NET SDK 8' }
    @{ Id = 'EclipseAdoptium.Temurin.21.JDK'; Name = 'Eclipse Temurin JDK 21' }
    @{ Id = 'Anthropic.Claude'; Name = 'Claude Desktop' }
)

$ITApps = @(
    @{ Id = 'Famatech.AdvancedIPScanner'; Name = 'Advanced IP Scanner' }
    @{ Id = 'Microsoft.AzureCLI'; Name = 'Azure CLI' }
    @{ Id = 'Microsoft.Azure.StorageExplorer'; Name = 'Azure Storage Explorer' }
    @{ Id = 'Microsoft.Azure.AZCopy.10'; Name = 'AzCopy' }
    @{ Id = 'WinSCP.WinSCP'; Name = 'WinSCP' }
    @{ Id = 'RustDesk.RustDesk'; Name = 'RustDesk' }
    @{ Id = 'JAMSoftware.TreeSize.Free'; Name = 'TreeSize Free' }
    @{ Id = 'WinDirStat.WinDirStat'; Name = 'WinDirStat' }
)

$UtilityApps = @(
    @{ Id = 'dotPDN.PaintDotNet'; Name = 'Paint.NET' }
)

# ============================================
# FUNCTIONS
# ============================================

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

function Test-AppInstalled {
    param([string]$Id)
    $result = winget list --id $Id --accept-source-agreements 2>$null
    return ($result | Select-String $Id) -ne $null
}

function Install-SingleApp {
    param(
        [string]$Id,
        [string]$Name,
        [int]$Current,
        [int]$Total
    )
    
    $percent = [math]::Round(($Current / $Total) * 100)
    
    if ((Test-AppInstalled -Id $Id) -and -not $Force) {
        Write-Host "[$percent%] " -ForegroundColor Cyan -NoNewline
        Write-Host "✓ $Name" -ForegroundColor Green -NoNewline
        Write-Host " (already installed)"
        return @{ Success = $true; Skipped = $true }
    }
    
    Write-Host "[$percent%] " -ForegroundColor Cyan -NoNewline
    Write-Host "Installing $Name" -ForegroundColor Yellow -NoNewline
    Write-Host "..."
    
    try {
        $result = winget install --id $Id --accept-package-agreements --accept-source-agreements --silent 2>&1
        if ($LASTEXITCODE -eq 0 -or $result -match 'Successfully installed') {
            Write-Host "       ✓ $Name installed" -ForegroundColor Green
            return @{ Success = $true; Skipped = $false }
        }
        else {
            Write-Host "       ⚠ $Name may need manual install" -ForegroundColor Yellow
            return @{ Success = $false; Skipped = $false }
        }
    }
    catch {
        Write-Host "       ✗ $Name failed" -ForegroundColor Red
        return @{ Success = $false; Skipped = $false }
    }
}

function Install-AppsSequential {
    param(
        [array]$Apps,
        [string]$Category,
        [ref]$CurrentCount,
        [int]$TotalCount,
        [ref]$Stats
    )
    
    if ($Apps.Count -eq 0) { return }
    
    Write-Host ""
    Write-Host "  $Category ($($Apps.Count) apps)" -ForegroundColor Yellow
    Write-Host "  $('-' * ($Category.Length + 10))" -ForegroundColor Yellow
    
    foreach ($app in $Apps) {
        $CurrentCount.Value++
        $result = Install-SingleApp -Id $app.Id -Name $app.Name -Current $CurrentCount.Value -Total $TotalCount
        
        if ($result.Success) {
            if ($result.Skipped) {
                $Stats.Value.Skipped++
            }
            else {
                $Stats.Value.Installed++
            }
        }
        else {
            $Stats.Value.Failed++
        }
    }
}

function Install-AppsParallel {
    param(
        [array]$Apps,
        [string]$Category,
        [ref]$Stats
    )
    
    if ($Apps.Count -eq 0) { return }
    
    Write-Host ""
    Write-Host "  $Category ($($Apps.Count) apps) - Parallel" -ForegroundColor Yellow
    Write-Host "  $('-' * ($Category.Length + 22))" -ForegroundColor Yellow
    
    # Check which apps need installing
    $toInstall = @()
    foreach ($app in $Apps) {
        if ((Test-AppInstalled -Id $app.Id) -and -not $Force) {
            Write-Host "  ✓ $($app.Name) (already installed)" -ForegroundColor Green
            $Stats.Value.Skipped++
        }
        else {
            $toInstall += $app
        }
    }
    
    if ($toInstall.Count -eq 0) { return }
    
    # Start parallel jobs
    $jobs = @()
    foreach ($app in $toInstall) {
        Write-Host "  ○ Starting $($app.Name)..." -ForegroundColor Gray
        
        $job = Start-Job -ScriptBlock {
            param($AppId)
            winget install --id $AppId --accept-package-agreements --accept-source-agreements --silent 2>&1
            return $LASTEXITCODE
        } -ArgumentList $app.Id
        
        $jobs += @{
            Job = $job
            App = $app
            Completed = $false
        }
    }
    
    # Wait for jobs with progress
    $completed = 0
    $total = $jobs.Count
    
    while ($completed -lt $total) {
        foreach ($item in $jobs) {
            if ($item.Completed) { continue }
            
            if ($item.Job.State -eq 'Completed' -or $item.Job.State -eq 'Failed') {
                $item.Completed = $true
                $completed++
                
                $exitCode = Receive-Job -Job $item.Job 2>$null | Select-Object -Last 1
                
                if ($item.Job.State -eq 'Completed' -and $exitCode -eq 0) {
                    Write-Host "  ✓ $($item.App.Name) installed" -ForegroundColor Green
                    $Stats.Value.Installed++
                }
                else {
                    Write-Host "  ⚠ $($item.App.Name) may need manual install" -ForegroundColor Yellow
                    $Stats.Value.Failed++
                }
            }
        }
        
        if ($completed -lt $total) {
            $running = ($jobs | Where-Object { -not $_.Completed }).App.Name -join ', '
            $percent = [math]::Round(($completed / $total) * 100)
            Write-Host "`r  [$percent%] Installing: $running                    " -NoNewline
            Start-Sleep -Milliseconds 1000
        }
    }
    
    Write-Host "`r                                                                              "
    
    # Cleanup
    $jobs | ForEach-Object { Remove-Job -Job $_.Job -Force -ErrorAction SilentlyContinue }
}

function Install-RSAT {
    param([ref]$Stats)
    
    Write-Host ""
    Write-Host "  RSAT Tools (this may take a while)" -ForegroundColor Yellow
    Write-Host "  -----------------------------------" -ForegroundColor Yellow
    
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Status "RSAT requires Administrator privileges. Skipping." -Type Warning
        return
    }
    
    $rsatFeatures = @(
        @{ Id = 'Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0'; Name = 'Active Directory' }
        @{ Id = 'Rsat.Dns.Tools~~~~0.0.1.0'; Name = 'DNS' }
        @{ Id = 'Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0'; Name = 'Group Policy' }
        @{ Id = 'Rsat.DHCP.Tools~~~~0.0.1.0'; Name = 'DHCP' }
    )
    
    $total = $rsatFeatures.Count
    $current = 0
    
    foreach ($feature in $rsatFeatures) {
        $current++
        $percent = [math]::Round(($current / $total) * 100)
        
        $installed = Get-WindowsCapability -Online -Name $feature.Id -ErrorAction SilentlyContinue
        
        if ($installed.State -eq 'Installed') {
            Write-Host "[$percent%] ✓ RSAT: $($feature.Name) (already installed)" -ForegroundColor Green
            $Stats.Value.Skipped++
        }
        else {
            Write-Host "[$percent%] Installing RSAT: $($feature.Name)..." -ForegroundColor Yellow
            try {
                Add-WindowsCapability -Online -Name $feature.Id -ErrorAction Stop | Out-Null
                Write-Host "       ✓ Installed" -ForegroundColor Green
                $Stats.Value.Installed++
            }
            catch {
                Write-Host "       ✗ Failed" -ForegroundColor Red
                $Stats.Value.Failed++
            }
        }
    }
}

function Install-WSL {
    param([ref]$Stats)
    
    Write-Host ""
    Write-Host "  WSL" -ForegroundColor Yellow
    Write-Host "  ---" -ForegroundColor Yellow
    
    $wslInstalled = Get-Command wsl -ErrorAction SilentlyContinue
    
    if ($wslInstalled) {
        Write-Host "[100%] ✓ WSL (already installed)" -ForegroundColor Green
        $Stats.Value.Skipped++
    }
    else {
        Write-Host "[100%] Installing WSL..." -ForegroundColor Yellow
        wsl --install --no-launch 2>&1 | Out-Null
        Write-Host "       ✓ WSL installed (reboot required)" -ForegroundColor Green
        $Stats.Value.Installed++
    }
}

function Show-InteractiveMenu {
    Write-Host ""
    Write-Host ('=' * 55) -ForegroundColor Cyan
    Write-Host "  Application Installation" -ForegroundColor Cyan
    Write-Host ('=' * 55) -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [1] Core Only        - Git, PS7, VS Code, NanaZip, Bitwarden"
    Write-Host "  [2] Core + Dev       - Add Docker, Python, WSL, .NET, JDK"
    Write-Host "  [3] Core + IT        - Add RustDesk, AzCopy, WinSCP, etc."
    Write-Host "  [4] Core + Dev + IT  - Development + Infrastructure"
    Write-Host "  [5] Everything       - All of the above + utilities"
    Write-Host ""
    Write-Host "  [R] Include RSAT     - Add AD, DNS, DHCP, GP tools (slow)" -ForegroundColor DarkGray
    Write-Host "  [Q] Quit"
    Write-Host ""
    
    $selection = Read-Host "Select option (add R for RSAT, e.g. '3R' or '4R')"
    
    $includeRsat = $selection -match 'R'
    $selection = $selection -replace 'R', ''
    
    switch ($selection.ToUpper().Trim()) {
        '1' { return @{ Core = $true; RSAT = $includeRsat } }
        '2' { return @{ Core = $true; Dev = $true; RSAT = $includeRsat } }
        '3' { return @{ Core = $true; IT = $true; RSAT = $includeRsat } }
        '4' { return @{ Core = $true; Dev = $true; IT = $true; RSAT = $includeRsat } }
        '5' { return @{ Core = $true; Dev = $true; IT = $true; Utility = $true; RSAT = $includeRsat } }
        'Q' { exit 0 }
        default { 
            Write-Host "Invalid selection" -ForegroundColor Red
            return Show-InteractiveMenu 
        }
    }
}

function Show-Summary {
    param($Stats, $Stopwatch)
    
    $elapsed = [math]::Round($Stopwatch.Elapsed.TotalMinutes, 1)
    
    Write-Host ""
    Write-Host ('=' * 50) -ForegroundColor Cyan
    Write-Host "  Installation Summary" -ForegroundColor Cyan
    Write-Host ('=' * 50) -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Installed:  $($Stats.Installed)" -ForegroundColor Green
    Write-Host "  Skipped:    $($Stats.Skipped)" -ForegroundColor Gray
    Write-Host "  Failed:     $($Stats.Failed)" -ForegroundColor $(if ($Stats.Failed -gt 0) { 'Red' } else { 'Gray' })
    Write-Host "  ─────────────────"
    Write-Host "  Total time: $elapsed minutes"
    Write-Host ""
}

# ============================================
# MAIN
# ============================================

Write-Host ""
Write-Host "Application Installation" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan

# Check winget
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Status "winget not found. Please install App Installer from Microsoft Store." -Type Error
    exit 1
}

# Determine what to install
if ($All) {
    $Core = $true; $Dev = $true; $IT = $true; $Utility = $true
}
elseif (-not ($Core -or $Dev -or $IT)) {
    $selections = Show-InteractiveMenu
    $Core = $selections.Core
    $Dev = $selections.Dev
    $IT = $selections.IT
    $Utility = $selections.Utility
    $IncludeRSAT = $selections.RSAT
}

# Calculate totals
$allApps = @()
if ($Core) { $allApps += $CoreApps }
if ($Dev) { $allApps += $DevApps }
if ($IT) { $allApps += $ITApps }
if ($Utility) { $allApps += $UtilityApps }

$totalCount = $allApps.Count
if ($Dev) { $totalCount++ }  # WSL
if ($IncludeRSAT) { $totalCount += 4 }  # RSAT features

Write-Host ""
Write-Host "Total items to process: $totalCount" -ForegroundColor Gray
if ($Parallel) {
    Write-Host "Mode: Parallel installation" -ForegroundColor Gray
}
if (-not $IncludeRSAT -and $IT) {
    Write-Host "RSAT: Skipped (use -IncludeRSAT to install)" -ForegroundColor DarkGray
}

$stats = [ref]@{ Installed = 0; Skipped = 0; Failed = 0 }
$currentCount = [ref]0
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# Install by category
if ($Parallel) {
    if ($Core) { Install-AppsParallel -Apps $CoreApps -Category "Core Applications" -Stats $stats }
    if ($Dev) { Install-AppsParallel -Apps $DevApps -Category "Development Tools" -Stats $stats; Install-WSL -Stats $stats }
    if ($IT) { Install-AppsParallel -Apps $ITApps -Category "IT/Infrastructure Tools" -Stats $stats }
    if ($Utility) { Install-AppsParallel -Apps $UtilityApps -Category "Utilities" -Stats $stats }
    if ($IncludeRSAT) { Install-RSAT -Stats $stats }
}
else {
    if ($Core) { Install-AppsSequential -Apps $CoreApps -Category "Core Applications" -CurrentCount $currentCount -TotalCount $totalCount -Stats $stats }
    if ($Dev) { Install-AppsSequential -Apps $DevApps -Category "Development Tools" -CurrentCount $currentCount -TotalCount $totalCount -Stats $stats; Install-WSL -Stats $stats }
    if ($IT) { Install-AppsSequential -Apps $ITApps -Category "IT/Infrastructure Tools" -CurrentCount $currentCount -TotalCount $totalCount -Stats $stats }
    if ($Utility) { Install-AppsSequential -Apps $UtilityApps -Category "Utilities" -CurrentCount $currentCount -TotalCount $totalCount -Stats $stats }
    if ($IncludeRSAT) { Install-RSAT -Stats $stats }
}

$stopwatch.Stop()
Show-Summary -Stats $stats.Value -Stopwatch $stopwatch

# Post-install notes
if ($Dev -or $IT -or $IncludeRSAT) {
    Write-Host "Notes:" -ForegroundColor Yellow
    if ($Dev) {
        Write-Host "  • Claude Code: npm install -g @anthropic-ai/claude-code"
        Write-Host "  • WSL: Reboot, then 'wsl --install Ubuntu'"
        Write-Host "  • Docker: May need Hyper-V/WSL2 backend enabled"
    }
    if ($IncludeRSAT) {
        Write-Host "  • RSAT: Reboot may be needed for all tools"
    }
    Write-Host ""
}
