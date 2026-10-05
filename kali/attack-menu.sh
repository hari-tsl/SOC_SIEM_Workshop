#!/bin/bash
set -euo pipefail

SCENARIO="${1:-}"

if [ -z "$SCENARIO" ]; then
    echo "=================================================="
    echo "         SOC SIEM LAB - ATTACK LAUNCHER           "
    echo "=================================================="
    echo "Usage: attack <scenario-name>"
    echo ""
    echo "Available Scenarios:"
    echo "  demo              - Run all scenarios end-to-end"
    echo "  port-scan         - Nmap TCP reconnaissance"
    echo "  web               - DVWA web path enumeration"
    echo "  dvwa-bruteforce   - DVWA login brute force attack"
    echo "  dvwa-sqli         - DVWA SQL injection exploitation"
    echo "  linux-auth        - Linux SSH brute force & login"
    echo "  linux-ftp         - Linux FTP brute force & login"
    echo "  windows-auth      - Windows SMB brute force & login (4625/4624)"
    echo "  windows-ssh       - Windows OpenSSH brute force & login"
    echo "  windows-ftp       - Windows IIS FTP brute force & login"
    echo "=================================================="
    exit 1
fi

python3 /opt/scenarios.py "$SCENARIO"
