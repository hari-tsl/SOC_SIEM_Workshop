# SOC SIEM Lab — Quick Start Guide

A one-command cybersecurity training lab running a native **ELK Stack (Elasticsearch, Logstash, Kibana)** on an Ubuntu host with **3 containerized targets/attackers in Docker** (no KVM or nested virtualization required).

---

## 1. Architecture Overview

```
                      +---------------------------------------+
                      |         Ubuntu Host (EC2 / VM)        |
                      |                                       |
                      |  * Elasticsearch (Port 9200)          |
                      |  * Logstash      (Port 5044)          |
                      |  * Kibana        (Port 5601)          |
                      +-------------------+-------------------+
                                          ^
                     Beats Telemetry (5044)| (Filebeat shippers)
                                          |
        +---------------------------------+---------------------------------+
        |                                 |                                 |
+-------v---------+             +---------v-------+             +-----------v-----+
|   kali          |  Attacks    |  linux-victim   |             |  windows        |
|  (Attacker)     | ----------> |  (Port 8080)    |             |  (Port 8006)    |
|                 |             |                 |             |                 |
| * Nmap          |             | * DVWA Web App  |             | * SMB LabShare  |
| * Hydra         |             | * SSH Server    |             | * OpenSSH       |
| * smbclient     |             | * vsftpd FTP    |             | * IIS FTP       |
| * Attack runner |             | * MariaDB + PHP |             | * EventLog Mock |
+-----------------+             +-----------------+             +-----------------+
```

---

## 2. Host Requirements & Cloud Security Groups

- **OS:** Ubuntu 22.04 LTS or 24.04 LTS (x86_64)
- **Instance Size:** AWS EC2 `t3.large` (8 GB RAM) or `t3.xlarge` (16 GB RAM recommended)
- **Disk:** 25+ GB free storage
- **Firewall / Security Group Inbound Ports:**
  - `22/tcp` — SSH access to EC2
  - `5601/tcp` — Kibana SIEM Dashboard
  - `8080/tcp` — DVWA Vulnerable Web App
  - `8006/tcp` — Windows Target Web Console

---

## 3. Installation & Startup (One Command)

Log in to your Ubuntu machine and run:

```bash
# 1. Clone the repository
git clone https://github.com/hari-tsl/SOC_SIEM_Workshop.git
cd SOC_SIEM_Workshop

# 2. Launch the lab
./start.sh
```

### What `./start.sh` does automatically:
1. Installs and configures native Elasticsearch 8.x, Logstash, and Kibana on the host.
2. Imports the pre-built **SOC Overview Dashboard** and `soc-*` data views into Kibana.
3. Builds and boots the 3 Docker target machines (`linux-victim`, `windows`, `kali`).
4. Gates startup until all target services report ready (Windows HTTP mock and DVWA HTTP 200).
5. Runs an initial acceptance check (`./attack.sh demo`) and verifies end-to-end telemetry ingestion.

---

## 4. Accessing Lab Interfaces

| Service | Access URL | Default Credentials | Description |
| :--- | :--- | :--- | :--- |
| **Kibana SIEM** | `http://<HOST-IP>:5601` | *No auth (lab mode)* | Pre-built SOC Overview Dashboard & Discover search |
| **DVWA Web Target** | `http://<HOST-IP>:8080` | `admin` / `password` | Damn Vulnerable Web Application (PHP + MariaDB) |
| **Windows Web Console** | `http://<HOST-IP>:8006` | *No auth (web view)* | Status monitor for SMB, OpenSSH, IIS FTP |

*(If using an SSH tunnel from your local laptop instead of public IPs):*
```bash
ssh -L 5601:127.0.0.1:5601 -L 8080:127.0.0.1:8080 -L 8006:127.0.0.1:8006 ubuntu@<EC2-IP>
```

---

## 5. Accessing Docker Containers Directly

To enter the command line of any of the machines:

```bash
# 1. Attacker Box (Kali Linux)
sudo docker compose exec -it kali bash

# 2. Windows Target (Terminal)
sudo docker compose exec -it windows bash

# 3. Linux DVWA Victim (Terminal)
sudo docker compose exec -it linux-victim bash
```

---

## 6. Running Attack Simulations

All attacks run **strictly once and terminate** (no infinite background loops).

### Run All 9 Scenarios (End-to-End Demo):
```bash
./attack.sh demo
```

### Run Individual Scenarios:
| Command | Attack Description | Generated Telemetry |
| :--- | :--- | :--- |
| `./attack.sh port-scan` | Nmap TCP SYN/Connect scan on ports 21, 22, 80 | Network port activity |
| `./attack.sh web` | Path enumeration (`/admin`, `/.env`, etc.) | Nginx access logs (`linux.web`) |
| `./attack.sh dvwa-bruteforce` | Password brute force against DVWA login | HTTP 200/302 bursts on `login.php` |
| `./attack.sh dvwa-sqli` | SQL injection queries against `/search` | Malicious SQL syntax in web logs |
| `./attack.sh linux-auth` | 5 failed SSH logins followed by 1 successful login | `Failed password` & `Accepted password` (`linux.auth`) |
| `./attack.sh linux-ftp` | 3 failed FTP logins followed by 1 successful login | `FAIL LOGIN` & `OK LOGIN` (`linux.ftp`) |
| `./attack.sh windows-auth` | 5 failed SMB logons followed by share enumeration | Event ID **4625** (Failure) & **4624** (Success) |
| `./attack.sh windows-ssh` | 5 failed SSH logins followed by 1 successful login | OpenSSH Operational events |
| `./attack.sh windows-ftp` | 3 failed FTP logins followed by 1 successful login | IIS FTP 530 / 230 status codes (`windows.ftp`) |

---

## 7. Investigating in Kibana

1. Open `http://<HOST-IP>:5601` in your browser.
2. Go to **Analytics > Discover**:
   - Change data view to `soc-*`.
   - Filter by dataset: `event.dataset : "linux.auth"`, `event.dataset : "windows.eventlog"`, etc.
3. Go to **Analytics > Dashboards > SOC Overview**:
   - Inspect the **Authentication Failures vs Successes** charts.
   - Inspect **Windows Logon Activity (Event 4625/4624)**.
   - Inspect **DVWA Web Traffic & Suspicious URIs**.

---

## 8. Management Commands

| Action | Command | Note |
| :--- | :--- | :--- |
| **Check Status** | `./status.sh` | Checks ELK health, container state, and recent event counts |
| **Stop Lab** | `./stop.sh` | Halts Docker containers; preserves database and Elasticsearch logs |
| **Restart Lab** | `./start.sh` | Restarts services and runs acceptance verification |
| **Full Reset** | `./reset.sh --destroy-all` | Requires typing `DELETE`; wipes all logs and volumes |
