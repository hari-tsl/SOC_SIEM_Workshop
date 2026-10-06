"""Dependency-free ELK bootstrap and evidence-based acceptance checks."""
import datetime, json, os, sys, time, urllib.request, urllib.error
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NDJSON_PATH = Path('/kibana/soc-dashboard.ndjson') if Path('/kibana/soc-dashboard.ndjson').exists() else (ROOT / 'elk/kibana/soc-dashboard.ndjson')

ES = os.environ.get('ES_URL') or (sys.argv[2] if len(sys.argv) > 2 and sys.argv[2].startswith('http') else ('http://elasticsearch:9200' if Path('/kibana/soc-dashboard.ndjson').exists() else 'http://localhost:9200'))
KB = os.environ.get('KB_URL') or (sys.argv[3] if len(sys.argv) > 3 and sys.argv[3].startswith('http') else ('http://kibana:5601' if Path('/kibana/soc-dashboard.ndjson').exists() else 'http://localhost:5601'))

def request(base, path, method='GET', data=None, headers=None):
    h = {'kbn-xsrf': 'soc-lab'}
    if headers: h.update(headers)
    if isinstance(data, dict):
        data = json.dumps(data).encode(); h['Content-Type'] = 'application/json'
    with urllib.request.urlopen(urllib.request.Request(base + path, data=data, method=method, headers=h), timeout=15) as r:
        return json.loads(r.read())

def wait_ready(base, path, limit=900):
    deadline = time.monotonic() + limit
    while time.monotonic() < deadline:
        try:
            result = request(base, path)
            if base == KB and result.get('status', {}).get('overall', {}).get('level') != 'available':
                raise RuntimeError('Kibana not available')
            return result
        except (OSError, ValueError, RuntimeError):
            time.sleep(5)
    raise RuntimeError('Readiness timeout: ' + base + path)

def bootstrap():
    wait_ready(ES, '/_cluster/health?wait_for_status=yellow&timeout=5s')
    # Daily indices expire after seven days; no rollover alias is needed.
    request(ES, '/_ilm/policy/soc-retention', 'PUT', {'policy': {'phases': {'delete': {'min_age': '7d', 'actions': {'delete': {}}}}}})
    properties = {
        '@timestamp': {'type': 'date'},
        'event': {'properties': {k: {'type': 'keyword'} for k in ['dataset', 'code', 'category', 'outcome', 'action']}},
        'winlog': {'properties': {'channel': {'type': 'keyword'}}},
        'host': {'properties': {'name': {'type': 'keyword'}}},
        'user': {'properties': {'name': {'type': 'keyword'}}},
        'source': {'properties': {'ip': {'type': 'ip'}, 'address': {'type': 'keyword'}, 'port': {'type': 'integer'}}},
        'http': {'properties': {'response': {'properties': {'status_code': {'type': 'integer'}}}}}
    }
    request(ES, '/_index_template/soc-lab', 'PUT', {
        'index_patterns': ['soc-*'],
        'priority': 200,
        'template': {
            'settings': {'number_of_shards': 1, 'number_of_replicas': 0, 'index.lifecycle.name': 'soc-retention'},
            'mappings': {'properties': properties}
        }
    })
    wait_ready(KB, '/api/status')
    boundary = 'soc_lab_ndjson_boundary'
    content = NDJSON_PATH.read_bytes()
    body = (f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="soc.ndjson"\r\nContent-Type: application/ndjson\r\n\r\n'.encode() + content + f'\r\n--{boundary}--\r\n'.encode())
    result = request(KB, '/api/saved_objects/_import?overwrite=true', 'POST', body, {'Content-Type': 'multipart/form-data; boundary=' + boundary})
    if not result.get('success'): raise RuntimeError('Saved-object import failed: ' + json.dumps(result))
    request(KB, '/api/kibana/settings', 'POST', {'changes': {'defaultIndex': 'soc-events'}})
    print('Index policy, mappings, data view, dashboard and saved searches configured.', flush=True)

def checks():
    return {
        'Linux SSH failure': {'bool': {'filter': [{'term': {'event.dataset': 'linux.auth'}}, {'term': {'event.outcome': 'failure'}}]}},
        'Linux SSH success': {'bool': {'filter': [{'term': {'event.dataset': 'linux.auth'}}, {'term': {'event.outcome': 'success'}}]}},
        'Web requests': {'term': {'event.dataset': 'linux.web'}},
        'Linux FTP': {'term': {'event.dataset': 'linux.ftp'}},
        'Windows failed logon': {'bool': {'filter': [{'term': {'event.code': '4625'}}, {'term': {'user.name': 'student'}}]}},
        'Windows successful logon': {'bool': {'filter': [{'term': {'event.code': '4624'}}, {'term': {'user.name': 'student'}}]}},
        'Windows SSH': {'term': {'winlog.channel': 'OpenSSH/Operational'}},
        'Windows FTP': {'term': {'event.dataset': 'windows.ftp'}},
        'Kali scenarios': {'term': {'event.dataset': 'kali.scenario'}}
    }

def counts(since):
    result = {}
    for label, query in checks().items():
        payload = {'query': {'bool': {'filter': [query, {'range': {'@timestamp': {'gte': since}}}]}}}
        try:
            result[label] = request(ES, '/soc-*/_count', 'POST', payload)['count']
        except urllib.error.HTTPError as e:
            if e.code != 404: raise
            result[label] = 0
    return result

def verify(since):
    deadline = time.monotonic() + 300
    while time.monotonic() < deadline:
        result = counts(since)
        if all(result.values()):
            print(json.dumps({'since': since, 'counts': result, 'result': 'PASS'}, indent=2)); return
        print('Waiting for telemetry: ' + ', '.join(k for k, v in result.items() if not v), flush=True)
        time.sleep(10)
    raise RuntimeError('Missing fresh telemetry: ' + json.dumps(result))

def status():
    print(json.dumps(request(ES, '/_cluster/health'), indent=2))
    print('Kibana:', request(KB, '/api/status')['status']['overall']['level'])
    result = counts('now-15m'); print(json.dumps(result, indent=2))
    if not all(result.values()): raise RuntimeError('One or more telemetry sources have no events in the last 15m; rerun acceptance.')

if __name__ == '__main__':
    mode = sys.argv[1] if len(sys.argv) > 1 else 'bootstrap'
    if mode == 'bootstrap': bootstrap()
    elif mode == 'verify': verify(sys.argv[2])
    elif mode == 'status': status()
    else: raise SystemExit('Unknown operation')
