function Remove-FlashArrayPendingDeletes() {
    <#
    .SYNOPSIS
    Reports on pending FlashArray Volume and Snapshots deletions and optionally Eradicates them.
    .DESCRIPTION
    This cmdlet will return information on any volumes or volume snapshots that are pending eradication after deletion and optionally prompt for eradication of those objects. The user will be prompted for confirmation.
    .PARAMETER EndPoint
    Required. FQDN or IP address of the FlashArray.
    .INPUTS
    None
    .OUTPUTS
    Volume and volume snapshots awaiting eradication.
    .EXAMPLE
    Remove-FlashArrayPendingDelete -EndPoint myArray

    .NOTES
    This cmdlet can utilize the global $Creds variable for FlashArray authentication. Set the variable $Creds by using the command $Creds = Get-Credential.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $EndPoint,
        [Parameter(ValueFromPipelineByPropertyName)]
        [pscredential]$Credential = ( Get-PfaCredential )
    )

    # Connect to FlashArray
    try {
        $flashArray = Connect-Pfa2Array -Endpoint $EndPoint -Credential $Credential -IgnoreCertificateError
    }
    catch {
        $ExceptionMessage = $_.Exception.Message
        Write-Error "Failed to connect to FlashArray endpoint $Endpoint with: $ExceptionMessage"
        Return
    }

    $pendingvolumelist = Get-Pfa2Volume -Array $flashArray -Destroyed $true
    $pendingsnaplist = Get-Pfa2VolumeSnapshot -Array $flashArray -Destroyed $true

    Write-Host "Listing PENDING volumes and snapshots that exist on the array."
    Write-Host "======================================================================================================================`n"

    if (!$pendingvolumelist) {
        Write-Host "No volumes are pending delete."
    }
    else {
        Write-Host "Volumes in PENDING state"
        foreach ($volume in $pendingvolumelist) {
            Write-Host " -" $volume.name
        }
    }

    if (!$pendingsnaplist) {
        Write-Host "No snapshots are pending delete."
    }
    else {
        Write-Host "Snapshots in PENDING state"
        foreach ($volumesnap in $pendingsnaplist) {
            Write-Host " -" $volumesnap.name
        }
    }

    if (!$pendingvolumelist -and !$pendingsnaplist) {
        return
    }

    $confirmstring = "proceed"
    Write-Host "Please confirm that you wish to perform an unrecoverable operation."
    Write-Host "======================================================================================================================`n"
    Write-Host "Please type the word $confirmstring to eradicate the pending deleted volumes and snapshots."
    Write-Host "The action will initiate immediately upon inputting $confirmstring. This operation CANNOT be undone." -fore yellow

    $user_response = Read-Host "`t"

    if (($user_response.ToLower() -ne $confirmstring.ToLower())) {
        Write-Host "Your input was [$user_response]. It was not the word $confirmstring. Exiting."
        return
    }

    Write-Host "Eradicating PENDING volumes and snapshots."
    Write-Host "======================================================================================================================`n"

    foreach ($volumesnap in $pendingsnaplist) {
        Write-Host " -" $volumesnap.name " eradicated"
        Remove-Pfa2VolumeSnapshot -Array $flashArray -Name $volumesnap.name -Eradicate -Confirm:$false
    }

    foreach ($volume in $pendingvolumelist) {
        Write-Host " -" $volume.name " eradicated."
        Remove-Pfa2Volume -Array $flashArray -Name $volume.name -Eradicate -Confirm:$false
    }

    Write-Host "Volume and Snapshot pending deletes have been eradicated."
}
