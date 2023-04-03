#Requires -Version 5.1
#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

# Requires Exchange module
$exch_snapin = 'Microsoft.Exchange.Management.PowerShell.SnapIn'
if (-not (Get-PSSnapin -Name $exch_snapin -ea SilentlyContinue)) {
    throw "Exchange snap-in '$exch_snapin' not found. Add snap-in to the current session."
}

# Core functions
$script:PureProvider = [guid]'781C006A-5829-4A25-81E3-D5E43BD005AB'
$script:ExchangeWriter = [guid]'76FE1AC4-15F7-4BCD-987E-8E1ACB462FB7'
$script:backupNameFormat = 'MM_dd_yyyy__HH_mm_ss'
$script:supportedBusTypes = @('iSCSI', 'Fibre Channel')

class ExchangeBackup {
    [string]$DatabaseName
    [string]$Alias
    [datetime]$BackupDate
    [string[]]$BusType
    [string[]]$SerialNumber
    hidden [IO.FileInfo]$_file

    ExchangeBackup([IO.FileInfo]$file, [pscustomobject]$database) {
        $this.DatabaseName = $file.Directory.Name
        $this.Alias = [IO.Path]::GetFileNameWithoutExtension($file.Name)
        $this.BackupDate = [DateTime]::ParseExact($this.Alias, $script:backupNameFormat, $null, 'AssumeUniversal')
        $this.BusType = $database.BusType
        $this.SerialNumber = $database.SerialNumber
        $this._file = $file
    }
}

class ShadowWriter {
    [guid]$Id
    [string]$Name

    static [ShadowWriter[]]$InBoxWriters = @(
        [ShadowWriter]::new('E8132975-6F93-4464-A53E-1050253AE220', 'System Writer'),
        [ShadowWriter]::new('2A40FD15-DFCA-4AA8-A654-1F8C654603F6', 'IIS Config Writer'),
        [ShadowWriter]::new('35E81631-13E1-48DB-97FC-D5BC721BB18A', 'NPS VSS Writer'),
        [ShadowWriter]::new('BE000CBE-11FE-4426-9C58-531AA6355FC4', 'ASR Writer'),
        [ShadowWriter]::new('4969D978-BE47-48B0-B100-F328F07AC1E0', 'BITS Writer'),
        [ShadowWriter]::new('A6AD56C2-B509-4E6C-BB19-49D8F43532F0', 'WMI Writer'),
        [ShadowWriter]::new('AFBAB4A2-367D-4D15-A586-71DBB18F8485', 'Registry Writer'),
        [ShadowWriter]::new('59B1F0CF-90EF-465F-9609-6CA8B2938366', 'IIS Metabase Writer'),
        [ShadowWriter]::new('7E47B561-971A-46E6-96B9-696EEAA53B2A', 'MSMQ Writer (%s)'),
        [ShadowWriter]::new('CD3F2362-8BEF-46C7-9181-D62844CDC0B2', 'MSSearch Service Writer'),
        [ShadowWriter]::new('542DA469-D3E1-473C-9F4F-7847F01FC64F', 'COM+ REGDB Writer'),
        [ShadowWriter]::new('4DC3BDD4-AB48-4D07-ADB0-3BEE2926FD7F', 'Shadow Copy Optimization Writer'),
        [ShadowWriter]::new('D46BF321-FDBA-4A35-8EC3-454DF03BC86A', 'Sync Share Service VSS Writer'),
        [ShadowWriter]::new('41E12264-35D8-479B-8E5C-9B23D1DAD37E', 'Cluster Database'),
        [ShadowWriter]::new('1072AE1C-E5A7-4EA1-9E4A-6F7964656570', 'Cluster Shared Volume VSS Writer'),
        [ShadowWriter]::new('41DB4DBF-6046-470E-8AD5-D5081DFB1B70', 'Dedup Writer'),
        [ShadowWriter]::new('2707761b-2324-473d-88eb-eb007a359533', 'DFS Replication service writer'),
        [ShadowWriter]::new('d76f5a28-3092-4589-ba48-2958fb88ce29', 'FRS Writer'),
        [ShadowWriter]::new('66841cd4-6ded-4f4b-8f17-fd23f8ddc3de', 'Microsoft Hyper-V VSS Writer'),
        [ShadowWriter]::new('12CE4370-5BB7-4C58-A76A-E5D5097E3674', 'FSRM Writer'),
        [ShadowWriter]::new('DD846AAA-A1B6-42A8-AAF8-03DCB6114BFD', 'ADAM (instance%u) Writer'),
        [ShadowWriter]::new('886C43B1-D455-4428-A37F-4D6B9E43F50F', 'AD RMS Writer'),
        [ShadowWriter]::new('B2014C9E-8711-4C5C-A5A9-3CF384484757', 'NTDS'),
        [ShadowWriter]::new('772C45F8-AE01-4F94-940C-94961864ACAD', 'ADFS VSS Writer'),
        [ShadowWriter]::new('BE9AC81E-3619-421F-920F-4C6FEA9E93AD', 'Dhcp Jet Writer'),
        [ShadowWriter]::new('F08C1483-8407-4A26-8C26-6C267A629741', 'WINS Jet Writer'),
        [ShadowWriter]::new('6F5B15B5-DA24-4D88-B737-63063E3A1F86', 'Certificate Authority'),
        [ShadowWriter]::new('368753EC-572E-4FC7-B4B9-CCD9BDC624CB', 'TS Gateway Writer'),
        [ShadowWriter]::new('5382579C-98DF-47A7-AC6C-98A6D7106E09', 'TermServLicensing'),
        [ShadowWriter]::new('D61D61C8-D73A-4EEE-8CDD-F6F9786B7124', 'Task Scheduler Writer'),
        [ShadowWriter]::new('75DFB225-E2E4-4D39-9AC9-FFAFF65DDF06', 'VSS Express Writer Metadata Store Writer'),
        [ShadowWriter]::new('82CB5521-68DB-4626-83A4-7FC6F88853E9', 'WDS VSS Writer'),
        [ShadowWriter]::new('8D5194E1-E455-434A-B2E5-51296CCE67DF', 'WIDWriter'),
        [ShadowWriter]::new('0BADA1DE-01A9-4625-8278-69E735F39DD2', 'Performance Counters Writer'),
        [ShadowWriter]::new('A65FAA63-5EA8-4EBC-9DBD-A0C4DB26912A', 'SqlServerWriter')
    )

