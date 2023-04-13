<#
    ===========================================================================
    Release version: 3.0.0
    Revision information: Refer to the changelog.md file
    ---------------------------------------------------------------------------
    Maintained by:   FlashArray Integrations and Evangelsigm Team @ Pure Storage
    Organization:    Pure Storage, Inc.
    Filename:        PureStoragePowerShellToolkit.WindowsAdministration.psm1
    Copyright:       (c) 2023 Pure Storage, Inc.
    Module Name:     PureStoragePowerShellToolkit.WindowsAdministration
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

function Get-FlashArraySerialNumbers() {
    <#
    .SYNOPSIS
    Retrieves FlashArray disk serial numbers connected to the host.
    .DESCRIPTION
    Cmdlet retrieves disk serial numbers that are associated to Pure FlashArrays.
    .PARAMETER CimSession
    Optional. A CimSession or computer name. CIM session may be reused.
    .INPUTS
    CimSession is optional.
    .OUTPUTS
    Outputs serial numbers of FlashArrays devices.
    .EXAMPLE
    Get-FlashArraySerialNumbers

    Returns serial number information on Pure FlashArray disk devices connected to the host.

    .EXAMPLE
    Get-FlashArraySerialNumbers -CimSession 'myComputer'

    Returns serial number information on Pure FlashArray disk devices connected to 'myComputer' with current credentials.

    .EXAMPLE
    $session = New-CimSession 'myComputer' -Credential (Get-Credential)
    Get-FlashArraySerialNumbers -CimSession $session
    Get-HostBusAdapter -CimSession $session

    Returns serial number information on Pure FlashArray disk devices and host bus adapter 
    with previously created CIM session.

    .EXAMPLE
    Get-FlashArraySerialNumbers -CimSession (New-CimSession 'myComputer' -Credential $Creds)

    Returns serial number information on Pure FlashArray disk devices connected to 'myComputer'
    with credentials stored in variable $Creds.

    .EXAMPLE
    Get-FlashArraySerialNumbers -CimSession (New-CimSession 'myComputer' -Credential (Get-Secret admin))

    Returns serial number information on Pure FlashArray disk devices connected to 'myComputer'
    with credentials stored in a secret vault.

    .EXAMPLE
    Get-FlashArraySerialNumbers -CimSession (New-CimSession 'myComputer' -Credential (Get-Credential))

    Returns serial number information on Pure FlashArray disk devices connected to 'myComputer'. Asks for credentials.

    .EXAMPLE
    'myComputer' | Get-FlashArraySerialNumbers

    Returns serial number information on Pure FlashArray disk devices connected to 'myComputer' with current credentials.

    .EXAMPLE
    $session = New-CimSession 'myComputer' -Credential (Get-Credential)
    $session | Get-FlashArraySerialNumbers

    Returns serial number information on Pure FlashArray disk devices with previously created CIM session.

    .EXAMPLE
    'myComputer01', 'myComputer02' | Get-FlashArraySerialNumbers

    Returns serial number information on Pure FlashArray disk devices connected to 'myComputer01' and 'myComputer02' with current credentials.

    .EXAMPLE
    $prod = [pscustomobject]@{Caption = 'Prod Server'; CimSession = 'myComputer'}
    $prod | Get-FlashArraySerialNumbers

    Returns serial number information on Pure FlashArray disk devices connected to 'myComputer' with current credentials.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNull()]
        [CimSession]$CimSession
    )

    process {
        Get-Disk -FriendlyName 'PURE FlashArray*' @PSBoundParameters | Select-Object PSComputerName, Number, SerialNumber
    }
}

function Get-HostBusAdapter() {
    <#
    .SYNOPSIS
    Retrieves host bus adapater (HBA) information.
    .DESCRIPTION
    Retrieves host bus adapater (HBA) information for the host.
    .PARAMETER CimSession
    Optional. A CimSession or computer name.
    .INPUTS
    CimSession is optional.
    .OUTPUTS
    Host bus adapater information.
    .EXAMPLE
    Get-HostBusAdapter 

    Returns HBA information for the host.

    .EXAMPLE
    Get-HostBusAdapter -CimSession 'myComputer'

    Returns HBA information for 'myComputer' with current credentials.

    .EXAMPLE
    $session = New-CimSession 'myComputer' -Credential (Get-Credential)
    Get-FlashArraySerialNumbers -CimSession $session
    Get-HostBusAdapter -CimSession $session

    Returns serial number information on Pure FlashArray disk devices and host bus adapter 
    with previously created CIM session.

    .EXAMPLE
    Get-HostBusAdapter -CimSession (New-CimSession 'myComputer' -Credential $Creds)

    Returns HBA information for 'myComputer' with credentials stored in variable $Creds.

    .EXAMPLE
    Get-HostBusAdapter -CimSession (New-CimSession 'myComputer' -Credential (Get-Secret admin))

    Returns HBA information for 'myComputer' with credentials stored in a secret vault.

    .EXAMPLE
    Get-HostBusAdapter -CimSession (New-CimSession 'myComputer' -Credential (Get-Credential))

    Returns HBA information for 'myComputer'. Asks for credentials.

    .EXAMPLE
    'myComputer' | Get-HostBusAdapter

    Returns HBA information for 'myComputer' with current credentials.

    .EXAMPLE
    $session = New-CimSession 'myComputer' -Credential (Get-Credential)
    $session | Get-HostBusAdapter

    Returns HBA information for 'myComputer' with previously created CIM session.

    .EXAMPLE
    'myComputer01', 'myComputer02' | Get-HostBusAdapter

    Returns HBA information for 'myComputer01' and 'myComputer02' with current credentials.

    .EXAMPLE
    $prod = [pscustomobject]@{Caption = 'Prod Server'; CimSession = 'myComputer'}
    $prod | Get-HostBusAdapter

    Returns HBA information for 'myComputer' with current credentials.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNull()]
        [CimSession]$CimSession
    )

    process {

        function ConvertTo-HexAndColons([byte[]]$address) {
            return (($address | ForEach-Object { '{0:x2}' -f $_ }) -join ':').ToUpper()
        }

        try {
            $ports = Get-CimInstance -Class 'MSFC_FibrePortHBAAttributes' -Namespace 'root\WMI' @PSBoundParameters -ea Stop
            $adapters = Get-CimInstance -Class 'MSFC_FCAdapterHBAAttributes' -Namespace 'root\WMI' @PSBoundParameters -ea Stop

            foreach ($adapter in $adapters) {
                $attributes = $ports.Where({ $_.InstanceName -eq $adapter.InstanceName }, 'first').Attributes

                $adapter | Select-Object -ExcludeProperty 'NodeWWN', 'Cim*' -Property *, 
                @{n = 'NodeWWN'; e = { ConvertTo-HexAndColons $_.NodeWWN } }, 
                @{n = 'FabricName'; e = { ConvertTo-HexAndColons $attributes.FabricName } }, 
                @{n = 'PortWWN'; e = { ConvertTo-HexAndColons $attributes.PortWWN } }
            }
        }
        catch [Microsoft.Management.Infrastructure.CimException] {
            if ($_.Exception.NativeErrorCode -ne 'NotSupported') {
                throw
            }
        }
    }
}

