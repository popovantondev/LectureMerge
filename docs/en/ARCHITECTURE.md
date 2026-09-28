# LectureMerge architecture

[English](ARCHITECTURE.md) · [Deutsch](../de/ARCHITECTURE.md) · [Русский](../ru/ARCHITECTURE.md)

LectureMerge is a native AppKit and SwiftUI app. It has no web server or external API. The bundled FFmpeg tools run as local child processes.

| Area | Responsibility |
|---|---|
| `Sources/App.swift` | Window, menus, queue rows, and export settings |
| `Sources/Localization.swift` | Language preference and localized message lookup |
| `Sources/QueueModel.swift` | Import, project state, queue, parallelism, and cancellation |
| `Sources/Core.swift` | FFprobe analysis, file matching, MP4 muxing, subtitles, verification, and safe output |
| `Sources/Audio.swift` | Audio export profiles, AAC/MP3, and disk space reservations |
| `Sources/Project.swift` | JSON project format and path restoration |
| `Resources/*.lproj` | Russian, German, and English app strings and bundle metadata |

FFprobe reads media streams and timelines. The matcher finds companion files by the complete filename and checks the set. Export plans select FFmpeg arguments. Unsupported combinations are reported before processing.

Each active job has its own cancellation token. A Swift task group runs at most four jobs. The main actor updates the interface; media processes run separately. Shared disk reservations account for all active exports on the same volume.

FFmpeg writes a temporary output. After stream, language, duration, and sample-decoding checks pass, the output is moved into place. Exclusive rename protects copy mode from overwriting a concurrent result. Compatible RU AAC-LC is copied without re-encoding; short narration does not truncate the video.

Project files store local paths and settings, not media. Restored completed results are verified again. LectureMerge is separate from SRT Voiceover and does not translate or synthesize speech.
