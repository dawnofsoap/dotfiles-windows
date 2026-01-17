<#
.SYNOPSIS
    Configure Git settings
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

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

Write-Host ""
Write-Host "Git Configuration" -ForegroundColor Cyan
Write-Host "=================" -ForegroundColor Cyan
Write-Host ""

# Check if Git is installed
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Status "Git not found. Installing via winget..." -Type Warning
    winget install Git.Git --accept-package-agreements --accept-source-agreements
    
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + 
                [System.Environment]::GetEnvironmentVariable("Path", "User")
}

# Get current config or prompt for new
$currentName = git config --global user.name 2>$null
$currentEmail = git config --global user.email 2>$null

if ($currentName) {
    Write-Status "Current git user.name: $currentName"
    $changeName = Read-Host "Keep this name? (Y/n)"
    if ($changeName -eq 'n' -or $changeName -eq 'N') {
        $currentName = $null
    }
}

if (-not $currentName) {
    $newName = Read-Host "Enter your Git name"
    git config --global user.name "$newName"
    Write-Status "Set user.name to: $newName" -Type Success
}

if ($currentEmail) {
    Write-Status "Current git user.email: $currentEmail"
    $changeEmail = Read-Host "Keep this email? (Y/n)"
    if ($changeEmail -eq 'n' -or $changeEmail -eq 'N') {
        $currentEmail = $null
    }
}

if (-not $currentEmail) {
    $newEmail = Read-Host "Enter your Git email"
    git config --global user.email "$newEmail"
    Write-Status "Set user.email to: $newEmail" -Type Success
}

# Set recommended defaults
Write-Status "Configuring Git defaults..."

# Default branch name
git config --global init.defaultBranch main

# Better diff
git config --global diff.colorMoved zebra

# Auto-correct typos (with 1 second delay)
git config --global help.autocorrect 10

# Push current branch by default
git config --global push.default current

# Rebase on pull instead of merge
git config --global pull.rebase true

# Use VS Code as default editor (if available)
if (Get-Command code -ErrorAction SilentlyContinue) {
    git config --global core.editor "code --wait"
    Write-Status "Set VS Code as default Git editor" -Type Success
}

# Windows-specific settings
git config --global core.autocrlf true
git config --global credential.helper manager

# Useful aliases
git config --global alias.st "status"
git config --global alias.co "checkout"
git config --global alias.br "branch"
git config --global alias.cm "commit -m"
git config --global alias.lg "log --oneline --graph --decorate"
git config --global alias.last "log -1 HEAD"
git config --global alias.unstage "reset HEAD --"
git config --global alias.undo "reset --soft HEAD~1"

Write-Host ""
Write-Status "Git configuration complete!" -Type Success
Write-Host ""
Write-Host "Aliases configured:" -ForegroundColor Yellow
Write-Host "  git st     = status"
Write-Host "  git co     = checkout"
Write-Host "  git br     = branch"
Write-Host "  git cm     = commit -m"
Write-Host "  git lg     = log (pretty)"
Write-Host "  git last   = show last commit"
Write-Host "  git unstage = unstage files"
Write-Host "  git undo   = undo last commit (keep changes)"
Write-Host ""
