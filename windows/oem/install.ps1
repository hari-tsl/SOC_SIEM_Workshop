$ErrorActionPreference = 'Stop'
New-Item C:\SOC -ItemType Directory -Force | Out-Null
Copy-Item C:\OEM\* C:\SOC -Recurse -Force
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File C:\SOC\bootstrap.ps1'
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 5)
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 2) -MultipleInstances IgnoreNew
Register-ScheduledTask -TaskName SOC-Bootstrap -Action $action -Trigger @($trigger, (New-ScheduledTaskTrigger -AtStartup)) -User SYSTEM -RunLevel Highest -Settings $settings -Force | Out-Null
Start-ScheduledTask SOC-Bootstrap
