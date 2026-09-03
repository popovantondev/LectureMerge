#!/usr/bin/env python3
"""Read-only verification of release checksums, ZIPs, tag and app signature."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile
from release_support import ROOT, sha256, version

tag = sys.argv[1] if len(sys.argv) > 1 else 'v' + version()
if not tag.startswith('v') or '/' in tag or '..' in tag:
    raise SystemExit('Expected a local version tag, e.g. v2.0.0')
folder = ROOT / 'releases' / tag
subprocess.run(['shasum', '-a', '256', '-c', 'SHA256SUMS'], cwd=folder, check=True)
manifest = json.loads((folder / 'manifest.json').read_text())
commit = subprocess.check_output(['git', 'rev-list', '-n', '1', tag], cwd=ROOT, text=True).strip()
assert manifest['gitCommit'] == commit, 'Release tag no longer points to the archived source commit'
assert tag == 'v' + manifest['version'], 'Version mismatch'
for name, entry in manifest['artifacts'].items():
    assert Path(name).name == name, 'Invalid archive name'
    p = folder / name
    assert p.stat().st_size == entry['bytes'] and sha256(p) == entry['sha256']
    with zipfile.ZipFile(p) as archive:
        assert archive.testzip() is None
        assert all(not Path(n).is_absolute() and '..' not in Path(n).parts for n in archive.namelist())
    if name.endswith('-macos-arm64.zip'):
        with tempfile.TemporaryDirectory(prefix='lecture-release-verify-') as tmp:
            subprocess.run(['ditto', '-x', '-k', str(p), tmp], check=True)
            app = Path(tmp) / manifest['application']
            subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
            for tool, digest in manifest['bundledCodecs'].items():
                assert sha256(app / 'Contents/Resources/bin' / tool) == digest
print('Verified archives, source tag, unpacked application signature and codec hashes:', tag)
