# konfiguration
$mode = Read-Host "Vælg mode: audit / fix"
$reportFile = "C:\temp\hardening_report.csv"
$htmlFile = "C:\temp\hardening_report.html"
$logFile = "C:\temp\hardening_log.txt"

$report = @()

# Funktion: tilføj resultat
function Add-Result {
    param ($Check, $Status, $Details)

    $report += [PSCustomObject]@{
        Check   = $Check
        Status  = $Status
        Details = $Details
        Time    = Get-Date
    }
}


# Check 1: Telnet
$service = Get-Service -Name "Telnet" -ErrorAction SilentlyContinue

if ($service -and $service.Status -ne "Stopped") {
    Add-Result "Telnet Service" "FAIL" "Kører"

    if ($mode -eq "fix") {
        Stop-Service Telnet -Force
        Set-Service Telnet -StartupType Disabled
    }
} else {
    Add-Result "Telnet Service" "OK" "Deaktiveret"
}

# Check 2: gæstebruger

$guest = Get-LocalUser -Name "Guest" -ErrorAction SilentlyContinue

if ($guest.Enabled) {
    Add-Result "Guest Account" "FAIL" "Aktiv"

    if ($mode -eq "fix") {
        Disable-LocalUser -Name "Guest"
    }
} else {
    Add-Result "Guest Account" "OK" "Disabled"
}


# Check 3: Firewall Telnet
$rule = Get-NetFirewallRule -DisplayName "Block Telnet" -ErrorAction SilentlyContinue

if (!$rule) {
    Add-Result "Firewall Telnet" "FAIL" "Manglende regel"

    if ($mode -eq "fix") {
        New-NetFirewallRule -DisplayName "Block Telnet" -Direction Inbound -Protocol TCP -LocalPort 23 -Action Block
    }
} else {
    Add-Result "Firewall Telnet" "OK" "Findes"
}

# Check 4: Længde af kodeord
$policy = net accounts

if ($policy -match "Minimum password length.*12") {
    Add-Result "Password Length" "OK" ">= 12"
} else {
    Add-Result "Password Length" "FAIL" "For lav"

    if ($mode -eq "fix") {
        net accounts /minpwlen:12
    }
}


# Check 5: Windows Defender
$defender = Get-Service -Name "WinDefend"

if ($defender.Status -eq "Running") {
    Add-Result "Windows Defender" "OK" "Aktiv"
} else {
    Add-Result "Windows Defender" "FAIL" "Ikke aktiv"
}

# Check 6: UAC
$uac = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System"

if ($uac.EnableLUA -eq 1) {
    Add-Result "UAC" "OK" "Aktiveret"
} else {
    Add-Result "UAC" "FAIL" "Deaktiveret"

    if ($mode -eq "fix") {
        Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name EnableLUA -Value 1
    }
}


# HTML Rapport
$html = $report | ConvertTo-Html `
    -Title "Hardening Report" `
    -PreContent "<h1>Security Hardening Report</h1>" `
    -PostContent "<p>Genereret: $(Get-Date)</p>"

$html | Out-File $htmlFile


# CSV Rapport
$report | Export-Csv -Path $reportFile -NoTypeInformation

Write-Host "Hardening færdig!"
Write-Host "HTML rapport: $htmlFile"
Write-Host "CSV rapport: $reportFile"