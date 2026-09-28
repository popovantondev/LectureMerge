# LectureMerge

[Download for macOS](https://github.com/popovantondev/LectureMerge/releases/tag/v2.1.0) · [Deutsch](docs/de/README.md) · [Русский](docs/ru/README.md) · [English](docs/en/README.md)

<img src="Assets/AppIcon-1024.png" width="128" alt="LectureMerge app icon">

**macOS 14 or later · Apple Silicon · Version 2.1.0**

LectureMerge combines a video, Russian narration, the original audio, and subtitles into one MP4 lecture. It also exports AAC or MP3 audio on its own. Processing is local; the app does not need an internet connection or an online API.

## What it does

- Create MP4 files with H.264 video, AAC audio, and switchable Russian and German subtitles.
- Copy compatible AAC-LC narration into the MP4 without re-encoding.
- Keep the original German audio as a separate track.
- Resize video from 144p to 4K, preserve the original dimensions, or copy compatible H.264 without re-encoding.
- Export AAC or MP3 audio, including AAC copy mode and MP3 up to 320 kbit/s.
- Process a queue of up to four files, save projects, and run a 30-second test before the full export.

## Download

The current local release is **2.1.0**. The GitHub repository and release page are being prepared; the download link above will work after the repository and release are published. Release archives include the app, source archive, manifest, checksums, and third-party notices.

The app is built for Apple Silicon Macs running macOS 14 or later. Builds are ad-hoc signed and are not notarized by Apple. See the [Russian user guide](docs/USAGE.md) for current installation and first-run details.

## Quick start

1. Add a folder of lectures or select video and audio files.
2. Choose a lecture and check the matched narration and subtitle files.
3. In the Russian interface, choose **«Видео MP4»** or **«Только звук»** and set the output options.
4. Run **30-second test**, review the result, then start the queue.

The app keeps original files. It writes to a temporary output and checks the result before publishing it to the destination folder.

## Documentation

- [English guide](docs/en/README.md)
- [German guide](docs/de/README.md)
- [Russian guide](docs/ru/README.md) and [detailed Russian manual](docs/USAGE.md)
- [Build and tests](docs/BUILD.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Changelog](CHANGELOG.md)
- [Release verification](docs/VERIFICATION-2.1.0.md)
- [GitHub preparation and release process](docs/GITHUB.md)
- [Third-party notices](THIRD_PARTY_NOTICES.md)
- [Rights and permitted use](RIGHTS.md)

## Build from source

On a Mac with Apple Command Line Tools installed:

```bash
bash Scripts/check.sh
bash Scripts/test.sh
bash Scripts/build.sh --preview
```

See [Build and tests](docs/BUILD.md) and [versioning](docs/VERSIONING.md) before making a release. The CI workflow checks project metadata and Swift types on macOS; hardware encoding checks remain local.

## Feedback

Bug reports and feature suggestions are welcome in English, German, or Russian through the repository's GitHub Issues after publication. Please include the app version and macOS version, and remove personal paths, lecture files, and subtitle text from reports.

## Rights and third-party software

The project owner's source code is published for public viewing only; no open-source license is granted. Individuals may download and run an unmodified release binary for personal use. See [RIGHTS.md](RIGHTS.md) and [third-party notices](THIRD_PARTY_NOTICES.md). Licenses for bundled components continue to apply to those components.
