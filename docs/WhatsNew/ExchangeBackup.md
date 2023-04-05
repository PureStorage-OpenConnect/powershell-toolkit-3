# Exchange backup cmdlets

The following cmdlets manage Exchange server backups.

## Get-ExchangeBackup, Restore-ExchangeBackup, New-ExchangeBackup, Remove-ExchangeBackup

These functions implement basic backup operations. See help for more information.

## Mount-ExchangeBackup, Dismount-ExchangeBackup

These functions help to expose Exchange backups as file system entries. See help for details and examples.

## Enter-ExchangeBackupExposeSession

This cmdlet wraps a script or manual operations with `Mount-ExchangeBackup` and `Dismount-ExchangeBackup`.

### Manual operation

This script exposes an Exchange backup as a file system directory, then pauses execution to let the manipulate the files. After the user types `exit`, the script continues and removes the mapping of backup into the file system.

The following example the user gets the latest backup for database named 'single' and invokes `Enter-ExchangeBackupExposeSession`. The cmdlet maps the backup into the file system and creates a nested prompt. The message above the prompt is a reminder of temporarily mapped backup.

```PowerShell
PS C:\Users\administrator.QEXCHANGE> Get-ExchangeBackup -DatabaseName 'single' -Latest 1 | Enter-ExchangeBackupExposeSession
# Type 'exit' to end the expose session, cleanup and unexpose the shadow copy.
[single]: PS C:\Program Files\Pure Storage\VSS\Exchange\single\03_14_2023__22_27_55>
```

At this point current path is the location of the exposed backup files. The user is free to run PowerShell commands or do any manipulations with other software like Windows Explorer.

```powershell
# Type 'exit' to end the expose session, cleanup and unexpose the shadow copy.
[single]: PS C:\Program Files\Pure Storage\VSS\Exchange\single\03_14_2023__22_27_55> Get-ChildItem

    Directory: C:\Program Files\Pure Storage\VSS\Exchange\single\03_14_2023__22_27_55 

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d----l         3/15/2023  10:11 AM                db 

# Type 'exit' to end the expose session, cleanup and unexpose the shadow copy.
[single]: PS C:\Program Files\Pure Storage\VSS\Exchange\single\03_14_2023__22_27_55>> cd .\db\exchange_single_db\
# Type 'exit' to end the expose session, cleanup and unexpose the shadow copy.
[single]: PS C:\Program Files\Pure Storage\VSS\Exchange\single\03_14_2023__22_27_55\db\exchange_single_db> Get-ChildItem

    Directory: C:\Program Files\Pure Storage\VSS\Exchange\single\03_14_2023__22_27_55\db\exchange_single_db 

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
-a----         3/14/2023   3:28 PM           8192 E01.chk
-a----         3/14/2023  10:41 AM        1048576 E01000000DF.log
-a----         3/14/2023  10:41 AM        1048576 E01000000E0.log
-a----         3/14/2023  10:59 AM        1048576 E01000000E1.log
-a----         3/14/2023  10:59 AM        1048576 E01000000E2.log
-a----         3/14/2023  11:04 AM        1048576 E01000000E3.log
-a----          3/3/2023   4:54 AM        1048576 E01res00001.jrs
-a----          3/3/2023   4:54 AM        1048576 E01res00002.jrs
-a----         3/14/2023   3:25 PM        1048576 E01res00003.jrs
-a----         3/14/2023   3:25 PM        1048576 E01res00004.jrs
-a----         3/14/2023   3:25 PM        1048576 E01res00005.jrs
-a----         3/14/2023   3:28 PM        1048576 E01tmp.log
-a----         3/14/2023   3:25 PM      259981312 single.edb
-a----         3/14/2023   3:25 PM         163840 tmp.edb 

Type 'exit' to end the expose session, cleanup and unexpose the shadow copy.
[single]: PS C:\Program Files\Pure Storage\VSS\Exchange\single\03_14_2023__22_27_55\db\exchange_single_db>
```

The user types `exit` after all manipulations with the exposed backup. The cmdlet unmaps the backup and returns to the original prompt.

```powershell
Type 'exit' to end the expose session, cleanup and unexpose the shadow copy.
[single]: PS C:\Program Files\Pure Storage\VSS\Exchange\single\03_14_2023__22_27_55\db\exchange_single_db> exit
PS C:\Users\administrator.QEXCHANGE>
```

### Script automation

The `Enter-ExchangeBackupExposeSession` cmdlet accepts an optional script block. When the block is present the cmdlet does not create a nested prompt. It runs the script instead of manual operation. This allows manipulating the backup files with a PowerShell script.

```powershell
PS C:\Users\administrator.QEXCHANGE> Get-ExchangeBackup -DatabaseName 'single' -Latest 1 | Enter-ExchangeBackupExposeSession -ScriptBlock { Remove-Item .\db\exchange_single_db\*.log }
```
