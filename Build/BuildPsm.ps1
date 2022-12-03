#Requires -Version 5

$prologueRelativePath = 'prologue.psm1'

function Merge-Directory {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$PsmPath
    )

    Get-ChildItem -Directory | % {
        $sectionName = $_.Name
        "#region $sectionName functions`n"    | Out-File -Append $PsmPath
        Push-Location $_
        Merge-Directory $PsmPath
        Pop-Location
        "#endregion $sectionName functions`n" | Out-File -Append $PsmPath
    }

    Get-ChildItem -Filter '*.ps1' | Get-Content -Raw | Out-File -Append $PsmPath
}

function Merge-Module {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [IO.FileInfo]$ManifestPath,
        [Parameter(Mandatory)]
        [IO.DirectoryInfo]$OutPath
    )

    process {
        $manifest = Import-PowerShellDataFile $ManifestPath
        $shortName = [IO.Path]::GetFileNameWithoutExtension($ManifestPath.Name)
        $fullName = if($shortName -eq 'root'){
            "PureStorage.Toolkit"
        }
        else{
            "PureStorage.Toolkit.$shortName"
        }

        $psmPath = New-Item (Join-Path $OutPath $fullName) -ItemType Directory -Force
        Copy-Item $ManifestPath (Join-Path $psmPath "$fullName.psd1") -PassThru

        if(-not $manifest.RootModule) { return }

        $psmPath = Join-Path $psmPath $manifest.RootModule

        $sourcePath = Join-Path 'src' $shortName
        if (Test-Path $sourcePath) {
            Push-Location $sourcePath -Verbose
            try {
                if (Test-Path $prologueRelativePath) {
                    Get-Content $prologueRelativePath -Raw | Out-File $psmPath
                }

                Push-Location '../shared'
                try{
                    Merge-Directory $psmPath
                }
                finally{
                    Pop-Location
                }

                Merge-Directory $psmPath
            }
            finally {
                Pop-Location -Verbose
            }

            '# Declare exports' | Out-File -Append $psmPath

            $manifest.FunctionsToExport | % { "Export-ModuleMember -Function $_" } | Out-File -Append $psmPath
            $manifest.VariablesToExport | % { "Export-ModuleMember -Variable $_" } | Out-File -Append $psmPath
            $manifest.AliasesToExport   | % { "Export-ModuleMember -Alias $_" }    | Out-File -Append $psmPath
            $manifest.CmdletsToExport   | % { "Export-ModuleMember -Cmdlet $_" }   | Out-File -Append $psmPath

            '# END' | Out-File -Append $psmPath
        }
    }
}

$moduleParams = @{
    OutPath = New-Item -Name 'out' -ItemType Directory -Force
}

Remove-Item -Recurse (Join-Path $moduleParams.OutPath '*')

Get-ChildItem '*.psd1' | Merge-Module @moduleParams
