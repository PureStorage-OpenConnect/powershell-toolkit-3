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
        [string]$Alias
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

            $shadows = @($add_shadow_format -f $alias)
            if ($db.EdbVolume.UniqueId -ne $db.LogVolume.UniqueId) {
                $shadows += $add_shadow_format -f "$($alias)_log"
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