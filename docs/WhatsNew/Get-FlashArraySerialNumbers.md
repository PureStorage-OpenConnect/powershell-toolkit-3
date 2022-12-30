# What's new in Get-flashArraySerialNumbers

- Add optional `-CimSession` parameter
- Change return type to `PSCustomObject`

## CimSession parameter

The user may reuse an existing CimSession or pass a computer name.

```powershell
Get-flashArraySerialNumbers 'someComputer'
```

```powershell
$session = New-CimSession 'someComputer' -Credential (Get-Credential)
Get-flashArraySerialNumbers -CimSession $session
```

## Return type

The function return a collection of objects instead of formatting data. The output can be reused or saved in a variable while the screen output is the same.
