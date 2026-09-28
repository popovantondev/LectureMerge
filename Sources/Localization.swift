import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case russian = "ru"
    case german = "de"
    case english = "en"

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }
    var nativeName: String {
        switch self {
        case .russian: "Русский"
        case .german: "Deutsch"
        case .english: "English"
        }
    }

    static var preferred: AppLanguage {
        if let override = ProcessInfo.processInfo.environment["LECTURE_MERGE_LANGUAGE"], let language = AppLanguage(rawValue: override) {
            return language
        }
        if let saved = UserDefaults.standard.string(forKey: "appLanguage"), let language = AppLanguage(rawValue: saved) {
            return language
        }
        let preferredCode = Locale.preferredLanguages.first.map { String($0.prefix(2)) } ?? "ru"
        return AppLanguage(rawValue: preferredCode) ?? .russian
    }
}

func localized(_ russianKey: String, language: AppLanguage = AppLanguage.preferred) -> String {
    guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
          let bundle = Bundle(path: path) else { return russianKey }
    return bundle.localizedString(forKey: russianKey, value: russianKey, table: nil)
}

func localizedFormat(_ russianFormat: String, language: AppLanguage = AppLanguage.preferred, _ arguments: CVarArg...) -> String {
    String(format: localized(russianFormat, language: language), locale: language.locale, arguments: arguments)
}

