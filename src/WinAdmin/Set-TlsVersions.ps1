function Backup-RegistryKey {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([IO.FileInfo])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$KeyPath,
        [IO.FileInfo]$BackupFilePath,
        [switch]$Force,
        [Parameter(DontShow)]
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference'),
        [Parameter(DontShow)]
        $ConfirmPreference = $PSCmdlet.GetVariableValue('ConfirmPreference'),
        [Parameter(DontShow)]
        $WhatIfPreference = $PSCmdlet.GetVariableValue('WhatIfPreference')
    )

    if ($Force -and ($ConfirmPreference -gt 'Low')) {
        $ConfirmPreference = 'None'
    }

    $catption = 'Registry key backup'
    $description = "Backup registry key $KeyPath"
    $warning = "Are you sure you want to back up registry key $KeyPath"
    if ($PSCmdlet.ShouldProcess($description, $warning, $catption)) {
        if (-not $Force -and $BackupFilePath -and (Test-Path $BackupFilePath)) {
            $query = "Are you sure you want to overwrite registry backup file $($BackupFilePath.FullName)"

            if (-not $PSCmdlet.ShouldContinue($query, $caption)) {
                Write-Error 'Cancelled by user'
                return
            }
        }
        elseif (-not $BackupFilePath) {
            $BackupFilePath = New-TemporaryFile
        }

        Write-Host "Creating registry backup in $($BackupFilePath.FullName)"
        reg export $KeyPath $BackupFilePath.FullName /Y

        if ($LASTEXITCODE) {
            Write-Error 'Registry backup failed'
            return
        }

        $BackupFilePath
    }
}

function Disable-SecureChannelProtocol {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string]$ProtocolName,
        [Parameter(DontShow)]
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference'),
        [Parameter(DontShow)]
        $ConfirmPreference = $PSCmdlet.GetVariableValue('ConfirmPreference'),
        [Parameter(DontShow)]
        $WhatIfPreference = $PSCmdlet.GetVariableValue('WhatIfPreference')
    )

    process {
        Push-Location 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'

        try {
            if (-not ( Test-Path $ProtocolName )) {
                New-Item -Path $ProtocolName | Out-Null
            }

            if (Test-Path $ProtocolName) {
                Write-Verbose "Disable Client $ProtocolName"

                $path = Join-Path $ProtocolName 'Client'

                if (-not (Test-Path $path)) {
                    New-Item -Path  $path | Out-Null
                }

                if (Test-Path $path) {
                    Set-ItemProperty -Path $path -Value 0 -Type DWord -Name 'Enabled'
                    Set-ItemProperty -Path $path -Value 1 -Type DWord -Name 'DisabledByDefault'
                }

                Write-Verbose "Disable Server $ProtocolName"

                $path = Join-Path $ProtocolName 'Server'

                if (-not (Test-Path $path)) {
                    New-Item -Path $path | Out-Null
                }

                if (Test-Path $path) {
                    Set-ItemProperty -Path $path -Value 0 -Type DWord -Name 'Enabled'
                    Set-ItemProperty -Path $path -Value 1 -Type DWord -Name 'DisabledByDefault'
                }
            }
        }
        finally {
            Pop-Location
        }
    }
}

function Enable-SecureChannelProtocol {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string]$ProtocolName,
        [Parameter(DontShow)]
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference'),
        [Parameter(DontShow)]
        $ConfirmPreference = $PSCmdlet.GetVariableValue('ConfirmPreference'),
        [Parameter(DontShow)]
        $WhatIfPreference = $PSCmdlet.GetVariableValue('WhatIfPreference')
    )

    process {
        Push-Location 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'

        try {
            if (-not ( Test-Path $ProtocolName )) {
                New-Item -Path $ProtocolName | Out-Null
            }

            if (Test-Path $ProtocolName) {
                Write-Verbose "Enable Client $ProtocolName"

                $path = Join-Path $ProtocolName 'Client'

                if (-not (Test-Path $path)) {
                    New-Item -Path  $path | Out-Null
                }

                if (Test-Path $path) {
                    Set-ItemProperty $path -Value 1 -Type DWord -Name 'Enabled'
                    Set-ItemProperty $path -Value 0 -Type DWord -Name 'DisabledByDefault'
                }

                Write-Verbose "Enable Server $ProtocolName"

                $path = Join-Path $ProtocolName 'Server'

                if (-not (Test-Path $path)) {
                    New-Item -Path  $path | Out-Null
                }

                if (Test-Path $path) {
                    Set-ItemProperty $path -Value 1 -Type DWord -Name 'Enabled'
                    Set-ItemProperty $path -Value 0 -Type DWord -Name 'DisabledByDefault'
                }
            }
        }
        finally {
            Pop-Location
        }
    }
}

function Set-TlsVersions {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [switch]$SkipBackup,
        [IO.FileInfo]$BackupFilePath = 'protocols.reg',
        [switch]$Force,
        [Parameter(DontShow)]
        $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference'),
        [Parameter(DontShow)]
        $ConfirmPreference = $PSCmdlet.GetVariableValue('ConfirmPreference'),
        [Parameter(DontShow)]
        $WhatIfPreference = $PSCmdlet.GetVariableValue('WhatIfPreference')
    )

    if ($Force -and ($ConfirmPreference -gt 'Low')) {
        $ConfirmPreference = 'None'
    }

    $key = 'HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'

    if (-not $SkipBackup) {
        Backup-RegistryKey -KeyPath $key -BackupFilePath $BackupFilePath @PSBoundParameters | Out-Null
    }

    Disable-SecureChannelProtocol 'TLS 1.0'
    Disable-SecureChannelProtocol 'TLS 1.1'
    Enable-SecureChannelProtocol 'TLS 1.2'
    Enable-SecureChannelProtocol 'TLS 1.3'
}
