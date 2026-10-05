# Troubleshooting

## No KVM / incompatible host

Check `ls -l /dev/kvm /dev/net/tun` and host virtualization support. Docker Desktop on the M2 Mac is not a supported full-lab host. A cloud VM must expose working nested virtualization or be an appropriate bare-metal host. A separate Windows instance is a possible architecture change, but it is not an automatic fallback in this repository.

## Windows takes a long time or OEM provisioning fails

Open http://127.0.0.1:8006 through the SSH tunnel. Container logs:

```bash
docker compose logs --tail=150 windows
```

Inside Windows, inspect `C:\OEM\install.log` and `C:\SOC\bootstrap.log`. Check Task Scheduler entries `SOC-Bootstrap` and `SOC-Readiness`. The bootstrap task retries at five-minute intervals and at boot until successful. Optional Windows features need access to Microsoft download/update endpoints. Beats downloads need artifacts.elastic.co.

If Windows is installed but the OEM script never ran, run `C:\OEM\install.bat` as administrator. If the OEM source changed since initial installation, the `/oem` mount is **not** live-synced into an existing guest. Run `python3 scripts/configure.py` on the host, securely copy the newly generated `.runtime/oem` files to `C:\OEM` using an administrative session, then rerun install.bat. For a disposable lab, `reset.sh --destroy-all` is the simpler destructive reinstall route.

## Windows services work but no logs arrive

Inside Windows:

```powershell
Test-NetConnection 172.30.51.10 -Port 5044
Get-Service winlogbeat,filebeat,sshd,FTPSVC,LanmanServer
Get-Content C:\SOC\bootstrap.log -Tail 80
```

Check Beats logs under `C:\Program Files\Winlogbeat-Data\logs` and `C:\Program Files\Filebeat-Data\logs`. Check `auditpol /get /category:*`. Verify Windows time is correct. Windows services are checked before scenarios run; the final ingestion check is separate.

## ELK is unhealthy / acceptance misses sources

```bash
docker compose logs --tail=100 elasticsearch logstash kibana filebeat kali-filebeat
docker compose exec linux-victim tail -n 20 /var/log/auth.log
./attack.sh demo
./scripts/acceptance.sh
```

Low memory can kill Elasticsearch or Windows. `vm.max_map_count` is checked at startup. IIS FTP logs may flush with a delay; the acceptance gate waits up to five minutes after scenarios. Filestream must see data before it creates a source; run scenarios rather than checking an idle source.

If index mappings were created manually before bootstrap, the template cannot repair incompatible existing fields. Export required evidence first, then use the documented full reset or an administrator-controlled index migration. Do not delete indices blindly.

## Network conflict

Check whether `172.30.51.0/24` conflicts with your VPC, VPN or Docker networks. If it does, change all documented static references before creating Windows. Windows logs show proxy/NAT source addresses by design. Kali's lack of Internet access is intentional.

## Restart and cleanup

`stop.sh` retains containers and volumes; `start.sh` resumes them. Restart policies bring services back when Docker restarts. The readiness scheduled task restarts with Windows. Docker must itself start at host boot. Reset deletes all project volumes including the Windows installation and needs an explicit confirmation. It leaves `.env`, built images and the host sysctl file in place.
