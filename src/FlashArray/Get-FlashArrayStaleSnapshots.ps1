function Get-FlashArrayStaleSnapshots() {
    <#
    .SYNOPSIS
    Retrieves aged snapshots and allows for Deletion and Eradication of such snapshots.
    .DESCRIPTION
    This cmdlet will retrieve all snapshots that are beyond the specified SnapAgeThreshold. It allows for the parameters of Delete and Eradicate, and if set to $true, it will delete and eradicate the snapshots returned. It allows for the parameter of Confirm, and if set to $true, it will prompt before deletion and/or eradication of the snapshots.
    Snapshots must be deleted before they can be eradicated.
    .PARAMETER EndPoint
    Required. Endpoint is the FlashArray IP or FQDN.
    .PARAMETER SnapAgeThreshold
    Required. SnapAgeThreshold is the number of days from the current date. Delete. Confirm, and Eradicate are optional.
    .PARAMETER Delete
    Optional. If set to $true, delete the snapshots.
    .PARAMETER Eradicate
    Optional. If set to $true, eradicate the deleted snapshots (snapshot must be flagged as deleted).
    .PARAMETER Confirm
    Optional. If set to $true, provide user confirmation for Deletion or Eradication of the snapshots.
    .OUTPUTS
    Returns a listing of snapshots that are beyond the specified threshold and displays final results.
    .EXAMPLE
    Get-FlashArrayStaleSnapshots -EndPoint myArray -SnapAgeThreshold 30

    Returns all snapshots that are older than 30 days from the current date.

    .EXAMPLE
    Get-FlashArrayStaleSnapshots -EndPoint myArray -SnapAgeThreshold 30 -Delete:$true -Eradicate:$true -Confirm:$false

    Returns all snapshots that are older than 30 days from the current date, deletes and eradicates them without confirmation.
    .NOTES
    This cmdlet can utilize the global $Creds variable for FlashArray authentication. Set the variable $Creds by using the command $Creds = Get-Credential.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, Mandatory = $True)][ValidateNotNullOrEmpty()][string] $EndPoint,
        [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][string] $SnapAgeThreshold,
        [switch]$Delete,
        [switch]$Eradicate,
        [switch]$Confirm
    )
    # Establish variables, Pure time format, and gather current time.
    $1GB = 1024 * 1024 * 1024
    $CurrentTime = Get-Date
    $DateTimeFormat = 'yyyy-MM-ddTHH:mm:ssZ'

    # Connect to FlashArray
    if (!($Creds)) {
        try {
            $FlashArray = New-PfaArray -EndPoint $EndPoint -Credentials (Get-Credential) -IgnoreCertificateError
        }
        catch {
            $ExceptionMessage = $_.Exception.Message
            Write-Error "Failed to connect to FlashArray endpoint $Endpoint with: $ExceptionMessage"
            Return
        }
    }
    else {
        try {
            $FlashArray = New-PfaArray -EndPoint $EndPoint -Credentials $Creds -IgnoreCertificateError
        }
        catch {
            $ExceptionMessage = $_.Exception.Message
            Write-Error "Failed to connect to FlashArray endpoint $Endpoint with: $ExceptionMessage"
            Return
        }
    }

    # Establish and reset counter variables.
    [int]$SpaceConsumedTotal = 0
    [int]$SnapNumberTotal = 0
    $Timespan = $null
    [int]$SpaceConsumed = 0
    [int]$SnapNumber = 0
    try {
        $Snapshots = Get-PfaAllVolumeSnapshots -Array $FlashArray

        Write-Output ""
        Write-Output "========================================================================="
        Write-Output "      $EndPoint                               "
        Write-Output "========================================================================="
    }
    catch {
        Write-Host "Error processing $($EndPoint)."
    }
    #Get all snapshots and compute the age of them. $DateTimeFormat variable taken from above; this is needed in order to parse Pure time format.
    foreach ($Snapshot in $Snapshots) {
        $SnapshotDateTime = $Snapshot.created
        $SnapshotDateTime = [datetime]::ParseExact($SnapshotDateTime, $DateTimeFormat, $null)
        $Timespan = New-TimeSpan -Start $SnapshotDateTime -End $CurrentTime
        $SnapAge = $($Timespan.Days + $($Timespan.Hours / 24) + $($Timespan.Minutes / 1440))
        $SnapAge = [math]::Round($SnapAge, 2)

        #Find snaps older than given threshold and output with formatted data.
        if ($SnapAge -gt $SnapAgeThreshold) {
            $SnapStats = Get-PfaSnapshotSpaceMetrics -Array $FlashArray -Name $Snapshot.name
            $SnapSize = [math]::round($($SnapStats.total / $1GB), 2)
            $SpaceConsumed = $SpaceConsumed + $SnapSize
            $SnapNumber = $SnapNumber + 1

            #Delete snapshots
            if ($Delete -eq $true -and $Eradicate -eq $true) {
                Remove-PfaVolumeOrSnapshot -Array $FlashArray -Name $Snapshot.name -Eradicate -Confirm $Confirm
                Write-Output "Eradicating $($Snapshot.name) - $($SnapSize) GB."
            }
            elseif ($Delete -eq $true) {
                Remove-PfaVolumeOrSnapshot -Array $FlashArray -Name $Snapshot.name -Confirm $Confirm
                Write-Output "Deleting $($Snapshot.name) - $($SnapSize) GB."
            }
            else {
                Write-Output $Snapshot.name
                Write-Output "          $SnapSize GB"
                Write-Output "          $SnapAge days"
            }
        }

    }
    #Display final message for array results.
    Write-Output "There are $($SnapNumber) snapshot(s) older than $($SnapAgeThreshold) days consuming a total of $($SpaceConsumed) GB on the array."

    $SnapNumberTotal = $SnapNumberTotal + $SnapNumber
    $SpaceConsumedTotal = $SpaceConsumedTotal + $SpaceConsumed
}
Write-Output "There are $($SnapNumberTotal) snapshot(s) older than $($SnapAgeThreshold) days consuming a total of $($SpaceConsumedTotal) GB."