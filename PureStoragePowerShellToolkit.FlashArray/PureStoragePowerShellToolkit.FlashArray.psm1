<#
    ===========================================================================
    Release version: 3.0.1
    Revision information: Refer to the changelog.md file
    ---------------------------------------------------------------------------
    Maintained by:   FlashArray Integrations and Evangelsigm Team @ Pure Storage
    Organization:    Pure Storage, Inc.
    Filename:        PureStoragePowerShellToolkit.FlashArray.psm1
    Copyright:       (c) 2023 Pure Storage, Inc.
    Module Name:     PureStoragePowerShellToolkit.FlashArray
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
#Requires -Modules @{ ModuleName='PureStoragePowerShellSDK2'; ModuleVersion='2.16' }

#region Helper functions

function Convert-UnitOfSize {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [AllowNull()]
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

class ModuleEntity {
    hidden [string] GetSizeLabel($size) {
        return Get-SizeLabel -Size $size -Decimals 2
    }
}

class ArrayEntity : ModuleEntity {
    [string]$Array

    ArrayEntity([string]$array) {
        $this.Array = $array
    }
}

class HostVolume : ArrayEntity {
    [string]$HostName
    [string]$VolumeName
    [string]$SourceName
    [datetime]$Created
    [string]$SerialNumber
    [long]$Provisioned

    HostVolume([string]$array, 
        [string]$hostName,
        [string]$volumeName,
        [string]$sourceName,
        [datetime]$created,
        [string]$serial,
        [long]$provisioned) : base($array) {

        $this.HostName     = $hostName
        $this.VolumeName   = $volumeName
        $this.SourceName   = $sourceName
        $this.Created      = $created
        $this.SerialNumber = $serial
        $this.Provisioned  = $provisioned
    }
}

class VolumeConnection : ArrayEntity {
    [string]$HostName
    [string]$VolumeName
    [long]$Lun
    [string[]]$Iqn
    [string[]]$Wwn
    [long]$Provisioned
    [long]$Unique

    VolumeConnection([string]$array, 
        [string]$hostName,
        [string]$volumeName,
        [long]$lun,
        [string[]]$iqn,
        [string[]]$wwn,
        [long]$provisioned,
        [long]$unique) : base($array) {

        $this.HostName    = $hostName
        $this.VolumeName  = $volumeName
        $this.Lun         = $lun
        $this.Iqn         = $iqn
        $this.Wwn         = $wwn
        $this.Provisioned = $provisioned
        $this.Unique      = $unique
    }
}

class DisconnectedVolume : ArrayEntity {
    [string]$VolumeName
    [string]$SerialNumber
    [long]$Provisioned
    [long]$Unique
    [float]$DataReduction

    DisconnectedVolume([string]$array,
        [string]$volumeName,
        [string]$serial,
        [long]$provisioned,
        [long]$unique,
        [float]$reduction) : base($array) {

        $this.VolumeName    = $volumeName
        $this.SerialNumber  = $serial
        $this.Provisioned   = $provisioned
        $this.Unique        = $unique
        $this.DataReduction = $reduction
    }
}

class CapacityStats : ModuleEntity {
    [int]$ArraysCount
    [long]$Capacity
    [long]$Unique
    [double]$ReducedFrom
    [double]$TotalProvisioned
    [datetime]$CollectionDate

    CapacityStats([int]$arraysCount,
        [long]$capacity,
        [long]$unique,
        [double]$reducedFrom,
        [double]$totalProvisioned) : base() {

        $this.ArraysCount      = $arraysCount
        $this.Capacity         = $capacity
        $this.Unique           = $unique
        $this.ReducedFrom      = $reducedFrom
        $this.TotalProvisioned = $totalProvisioned
        $this.CollectionDate   = Get-Date
    }
}

class ArraySpace : ArrayEntity {
    [long]$Capacity
    [long]$CapacityFree
    [double]$PercentUsed
    [long]$TotalPhysical
    [long]$Unique
    [long]$Shared
    [long]$Snapshots
    [long]$System
    [float]$DataReduction
    [float]$ThinProvisioning

    ArraySpace([string]$array,
        [long]$capacity,
        [long]$totalPhysical,
        [long]$unique,
        [long]$shared,
        [long]$snapshots,
        [long]$system,
        [float]$dataReduction,
        [float]$thinProvisioning) : base($array) {

        $this.Capacity         = $capacity
        $this.TotalPhysical    = $totalPhysical
        $this.Unique           = $unique
        $this.Shared           = $shared
        $this.Snapshots        = $snapshots
        $this.System           = $system
        $this.DataReduction    = $dataReduction
        $this.ThinProvisioning = $thinProvisioning

        $this.CapacityFree = $this.Capacity - $this.TotalPhysical
        $this.PercentUsed  = $this.TotalPhysical / $this.Capacity
    }
}

class StaleSnapshot : ArrayEntity {
    [string]$SnapshotName
    [long]$TotalPhysical
    [bool]$Destroyed
    [timespan]$Age

    StaleSnapshot([string]$array,
        [string]$snapshotName,
        [long]$totalPhysical,
        [bool]$destroyed,
        [timespan]$age) : base($array) {

        $this.SnapshotName  = $snapshotName
        $this.TotalPhysical = $totalPhysical
        $this.Destroyed     = $destroyed
        $this.Age           = $age
    }
}

class VolumeGrowthStats : ArrayEntity {
    [string]$VolumeName
    [long]$Provisioned
    [long]$Unique
    [long]$Growth
    [double]$GrowthPercent

    VolumeGrowthStats([string]$array, 
        [string]$volumeName,
        [long]$provisioned,
        [long]$unique,
        [long]$growth,
        [double]$growthPercent) : base($array) {

        $this.VolumeName    = $volumeName
        $this.Provisioned   = $provisioned
        $this.Unique        = $unique
        $this.Growth        = $growth
        $this.GrowthPercent = $growthPercent
    }
}

class PgroupConfig : ArrayEntity {
    [string]$PgroupName
    [string[]]$HostGroups
    [string[]]$Hosts
    [string[]]$Volumes
    [string[]]$Members
    [bool]$ReplicationEnabled
    [long]$Frequency
    [int]$AllForSec
    [int]$Days
    [int]$PerDay

    PgroupConfig([string]$array,
        [string]$pgroupName,
        [string[]]$hostGroups,
        [string[]]$hosts,
        [string[]]$volumes,
        [bool]$replicationEnabled,
        [long]$frequency,
        [int]$allForSec,
        [int]$days,
        [int]$perDay) : base($array) {

            $this.PgroupName         = $pgroupName
            $this.HostGroups         = $hostGroups
            $this.Hosts              = $hosts
            $this.Volumes            = $volumes
            $this.ReplicationEnabled = $replicationEnabled
            $this.Frequency          = $frequency
            $this.AllForSec          = $allForSec
            $this.Days               = $days
            $this.PerDay             = $perDay

            $this.Members = (@($this.HostGroups, $this.Hosts, $this.Volumes) -ne $null)[0]
    }
}

$stylesheetRawXml = @"
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
    xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" mc:Ignorable="x14ac x16r2 xr"
    xmlns:x14ac="http://schemas.microsoft.com/office/spreadsheetml/2009/9/ac"
    xmlns:x16r2="http://schemas.microsoft.com/office/spreadsheetml/2015/02/main"
    xmlns:xr="http://schemas.microsoft.com/office/spreadsheetml/2014/revision">
    <numFmts count="1">
        <numFmt numFmtId="164" formatCode="m/d/yy\ h:mm;@"/>
    </numFmts>
    <fonts count="1" x14ac:knownFonts="1">
        <font>
            <sz val="11"/>
            <color theme="1"/>
            <name val="Calibri"/>
            <family val="2"/>
            <scheme val="minor"/>
        </font>
    </fonts>
    <fills count="2">
        <fill>
            <patternFill patternType="none"/>
        </fill>
        <fill>
            <patternFill patternType="gray125"/>
        </fill>
    </fills>
    <borders count="1">
        <border>
            <left/>
            <right/>
            <top/>
            <bottom/>
            <diagonal/>
        </border>
    </borders>
    <cellStyleXfs count="1">
        <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
    </cellStyleXfs>
    <cellXfs count="2">
        <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
        <xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>
    </cellXfs>
    <cellStyles count="1">
        <cellStyle name="Normal" xfId="0" builtinId="0"/>
    </cellStyles>
    <dxfs count="0"/>
    <tableStyles count="0" defaultTableStyle="TableStyleMedium2" defaultPivotStyle="PivotStyleLight16"/>
    <extLst>
        <ext uri="{EB79DEF2-80B8-43e5-95BD-54CBDDF9020C}"
            xmlns:x14="http://schemas.microsoft.com/office/spreadsheetml/2009/9/main">
            <x14:slicerStyles defaultSlicerStyle="SlicerStyleLight1"/>
        </ext>
        <ext uri="{9260A510-F301-46a8-8635-F512D64BE5F5}"
            xmlns:x15="http://schemas.microsoft.com/office/spreadsheetml/2010/11/main">
            <x15:timelineStyles defaultTimelineStyle="TimeSlicerStyleLight1"/>
        </ext>
    </extLst>
</styleSheet>
"@

function Invoke-GenericMethod {
    <#
    .SYNOPSIS
    Invoke a generic method on a non-generic type: 
    #> 
    [CmdletBinding()]
    param( 
        [Parameter(Mandatory)]
        $Instance, 
        [Parameter(Mandatory)]
        [string] $MethodName, 
        [Parameter(Mandatory=$false)]
        [Type[]] $TypeParameters = ($MethodParameters | ForEach-Object { $_.GetType() }),
        [Parameter(Mandatory=$false)]
        [object[]] $MethodParameters = @()
    ) 

    ## Determine if the types in $set1 match the types in $set2, replacing generic
    ## parameters in $set1 with the types in $genericTypes
    function ParameterTypesMatch([type[]] $Set1, [type[]] $Set2, [type[]] $GenericTypes) {
        $typeReplacementIndex = 0
        $currentTypeIndex = 0

        ## Exit if the set lengths are different
        if ($Set1.Count -ne $Set2.Count) {
            return $false
        }

        ## Go through each of the types in the first set
        foreach ($type in $Set1) {
            ## If it is a generic parameter, then replace it with a type from
            ## the $genericTypes list
            if ($type.IsGenericParameter) {
                $type = $GenericTypes[$typeReplacementIndex]
                $typeReplacementIndex++
            }

            ## Check that the current type (i.e.: the original type, or replacement
            ## generic type) matches the type from $set2
            if ($type -ne $Set2[$currentTypeIndex]) {
                return $false
            }

            $currentTypeIndex++
        }

        return $true
    }

    ## Determine the type that we will call the generic method on. Initially, assume
    ## that it is actually a type itself.
    $type = $Instance

    ## If it is not, then it is a real object, and we can call its GetType() method
    if ($Instance -isnot 'Type') {
        $type = $Instance.GetType()
    }

    ## Search for the method that:
    ##    - has the same name
    ##    - is public
    ##    - is a generic method
    ##    - has the same parameter types
    foreach ($method in $type.GetMethods()) {
        # Write-Host $method.Name
        if (($method.Name -eq $methodName) -and 
                ($method.IsPublic) -and 
                ($method.IsGenericMethod)) {
            $parameterTypes = @($method.GetParameters() | ForEach-Object { $_.ParameterType })
            $methodParameterTypes = @($MethodParameters | ForEach-Object { $_.GetType() })
            if (ParameterTypesMatch $parameterTypes $methodParameterTypes $TypeParameters) {
                ## Create a closed representation of it
                $newMethod = $method.MakeGenericMethod($TypeParameters)

                ## Invoke the method
                $newMethod.Invoke($Instance, $MethodParameters)

                return
            }
        }
    }

    ## Return an error if we couldn't find that method
    throw "Could not find method $MethodName"
}

function Export-Pfa2Excel {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [System.Collections.IDictionary]$Tables,
        [Parameter(Mandatory)]
        [string]$LiteralPath
    )
    begin {
        if (Test-Path $LiteralPath) {
            Remove-Item $LiteralPath
        }

        $workbook = [DocumentFormat.OpenXml.Spreadsheet.Workbook]::new();
        $sheets = [DocumentFormat.OpenXml.Spreadsheet.Sheets]::new();
        $workbookPart = $null

        try {
            $spreadsheetDocument = [DocumentFormat.OpenXml.Packaging.SpreadsheetDocument]::Create($LiteralPath, [DocumentFormat.OpenXml.SpreadsheetDocumentType]::Workbook)
            $workbookPart = $spreadsheetDocument.AddWorkbookPart()
            $workbookPart.Workbook = $workbook

            $workbookPart.Workbook.AppendChild($sheets)

            $stylesheet = [DocumentFormat.OpenXml.Spreadsheet.Stylesheet]::new($stylesheetRawXml);
            $workbookStylesPart = Invoke-GenericMethod $workbookPart AddNewPart -TypeParameters DocumentFormat.OpenXml.Packaging.WorkbookStylesPart
            $workbookStylesPart.Stylesheet = $stylesheet
        }
        catch {
            if ($spreadsheetDocument) {
                $spreadsheetDocument.Dispose()
                $spreadsheetDocument = $null
            }

            throw
        }

        $booleanType = [DocumentFormat.OpenXml.EnumValue[DocumentFormat.OpenXml.Spreadsheet.CellValues]]::new([DocumentFormat.OpenXml.Spreadsheet.CellValues]::Boolean)
        $stringType = [DocumentFormat.OpenXml.EnumValue[DocumentFormat.OpenXml.Spreadsheet.CellValues]]::new([DocumentFormat.OpenXml.Spreadsheet.CellValues]::String)
        $dateType = [DocumentFormat.OpenXml.EnumValue[DocumentFormat.OpenXml.Spreadsheet.CellValues]]::new([DocumentFormat.OpenXml.Spreadsheet.CellValues]::Date)
        $numberType = [DocumentFormat.OpenXml.EnumValue[DocumentFormat.OpenXml.Spreadsheet.CellValues]]::new([DocumentFormat.OpenXml.Spreadsheet.CellValues]::Number)

        $dataTypes = @{
            [DateTime] = $dateType
            [DateTimeOffset] = $dateType
            [String] = $stringType
            [bool] = $booleanType
            [float] = $numberType
            [double] = $numberType
            [decimal] = $numberType
            [System.SByte] = $numberType
            [System.Byte] = $numberType
            [System.Int16] = $numberType
            [System.UInt16] = $numberType
            [System.Int32] = $numberType
            [System.UInt32] = $numberType
            [System.Int64] = $numberType
            [System.UInt64] = $numberType
        }
    }

    process {
        $sheetId = 1
        foreach($table in $Tables.GetEnumerator()) {

            $sheetData = [DocumentFormat.OpenXml.Spreadsheet.SheetData]::new()
            $worksheet = [DocumentFormat.OpenXml.Spreadsheet.Worksheet]::new($sheetData)

            $worksheetPart = Invoke-GenericMethod $workbookPart AddNewPart -TypeParameters DocumentFormat.OpenXml.Packaging.WorksheetPart
            $worksheetPart.Worksheet = $worksheet

            $sheet = [DocumentFormat.OpenXml.Spreadsheet.Sheet]::new()
            $sheet.Id = $workbookPart.GetIdOfPart($worksheetPart)
            $sheet.SheetId = [DocumentFormat.OpenXml.Uint32Value]::new($sheetId)
            $sheet.Name = $table.Key
            $sheets.Append($sheet)

            $valueArray = $table.Value
            if ($table.Value -isnot [array]) {
                $valueArray = ,$table.Value
            }

            $items = @(foreach($valueItem in $valueArray) {
                $ht = [ordered]@{}

                $( if ($valueItem -is [System.Collections.IDictionary]) { $valueItem.GetEnumerator() } else { $valueItem.PSObject.Properties } ) |
                ForEach-Object {
                    $value = if(($null -eq $_.Value) -or $dataTypes.ContainsKey($_.Value.GetType())) { $_.Value } else {[string]$_.Value}
                    $ht.Add($_.Name, $value )
                }

                $ht
            })

            $columns = @($items.Keys | Select-Object -Unique)

            $row = [DocumentFormat.OpenXml.Spreadsheet.Row]::new();
            $row.RowIndex = [DocumentFormat.OpenXml.Uint32Value]::new(1)
            $sheetData.Append($row)

            foreach($c in $columns) {
                $cell = [DocumentFormat.OpenXml.Spreadsheet.Cell]::new();
                $cell.CellValue = [DocumentFormat.OpenXml.Spreadsheet.CellValue]::new($c);
                $cell.DataType = $stringType
                Invoke-GenericMethod $row AppendChild -MethodParameters (,$cell)
            }

            $rowIndex = 2

            foreach($item in $items) {
                $row = [DocumentFormat.OpenXml.Spreadsheet.Row]::new();
                $row.RowIndex = [DocumentFormat.OpenXml.Uint32Value]::new($rowIndex)
                $sheetData.Append($row)
                $rowIndex++

                foreach($c in $columns) {
                    $v = $item[$c]
                    $cell = [DocumentFormat.OpenXml.Spreadsheet.Cell]::new();
                    if($null -ne $v) {
                        $cell.CellValue = [DocumentFormat.OpenXml.Spreadsheet.CellValue]::new($v);
                        $cell.DataType = $dataTypes[$v.GetType()]

                        if($v -is [datetime]) {
                            $cell.StyleIndex = [DocumentFormat.OpenXml.Uint32Value]::new(1)
                        }
                    }

                    Invoke-GenericMethod $row AppendChild -MethodParameters (,$cell)
                }
            }

            if($columns) {
                $tableColumns = [DocumentFormat.OpenXml.Spreadsheet.TableColumns]::new()
                foreach($cid in 1..$columns.Count) {
                    $tc = [DocumentFormat.OpenXml.Spreadsheet.TableColumn]::new()
                    $tc.Name = [DocumentFormat.OpenXml.StringValue]::new($columns[$cid - 1])
                    $tc.Id = [DocumentFormat.OpenXml.Uint32Value]::new($cid)
                    $tableColumns.Append($tc)
                }

                $tableStyleInfo = [DocumentFormat.OpenXml.Spreadsheet.TableStyleInfo]::new()
                $tableStyleInfo.ShowRowStripes = [DocumentFormat.OpenXml.BooleanValue]::new($true)
                $tableStyleInfo.Name = [DocumentFormat.OpenXml.StringValue]::new("TableStyleMedium6")

                $cr = $columns.Count
                if($cr -lt 27) {
                    $cn = [char](64 + $cr)
                } else {
                    $rem = 0
                    $cr = [math]::DivRem($cr - 1, 26, [ref] $rem)
                    $cn = [char](64 + $cr) + [char](65 + $rem)
                }

                $excelTable = [DocumentFormat.OpenXml.Spreadsheet.Table]::new();
                $excelTable.Reference = [DocumentFormat.OpenXml.StringValue]::new('A1:' + $cn + (1 + $items.Length))
                $excelTable.Name = [DocumentFormat.OpenXml.StringValue]::new('Table' + $sheetId)
                $excelTable.DisplayName = $excelTable.Name
                $excelTable.Id = [DocumentFormat.OpenXml.Uint32Value]::new($sheetId)
                $excelTable.TableColumns = $tableColumns
                $excelTable.AutoFilter = [DocumentFormat.OpenXml.Spreadsheet.AutoFilter]::new()
                $excelTable.AutoFilter.Reference = $excelTable.Reference
                $excelTable.TableStyleInfo = $tableStyleInfo

                $tableDefinitionId = 'rId' + $sheetId
                $tableDefinitionPart = Invoke-GenericMethod $worksheetPart AddNewPart -TypeParameters DocumentFormat.OpenXml.Packaging.TableDefinitionPart -MethodParameters $tableDefinitionId
                $tableDefinitionPart.Table = $excelTable

                $tablePart = [DocumentFormat.OpenXml.Spreadsheet.TablePart]::new()
                $tablePart.Id = [DocumentFormat.OpenXml.StringValue]::new($tableDefinitionId)
                $tableParts = [DocumentFormat.OpenXml.Spreadsheet.TableParts]::new($tablePart)
                $worksheet.Append($tableParts)
            }

            $sheetId++
        }
    }

    end {
        if ($spreadsheetDocument) {

            if ($workbookPart.Workbook) {
                $workbookPart.Workbook.Save()
            }

            $spreadsheetDocument.Dispose()
            $spreadsheetDocument = $null
        }
    }
}

