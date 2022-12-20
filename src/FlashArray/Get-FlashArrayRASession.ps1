function Get-FlashArrayRASession() {
    <#
    .SYNOPSIS
    Retrieves Remote Assist status from a FlashArray.
    .DESCRIPTION
    Retrieves Remote Assist status from a FlashArray as disabled or enabled in a loop every 30 seconds until stopped.
    .PARAMETER EndPopint
    Required. FlashArray IP address or FQDN.
    .INPUTS
    EndPoint IP or FQDN required.
    .OUTPUTS
    Outputs Remote Assst status.
    .EXAMPLE
    Get-FlashArrayRASession -EndPoint myarray.mydomain.com

    Retrieves the current Remote Assist status and continues check status every 30 seconds until stopped.
    .NOTES
    This cmdlet can utilize the global $Creds variable for FlashArray authentication. Set the variable $Creds by using the command $Creds = Get-Credential.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, Mandatory = $True, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()][string] $EndPoint,
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
        Write-Host 'Testing remote assist connectivity'
        do {
            $test = Get-Pfa2SupportTest -Array $flashArray -TestType 'remote-assist'
            If ($test.Success) {
                Write-Host $test.ResultDetails
            } else {
                Write-Warning $test.ResultDetails
                Start-Sleep 30
            }
        } until ($test.Success)
    }
    finally {
        Disconnect-Pfa2Array -Array $flashArray
    }
}