function Get-MPIODiskLBPolicy() {
    <#
    .SYNOPSIS
    Retrieves the current MPIO Load Balancing policy for Pure FlashArray disk(s).
    .DESCRIPTION
    This cmdlet will retrieve the current MPIO Load Balancing policy for connected Pure FlashArrays disk(s) using the mpclaim.exe utlity.
    .PARAMETER DiskId
    Optional. If specified, retrieves only the policy for the that MPIO disk. Otherwise, returns all disks.
    .INPUTS
    Disk number is optional.
    .OUTPUTS
    mpclaim.exe output.
    .EXAMPLE
    Get-MPIODiskLBPolicy

    Returns the current MPIO Load Balancing Policy for all MPIO disks.

    .EXAMPLE
    Get-MPIODiskLBPolicy -DiskId 1

    Returns the current MPIO LB policy for MPIO disk 1.

    .EXAMPLE
    2, 3 | Get-MPIODiskLBPolicy

    Returns the current MPIO LB policy for MPIO disks 2 and 3.

    .EXAMPLE
    $dataDisk = [pscustomobject]@{Caption = 'Prod Data'; DiskId = 2}
    $dataDisk | Get-MPIODiskLBPolicy

    Returns the current MPIO LB policy for MPIO disk 2.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$DiskId
    )

    process {
        #Checks whether mpclaim.exe is available.
        $exists = Test-Path "$env:systemroot\System32\mpclaim.exe"
        if (-not ($exists)) {
            Write-Error 'mpclaim.exe not found. Is MultiPathIO enabled? Exiting.' -ErrorAction Stop
        }

        $expr = 'mpclaim.exe -s -d '

        if ($PSBoundParameters.ContainsKey('DiskId')) {
            Write-Host "Getting current MPIO Load Balancing Policy for MPIO disk $DiskId" -ForegroundColor Green
            $expr += $DiskId
        }
        else {
            Write-Host 'Getting current MPIO Load Balancing Policy for all MPIO disks.' -ForegroundColor Green
        }

        Invoke-Expression $expr
    }
}

function Get-QuickFixEngineering() {
    <#
    .SYNOPSIS
    Retrieves all the Windows OS QFE patches applied.
    .DESCRIPTION
    Retrieves all the Windows OS QFE patches applied.
    .PARAMETER CimSession
    Optional. A CimSession or computer name.
    .INPUTS
    CimSession is optional.
    .OUTPUTS
    Outputs a listing of QFE patches applied.
    .EXAMPLE
    Get-QuickFixEngineering

    Retrieves all the Windows OS QFE patches applied.

    .EXAMPLE
    Get-QuickFixEngineering -CimSession 'myComputer'

    Retrieves all the Windows OS QFE patches applied to 'myConputer' with current credentials.

    .EXAMPLE
    $session = New-CimSession 'myComputer' -Credential (Get-Credential)
    Get-QuickFixEngineering -CimSession $session
    Get-HostBusAdapter -CimSession $session

    Retrieves all the Windows OS QFE patches applied and host bus adapter 
    with previously created CIM session.

    .EXAMPLE
    Get-QuickFixEngineering -CimSession (New-CimSession 'myComputer' -Credential $Creds)

    Retrieves all the Windows OS QFE patches applied to 'myComputer' with credentials stored in variable $Creds.

    .EXAMPLE
    Get-QuickFixEngineering -CimSession (New-CimSession 'myComputer' -Credential (Get-Secret admin))

    Retrieves all the Windows OS QFE patches applied to 'myComputer' with credentials stored in a secret vault.

    .EXAMPLE
    Get-QuickFixEngineering -CimSession (New-CimSession 'myComputer' -Credential (Get-Credential))

    Retrieves all the Windows OS QFE patches applied to 'myComputer'. Asks for credentials.

    .EXAMPLE
    'myComputer' | Get-QuickFixEngineering

    Retrieves all the Windows OS QFE patches applied to 'myComputer' with current credentials.

    .EXAMPLE
    $session = New-CimSession 'myComputer' -Credential (Get-Credential)
    $session | Get-QuickFixEngineering

    Retrieves all the Windows OS QFE patches applied to 'myComputer' with previously created CIM session.

    .EXAMPLE
    'myComputer01', 'myComputer02' | Get-QuickFixEngineering

    Retrieves all the Windows OS QFE patches applied to 'myComputer01' and 'myComputer02' with current credentials.

    .EXAMPLE
    $prod = [pscustomobject]@{Caption = 'Prod Server'; CimSession = 'myComputer'}
    $prod | Get-QuickFixEngineering

    Retrieves all the Windows OS QFE patches applied to 'myComputer' with current credentials.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNull()]
        [CimSession]$CimSession
    )

    process {
        Get-CimInstance -Class 'Win32_QuickFixEngineering' @PSBoundParameters | Select-Object PSComputerName, Description, HotFixID, InstalledOn
    }
}

function Get-VolumeShadowCopy() {
    <#
    .SYNOPSIS
    Exposes volume shadow copy using the Diskshadow command.
    .DESCRIPTION
    This cmdlet will expose volume shadow copy using the Diskshadow command, passing the variables specified.
    .PARAMETER ExposeAs
    Required. Drive letter, share, or mount point to expose the shadow copy.
    .PARAMETER Alias
    Required. Name of the shadow copy alias.
    .PARAMETER MetadataFile
    Required. Filename for the metadata .cab file.
    .PARAMETER VerboseMode
    Optional. 'On' or 'Off'. If set to 'Off', verbose mode for the Diskshadow command is disabled. Default is 'On'.
    .INPUTS
    None
    .OUTPUTS
    diskshadow.exe output.
    .EXAMPLE
    Get-VolumeShadowCopy -MetadataFile prodmeta.cab -Alias Prod -ExposeAs G:

    Exposes the Prod shadow copy as drive letter G: using the prodmeta.cab metadata file.

    .NOTES
    See https://docs.microsoft.com/windows-server/administration/windows-commands/diskshadow for more information on the Diskshadow utility.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [ValidateNotNullorEmpty()]
        [string]$MetadataFile,
        [Parameter(Mandatory)]
        [ValidateNotNullorEmpty()]
        [string]$Alias,
        [Parameter(Mandatory)]
        [ValidateNotNullorEmpty()]
        [string]$ExposeAs,
        [ValidateSet('On', 'Off')]
        [string]$VerboseMode = 'On'
    )

    $dsh = "./PUREVSS-SNAP.PFA"
    try {
        'RESET',
        "SET VERBOSE $VerboseMode",
        "LOAD METADATA $MetadataFile",
        'IMPORT',
        "EXPOSE %$Alias% $ExposeAs",
        'EXIT' | Set-Content $dsh
        DISKSHADOW /s $dsh
    }
    finally {
        Remove-Item $dsh -ErrorAction SilentlyContinue
    }
}

