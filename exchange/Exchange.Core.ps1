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
        Remove-Item $dsh -ea SilentlyContinue
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

    $volumes = Get-Volume -FilePath $path | % {$_} -PipelineVariable 'volume' | 
    Get-Partition | 
    Get-Disk | 
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