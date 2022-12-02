function Update-DriveInformation() {
    <#
    .SYNOPSIS
    Updates drive letters and assigns a label.
    .DESCRIPTION
    Thsi cmdlet will update the current drive letter to the new drive letter, and assign a new drive label if specified.
    .PARAMETER NewDriveLetter
    Required. Drive lettwre without the colon.
    .PARAMETER CurrentDriveLetter
    Required. Drive lettwre without the colon.
    .PARAMETER NewDriveLabel
    Optional. Drive label text. Defaults to "NewDrive".
    .PARAMETER CimSession
    Optional. A CimSession or computer name.
    .INPUTS
    None
    .OUTPUTS
    None
    .EXAMPLE
    Update-DriveInformation -NewDriveLetter S -CurrentDriveLetter M

    Updates the drive letter from M: to S: and labels S: to NewDrive.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [Parameter(Mandatory = $True)][string]$NewDriveLetter,
        [Parameter(Mandatory = $True)][string]$CurrentDriveLetter,
        [Parameter(Mandatory = $False)][string]$NewDriveLabel = 'NewDrive',
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [CimSession]$CimSession
    )

    $params = @{
        Query    = "SELECT * FROM Win32_Volume WHERE DriveLetter = '$CurrentDriveLetter`:"
        Property = @{ DriveLetter = "$($NewDriveLetter):" }
    }

    if ($NewDriveLabel) {
        $params.Property.Add('Label', $NewDriveLabel)
    }

    if ($PSBoundParameters.ContainsKey('CimSession')) {
        $params.Add('CimSession', $CimSession)
    }

    Set-CimInstance @params | Out-Null
}
