<#
    ===========================================================================
    Release version: 3.0.0.1
    Revision information: Refer to the changelog.md file
    ---------------------------------------------------------------------------
    Maintained by:   FlashArray Integrations and Evangelsigm Team @ Pure Storage
    Organization:    Pure Storage, Inc.
    Filename:        PureStorage.Toolkit.WinAdmin.psm1
    Copyright:       (c) 2022 Pure Storage, Inc.
    Module Name:     PureStorage.Toolkit.WinAdmin
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
#Requires -RunAsAdministrator

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
#endregion Helper functions

function Get-FlashArraySerialNumbers() {
    <#
    .SYNOPSIS
    Retrieves FlashArray disk serial numbers connected to the host.
    .DESCRIPTION
    Cmdlet retrieves disk serial numbers that are associated to Pure FlashArrays.
    .PARAMETER CimSession
    Optional. A CimSession or computer name.
    .INPUTS
    CimSession is optional.
    .OUTPUTS
    Outputs serial numbers of FlashArrays devices.
    .EXAMPLE
    Get-FlashArraySerialNumbers -CimSession 'myComputer'

    Returns serial number information on Pure FlashArray disk devices connected to the host.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [CimSession]$CimSession
    )

    Get-CimInstance -ClassName 'Win32_DiskDrive' -Filter 'Model LIKE ''PURE FlashArray%''' @PSBoundParameters | 
    select 'Name', 'Caption', 'Index', 'SerialNumber'
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
    Get-HostBusAdapter -CimSession 'myComputer'
    #>

    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [CimSession]$CimSession
    )

    function ConvertTo-HexAndColons([byte[]]$address) {
        return (($address | foreach { '{0:x2}' -f $_ }) -join ':').ToUpper()
    }

    try {
        $ports = Get-CimInstance -Class 'MSFC_FibrePortHBAAttributes' -Namespace 'root\WMI' @PSBoundParameters
        $adapters = Get-CimInstance -Class 'MSFC_FCAdapterHBAAttributes' -Namespace 'root\WMI' @PSBoundParameters

        foreach ($adapter in $adapters) {
            $attributes = $ports.Where({ $_.InstanceName -eq $adapter.InstanceName }, 'first').Attributes

            $adapter | select -ExcludeProperty 'NodeWWN', 'Cim*' -Property *, 
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

function Get-MPIODiskLBPolicy() {
    <#
    .SYNOPSIS
    Retrieves the current MPIO Load Balancing policy for Pure FlashArray disk(s).
    .DESCRIPTION
    This cmdlet will retrieve the current MPIO Load Balancing policy for connected Pure FlashArrays disk(s) using the mpclaim.exe utlity.
    .PARAMETER DiskID
    Optional. If specified, retrieves only the policy for the that disk ID. Otherwise, returns all disks.
    DiskID is the 'Number' identifier of the disk from the cmdlet 'Get-Disk'.
    .INPUTS
    None
    .OUTPUTS
    mpclaim.exe output
    .EXAMPLE
    Get-MPIODiskLBPolicy -DiskID 1

    Returns the current MPIO LB policy for disk ID 1.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $False, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$DiskId
    )

    process {
        #Checks whether mpclaim.exe is available.
        $exists = Test-Path "$env:systemroot\System32\mpclaim.exe"
        if (-not ($exists)) {
            Write-Error 'mpclaim.exe not found. Is MultiPathIO enabled? Exiting.' -ErrorAction Stop
        }

        $expr = "mpclaim.exe -s -d "

        if ($DiskId) {
            Write-Host "Getting current MPIO Load Balancing Policy for DiskID $DiskId" -ForegroundColor Green
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
    Get-QuickFixEngineering -CimSession 'myComputer'
    #>

    [CmdletBinding()]
    Param (
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [CimSession]$CimSession
    )

    Get-CimInstance -Class 'Win32_QuickFixEngineering' @PSBoundParameters |
    select Description, HotFixID, InstalledOn
}

function Get-VolumeShadowCopy() {
    <#
    .SYNOPSIS
    Retrieves the volume shadow copy informaion using the Diskhadow command.
    .DESCRIPTION

    .PARAMETER ExposeAs
    Required. Drive letter, share, or mount point to expose the shadow copy.
    .PARAMETER ScriptName
    Optional. Script text file name created to pass to the Diskshadow command. defaults to 'PUREVSS-SNAP'.
    .PARAMETER ShadowCopyAlias
    Required. Name of the shadow copy alias.
    .PARAMETER MetadataFile
    Required. Full filename for the metadata .cab file. It must exist in the current working folder.
    .PARAMETER VerboseMode
    Optional. "On" or "Off". If set to 'off', verbose mode for the Diskshadow command is disabled. Default is 'On'.
    .INPUTS
    None
    .OUTPUTS
    None
    .EXAMPLE
    Get-VolumeShadowCopy -MetadataFile myFile.cab -ShadowCopyAlias MyAlias -ExposeAs MyShadowCopy

    Exposes the MyAias shadow copy as drive latter G: using the myFie.cab metadata file.

    .NOTES
    See https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/diskshadow for more information on the Diskshadow utility.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $False)][string]$ScriptName = "PUREVSS-SNAP",
        [Parameter(Mandatory = $True)][string]$MetadataFile,
        [Parameter(Mandatory = $True)][string]$ShadowCopyAlias,
        [Parameter(Mandatory = $True)][string]$ExposeAs,
        [ValidateSet("On", "Off")][string]$VerboseMode = "On"
    )
    $dsh = "./$ScriptName.PFA"
    try {
        "SET VERBOSE $VerboseMode",
        "RESET",
        "LOAD METADATA $MetadataFile.cab",
        "IMPORT",
        "EXPOSE %$ShadowCopyAlias% $ExposeAs",
        "EXIT" | Set-Content $dsh
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
    This script will place all of the files in a parent folder in the root of the C:\ drive that is named after the computer NetBios name($env:computername).
    Each section of information gathered will have it's own child folder in that parent folder.
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
    Get-WindowsDiagnosticInfo.ps1 -Cluster

    Retrieves all of the operating system, hardware, software, event log, and WSFC logs into the default folder.

    .EXAMPLE
    Get-WindowsDiagnosticInfo.ps1 -Compress

    Retrieves all of the operating system, hardware, software, event log, and compresses the parent folder into a zip file that will be created in the root of the C: drive.

    .NOTES
    This cmdlet requires Administrative permissions.
    #>
    [cmdletbinding()]
    Param(
        [Parameter(ValuefromPipeline = $false, Mandatory = $false)][switch]$Cluster,
        [Parameter(ValuefromPipeline = $false, Mandatory = $false)][switch]$Compress
    )
    Get-ElevatedStatus
    # create root outfile
    $folder = Test-Path -PathType Container -Path "c:\$env:computername"
    if ($folder -eq "false") {
        New-Item -Path "c:\$env:computername" -ItemType "directory" | Out-Null
    }
    Set-Location -Path "c:\$env:computername"
    Write-Host ""

    # system information
    Write-Host "Retrieving MSInfo32 information. This will take some time to complete. Please wait..." -ForegroundColor Yellow
    msinfo32 /report msinfo32.txt | Out-Null
    Write-Host "Completed MSInfo32 information." -ForegroundColor Green
    Write-Host ""
    ## hotfixes
    Write-Host "Retrieving Hotfix information..." -ForegroundColor Yellow
    Get-WmiObject -Class Win32_QuickFixEngineering | Select-Object -Property Description, HotFixID, InstalledOn | Format-Table -Wrap -AutoSize | Out-File  "HotfixesQFE.txt"
    Get-HotFix | Format-Table -Wrap -AutoSize | Out-File "Get-Hotfix.txt"
    Write-Host "Completed HotfixQFE information." -ForegroundColor Green
    Write-Host ""

    # storage information
    New-Item -Path "c:\$env:computername\storage" -ItemType "directory" | Out-Null
    Set-Location -Path "c:\$env:computername\storage"
    Write-Host "Retrieving Storage information..." -ForegroundColor Yellow
    fsutil behavior query DisableDeleteNotify | Out-File "fsutil_behavior_DisableDeleteNotify.txt"
    Get-PhysicalDisk | Select-Object * | Out-File "Get-PhysicalDisk.txt"
    Get-Disk | Select-Object * | Out-File "Get-Disk.txt"
    Get-Volume | Select-Object * | Out-File "Get-Volume.txt"
    Get-Partition | Select-Object * | Out-File "Get-Partition.txt"
    Write-Host "    Completed Disk information." -ForegroundColor Green
    Write-Host ""
    ## disk, MPIO, and MSDSM information
    Write-Host "    Retrieving MPIO and MSDSM information..." -ForegroundColor Yellow
    Get-ItemProperty "HKLM:\System\CurrentControlSet\Services\MSDSM\Parameters" | Out-File "Get-ItemProperty_msdsm.txt"
    Get-MSDSMGlobalDefaultLoadBalancePolicy | Out-File "Get-ItemProperty_msdsm_load_balance_policy.txt"
    Get-ItemProperty "HKLM:\System\CurrentControlSet\Services\mpio\Parameters" | Out-File "Get-ItemProperty_mpio.txt"
    Get-ItemProperty "HKLM:\System\CurrentControlSet\Services\Disk" | Out-File "Get-ItemProperty_disk.txt"
    mpclaim -s -d | Out-File "mpclaim_-s_-d.txt"
    mpclaim -v | Out-File "mpclaim_-v.txt"
    Get-MPIOSetting | Out-File "Get-MPIOSetting.txt"
    Get-MPIOAvailableHW | Out-File "Get-MPIOAvailableHW.txt"
    Write-Host "    Completed MPIO, & MSDSM information." -ForegroundColor Green
    Write-Host ""
    ## Fibre Channel information
    Write-Host "    Retrieving Fibre Channel information..." -ForegroundColor Yellow
    winrm e wmi/root/wmi/MSFC_FCAdapterHBAAttributes > MSFC_FCAdapterHBAAttributes.txt
    winrm e wmi/root/wmi/MSFC_FibrePortHBAAttributes > MSFC_FibrePortHBAAttributes.txt
    Get-InitiatorPort | Out-File "Get-InitiatorPort.txt"
    Write-Host "    Completed Fibre Channel information." -ForegroundColor Green
    Write-Host ""
    Write-Host "Completed Storage information." -ForegroundColor Green
    Write-Host ""

    # Network information
    New-Item -Path "c:\$env:computername\network" -ItemType "directory" | Out-Null
    Set-Location -Path "c:\$env:computername\network"
    Write-Host "Retrieving Network information..." -ForegroundColor Yellow
    Get-NetAdapter | Format-Table Name, ifIndex, Status, MacAddress, LinkSpeed, InterfaceDescription -AutoSize | Out-File "Get-NetAdapter.txt"
    Get-NetAdapterAdvancedProperty | Format-Table DisplayName, DisplayValue, ValidDisplayValues | Out-File "Get-NetAdapterAdvancedProperty.txt" -Width 160
    Write-Host "Completed Network information." -ForegroundColor Green
    Write-Host ""

    # Event Logs in evtx format
    New-Item -Path "c:\$env:computername\eventlogs" -ItemType "directory" | Out-Null
    Set-Location -Path "c:\$env:computername\eventlogs"
    Write-Host "Retrieving Event Logs unfiltered." -ForegroundColor Yellow
    wevtutil epl System "systemlog.evtx"
    wevtutil epl Setup "setuplog.evtx"
    wevtutil epl Security "securitylog.evtx"
    wevtutil epl Application "applicationlog.evtx"
    Write-Host "   Completed .evtx log files." -ForegroundColor Green
    ## create locale files
    wevtutil al "systemlog.evtx"
    wevtutil al "setuplog.evtx"
    wevtutil al "securitylog.evtx"
    wevtutil al "applicationlog.evtx"
    Write-Host "   Completed locale .evtx log files." -ForegroundColor Green
    ## get error & warning events & export to csv
    Write-Host "Retrieving filtered Event Logs. This will take some time to complete. Please wait..." -ForegroundColor Yellow
    Get-WinEvent -FilterHashtable @{LogName = 'Application'; 'Level' = 1, 2, 3 } -ErrorAction SilentlyContinue | Export-Csv "application_log-CRITICAL_ERROR_WARNING.csv" -NoTypeInformation
    Get-WinEvent -FilterHashtable @{LogName = 'System'; 'Level' = 1, 2, 3 } -ErrorAction SilentlyContinue | Export-Csv "system_log-CRITICAL_ERROR_WARNING.csv" -NoTypeInformation
    Get-WinEvent -FilterHashtable @{LogName = 'Security'; 'Level' = 1, 2, 3 } -ErrorAction SilentlyContinue | Export-Csv "security_log-CRITICAL_ERROR_WARNING.csv" -NoTypeInformation
    Get-WinEvent -FilterHashtable @{LogName = 'Setup'; 'Level' = 1, 2, 3 } -ErrorAction SilentlyContinue | Export-Csv "setup_log-CRITICAL_ERROR_WARNING.csv" -NoTypeInformation
    Write-Host "   Completed Critical, Error, & Warning .csv log files." -ForegroundColor Green
    ## get information events & export to csv
    Get-WinEvent -FilterHashtable @{LogName = 'Application'; 'Level' = 4 } -ErrorAction SilentlyContinue | Export-Csv "application_log-INFO.csv" -NoTypeInformation
    Get-WinEvent -FilterHashtable @{LogName = 'System'; 'Level' = 4 } -ErrorAction SilentlyContinue | Export-Csv "system_log-INFO.csv" -NoTypeInformation
    Get-WinEvent -FilterHashtable @{LogName = 'Security'; 'Level' = 4 } -ErrorAction SilentlyContinue | Export-Csv "security_log-INFO.csv" -NoTypeInformation
    Get-WinEvent -FilterHashtable @{LogName = 'Setup'; 'Level' = 4 } -ErrorAction SilentlyContinue | Export-Csv "setup_log-INFO.csv" -NoTypeInformation
    Write-Host "   Completed Informational .csv log files." -ForegroundColor Green
    Write-Host ""
    Write-Host "Completed Event Logs." -ForegroundColor Green
    Write-Host ""

    # WSFC inforation
    If ($Cluster.IsPresent) {
        New-Item -Path "c:\$env:computername\cluster" -ItemType "directory" | Out-Null
        Set-Location -Path "c:\$env:computername\cluster"
        Write-Host "Retrieving Cluster Logs. This may take some time to complete. Please wait..." -ForegroundColor Yellow
        Get-ClusterLog -Destination . | Out-Null
        Get-ClusterSharedVolume | Select-Object * | Out-File "Get-ClusterSharedVolume.txt"
        Get-ClusterSharedVolumeState | Select-Object * | Out-File "Get-ClusterSharedVolumeState.txt"
        Write-Host "Completed Cluster information." -ForegroundColor Green
        Write-Host ""
    }

    # Compress folder
    If ($Compress.IsPresent) {
        Write-Host "Starting folder compression. Please wait..." -ForegroundColor Yellow
        Set-Location -Path "\"
        $compress = @{
            Path             = "c:\$env:computername"
            CompressionLevel = "Optimal"
            DestinationPath  = $env:computername + "_diagnostics.zip"
        }
        Compress-Archive @compress
        Write-Host "Completed folder compression." -ForegroundColor Green
    }
    Write-Host ""
    Write-Host "Information collection completed."
}

function New-VolumeShadowCopy() {
    <#
    .SYNOPSIS
    Creates a new volume shadow copy using Diskshadow.
    .DESCRIPTION
    This cmdlet will create a new volume shadow copy using the Diskshadow command, passing the variables specified.
    .PARAMETER Volume
    Required.
    .PARAMETER Scriptname
    Optional. Script text file name created to pass to the Diskshadow command. Pre-defined as 'PUREVSS-SNAP'.
    .PARAMETER ShadowCopyAlias
    Required. Name of the shadow copy alias.
    .PARAMETER VerboseMode
    Optional. "On" or "Off". If set to 'off', verbose mode for the Diskshadow command is disabled. Default is 'on'.
    .INPUTS
    None
    .OUTPUTS
    None
    .EXAMPLE
    New-VolumeShadowCopy -Volume Volume01 -ShadowCopyAlias MyAlias

    Adds a new volume shadow copy of Volume01 using Diskshadow with an alias of 'MyAlias'.

    .NOTES
    See https://docs.microsoft.com/en-us/windows-server/administration/windows-commands/diskshadow for more information on the Diskshadow utility.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)][string[]]$Volume,
        [Parameter(Mandatory = $False)][string]$ScriptName = "PUREVSS-SNAP",
        [Parameter(Mandatory = $True)][string]$ShadowCopyAlias,
        [ValidateSet("On", "Off")][string]$VerboseMode = "On"
    )

    $dsh = "./$ScriptName.PFA"

    foreach ($Vol in $Volume) {
        "ADD VOLUME $Vol ALIAS $ShadowCopyAlias PROVIDER {781c006a-5829-4a25-81e3-d5e43bd005ab}"
    }
    'RESET',
    'SET CONTEXT PERSISTENT',
    'SET OPTION TRANSPORTABLE',
    "SET VERBOSE $VerboseMode",
    'BEGIN BACKUP',
    "ADD VOLUME $Volume ALIAS $ShadowCopyAlias PROVIDER {781c006a-5829-4a25-81e3-d5e43bd005ab}",
    'CREATE',
    'END BACKUP' | Set-Content $dsh
    DISKSHADOW /s $dsh
    Remove-Item $dsh
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
    Register-HostVolumes -CimSession 'myComputer'
    #>

    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [CimSession]$CimSession
    )

    Update-HostStorageCache @PSBoundParameters
    $disks = Get-Disk -FriendlyName 'PURE FlashArray*' @PSBoundParameters | where OperationalStatus -ne "Other"

    foreach ($disk in $disks) {
        if ($disk.IsReadOnly -and $PSCmdlet.ShouldProcess("Disk $($disk.Number)", "Remove read-only attribute")) {
            $disk | Set-Disk -IsReadOnly $false @PSBoundParameters
        }

        if ($disk.IsOffline -and $PSCmdlet.ShouldProcess("Disk $($disk.Number)", "Set disk online")) {
            $disk | Set-Disk -IsOffline $false @PSBoundParameters
        }
    }
}

