# Hinweise zu Drittanbieter-Komponenten

[English](../en/THIRD_PARTY_NOTICES.md) · [Deutsch](THIRD_PARTY_NOTICES.md) · [Русский](../ru/THIRD_PARTY_NOTICES.md)

| Komponente | Version | Zweck | Lizenz |
|---|---|---|---|
| FFmpeg / FFprobe | 9.0.1 | Medienanalyse, Video, Audio und Container | Für diesen Build: LGPL 2.1+ |
| LAME | 4.0 | MP3-Codierung | LGPL; siehe `vendor/LAME-COPYING` |
| pkgconf | 2.5.1 | Nur Build-Werkzeug | Lizenztexte sind im Quellarchiv enthalten |
| Apple AppKit / SwiftUI / VideoToolbox / AudioToolbox | System | Oberfläche und Hardwarecodierung | macOS-Komponenten |
| SF Symbols | System | Symbol `play.rectangle.on.rectangle.fill` | Apple-Bedingungen für SF Symbols |

Offizielle Archiv-URLs und festgelegte SHA-256-Prüfsummen stehen in [`vendor/dependencies.json`](../../vendor/dependencies.json). Hinweise zu Build und Lizenzen enthält [`vendor/NOTICE.md`](../../vendor/NOTICE.md). Unveränderte Codec-Quellarchive und Lizenztexte sind im App-Bundle enthalten. FFmpeg läuft lokal und verwendet kein Netzwerk.

Der Eigentümer hat für den Originalcode von LectureMerge keine Open-Source-Lizenz erteilt. Dieser Hinweis gewährt keine zusätzlichen Rechte am Code, an Apple-Symbolen oder an Drittanbieter-Komponenten.
