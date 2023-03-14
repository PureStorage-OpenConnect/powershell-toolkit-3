#Requires -Version 5.1
#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

# Requires Exchange module
$exch_snapin = 'Microsoft.Exchange.Management.PowerShell.SnapIn'
if (-not (Get-PSSnapin -Name $exch_snapin -ea SilentlyContinue)) {
    throw "Exchange snap-in '$exch_snapin' not found. Add snap-in to the current session."
}

# Core functions
$script:backupNameFormat = 'MM_dd_yyyy__HH_mm_ss'
$script:supportedBusTypes = @('iSCSI', 'Fibre Channel')

class ExchBackup {
    [string]$DatabaseName
    [string]$Alias
    [datetime]$BackupDate
    [string[]]$BusType
    [string[]]$SerialNumber
    hidden [IO.FileInfo]$_file

    ExchBackup([IO.FileInfo]$file, [pscustomobject]$database) {
        $this.DatabaseName = $database.Name
        $this.Alias = [IO.Path]::GetFileNameWithoutExtension($file.Name)
        $this.BackupDate = [DateTime]::ParseExact($this.Alias, $script:backupNameFormat, $null, 'AssumeUniversal')
        $this.BusType = $database.BusType
        $this.SerialNumber = $database.SerialNumber
        $this._file = $file
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
    $script | Set-Content $dsh
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

    $db = Get-MailboxDatabase -Identity $name
    if (-not ($db.EdbFilePath.IsLocalFull -and $db.LogFolderPath.IsLocalFull)) {
        throw "Path type not supported."
    }
    $edb_volume = Get-ExchVolume -path $db.EdbFilePath.PathName
    $log_volume = Get-ExchVolume -path $db.LogFolderPath.PathName
    $bus_type = @($edb_volume.BusType)
    if ($edb_volume.BusType -ne $log_volume.BusType) {
        $bus_type += $log_volume.BusType
    }
    $serial = @($edb_volume.SerialNumber)
    if ($edb_volume.SerialNumber -ne $log_volume.SerialNumber) {
        $serial += $log_volume.SerialNumber
    }
    [pscustomobject]@{
        Name         = $name
        Database     = $db
        EdbVolume    = $edb_volume
        LogVolume    = $log_volume
        BusType      = $bus_type
        SerialNumber = $serial
    }
}

function Get-ExchVolume()
{
    [CmdletBinding()]
    param([string]$path)

    $volumes = foreach ($volume in (Get-Volume -FilePath $path)) { 
        $volume | Get-Partition | Get-Disk |
        ? { $null -ne $_.Number -and $_.FriendlyName -like 'PURE*' } | 
        % {
            [pscustomobject]@{
                UniqueId     = $volume.UniqueId
                DriveLetter  = $volume.DriveLetter
                DiskNumber   = $_.Number
                BusType      = $_.BusType
                SerialNumber = $_.SerialNumber
                Volume       = $volume
                Disk         = $_
            }
        }
    }

    if (-not $volumes -or $volumes.Count -gt 1) {
        throw "Volume not found. File path '$path'."
    }

    return $volumes
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
function Get-ExchBackup()
{
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Identity')]
        [string[]]$DatabaseName,
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Alias = '*',
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
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
            $db = Get-ExchDatabase -name $db_name
            if ($SerialNumber -and -not ($db.SerialNumber -like $SerialNumber)) {
                continue
            }
            $backups = Get-ChildItem $db_path -File -Filter "$Alias.cab" | % {
                [ExchBackup]::new($_, $db)
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
function New-ExchBackup()
{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Identity')]
        [string[]]$DatabaseName
    )

    begin {
        $add_volume_format = 'ADD VOLUME {0} ALIAS {1} Provider {{781c006a-5829-4a25-81e3-d5e43bd005ab}}'

        $root = Get-ExchRoot
        if (-not (Test-Path $root)) {
            New-Item $root -ItemType 'Directory' | Out-Null
        }
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
            # TODO: Or database copy just should be active (ActiveCopy = $true).
            $db_status = Get-MailboxDatabaseCopyStatus -Id $db_name -Local
            if ($db_status.Status -ne 'mounted') {
                throw "Database '$db_name' copy status '$($db_status.Status)' is invalid. Expected value is 'mounted'"
            }

            $volumes = @($add_volume_format -f $db.EdbVolume.UniqueId, $alias)
            if ($db.EdbVolume.UniqueId -ne $db.LogVolume.UniqueId) {
                $volumes += $add_volume_format -f $db.LogVolume.UniqueId, "$($alias)_log"
            }

            $db_path = Join-Path $root $db_name
            if (-not (Test-Path $db_path)) {
                New-Item $db_path -ItemType 'Directory' | Out-Null
            }
            $cab_path = Join-Path $db_path "$alias.cab"

            Invoke-Diskshadow -script 'RESET',
            'SET VERBOSE ON',
            'SET CONTEXT PERSISTENT',
            'SET OPTION TRANSPORTABLE',
            "SET METADATA `"$cab_path`"",
            'BEGIN BACKUP',
            $volumes,
            'CREATE',
            'END BACKUP',
            'EXIT'

            [ExchBackup]::new((Get-Item $cab_path), $db)
        }
    }

    end {

    }
}

# Remove
function Remove-ExchBackup()
{
    [CmdletBinding(SupportsShouldProcess)]
    param(

    )

    # Remove .cab file
    # Remove pfa volume (needs pfa endpoint and credential).
    # Params to specify which backups to delete (older than 100 days, keep last 5 backups and etc.).
}

# Restore
function Restore-ExchBackup()
{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Identity')]
        [string[]]$DatabaseName,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Alias,
        [switch]$ExcludeLog
    )

    begin {
        $add_shadow_format = 'ADD SHADOW %{0}%'

        $root = Get-ExchRoot
        if (-not (Test-Path $root)) {
           throw 'Backup not found.'
        }
    }

    process {
        foreach ($db_name in $DatabaseName) {
            if (-not $PSCmdlet.ShouldProcess("Database '$db_name'", "Restore from '$Alias' backup")) {
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
            # TODO: Database copy should be active (ActiveCopy = $true).
            $db_status = Get-MailboxDatabaseCopyStatus -Id $db_name -Local
            if (-not $db_status.ActiveCopy) {
                throw "Database '$db_name' copy (local) is not active."
            }

            $shadows = @($add_shadow_format -f $Alias)
            if (-not $ExcludeLog -and $db.EdbVolume.UniqueId -ne $db.LogVolume.UniqueId) {
                $shadows += $add_shadow_format -f "$($Alias)_log"
            }

            Dismount-Database -Identity $db_name -Confirm:$false
            try {
                Set-MailboxDatabase -Identity $db_name -AllowFileRestore $true
                Invoke-Diskshadow -script 'RESET',
                'SET VERBOSE ON',
                "LOAD METADATA `"$cab_path`"",
                'IMPORT',
                'BEGIN RESTORE',
                $shadows,
                'RESYNC',
                'END RESTORE',
                'EXIT'
            }
            finally {
                Mount-Database -Identity $db_name
            }
        }
    }

    end {

    }
}

# Expose
function Enter-ExchBackupExposeSession()
{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Identity')]
        [string[]]$DatabaseName,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Alias,
        [Parameter(ParameterSetName='ScriptBlock')]
        [ValidateNotNullOrEmpty()]
        [scriptblock]$ScriptBlock
    )

