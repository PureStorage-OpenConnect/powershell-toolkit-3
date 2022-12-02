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
        [Parameter(Position = 0, Mandatory = $True)][ValidateNotNullOrEmpty()][string] $EndPoint
    )
    Get-Sdk1Module
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

    While ($true) {
        If ((Get-PfaRemoteAssistSession -Array $FlashArray).Status -eq 'disabled') {
            Set-PfaRemoteAssistStatus -Array $FlashArray -Action connect
        }
        else {
            Write-Warning "Remote Assist session is not active."
            Start-Sleep 30
        }
    }
}