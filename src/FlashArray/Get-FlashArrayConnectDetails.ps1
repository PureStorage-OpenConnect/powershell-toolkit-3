function Get-FlashArrayConnectDetails() {
    <#
    .SYNOPSIS
    Outputs FlashArray connection details.
    .DESCRIPTION
    Output FlashArray connection details including Host and Volume names, LUN ID, IQN / WWN, Volume Provisioned Size, and Host Capacity Written.
    .PARAMETER EndPoint
    Required. FlashArray IP address or FQDN.
    .INPUTS
    None
    .OUTPUTS
    Formatted output details from Get-Pfa2Connection
    .EXAMPLE
    Get-FlashArrayConnectDetails.ps1 -EndPoint myArray
    .NOTES
    This cmdlet does not allow for use of OAUth authentication, only token authentication. Arrays with maximum API versions of 2.0 or 2.1 must use OAuth authentication. This will be added in a later revision.
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
        $flashArray = Connect-Pfa2Array -Endpoint $EndPoint -Credential $Credential -IgnoreCertificateError
    }
    catch {
        $exceptionMessage = $_.Exception.Message
        Write-Error "Failed to connect to FlashArray endpoint $Endpoint with: $exceptionMessage"
        Return
    }

    try {
        # Create an object to store the connection details
        $connDetails = New-Object -TypeName System.Collections.ArrayList
        $header = 'HostName', 'VolumeName', 'LUNID', 'IQNs', 'WWNs', 'Provisioned(TB)', 'HostWritten(GB)'

        # Get Connections and filter out VVOL protocol endpoints
        $pureConns = (Get-Pfa2Connection -Array $flashArray | Where-Object { !($_.Volume.Name -eq 'pure-protocol-endpoint') })

        # For each Connection, build a row with the desired values from Connection, Host, and Volume objects. Add it to ConnDetails.
        ForEach ($pureConn in $PureConns) {
            $pureHost = (Get-Pfa2Host -Array $flashArray | Where-Object { $_.Name -eq $PureConn.Host.Name })
            $pureVol = (Get-Pfa2Volume -Array $flashArray | Where-Object { $_.Name -eq $PureConn.Volume.Name })

            # Calculate and format Host Written Capacity, Volume Provisioned Capacity
            $hostWrittenCapacity = [Math]::Round(($pureVol.Provisioned * (1 - $PureVol.Space.ThinProvisioning)) / 1GB, 2)
            $volumeProvisionedCapacity = [Math]::Round(($pureVol.Provisioned ) / 1TB, 2)

            $newRow = "$($pureHost.Name),$($PureVol.Name),$($PureConn.Lun),$($PureHost.Iqns),$($PureHost.Wwns),"
            $newRow += "$($volumeProvisionedCapacity),$($hostWrittenCapacity)"
            [void]$connDetails.Add($newRow)
        }

        # Print ConnDetails and make it look nice
        $connDetails | ConvertFrom-Csv -Header $header | Sort-Object HostName | Format-Table -AutoSize
    }
    finally {
        Disconnect-Pfa2Array -Array $flashArray
    }
}
