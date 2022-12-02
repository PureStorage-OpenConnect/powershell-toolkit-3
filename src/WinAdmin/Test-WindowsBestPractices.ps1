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