function Get-Pfa2AllHostVolumeInfo() {
    <#
    .SYNOPSIS
    Retrieves Host Volume information from a FlashArray.
    .DESCRIPTION
    Retrieves Host Volume information including volumes attributes from a FlashArray.
    .PARAMETER Endpoint
    Required. FQDN or IP address of the FlashArray.
    .PARAMETER Credential
    Optional. Credential for the FlashArray.
    .INPUTS
    FQDN or IP address of the FlashArray.
    .OUTPUTS
    Host volume information.
    .EXAMPLE
    Get-Pfa2AllHostVolumeInfo -Endpoint 'myarray.mydomain.com'

    Retrieves Host Volume information from the FlashArray myarray.mydomain.com.

    .EXAMPLE
    Get-Pfa2AllHostVolumeInfo -Endpoint 'myarray.mydomain.com' -Credential ( Get-Credential )

    Retrieves Host Volume information from the FlashArray myarray.mydomain.com. Asks for credentials.

    .EXAMPLE
    'myarray.mydomain.com' | Get-Pfa2AllHostVolumeInfo

    Retrieves Host Volume information from the FlashArray myarray.mydomain.com.

    .EXAMPLE
    'myarray01', 'myarray02' | Get-Pfa2AllHostVolumeInfo

    Retrieves Host Volume information from the FlashArray myarray01 and myarray02.

    .EXAMPLE
    $array = [pscustomobject]@{
        Caption    = 'Prod Array'
        Endpoint   = 'myarray.mydomain.com'
        Credential = ( Get-Credential )
    }

    $array | Get-Pfa2AllHostVolumeInfo

    Retrieves Host Volume information from the FlashArray myarray.mydomain.com. Asks for credentials.

    .NOTES
    This cmdlet can utilize the global credentials variable for FlashArray authentication. Set the credential variable by using the command Set-Pfa2Credential.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Endpoint,
        [Parameter(ValueFromPipelineByPropertyName)]
        [pscredential]$Credential = [pscredential]::Empty
    )

    process {
        if (-not $Credential -or $Credential -eq [pscredential]::Empty) {
            $Credential = Get-Pfa2Credential
        }

        try {
            $flashArray = Connect-Pfa2Array -Endpoint $Endpoint -Credential $Credential -IgnoreCertificateError
        }
        catch {
            $exceptionMessage = $_.Exception.Message
            Write-Error "Failed to connect to FlashArray endpoint $Endpoint with: $exceptionMessage"
            Return
        }

        try {
            Get-Pfa2Connection -Array $flashArray -PipelineVariable c |
            ForEach-Object { Get-Pfa2Volume -Array $flashArray -Name $_.Volume.Name } |
            ForEach-Object {
                [HostVolume]::new($flashArray.ArrayName,
                    $c.Host.Name,
                    $_.Name,
                    $_.Source.Name,
                    $_.Created,
                    $_.Serial,
                    $_.Provisioned)
            }
        }
        finally {
            Disconnect-Pfa2Array -Array $flashArray
        }
    }
}

function Get-Pfa2Config() {
    <#
    .SYNOPSIS
    Retrieves and outputs to a file the configuration of the FlashArray.
    .DESCRIPTION
    This cmdlet will run Purity CLI commands to retrieve the base configuration of a FlashArray and output it to a file. This file is formatted for the CLI, not necessarily human-readable.
    .PARAMETER Endpoint
    Required. FQDN or IP address of the FlashArray.
    .PARAMETER OutFile
    Optional. The file path and filename that will contain the output. If not specified, the default is the current folder\Array_Config.txt.
    .PARAMETER Credential
    Optional. Credential for the FlashArray.
    .INPUTS
    FQDN or IP address of the FlashArray.
    .OUTPUTS
    Configuration file.
    .EXAMPLE
    Get-Pfa2Config -Endpoint 'myarray.mydomain.com'

    Retrieves the configuration for a FlashArray myarray.mydomain.com.

    .EXAMPLE
    Get-Pfa2Config -Endpoint 'myarray.mydomain.com' -OutFile '.\myarray.txt'

    Retrieves the configuration for a FlashArray myarray.mydomain.com and stores it in the current path as myarray.txt.

    .EXAMPLE
    Get-Pfa2Config -Endpoint 'myarray.mydomain.com' -Credential ( Get-Credential )

    Retrieves Host Volume information from the FlashArray myarray.mydomain.com. Asks for credentials.

    .EXAMPLE
    'myarray.mydomain.com' | Get-Pfa2Config

    Retrieves Host Volume information from the FlashArray myarray.mydomain.com.

    .EXAMPLE
    'myarray01', 'myarray02' | Get-Pfa2Config

    Retrieves Host Volume information from the FlashArray myarray01 and myarray02.

    .EXAMPLE
    $array = [pscustomobject]@{
        Caption    = 'Prod Array'
        Endpoint   = 'myarray.mydomain.com'
        Credential = ( Get-Credential )
    }

    $array | Get-Pfa2Config

    Retrieves Host Volume information from the FlashArray myarray.mydomain.com. Asks for credentials.

    .NOTES
    This cmdlet can utilize the global credentials variable for FlashArray authentication. Set the credential variable by using the command Set-Pfa2Credential.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Endpoint,
        [string]$OutFile = "Array_Config.txt",
        [Parameter(ValueFromPipelineByPropertyName)]
        [pscredential]$Credential = [pscredential]::Empty
    )

    begin {
        $purearray_list         = "purearray list"
        $pureconfig_list_object = "pureconfig list --object"
        $pureconfig_list_system = "pureconfig list --system"
    }

    process {
        if (-not $Credential -or $Credential -eq [pscredential]::Empty) {
            $Credential = Get-Pfa2Credential
        }

        $connParam = @{
            Endpoint   = $Endpoint
            Credential = $Credential
        }

        Write-Host "Retrieving FlashArray Configuration Export for endpoint: $Endpoint"

        "==================================================================================",
        "FlashArray Configuration Export for endpoint: $Endpoint",
        "Date: $(Get-Date)",
        "==================================================================================`n" | 
        Out-File -FilePath $OutFile -Append

        Write-Host 'Retrieving FlashArray ATTRIBUTES (name-serial-firmware)...'
    
        "FlashArray ATTRIBUTES (name-serial-firmware)...`n",
        (Invoke-Pfa2CLICommand @connParam -CommandText $purearray_list) |
        Out-File -FilePath $OutFile -Append

        Write-Host 'Retrieving FlashArray OBJECT configuration export (host-pod-volume-hgroup-connection)...'
    
        "FlashArray OBJECT configuration export (host-pod-volume-hgroup-connection)...`n",
        (Invoke-Pfa2CLICommand @connParam -CommandText $pureconfig_list_object) |
        Out-File -FilePath $OutFile -Append

        Write-Host 'Retrieving FlashArray SYSTEM configuration export (array-network-alert-support)...'

        "FlashArray SYSTEM configuration export (array-network-alert-support):`n",
        (Invoke-Pfa2CLICommand @connParam -CommandText $pureconfig_list_system) |
        Out-File -FilePath $OutFile -Append
    }

    end {
        Write-Host "FlashArray configuration file located in $Outfile." -ForegroundColor Green
    }
}

