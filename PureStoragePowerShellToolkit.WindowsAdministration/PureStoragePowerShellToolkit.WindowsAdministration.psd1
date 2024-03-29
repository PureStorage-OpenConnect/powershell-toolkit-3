<#
    ===========================================================================
    Created by:   	FlashArray Integrations and Evangelism Team @ Pure Storage
    Organization: 	Pure Storage, Inc.
    Filename:     	PureStoragePowerShellToolkit.WindowsAdministration.psd1
    Copyright:		(c) 2023 Pure Storage, Inc.
    Module Name: 	PureStoragePowerShellToolkit.WindowsAdministration
    Description: 	PowerShell Script Module Manifest (.psd1)
    -------------------------------------------------------------------------
    Disclaimer
     The sample script and documentation are provided AS IS and are not supported by
    the author or the author's employer, unless otherwise agreed in writing. You bear
    all risk relating to the use or performance of the sample script and documentation.
    The author and the author's employer disclaim all express or implied warranties
    (including, without limitation, any warranties of merchantability, title, infringement
    or fitness for a particular purpose). In no event shall the author, the author's employer
    or anyone else involved in the creation, production, or delivery of the scripts be liable
    for any damages whatsoever arising out of the use or performance of the sample script and
    documentation (including, without limitation, damages for loss of business profits,
    business interruption, loss of business information, or other pecuniary loss), even if
    such person has been advised of the possibility of such damages.
    ===========================================================================
#>

@{

# Script module or binary module file associated with this manifest.
RootModule = 'PureStoragePowerShellToolkit.WindowsAdministration.psm1'

# Version number of this module.

ModuleVersion = '3.0.2'

# Supported PSEditions
#CompatiblePSEditions  = @("Desktop", "Core")

# ID used to uniquely identify this module
GUID = '0b8311a9-dcd1-4ca9-9b04-b8b63e006072'

# Author of this module
Author = 'Pure Storage'

# Company or vendor of this module
CompanyName = 'Pure Storage, Inc.'

# Copyright statement for this module
Copyright = '(c) 2023 Pure Storage, Inc. All rights reserved.'

# Description of the functionality provided by this module
Description = 'PowerShell Toolkit for Pure Storage Flasharray and Initiators.'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '5.1'

# Name of the Windows PowerShell host required by this module
PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
DotNetFrameworkVersion = '4.5'

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
CLRVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @(
    @{
        ModuleName = 'PureStoragePowerShellToolkit.FlashArray'
        ModuleVersion = '3.0.1'
    }
)

# Assemblies that must be loaded prior to importing this module
RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
#NestedModules = @('Show-ModuleLoadBanner.ps1')

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = @(
    'Get-Pfa2HostBusAdapter',
    'Get-Pfa2SerialNumbers',
    'Get-Pfa2QuickFixEngineering',
    'Get-Pfa2VolumeShadowCopy',
    'Get-Pfa2WindowsDiagnosticInfo',
    'Get-Pfa2MPIODiskLBPolicy',
    'Set-Pfa2MPIODiskLBPolicy',
    'Set-Pfa2TlsVersions',
    'Set-Pfa2WindowsPowerScheme',
    'New-Pfa2VolumeShadowCopy',
    'Enable-Pfa2SecureChannelProtocol',
    'Disable-Pfa2SecureChannelProtocol',
    'Mount-Pfa2HostVolumes',
    'Dismount-Pfa2HostVolumes',
    'Update-Pfa2DriveInformation',
    'Test-Pfa2WindowsBestPractices',
    'New-Pfa2HypervClusterVolumeReport'
)

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = @()

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = @()

# DSC resources to export from this module
DscResourcesToExport = @()

# List of all modules packaged with this module
ModuleList = @()

# List of all files packaged with this module
FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @('PureStorage', 'PowerShell', 'FlashArray')

        # A URL to the license for this module.
        LicenseUri = "https://github.com/PureStorage-OpenConnect/PowerShell-Toolkit/blob/dev/LICENSE"

        # A URL to the main website for this project.
        ProjectUri = "https://github.com/PureStorage-OpenConnect/PowerShell-Toolkit"

        # A URL to an icon representing this module.
        IconUri = "https://github.com/PureStorage-OpenConnect/PowerShell-Toolkit/blob/dev/Installer/icon.ico"

        # ReleaseNotes of this module
        ReleaseNotes = "https://github.com/PureStorage-OpenConnect/powershell-toolkit/dev/main/CHANGELOG.md"

        # External dependent modules of this module
        # ExternalModuleDependencies = ''

        # If true, the LicenseUrl points to an end-user license (not just a source license) which requires the user agreement before use.
        # RequireLicenseAcceptance = ""

        # Indicates this is a pre-release/testing version of the module.
        #Prerelease = 'True'

    } # End of PSData hashtable

 } # End of PrivateData hashtable

# HelpInfo URI of this module
HelpInfoURI = 'http://connect.pure1.purestorage.com/powershell/PureStoragePowerShellSDK2/2.16'

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
DefaultCommandPrefix = ''

}

