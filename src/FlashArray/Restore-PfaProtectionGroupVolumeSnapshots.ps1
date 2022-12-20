function Restore-PfaPGroupVolumeSnapshots() {
    <#
    .SYNOPSIS
    Recover all of the volumes from a protection group (PGroup) snapshot.
    .DESCRIPTION
    This cmdlet will recover all of the volumes from a protection group (PGroup) snapshot in one operation.
    .PARAMETER ProtectionGroup
    Required. The name of the Protection Group.
    .PARAMETER SnapshotName
    Required. The name of the snapshot.
    .PARAMETER PGroupPrefix
    Required. The name of the Protection Group prefix.
    .PARAMETER Hostname
    Optional. The hostname to attach the snapshots to.
    .INPUTS
    None
    .OUTPUTS
    None
    .EXAMPLE

    Restore-PfaPGroupVolumeSnapshots –Array $array –ProtectionGroup "VOL1-PGroup" –SnapshotName "VOL1-PGroup.001" –Prefix TEST -Hostname HOST1

    Restores protection group snapshots named "VOL1-PGroup.001" from PGroup "VOL1-PGroup", adds the prefix of "TEST" to the name, and attaches them to the host "HOST1" on array $array.
    .NOTES
    This cmdlet can utilize the global $Creds variable for FlashArray authentication. Set the variable $Creds by using the command $Creds = Get-Credential.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][string] $EndPoint,
        [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][string] $ProtectionGroup,
        [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][string] $SnapshotName,
        [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][string] $Prefix,
        [Parameter(Mandatory = $False)][ValidateNotNullOrEmpty()][string] $Hostname,
        [Parameter(ValueFromPipelineByPropertyName)]
        [pscredential]$Credential = ( Get-PfaCredential )
    )

    # Connect to FlashArray
    try {
        $flashArray = Connect-Pfa2Array -Endpoint $EndPoint -Credential $Credential -IgnoreCertificateError
    }
    catch {
        $ExceptionMessage = $_.Exception.Message
        Write-Error "Failed to connect to FlashArray endpoint $Endpoint with: $ExceptionMessage"
        Return
    }

    try {
        $groups = Get-Pfa2ProtectionGroup -Array $flashArray -Name $ProtectionGroup
        foreach ($group in $groups) {
            $volumes = Get-Pfa2ProtectionGroupVolume -Array $connection -GroupNames $group.Name | select -ExpandProperty 'Member'
            foreach ($volume in $volumes) {
                $name = $volume.Name.Replace($group.Source.Name + '::', '')
                $volumeName = "$Prefix-$name"
                $source = "$SnapshotName.$name"
                New-Pfa2Volume -Array $flashArray -Name $volumeName -SourceName $source
                if ($Hostname) {
                    New-Pfa2Connection -Array $flashArray -HostNames $Hostname -VolumeNames $volumeName
                }
            }
        }
    }
    finally {
        Disconnect-Pfa2Array -Array $flashArray
    }
}