function Get-Pfa2ConnectDetails() {
    <#
    .SYNOPSIS
    Retrieves Host Connection details from a FlashArray.
    .DESCRIPTION
    Retrieves Host Connection details including Host and Volume names, LUN ID, IQN / WWN, Volume Provisioned Size, and Host Capacity Written from a FlashArray.
    .PARAMETER Endpoint
    Required. FQDN or IP address of the FlashArray.
    .PARAMETER Credential
    Optional. Credential for the FlashArray.
    .INPUTS
    FQDN or IP address of the FlashArray.
    .OUTPUTS
    Host Connection details.
    .EXAMPLE
    Get-Pfa2ConnectDetails -Endpoint 'myarray.mydomain.com'

    Retrieves Host Connection details from the FlashArray myarray.mydomain.com.

    .EXAMPLE
    Get-Pfa2ConnectDetails -Endpoint 'myarray.mydomain.com' -Credential ( Get-Credential )

    Retrieves Host Connection details from the FlashArray myarray.mydomain.com. Asks for credentials.

    .EXAMPLE
    'myarray.mydomain.com' | Get-Pfa2ConnectDetails

    Retrieves Host Connection details from the FlashArray myarray.mydomain.com.

    .EXAMPLE
    'myarray01', 'myarray02' | Get-Pfa2ConnectDetails

    Retrieves Host Connection details from the FlashArray myarray01 and myarray02.

    .EXAMPLE
    $array = [pscustomobject]@{
        Caption    = 'Prod Array'
        Endpoint   = 'myarray.mydomain.com'
        Credential = ( Get-Credential )
    }

    $array | Get-Pfa2ConnectDetails

    Retrieves Host Connection details from the FlashArray myarray.mydomain.com. Asks for credentials.

    .NOTES
    This cmdlet can utilize the global credential variable for FlashArray authentication. Set the credential variable by using the command Set-Pfa2Credential.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Endpoint,
        [Parameter(ValueFromPipelineByPropertyName)]
        [pscredential]$Credential = [pscredential]::Empty
    )

    process {
        if (-not $Credential -or $Credential -eq [pscredential]::Empty) {
            $Credential = Get-Pfa2Credential
        }

        try {
            $flashArray = Connect-Pfa2Array -Endpoint $EndPoint -Credential $Credential -IgnoreCertificateError
        }
        catch {
            $exceptionMessage = $_.Exception.Message
            Write-Error "Failed to connect to FlashArray endpoint $Endpoint with: $exceptionMessage"
            Return
        }

        try {
            $hosts = @{}
            Get-Pfa2Host -Array $flashArray | ForEach-Object { $hosts.Add($_.Name, $_) }

            $volumes = @{}
            Get-Pfa2Volume -Array $flashArray | ForEach-Object { $volumes.Add($_.Name, $_) }

            Get-Pfa2Connection -Array $flashArray -Filter "volume.name!='pure-protocol-endpoint'" | ForEach-Object {
                $purehost = $hosts[$_.Host.Name]
                $volume = $volumes[$_.Volume.Name]
                [VolumeConnection]::new($flashArray.ArrayName,
                    $purehost.Name,
                    $volume.Name,
                    $_.Lun,
                    $purehost.Iqns,
                    $purehost.Wwns,
                    $volume.Provisioned,
                    $volume.Space.Unique)
            }
        }
        finally {
            Disconnect-Pfa2Array -Array $flashArray
        }
    }
}

function Get-Pfa2DisconnectedVolumes() {
    <#
    .SYNOPSIS
    Retrieves disconnected volume information from a FlashArray.
    .DESCRIPTION
    Retrieves information for volumes that are in a disconnected state from a FlashArray.
    .PARAMETER Endpoint
    Required. FQDN or IP address of the FlashArray.
    .PARAMETER Credential
    Optional. Credential for the FlashArray.
    .INPUTS
    FQDN or IP address of the FlashArray.
    .OUTPUTS
    Disconnected volume information.
    .EXAMPLE
    Get-Pfa2DisconnectedVolumes -Endpoint 'myarray.mydomain.com'

    Retrieves disconnected volume information from the FlashArray myarray.mydomain.com.

    .EXAMPLE
    Get-Pfa2DisconnectedVolumes -Endpoint 'myarray.mydomain.com' -Credential ( Get-Credential )

    Retrieves disconnected volume information from the FlashArray myarray.mydomain.com. Asks for credentials.

    .EXAMPLE
    'myarray.mydomain.com' | Get-Pfa2DisconnectedVolumes

    Retrieves disconnected volume information from the FlashArray myarray.mydomain.com.

    .EXAMPLE
    'myarray01', 'myarray02' | Get-Pfa2DisconnectedVolumes

    Retrieves disconnected volume information from the FlashArray myarray01 and myarray02.

    .EXAMPLE
    $array = [pscustomobject]@{
        Caption    = 'Prod Array'
        Endpoint   = 'myarray.mydomain.com'
        Credential = ( Get-Credential )
    }

    $array | Get-Pfa2DisconnectedVolumes

    Retrieves disconnected volume information from the FlashArray myarray.mydomain.com. Asks for credentials.

    .NOTES
    This cmdlet can utilize the global credential variable for FlashArray authentication. Set the credential variable by using the command Get-Pfa2Credential.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Endpoint,
        [Parameter(ValueFromPipelineByPropertyName)]
        [pscredential]$Credential = [pscredential]::Empty
    )

    process {
        if (-not $Credential -or $Credential -eq [pscredential]::Empty) {
            $Credential = Get-Pfa2Credential
        }

        try {
            $flashArray = Connect-Pfa2Array -Endpoint $EndPoint -Credential $Credential -IgnoreCertificateError
        }
        catch {
            $exceptionMessage = $_.Exception.Message
            Write-Error "Failed to connect to FlashArray endpoint $Endpoint with: $exceptionMessage"
            Return
        }

        try {
            $faSpace = Get-Pfa2ArraySpace -Array $flashArray

            $allVolumes = @(Get-Pfa2Volume -Array $flashArray | Select-Object -Expand Name)
            $connectedVolumes = @(Get-Pfa2Connection -Array $flashArray | Select-Object -Expand Volume | Select-Object -Expand Name -Unique)
            $disconnectedVolumes = @($allVolumes | Where-Object { $_ -notin $connectedVolumes })

            $faTotal = Get-SizeLabel $faSpace.Space.TotalPhysical
            $faCapacity = Get-SizeLabel $faSpace.Capacity

            Write-Host ''
            Write-Host "`t$Endpoint - $faTotal / $faCapacity ($(($faSpace.Space.TotalPhysical/$faSpace.Capacity).ToString('P2')) Full)`n"
            Write-Host '==================================================='
            Write-Host "`t`tDisconnected Volumes ($($disconnectedVolumes.Count) of $($allVolumes.Count))"
            Write-Host '==================================================='

            #If the array has a disconnected volume, gather volume space metrics
            if (($disconnectedVolumes.Count) -gt 0 ) {
                foreach ($disconnectedVolume in $DisconnectedVolumes) {
                    if ($null -ne $disconnectedVolume) {
                        $getVol = Get-Pfa2Volume -Array $flashArray -Name $disconnectedVolume
                        [DisconnectedVolume]::new($flashArray.ArrayName,
                        $disconnectedVolume,
                        $getVol.Serial,
                        $getVol.Provisioned,
                        $getVol.Space.Unique,
                        $getVol.Space.DataReduction)

                        $potentialSpaceSavings = $potentialSpaceSavings + $getVol.Space.Unique
                    }
                }
                Write-Host ''
                Write-Host "Potential space savings for $Endpoint is $(Get-SizeLabel $potentialSpaceSavings)."
            }
        }
        finally {
            Disconnect-Pfa2Array -Array $flashArray
        }
    }
}

Function Get-Pfa2Hierarchy() {
    <#
    .SYNOPSIS
    Displays array hierarchy in relation to hosts and/or volumes.
    .DESCRIPTION
    This cmdlet will display the hierarchy from a FlashArray of hosts and volumes. The output is to the console in text.
    .PARAMETER Endpoint
    Required. FQDN or IP address of the FlashArray.
    .PARAMETER ByHost
    Optional. If specified, the hierarchy will be shown at the host level. It is useful to find disconnected hosts or hosts with no replication group. Otherwise, the hierarchy will be shown at the volume level.
    .PARAMETER Credential
    Optional. Credential for the FlashArray.
    .INPUTS
    FQDN or IP address of the FlashArray.
    .OUTPUTS
    FlashArray host and/or volume hierarchy.
    .EXAMPLE
    Get-Pfa2Hierarchy -Endpoint 'myarray.mydomain.com'

    Displays the hierarchy from the FlashArray myarray.mydomain.com.

    .EXAMPLE
    Get-Pfa2Hierarchy -Endpoint 'myarray.mydomain.com' -ByHost

    Displays the hierarchy from the FlashArray myarray.mydomain.com at the host level.

    .EXAMPLE
    Get-Pfa2Hierarchy -Endpoint 'myarray.mydomain.com' -Credential ( Get-Credential )

    Displays the hierarchy from the FlashArray myarray.mydomain.com. Asks for credentials.

    .EXAMPLE
    'myarray.mydomain.com' | Get-Pfa2Hierarchy

    Displays the hierarchy from the FlashArray myarray.mydomain.com.

    .EXAMPLE
    'myarray01', 'myarray02' | Get-Pfa2Hierarchy

    Displays the hierarchy from the FlashArray myarray01 and myarray02.

    .EXAMPLE
    $array = [pscustomobject]@{
        Caption    = 'Prod Array'
        Endpoint   = 'myarray.mydomain.com'
        Credential = ( Get-Credential )
    }

    $array | Get-Pfa2Hierarchy

    Displays the hierarchy from the FlashArray myarray.mydomain.com. Asks for credentials.

    .NOTES
    This cmdlet can utilize the global credential variable for FlashArray authentication. Set the credential variable by using the command Set-Pfa2Credential.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Endpoint,
        [switch]$ByHost,
        [Parameter(ValueFromPipelineByPropertyName)]
        [pscredential]$Credential = [pscredential]::Empty
    )

    process {
        if (-not $Credential -or $Credential -eq [pscredential]::Empty) {
            $Credential = Get-Pfa2Credential
        }

        try {
            $FlashArray = Connect-Pfa2Array -Endpoint $Endpoint -Credential $Credential -IgnoreCertificateError
        }
        catch {
            $ExceptionMessage = $_.Exception.Message
            Write-Error "Failed to connect to FlashArray endpoint $Endpoint with: $ExceptionMessage"
            Return
        }

        try {
            Write-Host ''
            Write-Host '================================================================'
            Write-Host "                    $Endpoint Hierarchy"
            Write-Host '================================================================'
            #If else statement to control hierarchy displayed by host or by volume
            If ($ByHost) {
                $Initiators = Get-Pfa2Host -Array $FlashArray

                #Start at host level
                ForEach ($Initiator in $Initiators) {
                    Write-Host "[H] $($Initiator.name)"

                    $Volumes = Get-Pfa2Connection -Array $FlashArray -HostNames $Initiator.name | 
                    Select-Object -expand Volume | 
                    Where-Object Name -ne 'pure-protocol-endpoint'

                    If (!$Volumes) {
                        Write-Host '  [No volumes connected]' -ForegroundColor Yellow
                    }
                    Else {
                        #Start at volume level
                        ForEach ($Volume in $Volumes) {

                            #Reset variables
                            $Snapshots = @(Get-Pfa2VolumeSnapshot -Array $FlashArray -SourceNames $Volume.name)
                            $SpaceConsumed = 0

                            #Change value for snapshot count threshold
                            If ($Snapshots.Count -eq 0) {
                                Write-Host "  [V] $($Volume.name)" -ForegroundColor Yellow
                                Write-Host '    There are no associated snapshots with this volume.' -ForegroundColor Red
                            }
                            Else {
                                Write-Host "  [V] $($Volume.name)" -ForegroundColor Green
                            }

                            #Change value for snapshot count threshold
                            ForEach ($Snapshot in $Snapshots) {
                                If ($Snapshots.Count -gt 1) {
                                    Write-Host "    [S] $($Snapshot.name)" -ForegroundColor Yellow
                                }
                                Else {
                                    Write-Host "    [S] $($Snapshot.name)" -ForegroundColor Green
                                }

                                #Space consumed computation for each volume
                                $SpaceConsumed += $Snapshot.Space.TotalPhysical
                            }

                            #Display space consumed if snapshot count exceeds threshold
                            If ($Snapshots.Count -gt 1) {
                                Write-Host  "    There are $($Snapshots.Count) snapshots associated with this volume consuming a total of $(Get-SizeLabel $SpaceConsumed) on the array."
                            }
                        }
                    }
                }
            }
            #If user does not want hierarchy at host level
            Else {
                $Volumes = Get-Pfa2Volume -Array $FlashArray | Where-Object Name -ne 'pure-protocol-endpoint'

                #Start volume level
                ForEach ($Volume in $Volumes) {

                    #Reset variables
                    $Snapshots = @(Get-Pfa2VolumeSnapshot -Array $FlashArray -SourceNames $Volume.name)
                    $SpaceConsumed = 0

                    #Change value for snapshot count threshold
                    If ($Snapshots.Count -eq 0) {
                        Write-Host "[V] $($Volume.name)" -ForegroundColor Yellow
                        Write-Host '  There are no associated snapshots with this volume.' -ForegroundColor Red
                    }
                    Else {
                        Write-Host "[V] $($Volume.name)" -ForegroundColor Green
                    }

                    #Change value for snapshot count threshold
                    ForEach ($Snapshot in $Snapshots) {
                        If ($Snapshots.Count -gt 1) {
                            Write-Host "  [S] $($Snapshot.name)" -ForegroundColor Yellow
                        }
                        Else {
                            Write-Host "  [S] $($Snapshot.name)" -ForegroundColor Green
                        }

                        #Space consumed computation for each volume
                        $SpaceConsumed += $Snapshot.Space.TotalPhysical
                    }

                    #Display space consumed if snapshot count threshold is exceeded
                    If ($Snapshots.Count -gt 1) {
                        Write-Host  "  There are $($Snapshots.Count) snapshots associated with this volume consuming a total of $(Get-SizeLabel $SpaceConsumed) on the array."
                    }
                }
            }
        }
        finally {
            Disconnect-Pfa2Array -Array $FlashArray
        }
    }
}

