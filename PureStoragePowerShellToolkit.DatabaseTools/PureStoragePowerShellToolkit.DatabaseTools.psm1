<#
    ===========================================================================
    Release version: 3.0.0.1
    Revision information: Refer to the changelog.md file
    ---------------------------------------------------------------------------
    Maintained by:   FlashArray Integrations and Evangelsigm Team @ Pure Storage
    Organization:    Pure Storage, Inc.
    Filename:        PureStoragePowerShellToolkit.DatabaseTools.psm1
    Copyright:       (c) 2022 Pure Storage, Inc.
    Module Name:     PureStoragePowerShellToolkit.DatabaseTools.Dba
    Description:     PowerShell Script Module (.psm1)
    --------------------------------------------------------------------------
    Disclaimer:
    The sample module and documentation are provided AS IS and are not supported by the author or the author’s employer, unless otherwise agreed in writing. You bear
    all risk relating to the use or performance of the sample script and documentation. The author and the author’s employer disclaim all express or implied warranties
    (including, without limitation, any warranties of merchantability, title, infringement or fitness for a particular purpose). In no event shall the author, the author’s employer or anyone else involved in the creation, production, or delivery of the scripts be liable     for any damages whatsoever arising out of the use or performance of the sample script and     documentation (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss), even if     such person has been advised of the possibility of such damages.
    --------------------------------------------------------------------------
    Contributors: Rob "Barkz" Barker @purestorage, Robert "Q" Quimbey @purestorage, Mike "Chief" Nelson, Julian "Doctor" Cates, Marcel Dussil @purestorage - https://en.pureflash.blog/ , Craig Dayton - https://github.com/cadayton , Jake Daniels - https://github.com/JakeDennis, Richard Raymond - https://github.com/data-sciences-corporation/PureStorage , The dbatools Team - https://dbatools.io , many more Puritans, and all of the Pure Code community who provide excellent advice, feedback, & scripts now and in the future.
    ===========================================================================
#>

#Requires -Version 5
#Requires -Modules 'PureStoragePowerShellToolkit.FlashArray'
#Requires -Modules @{ ModuleName="dbatools"; ModuleVersion="1.1" }

#region Helper functions

function Convert-UnitOfSize {
    [CmdletBinding()]
    param (
        [parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        $Value,
        $To = 1GB,
        $From = 1,
        $Decimals = 2
    )

    process {
        return [math]::Round($Value * $From / $To, $Decimals)
    }
}
function Write-Color {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [string[]]
        $Text,

        [ConsoleColor[]]
        $ForegroundColor = ([console]::ForegroundColor),

        [ConsoleColor[]]
        $BackgroundColor = ([console]::BackgroundColor),

        [int]
        $Indent = 0,

        [int]
        $LeadingSpace = 0,

        [int]
        $TrailingSpace = 0,

        [switch]
        $NoNewLine
    )

    begin {
        $baseParams = @{
            ForegroundColor = [console]::ForegroundColor
            BackgroundColor = [console]::BackgroundColor
            NoNewline = $true
        }

        # Add leading lines
        Write-Host ("`n" * $LeadingSpace) @baseParams
    }

    process {
        # Add TABs before text
        Write-Host ("`t" * $Indent) @baseParams

        if ($PSBoundParameters.ContainsKey('ForegroundColor') -or $PSBoundParameters.ContainsKey('BackgroundColor')) {
            $writeParams = $baseParams.Clone()
            for ($i = 0; $i -lt $Text.Count; $i++) {

                if ($i -lt $ForegroundColor.Count) {
                    $writeParams['ForegroundColor'] = $ForegroundColor[$i]
                }

                if ($i -lt $BackgroundColor.Count) {
                    $writeParams['BackgroundColor'] = $BackgroundColor[$i]
                }

                Write-Host $Text[$i] @writeParams
            }
        } else {
            Write-Host $Text -NoNewline
        }

        if (-not $NoNewLine) {
            Write-Host
        }
    }

    end {
        if (-not $NoNewLine) {
            Write-Host ("`n" * $TrailingSpace) @baseParams
        }
    }
}

#endregion Helper functions

