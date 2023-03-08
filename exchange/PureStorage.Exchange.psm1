#Requires -Version 5.1
#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

# Requires Exchange module
$exch_snapin = 'Microsoft.Exchange.Management.PowerShell.SnapIn'
if (-not (Get-PSSnapin -Name $exch_snapin -ea SilentlyContinue)) {
    throw "Exchange snap-in '$exch_snapin' not found. Add snap-in to the current session."
}

# Core functions
$script:backupNameFormat = 'MM_dd_yyyy__HHmm_ss'
$script:supportedBusTypes = @('iSCSI', 'Fibre Channel')

. .\Exchange.Core.ps1

# Get
. .\Get-ExchBackup.ps1

# Create
. .\New-ExchBackup.ps1

# Remove
. .\Remove-ExchBackup.ps1

# Restore
. .\Restore-ExchBackup.ps1

# Expose
. .\Expose-ExchBackup.ps1

# Declare exports
Export-ModuleMember -Function Get-ExchBackup
Export-ModuleMember -Function New-ExchBackup
Export-ModuleMember -Function Remove-ExchBackup
Export-ModuleMember -Function Restore-ExchBackup
Export-ModuleMember -Function Expose-ExchBackup