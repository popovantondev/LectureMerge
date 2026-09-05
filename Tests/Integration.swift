import Foundation
import Darwin

@main struct Integration {
    static func require(_ value: @autoclosure () -> Bool, _ message: String) throws {
        if !value() { throw AssemblyError.message("TEST FAILED: " + message) }
        print("PASS: " + message)
    }
    static func main() throws {
        setbuf(stdout, nil)
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let run = root.appendingPathComponent("build/qa-" + UUID().uuidString)
        let fixtures = run.appendingPathComponent("Исходники с пробелами ü"), outputs = run.appendingPathComponent("Результаты")
        let tools = Toolchain(ffmpeg: root.appendingPathComponent("vendor/ffmpeg"), ffprobe: root.appendingPathComponent("vendor/ffprobe"), logs: run.appendingPathComponent("Logs"))
        if CommandLine.arguments.contains("--full-only") {
            guard let path = ProcessInfo.processInfo.environment["LECTURE_TEST_VIDEO"] else { throw AssemblyError.message("Set LECTURE_TEST_VIDEO to a real complete lecture video.") }
            let input = URL(fileURLWithPath: path)
            var full = Matcher.analyze(Matcher.match(input), tools: tools)
            full.settings.resolution = .p240
            let start = Date()
            var last = -1
            let file = try Exporter.run(full, tools: tools, destination: root.appendingPathComponent("Тестовые результаты"), test: false, policy: .copy, token: Cancellation()) { fraction, speed, validating in
                let percent = Int(fraction * 100)
                if percent / 10 > last { last = percent / 10; print("FULL: \(percent)%, \(speed)x, validation=\(validating)") }
            }!
            let info = try MediaInfo.read(file, tools: tools)
            print("FULL PASSED: \(info.duration) sec, \(Date().timeIntervalSince(start)) sec elapsed, \(file.path)")
            return
        }
        try FileManager.default.createDirectory(at: fixtures, withIntermediateDirectories: true)
        func ff(_ args: [String]) throws { try Runner.run(tools.ffmpeg, ["-hide_banner", "-nostdin", "-v", "error", "-n"] + args, logs: tools.logs) }
        let video = fixtures.appendingPathComponent("01_лекция_360p.mp4")
        let ru = fixtures.appendingPathComponent("01_лекция_360p.ru.siri.voice.wav")
        try ff(["-f", "lavfi", "-i", "testsrc2=size=640x360:rate=25:duration=6", "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000:duration=6", "-c:v", "h264_videotoolbox", "-allow_sw", "0", "-b:v", "1000k", "-pix_fmt", "yuv420p", "-c:a", "aac", "-metadata:s:a:0", "language=deu", video.path])
        try ff(["-f", "lavfi", "-i", "sine=frequency=880:sample_rate=24000:duration=5.4", "-c:a", "pcm_s16le", ru.path])
        let srt = "1\n00:00:00,300 --> 00:00:01,000\nКороткие субтитры — проверка конца видео.\n\n"
        try srt.write(to: video.deletingPathExtension().appendingPathExtension("ru.srt"), atomically: true, encoding: .utf8)
        try srt.replacingOccurrences(of: "Короткие субтитры — проверка конца видео.", with: "Deutsche Untertitel.").write(to: video.deletingPathExtension().appendingPathExtension("srt"), atomically: true, encoding: .utf8)
        try "report".write(to: fixtures.appendingPathComponent("01_лекция_360p.ru.siri.voice.report.txt"), atomically: true, encoding: .utf8)
        try Data().write(to: fixtures.appendingPathComponent("01_лекция_360p.ru.mp4"))
        let matched = Matcher.videos(in: [fixtures], recursive: false)
        try require(matched == [video], "точный подбор; отчёты и собственные экспорты игнорируются")
        var job = Matcher.analyze(Matcher.match(video), tools: tools)
        try require(job.status == .ready, "комплект с кириллицей, Unicode и пробелами готов: " + job.detail)
        try require(job.russianSRT != job.germanSRT, "RU и DE SRT различаются")
        let alternate = video.deletingPathExtension().appendingPathExtension("ru.wav")
        try FileManager.default.copyItem(at: ru, to: alternate)
        let ambiguous = Matcher.analyze(Matcher.match(video), tools: tools)
        try require(ambiguous.status == .ambiguous && ambiguous.russianAudio == nil, "неоднозначная озвучка не выбирается произвольно")
        try FileManager.default.removeItem(at: alternate)
        let sourceBefore = try Data(contentsOf: video), ruBefore = try Data(contentsOf: ru)
        job.settings.resolution = .copy
        let plan = try ExportPlan(job, test: false)
        try require(plan.copyVideo, "режим без перекодирования")
        let copy = try Exporter.run(job, tools: tools, destination: outputs, test: false, policy: .copy, token: Cancellation()) { _, _, _ in }!
        let info = try MediaInfo.read(copy, tools: tools)
        try require(info.duration >= 5.96 && (info.audio[0].seconds ?? 0) >= 5.9, "WAV короче на 0,6 с и короткие SRT не обрезали конец")
        try require(info.audio.map(\.language) == ["rus", "deu"] && info.audio[0].isDefault && !info.audio[1].isDefault, "RU первая/default, DE вторая")
        func videoHash(_ file: URL) throws -> Data {
            try Runner.run(tools.ffmpeg, ["-v", "error", "-i", file.path, "-map", "0:v:0", "-c", "copy", "-f", "hash", "-hash", "sha256", "-"], logs: tools.logs)
        }
        let hashBefore = try videoHash(video), hashAfter = try videoHash(copy)
        try require(hashBefore == hashAfter, "хеш сжатого видеопотока идентичен после копирования")
        let outputBefore = try Data(contentsOf: copy)
        let second = try Exporter.run(job, tools: tools, destination: outputs, test: false, policy: .copy, token: Cancellation()) { _, _, _ in }!
        try require(second != copy && FileManager.default.fileExists(atPath: second.path), "конфликт имени создаёт отдельную копию")
        let skipped = try Exporter.run(job, tools: tools, destination: outputs, test: false, policy: .skip, token: Cancellation()) { _, _, _ in }
        try require(skipped == nil, "существующий результат пропускается")
        let replaced = try Exporter.run(job, tools: tools, destination: outputs, test: false, policy: .replace, token: Cancellation()) { _, _, _ in }
        try require(replaced == copy, "проверенный MP4 атомарно заменяет результат при явном режиме replace")
        let fake = run.appendingPathComponent("failing-ffmpeg")
        try "#!/bin/sh\nfor last do :; done\nprintf broken > \"$last\"\nexit 7\n".write(to: fake, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fake.path)
        let failingTools = Toolchain(ffmpeg: fake, ffprobe: tools.ffprobe, logs: tools.logs)
        let goodBeforeFailure = try Data(contentsOf: copy)
        do {
            _ = try Exporter.run(job, tools: failingTools, destination: outputs, test: false, policy: .replace, token: Cancellation()) { _, _, _ in }
            throw AssemblyError.message("TEST FAILED: failed export succeeded")
        } catch { try require(error.localizedDescription.contains("7"), "ошибка FFmpeg передана пользователю") }
        let goodAfterFailure = try Data(contentsOf: copy)
        try require(goodBeforeFailure == goodAfterFailure, "сбой замены сохранил прежний готовый MP4")
        job.settings.resolution = .p240
        let smaller = try Exporter.run(job, tools: tools, destination: outputs, test: false, policy: .copy, token: Cancellation()) { _, _, _ in }!
        let smallInfo = try MediaInfo.read(smaller, tools: tools)
        try require(smallInfo.video?.height == 240 && smallInfo.video?.width == 426, "реальное аппаратное H.264 240p с сохранением пропорций")
        for resolution in [Resolution.p360, .p480, .p720, .p1080] {
            job.settings.resolution = resolution
            let p = try ExportPlan(job, test: false)
            try require(p.height == 360, "\(resolution.title): автоматическое увеличение выключено")
        }
        job.settings.resolution = .p1080; job.settings.upscale = true
        let up = try ExportPlan(job, test: false)
        try require(up.height == 1080 && up.width == 1920, "увеличение возможно только при явном включении")
        job.settings.upscale = false; job.settings.resolution = .p240
        let token = Cancellation()
        do {
            _ = try Exporter.run(job, tools: tools, destination: outputs, test: false, policy: .copy, token: token) { _, _, _ in token.cancel() }
            throw AssemblyError.message("TEST FAILED: cancellation ignored")
        } catch { try require(token.isCancelled, "остановка прерывает экспорт") }
        let remaining = try FileManager.default.contentsOfDirectory(at: outputs, includingPropertiesForKeys: nil)
        try require(!remaining.contains { $0.lastPathComponent.contains(".partial.") }, "после остановки и ошибки нет временных MP4")
        let sourceAfter = try Data(contentsOf: video), ruAfter = try Data(contentsOf: ru)
        try require(sourceAfter == sourceBefore && ruAfter == ruBefore, "исходные видео и WAV не изменились")
        try require(!outputBefore.isEmpty, "первый результат содержит данные")
        let rotated = fixtures.appendingPathComponent("rotated.mp4")
        try ff(["-display_rotation", "90", "-i", video.path, "-c", "copy", rotated.path])
        var rotatedJob = job; rotatedJob.video = rotated; rotatedJob.info = try MediaInfo.read(rotated, tools: tools)
        let rotatedPlan = try ExportPlan(rotatedJob, test: false)
        try require(rotatedPlan.width == 136 && rotatedPlan.height == 240, "поворот учтён при вычислении портретных размеров")
        let rotatedOutput = try Exporter.run(rotatedJob, tools: tools, destination: outputs, test: false, policy: .copy, token: Cancellation()) { _, _, _ in }!
        let rotatedInfo = try MediaInfo.read(rotatedOutput, tools: tools)
        try require(rotatedInfo.video?.width == 136 && rotatedInfo.video?.height == 240, "портретное видео после поворота действительно закодировано правильно")
        var mismatch = job
        mismatch.russianInfo = nil
        let longRU = fixtures.appendingPathComponent("wrong.wav")
        try ff(["-f", "lavfi", "-i", "sine=duration=15", "-c:a", "pcm_s16le", longRU.path])
        mismatch.russianAudio = longRU
        mismatch = Matcher.analyze(mismatch, tools: tools)
        try require(mismatch.status == .review && mismatch.detail.contains("длиннее видео"), "длинная RU-дорожка предупреждает о возможной обрезке слов")

        let shortRU = fixtures.appendingPathComponent("short-matching.ru.siri.voice.m4a")
        try ff(["-f", "lavfi", "-i", "sine=frequency=880:sample_rate=48000:duration=1", "-c:a", "aac", "-b:a", "128k", shortRU.path])
        var alignedShort = job
        alignedShort.russianAudio = shortRU
        alignedShort = Matcher.analyze(alignedShort, tools: tools)
        try require(alignedShort.status == .ready && alignedShort.detail.contains("Озвучка совпадает с SRT") && alignedShort.detail.contains("без перекодирования"), "короткая M4A, совпадающая с концом RU SRT, разрешена")
        let alignedOutput = try Exporter.run(alignedShort, tools: tools, destination: outputs, test: false, policy: .copy, token: Cancellation()) { _, _, _ in }!
        let alignedInfo = try MediaInfo.read(alignedOutput, tools: tools)
        try require(alignedInfo.duration >= 5.96 && (alignedInfo.audio[0].seconds ?? 0) < 1.2, "короткий AAC не растянут, полный видеоряд сохранён")

        let mismatchedSRT = fixtures.appendingPathComponent("short-mismatch.ru.srt")
        try "1\n00:00:00,300 --> 00:00:03,000\nРеплика заканчивается позже звука.\n\n".write(to: mismatchedSRT, atomically: true, encoding: .utf8)
        var mismatchedShort = alignedShort
        mismatchedShort.russianSRT = mismatchedSRT
        mismatchedShort = Matcher.analyze(mismatchedShort, tools: tools)
        try require(mismatchedShort.status == .review && mismatchedShort.detail.contains("не совпадает с концом RU SRT"), "короткая RU-дорожка, не совпадающая с SRT, остаётся на проверке")
        let mkv = fixtures.appendingPathComponent("German PCM.mkv")
        try ff(["-i", video.path, "-map", "0:v:0", "-map", "0:a:0", "-c:v", "copy", "-c:a", "pcm_s16le", mkv.path])
        var mkvJob = job; mkvJob.video = mkv; mkvJob.germanIndex = nil
        mkvJob = Matcher.analyze(mkvJob, tools: tools)
        try require(mkvJob.status == .ready, "исходник MKV с немецким PCM готов")
        let mkvOutput = try Exporter.run(mkvJob, tools: tools, destination: outputs, test: false, policy: .copy, token: Cancellation()) { _, _, _ in }!
        let mkvInfo = try MediaInfo.read(mkvOutput, tools: tools)
        try require(mkvInfo.audio[1].isAACLC, "немецкий PCM преобразован в AAC-LC")
        let m4a = fixtures.appendingPathComponent("Русская озвучка.m4a")
        try ff(["-i", ru.path, "-c:a", "aac", m4a.path])
        var m4aJob = job; m4aJob.russianAudio = m4a
        m4aJob = Matcher.analyze(m4aJob, tools: tools)
        try require(m4aJob.status == .ready, "русская озвучка M4A поддерживается")
        _ = try Exporter.run(m4aJob, tools: tools, destination: outputs, test: true, policy: .copy, token: Cancellation()) { _, _, _ in }
        let multi = fixtures.appendingPathComponent("Несколько дорожек.mp4")
        try ff(["-i", video.path, "-map", "0:v:0", "-map", "0:a:0", "-map", "0:a:0", "-c", "copy", "-metadata:s:a:0", "language=eng", "-metadata:s:a:1", "language=und", multi.path])
        var multiJob = job; multiJob.video = multi; multiJob.germanIndex = nil
        multiJob = Matcher.analyze(multiJob, tools: tools)
        try require(multiJob.status == .review && multiJob.germanIndex == nil, "при нескольких непомеченных дорожках нужен явный выбор DE")
        multiJob.germanIndex = 2; multiJob = Matcher.analyze(multiJob, tools: tools)
        try require(multiJob.status == .ready, "ручной выбор второй исходной аудиодорожки")
        _ = try Exporter.run(multiJob, tools: tools, destination: outputs, test: false, policy: .copy, token: Cancellation()) { _, _, _ in }
        var emptyJob = job
        for language in ["ru", "de"] {
            let file = fixtures.appendingPathComponent("late-\(language).srt")
            try "1\n00:00:07,000 --> 00:00:09,000\nТолько после конца фрагмента\n\n".write(to: file, atomically: true, encoding: .utf8)
            if language == "ru" { emptyJob.russianSRT = file } else { emptyJob.germanSRT = file }
        }
        let emptyOutput = try Exporter.run(emptyJob, tools: tools, destination: outputs, test: true, policy: .copy, token: Cancellation()) { _, _, _ in }!
        let emptyInfo = try MediaInfo.read(emptyOutput, tools: tools)
        try require(emptyInfo.subtitles.count == 2, "обе дорожки субтитров есть даже без реплик в тестовом фрагменте")
        let crossing = fixtures.appendingPathComponent("crossing.srt")
        try "1\n00:00:01,000 --> 00:00:50,000\nДлинная реплика\n\n".write(to: crossing, atomically: true, encoding: .utf8)
        let clipped = try Subtitles.clipped(crossing, duration: 6)
        try require(clipped.contains("00:00:06,000") && !clipped.contains("00:00:50,000"), "конец пересекающего границу субтитра ограничен длиной видео")
        if CommandLine.arguments.contains("--real") {
            guard let path = ProcessInfo.processInfo.environment["LECTURE_TEST_FOLDER"] else { throw AssemblyError.message("Set LECTURE_TEST_FOLDER to a folder of complete lecture inputs.") }
            let day = URL(fileURLWithPath: path)
            let videos = Matcher.videos(in: [day], recursive: false)
            try require(!videos.isEmpty, "Папка содержит лекции для проверки")
            var realJobs: [Lecture] = []
            for file in videos {
                let real = Matcher.analyze(Matcher.match(file), tools: tools)
                try require(real.status == .ready, "Реальная лекция: \(real.basename) — готова: \(real.detail)")
                realJobs.append(real)
            }
            let destination = root.appendingPathComponent("Тестовые результаты")
            var real = realJobs[0]
            for mode in [Resolution.copy, .p240, .p720] {
                real.settings.resolution = mode; real.settings.recompress = mode == .p720
                let start = Date()
                let file = try Exporter.run(real, tools: tools, destination: destination, test: true, policy: .copy, token: Cancellation()) { _, _, _ in }!
                print("REAL: \(mode.title), \(Date().timeIntervalSince(start)) sec, \(file.path)")
            }
        }
        print("ALL PASSED. QA artifacts: \(run.path)")
    }
}
