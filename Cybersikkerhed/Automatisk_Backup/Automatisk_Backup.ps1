# =========================
# konfiguration 
# =========================
$source = "C:\Data"
$backupRoot = "\\server\backup"
$cloudpath = "C:\cloud_backup"
$logfile = "C:\temp\backup_log.txt"
$reportFile = "C:\temp\backup_report.csv"

$retentionDays = 7 

# =========================
# report array
# =========================
$report = @()

# =========================
# type af backup 
# =========================
$choice = Read-Host "1 = backup | 2 = restore"

# =========================
# BACKUP
# =========================
if ($choice -eq "1") {

    try {
        $date = Get-Date -Format "yyyy-MM-dd_HH-mm"
        $destination = "$backupRoot\$date"

        # inkrementel backup
        robocopy $source $destination /E /XO /R:2 /W:2 /LOG:$logfile
        Write-Host "Backup gennemført"

        # kopi til cloud 
        $cloudDest = "$cloudpath\$date"
        robocopy $destination $cloudDest /E /R:2 /W:2
        Write-Host "Cloud backup gennemført"

        # retention 
        $limit = (Get-Date).AddDays(-$retentionDays)

        Get-ChildItem $backupRoot | Where-Object {
            $_.CreationTime -lt $limit
        } | ForEach-Object {
            Remove-Item $_.FullName -Recurse -Force
        }

        # SUCCESS REPORT
        $report += [PSCustomObject]@{
            Status = "SUCCESS"
            Time = Get-Date
            BackupPath = $destination
        }

    } catch {

        # ERROR REPORT
        $report += [PSCustomObject]@{
            Status = "FAILED"
            Time = Get-Date
            BackupPath = "N/A"
            Error = $_
        }

        Write-Host "FEJL under backup" -ForegroundColor Red
    }
}

# =========================
# RESTORE
# =========================
elseif ($choice -eq "2") {

    try {
        $backups = Get-ChildItem $backupRoot

        $i = 1
        foreach ($b in $backups) {
            Write-Host "$i. $($b.Name)"
            $i++
        }

        $choice = Read-Host "Vælg backup"
        $selected = $backups[$choice - 1]

        robocopy $selected.FullName $source /E /R:2 /W:2

        Write-Host "Restore færdig"

        # SUCCESS REPORT
        $report += [PSCustomObject]@{
            Status = "RESTORE SUCCESS"
            Time = Get-Date
            BackupPath = $selected.FullName
        }

    } catch {

        $report += [PSCustomObject]@{
            Status = "RESTORE FAILED"
            Time = Get-Date
            BackupPath = "N/A"
            Error = $_
        }

        Write-Host "FEJL under restore" -ForegroundColor Red
    }
}

# =========================
# EXPORT REPORT
# =========================
$report | Export-Csv -Path $reportFile -NoTypeInformation

Write-Host "Rapport gemt: $reportFile"