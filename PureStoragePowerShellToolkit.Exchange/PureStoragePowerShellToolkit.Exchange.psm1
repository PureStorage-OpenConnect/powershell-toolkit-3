<#
    ===========================================================================
    Release version: 3.0.0
    Revision information: Refer to the changelog.md file
    ---------------------------------------------------------------------------
    Maintained by:   FlashArray Integrations and Evangelsigm Team @ Pure Storage
    Organization:    Pure Storage, Inc.
    Filename:        PureStoragePowerShellToolkit.Exchange.psm1
    Copyright:       (c) 2023 Pure Storage, Inc.
    Module Name:     PureStoragePowerShellToolkit.Exchange.Dba
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

#Requires -Version 5.1

$ErrorActionPreference = 'Stop'

# Core functions
$script:exch_snapin = 'Microsoft.Exchange.Management.PowerShell.SnapIn'
$script:PureProvider = [guid]'781C006A-5829-4A25-81E3-D5E43BD005AB'
$script:ExchangeWriter = [guid]'76FE1AC4-15F7-4BCD-987E-8E1ACB462FB7'
$script:backupNameFormat = 'MM_dd_yyyy__HH_mm_ss'
$script:supportedBusTypes = @('iSCSI', 'Fibre Channel')

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

function Invoke-Diskshadow() {
    <#
    .SYNOPSIS
    Runs Diskshadow commands.
    .DESCRIPTION
    Runs Diskshadow commands in a script mode.
    .PARAMETER Script
    Specifies commands to run.
    #>

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

function Get-ExchangeDatabase() {
    <#
    .SYNOPSIS
    Gets a mailbox database copy.
    .DESCRIPTION
    Gets a mailbox database local copy configuration.
    .PARAMETER DatabaseName
    Specifies name of the mailbox database.
    #>

    [CmdletBinding()]
    param([string]$name)

    $local_copy = Get-MailboxDatabaseCopyStatus -Identity $name -Local
    $database_volume = Get-ExchangeVolume -path $local_copy.DatabaseVolumeName
    $bus_type = @($database_volume.BusType)
    $serial = @($database_volume.SerialNumber)
    $distinct = $local_copy.DatabaseVolumeName -ne $local_copy.LogVolumeName
    if ($distinct)
    {
        $log_volume = Get-ExchangeVolume -path $local_copy.LogVolumeName
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

function Get-ExchangeVolume() {
    <#
    .SYNOPSIS
    Gets PURE volume.
    .DESCRIPTION
    Gets the volume for the file path specified.
    .PARAMETER Path
    Specifies the full path of a file.
    #>

    [CmdletBinding()]
    param([string]$path)

    $volume = Get-Volume -Path $path
    if (-not $volume) {
        throw "Volume '$path' not found."
    }

    $disk = $volume | Get-Partition | Get-Disk | Where-Object FriendlyName -like 'PURE*'
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

function Get-ExchangeRoot() {
    <#
    .SYNOPSIS
    Gets root directory for storing backups.
    .DESCRIPTION
    Gets fully qualified path to the root directory for storing backups metadata (.cab) files.
    #>

    [CmdletBinding()]
    param()

    $provider = Get-Provider
    $root = Split-Path $provider.FilePath | Split-Path
    if (-not $root) {
        $root = Split-Path $provider.FilePath
    }
    return Join-Path $root 'Exchange'
}

function Get-Provider() {
    <#
    .SYNOPSIS
    Gets PURE hardware provider service configuration.
    .DESCRIPTION
    Gets fully qualified path to the service binary file that implements the service.
    #>

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
    <#
    .SYNOPSIS
    Determines whether the I/O bus type is supported.
    .DESCRIPTION
    Determines whether the I/O bus type used by the disk is supported.
    .PARAMETER BusType
    The I/O bus type.
    #>

    [CmdletBinding()]
    param([string[]]$busType)
    
    -not @($busType | Where-Object { $script:supportedBusTypes -notcontains $_ }).Count
}

function Dismount-Pfa2ExchangeBackup() {
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
    Dismount-Pfa2ExchangeBackup -DatabaseName 'db_1708' -Alias '03_27_2023__21_30_06'

    Unexposes database db_1708 backup 03_27_2023__21_30_06.
    .EXAMPLE
    PS C:\>$backup = Get-Pfa2ExchangeBackup 'db_1708' -Latest 1

    PS C:\>$mount_point = $backup | Mount-Pfa2ExchangeBackup

    PS C:\>$backup | Dismount-Pfa2ExchangeBackup

    Exposes the latest database db_1708 backup and then unexposes it.
    .NOTES
    PURE volumes should be connected via iSCSI or Fiber Channel bus, no raw device mapping (RDM) is supported in case of virtual machine.
    #>

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
        # Requires Exchange module
        if (-not (Get-PSSnapin -Name $script:exch_snapin -ea SilentlyContinue)) {
            throw "Exchange snap-in '$script:exch_snapin' not found. Add snap-in to the current session."
        }

        $unexpose_format = 'UNEXPOSE %{0}%'

        $root = Get-ExchangeRoot
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
            $db = Get-ExchangeDatabase -name $db_name
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

function Enter-Pfa2ExchangeBackupExposeSession() {
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
    Get-Pfa2ExchangeBackup 'db_1708' -Latest 1 | Enter-Pfa2ExchangeBackupExposeSession

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
    Get-Pfa2ExchangeBackup 'db_1708' -Latest 1 | Enter-Pfa2ExchangeBackupExposeSession -ScriptBlock {"DB Name: {0}`nAlias: {1}`nMount point: {2}" -f $args}

    DB Name: db_1708
    Alias: 03_29_2023__12_24_15
    Mount point: C:\Program Files\Pure Storage\VSS\Exchange\db_1708\03_29_2023__12_24_15

    Runs a script block.
    .NOTES
    PURE volumes should be connected via iSCSI or Fiber Channel bus, no raw device mapping (RDM) is supported in case of virtual machine.
    #>

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
        # Requires Exchange module
        if (-not (Get-PSSnapin -Name $script:exch_snapin -ea SilentlyContinue)) {
            throw "Exchange snap-in '$script:exch_snapin' not found. Add snap-in to the current session."
        }
    }

    process {
        foreach ($db_name in $DatabaseName) {
            if (-not $PSCmdlet.ShouldProcess("Database '$db_name'", "Enter '$Alias' backup expose session")) {
                continue
            }

            $mp_root_path = Mount-Pfa2ExchangeBackup -DatabaseName $db_name -Alias $Alias -Confirm:$false
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
                Dismount-Pfa2ExchangeBackup -DatabaseName $db_name -Alias $Alias -Confirm:$false
            }
        }
    }

    end {

    }
}

function Get-Pfa2ExchangeBackup() {
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
    Get-Pfa2ExchangeBackup

    Gets all backups of all mailbox databases.
    .EXAMPLE
    Get-Pfa2ExchangeBackup -DatabaseName 'db_1708'

    Gets database db_1708 backups.
    .EXAMPLE
    Get-Pfa2ExchangeBackup -DatabaseName 'db_1708' -Alias '03_27_2023__21_30_06'

    Gets database db_1708 backup 03_27_2023__21_30_06.
    .EXAMPLE
    Get-Pfa2ExchangeBackup -Alias '03_27_2023__*'

    Gets backups with an alias that matches the pattern 03_27_2023__*.
    .EXAMPLE
    Get-Pfa2ExchangeBackup -SerialNumber '*2B8C'

    Gets backups with an original volume serial number that matches the pattern *2B8C.
    .EXAMPLE
    Get-Pfa2ExchangeBackup -Latest 1

    Gets the most recent backup of every database.
    .EXAMPLE
    Get-Pfa2ExchangeBackup 'db_1708' -Latest 2

    Gets two latest backups of database named db_1708.
    .EXAMPLE
    Get-Pfa2ExchangeBackup 'db_1708' -Before 'Friday, March 24, 2023'

    Gets database db_1708 backups created before Friday, March 24, 2023.
    .EXAMPLE
    Get-Pfa2ExchangeBackup -After (Get-Date).AddDays(-30)

    Gets backups created in last 30 days.
    .EXAMPLE
    Get-MailboxDatabase 'db_1708' | Get-Pfa2ExchangeBackup

    Gets database db_1708 backups.
    .EXAMPLE
    Get-MailboxDatabaseCopyStatus 'db_1708' -Local | Get-Pfa2ExchangeBackup

    Gets database db_1708 backups.
    .NOTES
    PURE volumes should be connected via iSCSI or Fiber Channel bus, no raw device mapping (RDM) is supported in case of virtual machine.
    #>

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
        # Requires Exchange module
        if (-not (Get-PSSnapin -Name $script:exch_snapin -ea SilentlyContinue)) {
            throw "Exchange snap-in '$script:exch_snapin' not found. Add snap-in to the current session."
        }

        $root = Get-ExchangeRoot
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

        foreach ($db_name in ($databases | Sort-Object -Unique)) {
            $db_path = Join-Path $root $db_name
            if (-not (Test-Path $db_path)) {
                throw "Database '$db_name' not found."
            }
            $db = $null
            try {
                $db = Get-ExchangeDatabase -name $db_name
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
                $backups = $backups | Where-Object BackupDate -gt $After
            }
            if ($Before) {
                $backups = $backups | Where-Object BackupDate -lt $Before
            }
            if ($Latest) {
                $backups = $backups | Sort-Object BackupDate -Descending | Select-Object -First $Latest
            }
            $backups
        }
    }

    end {

    }
}

function Mount-Pfa2ExchangeBackup() {
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
    Mount-Pfa2ExchangeBackup -DatabaseName 'db_1708' -Alias '03_27_2023__21_30_06'

    Exposes database db_1708 backup 03_27_2023__21_30_06.
    .EXAMPLE
    Get-Pfa2ExchangeBackup 'db_1708' -Latest 1 | Mount-Pfa2ExchangeBackup

    Exposes the latest database db_1708 backup.
    .EXAMPLE
    'db_1708' | Mount-Pfa2ExchangeBackup -Alias '03_27_2023__21_30_06'

    Exposes database db_1708 backup 03_27_2023__21_30_06.
    .EXAMPLE
    Get-MailboxDatabase 'db_1708' | Mount-Pfa2ExchangeBackup -Alias '03_27_2023__21_30_06'

    Exposes database db_1708 backup 03_27_2023__21_30_06.
    .EXAMPLE
    Get-MailboxDatabaseCopyStatus 'db_1708' -Local | Mount-Pfa2ExchangeBackup -Alias '03_27_2023__21_30_06'

    Exposes database db_1708 backup 03_27_2023__21_30_06.
    .EXAMPLE
    'db_1708', 'ha_1809' | Mount-Pfa2ExchangeBackup -Alias '03_27_2023__21_30_06'

    Exposes database db_1708 and database ha_1809 backup 03_27_2023__21_30_06.
    .EXAMPLE
    Get-Pfa2ExchangeBackup | Out-GridView -PassThru | Mount-Pfa2ExchangeBackup

    Exposes database backup selected by user.
    .NOTES
    PURE volumes should be connected via iSCSI or Fiber Channel bus, no raw device mapping (RDM) is supported in case of virtual machine.
    #>

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
        # Requires Exchange module
        if (-not (Get-PSSnapin -Name $script:exch_snapin -ea SilentlyContinue)) {
            throw "Exchange snap-in '$script:exch_snapin' not found. Add snap-in to the current session."
        }

        $expose_format = 'EXPOSE %{0}% "{1}"'

        $root = Get-ExchangeRoot
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
            $db = Get-ExchangeDatabase -name $db_name
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

function New-Pfa2ExchangeBackup() {
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
    New-Pfa2ExchangeBackup -DatabaseName 'db_1708'

    Creates database db_1708 full backup.
    .EXAMPLE
    New-Pfa2ExchangeBackup 'db_1708' -CopyBackup

    Creates database db_1708 copy backup.
    .EXAMPLE
    'db_1708' | New-Pfa2ExchangeBackup

    Creates database db_1708 full backup.
    .EXAMPLE
    Get-MailboxDatabase 'db_1708' | New-Pfa2ExchangeBackup

    Creates database db_1708 full backup.
    .EXAMPLE
    Get-MailboxDatabaseCopyStatus 'db_1708' -Local | New-Pfa2ExchangeBackup

    Creates database db_1708 full backup.
    .EXAMPLE
    'db_1708', 'ha_1809' | New-Pfa2ExchangeBackup

    Creates full backups of databases db_1708 and ha_1809.
    .NOTES
    PURE volumes should be connected via iSCSI or Fiber Channel bus, no raw device mapping (RDM) is supported in case of virtual machine.
    #>

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
        # Requires Exchange module
        if (-not (Get-PSSnapin -Name $script:exch_snapin -ea SilentlyContinue)) {
            throw "Exchange snap-in '$script:exch_snapin' not found. Add snap-in to the current session."
        }

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

        $root = Get-ExchangeRoot
        $alias = (Get-Date).ToUniversalTime().ToString($script:backupNameFormat)
    }

    process {
        foreach ($db_name in $DatabaseName) {
            if (-not $PSCmdlet.ShouldProcess("Database '$db_name'", 'Create backup')) {
                continue
            }
            $db = Get-ExchangeDatabase -name $db_name
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

function Remove-Pfa2ExchangeBackup() {
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
    Remove-Pfa2ExchangeBackup -DatabaseName 'db_1708' -Alias '03_27_2023__21_30_06'

    Deletes database db_1708 backup 03_27_2023__21_30_06.
    .EXAMPLE
    Remove-Pfa2ExchangeBackup -DatabaseName 'db_1708' -Alias '03_27_2023__21_30_06' -Confirm:$false

    Deletes database db_1708 backup 03_27_2023__21_30_06 skipping confirmation prompt.
    .EXAMPLE
    Remove-Pfa2ExchangeBackup -DatabaseName 'db_1708' -Retain 2

    Deletes old database db_1708 backups except two most recent ones.
    .EXAMPLE
    Get-Pfa2ExchangeBackup -DatabaseName 'db_1708' -Before 'Friday, March 24, 2023' | Remove-Pfa2ExchangeBackup

    Deletes database db_1708 backups created before Friday, March 24, 2023.
    .EXAMPLE
    Get-MailboxDatabase 'db_1708' | Remove-Pfa2ExchangeBackup -Retain 1

    Deletes database db_1708 backups except the most recent one.
    .EXAMPLE
    'db_1708', 'ha_1809' | Remove-Pfa2ExchangeBackup -Retain 1

    Deletes all backups of db_1708 and ha_1809 databases retaining the most recent backup of each.
    .NOTES
    PURE volumes should be connected via iSCSI or Fiber Channel bus, no raw device mapping (RDM) is supported in case of virtual machine.
    #>

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
        $root = Get-ExchangeRoot
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
                $backups = Get-ChildItem $db_path -File -Filter "*.cab" | ForEach-Object {
                    [ExchangeBackup]::new($_, $null)
                } | Sort-Object BackupDate | Select-Object -SkipLast $Retain
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

function Restore-Pfa2ExchangeBackup() {
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
    Restore-Pfa2ExchangeBackup -DatabaseName 'db_1708' -Alias '03_27_2023__21_30_06'

    Restores database db_1708 backup 03_27_2023__21_30_06.
    .EXAMPLE
    Get-Pfa2ExchangeBackup 'db_1708' -Latest 1 | Restore-Pfa2ExchangeBackup

    Restores the latest database db_1708 backup.
    .EXAMPLE
    Get-Pfa2ExchangeBackup 'db_1708' -Latest 1 | Restore-Pfa2ExchangeBackup -Confirm:$false

    Restores the latest database db_1708 backup skipping confirmation prompt.
    .EXAMPLE
    Restore-Pfa2ExchangeBackup -DatabaseName 'ha_1809' -Alias '03_27_2023__21_30_06' -ExcludeLog

    Restores database ha_1809 backup 03_27_2023__21_30_06 excluding transaction log volume.
    .EXAMPLE
    'db_1708' | Restore-Pfa2ExchangeBackup -Alias '03_27_2023__21_30_06'

    Restores database db_1708 backup 03_27_2023__21_30_06.
    .EXAMPLE
    Get-MailboxDatabase 'db_1708' | Restore-Pfa2ExchangeBackup -Alias '03_27_2023__21_30_06'

    Restores database db_1708 backup 03_27_2023__21_30_06.
    .EXAMPLE
    Get-MailboxDatabaseCopyStatus 'db_1708' -Local | Restore-Pfa2ExchangeBackup -Alias '03_27_2023__21_30_06'

    Restores database db_1708 backup 03_27_2023__21_30_06.
    .EXAMPLE
    'db_1708', 'ha_1809' | Restore-Pfa2ExchangeBackup -Alias '03_27_2023__21_30_06'

    Restores database db_1708 and database ha_1809 backup 03_27_2023__21_30_06.
    .EXAMPLE
    Get-Pfa2ExchangeBackup | Out-GridView -PassThru | Restore-Pfa2ExchangeBackup

    Restores database backup selected by user.
    .NOTES
    PURE volumes should be connected via iSCSI or Fiber Channel bus, no raw device mapping (RDM) is supported in case of virtual machine.
    #>

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
        # Requires Exchange module
        if (-not (Get-PSSnapin -Name $script:exch_snapin -ea SilentlyContinue)) {
            throw "Exchange snap-in '$script:exch_snapin' not found. Add snap-in to the current session."
        }

        function ShouldProcess() {
            $sp_msg = "Restore database '$db_name' from backup '$Alias'. " +
            "Database will be dismounted during this process."
            $PSCmdlet.ShouldProcess($sp_msg, "Are you sure you want to perform this action?`n$sp_msg", 'Confirm')
        }

        $add_shadow_format = 'ADD SHADOW %{0}%'

        $root = Get-ExchangeRoot
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
            $db = Get-ExchangeDatabase -name $db_name
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

# Declare exports
Export-ModuleMember -Function Get-Pfa2ExchangeBackup
Export-ModuleMember -Function New-Pfa2ExchangeBackup
Export-ModuleMember -Function Remove-Pfa2ExchangeBackup
Export-ModuleMember -Function Restore-Pfa2ExchangeBackup
Export-ModuleMember -Function Enter-Pfa2ExchangeBackupExposeSession
Export-ModuleMember -Function Mount-Pfa2ExchangeBackup
Export-ModuleMember -Function Dismount-Pfa2ExchangeBackup
# END
