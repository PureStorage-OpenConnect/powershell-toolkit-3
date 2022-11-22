function Get-FlashArrayVolumeGrowth() {
    <#
    .SYNOPSIS
    Retrieves volume growth information over past X days at X percentage of growth.
    .DESCRIPTION
    Retrieves volume growth in GB from a FlashArray for volumes that grew in past X amount of days at X percentage of growth.
    .PARAMETER Arrays
    Required. An IP address or FQDN of the FlashArray(s). Multiple arrys can be specified, seperated by commas. Only use single-quotes or no quotes around the arrays parameter object. Ex. -Arrays array1,array2,array3 --or-- -Arrays 'array1,array2,array3'
    .PARAMETER MinimumVolumeAgeInDays
    Optional. The minimum age in days that a volume must be to report on it. If not specified, defaults to 1 day.
    .PARAMETER StartTime
    Required. The timeframe to compare the volume size against.
    .PARAMETER GrowthPercentThreshold
    Optional. The minimum percentage of volume growth to report on. Specified as a numerical value from 1-99. If not specified, defaults to '1'.
    .PARAMETER DoNotReportGrowthOfLessThan
    Optional. If growth in size, in Gigabytes, over the specified period is lower than this value, it will not be reported. Specified as a numerical value. If not specified, defaults to '1'.
    .PARAMETER DoNotReportVolSmallerThan
    Optional. Volumes that are smaller than this size in Gigabytes will not be reported on. Specified as a numerical value + GB. If not specified, defaults to '1GB'.
    .PARAMETER html
    Optional. Switch. If present, produces a HTML of the output in the current folder named FlashArrayVolumeGrowthReport.html.
    .PARAMETER csv
    Optional. Switch. If present, produces a csv comma-delimited file of the output in the current folder named FlashArrayVolumeGrowthReport.csv.
    .INPUTS
    Specified inputs to calculate volumes reported on.
    .OUTPUTS
    Volume capacity information to the console, and also to a CSV and/or HTML formatted report (if specified).
    .EXAMPLE
    Get-FlashArrayVolumeGrowth -Arrays array1,array2 -GrowthPercentThreshold '10' -MinimumVolumeAgeInDays '1' -StartTime (Get-Date).AddHours(-1) -DoNotReportGrowthOfLessThan '1' -DoNotReportVolSmallerThan '1GB' -csv

    Retrieve volume capacity report for array 1 and array2 comparing volumes over the last hour that:
        - volumes that are not smaller than 1GB in size
        - must have growth of less than 1GB
        - that are at least 1 day old
        - have grown at least 10%
        - output the report to a CSV delimited file
    .NOTES
    All arrays specified must use the same credential login.

    This cmdlet can utilize the global $Creds variable for FlashArray authentication. Set the variable $Creds by using the command $Creds = Get-Credential.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][string[]] $Arrays,
        [Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][DateTime] $StartTime,
        [Parameter(Mandatory = $False)][ValidateNotNullOrEmpty()][string] $MinimumVolumeAgeInDays = '1',
        [Parameter(Mandatory = $False)][ValidateNotNullOrEmpty()][string] $GrowthPercentThreshold = '1',
        [Parameter(Mandatory = $False)][string] $DoNotReportGrowthOfLessThan = '1',
        [Parameter(Mandatory = $False)][string] $DoNotReportVolSmallerThan = '1GB',
        [Parameter(Mandatory = $False)][switch] $csv,
        [Parameter(Mandatory = $False)][switch] $html
    )

    # Get credentials for all endpoints
    $cred = Get-Creds

    # Connect to FlashArray(s)
    $connections = @{}
    $volThatBreachGrowthPercentThreshold = @()
    foreach ($array in $Arrays) {
        try {
            $flashArray = Connect-Pfa2Array -Endpoint $array -Credential $cred -IgnoreCertificateError
            $connections.add($array, $flashArray)
        }
        catch {
            $exceptionMessage = $_.Exception.Message
            Write-Error "Failed to connect to FlashArray endpoint $array with: $exceptionMessage"
            Return
        }
    }

    try {
        Write-Host ''
        Write-Host 'Retrieving data from arrays and calculating.' -ForegroundColor Yellow
        Write-Host 'This may take some time depending on number of arrays, volumes, etc. Please wait...' -ForegroundColor Yellow
        Write-Host ''

        foreach ($array in $Arrays) {
            Write-Host "Calculating array $array..." -ForegroundColor Green
            Write-Host ''
            $flashArray = $connections[$array]
            $volDetails = (Get-Pfa2Volume -Array $flashArray -ErrorAction SilentlyContinue)
            $volDetailsExcludingNewAndSmall = $volDetails | ? { $_.Space.TotalProvisioned -GT $DoNotReportVolSmallerThan } | Where-Object { (Get-Date $_.created) -lt (Get-Date).AddDays(-$MinimumVolumeAgeInDays) }
            $volDetailsExcludingNewAndSmall = $volDetailsExcludingNewAndSmall |
            % {
                $volumeSpaceMetrics = Get-Pfa2VolumeSpace -Name $_.name -StartTime $StartTime -Array $flashArray
                $_ | Add-Member NoteProperty -PassThru -Force -Name 'GrowthPercentage' -Value  $([math]::Round((($volumeSpaceMetrics | select -Last 1).volumes / (1KB + ($volumeSpaceMetrics | Select-Object -First 1).volumes)), 2)) | # 1KB+ appended to avoid devide by 0 errors
                Add-Member NoteProperty -PassThru -Force -Name 'GrowthInGB' -Value  $([math]::Round(((($volumeSpaceMetrics | Select-Object -Last 1).volumes - ($volumeSpaceMetrics | Select-Object -First 1).volumes) / 1GB), 2)) | `
                    Add-Member NoteProperty -PassThru -Force -Name 'ArrayName' -Value $array
            }
            $volThatBreachGrowthPercentThreshold += $volDetailsExcludingNewAndSmall | Where-Object { $_.GrowthPercentage -gt $GrowthPercentThreshold -and $_.GrowthInGB -gt $DoNotReportGrowthOfLessThan }

            if ($volThatBreachGrowthPercentThreshold) {
                Write-Host "The following volumes have grown above the $GrowthPercentThreshold Percent of thier previous size starting from ${StartTime}:" -ForegroundColor Green
            ($($volThatBreachGrowthPercentThreshold | Select-Object Name, ArrayName, GrowthInGB, GrowthPercentage) | Format-Table -AutoSize )
                $htmlOutput = ($($volThatBreachGrowthPercentThreshold | Select-Object name, ArrayName, GrowthInGB, GrowthPercentage))
                $csvOutput = ($($volThatBreachGrowthPercentThreshold | Select-Object name, ArrayName, GrowthInGB, GrowthPercentage))
            }
        }

        Write-Host ' '
        Write-Host 'Query parameters specified as:'
        Write-Host "1) Ignore volumes created in the last $MinimumVolumeAgeInDays days, 2) Volumes smaller than $($DoNotReportVolSmallerThan / 1GB) GB, and 3) Growth lower than $DoNotReportGrowthOfLessThan GB." -ForegroundColor Green
        Write-Host ' '

        if ($html.IsPresent) {
            Write-Host 'Building HTML report as requested. Please wait...' -ForegroundColor Yellow
            $htmlParams = @{
                Title       = 'Volume Capacity Report for FlashArrays'
                Body        = Get-Date
                PreContent  = "<p>Volume Capacity Report for FlashArrays $Arrays :</p>"
                PostContent = "<p>Query parameters specified as: 1) Ignore volumes created in the last $MinimumVolumeAgeInDays days, 2) Volumes smaller than $($DoNotReportVolSmallerThan / 1GB) GB, and 3) Growth lower than $DoNotReportGrowthOfLessThan GB.</p>"
            }
            $htmlOutput | ConvertTo-Html @htmlParams | Out-File -FilePath .\FlashArrayVolumeGrowthReport.html | Out-Null
        }
        if ($csv.IsPresent) {
            Write-Host 'Building CSV report as requested. Please wait...' -ForegroundColor Yellow
            $csvOutput | Export-Csv -NoTypeInformation -Path .\FlashArrayVolumeGrowthReport.csv
        }
        else {
            Write-Host ' '
            Write-Host 'No volumes on the array(s) match the requested criteria.'
            Write-Host ' '
        }
    }
    finally {
        Disconnect-Pfa2Array -Array $flashArray
    }
}
