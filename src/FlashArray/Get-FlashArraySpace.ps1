function Get-FlashArraySpace() {
    <#
    .SYNOPSIS
    Retrieves the space used and available for a FlashArray.
    .DESCRIPTION
    This cmdlet will return various array space metrics for the given FlashArray.
    .PARAMETER EndPoint
    Required. FQDN or IP address of the FlashArray.
    .INPUTS
    None
    .OUTPUTS
    Various FlashArray space used and available information.
    .EXAMPLE
    Get-FlashArraySpace -EndPoint myArray

    .NOTES
    This cmdlet can utilize the global $Creds variable for FlashArray authentication. Set the variable $Creds by using the command $Creds = Get-Credential.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][string] $EndPoint
    )

    # Connect to FlashArray
    try {
        $flashArray = Connect-Pfa2Array -Endpoint $EndPoint -Credential (Get-Creds) -IgnoreCertificateError
    }
    catch {
        $ExceptionMessage = $_.Exception.Message
        Write-Error "Failed to connect to FlashArray endpoint $Endpoint with: $ExceptionMessage"
        Return
    }

    try {
        Get-Pfa2ArraySpace -Array $flashArray -PipelineVariable a | 
        select -Expand Space |
        foreach { [pscustomobject]@{
                Name                  = $a.Name;
                'Percent Used'        = ($_.TotalPhysical / $a.Capacity).ToString('P');
                'Capacity Used (TB)'  = [math]::Round([double]($_.TotalPhysical / 1TB), 2);
                'Capacity Free (TB)'  = [math]::Round([double](($a.Capacity - $_.TotalPhysical) / 1TB), 2);
                'Volume Space (TB)'   = [math]::Round([double]($_.Unique / 1TB), 2);
                'Shared Space (TB)'   = [math]::Round([double]($_.Shared / 1TB), 2);
                'Snapshot Space (TB)' = [math]::Round([double]($_.Snapshots / 1TB), 2);
                'System Space (TB)'   = [math]::Round([double]($_.System / 1TB), 2);
                'Total Storage (TB)'  = [math]::Round([double]($a.Capacity / 1TB), 2);
                'Data Reduction'      = [math]::Round($_.DataReduction, 2) ;
                'Thin Provisioning'   = [math]::Round($_.ThinProvisioning * 10, 2) 
            } } |
        Format-Table -AutoSize
    }
    finally {
        Disconnect-Pfa2Array -Array $flashArray
    }
}