function Get-Pfa2PgroupsConfig() {
    <#
    .SYNOPSIS
    Retrieves Protection Group information for the FlashArray.
    .DESCRIPTION
    Retrieves Protection Group information including replication schedule configuration for the FlashArray.
    .PARAMETER Endpoint
    Required. FQDN or IP address of the FlashArray.
    .PARAMETER Credential
    Optional. Credential for the FlashArray.
    .INPUTS
    FQDN or IP address of the FlashArray.
    .OUTPUTS
    Protection Group information.
    .EXAMPLE
    Get-Pfa2PgroupsConfig -Endpoint 'myarray.mydomain.com'

    Retrieves Protection Group information from the FlashArray myarray.mydomain.com.

    .EXAMPLE
    Get-Pfa2PgroupsConfig -Endpoint 'myarray.mydomain.com' -Credential ( Get-Credential )

    Retrieves Protection Group information from the FlashArray myarray.mydomain.com. Asks for credentials.

    .EXAMPLE
    'myarray.mydomain.com' | Get-Pfa2PgroupsConfig

    Retrieves Protection Group information from the FlashArray myarray.mydomain.com.

    .EXAMPLE
    'myarray01', 'myarray02' | Get-Pfa2PgroupsConfig

    Retrieves Protection Group information from the FlashArray myarray01 and myarray02.

    .EXAMPLE
    $array = [pscustomobject]@{
        Caption    = 'Prod Array'
        Endpoint   = 'myarray.mydomain.com'
        Credential = ( Get-Credential )
    }

    $array | Get-Pfa2PgroupsConfig

    Retrieves Protection Group information from the FlashArray myarray.mydomain.com. Asks for credentials.

    .NOTES
    This cmdlet can utilize the global credential variable for FlashArray authentication. Set the credential variable by using the command Set-Pfa2Credential.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Endpoint,
        [Parameter(ValueFromPipelineByPropertyName)]
        [pscredential]$Credential = [pscredential]::Empty
    )

    process {
        if (-not $Credential -or $Credential -eq [pscredential]::Empty) {
            $Credential = Get-Pfa2Credential
        }

        try {
            $flashArray = Connect-Pfa2Array -Endpoint $Endpoint -Credential $Credential -IgnoreCertificateError
        }
        catch {
            $exceptionMessage = $_.Exception.Message
            Write-Error "Failed to connect to FlashArray endpoint $Endpoint with: $exceptionMessage"
            Return
        }

        try {
            $protectionGroups = Get-Pfa2ProtectionGroup -Array $flashArray

            $groupVolumes = @{} 
            Get-Pfa2ProtectionGroupVolume -Array $flashArray | ForEach-Object { $groupVolumes[$_.Group.Name] += @($_.Member.Name) }

            $groupHosts = @{} 
            Get-Pfa2ProtectionGroupHost -Array $flashArray | ForEach-Object { $groupHosts[$_.Group.Name] += @($_.Member.Name) }

            $groupHostGroups = @{} 
            Get-Pfa2ProtectionGroupHostGroup -Array $flashArray | ForEach-Object { $groupHostGroups[$_.Group.Name] += @($_.Member.Name) }

            foreach ($protectionGroup in $ProtectionGroups) {
                [PgroupConfig]::new($flashArray.ArrayName,
                    $protectionGroup.Name,
                    $groupHostGroups[$protectionGroup.Name],
                    $groupHosts[$protectionGroup.Name],
                    $groupVolumes[$protectionGroup.Name],
                    $protectionGroup.ReplicationSchedule.Enabled,
                    $protectionGroup.ReplicationSchedule.Frequency,
                    $protectionGroup.TargetRetention.AllForSec,
                    $ProtectionGroup.TargetRetention.Days,
                    $protectionGroup.TargetRetention.PerDay)
            }
        }
        finally {
            Disconnect-Pfa2Array -Array $flashArray
        }
    }
}

function Get-Pfa2QuickCapacityStats() {
    <#
    .SYNOPSIS
    Quick way to retrieve FlashArray capacity statistics.
    .DESCRIPTION
    Retrieves high level capcity statistics from a FlashArray.
    .PARAMETER Endpoint
    Required. FQDN or IP address of the FlashArray.
    .PARAMETER Credential
    Optional. Credential for the FlashArray.
    .INPUTS
    FQDN or IP address of the FlashArray.
    .OUTPUTS
    FlashArray capacity statistics.
    .EXAMPLE
    Get-Pfa2QuickCapacityStats -Endpoint 'myarray.mydomain.com'

    Retrieves capacity statistic information from the FlashArray myarray.mydomain.com.

    .EXAMPLE
    Get-Pfa2QuickCapacityStats -Endpoint 'myarray.mydomain.com' -Credential ( Get-Credential )

    Retrieves capacity statistic information from the FlashArray myarray.mydomain.com. Asks for credentials.

    .EXAMPLE
    'myarray.mydomain.com' | Get-Pfa2QuickCapacityStats

    Retrieves capacity statistic information from the FlashArray myarray.mydomain.com.

    .EXAMPLE
    Get-Pfa2QuickCapacityStats -Endpoint 'myarray01', 'myarray02'

    Retrieves capacity statistic information from the FlashArray myarray01 and myarray02.

    .EXAMPLE
    'myarray01', 'myarray02' | Get-Pfa2QuickCapacityStats

    Retrieves capacity statistic information from the FlashArray myarray01 and myarray02.

    .EXAMPLE
    $array = [pscustomobject]@{
        Caption    = 'Prod Array'
        Endpoint   = 'myarray.mydomain.com'
        Credential = ( Get-Credential )
    }

    $array | Get-Pfa2QuickCapacityStats

    Retrieves capacity statistic information from the FlashArray myarray.mydomain.com. Asks for credentials.

    .NOTES
    This cmdlet can utilize the global credentials variable for FlashArray authentication. Set the credential variable by using the command Set-Pfa2Credential.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Endpoint,
        [Parameter(ValueFromPipelineByPropertyName)]
        [pscredential]$Credential = [pscredential]::Empty
    )

    begin {
        $count = 0
        $capacity = 0
        $volumes = 0
        $beforereduction = 0
        $provisioned = 0
    }

    process {
        if (-not $Credential -or $Credential -eq [pscredential]::Empty) {
            $Credential = Get-Pfa2Credential
        }

        foreach ($e in $Endpoint) {
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
                $s = Get-Pfa2ArraySpace -Array $flashArray | Select-Object Capacity -Expand Space

                $count ++;
                $capacity += $s.Capacity
                $volumes += $s.Unique
                $beforereduction += $s.Unique * $s.DataReduction
                $provisioned += ($s.TotalPhysical - $s.System) / (1 - $s.ThinProvisioning) * $s.DataReduction
            }
            finally {
                Disconnect-Pfa2Array -Array $flashArray
            }
        }
    }

    end {
        [CapacityStats]::new($count,
            $capacity,
            $volumes,
            $beforereduction,
            $provisioned)
    }
}

function Get-Pfa2RASession() {
    <#
    .SYNOPSIS
    Retrieves Remote Assist status from a FlashArray.
    .DESCRIPTION
    Retrieves Remote Assist status from a FlashArray as disabled or enabled in a loop every 30 seconds until stopped.
    .PARAMETER Endpoint
    Required. FQDN or IP address of the FlashArray.
    .PARAMETER Credential
    Optional. Credential for the FlashArray.
    .INPUTS
    None.
    .OUTPUTS
    Remote Assst status.
    .EXAMPLE
    Get-Pfa2RASession -Endpoint 'myarray.mydomain.com'

    Retrieves the current Remote Assist status and continues check status every 30 seconds until stopped.

    .EXAMPLE
    Get-Pfa2PgroupsConfig -Endpoint 'myarray.mydomain.com' -Credential ( Get-Credential )

    Retrieves the current Remote Assist status and continues check status every 30 seconds until stopped. Asks for credentials.
    .NOTES
    This cmdlet can utilize the global credentials variable for FlashArray authentication. Set the credential variable by using the command Set-Pfa2Credential.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Endpoint,
        [pscredential]$Credential = [pscredential]::Empty
    )

    if (-not $Credential -or $Credential -eq [pscredential]::Empty) {
        $Credential = Get-Pfa2Credential
    }

    try {
        $flashArray = Connect-Pfa2Array -Endpoint $Endpoint -Credential $Credential -IgnoreCertificateError
    }
    catch {
        $exceptionMessage = $_.Exception.Message
        Write-Error "Failed to connect to FlashArray endpoint $Endpoint with: $exceptionMessage"
        Return
    }

    try {
        Write-Host 'Testing remote assist connectivity'
        do {
            $test = Get-Pfa2SupportTest -Array $flashArray -TestType 'remote-assist'
            If ($test.Success) {
                Write-Host $test.ResultDetails
            } else {
                Write-Warning $test.ResultDetails
                Start-Sleep 30
            }
        } until ($test.Success)
    }
    finally {
        Disconnect-Pfa2Array -Array $flashArray
    }
}

function Get-Pfa2Space() {
    <#
    .SYNOPSIS
    Retrieves the space used and available for a FlashArray.
    .DESCRIPTION
    This cmdlet will return various array space metrics for the given FlashArray.
    .PARAMETER Endpoint
    Required. FQDN or IP address of the FlashArray.
    .PARAMETER Credential
    Optional. Credential for the FlashArray.
    .INPUTS
    FQDN or IP address of the FlashArray.
    .OUTPUTS
    FlashArray space metrics.
    .EXAMPLE
    Get-Pfa2Space -Endpoint 'myarray.mydomain.com'

    Retrieves space metrics for the FlashArray myarray.mydomain.com.

    .EXAMPLE
    Get-Pfa2Space -Endpoint 'myarray.mydomain.com' -Credential ( Get-Credential )

    Retrieves space metrics for the FlashArray myarray.mydomain.com. Asks for credentials.

    .EXAMPLE
    'myarray.mydomain.com' | Get-Pfa2Space

    Retrieves space metrics for the FlashArray myarray.mydomain.com.

    .EXAMPLE
    'myarray01', 'myarray02' | Get-Pfa2Space

    Retrieves space metrics for the FlashArray myarray01 and myarray02.

    .EXAMPLE
    $array = [pscustomobject]@{
        Caption    = 'Prod Array'
        Endpoint   = 'myarray.mydomain.com'
        Credential = ( Get-Credential )
    }

    $array | Get-Pfa2Space

    Retrieves space metrics for the FlashArray myarray.mydomain.com. Asks for credentials.

    .NOTES
    This cmdlet can utilize the global credential variable for FlashArray authentication. Set the credential variable by using the command Set-Pfa2Credential.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Endpoint,
        [Parameter(ValueFromPipelineByPropertyName)]
        [pscredential]$Credential = [pscredential]::Empty
    )

    process {
        if (-not $Credential -or $Credential -eq [pscredential]::Empty) {
            $Credential = Get-Pfa2Credential
        }

        try {
            $flashArray = Connect-Pfa2Array -Endpoint $Endpoint -Credential $Credential -IgnoreCertificateError
        }
        catch {
            $ExceptionMessage = $_.Exception.Message
            Write-Error "Failed to connect to FlashArray endpoint $Endpoint with: $ExceptionMessage"
            Return
        }

        try {
            Get-Pfa2ArraySpace -Array $flashArray -PipelineVariable a | 
            Select-Object -Expand Space |
            ForEach-Object {
                [ArraySpace]::new($flashArray.ArrayName,
                    $a.Capacity,
                    $_.TotalPhysical,
                    $_.Unique,
                    $_.Shared,
                    $_.Snapshots,
                    $_.System,
                    $_.DataReduction,
                    $_.ThinProvisioning)
            }
        }
        finally {
            Disconnect-Pfa2Array -Array $flashArray
        }
    }
}

