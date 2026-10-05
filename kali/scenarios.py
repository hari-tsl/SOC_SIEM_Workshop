"""Bounded scenarios. No caller-controlled target, command, count, or wordlist."""
import datetime, ftplib, json, os, subprocess, sys, time, urllib.request, urllib.parse
from logging.handlers import RotatingFileHandler
import logging
PASSWORD = os.environ.get('LAB_PASSWORD', '')
SSH = ['sshpass','-e','ssh','-o','StrictHostKeyChecking=no','-o','UserKnownHostsFile=/dev/null','-o','ConnectTimeout=5','-o','NumberOfPasswordPrompts=1','-o','PreferredAuthentications=password']
log = logging.getLogger('scenarios'); log.setLevel(logging.INFO)
os.makedirs('/logs', exist_ok=True)
h = RotatingFileHandler('/logs/scenarios.json', maxBytes=5_000_000, backupCount=2)
log.addHandler(h)
def record(action, outcome):
    log.info(json.dumps({'@timestamp': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'event': {'dataset':'kali.scenario','action':action,'outcome':outcome}, 'host':{'name':'kali'}}))
def command(args, password=None, expect_failure=False):
    env = os.environ.copy()
    if password is not None: env['SSHPASS'] = password
    result = subprocess.run(args, env=env, capture_output=True, timeout=40)
    # Do not classify a transport error as an expected authentication rejection.
    output = (result.stdout + result.stderr).decode(errors='replace')
    if expect_failure:
        if not result.returncode or not any(s in output for s in ('Permission denied','NT_STATUS_LOGON_FAILURE','NT_STATUS_WRONG_PASSWORD')):
            raise RuntimeError('Expected authentication rejection, received: ' + output[-500:])
    elif result.returncode:
        raise RuntimeError(output[-500:])
def auth(host):
    for _ in range(5):
        command(SSH + ['student@'+host, 'whoami'], 'IntentionallyWrong123!', True)
        time.sleep(1)
    command(SSH + ['student@'+host, 'whoami'], PASSWORD)
def ftp(host):
    for _ in range(3):
        with ftplib.FTP() as c:
            c.connect(host,21,timeout=10)
            try: c.login('student', 'IntentionallyWrong123!')
            except ftplib.error_perm as e:
                if not str(e).startswith('530'): raise
            else: raise RuntimeError('Wrong FTP password was accepted')
    with ftplib.FTP() as c:
        c.connect(host,21,timeout=10); c.login('student',PASSWORD); c.quit()
def web():
    for path in ['/', '/admin', '/.env', '/robots.txt', '/search?q=router', '/search?q='+urllib.parse.quote("' OR 1=1 -- ")]:
        try:
            with urllib.request.urlopen('http://linux-victim'+path,timeout=10) as r: r.read()
        except urllib.error.HTTPError as e:
            if e.code != 404: raise

def smb():
    # A temporary auth file keeps the correct password out of process arguments.
    import tempfile
    for _ in range(5):
        command(['smbclient','//windows-target/LabShare','-U','student%IntentionallyWrong123!','-c','ls'],expect_failure=True)
    with tempfile.NamedTemporaryFile(mode='w') as f:
        f.write('username = student\npassword = '+PASSWORD+'\n'); f.flush()
        command(['smbclient','//windows-target/LabShare','-A',f.name,'-c','ls'])
SCENARIOS = {'port-scan':lambda: command(['nmap','-sT','-Pn','-p','21,22,80','linux-victim']), 'web':web, 'linux-auth':lambda:auth('linux-victim'), 'linux-ftp':lambda:ftp('linux-victim'), 'windows-auth':smb, 'windows-ssh':lambda:auth('windows-target'), 'windows-ftp':lambda:ftp('windows-target')}
def main():
    name = sys.argv[1] if len(sys.argv)==2 else ''
    if name not in [*SCENARIOS, 'demo']:
        raise SystemExit('Usage: scenarios.py '+ '|'.join([*SCENARIOS,'demo']))
    for action in SCENARIOS if name == 'demo' else [name]:
        record(action,'unknown')
        try: SCENARIOS[action]()
        except Exception:
            record(action,'failure'); raise
        record(action,'success'); print('[OK]',action,flush=True)
if __name__ == '__main__': main()
