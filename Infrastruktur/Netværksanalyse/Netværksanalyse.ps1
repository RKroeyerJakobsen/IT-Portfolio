
#Konfiguration
$subnet = "192.168.1"
$ports = @(21, 22, 80, 443, 3389)
$report = @()

# CVE cache
$cveCache = @{}

#Funktioner 
function Test-Port {
    param ($ip, $port)

    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $tcp.Connect($ip, $port)
        $tcp.Close()
        return $true
    } catch {
        return $false
    }
}

function Search-CVE {
    param ($keyword)

    # Cache check
    if ($cveCache.ContainsKey($keyword)) {
        return $cveCache[$keyword]
    }

    $url = "https://services.nvd.nist.gov/rest/json/cves/2.0?keywordSearch=$keyword"

    try {
        $response = Invoke-RestMethod -Uri $url -Method Get

        if ($response.vulnerabilities) {
            $cve = $response.vulnerabilities[0].cve.id
        } else {
            $cve = "Ingen fundet"
        }

    } catch {
        $cve = "API fejl"
    }

    #Gem i Cache
    $cveCache[$keyword] = $cve

    return $cve
}

function Get-Vulnerability {
    param ($port)

    switch ($port) {
        21 { return Search-CVE "FTP" }
        22 { return Search-CVE "SSH" }
        80 { return Search-CVE "HTTP" }
        443 { return Search-CVE "HTTPS" }
        3389 { return Search-CVE "RDP" }
        default { return "Lav risiko" }
    }
}


#parallel scan
$jobs = @()

for ($i = 1; $i -le 254; $i++) {

    $ip = "$subnet.$i"

    $jobs += Start-Job -ScriptBlock {

        param($ip, $ports)

        function Test-Port {
            param ($ip, $port)

            try {
                $tcp = New-Object System.Net.Sockets.TcpClient
                $tcp.Connect($ip, $port)
                $tcp.Close()
                return $true
            } catch {
                return $false
            }
        }

        $results = @()

        if (Test-Connection -ComputerName $ip -Count 1 -Quiet) {

            foreach ($port in $ports) {

                $open = Test-Port $ip $port

                try {
                    $dns = [System.Net.Dns]::GetHostEntry($ip)
                    $hostname = $dns.HostName
                } catch {
                    $hostname = "Ukendt"
                }

                $results += [PSCustomObject]@{
                    IP = $ip
                    Hostname = $hostname
                    Port = $port
                    Open = $open
                }
            }
        }

        return $results

    } -ArgumentList $ip, $ports
}

# Vent på jobs
Wait-Job $jobs

# Saml resultater
foreach ($job in $jobs) {
    $report += Receive-Job $job
    Remove-Job $job
}

# tilføj CVE efter scan
foreach ($entry in $report) {

    if ($entry.Open -eq $true) {
        $entry | Add-Member -NotePropertyName Risk -NotePropertyValue (Get-Vulnerability $entry.Port)
    } else {
        $entry | Add-Member -NotePropertyName Risk -NotePropertyValue "Closed"
    }
}

# HTML REPORT
$html = $report | ConvertTo-Html `
    -Title "Network Scan Report" `
    -PreContent "<h1>Netværk Scan</h1>" `
    -PostContent "<p>Genereret: $(Get-Date)</p>"

$html | Out-File "C:\temp\network_report.html"

Write-Host "Scan færdig!"
Write-Host "Rapport: C:\temp\network_report.html"