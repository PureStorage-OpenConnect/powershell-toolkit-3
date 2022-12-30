# What's new in Unregister-HostVolumes

- Add  support for standard `-Confirm`, `-Verbose`, and `-WhatIf` parameters
- Add `-CimSession` optional parameter

## CimSession parameter

The user may reuse an existing CimSession or pass a computer name.

```powershell
Unregister-HostVolumes 'someComputer'
```

```powershell
$session = New-CimSession 'someComputer' -Credential (Get-Credential)
Unregister-HostVolumes -CimSession $session
```
