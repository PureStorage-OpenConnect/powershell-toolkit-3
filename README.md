# Pure Storage PowerShell Toolkit 3.0
![GitHub all releases](https://img.shields.io/github/downloads/PureStorage-OpenConnect/powershell-toolkit-3/total?color=orange&label=GitHub%20downloads&logo=powershell&style=plastic) ![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/PureStoragePowerShellToolkit?color=orange&label=PSGallery%20downloads&logo=powershell&style=plastic)
[![PSScriptAnalyzer](https://github.com/PureStorage-OpenConnect/powershell-toolkit-3/actions/workflows/psanalyzer-toolkitcodecheck.yml/badge.svg?branch=main)](https://github.com/PureStorage-OpenConnect/powershell-toolkit-3/actions/workflows/psanalyzer-toolkitcodecheck.yml)

The Pure Storage PowerShell Toolkit 3.0 is a new beginning for the Toolkit. The original version was released in 2016 and was based on older versions of the Pure Storage PowerShell SDK 1.x release. The Toolkit provides useful cmdlets for customers and the Pure Storage Field Support to use in troubleshooting, monitoring, reporting, best practices, and configuration. The PowerShell Toolkit leverages the Pure Storage PowerShell SDK 2.16 for some of the cmdlets. All references to the PowerShell SDK 1.x have been removed. 

The new release includes:
- Separate modules for specific functionality: Database Tools, Windows Administration, FlashArray and Exchange
- Update from SDK 1.x --> 2.16
- Improved error handling
- Updated Get-Help

### Release History
- [PowerShell Toolkit 3.0.1](https://github.com/PureStorage-OpenConnect/powershell-toolkit-3/releases/latest) - June 28, 2023

### Release Compatibility
- This release requires PowerShell 5.1 or higher.
- This release requires .NET 4.5 minimum.
- This release is compatible with the PowerShell SDK 2.16.12.0.
- Database Tools module is compatible with dbatools 1.0.173.
- This release requires a 64-bit operating system.

### Install and Uninstall
The very latest versions of the Toolkit are always available in this repository and in the PowerShell Gallery. There may be multiple branches that may contain alpha or beta code. The default "main" branch contains "stable" code. The Pure Storage PowerShell Toolkit is also distrbuted through the [PowerShell Gallery](https://www.powershellgallery.com/packages/PureStoragePowerShellToolkit).

The tookit requires the PureStoragePowerShellSDK2 module by default for any functions that connect to a FlashArray. Other modules are also used for further functionaility with SQL Server, Excel output, etc. A built-in global function will attempt to download and install them if they are not present when the cmdlet is launched.

- [Pure Storage PowerShell SDK 2.16](https://www.powershellgallery.com/packages/PureStoragePowerShellSDK2/) (Required)
- [dbatools 1.0.173](https://www.powershellgallery.com/packages/dbatools/1.0.173) (Required to use Database Tools module)

To install the Pure Storage PowerShell Toolkit, open up an elevated Windows PowerShell session and type:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-Module -Name PureStoragePowerShellToolkit
```

To verify the installation:

```powershell
Get-Module -Name PureStoragePowerShellToolkit
```

To see the available cmdlets:

```powershell
Get-Command -Module PureStoragePowerShellToolkit
```

To uninstall the module:

```powershell
Uninstall-Module -Module PureStoragePowerShellToolkit
```

### Please contribute!!
We welcome Pull Requests, issues, and open discussions around the toolkit. Help make the toolkit an invaluable tool!




### Pure/Code()
[Join the Pure Storage Code Slack team](https://codeinvite.purestorage.com)
