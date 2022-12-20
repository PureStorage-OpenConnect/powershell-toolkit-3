function New-FlashArrayPGroupVolumes() {
    <#
    .SYNOPSIS
    Creates volumes to a new FlashArray Protection Group (PGroup).
    .DESCRIPTION
    This cmdlet will allow for the creation of multiple volumes and adding the created volumes to a new Protection Group (PGroup). The new volume names will default to "$PGroupPrefix-vol1", "PGroupPrefix-vol2" etc.
    .PARAMETER PGroupPrefix
    Required. The name of the Protection Group prefix to add volumes to. This parameter specifies the prefix of the PGroup name. The suffix defaults to "-PGroup". Example: -PGroupPrefix "database". The full PGroup name will be "database-PGroup".
    This PGroup will be created as new and must not already exist on the array.
    This prefix will also be used to uniquely name the volumes as they are created.
    .PARAMETER VolumeSizeGB
    Required. The size of the new volumes in Gigabytes (GB).
    .PARAMETER NumberOfVolumes
    Required. The number of volumes that are to be created. Each volume will be named "vol" with an ascending number following (ie. vol1, vol2, etc.). Each volume name will also contain the $PGroupPrefix variable as the name prefix.
    .INPUTS
    None
    .OUTPUTS
    None
    .EXAMPLE
    New-FlashArrayPGroupVolumes -PGroupPrefix "database" -VolumeSizeGB "200" -NumberOfVolumes "3"

    Creates 3-200GB volumes, named "database-vol1", "database-vol2", and "database-vol3". Each volume is added to the new Protection Group "database-PGroup".
    .NOTES
    This cmdlet can utilize the global $Creds variable for FlashArray authentication. Set the variable $Creds by using the command $Creds = Get-Credential.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, Mandatory = $True, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][string] $EndPoint,
        [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][string] $PGroupPrefix,
        [Parameter(Mandatory = $True)][ValidateRange(1, [int]::MaxValue)][int] $VolumeSizeGB,
        [Parameter(Mandatory = $True)][ValidateRange(1, [int]::MaxValue)][int] $NumberOfVolumes,
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
        $volumes = ( 1..$NumberOfVolumes ) |
        foreach { "$PGroupPrefix-Vol$_" } |
        New-Pfa2Volume -Array $FlashArray -Provisioned ($VolumeSizeGB * 1GB)

        $group = New-Pfa2ProtectionGroup -Array $FlashArray -Name "$PGroupPrefix-PGroup"

        New-Pfa2ProtectionGroupVolume -Array $FlashArray -MemberNames $volumes.name -GroupNames $group.Name
    }
    finally {
        Disconnect-Pfa2Array -Array $flashArray
    }
}