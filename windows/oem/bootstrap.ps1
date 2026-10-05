$ErrorActionPreference = 'Stop'
Start-Transcript -Path C:\SOC\bootstrap.log -Append
try {
    $cfg = Get-Content C:\SOC\settings.json -Raw | ConvertFrom-Json
    $pw = ConvertTo-SecureString $cfg.lab_password -AsPlainText -Force
    if (Get-LocalUser -Name student -ErrorAction SilentlyContinue) {
        Set-LocalUser -Name student -Password $pw -PasswordNeverExpires $true
    } else {
        New-LocalUser -Name student -Password $pw -PasswordNeverExpires | Out-Null
    }
    $users = Get-LocalGroup -SID 'S-1-5-32-545'
    $student = Get-LocalUser student
    if (-not (Get-LocalGroupMember $users | Where-Object { $_.SID -eq $student.SID })) {
        Add-LocalGroupMember -Group $users -Member $student
    }
    # Locale-independent audit subcategory GUIDs: logon, credential validation,
    # process creation, file share, detailed file share.
    foreach ($guid in @('{0CCE9215-69AE-11D9-BED3-505054503030}', '{0CCE923F-69AE-11D9-BED3-505054503030}', '{0CCE922B-69AE-11D9-BED3-505054503030}', '{0CCE9224-69AE-11D9-BED3-505054503030}', '{0CCE9244-69AE-11D9-BED3-505054503030}')) {
        & auditpol /set /subcategory:$guid /success:enable /failure:enable
        if ($LASTEXITCODE -ne 0) { throw "auditpol failed for $guid" }
    }
    $audit = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System\Audit'
    New-Item $audit -Force | Out-Null
    New-ItemProperty $audit ProcessCreationIncludeCmdLine_Enabled -Value 1 -PropertyType DWord -Force | Out-Null
    $ps = 'HKLM:\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging'
    New-Item $ps -Force | Out-Null
    New-ItemProperty $ps EnableScriptBlockLogging -Value 1 -PropertyType DWord -Force | Out-Null
    # Bounded repeated failures should not lock the disposable training account.
    & net accounts /lockoutthreshold:0
    if ($LASTEXITCODE -ne 0) { throw 'Could not set lab lockout policy' }
    New-Item C:\LabShare -ItemType Directory -Force | Out-Null
    Set-Content C:\LabShare\training.txt 'Synthetic training document. No production data.'
    & icacls C:\LabShare /grant 'student:(OI)(CI)RX'
    if ($LASTEXITCODE -ne 0) { throw 'Share ACL failed' }
    if (-not (Get-SmbShare -Name LabShare -ErrorAction SilentlyContinue)) {
        New-SmbShare -Name LabShare -Path C:\LabShare -ReadAccess student | Out-Null
    }
    Set-Service LanmanServer -StartupType Automatic
    Start-Service LanmanServer
    $cap = Get-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    if ($cap.State -ne 'Installed') {
        $result = Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
        if ($result.RestartNeeded) { Restart-Computer -Force; exit }
    }
    Set-Service sshd -StartupType Automatic
    Start-Service sshd
    & wevtutil sl OpenSSH/Operational /e:true
    $features = Install-WindowsFeature Web-FTP-Server,Web-Scripting-Tools -IncludeManagementTools
    if (-not $features.Success) { throw 'FTP feature installation failed' }
    if ($features.RestartNeeded -eq 'Yes') { Restart-Computer -Force; exit }
    Import-Module WebAdministration
    if (-not (Test-Path 'IIS:\Sites\SOC-FTP')) {
        New-WebFtpSite -Name SOC-FTP -Port 21 -PhysicalPath C:\LabShare -Force | Out-Null
    }
    Set-ItemProperty 'IIS:\Sites\SOC-FTP' -Name ftpServer.security.authentication.anonymousAuthentication.enabled -Value $false
    Set-ItemProperty 'IIS:\Sites\SOC-FTP' -Name ftpServer.security.authentication.basicAuthentication.enabled -Value $true
    Set-ItemProperty 'IIS:\Sites\SOC-FTP' -Name ftpServer.security.ssl.controlChannelPolicy -Value 0
    Set-ItemProperty 'IIS:\Sites\SOC-FTP' -Name ftpServer.security.ssl.dataChannelPolicy -Value 0
    Set-ItemProperty 'IIS:\Sites\SOC-FTP' -Name ftpServer.logFile.enabled -Value $true
    Set-ItemProperty 'IIS:\Sites\SOC-FTP' -Name ftpServer.logFile.directory -Value 'C:\inetpub\logs\LogFiles'
    Clear-WebConfiguration -PSPath 'IIS:\' -Location SOC-FTP -Filter 'system.ftpServer/security/authorization'
    Add-WebConfiguration -PSPath 'IIS:\' -Location SOC-FTP -Filter 'system.ftpServer/security/authorization' -Value @{accessType='Allow';users='student';permissions='Read'}
    Set-Service FTPSVC -StartupType Automatic
    Start-Service FTPSVC
    Start-WebSite SOC-FTP
    # FTP scenarios only authenticate; passive data ports are deliberately not proxied.
    foreach ($port in @(21,22,445,18080)) {
        $name = "SOC-Lab-$port"
        if (-not (Get-NetFirewallRule -Name $name -ErrorAction SilentlyContinue)) {
            New-NetFirewallRule -Name $name -DisplayName $name -Direction Inbound -Action Allow -Protocol TCP -LocalPort $port | Out-Null
        }
    }
    & C:\SOC\install-winlogbeat.ps1
    # Generate a genuine Application event as provisioning evidence.
    if (-not [System.Diagnostics.EventLog]::SourceExists('SOC-Lab')) {
        New-EventLog -LogName Application -Source SOC-Lab
    }
    Write-EventLog -LogName Application -Source SOC-Lab -EventId 100 -EntryType Information -Message 'SOC Windows bootstrap completed'
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File C:\SOC\readiness.ps1'
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 10 -RestartInterval (New-TimeSpan -Minutes 1)
    Register-ScheduledTask SOC-Readiness -Action $action -Trigger $trigger -User SYSTEM -RunLevel Highest -Settings $settings -Force | Out-Null
    Set-Content C:\SOC\ready.txt (Get-Date).ToUniversalTime().ToString('o')
    Start-ScheduledTask SOC-Readiness
    Disable-ScheduledTask SOC-Bootstrap | Out-Null
} catch {
    $_ | Out-String | Write-Output
    Remove-Item C:\SOC\ready.txt -ErrorAction SilentlyContinue
    exit 1
} finally { Stop-Transcript }