function Get-Pfa2StaleSnapshots() {
    <#
    .SYNOPSIS
    Retrieves aged snapshots and allows for Deletion and Eradication of such snapshots.
    .DESCRIPTION
    This cmdlet will retrieve all snapshots that are beyond the specified SnapAgeThreshold.
    It allows for the parameters of Delete and Eradicate, and if specified, it will delete
    and eradicate the snapshots returned. It allows for the parameter of Confirm, and if set
    to $false, it will eradicate snapshots without confirmation. Snapshots must be deleted
    before they can be eradicated.
    .PARAMETER Endpoint
    Required. FQDN or IP address of the FlashArray.
    .PARAMETER SnapAgeThreshold
    Optional. SnapAgeThreshold is the number of days from the current date. Defaults to 30.
    .PARAMETER Delete
    Optional. If specified, delete the snapshots.
    .PARAMETER Eradicate
    Optional. If specified, eradicate the deleted snapshots. Snapshot must be flagged as
    deleted and -Delete switch must be specified.
    .PARAMETER Credential
    Optional. Credential for the FlashArray.
    .INPUTS
    FQDN or IP address of the FlashArray.
    .OUTPUTS
    Snapshots that are beyond the specified threshold and final results.
    .EXAMPLE
    Get-Pfa2StaleSnapshots -Endpoint 'myarray.mydomain.com'

    Returns all snapshots from the FlashArray myarray.mydomain.com that are older than 30 days from the current date.

    .EXAMPLE
    Get-Pfa2StaleSnapshots -Endpoint 'myarray.mydomain.com' -SnapAgeThreshold 10

    Returns all snapshots from the FlashArray myarray.mydomain.com that are older than 10 days from the current date.

    .EXAMPLE
    Get-Pfa2StaleSnapshots -Endpoint 'myarray.mydomain.com' -Delete

    Returns all snapshots from the FlashArray myarray.mydomain.com that are older than 30 days from the current date.
    Deletes snapshots without confirmation.

    .EXAMPLE
    Get-Pfa2StaleSnapshots -Endpoint 'myarray.mydomain.com' -Delete -Eradicate -Confirm:$false

    Returns all snapshots from the FlashArray myarray.mydomain.com that are older than 30 days from the current date.
    Deletes and eradicates (flagged as deleted) snapshots without confirmation.
    
    .EXAMPLE
    Get-Pfa2StaleSnapshots -Endpoint 'myarray.mydomain.com'

    Returns all snapshots from the FlashArray myarray.mydomain.com that are older than 30 days from the current date.

    .EXAMPLE
    Get-Pfa2StaleSnapshots -Endpoint 'myarray.mydomain.com' -Credential ( Get-Credential )

    Returns all snapshots from the FlashArray myarray.mydomain.com that are older than 30 days from the current date.
    Asks for credentials.

    .EXAMPLE
    'myarray.mydomain.com' | Get-Pfa2StaleSnapshots

    Returns all snapshots from the FlashArray myarray.mydomain.com that are older than 30 days from the current date.

    .EXAMPLE
    'myarray01', 'myarray02' | Get-Pfa2StaleSnapshots

    Retrieves Host Volume information from the FlashArray myarray01 and myarray02.

    .EXAMPLE
    $array = [pscustomobject]@{
        Caption    = 'Prod Array'
        Endpoint   = 'myarray.mydomain.com'
        Credential = ( Get-Credential )
    }

    $array | Get-Pfa2StaleSnapshots

    Returns all snapshots from the FlashArray myarray.mydomain.com that are older than 30 days from the current date.
    Asks for credentials.

    .NOTES
    This cmdlet can utilize the global credentials variable for FlashArray authentication. Set the credential variable by using the command Set-Pfa2Credential.
    #>

    [CmdletBinding(SupportsShouldProcess)]
    Param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Endpoint,
        [ValidateNotNullOrEmpty()]
        [decimal]$SnapAgeThreshold = 30,
        [switch]$Delete,
        [switch]$Eradicate,
        [Parameter(ValueFromPipelineByPropertyName)]
        [pscredential]$Credential = [pscredential]::Empty
    )

    begin {
        # Establish variables, Pure time format, and gather current time.
        $currentTime = Get-Date
        [int]$snapNumber = 0
        [long]$spaceConsumed = 0
    }

    process {
        if (-not $Credential -or $Credential -eq [pscredential]::Empty) {
            $Credential = Get-Pfa2Credential
        }

        try {
            $flashArray = Connect-Pfa2Array -Endpoint $Endpoint -Credential $Credential -IgnoreCertificateError
        }
        catch {
            $ExceptionMessage = $_.Exception.Message
            Write-Error "Failed to connect to FlashArray endpoint $Endpoint with: $ExceptionMessage"
            Return
        }

        try {
            #Get all snapshots and compute the age of them.
            $snapshots = Get-Pfa2VolumeSnapshot -Array $flashArray
            foreach ($snapshot in $snapshots) {
                $snapAge = New-TimeSpan -Start $snapshot.created -End $currentTime

                #Find snaps older than given threshold and output with formatted data.
                if ($snapAge.TotalDays -gt $SnapAgeThreshold) {
                    $spaceConsumed += $snapshot.Space.TotalPhysical
                    $snapNumber++

                    #Delete snapshots
                    if ($Delete) {
                        $snapSize = Get-SizeLabel $snapshot.Space.TotalPhysical
                        if (-not $snapshot.Destroyed) {
                            Write-Host "Deleting $($snapshot.name) - $snapSize."
                            Remove-Pfa2VolumeSnapshot -Array $flashArray -Name $snapshot.name
                        }
                        elseif ($Eradicate) {
                            Write-Host "Eradicating $($snapshot.name) - $snapSize."
                            Remove-Pfa2VolumeSnapshot -Array $flashArray -Name $snapshot.name -Eradicate
                        }
                    }
                    else {
                        [StaleSnapshot]::new($flashArray.ArrayName,
                            $snapshot.Name,
                            $snapshot.Space.TotalPhysical,
                            $snapshot.Destroyed,
                            $snapAge)
                    }
                }
            }
        }
        finally {
            Disconnect-Pfa2Array -Array $flashArray
        }
    }

    end {
        #Display final message for array results.
        Write-Host ''
        Write-Host "There are $snapNumber snapshot(s) older than $SnapAgeThreshold days consuming a total of $(Get-SizeLabel $spaceConsumed)."
    }
}

function Get-Pfa2VolumeGrowth() {
    <#
    .SYNOPSIS
    Retrieves volume growth information over past X days at Y percentage of growth.
    .DESCRIPTION
    Retrieves volume growth in GB from a FlashArray for volumes that grew in past X amount of days at Y percentage of growth.
    .PARAMETER Endpoint
    Required. FQDN or IP address of the FlashArray.
    .PARAMETER StartTime
    Optional. The timeframe to compare the volume size against. If not specified, defaults to the last hour.
    .PARAMETER MinimumVolumeAgeInDays
    Optional. The minimum age in days that a volume must be to report on it. If not specified, defaults to 1 day.
    .PARAMETER GrowthPercentThreshold
    Optional. The minimum percentage of volume growth to report on. If not specified, defaults to 1%.
    .PARAMETER DoNotReportGrowthOfLessThan
    Optional. If growth in size, in Gigabytes, over the specified period is lower than this value, it will not be reported. If not specified, defaults to 1GB.
    .PARAMETER DoNotReportVolSmallerThan
    Optional. Volumes that are smaller than this size in Gigabytes will not be reported on. If not specified, defaults to 1GB.
    .PARAMETER Html
    Optional. Switch. If present, produces a HTML of the output in the current folder named FlashArrayVolumeGrowthReport.html.
    .PARAMETER Csv
    Optional. Switch. If present, produces a CSV comma-delimited file of the output in the current folder named FlashArrayVolumeGrowthReport.csv.
    .PARAMETER Credential
    Optional. Credential for the FlashArray.
    .INPUTS
    FQDN or IP address of the FlashArray.
    .OUTPUTS
    Volume capacity information to the console, and also to a CSV and/or HTML formatted report (if specified).
    .EXAMPLE
    Get-Pfa2VolumeGrowth -Endpoint 'myarray.mydomain.com'

    Retrieve volume capacity report for 'myarray.mydomain.com' comparing volumes over the last hour that:
        - volumes that are not smaller than 1GB in size
        - that are at least 1 day old
        - must have growth of more than 1GB
        - have grown at least 10%

    .EXAMPLE
    Get-Pfa2VolumeGrowth -Endpoint 'myarray.mydomain.com' -StartTime (Get-Date).AddHours(-2) -MinimumVolumeAgeInDays 7 -GrowthPercentThreshold 15 -DoNotReportGrowthOfLessThan 50GB -DoNotReportVolSmallerThan 250GB

    Retrieve volume capacity report for 'myarray.mydomain.com' comparing volumes over the last two hours that:
        - volumes that are not smaller than 250GB in size
        - that are at least 7 day old
        - must have growth of more than 50GB
        - have grown at least 15%

    .EXAMPLE
    Get-Pfa2VolumeGrowth -Endpoint 'myarray.mydomain.com' -Html

    Retrieve volume capacity report for 'myarray.mydomain.com' with default parameters. Create HTML report.

    .EXAMPLE
    Get-Pfa2VolumeGrowth -Endpoint 'myarray.mydomain.com' -Credential ( Get-Credential )

    Retrieve volume capacity report for 'myarray.mydomain.com' with default parameters. Asks for credentials.

    .EXAMPLE
    'myarray.mydomain.com' | Get-Pfa2VolumeGrowth

    Retrieve volume capacity report for 'myarray.mydomain.com' with default parameters.

    .EXAMPLE
    Get-Pfa2VolumeGrowth -Endpoint 'myarray01', 'myarray02'

    Retrieve volume capacity report for myarray01 and myarray02 with default parameters.

    .EXAMPLE
    'myarray01', 'myarray02' | Get-Pfa2VolumeGrowth

    Retrieve volume capacity report for myarray01 and myarray02 with default parameters.

    .EXAMPLE
    $array = [pscustomobject]@{
        Caption    = 'Prod Array'
        Endpoint   = 'myarray.mydomain.com'
        Credential = ( Get-Credential )
    }

    $array | Get-Pfa2VolumeGrowth

    Retrieve volume capacity report for 'myarray.mydomain.com' with default parameters. Asks for credentials.

    .NOTES
    This cmdlet can utilize the global credentials variable for FlashArray authentication. Set the credential variable by using the command Set-Pfa2Credential.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Endpoint,
        [DateTime]$StartTime = ( (Get-Date).AddHours(-1) ),
        [int]$MinimumVolumeAgeInDays = 1,
        [int]$GrowthPercentThreshold = 10,
        [long]$DoNotReportGrowthOfLessThan = 1GB,
        [long]$DoNotReportVolSmallerThan = 1GB,
        [switch]$Csv,
        [switch]$Html,
        [Parameter(ValueFromPipelineByPropertyName)]
        [pscredential]$Credential = [pscredential]::Empty
    )

    begin {
        Write-Host ''
        Write-Host 'Retrieving data from arrays and calculating.' -ForegroundColor Yellow
        Write-Host 'This may take some time depending on number of arrays, volumes, etc. Please wait...' -ForegroundColor Yellow
        Write-Host ''

        $latestDate = (Get-Date).AddDays(-$MinimumVolumeAgeInDays)

        $params_message = "Ignore volumes " +
        "1) created in the last $MinimumVolumeAgeInDays days, " +
        "2) smaller than $(Get-SizeLabel $DoNotReportVolSmallerThan), and " +
        "3) have growth of less than $(Get-SizeLabel $DoNotReportGrowthOfLessThan) " +
        "or $GrowthPercentThreshold% of thier size starting from $StartTime."

        $all_arrays = @()
        $volThatBreachGrowthThreshold = @()
    }

    process {
        if (-not $Credential -or $Credential -eq [pscredential]::Empty) {
            $Credential = Get-Pfa2Credential
        }
    
        function Get-VolumeStats {
            param (
                [Parameter(ValueFromPipeline)]
                [string]$array
            )

            process {
                Write-Host "Calculating array $array..." -ForegroundColor Green
                Write-Host ''

                # Connect to FlashArray(s)
                try {
                    $flashArray = Connect-Pfa2Array -Endpoint $array -Credential $Credential -IgnoreCertificateError
                }
                catch {
                    $exceptionMessage = $_.Exception.Message
                    Write-Error "Failed to connect to FlashArray endpoint $array with: $exceptionMessage"
                    Return
                }

                try {
                    Get-Pfa2Volume -Array $flashArray -ErrorAction SilentlyContinue |
                    Where-Object { $_.Space.TotalProvisioned -GT $DoNotReportVolSmallerThan } | 
                    Where-Object { (Get-Date $_.created) -lt $latestDate } |
                    ForEach-Object {
                        $volumeSpaceMetrics = Get-Pfa2VolumeSpace -Name $_.name -StartTime $StartTime -Array $flashArray
                        $last = ($volumeSpaceMetrics | Select-Object -Last 1).Space.Unique
                        $first = ($volumeSpaceMetrics | Select-Object -First 1).Space.Unique
                        $growth = $last - $first
                        $growthPercent = if ($first -ne 0) { $growth / $first } else { $growth / 1 }
                        [VolumeGrowthStats]::new($flashArray.ArrayName,
                            $_.Name,
                            $_.Provisioned,
                            $_.Space.Unique,
                            $growth,
                            $growthPercent)
                    } |
                    Where-Object { ($_.GrowthPercent * 100) -gt $GrowthPercentThreshold -and $_.Growth -gt $DoNotReportGrowthOfLessThan }
                }
                finally {
                    Disconnect-Pfa2Array -Array $flashArray
                }
            }
        }

        $volThatBreachGrowthThreshold += $Endpoint | Get-VolumeStats
        $all_arrays += $Endpoint
    }

    end {
        Write-Host 'Query parameters specified as:'
        Write-Host $params_message -ForegroundColor Green
        Write-Host ''

        if ($volThatBreachGrowthThreshold) {
            $result = $volThatBreachGrowthThreshold | ForEach-Object {
                [pscustomobject]@{
                    Array         = $_.Array
                    Name          = $_.VolumeName
                    'Size (GB)'   = Convert-UnitOfSize $_.Provisioned -To 1GB
                    'Unique (GB)' = Convert-UnitOfSize $_.Unique -To 1GB
                    'Growth (GB)' = Convert-UnitOfSize $_.Growth -To 1GB
                    'Growth (%)'  = '{0:P2}' -f $_.GrowthPercent
                }
            }

            # Output
            $volThatBreachGrowthThreshold

            if ($Html) {
                Write-Host 'Building HTML report as requested. Please wait...' -ForegroundColor Yellow
                Write-Host ''

                $htmlParams = @{
                    Title       = 'Volume Capacity Report'
                    Body        = Get-Date
                    PreContent  = "<p>Volume Capacity Report for FlashArray(s) $all_arrays`:</p>"
                    PostContent = "<p>Query parameters specified as: $params_message</p>"
                }

                $result | ConvertTo-Html @htmlParams | Out-File -FilePath .\FlashArrayVolumeGrowthReport.html | Out-Null
            }

            if ($Csv) {
                Write-Host 'Building CSV report as requested. Please wait...' -ForegroundColor Yellow
                Write-Host ''

                $result | Export-Csv -NoTypeInformation -Path .\FlashArrayVolumeGrowthReport.csv
            }
        }
        else {
            Write-Host 'No volumes on the array(s) match the requested criteria.'
            Write-Host ''
        }
    }
}

