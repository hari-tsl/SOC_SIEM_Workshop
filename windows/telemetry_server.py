#!/usr/bin/env python3
"""Telemetry server and readiness probe for SOC Windows Target (KVM-Free).
Generates authentic Windows Security Event Logs and IIS FTP W3C logs in real time.
"""
import datetime
import glob
import json
import os
import re
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

EVENTS_FILE = '/var/log/winlogbeat/windows-events.json'
FTP_LOG_FILE = '/var/log/windows-ftp/ftpsvc.log'

os.makedirs(os.path.dirname(EVENTS_FILE), exist_ok=True)
os.makedirs(os.path.dirname(FTP_LOG_FILE), exist_ok=True)

for p in (EVENTS_FILE, FTP_LOG_FILE):
    if not os.path.exists(p):
        with open(p, 'w') as f:
            pass

def now_iso():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()

def write_winlog_event(event_id, channel='Security', event_data=None, message=''):
    data = event_data or {}
    record = {
        '@timestamp': now_iso(),
        'winlog': {
            'channel': channel,
            'event_id': str(event_id),
            'event_data': data
        },
        'user': {'name': data.get('TargetUserName', 'student')},
        'host': {'name': 'SOC-WINDOWS'},
        'message': message
    }
    with open(EVENTS_FILE, 'a', encoding='utf-8') as f:
        f.write(json.dumps(record) + '\n')

def write_ftp_w3c(client_ip, user, status):
    # W3C log format matching Logstash pipeline grok parser
    # %{TIMESTAMP_ISO8601:ftp_time} %{IP:[source][ip]} (?:%{NOTSPACE:[user][name]}|-) %{IP:[destination][ip]} %{INT:[destination][port]} %{WORD:ftp_command} %{NOTSPACE:ftp_arg} %{INT:ftp_status}
    line = f"{now_iso()} {client_ip} {user} 172.30.51.30 21 PASS - {status} 0 0\n"
    with open(FTP_LOG_FILE, 'a', encoding='utf-8') as f:
        f.write(line)

# Write initial boot event (Event 100)
write_winlog_event('100', 'Application', {'TargetUserName': 'SYSTEM'}, 'SOC Windows bootstrap completed')

class ReadinessHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = json.dumps({'ready': True, 'host': 'SOC-WINDOWS'}).encode('utf-8')
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass

class ConsoleHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        html = """<!DOCTYPE html>
<html>
<head>
    <title>SOC Windows Target Console</title>
    <style>
        body { background: #0f172a; color: #f8fafc; font-family: monospace; padding: 2rem; }
        .card { background: #1e293b; border-radius: 8px; padding: 1.5rem; max-width: 800px; margin: 0 auto; border: 1px solid #334155; }
        h1 { color: #38bdf8; margin-top: 0; }
        .status { color: #4ade80; font-weight: bold; }
        .badge { display: inline-block; padding: 4px 8px; border-radius: 4px; background: #0284c7; margin: 4px; }
    </style>
</head>
<body>
    <div class="card">
        <h1>SOC-WINDOWS TARGET CONSOLE</h1>
        <p>Status: <span class="status">ONLINE (KVM-Free Native Container)</span></p>
        <p>Services Active:</p>
        <div>
            <span class="badge">SMB (445) - LabShare</span>
            <span class="badge">OpenSSH (22)</span>
            <span class="badge">IIS FTP (21)</span>
            <span class="badge">Telemetry Daemon (18080)</span>
        </div>
        <p>Windows Event Telemetry: <strong>Active & Forwarding to Logstash</strong></p>
    </div>
</body>
</html>"""
        body = html.encode('utf-8')
        self.send_response(200)
        self.send_header('Content-Type', 'text/html')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass

def run_servers():
    s18080 = ThreadingHTTPServer(('0.0.0.0', 18080), ReadinessHandler)
    threading.Thread(target=s18080.serve_forever, daemon=True).start()

    s8006 = ThreadingHTTPServer(('0.0.0.0', 8006), ConsoleHandler)
    threading.Thread(target=s8006.serve_forever, daemon=True).start()

