function Get-VolumeShadowCopy() {
    <#
    .SYNOPSIS
    Retrieves the volume shadow copy informaion using the Diskhadow command.
    .DESCRIPTION

    .PARAMETER ExposeAs
    Required. Drive letter, share, or mount point to expose the shadow copy.
    .PARAMETER ScriptName
    Optional. Script text file name created to pass to the Diskshadow command. defaults to 'PUREVSS-SNAP'.
    .PARAMETER ShadowCopyAlias
    Required. Name of the shadow copy alias.
    .PARAMETER MetadataFile
    Required. Full filename for the metadata .cab file. It must exist in the current working folder.
    .PARAMETER VerboseMode
    Optional. "On" or "Off". If set to 'off', verbose mode for the Diskshadow command is disabled. Default is 'On'.
    .INPUTS
    None
    .OUTPUTS
    None
    .EXAMPLE
    Get-VolumeShadowCopy -MetadataFile myFile.cab -ShadowCopyAlias MyAlias -ExposeAs MyShadowCopy

    Exposes the MyAias shadow copy as drive latter G: using the myFie.cab metadata file.

    .NOTES
    See https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/diskshadow for more information on the Diskshadow utility.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $False)][string]$ScriptName = "PUREVSS-SNAP",
        [Parameter(Mandatory = $True)][string]$MetadataFile,
        [Parameter(Mandatory = $True)][string]$ShadowCopyAlias,
        [Parameter(Mandatory = $True)][string]$ExposeAs,
        [ValidateSet("On", "Off")][string]$VerboseMode = "On"
    )
    $dsh = "./$ScriptName.PFA"
    "SET VERBOSE $VerboseMode",
    'RESET',
    "LOAD METADATA $MetadataFile.cab",
    'IMPORT',
    "EXPOSE %$ShadowCopyAlias% $ExposeAs",
    'EXIT' | Set-Content $dsh
    DISKSHADOW /s $dsh
    Remove-Item $dsh
}