# Scenario catalogue

All scenarios use hard-coded Docker names. There is no arbitrary target or wordlist parameter. Run with `./attack.sh NAME`.

| Name | Bounded activity | Expected evidence |
| --- | --- | --- |
| port-scan | TCP connect to Linux 21,22,80 | Kali scenario record; target logs may record accepted/closed connections |
| web | Six HTTP requests, including 404s and catalog SQL injection | linux.web, URI and HTTP status |
| linux-auth | Five incorrect and one correct SSH login | linux.auth; failure then success |
| linux-ftp | Three incorrect and one correct FTP login | linux.ftp native vsftpd records |
| windows-auth | Five incorrect SMB authentications, then list LabShare | 4625, 4624, share-audit events |
| windows-ssh | Five incorrect and one correct SSH login | OpenSSH/Operational; applicable Security events |
| windows-ftp | Three incorrect and one correct FTP login | windows.ftp W3C records; applicable Security events |
| demo | All scenarios in order | Correlated multi-source incident |

FTP scenarios exercise control-channel authentication only. File transfer/passive ports are not exposed through the Windows proxy. Scan traffic alone is not guaranteed to generate a security event: there is no IDS/packet sensor in V1.

Useful Kibana KQL:

```text
event.dataset: "linux.auth" and event.outcome: "failure"
event.code: "4625" and user.name: "student"
event.code: "4624" and user.name: "student"
event.dataset: "linux.web" and http.response.status_code: 404
winlog.channel: "OpenSSH/Operational"
event.dataset: "windows.ftp"
event.dataset: "kali.scenario"
```

Ask learners to correlate failure bursts with later successes, identify the account and source, and distinguish proxy addresses from direct client addresses. Expected authentication failures are checked for actual rejection text; a network timeout is a failed scenario, not a successful brute-force demonstration.
