function Set-WindowsPowerScheme() {
    <#
    .SYNOPSIS
    Cmdlet to set the Power scheme for the Windows OS to High Performance.
    .DESCRIPTION
    Cmdlet to set the Power scheme for the Windows OS to High Performance.
    .PARAMETER ComputerName
    Optional. The computer name to run the cmdlet against. It defaults to the local computer name.
    .INPUTS
    None
    .OUTPUTS
    Current power scheme and optional confirmation to alter the setting in the Windows registry.
    .EXAMPLE
    Set-WindowsPowerScheme

    Retrieves the current Power Scheme setting, and if not set to High Performance, asks for confirmation to set it.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $False)] [string] $ComputerName = "$env:COMPUTERNAME"
    )
    $PowerScheme = Get-WmiObject -Class WIN32_PowerPlan -Namespace 'root\cimv2\power' -ComputerName $ComputerName -Filter "isActive='true'"
    if ($PowerScheme.ElementName -ne "High performance") {
        Write-Host "WARNING" -ForegroundColor Yellow -NoNewline
        Write-Host ": Computer Power Scheme is not set to High Performance. Pure Storage best practice is to set this power plan as default."
        Write-Host " "
        Write-Host "REQUIRED ACTION: Set the Power Plan to High Performance?"
        $resp = Read-Host -Prompt "Y/N?"
        if ($resp.ToUpper() -eq 'Y') {
            $planId = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
            powercfg -setactive "$planId"
        }
    }
    else {
        Write-Host "PASSED" -ForegroundColor Green -NoNewline
        Write-Host ": Computer Power Scheme is already set to High Performance. Exiting."
    }
}