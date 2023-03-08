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
        [string]$Alias = '*'
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

        foreach ($db_name in $databases) {
            $db_path = Join-Path $root $db_name
            if (-not (Test-Path $db_path)) {
                throw "Database '$db_name' not found."
            }
            $db = Get-ExchDatabase -name $db_name -ea SilentlyContinue
            Get-ChildItem $db_path -File -Filter "$Alias.cab" | % {
                $b_alias = [IO.Path]::GetFileNameWithoutExtension($_.Name)
                [pscustomobject]@{
                    DatabaseName  = $db_name
                    Alias         = $b_alias
                    FileName      = $_.Name
                    Size          = $_.Length
                    LastWriteTime = $_.LastWriteTime
                    BackupTime    = [DateTime]::ParseExact($b_alias, $script:backupNameFormat, $null, 'AssumeUniversal')
                    BusType       = $db.BusType
                    SerialNumber  = $db.SerialNumber
                }
            }
        }
    }

    end {

    }
}