#!/usr/bin/env python3
"""Generate secrets and OEM inputs without executing .env as shell code."""
import json, os, re, secrets, shutil
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def read_env(path):
    values = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith('#'): continue
        key, sep, value = line.partition('=')
        if not sep or not re.fullmatch(r'[A-Z_]+',key): raise ValueError('Invalid .env key')
        if not re.fullmatch(r'[a-zA-Z0-9_./:@!+-]+',value):
            raise ValueError('Use simple unquoted .env values; passwords may contain letters, digits, ! + - _')
        values[key] = value
    return values

def main():
    os.umask(0o077)
    path = ROOT/'.env'
    if not path.exists():
        text = (ROOT/'.env.example').read_text()
        for key in ('WINDOWS_PASSWORD','LAB_PASSWORD'):
            text = text.replace(key+'=CHANGE_ME',key+'=Soc9!'+secrets.token_hex(12))
        path.write_text(text)
    cfg = read_env(path)
    for key in ('WINDOWS_PASSWORD','LAB_PASSWORD'):
        if cfg.get(key) == 'CHANGE_ME' or len(cfg.get(key,'')) < 12: raise ValueError('Set a strong lab-only '+key)
    runtime=ROOT/'.runtime/oem'; runtime.mkdir(parents=True,exist_ok=True)
    for src in (ROOT/'windows/oem').iterdir(): shutil.copy2(src,runtime/src.name)
    (runtime/'settings.json').write_text(json.dumps({'elastic_version':cfg.get('ELASTIC_VERSION','8.19.4'),'lab_password':cfg['LAB_PASSWORD']}))
    path.chmod(0o600)
    print('Configuration prepared. Lab credentials: .env (do not commit).')
if __name__=='__main__': main()
