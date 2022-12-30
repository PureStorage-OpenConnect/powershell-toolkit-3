# What's new in Register-HostVolumes

- Add  support for standard `-Confirm`, `-Verbose`, and `-WhatIf` parameters
- Add `-CimSession` optional parameter

## CimSession parameter

The user may reuse an existing CimSession or pass a computer name.

```powershell
Register-HostVolumes 'someComputer'
```

```powershell
$session = New-CimSession 'someComputer' -Credential (Get-Credential)
Register-HostVolumes -CimSession $session
```
