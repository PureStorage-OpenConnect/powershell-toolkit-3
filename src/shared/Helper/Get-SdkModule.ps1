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
