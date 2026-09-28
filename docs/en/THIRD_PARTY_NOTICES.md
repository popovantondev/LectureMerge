# Third-party notices

[English](THIRD_PARTY_NOTICES.md) · [Deutsch](../de/THIRD_PARTY_NOTICES.md) · [Русский](../ru/THIRD_PARTY_NOTICES.md)

| Component | Version | Purpose | License |
|---|---|---|---|
| FFmpeg / FFprobe | 9.0.1 | Media analysis, video, audio, and containers | LGPL 2.1+ for this build |
| LAME | 4.0 | MP3 encoding | LGPL; see `vendor/LAME-COPYING` |
| pkgconf | 2.5.1 | Build tool only | License texts are included in the source archive |
| Apple AppKit / SwiftUI / VideoToolbox / AudioToolbox | System | Interface and hardware encoding | macOS components |
| SF Symbols | System | `play.rectangle.on.rectangle.fill` symbol | Apple's SF Symbols terms |

Official archive URLs and pinned SHA-256 hashes are listed in [`vendor/dependencies.json`](../../vendor/dependencies.json). Build and license details are in [`vendor/NOTICE.md`](../../vendor/NOTICE.md). Unmodified codec source archives and license texts are included in the app bundle. FFmpeg runs locally and does not use the network.

The owner has not granted an open-source license for LectureMerge's original code. This notice does not grant additional rights to the code, Apple symbols, or third-party components.
