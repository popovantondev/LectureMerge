import Foundation

@main struct V2Tests {
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw AssemblyError.message("TEST FAILED: " + message) }
        print("PASS: " + message)
    }
    static func main() async throws {
        setbuf(stdout, nil)
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let build = root.appendingPathComponent("build")
        let qa = build.appendingPathComponent("v2-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: qa, withIntermediateDirectories: true)
        let tools = Toolchain(ffmpeg: root.appendingPathComponent("vendor/ffmpeg"), ffprobe: root.appendingPathComponent("vendor/ffprobe"), logs: qa.appendingPathComponent("Logs"))
        let baseDirectories = try FileManager.default.contentsOfDirectory(at: build, includingPropertiesForKeys: [.creationDateKey]).filter { $0.lastPathComponent.hasPrefix("qa-") }.sorted {
            ((try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast) > ((try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast)
        }
        guard let base = baseDirectories.first else { throw AssemblyError.message("Сначала запустите базовые интеграционные тесты.") }
        let fixture = try FileManager.default.contentsOfDirectory(at: base, includingPropertiesForKeys: nil).first { $0.lastPathComponent.hasPrefix("Исходники") }!
        let video = fixture.appendingPathComponent("01_лекция_360p.mp4")
        let wav = fixture.appendingPathComponent("01_лекция_360p.ru.siri.voice.wav")
        var job = Matcher.analyze(Matcher.match(video), tools: tools)
        try check(job.status == .ready, "базовый комплект для версии 2 готов")
        for resolution in [Resolution.p144, .p1440, .p2160] {
            job.settings.resolution = resolution; job.settings.upscale = resolution != .p144
            let output = try Exporter.run(job, tools: tools, destination: qa, test: false, policy: .copy, token: Cancellation(), workerThreads: 4) { _, _, _ in }!
            let info = try MediaInfo.read(output, tools: tools)
            try check(info.video?.height == resolution.height, "реальный экспорт \(resolution.title)")
        }
        job.settings.upscale = false; job.settings.resolution = .p2160
        let capped = try ExportPlan(job, test: false)
        try check(capped.height == 360, "4K без разрешения увеличения остаётся 360p")
        var audio = Matcher.match(wav); audio.settings.mode = .audio; audio.settings.audioSource = .original
        var aacFile: URL?
        for profile in AudioProfile.allCases where !profile.isCopy {
            audio.settings.audioProfile = profile; audio = Matcher.analyze(audio, tools: tools)
            try check(audio.status == .ready, "подготовка \(profile.title) без видео и SRT")
            let output = try Exporter.run(audio, tools: tools, destination: qa, test: false, policy: .copy, token: Cancellation()) { _, _, _ in }!
            let info = try MediaInfo.read(output, tools: tools)
            try check(info.video == nil && info.audio.count == 1, "\(profile.title): в результате только звук")
            if profile == .aac128 { aacFile = output }
        }
        audio.settings.audioProfile = .aacCopy; audio = Matcher.analyze(audio, tools: tools)
        try check(audio.status == .review && audio.detail.contains("уже готовый AAC"), "WAV нельзя выдать за AAC без перекодирования")
        guard let aacFile else { throw AssemblyError.message("AAC fixture missing") }
        var copyJob = Matcher.match(aacFile); copyJob.settings.mode = .audio; copyJob.settings.audioProfile = .aacCopy
        copyJob = Matcher.analyze(copyJob, tools: tools)
        let copied = try Exporter.run(copyJob, tools: tools, destination: qa, test: false, policy: .copy, token: Cancellation()) { _, _, _ in }!
        func hash(_ file: URL) throws -> Data {
            try Runner.run(tools.ffmpeg, ["-v", "error", "-i", file.path, "-map", "0:a:0", "-c", "copy", "-f", "hash", "-hash", "sha256", "-"], logs: tools.logs)
        }
        let firstHash = try hash(aacFile), secondHash = try hash(copied)
        try check(firstHash == secondHash, "AAC без перекодирования: хеш сжатых аудиопакетов совпадает")
        for rate in [24000, 48000] {
            let voice = qa.appendingPathComponent("voice-\(rate).m4a")
            try Runner.run(tools.ffmpeg, ["-v", "error", "-n", "-i", wav.path, "-af", "apad=whole_dur=6,atrim=duration=6", "-c:a", "aac_at", "-profile:a", "1", "-ar", String(rate), "-ac", rate == 24000 ? "1" : "2", "-b:a", "128k", voice.path], logs: tools.logs)
            var readyAAC = job; readyAAC.russianAudio = voice; readyAAC.settings.resolution = .copy
            readyAAC = Matcher.analyze(readyAAC, tools: tools)
            let copyPlan = try ExportPlan(readyAAC, test: false)
            try check(copyPlan.copyRussianAudio, "RU \(rate) Гц: готовый AAC-LC выбирает копирование в MP4")
            let movie = try Exporter.run(readyAAC, tools: tools, destination: qa, test: false, policy: .copy, token: Cancellation()) { _, _, _ in }!
            func timedHash(_ file: URL) throws -> Data {
                try Runner.run(tools.ffmpeg, ["-v", "error", "-i", file.path, "-map", "0:a:0", "-t", "6", "-c", "copy", "-f", "hash", "-hash", "sha256", "-"], logs: tools.logs)
            }
            let before = try timedHash(voice), after = try timedHash(movie)
            try check(before == after, "RU \(rate) Гц: сжатые пакеты M4A и MP4 побитно совпадают")
            func pcm(_ url: URL) throws -> Data { try Runner.run(tools.ffmpeg, ["-v", "error", "-i", url.path, "-map", "0:a:0", "-t", "5.3", "-f", "s16le", "-"], logs: tools.logs) }
            let decodedBefore = try pcm(voice), decodedAfter = try pcm(movie)
            try check(decodedBefore == decodedAfter, "RU \(rate) Гц: декодированный звук и начало временной шкалы совпадают")
            readyAAC.settings.copyRussianAAC = false
            let forced = try ExportPlan(readyAAC, test: false)
            try check(!forced.copyRussianAudio, "Повторное кодирование RU можно включить вручную")
        }
        var shortAAC = job; shortAAC.russianAudio = aacFile; shortAAC = Matcher.analyze(shortAAC, tools: tools)
        let shortPlan = try ExportPlan(shortAAC, test: false)
        try check(shortPlan.copyRussianAudio && shortPlan.russianAudioDescription.contains("конец видео сохраняется"), "Короткий AAC копируется; тихий хвост видео сохраняется")
        let shortMovie = try Exporter.run(shortAAC, tools: tools, destination: qa, test: false, policy: .copy, token: Cancellation()) { _, _, _ in }!
        let shortMovieInfo = try MediaInfo.read(shortMovie, tools: tools)
        let shortBefore = try hash(aacFile), shortAfter = try hash(shortMovie)
        try check(shortBefore == shortAfter && shortMovieInfo.duration >= 5.96, "Копирование короткого AAC сохраняет все пакеты звука и весь видеоряд")
        copyJob.settings.aacContainer = .adts
        let raw = try Exporter.run(copyJob, tools: tools, destination: qa, test: false, policy: .copy, token: Cancellation()) { _, _, _ in }!
        try check(raw.pathExtension == "aac", "экспорт чистого .aac ADTS")
        var rawJob = Matcher.match(raw); rawJob.settings.mode = .audio; rawJob.settings.audioProfile = .mp3320
        rawJob = Matcher.analyze(rawJob, tools: tools)
        _ = try Exporter.run(rawJob, tools: tools, destination: qa, test: false, policy: .copy, token: Cancellation()) { _, _, _ in }
        try check(rawJob.status == .ready, "длительность входного .aac подсчитана по пакетам")
        var extract = job; extract.settings.mode = .audio; extract.settings.audioSource = .original; extract.settings.audioProfile = .aacCopy
        extract.russianAudio = nil; extract.russianSRT = nil; extract.germanSRT = nil
        extract = Matcher.analyze(extract, tools: tools)
        let extracted = try Exporter.run(extract, tools: tools, destination: qa, test: false, policy: .copy, token: Cancellation()) { _, _, _ in }!
        try check(extracted.pathExtension == "m4a", "AAC из видео извлечён без озвучки и субтитров")
        // Four copies of the same name prove atomic publication under contention.
        var parallelJob = job; parallelJob.settings.resolution = .p144
        let testJob = parallelJob
        let folder = qa.appendingPathComponent("parallel")
        let urls = try await withThrowingTaskGroup(of: URL.self) { group in
            for _ in 0..<4 {
                group.addTask {
                    try Exporter.run(testJob, tools: tools, destination: folder, test: false, policy: .copy, token: Cancellation(), workerThreads: 2) { _, _, _ in }!
                }
            }
            var output: [URL] = []; for try await file in group { output.append(file) }; return output
        }
        try check(Set(urls).count == 4, "четыре параллельных задания публикуют разные файлы при одинаковых именах")
        job.output = urls[0]; job.status = .completed
        let project = LectureProject(lectures: [SavedLecture(job), SavedLecture(audio)], common: job.settings, destination: qa, recursive: true, parallelism: .four)
        let projectPath = qa.appendingPathComponent("Проект ü.olyalecture")
        try project.save(projectPath)
        let read = try LectureProject.read(projectPath)
        let originalBytes = try project.encoded(), restoredBytes = try read.encoded()
        try check(originalBytes == restoredBytes, "проект сохраняет Unicode-пути, настройки, очередь и завершённые задания")
        try check(read.lectures[0].restore().settings.resolution == .p2160 && read.parallelism == .four, "разрешение и параллельность восстановлены")
        do { try project.save(video); throw AssemblyError.message("Project overwrote source media") }
        catch { try check(error.localizedDescription.contains("Нельзя сохранить"), "проект не может перезаписать исходный медиафайл") }
        var duplicate = project; duplicate.lectures = [project.lectures[0], project.lectures[0]]
        let duplicatePath = qa.appendingPathComponent("duplicate.olyalecture"); try duplicate.encoded().write(to: duplicatePath)
        do { _ = try LectureProject.read(duplicatePath); throw AssemblyError.message("Duplicate IDs were accepted") }
        catch { try check(error.localizedDescription.contains("повторяются"), "повреждённый проект отклонён без подмены очереди") }
        print("ALL V2 TESTS PASSED: \(qa.path)")
    }
}
