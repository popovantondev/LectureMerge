# Architektur von LectureMerge

[English](../en/ARCHITECTURE.md) · [Deutsch](ARCHITECTURE.md) · [Русский](../ru/ARCHITECTURE.md)

LectureMerge ist eine native App mit AppKit und SwiftUI. Es gibt keinen Webserver und keine externe API. Die mitgelieferten FFmpeg-Werkzeuge laufen als lokale Unterprozesse.

| Bereich | Aufgabe |
|---|---|
| `Sources/App.swift` | Fenster, Menüs, Warteschlangeneinträge und Exporteinstellungen |
| `Sources/Localization.swift` | Sprachauswahl und lokalisierte Meldungen |
| `Sources/QueueModel.swift` | Import, Projektstatus, Warteschlange, Parallelverarbeitung und Abbruch |
| `Sources/Core.swift` | FFprobe-Analyse, Dateizuordnung, MP4-Muxing, Untertitel, Prüfung und sichere Ausgabe |
| `Sources/Audio.swift` | Audioprofile, AAC/MP3 und Speicherplatzreservierung |
| `Sources/Project.swift` | JSON-Projektformat und Wiederherstellung der Pfade |
| `Resources/*.lproj` | Russische, deutsche und englische App-Texte und Bundle-Metadaten |

FFprobe liest Streams und Zeitachsen. Der Matcher ordnet Begleitdateien anhand des vollständigen Dateinamens zu und prüft den Dateisatz. Exportpläne bestimmen die FFmpeg-Parameter. Nicht unterstützte Kombinationen werden vor der Verarbeitung gemeldet.

Jeder aktive Auftrag besitzt ein eigenes Abbruchsignal. Eine Swift-Taskgruppe verarbeitet höchstens vier Aufträge gleichzeitig. Der Main Actor aktualisiert die Oberfläche; Medienprozesse laufen separat. Gemeinsame Speicherreservierungen berücksichtigen alle aktiven Ausgaben auf demselben Volume.

FFmpeg schreibt zunächst eine temporäre Datei. Nach der Prüfung von Streams, Sprachen, Dauer und Beispieldaten wird die Ausgabe verschoben. Ein exklusives Umbenennen schützt den Kopiermodus vor gleichzeitigem Überschreiben. Kompatibles RU-AAC-LC wird ohne Neukodierung übernommen; eine kurze Vertonung kürzt das Video nicht.

Projektdateien speichern lokale Pfade und Einstellungen, aber keine Mediendateien. Fertige Ausgaben werden nach dem Öffnen erneut geprüft. LectureMerge ist von SRT Voiceover getrennt und übersetzt oder synthetisiert keine Sprache.
