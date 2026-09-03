import Foundation

@main struct FullAAC {
    static func main() throws {
        setbuf(stdout, nil)
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let folder = root.appendingPathComponent("build/full-aac-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let tools = Toolchain(ffmpeg: root.appendingPathComponent("vendor/ffmpeg"), ffprobe: root.appendingPathComponent("vendor/ffprobe"), logs: folder.appendingPathComponent("Logs"))
        guard let path = ProcessInfo.processInfo.environment["LECTURE_TEST_VIDEO"] else { throw AssemblyError.message("Set LECTURE_TEST_VIDEO to a real lecture video with matching WAV and SRT.") }
        let source = URL(fileURLWithPath: path)
        let voice = folder.appendingPathComponent("voice.ru.siri.voice.m4a")
        // Same format and encoder options as SRT Voiceover/srt_gui_job.rb.
        if !FileManager.default.fileExists(atPath: voice.path) {
            try Runner.run(tools.ffmpeg, ["-v", "error", "-n", "-i", source.deletingPathExtension().appendingPathExtension("ru.siri.voice.wav").path, "-map", "0:a:0", "-map_metadata", "-1", "-c:a", "aac", "-profile:a", "aac_low", "-b:a", "128k", "-ar", "48000", "-ac", "2", "-metadata:s:a:0", "language=rus", "-movflags", "+faststart", "-f", "ipod", voice.path], logs: tools.logs)
        }
        var job = Matcher.match(source); job.russianAudio = voice; job.settings.resolution = .p240
        job = Matcher.analyze(job, tools: tools)
        let plan = try ExportPlan(job, test: false)
        guard job.status == .ready && plan.copyRussianAudio else { throw AssemblyError.message(job.detail) }
        let started = Date()
        let output = try Exporter.run(job, tools: tools, destination: root.appendingPathComponent("Тестовые результаты/AAC без перекодирования"), test: false, policy: .copy, token: Cancellation(), workerThreads: 4) { _, _, _ in }!
        let seconds = Date().timeIntervalSince(started)
        for codec in ["copy", "pcm_s16le"] {
            func hash(_ url: URL) throws -> Data {
                try Runner.run(tools.ffmpeg, ["-v", "error", "-i", url.path, "-map", "0:a:0", "-c:a", codec, "-f", "hash", "-hash", "sha256", "-"], logs: tools.logs)
            }
            let before = try hash(voice), after = try hash(output)
            guard before == after else { throw AssemblyError.message("Full AAC \(codec) differs") }
            print("PASS: full lecture RU \(codec) hashes identical")
        }
        let info = try MediaInfo.read(output, tools: tools)
        let result: [String: Any] = ["seconds": seconds, "videoDuration": info.duration, "russianDuration": info.audio[0].seconds ?? 0, "output": output.path, "sourceAAC": voice.path]
        try JSONSerialization.data(withJSONObject: result, options: .prettyPrinted).write(to: root.appendingPathComponent("build/full-aac-results.json"))
        print("FULL AAC PASSED: \(result)")
    }
}
