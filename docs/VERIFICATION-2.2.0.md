# Verification — LectureMerge 2.2.0

Date: 2026-09-28 · Apple Silicon · macOS preview build

## Automated checks

- `bash Scripts/check.sh` — passed: project metadata, localization catalog
  parity and format placeholders, fixed app-string coverage, Swift type-check.
- `bash Scripts/test.sh` — passed: integration and v2 suites, including media
  matching, export, AAC handling, queue safety, hardware H.264, stop/error
  cleanup, and preservation of source files.
- `bash Scripts/build.sh --preview` — passed; produced a 2.2.0 preview bundle.
- `codesign --verify --deep --strict --verbose=2 <preview.app>` — passed.
- Bundle contains `ru.lproj`, `de.lproj`, and `en.lproj`; bundle version is
  2.2.0 (build 6).
- The English, German, and Russian screenshots in the matching language guides
  were captured from the running 2.2.0 preview app. The queue was empty.
- `git diff --check` — passed. Local Markdown links are checked again after the
  report and release documents are finalized.

## Scope and limits

The 2.2.0 verification is local. It does not claim GitHub Actions, notarization,
testing on other Macs, Windows, Android devices, or real user lecture files.
The older 2.1.0 release and tag were not modified.
