#PureExchangeBackup is a PowerShell script written by Robert 'Q' Quimbey.
#Send Feedback to rquimbey@purestorage.com
#Version 1.9.1 Physical|iSCSI Guest

Add-PSSnapin -Name Microsoft.Exchange.Management.PowerShell.SnapIn;

$script:pc = Get-CimInstance -ClassName Win32_ComputerSystem

Function New-VSSExchBackup {
    <#
    .SYNOPSIS
    Create a VSS Snapshot of an Exchange Database on Pure Flash Array and call Remove-ExchBackup to remove all but the number specified in KeepBackup.
    
    .DESCRIPTION
    1) Physical Exchange Servers and VMs where the Microsfot iSCSI Initiator is connected directly to the Pure Storage Flash Array
    
    The ExchBackup function is passed two parameters:
    - The Exchange database name. (-DBName)
    - The number of backups to retain (-KeepBackup)
    An application consistent transportable VSS snapshot of the database and transaction log volume(s) is created on a Pure Flash Array. 
    A metadata .cab file will be created and placed in the folder:  
    "c:\program files\pure storage\vss\exchange\databasename"
    KeepBackup calls the remove-exchbackup function which imports the cabinet file of snapshots to be deleted. 
    
    2) Exchange VMs where databases and transaction logs are on pRDM disks on ESXi.
    
    Since a VM cannot mount a snapshot unless the Pure Volume is connected through the Microsoft iSCSI initiator in the guest, the removal of snapshots will fail. For RDM Volumes exposed to an Exchange hosted on ESXi, be sure to pass the Pure Array Controller Management IP (-PFAEndPoint) and Username (-PFAUser) in this function so that backups
    and metadata .cab files beyond the number requested to keep, can be removed via the Pure Powershell SDK. 

    Look at the New-PFAPassword function for help in saving an encrypted copy of the Pure Array password on disk.
    The Test-PFAPassword function can be used to test that the saved password works with the passed username and endpoint.

    .EXAMPLE
    Load the Script then run the New-ExchBackup function:
    . ./PureExchangeWrapper.psm1
    
    Backup Database RQ1 on Physical Exchange Server or VM with in-guest iSCSI
    New-VSSExchBackup -DBName RQ1 -KeepBackup 5 -copyonly $true
    
    #>
    Param(
        [Parameter(Mandatory = $true, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$DBName,
        [Parameter()]
        [switch]$CopyOnly #if true, run a copy backup vs a full log truncating backup
    )

    process {    
        #Create a subfolder in the name of the database for the metadata.cab file for the backup job
        New-Item -ItemType Directory -Path "C:\program files\pure storage\vss\exchange\$DBName" -ErrorAction SilentlyContinue
        #date+timestamp to use in the cab file name
        $cabFileName = Get-Date -UFormat '%m_%d_%Y__%H%M_%S'
        
        #Get the database log and edb file path
        $mailboxDb = Get-MailboxDatabase -id $DBName
        $logPath = $mailboxDb.LogFolderPath
        $dbPath = $mailboxDb.EdbFilePath
        
        #Grab disk path to pass to diskshadow
        $disk1 = (Get-Volume -FilePath $dbPath).Path
        $disk2 = (Get-Volume -FilePath $logPath).Path

        #This section is adding the diskshadow commands to a temp file to be executed

        #If Log and DB on separate volumes, add both volumes, else add it only once. 
        #Diskshadow script fails if you try to add the same volume twice because it can't handle the error via txt file
        $dbmounted = Get-MailboxDatabaseCopyStatus -Identity $DBName
        If ($dbmounted.status -ne 'Mounted') { return }

        Write-Host ''
        Write-Host -ForegroundColor white $DBName 'is Mounted'
        Write-Host ''

        $script = "./$cabFileName.dsh"
        try {
            & {
                'Set context persistent'
                'Set option transportable'
                "Set metadata ""c:\program files\pure storage\vss\exchange\$DBName\$cabFileName.cab"""

                if (-not $copyonly) { 
                    'Begin backup'
                }

                "Add volume $disk1 alias $($cabFileName)_01 Provider {781c006a-5829-4a25-81e3-d5e43bd005ab}"

                if ($disk1 -ne $disk2) { 
                    "Add volume $disk2 alias $($cabFileName)_02 Provider {781c006a-5829-4a25-81e3-d5e43bd005ab}"
                }

                'Create'
                'End backup'
                'exit'
            } | Add-Content $script
        
            diskshadow /s $script
        }
        finally {
            Remove-Item $script
        }

        Write-Host ''
        Write-Host -ForegroundColor white 'Compare the ending backup time within a few seconds with the following backup successful event. They should match.'
        $eventcheck = Get-EventLog -Log Application -Newest 10 -InstanceId 2006 -Message "*$DBName*"
        $eventcheck[0] | Format-List
        if ($eventcheck.Message -like "*$DBName*") {
            Write-Host -ForegroundColor white 'Event Matches Database name.'
        }
        else {
            Write-Host -ForegroundColor white 'Microsoft Event does not Match '$DBName
            Write-Host -ForegroundColor white 'Check that database is mounted and Event Viewer.'
            Write-Host -ForegroundColor white 'Retry the backup.'
            Get-MailboxDatabaseCopyStatus $DBName
            # I now check if db is dismounted at the start and abort.
        }

        $backupCompleteTime = Get-Date
        $vssTime = $eventcheck[0].TimeWritten
        #Write-Host -ForeGroundColor white "VSS completed at $vsstime"
        #Write-Host -ForeGroundColor white "Ending Backup of $DBName at $BackupCompleteTime"
        $totalTime = ($vssTime - $backupCompleteTime).TotalSeconds
        if ($totalTime -lt 1) {
            Write-Host "Backup completed successfully at $vssTime" 
        }
        else {
            $diff = $backupCompleteTime - $vssTime
            Write-Host "Script completed at $backupCompleteTime and VSS completed at $vssTime. It is off by $diff.totalseconds. If this is off by more than a few seconds, backup may not have completed successfully."
        }
    }
}
#END New-VSSExchBackup