def tail_logs():
    files = {
        'auth': ('/var/log/auth.log', 0),
        'vsftpd': ('/var/log/vsftpd.log', 0),
    }

    samba_positions = {}

    while True:
        try:
            # 1. Check auth.log for SSH events
            auth_path, auth_pos = files['auth']
            if os.path.exists(auth_path):
                with open(auth_path, 'r', encoding='utf-8', errors='ignore') as f:
                    f.seek(auth_pos)
                    lines = f.readlines()
                    files['auth'] = (auth_path, f.tell())
                for line in lines:
                    if 'Failed password for' in line:
                        m = re.search(r'Failed password for (?:invalid user )?(\S+) from (\S+)', line)
                        user = m.group(1) if m else 'student'
                        ip = m.group(2) if m else '172.30.51.10'
                        write_winlog_event('4', 'OpenSSH/Operational', {'TargetUserName': user, 'IpAddress': ip}, f'Failed authentication for {user}')
                    elif 'Accepted password for' in line:
                        m = re.search(r'Accepted password for (\S+) from (\S+)', line)
                        user = m.group(1) if m else 'student'
                        ip = m.group(2) if m else '172.30.51.10'
                        write_winlog_event('1', 'OpenSSH/Operational', {'TargetUserName': user, 'IpAddress': ip}, f'Accepted authentication for {user}')
                        write_winlog_event('4624', 'Security', {'TargetUserName': user, 'IpAddress': ip, 'LogonType': '3'}, 'An account was successfully logged on.')

            # 2. Check vsftpd.log for FTP events
            ftp_path, ftp_pos = files['vsftpd']
            if os.path.exists(ftp_path):
                with open(ftp_path, 'r', encoding='utf-8', errors='ignore') as f:
                    f.seek(ftp_pos)
                    lines = f.readlines()
                    files['vsftpd'] = (ftp_path, f.tell())
                for line in lines:
                    if 'FAIL LOGIN' in line:
                        m = re.search(r'\[(\S+)\] FAIL LOGIN: Client "(\S+)"', line)
                        user = m.group(1) if m else 'student'
                        ip = m.group(2) if m else '172.30.51.10'
                        write_ftp_w3c(ip, user, '530')
                    elif 'OK LOGIN' in line:
                        m = re.search(r'\[(\S+)\] OK LOGIN: Client "(\S+)"', line)
                        user = m.group(1) if m else 'student'
                        ip = m.group(2) if m else '172.30.51.10'
                        write_ftp_w3c(ip, user, '230')

            # 3. Check Samba logs for SMB events
            for smb_log in glob.glob('/var/log/samba/log.*'):
                pos = samba_positions.get(smb_log, 0)
                try:
                    with open(smb_log, 'r', encoding='utf-8', errors='ignore') as f:
                        f.seek(pos)
                        lines = f.readlines()
                        samba_positions[smb_log] = f.tell()
                    for line in lines:
                        if 'check_ntlm_password:  Authentication for user [student]' in line and 'FAILED' in line:
                            write_winlog_event('4625', 'Security', {
                                'TargetUserName': 'student',
                                'IpAddress': '172.30.51.10',
                                'LogonType': '3',
                                'Status': '0xc000006d',
                                'SubStatus': '0xc000006a'
                            }, 'An account failed to log on.')
                        elif ('authentication for user [student] succeeded' in line) or ('check_ntlm_password:  Authentication for user [student]' in line and 'OK' in line):
                            write_winlog_event('4624', 'Security', {
                                'TargetUserName': 'student',
                                'IpAddress': '172.30.51.10',
                                'LogonType': '3'
                            }, 'An account was successfully logged on.')
                            write_winlog_event('5140', 'Security', {
                                'TargetUserName': 'student',
                                'IpAddress': '172.30.51.10',
                                'ShareName': r'\\*\LabShare'
                            }, 'A network share object was accessed.')
                except Exception:
                    pass

        except Exception as e:
            pass

        time.sleep(0.5)

if __name__ == '__main__':
    run_servers()
    tail_logs()
