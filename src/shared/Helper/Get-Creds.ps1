function Get-Creds() {
    <#
    .SYNOPSIS
    Gets credentials for FlashArray authentication.
    .DESCRIPTION
    Helper function
    Supporting function to handle connections.
    .OUTPUTS
    Credentials
    #>
    
    return $(if (!($Creds)) { Get-Credential } else { $Creds })
}
