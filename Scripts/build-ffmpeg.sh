#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TASK_BUILD="$(mktemp -d /tmp/olya-codecs.XXXXXX)"
trap 'rm -rf "$TASK_BUILD"' EXIT
mkdir -p "$TASK_ROOT/vendor" "$TASK_ROOT/build"
fetch() { if [ ! -f "$2" ]; then curl -fL --retry 2 "$1" -o "$2"; fi; }
fetch https://ffmpeg.org/releases/ffmpeg-9.0.1.tar.xz "$TASK_ROOT/vendor/ffmpeg-9.0.1.tar.xz"
fetch https://downloads.sourceforge.net/project/lame/lame/4.0/lame-4.0.tar.gz "$TASK_ROOT/vendor/lame-4.0.tar.gz"
fetch https://distfiles.ariadne.space/pkgconf/pkgconf-2.5.1.tar.xz "$TASK_ROOT/vendor/pkgconf-2.5.1.tar.xz"
python3 - "$TASK_ROOT" <<'VERIFY_ARCHIVES'
import json, pathlib, hashlib, sys
root=pathlib.Path(sys.argv[1])
for name, info in json.loads((root/'vendor/dependencies.json').read_text()).items():
    if hashlib.sha256((root/'vendor'/name).read_bytes()).hexdigest()!=info['sha256']:
        raise SystemExit('Archive checksum mismatch: '+name)
VERIFY_ARCHIVES
for archive in "$TASK_ROOT/vendor/ffmpeg-9.0.1.tar.xz" "$TASK_ROOT/vendor/lame-4.0.tar.gz" "$TASK_ROOT/vendor/pkgconf-2.5.1.tar.xz"; do tar -xf "$archive" -C "$TASK_BUILD"; done
cd "$TASK_BUILD/pkgconf-2.5.1"
./configure --prefix="$TASK_BUILD/prefix" --disable-shared
make -j8
make install
cd "$TASK_BUILD/lame-4.0"
PKG_CONFIG="$TASK_BUILD/prefix/bin/pkgconf" ./configure --prefix="$TASK_BUILD/prefix" --disable-shared --enable-static --disable-frontend --disable-decoder
make -j8
make install
cp COPYING "$TASK_ROOT/vendor/LAME-COPYING"
cp LICENSE "$TASK_ROOT/vendor/LAME-LICENSE"
cd "$TASK_BUILD/ffmpeg-9.0.1"
./configure --disable-doc --disable-ffplay --disable-debug --disable-autodetect --disable-network --enable-videotoolbox --enable-audiotoolbox --enable-libmp3lame --extra-cflags="-I$TASK_BUILD/prefix/include" --extra-ldflags="-L$TASK_BUILD/prefix/lib"
make -j8 ffmpeg ffprobe
cp ffmpeg ffprobe COPYING.LGPLv2.1 "$TASK_ROOT/vendor/"
cd "$TASK_ROOT"
shasum -a 256 vendor/*.tar.* vendor/ffmpeg vendor/ffprobe > vendor/SHA256SUMS.local