    ShadowWriter([guid]$id, [string]$name) {
        $this.Id = $id
        $this.Name = $name
    }
}

function Invoke-Diskshadow()
{
    [CmdletBinding()]
    param($script)

    if (-not (Test-Path ([IO.Path]::Combine($env:SystemRoot, 'system32', 'diskshadow.exe')))) {
        throw "diskshadow.exe not found."
    }
    $dsh = "./$([IO.Path]::GetRandomFileName())"
    $script | Set-Content $dsh -Confirm:$false
    try {
        DISKSHADOW /s "$dsh" | Write-Verbose
        if ($LASTEXITCODE -gt 0)
        {
            throw "DISKSHADOW command failed. Exit code $LASTEXITCODE."
        }
    }
    finally {
        Remove-Item $dsh -Confirm:$false -ea 'SilentlyContinue'
    }
}

function Get-ExchDatabase()
{
    [CmdletBinding()]
    param([string]$name)

    $local_copy = Get-MailboxDatabaseCopyStatus -Identity $name -Local
    $database_volume = Get-ExchVolume -path $local_copy.DatabaseVolumeName
    $bus_type = @($database_volume.BusType)
    $serial = @($database_volume.SerialNumber)
    $distinct = $local_copy.DatabaseVolumeName -ne $local_copy.LogVolumeName
    if ($distinct)
    {
        $log_volume = Get-ExchVolume -path $local_copy.LogVolumeName
        $serial += $log_volume.SerialNumber
        if ($database_volume.BusType -ne $log_volume.BusType) {
            $bus_type += $log_volume.BusType
        }
    }
    else {
        $log_volume = $database_volume
    }

    [pscustomobject]@{
        Name           = $name
        LocalCopy      = $local_copy
        DatabaseVolume = $database_volume.Path
        LogVolume      = $log_volume.Path
        Distinct       = $distinct
        BusType        = $bus_type
        SerialNumber   = $serial
    }
}

function Get-ExchVolume() {
    [CmdletBinding()]
    param([string]$path)

    $volume = Get-Volume -Path $path
    if (-not $volume) {
        throw "Volume '$path' not found."
    }

    $disk = $volume | Get-Partition | Get-Disk | ? FriendlyName -like 'PURE*'
    if (-not $disk) {
        throw "PURE Disk '$path' not found."
    }

    [pscustomobject]@{
        Path         = $volume.Path
        UniqueId     = $volume.UniqueId
        DriveLetter  = $volume.DriveLetter
        DiskNumber   = $disk.Number
        BusType      = $disk.BusType
        SerialNumber = $disk.SerialNumber
    }
}

function Get-ExchRoot()
{
    [CmdletBinding()]
    param()

    $provider = Get-Provider
    $root = Split-Path $provider.FilePath | Split-Path
    if (-not $root) {
        $root = Split-Path $provider.FilePath
    }
    return Join-Path $root 'Exchange'
}

function Get-Provider() 
{
    [CmdletBinding()]
    param()

    $name = 'pureprovider'
    $service = Get-CimInstance 'win32_service' -Filter "name='$name'" -Property 'name', 'pathName'
    if (-not $service) {
        throw "Provider '$name' not found."
    }
    return [pscustomobject]@{
        Name = $service.Name
        FilePath = $service.PathName.Trim('"')
    }
}

function Test-BusType() {
    [CmdletBinding()]
    param([string[]]$busType)
    
    -not @($busType | ? { $script:supportedBusTypes -notcontains $_ }).Count
}