function Get-WindowsDiagnosticInfo() {
    <#
    .SYNOPSIS
    Gathers Windows operating system, hardware, and software information, including logs for diagnostics. This cmdlet requires Administrative permissions.
    .DESCRIPTION
    This script will collect detailed information on the Windows operating system, hardware and software components, and collect event logs in .evtx and .csv formats. It will optionally collect WSFC logs and optionally compress all gathered files intoa .zip file for easy distribution.
    This script will place all of the files in a parent folder that is named after the computer NetBios name($env:computername).
    Each section of information gathered will have it's own child folder in that parent folder.
    By default, the output will be placed in the %temp% folder.
    .PARAMETER Path
    Optional. Directory path for the output. If not specified, the output will be placed in the %temp% folder.
    .PARAMETER Cluster
    Optional. Collect Windows Server Failover Cluster (WSFC) logs.
    .PARAMETER Compress
    Optional. Compress the folder that contains all the gathered data into a zip file. The file name will be the computername_diagnostics.zip.
    .INPUTS
    None
    .OUTPUTS
    Diagnostic outputs in txt and event log files.
    Compressed zip file.
    .EXAMPLE
    Get-WindowsDiagnosticInfo -Path '.\diagnostic_report' -Cluster

    Retrieves all of the operating system, hardware, software, event log, and WSFC logs into the 'diagnostic_report' folder.

    .EXAMPLE
    Get-WindowsDiagnosticInfo -Cluster

    Retrieves all of the operating system, hardware, software, event log, and WSFC logs into the default folder.

    .EXAMPLE
    Get-WindowsDiagnosticInfo -Compress

    Retrieves all of the operating system, hardware, software, event log, and compresses the parent folder into a zip file that will be created in the %temp% folder.

    .NOTES
    This cmdlet requires Administrative permissions.
    #>

    [cmdletbinding()]
    Param(
        [string]$Path = (Join-Path $env:Temp $env:computername),
        [switch]$Cluster,
        [switch]$Compress
    )

    {
        # System Information
        {msinfo32 /report msinfo32.txt | Out-Null} | Get-Diagnostic -header 'system information'

        # Hotfixes
        { Get-HotFix | Format-Table -Wrap -AutoSize | Out-File 'Get-Hotfix.txt' } | Get-Diagnostic -header 'hotfix information'

        # Storage
        {
            # Disk
            {
                fsutil behavior query DisableDeleteNotify | Out-File 'fsutil_behavior_DisableDeleteNotify.txt'
                Get-PhysicalDisk | Format-List            | Out-File 'Get-PhysicalDisk.txt'
                Get-Disk | Format-List                    | Out-File 'Get-Disk.txt'
                Get-Volume | Format-List                  | Out-File 'Get-Volume.txt'
                Get-Partition | Format-List               | Out-File 'Get-Partition.txt'
            } | Get-Diagnostic -header 'disk information'

            # MPIO
            {
                if (Test-Path "$env:systemroot\System32\mpclaim.exe") {
                    mpclaim -s -d | Out-File 'mpclaim_-s_-d.txt'
                    mpclaim -v    | Out-File 'mpclaim_-v.txt'
                }

                if (Get-Module -ListAvailable 'mpio') {
                    Get-MPIOSetting                         | Out-File 'Get-MPIOSetting.txt'
                    Get-MPIOAvailableHW                     | Out-File 'Get-MPIOAvailableHW.txt'
                    Get-MSDSMGlobalDefaultLoadBalancePolicy | Out-File 'Get-MSDSMGlobalDefaultLoadBalancePolicy.txt'
                }

                $root = 'HKLM:\System\CurrentControlSet\Services'
                $keys = @(
                    @{'service' = 'MSDSM';
                        'key'   = 'MSDSM\Parameters';
                        'file'  = 'Get-ItemProperty_msdsm.txt'
                    },
                    @{'service' = 'mpio';
                        'key'   = 'mpio\Parameters';
                        'file'  = 'Get-ItemProperty_mpio.txt'
                    },
                    @{'service' = 'Disk';
                        'key'   = 'Disk';
                        'file'  = 'Get-ItemProperty_disk.txt'
                    }
                )

                $keys | Where-Object { Join-Path $root $_.service | Test-Path } | ForEach-Object { Join-Path $root $_.key | Get-ItemProperty | Out-File $_.file }
            } | Get-Diagnostic -header 'MPIO information'

            # Fibre Channel
            {
                winrm e wmi/root/wmi/MSFC_FCAdapterHBAAttributes 2>&1 | Out-File 'MSFC_FCAdapterHBAAttributes.txt'
                winrm e wmi/root/wmi/MSFC_FibrePortHBAAttributes 2>&1 | Out-File 'MSFC_FibrePortHBAAttributes.txt'
                Get-InitiatorPort                                     | Out-File 'Get-InitiatorPort.txt'
            } | Get-Diagnostic -header 'fibre channel information'

        } | Get-Diagnostic -header 'storage information' -location 'storage'

        # Network
        {
            Get-NetAdapter                 | Format-Table -AutoSize -Wrap | Out-File 'Get-NetAdapter.txt'
            Get-NetAdapterAdvancedProperty | Format-Table -AutoSize -Wrap | Out-File 'Get-NetAdapterAdvancedProperty.txt'
        } | Get-Diagnostic -header 'network information' -location 'network'

        # Event Logs
        {
            $logs = @('System', 'Setup', 'Security', 'Application')

            # Export
            {
                $logs | ForEach-Object { wevtutil epl $_ "$_.evtx" /ow }
            } | Get-Diagnostic -header 'event log files'

            # Locale-specific messages
            {
                $logs | ForEach-Object { wevtutil al "$_.evtx" }
            } | Get-Diagnostic -header 'locale-specific information'

            #Get critical, error, & warning events
            {
                $logs | ForEach-Object { Get-WinEvent -FilterHashtable @{LogName = $_; Level = 1, 2, 3 } -ea SilentlyContinue | Export-Csv "$_-CRITICAL.csv" -NoTypeInformation }
            } | Get-Diagnostic -header 'critical, error, & warning events'

            # Get informational events
            {
                $logs | ForEach-Object { Get-WinEvent -FilterHashtable @{LogName = $_; Level = 4 } -ea SilentlyContinue | Export-Csv "$_-INFO.csv" -NoTypeInformation }
            } | Get-Diagnostic -header 'informational events'
        } | Get-Diagnostic -header 'event log' -location 'log'

        # WSFC inforation
        If ($Cluster) {
            {
                Get-ClusterLog -Destination '.' | Out-Null
                Get-ClusterSharedVolume      | Select-Object * | Out-File 'Get-ClusterSharedVolume.txt'
                Get-ClusterSharedVolumeState | Select-Object * | Out-File 'Get-ClusterSharedVolumeState.txt'
            } | Get-Diagnostic -header 'cluster information' -location 'cluster'
        }
    } | Get-Diagnostic -header 'diagnostic information' -location $Path -long

    # Compress
    If ($Compress) {
        $params = @{
            Path             = $Path
            CompressionLevel = 'Optimal'
            DestinationPath  = $Path + '_diagnostics.zip'
        }

        Compress-Archive @params -Force
    }
}

