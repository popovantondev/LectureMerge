#!/usr/bin/env python3
import ast
import json
from pathlib import Path
import re
import subprocess
from release_support import ROOT, version, sha256

number = version()
assert (ROOT / 'BUILD_NUMBER').read_text().strip().isdigit(), 'Invalid BUILD_NUMBER'
assert f'## [{number}]' in (ROOT / 'CHANGELOG.md').read_text(), 'Missing changelog entry'
for directory in ['Sources', 'Scripts', 'Tests', 'docs', 'Assets', '.github']:
    assert (ROOT / directory).is_dir(), 'Missing ' + directory
for path in (ROOT / 'Scripts').glob('*.py'):
    ast.parse(path.read_text(), filename=str(path))
for pattern in ['Scripts/*.sh', '*.command']:
    for path in ROOT.glob(pattern):
        subprocess.run(['bash', '-n', str(path)], check=True)
for directory in ['Sources', 'Scripts', 'Tests']:
    for path in (ROOT / directory).rglob('*'):
        if path.suffix in {'.swift', '.py', '.sh'}:
            assert not re.search('/' + 'Users/' + r'[^/]+/', path.read_text()), f'Personal absolute path: {path}'
for name, info in json.loads((ROOT / 'vendor/dependencies.json').read_text()).items():
    assert Path(name).name == name and info['url'].startswith('https://')
    assert re.fullmatch('[0-9a-f]{64}', info['sha256'])
    archive = ROOT / 'vendor' / name
    if archive.exists():
        assert sha256(archive) == info['sha256'], f'Changed codec archive: {name}'
print('Project metadata, scripts and available source archives: OK')