    begin {
        $expose_format = 'EXPOSE %{0}% "{1}"'
        $unexpose_format = 'UNEXPOSE "{0}"'

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

            New-Variable 'mp_root_path' (Join-Path $db_path $Alias) -Option Constant 
            $db_mp_path = Join-Path $mp_root_path 'db'

            $expose = @($expose_format -f $alias, $db_mp_path)
            $unexpose = @($unexpose_format -f $db_mp_path)
            if ($db.EdbVolume.UniqueId -ne $db.LogVolume.UniqueId) {
                $log_mp_path = Join-Path $mp_root_path 'log'

                $expose += $expose_format -f "$($alias)_log", $log_mp_path
                $unexpose += $unexpose_format -f $log_mp_path
            }
            New-Variable 'c_unexpose' $unexpose -Option Constant 

            New-Item $db_mp_path -ItemType 'Directory' | Out-Null
            try {
                if ($log_mp_path) {
                    New-Item $log_mp_path -ItemType 'Directory' | Out-Null
                }

                Invoke-Diskshadow -script 'RESET',
                'SET VERBOSE ON',
                "LOAD METADATA `"$cab_path`"",
                'IMPORT',
                $expose,
                'EXIT'

                try {
                    New-Variable 'current_location' (Get-Location) -Option Constant 
                    Set-Location $mp_root_path
                    try {
                        if ('ScriptBlock' -eq $PSCmdlet.ParameterSetName) {
                            $argList = @($db_name, $db_mp_path)
                            if ($log_mp_path) {
                                $argList += $log_mp_path 
                            }

                            Invoke-Command -ScriptBlock $ScriptBlock -ArgumentList $argList
                        }
                        else {
                            New-Variable 'cpr' ($function:prompt) -Option Constant 
                            $pr_msg = "Type 'exit' to end the expose session, cleanup and unexpose the shadow copy."
                            function prompt { $pr_msg + "`n[$db_name]: " + $cpr.Invoke() }
                            try {
                                $HOST.EnterNestedPrompt();
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
                    Invoke-Diskshadow -script 'RESET',
                    'SET VERBOSE ON',
                    $c_unexpose,
                    'EXIT'
                }
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
Export-ModuleMember -Function 'Get-ExchBackup'
Export-ModuleMember -Function 'New-ExchBackup'
Export-ModuleMember -Function 'Remove-ExchBackup'
Export-ModuleMember -Function 'Restore-ExchBackup'
Export-ModuleMember -Function 'Enter-ExchBackupExposeSession'