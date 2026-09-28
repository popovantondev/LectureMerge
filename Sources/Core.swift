import Foundation
import Darwin

enum AssemblyError: LocalizedError {
    case message(String), cancelled
    var errorDescription: String? {
        switch self { case .message(let s): return s; case .cancelled: return "Остановлено пользователем" }
    }
}

struct Toolchain {
    let ffmpeg: URL
    let ffprobe: URL
    let logs: URL
    static func bundled() throws -> Toolchain {
        let resources = Bundle.main.resourceURL ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let logs = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OlyaLectureAssembler2/Logs", isDirectory: true)
        let result = Toolchain(ffmpeg: resources.appendingPathComponent("bin/ffmpeg"),
                               ffprobe: resources.appendingPathComponent("bin/ffprobe"), logs: logs)
        for url in [result.ffmpeg, result.ffprobe] {
            guard FileManager.default.isExecutableFile(atPath: url.path) else {
                throw AssemblyError.message("В приложении отсутствует \(url.lastPathComponent). Соберите приложение заново через «Собрать приложение.command».")
            }
        }
        return result
    }
}

final class Cancellation {
    private let lock = NSLock()
    private var stopped = false
    private var process: Process?
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return stopped }
    func check() throws { if isCancelled { throw AssemblyError.cancelled } }
    func launch(_ p: Process) throws {
        lock.lock(); defer { lock.unlock() }
        if stopped { throw AssemblyError.cancelled }
        try p.run()
        process = p
    }
    func clear() { lock.lock(); process = nil; lock.unlock() }
    func cancel() {
        lock.lock(); stopped = true; let p = process; lock.unlock()
        guard let p, p.isRunning else { return }
        p.interrupt()
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            if p.isRunning { p.terminate() }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + 6) {
            if p.isRunning { kill(p.processIdentifier, SIGKILL) }
        }
    }
}

enum Runner {
    /// stderr goes to a file, so a full pipe can never deadlock a long export.
    @discardableResult static func run(_ tool: URL, _ args: [String], logs: URL,
                                      token: Cancellation = Cancellation(),
                                      progress: ((String) -> Void)? = nil) throws -> Data {
        try token.check()
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        let log = logs.appendingPathComponent("\(Int(Date().timeIntervalSince1970))-\(UUID().uuidString).log")
        let header = "\(tool.path)\nArguments (JSON): \((try? String(data: JSONEncoder().encode(args), encoding: .utf8)) ?? "")\n\n"
        try Data(header.utf8).write(to: log, options: .withoutOverwriting)
        let stderr = try FileHandle(forWritingTo: log)
        try stderr.seekToEnd()
        defer { try? stderr.close() }
        let p = Process(), pipe = Pipe()
        p.executableURL = tool; p.arguments = args
        p.standardInput = FileHandle.nullDevice; p.standardOutput = pipe; p.standardError = stderr
        try token.launch(p)
        defer { token.clear() }
        var output = Data(), buffer = Data()
        while true {
            let data = pipe.fileHandleForReading.availableData
            if data.isEmpty { break }
            if let progress {
                buffer.append(data)
                while let newline = buffer.firstIndex(of: 10) {
                    progress(String(decoding: buffer[..<newline], as: UTF8.self))
                    buffer.removeSubrange(...newline)
                }
            } else { output.append(data) }
        }
        p.waitUntilExit()
        try token.check()
        guard p.terminationStatus == 0 else {
            let handle = try FileHandle(forReadingFrom: log)
            let size = try handle.seekToEnd()
            try handle.seek(toOffset: size > 6000 ? size - 6000 : 0)
            let tail = String(decoding: try handle.readToEnd() ?? Data(), as: UTF8.self)
            try? handle.close()
            let hint = args.contains("h264_videotoolbox") ? "\nАппаратное кодирование не удалось. CPU-режим в этой версии не включён. Для совместимого H.264 можно выбрать «Без перекодирования»." : ""
            throw AssemblyError.message("\(tool.lastPathComponent) завершился с ошибкой \(p.terminationStatus).\(hint)\n\(tail)\nЖурнал: \(log.path)")
        }
        return output
    }
}