function Set-Pfa2Credential {
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

function Get-Pfa2Credential {
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

    Set-Pfa2Credential $script:Creds
    $script:Creds
}

function Clear-Pfa2Credential {
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

function Get-SizeLabel {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        $Size,
        $Decimals = 2
    )

    begin {
        $postfixes = @('B', 'KB', 'MB', 'GB', 'TB', 'PB')
    }

    process {
        for ($i = 0; $Size -ge 1024 -and $i -lt $postfixes.Length; $i++) {
            $Size = $Size / 1024
        }
        return '' + [System.Math]::Round($Size, $Decimals) + ' ' + $postfixes[$i]
    }
}

function New-Pfa2CapacityReport() {
    <#
    .SYNOPSIS
    Create a formatted report that contains FlashArray Capacity Information
    .DESCRIPTION
    This cmdlet will retrieve volume and snapshot capacity information from the FlashArray and output it to a formatted report.
    .PARAMETER Endpoint
    Required. FQDN or IP address of the FlashArray.
    .PARAMETER OutHTMLFile
    Optional. Path for output report file. Default is %TEMP%\Array_Capacity_Report.html.
    .PARAMETER VolumeFilter
    Optional. Specific volumes to filter output on. Wildcards are accepted. By default, this is "*" (all).
    .PARAMETER Credential
    Optional. Credential for the FlashArray.
    .INPUTS
    None
    .OUTPUTS
    Formatted HTML report containing retrieved data and specified options.
    .EXAMPLE
    New-Pfa2CapacityReport -Endpoint 'myarray.mydomain.com'

    Creates 'myarray.mydomain.com' FlashArray capacity report named 'Array_Capacity_Report.html' in the %TEMP% folder.

    .EXAMPLE
    New-Pfa2CapacityReport -Endpoint 'myarray.mydomain.com' -OutHTMLFile '.\reports\dev_array.html'

    Creates 'myarray.mydomain.com' FlashArray capacity report located at the path '.\reports\dev_array.html'.

    .EXAMPLE
    New-Pfa2CapacityReport -Endpoint 'myarray.mydomain.com' -OutHTMLFile '.\reports\dev_array.html' -VolumeFilter 'dev-*'

    Creates 'myarray.mydomain.com' FlashArray capacity report located at the path '.\reports\dev_array.html'.
    Volumes names to include matches 'dev-*' pattern.

    .NOTES
    This cmdlet can utilize the global credentials variable for FlashArray authentication. Set the credential variable by using the command Set-Pfa2Credential.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Endpoint,
        [ValidateNotNullOrEmpty()]
        [string]$OutHTMLFile = (Join-Path $env:Temp 'Array_Capacity_Report.html'),
        [ValidateNotNullOrEmpty()]
        [string]$VolumeFilter = '*',
        [pscredential]$Credential = ( Get-Pfa2Credential )
    )

    # define variables
    $ReportDateTime = Get-Date -Format d
    $metadata = [PSCustomObject]@{
        ReportDate = Get-Date -Format g
        Source = $env:COMPUTERNAME
        ScriptPath = $($myInvocation.mycommand).path
        ScriptVersion = "3.0.0.0"
        CreatedBy = "$env:USERNAME"
    }

    # Connect to FlashArray
    try {
        $flashArray = Connect-Pfa2Array -Endpoint $Endpoint -Credential $Credential -IgnoreCertificateError
    }
    catch {
        $ExceptionMessage = $_.Exception.Message
        Write-Error "Failed to connect to FlashArray endpoint $Endpoint with: $ExceptionMessage"
        Return
    }

    try {
        # populate variables
        $FlashArrayConfig = Get-Pfa2Array -Array $FlashArray

        $sysCapacity = $FlashArrayConfig.Capacity / 1TB
        $sysSnapshotSpace = $FlashArrayConfig.Space.Snapshots / 1MB
        $sysVolumeSpace = $FlashArrayConfig.Space.Unique / 1GB
        $sysSpace = $FlashArrayConfig.Space.TotalPhysical / 1GB
        $sysSharedSpace = $FlashArrayConfig.Space.Shared / 1GB

        if ($FlashArrayConfig.Space.TotalReduction -gt 100) {
            $sysTotalReduction = '>100:1'
        }
        else {
            $sysTotalReduction = "$('{0:N1}' -f $FlashArrayConfig.Space.TotalReduction):1"
        }

        # zero out varables
        $volumeInfo = $null
        $provisioned = 0

        $volumes = Get-Pfa2Volume -Array $FlashArray -Filter "name='$VolumeFilter' and not(subtype='protocol_endpoint')"
        $volumeInfo += "<th>Volume Name</th><th>Volume Size (GB)</th><th>Connection</th><th><center>Protected</center></th><th>DR</th><th>SS</th><th>TP</th><th>WS (GB)</th>"

        ForEach ($volume in $volumes) {
            $printVol = $volume.name
            $volSize = $volume.Provisioned / 1GB
            $provisioned += $volume.Provisioned / 1TB
            $datardx = "{0:N2}" -f $volume.Space.DataReduction
            $dataTP = "{0:N3}" -f $volume.Space.ThinProvisioning
            $WrittenSpace = "{0:N2}" -f (((1 - $volume.Space.ThinProvisioning) * $volume.Space.TotalPhysical) / 1GB)
            if ($volume.Space.shared) {
                $dataSS = "{0:N2}" -f $volume.Space.shared
            }
            else {
                $dataSS = "None"
            }

            # Does the volume have any snapshots?
            if (!(Get-Pfa2VolumeSnapshot -Array $FlashArray -SourceNames $volume.name)) {
                $protected = "No"
            }
            else {
                $protected = "Yes"
            }

            $hostConnections = (Get-Pfa2Connection -Array $connection -VolumeNames $volume.name)
            if (!$hostConnections) {
                $hostconnname = "Not Connected"
            }
            else {
                $hostconnname = $hostConnections.Host.Name
            }

            $volumeInfo += "<tr><td>$("{0:N0}" -f $printVol)</td> <td>$("{0:N0}" -f $volSize)</td><td>$($hostconnname -join '<br>')</td><td><center>$protected</center></td><td>$($datardx)</td><td>$($dataSS)</td><td>$($dataTP)</td><td>$($WrittenSpace)</td></tr>"
        }

        $snapshotInfo = $null
        $snapshots = Get-Pfa2VolumeSnapshot -Array $FlashArray -Filter "source.name='$VolumeFilter'"
        $snapshotInfo += "<th>Snapshot Name</th><th>Snapshot Size (GB)</th>"
        ForEach ($snapshot in $snapshots) {
            $printSnapshot = $snapshot.name
            $snapshotSize = ($snapshot.Space.TotalProvisioned) / 1GB
            $snapshotInfo += "<tr><td>$("{0:N0}" -f $printSnapshot)</td> <td>$("{0:N0}" -f $snapshotSize)</td></tr>"
        }
    }
    finally {
        Disconnect-Pfa2Array -Array $flashArray
    }

    # Create HTML/CSS report format
    #region HTML
    $HTMLHeader = @"
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">
<html>
<head>
<!--
$(($metadata | Out-String).Trim())
-->
<title>Pure Storage FlashArray Capacity Report</title>
<style type="text/css">
<!--
body {
    font-family: Proxima Nova, Verdana, Geneva, Arial, Helvetica, Sans-Serif;
}
table {
	border-collapse: collapse;
	border: none;
	border-right: 1px grey solid;
    border-top: 1px grey solid;
    border-bottom: 1px grey solid;
    border-left: 1px grey solid;
	text-align: left;
	font: 12pt Proxima Nova, Verdana, Geneva, Arial, Helvetica, Sans-Serif;
	color: black;
	margin-bottom: 10px;
    margin-left: 20px;
}

table td {
    vertical-align: top;
	font-size: 12px;
	padding-left: 2px;
	padding-right: 2px;
	text-align: left;
	border-right: 1px grey solid;
    border-top: 1px grey solid;
    border-bottom: 1px grey solid;
    border-left: 1px grey solid;
}

table th {
	font-size: 14px;
	font-weight: bold;
	padding-left: 2px;
	padding-right: 2px;
	text-align: left;
	border-right: 1px grey solid;
    border-top: 1px grey solid;
    border-bottom: 1px grey solid;
    border-left: 1px grey solid;
}

h2 {
    clear: both;
    font-size: 130%;
}

h3 {
	clear: both;
	font-size: 115%;
	margin-left: 20px;
	margin-top: 30px;
}

protected {
    font-weight: bold;
	text-align: left;
}

p {
    margin-left: 20px;
    font-size: 12px;
}

hr {
    background-color: #FE5000
}

table.list {
	font-size: 12px;
	font-weight: normal;
	padding-left: 2px;
	padding-right: 2px;
	text-align: right;
    border-style: solid;
    width: 700px;
}

table.list td:nth-child(1) {
	font-weight: bold;
	border-right: 1px grey solid;
	text-align: left;
}

table.list td:nth-child(2) {
    padding-left: 2px;
	border-right: 1px grey solid;
	text-align: left;
}

table tr:nth-child(even) td:nth-child(even) {
    background: #F8D2CD;
}

table tr:nth-child(odd) td:nth-child(odd) {
    background: #FCEAE8;
}

table tr:nth-child(even) td:nth-child(odd) {
    background: #F8D2CD;
}

table tr:nth-child(odd) td:nth-child(even) {
    background: #FCEAE8;
}

div.column {
    width: 400px;
    float: left;
}

div.first {
    padding-right: 2px;
    border-right: 1px grey solid;
}

div.second {
    margin-left: 30px;
}

div.relative {
    position: relative;
}

div.absolute {
    position: absolute;
    top: 80px;
    left: 350px;
    width: 250px;
    height: 75px;
	font-size: 14px;
	font-weight: bold;
}

div.time {
    position: absolute;
    top: 25px;
    left: 0px;
    width: 600px;
    height: 75px;
	font-size: 12px;
	font-weight: normal;
}

img {
    max-width: 500px;
    max-height: 88px;
}
-->
</style>
</head>
<body>
"@

$CurrentSystemHTML = @"
<img class="relative" src="data:image/png;base64,
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
AElFTkSuQmCC">

<div id="report">
<p><div class='absolute'>FlashArray Capacity Report<br><div class='time'>$(Get-Date -Format U)</div></div>
<h3>FlashArray Information</h3>
<table class="list">
<tr>
<td>FlashArray Name</td>
<td>$($FlashArrayConfig.name)</td>
</tr>
<tr>
<td>Purity Version</td>
<td>$($FlashArrayConfig.version)</td>
</tr>
<tr>
<td>ID</td>
<td>$($FlashArrayConfig.id)</td>
</tr>
<tr>
<td>Total Volumes Space</td>
<td>$("{0:N2}" -f $sysVolumeSpace) G</td>
</tr>
<tr>
<td>Total Snapshots Space</td>
<td>$("{0:N2}" -f $sysSnapshotSpace) M</td>
</tr>
<tr>
<td>Shared Space</td>
<td>$("{0:N2}" -f $sysSharedSpace) G</td>
</tr>
<tr>
<td>Used Space</td>
<td>$("{0:N2}" -f $sysSpace) G</td>
</tr>
<tr>
<td>System Capacity</td>
<td>$("{0:N2}" -f $sysCapacity) T</td>
</tr>
<tr>
<td>System Data Reduction</td>
<td>$("{0:N2}" -f $FlashArrayConfig.Space.DataReduction):1</td>
</tr>
<tr>
<td>Total Data Reduction</td>
<td>$sysTotalReduction</td>
</tr>
<tr>
<td>Provisioned Space</td>
<td>$("{0:N2}" -f $provisioned) T</td>
</tr>
</table>
<h3>Volume Information</h3>
<p>Volumes(s), Sizes (GB) and Data Reduction columes include DR (Data Reduction), SS (Shared Space)<br>and TP (Thin Provisioning) and WS (Written Space) for $($FlashArrayConfig.name) listed below.</p>
<table class="list">$volumeInfo</table>
<h3>FlashRecover SnapShot Information</h3>
<p>Snapshot(s) and Sizes (GB) for $($FlashArrayConfig.name) listed below.</p>
<table class="list">$snapshotInfo</table>
<br></br>
"@
    # Add the current System HTML Report into the final HTML Report body
    $HTMLMiddle += $CurrentSystemHTML

    # Assemble the closing HTML for our report.
    $HTMLEnd = @"
</div>
<hr noshade size=3 width="100%">
$ReportDateTime
</body>
</html>
"@
    # Assemble the final report from all our HTML sections
    $HTMLmessage = $HTMLHeader + $HTMLMiddle + $HTMLEnd
    # Save the report out to a file
    $HTMLmessage | Out-File $OutHTMLFile

    Write-Host ''
    Write-Host "The report file path $(Resolve-Path $OutHTMLFile)." -ForegroundColor Green
}

