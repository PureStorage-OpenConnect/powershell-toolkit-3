function New-FlashArrayDbSnapshot {
    <#
.SYNOPSIS
A PowerShell function to create a FlashArray snapshot of the volume that a database resides on.

.DESCRIPTION
A PowerShell function to create a FlashArray snapshot of the volume that a database resides on, based in the
values of the following parameters:

.PARAMETER Database
Required. The name of the database to refresh, note that it is assumed that source and target database(s) are named the same.

.PARAMETER SqlInstance
Required. This can be one or multiple SQL Server instance(s) that host the database(s) to be refreshed, in the case that the
function is invoked  to refresh databases  across more than one instance, the list of target instances should be
spedcified as an array of strings, otherwise a single string representing the target instance will suffice.

.PARAMETER Endpoint
Required. The IP address representing the FlashArray that the volumes for the source and refresh target databases reside on.

.EXAMPLE
New-FlashArrayDbSnapshot -Database tpch-no-compression -SqlInstance z-sql2016-devops-prd -Endpoint 10.225.112.10 -Creds $Creds

Create a snapshot of FlashArray volume that stores the tpch-no-compression database on the z-sql2016-devops-prd instance

.NOTES

FlashArray Credentials - A global variable $Creds may be used as described in the release notes for this module. If neither is specified, the module will prompt for credentials.

Known Restrictions
------------------
1. This function does not work for databases associated with failover cluster instances.
2. This function cannot be used to seed secondary replicas in availability groups using databases in the primary replica.
3. The function assumes that all database files and the transaction log reside on a single FlashArray volume.

Note that it has dependencies on the dbatools and PureStoragePowerShellSDK modules which are installed as part of this module.
#>
    param(
        [parameter(mandatory = $true)] [string] $Database,
        [parameter(mandatory = $true)] [string] $SqlInstance,
        [parameter(mandatory = $true)] [string] $Endpoint
    )

    Get-Sdk1Module
    Get-DbaToolsModule

    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

    if ( ! $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) ) {
        Write-Error "This function needs to be invoked within a PowerShell session with elevated admin rights"
        Return
    }

    # Connect to FlashArray
    if (!($Creds)) {
        try {
            $FlashArray = New-PfaArray -EndPoint $EndPoint -Credentials (Get-Credential) -IgnoreCertificateError
        }
        catch {
            $ExceptionMessage = $_.Exception.Message
            Write-Error "Failed to connect to FlashArray endpoint $Endpoint with: $ExceptionMessage"
            Return
        }
    }
    else {
        try {
            $FlashArray = New-PfaArray -EndPoint $EndPoint -Credentials $Creds -IgnoreCertificateError
        }
        catch {
            $ExceptionMessage = $_.Exception.Message
            Write-Error "Failed to connect to FlashArray endpoint $Endpoint with: $ExceptionMessage"
            Return
        }
    }

    Write-Colour -Text "FlashArray endpoint       : ", "CONNECTED" -Color Yellow, Green

    try {
        $DestDb = Get-DbaDatabase -SqlInstance $SqlInstance -Database $Database
    }
    catch {
        $ExceptionMessage = $_.Exception.Message
        Write-Error "Failed to connect to destination database $SqlInstance.$Database with: $ExceptionMessage"
        Return
    }

    Write-Colour -Text "Target SQL Server instance: ", $SqlInstance, " - ", "CONNECTED" -Color Yellow, Green, Green, Green
    Write-Colour -Text "Target windows drive      : ", $DestDb.PrimaryFilePath.Split(':')[0] -Color Yellow, Green

    try {
        $TargetServer = (Connect-DbaInstance -SqlInstance $SqlInstance).ComputerNamePhysicalNetBIOS
    }
    catch {
        Write-Error "Failed to determine target server name with: $ExceptionMessage"
    }

    Write-Colour -Text "Target SQL Server host    : ", $TargetServer -ForegroundColor Yellow, Green

    $GetDbDisk = { param ( $Db )
        $DbDisk = Get-Partition -DriveLetter $Db.PrimaryFilePath.Split(':')[0] | Get-Disk
        return $DbDisk
    }

    try {
        $TargetDisk = Invoke-Command -ComputerName $TargetServer -ScriptBlock $GetDbDisk -ArgumentList $DestDb
    }
    catch {
        $ExceptionMessage = $_.Exception.Message
        Write-Error "Failed to determine the windows disk snapshot target with: $ExceptionMessage"
        Return
    }

    Write-Colour -Text "Target disk serial number : ", $TargetDisk.SerialNumber -Color Yellow, Green

    try {
        $TargetVolume = Get-PfaVolumes -Array $FlashArray | Where-Object { $_.serial -eq $TargetDisk.SerialNumber } | Select-Object name
    }
    catch {
        $ExceptionMessage = $_.Exception.Message
        Write-Error "Failed to determine snapshot FlashArray volume with: $ExceptionMessage"
        Return
    }

    $SnapshotSuffix = $SqlInstance.Replace('\', '-') + '-' + $Database + '-' + $(Get-Date).Hour + $(Get-Date).Minute + $(Get-Date).Second
    Write-Colour -Text "Snapshot target Pfa volume: ", $TargetVolume.name -Color Yellow, Green
    Write-Colour -Text "Snapshot suffix           : ", $SnapshotSuffix -Color Yellow, Green

    try {
        New-PfaVolumeSnapshots -Array $FlashArray -Sources $TargetVolume.name -Suffix $SnapshotSuffix
    }
    catch {
        $ExceptionMessage = $_.Exception.Message
        Write-Error "Failed to create snapshot for target database FlashArray volume with: $ExceptionMessage"
        Return
    }
}