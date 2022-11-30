function Get-AllHostVolumeInfo() {
    <#
    .SYNOPSIS
    Retrieves Host Volume information from FlashArray.
    .DESCRIPTION
    Retrieves Host Volume information including volumes attributes from a FlashArray.
    .INPUTS
    EndPoint IP or FQDN required
    .OUTPUTS
    Outputs Host volume information
    .EXAMPLE
    Get-HostVolumeinfo -EndPoint myarray.mydomain.com

    Retrieves Host Volume information from the FlashArray myarray.mydomain.com.
    .NOTES
    This cmdlet can utilize the global credentials variable for FlashArray authentication. Set the credential variable by using the command Set-PfaCredential.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][string] $EndPoint,
        [Parameter()]
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
        Get-Pfa2Connection -Array $flashArray -PipelineVariable c |
        foreach { Get-Pfa2Volume -Array $flashArray -Name $_.Volume.Name } |
        foreach { [pscustomobject]@{
                Host          = $c.Host.Name; 
                'Volume Name' = $_.Name; 
                Created       = $_.Created; 
                Source        = $_.Source; 
                Serial        = $_.Serial; 
                'Size (GB)'   = $_.Space.TotalProvisioned / 1GB 
            } } |
        Sort-Object -Property 'Host' |
        Format-Table -AutoSize
    }
    finally {
        Disconnect-Pfa2Array -Array $flashArray
    }
}
