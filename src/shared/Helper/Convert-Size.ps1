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
