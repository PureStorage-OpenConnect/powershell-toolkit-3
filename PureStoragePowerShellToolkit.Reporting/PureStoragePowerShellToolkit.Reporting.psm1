<#
    ===========================================================================
    Release version: 3.0.0
    Revision information: Refer to the changelog.md file
    ---------------------------------------------------------------------------
    Maintained by:   FlashArray Integrations and Evangelsigm Team @ Pure Storage
    Organization:    Pure Storage, Inc.
    Filename:        PureStoragePowerShellToolkit.Reporting.psm1
    Copyright:       (c) 2023 Pure Storage, Inc.
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
#Requires -Modules @{ ModuleName='ImportExcel'; ModuleVersion='7.8.4' }
#Requires -Modules @{ ModuleName='PureStoragePowerShellToolkit.FlashArray'; ModuleVersion='3.0.0.3' }

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

function New-FlashArrayExcelReport {
    <#
    .SYNOPSIS
    Create an Excel workbook that contains FlashArray Information for each endpoint specified.
    .DESCRIPTION
    This cmdlet will retrieve array, volume, host, pod, and snapshot capacity information from all of the endpoints and output it to an Excel spreadsheet. Each FlashArray will have it's own filename and the current date and time will be added to the filenames.
    This cmdlet requires the PowerShell module ImportExcel - https://www.powershellgallery.com/packages/ImportExcel
    .PARAMETER Endpoint
    Required. An IP address or FQDN of the FlashArray. Multiple endpoints can be specified.
    .PARAMETER OutPath
    Optional. Directory path for Excel workbook. If not specified, the files will be placed in the %temp% folder.
    .PARAMETER SnapLimit
    Optional. This will limit the total number of Volume snapshots returned from the arrays. This will be beneficial when working with a large number of snapshots. With a large number of snapshots, and not setting this limit, the worksheet creation time is increased considerably.
    .PARAMETER Credential
    Optional. Credential for the FlashArray.
    .INPUTS
    None
    .OUTPUTS
    An Excel workbook
    .EXAMPLE
    New-FlashArrayExcelReport -Endpoint 'myarray.mydomain.com'

    Creates an Excel file in the %temp% folder for array myarray.mydomain.com.

    .EXAMPLE
    New-FlashArrayExcelReport -Endpoint 'myarray01', 'myarray02' -OutPath '.\reports'

    Creates an Excel file for myarray01 and myarray02. Reports are located in the 'reports' folder.

    .EXAMPLE
    Get-Content '.\arrays.txt' | New-FlashArrayExcelReport -OutPath '.\reports'

    Creates an Excel file for each array in the arrays.txt file. Reports are located in the 'reports' folder.

    .EXAMPLE
    New-FlashArrayExcelReport -Endpoint 'myarray.mydomain.com' -Credential (Get-Credential) -OutPath '.\reports'

    Creates an Excel file in the 'reports' folder for array myarray.mydomain.com. Asks for FlashArray credentials.

    .EXAMPLE
    $endpoint = [pscustomobject]@{Endpoint = @('myarray.mydomain.com'); Credential = (Get-Credential)}
    $endpoint | New-FlashArrayExcelReport -OutPath '.\reports'

    Creates an Excel file in the 'reports' folder for array myarray.mydomain.com. Asks for FlashArray credentials.

    .NOTES
    This cmdlet can utilize the global credential variable for FlashArray authentication. Set the credential variable by using the command Set-PfaCredential.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Endpoint,
        [int]$SnapLimit,
        [string]$OutPath = $env:Temp,
        [Parameter(ValueFromPipelineByPropertyName)]
        [pscredential]$Credential = ( Get-PfaCredential )
    )

    begin {
        $date = (Get-Date).ToString('MMddyyyy_HHmmss')
    }

    process {
        # Run through each array
        foreach ($e in $Endpoint) {
            Write-Host "Starting to read from array $e ..." -ForegroundColor green

            # Connect to FlashArray(s)
            try {
                $flashArray = Connect-Pfa2Array -Endpoint $e -Credential $Credential -IgnoreCertificateError
            }
            catch {
                $exceptionMessage = $_.Exception.Message
                Write-Error "Failed to connect to FlashArray endpoint $e with: $exceptionMessage"
                Return
            }

            try {
                $array_details = Get-Pfa2Array -Array $flasharray
                $host_details = Get-Pfa2Host -Array $flasharray -Sort 'name'
                $hostgroup = Get-Pfa2HostGroup -Array $flasharray
                $volumes = Get-Pfa2Volume -Array $flasharray -Sort 'name'
                $pgd = Get-Pfa2ProtectionGroup -Array $flasharray
                $pgst = Get-Pfa2ProtectionGroupSnapshotTransfer -Array $flasharray -Sort 'name'
                $controllers = Get-Pfa2Controller -Array $flasharray
                $controller0_details = $controllers | Where-Object Name -eq 'CT0'
                $controller1_details = $controllers | Where-Object Name -eq 'CT1'
                $free = $array_details.capacity - $array_details.space.TotalPhysical
                $lim = @{}
                if ($PSBoundParameters.ContainsKey('SnapLimit')) {
                    $lim.Add('Limit', $SnapLimit)
                }
                $snapshots = Get-Pfa2VolumeSnapshot -Array $flashArray @lim
                $pods = Get-Pfa2Pod -Array $flashArray
            
                Write-Host 'Read complete. Disconnecting and continuing...' -ForegroundColor green
            }
            finally {
                # Disconnect 'cause we don't need to waste the connection anymore
                Disconnect-Pfa2Array -Array $flasharray
            }

            # Name and path the files
            $excelFile = Join-Path $OutPath "$($array_details.name)-$date.xlsx"
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
                '% Utilized'            = '{0:P}' -f ($array_details.space.TotalPhysical / $array_details.capacity)
                'Total Capacity(TB)'    = Convert-UnitOfSize $array_details.Capacity -To 1TB
                'Used Capacity(TB)'     = Convert-UnitOfSize $array_details.space.TotalPhysical -To 1TB
                'Free Capacity(TB)'     = Convert-UnitOfSize $free -To 1TB
                'Provisioned Size(TB)'  = Convert-UnitOfSize $array_details.space.TotalProvisioned -To 1TB
                'Unique Data(TB)'       = Convert-UnitOfSize $array_details.space.Unique -To 1TB
                'Shared Data(TB)'       = Convert-UnitOfSize $array_details.space.shared -To 1TB
                'Snapshot Capacity(TB)' = Convert-UnitOfSize $array_details.space.snapshots -To 1TB
            } | Export-Excel $excelFile -WorksheetName 'Array_Info' -AutoSize -TableName 'ArrayInformation' -Title 'FlashArray Information'

            ## Volume Details
            $details = $volumes | Select-Object Name, `
                @{n = 'Size(GB)'; e = { Convert-UnitOfSize $_.provisioned -To 1GB } }, `
                @{n = 'Unique Data(GB)'; e = { Convert-UnitOfSize $_.space.Unique -To 1GB } }, `
                @{n = 'Shared Data(GB)'; e = { Convert-UnitOfSize $_.space.Shared -To 1GB } }, `
                Serial, `
                ConnectionCount, `
                Created, `
                @{n = 'Volume Group'; e = { $_.VolumeGroup.Name } }, `
                Destroyed, `
                TimeRemaining

            $simple = @()
            $vvol = @()
            foreach ($v in $details) {
                if ($v.Name -like '*vvol*') {
                    $vvol +=$v
                }
                else {
                    $simple +=$v
                }
            }

            if ($simple) {
                $simple | Export-Excel $excelFile -WorksheetName 'Volumes-No vVols' -AutoSize -TableName 'VolumesNovVols' -Title 'Volumes - Not including vVols'
            }
            else {
                Write-Host 'No Volumes exist on Array. Skipping.'
            }

            if ($vvol) {
                $vvol | Export-Excel $excelFile -WorksheetName 'vVol Volumes' -AutoSize -TableName 'vVolVolumes' -Title 'vVol Volumes'
            }
            else {
                Write-Host 'No vVol Volume exist on Array. Skipping.'
            }

            ## Volume Snapshot details
            if ($snapshots) {
                $snapshots | Select-Object Name, `
                    Created, `
                    @{n = 'Provisioned(GB)'; e = { Convert-UnitOfSize $_.Provisioned -To 1GB } }, `
                    Destroyed, `
                    @{n = 'Source'; e = { $_.Source.Name } }, `
                    @{n = 'Pod'; e = { $_.pod.name } }, `
                    @{n = 'Volume Group'; e = { $_.VolumeGroup.Name } } | 
                Export-Excel $excelFile -WorksheetName 'Volume Snapshots' -AutoSize -TableName 'VolumeSnapshots' -Title 'Volume Snapshots'
            }
            else {
                Write-Host 'No Volume Snapshots exist on Array. Skipping.'
            }

            # Host Details
            if ($host_details) {
                $host_details | Select-Object Name, `
                    @{n = 'No. of Volumes'; e = { $_.ConnectionCount } }, `
                    @{n = 'HostGroup'; e = { $_.HostGroup.Name } }, `
                    Personality, `
                    @{n = 'Allocated(GB)'; e = { Convert-UnitOfSize $_.space.totalprovisioned -To 1GB } }, `
                    @{n = 'Wwns'; e = { $_.Wwns -join ', ' } } | 
                Export-Excel $excelFile -WorksheetName 'Hosts' -AutoSize -TableName 'Hosts' -Title 'Host Information'
            }
            else {
                Write-Host 'No Hosts exist on Array. Skipping.'
            }
            
            ## HostGroup Details
            if ($hostgroup) {
                $hostgroup | Select-Object Name, `
                    HostCount, `
                    @{n = 'No. of Volumes'; e = { $_.ConnectionCount } }, `
                    @{n = 'Total Size(GB)'; e = { Convert-UnitOfSize $_.space.totalprovisioned -To 1GB } } | 
                Export-Excel $excelFile -WorksheetName 'Host Groups' -AutoSize -TableName 'HostGroups' -Title 'Host Groups'
            }
            else {
                Write-Host 'No Host Groups exist on Array. Skipping.'
            }
            
            ## Protection Group and Protection Group Transfer details
            if ($pgd) {
                $pgd | Select-Object Name, `
                    @{n = 'Snapshot Size(GB)'; e = { Convert-UnitOfSize $_.space.snapshots -To 1GB } }, `
                    VolumeCount, `
                    @{n = 'Source'; e = { $_.source.name } } | 
                Export-Excel $excelFile -WorksheetName 'Protection Groups' -AutoSize -TableName 'ProtectionGroups' -Title 'Protection Group'
            }
            else {
                Write-Host 'No Protection Groups exist on Array. Skipping.'
            }

            if ($pgst) {
                $pgst | Select-Object Name, `
                    @{n = 'Data Transferred(MB)'; e = { Convert-UnitOfSize $_.DataTransferred -To 1MB } }, `
                    Destroyed, `
                    @{n = 'Physical Bytes Written(MB)'; e = { Convert-UnitOfSize $_.PhysicalBytesWritten -To 1MB } }, `
                    @{n = 'Status'; e = { $_.Progress -Replace ('1', 'Transfer Complete') } } | 
                Export-Excel $excelFile -WorksheetName 'PG Snapshot Transfers' -AutoSize -TableName 'PGroupSnapshotTransfers' -Title 'Protection Group Snapshot Transfers'
            }
            else {
                Write-Host 'No Protection Group Transfer details on Array. Skipping.'
            }

            ## Pod details
            if ($pods) {
                $pods | Select-Object Name, `
                    ArrayCount, `
                    @{ n = 'Source'; e = { $_.source.name } }, `
                    Mediator, `
                    PromotionStatus, `
                    Destroyed | 
                Export-Excel $excelFile -WorksheetName 'Pods' -AutoSize -TableName 'Pods' -Title 'Pod Information'
            }
            else {
                Write-Host 'No Pods exist on Array. Skipping.'
            }
        }
    }

    end{
        Write-Host "Complete. Files located in $(Resolve-Path $OutPath)" -ForegroundColor green
    }
}

function New-HypervClusterVolumeReport() {
    <#
    .SYNOPSIS
    Creates a Excel report on volumes connected to a Hyper-V cluster.
    .DESCRIPTION
    This creates separate CSV files for VM, Windows Hosts, and FlashArray information for each endpoint specified that is part of a HyperV cluster. It then takes that output and places it into a an Excel workbook that contains sheets for each CSV file.
    .PARAMETER Endpoint
    Required. An IP address or FQDN of the FlashArray. Multiple endpoints can be specified.
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
    New-HypervClusterVolumeReport -Endpoint myarray -VmCsvName myVMs.csv -WinCsvName myWinHosts.csv -PfaCsvName myFlashArray.csv -ExcelFile myExcelFile.xlsx

    This will create three separate CSV files with HyperV cluster information and incorporate them into a single Excel workbook.

    .EXAMPLE
    New-HypervClusterVolumeReport -Endpoint 'myarray01', 'myarray02'

    This will create files with HyperV cluster information, and FlashArray information for myarray01, and myarray02.

    .EXAMPLE
    Get-Content '.\arrays.txt' | New-HypervClusterVolumeReport

    This will create files with HyperV cluster information, and FlashArray information for each array in the arrays.txt file.

    .EXAMPLE
    New-HypervClusterVolumeReport -Endpoint 'myarray.mydomain.com' -Credential (Get-Credential)

    This will create files with HyperV cluster information, and FlashArray information for myarray.mydomain.com. Asks for FlashArray credentials.

    .EXAMPLE
    $endpoint = [pscustomobject]@{Endpoint = @('myarray.mydomain.com'); Credential = (Get-Credential)}
    $endpoint | New-HypervClusterVolumeReport

    This will create files with HyperV cluster information, and FlashArray information for myarray.mydomain.com. Asks for FlashArray credentials.

    .NOTES
    This cmdlet can utilize the global credential variable for FlashArray authentication. Set the credential variable by using the command Set-PfaCredential.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Endpoint,
        [string]$VmCsvFileName = "VMs.csv",
        [string]$WinCsvFileName = "WindowsHosts.csv",
        [string]$PfaCsvFileName = "FlashArrays.csv",
        [string]$ExcelFile = "HypervClusterReport.xlsx",
        [Parameter(ValueFromPipelineByPropertyName)]
        [pscredential]$Credential = ( Get-PfaCredential )
    )

    begin {
        #Validate modules
        $modules = @('Hyper-V', 'FailoverClusters')
        foreach ($module in $modules) {
            if (-not (Get-Module -ListAvailable $module)) {
                Write-Error "Required module $module not found"
                return
            }
        }
    
        #Get VMs & VHDs
        $nodes = Get-ClusterNode
        $vhds = Get-VM -ComputerName $nodes.Name | foreach { $_ } -PipelineVariable 'vm' | foreach {
            Get-Vhd -ComputerName $_.ComputerName -VmId $_.VmId 
        } | foreach {
            [pscustomobject]@{
                'VM Name'           = $vm.Name
                'VM State'          = $vm.State
                ComputerName        = $_.ComputerName
                Path                = $_.Path
                'VHD Type'          = $_.VhdType
                'Size (GB)'         = Convert-UnitOfSize $_.Size -To 1GB
                'Size on disk (GB)' = Convert-UnitOfSize $_.FileSize -To 1GB
            }
        }

        if ($vhds) {
            $vhds | Export-Csv $VmCsvFileName -NoTypeInformation
            $vhds | Export-Excel -Path $ExcelFile -AutoSize -WorkSheetname 'VMs' -TableName 'vm'
        }

        #Get hosts and volumes
        $volumes = $nodes | foreach { $_ } -PipelineVariable 'node' | foreach {
            Get-Disk -CimSession $node.Name | where Number -ne $null | Get-Partition | Get-Volume 
        } | where DriveType -eq Fixed | foreach {
            [pscustomobject]@{
                ComputerName        = $node.Name
                Label               = $_.FileSystemLabel
                Name                = if ($_.DriveLetter) { "$($_.DriveLetter):\" } else { $_.Path }
                'Total size (GB)'   = Convert-UnitOfSize $_.Size -To 1GB
                'Free space (GB)'   = Convert-UnitOfSize $_.SizeRemaining -To 1GB
                'Size on disk (GB)' = Convert-UnitOfSize ($_.Size - $_.SizeRemaining) -To 1GB
            }
        }

        if ($volumes) {
            $volumes | Export-Csv $WinCsvFileName -NoTypeInformation
            $volumes | Export-Excel -Path $ExcelFile -AutoSize -WorkSheetname 'Windows Hosts' -TableName 'host'
        }

        #Get Pure volumes
        $sn = $vhds | 
        foreach { Get-Volume -FilePath $_.Path -CimSession $_.ComputerName } | 
        group 'ObjectId' | 
        foreach { $_.Group[0] } | 
        Get-Partition | 
        Get-Disk | 
        select -ExpandProperty 'SerialNumber'

        $pureVolumes = @()
    }

    process {
        #Run through each array
        foreach ($e in $Endpoint) {
            #Connect to FlashArray
            try {
                $flashArray = Connect-Pfa2Array -Endpoint $e -Credential $Credential -IgnoreCertificateError
            }
            catch {
                $ExceptionMessage = $_.Exception.Message
                Write-Error "Failed to connect to FlashArray endpoint $e with: $ExceptionMessage"
                return
            }

            #FlashArray volumes
            try {
                $details = Get-Pfa2Array -Array $flasharray

                $pureVolumes += Get-Pfa2Volume -Array $flashArray | where { $sn -contains $_.serial } | select 'Name' -ExpandProperty 'Space' | foreach {
                    [pscustomobject]@{
                        Array               = $details.Name
                        Name                = $_.Name
                        'Size (GB)'         = Convert-UnitOfSize $_.TotalProvisioned -To 1GB
                        'Size on disk (GB)' = Convert-UnitOfSize $_.TotalPhysical -To 1GB
                        'Data Reduction'    = [math]::round($_.DataReduction, 2)
                    }
                }
            }
            finally {
                Disconnect-Pfa2Array -Array $flashArray
            }
        }
    }

    end {
        if ($pureVolumes) {
            $pureVolumes | Export-Csv $PfaCsvFileName -NoTypeInformation
            $pureVolumes | Export-Excel -Path $ExcelFile -AutoSize -WorkSheetname 'FlashArrays' -TableName 'volume'
        }
    }
}

# Declare exports
Export-ModuleMember -Function New-FlashArrayExcelReport
Export-ModuleMember -Function New-HypervClusterVolumeReport
# END
