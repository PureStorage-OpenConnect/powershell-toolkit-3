<#
    ===========================================================================
    Release version: 3.0.0.1
    Revision information: Refer to the changelog.md file
    ---------------------------------------------------------------------------
    Maintained by:   FlashArray Integrations and Evangelsigm Team @ Pure Storage
    Organization:    Pure Storage, Inc.
    Filename:        PureStoragePowerShellToolkit.Reporting.psm1
    Copyright:       (c) 2022 Pure Storage, Inc.
    Module Name:     PureStoragePowerShellToolkit.Reporting
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
#Requires -Modules 'ImportExcel', 'PureStoragePowerShellToolkit.FlashArray'

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

Function New-FlashArrayExcelReport {
    <#
    .SYNOPSIS
    Create an Excel workbook that contains FlashArray Information for each array specified in a file.
    .DESCRIPTION
    This cmdlet will retrieve array, volume, host, pod, and snapshot capacity information from all of the FlashArrays listed in the txt file and output it to an Excel spreadsheet. Each arrays will have it's own filename and the current date and time will be added to the filenames.
    This cmdlet requires the PowerShell module ImportExcel - https://www.powershellgallery.com/packages/ImportExcel
    .PARAMETER Username
    Optional. Required if $Creds variable is not used.
    Full username to login to the arrays. This currently must be the same username for all arrays. This user must have the array-admin role.
    If not supplied, the $Creds variable must exist in the session and be set by Get-Credential.
    .PARAMETER PassFilePath
    Optional. Required if $Creds variable is not used.
    Full path and filename that contains the plaintext password for the $username. The password will be encrypted when passing to the array.
    If not supplied, the $Creds variable must exist in the session and be set by Get-Credential.
    .PARAMETER ArrayList
    Required. Full path to file name that contains IP addresses or FQDN's for all FlashAarays being reported on. This is a plain text file with each array on a new line.
    .PARAMETER OutPath
    Optional. Full directory path (with no trailing "\") for Excel workbook, formatted as DRIVE_LETTER:\folder_name. If not specified, the files will be placed in the %temp% folder.
    .PARAMETER snapLimit
    Optional. This will limit the total number of Volume snapshots returned from the arrays. This will be beneficial when working with a large number of snapshots. With a large number of snapshots, and not setting this limit, the worksheet creation time is increased considerably.
    .INPUTS
    None
    .OUTPUTS
    An Excel workbook
    .EXAMPLE
    New-FlashArrayExcelReport -Username "pureuser" -PassFilePath "c:\temp\creds.txt" -ArrayList "c:\temp\arrays.txt"

    Creates an Excel file in the the %temp% folder for each array in the Arrays.txt file, using the username and plaintext password file supplied.

    .EXAMPLE
    $Creds = (Get-Credential)
    New-FlashArrayExcelReport -ArrayList "c:\temp\arrays.txt" -snapLimit 25 -OutPath "c:\outputs"

    Creates an Excel file for each array in the Arrays.txt file, using the credentials preconfigured via the Get-Credentials cmdlet supplied.

    .NOTES
    This cmdlet can utilize the global $Creds variable for FlashArray authentication. Set the variable $Creds by using the command $Creds = Get-Credential.
    This cmdlet requires the PowerShell module ImportExcel.
    #>
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][string] $Arraylist,
        [Parameter(Mandatory = $False)][string] $OutPath = "$env:Temp",
        [Parameter(Mandatory = $False)][string] $snapLimit,
        [Parameter(Mandatory = $False)][string] $Username,
        [Parameter(Mandatory = $False)][string] $PassFilePath
    )

    # Check for Creds
    if (!($Creds)) {
        $pass = Get-Content -Path $PassFilePath | ConvertTo-SecureString -AsPlainText
        $Creds = New-Object System.Management.Automation.PSCredential($username, $pass)
    }

    # Assign variables
    $arrays = Get-Content -Path $arraylist
    $date = (Get-Date).ToString('MMddyyyy_HHmmss')
    # Run through each array
    Write-Host 'Starting to read from array...' -ForegroundColor green
    foreach ($array in $arrays) {
        $flasharray = Connect-Pfa2Array -Endpoint $array -Credential $Creds -IgnoreCertificateError
        $array_details = Get-Pfa2Array -Array $flasharray
        $host_details = Get-Pfa2Host -Array $flasharray -Sort 'name'
        $hostgroup = Get-Pfa2HostGroup -Array $flasharray
        $vol_details = Get-Pfa2Volume -Array $flasharray -Sort 'name' -Filter "not(contains(name,'vvol'))"
        $vvol_details = Get-Pfa2Volume -Array $flasharray -Sort 'name' -Filter "contains(name,'vvol')"
        $pgd = Get-Pfa2ProtectionGroup -Array $flasharray
        $pgst = Get-Pfa2ProtectionGroupSnapshotTransfer -Array $flasharray -Sort 'name'
        $controller0_details = Get-Pfa2Controller -Array $flasharray | Where-Object Name -EQ CT0
        $controller1_details = Get-Pfa2Controller -Array $flasharray | Where-Object Name -EQ CT1
        $free = $array_details.capacity - $array_details.space.TotalPhysical
        if ($PSBoundParameters.ContainsKey('snapLimit')) {
            $snapshots = Get-Pfa2VolumeSnapshot -Array $FlashArray -Limit $snapLimit
        }
        else {
            $snapshots = Get-Pfa2VolumeSnapshot -Array $FlashArray
        }
        $pods = Get-Pfa2Pod -Array $FlashArray
        Write-Host 'Read complete. Disconnecting and continuing...' -ForegroundColor green
        # Disconnect 'cause we don't need to waste the connection anymore
        Disconnect-Pfa2Array -Array $flasharray

        # Name and path the files
        $wsname = $array_details.name
        $excelFile = "$outPath\$wsname-$date.xlsx"
        Write-Host 'Writing data to Excel workbook...' -ForegroundColor green
        # Array Information
        [PSCustomObject]@{
            'Array Name'            = ($array_details.Name).ToUpper()
            'Array ID'              = $array_details.Id
            'Purity Version'        = $array_details.Version
            'CT0-Mode'              = $controller0_details.Mode
            'CT0-Status'            = $controller0_details.Status
            'CT1-Mode'              = $controller1_details.Mode
            'CT1-Status'            = $controller1_details.Status
            '% Utilized'            = '{0:P}' -f ($array_details.space.TotalPhysical / $array_details.capacity )
            'Total Capacity(TB)'    = [math]::round($array_details.Capacity / 1024 / 1024 / 1024 / 1024, 2)
            'Used Capacity(TB)'     = [math]::round($array_details.space.TotalPhysical / 1024 / 1024 / 1024 / 1024, 2)
            'Free Capacity(TB)'     = [math]::round($free / 1024 / 1024 / 1024 / 1024, 2)
            'Provisioned Size(TB)'  = [math]::round($array_details.space.TotalProvisioned / 1024 / 1024 / 1024 / 1024, 2)
            'Unique Data(TB)'       = [math]::round($array_details.space.Unique / 1024 / 1024 / 1024 / 1024, 2)
            'Shared Data(TB)'       = [math]::round($array_details.space.shared / 1024 / 1024 / 1024 / 1024, 2)
            'Snapshot Capacity(TB)' = [math]::round($array_details.space.snapshots / 1024 / 1024 / 1024 / 1024, 2)
        } | Export-Excel $excelFile -WorksheetName 'Array_Info' -AutoSize -TableName 'ArrayInformation' -Title 'FlashArray Information'

        ## Volume Details
        $vol_details | Select-Object name, @{n = 'Size(GB)'; e = { [math]::round(($_.provisioned / 1024 / 1024 / 1024), 2) } }, @{n = 'Unique Data(GB)'; e = { [math]::round(($_.space.Unique / 1024 / 1024 / 1024), 2) } }, @{n = 'Shared Data(GB)'; e = { [math]::round(($_.space.Shared / 1024 / 1024 / 1024), 2) } }, serial, ConnectionCount, Created, @{n = 'Volume Group'; e = { $_.VolumeGroup.Name } }, Destroyed, TimeRemaining | Export-Excel $excelFile -WorksheetName 'Volumes-No vVols' -AutoSize -ConditionalText $(New-ConditionalText Stop DarkRed LightPink) -TableName 'VolumesNovVols' -Title 'Volumes - Not including vVols'
        ## vVol Volume Details
        if ($vvol_details) {
            $vvol_details | Select-Object name, @{n = 'Size(GB)'; e = { [math]::round(($_.provisioned / 1024 / 1024 / 1024), 2) } }, @{n = 'Unique Data(GB)'; e = { [math]::round(($_.space.Unique / 1024 / 1024 / 1024), 2) } }, @{n = 'Shared Data(GB)'; e = { [math]::round(($_.space.Shared / 1024 / 1024 / 1024), 2) } }, serial, ConnectionCount, Created, @{n = 'Volume Group'; e = { $_.VolumeGroup.Name } }, Destroyed, TimeRemaining | Export-Excel $excelFile -WorksheetName 'vVol Volumes' -AutoSize -ConditionalText $(New-ConditionalText Stop DarkRed LightPink) -TableName 'vVolVolumes' -Title 'vVol Volumes'
        }
        else {
            Write-Host 'No vVol Volumes exist on Array. Skipping.'
        }
        ## Volume Snapshot details
        if ($snapshots) {
            $snapshots | Select-Object Name, Created, @{n = 'Provisioned(GB)'; e = { [math]::round(($_.Provisioned / 1024 / 1024 / 1024), 2) } }, Destroyed, @{n = 'Source'; e = { $_.Source.Name } }, @{n = 'Pod'; e = { $_.pod.name } }, @{n = 'Volume Group'; e = { $_.VolumeGroup.Name } } | Export-Excel $excelFile -WorksheetName 'Volume Snapshots' -AutoSize -TableName 'VolumeSnapshots' -Title 'Volume Snapshots'
        }
        else {
            Write-Host 'No Volume Snapshots exist on Array. Skipping.'
        }
        # Host Details
        $host_details | Select-Object Name, @{n = 'No. of Volumes'; e = { $_.ConnectionCount } }, @{n = 'HostGroup'; e = { $_.HostGroup.Name } }, Personality, @{n = 'Allocated(GB)'; e = { [math]::round(($_.space.totalprovisioned / 1024 / 1024 / 1024), 2) } }, @{n = 'Wwns'; e = { $_.Wwns -join ',' } } | Export-Excel $excelFile -WorksheetName 'Hosts' -AutoSize -TableName 'Hosts' -Title 'Host Information'
        ## HostGroup Details
        if ($hostgroup) {
            $hostgroup | Select-Object Name, HostCount, @{n = 'No.of Volumes'; e = { $_.ConnectionCount } }, @{n = 'Total Size(GB)'; e = { [math]::round(($_.space.totalprovisioned / 1024 / 1024 / 1024), 2) } } | Export-Excel $excelFile -WorksheetName 'Host Groups' -AutoSize -TableName 'HostGroups' -Title 'Host Groups'
        }
        else {
            Write-Host 'No Host Groups exist on Array. Skipping.'
        }
        ## Protection Group and Protection Group Transfer details
        if ($pgd) {
            $pgd | Select-Object Name, @{n = 'Snapshot Size(GB)'; e = { [math]::round(($_.space.snapshots / 1024 / 1024 / 1024), 2) } }, volumecount, @{n = 'Source'; e = { $_.source.name } } | Export-Excel $excelFile -WorksheetName 'Protection Groups' -AutoSize -TableName 'ProtectionGroups' -Title 'Protection Group'
            $pgst | Select-Object Name, @{n = 'Data Transferred(MB)'; e = { [math]::round(($_.DataTransferred / 1024 / 1024), 2) } }, Destroyed, @{n = 'Physical Bytes Written(MB)'; e = { [math]::round(($_.PhysicalBytesWritten / 1024 / 1024), 2) } }, @{n = 'Status'; e = { $_.Progress -Replace ('1', 'Transfer Complete') } } | Export-Excel $excelFile -WorksheetName 'PG Snapshot Transfers' -AutoSize -TableName 'PGroupSnapshotTransfers' -Title 'Protection Group Snapshot Transfers'
        }
        else {
            Write-Host 'No Protection Groups exist on Array. Skipping.'
        }
        ## Pod details
        if ($pods) {
            $pods | Select-Object Name, arraycount, @{n = 'Source'; e = { $_.source.name } }, mediator, promotionstatus, destroyed | Export-Excel $excelFile -WorksheetName 'Pods' -AutoSize -TableName 'Pods' -Title 'Pod Information'
        }
        else {
            Write-Host 'No Pods exist on Array. Skipping.'
        }
    }
    Write-Host "Complete. Files located in $outpath" -ForegroundColor green
}

