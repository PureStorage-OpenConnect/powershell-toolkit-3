function New-VolumeShadowCopy() {
    <#
    .SYNOPSIS
    Creates a new volume shadow copy using Diskshadow.
    .DESCRIPTION
    This cmdlet will create a new volume shadow copy using the Diskshadow command, passing the variables specified.
    .PARAMETER Volume
    Required.
    .PARAMETER Scriptname
    Optional. Script text file name created to pass to the Diskshadow command. Pre-defined as 'PUREVSS-SNAP'.
    .PARAMETER ShadowCopyAlias
    Required. Name of the shadow copy alias.
    .PARAMETER VerboseMode
    Optional. "On" or "Off". If set to 'off', verbose mode for the Diskshadow command is disabled. Default is 'on'.
    .INPUTS
    None
    .OUTPUTS
    None
    .EXAMPLE
    New-VolumeShadowCopy -Volume Volume01 -ShadowCopyAlias MyAlias

    Adds a new volume shadow copy of Volume01 using Diskshadow with an alias of 'MyAlias'.

    .NOTES
    See https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/diskshadow for more information on the Diskshadow utility.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)][string[]]$Volume,
        [Parameter(Mandatory = $False)][string]$ScriptName = "PUREVSS-SNAP",
        [Parameter(Mandatory = $True)][string]$ShadowCopyAlias,
        [ValidateSet("On", "Off")][string]$VerboseMode = "On"
    )

    $dsh = "./$ScriptName.PFA"

    foreach ($Vol in $Volume) {
        "ADD VOLUME $Vol ALIAS $ShadowCopyAlias PROVIDER {781c006a-5829-4a25-81e3-d5e43bd005ab}"
    }
    'RESET',
    'SET CONTEXT PERSISTENT',
    'SET OPTION TRANSPORTABLE',
    "SET VERBOSE $VerboseMode",
    'BEGIN BACKUP',
    "ADD VOLUME $Volume ALIAS $ShadowCopyAlias PROVIDER {781c006a-5829-4a25-81e3-d5e43bd005ab}",
    'CREATE',
    'END BACKUP' | Set-Content $dsh
    DISKSHADOW /s $dsh
    Remove-Item $dsh
}