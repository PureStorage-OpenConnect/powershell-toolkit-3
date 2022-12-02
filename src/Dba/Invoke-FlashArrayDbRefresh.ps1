function Invoke-FlashArrayDbRefresh {
<#
.SYNOPSIS
A PowerShell function to refresh one or more SQL Server databases (the destination) from either a snapshot or database.

.DESCRIPTION
A PowerShell function to refresh one or more SQL Server databases either from:
- a snapshot specified by its name
- a snapshot picked from a list associated with the volume the source database resides on
- a source database directly

This  function will detect and repair orpaned users in refreshed databases and optionally
apply data masking, based on either:
- the dynamic data masking functionality available in SQL Server version 2016 onwards,
- static data masking built into dbatools from version 0.9.725, refer to https://dbatools.io/mask/

.PARAMETER RefreshDatabase
Required. The name of the database to refresh, note that it is assumed that source and target database(s) are named the same.

.PARAMETER RefreshSource
Required. If the RefreshFromSnapshot flag is specified, this parameter takes the name of a snapshot, otherwise this takes the
name of the source SQL Server instance.

.PARAMETER DestSqlInstance
Required. This can be one or multiple SQL Server instance(s) that host the database(s) to be refreshed, in the case that the
function is invoked  to refresh databases across more than one instance, the list of target instances should be
spedcified as an array of strings, otherwise a single string representing the target instance will suffice.

.PARAMETER Endpoint
Required. The IP address representing the FlashArray that the volumes for the source and refresh target databases reside on.

.PARAMETER PollJobInterval
Optional. Interval at which background job status is poll, if this is ommited polling will not take place. Note that this parameter
is not applicable is the PromptForSnapshot switch is specified.

.PARAMETER PromptForSnapshot
Optional. This is an optional flag that if specified will result in a list of snapshots being displayed for the database volume on
the FlashArray that the user can select one from. Despite the source of the refresh operation being an existing snapshot,
 the source instance still has to be specified by the RefreshSource parameter in order that the function can determine
which FlashArray volume to list existing snapshots for.

.PARAMETER RefreshFromSnapshot
Optional. This is an optional flag that if specified causes the function to expect the RefreshSource parameter to be supplied with
the name of an existing snapshot.

.PARAMETER NoPsRemoting
Optional. The commands that off and online the windows volumes associated with the refresh target databases will use Invoke-Command
with powershell remoting unless this flag is specified. Certain tools that can invoke PowerShell, Ansible for example, do
not permit double-hop authentication unless CredSSP authentication is used. For security purposes Kerberos is recommended
over CredSSP, however this does not support double-hop authentication, in which case this flag should be specified.

.PARAMETER ApplyDataMasks
Optional. Specifying this optional masks will cause data masks to be applied , as per the dynamic data masking feature first
introduced with SQL Server 2016, this results in this function invoking the Invoke-DynamicDataMasking function to be invoked.
For documentation on Invoke-DynamicDataMasking, use the command Get-Help Invoke-DynamicDataMasking -Detailed.

.PARAMETER ForceDestDbOffline
Optional. Specifying this switch will cause refresh target databases for be forced offline via WITH ROLLBACK IMMEDIATE.

.PARAMETER StaticDataMaskFile
Optional. If this parameter is present and has a file path associated with it, the data masking available in version 0.9.725 of the
dbatools module onwards will be applied  to the refreshed database. The use of this is contigent on the data mask file
being created and populated in the first place as per this blog post: https://dbatools.io/mask/ .

.EXAMPLE
Invoke-FlashArrayDbRefresh -RefreshDatabase tpch-no-compression -RefreshSource z-sql2016-devops-prd -DestSqlInstance z-sql2016-devops-tst -Endpoint 10.225.112.10 `
-PromptForSnapshot

Refresh a single database from a snapshot selected from a list of snapshots associated with the volume specified by the RefreshSource parameter.
.EXAMPLE
$Targets = @("z-sql2016-devops-tst", "z-sql2016-devops-dev")
Invoke-FlashArrayDbRefresh -RefreshDatabase tpch-no-compression -RefreshSource z-sql2016-devops-prd -DestSqlInstance $Targets -Endpoint 10.225.112.10 `
-PromptForSnapshot

Refresh multiple databases from a snapshot selected from a list of snapshots associated with the volume specified by the RefreshSource parameter.
.EXAMPLE
Invoke-FlashArrayDbRefresh -RefreshDatabase tpch-no-compression -RefreshSource source-snap -DestSqlInstance z-sql2016-devops-tst -Endpoint 10.225.112.10 `
-RefreshFromSnapshot

Refresh a single database using the snapshot specified by the RefreshSource parameter.
.EXAMPLE
$Targets = @("z-sql2016-devops-tst", "z-sql2016-devops-dev")
Invoke-FlashArrayDbRefresh -RefreshDatabase tpch-no-compression -RefreshSource source-snap -DestSqlInstance $Targets -Endpoint 10.225.112.10 `
-RefreshFromSnapshot

Refresh multiple databases using the snapshot specified by the RefreshSource parameter.
.EXAMPLE
Invoke-FlashArrayDbRefresh -$RefreshDatabase tpch-no-compression -RefreshSource z-sql-prd -DestSqlInstance z-sql2016-devops-tst -Endpoint 10.225.112.10

Refresh a single database from the database specified by the SourceDatabase parameter residing on the instance specified by RefreshSource.
.EXAMPLE
$Targets = @("z-sql2016-devops-tst", "z-sql2016-devops-dev")
Invoke-FlashArrayDbRefresh -$RefreshDatabase tpch-no-compression -RefreshSource z-sql-prd -DestSqlInstance $Targets -Endpoint 10.225.112.10 `

Refresh multiple databases from the database specified by the SourceDatabase parameter residing on the instance specified by RefreshSource.
.EXAMPLE
$Targets = @("z-sql2016-devops-tst", "z-sql2016-devops-dev")
Invoke-PfaDbRefresh -$RefreshDatabase tpch-no-compression -RefreshSource z-sql-prd -DestSqlInstance $Targets -Endpoint 10.225.112.10 `
-ApplyDataMasks

Refresh multiple databases from the database specified by the SourceDatabase parameter residing on the instance specified by RefreshSource.
.EXAMPLE
$StaticDataMaskFile = "D:\apps\datamasks\z-sql-prd.tpch-no-compression.tables.json"
$Targets = @("z-sql2016-devops-tst", "z-sql2016-devops-dev")
Invoke-FlashArrayDbRefresh -$RefreshDatabase tpch-no-compression -RefreshSource z-sql-prd -DestSqlInstance $Targets -Endpoint 10.225.112.10 `
-StaticDataMaskFile $StaticDataMaskFile

Refresh multiple databases from the database specified by the SourceDatabase parameter residing on the instance specified by RefreshSource and apply SQL Server dynamic data masking to each database.
.EXAMPLE
$StaticDataMaskFile = "D:\apps\datamasks\z-sql-prd.tpch-no-compression.tables.json"
$Targets = @("z-sql2016-devops-tst", "z-sql2016-devops-dev")
Invoke-FlashArrayDbRefresh -$RefreshDatabase tpch-no-compression -RefreshSource z-sql-prd -DestSqlInstance $Targets -Endpoint 10.225.112.10 `
-ForceDestDbOffline -StaticDataMaskFile $StaticDataMaskFile

Refresh multiple databases from the database specified by the SourceDatabase parameter residing on the instance specified by RefreshSource and apply SQL Server dynamic data masking to each database.
All databases to be refreshed are forced offline prior to their underlying FlashArray volumes being overwritten.
.EXAMPLE
$StaticDataMaskFile = "D:\apps\datamasks\z-sql-prd.tpch-no-compression.tables.json"
$Targets = @("z-sql2016-devops-tst", "z-sql2016-devops-dev")
Invoke-FlashArrayDbRefresh -$RefreshDatabase tpch-no-compression -RefreshSource z-sql-prd -DestSqlInstance $Targets -Endpoint 10.225.112.10 `
-PollJobInterval 10 -ForceDestDbOffline -StaticDataMaskFile $StaticDataMaskFile

Refresh multiple databases from the database specified by the SourceDatabase parameter residing on the instance specified by RefreshSource and apply SQL Server dynamic data masking to each database.
All databases to be refreshed are forced offline prior to their underlying FlashArray volumes being overwritten. Poll the status of the refresh jobs once every 10 seconds.
.NOTES
FlashArray Credentials - A global variable $Creds may be used as described in the release notes for this module. If neither is specified, the module will prompt for credentials.

Known Restrictions
------------------
1. This function does not work for databases associated with failover cluster instances.
2. This function cannot be used to seed secondary replicas in availability groups using databases in the primary replica.
3. The function assumes that all database files and the transaction log reside on a single FlashArray volume.

Note that it has dependencies on the dbatools and PureStoragePowerShellSDK modules which are installed by this module.
#>
    param(
        [parameter(mandatory = $true)][string]$RefreshDatabase,
        [parameter(mandatory = $true)][string]$RefreshSource,
        [parameter(mandatory = $true)][string[]]$DestSqlInstances,
        [parameter(mandatory = $true)][string]$Endpoint,
        [parameter(mandatory = $false)][int]$PollJobInterval,
        [parameter(mandatory = $false)][switch]$PromptForSnapshot,
        [parameter(mandatory = $false)][switch]$RefreshFromSnapshot,
        [parameter(mandatory = $false)][switch]$NoPsRemoting,
        [parameter(mandatory = $false)][switch]$ApplyDataMasks,
        [parameter(mandatory = $false)][switch]$ForceDestDbOffline,
        [parameter(mandatory = $false)][string]$StaticDataMaskFile
    )

    $StartMs = Get-Date

    Get-Sdk1Module
    Get-DbaToolsModule

    if ( $PromptForSnapshot.IsPresent.Equals($false) -And $RefreshFromSnapshot.IsPresent.Equals($false) ) {
        try {
            $SourceDb = Get-DbaDatabase -SqlInstance $RefreshSource -Database $RefreshDatabase
        }
        catch {
            $ExceptionMessage = $_.Exception.Message
            Write-Error "Failed to connect to source database $RefreshSource.$Database with: $ExceptionMessage"
            Return
        }

        Write-Color -Text "Source SQL Server instance: ", $RefreshSource, " - CONNECTED" -Color Yellow, Green, Green

        try {
            $SourceServer = (Connect-DbaInstance -SqlInstance $RefreshSource).ComputerNamePhysicalNetBIOS
        }
        catch {
            Write-Error "Failed to determine target server name with: $ExceptionMessage"
        }
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

    Write-Color -Text "FlashArray endpoint       : ", "CONNECTED" -ForegroundColor Yellow, Green

    $GetDbDisk = { param ( $Db )
        $DbDisk = Get-Partition -DriveLetter $Db.PrimaryFilePath.Split(':')[0] | Get-Disk
        return $DbDisk
    }

    $Snapshots = $(Get-PfaAllVolumeSnapshots $FlashArray)
    $FilteredSnapshots = $Snapshots.where( { ([string]$_.Source) -eq $RefreshSource })

    if ( $PromptForSnapshot.IsPresent ) {
        Write-Host ' '
        for ($i = 0; $i -lt $FilteredSnapshots.Count; $i++) {
            Write-Host 'Snapshot ' $i.ToString()
            $FilteredSnapshots[$i]
        }

        $SnapshotId = Read-Host -Prompt 'Enter the number of the snapshot to be used for the database refresh'
    }
    elseif ( $RefreshFromSnapshot.IsPresent.Equals( $false ) ) {
        try {
            if ( $NoPsRemoting.IsPresent ) {
                $SourceDisk = Invoke-Command -ScriptBlock $GetDbDisk -ArgumentList $SourceDb
            }
            else {
                $SourceDisk = Invoke-Command -ComputerName $SourceServer -ScriptBlock $GetDbDisk -ArgumentList $SourceDb
            }
        }
        catch {
            $ExceptionMessage = $_.Exception.Message
            Write-Error "Failed to determine source disk with: $ExceptionMessage"
            Return
        }

        try {
            $SourceVolume = Get-PfaVolumes -Array $FlashArray | Where-Object { $_.serial -eq $SourceDisk.SerialNumber } | Select-Object name
        }
        catch {
            $ExceptionMessage = $_.Exception.Message
            Write-Error "Failed to determine source volume with: $ExceptionMessage"
            Return
        }
    }

    if ( $PromptForSnapshot.IsPresent ) {
        Foreach ($DestSqlInstance in $DestSqlInstances) {
            Invoke-DbRefresh -DestSqlInstance $DestSqlInstance `
                -RefreshDatabase $RefreshDatabase `
                -Endpoint     $Endpoint     `
                -Creds  $Creds  `
                -SourceVolume    $FilteredSnapshots[$SnapshotId]
        }
    }
    else {
        $JobNumber = 1
        Foreach ($DestSqlInstance in $DestSqlInstances) {
            $JobName = "DbRefresh" + $JobNumber
            Write-Colour -Text "Refresh background job    : ", $JobName, " - ", "PROCESSING" -Color Yellow, Green, Green, Green
            If ( $RefreshFromSnapshot.IsPresent ) {
                Start-Job -Name $JobName -ScriptBlock $Function:DbRefresh -ArgumentList $DestSqlInstance   , `
                    $RefreshDatabase   , `
                    $Endpoint       , `
                    $Creds    , `
                    $RefreshSource     , `
                    $StaticDataMaskFile, `
                    $ForceDestDbOffline.IsPresent, `
                    $NoPsRemoting.IsPresent      , `
                    $PromptForSnapshot.IsPresent , `
                    $ApplyDataMasks.IsPresent | Out-Null
            }
            else {
                Start-Job -Name $JobName -ScriptBlock $Function:DbRefresh -ArgumentList $DestSqlInstance   , `
                    $RefreshDatabase   , `
                    $Endpoint       , `
                    $Creds    , `
                    $SourceVolume.Name , `
                    $StaticDataMaskFile, `
                    $ForceDestDbOffline.IsPresent, `
                    $NoPsRemoting.IsPresent      , `
                    $PromptForSnapshot.IsPresent , `
                    $ApplyDataMasks.IsPresent | Out-Null
            }
            $JobNumber += 1;
        }

        While (Get-Job -State Running | Where-Object { $_.Name.Contains("DbRefresh") }) {
            if ($PSBoundParameters.ContainsKey('PollJobInterval')) {
                Get-Job -State Running | Where-Object { $_.Name.Contains("DbRefresh") } | Receive-Job
                Start-Sleep -Seconds $PollJobInterval
            }
            else {
                Start-Sleep -Seconds 1
            }
        }

        Write-Colour -Text "Refresh background jobs   : ", "COMPLETED" -Color Yellow, Green

        foreach ($job in (Get-Job | Where-Object { $_.Name.Contains("DbRefresh") })) {
            $result = Receive-Job $job
            Write-Host $result
        }

        Remove-Job -State Completed
    }

    $EndMs = Get-Date
    Write-Host " "
    Write-Host "-------------------------------------------------------"         -ForegroundColor Green
    Write-Host " "
    Write-Host "D A T A B A S E      R E F R E S H      C O M P L E T E"         -ForegroundColor Green
    Write-Host " "
    Write-Host "              Duration (s) = " ($EndMs - $StartMs).TotalSeconds  -ForegroundColor White
    Write-Host " "
    Write-Host "-------------------------------------------------------"         -ForegroundColor Green
}
function DbRefresh {
    param(
        [parameter(mandatory = $true)][string]$DestSqlInstance,
        [parameter(mandatory = $true)][string]$RefreshDatabase,
        [parameter(mandatory = $true)][string]$Endpoint,
        [parameter(mandatory = $true)][string]$SourceVolume,
        [parameter(mandatory = $false)][string]$StaticDataMaskFile,
        [parameter(mandatory = $false)][bool]$ForceDestDbOffline,
        [parameter(mandatory = $false)][bool]$NoPsRemoting,
        [parameter(mandatory = $false)][bool]$PromptForSnapshot,
        [parameter(mandatory = $false)][bool]$ApplyDataMasks
    )

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

    try {
        $DestDb = Get-DbaDatabase -SqlInstance $DestSqlInstance -Database $RefreshDatabase
    }
    catch {
        $ExceptionMessage = $_.Exception.Message
        Write-Error "Failed to connect to destination database $DestSqlInstance.$Database with: $ExceptionMessage"
        Return
    }

    Write-Host " "
    Write-Colour -Text "Target SQL Server instance: ", $DestSqlInstance, "- CONNECTED" -ForegroundColor Yellow, Green, Green

    try {
        $TargetServer = (Connect-DbaInstance -SqlInstance $DestSqlInstance).ComputerNamePhysicalNetBIOS
    }
    catch {
        Write-Error "Failed to determine target server name with: $ExceptionMessage"
    }

    Write-Colour -Text "Target SQL Server host    : ", $TargetServer -ForegroundColor Yellow, Green

    $GetDbDisk = { param ( $Db )
        $DbDisk = Get-Partition -DriveLetter $Db.PrimaryFilePath.Split(':')[0] | Get-Disk
        return $DbDisk
    }

    $GetVolumeLabel = { param ( $Db )
        Write-Verbose "Target database drive letter = $Db.PrimaryFilePath.Split(':')[0]"
        $VolumeLabel = $(Get-Volume -DriveLetter $Db.PrimaryFilePath.Split(':')[0]).FileSystemLabel
        Write-Verbose "Target database windows volume label = <$VolumeLabel>"
        return $VolumeLabel
    }

    try {
        if ( $NoPsRemoting ) {
            $DestDisk = Invoke-Command -ScriptBlock $GetDbDisk -ArgumentList $DestDb
            $DestVolumeLabel = Invoke-Command -ScriptBlock $GetVolumeLabel -ArgumentList $DestDb
        }
        else {
            $DestDisk = Invoke-Command -ComputerName $TargetServer -ScriptBlock $GetDbDisk -ArgumentList $DestDb
            $DestVolumeLabel = Invoke-Command -ComputerName $TargetServer -ScriptBlock $GetVolumeLabel -ArgumentList $DestDb
        }
    }
    catch {
        $ExceptionMessage = $_.Exception.Message
        Write-Error "Failed to determine destination database disk with: $ExceptionMessage"
        Return
    }

    Write-Colour -Text "Target drive letter       : ", $DestDb.PrimaryFilePath.Split(':')[0] -ForegroundColor Yellow, Green

    try {
        $DestVolume = Get-PfaVolumes -Array $FlashArray | Where-Object { $_.serial -eq $DestDisk.SerialNumber } | Select-Object name

        if (!$DestVolume) {
            throw "Failed to determine destination FlashArray volume, check that source and destination volumes are on the SAME array"
        }
    }
    catch {
        $ExceptionMessage = $_.Exception.Message
        Write-Error "Failed to determine destination FlashArray volume with: $ExceptionMessage"
        Return
    }

    Write-Colour -Text "Target Pfa volume         : ", $DestVolume.name -ForegroundColor Yellow, Green

    $OfflineDestDisk = { param ( $DiskNumber, $Status )
        Set-Disk -Number $DiskNumber -IsOffline $Status
    }

    try {
        if ( $ForceDestDbOffline ) {
            $ForceDatabaseOffline = "ALTER DATABASE [$RefreshDatabase] SET OFFLINE WITH ROLLBACK IMMEDIATE"
            Invoke-DbaQuery -ServerInstance $DestSqlInstance -Database $RefreshDatabase -Query $ForceDatabaseOffline
        }
        else {
            $DestDb.SetOffline()
        }
    }
    catch {
        $ExceptionMessage = $_.Exception.Message
        Write-Error "Failed to offline database $Database with: $ExceptionMessage"
        Return
    }

    Write-Colour -Text "Target database           : ", "OFFLINE" -ForegroundColor Yellow, Green

    try {
        if ( $NoPsRemoting ) {
            Invoke-Command -ScriptBlock $OfflineDestDisk -ArgumentList $DestDisk.Number, $True
        }
        else {
            Invoke-Command -ComputerName $TargetServer -ScriptBlock $OfflineDestDisk -ArgumentList $DestDisk.Number, $True
        }
    }
    catch {
        $ExceptionMessage = $_.Exception.Message
        Write-Error "Failed to offline disk with : $ExceptionMessage"
        Return
    }

    Write-Colour -Text "Target windows disk       : ", "OFFLINE" -ForegroundColor Yellow, Green

    $StartCopyVolMs = Get-Date

    try {
        Write-Colour -Text "Source Pfa volume         : ", $SourceVolume -ForegroundColor Yellow, Green
        New-PfaVolume -Array $FlashArray -VolumeName $DestVolume.name -Source $SourceVolume -Overwrite
    }
    catch {
        $ExceptionMessage = $_.Exception.Message
        Write-Error "Failed to refresh test database volume with : $ExceptionMessage"
        Set-Disk -Number $DestDisk.Number -IsOffline $False
        $DestDb.SetOnline()
        Return
    }

    Write-Colour -Text "Volume overwrite          : ", "SUCCESSFUL" -ForegroundColor Yellow, Green
    $EndCopyVolMs = Get-Date
    Write-Colour -Text "Overwrite duration (ms)   : ", ($EndCopyVolMs - $StartCopyVolMs).TotalMilliseconds -Color Yellow, Green

    $SetVolumeLabel = { param ( $Db, $DestVolumeLabel )
        Set-Volume -DriveLetter $Db.PrimaryFilePath.Split(':')[0] -NewFileSystemLabel $DestVolumeLabel
    }

    try {
        if ( $NoPsRemoting ) {
            Invoke-Command -ScriptBlock $OfflineDestDisk -ArgumentList $DestDisk.Number, $False
            Invoke-Command -ScriptBlock $SetVolumeLabel -ArgumentList $DestDb, $DestVolumeLabel
        }
        else {
            Invoke-Command -ComputerName $TargetServer -ScriptBlock $OfflineDestDisk -ArgumentList $DestDisk.Number, $False
            Invoke-Command -ComputerName $TargetServer -ScriptBlock $SetVolumeLabel -ArgumentList $DestDb, $DestVolumeLabel
        }
    }
    catch {
        $ExceptionMessage = $_.Exception.Message
        Write-Error "Failed to online disk with : $ExceptionMessage"
        Return
    }

    Write-Colour -Text "Target windows disk       : ", "ONLINE" -ForegroundColor Yellow, Green

    try {
        $DestDb.SetOnline()
    }
    catch {
        $ExceptionMessage = $_.Exception.Message
        Write-Error "Failed to online database $Database with: $ExceptionMessage"
        Return
    }

    Write-Colour -Text "Target database           : ", "ONLINE" -ForegroundColor Yellow, Green

    if ( $ApplyDataMasks ) {
        Write-Host "Applying SQL Server dynamic data masks to $RefreshDatabase on SQL Server instance $DestSqlInstance" -ForegroundColor Yellow

        try {
            Invoke-DynamicDataMasking -SqlInstance $DestSqlInstance -Database $RefreshDatabase
            Write-Host "SQL Server dynamic data masking has been applied" -ForegroundColor Yellow
        }
        catch {
            $ExceptionMessage = $_.Exception.Message
            Write-Error "Failed to apply SQL Server dynamic data masks to $Database on $DestSqlInstance with: $ExceptionMessage"
            Return
        }
    }
    elseif ([System.IO.File]::Exists($StaticDataMaskFile)) {
        Write-Color -Text "Static data mask target   : ", $DestSqlInstance, " - ", $RefreshDatabase -Color Yellow, Green, Green, Green

        try {
            Invoke-StaticDataMasking -SqlInstance $DestSqlInstance -Database $RefreshDatabase -DataMaskFile $StaticDataMaskFile
            Write-Color -Text "Static data masking       : ", "APPLIED" -ForegroundColor Yellow, Green

        }
        catch {
            $ExceptionMessage = $_.Exception.Message
            Write-Error "Failed to apply static data masking to $Database on $DestSqlInstance with: $ExceptionMessage"
            Return
        }
    }

    Repair-DbaDbOrphanUser -SqlInstance $DestSqlInstance -Database $RefreshDatabase | Out-Null
    Write-Color -Text "Orphaned users            : ", "REPAIRED" -ForegroundColor Yellow, Green
}