# Get
<#
.SYNOPSIS
Gets a mailbox database backup.
.DESCRIPTION
Gets a mailbox database backup, a set of backups that match the specified criteria, or all backups if no filter is provided.
.PARAMETER DatabaseName
Specifies name(s) of the mailbox database(s).
.PARAMETER Alias
Specifies an alias of the backup. Wildcards are supported.
.PARAMETER SerialNumber
Specifies a serial number of the original PURE volume. Wildcards are supported.
.PARAMETER Latest
Specifies a number of latest backups to get. Selects backups after other filtering parameters are applied.
.PARAMETER After
Specifies a date for use as a filter for backup creation date. The backup should be create after this date.
.PARAMETER Before
Specifies a date for use as a filter for backup creation date. The backup should be create before this date.
.INPUTS
System.String
.EXAMPLE
PS> Get-ExchangeBackup

Gets all backups of all mailbox databases.
.EXAMPLE
PS> Get-ExchangeBackup -DatabaseName 'db_1708'

Gets database db_1708 backups.
.EXAMPLE
PS> Get-ExchangeBackup -DatabaseName 'db_1708' -Alias '03_27_2023__21_30_06'

Gets database db_1708 backup 03_27_2023__21_30_06.
.EXAMPLE
PS> Get-ExchangeBackup -Alias '03_27_2023__*'

Gets backups with an alias that matches the pattern 03_27_2023__*.
.EXAMPLE
PS> Get-ExchangeBackup -SerialNumber '*2B8C'

Gets backups with an original volume serial number that matches the pattern *2B8C.
.EXAMPLE
PS> Get-ExchangeBackup -Latest 1

Gets the most recent backup for every database.
.EXAMPLE
PS> Get-ExchangeBackup 'db_1708' -Latest 2

Gets two latest backups for database named db_1708.
.EXAMPLE
PS> Get-ExchangeBackup 'db_1708' -Before 'Friday, March 24, 2023'

Gets database db_1708 backups created before Friday, March 24, 2023.
.EXAMPLE
PS> Get-ExchangeBackup -After (Get-Date).AddDays(-30)

Gets backups created in last 30 days.
.EXAMPLE
PS> Get-MailboxDatabase 'db_1708' | Get-ExchangeBackup

Gets database db_1708 backups.
.EXAMPLE
PS> Get-MailboxDatabaseCopyStatus 'db_1708' -Local | Get-ExchangeBackup

Gets database db_1708 backups.
.NOTES
PURE volumes should be connected via iSCSI or Fiber Channel bus, no raw device mapping (RDM) is supported in case of virtual machine.
#>
function Get-ExchangeBackup()
{
    [CmdletBinding()]
    [OutputType('ExchangeBackup')]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string[]]$DatabaseName,
        [Parameter(ValueFromPipelineByPropertyName)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [string]$Alias,
        [Parameter(ValueFromPipelineByPropertyName)]
        [SupportsWildcards()]
        [ValidateNotNullOrEmpty()]
        [Alias('Serial')]
        [string]$SerialNumber,
        [ValidateRange(0, [int]::maxvalue)]
        [int]$Latest,
        [datetime]$After,
        [datetime]$Before
    )

    begin {
        $root = Get-ExchRoot
        if (-not (Test-Path $root)) {
           return
        }
    }

    process {
        $databases = if ($DatabaseName) {
            $DatabaseName
        }
        else {
            (Get-ChildItem $root -Directory).Name
        }

        foreach ($db_name in ($databases | sort -Unique)) {
            $db_path = Join-Path $root $db_name
            if (-not (Test-Path $db_path)) {
                throw "Database '$db_name' not found."
            }
            $db = $null
            try {
                $db = Get-ExchDatabase -name $db_name
            }
            catch {
                # ignore
            }
            if ($SerialNumber -and -not ($db.SerialNumber -like $SerialNumber)) {
                continue
            }
            if (-not $Alias) { $Alias = '*' }
            $backups = Get-ChildItem $db_path -File -Filter "$Alias.cab" | % {
                [ExchangeBackup]::new($_, $db)
            }
            if ($After) {
                $backups = $backups | ? BackupDate -gt $After
            }
            if ($Before) {
                $backups = $backups | ? BackupDate -lt $Before
            }
            if ($Latest) {
                $backups = $backups | sort BackupDate -Descending | select -First $Latest
            }
            $backups
        }
    }

    end {

    }
}

# Create
<#
.SYNOPSIS
Creates a new mailbox database backup.
.DESCRIPTION
Creates a new mailbox database backup using Volume Shadow Copy Service (VSS) Hardware Provider.
.PARAMETER DatabaseName
Specifies name(s) of the mailbox database(s).
.PARAMETER CopyBackup
Specifies that the copy backup should be performed. Unlike full backup, copy backup does not truncate the transaction log for the database. By default, full backup is performed.
.INPUTS
System.String
.EXAMPLE
PS> New-ExchangeBackup -DatabaseName 'db_1708'

