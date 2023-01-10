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
#Requires -Modules @{ ModuleName="PureStoragePowerShellSDK2"; ModuleVersion="2.16" }
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
                    Write-Error "$($column.ColumnType) is not supported, please remove the column $($column.Name) from the $($table.Name) table"
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
