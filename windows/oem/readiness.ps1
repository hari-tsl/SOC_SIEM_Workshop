$ErrorActionPreference = 'Stop'
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add('http://+:18080/')
$listener.Start()
try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $ready = Test-Path C:\SOC\ready.txt
        foreach ($svc in @('filebeat','winlogbeat','sshd','FTPSVC','LanmanServer')) {
            if ((Get-Service $svc -ErrorAction SilentlyContinue).Status -ne 'Running') { $ready = $false }
        }
        $context.Response.StatusCode = $(if ($ready) {200} else {503})
        $bytes = [Text.Encoding]::UTF8.GetBytes('{"ready":' + $ready.ToString().ToLower() + '}')
        $context.Response.ContentType = 'application/json'
        $context.Response.ContentLength64 = $bytes.Length
        $context.Response.OutputStream.Write($bytes,0,$bytes.Length)
        $context.Response.Close()
    }
} finally { $listener.Stop() }
