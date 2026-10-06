"""Bounded scenario runner for SOC SIEM Lab.
Covers DVWA web attacks, Linux victim attacks, and Windows guest attacks.
"""
import datetime
import ftplib
import json
import logging
from logging.handlers import RotatingFileHandler
import os
import subprocess
import sys
import time
import urllib.parse
import urllib.request

PASSWORD = os.environ.get('LAB_PASSWORD', '')
SSH = [
    'sshpass', '-e', 'ssh',
    '-o', 'StrictHostKeyChecking=no',
    '-o', 'UserKnownHostsFile=/dev/null',
    '-o', 'ConnectTimeout=5',
    '-o', 'NumberOfPasswordPrompts=1',
    '-o', 'PreferredAuthentications=password'
]

log = logging.getLogger('scenarios')
log.setLevel(logging.INFO)
os.makedirs('/logs', exist_ok=True)
h = RotatingFileHandler('/logs/scenarios.json', maxBytes=5_000_000, backupCount=2)
log.addHandler(h)

def record(action, outcome):
    log.info(json.dumps({
        '@timestamp': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'event': {'dataset': 'kali.scenario', 'action': action, 'outcome': outcome},
        'host': {'name': 'kali'}
    }))

def command(args, password=None, expect_failure=False):
    env = os.environ.copy()
    if password is not None:
        env['SSHPASS'] = password
    result = subprocess.run(args, env=env, capture_output=True, timeout=40)
    output = (result.stdout + result.stderr).decode(errors='replace')
    if expect_failure:
        if not result.returncode or not any(s in output for s in (
            'Permission denied', 'NT_STATUS_LOGON_FAILURE', 'NT_STATUS_WRONG_PASSWORD', 'Login failed'
        )):
            raise RuntimeError('Expected authentication rejection, received: ' + output[-500:])
    elif result.returncode:
        raise RuntimeError(output[-500:])

def auth(host):
    for _ in range(5):
        command(SSH + ['student@' + host, 'whoami'], 'IntentionallyWrong123!', True)
        time.sleep(1)
    command(SSH + ['student@' + host, 'whoami'], PASSWORD)

def ftp(host):
    for _ in range(3):
        with ftplib.FTP() as c:
            c.connect(host, 21, timeout=10)
            try:
                c.login('student', 'IntentionallyWrong123!')
            except ftplib.error_perm as e:
                if not str(e).startswith('530'):
                    raise
            else:
                raise RuntimeError('Wrong FTP password was accepted')
    with ftplib.FTP() as c:
        c.connect(host, 21, timeout=10)
        c.login('student', PASSWORD)
        c.quit()

def web():
    targets = [
        '/',
        '/dvwa/',
        '/dvwa/login.php',
        '/admin',
        '/.env',
        '/robots.txt',
        '/health',
        '/search?q=router',
        '/search?q=' + urllib.parse.quote("' OR 1=1 -- ")
    ]
    for path in targets:
        for attempt in range(10):
            try:
                with urllib.request.urlopen('http://linux-victim' + path, timeout=10) as r:
                    r.read()
                break
            except urllib.error.HTTPError as e:
                if e.code != 404:
                    raise
                break
            except (urllib.error.URLError, ConnectionRefusedError, OSError):
                if attempt == 9:
                    raise
                time.sleep(1)

def dvwa_bruteforce():
    url = 'http://linux-victim/dvwa/login.php'
    passwords = ['123456', 'password123', 'admin123', 'qwerty', 'password']
    for pwd in passwords:
        data = urllib.parse.urlencode({
            'username': 'admin',
            'password': pwd,
            'Login': 'Login'
        }).encode('utf-8')
        req = urllib.request.Request(url, data=data, method='POST')
        for attempt in range(5):
            try:
                with urllib.request.urlopen(req, timeout=10) as resp:
                    resp.read()
                break
            except urllib.error.HTTPError:
                break
            except (urllib.error.URLError, ConnectionRefusedError, OSError):
                if attempt == 4:
                    pass
                time.sleep(1)
        time.sleep(0.5)

def dvwa_sqli():
    sqli_payloads = [
        "' OR '1'='1",
        "1' UNION SELECT 1, user() #",
        "1' AND 1=2 UNION SELECT user, password FROM users #"
    ]
    for p in sqli_payloads:
        url = 'http://linux-victim/search?q=' + urllib.parse.quote(p)
        try:
            with urllib.request.urlopen(url, timeout=10) as resp:
                resp.read()
        except Exception:
            pass
        time.sleep(0.5)

def smb():
    import tempfile
    for _ in range(5):
        command(['smbclient', '//windows-target/LabShare', '-U', 'student%IntentionallyWrong123!', '-c', 'ls'], expect_failure=True)
    with tempfile.NamedTemporaryFile(mode='w') as f:
        f.write('username = student\npassword = ' + PASSWORD + '\n')
        f.flush()
        command(['smbclient', '//windows-target/LabShare', '-A', f.name, '-c', 'ls'])

SCENARIOS = {
    'port-scan': lambda: command(['nmap', '-sT', '-Pn', '-p', '21,22,80', 'linux-victim']),
    'web': web,
    'dvwa-bruteforce': dvwa_bruteforce,
    'dvwa-sqli': dvwa_sqli,
    'linux-auth': lambda: auth('linux-victim'),
    'linux-ftp': lambda: ftp('linux-victim'),
    'windows-auth': smb,
    'windows-ssh': lambda: auth('windows-target'),
    'windows-ftp': lambda: ftp('windows-target')
}

def main():
    name = sys.argv[1] if len(sys.argv) == 2 else ''
    if name not in [*SCENARIOS, 'demo']:
        raise SystemExit('Usage: scenarios.py ' + '|'.join([*SCENARIOS, 'demo']))
    
    actions = list(SCENARIOS.keys()) if name == 'demo' else [name]
    for action in actions:
        record(action, 'unknown')
        try:
            SCENARIOS[action]()
        except Exception:
            record(action, 'failure')
            raise
        record(action, 'success')
        print('[OK]', action, flush=True)

if __name__ == '__main__':
    main()
