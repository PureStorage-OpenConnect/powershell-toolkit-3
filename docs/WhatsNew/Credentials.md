# What's new in credential management

- Added new cmdlets `Get-PfaCredential`, `Set-PfaCredential`, `Clear-PfaCredential`
- Dropped global `$Creds` variable usage
- Added `-Credential` parameter to cmdlets accessing FlashArray
- Moved credential handling code from cmdlet bodies to `-Credential` parameter

## $Creds variable

Instead of setting `$creds` variable, the user can call `Set-PfaCredential` with new credential as optional argument. If no credential was specified, the cmdlet will ask for new credentials. These credentials will be used used by all toolkit cmdlets by default.

`Get-PfaCredential` returns currently saved credentials. If nothing was saved, then the cmdlet will ask for new credential.

After calling `Clear-PfaCredential` the saved value is cleared and the first toolkit cmdlet, which needs FlashArray credentials, will ask for new credentials interactively.

## -Credential parameter

Every toolkit function that connects to a FlashArray, has optional `-Credential` parameter. This adapts the cmdlets to the user's habits.

Use credentials stored with with `Set-PfaCredential` or by another toolkit function. If nothing was saved before, the function will ask for credentials and save them.

```powershell
Get-FlashArrayDisconnectedVolumes 10.21.231.71
```

Use credentials stored in a custom variable.

```powershell
Get-FlashArrayDisconnectedVolumes 10.21.231.71 -Credential $myCreds
```

Ask for credentials, avoid using stored value.

```powershell
Get-FlashArrayDisconnectedVolumes 10.21.231.71 -Credential (Get-Credential)
```

Get credentials from **PowerShell SecretManagement**.

```powershell
Get-FlashArrayDisconnectedVolumes 10.21.231.71 -Credential (Get-Secret superuser)
```

Process multiple FlashArrays with same credentials.

```powershell
$ep = @('10.21.231.71',  '10.21.231.21')
$ep | Get-FlashArrayDisconnectedVolumes -Credential (Get-Secret admin)
```

Process multiple FlashArrays with different credentials.

```powershell
$ep1 = [pscustomobject]@{
    EndPoint = '10.21.231.71'
    Credential = (secret superuser)
}

$ep2 = [pscustomobject]@{
    EndPoint = '10.21.231.21'
    Credential = (secret anotherser)
}

$ep1, $ep2 | Get-FlashArrayDisconnectedVolumes 
```

Attach credentials to existing endpoint object.

```powershell
$ep1 = [pscustomobject]'10.21.231.71'
$ep2 = [pscustomobject]'10.21.231.21'

Add-Member -Input $ep1 -Type NoteProperty -Name Credential -Value (secret superuser)
Add-Member -Input $ep1 -Type NoteProperty -Name Credential -Value (secret anotherser)

$ep1, $ep2 | Get-FlashArrayDisconnectedVolumes 

```