#!/usr/bin/env python3
"""Create a local immutable release from a clean, committed working tree."""
import datetime
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import zipfile
from release_support import ROOT, version, sha256, source_fingerprint, publish_new


def run(*args):
    return subprocess.check_output(args, cwd=ROOT, text=True).strip()


def main():
    number = version()
    tag = 'v' + number
    releases = ROOT / 'releases'
    releases.mkdir(exist_ok=True)
    target = releases / tag
    if target.exists() or target.is_symlink():
        raise SystemExit(f'Release {tag} already exists. Choose a NEW version; nothing was changed.')
    if run('git', 'status', '--porcelain'):
        raise SystemExit('Commit the source and documentation changes before creating a release.')
    if run('git', 'tag', '--list', tag):
        raise SystemExit(f'Tag {tag} already exists. Tags are never moved or replaced.')
    commit = run('git', 'rev-parse', 'HEAD')
    app = ROOT / 'dist' / tag / 'Сборка лекций 2.app'
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    if info['CFBundleShortVersionString'] != number:
        raise SystemExit('Application version does not match VERSION. Build the new version first.')
    if (ROOT / 'BUILD_NUMBER').read_text().strip() != info['CFBundleVersion']:
        raise SystemExit('Application build number does not match BUILD_NUMBER.')
    build = json.loads((app.parent / 'BUILD-INFO.json').read_text())
    if build['sourceFiles'] != source_fingerprint():
        raise SystemExit('Sources changed after the build. Build a fresh preview or a NEW release version.')
    for tool, digest in build['bundledCodecs'].items():
        if sha256(app / 'Contents/Resources/bin' / tool) != digest:
            raise SystemExit(f'Bundled {tool} changed after the build.')
    run('codesign', '--verify', '--deep', '--strict', str(app))
    lock = releases / ('.' + tag + '.lock')
    lock.mkdir()  # One release process per version.
    try:
        with tempfile.TemporaryDirectory(prefix='.' + tag + '-', dir=releases) as tmp:
            stage = Path(tmp)
            app_zip = stage / f'LectureMerge-{tag}-macos-arm64.zip'
            source_zip = stage / f'LectureMerge-{tag}-source.zip'
            run('ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', str(app), str(app_zip))
            run('git', 'archive', '--format=zip', f'--prefix=LectureMerge-{number}/', '-o', str(source_zip), commit)
            for archive in [app_zip, source_zip]:
                with zipfile.ZipFile(archive) as z:
                    bad = z.testzip()
                    if bad:
                        raise RuntimeError(f'Corrupt archive member: {bad}')
            manifest = {
                'project': 'LectureMerge', 'version': number, 'gitCommit': commit,
                'builtFromCommit': build.get('gitCommit'),
                'createdUTC': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                'platform': 'macOS 14+ / Apple Silicon', 'application': app.name,
                'sourceFiles': build['sourceFiles'], 'bundledCodecs': build['bundledCodecs'],
                'artifacts': {p.name: {'sha256': sha256(p), 'bytes': p.stat().st_size} for p in [app_zip, source_zip]},
            }
            (stage / 'manifest.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + '\n')
            (stage / 'RELEASE.md').write_text(
                f'# LectureMerge {tag}\n\nSource commit: `{commit}`.\n\n'
                f'- `{app_zip.name}` — самостоятельное приложение, macOS 14+, Apple Silicon.\n'
                f'- `{source_zip.name}` — исходники этого коммита, документация и сценарии сборки.\n'
                '- `manifest.json` — версия, коммит, состав исходников и хеши бинарных зависимостей.\n'
                '- `SHA256SUMS` — проверка: `shasum -a 256 -c SHA256SUMS`.\n\n'
                'Распакуйте приложение в отдельную папку. Локальная подпись ad-hoc; '
                'не нотарифицировано. Копирование на GitHub этой командой не выполняется.\n\n'
                'История изменений: CHANGELOG.md в архиве исходников. '
                'Новые изменения выпускаются с новым номером; этот каталог не изменять.\n'
            )
            (stage / 'SHA256SUMS').write_text(''.join(f'{sha256(p)}  {p.name}\n' for p in sorted(stage.iterdir()) if p.is_file()))
            # Create an immutable tag only after every artifact has been built and checked.
            run('git', 'tag', '-a', tag, '-m', f'LectureMerge {tag}')
            publish_new(stage, target)
        print(f'Created {tag}: {target}\nCommit: {commit}')
    finally:
        lock.rmdir()


if __name__ == '__main__':
    main()