Creates database db_1708 full backup.
.EXAMPLE
PS> New-ExchangeBackup 'db_1708' -CopyBackup

Creates database db_1708 copy backup.
.EXAMPLE
PS> 'db_1708' | New-ExchangeBackup

Creates database db_1708 full backup.
.EXAMPLE
PS> Get-MailboxDatabase 'db_1708' | New-ExchangeBackup

Creates database db_1708 full backup.
.EXAMPLE
PS> Get-MailboxDatabaseCopyStatus 'db_1708' -Local | New-ExchangeBackup

Creates database db_1708 full backup.
.EXAMPLE
PS> 'db_1708', 'ha_1809' | New-ExchangeBackup

Creates full backups for databases db_1708 and ha_1809.
.NOTES
PURE volumes should be connected via iSCSI or Fiber Channel bus, no raw device mapping (RDM) is supported in case of virtual machine.
#>
function New-ExchangeBackup()
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType('ExchangeBackup')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string[]]$DatabaseName,
        [switch]$CopyBackup
    )

    begin {
        function Get-BoundDatabase($copy) {
            $volumes = @($copy.DatabaseVolumeName, $copy.LogVolumeName)
            (Get-MailboxDatabaseCopyStatus -Local | ? {
                $_.Identity -ne $copy.Identity -and ($_.DatabaseVolumeName, $_.LogVolumeName | ? { $volumes -contains $_ })
            }).DatabaseName
        }

        $writer_exclude = [ShadowWriter]::InBoxWriters | % {
            "WRITER EXCLUDE {0:B}" -f $_.Id
        }

        $add_volume_format = "ADD VOLUME {0} ALIAS {1} Provider {$($script:PureProvider.ToString('B'))}"

        $root = Get-ExchRoot
        $alias = (Get-Date).ToUniversalTime().ToString($script:backupNameFormat)
    }

    process {
        foreach ($db_name in $DatabaseName) {
            if (-not $PSCmdlet.ShouldProcess("Database '$db_name'", 'Create backup')) {
                continue
            }
            $db = Get-ExchDatabase -name $db_name
            if (-not (Test-BusType -busType $db.BusType)) {
                throw "Bus type '$($db.BusType)' not supported. Expected value is '$script:supportedBusTypes'"
            }
            if ($db.LocalCopy.Status -ne 'mounted') {
                throw "Database '$db_name' copy (local) status '$($db.LocalCopy.Status)' is invalid. Expected value is 'mounted'"
            }
            $bound_db = Get-BoundDatabase $db.LocalCopy
            if ($bound_db) {
                throw "Database '$db_name' share the same volume with $bound_db."
            }

            $volumes = @($add_volume_format -f $db.DatabaseVolume, $alias)
            if ($db.Distinct) {
                $volumes += $add_volume_format -f $db.LogVolume, "$($alias)_log"
            }

            $db_path = Join-Path $root $db_name
            if (-not (Test-Path $db_path)) {
                New-Item $db_path -ItemType 'Directory' -Confirm:$false | Out-Null
            }
            $cab_path = Join-Path $db_path "$alias.cab"

            Invoke-Diskshadow -script 'RESET',
            'SET VERBOSE ON',
            'SET CONTEXT PERSISTENT',
            'SET OPTION TRANSPORTABLE',
            "SET METADATA `"$cab_path`"",
            $writer_exclude,
            $(if (-not $CopyBackup) {'BEGIN BACKUP'}),
            $volumes,
            'CREATE',
            'END BACKUP',
            'EXIT'

            [ExchangeBackup]::new((Get-Item $cab_path), $db)
        }
    }

    end {

    }
}

# Remove
<#
.SYNOPSIS
Deletes a mailbox database backup.
.DESCRIPTION
Deletes a mailbox database backup using Volume Shadow Copy Service (VSS) Hardware Provider.
.PARAMETER DatabaseName
Specifies name(s) of the mailbox database(s).
.PARAMETER Alias
Specifies an alias of the backup.
.PARAMETER Retain
Specifies a number of latest backups to retain.
.PARAMETER Force
Forces a backup deletion. If specified, errors that occur while deleting the backup are ignored.
.INPUTS
System.String
.OUTPUTS
None
.EXAMPLE
PS> Remove-ExchangeBackup -DatabaseName 'db_1708' -Alias '03_27_2023__21_30_06'

Deletes database db_1708 backup 03_27_2023__21_30_06.
.EXAMPLE
PS> Remove-ExchangeBackup -DatabaseName 'db_1708' -Alias '03_27_2023__21_30_06' -Confirm:$false

Deletes database db_1708 backup 03_27_2023__21_30_06 skipping confirmation prompt.
.EXAMPLE
PS> Remove-ExchangeBackup -DatabaseName 'db_1708' -Retain 2

Deletes old database db_1708 backups except tow most recent ones.
.EXAMPLE
PS> Get-ExchangeBackup -DatabaseName 'db_1708' -Before 'Friday, March 24, 2023' | Remove-ExchangeBackup

Deletes database db_1708 backups created before Friday, March 24, 2023.
.EXAMPLE
PS> Get-MailboxDatabase 'db_1708' | Remove-ExchangeBackup -Retain 1

Deletes database db_1708 backups except the most recent one.
.EXAMPLE
PS> 'db_1708', 'ha_1809' | Remove-ExchangeBackup -Retain 1

Deletes all backups of db_1708 and ha_1809 databases retaining the most recent backup of each.
.NOTES
PURE volumes should be connected via iSCSI or Fiber Channel bus, no raw device mapping (RDM) is supported in case of virtual machine.
#>
function Remove-ExchangeBackup()
{
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string[]]$DatabaseName,
        [Parameter(Mandatory, Position = 1, ValueFromPipelineByPropertyName, ParameterSetName = 'ByAlias')]
        [ValidateNotNullOrEmpty()]
        [string]$Alias,
        [Parameter(Mandatory, Position = 1, ParameterSetName = 'ByDate')]
        [ValidateRange(0, [int]::maxvalue)]
        [int]$Retain,
        [switch]$Force
    )

    begin {
        $root = Get-ExchRoot
        if (-not (Test-Path $root)) {
           throw 'Backup not found.'
        }
    }

    process {
        foreach ($db_name in $DatabaseName) {
            $db_path = Join-Path $root $db_name
            if (-not (Test-Path $db_path)) {
                throw "Database '$db_name' not found."
            }
            $backups = $null
            if ('ByAlias' -eq $PSCmdlet.ParameterSetName) {
                $cab_path = Join-Path $db_path "$Alias.cab"
                if (-not (Test-Path $cab_path)) {
                    throw "Database backup '$Alias' not found."
                }
                $cab_file = Get-Item $cab_path
                $backups = [ExchangeBackup]::new($cab_file, $null)
            }
            else {
                $backups = Get-ChildItem $db_path -File -Filter "*.cab" | % {
                    [ExchangeBackup]::new($_, $null)
                } | sort BackupDate | select -SkipLast $Retain
            }

            foreach ($backup in $backups){
                if (-not $PSCmdlet.ShouldProcess("Database '$db_name'", "Remove '$($backup.Alias)' backup")) {
                    continue
                }
                $rem_err = $null
                try {
                    Invoke-Diskshadow -script 'RESET',
                    'SET VERBOSE ON',
                    "LOAD METADATA `"$($backup._file.FullName)`"",
                    'IMPORT',
                    'DELETE SHADOWS SET %VSS_SHADOW_SET%',
                    'EXIT'
                }
                catch {
                    $rem_err = $_
                    if (-not $Force) {
                        throw
                    }
                }
                finally {
                    if (-not $rem_err -or $Force) {
                        Remove-Item $backup._file.FullName -Confirm:$false -Force:$Force
                    }
                }
            }
        }
    }

    end {

    }
}

