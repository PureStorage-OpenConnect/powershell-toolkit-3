function Set-MPIODiskLBPolicy() {
    <#
    .SYNOPSIS
    Sets the MPIO Load Balancing policy for FlashArray disks.
    .DESCRIPTION
    This cmdlet will set the MPIO Load Balancing policy for all connected Pure FlashArrays disks to the desired setting using the mpclaim.exe utlity.
    The default Windows OS setting is RR.
    .PARAMETER Policy
    Required. No default. The Policy type must be specified by the letter acronym for the policy name (ex. "RR" for Round Robin). Available options are:
        LQD = Least Queue Depth
        RR = Round Robin
        FO = Fail Over Only
        RRWS = Round Robin with Subset
        WP = Weighted Paths
        LB = Least Blocks
        clear = clears current policy and sets to Windows OS default of RR
    .INPUTS
    None
    .OUTPUTS
    None
    .EXAMPLE
    Set-MPIODiskLBPolicy -Policy LQD

    Sets the MPIO load balancing policy for all Pure disks to Least Queue Depth.

    .EXAMPLE
    Set-MPIODiskLBPolicy -Policy clear

    Clears the current MPIO policy for all Pure disks and sets to the default of RR.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)][ValidateSet('LQD','RR','clear','FO','RRWS','WP','LB',IgnoreCase = $true)][string]$Policy
    )
    If ($Policy -eq "LQD") { $pn = "4" }
    elseif ($Policy -eq "RR") { $pn = "2" }
    elseif ($Policy -like "clear") { $pn = "0" }
    elseif ($Policy -eq "FO") { $pn = "1" }
    elseif ($Policy -eq "RRWS") { $pn = "3" }
    elseif ($Policy -eq "WP") { $pn = "5" }
    elseif ($Policy -eq "LB") { $pn = "6" }
    else {
        Write-Host "Required policy type parameter of LQD, RR, FO, RRWS, WP LB, or clear not supplied. Exiting."
        break
    }
    function Invoke-MPclaim($param1, $param2, $param3, $param4) {
        . mpclaim.exe $param1 $param2 $param3 $param4
    }
    #Checks whether mpclaim.exe is available.
    $exists = Test-Path "$env:systemroot\System32\mpclaim.exe"
    if (-not ($exists)) {
        Write-Host "mpclaim.exe not found. Is MultiPathIO enabled? Exiting." -ForegroundColor Yellow
        break
    }
    Write-Host "Setting MPIO Load Balancing Policy to" + $pn + " for all Pure FlashArray disks."
    $puredisks = Get-PhysicalDisk | Where-Object FriendlyName -Match "PURE"
    $puredisks | ForEach-Object {
        # Get disk uniqueid
        $UniqueID = $_.UniqueId
        $MPIODisk = (Get-WmiObject -Namespace root\wmi -Class mpio_disk_info).driveinfo | Where-Object { $_.SerialNumber -eq $UniqueID }
        $MPIODiskID = $MPIODisk.Name.Replace("MPIO Disk", "")
        $MPIODiskID
        Invoke-mpclaim -param1 "-l" -param2 "-d" -param3 $MPIODiskID -param4 $pn
    }
    Write-Host "New disk LB policy settings:" -ForegroundColor Green
    Invoke-mpclaim -param1 "-s" -param2 "-d" -param3 "" -param4 ""
}