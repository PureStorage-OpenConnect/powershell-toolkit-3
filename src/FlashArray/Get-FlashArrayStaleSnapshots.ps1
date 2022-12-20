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

    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [Parameter(Position = 0, Mandatory = $True, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][string] $EndPoint,
        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()][decimal] $SnapAgeThreshold,
        [switch]$Delete,
        [switch]$Eradicate,
        [Parameter(ValueFromPipelineByPropertyName)]
        [pscredential]$Credential = ( Get-PfaCredential )
    )

    # Establish variables, Pure time format, and gather current time.
    $CurrentTime = Get-Date

    # Connect to FlashArray
    try {
        $flashArray = Connect-Pfa2Array -Endpoint $EndPoint -Credential $Credential -IgnoreCertificateError
    }
    catch {
        $ExceptionMessage = $_.Exception.Message
        Write-Error "Failed to connect to FlashArray endpoint $Endpoint with: $ExceptionMessage"
        Return
    }

    # Establish and reset counter variables.
    $Timespan = $null
    [decimal]$SpaceConsumed = 0
    [int]$SnapNumber = 0

    try {
        $Snapshots = Get-Pfa2VolumeSnapshot -Array $FlashArray

        Write-Host ''
        Write-Host '========================================================================='
        Write-Host "      $EndPoint                               "
        Write-Host '========================================================================='

        #Get all snapshots and compute the age of them. $DateTimeFormat variable taken from above; this is needed in order to parse Pure time format.
        foreach ($Snapshot in $Snapshots) {
            $Timespan = New-TimeSpan -Start $Snapshot.created -End $CurrentTime
            $SnapAge = $Timespan.TotalDays

            #Find snaps older than given threshold and output with formatted data.
            if ($SnapAge -gt $SnapAgeThreshold) {
                $SnapSize = [math]::round([decimal]$Snapshot.Space.TotalPhysical / 1GB, 2)
                $SpaceConsumed = $SpaceConsumed + $SnapSize
                $SnapNumber++

                #Delete snapshots
                if ($Delete -and $Eradicate) {
                    Remove-Pfa2VolumeSnapshot -Array $FlashArray -Name $Snapshot.name -Eradicate
                    Write-Host "Eradicating $($Snapshot.name) - $($SnapSize) GB."
                }
                elseif ($Delete) {
                    Remove-Pfa2VolumeSnapshot -Array $FlashArray -Name $Snapshot.name
                    Write-Host "Deleting $($Snapshot.name) - $($SnapSize) GB."
                }
                else {
                    Write-Host $Snapshot.name
                    Write-Host "          $SnapSize GB"
                    "          {0:N2} days" -f $SnapAge | Write-Host
                }
            }
        }
    }
    finally {
        Disconnect-Pfa2Array -Array $flashArray
    }

    #Display final message for array results.
    Write-Host "There are $($SnapNumber) snapshot(s) older than $($SnapAgeThreshold) days consuming a total of $($SpaceConsumed) GB on the array."
}
