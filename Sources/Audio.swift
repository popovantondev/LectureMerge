import Foundation
import Darwin

enum ExportMode: String, Codable, CaseIterable, Identifiable {
    case video = "Видео MP4", audio = "Только звук"
    var id: String { rawValue }
    var title: String { localized(rawValue) }
}
enum AACEngine: String, Codable, CaseIterable, Identifiable {
    case apple = "Apple AudioToolbox · быстро", ffmpeg = "FFmpeg AAC · как в версии 1"
    var id: String { rawValue }
    var title: String { localized(rawValue) }
    var codec: String { self == .apple ? "aac_at" : "aac" }
}
enum AudioSource: String, Codable, CaseIterable, Identifiable {
    case russian = "Русская озвучка", original = "Дорожка исходника"
    var id: String { rawValue }
    var title: String { localized(rawValue) }
}
enum AACContainer: String, Codable, CaseIterable, Identifiable {
    case m4a = "M4A", adts = "AAC (.aac)"
    var id: String { rawValue }
    var title: String { localized(rawValue) }
    var ext: String { self == .m4a ? "m4a" : "aac" }
}
enum AudioProfile: String, Codable, CaseIterable, Identifiable {
    case aacCopy, aac96, aac128, aac192, aac256, mp3128, mp3192, mp3256, mp3320
    var id: String { rawValue }
    var isMP3: Bool { rawValue.hasPrefix("mp3") }
    var isCopy: Bool { self == .aacCopy }
    var kbps: Int { Int(rawValue.dropFirst(3)) ?? 0 }
    var title: String {
        if isCopy { return localized("AAC · без перекодирования") }
        return localizedFormat(isMP3 ? "MP3 · %d кбит/с" : "AAC · %d кбит/с", kbps)
    }
}
enum Parallelism: String, Codable, CaseIterable, Identifiable {
    case auto, one, two, three, four
    var id: String { rawValue }
    var limit: Int { switch self { case .auto: return max(1, min(4, ProcessInfo.processInfo.activeProcessorCount / 2)); case .one: return 1; case .two: return 2; case .three: return 3; case .four: return 4 } }
    var title: String { self == .auto ? localizedFormat("Авто · до %d одновременно", limit) : localizedFormat("%d одновременно", limit) }
}

/// Reserve estimated space for every active job on the same volume, not per process.
final class DiskReservations {
    static let shared = DiskReservations()
    private let lock = NSLock()
    private var reservations: [UUID: (String, Int64)] = [:]
    func reserve(_ folder: URL, bytes: Int64) throws -> UUID {
        lock.lock(); defer { lock.unlock() }
        let attrs = try FileManager.default.attributesOfFileSystem(forPath: folder.path)
        guard let free = attrs[.systemFreeSize] as? NSNumber else { throw AssemblyError.message("Не удалось проверить свободное место.") }
        let volume = (attrs[.systemNumber] as? NSNumber)?.stringValue ?? folder.path
        let reserved = reservations.values.filter { $0.0 == volume }.reduce(Int64(0)) { $0 + $1.1 }
        guard bytes > 0, free.int64Value - reserved > bytes else {
            throw AssemblyError.message("Недостаточно места с учётом других заданий. Нужно \(byteText(bytes)), доступно с учётом резерва \(byteText(max(0, free.int64Value - reserved))).")
        }
        let id = UUID(); reservations[id] = (volume, bytes); return id
    }
    func release(_ id: UUID) { lock.lock(); reservations.removeValue(forKey: id); lock.unlock() }
}