extension DateFormatter {
    static let logStamp: DateFormatter = { let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd_HH-mm-ss"; return f }()
}

struct MediaStream: Decodable {
    var index: Int
    var codec_name: String?
    var codec_type: String?
    var profile: String?
    var width: Int?
    var height: Int?
    var pix_fmt: String?
    var sample_aspect_ratio: String?
    var avg_frame_rate: String?
    var r_frame_rate: String?
    var duration: String?
    var start_time: String?
    var bit_rate: String?
    var sample_rate: String?
    var channels: Int?
    var field_order: String?
    var color_transfer: String?
    var tags: [String: String]?
    var disposition: [String: Int]?
    var side_data_list: [SideData]?
    struct SideData: Decodable { var rotation: Double? }
    var seconds: Double? { duration.flatMap(Double.init) }
    var start: Double { start_time.flatMap(Double.init) ?? 0 }
    var language: String { tags?["language"] ?? "und" }
    var isDefault: Bool { disposition?["default"] == 1 }
    var fps: Double { Self.ratio(avg_frame_rate) > 0 ? Self.ratio(avg_frame_rate) : Self.ratio(r_frame_rate) }
    static func ratio(_ text: String?) -> Double {
        let parts = (text ?? "").replacingOccurrences(of: ":", with: "/").split(separator: "/")
        guard let n = parts.first.flatMap({ Double($0) }) else { return 0 }
        if parts.count == 1 { return n }
        let d = Double(parts[1]) ?? 0
        return d > 0 ? n / d : 0
    }
    var rotation: Double { side_data_list?.compactMap(\.rotation).first ?? tags?["rotate"].flatMap(Double.init) ?? 0 }
    var displaySize: (Double, Double) {
        let sar = Self.ratio(sample_aspect_ratio)
        let w = Double(width ?? 0) * (sar > 0 ? sar : 1), h = Double(height ?? 0)
        return abs(Int(rotation.rounded())) % 180 == 90 ? (h, w) : (w, h)
    }
    var canCopyVideo: Bool {
        codec_name == "h264" && pix_fmt == "yuv420p" && !isInterlaced
    }
    var isInterlaced: Bool { ["tt", "bb", "tb", "bt"].contains(field_order ?? "") }
    var isAACLC: Bool { codec_name == "aac" && ["LC", "1"].contains(profile ?? "") }
    var canCopyAudio: Bool { isAACLC && (channels ?? 99) <= 2 }
    var audioLabel: String {
        "\(localized("Дорожка")) \(index) · \(language) · \(codec_name ?? "?") · \(channels ?? 0) \(localized("кан."))\(tags?["title"].map { " · " + $0 } ?? "")"
    }
}

struct MediaInfo: Decodable {
    var streams: [MediaStream]
    var format: Format?
    struct Format: Decodable { var duration: String?; var start_time: String?; var size: String?; var bit_rate: String?; var format_name: String? }
    var video: MediaStream? { streams.first { $0.codec_type == "video" && $0.disposition?["attached_pic"] != 1 } }
    var audio: [MediaStream] { streams.filter { $0.codec_type == "audio" } }
    var subtitles: [MediaStream] { streams.filter { $0.codec_type == "subtitle" } }
    var duration: Double { video?.seconds ?? format?.duration.flatMap(Double.init) ?? audio.first?.seconds ?? 0 }
    var start: Double { format?.start_time.flatMap(Double.init) ?? 0 }
    static func read(_ url: URL, tools: Toolchain, token: Cancellation = Cancellation()) throws -> MediaInfo {
        let data = try Runner.run(tools.ffprobe, ["-v", "error", "-protocol_whitelist", "file,pipe", "-show_streams", "-show_format", "-of", "json", url.path], logs: tools.logs, token: token)
        do {
            var info = try JSONDecoder().decode(MediaInfo.self, from: data)
            if info.format?.format_name == "aac" {
                let packets = try Runner.run(tools.ffprobe, ["-v", "error", "-select_streams", "a:0", "-show_entries", "packet=duration_time", "-of", "csv=p=0", url.path], logs: tools.logs, token: token)
                let total = String(decoding: packets, as: UTF8.self).split(separator: "\n").reduce(0.0) { $0 + (Double($1) ?? 0) }
                guard total > 0 else { throw AssemblyError.message("Не удалось определить точную длину AAC.") }
                info.format?.duration = String(total)
                if let index = info.streams.firstIndex(where: { $0.codec_type == "audio" }) { info.streams[index].duration = String(total) }
            }
            return info
        }
        catch { throw AssemblyError.message("Не удалось прочитать параметры файла \(url.lastPathComponent): \(error.localizedDescription)") }
    }
}

enum Resolution: String, CaseIterable, Identifiable, Codable {
    case copy, original, p144, p240, p360, p480, p720, p1080, p1440, p2160
    var id: String { rawValue }
    var title: String {
        switch self { case .copy: return localized("Без перекодирования"); case .original: return localized("Исходное разрешение"); case .p1440: return "1440p · QHD"; case .p2160: return "2160p · 4K"; default: return String(rawValue.dropFirst()) + "p" }
    }
    var height: Int? { Int(rawValue.dropFirst()) }
}
enum Quality: String, CaseIterable, Identifiable, Codable {
    case compact = "Компактно", balanced = "Баланс", clear = "Чётче"
    var id: String { rawValue }
    var title: String { localized(rawValue) }
    func kbps(height: Int) -> Int {
        let base: Double = height <= 144 ? 180 : height <= 240 ? 450 : height <= 360 ? 800 : height <= 480 ? 1300 : height <= 720 ? 2400 : height <= 1080 ? 4500 : height <= 1440 ? 8000 : 16000
        return Int(base * (self == .compact ? 0.65 : self == .clear ? 1.5 : 1))
    }
}
struct ExportSettings: Codable {
    var resolution: Resolution = .p720
    var quality: Quality = .balanced
    var recompress = false
    var upscale = false
    var mode: ExportMode = .video
    var audioSource: AudioSource = .russian
    var audioProfile: AudioProfile = .mp3320
    var aacContainer: AACContainer = .m4a
    var aacEngine: AACEngine = .apple
    var copyRussianAAC = true
}
enum JobStatus: String {
    case analyzing = "Анализ", ready = "Готова", missing = "Нет файлов", ambiguous = "Выберите файл", review = "Нужна проверка"
    case running = "Обработка", validating = "Проверка результата", completed = "Завершена", failed = "Ошибка", stopped = "Остановлена", skipped = "Пропущена"
    var localizedTitle: String { localized(rawValue) }
}
struct Lecture: Identifiable {
    var id = UUID()
    var video: URL
    var russianAudio: URL?
    var russianSRT: URL?
    var germanSRT: URL?
    var audioCandidates: [URL] = []
    var germanIndex: Int?
    var info: MediaInfo?
    var russianInfo: MediaInfo?
    var russianSRTEnd: Double?
    var settings = ExportSettings()
    var status: JobStatus = .analyzing
    var detail = ""
    var progress = 0.0
    var speed = 0.0
    var output: URL?
    var enabled = true
    var primaryIsAudio: Bool { ["wav", "m4a", "aac", "mp3", "flac"].contains(video.pathExtension.lowercased()) }
    var basename: String { video.deletingPathExtension().lastPathComponent }
}

enum Matcher {
    static func videos(in urls: [URL], recursive: Bool, includeAudio: Bool = false) -> [URL] {
        let fm = FileManager.default
        var found = Set<URL>()
        func accept(_ url: URL) {
            let lower = url.lastPathComponent.lowercased()
            let extensions = includeAudio ? ["mp4", "mkv", "wav", "m4a", "aac", "mp3", "flac"] : ["mp4", "mkv"]
            guard extensions.contains(url.pathExtension.lowercased()),
                  !lower.contains(".ru."), !lower.contains(".partial."), !lower.hasPrefix("."),
                  lower.range(of: #"\.ru \(\d+\)\.(mp4|mkv)$"#, options: .regularExpression) == nil,
                  (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { return }
            found.insert(url.standardizedFileURL.resolvingSymlinksInPath())
        }
        for input in urls {
            var dir: ObjCBool = false
            guard fm.fileExists(atPath: input.path, isDirectory: &dir) else { continue }
            if !dir.boolValue { accept(input); continue }
            if recursive, let items = fm.enumerator(at: input, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
                for case let url as URL in items {
                    if url.lastPathComponent == "Готовое" { items.skipDescendants(); continue }
                    accept(url)
                }
            } else {
                (try? fm.contentsOfDirectory(at: input, includingPropertiesForKeys: nil, options: .skipsHiddenFiles))?.forEach { url in
                    if (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true { accept(url) }
                }
            }
        }
        return found.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }
    static func match(_ video: URL) -> Lecture {
        var lecture = Lecture(video: video)
        let root = video.deletingPathExtension().path
        // Only exact, documented suffixes: never prefix-match translation fragments.
        lecture.audioCandidates = [".ru.siri.voice.wav", ".ru.siri.voice.m4a", ".ru.siri.voice.aac", ".ru.wav", ".ru.m4a", ".ru.aac", ".ru.voice.wav", ".ru.voice.m4a", ".ru.voice.aac"]
            .map { URL(fileURLWithPath: root + $0) }.filter { FileManager.default.isReadableFile(atPath: $0.path) }
        if lecture.audioCandidates.count == 1 { lecture.russianAudio = lecture.audioCandidates.first }
        let ru = URL(fileURLWithPath: root + ".ru.srt"), de = URL(fileURLWithPath: root + ".srt")
        if FileManager.default.isReadableFile(atPath: ru.path) { lecture.russianSRT = ru }
        if FileManager.default.isReadableFile(atPath: de.path) { lecture.germanSRT = de }
        return lecture
    }
    static func analyze(_ input: Lecture, tools: Toolchain, token: Cancellation = Cancellation()) -> Lecture {
        var job = input
        do {
            job.info = try MediaInfo.read(job.video, tools: tools, token: token)
            if job.settings.mode == .audio { return try AudioPlan.analyze(job, tools: tools, token: token) }
            guard let info = job.info, let video = info.video else { throw AssemblyError.message("В файле нет видеоряда.") }
            if job.germanIndex == nil {
                let tagged = info.audio.filter { ["deu", "ger", "de"].contains($0.language.lowercased()) }
                if info.audio.count == 1 { job.germanIndex = info.audio[0].index }
                else if tagged.count == 1 { job.germanIndex = tagged[0].index }
            }
            if job.audioCandidates.count > 1 && job.russianAudio == nil {
                job.status = .ambiguous; job.detail = "Найдено несколько вариантов русской озвучки. Выберите нужный."; return job
            }
            guard let ru = job.russianAudio, let ruSRT = job.russianSRT, let deSRT = job.germanSRT else {
                job.status = .missing; job.detail = "Укажите русскую озвучку и оба файла SRT."; return job
            }
            guard let german = info.audio.first(where: { $0.index == job.germanIndex }) else {
                job.status = .review; job.detail = info.audio.isEmpty ? "В исходнике нет немецкой аудиодорожки." : "Выберите немецкую дорожку исходного видео."; return job
            }
            for file in [ru, ruSRT, deSRT] {
                guard FileManager.default.isReadableFile(atPath: file.path) else { throw AssemblyError.message("Файл недоступен: \(file.path)") }
            }
            guard ruSRT.resolvingSymlinksInPath() != deSRT.resolvingSymlinksInPath() else { throw AssemblyError.message("Для RU и DE выбран один и тот же SRT. Проверьте подбор.") }
            job.russianInfo = try MediaInfo.read(ru, tools: tools, token: token)
            guard let russian = job.russianInfo, russian.audio.count == 1 else { throw AssemblyError.message("Русская озвучка должна содержать ровно одну аудиодорожку.") }
            let russianSRTEnd = try Subtitles.lastEnd(ruSRT)
            job.russianSRTEnd = russianSRTEnd
            guard info.duration.isFinite, info.duration > 0, video.fps > 0, video.displaySize.0 > 0, video.displaySize.1 > 0 else { throw AssemblyError.message("Не удалось определить длительность, частоту или размеры видео.") }
            // Unsupported offsets are visible and blocked, never silently reset per input.
            if [info.start, video.start, german.start, russian.start, russian.audio[0].start].contains(where: { abs($0) > 0.12 }) {
                throw AssemblyError.message("У потоков есть стартовое смещение более 0,12 с. Эта версия не меняет их синхронизацию автоматически. Нужна отдельная проверка исходника.")
            }
            let difference = russian.duration - info.duration
            let tolerance = max(2, min(10, info.duration * 0.005))
            guard russian.duration > 0 else { throw AssemblyError.message("Не удалось определить длительность русской озвучки.") }
            if difference > tolerance {
                throw AssemblyError.message("Русская озвучка длиннее видео на \(String(format: "%.2f", difference)) с. Возможна обрезка последних слов; проверьте файлы. Темп автоматически не меняется.")
            }
            if difference < -tolerance && abs(russian.duration - russianSRTEnd) > 0.5 {
                throw AssemblyError.message("RU короче видео на \(String(format: "%.2f", -difference)) с и не совпадает с концом RU SRT: RU \(clockText(russian.duration)), SRT \(clockText(russianSRTEnd)). Проверьте озвучку. Темп автоматически не меняется.")
            }
            if let duration = german.seconds, abs(duration - info.duration) > tolerance {
                throw AssemblyError.message("Длительность немецкой дорожки заметно отличается от видео. Проверьте выбранную дорожку.")
            }
            if ["smpte2084", "arib-std-b67"].contains(video.color_transfer ?? "") { throw AssemblyError.message("Обнаружено HDR-видео. Первая версия рассчитана на SDR и не преобразует HDR автоматически.") }
            for srt in [ruSRT, deSRT] {
                let data = try Data(contentsOf: srt)
                guard let contents = String(data: data, encoding: .utf8), contents.contains("-->"), !contents.contains("\0") else { throw AssemblyError.message("SRT должен быть непустым файлом UTF-8: \(srt.lastPathComponent)") }
                let sub = try MediaInfo.read(srt, tools: tools, token: token)
                guard sub.subtitles.count == 1 else { throw AssemblyError.message("Не удалось распознать субтитры: \(srt.lastPathComponent)") }
            }
            job.status = .ready
            job.detail = try ExportPlan(job, test: false).russianAudioDescription
            if info.audio.count == 1 && !["deu", "ger", "de"].contains(german.language) { job.detail += " Язык единственной исходной дорожки не помечен как немецкий — проверьте его на слух." }
        } catch { job.status = .review; job.detail = error.localizedDescription }
        return job
    }
}

struct ExportPlan {
    let job: Lecture
    let duration: Double
    let width: Int
    let height: Int
    let copyVideo: Bool
    let copyRussianAudio: Bool
    let videoKbps: Int
    let estimatedBytes: Int64
    let test: Bool
    var description: String {
        localizedFormat("%d×%d · %@ · RU %@", width, height,
                        localized(copyVideo ? "копирование видео" : "H.264 · Apple VideoToolbox"),
                        localized(copyRussianAudio ? "AAC без перекодирования" : "AAC 128 кбит/с"))
    }
    var russianAudioDescription: String {
        let russianDuration = job.russianInfo?.duration ?? 0
        let shortfall = duration - russianDuration
        let matchesSRT = job.russianSRTEnd.map { abs($0 - russianDuration) <= 0.5 } == true
        if copyRussianAudio {
            if shortfall > 0.05 && matchesSRT {
                return localizedFormat("Озвучка совпадает с SRT. После последней реплики остаётся %@ с видео без русской речи. RU AAC-LC копируется без перекодирования.", String(format: "%.2f", shortfall))
            }
            let tail = shortfall > 0.05 ? " " + localizedFormat("После окончания RU остаётся %@ с видео без русской речи; конец видео сохраняется.", String(format: "%.2f", shortfall)) : ""
            return localized("RU AAC-LC копируется без перекодирования и потери качества; сохраняются исходные частота и каналы.") + tail
        }
        if shortfall > 0.05 { return localizedFormat("RU будет закодирован в AAC-LC: конец дополнится тишиной на %@ с.", String(format: "%.2f", shortfall)) }
        if !job.settings.copyRussianAAC { return localized("RU будет заново закодирован в AAC-LC: копирование отключено в настройках.") }
        return localized("RU будет закодирован в AAC-LC. Без перекодирования принимается готовый AAC-LC в M4A/MP4, моно или стерео.")
    }
    var filename: String {
        let base = job.basename.replacingOccurrences(of: "_[0-9]{3,4}p$", with: "", options: .regularExpression)
        return "\(base)_\(height)p\(test ? ".test-30s" : "").ru.mp4"
    }
    init(_ job: Lecture, test: Bool) throws {
        guard let info = job.info, let video = info.video else { throw AssemblyError.message("Сначала проанализируйте видео.") }
        self.job = job; self.test = test
        self.duration = test ? min(30, info.duration) : info.duration
        let russian = job.russianInfo
        let timedContainer = russian?.format?.format_name?.split(separator: ",").contains("mov") == true
        copyRussianAudio = job.settings.copyRussianAAC && timedContainer && russian?.audio.first?.canCopyAudio == true
        let (sourceW, sourceH) = video.displaySize
        guard sourceW > 0, sourceH > 0, duration > 0 else { throw AssemblyError.message("Некорректные параметры видео.") }
        let requested = Double(job.settings.resolution.height ?? Int(sourceH.rounded()))
        let actual = job.settings.upscale ? requested : min(requested, sourceH)
        let sameSize = abs(actual - sourceH) < 1
        if job.settings.resolution == .copy && !video.canCopyVideo {
            throw AssemblyError.message("Для копирования нужен совместимый H.264 8-бит 4:2:0. Выберите разрешение для аппаратного перекодирования.")
        }
        copyVideo = job.settings.resolution == .copy || (sameSize && video.canCopyVideo && !job.settings.recompress)
        if copyVideo { width = Int(sourceW.rounded()); height = Int(sourceH.rounded()) }
        else {
            height = max(2, Int(actual / 2) * 2)
            width = max(2, Int((Double(height) * sourceW / sourceH / 2).rounded()) * 2)
        }
        videoKbps = job.settings.quality.kbps(height: height)
        let fileSize = Double(info.format?.size ?? "") ?? 0
        let bitRate = copyVideo ? (video.bit_rate.flatMap(Double.init) ?? max(500_000, fileSize * 8 / info.duration)) : Double(videoKbps * 1000)
        let german = info.audio.first { $0.index == job.germanIndex }
        let germanRate = german?.canCopyAudio == true ? (german?.bit_rate.flatMap(Double.init) ?? 192_000) : 192_000
        let russianRate = copyRussianAudio ? (russian?.audio.first?.bit_rate.flatMap(Double.init) ?? 192_000) : 128_000
        estimatedBytes = Int64((bitRate + russianRate + germanRate) * duration / 8 * 1.05)
    }
    func arguments(output: URL, clippedRussianSRT: URL? = nil, clippedGermanSRT: URL? = nil, workerThreads: Int = 0) throws -> [String] {
        guard let ru = job.russianAudio, let rs = job.russianSRT, let ds = job.germanSRT,
              let info = job.info, let video = info.video, let german = info.audio.first(where: { $0.index == job.germanIndex }) else { throw AssemblyError.message("Комплект не готов.") }
        var a = ["-hide_banner", "-nostdin", "-n", "-loglevel", "warning", "-progress", "pipe:1", "-stats_period", "0.25"]
        for (index, file) in [job.video, ru, clippedRussianSRT ?? rs, clippedGermanSRT ?? ds].enumerated() {
            if index == 0 { a += ["-threads", String(workerThreads)] }
            a += ["-protocol_whitelist", "file,pipe", "-i", file.path]
        }
        a += ["-filter_threads", String(max(1, workerThreads))]
        a += ["-map", "0:\(video.index)", "-map", "1:a:0", "-map", "0:\(german.index)", "-map", "2:s:0", "-map", "3:s:0", "-map_metadata", "-1", "-map_chapters", "-1"]
        if copyVideo { a += ["-c:v", "copy"] }
        else {
            let filter = (video.isInterlaced ? "bwdif=mode=send_frame," : "") + "scale=\(width):\(height):flags=lanczos,setsar=1,format=yuv420p"
            a += ["-vf", filter, "-c:v", "h264_videotoolbox", "-allow_sw", "0", "-profile:v", "high", "-pix_fmt", "yuv420p", "-b:v", "\(videoKbps)k", "-maxrate", "\(videoKbps * 2)k", "-bufsize", "\(videoKbps * 4)k", "-fps_mode", "passthrough"]
        }
        if copyRussianAudio { a += ["-c:a:0", "copy"] }
        else {
            a += ["-c:a:0", job.settings.aacEngine.codec, "-profile:a:0", "1", "-b:a:0", "128k", "-ar:a:0", "48000", "-ac:a:0", "2",
                  "-filter:a:0", "apad=whole_dur=\(duration),atrim=duration=\(duration)"]
        }
        if german.canCopyAudio { a += ["-c:a:1", "copy"] }
        else { a += ["-c:a:1", job.settings.aacEngine.codec, "-profile:a:1", "1", "-b:a:1", "192k", "-ar:a:1", "48000", "-ac:a:1", "2"] }
        a += ["-c:s", "mov_text"]
        for (specifier, lang, name, disposition) in [("a:0", "rus", "Русский", "default"), ("a:1", "deu", "Deutsch — оригинал", "0"), ("s:0", "rus", "Русские субтитры", "default"), ("s:1", "deu", "Deutsche Untertitel", "0")] {
            a += ["-metadata:s:\(specifier)", "language=\(lang)", "-metadata:s:\(specifier)", "handler_name=\(name)", "-disposition:\(specifier)", disposition]
        }
        // A finite bound comes from the VIDEO, never from a shorter WAV or subtitle track.
        a += ["-t", String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), duration), "-movflags", "+faststart", "-f", "mp4", output.path]
        return a
    }
}

enum ConflictPolicy: String, CaseIterable, Identifiable, Codable {
    case copy = "Сохранить копию", skip = "Пропустить", replace = "Заменить"
    var id: String { rawValue }
    var title: String { localized(rawValue) }
}

enum Subtitles {
    static func lastEnd(_ input: URL) throws -> Double {
        let original = try String(contentsOf: input, encoding: .utf8)
        let normalized = original.replacingOccurrences(of: "\u{feff}", with: "").replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let regex = try NSRegularExpression(pattern: #"(?m)^\d+:\d{2}:\d{2}[,.]\d{3}[ \t]+-->[ \t]+(\d+):(\d{2}):(\d{2})[,.](\d{3})[^\n]*$"#)
        let matches = regex.matches(in: normalized, range: NSRange(normalized.startIndex..., in: normalized))
        guard !matches.isEmpty else { throw AssemblyError.message("Нет корректных временных меток SRT: \(input.lastPathComponent)") }
        let ns = normalized as NSString
        return matches.reduce(0) { latest, match in
            let values = (1...4).map { Double(ns.substring(with: match.range(at: $0))) ?? 0 }
            return max(latest, values[0] * 3600 + values[1] * 60 + values[2] + values[3] / 1000)
        }
    }

    /// Clip cue ends as well as starts: FFmpeg's -t alone does not clip a crossing subtitle packet.
    static func clipped(_ input: URL, duration: Double) throws -> String {
        let original = try String(contentsOf: input, encoding: .utf8)
        let normalized = original.replacingOccurrences(of: "\u{feff}", with: "").replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let regex = try NSRegularExpression(pattern: #"(?m)^(\d+):(\d{2}):(\d{2})[,.](\d{3})[ \t]+-->[ \t]+(\d+):(\d{2}):(\d{2})[,.](\d{3})[^\n]*$"#)
        let range = NSRange(normalized.startIndex..., in: normalized)
        let matches = regex.matches(in: normalized, range: range)
        guard !matches.isEmpty else { throw AssemblyError.message("Нет корректных временных меток SRT: \(input.lastPathComponent)") }
        let ns = normalized as NSString
        var result: [String] = []
        func time(_ match: NSTextCheckingResult, _ offset: Int) -> Double {
            var v: [Double] = []
            for i in offset..<(offset + 4) { v.append(Double(ns.substring(with: match.range(at: i))) ?? 0) }
            return v[0] * 3600 + v[1] * 60 + v[2] + v[3] / 1000
        }
        func stamp(_ seconds: Double) -> String {
            let value = Int((seconds * 1000).rounded(.down))
            return String(format: "%02d:%02d:%02d,%03d", value / 3_600_000, value / 60_000 % 60, value / 1000 % 60, value % 1000)
        }
        for (i, match) in matches.enumerated() {
            let start = time(match, 1), end = min(duration, time(match, 5))
            guard start < duration, end > start else { continue }
            let textStart = match.range.location + match.range.length
            let textEnd = i + 1 < matches.count ? matches[i + 1].range.location : ns.length
            var text = ns.substring(with: NSRange(location: textStart, length: textEnd - textStart)).trimmingCharacters(in: .whitespacesAndNewlines)
            if i + 1 < matches.count {
                text = text.replacingOccurrences(of: #"\n\s*\d+\s*$"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if text.isEmpty { continue }
            result.append("\(result.count + 1)\n\(stamp(start)) --> \(stamp(end))\n\(text)\n")
        }
        // A zero-width 1 ms cue keeps a selectable mov_text track when the test has no spoken subtitles yet.
        if result.isEmpty { return "1\n00:00:00,000 --> 00:00:00,001\n\u{200B}\n\n" }
        return result.joined(separator: "\n") + "\n"
    }
}

enum Exporter {
    static func validate(_ url: URL, plan: ExportPlan, tools: Toolchain, token: Cancellation) throws -> MediaInfo {
        let info = try MediaInfo.read(url, tools: tools, token: token)
        guard info.streams.count == 5, let video = info.video, info.audio.count == 2, info.subtitles.count == 2,
              video.codec_name == "h264", video.pix_fmt == "yuv420p",
              info.audio.map(\.language) == ["rus", "deu"], info.subtitles.map(\.language) == ["rus", "deu"],
              info.audio.allSatisfy({ $0.isAACLC }),
              info.audio[0].isDefault, !info.audio[1].isDefault,
              info.audio[0].sample_rate == (plan.copyRussianAudio ? plan.job.russianInfo?.audio.first?.sample_rate : "48000"),
              info.audio[0].channels == (plan.copyRussianAudio ? plan.job.russianInfo?.audio.first?.channels : 2),
              info.subtitles[0].isDefault, !info.subtitles[1].isDefault,
              info.subtitles.allSatisfy({ $0.codec_name == "mov_text" }) else {
            throw AssemblyError.message("Проверка структуры MP4 не пройдена: нужны H.264, RU/DE AAC и RU/DE mov_text с правильными основными дорожками.")
        }
        let tolerance = max(0.4, 3 / max(1, video.fps))
        guard abs(info.duration - plan.duration) <= tolerance,
              abs((info.format?.duration.flatMap(Double.init) ?? 0) - plan.duration) <= tolerance,
              abs(Double(plan.width) - video.displaySize.0) < 2,
              abs(Double(plan.height) - video.displaySize.1) < 2,
              abs(video.fps - (plan.job.info?.video?.fps ?? 0)) < 0.15,
              (info.audio[0].seconds ?? 0) >= (plan.copyRussianAudio ? min(plan.duration, plan.job.russianInfo?.duration ?? plan.duration) : plan.duration) - 0.15 else {
            throw AssemblyError.message("Проверка параметров MP4 не пройдена. Ожидалось \(plan.width)×\(plan.height), \(String(format: "%.3f", plan.duration)) с; получено \(Int(video.displaySize.0))×\(Int(video.displaySize.1)), видео \(info.duration) с, контейнер \(info.format?.duration ?? "?") с, RU \(info.audio[0].duration ?? "?") с, \(video.fps) fps.")
        }
        for offset in [0.0, max(0, plan.duration / 2 - 0.5), max(0, plan.duration - 1)] {
            try Runner.run(tools.ffmpeg, ["-hide_banner", "-nostdin", "-v", "error", "-xerror", "-err_detect", "explode", "-ss", String(offset), "-i", url.path, "-map", "0:v:0", "-map", "0:a:0", "-map", "0:a:1", "-t", "1", "-f", "null", "-"], logs: tools.logs, token: token)
        }
        return info
    }
    static func run(_ job: Lecture, tools: Toolchain, destination: URL?, test: Bool, policy: ConflictPolicy,
                    protectedInputs: Set<String> = [], token: Cancellation, workerThreads: Int = 0,
                    update: @escaping (Double, Double, Bool) -> Void) throws -> URL? {
        if job.settings.mode == .audio {
            return try AudioExporter.run(job, tools: tools, destination: destination, test: test, policy: policy, protectedInputs: protectedInputs, token: token, update: update)
        }
        try token.check()
        // Re-read inputs immediately before every export; a queued path may have changed on disk.
        let checked = Matcher.analyze(job, tools: tools, token: token)
        try token.check()
        guard checked.status == .ready else { throw AssemblyError.message(checked.detail) }
        let plan = try ExportPlan(checked, test: test)
        let fm = FileManager.default
        let folder = destination ?? job.video.deletingLastPathComponent().appendingPathComponent("Готовое", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let requested = folder.appendingPathComponent(plan.filename)
        if fm.fileExists(atPath: requested.path) && policy == .skip { return nil }
        let allInputs = protectedInputs.union([job.video, job.russianAudio, job.russianSRT, job.germanSRT].compactMap { $0?.resolvingSymlinksInPath().path })
        guard !allInputs.contains(requested.resolvingSymlinksInPath().path) else { throw AssemblyError.message("Путь результата совпадает с исходным файлом. Выберите другую папку.") }
        let needed = plan.estimatedBytes * 2 + 256 * 1024 * 1024
        let reservation = try DiskReservations.shared.reserve(folder, bytes: needed)
        defer { DiskReservations.shared.release(reservation) }
        let temp = folder.appendingPathComponent(".olya-\(UUID().uuidString).partial.mp4")
        defer { if fm.fileExists(atPath: temp.path) { try? fm.removeItem(at: temp) } }
        let tempInputs = tools.logs.deletingLastPathComponent().appendingPathComponent("Temp/\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tempInputs, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempInputs) }
        let ruSRT = tempInputs.appendingPathComponent("ru.srt"), deSRT = tempInputs.appendingPathComponent("de.srt")
        guard let sourceRU = checked.russianSRT, let sourceDE = checked.germanSRT else { throw AssemblyError.message("Не выбраны субтитры.") }
        try Subtitles.clipped(sourceRU, duration: plan.duration).write(to: ruSRT, atomically: true, encoding: .utf8)
        try Subtitles.clipped(sourceDE, duration: plan.duration).write(to: deSRT, atomically: true, encoding: .utf8)
        var speed = 0.0
        try Runner.run(tools.ffmpeg, plan.arguments(output: temp, clippedRussianSRT: ruSRT, clippedGermanSRT: deSRT, workerThreads: workerThreads), logs: tools.logs, token: token) { line in
            let pair = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2 else { return }
            if pair[0] == "speed" { speed = Double(pair[1].replacingOccurrences(of: "x", with: "").trimmingCharacters(in: .whitespaces)) ?? 0 }
            if pair[0] == "out_time_us", let us = Double(pair[1]) { update(max(0, min(0.98, us / 1_000_000 / plan.duration * 0.98)), speed, false) }
        }
        update(0.98, speed, true)
        _ = try validate(temp, plan: plan, tools: tools, token: token)
        try token.check()
        var target = requested, number = 2
        while true {
            // RENAME_EXCL is atomic: a file created while encoding cannot be overwritten accidentally.
            let status = temp.path.withCString { src in target.path.withCString { dst in
                policy == .replace ? Darwin.rename(src, dst) : renamex_np(src, dst, UInt32(RENAME_EXCL))
            } }
            if status == 0 { update(1, speed, false); return target }
            let code = errno
            if code == EEXIST && policy == .skip { return nil }
            if code == EEXIST && policy == .copy {
                target = folder.appendingPathComponent(requested.deletingPathExtension().deletingPathExtension().lastPathComponent + " (\(number)).ru.mp4")
                number += 1
                if allInputs.contains(target.resolvingSymlinksInPath().path) { continue }
                continue
            }
            throw AssemblyError.message("Не удалось безопасно сохранить MP4: \(String(cString: strerror(code))).")
        }
    }
}

func clockText(_ seconds: Double) -> String {
    guard seconds.isFinite else { return "—" }
    let value = max(0, Int(seconds.rounded()))
    return String(format: "%02d:%02d:%02d", value / 3600, value / 60 % 60, value % 60)
}
func byteText(_ bytes: Int64) -> String { ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) }