# Restore
<#
.SYNOPSIS
Restores a mailbox database backup.
.DESCRIPTION
Restores a mailbox database backup to the original location using Volume Shadow Copy Service (VSS) Hardware Provider. The mailbox database will be dismounted during this process.
.PARAMETER DatabaseName
Specifies name(s) of the mailbox database(s).
.PARAMETER Alias
Specifies an alias of the backup.
.PARAMETER ExcludeLog
Specifies that the transaction log volume should not be restored. This option is not applicable if the database and transaction logs are on the same volume. If specified, the mailbox database will remain dismounted after the restore operation completes. By default, both the database volume and the transaction log volume are restored.
.PARAMETER Force
Forces a mailbox database mount. If specified, errors or warnings (including data loss warnings) that occur while mounting the mailbox database are ignored.
.INPUTS
System.String
.OUTPUTS
None
.EXAMPLE
PS> Restore-ExchangeBackup -DatabaseName 'db_1708' -Alias '03_27_2023__21_30_06'

Restores database db_1708 backup 03_27_2023__21_30_06.
.EXAMPLE
PS> Get-ExchangeBackup 'db_1708' -Latest 1 | Restore-ExchangeBackup

Restores the latest database db_1708 backup.
.EXAMPLE
PS> Get-ExchangeBackup 'db_1708' -Latest 1 | Restore-ExchangeBackup -Confirm:$false

Restores the latest database db_1708 backup skipping confirmation prompt.
.EXAMPLE
PS> Restore-ExchangeBackup -DatabaseName 'ha_1809' -Alias '03_27_2023__21_30_06' -ExcludeLog

Restores database ha_1809 backup 03_27_2023__21_30_06 excluding transaction log volume.
.EXAMPLE
PS> 'db_1708' | Restore-ExchangeBackup -Alias '03_27_2023__21_30_06'

Restores database db_1708 backup 03_27_2023__21_30_06.
.EXAMPLE
PS> Get-MailboxDatabase 'db_1708' | Restore-ExchangeBackup -Alias '03_27_2023__21_30_06'

