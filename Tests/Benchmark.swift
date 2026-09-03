import Foundation

@main struct Benchmark {
    static func main() async throws {
        setbuf(stdout, nil)
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let build = root.appendingPathComponent("build")
        let tools = Toolchain(ffmpeg: root.appendingPathComponent("vendor/ffmpeg"), ffprobe: root.appendingPathComponent("vendor/ffprobe"), logs: build.appendingPathComponent("benchmark-logs"))
        let jobs = Matcher.videos(in: [build.appendingPathComponent("benchmark-inputs")], recursive: false).map { file -> Lecture in
            var job = Matcher.analyze(Matcher.match(file), tools: tools); job.settings.resolution = .p240; return job
        }
        guard jobs.count == 4 && jobs.allSatisfy({ $0.status == .ready }) else { throw AssemblyError.message("Benchmark fixtures not ready: \(jobs.map(\.detail))") }
        let batch = jobs + jobs
        var measurements: [[String: Double]] = []
        for workers in 1...4 {
            let started = Date()
            let destination = build.appendingPathComponent("benchmark-output-\(workers)")
            try await withThrowingTaskGroup(of: Void.self) { group in
                var next = 0
                func submit(_ index: Int) {
                    group.addTask {
                        _ = try Exporter.run(batch[index], tools: tools, destination: destination, test: false, policy: .copy, token: Cancellation(), workerThreads: max(1, ProcessInfo.processInfo.activeProcessorCount / workers)) { _, _, _ in }
                    }
                }
                while next < min(workers, batch.count) { submit(next); next += 1 }
                while try await group.next() != nil { if next < batch.count { submit(next); next += 1 } }
            }
            let seconds = Date().timeIntervalSince(started)
            measurements.append(["workers": Double(workers), "seconds": seconds])
            print("\(workers) concurrent: \(seconds) seconds for 8 × 180 seconds of real lecture video")
        }
        try JSONSerialization.data(withJSONObject: measurements, options: .prettyPrinted).write(to: build.appendingPathComponent("parallel-benchmark.json"))
    }
}
