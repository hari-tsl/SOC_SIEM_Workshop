#!/usr/bin/env python3
"""Offline structural validation. Does not substitute for Docker/KVM acceptance."""
import ast,json,shutil,subprocess
from pathlib import Path
import yaml
ROOT=Path(__file__).resolve().parents[1]
def validate():
    has_bash = shutil.which('bash') is not None
    files=list(ROOT.rglob('*'))
    for path in files:
        if any(x in path.parts for x in ('.git','.runtime','__pycache__')): continue
        if path.suffix=='.py': ast.parse(path.read_text(),filename=str(path))
        if path.suffix=='.sh' and has_bash: subprocess.run(['bash','-n',str(path)],check=True)
        if path.suffix in ('.yaml','.yml'): yaml.safe_load(path.read_text())
    compose=yaml.safe_load((ROOT/'compose.yml').read_text())
    services=compose['services']
    for name,svc in services.items():
        for dep in svc.get('depends_on',{}): assert dep in services,(name,dep)
        for volume in svc.get('volumes',[]):
            source=volume.split(':')[0]
            if source.startswith('./') and not source.startswith('./.runtime'):
                assert (ROOT/source).exists(),source
        for port in svc.get('ports',[]): assert str(port).startswith('127.0.0.1:'),(name,port)
    assert compose['networks']['lab']['internal'] is True
    for name in ('kali','linux-victim'):
        assert services[name]['networks']==['lab']
    objects=[json.loads(x) for x in (ROOT/'elk/kibana/soc-dashboard.ndjson').read_text().splitlines()]
    ids={(o['type'],o['id']) for o in objects}
    assert len(ids)==len(objects)
    for obj in objects:
        for ref in obj.get('references',[]): assert (ref['type'],ref['id']) in ids,ref
        for key,val in obj['attributes'].items():
            if key.endswith('JSON') or key=='visState': json.loads(val)
    print(f'PASS: Python, shell, YAML, bind mounts, loopback ports, isolation and {len(objects)} saved objects')
if __name__=='__main__': validate()