Restores database db_1708 backup 03_27_2023__21_30_06.
.EXAMPLE
PS> Get-MailboxDatabaseCopyStatus 'db_1708' -Local | Restore-ExchangeBackup -Alias '03_27_2023__21_30_06'

Restores database db_1708 backup 03_27_2023__21_30_06.
.EXAMPLE
PS> 'db_1708', 'ha_1809' | Restore-ExchangeBackup -Alias '03_27_2023__21_30_06'

Restores database db_1708 and database ha_1809 backup 03_27_2023__21_30_06.
.EXAMPLE
PS> Get-ExchangeBackup | Out-GridView -PassThru | Restore-ExchangeBackup

Restores database backup selected by user.
.NOTES
PURE volumes should be connected via iSCSI or Fiber Channel bus, no raw device mapping (RDM) is supported in case of virtual machine.
#>
function Restore-ExchangeBackup()
{
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string[]]$DatabaseName,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Alias,
        [switch]$ExcludeLog,
        [switch]$Force
    )

    begin {

        function ShouldProcess()
        {
            $sp_msg = "Restore database '$db_name' from backup '$Alias'. " +
            "Database will be dismounted during this process."
            $PSCmdlet.ShouldProcess($sp_msg, "Are you sure you want to perform this action?`n$sp_msg", 'Confirm')
        }

        $add_shadow_format = 'ADD SHADOW %{0}%'

        $root = Get-ExchRoot
        if (-not (Test-Path $root)) {
           throw 'Backup not found.'
        }
    }

    process {
        foreach ($db_name in $DatabaseName) {
            if (-not (ShouldProcess)) {
                continue
            }
            $db_path = Join-Path $root $db_name
            if (-not (Test-Path $db_path)) {
                throw "Database '$db_name' not found."
            }
            $cab_path = Join-Path $db_path "$Alias.cab"
            if (-not (Test-Path $cab_path)) {
                throw "Database backup '$Alias' not found."
            }
            $db = Get-ExchDatabase -name $db_name
            if (-not (Test-BusType -busType $db.BusType)) {
                throw "Bus type '$($db.BusType)' not supported. Expected value is '$script:supportedBusTypes'."
            }
            if (-not $db.LocalCopy.ActiveCopy) {
                throw "Database '$db_name' copy (local) is not active."
            }

            $shadows = @($add_shadow_format -f $Alias)
            if ($db.Distinct) {
                if (-not $ExcludeLog) {
                    $shadows += $add_shadow_format -f "$($Alias)_log"
                }
            }
            elseif ($ExcludeLog) {
                $err_msg = "'$db_name' database and transaction logs are on the same volume. " +
                "'ExcludeLog' switch is not applicable."

                throw $err_msg
            }

            $resync_err = $null
            $mounted = $db.LocalCopy.Status -eq 'mounted'
            if ($mounted)
            {
                Dismount-Database -Identity $db_name -Confirm:$false
            }
            try {
                Set-MailboxDatabase -Identity $db_name -AllowFileRestore $true -Confirm:$false

                Invoke-Diskshadow -script 'RESET',
                'SET VERBOSE ON',
                "LOAD METADATA `"$cab_path`"",
                'IMPORT',
                'BEGIN RESTORE',
                $shadows,
                'RESYNC',
                'END RESTORE',
                'MASK %VSS_SHADOW_SET%',
                'EXIT'
            }
            catch {
                $resync_err = $_
                throw
            }
            finally {
                if ($mounted) {
                    if ($resync_err) {
                        $warning_msg = "Database '$db_name' restore operation failed. " +
                        "To prevent a possible data loss, the database will remain dismounted."

                        Write-Warning $warning_msg
                    }
                    elseif ($ExcludeLog) {
                        $warning_msg = "Database '$db_name' is dismounted. " +
                        "Perform transaction log manipulation, and then mount the database."

                        Write-Warning $warning_msg
                    }
                    else {
                        Mount-Database -Identity $db_name -Confirm:$false -AcceptDataLoss:$Force -Force:$Force
                    }
                }
            }
        }
    }

    end {

    }
}

# Expose
<#
.SYNOPSIS
Starts a mailbox database backup expose session.
.DESCRIPTION
Starts a mailbox database backup expose session using Volume Shadow Copy Service (VSS) Hardware Provider. If ScriptBlock parameter not specified, an interactive session starts.
.PARAMETER DatabaseName
Specifies name(s) of the mailbox database(s).
.PARAMETER Alias
Specifies an alias of the backup.
.PARAMETER ScriptBlock
Specifies commands to run. Enclose the commands in braces ({ }) to create a script block. The database name, alias and mount point are passed to the script as parameters.
.INPUTS
System.String
.OUTPUTS
None
.EXAMPLE
PS> Get-ExchangeBackup 'db_1708' -Latest 1 | Enter-ExchangeBackupExposeSession

Type 'exit' to end the expose session, cleanup and unexpose the shadow copy.
[db_1708]: PS C:\Program Files\Pure Storage\VSS\Exchange\db_1708\03_29_2023__12_24_15>> dir


    Directory: C:\Program Files\Pure Storage\VSS\Exchange\db_1708\03_29_2023__12_24_15


Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d----l         3/29/2023   7:43 AM                db


Type 'exit' to end the expose session, cleanup and unexpose the shadow copy.
[db_1708]: PS C:\Program Files\Pure Storage\VSS\Exchange\db_1708\03_29_2023__12_24_15>> exit

Starts an interactive session.
.EXAMPLE
PS> Get-ExchangeBackup 'db_1708' -Latest 1 | Enter-ExchangeBackupExposeSession -ScriptBlock {"DB Name: {0}`nAlias: {1}`nMount point: {2}" -f $args}

DB Name: db_1708
Alias: 03_29_2023__12_24_15
Mount point: C:\Program Files\Pure Storage\VSS\Exchange\db_1708\03_29_2023__12_24_15

Runs a script block.
.NOTES
PURE volumes should be connected via iSCSI or Fiber Channel bus, no raw device mapping (RDM) is supported in case of virtual machine.
#>
function Enter-ExchangeBackupExposeSession()
{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string[]]$DatabaseName,
        [Parameter(Mandatory, Position = 1, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Alias,
        [Parameter(Position = 2, ParameterSetName = 'ScriptBlock')]
        [ValidateNotNullOrEmpty()]
        [scriptblock]$ScriptBlock
    )

    begin {

    }

    process {
        foreach ($db_name in $DatabaseName) {
            if (-not $PSCmdlet.ShouldProcess("Database '$db_name'", "Enter '$Alias' backup expose session")) {
                continue
            }

            $mp_root_path = Mount-ExchangeBackup -DatabaseName $db_name -Alias $Alias -Confirm:$false
            try {
                $current_location = Get-Location
                Set-Location $mp_root_path
                try {
                    if ('ScriptBlock' -eq $PSCmdlet.ParameterSetName) {
                        Invoke-Command $ScriptBlock -Args $db_name, $Alias, $mp_root_path
                    }
                    else {
                        $cpr = $function:prompt
                        $pr_msg = "Type 'exit' to end the expose session, cleanup and unexpose the shadow copy."
                        function prompt { $pr_msg + "`n[$db_name]: " + $cpr.Invoke() }
                        try {
                            Invoke-Command {$Host.EnterNestedPrompt()}
                        }
                        finally {
                            $function:prompt = $cpr
                        }
                    }
                }
                finally {
                    Set-Location $current_location
                }
            }
            finally {
                Dismount-ExchangeBackup -DatabaseName $db_name -Alias $Alias -Confirm:$false
            }
        }
    }

    end {

    }
}


