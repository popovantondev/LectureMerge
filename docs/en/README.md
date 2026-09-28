# User guide

[Download for macOS](https://github.com/popovantondev/LectureMerge/releases/tag/v2.1.0) · [Deutsch](../de/README.md) · [Русский](../ru/README.md) · [English](README.md)

LectureMerge is a local macOS app for combining lecture video, Russian narration, original audio, and subtitles into an MP4. It can also export audio as AAC or MP3. Current release: **2.1.0** · macOS 14+ · Apple Silicon.

## First export

1. Add a folder of lectures or select video/audio files.
2. Select a queue row and review the matched narration and subtitle tracks.
3. In the Russian interface, choose **«Видео MP4»** or **«Только звук»** and set the output options.
4. Choose an output folder. By default, finished files go into a **Готовое** folder beside each source video.
5. Run **30-second test** and check the result before starting the full queue.

Remove a row with Backspace, Delete, the trash button, or its context menu. **Очистить очередь** clears the list only; it does not remove source files or completed exports.

## Video and audio

Video presets range from 144p to 4K. **Без перекодирования** copies compatible H.264 video without changing its quality. **Исходное разрешение** keeps the frame dimensions; it can still re-encode when the matching option is enabled. Resizing uses Apple's hardware H.264 VideoToolbox encoder.

Compatible RU AAC-LC narration in M4A/MP4 can be copied into the MP4 without re-encoding. WAV and incompatible audio are encoded as AAC-LC. Short narration is allowed when it ends at the last RU subtitle; the remaining video plays without Russian narration. Speech is not stretched.

Audio-only export supports AAC copy, AAC at 96–256 kbit/s, and MP3 at 128–320 kbit/s. MP3 defaults to 320 kbit/s. M4A is convenient for later MP4 assembly because it preserves audio timing metadata.

## Projects and safety

Use **Проект → Новый проект / Открыть проект… / Сохранить / Сохранить как…** to store queue settings. Project files refer to source paths; they do not contain or copy the media.

LectureMerge works locally and does not need an internet connection or online API. It keeps the original files, writes exports to temporary files, and checks outputs before placing them in the destination. The app is ad-hoc signed and not notarized by Apple.

## More information

- [Detailed Russian manual](../USAGE.md)
- [Build and tests](../BUILD.md)
- [Release verification](../VERIFICATION-2.1.0.md)
- [Rights and permitted use](../../RIGHTS.md)
- [Third-party notices](../../THIRD_PARTY_NOTICES.md)
