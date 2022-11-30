function Get-FlashArrayPgroupsConfig() {
    <#
    .SYNOPSIS
    Retrieves Protection Group (PGroup) information for the FlashArray.
    .DESCRIPTION
    Retrieves Protection Group (PGroup) information for the FlashArray.
    .PARAMETER EndPoint
    Required. FQDN or IP address of the FlashArray.
    .INPUTS
    None
    .OUTPUTS
    Protection Group information is displayed.
    .EXAMPLE
    Get-FlashArrayPgroupsConfig -EndPoint myArrayg

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
        $exceptionMessage = $_.Exception.Message
        Write-Error "Failed to connect to FlashArray endpoint $Endpoint with: $exceptionMessage"
        Return
    }

    try {
        $protectionGroups = Get-Pfa2ProtectionGroup -Array $flashArray

        $groupVolumes = @{} 
        Get-Pfa2ProtectionGroupVolume -Array $flashArray | foreach { $groupVolumes[$_.Group.Name] += @($_.Member.Name) }

        $groupHosts = @{} 
        Get-Pfa2ProtectionGroupHost -Array $flashArray | foreach { $groupHosts[$_.Group.Name] += @($_.Member.Name) }

        $groupHostGroups = @{} 
        Get-Pfa2ProtectionGroupHostGroup -Array $flashArray | foreach { $groupHostGroups[$_.Group.Name] += @($_.Member.Name) }

        foreach ($protectionGroup in $ProtectionGroups) {
            if ($protectionGroup.ReplicationSchedule.Enabled -eq 'True') {
                Write-Host '========================================================================================'
                Write-Host "                 $($protectionGroup.name)                               " -ForegroundColor Green
                Write-Host '========================================================================================'
                Write-Host "Host Groups: $($groupHostGroups[$protectionGroup.name])"
                Write-Host "Hosts: $($groupHosts[$protectionGroup.name])"
                Write-Host "Volumes: $($groupVolumes[$protectionGroup.name])"
                Write-Host ''
                Write-Host "A snapshot is taken and replicated every $($protectionGroup.ReplicationSchedule.Frequency/1000/60) minutes."
                Write-Host "$(($protectionGroup.TargetRetention.AllForSec/60)/($ProtectionGroup.ReplicationSchedule.Frequency/1000/60)) snapshot(s) are kept on the target for $($ProtectionGroup.TargetRetention.AllForSec/60) minutes."
                Write-Host "$($protectionGroup.TargetRetention.PerDay) additional snapshot(s) are kept for $($ProtectionGroup.TargetRetention.Days) more days."
            }
            else {
                Write-Host '=========================================================================================='
                Write-Host "                $($protectionGroup.name)                               " -ForegroundColor Yellow
                Write-Host '=========================================================================================='
                Write-Host "Host Groups: $($groupHostGroups[$protectionGroup.name])"
                Write-Host "Hosts: $($groupHosts[$protectionGroup.name])"
                Write-Host "Volumes: $($groupVolumes[$protectionGroup.name])"
                Write-Host ''
                Write-Host "$($protectionGroup.name) is disabled." -ForegroundColor Yellow
                Write-Host ''
            }
        }
    }
    finally {
        Disconnect-Pfa2Array -Array $flashArray
    }
}
