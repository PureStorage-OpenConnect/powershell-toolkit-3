function Sync-FlashArrayHosts() {
    <#
    .SYNOPSIS
    Synchronizes the hosts amd host protocols between two FlashArrays.
    .DESCRIPTION
    This cmdlet will retrieve the current hosts from the Source array and create them on the target array. It will also add the FC (WWN) or iSCSI (iqn) settings for each host on the Target array.
    .PARAMETER SourceArray
    Required. FQDN or IP address of the source FlashArray.
    .PARAMETER TargetArray
    Required. FQDN or IP address of the source FlashArray.
    .PARAMETER Protocol
    Required. 'FC' for Fibre Channel WWNs or 'iSCSI' for iSCSI IQNs.
    .INPUTS
    None
    .OUTPUTS
    None
    .EXAMPLE
    Sync-FlashArraysHosts -SourceArray mySourceArray -TargetArray myTargetArray -Protocol FC

    Synchronizes the hosts and hosts FC WWNs from the mySourceArray to the myTargetArray.
    .NOTES
    This cmdlet cannot utilize the global $Creds variable as it requires two logins to two separate arrays.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Position=0,Mandatory=$True)][ValidateNotNullOrEmpty()][string] $SourceArray,
        [Parameter(Position=1,Mandatory=$True)][ValidateNotNullOrEmpty()][string]$TargetArray,
        [Parameter(Mandatory = $True)][ValidateSet("iSCSI", "FC")][string]$Protocol
    )

    $FlashArray1 = New-PfaArray -EndPoint $SourceArray -Credentials (Get-Credential) -IgnoreCertificateError
    $FlashArray2 = New-PfaArray -EndPoint $TargetArray -Credentials (Get-Credential) -IgnoreCertificateError

    Get-PfaHosts -Array $FlashArray1 | New-PfaHost -Array $FlashArray2
    Get-PfaHostGroups -Array $FlashArray1 | New-PfaHostGroup -Array $FlashArray2

    $fa1Hosts = Get-PfaHosts -Array $FlashArray1

    switch ($Procotol) {
        'iSCSI' {
            foreach ($fa1Host in $fa1Hosts) {
                Add-PfaHostIqns -Array $FlashArray2 -AddIqnList $fa1Host.iqn -Name $fa1Host.name
            }
        }
        'FC' {
            foreach ($fa1Host in $fa1Hosts) {
                Add-PfaHostWwns -Array $FlashArray2 -AddWwnList $fa1Host.wwn -Name $fa1Host.name
            }
        }
    }
}