<#
.SYNOPSIS
Exposes a mailbox database backup.
.DESCRIPTION
Exposes a mailbox database backup as a mount point using Volume Shadow Copy Service (VSS) Hardware Provider.
.PARAMETER DatabaseName
Specifies name(s) of the mailbox database(s).
.PARAMETER Alias
Specifies an alias of the backup.
.INPUTS
System.String
.EXAMPLE
PS> Mount-ExchangeBackup -DatabaseName 'db_1708' -Alias '03_27_2023__21_30_06'

Exposes database db_1708 backup 03_27_2023__21_30_06.
.EXAMPLE
PS> Get-ExchangeBackup 'db_1708' -Latest 1 | Mount-ExchangeBackup

Exposes the latest database db_1708 backup.
.EXAMPLE
PS> 'db_1708' | Mount-ExchangeBackup -Alias '03_27_2023__21_30_06'

Exposes database db_1708 backup 03_27_2023__21_30_06.
.EXAMPLE
PS> Get-MailboxDatabase 'db_1708' | Mount-ExchangeBackup -Alias '03_27_2023__21_30_06'

Exposes database db_1708 backup 03_27_2023__21_30_06.
.EXAMPLE
PS> Get-MailboxDatabaseCopyStatus 'db_1708' -Local | Mount-ExchangeBackup -Alias '03_27_2023__21_30_06'

Exposes database db_1708 backup 03_27_2023__21_30_06.
.EXAMPLE
PS> 'db_1708', 'ha_1809' | Mount-ExchangeBackup -Alias '03_27_2023__21_30_06'

Exposes database db_1708 and database ha_1809 backup 03_27_2023__21_30_06.
.EXAMPLE
PS> Get-ExchangeBackup | Out-GridView -PassThru | Mount-ExchangeBackup

