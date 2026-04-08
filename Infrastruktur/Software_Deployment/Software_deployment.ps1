add-type -AssemblyName system.windows.Forms
add-type -AssemblyName system.Drawing 

#konfiguration
$computers = @("client1", "client2")
$logfile = "C:\temp\deploy_log.txt"
$reportfile = "C:\temp\deploy_report.csv"
$temppath = "C:\temp\software"

New-Item -ItemType Directory -Path $temppath -Force | Out-Null

#Softwaredownload og dependencies 
$softwareList = @{
    "Chrome" = @{
        Url = "https://dl.google.com/chrome/install/googlechromestandaloneenterprise64.msi"
        File = "$tempPath\chrome.msi"
        DependsOn = @()
    }
    "7zip" = @{
        Url = "https://www.7-zip.org/a/7z1900-x64.msi"
        File = "$tempPath\7zip.msi"
        DependsOn = @()
    }
    "Notepad++" = @{
        Url = "https://github.com/notepad-plus-plus/notepad-plus-plus/releases/download/v8.5.8/npp.8.5.8.Installer.x64.msi"
        File = "$tempPath\npp.msi"
        DependsOn = @("7zip")
    }
}


#funktioner 
function Test-SoftwareInstalled {
    param $name

    $path = = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    foreach ($path in $paths) {
        $apps = Get-ItemProperty $path -ErrorAction SilentlyContinue | Where-Object {
            $_.DisplayName -like "*$name*"
        }
        if ($apps) {return $true}
    }
    return $false  
}

function Download_Software {
    param ($url, $file)

    if (!(Test-Path $file)) {
        Write-Host "downloader $fil..."
        Invoke-WebRequest -uri $url -OutFile $file
    }
}

function install-SoftwareRemote {
    param ($computer, $softwareName, $file)

    Invoke-Command -ComputerName $computer -ScriptBlock {
        param ($softwareName, $file)

        function Test-SoftwareInstalled {
            param ($name)

            $paths = @(
                "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
            )
           foreach ($path in $paths) {
            $apps = Get-ItemProperty $path -ErrorAction SilentlyContinue | Where-Object {
                $_.DisplayName -like "*$name*"
            }
            if ($apps) {return $true}
           } 
           return $false
        }
        if (Test-SoftwareInstalled $softwareName) {
            return "already installed"
        } -argumentlist $softwareName, $file
    }
}

#GUI
$form = New-Object System.Windows.Form
$form.Text = "Software Deployment Tool"
$form.Size = New-Object System.Drawing.Size(400,400)

$CheckedlistBox = New-Object System.Windows.Forms.CheckedListBox
$checkedListBox.Size = New-Object System.Drawing.Size(200,200)
$checkedListBox.Location = New-Object System.Drawing.Point(20,20)

foreach ($app in $softwareList.Keys) {
    $checkedListBox.Items.Add($app)
}

$form.Controls.Add($checkedListBox)

$button = New-Object System.Windows.Forms.Button
$button.Text = "Deploy"
$button.Location = New-Object System.Drawing.Point(20,250)

$form.Controls.Add($button)

#tryk på knap 
$button.Add_Click({

    $selected = $checkedListBox.CheckedItems

    $report = @()

    foreach ($software in $selected) {

        # Dependencies først
        $deps = $softwareList[$software].DependsOn
        foreach ($dep in $deps) {
            Download-Software $softwareList[$dep].Url $softwareList[$dep].File
        }

        # Download
        Download-Software $softwareList[$software].Url $softwareList[$software].File

        foreach ($computer in $computers) {

            try {
                $result = Install-SoftwareRemote $computer $software $softwareList[$software].File

                Add-Content $logFile "$(Get-Date) | $computer | $software | $result"

                $report += [PSCustomObject]@{
                    Computer = $computer
                    Software = $software
                    Status   = $result
                    Time     = Get-Date
                }

            } catch {
                Add-Content $logFile "$(Get-Date) | $computer | $software | FEJL $_"
            }
        }
    }

    $report | Export-Csv -Path $reportFile -NoTypeInformation

    [System.Windows.Forms.MessageBox]::Show("Deployment færdig!")
})

$form.ShowDialog()