function Invoke-DynamicDataMasking {
    <#
.SYNOPSIS
A PowerShell function to apply data masks to database columns using the SQL Server dynamic data masking feature.

.DESCRIPTION
This function uses the information stored in the extended properties of a database:
sys.extended_properties.name = 'DATAMASK' to obtain the dynamic data masking function to apply
at column level. Columns of the following data type are currently supported:

- int
- bigint
- char
- nchar
- varchar
- nvarchar

Using the c_address column in the tpch customer table as an example, the DATAMASK extended property can be applied
to the column as follows:

exec sp_addextendedproperty
     @name = N'DATAMASK'
    ,@value = N'(FUNCTION = 'partial(0, "XX", 20)''
    ,@level0type = N'Schema', @level0name = 'dbo'
    ,@level1type = N'Table',  @level1name = 'customer'
    ,@level2type = N'Column', @level2name = 'c_address'
GO

.PARAMETER SqlInstance
Required. The SQL Server instance of the database that data masking is to be applied to.

.PARAMETER Database
Required. The name of the database that data masking is to be applied to.

.PARAMETER SqlCredential
Optional. Credential for the SQL Server instance.

.EXAMPLE
Invoke-DynamicDataMasking -SqlInstance Z-STN-WIN2016-A\DEVOPSDEV -Database tpch-no-compression

Applies data masks to database columns using the SQL Server dynamic data masking feature.

.EXAMPLE
Invoke-DynamicDataMasking -SqlInstance Z-STN-WIN2016-A\DEVOPSDEV -Database tpch-no-compression -SqlCredential (Get-Credential)

Applies data masks to database columns using the SQL Server dynamic data masking feature. Asks for SQL Server instance credentials.

.NOTES
Note that it has dependencies on the dbatools module which is installed with this module.
#>
	[CmdletBinding()]
    param(
        [parameter(mandatory = $true)][Sqlcollaborative.Dbatools.Parameter.DbaInstanceParameter] $SqlInstance,
        [parameter(mandatory = $true)][string] $Database,
		[parameter(mandatory = $false)][pscredential] $SqlCredential
    )

    $sql = @"
BEGIN
	DECLARE  @sql_statement nvarchar(1024)
	        ,@error_message varchar(1024)

	DECLARE apply_data_masks CURSOR FOR
	SELECT       'ALTER TABLE ' + tb.name + ' ALTER COLUMN ' + c.name +
			   + ' ADD MASKED WITH '
			   + CAST(p.value AS char) + ''')'
	FROM       sys.columns c
	JOIN       sys.types t
	ON         c.user_type_id = t.user_type_id
	LEFT JOIN  sys.index_columns ic
	ON         ic.object_id = c.object_id
	AND        ic.column_id = c.column_id
	LEFT JOIN  sys.indexes i
	ON         ic.object_id = i.object_id
	AND        ic.index_id  = i.index_id
	JOIN       sys.tables tb
	ON         tb.object_id = c.object_id
	JOIN       sys.extended_properties AS p
	ON         p.major_id   = tb.object_id
	AND        p.minor_id   = c.column_id
	AND        p.class      = 1
	WHERE      t.name IN ('int', 'bigint', 'char', 'nchar', 'varchar', 'nvarchar');

	OPEN apply_data_masks
	FETCH NEXT FROM apply_data_masks INTO @sql_statement;

	WHILE @@FETCH_STATUS = 0
	BEGIN
	    PRINT 'Applying data mask: ' + @sql_statement;

		BEGIN TRY
		    EXEC sp_executesql @stmt = @sql_statement
		END TRY
		BEGIN CATCH
		    SELECT @error_message = ERROR_MESSAGE();
			PRINT 'Application of data mask failed with: ' + @error_message;
		END CATCH;

		FETCH NEXT FROM apply_data_masks INTO @sql_statement
	END;

	CLOSE apply_data_masks
	DEALLOCATE apply_data_masks;
END;
"@

    Invoke-DbaQuery -Query $sql @PSBoundParameters
}

function Invoke-FlashArrayDbRefresh {
<#
.SYNOPSIS
A PowerShell function to refresh one or more SQL Server databases (the destination) from either a snapshot, volume, or database.

.DESCRIPTION
A PowerShell function to refresh one or more SQL Server databases either from:
- a snapshot specified by its name
- a volume specified by its name
- a source database directly
- a snapshot picked from a list of snapshots associated with the specified volume or volume the source database resides on

This function will detect and repair orpaned users in refreshed databases and optionally apply data masking, based on either:
- the dynamic data masking functionality available in SQL Server version 2016 onwards,
- static data masking as specified by JSON file

.PARAMETER DatabaseName
Required. The name of the database to refresh, note that it is assumed that source and target database(s) are named the same.

.PARAMETER SourceSnapshotName
Required. The name of the source snapshot.

.PARAMETER SourceVolumeName
Required. The name of the source volume.

.PARAMETER SourceSqlInstance
Required. The source SQL Server instance.

.PARAMETER SqlInstance
Required. This can be one or multiple SQL Server instance(s) that host the database(s) to be refreshed, in the case that the
function is invoked to refresh databases across more than one instance, the list of target instances should be
spedcified as an array.

.PARAMETER Endpoint
Required. FQDN or IP address representing the FlashArray that the volumes for the source and refresh target databases reside on.

.PARAMETER Credential
Optional. Credential for the FlashArray.

.PARAMETER PromptForSnapshot
Optional. This is an optional flag that if specified will result in a list of snapshots being displayed for the specified volume
or volume the source database resides on that the user can select one from.

.PARAMETER ForceOffline
Optional. Specifying this switch will cause refresh target databases for be forced offline via WITH ROLLBACK IMMEDIATE.

.PARAMETER ApplyDataMasks
Optional. Specifying this optional flag will cause data masks to be applied, in the sense that function
Invoke-DynamicDataMasking will be invoked from this function. For documentation on Invoke-DynamicDataMasking,
use the command Get-Help Invoke-DynamicDataMasking -Detailed.

.PARAMETER StaticDataMaskFile
Optional. Specifying this optional flag will cause static data masks to be applied, in the sense that function
Invoke-StaticDataMasking will be invoked from this function. For documentation on Invoke-StaticDataMasking,
use the command Get-Help Invoke-StaticDataMasking -Detailed.

.PARAMETER JobPollInterval
Optional. Interval at which background job status is poll. Default is 1 second.

.EXAMPLE
Invoke-FlashArrayDbRefresh -DatabaseName 'devops-db' -SourceSnapshotName 'devops.snap05' -SqlInstance 'devops-tst' -Endpoint 'myarray.mydomain.com'

Refresh 'devops-db' database on the 'devops-tst' SQL Server instance from 'devops.snap05' snapshot on the 'myarray.mydomain.com' FlashArray.

.EXAMPLE
Invoke-FlashArrayDbRefresh -DatabaseName 'devops-db' -Snapshot 'devops.snap05' -SqlInstance 'devops-tst' -Endpoint 'myarray.mydomain.com'

Refresh 'devops-db' database on the 'devops-tst' SQL Server instance from 'devops.snap05' snapshot on the 'myarray.mydomain.com' FlashArray.

.EXAMPLE
Invoke-FlashArrayDbRefresh -DatabaseName 'devops-db' -SourceVolumeName 'devops' -SqlInstance 'devops-tst' -Endpoint 'myarray.mydomain.com'

Refresh 'devops-db' database on the 'devops-tst' SQL Server instance from 'devops' volume on the 'myarray.mydomain.com' FlashArray.

.EXAMPLE
Invoke-FlashArrayDbRefresh -DatabaseName 'devops-db' -Volume 'devops' -SqlInstance 'devops-tst' -Endpoint 'myarray.mydomain.com'

Refresh 'devops-db' database on the 'devops-tst' SQL Server instance from 'devops' volume on the 'myarray.mydomain.com' FlashArray.

.EXAMPLE
Invoke-FlashArrayDbRefresh -DatabaseName 'devops-db' -Volume 'devops' -SqlInstance 'devops-tst' -Endpoint 'myarray.mydomain.com' -PromptForSnapshot

Refresh 'devops-db' database on the 'devops-tst' SQL Server instance from a snapshot selected from a list of snapshots
associated with the 'devops' volume on the 'myarray.mydomain.com' FlashArray.

.EXAMPLE
Invoke-FlashArrayDbRefresh -DatabaseName 'devops-db' -SourceSqlInstance 'devops-prod' -SqlInstance 'devops-tst' -Endpoint 'myarray.mydomain.com'

Refresh 'devops-db' database on the 'devops-tst' SQL Server instance from the volume on wich database on the 'devops-prod' SQL Server instance resides on.

.EXAMPLE
Invoke-FlashArrayDbRefresh -DatabaseName 'devops-db' -SourceSqlInstance 'devops-prod' -SqlInstance 'devops-tst' -Endpoint 'myarray.mydomain.com' -PromptForSnapshot

Refresh 'devops-db' database on the 'devops-tst' SQL Server instance from a snapshot selected from a list of snapshots
associated with the volume on wich database on the 'devops-prod' SQL Server instance resides on.

.EXAMPLE
Invoke-FlashArrayDbRefresh -DatabaseName 'devops-db' -Volume 'devops' -SqlInstance 'devops-tst01', 'devops-tst02' -Endpoint 'myarray.mydomain.com'

Refresh 'devops-db' database on the 'devops-tst01' and 'devops-tst02' SQL Server instances from 'devops' volume on the 'myarray.mydomain.com' FlashArray.

.EXAMPLE
Invoke-FlashArrayDbRefresh -DatabaseName 'devops-db' -Volume 'devops' -SqlInstance 'devops-tst' -Endpoint 'myarray.mydomain.com' -ForceOffline

Refresh 'devops-db' database on the 'devops-tst' SQL Server instance from 'devops' volume on the 'myarray.mydomain.com' FlashArray.
The database on the 'devops-tst' SQL Server instance is forced offline prior to its underlying volume being overwritten.

.NOTES
This cmdlet can utilize the global credential variable for FlashArray authentication. Set the credential variable by using the command Set-PfaCredential.

Known Restrictions
------------------
1. This function does not work for databases associated with failover cluster instances.
2. This function cannot be used to seed secondary replicas in availability groups using databases in the primary replica.
3. The function assumes that all database files and the transaction log reside on a single FlashArray volume.

Note that it has dependencies on the dbatools module which is installed with this module.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DatabaseName,
        [Parameter(Mandatory = $true, ParameterSetName = 'Snapshot')]
        [ValidateNotNullOrEmpty()]
        [Alias('Snapshot')]
        [string]$SourceSnapshotName,
        [Parameter(Mandatory = $true, ParameterSetName = 'Volume')]
        [ValidateNotNullOrEmpty()]
        [Alias('Volume')]
        [string]$SourceVolumeName,
        [Parameter(Mandatory = $true, ParameterSetName = 'Database')]
        [ValidateNotNull()]
        [DbaInstanceParameter]$SourceSqlInstance,
        [Parameter(ParameterSetName = 'Volume')]
        [Parameter(ParameterSetName = 'Database')]
        [switch]$PromptForSnapshot,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [DbaInstanceParameter[]]$SqlInstance,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Endpoint,
        [switch]$ForceOffline,
        [switch]$ApplyDataMask,
        [string]$StaticDataMaskFile,
        [int]$JobPollInterval = 1,
        [pscredential]$Credential = (Get-PfaCredential)
    )

    trap {
        $exceptionMessage = $_.Exception.Message
        Write-Error "Failed to $goal. $exceptionMessage"
        return
    }

    $ErrorActionPreference = 'Stop'

    $s = [int][math]::Floor([console]::WindowWidth / 3)
    $x = [console]::WindowWidth - $s
    $start = Get-Date

    $goal = "connect to FlashArray endpoint $Endpoint"
    $flashArray = Connect-Pfa2Array -Endpoint $Endpoint -Credential $Credential -IgnoreCertificateError
    try {
        Write-Color "FlashArray endpoint $Endpoint".PadRight($x), 'CONNECTED'.PadLeft($s) -ForegroundColor Yellow, Green

        if ($PSCmdlet.ParameterSetName -in 'Database', 'Volume') {
            if ($PSCmdlet.ParameterSetName -eq 'Database') {
                $goal = "connect to source SQL Server $SourceSqlInstance"
                $instance = Connect-DbaInstance -SqlInstance $SourceSqlInstance
                try {
                    Write-Color "Source SQL Server instance $instance".PadRight($x), 'CONNECTED'.PadLeft($s) -ForegroundColor Yellow, Green

                    $goal = "connect to source database $DatabaseName"
                    $database = Get-DbaDatabase -SqlInstance $instance -Database $DatabaseName

                    if ($null -eq $database) {
                        throw 'Database not found.'
                    }

                    $goal = 'connect to source server'
                    $sp = @{}
                    if (-not $SourceSqlInstance.IsLocalHost) {
                        $sp.Add('ComputerName', $SourceSqlInstance.ComputerName)
                    }
                    $cimSession = New-CimSession @sp
                    try {
                        Write-Color "Source server $($cimSession.ComputerName)".PadRight($x), 'CONNECTED'.PadLeft($s) -ForegroundColor Yellow, Green

                        $goal = 'get source disk'
                        $v = Get-Volume -FilePath $database.PrimaryFilePath -CimSession $cimSession
                        $disk = $v | Get-Partition -CimSession $cimSession | Get-Disk -CimSession $cimSession
                    }
                    finally {
                         Remove-CimSession $cimSession
                    }

                    $goal = 'get source volume'
                    $sn = $disk.SerialNumber
                    $source = Get-Pfa2Volume -Array $flashArray -Filter "serial='$sn'" -Limit 1

                    if (-not $source) {
                        throw 'Source volume not found.'
                    }
                }
                finally {
                    $instance | Disconnect-DbaInstance | Out-Null
                }
            }
            else {
                $goal = 'get source volume'
                $source = Get-Pfa2Volume -Array $flashArray -Name $SourceVolumeName
            }

            if ($PromptForSnapshot) {
                $goal = 'get source volume snapshot'
                $snapshots = Get-Pfa2VolumeSnapshot -Array $flashArray -SourceNames $source.name | foreach { $i = 1 } { [pscustomobject]@{'Number' = $i++; 'Name' = $_.name; 'Created' = $_.created } }

                if ($snapshots) {
                    $snapshots | Format-Table
                    [int]$num = Read-Host -Prompt 'Select snapshot number'
                    if ($num -gt 0) {
                        $snap = $snapshots[$num - 1]
                    }
                }
                if (-not $snap) {
                    throw 'No snapshot found\selected.'
                }
                $source = $snap
            }
        }
        else {
            $goal = 'get source snapshot'
            $source = Get-Pfa2VolumeSnapshot -Array $flashArray -Name $SourceSnapshotName
        }

        Write-Color "Get source $($source.name)".PadRight($x), 'DONE'.PadLeft($s) -ForegroundColor Yellow, Green
    }
    finally {
        Disconnect-Pfa2Array -Array $flashArray
    }

    $init = [scriptblock]::Create('function Write-Color {' + ${function:Write-Color} + "}`n`nImport-Module dbatools")

    $goal = 'start background job'
    $jobs = foreach ($di in $SqlInstance) {
        Start-Job -InitializationScript $init -ScriptBlock $function:CoreDbRefresh -ArgumentList $di.FullName, `
            $DatabaseName, `
            $Endpoint, `
            $Credential, `
            $source.name, `
            $ForceOffline.IsPresent, `
            $ApplyDataMask.IsPresent, `
            $StaticDataMaskFile, `
            $s, $x
    }
    Write-Color "Background job ($($jobs.Count))".PadRight($x), 'PROCESSING'.PadLeft($s) -ForegroundColor Yellow, Green

    $goal = 'process background job'
    $running = $jobs | where State -eq 'Running'
    while ($running) {
        $running | Receive-Job -ea Continue
        Start-Sleep $JobPollInterval
        $running = $jobs | where State -eq 'Running'
    }

    $goal = 'clear background job'
    $jobs | Receive-Job -ea Continue
    $jobs | Remove-Job

    Write-Color "Background job ($($jobs.Count))".PadRight($x), 'DONE'.PadLeft($s) -ForegroundColor Yellow, Green

    Write-Host ' '
    Write-Host '-------------------------------------------------------'           -ForegroundColor Green
    Write-Host ' '
    Write-Host 'D A T A B A S E      R E F R E S H      C O M P L E T E'           -ForegroundColor Green
    Write-Host ' '
    Write-Host '              Duration (s) = ' ((Get-Date) - $start).TotalSeconds  -ForegroundColor White
    Write-Host ' '
    Write-Host '-------------------------------------------------------'           -ForegroundColor Green
}

function CoreDbRefresh {
    param(
        [DbaInstanceParameter]$sqlInstance,
        [string]$databaseName,
        [string]$endpoint,
        [pscredential]$credential,
        [string]$source,
        [bool]$forceOffline,
        [bool]$applyDataMask,
        [string]$staticDataMaskFile,
        [int]$s, 
        [int]$x
    )

    trap {
        $exceptionMessage = $_.Exception.Message
        Write-Error "Failed to $goal. $exceptionMessage"
        return
    }

    $ErrorActionPreference = 'Stop'

    $goal = "connect to FlashArray endpoint $endpoint"
    $flashArray = Connect-Pfa2Array -Endpoint $endpoint -Credential $Credential -IgnoreCertificateError
    try {
        Write-Color "FlashArray endpoint $endpoint".PadRight($x), 'CONNECTED'.PadLeft($s) -ForegroundColor Yellow, Green

        $goal = "connect to destination SQL Server $sqlInstance"
        $instance = Connect-DbaInstance -SqlInstance $sqlInstance
        try {
            Write-Color "Destination SQL Server instance $instance".PadRight($x), 'CONNECTED'.PadLeft($s) -ForegroundColor Yellow, Green

            $goal = "connect to destination database $databaseName"
            $database = Get-DbaDatabase -SqlInstance $instance -Database $databaseName

            if ($null -eq $database) {
                throw 'Database not found.'
            }

            $goal = 'connect to destination server'
            $sp = @{}
            if (-not $sqlInstance.IsLocalHost) {
                $sp.Add('ComputerName', $sqlInstance.ComputerName)
            }
            $cimSession = New-CimSession @sp
            try {
                Write-Color "Destination server $($cimSession.ComputerName)".PadRight($x), 'CONNECTED'.PadLeft($s) -ForegroundColor Yellow, Green

                $goal = 'get destination disk'
                $v = Get-Volume -FilePath $database.PrimaryFilePath -CimSession $cimSession
                $disk = $v | Get-Partition -CimSession $cimSession | Get-Disk -CimSession $cimSession

                $goal = 'get destination volume'
                $sn = $disk.SerialNumber
                $volume = Get-Pfa2Volume -Array $flashArray -Filter "serial='$sn'" -Limit 1

                if (-not $volume) {
                    throw 'Volume not found.'
                }

                $goal = "offline destination database"
                if ($forceOffline) {
                    $database | Invoke-DbaQuery -Query "ALTER DATABASE [$databaseName] SET OFFLINE WITH ROLLBACK IMMEDIATE"
                    $dff = ' (force)'
                }
                else {
                    $database.SetOffline()
                }

                try {
                    Write-Color ('Destination database' + $dff).PadRight($x), 'OFFLINE'.PadLeft($s) -ForegroundColor Yellow, Green

                    $goal = 'offline destination disk'
                    $disk | Set-Disk -IsOffline $true -CimSession $cimSession
                    try {
                        Write-Color 'Destination disk'.PadRight($x), 'OFFLINE'.PadLeft($s) -ForegroundColor Yellow, Green

                        $start = Get-Date

                        $goal = 'overwrite volume'
                        New-Pfa2Volume -Array $flashArray -Name $volume.name -SourceName $source -Overwrite $true | Out-Null

                        Write-Color "Volume overwrite ($(((Get-Date) - $start).TotalSeconds) sec.)".PadRight($x), 'DONE'.PadLeft($s) -ForegroundColor Yellow, Green
                    }
                    finally {
                        $goal = 'online destination disk'
                        $disk | Set-Disk -IsOffline $false -CimSession $cimSession
                        Set-Volume -DriveLetter $v.DriveLetter -NewFileSystemLabel $v.FileSystemLabel -CimSession $cimSession

                        Write-Color 'Destination disk'.PadRight($x), 'ONLINE'.PadLeft($s) -ForegroundColor Yellow, Green
                    }
                }
                finally {      
                    $goal = "online destination database"
                    $database.SetOnline()

                    Write-Color 'Destination database'.PadRight($x), 'ONLINE'.PadLeft($s) -ForegroundColor Yellow, Green
                }
            }
            finally {
                 Remove-CimSession $cimSession
            }
        }
        finally {
            $instance | Disconnect-DbaInstance | Out-Null
        }
    }
    finally {
        Disconnect-Pfa2Array -Array $flashArray
    }

    if ($applyDataMask) {
        $goal = "apply dynamic data masking to $databaseName"
        Invoke-DynamicDataMasking -SqlInstance $instance -Database $databaseName | Out-Null

        Write-Color 'Dynamic data masking'.PadRight($x), 'DONE'.PadLeft($s) -ForegroundColor Yellow, Green
    }

    if ($staticDataMaskFile) {
        $goal = "apply static data masking to $databaseName"
        Invoke-StaticDataMasking -SqlInstance $instance -Database $databaseName -DataMaskFile $staticDataMaskFile | Out-Null

        Write-Color 'Static data masking'.PadRight($x), 'DONE'.PadLeft($s) -ForegroundColor Yellow, Green
    }

    $goal = 'repair orphaned users'
    Repair-DbaDbOrphanUser -SqlInstance $instance -Database $database | Out-Null

    Write-Color 'Repair orphaned users'.PadRight($x), 'DONE'.PadLeft($s) -ForegroundColor Yellow, Green
}

function Invoke-StaticDataMasking {
<#
.SYNOPSIS
A PowerShell function to statically mask data in char, varchar and/or nvarchar columns using a MD5 hashing function.

.DESCRIPTION
This PowerShell function uses as input a JSON file created by calling the New-DbaDbMaskingConfig PowerShell function.
Data in the columns specified in this file which are of the type char, varchar or nvarchar are envrypted using a MD5
hash.

.PARAMETER SqlInstance
Required. The SQL Server instance of the database that static data masking is to be applied to.

.PARAMETER Database
Required. The name of the database that static data masking is to be applied to.

.PARAMETER DataMaskFile
Required. Absolute path to the JSON file generated by invoking New-DbaDbMaskingConfig. The file can be subsequently editted by
hand to suit the data masking requirements of this function's user. Currently, static data masking is only supported for
columns with char, varchar, nvarchar, int and bigint data types.

.PARAMETER Table
Optional. Applies data masking only on specified tables, ignoring other tables in JSON file.

.PARAMETER SqlCredential
Optional. Credential for the SQL Server instance.

.EXAMPLE
Invoke-StaticDataMasking -SqlInstance Z-STN-WIN2016-A\DEVOPSDEV -Database tpch-no-compression -DataMaskFile 'C:\devops\tpch-no-compression.tables.json'

Statically masks data in columns specified by JSON file.

.EXAMPLE
Invoke-StaticDataMasking -SqlInstance Z-STN-WIN2016-A\DEVOPSDEV -Database tpch-no-compression -DataMaskFile 'C:\devops\tpch-no-compression.tables.json' -SqlCredential (Get-Credential)

Statically masks data in columns specified by JSON file. Asks for SQL Server instance credentials.

.NOTES
Note that it has dependencies on the dbatools module which is installed with this module.
#>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [parameter(mandatory = $true)] [Sqlcollaborative.Dbatools.Parameter.DbaInstanceParameter] $SqlInstance,
        [parameter(mandatory = $true)] [string] $Database,
        [parameter(mandatory = $true)] [string] $DataMaskFile,
        [parameter()] [pscredential] $SqlCredential,
        [parameter()] [string[]] $Table
    )

    $queryParams = @{
        SqlInstance = $SqlInstace
        Database = $Database
        QueryTimeout = 999999
    }

    if ($PSBoundParameters.ContainsKey('SqlCredential')) {
        $queryParams.Add('SqlCredential', $SqlCredential)
    }

    if ($DataMaskFile.ToString().StartsWith('http')) {
        $config = Invoke-RestMethod -Uri $DataMaskFile
    }
    else {
        $config = Get-Content -Path $DataMaskFile -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }

    foreach ($tabletest in $config.Tables) {
        if (($Table -and $tabletest.Name -notin $Table) -or -not $PSCmdlet.ShouldProcess("[$($tabletest.Name)]", 'Statically mask table')){
            continue
        }

        $columnExpressions = $tabletest.Columns.foreach{
            $column = $_
            $statement = switch($column.ColumnType) {
                {$_ -in 'varchar', 'char', 'nvarchar'} {
                    "SUBSTRING(CONVERT(VARCHAR, HASHBYTES('MD5', $($column.Name)), 1), 1, $($column.MaxValue))"
                }
                'int' {
                    "ABS(CHECKSUM(NEWID())) % 2147483647"
                }
                'bigint' {
                    "ABS(CHECKSUM(NEWID()))"
                }
                default {
                    Write-Error "$($column.ColumnType) is not supported, please remove the column $($column.Name) from the $($tabletest.Name) table"
                }
            }
            
            "$($column.Name) = $statement"
        }

        $queryParams['Query'] = "UPDATE $($tabletest.Name) SET $($columnExpressions -join ', ')"

        Write-Verbose "Statically masking table $($tabletest.Name) using $($queryParams['Query'])"

        Invoke-DbaQuery @queryParams
    }
}

function New-FlashArrayDbSnapshot {
    <#
.SYNOPSIS
A PowerShell function to create a FlashArray snapshot of the volume that a database resides on.

.DESCRIPTION
A PowerShell function to create a FlashArray snapshot of the volume that a database resides on, based in the
values of the following parameters:

.PARAMETER SqlInstance
Required. The SQL Server instance of the database that resides on a FlashArray volume.

.PARAMETER Database
Required. The name of the database that resides on a FlashArray volume.

.PARAMETER Endpoint
Required. FQDN or IP address of the FlashArray.

.PARAMETER SqlCredential
Optional. Credential for the SQL Server instance.

.PARAMETER Credential
Optional. Credential for the FlashArray.

.EXAMPLE
New-FlashArrayDbSnapshot -SqlInstance devops-prd -Database devops-db -Endpoint myarray.mydomain.com

Creates a snapshot of volume on the myarray.mydomain.com FlashArray that stores the devops-db database on the devops-prd instance.

.EXAMPLE
New-FlashArrayDbSnapshot -SqlInstance devops-prd -Database devops-db -Endpoint myarray.mydomain.com -Credential (Get-Credential)

Creates a snapshot of volume on the myarray.mydomain.com FlashArray that stores the devops-db database on the devops-prd instance. Asks for FlashArray credentials.

.EXAMPLE
New-FlashArrayDbSnapshot -SqlInstance devops-prd -Database devops-db -SqlCredential (Get-Credential) -Endpoint myarray.mydomain.com

Creates a snapshot of volume on the myarray.mydomain.com FlashArray that stores the devops-db database on the devops-prd instance. Asks for SQL Server instance credentials.

.NOTES
This cmdlet can utilize the global credential variable for FlashArray authentication. Set the credential variable by using the command Set-PfaCredential.

Known Restrictions
------------------
1. This function does not work for databases associated with failover cluster instances.
2. This function cannot be used to seed secondary replicas in availability groups using databases in the primary replica.
3. The function assumes that all database files and the transaction log reside on a single FlashArray volume.

Note that it has dependencies on the dbatools module which is installed with this module.
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
        $flashArray = Connect-Pfa2Array -EndPoint $EndPoint -Credential $Credential -IgnoreCertificateError
    }
    catch {
        $exceptionMessage = $_.Exception.Message
        Write-Error "Failed to connect to FlashArray endpoint $Endpoint with: $exceptionMessage"
        Return
    }

    try {
        Write-Color -Text 'FlashArray endpoint       : ', 'CONNECTED' -ForegroundColor Yellow, Green

        try {
            $destDb = Get-DbaDatabase @sqlParams -Database $Database
        }
        catch {
            $exceptionMessage = $_.Exception.Message
            Write-Error "Failed to connect to destination database $SqlInstance.$Database with: $exceptionMessage"
            Return
        }

        Write-Color -Text 'Target SQL Server instance: ', $SqlInstance, ' - ', 'CONNECTED' -ForegroundColor Yellow, Green, Green, Green
        Write-Color -Text 'Target windows drive      : ', $destDb.PrimaryFilePath.Split(':')[0] -ForegroundColor Yellow, Green

        try {
            $instance = Connect-DbaInstance @sqlParams
            $targetServer = $instance.ComputerNamePhysicalNetBIOS
            $instance | Disconnect-DbaInstance | Out-Null
        }
        catch {
            $exceptionMessage = $_.Exception.Message
            Write-Error "Failed to determine target server name with: $exceptionMessage"
            Return
        }

        Write-Color -Text 'Target SQL Server host    : ', $targetServer -ForegroundColor Yellow, Green

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

        Write-Color -Text 'Target disk serial number : ', $targetDisk.SerialNumber -ForegroundColor Yellow, Green

        try {
            $targetVolume = (Get-Pfa2Volume -Array $flashArray | Where-Object { $_.serial -eq $targetDisk.SerialNumber }).Name
        }
        catch {
            $exceptionMessage = $_.Exception.Message
            Write-Error "Failed to determine snapshot FlashArray volume with: $exceptionMessage"
            Return
        }

        $snapshotSuffix = '{0}-{1}-{2:HHmmss}' -f $SqlInstance.FullName.Replace('\', '-'), $Database, (Get-Date)
        Write-Color -Text 'Snapshot target Pfa volume: ', $targetVolume -ForegroundColor Yellow, Green
        Write-Color -Text 'Snapshot suffix           : ', $snapshotSuffix -ForegroundColor Yellow, Green

        try {
            New-Pfa2VolumeSnapshot -Array $flashArray -SourceNames $targetVolume -Suffix $snapshotSuffix
        }
        catch {
            $exceptionMessage = $_.Exception.Message
            Write-Error "Failed to create snapshot for target database FlashArray volume with: $exceptionMessage"
            Return
        }
    }
    finally {
        Disconnect-Pfa2Array -Array $flashArray
    }
}

# Declare exports
Export-ModuleMember -Function Invoke-DynamicDataMasking
Export-ModuleMember -Function Invoke-StaticDataMasking
Export-ModuleMember -Function New-FlashArrayDbSnapshot
Export-ModuleMember -Function Invoke-FlashArrayDbRefresh
# END
