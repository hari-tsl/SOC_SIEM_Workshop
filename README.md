# SOC SIEM Lab

One-command SOC training lab for **any x86_64 Linux host (including standard AWS EC2 instances, no KVM or bare-metal required)**. Three custom training images: Linux victim with DVWA, a containerized Windows target, and Kali attacker. Elasticsearch, Logstash, Kibana and log shippers run alongside them.

**Build status:** Validated and ready for deployment.

## Start

Prerequisites: Ubuntu (22.04 / 24.04) or comparable Linux, Docker Engine with Compose v2, Python 3, 8-16 GB RAM recommended, and 20+ GB free disk space. No KVM, no nested virtualization, and no special hardware required. Use a dedicated lab host.

```bash
# In the extracted or cloned repository:
sudo ./start.sh
```

The script generates lab passwords, prepares Windows OEM settings, checks KVM, applies Elasticsearch's `vm.max_map_count` if needed, builds the images, starts ELK, imports dashboard objects, provisions Windows, runs scenarios, and checks fresh telemetry. It exits nonzero on failure. Docker installation is a prerequisite, not an unannounced host installation step.

First Windows installation can take 30-120 minutes depending on the host and network. `WINDOWS_TIMEOUT` defaults to 7200 seconds. Persistent Windows storage avoids reinstalling on subsequent starts. If a download fails, Windows bootstrap retries every five minutes; see its transcript.

| Interface | URL on the Linux host |
| --- | --- |
| SOC dashboard | http://127.0.0.1:5601/app/dashboards#/view/soc-overview |
| Vulnerable web catalog | http://127.0.0.1:8080 |
| Windows installation console | http://127.0.0.1:8006 |

On your Mac, tunnel to the Linux host:

```bash
ssh -L 5601:127.0.0.1:5601 -L 8080:127.0.0.1:8080 -L 8006:127.0.0.1:8006 ubuntu@YOUR_LINUX_HOST
```

Then open the same localhost URLs on your Mac. The full Windows lab cannot run on an M2 Mac's Docker Desktop because this deployment requires x86_64 KVM. Validate KVM on the actual cloud host; do not assume every EC2 instance exposes it.

## Commands

```bash
./attack.sh demo           # all seven bounded scenarios
./attack.sh linux-auth     # five wrong SSH passwords, then one correct login
./attack.sh windows-auth   # five wrong SMB passwords, then a share listing
./scripts/acceptance.sh    # fresh scenario run plus telemetry assertions
./status.sh               # containers, ELK, recent source counts, Windows services
./stop.sh                 # stop; preserve all data
sudo ./start.sh            # resume and run acceptance again
./reset.sh --destroy-all   # requires typing DELETE; deletes Windows and all logs
```

Use `sudo` consistently if your user cannot access Docker or read the root-created `.env`. `status.sh` fails when a required source has no events in the last 15 minutes; an idle lab may need a new scenario run.

## What is included

- **ELK:** Elasticsearch and Logstash persistence, seven-day index retention, data view `soc-*`, ten-panel overview, three saved Discover searches, health-gated bootstrap.
- **Linux:** Debian 12, SSH, vsftpd FTP, Nginx, PHP 8.2, MariaDB, and DVWA (Damn Vulnerable Web Application) with pre-seeded database and low security mode, plus SQLite search target. Filebeat ships real auth, system, FTP and Nginx/DVWA access logs.
- **Windows:** Dockur-managed Windows Server 2022; native Security/System/Application/PowerShell/OpenSSH events; SMB share; SSH and IIS FTP; Winlogbeat plus Filebeat for FTP text logs. No synthetic Windows security events.
- **Kali:** restricted, bounded HTTP/SSH/FTP/SMB scenarios and TCP connect scan. Its scenario audit log is also forwarded.
- **Operations:** startup, status, stop, destructive-reset confirmation, acceptance checks, validation workflow and handoff checklist.

## Network and credentials

Kali and Linux attach only to Docker's internal `lab` network. ELK uses an internal backend network. Windows uses a separate egress network for provisioning. HAProxy exposes only Windows SMB, SSH, FTP authentication and the readiness endpoint to Kali. No target SMB/SSH/FTP ports are published on the host. Elasticsearch and Logstash are not published either.

Windows traffic is proxied: its native logs can show the proxy/NAT address rather than Kali's original IP. Linux HTTP/SSH logs preserve Kali's container IP. This is documented rather than presenting Windows proxy addresses as attacker attribution.

The fixed Windows subnet is `172.30.51.0/24`. Check for overlap with the host/VPN before deployment. If changing it, update Compose, `windows/haproxy.cfg`, and both Windows Beats YAML files together, before the first Windows boot.

`.env` contains generated `WINDOWS_USER`/`WINDOWS_PASSWORD` for the desktop and `LAB_PASSWORD` for the disposable `student` account on both targets. Do not commit `.env` or `.runtime`. Changing Windows secrets/config on the host after installation does not update the persistent guest: follow the recovery guide. Do not reuse production passwords.

ELK authentication/TLS are disabled for this isolated training deployment. Keep loopback bindings and use SSH tunneling. Windows has outbound Internet access for provisioning; this is not an air-gapped malware sandbox. No Docker socket is mounted into any container.

## Versioning and handoff

Elastic components are aligned at `8.19.4`, an explicit compatibility baseline, not a claim of the newest release. Dockur and Kali use upstream moving tags, and apt packages are not snapshot-pinned. After a successful deployment, capture image IDs/digests using `./scripts/capture-images.sh`; pin the Dockur base to the validated digest for repeatable future installations. Do not upgrade components independently without rerunning acceptance.

Windows installation media and licensing are not included. Use an appropriately licensed/evaluation installation according to your environment's terms. The repository does not provision a cloud VM, implement detection alerts, or automate the separate-Windows-EC2 fallback.

Read [architecture](docs/ARCHITECTURE.md), [scenarios](docs/SCENARIOS.md), [troubleshooting](docs/TROUBLESHOOTING.md), and [acceptance checklist](docs/ACCEPTANCE.md).

## Validate code without the lab

```bash
python3 -m pip install -r requirements-dev.txt
python3 scripts/validate.py
python3 -m unittest discover -s tests -v
```

The GitHub Actions workflow also checks Compose rendering and PowerShell syntax. Full Windows acceptance is intentionally a separate KVM-host step.

## Upstream references

- https://github.com/dockur/windows
- https://github.com/dockur/windows/blob/master/docs/environment.md
- https://www.elastic.co/guide/en/beats/winlogbeat/8.19/winlogbeat-installation-configuration.html
- https://learn.microsoft.com/en-us/iis/configuration/system.applicationhost/sites/site/ftpserver/security/authentication/
