function Unregister-HostVolumes() {
    <#
    .SYNOPSIS
    Sets Pure FlashArray connected disks to offline.
    .DESCRIPTION
    This cmdlet will set any FlashArray volumes (disks) to offline in Windows using the diskpart command.
    .PARAMETER ComputerName
    Optional. The computer name to run the cmdlet against. It defaults to the local computer name.
    .INPUTS
    None
    .OUTPUTS
    None
    .EXAMPLE
    Unregister-HostVolumes -ComputerName myComputer

    Offlines all FlashArray disks from myComputer.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $False)] [string]$Computername = "$env:COMPUTERNAME"
    )

    $cmds = "`"RESCAN`""
    $scriptblock = [string]::Join(',', $cmds)
    $diskpart = $ExecutionContext.InvokeCommand.NewScriptBlock("$scriptblock | DISKPART")
    $result = Invoke-Command -ComputerName $Computername -ScriptBlock $diskpart
    $disks = Invoke-Command -ComputerName $Computername { Get-Disk }
    ForEach ($disk in $disks) {
        If ($disk.FriendlyName -like 'PURE FlashArray*') {
            If ($disk.OperationalStatus -ne 1) {
                $disknumber = $disk.Number
                $cmds = "`"SELECT DISK $disknumber`"",
                "`"OFFLINE DISK`""
                $scriptblock = [string]::Join(',', $cmds)
                $diskpart = $ExecutionContext.InvokeCommand.NewScriptBlock("$scriptblock | DISKPART")
                $result = Invoke-Command -ComputerName $Computername -ScriptBlock $diskpart -ErrorAction Stop
            }
        }
    }
}