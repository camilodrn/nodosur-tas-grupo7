"""Regresiones locales: ningún comando llega a Docker/iptables/red real."""
import copy
import importlib.util
import ipaddress
import json
import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class Sandbox(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='nodosur-test-')
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name)
        self.bin = self.path / 'bin'
        self.bin.mkdir()
        self.env = {**os.environ, 'PATH': str(self.bin) + ':' + os.environ['PATH']}

    def stub(self, name, content):
        p = self.bin / name
        p.write_text(content)
        p.chmod(0o755)

    def run_script(self, path, *args):
        return subprocess.run(['bash', str(path), *args], text=True, capture_output=True, env=self.env, cwd=ROOT)

class BackupTests(Sandbox):
    def setUp(self):
        super().setUp()
        self.backup = self.path / 'backup.sh'
        self.backup.write_text((ROOT/'scripts/e3/nodosur-backup-db.sh').read_text().replace('/var/backups/nodosur', str(self.path / 'backups')))
        self.stub('docker', '''#!/usr/bin/env python3
import os, sys
if sys.argv[1] == 'inspect':
    print(os.environ.get('HEALTH', 'healthy'))
elif sys.argv[1] == 'exec':
    for i in range(int(os.environ.get('TABLES', '52'))):
        print('CREATE TABLE `fixture_%d` (`id` int);' % i)
    sys.exit(int(os.environ.get('DUMP_EXIT', '0')))
else:
    sys.exit(99)
''')

    def artifacts(self):
        return list((self.path/'backups').rglob('*.sql.gz'))

    def test_success_checksum_and_permissions(self):
        r = self.run_script(self.backup, 'prod')
        self.assertEqual(r.returncode, 0, r.stderr)
        dump, = self.artifacts()
        self.assertEqual(dump.stat().st_mode & 0o777, 0o600)
        self.assertEqual(dump.parent.stat().st_mode & 0o777, 0o700)
        checksum = subprocess.run(['sha256sum', '-c', dump.name+'.sha256'], cwd=dump.parent, capture_output=True)
        self.assertEqual(checksum.returncode, 0)
        self.assertFalse(list(dump.parent.glob('.nodosur-*')))

    def test_partial_failed_dump_never_published(self):
        self.env['DUMP_EXIT'] = '1'
        r = self.run_script(self.backup, 'prod')
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual(self.artifacts(), [])
        self.assertFalse(list((self.path/'backups/daily').glob('.nodosur-*')))

    def test_unhealthy_never_published(self):
        self.env['HEALTH'] = 'unhealthy'
        self.assertNotEqual(self.run_script(self.backup, 'prod').returncode, 0)
        self.assertEqual(self.artifacts(), [])

    def test_empty_dump_rejected(self):
        self.env['TABLES'] = '0'
        self.assertNotEqual(self.run_script(self.backup, 'prod').returncode, 0)
        self.assertEqual(self.artifacts(), [])

    def test_schema_growth_preserves_backup_with_warning(self):
        self.env['TABLES'] = '53'
        r = self.run_script(self.backup, 'prod')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn('AVISO', r.stderr)
        self.assertEqual(len(self.artifacts()), 1)

    def test_concurrent_lock_rejected(self):
        import fcntl
        directory = self.path/'backups/daily'
        directory.mkdir(parents=True)
        with (directory/'.backup.lock').open('w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.assertNotEqual(self.run_script(self.backup, 'prod').returncode, 0)
        self.assertEqual(self.artifacts(), [])

    def test_client_password_escaping(self):
        # Ejecutar el sh interior con un secreto FICTICIO y un cliente simulado.
        # Comprueba que #, espacios, comillas y backslash no alteran option files.
        secret = self.path/'password'
        secret.write_text('test # " slash\\ value\n')
        marker = self.path/'config-result'
        self.env['CONFIG_RESULT'] = str(marker)
        self.stub('mariadb-dump', '''#!/usr/bin/env python3
import os, pathlib, sys
p = pathlib.Path(sys.argv[1].split('=', 1)[1])
pathlib.Path(os.environ['CONFIG_RESULT']).write_bytes(p.read_bytes())
print('CREATE TABLE fixture (id int);')
''')
        source = self.backup.read_text().replace('/run/secrets/root_password', str(secret))
        inner = self.path/'inner.sh'
        # Reemplazar docker exec por ejecución del sh proporcionado por el script.
        self.stub('docker', '''#!/usr/bin/env python3
import os, sys
if sys.argv[1] == 'inspect': print('healthy')
else: os.execvp(sys.argv[3], sys.argv[3:])
''')
        inner.write_text(source)
        r = self.run_script(inner, 'prod')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(marker.read_text(), '[client]\nuser=root\npassword="test # \\" slash\\\\ value"\n')

FIREWALL_STUB = '''#!/usr/bin/env python3
import json, os, pathlib, shlex, sys
p = pathlib.Path(os.environ['RULE_STATE'])
state = json.loads(p.read_text())
a = sys.argv[1:]
if pathlib.Path(sys.argv[0]).name == 'iptables-restore':
    if os.environ.get('RESTORE_FAIL'): sys.exit(1)
    lines = sys.stdin.read().splitlines()
    if lines[0] != '*filter' or lines[-1] != 'COMMIT': sys.exit(2)
    for line in lines[1:-1]:
        if line.startswith(':'):
            state[line.split()[0][1:]] = []
            continue
        op, chain, *rule = shlex.split(line)
        if op == '-F': state[chain] = []
        elif op == '-A': state[chain].append(rule)
        elif op == '-D': state[chain].remove(rule)
        elif op == '-I': state[chain].insert(int(rule[0])-1, rule[1:])
        else: sys.exit(3)
else:
    if a[:2] == ['-w', '5']: a = a[2:]
    op, chain, *rule = a
    if op == '-S': sys.exit(0 if chain in state else 1)
    if op == '-C': sys.exit(0 if rule in state.get(chain, []) else 1)
    if op == '-N': state[chain] = []
    else: sys.exit(4)
p.write_text(json.dumps(state))
'''

class FirewallTests(Sandbox):
    def setUp(self):
        super().setUp()
        self.state = self.path/'rules.json'
        self.initial = {'FORWARD': [['-j', 'DOCKER-USER']], 'DOCKER-USER': [['-j', 'RETURN']], 'OTHER': [['-j', 'RETURN']]}
        self.state.write_text(json.dumps(self.initial))
        self.env['RULE_STATE'] = str(self.state)
        for name in ('iptables', 'iptables-restore'):
            self.stub(name, FIREWALL_STUB)

    def apply(self, script, *args):
        source = (ROOT/'configs/firewall'/script).read_text().replace('/usr/local/lib/nodosur/nodosur-firewall-common.sh', str(ROOT/'configs/firewall/nodosur-firewall-common.sh'))
        path = self.path/'apply.sh'
        path.write_text(source)
        return self.run_script(path, *args)

    def decision(self, source, destination, port):
        """Simula el retorno a DOCKER-USER tras un jump, no un goto."""
        state = json.loads(self.state.read_text())
        for rule in state['DOCKER-USER']:
            if '--ctorigdst' in rule:
                if destination != rule[rule.index('--ctorigdst')+1]:
                    continue
                if str(port) != rule[rule.index('--ctorigdstport')+1]:
                    continue
                for item in state[rule[-1]]:
                    allowed = '-s' not in item or ipaddress.ip_address(source) in ipaddress.ip_network(item[item.index('-s')+1])
                    if not allowed:
                        continue
                    if item[-1] == 'DROP':
                        return 'DROP'
                    if item[-1] == 'RETURN':
                        if '-g' in rule:
                            return 'DOCKER'
                        break  # -j: continuar con la siguiente regla DOCKER-USER
                continue
            if rule[-2:] == ['-j', 'DROP']:
                return 'DROP'
            if rule[-2:] == ['-j', 'RETURN']:
                return 'DOCKER'
        return 'DOCKER'

    def test_db_allow_deny_and_idempotence(self):
        name='nodosur-db-prod-firewall.sh'
        self.assertEqual(self.apply(name).returncode, 0)
        first = json.loads(self.state.read_text())
        self.assertEqual(self.apply(name).returncode, 0)
        self.assertEqual(first, json.loads(self.state.read_text()))
        for source in ('10.33.199.58', '10.33.199.62'):
            self.assertEqual(self.decision(source, '10.33.199.60', 3306), 'DOCKER')
        for source in ('10.33.199.59', '10.33.199.61', '10.30.248.3'):
            self.assertEqual(self.decision(source, '10.33.199.60', 3306), 'DROP')
        self.assertEqual(self.decision('10.33.199.61', '10.33.199.60', 22), 'DOCKER')
        self.assertEqual(first['OTHER'], self.initial['OTHER'])
        self.assertNotIn('-i', str(first))

    def test_allowed_source_obeys_subsequent_docker_user_rules(self):
        # Un goto saltaría este DROP heredado incluso con origen permitido.
        self.initial['DOCKER-USER'] = [['-j', 'DROP']]
        self.state.write_text(json.dumps(self.initial))
        self.assertEqual(self.apply('nodosur-db-prod-firewall.sh').returncode, 0)
        self.assertEqual(
            self.decision('10.33.199.58', '10.33.199.60', 3306), 'DROP'
        )

    def test_proxy_both_ports_and_sources(self):
        self.assertEqual(self.apply('nodosur-proxy-firewall.sh').returncode, 0)
        for port in (80, 443):
            for source in ('10.30.248.3','10.33.21.5'):
                self.assertEqual(self.decision(source,'10.33.195.194',port),'DOCKER')
            self.assertEqual(self.decision('10.33.199.60','10.33.195.194',port),'DROP')

    def test_web_and_invalid_arguments(self):
        self.assertEqual(self.apply('nodosur-docker-firewall.sh','10.33.199.58','18081').returncode,0)
        self.assertEqual(self.decision('10.33.199.61','10.33.199.58',18081),'DOCKER')
        self.assertEqual(self.decision('10.33.199.62','10.33.199.58',18081),'DROP')
        self.assertNotEqual(self.apply('nodosur-docker-firewall.sh','0.0.0.0','22').returncode,0)

    def test_missing_docker_jump_stops_without_changes(self):
        self.initial['FORWARD']=[]
        self.state.write_text(json.dumps(self.initial))
        self.assertNotEqual(self.apply('nodosur-db-prod-firewall.sh').returncode,0)
        self.assertEqual(json.loads(self.state.read_text()),self.initial)

    def test_restore_failure_preserves_active_policy(self):
        self.assertEqual(self.apply('nodosur-db-prod-firewall.sh').returncode,0)
        before=self.state.read_text()
        self.env['RESTORE_FAIL']='1'
        self.assertNotEqual(self.apply('nodosur-db-prod-firewall.sh').returncode,0)
        self.assertEqual(self.state.read_text(),before)

class ValidatorTests(Sandbox):
    def test_http_healthy_and_redirect(self):
        self.stub('curl', '''#!/usr/bin/env python3
import sys
if '--head' in sys.argv: print('HTTP/1.1 301 Moved Permanently\\r\\nLocation: https://nodosur07.tas/\\r\\n')
else: print('200', end='')
''')
        self.assertEqual(self.run_script(ROOT/'scripts/validate-web.sh').returncode,0)

    def test_http_network_failure(self):
        self.stub('curl', '#!/bin/sh\nexit 7\n')
        self.assertNotEqual(self.run_script(ROOT/'scripts/validate-web.sh').returncode,0)

    def test_http_failure_propagates(self):
        self.stub('curl', '#!/bin/sh\nprintf 503\n')
        self.assertNotEqual(self.run_script(ROOT/'scripts/validate-web.sh').returncode,0)

    def test_dns_wrong_address_propagates(self):
        self.stub('dig', '#!/bin/sh\necho 10.33.195.202\n')
        self.assertNotEqual(self.run_script(ROOT/'scripts/validate-dns.sh').returncode,0)

    def test_dns_expected_records(self):
        self.stub('dig', '''#!/usr/bin/env python3
import sys
print({'nodosur07.tas':'10.33.195.194','www.nodosur07.tas':'10.33.195.194','db.nodosur07.tas':'10.33.199.60','ns1.nodosur07.tas':'10.33.195.205'}[sys.argv[2]])
''')
        self.assertEqual(self.run_script(ROOT/'scripts/validate-dns.sh').returncode,0)

    def test_storage_rejects_local_mount(self):
        self.stub('mountpoint', '#!/bin/sh\nexit 0\n')
        self.stub('findmnt', '#!/bin/sh\necho ext4\n')
        self.assertNotEqual(self.run_script(ROOT/'scripts/e3/nodosur-check-web-storage.sh','web1').returncode,0)

    def test_storage_rejects_readonly_or_wrong_server(self):
        self.stub('mountpoint', '#!/bin/sh\nexit 0\n')
        self.stub('findmnt', '''#!/usr/bin/env python3
import os, sys
print({'FSTYPE':'nfs4','SOURCE':os.environ.get('NFS_SOURCE','10.33.199.59:/uploads'),'OPTIONS':'ro,hard'}[sys.argv[-1]])
''')
        self.assertNotEqual(self.run_script(ROOT/'scripts/e3/nodosur-check-web-storage.sh','web1').returncode,0)
        self.env['NFS_SOURCE']='10.33.199.60:/uploads'
        self.assertNotEqual(self.run_script(ROOT/'scripts/e3/nodosur-check-web-storage.sh','web1').returncode,0)

    def test_cart_requires_explicit_mutation_flag(self):
        result=subprocess.run(['python3', str(ROOT/'pruebas/e3/carrito-coherencia.py')],capture_output=True,text=True)
        self.assertEqual(result.returncode,2)
        self.assertIn('--permitir-escritura',result.stderr)

class ConfigurationTests(unittest.TestCase):
    def test_compose_validation_and_data_isolation(self):
        configs={}
        for path in sorted((ROOT/'compose').glob('*/*.yaml')):
            p=subprocess.run(['docker','compose','-f',str(path),'config','--format','json'],capture_output=True,text=True)
            self.assertEqual(p.returncode,0,p.stderr)
            configs[str(path.relative_to(ROOT))]=json.loads(p.stdout)
        prod=configs['compose/db-stage/compose.prod.yaml']
        stage=configs['compose/db-stage/compose.yaml']
        self.assertNotEqual(prod['name'],stage['name'])
        self.assertNotEqual(prod['services']['mariadb']['container_name'],stage['services']['mariadb']['container_name'])
        self.assertTrue(prod['volumes']['db_stage_data']['external'])
        self.assertEqual(prod['volumes']['db_stage_data']['name'],'nodosur-db-staging_db_stage_data')
        self.assertNotEqual(prod['volumes']['db_stage_data']['name'],stage['volumes']['db_lab_data']['name'])
        for backend in ('web1','web2'):
            volumes=configs[f'compose/{backend}/compose.yaml']['services']['wordpress']['volumes']
            self.assertTrue(all(not v.get('bind',{}).get('create_host_path',False) for v in volumes))

    def test_systemd_local_dependencies_resolve(self):
        directory=ROOT/'configs/systemd'
        for file in directory.glob('*.service'):
            for line in file.read_text().splitlines():
                if line.startswith(('Requires=','Requisite=','After=','Before=','PartOf=')):
                    for unit in line.split('=',1)[1].split():
                        if unit.startswith('nodosur-'):
                            self.assertTrue((directory/unit).exists(),f'{file.name}: {unit}')
            if 'WorkingDirectory=' in file.read_text():
                self.assertIn('WorkingDirectory=/opt/nodosur',file.read_text())

class BackupVerifierTests(Sandbox):
    def setUp(self):
        super().setUp()
        import gzip
        import hashlib
        self.dump = self.path/'fixture.sql.gz'
        self.dump.write_bytes(gzip.compress(b'CREATE TABLE fixture (id int);\n'))
        self.manifest = Path(str(self.dump)+'.sha256')
        self.manifest.write_text(hashlib.sha256(self.dump.read_bytes()).hexdigest()+'  '+self.dump.name+'\n')
        spec=importlib.util.spec_from_file_location('verify_backup',ROOT/'scripts/e3/verify-backup.py')
        self.module=importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.module)

    def test_integrity_and_table_count(self):
        self.assertEqual(self.module.verify(self.dump,1),1)
        with self.assertRaises(ValueError): self.module.verify(self.dump,52)

    def test_corruption_rejected(self):
        self.dump.write_bytes(self.dump.read_bytes()+b'corrupt')
        with self.assertRaises(ValueError): self.module.verify(self.dump,None)

    def test_manifest_other_path_rejected(self):
        self.manifest.write_text(self.manifest.read_text().replace(self.dump.name,'../outside.sql.gz'))
        with self.assertRaises(ValueError): self.module.verify(self.dump,None)

if __name__=='__main__':
    unittest.main(verbosity=2)
