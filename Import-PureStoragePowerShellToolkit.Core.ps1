function Import-ModuleManually {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$ModuleName
    )

    process {

        $manifestPath = Join-Path $ModuleName ($ModuleName + '.psd1')
        $manifest = Import-PowerShellDataFile $manifestPath

        $requiredModules = $manifest.RequiredModules | Where-Object { $_ -is [hashtable] -and $_['ModuleName'] -NotLike 'PureStoragePowershellToolkit*' }

        $requiredModules | ForEach-Object {

            $v = $_.ModuleVersion
            $n = $_.ModuleName

            $m = Get-Module -ListAvailable $n 

            if (-not $m) {
                if ($PSCmdlet.ShouldContinue("Required module $n not found. Install it?", 'Required module installation')) {
                    Install-Module $n -MinimumVersion $v -ErrorAction Stop
                }
                else {
                    Write-Host "Required module $n not installed. Aborting."
                    exit
                }
            }
            else {
                $actualVersion = ($m.Version | Measure-Object -Maximum).Maximum
                if ($actualVersion -lt $v) {
                    if ($PSCmdlet.ShouldContinue("Module $n version $actualVersion is lower than required $v. Update the module?", 'Required module update')) {
                        Install-Module $n -RequiredVersion $v -ErrorAction Stop -Force
                    }
                    else {
                        Write-Host "Required module $n not updated. Aborting."
                        exit
                    }
                }
            }
        }

        Write-host "Import $ModuleName"
        Import-Module ".\$ModuleName"
    }
}

'PureStoragePowershellToolkit.FlashArray',
'PureStoragePowershellToolkit.DatabaseTools' | Import-ModuleManually
