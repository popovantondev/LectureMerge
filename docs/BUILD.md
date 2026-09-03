# Сборка и проверка

Нужны macOS 14+, Apple Silicon, Apple Command Line Tools/Swift, Python 3,
системные bash, make, clang, codesign, iconutil, ditto и Git.
Все команды выполняются из корня `lecture_merge`.

## Зависимости

В локальной перенесённой папке уже есть `vendor/ffmpeg`, `vendor/ffprobe`
и исходные архивы. Они исключены из Git. После чистого клонирования:

```bash
bash Scripts/build-ffmpeg.sh
```

Сценарий загружает официальные версии из `vendor/dependencies.json`, проверяет
их SHA-256 и собирает pkgconf, статический LAME и FFmpeg с VideoToolbox /
AudioToolbox. Загрузка и сборка нужны только для разработки, не для запуска
готового `.app`. Исходные архивы входят в релиз приложения вместе с лицензиями.

## Быстрые проверки

```bash
bash Scripts/check.sh
bash Scripts/test.sh
```

Первая команда проверяет структуру, VERSION/CHANGELOG, сценарии, имеющиеся
архивы зависимостей и типы Swift. Вторая создаёт собственные короткие медиа
в `build`, выполняет базовые и v2 интеграционные проверки. Использует реальный
FFmpeg и аппаратный кодировщик. Проверка 4K идёт на коротком фрагменте.
Живое окно и реальные устройства этим набором не заменяются.

`bash Scripts/test-v2.sh` запускает только v2-проверки и требует уже созданных
базовым набором файлов. `Tests/Benchmark.swift` предназначен для локальных
измерений на явно подготовленных `build/benchmark-inputs`, а не для CI.

## Сборки

```bash
bash Scripts/build.sh --preview
bash Scripts/build.sh
```

`--preview` всегда создаёт новый каталог в `build/previews`.
Обычная сборка создаёт `dist/v<VERSION>/Сборка лекций 2.app` и BUILD-INFO.json;
повторно использовать существующую папку нельзя. BUILD-INFO связывает приложение
с хешами исходников и его бинарных зависимостей. После компиляции скрипт
проверяет, что исходники не изменились во время сборки, и проверяет подпись.

VERSION — единственный источник номера X.Y.Z. BUILD_NUMBER — номер сборки
macOS, его увеличивают для следующего выпуска. В окне версия читается из Bundle.
Приложение локально подписано ad-hoc. Apple notarization не выполняется.

## Дополнительная проверка реальных лекций

Реальные файлы не включены в Git. Пути задаются явно:

```bash
LECTURE_TEST_FOLDER="/path/to/lectures" bash Scripts/test.sh --real
LECTURE_TEST_VIDEO="/path/to/lecture.mp4" build/integration-tests --full-only
python3 Scripts/check-sync.py SOURCE.mp4 RESULT.mp4 --positions 12 300 600
```

Для этих проверок нужны видео, соответствующие `.ru.siri.voice.wav`, `.ru.srt`
и `.srt`. Укажите моменты с речью: тишина не позволяет измерить корреляцию.
Результат создаётся отдельно в `Тестовые результаты`; исходники не меняются.

Для полной проверки цепочки «формат озвучки → AAC-copy в MP4»:

```bash
xcrun swiftc -swift-version 5 -O -module-cache-path build/module-cache \
  Sources/Core.swift Sources/Audio.swift Sources/Project.swift Tests/FullAAC.swift \
  -o build/full-aac-test
LECTURE_TEST_VIDEO="/path/to/lecture.mp4" build/full-aac-test
```

Это кодирует отдельную тестовую M4A теми же параметрами, что SRT Озвучка,
собирает MP4 и сравнивает SHA-256 сжатого и декодированного русского звука.
