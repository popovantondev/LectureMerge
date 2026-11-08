<!-- ppk-readme:head:start -->
<a href="https://popovantondev.github.io/LectureMerge/index-en.html"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/popovantondev/LectureMerge/main/docs/readme/header-en-dark.5fab5b88.svg"><img src="https://raw.githubusercontent.com/popovantondev/LectureMerge/main/docs/readme/header-en-light.11febc0d.svg" width="880" height="188" alt="LectureMerge — Combines lecture video, narration and subtitles into MP4. macOS 14+ · Apple Silicon, Release 2.2.0"></picture></a>
<!-- ppk-readme:head:end -->

# LectureMerge

[Русский](README.ru.md) · [Deutsch](README.md) · **English**

<!-- ppk-readme:body:start -->
<p>
<a href="https://github.com/popovantondev/LectureMerge/releases/tag/v2.2.0"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/popovantondev/LectureMerge/main/docs/readme/btn-download-en-dark.079d1097.svg"><img src="https://raw.githubusercontent.com/popovantondev/LectureMerge/main/docs/readme/btn-download-en-light.c188d95a.svg" width="136" height="36" alt="Download"></picture></a>
<a href="https://popovantondev.github.io/LectureMerge/index-en.html"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/popovantondev/LectureMerge/main/docs/readme/btn-website-en-dark.b3908e5a.svg"><img src="https://raw.githubusercontent.com/popovantondev/LectureMerge/main/docs/readme/btn-website-en-light.d49a72ea.svg" width="120" height="36" alt="Website"></picture></a>
<a href="https://popovantondev.github.io/LectureMerge/Guide-en.html"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/popovantondev/LectureMerge/main/docs/readme/btn-guide-en-dark.93174834.svg"><img src="https://raw.githubusercontent.com/popovantondev/LectureMerge/main/docs/readme/btn-guide-en-light.399a30a6.svg" width="141" height="36" alt="User guide"></picture></a>
<a href="https://github.com/popovantondev/LectureMerge/issues/new/choose"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/popovantondev/LectureMerge/main/docs/readme/btn-bug-en-dark.2586aa78.svg"><img src="https://raw.githubusercontent.com/popovantondev/LectureMerge/main/docs/readme/btn-bug-en-light.e855170a.svg" width="196" height="36" alt="Report a problem"></picture></a>
</p>

<p><a href="https://raw.githubusercontent.com/popovantondev/LectureMerge/main/docs/en/screenshots/main.png"><picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/popovantondev/LectureMerge/main/docs/readme/preview-en-dark.b4e317b8.webp"><img src="https://raw.githubusercontent.com/popovantondev/LectureMerge/main/docs/readme/preview-en-light.e23321d9.webp" width="880" height="516" alt="LectureMerge interface"></picture></a><br>
<sub><a href="https://raw.githubusercontent.com/popovantondev/LectureMerge/main/docs/en/screenshots/main.png">Full screenshot</a></sub></p>

<picture><source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/popovantondev/LectureMerge/main/docs/readme/divider-dark.fbb5c3a2.svg"><img src="https://raw.githubusercontent.com/popovantondev/LectureMerge/main/docs/readme/divider-light.8825eba3.svg" width="880" height="6" alt="Divider"></picture>
<!-- ppk-readme:body:end -->

<!-- public-release:start -->
Combine lecture video, narration, original audio and subtitles into MP4, or export audio.

**macOS 14+ · Apple Silicon · Release 2.2.0**

**[Download](https://github.com/popovantondev/LectureMerge/releases/tag/v2.2.0)** · **[User guide](https://popovantondev.github.io/LectureMerge/Guide-en.html)** · **[Report a problem](https://github.com/popovantondev/LectureMerge/issues/new/choose)**

**Requirements and limitations:** Local processing without an external service. Ad-hoc signed and not notarized by Apple.

**First steps:** Extract the app archive and add video, audio and subtitles. Check a 30-second sample before the full export.

**Application files:**

- [`LectureMerge-v2.2.0-macos-arm64.zip`](https://github.com/popovantondev/LectureMerge/releases/download/v2.2.0/LectureMerge-v2.2.0-macos-arm64.zip)

**Checksums:** [`SHA256SUMS`](https://github.com/popovantondev/LectureMerge/releases/download/v2.2.0/SHA256SUMS)
<!-- public-release:end -->

LectureMerge combines lecture video, Russian narration, original audio, and subtitles in one MP4 file. It can also export audio as AAC or MP3. The app works locally on your Mac and does not require an internet connection or an online API.

## Features

- Switch the interface between Russian, German, and English. The choice is saved for later launches.
- Create MP4 files with H.264 video, AAC audio, and switchable Russian and German subtitles.
- Copy compatible AAC-LC narration without re-encoding.
- Keep the original German audio as a separate track.
- Resize from 144p to 4K, preserve the original dimensions, or copy compatible H.264 without re-encoding.
- Export AAC or MP3 audio, including AAC copy mode and MP3 up to 320 kbit/s.
- Process up to four queue items at once, save projects, and run a 30-second test before a full export.

## Download

Version 2.2.0 is available from the [GitHub Releases page](https://github.com/popovantondev/LectureMerge/releases/tag/v2.2.0). Release packages include the app, source archive, manifest, checksums, and third-party notices.

The app supports Apple Silicon Macs running macOS 14 or later. It is ad-hoc signed and is not notarized by Apple. Start with the guide for your interface language: [English](docs/en/README.md) · [Deutsch](docs/de/README.md) · [Русский](docs/ru/README.md).

## Documentation

- User guides with a screenshot in the matching interface language: [English](docs/en/README.md), [Deutsch](docs/de/README.md), [Русский](docs/ru/README.md)
- Build and test: [EN](docs/en/BUILD.md) · [DE](docs/de/BUILD.md) · [RU](docs/ru/BUILD.md)
- Architecture: [EN](docs/en/ARCHITECTURE.md) · [DE](docs/de/ARCHITECTURE.md) · [RU](docs/ru/ARCHITECTURE.md)
- Rights: [EN](docs/en/RIGHTS.md) · [DE](docs/de/RIGHTS.md) · [RU](docs/ru/RIGHTS.md)
- Third-party notices: [EN](docs/en/THIRD_PARTY_NOTICES.md) · [DE](docs/de/THIRD_PARTY_NOTICES.md) · [RU](docs/ru/THIRD_PARTY_NOTICES.md)
- Changelog: [EN](docs/en/CHANGELOG.md) · [DE](docs/de/CHANGELOG.md) · [RU](docs/ru/CHANGELOG.md)

## Build from source

On an Apple Silicon Mac with Apple Command Line Tools installed:

```bash
bash Scripts/check.sh
bash Scripts/test.sh
bash Scripts/build.sh --preview
```

See the guide in your language for build requirements and verification details. CI checks project metadata and Swift types on macOS; hardware media encoding is verified locally.

## Rights and third-party software

The original source code is published for public viewing only; no open-source license is granted. Individuals may download and run an unmodified release binary for personal use. Read the notices in [English](docs/en/RIGHTS.md) · [Deutsch](docs/de/RIGHTS.md) · [Русский](docs/ru/RIGHTS.md), and the [third-party notices](docs/en/THIRD_PARTY_NOTICES.md). The licenses for bundled components continue to apply to those components.

## Feedback

Bug reports and suggestions are welcome in English, German, or Russian through [GitHub Issues](https://github.com/popovantondev/LectureMerge/issues/new/choose). Include the app and macOS versions; remove personal paths, lecture files, and subtitle text from reports.