struct AudioPlan {
    let job: Lecture
    let input: URL
    let stream: MediaStream
    let duration: Double
    let test: Bool
    var profile: AudioProfile { job.settings.audioProfile }
    var ext: String { profile.isMP3 ? "mp3" : job.settings.aacContainer.ext }
    var language: String { !job.primaryIsAudio && job.settings.audioSource == .russian ? "rus" : stream.language }
    var estimatedBytes: Int64 {
        let bitrate = profile.isCopy ? (Double(stream.bit_rate ?? "") ?? 192_000) : Double(profile.kbps * 1000)
        return Int64(bitrate * duration / 8 * 1.08)
    }
    var filename: String {
        let source = !job.primaryIsAudio && job.settings.audioSource == .russian ? "ru" : "track-\(stream.index)"
        let quality = profile.isCopy ? "copy" : String(profile.kbps)
        return "\(job.basename).audio-\(source)-\(quality)\(test ? ".test-30s" : "").\(ext)"
    }
    var description: String { "\(profile.title) · .\(ext) · \(clockText(duration))" }
    static func analyze(_ original: Lecture, tools: Toolchain, token: Cancellation) throws -> Lecture {
        var job = original
        if job.primaryIsAudio || job.settings.audioSource == .original {
            guard let info = job.info, !info.audio.isEmpty else { throw AssemblyError.message("В исходном файле нет аудиодорожек.") }
            if job.germanIndex == nil {
                if info.audio.count == 1 { job.germanIndex = info.audio[0].index }
            }
            guard info.audio.contains(where: { $0.index == job.germanIndex }) else { throw AssemblyError.message("Выберите аудиодорожку исходного файла для экспорта.") }
        } else {
            guard let ru = job.russianAudio else {
                job.status = job.audioCandidates.count > 1 ? .ambiguous : .missing
                job.detail = "Для экспорта звука выберите русскую озвучку или переключите источник на дорожку видео. SRT не нужны."
                return job
            }
            job.russianInfo = try MediaInfo.read(ru, tools: tools, token: token)
            guard job.russianInfo?.audio.count == 1 else { throw AssemblyError.message("В файле русской озвучки должна быть одна аудиодорожка.") }
        }
        let plan = try AudioPlan(job, test: false)
        job.status = .ready
        job.detail = plan.profile.isCopy ? "AAC копируется без потерь; битрейт, частота и каналы сохраняются." : "Экспортируется только выбранный звук. Субтитры и второй язык не требуются."
        return job
    }
    init(_ job: Lecture, test: Bool) throws {
        self.job = job; self.test = test
        let info: MediaInfo
        if job.primaryIsAudio || job.settings.audioSource == .original {
            input = job.video
            guard let primary = job.info, let audio = primary.audio.first(where: { $0.index == job.germanIndex }) else { throw AssemblyError.message("Выберите дорожку исходника.") }
            info = primary; stream = audio
        } else {
            guard let ru = job.russianAudio, let russian = job.russianInfo, let audio = russian.audio.first else { throw AssemblyError.message("Выберите и проверьте русскую озвучку.") }
            input = ru; info = russian; stream = audio
        }
        let full = stream.seconds ?? info.format?.duration.flatMap(Double.init) ?? 0
        guard full.isFinite, full > 0 else { throw AssemblyError.message("Не удалось определить длительность звука.") }
        duration = test ? min(30, full) : full
        if job.settings.audioProfile.isCopy && stream.codec_name != "aac" {
            throw AssemblyError.message("Без перекодирования можно сохранить только уже готовый AAC. Сейчас \(stream.codec_name ?? "неизвестный кодек"). Для WAV/MP3 выберите AAC 96–256 кбит/с.")
        }
    }
    func arguments(output: URL) -> [String] {
        var args = ["-hide_banner", "-nostdin", "-n", "-v", "warning", "-progress", "pipe:1", "-stats_period", "0.25", "-protocol_whitelist", "file,pipe", "-i", input.path,
                    "-map", "0:\(stream.index)", "-vn", "-sn", "-dn", "-map_metadata", "-1", "-map_chapters", "-1"]
        if profile.isCopy { args += ["-c:a", "copy"] }
        else if profile.isMP3 { args += ["-c:a", "libmp3lame", "-b:a", "\(profile.kbps)k", "-ar", "44100", "-ac", "2", "-id3v2_version", "3"] }
        else { args += ["-c:a", job.settings.aacEngine.codec, "-profile:a", "1", "-b:a", "\(profile.kbps)k", "-ar", "48000", "-ac", "2"] }
        args += ["-metadata:s:a:0", "language=\(language)", "-metadata", "title=\(job.basename)"]
        if test { args += ["-t", String(duration)] }
        let muxer = profile.isMP3 ? "mp3" : job.settings.aacContainer == .m4a ? "ipod" : "adts"
        if muxer == "ipod" { args += ["-movflags", "+faststart"] }
        args += ["-f", muxer, output.path]
        return args
    }
}

