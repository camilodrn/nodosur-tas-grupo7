#!/usr/bin/env python3
"""Verifica una copia existente sin importar SQL ni imprimir su contenido."""
import argparse
import gzip
import hashlib
import re
from pathlib import Path

def verify(path, expected):
    # No aceptar rutas adicionales en un manifiesto recibido de otra máquina.
    manifest = Path(str(path) + '.sha256').read_text().strip()
    match = re.fullmatch(r'([0-9a-f]{64})  (.+)', manifest)
    if not match or match[2] != path.name:
        raise ValueError('manifiesto inválido o nombre no coincidente')
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    if digest.hexdigest() != match[1]:
        raise ValueError('SHA-256 no coincide')
    tables = 0
    # Leer hasta EOF comprueba CRC y longitud GZIP; no guardar SQL sin comprimir.
    with gzip.open(path, 'rb') as stream:
        for line in stream:
            tables += line.startswith(b'CREATE TABLE ')
    if tables == 0 or (expected is not None and tables != expected):
        raise ValueError(f'cantidad de tablas inesperada: {tables}')
    return tables

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('backup', type=Path)
    parser.add_argument('--expected-tables', type=int, help='52 para comparar la línea base de E3')
    args = parser.parse_args()
    try:
        tables = verify(args.backup, args.expected_tables)
    except (OSError, EOFError, ValueError) as error:
        parser.exit(1, f'ERROR de integridad: {error}\n')
    print(f'SHA-256 y GZIP: OK; tablas={tables}; archivo={args.backup.name}')

if __name__ == '__main__':
    main()