function New-HypervClusterVolumeReport() {
    <#
    .SYNOPSIS
    Creates a Excel report on volumes connected to a Hyper-V cluster.
    .DESCRIPTION
    This creates separate CSV files for VM, Windows Hosts, and FlashArray information that is part of a HyperV cluster. It then takes that output and places it into a an Excel workbook that contains sheets for each CSV file.
    .PARAMETER VmCsvFileName
    Optional. Defaults to VMs.csv.
    .PARAMETER WinCsvFileName
    Optional. defaults to WindowsHosts.csv.
    .PARAMETER PfaCsvFileName
    Optional. defaults to FlashArrays.csv.
    .PARAMETER ExcelFile
    Optional. defaults to HypervClusterReport.xlsx.
    .INPUTS
    Endpoint is mandatory. VM, Win, and PFA csv file names are optional.
    .OUTPUTS
    Outputs individual CSV files and creates an Excel workbook that is built using the required PowerShell module ImportExcel, created by Douglas Finke.
    .EXAMPLE
    New-HypervClusterVolumeReport -EndPoint myarray -VmCsvName myVMs.csv -WinCsvName myWinHosts.csv -PfaCsvName myFlashArray.csv -ExcelFile myExcelFile

    This will create three separate CSV files with HyperV cluster information and incorporate them into a single Excel workbook.
    .NOTES
    This cmdlet can utilize the global $Creds variable for FlashArray authentication. Set the variable $Creds by using the command $Creds = Get-Credential.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, Mandatory = $True)][ValidateNotNullOrEmpty()][string] $EndPoint,
        [Parameter(Mandatory=$False)][string]$VmCsvFileName = "VMs.csv",
        [Parameter(Mandatory=$False)][string]$WinCsvFileName = "WindowsHosts.csv",
        [Parameter(Mandatory=$False)][string]$PfaCsvFileName = "FlashArrays.csv",
        [Parameter(Mandatory=$False)][string]$ExcelFile = "HypervClusterReport.xlsx",
        [Parameter(ValueFromPipelineByPropertyName)]
        [pscredential]$Credential = ( Get-PfaCredential )
    )
    try {
        Get-HypervStatus

        ## Check for modules & features
        Write-Host "Checking prerequisite modules."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $modulesArray = @(
            'Hyper-V', 'FailoverClusters'
        )
        ForEach ($mod in $modulesArray) {
            If (Get-Module -ListAvailable $mod) {
                Continue
            }
            Else {
                Write-Error "Required module $mod not found"
                Return
            }
        }

        ## Get a list of VMs - VM Sheet
        $vmList = Get-VM -ComputerName (Get-ClusterNode)
        $vmList | ForEach-Object { $vmState = $_.state; $vmName = $_.name; Write-Output $_; } | ForEach-Object { Get-VHD -ComputerName $_.ComputerName -VMId $_.VMId
        } | Select-Object -Property path, @{n = 'VMName'; e = { $vmName } }, @{n = 'VMState'; e = { $vmState } }, computername, vhdtype, @{Label = 'Size(GB)'; expression = { [Math]::Round($_.size / 1gb, 2) -as [int] } }, @{label = 'SizeOnDisk(GB)'; expression = { [Math]::Round($_.filesize / 1gb, 2) -as [int] } } | Export-Csv $VmCsvFileName
        Import-Csv $VmCsvFileName | Export-Excel -Path $ExcelFile -AutoSize -WorkSheetname 'VMs'

        ## Get windows physical disks - Windows Host Sheet
        Get-ClusterNode | ForEach-Object { Get-WmiObject Win32_Volume -Filter "DriveType='3'" -ComputerName $_ | ForEach-Object {
                [pscustomobject][ordered]@{
                    Server        = $_.__Server
                    Label         = $_.Label
                    Name          = $_.Name
                    TotalSize_GB  = ([Math]::Round($_.Capacity / 1GB, 2))
                    FreeSpace_GB  = ([Math]::Round($_.FreeSpace / 1GB, 2))
                    SizeOnDisk_GB = ([Math]::Round(($_.Capacity - $_.FreeSpace) / 1GB, 2))
                }
            } } | Export-Csv $WinCsvFileName -NoTypeInformation
        Import-Csv $WinCsvFileName | Export-Excel -Path $ExcelFile -AutoSize -WorkSheetname 'Windows Hosts'
        ## Get Pure FlashArray volumes and space - FlashArray Sheet
        Function GetSerial {
            [Cmdletbinding()]
            Param(   [Parameter(ValueFromPipeline)]
                $findserial)
            $GetVol = Get-Volume -FilePath $findserial | Select-Object -ExpandProperty path
            $GetDiskNum = Get-Partition | Where-Object -Property accesspaths -CContains $getvol | Select-Object disknumber
            Get-Disk -Number $getdisknum.disknumber | Select-Object serialnumber
        }
        $pathQ = $VmList | ForEach-Object { Get-VHD -ComputerName $_.ComputerName -VMId $_.VMId } | Select-Object -ExpandProperty path
        $serials = $pathQ | GetSerial -ErrorAction SilentlyContinue

        # Connect to FlashArray
        try {
            $flashArray = Connect-Pfa2Array -Endpoint $EndPoint -Credential $Credential -IgnoreCertificateError
        }
        catch {
            $ExceptionMessage = $_.Exception.Message
            Write-Error "Failed to connect to FlashArray endpoint $Endpoint with: $ExceptionMessage"
            Return
        }

        ## FlashArray volumes
        try {
            $pureVols = Get-Pfa2Volume -Array $FlashArray | Where-Object { $serials.serialnumber -contains $_.serial } | Select-Object name -ExpandProperty Space
        }
        finally {
            Disconnect-Pfa2Array -Array $flashArray
        }

        $pureVols | Select-Object Name, @{Name = "Size(GB)"; Expression = { [math]::round($_.TotalProvisioned / 1gb, 2) } }, @{Name = "SizeOnDisk(GB)"; Expression = { [math]::round($_.TotalPhysical / 1gb, 2) } }, @{Name = "DataReduction"; Expression = { [math]::round($_.DataReduction, 2) } } | Export-Csv $PfaCsvFileName -NoTypeInformation
        Import-Csv $PfaCsvFileName | Export-Excel -Path $ExcelFile -AutoSize -WorkSheetname 'FlashArrays'

    }
    catch {
        Write-Host "There was a problem running this cmdlet. Please try again or submit an Issue in the GitHub Repository."
    }
}

# Declare exports
Export-ModuleMember -Function New-FlashArrayExcelReport
Export-ModuleMember -Function New-HypervClusterVolumeReport
# END