function Get-Diagnostic() {
    param(
        [Parameter(ValueFromPipeline)]
        [scriptblock]$command,
        [string]$header = 'diagnostic',
        [string]$location,
        [switch]$long
    )

    $message = "Retrieving $header"
    $message += if (-not $long) { '...' } else { '. This will take some time to complete. Please wait...' }

    Write-Host $message -ForegroundColor Yellow

    if ($location) {
        if (-not (Test-Path $location -PathType Container)) {
            New-Item $location -ItemType 'Directory' | Out-Null
        }

        Push-Location $location
    }

    try {
        Invoke-Command $command
    }
    finally {
        if ($location) {
            Pop-Location
        }

        Write-Host "Retrieving $header completed." -ForegroundColor Green
    }
}

function New-VolumeShadowCopy() {
    <#
    .SYNOPSIS
    Creates a new volume shadow copy using the Diskshadow command.
    .DESCRIPTION
    This cmdlet will create a new volume shadow copy using the Diskshadow command, passing the variables specified.
    .PARAMETER Volume
    Required. A volume to add to the set.
    .PARAMETER Alias
    Required. Name of the shadow copy alias.
    .PARAMETER VerboseMode
    Optional. 'On' or 'Off'. If set to 'Off', verbose mode for the Diskshadow command is disabled. Default is 'On'.
    .INPUTS
    A volume to add to the set.
    .OUTPUTS
    diskshadow.exe output.
    .EXAMPLE
    New-VolumeShadowCopy -Volume G: -Alias Prod

    Creates a new volume shadow copy of volume G: and assigns an alias named Prod.

    .EXAMPLE
    New-VolumeShadowCopy -Volume G:, H: -Alias Prod

    Creates a new volume shadow copy of volumes G: and H: and assigns an aliases named Prod and Prod2 respectively.

    .EXAMPLE
    'G:', 'H:' | New-VolumeShadowCopy -Alias Prod

    Creates a new volume shadow copy of volumes G: and H: and assigns an aliases named Prod and Prod2 respectively.

    .NOTES
    See https://docs.microsoft.com/windows-server/administration/windows-commands/diskshadow for more information on the Diskshadow utility.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullorEmpty()]
        [string[]]$Volume,
        [Parameter(Mandatory)]
        [ValidateNotNullorEmpty()]
        [string]$Alias,
        [ValidateSet('On', 'Off')]
        [string]$VerboseMode = 'On'
    )

    begin {
        $i = 1
        $volumes = @()
    }

    process {
        $volumes += $Volume | ForEach-Object { 
            "ADD VOLUME $_ ALIAS $Alias$(if ($i -gt 1) {$i}) PROVIDER {781c006a-5829-4a25-81e3-d5e43bd005ab}"
            $i++
        }
    }

    end {
        $dsh = "./PUREVSS-SNAP.PFA"
        try {
            'RESET',
            "SET VERBOSE $VerboseMode",
            'SET CONTEXT PERSISTENT',
            'SET OPTION TRANSPORTABLE',
            'BEGIN BACKUP',
            $volumes,
            'CREATE',
            'END BACKUP',
            'EXIT' | Set-Content $dsh
            DISKSHADOW /s $dsh
        }
        finally {
            Remove-Item $dsh -ErrorAction SilentlyContinue
        }
    }
}

function Register-HostVolumes() {
    <#
    .SYNOPSIS
    Sets Pure FlashArray connected disks to online.
    .DESCRIPTION
    This cmdlet will set any FlashArray volumes (disks) to online.
    .PARAMETER CimSession
    Optional. A CimSession or computer name.
    .INPUTS
    CimSession is optional.
    .OUTPUTS
    None
    .EXAMPLE
    Register-HostVolumes

    Set Pure FlashArray connected disks to online.

    .EXAMPLE
    Register-HostVolumes -CimSession 'myComputer'

    Set to online all Pure FlashArray connected to 'myComputer' with current credentials.

    .EXAMPLE
    $session = New-CimSession 'myComputer' -Credential (Get-Credential)
    Register-HostVolumes -CimSession $session
    Get-HostBusAdapter -CimSession $session

    Set to online all Pure FlashArray connected to 'myComputer' and gets host bus adapter 
    with previously created CIM session.

    .EXAMPLE
    Register-HostVolumes -CimSession (New-CimSession 'myComputer' -Credential $Creds)

    Set to online all Pure FlashArray connected to 'myComputer' with credentials stored in variable $Creds.

    .EXAMPLE
    Register-HostVolumes -CimSession (New-CimSession 'myComputer' -Credential (Get-Secret admin))

    Set to online all Pure FlashArray connected to 'myComputer' with credentials stored in a secret vault.

    .EXAMPLE
    Register-HostVolumes -CimSession (New-CimSession 'myComputer' -Credential (Get-Credential))

    Set to online all Pure FlashArray connected to 'myComputer'. Asks for credentials.

    .EXAMPLE
    'myComputer' | Register-HostVolumes

    Set to online all Pure FlashArray connected to 'myComputer' with current credentials.

    .EXAMPLE
    $session = New-CimSession 'myComputer' -Credential (Get-Credential)
    $session | Register-HostVolumes

    Set to online all Pure FlashArray connected to 'myComputer' and gets host bus adapter with previously created CIM session.

    .EXAMPLE
    'myComputer01', 'myComputer02' | Register-HostVolumes

    Set to online all Pure FlashArray connected to 'myComputer01' and 'myComputer02' with current credentials.

    .EXAMPLE
    $prod = [pscustomobject]@{Caption = 'Prod Server'; CimSession = 'myComputer'}
    $prod | Register-HostVolumes

    Set to online all Pure FlashArray connected to 'myComputer' with current credentials.
    #>

    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNull()]
        [CimSession]$CimSession
    )

    process {
        $params = @{}
        if ($PSBoundParameters.ContainsKey('CimSession')) {
            $params.Add('CimSession', $CimSession)
        }

        Update-HostStorageCache @params
        $disks = Get-Disk -FriendlyName 'PURE FlashArray*' @params | Where-Object {$null -ne $_.Number -and $_.OperationalStatus -ne 'Other'}

        foreach ($disk in $disks) {
            $label = if ($disk.PSComputerName) {" on $($disk.PSComputerName)"}
            if ($disk.IsReadOnly -and $PSCmdlet.ShouldProcess("Disk $($disk.Number)$label", 'Remove read-only attribute')) {
                $disk | Set-Disk -IsReadOnly $false @params
            }

            if ($disk.IsOffline -and $PSCmdlet.ShouldProcess("Disk $($disk.Number)$label", 'Set disk online')) {
                $disk | Set-Disk -IsOffline $false @params
            }
        }
    }
}

enum MPIODiskLBPolicy {
    clear = 0   # clear current policy and sets to Windows OS default of RR
    FO    = 1   # Fail Over Only
    RR    = 2   # Round Robin
    RRWS  = 3   # Round Robin with Subset
    LQD   = 4   # Least Queue Depth
    WP    = 5   # Weighted Paths
    LB    = 6   # Least Blocks
}

