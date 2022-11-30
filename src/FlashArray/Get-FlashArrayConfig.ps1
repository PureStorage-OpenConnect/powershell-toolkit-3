function Get-FlashArrayConfig() {
    <#
    .SYNOPSIS
    Retrieves and outputs to a file the configuration of the FlashArray.
    .DESCRIPTION
    This cmdlet will run Purity CLI commands to retrieve the base configuration of a FlashArray and output it to a file. This file is formatted for the CLI, not necessarily human-readable.
    .PARAMETER EndPoint
    Required. FQDN or IP address of the FlashArray.
    .PARAMETER OutFile
    Optional. The file path and filename that will contain the output. if not specified, the default is the current folder\Array_Config.txt.
    .PARAMETER ArrayName
    Optional. The FlashArray name to use in the output. Defaults to $EndPoint.
    .INPUTS
    None
    .OUTPUTS
    Configuration file.
    .EXAMPLE
    Get-FlashArray -EndPoint myArray -ArrayName Array100

    Retrieves the configuration for a FlashArray and stores it in the current path as Array100_config.txt.

    .NOTES
    This cmdlet can utilize the global credential variable for FlashArray authentication. Set the credential variable by using the command Set-PfaCredential.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, Mandatory = $True, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $EndPoint,
        [Parameter(Mandatory = $False)][string] $OutFile = "Array_Config.txt",
        [Parameter(Mandatory = $False)][string] $ArrayName = $EndPoint,
        [Parameter()][pscredential]$Credential = ( Get-PfaCredential )
    )

    "==================================================================================" | Out-File -FilePath $OutFile -Append
    "FlashArray Configuration Export for: $($ArrayName)" | Out-File -FilePath $OutFile -Append
    "Date: $(Get-Date)" | Out-File -FilePath $OutFile -Append
    "==================================================================================`n" | Out-File -FilePath $OutFile -Append
    $invokeCommand_pureconfig_list_object = "pureconfig list --object"
    $invokeCommand_pureconfig_list_system = "pureconfig list --system"
    Write-Host "Retrieving FlashArray OBJECT configuration export (host-pod-volume-hgroup-connection)..."
    "FlashArray OBJECT configuration export (host-pod-volume-hgroup-connection)..." | Out-File -FilePath $OutFile -Append
    " " | Out-File -FilePath $OutFile -Append
    Invoke-Pfa2CLICommand -EndPoint $EndPoint -Credential $Credential -CommandText $invokeCommand_pureconfig_list_object | Out-File -FilePath $OutFile -Append
    Write-Host "Retrieving FlashArray SYSTEM configuration export (array-network-alert-support)..."
    "FlashArray SYSTEM configuration export (array-network-alert-support):" | Out-File -FilePath $OutFile -Append
    " " | Out-File -FilePath $OutFile -Append
    Invoke-Pfa2CLICommand -EndPoint $EndPoint -Credential $Credential -CommandText $invokeCommand_pureconfig_list_system | Out-File -FilePath $OutFile -Append
    Write-Host "FlashArray configuration file located in $Outfile." -ForegroundColor Green
}
