<#
.SYNOPSIS
    Install commonly used PowerShell modules with progress tracking

.PARAMETER Parallel
    Install modules in parallel (faster but more verbose output)

.PARAMETER Force
    Force reinstall of existing modules
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [switch]$Parallel,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# ============================================
# MODULE DEFINITIONS - Grouped by install time
# ============================================

# Quick installs (< 30 seconds)
$QuickModules = @(
    @{ Name = 'PSReadLine'; Description = 'Enhanced command line editing' }
    @{ Name = 'Terminal-Icons'; Description = 'File/folder icons in terminal' }
    @{ Name = 'posh-git'; Description = 'Git status in prompt' }
)

# Medium installs (1-2 minutes)
$MediumModules = @(
    @{ Name = 'ExchangeOnlineManagement'; Description = 'Exchange Online' }
    @{ Name = 'MicrosoftTeams'; Description = 'Microsoft Teams' }
)

# Large installs (2-5+ minutes)
$LargeModules = @(
    @{ Name = 'Az'; Description = 'Azure PowerShell (large - may take several minutes)' }
    @{ Name = 'Microsoft.Graph'; Description = 'Microsoft Graph API (large - may take several minutes)' }
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

function Write-ProgressBar {
    param(
        [int]$Current,
        [int]$Total,
        [string]$Activity,
        [string]$Status
    )
    
    $percent = [math]::Round(($Current / $Total) * 100)
    $completed = [math]::Round($percent / 2)
    $remaining = 50 - $completed
    
    $bar = "[" + ("█" * $completed) + ("░" * $remaining) + "]"
    
    Write-Host "`r$bar $percent% - $Status                    " -NoNewline
    
    if ($Current -eq $Total) {
        Write-Host ""
    }
}

function Test-ModuleInstalled {
    param([string]$Name)
    $null -ne (Get-Module -ListAvailable -Name $Name -ErrorAction SilentlyContinue)
}

function Install-ModuleWithProgress {
    param(
        [string]$Name,
        [string]$Description,
        [int]$Current,
        [int]$Total
    )
    
    $percent = [math]::Round(($Current / $Total) * 100)
    
    if ((Test-ModuleInstalled -Name $Name) -and -not $Force) {
        $version = (Get-Module -ListAvailable -Name $Name | Select-Object -First 1).Version
        Write-Host "`r[" -NoNewline
        Write-Host "$percent%" -ForegroundColor Cyan -NoNewline
        Write-Host "] " -NoNewline
        Write-Host "✓ $Name" -ForegroundColor Green -NoNewline
        Write-Host " (v$version already installed)                    "
        return $true
    }
    
    Write-Host "`r[" -NoNewline
    Write-Host "$percent%" -ForegroundColor Cyan -NoNewline
    Write-Host "] " -NoNewline
    Write-Host "Installing $Name" -ForegroundColor Yellow -NoNewline
    Write-Host " - $Description...                    " -NoNewline
    
    try {
        Install-Module -Name $Name -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop *>&1 | Out-Null
        Write-Host "`r[" -NoNewline
        Write-Host "$percent%" -ForegroundColor Cyan -NoNewline
        Write-Host "] " -NoNewline
        Write-Host "✓ $Name" -ForegroundColor Green -NoNewline
        Write-Host " installed successfully                              "
        return $true
    }
    catch {
        Write-Host "`r[" -NoNewline
        Write-Host "$percent%" -ForegroundColor Cyan -NoNewline
        Write-Host "] " -NoNewline
        Write-Host "✗ $Name" -ForegroundColor Red -NoNewline
        Write-Host " failed: $_                              "
        return $false
    }
}

function Install-ModulesParallel {
    param([array]$Modules, [string]$Category)
    
    if ($Modules.Count -eq 0) { return }
    
    Write-Host ""
    Write-Host "  $Category (parallel)" -ForegroundColor Yellow
    Write-Host "  $('-' * ($Category.Length + 11))" -ForegroundColor Yellow
    
    $jobs = @()
    
    foreach ($module in $Modules) {
        if ((Test-ModuleInstalled -Name $module.Name) -and -not $Force) {
            $version = (Get-Module -ListAvailable -Name $module.Name | Select-Object -First 1).Version
            Write-Host "  ✓ $($module.Name) (v$version already installed)" -ForegroundColor Green
            continue
        }
        
        Write-Host "  ○ Starting $($module.Name)..." -ForegroundColor Gray
        
        $job = Start-Job -ScriptBlock {
            param($ModuleName)
            Install-Module -Name $ModuleName -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        } -ArgumentList $module.Name
        
        $jobs += @{
            Job = $job
            Module = $module
        }
    }
    
    if ($jobs.Count -eq 0) { return }
    
    # Wait for jobs with progress
    $completed = 0
    $total = $jobs.Count
    
    while ($completed -lt $total) {
        foreach ($item in $jobs) {
            if ($item.Completed) { continue }
            
            if ($item.Job.State -eq 'Completed') {
                $item.Completed = $true
                $completed++
                Write-Host "  ✓ $($item.Module.Name) installed" -ForegroundColor Green
            }
            elseif ($item.Job.State -eq 'Failed') {
                $item.Completed = $true
                $completed++
                Write-Host "  ✗ $($item.Module.Name) failed" -ForegroundColor Red
            }
        }
        
        if ($completed -lt $total) {
            $running = ($jobs | Where-Object { -not $_.Completed }).Module.Name -join ', '
            Write-Host "`r  [$completed/$total] Still installing: $running          " -NoNewline
            Start-Sleep -Milliseconds 500
        }
    }
    
    Write-Host "`r                                                                        " -NoNewline
    Write-Host "`r"
    
    # Cleanup jobs
    $jobs | ForEach-Object { Remove-Job -Job $_.Job -Force -ErrorAction SilentlyContinue }
}

function Install-ModulesSequential {
    param([array]$Modules, [string]$Category, [ref]$CurrentCount, [int]$TotalCount)
    
    if ($Modules.Count -eq 0) { return }
    
    Write-Host ""
    Write-Host "  $Category" -ForegroundColor Yellow
    Write-Host "  $('-' * $Category.Length)" -ForegroundColor Yellow
    
    foreach ($module in $Modules) {
        $CurrentCount.Value++
        Install-ModuleWithProgress -Name $module.Name -Description $module.Description -Current $CurrentCount.Value -Total $TotalCount
    }
}

# ============================================
# MAIN
# ============================================

Write-Host ""
Write-Host "PowerShell Module Installation" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""

# Check for NuGet provider
if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
    Write-Status "Installing NuGet provider..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
}

