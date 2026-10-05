import contextlib, importlib.util, json, os, tempfile, threading, unittest
from pathlib import Path
from unittest.mock import patch
from urllib.request import urlopen
from http.server import ThreadingHTTPServer
ROOT=Path(__file__).resolve().parents[1]
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,ROOT/path)
    obj=importlib.util.module_from_spec(spec); spec.loader.exec_module(obj); return obj
app=module('app','linux-victim/webapp/app.py')
config=module('config','scripts/configure.py')
bootstrap=module('bootstrap','scripts/bootstrap.py')
class LabTests(unittest.TestCase):
    def test_actual_http_target_and_injection(self):
        from urllib.parse import quote
        server=ThreadingHTTPServer(('127.0.0.1',0),app.Handler)
        thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        try:
            base=f'http://127.0.0.1:{server.server_port}'
            self.assertEqual(json.load(urlopen(base+'/health'))['status'],'ok')
            normal=json.load(urlopen(base+'/search?q=router'))['products']
            injected=json.load(urlopen(base+'/search?q='+quote("' OR 1=1 -- ")))['products']
            self.assertEqual(len(normal),1);self.assertEqual(len(injected),2)
        finally: server.shutdown();server.server_close();thread.join()
    def test_configuration_idempotent_and_secrets_private(self):
        import shutil
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)
            shutil.copy(ROOT/'.env.example',root/'.env.example')
            shutil.copytree(ROOT/'windows',root/'windows')
            with patch.object(config,'ROOT',root):
                config.main(); before=(root/'.env').read_bytes(); config.main()
            self.assertEqual(before,(root/'.env').read_bytes())
            if os.name != 'nt': self.assertEqual((root/'.env').stat().st_mode & 0o777,0o600)
            cfg=config.read_env(root/'.env')
            self.assertNotEqual(cfg['LAB_PASSWORD'],cfg['WINDOWS_PASSWORD'])
            oem=json.loads((root/'.runtime/oem/settings.json').read_text())
            self.assertEqual(oem['lab_password'],cfg['LAB_PASSWORD'])
    def test_env_is_data_not_shell_code(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'.env';p.write_text('LAB_PASSWORD=$(touch /tmp/should-not-exist)\n')
            with self.assertRaises(ValueError):config.read_env(p)
    def test_every_acceptance_query_is_time_bounded(self):
        captured=[]
        def request(base,path,method,data):
            captured.append(data);return {'count':1}
        since='2026-10-05T10:00:00Z'
        with patch.object(bootstrap,'request',side_effect=request): result=bootstrap.counts(since)
        self.assertEqual(len(captured),9)
        self.assertTrue(all(result.values()))
        for payload in captured:
            self.assertIn({'range':{'@timestamp':{'gte':since}}},payload['query']['bool']['filter'])
    def test_verify_rejects_missing_telemetry(self):
        with patch.object(bootstrap,'counts',return_value={'Windows':0}),patch.object(bootstrap.time,'sleep'),patch.object(bootstrap.time,'monotonic',side_effect=[0,1,301]):
            with self.assertRaisesRegex(RuntimeError,'Missing fresh telemetry'):bootstrap.verify('now-1m')
    def test_verify_passes_complete_telemetry(self):
        with patch.object(bootstrap,'counts',return_value={'Linux':1,'Windows':2}),patch.object(bootstrap.time,'monotonic',side_effect=[0,1]):bootstrap.verify('now-1m')
if __name__=='__main__':unittest.main()
