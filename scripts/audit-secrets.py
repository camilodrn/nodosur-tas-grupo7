#!/usr/bin/env python3
"""Barrido heurístico sin imprimir valores; árbol completo y blobs de refs locales."""
import re
import stat
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATTERNS = {
    'private-key': re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY-----'),
    'provider-token': re.compile(r'\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}|AKIA[A-Z0-9]{16}|sk-[A-Za-z0-9]{32,})\b'),
    'credential-url': re.compile(r'\b(?:mysql|mariadb|postgres|https?)://[^\s/:]+:[^\s/@]+@'),
    'literal-credential': re.compile(r'''(?i)(?:password|passwd|secret|token)\s*[:=]\s*['"]([^'"\n]{8,})['"]'''),
    'wordpress-secret': re.compile(r'''define\(\s*['"](?:DB_PASSWORD|AUTH_KEY|SECURE_AUTH_KEY|LOGGED_IN_KEY|NONCE_KEY|AUTH_SALT|SECURE_AUTH_SALT|LOGGED_IN_SALT|NONCE_SALT)['"]\s*,\s*['"]([^'"\n]+)['"]'''),
}
PLACEHOLDER = re.compile(r'(?i)NO_INCLUID|REDACTED|PLACEHOLDER|NO_ES_UNA|example|put your|\$|\\|^/|^<.*>$')

def findings(data):
    text = data.decode('utf-8', errors='replace')
    for number, line in enumerate(text.splitlines(), 1):
        for rule, pattern in PATTERNS.items():
            for match in pattern.finditer(line):
                if rule in ('literal-credential', 'wordpress-secret') and PLACEHOLDER.search(match.group(1)):
                    continue
                yield rule, number

def sensitive_name(path):
    name = Path(path).name.lower()
    if 'example' in name:
        return False
    return (name == 'wp-config.php' or name.startswith('.env') or
            name.startswith(('id_rsa', 'id_ed25519')) or
            name.endswith(('.key', '.pem', '.p12', '.pfx', '.password', '.sql', '.sql.gz', '.dump', '.tar', '.tar.gz', '.tgz', '.zip', '.7z')))

def main():
    count = candidates = 0
    for p in sorted(ROOT.rglob('*')):
        rel = p.relative_to(ROOT)
        if '.git' in rel.parts or '__pycache__' in rel.parts:
            continue
        if p.is_symlink():
            print(f'REVISAR symlink: {rel}')
            candidates += 1
            continue
        if p.stat().st_mode & stat.S_IWOTH:
            print(f'REVISAR world-writable: {rel}')
            candidates += 1
        if not p.is_file():
            continue
        count += 1
        if sensitive_name(rel):
            print(f'REVISAR nombre-sensible: {rel}')
            candidates += 1
        for rule, line in findings(p.read_bytes()):
            print(f'REVISAR árbol {rel}:{line} regla={rule} (valor omitido)')
            candidates += 1
    objects = subprocess.check_output(['git', 'rev-list', '--objects', '--all'], cwd=ROOT).splitlines()
    proc = subprocess.Popen(['git', 'cat-file', '--batch'], cwd=ROOT, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    blobs = 0
    for item in objects:
        oid = item.split(b' ', 1)[0]
        proc.stdin.write(oid + b'\n')
        proc.stdin.flush()
        header = proc.stdout.readline().split()
        size = int(header[2])
        data = proc.stdout.read(size)
        proc.stdout.read(1)
        if header[1] != b'blob':
            continue
        blobs += 1
        # No imprimir rutas históricas ni líneas que pudieran contener secretos.
        for rule, line in findings(data):
            print(f'REVISAR historia blob={oid.decode()} línea={line} regla={rule} (valor omitido)')
            candidates += 1
        if len(item.split(b' ', 1)) == 2 and sensitive_name(item.split(b' ', 1)[1].decode(errors='replace')):
            print(f'REVISAR nombre-sensible histórico blob={oid.decode()}')
            candidates += 1
    proc.stdin.close()
    if proc.wait() != 0:
        raise SystemExit('Falló lectura de objetos Git')
    print(f'Archivos árbol={count}; blobs alcanzables --all={blobs}; candidatos={candidates}')
    print('Heurístico: no demuestra ausencia absoluta; excluye .git físico, objetos inalcanzables y contenido remoto.')
    return int(candidates != 0)

if __name__ == '__main__':
    raise SystemExit(main())
