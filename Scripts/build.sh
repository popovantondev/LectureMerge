#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$TASK_ROOT"
if [ "$(uname -m)" != arm64 ]; then echo "Build requires an Apple Silicon Mac." >&2; exit 1; fi
TASK_VERSION="$(python3 Scripts/release_support.py version)"
TASK_BUILD_NUMBER="$(tr -d '\r\n' < BUILD_NUMBER)"
mkdir -p build/module-cache build/previews dist
if [ "${1:-}" = --preview ] && [ "$#" -eq 1 ]; then
    TASK_OUTDIR="$(mktemp -d "$TASK_ROOT/build/previews/$TASK_VERSION.XXXXXX")"
elif [ "$#" -eq 0 ]; then
    if [ -e "releases/v$TASK_VERSION" ]; then echo "Released version is immutable; choose a new VERSION or --preview." >&2; exit 1; fi
    TASK_OUTDIR="$TASK_ROOT/dist/v$TASK_VERSION"
    if ! mkdir "$TASK_OUTDIR"; then echo "Build already exists. Use a new VERSION or --preview; nothing overwritten." >&2; exit 1; fi
else
    echo "Usage: bash Scripts/build.sh [--preview]" >&2; exit 1
fi
TASK_STAGE="$(mktemp -d "$TASK_ROOT/build/.app-stage.XXXXXX")"
TASK_COMPLETE=0
cleanup() {
    rm -rf "$TASK_STAGE"
    if [ "$TASK_COMPLETE" -eq 0 ]; then rmdir "$TASK_OUTDIR" 2>/dev/null || true; fi
}
trap cleanup EXIT
APP="$TASK_STAGE/Сборка лекций 2.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/bin" "$APP/Contents/Resources/Licenses"
for language in ru de en; do
    mkdir -p "$APP/Contents/Resources/$language.lproj"
    cp "Resources/$language.lproj/"*.strings "$APP/Contents/Resources/$language.lproj/"
done
for tool in ffmpeg ffprobe; do
    if [ ! -x "vendor/$tool" ]; then
        echo "Не найден vendor/$tool. Сначала выполните Scripts/build-ffmpeg.sh"
        exit 1
    fi
done
xcrun swiftc -swift-version 5 -module-cache-path "$TASK_ROOT/build/module-cache" Scripts/MakeIcon.swift -o build/MakeIcon
build/MakeIcon "$TASK_ROOT"
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
python3 Scripts/release_support.py fingerprint > "$TASK_STAGE/source-fingerprint.json"
xcrun swiftc -swift-version 5 -O -target arm64-apple-macosx14.0 \
    -module-cache-path "$TASK_ROOT/build/module-cache" \
    -framework AppKit -framework SwiftUI -framework UniformTypeIdentifiers \
    Sources/*.swift -o "$APP/Contents/MacOS/LectureAssembler2"
cp vendor/ffmpeg vendor/ffprobe "$APP/Contents/Resources/bin/"
cp vendor/COPYING.LGPLv2.1 vendor/NOTICE.md "$APP/Contents/Resources/Licenses/"
cp vendor/ffmpeg-9.0.1.tar.xz "$APP/Contents/Resources/Licenses/"
cp Scripts/build-ffmpeg.sh "$APP/Contents/Resources/Licenses/"
cp vendor/lame-4.0.tar.gz vendor/LAME-COPYING vendor/LAME-LICENSE "$APP/Contents/Resources/Licenses/"
cp vendor/pkgconf-2.5.1.tar.xz "$APP/Contents/Resources/Licenses/"
cp vendor/dependencies.json "$APP/Contents/Resources/Licenses/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>LectureAssembler2</string>
<key>CFBundleIdentifier</key><string>local.olya.lecture-assembler.v2</string>
<key>CFBundleName</key><string>LectureMerge</string>
<key>CFBundleDisplayName</key><string>LectureMerge</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>2.0</string>
<key>CFBundleVersion</key><string>2</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>ru</string><string>de</string><string>en</string></array>
<key>UTExportedTypeDeclarations</key><array><dict>
<key>UTTypeIdentifier</key><string>local.olya.lecture-project</string>
<key>UTTypeDescription</key><string>Проект сборки лекций</string>
<key>UTTypeConformsTo</key><array><string>public.json</string></array>
<key>UTTypeTagSpecification</key><dict><key>public.filename-extension</key><array><string>olyalecture</string></array></dict>
</dict></array>
<key>CFBundleDocumentTypes</key><array><dict>
<key>CFBundleTypeName</key><string>Проект сборки лекций</string>
<key>CFBundleTypeRole</key><string>Editor</string>
<key>LSItemContentTypes</key><array><string>local.olya.lecture-project</string></array>
<key>LSHandlerRank</key><string>Owner</string>
<key>CFBundleTypeIconFile</key><string>AppIcon</string>
</dict></array>
</dict></plist>
PLIST
python3 - "$APP/Contents/Info.plist" "$TASK_VERSION" "$TASK_BUILD_NUMBER" <<'PLIST_VERSION'
from pathlib import Path
import plistlib, sys
p = Path(sys.argv[1]); data = plistlib.loads(p.read_bytes())
data['CFBundleShortVersionString'] = sys.argv[2]
data['CFBundleVersion'] = sys.argv[3]
p.write_bytes(plistlib.dumps(data))
PLIST_VERSION
codesign --force --sign - "$APP/Contents/Resources/bin/ffmpeg"
codesign --force --sign - "$APP/Contents/Resources/bin/ffprobe"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
python3 - "$TASK_STAGE/source-fingerprint.json" "$APP" "$TASK_STAGE/BUILD-INFO.json" <<'BUILD_INFO'
from pathlib import Path
import json, subprocess, sys
sys.path.insert(0, 'Scripts')
from release_support import source_fingerprint, sha256, version
before=json.loads(Path(sys.argv[1]).read_text())
if before != source_fingerprint(): raise SystemExit('Source changed during compilation; build not published.')
app=Path(sys.argv[2])
p=subprocess.run(['git','rev-parse','HEAD'],text=True,capture_output=True)
info={'version':version(),'gitCommit':p.stdout.strip() if p.returncode==0 else None,
      'sourceFiles':before,'bundledCodecs':{t:sha256(app/'Contents/Resources/bin'/t) for t in ['ffmpeg','ffprobe']}}
Path(sys.argv[3]).write_text(json.dumps(info,indent=2,ensure_ascii=False)+'\n')
BUILD_INFO
python3 Scripts/release_support.py publish "$APP" "$TASK_OUTDIR/Сборка лекций 2.app"
cp "$TASK_STAGE/BUILD-INFO.json" "$TASK_OUTDIR/BUILD-INFO.json"
TASK_COMPLETE=1
echo "Приложение собрано: $TASK_OUTDIR/Сборка лекций 2.app"
