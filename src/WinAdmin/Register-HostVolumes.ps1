function Register-HostVolumes() {
    <#
    .SYNOPSIS
    Sets Pure FlashArray connected disks to online.
    .DESCRIPTION
    This cmdlet will set any FlashArray volumes (disks) to online in Windows using the diskpart command.
    .PARAMETER ComputerName
    Optional. The computer name to run the cmdlet against. It defaults to the local computer name.
    .INPUTS
    None
    .OUTPUTS
    None
    .EXAMPLE
    Register-HostVolumes -ComputerName myComputer

    Sets all FlashArray disks for myComputer to online.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $False)] [string]$ComputerName = "$env:COMPUTERNAME"
    )

    $cmds = "`"RESCAN`""
    $scriptblock = [string]::Join(',', $cmds)
    $diskpart = $ExecutionContext.InvokeCommand.NewScriptBlock("$scriptblock | DISKPART")
    $result = Invoke-Command -ComputerName $ComputerName -ScriptBlock $diskpart
    $disks = Invoke-Command -ComputerName $ComputerName { Get-Disk }
#    $i = 0
    ForEach ($disk in $disks) {
        If ($disk.FriendlyName -like 'PURE FlashArray*') {
            If ($disk.OperationalStatus -ne 1) {
                $disknumber = $disk.Number
                $cmds = "`"SELECT DISK $disknumber`"",
                "`"ATTRIBUTES DISK CLEAR READONLY`"",
                "`"ONLINE DISK`""
                $scriptblock = [string]::Join(',', $cmds)
                $diskpart = $ExecutionContext.InvokeCommand.NewScriptBlock("$scriptblock | DISKPART")
                $result = Invoke-Command -ComputerName $ComputerName -ScriptBlock $diskpart -ErrorAction Stop
            }
        }
    }
}