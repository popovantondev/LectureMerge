# Benutzerhandbuch

[Für macOS herunterladen](https://github.com/popovantondev/LectureMerge/releases/tag/v2.1.0) · [Deutsch](README.md) · [Русский](../ru/README.md) · [English](../en/README.md)

LectureMerge ist eine lokale macOS-App, die Lecture-Video, russische Vertonung, Originalton und Untertitel zu einer MP4-Datei zusammenfügt. Audio kann auch separat als AAC oder MP3 exportiert werden. Aktuelle Version: **2.1.0** · macOS 14 oder neuer · Apple Silicon.

## Erster Export

1. Füge einen Vorlesungsordner oder einzelne Video- und Audiodateien hinzu.
2. Wähle einen Eintrag in der Warteschlange und prüfe die zugeordneten Sprach- und Untertiteldateien.
3. Wähle in der russischen Oberfläche **«Видео MP4»** oder **«Только звук»** und lege die Ausgabeoptionen fest.
4. Wähle den Ausgabeordner. Standardmäßig werden fertige Dateien in **Готовое** neben dem jeweiligen Quellvideo gespeichert.
5. Führe zuerst einen **30-Sekunden-Test** aus und prüfe das Ergebnis.

Einträge lassen sich mit Backspace, Delete, der Papierkorb-Schaltfläche oder dem Kontextmenü entfernen. **Очистить очередь** leert nur die Liste; Quelldateien und fertige Exporte bleiben erhalten.

## Video und Audio

Die Videoauflösungen reichen von 144p bis 4K. **Без перекодирования** kopiert kompatibles H.264-Video ohne Qualitätsänderung. **Исходное разрешение** behält die Bildgröße bei; mit der entsprechenden Option kann das Video trotzdem neu codiert werden. Für Größenänderungen nutzt LectureMerge Apples Hardware-Encoder H.264 VideoToolbox.

Kompatible RU-AAC-LC-Vertonung in M4A/MP4 kann ohne erneute Codierung in die MP4-Datei übernommen werden. WAV und inkompatible Audiodateien werden als AAC-LC codiert. Eine kurze Vertonung ist zulässig, wenn sie mit dem letzten RU-Untertitel endet; danach läuft das Video ohne russische Sprache weiter. Die Sprache wird nicht gestreckt.

Der reine Audioexport unterstützt AAC-Kopie, AAC mit 96–256 kbit/s und MP3 mit 128–320 kbit/s. MP3 ist standardmäßig auf 320 kbit/s eingestellt. M4A bewahrt Zeitinformationen für die spätere MP4-Zusammenstellung.

## Projekte und Dateischutz

Über **Проект → Новый проект / Открыть проект… / Сохранить / Сохранить как…** werden Warteschlange und Einstellungen gespeichert. Projektdateien enthalten Verweise auf Quellpfade, aber keine Medien.

LectureMerge arbeitet lokal und benötigt weder Internet noch eine Online-API. Originaldateien bleiben erhalten. Exporte werden zunächst temporär geschrieben und vor dem Verschieben in den Zielordner geprüft. Die App ist ad-hoc signiert und nicht von Apple notarisiert.

## Weitere Informationen

- [Ausführliches russisches Handbuch](../USAGE.md)
- [Build und Tests](../BUILD.md)
- [Prüfung von Version 2.1.0](../VERIFICATION-2.1.0.md)
- [Rechte und zulässige Nutzung](../../RIGHTS.md)
- [Hinweise zu Drittanbieter-Komponenten](../../THIRD_PARTY_NOTICES.md)