function Set-MPIODiskLBPolicy() {
    <#
    .SYNOPSIS
    Sets the MPIO Load Balancing policy for FlashArray disks.
    .DESCRIPTION
    This cmdlet will set the MPIO Load Balancing policy for all connected Pure FlashArrays disks to the desired setting using the mpclaim.exe utlity.
    The default Windows OS setting is RR.
    .PARAMETER Policy
    Required. No default. The Policy type must be specified by the letter acronym for the policy name (ex. "RR" for Round Robin). Available options are:
        LQD = Least Queue Depth
        RR = Round Robin
        FO = Fail Over Only
        RRWS = Round Robin with Subset
        WP = Weighted Paths
        LB = Least Blocks
        clear = clears current policy and sets to Windows OS default of RR
    .INPUTS
    None
    .OUTPUTS
    mpclaim.exe output.
    .EXAMPLE
    Set-MPIODiskLBPolicy -Policy LQD

    Sets the MPIO load balancing policy for all Pure disks to Least Queue Depth.

    .EXAMPLE
    Set-MPIODiskLBPolicy -Policy clear

    Clears the current MPIO policy for all Pure disks and sets to the default of RR.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [MPIODiskLBPolicy]$Policy
    )

    #Checks whether mpclaim.exe is available.
    $exists = Test-Path "$env:systemroot\System32\mpclaim.exe"
    if (-not ($exists)) {
        Write-Error 'mpclaim.exe not found. Is MultiPathIO enabled? Exiting.' -ErrorAction Stop
    }

    Write-Host "Setting MPIO Load Balancing Policy to $([int]$Policy) for all Pure FlashArray disks."

    $drives = (Get-CimInstance -Namespace 'root\wmi' -Class 'mpio_disk_info').DriveInfo
    Get-PhysicalDisk -FriendlyName 'PURE FlashArray*' | ForEach-Object {
        $id = $drives | Where-Object SerialNumber -eq $_.UniqueId | ForEach-Object { $_.Name.Substring('MPIO Disk'.Length) }
        mpclaim.exe -l -d $id $([int]$Policy)
    }

    Write-Host 'New disk LB policy settings:' -ForegroundColor Green
    mpclaim.exe -s -d
}

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
    <#
    .SYNOPSIS
    Disable a secure channel protocol.
    .DESCRIPTION
    This cmdlet will change Windows registry to disable specified secure channel protocol for client and server.
    .PARAMETER ProtocolName
    Required. Secure channel protocol name as <SSL/TLS/DTLS> <major version number>.<minor version number>.
    Run with -WhatIf common parameter to see the changes.
    .INPUTS
    A string containing protocol name via pipeline or parameter.
    .OUTPUTS
    None
    .EXAMPLE
    Disable-SecureChannelProtocol 'TLS 1.1'

    Disables TLS 1.1.

    .LINK
    https://learn.microsoft.com/windows-server/security/tls/tls-registry-settings
    #>
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

        try {
            if (-not $PSCmdlet.ShouldProcess(
                    $ProtocolName,
                    "Disable secure channel protocol")) {
                return 
            }

            Push-Location 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'

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
    <#
    .SYNOPSIS
    Enable a secure channel protocol.
    .DESCRIPTION
    This cmdlet will change Windows registry to enable specified secure channel protocol for client and server.
    .PARAMETER ProtocolName
    Required. Secure channel protocol name as <SSL/TLS/DTLS> <major version number>.<minor version number>.
    Run with -WhatIf common parameter to see the changes.
    .INPUTS
    A string containing protocol name via pipeline or parameter.
    .OUTPUTS
    None
    .EXAMPLE
    Enable-SecureChannelProtocol 'TLS 1.2'

    Enables TLS 1.2.

    .LINK
    https://learn.microsoft.com/windows-server/security/tls/tls-registry-settings
    #>
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

        try {
            if (-not $PSCmdlet.ShouldProcess(
                    $ProtocolName,
                    "Enable secure channel protocol")) {
                return 
            }

            Push-Location 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'

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
    <#
    .SYNOPSIS
    Configures TLS secure channel protcols to follow best practice recommendations.
    .DESCRIPTION
    This cmdlet will alter Windows registry to disable outdated TLS secure channel protocols and enable 
    recent versions. The minimum allowed version is specified as MinVersion parameter, which is '1.2' by default.
    This cmdlet makes a backup of the secure channel registry branc. It save the branch into a registry file.
    Use -WhatIf or -Verbose common parameters to see what protocols are anabled or disabled.
    Use -Confirm common parameter to control individual changes.
    .PARAMETER MinVersion
    Optional. '1.2' by default. Minimum allowed TLS version.
    .PARAMETER SkipBackup
    Optional. False by default. When present, Set-TlsVersions does not make a registry backup.
    .PARAMETER BackupFilePath
    Optional. 'protocols.reg' by default. Sets path for registry backup.
    .PARAMETER Force
    Optional. False by default. When present suppresses all confirmations including registry backup file overwrite.
    .INPUTS
    Minimum allowed TLS version.
    .OUTPUTS
    None

    .EXAMPLE
    Set-TlsVersion
    
    Disable all TLS versinons below 1.2. Enable 1.2 and 1.3. Save registry branch backup as ./protocols.reg.

    .EXAMPLE
    Set-TlsVersion -SkipBackup
    
    Disable all TLS versinons below 1.2. Enable 1.2 and 1.3. Does not make registry backup.

    .EXAMPLE
    Set-TlsVersion -MinVersion 1.3
    
    Disable all TLS versinons below 1.3. Enable 1.3. Save registry branch backup as ./protocols.reg.

    .EXAMPLE
    Set-TlsVersion -BackupFilePath 'D:\backup\tls.reg'
    
    Disable all TLS versinons below 1.2. Enable 1.2 and 1.3. Save registry branch backup as  'D:\backup\tls.reg'.

    .EXAMPLE
    Set-TlsVersion -Force
    
    Disable all TLS versinons below 1.2. Enable 1.2 and 1.3. Overwrite backup file ./protocols.reg if exists.

    .LINK
    https://learn.microsoft.com/windows-server/security/tls/tls-registry-settings
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(ValueFromPipeline)]
        [Version]$MinVersion = '1.2',
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
        Backup-RegistryKey -KeyPath $key -BackupFilePath $BackupFilePath -Force:$Force | Out-Null
    }

    0..3 | ForEach-Object {
        $v = [Version]::new(1, $_)
        if ($v -lt $MinVersion) {
            Disable-SecureChannelProtocol "TLS $v"
        }
        else {
            Enable-SecureChannelProtocol "TLS $v"
        }
    }
}