enum MPIODiskLBPolicy {
    clear = 0
    FO    = 1
    RR    = 2
    RRWS  = 3
    LQD   = 4
    WP    = 5
    LB    = 6
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
    None
    .EXAMPLE
    Set-MPIODiskLBPolicy -Policy LQD

    Sets the MPIO load balancing policy for all Pure disks to Least Queue Depth.

    .EXAMPLE
    Set-MPIODiskLBPolicy -Policy clear

    Clears the current MPIO policy for all Pure disks and sets to the default of RR.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)][MPIODiskLBPolicy]$Policy
    )

    #Checks whether mpclaim.exe is available.
    $exists = Test-Path "$env:systemroot\System32\mpclaim.exe"
    if (-not ($exists)) {
        Write-Error 'mpclaim.exe not found. Is MultiPathIO enabled? Exiting.' -ErrorAction Stop
    }

    Write-Host "Setting MPIO Load Balancing Policy to $([int]$Policy) for all Pure FlashArray disks."
    $puredisks = Get-PhysicalDisk | Where-Object FriendlyName -Match 'PURE'
    $puredisks | ForEach-Object {
        # Get disk uniqueid
        $UniqueID = $_.UniqueId
        $MPIODisk = (Get-CimInstance -Namespace root\wmi -Class MPIO_DISK_INFO).driveinfo | Where-Object { $_.SerialNumber -eq $UniqueID }
        $MPIODiskID = $MPIODisk.Name.Replace('MPIO Disk', '')
        $MPIODiskID
        mpclaim.exe  -l -d $MPIODiskID [int]$Policy
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

    for ($m = 0; $m -lt 4; $m++) {
        $v = [Version]::new(1, $m)
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
    Cmdlet to set the Power scheme for the Windows OS to High Performance.
    .DESCRIPTION
    Cmdlet to set the Power scheme for the Windows OS to High Performance.
    .PARAMETER ComputerName
    Optional. The computer name to run the cmdlet against. It defaults to the local computer name.
    .INPUTS
    None
    .OUTPUTS
    Current power scheme and optional confirmation to alter the setting in the Windows registry.
    .EXAMPLE
    Set-WindowsPowerScheme

    Retrieves the current Power Scheme setting, and if not set to High Performance, asks for confirmation to set it.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $False)] [string] $ComputerName = "$env:COMPUTERNAME"
    )
    $PowerScheme = Get-WmiObject -Class WIN32_PowerPlan -Namespace 'root\cimv2\power' -ComputerName $ComputerName -Filter "isActive='true'"
    if ($PowerScheme.ElementName -ne "High performance") {
        Write-Host "WARNING" -ForegroundColor Yellow -NoNewline
        Write-Host ": Computer Power Scheme is not set to High Performance. Pure Storage best practice is to set this power plan as default."
        Write-Host " "
        Write-Host "REQUIRED ACTION: Set the Power Plan to High Performance?"
        $resp = Read-Host -Prompt "Y/N?"
        if ($resp.ToUpper() -eq 'Y') {
            $planId = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
            powercfg -setactive "$planId"
        }
    }
    else {
        Write-Host "PASSED" -ForegroundColor Green -NoNewline
        Write-Host ": Computer Power Scheme is already set to High Performance. Exiting."
    }
}
function Test-WindowsBestPractices() {
    <#
    .SYNOPSIS
    Cmdlet used to retrieve hosts information, test and optionally configure MPIO (FC) and/or iSCSI settings in a Windows OS against FlashArray Best Practices.
    .DESCRIPTION
    This cmdlet will retrieve the curretn host infromation, and iterate through several tests around MPIO (FC) and iSCSI OS settings and hardware, indicate whether they are adhearing to Pure Storage FlashArray Best Practices, and offer to alter the settings if applicable.
    All tests can be bypassed with a negative user response when prompted, or simply by using Ctrl-C to break the process.
    .PARAMETER EnableIscsiTests
    Optional. If this parameter is present, the cmdlet will run tests for iSCSI settings.
    .PARAMETER OutFile
    Optional. Specify the full filepath (ex. c:\mylog.log) for logging. If not specified, the default file of %TMP%\Test-WindowsBestPractices.log will be used.
    .INPUTS
    Optional parameter for iSCSI testing.
    .OUTPUTS
    Output status and best practice options for every test.
    .EXAMPLE
    Test-WindowsBestPractices

    Run the cmdlet against the local machine running the MPIO tests and the log is located in the %TMP%\Test-WindowsBestPractices.log file.

    .EXAMPLE
    Test-WindowsZBestPractices -EnableIscsiTests -OutFile "c:\temp\mylog.log"

    Run the cmdlet against the local machine, run the additional iSCSI tests, and create the log file at c:\temp\mylog.log.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $false)] [string] $OutFile = "$env:Temp\Test-WindowsBestPractices.log",
        [Switch]$EnableIscsiTests
    )
    function Write-Log {
        [CmdletBinding()]
        param(
            [Parameter()][ValidateNotNullOrEmpty()][string]$Message,
            [Parameter()][ValidateNotNullOrEmpty()][ValidateSet("Information", "Passed", "Warning", "Failed")][string]$Severity = "Information"
        )
        [pscustomobject]@{
            Time     = (Get-Date -f g)
            Message  = $Message
            Severity = $Severity
        } | Out-File -FilePath $OutFile -Append
    }
    Write-Log -Message 'Pure Storage FlashArray Windows Server Best Practices Analyzer v2.0.0.0' -Severity Information
    Clear-Host
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
    Write-Host 'Pure Storage FlashArray Windows Server Best Practices Analyzer v2.0.0.0'
    Write-Host '------------------------------------------------------------------------'
    Write-Host ''
    Write-Host ''
    Write-Host '========================================='
    Write-Host 'Host Information'
    Write-Host '========================================='
    $compinfo = Get-SilComputer | Out-String -Stream
    $compinfo | Out-File -FilePath $OutFile -Append
    $compinfo
    Write-Log -Message "Successfully retrieved computer properties. Continuing..." -Severity Information
    Write-Host ''
    Write-Host '========================================='
    Write-Host 'Multipath-IO Verificaton'
    Write-Host '========================================='
    # Multipath-IO
    if ((Get-WindowsFeature -Name 'Multipath-IO').InstallState -eq 'Available') {
        Write-Host "FAILED" -ForegroundColor Red -NoNewline
        Write-Host ": Multipath-IO Windows feature is not installed. This feature can be installed by this cmdlet, but a reboot of the server will be required, and the you must re-run the cmdlet again."
        Write-Log -Message 'Multipath-IO Windows feature is not installed.' -Severity Failed
        $resp = Read-Host "Would you like to install this feature? (***Reboot Required) Y/N"
        if ($resp.ToUpper() -eq 'Y') {
            Add-WindowsFeature -Name Multipath-IO
            Write-Log -Message 'Multipath-IO Windows feature was installed per user request. Continuing...' -Severity Passed
        }
        else {
            Write-Host "WARNING" -ForegroundColor Yellow -NoNewline
            Write-Host ": You have chosen not to install the Multipath-IO feature via this cmdlet. Please add this feature manually and re-run this cmdlet."
            Write-Log -Message 'Multipath-IO Windows feature not installed per user request. Exiting.' -Severity Warning
            exit
        }
    }
    else {
        Write-Host "PASSED" -ForegroundColor Green -NoNewline
        Write-Host ": The Multipath-IO feature is installed."
        Write-Log -Message 'Multipath-IO Windows feature is installed. Continuing...' -Severity Passed
    }

    Write-Host ''
    Write-Host '========================================='
    Write-Host 'Multipath-IO Hardware Verification'
    Write-Host '========================================='
    $MPIOHardware = Get-MPIOAvailableHW
    $MPIOHardware | Out-File -FilePath $OutFile -Append
    Write-Log -Message "Successfully retrieved MPIO Hardware. Continuing..." -Severity Information
    $MPIOHardware
    $DSMs = Get-MPIOAvailableHW
    ForEach ($DSM in $DSMs) {
        if ((($DSM).VendorId.Trim()) -eq 'PURE' -and (($DSM).ProductId.Trim()) -eq 'FlashArray') {
            Write-Host "PASSED" -ForegroundColor Green -NoNewline
            Write-Host ": Microsoft Device Specific Module (MSDSM) is configured for $($DSM.ProductID).`n`r"
            Write-Log -Message "Microsoft Device Specific Module (MSDSM) is configured for $($DSM.ProductID).`n`r. Continuing..." -Severity Passed
        }
        else {
            Write-Host "FAILED" -ForegroundColor Red -NoNewline
            Write-Host ": Microsoft Device Specific Module (MSDSM) is not configured for $($DSM.ProductID).`n`r"
            Write-Log -Message "Microsoft Device Specific Module (MSDSM) is not configured for $($DSM.ProductID).`n`r. Continuing anyway..." -Severity Failed
        }
    }

    Write-Host ''
    Write-Host '-----------------------------------------'
    Write-Host 'Current MPIO Settings'
    Write-Host '-----------------------------------------'

    $MPIOSettings = $null
    $MPIOSetting = $null
    Write-Log -Message "Retrieving MPIO settings. Continuing..." -Severity Information
    $MPIOSettings = Get-MPIOSetting | Out-String -Stream
    $MPIOSettings = $MPIOSettings.Replace(" ", "")
    $MPIOSettings | Out-Null
    $MPIOSettings | Out-File -FilePath $OutFile -Append
    Write-Log -Message "Successfully retrieved MPIO Settings. Continuing..." -Severity Information

    ForEach ($MPIOSetting in $MPIOSettings) {
        $MPIOSetting.Split(':')[0]
        $MPIOSetting.Split(':')[1]
        switch ( $($MPIOSetting.Split(':')[0])) {
            'PathVerificationState' { $PathVerificationState = $($MPIOSetting.Split(':')[1]) }
            'PDORemovePeriod' { $PDORemovePeriod = $($MPIOSetting.Split(':')[1]) }
            'UseCustomPathRecoveryTime' { $UseCustomPathRecoveryTime = $($MPIOSetting.Split(':')[1]) }
            'CustomPathRecoveryTime' { $CustomPathRecoveryTime = $($MPIOSetting.Split(':')[1]) }
            'DiskTimeoutValue' { $DiskTimeOutValue = $($MPIOSetting.Split(':')[1]) }
        }
    }

    Write-Host ''
    Write-Host '========================================='
    Write-Host 'MPIO Settings Verification'
    Write-Host '========================================='

    # PathVerificationState
    if ($PathVerificationState -eq 'Disabled') {
        Write-Host "FAILED" -ForegroundColor Red -NoNewline
        Write-Host ": PathVerificationState is $($PathVerificationState)."
        Write-Log -Message "PathVerificationState is $($PathVerificationState)." -Severity Failed
        $resp = Read-Host "REQUIRED ACTION: Set the PathVerificationState to Enabled? Y/N"
        if ($resp.ToUpper() -eq 'Y') {
            Set-MPIOSetting -NewPathVerificationState Enabled
            Write-Log -Message "PathVerificationState is now $($PathVerificationState) per to user request." -Severity Information
        }
        else {
            Write-Host "WARNING" -ForegroundColor Yellow
            Write-Host ": Not changing the PathVerificationState to Enabled could cause unexpected path recovery issues."
            Write-Log -Message "PathVerificationState $($PathVerificationState) was not altered due to user request." -Severity Warning
        }
    }
    else {
        Write-Host "PASSED" -ForegroundColor Green -NoNewline
        Write-Host ": PathVerificationState has a value of Enabled. No action required."
        Write-Log -Message "PathVerificationState has a value of Enabled. No action required." -Severity Passed
    }

    # PDORemovalPeriod
    # Need to test for Azure VM. If Azure VM, use PDORemovalPeriod=120. If not Azure VM, use PDORemovePeriod=30.
    try {
        $StatusCode = wget -TimeoutSec 3 -Headers @{"Metadata" = "true" } -Uri "http://169.254.169.254/metadata/instance/compute?api-version=2021-01-01" | ForEach-Object { $_.StatusCode }
    }
    catch {}
    if ($StatusCode -eq '200') {
        $b = Invoke-RestMethod -Headers @{"Metadata" = "true" } -Method GET -Proxy $Null -Uri "http://169.254.169.254/metadata/instance/compute?api-version=2021-01-01&format=json" | Select-Object azEnvironment
        if ($b.azEnvironment -like "Azure*") {
            Write-Log -Message "This is an Azure Vitual Machine. The PDORemovalPeriod is set differently than others." -Severity Information
            if ($PDORemovePeriod -ne '120') {
                Write-Host "FAILED" -ForegroundColor Red -NoNewline
                Write-Host ": PDORemovePeriod for this Azure VM is set to $($PDORemovePeriod)."
                Write-Log -Message "PDORemovePeriod for this Azure VM is set to $($PDORemovePeriod)." -Severity Failed
                $resp = Read-Host "REQUIRED ACTION: Set the PDORemovePeriod to a value of 120? Y/N"
                if ($resp.ToUpper() -eq 'Y') {
                    Set-MPIOSetting -NewPDORemovePeriod 120
                    Write-Log -Message ": PDORemovePeriod for this Azure VM is set to $($PDORemovePeriod) per user request." -Severity Information
                }
                else {
                    Write-Host "WARNING" -ForegroundColor Yellow -NoNewline
                    Write-Host ": Not changing the PDORemovePeriod to 120 for an Azure VM could cause unexpected path recovery issues."
                    Write-Log -Message "Not changing the PDORemovePeriod to 120 for an Azure VM could cause unexpected path recovery issues." -Severity Warning
                }
                else {
                    Write-Host "PASSED" -ForegroundColor Green -NoNewline
                    Write-Host ": PDORemovePeriod is set to a value of 120 for this Azure VM. No action required."
                    Write-Log -Message "PDORemovePeriod is set to a value of 120 for this Azure VM. No action required." -Severity Passed
                }
            }
        }
        else {
            if ($PDORemovePeriod -ne '30') {
                Write-Host "FAILED" -ForegroundColor Red -NoNewline
                Write-Host ": PDORemovePeriod is set to $($PDORemovePeriod)."
                Write-Log -Message "PDORemovePeriod is set to $($PDORemovePeriod)." -Severity Failed
                $resp = Read-Host "REQUIRED ACTION: Set the PDORemovePeriod to a value of 30? Y/N"
                if ($resp.ToUpper() -eq 'Y') {
                    Set-MPIOSetting -NewPDORemovePeriod 30
                    Write-Log -Message "PDORemovePeriod is set to $($PDORemovePeriod) per user request." -Severity Information
                }
                else {
                    Write-Host "WARNING" -ForegroundColor Yellow -NoNewline
                    Write-Host ": Not changing the PDORemovePeriod to 30 could cause unexpected path recovery issues."
                    Write-Log -Message "Not changing the PDORemovePeriod to 30 could cause unexpected path recovery issues." -Severity Warning
                }
                else {
                    Write-Host "PASSED" -ForegroundColor Green -NoNewline
                    Write-Host ": PDORemovePeriod is set to a value of 30. No action required."
                    Write-Log -Message "PDORemovePeriod is set to a value of 30. No action required." -Severity Passed
                }
            }
        }
    }
    # PathRecoveryTime
    if ($UseCustomPathRecoveryTime -eq 'Disabled') {
        Write-Host "FAILED" -ForegroundColor Red -NoNewline
        Write-Host ": UseCustomPathRecoveryTime is set to $($UseCustomPathRecoveryTime)."
        Write-Log -Message "UseCustomPathRecoveryTime is set to $($UseCustomPathRecoveryTime)." -Severity Failed
        $resp = Read-Host "REQUIRED ACTION: Set the UseCustomPathRecoveryTime to Enabled? Y/N"
        if ($resp.ToUpper() -eq 'Y') {
            Set-MPIOSetting -CustomPathRecovery Enabled
            Write-Log -Message "UseCustomPathRecoveryTime is set to $($UseCustomPathRecoveryTime) per user request." -Severity Information
        }
        else {
            Write-Host "WARNING" -ForegroundColor Yellow
            Write-Host ": Not changing the UseCustomPathRecoveryTime to Enabled could cause unexpected path recovery issues."
            Write-Log -Message "Not changing the UseCustomPathRecoveryTime to Enabled could cause unexpected path recovery issues." -Severity Warning
        }
    }
    else {
        Write-Host "PASSED" -ForegroundColor Green -NoNewline
        Write-Host ": UseCustomPathRecoveryTime is set to Enabled. No action required."
        Write-Log -Message "UseCustomPathRecoveryTime is set to Enabled. No action required." -Severity Passed
    }

    if ($CustomPathRecoveryTime -ne '20') {
        Write-Host "FAILED" -ForegroundColor Red -NoNewline
        Write-Host ": CustomPathRecoveryTime is set to $($CustomPathRecoveryTime)."
        Write-Log -Message "CustomPathRecoveryTime is set to $($CustomPathRecoveryTime)." -Severity Failed
        $resp = Read-Host "REQUIRED ACTION: Set the CustomPathRecoveryTime to a value of 20? Y/N"
        if ($resp.ToUpper() -eq 'Y') {
            Set-MPIOSetting -NewPathRecoveryInterval 20
            Write-Log -Message "CustomPathRecoveryTime is set to $($UseCustomPathRecoveryTime) per user request." -Severity Information
        }
        else {
            Write-Host "WARNING" -ForegroundColor Yellow
            Write-Host ": Not changing the CustomPathRecoveryTime to a value of 20 could cause unexpected path recovery issues."
            Write-Log -Message "Not changing the CustomPathRecoveryTime to a value of 20 could cause unexpected path recovery issues." -Severity Warning
        }
    }
    else {
        Write-Host "PASSED" -ForegroundColor Green -NoNewline
        Write-Host ": CustomPathRecoveryTime is set to $($CustomPathRecoveryTime). No action required."
        Write-Log -Message "CustomPathRecoveryTime is set to $($CustomPathRecoveryTime). No action required." -Severity Passed
    }

    # DiskTimeOutValue
    if ($DiskTimeOutValue -ne '60') {
        Write-Host "FAILED" -ForegroundColor Red -NoNewline
        Write-Host ": DiskTimeOutValue is set to $($DiskTimeOutValue)."
        Write-Log -Message "DiskTimeOutValue is set to $($DiskTimeOutValue)." -Severity Failed
        $resp = Read-Host "REQUIRED ACTION: Set the DiskTimeOutValue to a value of 60? Y/N"
        if ($resp.ToUpper() -eq 'Y') {
            Set-MPIOSetting -NewDiskTimeout 60
            Write-Log -Message "DiskTimeOutValue is set to $($DiskTimeOutValue) per user request." -Severity Information
        }
        else {
            Write-Host "WARNING" -ForegroundColor Yellow
            Write-Host ": Not changing the DiskTimeOutValue to a value of 60 could cause unexpected path recovery issues."
            Write-Log -Message "Not changing the DiskTimeOutValue to a value of 60 could cause unexpected path recovery issues." -Severity Warning
        }
    }
    else {
        Write-Host "PASSED" -ForegroundColor Green -NoNewline
        Write-Host ": DiskTimeOutValue is set to $($DiskTimeOutValue). No action required."
        Write-Log -Message "DiskTimeOutValue is set to $($DiskTimeOutValue). No action required." -Severity Passed
    }

    Write-Host ''
    Write-Host '========================================='
    Write-Host 'TRIM/UNMAP Verification'
    Write-Host '========================================='
    # DisableDeleteNotification
    $DisableDeleteNotification = (Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\FileSystem' -Name 'DisableDeleteNotification')
    if ($DisableDeleteNotification.DisableDeleteNotification -eq 0) {
        Write-Host "PASSED" -ForegroundColor Green -NoNewline
        Write-Host ": Delete Notification is Enabled"
        Write-Log -Message "Delete Notification is Enabled. No action required." -Severity Passed
    }
    else {
        Write-Host "WARNING" -ForegroundColor Yellow -NoNewline
        Write-Host ": Delete Notification is Disabled. Pure Storage Best Practice is to enable delete notifications."
        Write-Log -Message "Delete Notification is Disabled. Pure Storage Best Practice is to enable delete notifications." -Severity Warning
    }
    Write-Host " "
    Write-Host "MPIO settings tests complete. Continuing..." -ForegroundColor Green
    Write-Log -Message "MPIO settings tests complete. Continuing..." -Severity Information
    # iSCSI tests
    if ($EnableIscsiTests) {
        Write-Host ''
        Write-Host '========================================='
        Write-Host 'iSCSI Settings Verification'
        Write-Host '========================================='
        Write-Log -Message "iSCSI testing enabled. Continuing..." -Severity Information
        $AdapterNames = @()
        Write-Host "All available adapters: "
        Write-Host " "
        $adapters = Get-NetAdapter | Sort-Object Name | Format-Table -Property "Name", "InterfaceDescription", "MacAddress", "Status"
        $adapters | Out-File -FilePath $OutFile -Append
        $adapters
        Write-Host " "
        $AdapterNames = Read-Host "Please enter all iSCSI adapter names to be tested. Use a comma to seperate the names - ie. NIC1,NIC2,NIC3"
        $AdapterNames = $AdapterNames.Split(',')
        Write-Host " "
        Write-Host "Adapter names being configured: "
        $AdapterNames
        Write-Host "==============================="
        foreach ($adapter in $AdapterNames) {
            $adapterGuid = (Get-NetAdapterAdvancedProperty -Name $adapter -RegistryKeyword "NetCfgInstanceId" -AllProperties).RegistryValue
            $RegKeyPath = "HKLM:\system\currentcontrolset\services\tcpip\parameters\interfaces\$adapterGuid\"
            $TAFRegKey = "TcpAckFrequency"
            $TNDRegKey = "TcpNoDelay"
            ## TcpAckFrequency
            if ((Get-ItemProperty $RegkeyPath).$TAFRegKey -eq "1") {
                Write-Host "PASSED" -ForegroundColor Green -NoNewline
                Write-Host ": TcpAckFrequency is set to disabled (1). No action required."
                Write-Log -Message "TcpAckFrequency is set to disabled (1). No action required." -Severity Passed
            }
            if (-not (Get-ItemProperty $RegkeyPath $TAFRegKey -ErrorAction SilentlyContinue)) {
                Write-Host "FAILED" -ForegroundColor Red -NoNewline
                Write-Host ": TcpAckFrequency key does not exist."
                Write-Log -Message "TcpAckFrequency key does not exist." -Severity Failed
                Write-Host "REQUIRED ACTION: Set the TcpAckFrequency registry value to 1 for $adapter ?" -NoNewline
                $resp = Read-Host -Prompt "Y/N?"
                if ($resp.ToUpper() -eq 'Y') {
                    Write-Host "Creating Registry key and setting to disabled..."
                    New-ItemProperty -Path $RegKeyPath -Name 'TcpAckFrequency' -Value '1' -PropertyType DWORD -Force -ErrorAction SilentlyContinue
                    Write-Log -Message "Creating Registry key and setting to disabled per user request." -Severity Information
                }
                else {
                    Write-Host "WARNING" -ForegroundColor Yellow -NoNewline
                    Write-Host ": TcpAckFrequency registry key exists but is enabled. Changing to disabled."
                    Set-ItemProperty -Path $RegKeyPath -Name 'TcpAckFrequency' -Value '1' -Type DWORD -Force -ErrorAction SilentlyContinue
                    Write-Log -Message "TcpAckFrequency registry key exists but is enabled. Changing to disabled." -Severity Warning
                }
            }
            if ($resp.ToUpper() -eq 'N') {
                Write-Host "ABORTED" -ForegroundColor Yellow -NoNewline
                Write-Host ": Registry key not created or altered by request of user."
                Write-Log -Message "Registry key not created or altered by request of user." -Severity Warning

            }
            ## TcpNoDelay
            if ((Get-ItemProperty $RegkeyPath).$TNDRegKey -eq "1") {
                Write-Host "PASSED" -ForegroundColor Green -NoNewline
                Write-Host ": TcpNoDelay (Nagle) is set to disabled (1). No action required."
                Write-Log -Message "TcpNoDelay (Nagle) is set to disabled (1). No action required." -Severity Passed
            }
            if (-not (Get-ItemProperty $RegkeyPath $TNDRegKey -ErrorAction SilentlyContinue)) {
                Write-Host "REQUIRED ACTION: Set the TcpNodelay (Nagle) registry value to 1 for $adapter ?" -NoNewline
                $resp = Read-Host -Prompt "Y/N?"
                if ($resp.ToUpper() -eq 'Y') {
                    Write-Host "TcpNoDelay registry key does not exist. Creating..."
                    New-ItemProperty -Path $RegKeyPath -Name 'TcpNoDelay' -Value '1' -PropertyType DWORD -Force -ErrorAction SilentlyContinue
                    Write-Log -Message "TcpNoDelay registry key does not exist. Creating per user request." -Severity Information
                }
                else {
                    Write-Host "WARNING" -ForegroundColor Yellow -NoNewline
                    Write-Host ": TcpNoDelay registry key exists. Setting value to 1."
                    Set-ItemProperty -Path $RegKeyPath -Name 'TcpNoDelay' -Value '1' -Type DWORD -Force -ErrorAction SilentlyContinue
                    Write-Log -Message "TcpNoDelay registry key exists. Setting value to 1." -Severity Warning
                }
            }
            if ($resp.ToUpper() -eq 'N') {
                Write-Host "ABORTED" -ForegroundColor Yellow -NoNewline
                Write-Host ": TcpNoDelay registry key not created or altered by request of user."
                Write-Log -Message "TcpNoDelay registry key not created or altered by request of user." -Severity Warning
            }
        }
    }
    else {
        Write-host " "
        Write-Host "The -EnableIscsiTests parameter not present. No iSCSI tests will be run." -ForegroundColor Yellow
        Write-Host " "
        Write-Log -Message "The -EnableIscsiTests parameter not present. No iSCSI tests will be run." -Severity Information
    }
    Write-Host ''
    Write-Host "The Test-WindowsBestPractices cmdlet has completed. The log file has been created for reference." -ForegroundColor Green
    Write-Host ''
    Write-Log -Message "The Test-WindowsBestPractices cmdlet has completed." -Severity Information
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
    Unregister-HostVolumes -CimSession 'myComputer'
    #>

    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [CimSession]$CimSession
    )

    Update-HostStorageCache @PSBoundParameters
    $disks = Get-Disk -FriendlyName 'PURE FlashArray*' @PSBoundParameters | where OperationalStatus -ne "Other"

    ForEach ($disk in $disks) {
        if (!$disk.IsOffline -and $PSCmdlet.ShouldProcess("Disk $($disk.Number)", "Set disk offline")) {
            $disk | Set-Disk -IsOffline $true @PSBoundParameters
        }
    }
}

