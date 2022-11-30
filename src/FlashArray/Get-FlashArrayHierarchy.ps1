Function Get-FlashArrayHierarchy() {
    <#
    .SYNOPSIS
    Displays array hierarchy in relation to hosts and/or volumes.
    .DESCRIPTION
    This cmdlet will display the hierarchy from a FlashArray of hosts and volumes. The output is to the console in text.
    .PARAMETER EndPoint
    Required. FQDN or IP address of the FlashArray.
    .INPUTS
    None
    .OUTPUTS
    FlashArray host and/or volume hierarchy.
    .EXAMPLE
    Get-FlashArrayHierarchy -EndPoint myArray

    .NOTES
    This cmdlet can utilize the global credential variable for FlashArray authentication. Set the credential variable by using the command Set-PfaCredential.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $EndPoint,
        [Parameter(ValueFromPipelineByPropertyName)]
        [pscredential]$Credential = ( Get-PfaCredential )
    )

    # Connect to FlashArray
    try {
        $FlashArray = Connect-Pfa2Array -Endpoint $EndPoint -Credential $Credential -IgnoreCertificateError
    }
    catch {
        $ExceptionMessage = $_.Exception.Message
        Write-Error "Failed to connect to FlashArray endpoint $Endpoint with: $ExceptionMessage"
        Return
    }

    try {
        Write-Host ''
        Write-Host 'Please indicate if you would like to see the hierarchy by host.' -ForegroundColor Cyan
        Write-Host 'This process will take a couple minutes, but is useful to find disconnected hosts or hosts with no replication group.' -ForegroundColor Cyan
        Write-Host 'Otherwise, the hierarchy will be shown at the volume level.' -ForegroundColor Cyan
        Write-Host ''
        $ByHost = Read-Host -Prompt 'Do you want to view hierarchy by individual hosts? (Y/N)'

        Write-Host ''
        Write-Host '================================================================'
        Write-Host "                    $EndPoint Hierarchy"
        Write-Host '================================================================'
        #If else statement to control hierarchy displayed by host or by volume
        If ($ByHost -eq 'Y' -or $ByHost -eq 'y') {
            $Initiators = Get-Pfa2Host -Array $FlashArray

            #Start at host level
            ForEach ($Initiator in $Initiators) {
                Write-Host "[H] $($Initiator.name)"

                $Volumes = Get-Pfa2Connection -Array $FlashArray -HostNames $Initiator.name | 
                select -expand Volume | 
                where Name -NE 'pure-protocol-endpoint'

                If (!$Volumes) {
                    Write-Host '  [No volumes connected]' -ForegroundColor Yellow
                }
                Else {

                    #Start at volume level
                    ForEach ($Volume in $Volumes) {

                        #Reset variables
                        $Snapshots = @(Get-Pfa2VolumeSnapshot -Array $FlashArray -Name $Volume.name)
                        $SpaceConsumed = 0

                        #Change value for snapshot count threshold
                        If ($Snapshots.Count -eq 0) {
                            Write-Host "  [V] $($Volume.name)" -ForegroundColor Yellow
                            Write-Host '    There are no associated snapshots with this volume.' -ForegroundColor Red
                        }
                        Else {
                            Write-Host "  [V] $($Volume.name)" -ForegroundColor Green
                        }

                        #Change value for snapshot count threshold
                        ForEach ($Snapshot in $Snapshots) {
                            If ($Snapshots.Count -gt 1) {
                                Write-Host "    [S] $($Snapshot.name)" -ForegroundColor Yellow
                            }
                            Else {
                                Write-Host "    [S] $($Snapshot.name)" -ForegroundColor Green
                            }

                            #Space consumed computation for each volume
                            $SpaceConsumed = $SpaceConsumed + $Snapshot.TotalPhysical
                        }

                        #Display space consumed if snapshot count exceeds threshold
                        If ($Snapshots.Count -gt 1) {
                            Write-Host  "    There are $($Snapshots.Count) snapshots associated with this volume consuming a total of $([math]::Round($SpaceConsumed/1GB,2)) GB on the array."
                        }
                    }
                }
            }
        }
        #If user does not want hierarchy at host level
        Else {
            $Volumes = Get-Pfa2Volume -Array $FlashArray | where Name -NE 'pure-protocol-endpoint'

            #Start volume level
            ForEach ($Volume in $Volumes) {

                #Reset variables
                $Snapshots = @(Get-Pfa2VolumeSnapshot -Array $FlashArray -Name $Volume.name)
                $SpaceConsumed = 0

                #Change value for snapshot count threshold
                If ($Snapshots.Count -eq 0) {
                    Write-Host "[V] $($Volume.name)" -ForegroundColor Yellow
                    Write-Host '  There are no associated snapshots with this volume.' -ForegroundColor Red
                }
                Else {
                    Write-Host "[V] $($Volume.name)" -ForegroundColor Green
                }

                #Change value for snapshot count threshold
                ForEach ($Snapshot in $Snapshots) {
                    If ($Snapshots.Count -gt 1) {
                        Write-Host "  [S] $($Snapshot.name)" -ForegroundColor Yellow
                    }
                    Else {
                        Write-Host "  [S] $($Snapshot.name)" -ForegroundColor Green
                    }

                    #Space consumed computation for each volume
                    $SpaceConsumed = $SpaceConsumed + $Snapshot.TotalPhysical
                }

                #Display space consumed if snapshot count threshold is exceeded
                If ($Snapshots.Count -gt 1) {
                    Write-Host  "  There are $($Snapshots.Count) snapshots associated with this volume consuming a total of $([math]::Round($SpaceConsumed/1GB,2)) GB on the array."
                }
            }
        }
    }
    finally {
        Disconnect-Pfa2Array -Array $FlashArray
    }
}
