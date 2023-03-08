function Remove-ExchBackup()
{
    [CmdletBinding(SupportsShouldProcess)]
    param(

    )

    # Remove .cab file
    # Remove pfa volume (needs pfa endpoint and credential).
    # Params to specify which backups to delete (older than 100 days, keep last 5 backups and etc.).
}