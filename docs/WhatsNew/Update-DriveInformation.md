# What's new in Update-DriveInformation

- Replace WMI cmdlets with CIM cmdlets
- Add optional CimSession parameter
- Add support for `-WhatIf`, `-Confirm`, and `-Verbose`

## Examples

Change drive **A:** to **K:**.

```PowerShell
Update-DriveInformation -CurrentDriveLetter A -newDriveLetter K
```

Change drive letter on a remote computer when current user has WMI access permissions.

```PowerShell
Update-DriveInformation -CurrentDriveLetter A -newDriveLetter K -CimSession 10.21.231.151
```

Change drive letter on a remote computer with alternate credentials.

```PowerShell
$session = New-CimSession -ComputerName 10.21.231.151 -Credential (Get-Credential)
Update-DriveInformation -CurrentDriveLetter A -newDriveLetter K -CimSession $session
```

Change drive letter on multiple computers as current user.

```PowerShell
'.', '10.21.231.151' | Update-DriveInformation -CurrentDriveLetter A -newDriveLetter K
```

See what is going to happen instead of doing actual drive information update.

```PowerShell
'.', '10.21.231.151' | Update-DriveInformation -WhatIf -CurrentDriveLetter A -newDriveLetter K
```
