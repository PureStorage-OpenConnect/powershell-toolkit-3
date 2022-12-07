#PureExchangeBackup is a PowerShell script written by Robert 'Q' Quimbey.
#Send Feedback to rquimbey@purestorage.com
#Version 1.9.1 Physical|iSCSI Guest

Add-PSSnapin -Name Microsoft.Exchange.Management.PowerShell.SnapIn;

$script:pc = get-wmiobject -class win32_computersystem
Function New-VSSExchBackup{
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
        [Parameter(Mandatory=$true)]
        [string]$DBName,
        [Parameter(Mandatory=$false)]
        [boolean]$copyonly #if true, run a copy backup vs a full log truncating backup
    )
    Begin{    
        #Create a subfolder in the name of the database for the metadata.cab file for the backup job
        New-Item -itemtype directory -path "C:\program files\pure storage\vss\exchange\$DBName" -ErrorAction SilentlyContinue
        #date+timestamp to use in the cab file name
        $CABFileName = Get-Date -uFormat "%m_%d_%Y__%H%M_%S"
        
        #Get the database log and edb file path
        $LogPath = Get-MailboxDatabase -id $DBName | Select-Object logfolderpath
        $DBPath = Get-MailboxDatabase -id $DBName | Select-Object edbfilepath
        
        #Grab disk path to pass to diskshadow
        $Disk1 = Get-Volume -filepath $DBPath.edbfilepath | Select-Object -expandproperty path
        $Disk2 = Get-Volume -filepath $LogPath.logfolderpath | Select-Object -expandproperty path
    }
    
    Process{
        #This section is adding the diskshadow commands to a temp file to be executed
    
        #If Log and DB on separate volumes, add both volumes, else add it only once. 
        #Diskshadow script fails if you try to add the same volume twice because it can't handle the error via txt file
        $dbmounted = Get-MailboxDatabaseCopyStatus -Identity $DBName
        If($dbmounted.status -eq "Mounted"){
            Write-Host ""
            Write-Host -ForeGroundColor white $DBName "is Mounted"
            Write-Host ""
            $script = "./$CABFileName.dsh"
            "Set context persistent" | Add-Content $script
            "Set option transportable" | Add-Content $script 
            "Set metadata ""c:\program files\pure storage\vss\exchange\$DBName\$CABFileName.cab""" | Add-Content $script
            if ($copyonly -eq $true){}else{"Begin backup" | Add-Content $script}
            'Add volume '+$Disk1+' alias '+$CABFileName+'_01 Provider {781c006a-5829-4a25-81e3-d5e43bd005ab}'| Add-Content $script
            if ($Disk1 -ne $Disk2) {'Add volume '+$Disk2+' alias '+$CABFileName+'_02 Provider {781c006a-5829-4a25-81e3-d5e43bd005ab}' | Add-Content $script }
            "Create" | Add-Content $script
            "End backup" | Add-Content $script
            "exit" | Add-Content $script
        
            diskshadow /s $script
            Remove-Item $script

            
            Write-Host ""
            Write-Host -ForeGroundColor white "Compare the ending backup time within a few seconds with the following backup successful event. They should match."
            $eventcheck = Get-EventLog -log Application -newest 10 -instanceid 2006 -message "*$DBName*"
            $eventcheck[0] | Format-List
            if ($eventcheck.Message -like "*$DBName*"){
                Write-Host -ForeGroundColor white "Event Matches Database name."
            } else {
                Write-Host -ForeGroundColor white "Microsoft Event does not Match "$DBName
                Write-Host -ForeGroundColor white "Check that database is mounted and Event Viewer."
                Write-Host -ForeGroundColor white "Retry the backup."
                Get-MailboxDatabaseCopyStatus $DBName
                # I now check if db is dismounted at the start and abort.
            }
	    $BackupCompleteTime = Get-Date
	    $vsstime = $eventcheck[0].timewritten
	    #Write-Host -ForeGroundColor white "VSS completed at $vsstime"
            #Write-Host -ForeGroundColor white "Ending Backup of $DBName at $BackupCompleteTime"
	    $totaltime = ($vsstime - $backupcompletetime).totalseconds
	    if ($totaltime -lt 1)
            {
            write-host "Backup completed successfully at $vsstime" 
            }
	    else 
            {
            $diff = $backupcompletetime - $vsstime
            write-host "Script completed at $backupcompletetime and VSS completed at $vsstime. It is off by $diff.totalseconds. If this is off by more than a few seconds, backup may not have completed successfully."
	    }
        }
    }
}
#END New-VSSExchBackup