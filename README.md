# dotfiles-windows

Personal Windows development environment setup. One command to configure a new machine.

## Quick Install

```powershell
iex (irm "https://raw.githubusercontent.com/dawnofsoap/dotfiles-windows/main/install.ps1")
```

## What's Included

| Component | Description |
|-----------|-------------|
| `install.ps1` | Main installer - runs everything |
| `setup/apps.ps1` | Application installation via winget |
| `setup/ohmyposh.ps1` | OhMyPosh + Nerd Font + theme selection |
| `setup/modules.ps1` | PowerShell modules (Az, Graph, etc.) |
| `setup/git.ps1` | Git configuration + aliases |
| `config/functions.ps1` | Useful PowerShell functions |

## Application Profiles

The app installer supports different profiles depending on your needs:

```powershell
.\setup\apps.ps1              # Interactive menu
.\setup\apps.ps1 -Core        # Just essentials
.\setup\apps.ps1 -Core -IT    # Work/Infrastructure machine
.\setup\apps.ps1 -Core -Dev   # Development machine
.\setup\apps.ps1 -All         # Everything
```

### Core Apps
> Always installed - the essentials for any machine

- PowerShell 7
- Windows Terminal
- VS Code
- Git
- NanaZip
- Bitwarden

### Development Tools (`-Dev`)
> For development machines

- Python 3.12
- Docker Desktop
- .NET SDK 8
- Eclipse Temurin JDK 21
- Claude Desktop
- WSL (Windows Subsystem for Linux)

### IT/Infrastructure Tools (`-IT`)
> For sysadmin and infrastructure work

- Advanced IP Scanner
- Azure CLI
- Azure Storage Explorer
- AzCopy
- WinSCP
- RustDesk
- TreeSize Free
- WinDirStat
- RSAT (AD, DNS, DHCP, Group Policy)

### Utilities
> Nice to have extras (included with `-All`)

- Paint.NET

## PowerShell Modules

The following modules are installed by `setup/modules.ps1`:

| Module | Purpose |
|--------|---------|
| Az | Azure PowerShell |
| Microsoft.Graph | Microsoft Graph API |
| ExchangeOnlineManagement | Exchange Online |
| MicrosoftTeams | Teams administration |
| PSReadLine | Enhanced command line |
| Terminal-Icons | File/folder icons in terminal |
| posh-git | Git status in prompt |

## Git Aliases

Configured by `setup/git.ps1`:

| Alias | Command |
|-------|---------|
| `git st` | `status` |
| `git co` | `checkout` |
| `git br` | `branch` |
| `git cm` | `commit -m` |
| `git lg` | `log --oneline --graph --decorate` |
| `git last` | `log -1 HEAD` |
| `git unstage` | `reset HEAD --` |
| `git undo` | `reset --soft HEAD~1` |

## OhMyPosh Themes

The OhMyPosh setup (`setup/ohmyposh.ps1`) lets you choose from these themes:

1. **kushal** - Clean minimal theme with git status
2. **night-owl** - Night Owl color scheme
3. **pixelrobots** - Pixel robots themed prompt
4. **cloud-native-azure** - Azure/Kubernetes focused
5. **cloud-context** - Multi-cloud context aware
6. **froczh** - Colorful powerline style

Run with `-ShowPreviews` to open theme screenshots in your browser.

## Custom Functions

Add these to your profile from `config/functions.ps1`:

| Function | Description |
|----------|-------------|
| `..` / `...` | Navigate up directories |
| `ll` / `la` | List files (including hidden) |
| `mkcd <dir>` | Create and enter directory |
| `reload` | Reload PowerShell profile |
| `myip` | Get public IP address |
| `ff <name>` | Find files by name |
| `pkill <name>` | Kill process by name |
| `azctx [name]` | List/switch Azure contexts |
| `mggraph` | Connect to Microsoft Graph |
| `tail <file>` | Tail a file (like Unix) |
| `foldersize` | Get folder size |

## Manual Setup

Run individual components:

```powershell
# Clone the repo
git clone https://github.com/dawnofsoap/dotfiles-windows.git
cd dotfiles-windows

# Run everything
.\install.ps1

# Or run specific setups
.\setup\apps.ps1 -Core -IT
.\setup\git.ps1
.\setup\modules.ps1
.\setup\ohmyposh.ps1
```

## Skipping Steps

The main installer supports skipping components:

```powershell
.\install.ps1 -SkipApps        # Skip application installation
.\install.ps1 -SkipGit         # Skip git configuration
.\install.ps1 -SkipModules     # Skip PowerShell modules
.\install.ps1 -SkipOhMyPosh    # Skip OhMyPosh setup
```

## Customization

Edit these files to match your preferences:

| File | What to customize |
|------|-------------------|
| `setup/apps.ps1` | Add/remove applications in each category |
| `setup/modules.ps1` | Add/remove PowerShell modules |
| `setup/ohmyposh.ps1` | Change theme options or default font |
| `setup/git.ps1` | Modify git aliases or defaults |
| `config/functions.ps1` | Add your own PowerShell functions |

## Requirements

- Windows 10/11
- PowerShell 5.1+ (PowerShell 7 will be installed)
- winget (App Installer from Microsoft Store)
- Administrator recommended (required for fonts and RSAT)
