# Build and test LectureMerge

[English](BUILD.md) · [Deutsch](../de/BUILD.md) · [Русский](../ru/BUILD.md)

## Requirements

Use a Mac with Apple Silicon, macOS 14 or later, Apple Command Line Tools, Swift, Python 3, Git, and the standard macOS build tools. Run commands from the repository root.

## Prepare the bundled media tools

The app bundles FFmpeg, FFprobe, and LAME. These third-party binaries are excluded from Git. On a clean checkout, run:

```bash
bash Scripts/build-ffmpeg.sh
```

The script downloads the pinned upstream source archives listed in `vendor/dependencies.json`, verifies their SHA-256 hashes, and builds the local tools. This is needed for development and app packaging, not for running an already built app.

## Checks and tests

```bash
bash Scripts/check.sh
bash Scripts/test.sh
```

The first command checks project metadata, localization resources, scripts, and Swift types. The second creates short synthetic media in the ignored build directory and exercises MP4, SRT, AAC, MP3, project, queue, and cancellation behavior with FFmpeg and the hardware encoder. These checks do not replace a review in the live app or testing on real devices.

## Preview and release builds

```bash
bash Scripts/build.sh --preview
bash Scripts/build.sh
```

A preview always uses a new directory under `build/previews`. A release build creates `dist/v<VERSION>` and refuses to overwrite an existing release. The script bundles all three interface languages, embeds dependency notices, checks the source fingerprint, and verifies the ad-hoc signature. The app is not notarized by Apple.

To launch a preview in a chosen language for screenshot review, set `LECTURE_MERGE_LANGUAGE` to `en`, `de`, or `ru` for that process. This override does not change the saved preference in the app.
