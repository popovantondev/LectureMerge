# FFmpeg, FFprobe и LAME

FFmpeg / FFprobe 9.0.1: https://ffmpeg.org/ — исходный архив
https://ffmpeg.org/releases/ffmpeg-9.0.1.tar.xz.

Для MP3 используется LAME 4.0: https://lame.sourceforge.io/ — исходный архив
https://downloads.sourceforge.net/project/lame/lame/4.0/lame-4.0.tar.gz.
LAME собран статически и включён в отдельные процессы FFmpeg / FFprobe.
Приложение вызывает их через Foundation.Process. Исходники кодеков не изменялись.
FFmpeg собран с VideoToolbox, AudioToolbox и libmp3lame; сеть, GPL, nonfree
и автоматическое подключение прочих сторонних библиотек отключены.

Лицензия FFmpeg — LGPL 2.1 или новее (COPYING.LGPLv2.1).
Лицензия LAME — LGPL; полные тексты сохранены в LAME-COPYING и LAME-LICENSE.
Архивы полного соответствующего исходного кода, лицензии и скрипт пересборки
включены в приложение Contents/Resources/Licenses и находятся в vendor проекта.
Бинарные файлы можно заменить своей совместимой сборкой. Для пересборки из
ресурсов приложения разместите архивы в vendor, скрипт в Scripts и запустите его.

pkgconf 2.5.1 используется только при сборке LAME, в исполняемый код приложения
не включён. Его неизменённый архив с лицензиями также сохранён для пересборки:
https://distfiles.ariadne.space/pkgconf/pkgconf-2.5.1.tar.xz.

SHA256SUMS.local содержит локальные хеши полученных архивов и бинарных файлов,
это не независимая проверка подписи издателей. Компоненты Subtitle Edit
не копировались и не изменялись.
