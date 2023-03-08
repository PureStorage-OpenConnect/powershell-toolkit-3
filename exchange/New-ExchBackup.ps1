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

            Get-ExchBackup -DatabaseName $db_name -Alias $alias
        }
    }

    end {

    }
}