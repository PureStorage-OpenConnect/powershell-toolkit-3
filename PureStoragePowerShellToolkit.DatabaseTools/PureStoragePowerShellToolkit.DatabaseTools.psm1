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

function Convert-Size {
    <#
    .SYNOPSIS
    Converts volume sizes from B to MB, MB, GB, TB.
    .DESCRIPTION
    Helper function
    Supporting function to handle conversions.
    .INPUTS
    ConvertFrom (Mandatory)
    ConvertTo (Mandatory)
    Value (Mandatory)
    Precision (Optional)
    .OUTPUTS
    Converted size of volume.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)][ValidateSet("Bytes", "KB", "MB", "GB", "TB")][String]$ConvertFrom,
        [Parameter(Mandatory = $true)][ValidateSet("Bytes", "KB", "MB", "GB", "TB")][String]$ConvertTo,
        [Parameter(Mandatory = $true)][Double]$Value,
        [Parameter(Mandatory = $false)][Int]$Precision = 4
    )

    switch ($ConvertFrom) {
        "Bytes" { $value = $Value }
        "KB" { $value = $Value * 1024 }
        "MB" { $value = $Value * 1024 * 1024 }
        "GB" { $value = $Value * 1024 * 1024 * 1024 }
        "TB" { $value = $Value * 1024 * 1024 * 1024 * 1024 }
    }

    switch ($ConvertTo) {
        "Bytes" { return $value }
        "KB" { $Value = $Value / 1KB }
        "MB" { $Value = $Value / 1MB }
        "GB" { $Value = $Value / 1GB }
        "TB" { $Value = $Value / 1TB }
    }

    return [Math]::Round($Value, $Precision, [MidPointRounding]::AwayFromZero)
}

function ConvertTo-Base64() {
<#
    .SYNOPSIS
	Converts source file to Base64.
    .DESCRIPTION
	Helper function
	Supporting function to handle conversions.
    .INPUTS
	Source (Mandatory)
    .OUTPUTS
	Converted source.
#>
    Param (
        [Parameter(Mandatory = $true)][String] $Source
    )
    return [Convert]::ToBase64String((Get-Content $Source -Encoding byte))
}
function Get-HypervStatus() {
    <#
    .SYNOPSIS
	Confirms that the HyperV role is installed ont he server.
    .DESCRIPTION
	Helper function
	Supporting function to ensure proper role is installed.
    .OUTPUTS
	Error on missing HyperV role.
    #>
    $hypervStatus = (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V).State
    if ($hypervStatus -ne "Enabled") {
        Write-Host "Hyper-V is not running. This cmdlet must be run on a Hyper-V host."
        break
    }
}
function Set-PfaCredential {
    <#
    .SYNOPSIS
    Sets credentials for FlashArray authentication.
    .DESCRIPTION
    Helper function
    Supporting function to handle connections.
    .OUTPUTS
    Nothing
    #>
    
    [CmdletBinding()]
    [OutputType([void])]

    param (
        [Parameter(Mandatory)]
        [System.Management.Automation.Credential()]
        [pscredential]$Credential
    )

    $script:Creds = $Credential
}

function Get-PfaCredential {
    <#
    .SYNOPSIS
    Gets credentials for FlashArray authentication.
    .DESCRIPTION
    Helper function
    Supporting function to handle connections.
    .OUTPUTS
    Credentials
    #>
    
    [OutputType([pscredential])]

    param ()

    Set-PfaCredential $script:Creds
    $script:Creds
}

function Clear-PfaCredential {
    <#
    .SYNOPSIS
    Clears credentials for FlashArray authentication.
    .DESCRIPTION
    Helper function
    Supporting function to handle connections.
    .OUTPUTS
    Nothing
    #>
    
    [OutputType([void])]

    $script:Creds = $null
}

function Get-SdkModule() {
    <#
    .SYNOPSIS
	Confirms that PureStoragePowerShellSDK version 2 module is loaded, present, or missing. If missing, it will download it and import. If internet access is not available, the function will error.
    .DESCRIPTION
	Helper function
	Supporting function to load required module.
    .OUTPUTS
	PureStoragePowerShellSDK version 2 module.
    #>

    $m = "PureStoragePowerShellSDK2"
    # If module is imported, continue
    if (Get-Module | Where-Object { $_.Name -eq $m }) {
    }
    else {
        # If module is not imported, but available on disk, then import
        if (Get-InstalledModule | Where-Object { $_.Name -eq $m }) {
            Import-Module $m -ErrorAction SilentlyContinue
        }
        else {
            # If module is not imported, not available on disk, then install and import
            if (Find-Module -Name $m | Where-Object { $_.Name -eq $m }) {
                Write-Warning "The $m module does not exist."
                Write-Host "We will attempt to install the module from the PowerShell Gallery. Please wait..."
                Install-Module -Name $m -Force -ErrorAction SilentlyContinue -Scope CurrentUser
                Import-Module $m -ErrorAction SilentlyContinue
            }
            else {
                # If module is not imported, not available on disk, and we cannot access it online, then abort
                Write-Host "Module $m not imported, not available on disk, and we are not able to download it from the online gallery... Exiting."
                EXIT 1
            }
        }
    }
}

