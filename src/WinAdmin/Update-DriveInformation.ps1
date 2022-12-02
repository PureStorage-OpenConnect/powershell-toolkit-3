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
    .INPUTS
    None
    .OUTPUTS
    None
    .EXAMPLE
    Update-DriveInformation -NewDriveLetter S -CurrentDriveLetter M

    Updates the drive letter from M: to S: and labels S: to NewDrive.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)][string]$NewDriveLetter,
        [Parameter(Mandatory = $True)][string]$CurrentDriveLetter,
        [Parameter(Mandatory = $False)][string]$NewDriveLabel = "NewDrive"
        )

    $Drive = Get-WmiObject -Class Win32_Volume | Where-Object { $_.DriveLetter -eq "$($CurrentDriveLetter):" }
    if (!($NewDriveLabel)) {
        Set-WmiInstance -Input $Drive -Arguments @{ DriveLetter = "$($NewDriveLetter):" } | Out-Null
    }
    else {
        Set-WmiInstance -Input $Drive -Arguments @{ DriveLetter = "$($NewDriveLetter):"; Label = "$($NewDriveLabel)" } | Out-Null
    }
}