Exposes database backup selected by user.
.NOTES
PURE volumes should be connected via iSCSI or Fiber Channel bus, no raw device mapping (RDM) is supported in case of virtual machine.
#>
function Mount-ExchangeBackup()
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.IO.DirectoryInfo])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string[]]$DatabaseName,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Alias
    )

    begin {
        $expose_format = 'EXPOSE %{0}% "{1}"'

        $root = Get-ExchRoot
        if (-not (Test-Path $root)) {
           throw 'Backup not found.'
        }
    }

    process {
        foreach ($db_name in $DatabaseName) {
            if (-not $PSCmdlet.ShouldProcess("Database '$db_name'", "Expose '$Alias' backup")) {
                continue
            }
            $db_path = Join-Path $root $db_name
            if (-not (Test-Path $db_path)) {
                throw "Database '$db_name' not found."
            }
            $cab_path = Join-Path $db_path "$Alias.cab"
            if (-not (Test-Path $cab_path)) {
                throw "Database backup '$Alias' not found."
            }
            $db = Get-ExchDatabase -name $db_name
            if (-not (Test-BusType -busType $db.BusType)) {
                throw "Bus type '$($db.BusType)' not supported. Expected value is '$script:supportedBusTypes'."
            }
            $mp_root_path = Join-Path $db_path $Alias

            $db_mp_path = Join-Path $mp_root_path 'db'
            $expose = @($expose_format -f $Alias, $db_mp_path)
            if ($db.Distinct) {
                $log_mp_path = Join-Path $mp_root_path 'log'
                $expose += $expose_format -f "$($Alias)_log", $log_mp_path
            }

            New-Item $db_mp_path -ItemType 'Directory' -Confirm:$false | Out-Null
            try {
                if ($log_mp_path) {
                    New-Item $log_mp_path -ItemType 'Directory' -Confirm:$false | Out-Null
                }

                Invoke-Diskshadow -script 'RESET',
                'SET VERBOSE ON',
                "LOAD METADATA `"$cab_path`"",
                'IMPORT',
                $expose,
                'EXIT'

                Get-Item $mp_root_path
            }
            catch {
                Remove-Item $mp_root_path -Recurse -Confirm:$false
                throw
            }
        }
    }

    end {

    }
}

<#
.SYNOPSIS
Unexposes a mailbox database backup.
.DESCRIPTION
Unexposes a mailbox database backup using Volume Shadow Copy Service (VSS) Hardware Provider.
.PARAMETER DatabaseName
Specifies name(s) of the mailbox database(s).
.PARAMETER Alias
Specifies an alias of the backup.
.INPUTS
System.String
.OUTPUTS
None
.EXAMPLE
PS> Dismount-ExchangeBackup -DatabaseName 'db_1708' -Alias '03_27_2023__21_30_06'

Unexposes database db_1708 backup 03_27_2023__21_30_06.
.EXAMPLE
PS> $backup = Get-ExchangeBackup 'db_1708' -Latest 1

PS> $mount_point = $backup | Mount-ExchangeBackup

PS> $backup | Dismount-ExchangeBackup

Exposes the latest database db_1708 backup and then unexposes it.
.NOTES
PURE volumes should be connected via iSCSI or Fiber Channel bus, no raw device mapping (RDM) is supported in case of virtual machine.
#>
function Dismount-ExchangeBackup()
{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string[]]$DatabaseName,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Alias
    )

    begin {
        $unexpose_format = 'UNEXPOSE %{0}%'

        $root = Get-ExchRoot
        if (-not (Test-Path $root)) {
           throw 'Backup not found.'
        }
    }

    process {
        foreach ($db_name in $DatabaseName) {
            if (-not $PSCmdlet.ShouldProcess("Database '$db_name'", "Unexpose '$Alias' backup")) {
                continue
            }
            $db_path = Join-Path $root $db_name
            if (-not (Test-Path $db_path)) {
                throw "Database '$db_name' not found."
            }
            $cab_path = Join-Path $db_path "$Alias.cab"
            if (-not (Test-Path $cab_path)) {
                throw "Database backup '$Alias' not found."
            }
            $db = Get-ExchDatabase -name $db_name
            if (-not (Test-BusType -busType $db.BusType)) {
                throw "Bus type '$($db.BusType)' not supported. Expected value is '$script:supportedBusTypes'."
            }
            $mp_root_path = Join-Path $db_path $Alias

            $unexpose = @($unexpose_format -f $Alias)
            if ($db.Distinct) {
                $unexpose += $unexpose_format -f "$($Alias)_log"
            }

            try {
                Invoke-Diskshadow -script 'RESET',
                'SET VERBOSE ON',
                "LOAD METADATA `"$cab_path`"",
                $unexpose,
                'MASK %VSS_SHADOW_SET%',
                'EXIT'
            }
            finally {
                Remove-Item $mp_root_path -Recurse -Confirm:$false
            }
        }
    }

    end {

    }
}

# Declare exports
Export-ModuleMember -Function 'Get-ExchangeBackup'
Export-ModuleMember -Function 'New-ExchangeBackup'
Export-ModuleMember -Function 'Remove-ExchangeBackup'
Export-ModuleMember -Function 'Restore-ExchangeBackup'
Export-ModuleMember -Function 'Enter-ExchangeBackupExposeSession'
Export-ModuleMember -Function 'Mount-ExchangeBackup'
Export-ModuleMember -Function 'Dismount-ExchangeBackup'
