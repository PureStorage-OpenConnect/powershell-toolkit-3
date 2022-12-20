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
        [parameter(mandatory = $true)] [Sqlcollaborative.Dbatools.Parameter.DbaInstanceParameter] $SqlInstance,
        [parameter(mandatory = $true)] [string] $Database,
        [parameter(mandatory = $true)] [string] $Endpoint,
        [parameter()] [pscredential] $SqlCredential,
        [Parameter()] [pscredential] $Credential = ( Get-PfaCredential )
    )

    $sqlParams = @{
        SqlInstance = $SqlInstance
    }

    if ($PSBoundParameters.ContainsKey('SqlCredential')) {
        $sqlParams.Add('SqlCredential', $SqlCredential)
    }

    # Connect to FlashArray
    try {
        $flashArray = Connect-Pfa2Array -EndPoint $EndPoint -Credentials $Credential -IgnoreCertificateError
    }
    catch {
        $exceptionMessage = $_.Exception.Message
        Write-Error "Failed to connect to FlashArray endpoint $Endpoint with: $exceptionMessage"
        Return
    }

    try {
        Write-Colour -Text 'FlashArray endpoint       : ', 'CONNECTED' -Color Yellow, Green

        try {
            $destDb = Get-DbaDatabase @sqlParams -Database $Database
        }
        catch {
            $exceptionMessage = $_.Exception.Message
            Write-Error "Failed to connect to destination database $SqlInstance.$Database with: $exceptionMessage"
            Return
        }

        Write-Colour -Text 'Target SQL Server instance: ', $SqlInstance, ' - ', 'CONNECTED' -Color Yellow, Green, Green, Green
        Write-Colour -Text 'Target windows drive      : ', $destDb.PrimaryFilePath.Split(':')[0] -Color Yellow, Green

        try {
            $sqlInstance = Connect-DbaInstance @sqlParams
            $targetServer = $SqlInstance.ComputerNamePhysicalNetBIOS
            $sqlInstance | Disconnect-DbaInstance 
        }
        catch {
            $exceptionMessage = $_.Exception.Message
            Write-Error "Failed to determine target server name with: $exceptionMessage"
            Return
        }

        Write-Colour -Text 'Target SQL Server host    : ', $targetServer -ForegroundColor Yellow, Green

        $getDbDisk = { param ( $filePath )
            $dbDisk = Get-Partition -DriveLetter $filePath.Split(':')[0] | Get-Disk
            return $dbDisk
        }

        try {
            $targetDisk = Invoke-Command -ComputerName $targetServer -ScriptBlock $getDbDisk -ArgumentList $destDb.PrimaryFilePath
        }
        catch {
            $exceptionMessage = $_.Exception.Message
            Write-Error "Failed to determine the windows disk snapshot target with: $exceptionMessage"
            Return
        }

        Write-Colour -Text 'Target disk serial number : ', $targetDisk.SerialNumber -Color Yellow, Green

        try {
            $targetVolume = (Get-Pfa2Volume -Array $flashArray | Where-Object { $_.serial -eq $targetDisk.SerialNumber }).Name
        }
        catch {
            $exceptionMessage = $_.Exception.Message
            Write-Error "Failed to determine snapshot FlashArray volume with: $exceptionMessage"
            Return
        }

        $snapshotSuffix = '{0}-{1}-{2:HHmmss}' -f $SqlInstance.FullName.Replace('\', '-'), $Database, (Get-Date)
        Write-Colour -Text 'Snapshot target Pfa volume: ', $targetVolume -Color Yellow, Green
        Write-Colour -Text 'Snapshot suffix           : ', $snapshotSuffix -Color Yellow, Green

        try {
            New-Pfa2VolumeSnapshot -Array $flashArray -Sources $targetVolume -Suffix $snapshotSuffix
        }
        catch {
            $exceptionMessage = $_.Exception.Message
            Write-Error "Failed to create snapshot for target database FlashArray volume with: $exceptionMessage"
            Return
        }
    }
    finally {
        Disconnect-Pfa2Array $flashArray
    }
}