function New-FlashArrayReportPieChart() {
<#
    .SYNOPSIS
	Creates graphic pie chart .png image file for use in report.
    .DESCRIPTION
	Helper function
	Supporting function to create a pie chart.
    .OUTPUTS
	piechart.png.
#>
    Param (
        [string]$FileName,
        [float]$SnapshotSpace,
        [float]$VolumeSpace,
        [float]$CapacitySpace
    )

    [void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    [void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.DataVisualization")

    $chart = New-Object System.Windows.Forms.DataVisualization.charting.chart
    $chart.Width = 700
    $chart.Height = 500
    $chart.Left = 10
    $chart.Top = 10

    $chartArea = New-Object System.Windows.Forms.DataVisualization.charting.chartArea
    $chart.chartAreas.Add($chartArea)
    [void]$chart.Series.Add("Data")

    $legend = New-Object system.Windows.Forms.DataVisualization.charting.Legend
    $legend.Name = "Legend"
    $legend.Font = "Verdana"
    $legend.Alignment = "Center"
    $legend.Docking = "top"
    $legend.Bordercolor = "#FE5000"
    $legend.Legendstyle = "row"
    $chart.Legends.Add($legend)

    $datapoint = New-Object System.Windows.Forms.DataVisualization.charting.DataPoint(0, $SnapshotSpace)
    $datapoint.AxisLabel = "SnapShots " + "(" + $SnapshotSpace + " MB)"
    $chart.Series["Data"].Points.Add($datapoint)

    $datapoint = New-Object System.Windows.Forms.DataVisualization.charting.DataPoint(0, $VolumeSpace)
    $datapoint.AxisLabel = "Volumes " + "(" + $VolumeSpace + " GB)"
    $chart.Series["Data"].Points.Add($datapoint)

    $chart.Series["Data"].chartType = [System.Windows.Forms.DataVisualization.charting.SerieschartType]::Doughnut
    $chart.Series["Data"]["DoughnutLabelStyle"] = "Outside"
    $chart.Series["Data"]["DoughnutLineColor"] = "#FE5000"

    $Title = New-Object System.Windows.Forms.DataVisualization.charting.Title
    $chart.Titles.Add($Title)
    $chart.SaveImage($FileName + ".png", "png")
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
Required. The database that data masking is to be applied to.

.PARAMETER SqlCredential
Optional. SQL Server credentials.

.EXAMPLE
Invoke-DynamicDataMasking -SqlInstance Z-STN-WIN2016-A\DEVOPSDEV -Database tpch-no-compression

.NOTES
Note that it has dependencies on the dbatools and PureStoragePowerShellSDK  modules which are installed as part of this module.
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
    elseif ($staticDataMaskFile) {
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
Required. The database that static data masking is to be applied to.

.PARAMETER DataMaskFile
Required. Absolute path to the JSON file generated by invoking New-DbaDbMaskingConfig. The file can be subsequently editted by
hand to suit the data masking requirements of this function's user. Currently, static data masking is only supported for columns with char, varchar, nvarchar, int and bigint data types.

.PARAMETER SqlCredential
Optional. SQL Server credentials.

.EXAMPLE
Invoke-StaticDataMasking -SqlInstance  Z-STN-WIN2016-A\DEVOPSDEV -Database tpch-no-compression -DataMaskFile 'C:\Users\devops\Documents\tpch-no-compression.tables.json'

.NOTES
Note that it has dependencies on the dbatools module which are installed with this module.
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

.PARAMETER Database
Required. The name of the database to refresh, note that it is assumed that source and target database(s) are named the same.

.PARAMETER SqlInstance
Required. This can be one or multiple SQL Server instance(s) that host the database(s) to be refreshed, in the case that the
function is invoked  to refresh databases  across more than one instance, the list of target instances should be
spedcified as an array of strings, otherwise a single string representing the target instance will suffice.

.PARAMETER Endpoint
Required. The IP address representing the FlashArray that the volumes for the source and refresh target databases reside on.

.PARAMETER SqlCredential
Optional. SQL Server credentials.

.PARAMETER SqlCredential
Optional. FlashArray credentials.

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
        Write-Color -Text 'FlashArray endpoint       : ', 'CONNECTED' -Color Yellow, Green

        try {
            $destDb = Get-DbaDatabase @sqlParams -Database $Database
        }
        catch {
            $exceptionMessage = $_.Exception.Message
            Write-Error "Failed to connect to destination database $SqlInstance.$Database with: $exceptionMessage"
            Return
        }

        Write-Color -Text 'Target SQL Server instance: ', $SqlInstance, ' - ', 'CONNECTED' -Color Yellow, Green, Green, Green
        Write-Color -Text 'Target windows drive      : ', $destDb.PrimaryFilePath.Split(':')[0] -Color Yellow, Green

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

        Write-Color -Text 'Target disk serial number : ', $targetDisk.SerialNumber -Color Yellow, Green

        try {
            $targetVolume = (Get-Pfa2Volume -Array $flashArray | Where-Object { $_.serial -eq $targetDisk.SerialNumber }).Name
        }
        catch {
            $exceptionMessage = $_.Exception.Message
            Write-Error "Failed to determine snapshot FlashArray volume with: $exceptionMessage"
            Return
        }

        $snapshotSuffix = '{0}-{1}-{2:HHmmss}' -f $SqlInstance.FullName.Replace('\', '-'), $Database, (Get-Date)
        Write-Color -Text 'Snapshot target Pfa volume: ', $targetVolume -Color Yellow, Green
        Write-Color -Text 'Snapshot suffix           : ', $snapshotSuffix -Color Yellow, Green

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

# Declare exports
Export-ModuleMember -Function Invoke-DynamicDataMasking
Export-ModuleMember -Function Invoke-StaticDataMasking
Export-ModuleMember -Function New-FlashArrayDbSnapshot
Export-ModuleMember -Function Invoke-FlashArrayDbRefresh
# END
