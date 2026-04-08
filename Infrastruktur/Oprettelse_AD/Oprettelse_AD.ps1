Import-Module ActiveDirectory

# CSV sti
$csvPath = "C:\temp\users.csv"

# Log fil
$logFile = "C:\temp\user_log.txt"

# Password generator
function Generate_StrongPassword {
    $lower = "abcdefghijklmnopqrstuvwxyz"
    $upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $numbers = "0123456789"
    $special = "!@#$%^&*"

    $password = @()
    $password += $lower | Get-Random
    $password += $upper | Get-Random
    $password += $numbers | Get-Random
    $password += $special | Get-Random

    $all = $lower + $upper + $numbers + $special

    $password += (1..(12 - $password.Count) | ForEach-Object {
        $all | Get-Random
    })

    $password = $password | Get-Random -Count $password.Count

    return -join $password
}

# Import brugere
$users = Import-Csv -Path $csvPath

foreach ($user in $users) {

    try {
        $firstname = $user.FirstName
        $lastname = $user.LastName
        $department = $user.Department

        # Username
        $username = $firstname.Substring(0,1) + $lastname.Substring(0,2)
        $username = $username.ToLower()

        $counter = 1
        while (Get-ADUser -Filter "SamAccountName -eq '$username'") {
            $username = ($firstname.Substring(0,1) + $lastname.Substring(0,2) + $counter).ToLower()
            $counter++
        }

        # Password
        $PasswordPlain = Generate_StrongPassword
        $PasswordSecure = ConvertTo-SecureString $PasswordPlain -AsPlainText -Force

        $fullname = "$firstname $lastname"

        # OU baseret på afdeling
        switch ($department) {
            "IT" { 
                $OU = "OU=IT,DC=domain,DC=local"
                $groups = @("IT-Users", "VPN-Access")
            }
            "HR" { 
                $OU = "OU=HR,DC=domain,DC=local"
                $groups = @("HR-Users")
            }
            "Finance" { 
                $OU = "OU=Finance,DC=domain,DC=local"
                $groups = @("Finance-Users")
            }
            "Administration" { 
                $OU = "OU=Administration,DC=domain,DC=local"
                $groups = @("Administration-Users")
            }
            default {
                Write-Host "Ukendt afdeling: $department"
                continue
            }
        }

        # Opret bruger
        New-ADUser `
            -Name $fullname `
            -GivenName $firstname `
            -Surname $lastname `
            -SamAccountName $username `
            -UserPrincipalName "$username@domain.local" `
            -AccountPassword $PasswordSecure `
            -Enabled $true `
            -Path $OU `
            -ChangePasswordAtLogon $true

        # Tilføj til grupper
        foreach ($group in $groups) {
            Add-ADGroupMember -Identity $group -Members $username
        }

        # Log succes
        $log = "$(Get-Date) - Oprettet: $username | Password: $PasswordPlain | Afdeling: $department"
        Add-Content -Path $logFile -Value $log

        Write-Host "SUCCESS: $username"

    } catch {
        # Log fejl
        $errorLog = "$(Get-Date) - FEJL med bruger $($user.FirstName) $($user.LastName): $_"
        Add-Content -Path $logFile -Value $errorLog

        Write-Host "FEJL med $firstname $lastname"
    }
}