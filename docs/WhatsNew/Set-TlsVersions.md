# What's new in Set-TlsVersions

- Added `-Verbose`, `-Confirm`, `-WhatIf`, and `-Force` [common parameters](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_commonparameters) 
- Added `-MinVersion` parameter
- Added `Enable-SecureChannelProtocol`, `Enable-SecureChannelProtocol`, and `Backup-RegistryKey` cmdlets
- Backup does not save the whole registry, only the protocols branch is exported
- Existing settings for protocols other than TLS are now preserved
- Replaced raw user input with standard confirmation dialog for backup file overwrite

## MinVersion

Added `-MinVersion` optional parameter. `Set-TlsVersions` cmdlet disables all TLS protocol versions below `MinVersion` *and enables* `MinVersion` and above.

The following command disables TLS 1.0, 1.1, and 1.2, and enables TLS 1.3. (Use `-WhatIf` parameter to see what would happen).

```powershell
Set-TlsVersions -MinVersion 1.3
```

## Common parameters

 When backup file already exists, the overwrite confirmation dialog is always started even if `-Confirm` was not used, unless the `-Force` parameter is present. `-Force` suppresses all confirmations including backup file overwrite.