func localizedUserText(_ text: String, language: AppLanguage) -> String {
    let exact = localized(text, language: language)
    guard exact == text, language != .russian else { return exact }
    let phrases: [(String, String, String)] = [
        ("Остановлено пользователем", "Stopped by the user", "Vom Benutzer angehalten"),
        ("Не удалось проверить свободное место.", "Could not check available disk space.", "Der verfügbare Speicherplatz konnte nicht geprüft werden."),
        ("Недостаточно места с учётом других заданий. Нужно ", "Not enough space after accounting for other jobs. Required: ", "Nach Berücksichtigung anderer Aufträge ist nicht genügend Speicherplatz verfügbar. Erforderlich: "),
        ("доступно с учётом резерва ", "available after reservations: ", "nach Reservierungen verfügbar: "),
        ("В приложении отсутствует ", "The app is missing ", "In der App fehlt "),
        (". Соберите приложение заново через «Собрать приложение.command».", ". Rebuild the app with the included build command.", ". Erstellen Sie die App mit dem enthaltenen Build-Befehl erneut."),
        ("завершился с ошибкой ", " exited with error ", " wurde mit Fehler "),
        ("Аппаратное кодирование не удалось. CPU-режим в этой версии не включён. Для совместимого H.264 можно выбрать «Без перекодирования».", "Hardware encoding failed. This version does not enable CPU encoding. For compatible H.264, choose Copy without re-encoding.", "Die Hardwarecodierung ist fehlgeschlagen. Diese Version verwendet keine CPU-Codierung. Wählen Sie für kompatibles H.264 die Übernahme ohne Neukodierung."),
        ("Журнал:", "Log:", "Protokoll:"),
        ("Не удалось прочитать параметры файла ", "Could not read media properties for ", "Mediendaten konnten nicht gelesen werden für "),
        ("Файл проекта слишком большой.", "The project file is too large.", "Die Projektdatei ist zu groß."),
        ("Неподдерживаемая версия или размер проекта.", "Unsupported project version or size.", "Nicht unterstützte Projektversion oder -größe."),
        ("В проекте повторяются идентификаторы заданий.", "The project contains duplicate job identifiers.", "Das Projekt enthält doppelte Auftragskennungen."),
        ("Проекты поддерживают только локальные файлы.", "Projects support local files only.", "Projekte unterstützen nur lokale Dateien."),
        ("Нельзя сохранить проект поверх исходного медиафайла.", "A project cannot overwrite a source media file.", "Eine Projektdatei darf keine Quelldatei überschreiben."),
        ("Несколько заданий имеют одинаковое имя результата. Выберите «Сохранить копию», чтобы сохранить каждое.", "Multiple jobs produce the same output name. Choose Save a copy to keep each result.", "Mehrere Aufträge erzeugen denselben Ausgabenamen. Wählen Sie Kopie sichern, um jedes Ergebnis zu behalten."),
        ("Результат проекта требует повторного экспорта: ", "The project output needs to be exported again: ", "Die Projektausgabe muss erneut exportiert werden: "),
        ("Сначала проверьте выбранные файлы и настройки.", "Check the selected files and settings first.", "Prüfen Sie zuerst die ausgewählten Dateien und Einstellungen."),
        ("Язык единственной исходной дорожки не помечен как немецкий — проверьте его на слух.", "The only source track is not tagged as German; check it by listening.", "Die einzige Quellspur ist nicht als Deutsch markiert. Prüfen Sie sie durch Anhören."),
        ("Не удалось безопасно сохранить MP4:", "Could not safely save the MP4:", "Die MP4-Datei konnte nicht sicher gespeichert werden:"),
        ("Проверка параметров MP4 не пройдена.", "MP4 property verification failed.", "Die Prüfung der MP4-Eigenschaften ist fehlgeschlagen."),
        ("Ожидалось ", "Expected ", "Erwartet wurde "),
        ("; получено ", "; got ", "; erhalten: "),
        ("Проверка структуры MP4 не пройдена: нужны ", "MP4 structure check failed: required ", "MP4-Strukturprüfung fehlgeschlagen: erforderlich sind "),
        (" с и не совпадает с концом RU SRT: RU ", " s and does not end with the RU SRT: audio ", " s kürzer und endet nicht mit der RU-SRT: Audio "),
        ("; конец видео сохраняется.", "; the full video is kept.", "; das gesamte Video bleibt erhalten."),
        ("Видеоряд сохранится без потерь; степень сжатия сейчас не применяется.", "Video will be copied without quality loss; compression is not applied.", "Das Video wird verlustfrei übernommen; die Komprimierung wird nicht angewendet."),
        ("В исходном файле нет аудиодорожек.", "The source file has no audio tracks.", "Die Quelldatei enthält keine Audiospuren."),
        ("Выберите аудиодорожку исходного файла для экспорта.", "Select a source audio track to export.", "Wählen Sie eine Audiospur der Quelldatei für den Export aus."),
        ("В файле русской озвучки должна быть одна аудиодорожка.", "The Russian narration file must contain exactly one audio track.", "Die Datei mit der russischen Vertonung muss genau eine Audiospur enthalten."),
        ("Выберите дорожку исходника.", "Select a source track.", "Wählen Sie eine Quellspur aus."),
        ("Выберите и проверьте русскую озвучку.", "Select and verify the Russian narration.", "Wählen und prüfen Sie die russische Vertonung."),
        ("Не удалось определить длительность звука.", "Could not determine the audio duration.", "Die Audiodauer konnte nicht ermittelt werden."),
        ("Без перекодирования можно сохранить только уже готовый AAC.", "Copy mode only supports audio that is already AAC.", "Im Kopiermodus ist nur bereits vorhandenes AAC zulässig."),
        ("Для WAV/MP3 выберите AAC 96–256 кбит/с.", "For WAV/MP3, choose AAC at 96–256 kbit/s.", "Wählen Sie für WAV/MP3 AAC mit 96–256 kbit/s."),
        ("Не удалось определить точную длину AAC.", "Could not determine the exact AAC duration.", "Die genaue AAC-Dauer konnte nicht ermittelt werden."),
        ("В файле нет видеоряда.", "The file contains no video stream.", "Die Datei enthält keinen Videostream."),
        ("Найдено несколько вариантов русской озвучки. Выберите нужный.", "More than one Russian narration file was found. Choose the correct one.", "Mehrere Dateien mit russischer Vertonung gefunden. Wählen Sie die passende aus."),
        ("Укажите русскую озвучку и оба файла SRT.", "Select the Russian narration and both SRT files.", "Wählen Sie die russische Vertonung und beide SRT-Dateien aus."),
        ("В исходнике нет немецкой аудиодорожки.", "The source has no German audio track.", "Die Quelle enthält keine deutsche Audiospur."),
        ("Выберите немецкую дорожку исходного видео.", "Select the German audio track from the source video.", "Wählen Sie die deutsche Audiospur des Quellvideos aus."),
        ("Файл недоступен:", "File is unavailable:", "Datei ist nicht verfügbar:"),
        ("Для RU и DE выбран один и тот же SRT. Проверьте подбор.", "The same SRT file is selected for RU and DE. Check the matches.", "Für RU und DE ist dieselbe SRT-Datei ausgewählt. Prüfen Sie die Zuordnung."),
        ("Русская озвучка должна содержать ровно одну аудиодорожку.", "The Russian narration must contain exactly one audio track.", "Die russische Vertonung muss genau eine Audiospur enthalten."),
        ("Не удалось определить длительность, частоту или размеры видео.", "Could not determine the video duration, frame rate, or dimensions.", "Videodauer, Bildrate oder Abmessungen konnten nicht ermittelt werden."),
        ("У потоков есть стартовое смещение более 0,12 с.", "One or more streams start more than 0.12 s late.", "Mindestens ein Stream beginnt mit mehr als 0,12 s Versatz."),
        ("Эта версия не меняет их синхронизацию автоматически. Нужна отдельная проверка исходника.", "This version does not adjust synchronization automatically. Check the source separately.", "Diese Version passt die Synchronisierung nicht automatisch an. Prüfen Sie die Quelle separat."),
        ("Не удалось определить длительность русской озвучки.", "Could not determine the Russian narration duration.", "Die Dauer der russischen Vertonung konnte nicht ermittelt werden."),
        ("Русская озвучка длиннее видео на ", "Russian audio is longer than the video by ", "Die russische Tonspur ist um "),
        (" с. Возможна обрезка последних слов; проверьте файлы. Темп автоматически не меняется.", " s. The final words may be cut off; check the files. Playback speed is not changed automatically.", " s länger als das Video. Die letzten Wörter könnten abgeschnitten werden. Prüfen Sie die Dateien. Das Tempo wird nicht automatisch angepasst."),
        ("RU короче видео на ", "RU audio is shorter than the video by ", "Die RU-Tonspur ist um "),
        (" и не совпадает с концом RU SRT: RU ", " and does not end with the RU SRT: audio ", " kürzer als das Video und endet nicht mit der RU-SRT: Audio "),
        ("Проверьте озвучку. Темп автоматически не меняется.", "Check the narration. Playback speed is not changed automatically.", "Prüfen Sie die Vertonung. Das Tempo wird nicht automatisch angepasst."),
        ("Длительность немецкой дорожки заметно отличается от видео. Проверьте выбранную дорожку.", "The German audio duration differs substantially from the video. Check the selected track.", "Die Dauer der deutschen Tonspur weicht deutlich vom Video ab. Prüfen Sie die ausgewählte Spur."),
        ("Обнаружено HDR-видео. Первая версия рассчитана на SDR и не преобразует HDR автоматически.", "HDR video detected. This version is designed for SDR and does not convert HDR automatically.", "HDR-Video erkannt. Diese Version ist für SDR ausgelegt und wandelt HDR nicht automatisch um."),
        ("SRT должен быть непустым файлом UTF-8:", "SRT must be a non-empty UTF-8 file:", "Die SRT-Datei muss nicht leer und UTF-8-codiert sein:"),
        ("Не удалось распознать субтитры:", "Could not parse subtitles:", "Untertitel konnten nicht gelesen werden:"),
        ("Сначала проанализируйте видео.", "Analyze the video first.", "Analysieren Sie zuerst das Video."),
        ("Некорректные параметры видео.", "Invalid video properties.", "Ungültige Videoeigenschaften."),
        ("Для копирования нужен совместимый H.264 8-бит 4:2:0.", "Copying requires compatible H.264, 8-bit, 4:2:0 video.", "Zum Kopieren wird kompatibles H.264-Video mit 8 Bit und 4:2:0 benötigt."),
        ("Выберите разрешение для аппаратного перекодирования.", "Choose a resolution for hardware encoding.", "Wählen Sie eine Auflösung für die Hardwarecodierung."),
        ("Комплект не готов.", "The file set is not ready.", "Der Dateisatz ist nicht vollständig."),
        ("Нет корректных временных меток SRT:", "No valid SRT timestamps found:", "Keine gültigen SRT-Zeitstempel gefunden:"),
        ("Проверка структуры MP4 не пройдена:", "MP4 structure verification failed:", "Die Prüfung der MP4-Struktur ist fehlgeschlagen:"),
        ("Путь результата совпадает с исходным файлом. Выберите другую папку.", "The output path matches an input file. Choose another folder.", "Der Ausgabepfad entspricht einer Quelldatei. Wählen Sie einen anderen Ordner."),
        ("Не выбраны субтитры.", "No subtitles selected.", "Keine Untertitel ausgewählt."),
        ("Не удалось безопасно сохранить MP4:", "Could not safely save the MP4:", "Die MP4-Datei konnte nicht sicher gespeichert werden:"),
        ("Не удалось сохранить звук:", "Could not safely save the audio:", "Die Audiodatei konnte nicht sicher gespeichert werden:"),
        ("Результат совпадает с исходником.", "The output matches the input file.", "Die Ausgabe entspricht der Quelldatei."),
        ("Длительность звука не совпала: ожидалось ", "Audio duration mismatch: expected ", "Abweichende Audiodauer: erwartet "),
        ("Параметры AAC изменились при копировании.", "AAC properties changed during copying.", "AAC-Eigenschaften wurden beim Kopieren verändert."),
        ("Битрейт MP3 не соответствует выбранному профилю.", "MP3 bitrate does not match the selected profile.", "Die MP3-Bitrate entspricht nicht dem ausgewählten Profil."),
        ("Проверка результата: требуется единственная дорожка ", "Output verification: exactly one ", "Ausgabeprüfung: Es ist genau eine "),
        ("Проверка результата не пройдена.", "Output verification failed.", "Die Ausgabeprüfung ist fehlgeschlagen.")
    ]
    var translated = text
    for (russian, english, german) in phrases {
        translated = translated.replacingOccurrences(of: russian, with: language == .english ? english : german)
    }
    return translated
}

func localizedStatus(_ status: JobStatus, language: AppLanguage) -> String {
    localized(status.rawValue, language: language)
}
