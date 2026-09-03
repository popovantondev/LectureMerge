import Foundation

struct SavedLecture: Codable {
    var id: UUID
    var video: URL
    var russianAudio: URL?
    var russianSRT: URL?
    var germanSRT: URL?
    var germanIndex: Int?
    var settings: ExportSettings
    var enabled: Bool
    var output: URL?
    var completed: Bool
    init(_ job: Lecture) {
        id = job.id; video = job.video; russianAudio = job.russianAudio; russianSRT = job.russianSRT
        germanSRT = job.germanSRT; germanIndex = job.germanIndex; settings = job.settings
        enabled = job.enabled; output = job.output; completed = job.status == .completed
    }
    func restore() -> Lecture {
        var job = Matcher.match(video)
        job.id = id; job.russianAudio = russianAudio; job.russianSRT = russianSRT; job.germanSRT = germanSRT
        job.germanIndex = germanIndex; job.settings = settings; job.enabled = enabled; job.output = output
        return job
    }
}
struct LectureProject: Codable {
    var formatVersion = 2
    var lectures: [SavedLecture]
    var common: ExportSettings
    var destination: URL?
    var recursive: Bool
    var parallelism: Parallelism
    // Replacement consent is never persisted. Opening a project starts with safe copies.
    func encoded() throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }
    static func read(_ url: URL) throws -> LectureProject {
        let data = try Data(contentsOf: url)
        guard data.count < 20_000_000 else { throw AssemblyError.message("Файл проекта слишком большой.") }
        let project = try JSONDecoder().decode(Self.self, from: data)
        guard project.formatVersion == 2, project.lectures.count <= 10_000 else { throw AssemblyError.message("Неподдерживаемая версия или размер проекта.") }
        var ids = Set<UUID>()
        for row in project.lectures {
            guard ids.insert(row.id).inserted else { throw AssemblyError.message("В проекте повторяются идентификаторы заданий.") }
            let urls = [row.video, row.russianAudio, row.russianSRT, row.germanSRT, row.output, project.destination]
            for url in urls { if let url, !url.isFileURL { throw AssemblyError.message("Проекты поддерживают только локальные файлы.") } }
        }
        return project
    }
    func save(_ url: URL) throws {
        let inputPaths = Set(lectures.flatMap { [$0.video, $0.russianAudio, $0.russianSRT, $0.germanSRT].compactMap { $0?.resolvingSymlinksInPath().path } })
        guard !inputPaths.contains(url.resolvingSymlinksInPath().path) else { throw AssemblyError.message("Нельзя сохранить проект поверх исходного медиафайла.") }
        try encoded().write(to: url, options: .atomic)
    }
}
