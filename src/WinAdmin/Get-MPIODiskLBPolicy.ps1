function Get-MPIODiskLBPolicy() {
    <#
    .SYNOPSIS
    Retrieves the current MPIO Load Balancing policy for Pure FlashArray disk(s).
    .DESCRIPTION
    This cmdlet will retrieve the current MPIO Load Balancing policy for connected Pure FlashArrays disk(s) using the mpclaim.exe utlity.
    .PARAMETER DiskID
    Optional. If specified, retrieves only the policy for the that disk ID. Otherwise, returns all disks.
    DiskID is the 'Number' identifier of the disk from the cmdlet 'Get-Disk'.
    .INPUTS
    None
    .OUTPUTS
    mpclaim.exe output
    .EXAMPLE
    Get-MPIODiskLBPolicy -DiskID 1

    Returns the current MPIO LB policy for disk ID 1.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $False)][string]$DiskId
    )
    function Invoke-mpclaim($param1, $param2, $param3) {
        . mpclaim.exe $param1 $param2 $param3
    }
    #Checks whether mpclaim.exe is available.
    $exists = Test-Path "$env:systemroot\System32\mpclaim.exe"
    if (-not ($exists)) {
        Write-Host "mpclaim.exe not found. Is MultiPathIO enabled? Exiting." -ForegroundColor Yellow
        break
    }
    if ($DiskId) {
        Write-Host "Getting current MPIO Load Balancing Policy for DiskID " + $DiskId -ForegroundColor Green
        $result = Invoke-mpclaim -param1 "-s" -param2 "-d" -param3 $DiskId
        return $result
    }
    else {
        Write-Host "Getting current MPIO Load Balancing Policy for all MPIO disks." -ForegroundColor Green
        $result = Invoke-mpclaim -param1 "-s" -param2 "-d"
        return $result
    }
}