function Set-WindowsPowerScheme() {
    <#
    .SYNOPSIS
    Cmdlet to set the Power scheme for the Windows OS.
    .DESCRIPTION
    Cmdlet to set the Power scheme for the Windows OS to High Performance if no scheme id is specified.
    .PARAMETER PlanId
    Optional. A PlanId to activate on the system.
    .PARAMETER Session
    Optional. A PSSession to the remote computer.
    .INPUTS
    Session is optional.
    .OUTPUTS
    None
    .EXAMPLE
    Set-WindowsPowerScheme

    Retrieves the current Power Scheme setting, and if not set to High Performance, sets it to active.

    .EXAMPLE
    $pssession = New-PSSession -ComputerName 'computer_name' -Credential (Get-Credential)
    Set-WindowsPowerScheme -Session $pssession

    Retrieves the current Power Scheme setting on a remote computer, and if not set to High Performance, sets it to active.

    .EXAMPLE
    $pssession = New-PSSession -ComputerName 'computer_name' -Credential (Get-Credential)
    $pssession | Set-WindowsPowerScheme

    Retrieves the current Power Scheme setting on a remote computer, and if not set to High Performance, sets it to active.

    .EXAMPLE
    $pssession = New-PSSession -ComputerName 'computer_name' -Credential (Get-Credential)
    $prod = [pscustomobject]@{Caption = 'Prod Server'; Session = $pssession}
    $prod | Set-WindowsPowerScheme

    Retrieves the current Power Scheme setting on a remote computer, and if not set to High Performance, sets it to active.
    #>

    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [guid]$PlanId = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c",
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNull()]
        [System.Management.Automation.Runspaces.PSSession]$Session
    )

    process {
        $params = @{}
        if ($PSBoundParameters.ContainsKey('Session')) {
            $params.Add('Session', $Session)
        }

        Invoke-Command {
            [CmdletBinding(SupportsShouldProcess)]
            Param ($p, $c, $w)

            $ConfirmPreference = $c
            $WhatIfPreference = $w

            $scheme = Get-CimInstance -Class 'Win32_PowerPlan' -Namespace 'root\cimv2\power' -Filter 'isActive=True'
            if ($scheme.InstanceID -ne "Microsoft:PowerPlan\{$p}") {
                if ($PSCmdlet.ShouldProcess("power scheme $p on $($env:COMPUTERNAME)", 'set active')) {
                    powercfg.exe /setactive $p
                }
            }
        } -ArgumentList @($PlanId, $ConfirmPreference, $WhatIfPreference) @params
    }
}

function Test-WindowsBestPractices() {
    <#
    .SYNOPSIS
    Cmdlet used to retrieve hosts information, test and optionally configure MPIO (FC) and/or iSCSI settings in a Windows OS against FlashArray Best Practices.
    .DESCRIPTION
    This cmdlet will retrieve the curretn host infromation, and iterate through several tests around MPIO (FC) and iSCSI OS settings and hardware, indicate whether they are adhearing to Pure Storage FlashArray Best Practices, and offer to alter the settings if applicable.
    All tests can be bypassed with a negative user response when prompted, or simply by using Ctrl-C to break the process.
    .PARAMETER Repair
    Optional. If this parameter is present, the cmdlet will repair settings to their recommended values.
    .PARAMETER IncludeIscsi
    Optional. If this parameter is present, the cmdlet will run tests for iSCSI settings.
    .PARAMETER LogFilePath
    Optional. Specify the full filepath (ex. c:\mylog.log) for logging. If not specified, the default file of %TMP%\BestPractices.log will be used.
    .INPUTS
    Optional parameter for iSCSI testing.
    .OUTPUTS
    Output status and best practice options for every test.
    .EXAMPLE
    Test-WindowsBestPractices

    Run the cmdlet against the local machine running the MPIO tests and the log is located in the %TMP%\BestPractices.log file.

    .EXAMPLE
    Test-WindowsBestPractices -IncludeIscsi -LogFilePath "c:\temp\mylog.log"

    Run the cmdlet against the local machine, run the additional iSCSI tests, and create the log file at c:\temp\mylog.log.

    .EXAMPLE
    Test-WindowsBestPractices -Repair -IncludeIscsi -LogFilePath "c:\temp\mylog.log"

    Run the cmdlet against the local machine, run the additional iSCSI tests, repair settings to their recommended values, and create the log file at c:\temp\mylog.log.

    .EXAMPLE
    Test-WindowsBestPractices -Repair -Confirm:$false

    Run the cmdlet against the local machine, repair settings to their recommended values skipping confirmation prompt.
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param (
        [switch]$Repair,
        [string]$LogFilePath = (Join-Path $env:Temp 'BestPractices.log'),
        [switch]$IncludeIscsi,
        [switch]$Force
    )

    $p = @{
        'logFilePath' = $LogFilePath;
        'repair'      = $Repair;
        'force'       = $Force;
    }

    $log = @{
        'path' = $LogFilePath;
    }

    'Starting best practices verification' | Write-TestLog @log

    if (($PSVersionTable.PSVersion.Major -gt 5 -and -not $IsWindows) -or (Get-CimInstance -ClassName 'Win32_OperatingSystem').ProductType -lt 2) {
        'Windows Server operating system is required.' | Write-TestLog -severity 'Failed' @log
        return
    }

    $ft = Get-WindowsFeature -Name 'Multipath-IO'
    if ($ft.InstallState -ne 'Installed')
    {
        if ($Force -or $PSCmdlet.ShouldContinue('Are you sure you want to install Multipath I/O feature', 'Multipath I/O feature')) {
            $res = Add-WindowsFeature -Name $ft.Name
            if (-not $res.Success)
            {
                'Feature installation failed' | Write-TestLog -severity 'Failed' @log
                return
            }
        
            if ($res.RestartNeeded -eq 'Yes')
            {
                'Server reboot required' | Write-TestLog -severity 'Warning' @log
                return
            }
        }
        else {
            'Feature installation skipped' | Write-TestLog -severity 'Warning' @log
            return
        }
    }

    $inf = Get-SilComputer
    $inf | Write-TestLog @log

    $ms = Get-MPIOSetting
    $ms | Write-TestLog @log

    Test-Item -header 'MSDSM supported hardware' `
    -valueDisplayName 'FlashArray device hardware id' `
    -test { Get-MSDSMSupportedHW -VendorId 'PURE' -ProductId 'FlashArray' -ea SilentlyContinue } `
    -action { New-MSDSMSupportedHW -VendorId 'PURE' -ProductId 'FlashArray' } @p

    Test-Item -header 'PathVerificationState' `
    -valueDisplayName 'Enabled' `
    -test { $ms.PathVerificationState -eq 'Enabled' } `
    -action { Set-MPIOSetting -NewPathVerificationState 'Enabled' } @p

    $pdorp = if (-not (Test-AzureVm)) { 30 } else { 120 } #120 on Azure VM
    Test-Item -header 'PDORemovePeriod' `
    -valueDisplayName "$pdorp" `
    -test { $ms.PDORemovePeriod -eq $pdorp } `
    -action { Set-MPIOSetting -NewPDORemovePeriod $pdorp } @p

    Test-Item -header 'UseCustomPathRecoveryTime' `
    -valueDisplayName 'Enabled' `
    -test { $ms.UseCustomPathRecoveryTime -eq 'Enabled' } `
    -action { Set-MPIOSetting -CustomPathRecovery 'Enabled' } @p

    $pri = 20
    Test-Item -header 'CustomPathRecoveryTime' `
    -valueDisplayName "$pri" `
    -test { $ms.CustomPathRecoveryTime -eq $pri } `
    -action { Set-MPIOSetting -NewPathRecoveryInterval $pri } @p

    $dt = 60
    Test-Item -header 'DiskTimeoutValue' `
    -valueDisplayName "$dt" `
    -test { $ms.DiskTimeoutValue -eq $dt } `
    -action { Set-MPIOSetting -NewDiskTimeout $dt } @p

    $fsrg = 'HKLM:\System\CurrentControlSet\Control\FileSystem'
    Test-Item -header 'Delete notifications (trim or unmap)' `
    -valueDisplayName "Enabled" `
    -test { 
        $ddn = Get-ItemProperty $fsrg 'DisableDeleteNotification' -ea SilentlyContinue
        ($null -eq $ddn) -or ($ddn.DisableDeleteNotification -eq 0)
    } `
    -action { Set-ItemProperty $fsrg 'DisableDeleteNotification' 0 -Confirm:$false } @p

    if ($IncludeIscsi) {
        foreach ($adapter in Get-NetAdapter) {
            if ((-not $Repair) -or ($Force -or $PSCmdlet.ShouldContinue("Are you sure you want to repair $($adapter.Name) adapter", $adapter.Name))) {
                $adp = Get-NetAdapterAdvancedProperty -Name $adapter.Name -RegistryKeyword 'NetCfgInstanceId' -AllProperties
                $key = Join-Path 'HKLM:\System\CurrentControlSet\Services\Tcpip\Parameters\Interfaces' $adp.RegistryValue[0]

                Test-Item -header "$($adapter.Name) TcpAckFrequency" `
                -valueDisplayName 1 `
                -test { 
                    $taf = Get-ItemProperty $key 'TcpAckFrequency' -ea SilentlyContinue
                    ($null -ne $taf) -and ($taf.TcpAckFrequency -eq 1)
                } `
                -action { Set-ItemProperty $key 'TcpAckFrequency' 1 -Confirm:$false } @p

                Test-Item -header "$($adapter.Name) TcpNoDelay (Nagle)" `
                -valueDisplayName 'Disabled (1)' `
                -test { 
                    $tnd = Get-ItemProperty $key 'TcpNoDelay' -ea SilentlyContinue
                    ($null -ne $tnd) -and ($tnd.TcpNoDelay -eq 1)
                } `
                -action { Set-ItemProperty $key 'TcpNoDelay' 1 -Confirm:$false } @p
            }
        }
    }

    'Best practices verification completed' | Write-TestLog @log
}

function Test-AzureVm()
{
    $null -ne (Get-CimInstance -Query "SELECT Tag FROM Win32_SystemEnclosure WHERE SMBIOSAssetTag = '7783-7084-3265-9085-8269-3286-77'")
}

function Test-Item() {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(ValueFromPipeline)]
        [scriptblock]$test,
        [string]$logFilePath,
        [string]$header = 'best practices',
        [string]$valueDisplayName = 'recommended value',
        [switch]$repair,
        [scriptblock]$action,
        [switch]$force
    )

    $p = @{'path' = $logFilePath}

    Write-TestLog "Testing $header" @p
    if (Invoke-Command $test) {
        Write-TestLog "$header is $valueDisplayName" -Severity Passed @p
    }
    elseif ($repair -and ($force -or $PSCmdlet.ShouldProcess($header, "set to $valueDisplayName"))) {
        try {
            Write-TestLog "Repairing $header to $valueDisplayName" @p
            Invoke-Command $action | Out-Null
            Write-TestLog "$header is set to $valueDisplayName" -Severity Passed @p
        }
        catch {
            Write-TestLog "Failed setting $header to $valueDisplayName with error: $_" -Severity Failed @p
        }
    }
    else {
        Write-TestLog "$header has not recommended value" -Severity Failed @p
    }
}

enum TestSeverity {
    Information =   0
    Passed      =  10
    Warning     =  14
    Failed      = 112
}

function Write-TestLog {
    param(
        [Parameter(ValueFromPipeline)]
        [object]$inputObject,
        [string]$path,
        [TestSeverity]$severity = [TestSeverity]::Information
    )

    $ev = if ($inputObject -is [string]) {
        $m = "$severity`: $inputObject"

        $p = if ($severity -gt 0) { @{ForegroundColor = [int]$severity % 100 } }
        Write-Host $m @p

        "$((Get-Date -f g).PadRight(20)) $m"
    }
    else {
        $inputObject
    }

    $ev | Out-File $path -Append -Confirm:$false -WhatIf:$false
}