function New-Pfa2ExcelReport {
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
    New-Pfa2ExcelReport -Endpoint 'myarray.mydomain.com'

    Creates an Excel file in the %temp% folder for array myarray.mydomain.com.

    .EXAMPLE
    New-Pfa2ExcelReport -Endpoint 'myarray01', 'myarray02' -OutPath '.\reports'

    Creates an Excel file for myarray01 and myarray02. Reports are located in the 'reports' folder.

    .EXAMPLE
    Get-Content '.\arrays.txt' | New-Pfa2ExcelReport -OutPath '.\reports'

    Creates an Excel file for each array in the arrays.txt file. Reports are located in the 'reports' folder.

    .EXAMPLE
    New-Pfa2ExcelReport -Endpoint 'myarray.mydomain.com' -Credential (Get-Credential) -OutPath '.\reports'

    Creates an Excel file in the 'reports' folder for array myarray.mydomain.com. Asks for FlashArray credentials.

    .EXAMPLE
    $endpoint = [pscustomobject]@{Endpoint = @('myarray.mydomain.com'); Credential = (Get-Credential)}
    $endpoint | New-Pfa2ExcelReport -OutPath '.\reports'

    Creates an Excel file in the 'reports' folder for array myarray.mydomain.com. Asks for FlashArray credentials.

    .NOTES
    This cmdlet can utilize the global credential variable for FlashArray authentication. Set the credential variable by using the command Set-Pfa2Credential.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Endpoint,
        [int]$SnapLimit,
        [string]$OutPath = $env:Temp,
        [Parameter(ValueFromPipelineByPropertyName)]
        [pscredential]$Credential = ( Get-Pfa2Credential )
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
                $controller0_details = $controllers | Where-Object Name -EQ 'CT0'
                $controller1_details = $controllers | Where-Object Name -EQ 'CT1'
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
            
            $report = [ordered]@{}

            # Array Information
            $report['Array_Info'] = @( [ordered]@{
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
                } )

            ## Volume Details
            $details = $volumes | ForEach-Object {
                [ordered]@{
                    'Name'            = $_.Name
                    'Size(GB)'        = Convert-UnitOfSize $_.provisioned -To 1GB
                    'Unique Data(GB)' = Convert-UnitOfSize $_.space.Unique -To 1GB
                    'Shared Data(GB)' = Convert-UnitOfSize $_.space.Shared -To 1GB
                    'Serial'          = $_.Serial
                    'ConnectionCount' = $_.ConnectionCount
                    'Created'         = $_.Created
                    'Volume Group'    = $_.VolumeGroup.Name 
                    'Destroyed'       = $_.Destroyed
                    'Time Remaining'  =
                    if ($_.TimeRemaining) {
                        $span = [TimeSpan]::FromMilliseconds($_.TimeRemaining)
                        '{0:D2}h {1:D2}m' -f ($span.Days * 24 + $span.Hours), $span.Minutes
                    }
                } }

            $simple = @()
            $vvol = @()
            foreach ($v in $details) {
                if ($v.Name -like '*vvol*') {
                    $vvol += $v
                }
                else {
                    $simple += $v
                }
            }

            if ($simple) {
                $report['Volumes-No vVols'] = $simple
            }
            else {
                Write-Host 'No Volumes exist on Array. Skipping.'
            }

            if ($vvol) {
                $report['vVol Volumes'] = $vvol
            }
            else {
                Write-Host 'No vVol Volume exist on Array. Skipping.'
            }

            ## Volume Snapshot details
            if ($snapshots) {
                $report['Volume Snapshots'] = $snapshots | ForEach-Object {
                    [ordered]@{
                        'Name'            = $_.Name
                        'Created'         = $_.Created
                        'Provisioned(GB)' = Convert-UnitOfSize $_.Provisioned -To 1GB
                        'Destroyed'       = $_.Destroyed
                        'Source'          = $_.Source.Name
                        'Pod'             = $_.pod.name
                        'Volume Group'    = $_.VolumeGroup.Name
                    } }
            }
            else {
                Write-Host 'No Volume Snapshots exist on Array. Skipping.'
            }

            # Host Details
            if ($host_details) {
                $report['Hosts'] = $host_details | ForEach-Object {
                    [ordered]@{
                        'Name'           = $_.Name
                        'No. of Volumes' = $_.ConnectionCount
                        'HostGroup'      = $_.HostGroup.Name
                        'Personality'    = $_.Personality
                        'Allocated(GB)'  = Convert-UnitOfSize $_.space.totalprovisioned -To 1GB
                        'Wwns'           = $_.Wwns -join ', '
                    } }
            }
            else {
                Write-Host 'No Hosts exist on Array. Skipping.'
            }
            
            ## HostGroup Details
            if ($hostgroup) {
                $report['Host Groups'] = $hostgroup | ForEach-Object {
                    [ordered]@{
                        'Name'           = $_.Name
                        'HostCount'      = $_.HostCount
                        'No. of Volumes' = $_.ConnectionCount
                        'Total Size(GB)' = Convert-UnitOfSize $_.space.totalprovisioned -To 1GB
                    } }
            }
            else {
                Write-Host 'No Host Groups exist on Array. Skipping.'
            }
            
            ## Protection Group and Protection Group Transfer details
            if ($pgd) {
                $report['Protection Groups'] = $pgd | ForEach-Object {
                    [ordered]@{
                        'Name'              = $_.Name
                        'Snapshot Size(GB)' = Convert-UnitOfSize $_.space.snapshots -To 1GB
                        'VolumeCount'       = $_.VolumeCount
                        'Source'            = $_.source.name
                    } }
            }
            else {
                Write-Host 'No Protection Groups exist on Array. Skipping.'
            }

            if ($pgst) {
                $report['PG Snapshot Transfers'] = $pgst | ForEach-Object {
                    [ordered]@{
                        'Name'                       = $_.Name
                        'Data Transferred(MB)'       = Convert-UnitOfSize $_.DataTransferred -To 1MB
                        'Destroyed'                  = $_.Destroyed
                        'Physical Bytes Written(MB)' = Convert-UnitOfSize $_.PhysicalBytesWritten -To 1MB
                        'Status'                     = $_.Progress -Replace ('1', 'Transfer Complete')
                    } }
            }
            else {
                Write-Host 'No Protection Group Transfer details on Array. Skipping.'
            }

            ## Pod details
            if ($pods) {
                $report['Pods'] = $pods | ForEach-Object {
                    [ordered]@{
                        'Name'            = $_.Name
                        'ArrayCount'      = $_.ArrayCount
                        'Source'          = $_.source.name
                        'Mediator'        = $_.Mediator
                        'PromotionStatus' = $_.PromotionStatus
                        'Destroyed'       = $_.Destroyed
                    } }
            }
            else {
                Write-Host 'No Pods exist on Array. Skipping.'
            }

            Export-Pfa2Excel -Tables $report -LiteralPath $excelFile
        }
    }

    end {
        Write-Host "Complete. Files located in $(Resolve-Path $OutPath)" -ForegroundColor green
    }
}

function New-Pfa2PGroupVolumes() {
    <#
    .SYNOPSIS
    Creates volumes to a new FlashArray Protection Group (PGroup).
    .DESCRIPTION
    This cmdlet will allow for the creation of multiple volumes and adding the created volumes to a new Protection Group (PGroup).
    The new volume names will default to "$PGroupPrefix-vol1", "PGroupPrefix-vol2" etc.
    .PARAMETER Endpoint
    Required. FQDN or IP address of the FlashArray.
    .PARAMETER PGroupPrefix
    Required. The name of the Protection Group prefix to add volumes to. This parameter specifies the prefix of the PGroup name.
    The suffix defaults to "-PGroup". Example: -PGroupPrefix "database". The full PGroup name will be "database-PGroup".
    This PGroup will be created as new and must not already exist on the array.
    This prefix will also be used to uniquely name the volumes as they are created.
    .PARAMETER VolumeSizeGB
    Required. The size of the new volumes in Gigabytes (GB).
    .PARAMETER NumberOfVolumes
    Required. The number of volumes that are to be created. Each volume will be named "vol" with an ascending number following (ie. vol1, vol2, etc.). Each volume name will also contain the $PGroupPrefix variable as the name prefix.
    .PARAMETER Credential
    Optional. Credential for the FlashArray.
    .INPUTS
    None
    .OUTPUTS
    None
    .EXAMPLE
    New-Pfa2PGroupVolumes -Endpoint "myarray.mydomain.com" -PGroupPrefix "database" -VolumeSizeGB 200 -NumberOfVolumes 3

    Creates 3-200GB volumes, named "database-vol1", "database-vol2", and "database-vol3". Each volume is added to the new Protection Group "database-PGroup".

    .NOTES
    This cmdlet can utilize the global credentials variable for FlashArray authentication. Set the credential variable by using the command Set-Pfa2Credential.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Endpoint,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PGroupPrefix,
        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$VolumeSizeGB,
        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$NumberOfVolumes,
        [pscredential]$Credential = ( Get-Pfa2Credential )
    )

    # Connect to FlashArray
    try {
        $flashArray = Connect-Pfa2Array -Endpoint $Endpoint -Credential $Credential -IgnoreCertificateError
    }
    catch {
        $ExceptionMessage = $_.Exception.Message
        Write-Error "Failed to connect to FlashArray endpoint $Endpoint with: $ExceptionMessage"
        Return
    }

    try {
        $volumes = ( 1..$NumberOfVolumes ) |
        ForEach-Object { "$PGroupPrefix-Vol$_" } |
        New-Pfa2Volume -Array $FlashArray -Provisioned ($VolumeSizeGB * 1GB)

        $group = New-Pfa2ProtectionGroup -Array $FlashArray -Name "$PGroupPrefix-PGroup"

        New-Pfa2ProtectionGroupVolume -Array $FlashArray -MemberNames $volumes.name -GroupNames $group.Name
    }
    finally {
        Disconnect-Pfa2Array -Array $flashArray
    }
}

