# LectureMerge erstellen und testen

[English](../en/BUILD.md) · [Deutsch](BUILD.md) · [Русский](../ru/BUILD.md)

## Voraussetzungen

Benötigt werden ein Mac mit Apple Silicon, macOS 14 oder neuer, Apple Command Line Tools, Swift, Python 3, Git und die üblichen macOS-Buildwerkzeuge. Führen Sie alle Befehle im Stammverzeichnis des Repositories aus.

## Medienwerkzeuge vorbereiten

Die App enthält FFmpeg, FFprobe und LAME. Diese Fremdkomponenten sind von Git ausgeschlossen. Nach einem frischen Checkout:

```bash
bash Scripts/build-ffmpeg.sh
```

Das Skript lädt die in `vendor/dependencies.json` festgelegten Originalarchive herunter, prüft ihre SHA-256-Prüfsummen und erstellt die lokalen Werkzeuge. Das ist für Entwicklung und App-Pakete nötig, nicht zum Starten einer bereits erstellten App.

## Prüfungen und Tests

```bash
bash Scripts/check.sh
bash Scripts/test.sh
```

Der erste Befehl prüft Projektmetadaten, Sprachressourcen, Skripte und Swift-Typen. Der zweite erstellt kurze künstliche Mediendateien im ignorierten Build-Ordner und prüft MP4, SRT, AAC, MP3, Projekte, Warteschlange und Abbruch mit FFmpeg und dem Hardware-Encoder. Diese Prüfungen ersetzen weder den Test im laufenden Fenster noch Tests auf echten Geräten.

## Vorschau und Release

```bash
bash Scripts/build.sh --preview
bash Scripts/build.sh
```

Eine Vorschau erhält immer einen neuen Ordner unter `build/previews`. Ein Release erstellt `dist/v<VERSION>` und überschreibt keinen vorhandenen Release-Ordner. Das Skript bündelt alle drei Oberflächensprachen und die Lizenzhinweise, prüft den Quellcode-Fingerabdruck und die ad-hoc-Signatur. Apple-Notarisierung erfolgt nicht.

Für einen Sprachtest kann eine Vorschau mit `LECTURE_MERGE_LANGUAGE=en`, `de` oder `ru` gestartet werden. Diese Prozessvariable ändert nicht die in der App gespeicherte Sprachauswahl.
