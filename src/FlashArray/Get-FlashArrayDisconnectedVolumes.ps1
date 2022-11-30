function Get-FlashArrayDisconnectedVolumes() {
    <#
    .SYNOPSIS
    Retrieves disconnected volume information for a FlashArray.
    .DESCRIPTION
    This cmdlet will retrieve information for volumes that are ina disconnected state for a FlashArray.
    .PARAMETER EndPoint
    Required. FQDN or IP address of the FlashArray.
    .INPUTS
    None
    .OUTPUTS
    Disconnected volume information is displayed.
    .EXAMPLE
    Get-FlashArrayDisconnectedVolumes -EndPoint myArray
    .NOTES
    This cmdlet can utilize the global credential variable for FlashArray authentication. Set the credential variable by using the command Get-PfaCredential.
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
        $flashArray = Connect-Pfa2Array -Endpoint $EndPoint -Credential $Credential -IgnoreCertificateError
    }
    catch {
        $exceptionMessage = $_.Exception.Message
        Write-Error "Failed to connect to FlashArray endpoint $Endpoint with: $exceptionMessage"
        Return
    }

    try {
        $faSpace = Get-Pfa2ArraySpace -Array $flashArray

        $allVolumes = @(Get-Pfa2Volume -Array $flashArray | select -Expand Name)
        $connectedVolumes = @(Get-Pfa2Connection -Array $flashArray | select -Expand Volume | select -Expand Name -Unique)
        $disconnectedVolumes = @($allVolumes | where { $_ -notin $connectedVolumes })

        Write-Output ''
        Write-Output "`t$($EndPoint) - $([math]::Round((($faSpace.Space.TotalPhysical)/1TB),2)) TB/$([math]::Round($(($faSpace.capacity)/1TB),2)) TB ($([math]::Round((($faSpace.Space.TotalPhysical)*100)/$($faSpace.capacity),2))% Full)`n"
        Write-Output '==================================================='
        Write-Output "`t`t Disconnected Volumes ($($disconnectedVolumes.Count) of $($allVolumes.Count))"
        Write-Output '==================================================='

        #If the array has a disconnected volume, gather volume space metrics
        if (($disconnectedVolumes.Count) -gt 0 ) {
            foreach ($disconnectedVolume in $DisconnectedVolumes) {
                if ($null -ne $disconnectedVolume) {
                    $volDetails = Get-Pfa2VolumeSpace -Array $flashArray -Name $disconnectedVolume
                    $getVol = Get-Pfa2Volume -Array $flashArray -Name $disconnectedVolume
                    $space = ($($volDetails.Unique / 1GB))
                    $space = [math]::Round($Space, 3)
                    $total = [math]::Round(($($volDetails.TotalProvisioned / 1TB)), 3)
                    $reduction = $volDetails.DataReduction
                    $reduction = [math]::Round($Reduction, 0)
                    Write-Output "$($disconnectedVolume) `n`t $($getVol.serial) `n`t $($space) GB Consumed `n`t $($total) TB Provisioned `n`t $($reduction):1 Reduction `n" | Format-List
                    $potentialSpaceSavings = $PotentialSpaceSavings + $($volDetails.Unique / 1GB)
                }
            }
            Write-Output "Potential space savings for $($EndPoint) is $([math]::Round($potentialSpaceSavings,3)) GB."
        }
        else {
            Write-Output 'No Disconnected Volumes found.'
        }
    }
    finally {
        Disconnect-Pfa2Array -Array $flashArray
    }
}