enum AudioExporter {
    static func validate(_ file: URL, plan: AudioPlan, tools: Toolchain, token: Cancellation) throws {
        let info = try MediaInfo.read(file, tools: tools, token: token)
        let expected = plan.profile.isMP3 ? "mp3" : "aac"
        guard info.streams.count == 1, info.audio.count == 1, info.audio[0].codec_name == expected else { throw AssemblyError.message("Проверка результата: требуется единственная дорожка \(expected.uppercased()).") }
        let actual = info.audio[0].seconds ?? info.duration
        guard abs(actual - plan.duration) < 0.3 else { throw AssemblyError.message("Длительность звука не совпала: ожидалось \(plan.duration), получено \(actual) с.") }
        if plan.profile.isCopy {
            guard info.audio[0].sample_rate == plan.stream.sample_rate, info.audio[0].channels == plan.stream.channels else { throw AssemblyError.message("Параметры AAC изменились при копировании.") }
        }
        if plan.profile.isMP3 {
            let bitrate = Double(info.audio[0].bit_rate ?? "") ?? 0
            guard abs(bitrate - Double(plan.profile.kbps * 1000)) < 2000 else { throw AssemblyError.message("Битрейт MP3 не соответствует выбранному профилю.") }
        }
        for offset in [0, max(0, plan.duration / 2 - 0.5), max(0, plan.duration - 1)] {
            try Runner.run(tools.ffmpeg, ["-v", "error", "-nostdin", "-xerror", "-ss", String(offset), "-i", file.path, "-map", "0:a:0", "-t", "1", "-f", "null", "-"], logs: tools.logs, token: token)
        }
    }
    static func run(_ job: Lecture, tools: Toolchain, destination: URL?, test: Bool, policy: ConflictPolicy,
                    protectedInputs: Set<String>, token: Cancellation, update: @escaping (Double, Double, Bool) -> Void) throws -> URL? {
        let checked = Matcher.analyze(job, tools: tools, token: token)
        try token.check()
        guard checked.status == .ready else { throw AssemblyError.message(checked.detail) }
        let plan = try AudioPlan(checked, test: test), fm = FileManager.default
        let folder = destination ?? job.video.deletingLastPathComponent().appendingPathComponent("Готовое")
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let requested = folder.appendingPathComponent(plan.filename)
        guard !protectedInputs.contains(requested.resolvingSymlinksInPath().path), requested.resolvingSymlinksInPath() != plan.input.resolvingSymlinksInPath() else { throw AssemblyError.message("Результат совпадает с исходником.") }
        if policy == .skip && fm.fileExists(atPath: requested.path) { return nil }
        let reservation = try DiskReservations.shared.reserve(folder, bytes: plan.estimatedBytes * 2 + 64 * 1024 * 1024)
        defer { DiskReservations.shared.release(reservation) }
        let temp = folder.appendingPathComponent(".olya-\(UUID().uuidString).partial.\(plan.ext)")
        defer { if fm.fileExists(atPath: temp.path) { try? fm.removeItem(at: temp) } }
        var speed = 0.0
        try Runner.run(tools.ffmpeg, plan.arguments(output: temp), logs: tools.logs, token: token) { line in
            let parts = line.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { return }
            if parts[0] == "speed" { speed = Double(parts[1].replacingOccurrences(of: "x", with: "").trimmingCharacters(in: .whitespaces)) ?? 0 }
            if parts[0] == "out_time_us", let microseconds = Double(parts[1]) { update(max(0, min(0.98, microseconds / 1_000_000 / plan.duration * 0.98)), speed, false) }
        }
        update(0.98, speed, true)
        try validate(temp, plan: plan, tools: tools, token: token)
        try token.check()
        var target = requested, count = 2
        while true {
            let status = temp.path.withCString { a in target.path.withCString { b in policy == .replace ? Darwin.rename(a, b) : renamex_np(a, b, UInt32(RENAME_EXCL)) } }
            if status == 0 { update(1, speed, false); return target }
            let code = errno
            if code == EEXIST && policy == .skip { return nil }
            if code == EEXIST && policy == .copy {
                target = folder.appendingPathComponent(requested.deletingPathExtension().lastPathComponent + " (\(count)).\(plan.ext)"); count += 1; continue
            }
            throw AssemblyError.message("Не удалось сохранить звук: \(String(cString: strerror(code)))")
        }
    }
}

/// A single interface for video and audio lets the queue handle mixed exports.
struct PlannedOutput {
    var duration: Double
    var filename: String
    var summary: String
    var estimatedBytes: Int64
    init(_ job: Lecture, test: Bool) throws {
        if job.settings.mode == .audio {
            let p = try AudioPlan(job, test: test)
            duration = p.duration; filename = p.filename; summary = p.description; estimatedBytes = p.estimatedBytes
        } else {
            let p = try ExportPlan(job, test: test)
            duration = p.duration; filename = p.filename; summary = p.description; estimatedBytes = p.estimatedBytes
        }
    }
}
