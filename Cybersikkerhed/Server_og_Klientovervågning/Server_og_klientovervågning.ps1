Import-Module ActiveDirectory


# CONFIG
$computers = @("Server1", "Server2", "Client1")
$logFile = "C:\temp\monitor_log.txt"

# Email settings
$smtpServer = "smtp.office365.com"
$port = 587
$from = "monitor@domain.com"
$to = "admin@domain.com"
$credential = Get-Credential

# Cooldown (minutter)
$cooldownMinutes = 10

# Alert cache (memory)
$alertCache = @{}

# FUNCTIONS
function Send-Alert {
    param ($subject, $body)

    Send-MailMessage `
        -SmtpServer $smtpServer `
        -Port $port `
        -UseSsl `
        -Credential $credential `
        -From $from `
        -To $to `
        -Subject $subject `
        -Body $body
}

function Send-SmartAlert {
    param ($alertKey, $subject, $body)

    $now = Get-Date

    if ($alertCache.ContainsKey($alertKey)) {
        $lastSent = $alertCache[$alertKey]

        if (($now - $lastSent).TotalMinutes -lt $cooldownMinutes) {
            Write-Host "SKIPPED (cooldown): $alertKey"
            return
        }
    }

    Send-Alert -subject $subject -body $body
    $alertCache[$alertKey] = $now
}

function Clear-Alert {
    param ($alertKey)

    if ($alertCache.ContainsKey($alertKey)) {
        $alertCache.Remove($alertKey)
    }
}


# MONITOR LOOP
foreach ($computer in $computers) {

    Write-Host "Tjekker $computer..."

    
    # OFFLINE CHECK
    if (!(Test-Connection -ComputerName $computer -Count 1 -Quiet)) {

        $msg = "$computer er OFFLINE!"
        Write-Host $msg -ForegroundColor Red

        Send-SmartAlert `
            -alertKey "$computer`_DOWN" `
            -subject "SERVER DOWN: $computer" `
            -body $msg

        Add-Content $logFile "$(Get-Date) | $computer OFFLINE"
        continue
    }
    else {
        # Recovery: server er online igen
        if ($alertCache.ContainsKey("$computer`_DOWN")) {
            Send-Alert `
                -subject "SERVER RECOVERED: $computer" `
                -body "$computer er ONLINE igen"

            Clear-Alert "$computer`_DOWN"
        }
    }

    try {
        # CPU
        $cpu = Get-CimInstance Win32_Processor -ComputerName $computer | Select-Object -ExpandProperty LoadPercentage

        if ($cpu -gt 80) {
            $msg = "Høj CPU på $computer : $cpu%"

            Send-SmartAlert `
                -alertKey "$computer`_CPU" `
                -subject "CPU ALERT: $computer" `
                -body $msg
        }
        else {
            if ($alertCache.ContainsKey("$computer`_CPU")) {
                Send-Alert `
                    -subject "CPU OK: $computer" `
                    -body "CPU er normal igen ($cpu%)"

                Clear-Alert "$computer`_CPU"
            }
        }
        # RAM
        $ram = Get-CimInstance Win32_OperatingSystem -ComputerName $computer
        $ramUsed = [math]::Round((($ram.TotalVisibleMemorySize - $ram.FreePhysicalMemory) / $ram.TotalVisibleMemorySize) * 100, 2)

        if ($ramUsed -gt 80) {
            $msg = "Høj RAM på $computer : $ramUsed%"

            Send-SmartAlert `
                -alertKey "$computer`_RAM" `
                -subject "RAM ALERT: $computer" `
                -body $msg
        }
        else {
            if ($alertCache.ContainsKey("$computer`_RAM")) {
                Send-Alert `
                    -subject "RAM OK: $computer" `
                    -body "RAM er normal igen ($ramUsed%)"

                Clear-Alert "$computer`_RAM"
            }
        }

        # DISK
        $disks = Get-CimInstance Win32_LogicalDisk -ComputerName $computer -Filter "DriveType=3"

        foreach ($disk in $disks) {
            $diskUsed = [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 2)
            $diskKey = "$computer`_DISK_$($disk.DeviceID)"

            if ($diskUsed -gt 90) {
                $msg = "Disk fuld på $computer ($($disk.DeviceID)) : $diskUsed%"

                Send-SmartAlert `
                    -alertKey $diskKey `
                    -subject "DISK ALERT: $computer" `
                    -body $msg
            }
            else {
                if ($alertCache.ContainsKey($diskKey)) {
                    Send-Alert `
                        -subject "DISK OK: $computer" `
                        -body "Disk $($disk.DeviceID) er normal igen ($diskUsed%)"

                    Clear-Alert $diskKey
                }
            }

            # Log disk
            Add-Content $logFile "$(Get-Date) | $computer | Disk $($disk.DeviceID): $diskUsed%"
        }

        # Log CPU + RAM
        Add-Content $logFile "$(Get-Date) | $computer | CPU: $cpu% | RAM: $ramUsed%"

    } catch {
        $errorMsg = "$(Get-Date) | FEJL på $computer : $_"
        Add-Content $logFile $errorMsg
        Write-Host $errorMsg -ForegroundColor Red
    }
}

Write-Host "Monitoring færdig!"