function Update-DriveInformation() {
    <#
    .SYNOPSIS
    Updates drive letters and assigns a label.
    .DESCRIPTION
    Thsi cmdlet will update the current drive letter to the new drive letter, and assign a new drive label if specified.
    .PARAMETER NewDriveLetter
    Required. Drive lettwre without the colon.
    .PARAMETER CurrentDriveLetter
    Required. Drive lettwre without the colon.
    .PARAMETER NewDriveLabel
    Optional. Drive label text. Defaults to "NewDrive".
    .PARAMETER CimSession
    Optional. A CimSession or computer name.
    .INPUTS
    None
    .OUTPUTS
    None
    .EXAMPLE
    Update-DriveInformation -NewDriveLetter S -CurrentDriveLetter M

    Updates the drive letter from M: to S: and labels S: to NewDrive.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [Parameter(Mandatory = $True)][string]$NewDriveLetter,
        [Parameter(Mandatory = $True)][string]$CurrentDriveLetter,
        [Parameter(Mandatory = $False)][string]$NewDriveLabel = 'NewDrive',
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [CimSession]$CimSession
    )

    $params = @{
        Query    = "SELECT * FROM Win32_Volume WHERE DriveLetter = '$CurrentDriveLetter`:'"
        Property = @{ DriveLetter = "$($NewDriveLetter):" }
    }

    if ($NewDriveLabel) {
        $params.Property.Add('Label', $NewDriveLabel)
    }

    if ($PSBoundParameters.ContainsKey('CimSession')) {
        $params.Add('CimSession', $CimSession)
    }

    Set-CimInstance @params | Out-Null
}

# Declare exports
Export-ModuleMember -Function Get-HostBusAdapter
Export-ModuleMember -Function Get-FlashArraySerialNumbers
Export-ModuleMember -Function Get-QuickFixEngineering
Export-ModuleMember -Function Get-VolumeShadowCopy
Export-ModuleMember -Function Get-MPIODiskLBPolicy
Export-ModuleMember -Function Set-MPIODiskLBPolicy
Export-ModuleMember -Function Set-TlsVersions
Export-ModuleMember -Function Enable-SecureChannelProtocol
Export-ModuleMember -Function Disable-SecureChannelProtocol
Export-ModuleMember -Function Register-HostVolumes
Export-ModuleMember -Function Unregister-HostVolumes
Export-ModuleMember -Function Update-DriveInformation
# END