function Write-Logo()
{
    Write-Host ''
    Write-Host '             __________________________'
    Write-Host '            /++++++++++++++++++++++++++\'
    Write-Host '           /++++++++++++++++++++++++++++\'
    Write-Host '          /++++++++++++++++++++++++++++++\'
    Write-Host '         /++++++++++++++++++++++++++++++++\'
    Write-Host '        /++++++++++++++++++++++++++++++++++\'
    Write-Host '       /++++++++++++/----------\++++++++++++\'
    Write-Host '      /++++++++++++/            \++++++++++++\'
    Write-Host '     /++++++++++++/              \++++++++++++\'
    Write-Host '    /++++++++++++/                \++++++++++++\'
    Write-Host '   /++++++++++++/                  \++++++++++++\'
    Write-Host '   \++++++++++++\                  /++++++++++++/'
    Write-Host '    \++++++++++++\                /++++++++++++/'
    Write-Host '     \++++++++++++\              /++++++++++++/'
    Write-Host '      \++++++++++++\            /++++++++++++/'
    Write-Host '       \++++++++++++\          /++++++++++++/'
    Write-Host '        \++++++++++++\'
    Write-Host '         \++++++++++++\'
    Write-Host '          \++++++++++++\'
    Write-Host '           \++++++++++++\'
    Write-Host '            \------------\'
    Write-Host ''
}

