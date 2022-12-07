enum MPIODiskLBPolicy {
    clear = 0
    FO    = 1
    RR    = 2
    RRWS  = 3
    LQD   = 4
    WP    = 5
    LB    = 6
}

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
        [Parameter(Mandatory)][MPIODiskLBPolicy]$Policy
    )

    #Checks whether mpclaim.exe is available.
    $exists = Test-Path "$env:systemroot\System32\mpclaim.exe"
    if (-not ($exists)) {
        Write-Error 'mpclaim.exe not found. Is MultiPathIO enabled? Exiting.' -ErrorAction Stop
    }

    Write-Host "Setting MPIO Load Balancing Policy to $([int]$Policy) for all Pure FlashArray disks."
    $puredisks = Get-PhysicalDisk | Where-Object FriendlyName -Match 'PURE'
    $puredisks | ForEach-Object {
        # Get disk uniqueid
        $UniqueID = $_.UniqueId
        $MPIODisk = (Get-CimInstance -Namespace root\wmi -Class MPIO_DISK_INFO).driveinfo | Where-Object { $_.SerialNumber -eq $UniqueID }
        $MPIODiskID = $MPIODisk.Name.Replace('MPIO Disk', '')
        $MPIODiskID
        mpclaim.exe  -l -d $MPIODiskID [int]$Policy
    }
    Write-Host 'New disk LB policy settings:' -ForegroundColor Green
    mpclaim.exe -s -d
}