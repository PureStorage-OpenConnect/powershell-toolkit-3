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
        [Parameter(Mandatory=$False)][string]$ExcelFile = "HypervClusterReport.xlxs"
    )
    try {
        Get-ElevatedStatus

        Get-HypervStatus

        ## Check for modules & features
        Write-Host "Checking, installing, and importing prerequisite modules."
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $modulesArray = @(
            "PureStoragePowerShellSDK",
            "ImportExcel"
        )
        ForEach ($mod in $modulesArray) {
            If (Get-Module -ListAvailable $mod) {
                Continue
            }
            Else {
                Install-Module $mod -Force -ErrorAction 'SilentlyContinue'
                Import-Module $mod -ErrorAction 'SilentlyContinue'
            }
        }

        Write-Host "Checking and installing prerequisite Windows Features."
        $osVer = (Get-ComputerInfo).WindowsProductName
        $featuresArray = @(
            "hyper-v-powershell",
            "rsat-clustering-powershell"
        )
        ForEach ($fea in $featuresArray) {
            If (Get-WindowsFeature $fea | Select-Object -ExpandProperty installed) {
                Continue
            }
            Else {
                If ($osVer -le "2008") {
                    Add-WindowsFeature -Name $fea -Force -ErrorAction 'SilentlyContinue'
                }
                Else {
                    Install-WindowsFeature -Name $fea -Force -ErrorAction 'SilentlyContinue'
                }
            }
        }

        # Connect to FlashArray
        if (!($Creds)) {
            try {
                $FlashArray = New-PfaArray -EndPoint $EndPoint -Credentials (Get-Credential) -IgnoreCertificateError
            }
            catch {
                $ExceptionMessage = $_.Exception.Message
                Write-Error "Failed to connect to FlashArray endpoint $Endpoint with: $ExceptionMessage"
                Return
            }
        }
        else {
            try {
                $FlashArray = New-PfaArray -EndPoint $EndPoint -Credentials $Creds -IgnoreCertificateError
            }
            catch {
                $ExceptionMessage = $_.Exception.Message
                Write-Error "Failed to connect to FlashArray endpoint $Endpoint with: $ExceptionMessage"
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
        $serials = GetSerial { $pathQ } -ErrorAction SilentlyContinue

        ## FlashArray volumes
        $pureVols = Get-PfaVolumes -Array $FlashArray | Where-Object { $serials.serialnumber -contains $_.serial } | ForEach-Object { Get-PfaVolumeSpaceMetrics -Array $FlashArray -VolumeName $_.name } | Select-Object name, size, total, data_reduction

        $pureVols | Select-Object Name, @{Name = "Size(GB)"; Expression = { [math]::round($_.size / 1gb, 2) } }, @{Name = "SizeOnDisk(GB)"; Expression = { [math]::round($_.total / 1gb, 2) } }, @{Name = "DataReduction"; Expression = { [math]::round($_.data_reduction, 2) } } | Export-Csv $PfaCsvFileName -NoTypeInformation
        Import-Csv $PfaCsvFileName | Export-Excel -Path $ExcelFile -AutoSize -WorkSheetname 'FlashArrays'

    }
    catch {
        Write-Host "There was a problem running this cmdlet. Please try again or submit an Issue in the GitHub Repository."
    }
}