function Unregister-HostVolumes() {
    <#
    .SYNOPSIS
    Sets Pure FlashArray connected disks to offline.
    .DESCRIPTION
    This cmdlet will set any FlashArray volumes (disks) to offline.
    .PARAMETER CimSession
    Optional. A CimSession or computer name.
    .INPUTS
    CimSession is optional.
    .OUTPUTS
    None
    .EXAMPLE
    Unregister-HostVolumes

    Set Pure FlashArray connected disks to offline.

    .EXAMPLE
    Unregister-HostVolumes -CimSession 'myComputer'

    Set to offline all Pure FlashArray disks connected to 'myComputer' with current credentials.

    .EXAMPLE
    $session = New-CimSession 'myComputer' -Credential (Get-Credential)
    Unregister-HostVolumes -CimSession $session
    Get-HostBusAdapter -CimSession $session

    Set to offline all Pure FlashArray disks connected to 'myComputer' and gets host bus adapter 
    with previously created CIM session.

    .EXAMPLE
    Unregister-HostVolumes -CimSession (New-CimSession 'myComputer' -Credential $Creds)

    Set to offline all Pure FlashArray disks connected to 'myComputer' with credentials stored in variable $Creds.

    .EXAMPLE
    Unregister-HostVolumes -CimSession (New-CimSession 'myComputer' -Credential (Get-Secret admin))

    Set to offline all Pure FlashArray disks connected to 'myComputer' with credentials stored in a secret vault.

    .EXAMPLE
    Unregister-HostVolumes -CimSession (New-CimSession 'myComputer' -Credential (Get-Credential))

    Set to offline all Pure FlashArray disks connected to 'myComputer'. Asks for credentials.

    .EXAMPLE
    'myComputer' | Unregister-HostVolumes

    Set to offline all Pure FlashArray connected to 'myComputer' with current credentials.

    .EXAMPLE
    $session = New-CimSession 'myComputer' -Credential (Get-Credential)
    $session | Unregister-HostVolumes

    Set to offline all Pure FlashArray connected to 'myComputer' and gets host bus adapter with previously created CIM session.

    .EXAMPLE
    'myComputer01', 'myComputer02' | Unregister-HostVolumes

    Set to offline all Pure FlashArray connected to 'myComputer01' and 'myComputer02' with current credentials.

    .EXAMPLE
    $prod = [pscustomobject]@{Caption = 'Prod Server'; CimSession = 'myComputer'}
    $prod | Unregister-HostVolumes

    Set to offline all Pure FlashArray connected to 'myComputer' with current credentials.
    #>

    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNull()]
        [CimSession]$CimSession
    )

    process {
        $params = @{}
        if ($PSBoundParameters.ContainsKey('CimSession')) {
            $params.Add('CimSession', $CimSession)
        }

        Update-HostStorageCache @params
        $disks = Get-Disk -FriendlyName 'PURE FlashArray*' @params | Where-Object {$null -ne $_.Number -and $_.OperationalStatus -ne 'Other'}

        foreach ($disk in $disks) {
            $label = if ($disk.PSComputerName) {" on $($disk.PSComputerName)"}
            if (!$disk.IsOffline -and $PSCmdlet.ShouldProcess("Disk $($disk.Number)$label", 'Set disk offline')) {
                $disk | Set-Disk -IsOffline $true @params
            }
        }
    }
}

function Update-DriveInformation() {
    <#
    .SYNOPSIS
    Updates drive letter and assigns a label.
    .DESCRIPTION
    Thsi cmdlet will update the current drive letter to the new drive letter, and assign a new file system label if specified.
    .PARAMETER DriveLetter
    Required. Specifies the drive letter of the partition to modify.
    .PARAMETER NewDriveLetter
    Required. Specifies the new drive letter for the partition.
    .PARAMETER NewFileSystemLabel
    Optional. Specifies a new file system label to use.
    .PARAMETER CimSession
    Optional. A CimSession or computer name. CIM session may be reused.
    .INPUTS
    CimSession is optional.
    .OUTPUTS
    None
    .EXAMPLE
    Update-DriveInformation -DriveLetter M -NewDriveLetter S

    Updates the drive letter from M to S.

    .EXAMPLE
    Update-DriveInformation -DriveLetter M -NewDriveLetter S -NewFileSystemLabel Test

    Updates the drive letter from M to S and changes the file system label to Test.

    .EXAMPLE
    Update-DriveInformation -DriveLetter M -NewDriveLetter S -CimSession 'myComputer'

    Updates the drive letter from M to S. Update is performed on 'myComputer' with current credentials.

    .EXAMPLE
    $session = New-CimSession 'myComputer' -Credential (Get-Credential)
    Update-DriveInformation -DriveLetter M -NewDriveLetter S -CimSession $session

    Updates the drive letter from M to S. Update is performed on 'myComputer' with previously created CIM session.

    .EXAMPLE
    Update-DriveInformation -DriveLetter M -NewDriveLetter S -CimSession (New-CimSession 'myComputer' -Credential $Creds)

    Updates the drive letter from M to S. Update is performed on 'myComputer' with credentials stored in variable $Creds.

    .EXAMPLE
    Update-DriveInformation -DriveLetter M -NewDriveLetter S -CimSession (New-CimSession 'myComputer' -Credential (Get-Secret admin))

    Updates the drive letter from M to S. Update is performed on 'myComputer' with credentials stored in a secret vault.

    .EXAMPLE
    Update-DriveInformation -DriveLetter M -NewDriveLetter S -CimSession (New-CimSession 'myComputer' -Credential (Get-Credential))

    Updates the drive letter from M to S. Update is performed on 'myComputer'. Asks for credentials.

    .EXAMPLE
    $session = New-CimSession 'myComputer' -Credential (Get-Credential)
    $session | Update-DriveInformation -DriveLetter M -NewDriveLetter S

    Updates the drive letter from M to S. Update is performed on 'myComputer' with previously created CIM session.

    .EXAMPLE
    $dev = [pscustomobject]@{Caption = 'Dev Server'; CimSession = 'myComputer'}
    $dev | Update-DriveInformation -DriveLetter M -NewDriveLetter S

    Updates the drive letter from M to S. Update is performed on 'myComputer' with current credentials.
    #>

    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [Parameter(Mandatory)]
        [ValidateNotNullorEmpty()]
        [char]$DriveLetter,
        [Parameter(Mandatory)]
        [ValidateNotNullorEmpty()]
        [char]$NewDriveLetter,
        [string]$NewFileSystemLabel,
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNull()]
        [CimSession]$CimSession
    )

    process {
        $params = @{
            Query    = "SELECT * FROM Win32_Volume WHERE DriveLetter = '$DriveLetter`:'"
            Property = @{ DriveLetter = "$NewDriveLetter`:" }
        }

        if ($PSBoundParameters.ContainsKey('NewFileSystemLabel')) {
            $params.Property.Add('Label', $NewFileSystemLabel)
        }

        if ($PSBoundParameters.ContainsKey('CimSession')) {
            $params.Add('CimSession', $CimSession)
        }

        Set-CimInstance @params | Out-Null
    }
}

# Declare exports
Export-ModuleMember -Function Get-HostBusAdapter
Export-ModuleMember -Function Get-FlashArraySerialNumbers
Export-ModuleMember -Function Get-QuickFixEngineering
Export-ModuleMember -Function Get-VolumeShadowCopy
Export-ModuleMember -Function Get-WindowsDiagnosticInfo
Export-ModuleMember -Function Get-MPIODiskLBPolicy
Export-ModuleMember -Function Set-MPIODiskLBPolicy
Export-ModuleMember -Function Set-TlsVersions
Export-ModuleMember -Function Set-WindowsPowerScheme
Export-ModuleMember -Function New-VolumeShadowCopy
Export-ModuleMember -Function Enable-SecureChannelProtocol
Export-ModuleMember -Function Disable-SecureChannelProtocol
Export-ModuleMember -Function Register-HostVolumes
Export-ModuleMember -Function Unregister-HostVolumes
Export-ModuleMember -Function Update-DriveInformation
Export-ModuleMember -Function Test-WindowsBestPractices
# END