function Remove-Pfa2PendingDeletes() {
    <#
    .SYNOPSIS
    Reports on pending FlashArray Volume and Snapshots deletions and optionally Eradicates them.
    .DESCRIPTION
    This cmdlet will return information on any volumes or volume snapshots that are pending eradication after deletion and
    optionally prompt for eradication of those objects. The user will be prompted for confirmation.
    .PARAMETER Endpoint
    Required. FQDN or IP address of the FlashArray.
    .PARAMETER Credential
    Optional. Credential for the FlashArray.
    .INPUTS
    None
    .OUTPUTS
    Volume and volume snapshots awaiting eradication.
    .EXAMPLE
    Remove-Pfa2PendingDeletes -Endpoint 'myarray.mydomain.com'

    Reports and prompts for eradication on pending Volume and Snapshots deletions on the FlashArray myarray.mydomain.com.

    .EXAMPLE
    Remove-Pfa2PendingDeletes -Endpoint 'myarray.mydomain.com'

    Reports on pending Volume and Snapshots deletions on the FlashArray myarray.mydomain.com.
    Eradicates Volume and Snapshots without confirmation.

    .NOTES
    This cmdlet can utilize the global credentials variable for FlashArray authentication. Set the credential variable by using the command Set-Pfa2Credential.
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Endpoint,
        [pscredential]$Credential = ( Get-Pfa2Credential )
    )

    # Connect to FlashArray
    try {
        $flashArray = Connect-Pfa2Array -Endpoint $Endpoint -Credential $Credential -IgnoreCertificateError
    }
    catch {
        $ExceptionMessage = $_.Exception.Message
        Write-Error "Failed to connect to FlashArray endpoint $Endpoint with: $ExceptionMessage"
        Return
    }

    try {
        $pendingvolumelist = Get-Pfa2Volume -Array $flashArray -Destroyed $true
        $pendingsnaplist = Get-Pfa2VolumeSnapshot -Array $flashArray -Destroyed $true

        Write-Host 'Listing PENDING volumes and snapshots that exist on the array.'
        Write-Host "======================================================================================================================`n"

        if (-not $pendingvolumelist) {
            Write-Host 'No volumes are pending delete.'
        }
        else {
            Write-Host 'Volumes in PENDING state'
            foreach ($volume in $pendingvolumelist) {
                Write-Host ' -' $volume.name
            }
        }

        if (-not $pendingsnaplist) {
            Write-Host 'No snapshots are pending delete.'
        }
        else {
            Write-Host 'Snapshots in PENDING state'
            foreach ($volumesnap in $pendingsnaplist) {
                Write-Host ' -' $volumesnap.name
            }
        }

        if (-not $pendingvolumelist -and -not $pendingsnaplist) {
            return
        }

        if (-not $PSCmdlet.ShouldProcess(
                'Eradicate pending volumes and snapshots.',
                'Do you wish to perform this unrecoverable operation?',
                'Eradicate pending volumes and snapshots.')) {
            return
        }

        Write-Host 'Eradicating PENDING volumes and snapshots.'
        Write-Host "======================================================================================================================`n"

        foreach ($volumesnap in $pendingsnaplist) {
            Write-Host ' -' $volumesnap.name ' eradicated'
            Remove-Pfa2VolumeSnapshot -Array $flashArray -Name $volumesnap.name -Eradicate
        }

        foreach ($volume in $pendingvolumelist) {
            Write-Host ' -' $volume.name ' eradicated.'
            Remove-Pfa2Volume -Array $flashArray -Name $volume.name -Eradicate
        }

        Write-Host 'Volume and Snapshot pending deletes have been eradicated.'
    }
    finally {
        Disconnect-Pfa2Array -Array $flashArray
    }
}

function Restore-Pfa2PGroupVolumeSnapshots() {
    <#
    .SYNOPSIS
    Recover all of the volumes from a protection group (PGroup) snapshot.
    .DESCRIPTION
    This cmdlet will recover all of the volumes from a protection group (PGroup) snapshot in one operation.
    .PARAMETER Endpoint
    Required. FQDN or IP address of the FlashArray.
    .PARAMETER ProtectionGroup
    Required. The name of the protection group.
    .PARAMETER SnapshotName
    Required. The name of the protection group snapshot.
    .PARAMETER Prefix
    Required. The prefix to add to the recovered volume name.
    .PARAMETER HostName
    Optional. The name of the host to attach the recovered volumes to.
    .PARAMETER Credential
    Optional. Credential for the FlashArray.
    .INPUTS
    None
    .OUTPUTS
    None
    .EXAMPLE
    Restore-Pfa2PGroupVolumeSnapshots -Endpoint 'myarray.mydomain.com' –ProtectionGroup 'Dev-PGroup' –SnapshotName 'Dev-PGroup.01' –Prefix 'TEST'

    Restores snapshot 'Dev-PGroup.01' from the protection group 'Dev-PGroup', adds the prefix of 'TEST' to
    recovered volumes names on the FlashArray 'myarray.mydomain.com'.

    .EXAMPLE
    Restore-Pfa2PGroupVolumeSnapshots -Endpoint 'myarray.mydomain.com' –ProtectionGroup 'Dev-PGroup' –SnapshotName 'Dev-PGroup.01' –Prefix 'TEST' -HostName 'test-vm-01'

    Restores snapshot 'Dev-PGroup.01' from the protection group 'Dev-PGroup', adds the prefix of 'TEST' to
    recovered volumes names, and attaches them to the host 'test-vm-01' on the FlashArray 'myarray.mydomain.com'.

    .NOTES
    This cmdlet can utilize the global credentials variable for FlashArray authentication. Set the credential variable by using the command Set-Pfa2Credential.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Endpoint,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ProtectionGroup,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SnapshotName,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Prefix,
        [ValidateNotNullOrEmpty()]
        [string]$HostName,
        [pscredential]$Credential = ( Get-Pfa2Credential )
    )

    # Connect to FlashArray
    try {
        $flashArray = Connect-Pfa2Array -Endpoint $Endpoint -Credential $Credential -IgnoreCertificateError
    }
    catch {
        $ExceptionMessage = $_.Exception.Message
        Write-Error "Failed to connect to FlashArray endpoint $Endpoint with: $ExceptionMessage"
        Return
    }

    try {
        $groups = Get-Pfa2ProtectionGroup -Array $flashArray -Name $ProtectionGroup
        foreach ($group in $groups) {
            $volumes = Get-Pfa2ProtectionGroupVolume -Array $flashArray -GroupNames $group.Name | Select-Object -ExpandProperty 'Member'
            foreach ($volume in $volumes) {
                $name = $volume.Name.Replace($group.Source.Name + '::', '')
                $volumeName = "$Prefix-$name"
                $source = "$SnapshotName.$name"
                New-Pfa2Volume -Array $flashArray -Name $volumeName -SourceName $source
                if ($HostName) {
                    New-Pfa2Connection -Array $flashArray -HostNames $HostName -VolumeNames $volumeName
                }
            }
        }
    }
    finally {
        Disconnect-Pfa2Array -Array $flashArray
    }
}

function Sync-Pfa2Hosts() {
    <#
    .SYNOPSIS
    Synchronizes the hosts amd host protocols between two FlashArrays.
    .DESCRIPTION
    This cmdlet will retrieve the current hosts from the Source array and create them on the Target array. It will also add the FC (WWN) or iSCSI (IQN) settings for each host on the Target array.
    .PARAMETER SourceArray
    Required. FQDN or IP address of the source FlashArray.
    .PARAMETER TargetArray
    Required. FQDN or IP address of the target FlashArray.
    .PARAMETER Protocol
    Required. 'FC' for Fibre Channel WWNs or 'iSCSI' for iSCSI IQNs.
    .PARAMETER HostName
    Optional. Host name to filter out hosts to synchronize.
    .PARAMETER Credential
    Optional. Credential for the FlashArray.
    .INPUTS
    None
    .OUTPUTS
    None
    .EXAMPLE
    Sync-Pfa2Hosts -SourceArray 'dev-array' -TargetArray 'test-array' -Protocol FC

    Synchronizes the hosts and hosts FC WWNs from the 'dev-array' to the 'test-array'.

    .EXAMPLE
    Sync-Pfa2Hosts -SourceArray 'dev-array' -TargetArray 'test-array' -Protocol FC -Confirm:$false

    Synchronizes the hosts and hosts FC WWNs from the 'dev-array' to the 'test-array' skipping confirmation prompt.

    .EXAMPLE
    Sync-Pfa2Hosts -SourceArray 'dev-array' -TargetArray 'test-array' -Protocol FC -HostName 'vm-*'

    Synchronizes the hosts and hosts FC WWNs from the 'dev-array' to the 'test-array'. Hosts names to synchronize matches 'vm-*' pattern.

    .EXAMPLE
    Sync-Pfa2Hosts -SourceArray 'dev-array' -TargetArray 'test-array' -Protocol iSCSI

    Synchronizes the hosts and hosts iSCSI IQNs from the 'dev-array' to the 'test-array'.

    .NOTES
    This cmdlet can utilize the global credentials variable for FlashArray authentication. Set the credential variable by using the command Set-Pfa2Credential.
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SourceArray,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetArray,
        [Parameter(Mandatory)]
        [ValidateSet('iSCSI', 'FC')]
        [string]$Protocol,
        [ValidateNotNullOrEmpty()]
        [string]$HostName = '*',
        [pscredential]$Credential = ( Get-Pfa2Credential )
    )

    # Connect to source FlashArray
    try {
        $flashArray1 = Connect-Pfa2Array -Endpoint $SourceArray -Credential $Credential -IgnoreCertificateError
    }
    catch {
        $exceptionMessage = $_.Exception.Message
        Write-Error "Failed to connect to FlashArray endpoint $SourceArray with: $exceptionMessage"
        Return
    }

    try {
        # Connect to target FlashArray
        try {
            $flashArray2 = Connect-Pfa2Array -Endpoint $TargetArray -Credential $Credential -IgnoreCertificateError
        }
        catch {
            $exceptionMessage = $_.Exception.Message
            Write-Error "Failed to connect to FlashArray endpoint $TargetArray with: $exceptionMessage"
            Return
        }

        try {
            $sync_msg = "Copy hosts configuration from $SourceArray to $TargetArray. " +
            "This action overwrites the target array's configuration and can be destructive."
            if (-not $PSCmdlet.ShouldProcess($sync_msg, "Are you sure you want to perform this action?`n$sync_msg", 'Confirm')) {
                return
            }

            Get-Pfa2HostGroup -Array $flashArray1 -Filter "not(contains(name,':'))" | New-Pfa2HostGroup -Array $flashArray2

            $fa1Hosts = Get-Pfa2Host -Array $flashArray1 -Filter "not(contains(name,':'))" -Name $HostName
            $fa1Hosts | New-Pfa2Host -Array $flashArray2

            switch ($Protocol) {
                'iSCSI' {
                    foreach ($fa1Host in $fa1Hosts) {
                        Update-Pfa2host -Array $flashArray2 -AddIqns $fa1Host.iqns -Name $fa1Host.name |
                        Update-Pfa2host -Array $flashArray2 -HostGroupName $fa1Host.HostGroup.Name

                    }
                }
                'FC' {
                    foreach ($fa1Host in $fa1Hosts) {
                        Update-Pfa2host -Array $flashArray2 -AddWwns $fa1Host.wwns -Name $fa1Host.name |
                        Update-Pfa2host -Array $flashArray2 -HostGroupName $fa1Host.HostGroup.Name
                    }
                }
            }
        }
        finally {
            Disconnect-Pfa2Array -Array $flashArray2
        }
    }
    finally {
        Disconnect-Pfa2Array -Array $flashArray1
    }
}

# Declare exports
Export-ModuleMember -Function Get-Pfa2AllHostVolumeInfo
Export-ModuleMember -Function Get-Pfa2DisconnectedVolumes
Export-ModuleMember -Function Get-Pfa2Space
Export-ModuleMember -Function Get-Pfa2StaleSnapshots
Export-ModuleMember -Function Get-Pfa2PgroupsConfig
Export-ModuleMember -Function Get-Pfa2Config
Export-ModuleMember -Function Get-Pfa2Hierarchy
Export-ModuleMember -Function Get-Pfa2QuickCapacityStats
Export-ModuleMember -Function Get-Pfa2RASession
Export-ModuleMember -Function Get-Pfa2VolumeGrowth
Export-ModuleMember -Function Get-Pfa2ConnectDetails
Export-ModuleMember -Function Remove-Pfa2PendingDeletes
Export-ModuleMember -Function Restore-Pfa2PGroupVolumeSnapshots
Export-ModuleMember -Function Sync-Pfa2Hosts
Export-ModuleMember -Function New-Pfa2PGroupVolumes
Export-ModuleMember -Function New-Pfa2CapacityReport
Export-ModuleMember -Function Export-Pfa2Excel
Export-ModuleMember -Function New-Pfa2ExcelReport
Export-ModuleMember -Function Get-Pfa2Credential
Export-ModuleMember -Function Set-Pfa2Credential
Export-ModuleMember -Function Clear-Pfa2Credential
# END
