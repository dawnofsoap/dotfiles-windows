# PowerShell functions to add to your profile
# Copy these to your $PROFILE or source this file

# Quick navigation
function .. { Set-Location .. }
function ... { Set-Location ..\.. }
function .... { Set-Location ..\..\.. }

# Quick directory listing
function ll { Get-ChildItem -Force $args }
function la { Get-ChildItem -Force -Hidden $args }

# Open current folder in Explorer
function explorer { explorer.exe . }
function e { explorer.exe . }

# Open current folder in VS Code
function c { code . }

# Reload PowerShell profile
function reload { & $PROFILE.CurrentUserAllHosts }

# Get public IP
function myip { (Invoke-WebRequest -Uri "https://api.ipify.org").Content }

# Quick hosts file edit (requires admin)
function hosts { notepad C:\Windows\System32\drivers\etc\hosts }

# Create and enter directory
function mkcd {
    param([string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Set-Location $Path
}

# Find files by name
function ff {
    param([string]$Name)
    Get-ChildItem -Recurse -Filter "*$Name*" -ErrorAction SilentlyContinue
}

# Kill process by name
function pkill {
    param([string]$Name)
    Get-Process $Name -ErrorAction SilentlyContinue | Stop-Process -Force
}

# Quick Azure context switch
function azctx {
    param([string]$Name)
    if ($Name) {
        Get-AzContext -ListAvailable | Where-Object { $_.Name -match $Name } | Select-Object -First 1 | Set-AzContext
    }
    else {
        Get-AzContext -ListAvailable | Format-Table Name, Subscription, Tenant
    }
}

# Quick Graph connection
function mggraph {
    Connect-MgGraph -Scopes "User.Read.All", "Group.Read.All", "Directory.Read.All"
}

# Tail a file (like Unix tail -f)
function tail {
    param(
        [string]$Path,
        [int]$Lines = 10
    )
    Get-Content -Path $Path -Tail $Lines -Wait
}

# Get folder size
function foldersize {
    param([string]$Path = ".")
    $size = (Get-ChildItem -Path $Path -Recurse -ErrorAction SilentlyContinue | 
             Measure-Object -Property Length -Sum).Sum
    "{0:N2} MB" -f ($size / 1MB)
}
