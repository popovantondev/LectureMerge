import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor final class QueueModel: ObservableObject {
    @Published var jobs: [Lecture] = []
    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
            if !busy { queueText = localized("Добавьте видео, аудио или папку с лекциями", language: language); eta = "" }
        }
    }
    @Published var selected: UUID?
    @Published var common = ExportSettings()
    @Published var destination: URL?
    @Published var recursive = false
    @Published var parallelism: Parallelism = .auto
    @Published var policy: ConflictPolicy = .copy
    @Published var busy = false
    @Published var importing = false
    @Published var message: String?
    @Published var queueText = localized("Добавьте видео, аудио или папку с лекциями")
    @Published var queueProgress = 0.0
    @Published var eta = ""
    @Published var tools: Toolchain?
    @Published var projectURL: URL?
    private var savedData: Data?
    private var tokens: [UUID: Cancellation] = [:]
    private var runID = UUID()
    private var stopRequested = false
    private var runStarted = Date()
    private var weights: [UUID: Double] = [:]
    private var fractions: [UUID: Double] = [:]
    var locked: Bool { busy || importing }
    var current: Lecture? { jobs.first { $0.id == selected } }
    init() {
        language = AppLanguage.preferred
        queueText = localized("Добавьте видео, аудио или папку с лекциями", language: language)
        do { tools = try Toolchain.bundled() } catch { message = error.localizedDescription }
    }
    func mutate(_ id: UUID, _ update: (inout Lecture) -> Void) {
        if let index = jobs.firstIndex(where: { $0.id == id }) { update(&jobs[index]) }
    }
    func settingsBinding(_ id: UUID) -> Binding<ExportSettings> {
        Binding(get: { self.jobs.first { $0.id == id }?.settings ?? ExportSettings() }, set: { setting in
            guard !self.locked, let old = self.jobs.first(where: { $0.id == id })?.settings else { return }
            self.mutate(id) {
                $0.settings = setting
                if setting.mode == .audio && setting.audioSource == .original && (old.mode != setting.mode || old.audioSource != setting.audioSource) { $0.germanIndex = nil }
                if [.completed, .skipped].contains($0.status) { $0.status = .ready; $0.progress = 0 }
            }
            if old.mode != setting.mode || old.audioSource != setting.audioSource || old.audioProfile != setting.audioProfile || old.copyRussianAAC != setting.copyRussianAAC { self.reanalyze(id) }
        })
    }
    func chooseVideos(folder: Bool) {
        let panel = NSOpenPanel(); panel.canChooseDirectories = folder; panel.canChooseFiles = !folder
        panel.allowsMultipleSelection = true; panel.prompt = localized("Добавить", language: language)
        panel.message = folder ? localized("Папки с лекциями; звуковые файлы можно добавить отдельно", language: language) : localized("Видео MP4/MKV или аудио WAV/M4A/AAC/MP3/FLAC", language: language)
        if !folder { panel.allowedContentTypes = ["mp4", "mkv", "wav", "m4a", "aac", "mp3", "flac"].compactMap { UTType(filenameExtension: $0) } }
        if panel.runModal() == .OK { add(panel.urls) }
    }
    func add(_ urls: [URL]) {
        guard !locked, let tools else { return }
        importing = true; queueText = localized("Подбор файлов и анализ…", language: language)
        let recursive = recursive, settings = common
        let existing = Set(jobs.map { $0.video.resolvingSymlinksInPath().path })
        Task {
            let added = await Task.detached(priority: .userInitiated) {
                var paths = Matcher.videos(in: urls, recursive: recursive)
                // Explicit audio selection includes .ru.wav companions; folder scanning remains one row per video.
                for url in urls where ["mp4", "mkv", "wav", "m4a", "aac", "mp3", "flac"].contains(url.pathExtension.lowercased()) {
                    if (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true { paths.append(url.resolvingSymlinksInPath()) }
                }
                var seen = existing, result: [Lecture] = []
                for url in paths where seen.insert(url.path).inserted {
                    var job = Matcher.match(url); job.settings = settings
                    if job.primaryIsAudio { job.settings.mode = .audio; job.settings.audioSource = .original }
                    job = Matcher.analyze(job, tools: tools)
                    if settings.resolution == .p720, let height = job.info?.video?.displaySize.1, height < 720 { job.settings.resolution = .original }
                    result.append(job)
                }
                return result
            }.value
            jobs += added; if selected == nil { selected = added.first?.id }
            importing = false; queueText = added.isEmpty ? localized("Новых файлов не найдено", language: language) : localizedFormat("Добавлено: %d. Проверьте параметры справа.", language: language, added.count)
        }
    }
    func reanalyze(_ id: UUID) {
        guard !locked, let job = jobs.first(where: { $0.id == id }), let tools else { return }
        importing = true; mutate(id) { $0.status = .analyzing }
        Task {
            let result = await Task.detached { Matcher.analyze(job, tools: tools) }.value
            if let index = jobs.firstIndex(where: { $0.id == id }) { jobs[index] = result }
            importing = false
        }
    }
    func pickComponent(_ id: UUID, kind: String) {
        guard !locked else { return }
        let p = NSOpenPanel(); p.canChooseDirectories = false; p.allowsMultipleSelection = false
        p.prompt = localized("Выбрать", language: language); p.directoryURL = current?.video.deletingLastPathComponent()
        let extensions = kind == "primary" ? ["mp4", "mkv", "wav", "m4a", "aac", "mp3", "flac"] : kind == "audio" ? ["wav", "m4a", "aac", "mp3", "flac"] : ["srt"]
        p.allowedContentTypes = extensions.compactMap { UTType(filenameExtension: $0) }
        if p.runModal() == .OK, let url = p.url {
            mutate(id) { job in
                if kind == "primary" {
                    var replacement = Matcher.match(url); replacement.id = job.id; replacement.settings = job.settings; replacement.enabled = job.enabled
                    if replacement.primaryIsAudio { replacement.settings.mode = .audio; replacement.settings.audioSource = .original }
                    job = replacement
                } else if kind == "audio" { job.russianAudio = url }
                else if kind == "ru" { job.russianSRT = url }
                else { job.germanSRT = url }
            }
            reanalyze(id)
        }
    }
    func chooseDestination() {
        let p = NSOpenPanel(); p.canChooseFiles = false; p.canChooseDirectories = true; p.canCreateDirectories = true; p.prompt = localized("Сохранять сюда", language: language)
        if p.runModal() == .OK { destination = p.url }
    }
    func applyCommon() {
        guard !locked, let tools else { return }
        var snapshot = jobs
        for i in snapshot.indices {
            snapshot[i].settings = common
            if snapshot[i].primaryIsAudio { snapshot[i].settings.mode = .audio; snapshot[i].settings.audioSource = .original }
        }
        importing = true
        Task {
            jobs = await Task.detached { snapshot.map { Matcher.analyze($0, tools: tools) } }.value
            importing = false
        }
    }
    func remove(_ id: UUID) {
        guard !locked else { return }
        let index = jobs.firstIndex { $0.id == id } ?? 0
        jobs.removeAll { $0.id == id }
        if selected == id { selected = jobs.isEmpty ? nil : jobs[min(index, jobs.count - 1)].id }
        queueText = jobs.isEmpty ? localized("Очередь пуста. Файлы на диске сохранены.", language: language) : localized("Задание удалено из очереди. Файлы на диске сохранены.", language: language)
    }
    func removeSelection() { if let selected { remove(selected) } }
    func clearQueue() {
        guard !locked else { return }
        jobs.removeAll(); selected = nil; queueProgress = 0; eta = ""
        queueText = localized("Очередь очищена. Исходники и результаты на диске сохранены.", language: language)
    }
    func newProject() {
        guard !locked, confirmDiscard() else { return }
        jobs.removeAll(); selected = nil; common = ExportSettings(); destination = nil
        recursive = false; parallelism = .auto; policy = .copy
        projectURL = nil; savedData = nil; queueProgress = 0; eta = ""
        queueText = localized("Новый проект. Добавьте видео, аудио или папку с лекциями.", language: language)
    }
    func show(_ url: URL) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    func project() -> LectureProject {
        LectureProject(lectures: jobs.map(SavedLecture.init), common: common, destination: destination, recursive: recursive, parallelism: parallelism)
    }
    var hasUnsavedChanges: Bool {
        if savedData == nil { return !jobs.isEmpty }
        return (try? project().encoded()) != savedData
    }
    @discardableResult func saveProject(asNew: Bool = false) -> Bool {
        guard !locked else { return false }
        var target = projectURL
        if target == nil || asNew {
            let p = NSSavePanel(); p.allowedContentTypes = [UTType(filenameExtension: "olyalecture") ?? .json]
            p.nameFieldStringValue = projectURL?.lastPathComponent ?? localized("Лекции.olyalecture", language: language)
            p.canCreateDirectories = true
            p.message = localized("Сохраняются список, выбранные файлы, настройки и готовые результаты. Медиафайлы не копируются.", language: language)
            guard p.runModal() == .OK, let url = p.url else { return false }; target = url
        }
        do {
            let snapshot = project(); try snapshot.save(target!)
            savedData = try snapshot.encoded(); projectURL = target; queueText = localizedFormat("Проект сохранён: %@", language: language, target!.lastPathComponent); return true
        } catch { message = error.localizedDescription; return false }
    }
    func confirmDiscard() -> Bool {
        guard hasUnsavedChanges else { return true }
        let alert = NSAlert(); alert.messageText = localized("Сохранить изменения проекта?", language: language)
        alert.informativeText = localized("Список и настройки изменились. Медиафайлы остаются на диске.", language: language)
        alert.addButton(withTitle: localized("Сохранить", language: language)); alert.addButton(withTitle: localized("Не сохранять", language: language)); alert.addButton(withTitle: localized("Отмена", language: language))
        let response = alert.runModal()
        if response == .alertFirstButtonReturn { return saveProject() }
        return response == .alertSecondButtonReturn
    }
    func openProject(_ url: URL? = nil) {
        guard !locked, confirmDiscard(), let tools else { return }
        var target = url
        if target == nil {
            let p = NSOpenPanel(); p.allowedContentTypes = [UTType(filenameExtension: "olyalecture") ?? .json]
            p.canChooseDirectories = false; p.allowsMultipleSelection = false
            guard p.runModal() == .OK else { return }; target = p.url
        }
        guard let target else { return }
        do {
            let saved = try LectureProject.read(target)
            importing = true; queueText = localized("Открываю проект и проверяю файлы…", language: language)
            let currentLanguage = language
            Task {
                let restored = await Task.detached { () -> [Lecture] in
                    saved.lectures.map { row in
                        var job = Matcher.analyze(row.restore(), tools: tools)
                        if row.completed, job.status == .ready, let output = row.output, FileManager.default.isReadableFile(atPath: output.path) {
                            do {
                                if job.settings.mode == .audio { try AudioExporter.validate(output, plan: AudioPlan(job, test: false), tools: tools, token: Cancellation()) }
                                else { _ = try Exporter.validate(output, plan: ExportPlan(job, test: false), tools: tools, token: Cancellation()) }
                    job.status = .completed; job.progress = 1; job.detail = localized("Готовый результат из проекта проверен.", language: currentLanguage)
                            } catch { job.detail = "Результат проекта требует повторного экспорта: " + error.localizedDescription }
                        }
                        return job
                    }
                }.value
                jobs = restored; selected = restored.first?.id; common = saved.common; destination = saved.destination
                recursive = saved.recursive; parallelism = saved.parallelism; policy = .copy; projectURL = target
                importing = false; savedData = try? project().encoded(); queueProgress = 0; eta = ""
                queueText = localizedFormat("Проект открыт: %@", language: language, target.lastPathComponent)
            }
            } catch { message = localizedFormat("Не удалось открыть проект: %@", language: language, error.localizedDescription) }
    }
    func start(test: Bool) {
        guard !locked, let tools else { return }
        var pending: [Lecture] = []
        if test { if let job = current { pending.append(job) } }
        else { for job in jobs where job.enabled && job.status != .completed { pending.append(job) } }
        guard !pending.isEmpty else { message = localized("Нет заданий для запуска.", language: language); return }
        do {
            for job in pending {
                guard [.ready, .completed, .failed, .stopped, .skipped].contains(job.status) else { throw AssemblyError.message("\(job.basename): \(job.detail)") }
                _ = try PlannedOutput(job, test: test)
            }
            if policy == .replace {
                var names = Set<String>(), collisions: [String] = []
                for job in pending {
                    let plan = try PlannedOutput(job, test: test)
                    let folder = destination ?? job.video.deletingLastPathComponent().appendingPathComponent("Готовое")
                    let path = folder.appendingPathComponent(plan.filename).standardizedFileURL.resolvingSymlinksInPath().path
                    guard names.insert(path).inserted else { throw AssemblyError.message("Несколько заданий имеют одинаковое имя результата. Выберите «Сохранить копию», чтобы сохранить каждое.") }
                    if FileManager.default.fileExists(atPath: path) { collisions.append(path) }
                }
                let alert = NSAlert(); alert.messageText = localized("Разрешить замену результатов?", language: language)
                alert.informativeText = collisions.isEmpty ? localized("Совпавшие имена будут заменяться после успешной проверки новых файлов.", language: language) : collisions.joined(separator: "\n")
                alert.addButton(withTitle: localized("Заменить", language: language)); alert.addButton(withTitle: localized("Отмена", language: language))
                guard alert.runModal() == .alertFirstButtonReturn else { return }
            }
        } catch { message = error.localizedDescription; return }
        let batch = pending, folder = destination, conflict = policy, thisRun = UUID()
        let limit = test ? 1 : min(parallelism.limit, batch.count)
        var protected = Set<String>()
        for job in jobs {
            for file in [job.video, job.russianAudio, job.russianSRT, job.germanSRT] { if let file { protected.insert(file.resolvingSymlinksInPath().path) } }
        }
        busy = true; stopRequested = false; runID = thisRun; runStarted = Date(); fractions = [:]; weights = [:]; queueProgress = 0
        for job in batch { weights[job.id] = (try? PlannedOutput(job, test: test).duration) ?? 1; fractions[job.id] = 0 }
        queueText = localizedFormat("Запуск: %d заданий · одновременно %d", language: language, batch.count, limit); eta = localized("Оцениваю время…", language: language)
        Task {
            var completed = 0, failed = 0, next = 0
            await withTaskGroup(of: JobOutcome.self) { group in
                for _ in 0..<limit {
                    let job = batch[next]; next += 1
                    group.addTask { await self.process(job, tools: tools, destination: folder, test: test, policy: conflict, protected: protected, run: thisRun, workers: limit) }
                }
                for await outcome in group {
                    if outcome.success { completed += 1 }; if outcome.failed { failed += 1 }
                    if !stopRequested && next < batch.count {
                        let job = batch[next]; next += 1
                        group.addTask { await self.process(job, tools: tools, destination: folder, test: test, policy: conflict, protected: protected, run: thisRun, workers: limit) }
                    }
                }
            }
            busy = false; tokens = [:]; eta = ""
            queueText = stopRequested ? localizedFormat("Очередь остановлена · Готово: %d", language: language, completed) : localizedFormat("Готово: %d · Ошибок: %d · Время %@", language: language, completed, failed, clockText(Date().timeIntervalSince(runStarted)))
        }
    }
    private struct JobOutcome { var success = false; var failed = false }
    private func process(_ job: Lecture, tools: Toolchain, destination: URL?, test: Bool, policy: ConflictPolicy,
                         protected: Set<String>, run: UUID, workers: Int) async -> JobOutcome {
        guard !stopRequested else { return JobOutcome() }
        let token = Cancellation(); tokens[job.id] = token
        mutate(job.id) { $0.status = .running; $0.progress = 0; $0.detail = localized("Проверка файлов перед запуском…", language: language) }
        defer { tokens.removeValue(forKey: job.id); fractions[job.id] = 1; refreshProgress() }
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try Exporter.run(job, tools: tools, destination: destination, test: test, policy: policy, protectedInputs: protected, token: token,
                                 workerThreads: max(1, ProcessInfo.processInfo.activeProcessorCount / workers)) { fraction, speed, validating in
                    Task { @MainActor in
                        guard self.busy, self.runID == run, self.tokens[job.id] === token,
                              let active = self.jobs.first(where: { $0.id == job.id }), [.running, .validating].contains(active.status) else { return }
                        self.mutate(job.id) {
                            $0.progress = fraction; $0.speed = speed; $0.status = validating ? .validating : .running
                            $0.detail = validating ? "Проверяю результат и декодирование образцов…" : "\(Int(fraction * 100))%\(speed > 0 ? String(format: " · %.1f×", speed) : "")"
                        }
                        self.fractions[job.id] = fraction; self.refreshProgress()
                    }
                }
            }.value
            if let result {
                mutate(job.id) { $0.output = result; $0.progress = test ? 0 : 1; $0.status = test ? .ready : .completed; $0.detail = localized(test ? "Тест готов и проверен." : "Результат проверен: структура, длительность, начало, середина и конец.", language: language) }
                return JobOutcome(success: true)
            }
            mutate(job.id) { $0.status = .skipped; $0.detail = localized("Результат уже существует; выбран пропуск.", language: language) }
            return JobOutcome()
        } catch {
            mutate(job.id) { $0.status = token.isCancelled ? .stopped : .failed; $0.detail = error.localizedDescription }
            return JobOutcome(failed: !token.isCancelled)
        }
    }
    private func refreshProgress() {
        let total = max(1, weights.values.reduce(0, +))
        let done = weights.reduce(0.0) { $0 + $1.value * (fractions[$1.key] ?? 0) }
        queueProgress = min(1, done / total)
        let elapsed = Date().timeIntervalSince(runStarted)
        if elapsed > 2 && queueProgress > 0.01 { eta = localizedFormat("Осталось примерно %@ + проверка", language: language, clockText(elapsed * (1 - queueProgress) / queueProgress)) }
        if !stopRequested { queueText = localizedFormat("Активно: %d · Очередь: %d%%", language: language, tokens.count, Int(queueProgress * 100)) }
    }
    func stop() { stopRequested = true; for token in tokens.values { token.cancel() }; queueText = localized("Останавливаю все активные задания…", language: language) }
}
