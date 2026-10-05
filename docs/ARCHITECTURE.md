# Architecture

| Component | Networks | Purpose |
| --- | --- | --- |
| Elasticsearch, Kibana, setup | backend (internal) | Store, visualize and bootstrap |
| Logstash | backend, lab, windows-net | Receive Beats on 5044; publish no host port |
| Linux, Kali, their Filebeat sidecars | lab (internal) | Targets, bounded activity, forwarding |
| Windows | windows-net | QEMU/KVM, NAT guest and provisioning egress |
| windows-target | lab, windows-net | Fixed TCP proxy to Windows |

Logstash has an IP on each network but is not a network router. Kali does not attach to the Windows egress network. HAProxy forwards only TCP 21, 22, 445 and 18080; it is not an arbitrary destination proxy. Windows guest networking is managed by Dockur NAT. Windows shippers use Logstash's static `172.30.51.10` address, avoiding guest dependence on Docker DNS.

Each source uses genuine local logs. `kali.scenario` is activity metadata emitted by our runner, not a replacement for target evidence. Security event 4625 represents failed logon, 4624 success, and 4688 process creation when those Windows audit categories apply. FTP is additionally collected from IIS W3C files; SSH from OpenSSH/Operational.

The custom vulnerable catalog uses a fresh in-memory SQLite database for every query. The deliberate injection allows changing a SELECT over invented products. It is not a production application or a full VAPT training platform.

Windows OEM scripts register a retryable SYSTEM task. A successful bootstrap installs/configures services, writes a marker, starts a boot-persistent service-check HTTP listener, and disables the retry task. The host then runs real scenarios and verifies fresh ingested events. The private readiness endpoint is TCP 18080; it does not execute commands.

Daily Elasticsearch indices expire after seven days. Named volumes preserve Elasticsearch data, Logstash queue, Beats offsets, target logs and the Windows virtual disk. Linux logs rotate daily; Kali audit logs rotate by size. Windows event channels and Beats logs have their native retention limits. Monitor Windows IIS logs and disk usage for longer-running labs.
