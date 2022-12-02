function Get-HostBusAdapter() {
    <#
    .SYNOPSIS
    Retrieves host Bus Adapater (HBA) information.
    .DESCRIPTION
    Retrieves host Bus Adapater (HBA) information for the host.
    .PARAMETER ComputerName
    Optional. The computer name to run the cmdlet against. It defaults to the local computer name.
    .INPUTS
    Computer name is optional.
    .OUTPUTS
    Host Bus Adapter information.
    .EXAMPLE
    Get-HostBusAdapter -ComputerName myComputer
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $False)] [string] $ComputerName  = "$env:COMPUTERNAME"
    )

    try {
        $port = Get-WmiObject -Class MSFC_FibrePortHBAAttributes -Namespace 'root\WMI' -ComputerName $ComputerName
        $hbas = Get-WmiObject -Class MSFC_FCAdapterHBAAttributes -Namespace 'root\WMI' -ComputerName $ComputerName
        $hbaProp = $hbas | Get-Member -MemberType Property, AliasProperty | Select-Object -ExpandProperty name | Where-Object { $_ -notlike '__*' }
        $hbas = $hbas | Select-Object -ExpandProperty $hbaProp
        $hbas | ForEach-Object { $_.NodeWWN = ((($_.NodeWWN) | ForEach-Object { '{0:x2}' -f $_ }) -join ':').ToUpper() }

        ForEach ($hba in $hbas) {
            Add-Member -MemberType NoteProperty -InputObject $hba -Name FabricName -Value (($port | Where-Object { $_.instancename -eq $hba.instancename }).attributes | Select-Object @{ Name = 'Fabric Name'; Expression = { (($_.fabricname | ForEach-Object { '{0:x2}' -f $_ }) -join ':').ToUpper() } }, @{ Name = 'Port WWN'; Expression = { (($_.PortWWN | ForEach-Object { '{0:x2}' -f $_ }) -join ':').ToUpper() } }) -PassThru
        }
    }
    catch {

    }
}