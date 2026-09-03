"""Shared version, source fingerprint and no-overwrite publication helpers."""
import ctypes
import errno
import hashlib
import json
import os
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent.parent


def version():
    value = (ROOT / 'VERSION').read_text().strip()
    if not re.fullmatch(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)', value):
        raise ValueError('VERSION must contain MAJOR.MINOR.PATCH')
    return value


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def source_fingerprint():
    paths = [ROOT / 'VERSION', ROOT / 'BUILD_NUMBER', ROOT / 'vendor/dependencies.json']
    for name in ['Sources', 'Scripts', 'Assets']:
        paths.extend(p for p in (ROOT / name).rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.name != '.DS_Store')
    return {str(p.relative_to(ROOT)): sha256(p) for p in sorted(paths)}


def publish_new(source, target):
    """Darwin renamex_np(RENAME_EXCL) is atomic and never replaces a target."""
    if sys.platform != 'darwin':
        raise RuntimeError('Release publication requires macOS')
    libc = ctypes.CDLL(None, use_errno=True)
    rename = libc.renamex_np
    rename.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint]
    rename.restype = ctypes.c_int
    if rename(os.fsencode(source), os.fsencode(target), 0x00000004) != 0:
        code = ctypes.get_errno()
        if code == errno.EEXIST:
            raise FileExistsError(f'Already exists; will not overwrite: {target}')
        raise OSError(code, os.strerror(code), str(target))


if __name__ == '__main__':
    if sys.argv[1:] == ['version']:
        print(version())
    elif sys.argv[1:] == ['fingerprint']:
        print(json.dumps(source_fingerprint(), indent=2, ensure_ascii=False))
    elif len(sys.argv) == 4 and sys.argv[1] == 'publish':
        publish_new(sys.argv[2], sys.argv[3])
    else:
        raise SystemExit('Usage: release_support.py version | fingerprint | publish SOURCE TARGET')
