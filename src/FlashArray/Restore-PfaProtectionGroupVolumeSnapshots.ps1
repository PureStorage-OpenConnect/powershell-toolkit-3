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
		[Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][string] $Array,
		[Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][string] $ProtectionGroup,
		[Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][string] $SnapshotName,
		[Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][string] $PGroupPrefix,
		[Parameter(Mandatory = $False)][ValidateNotNullOrEmpty()][string] $Hostname

	)

    $PGroupVolumes = Get-PfaProtectionGroup -Array $Array -Name $ProtectionGroup -Session $Session
    $PGroupSnapshotsSet = $SnapshotName

    ForEach ($PGroupVolume in $PGroupVolumes)
    {
        For($i=0;$i -lt $PGroupVolume.volumes.Count;$i++)
        {
            $NewPGSnapshotVol = ($PGroupVolume.volumes[$i]).Replace($PGroupVolume.source+":",$Prefix+"-")
            $Source = ($PGroupSnapshotsSet+"."+$PGroupVolumes.volumes[$i]).Replace($PGroupVolume.source+":","")
            New-PfaVolume -Array $Array -VolumeName $NewPGSnapshotVol -Source $Source
            New-PfaHostVolumeConnection -Array $array -HostName $Hostname -VolumeName $NewPGSnapshotVol
        }
    }
}