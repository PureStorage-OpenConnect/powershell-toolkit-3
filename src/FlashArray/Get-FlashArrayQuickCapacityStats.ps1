function Get-FlashArrayQuickCapacityStats() {
    <#
    .SYNOPSIS
    Quick way to retrieve FlashArray capacity statistics.
    .DESCRIPTION
    Retrieves high level capcity statistics from a FlashArray.
    .PARAMETER Arrays
    Required. A single endpoint or array of endpoints, comma seperated, of arrays to show acapacity information.
    .INPUTS
    Single or multiple FlashArray IP addresses or FQDNs.
    .OUTPUTS
    Outputs array capacity information
    .EXAMPLE
    Get-FlashArrayQuickCapacityStats -Arrays 'array1, array2'

    Retrieves capacity statistic information from FlashArray's array1 and array2.
    .NOTES
    The arrays supplied in the "Arrays" parameter must use the same credentials for access.

    This cmdlet can utilize the global $Creds variable for FlashArray authentication. Set the variable $Creds by using the command $Creds = Get-Credential.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][string[]] $Arrays
    )

    # Get credentials for all endpoints
    $cred = Get-Creds

    # Connect to FlashArray(s)
    $connections = @()
    foreach ($Array in $Arrays) {
        try {
            $flashArray = Connect-Pfa2Array -Endpoint $Array -Credential $cred -IgnoreCertificateError
            $connections += $flashArray
        }
        catch {
            $exceptionMessage = $_.Exception.Message
            Write-Error "Failed to connect to FlashArray endpoint $Array with: $exceptionMessage"
            Return
        }
    }

    try {
        $spacemetrics = $connections | foreach { Get-Pfa2ArraySpace -Array $_ } | select -Property 'Capacity' -ExpandProperty 'Space'
        $spacemetrics = @($spacemetrics | Select-Object *, @{N = 'expvolumes'; E = { $_.Unique * $_.DataReduction } }, @{N = 'provisioned'; E = { ($_.TotalPhysical - $_.System) / (1 - $_.ThinProvisioning) * $_.DataReduction } })

        $totalcapacity = ($spacemetrics | Measure-Object Capacity -Sum).Sum
        $totalvolumes = ($spacemetrics | Measure-Object Unique -Sum).Sum
        $totalvolumes_beforereduction = ($spacemetrics | Measure-Object expvolumes -Sum).Sum
        $totalprovisioned = ($spacemetrics | Measure-Object provisioned -Sum).Sum

        Write-Host "On $($spacemetrics.Count) Pure FlashArrays, there is $([int]($totalcapacity/1TB)) TB of capacity; $([int]($totalvolumes/1TB)) TB written, reduced from $([int]($totalvolumes_beforereduction/1TB)) TB. Total provisioned: $([int]($totalprovisioned/1TB)) TB."
        Write-Host "Data collected on $(Get-Date)"
    }
    finally {
        Disconnect-Pfa2Array -Array $flashArray
    }
}