# Set PSGallery as trusted
if ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne 'Trusted') {
    Write-Status "Setting PSGallery as trusted..."
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}

$allModules = $QuickModules + $MediumModules + $LargeModules
$totalCount = $allModules.Count
$currentCount = [ref]0

# Show what we're installing
Write-Host "Modules to install: $totalCount" -ForegroundColor Gray
Write-Host "  Quick ($($QuickModules.Count)): $($QuickModules.Name -join ', ')" -ForegroundColor Gray
Write-Host "  Medium ($($MediumModules.Count)): $($MediumModules.Name -join ', ')" -ForegroundColor Gray
Write-Host "  Large ($($LargeModules.Count)): $($LargeModules.Name -join ', ')" -ForegroundColor Gray

if ($Parallel) {
    # Parallel installation - install large modules simultaneously
    Install-ModulesSequential -Modules $QuickModules -Category "Quick Installs" -CurrentCount $currentCount -TotalCount $totalCount
    Install-ModulesSequential -Modules $MediumModules -Category "Medium Installs" -CurrentCount $currentCount -TotalCount $totalCount
    Install-ModulesParallel -Modules $LargeModules -Category "Large Installs"
}
else {
    # Sequential installation with progress
    Install-ModulesSequential -Modules $QuickModules -Category "Quick Installs (< 30 sec each)" -CurrentCount $currentCount -TotalCount $totalCount
    Install-ModulesSequential -Modules $MediumModules -Category "Medium Installs (1-2 min each)" -CurrentCount $currentCount -TotalCount $totalCount
    
    Write-Host ""
    Write-Host "  Large Installs (2-5+ min each)" -ForegroundColor Yellow
    Write-Host "  ------------------------------" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Note: Az and Microsoft.Graph are large modules." -ForegroundColor Gray
    Write-Host "  Consider running with -Parallel flag for faster installation." -ForegroundColor Gray
    Write-Host ""
    
    foreach ($module in $LargeModules) {
        $currentCount.Value++
        $percent = [math]::Round(($currentCount.Value / $totalCount) * 100)
        
        if ((Test-ModuleInstalled -Name $module.Name) -and -not $Force) {
            $version = (Get-Module -ListAvailable -Name $module.Name | Select-Object -First 1).Version
            Write-Host "[$percent%] " -ForegroundColor Cyan -NoNewline
            Write-Host "✓ $($module.Name)" -ForegroundColor Green -NoNewline
            Write-Host " (v$version already installed)"
            continue
        }
        
        Write-Host "[$percent%] " -ForegroundColor Cyan -NoNewline
        Write-Host "Installing $($module.Name)" -ForegroundColor Yellow -NoNewline
        Write-Host " - $($module.Description)"
        Write-Host "       This may take several minutes. Please wait..." -ForegroundColor Gray
        
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        
        try {
            Install-Module -Name $module.Name -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
            $stopwatch.Stop()
            $elapsed = [math]::Round($stopwatch.Elapsed.TotalSeconds)
            Write-Host "       " -NoNewline
            Write-Host "✓ Completed in ${elapsed}s" -ForegroundColor Green
        }
        catch {
            $stopwatch.Stop()
            Write-Host "       " -NoNewline
            Write-Host "✗ Failed: $_" -ForegroundColor Red
        }
        Write-Host ""
    }
}

Write-Host ""
Write-Host ('=' * 40) -ForegroundColor Green
Write-Host "  Module Installation Complete!" -ForegroundColor Green
Write-Host ('=' * 40) -ForegroundColor Green
Write-Host ""
