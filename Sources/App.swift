import AppKit
import SwiftUI
import UniformTypeIdentifiers

private let applicationVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"

private let accent = Color(nsColor: NSColor(name: "LectureAccent") { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor(srgbRed: 0.30, green: 0.78, blue: 0.76, alpha: 1)
        : NSColor(srgbRed: 0.08, green: 0.48, blue: 0.48, alpha: 1)
})

struct MainView: View {
    @ObservedObject var model: QueueModel
    @State private var dropping = false
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage()).resizable().scaledToFit().frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Сборка лекций").font(.system(size: 25, weight: .semibold))
                    Text("Видео MP4 · Звук AAC / MP3 · Пакетная обработка").foregroundStyle(.secondary)
                    Text((model.projectURL?.lastPathComponent ?? "Новый проект") + (model.hasUnsavedChanges ? " · есть изменения" : "")).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Text("\(applicationVersion) · Apple Silicon").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("Открыть проект…") { model.openProject() }
                        Button("Сохранить") { model.saveProject() }
                        Menu { Button("Сохранить как…") { model.saveProject(asNew: true) } } label: { Image(systemName: "ellipsis") }.frame(width: 35)
                    }.disabled(model.locked)
                }
            }.padding(22)
            HStack(spacing: 10) {
                Button { model.chooseVideos(folder: false) } label: { Label("Добавить файлы", systemImage: "plus") }
                Button { model.chooseVideos(folder: true) } label: { Label("Добавить папку", systemImage: "folder.badge.plus") }
                Toggle("Включая подпапки", isOn: $model.recursive).font(.callout)
                Spacer()
                if model.importing { ProgressView().controlSize(.small) }
                Text("Лекций: \(model.jobs.count)").foregroundStyle(.secondary)
                Button("Очистить очередь") { model.clearQueue() }.disabled(model.jobs.isEmpty).help("Убрать все задания; файлы на диске сохраняются")
                Button(role: .destructive) { model.removeSelection() } label: { Image(systemName: "trash") }.disabled(model.selected == nil)
            }.disabled(model.locked).padding(.horizontal, 22).padding(.bottom, 15)
            Divider()
            HSplitView {
                queue.frame(minWidth: 350, idealWidth: 410, maxWidth: 490)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if let job = model.current { detail(job) }
                        else { emptyDetail }
                        Divider()
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Общие настройки").font(.headline)
                            SettingsView(settings: $model.common)
                            Button("Применить ко всей очереди") { model.applyCommon() }.disabled(model.jobs.isEmpty)
                        }.disabled(model.locked)
                    }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
                }.frame(minWidth: 530)
            }
            Divider()
            footer
        }
        .frame(minWidth: 1040, minHeight: 760)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(accent)
        .overlay { if dropping { RoundedRectangle(cornerRadius: 10).stroke(accent, lineWidth: 4).padding(6).allowsHitTesting(false) } }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $dropping) { providers in
            guard !model.locked else { return false }
            let group = DispatchGroup(), lock = NSLock()
            var urls: [URL] = []
            for provider in providers {
                group.enter()
                _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    defer { group.leave() }
                    if let data, let url = URL(dataRepresentation: data, relativeTo: nil) { lock.lock(); urls.append(url); lock.unlock() }
                }
            }
            group.notify(queue: .main) { model.add(urls) }
            return true
        }
        .alert("Сборка лекций", isPresented: Binding(get: { model.message != nil }, set: { if !$0 { model.message = nil } })) {
            Button("Понятно") { model.message = nil }
        } message: { Text(model.message ?? "") }
    }
    var queue: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text("ОЧЕРЕДЬ").font(.caption.weight(.semibold)).foregroundStyle(.secondary); Spacer(); Text("Delete / Backspace — убрать").font(.caption2).foregroundStyle(.secondary) }.padding(16)
            if model.jobs.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "tray.and.arrow.down").font(.system(size: 44, weight: .light)).foregroundStyle(accent)
                    Text("Перетащите сюда видео\nили папку с лекциями").multilineTextAlignment(.center).font(.title3)
                    Text("WAV / M4A / AAC и SRT будут\nподобраны по полному имени видео.").multilineTextAlignment(.center).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $model.selected) {
                    ForEach(model.jobs) { job in
                        HStack(alignment: .top, spacing: 10) {
                            Toggle("Включить в очередь", isOn: Binding(get: { model.jobs.first { $0.id == job.id }?.enabled ?? true }, set: { value in model.mutate(job.id) { $0.enabled = value } })).labelsHidden().disabled(model.locked)
                            VStack(alignment: .leading, spacing: 7) {
                                Text(job.basename).font(.system(.body, design: .monospaced).weight(.medium)).lineLimit(2).help(job.video.path)
                                Button { NSWorkspace.shared.open(job.video) } label: { Label("Открыть исходник", systemImage: "play.circle") }.buttonStyle(.borderless).font(.caption)
                                HStack(spacing: 7) {
                                    if job.settings.mode == .video {
                                        statusDot(job.russianAudio != nil); statusDot(job.russianSRT != nil); statusDot(job.germanSRT != nil)
                                    } else { Image(systemName: "waveform").foregroundStyle(accent); Text(job.settings.audioProfile.title).font(.caption) }
                                    Spacer()
                                    if job.settings.mode == .video { Text((try? ExportPlan(job, test: false)).map { "\($0.height)p" } ?? "—").font(.caption) }
                                }
                                HStack {
                                    Text(job.status.rawValue).font(.caption).foregroundStyle(statusColor(job.status))
                                    Spacer()
                                    if [.running, .validating].contains(job.status) { Text("\(Int(job.progress * 100))%").font(.caption.monospacedDigit()) }
                                }
                                if [.running, .validating].contains(job.status) { ProgressView(value: job.progress).controlSize(.small) }
                            }
                        }.padding(.vertical, 7).tag(job.id).contextMenu {
                            Button("Открыть исходник") { NSWorkspace.shared.open(job.video) }
                            Button("Показать в Finder") { model.show(job.video) }
                            Button("Заменить исходник…") { model.pickComponent(job.id, kind: "primary") }.disabled(model.locked)
                            Divider()
                            Button("Удалить из очереди", role: .destructive) { model.remove(job.id) }.disabled(model.locked)
                        }
                    }
                }.listStyle(.sidebar).onDeleteCommand { model.removeSelection() }
            }
        }
    }
    func statusDot(_ present: Bool) -> some View { Image(systemName: present ? "checkmark.circle.fill" : "minus.circle").foregroundStyle(present ? accent : Color.orange).font(.caption) }
    func statusColor(_ status: JobStatus) -> Color {
        switch status { case .ready, .completed: return accent; case .failed: return .red; case .missing, .ambiguous, .review: return .orange; default: return .secondary }
    }
    var emptyDetail: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Видео или только звук").font(.title2.weight(.semibold))
            Label("Русский звук первым и по умолчанию", systemImage: "speaker.wave.2")
            Label("Немецкий звук отдельной дорожкой", systemImage: "waveform")
            Label("Русские и немецкие субтитры внутри файла", systemImage: "captions.bubble")
            Label("AAC без перекодирования или MP3 до 320 кбит/с", systemImage: "music.note")
            Text("Сначала соберите 30-секундный тест и проверьте его на своём устройстве. Управление субтитрами зависит от плеера.").foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(.vertical, 12)
    }
    func detail(_ job: Lecture) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Выбранная лекция").font(.title2.weight(.semibold))
                Spacer()
                Button { model.reanalyze(job.id) } label: { Image(systemName: "arrow.clockwise") }.help("Повторно проверить комплект").disabled(model.locked)
            }
            Text(job.basename).font(.callout.monospaced()).textSelection(.enabled)
            if let info = job.info, let video = info.video {
                HStack(spacing: 20) {
                    fact("ИСТОЧНИК", "\(Int(video.displaySize.0.rounded()))×\(Int(video.displaySize.1.rounded()))")
                    fact("ДЛИТЕЛЬНОСТЬ", clockText(info.duration))
                    fact("ВИДЕО", "\(video.codec_name?.uppercased() ?? "?") · \(String(format: "%.2f", video.fps)) fps")
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 9))
            } else if let info = job.info, let audio = info.audio.first {
                HStack(spacing: 20) { fact("АУДИО", audio.codec_name?.uppercased() ?? "?"); fact("ДЛИТЕЛЬНОСТЬ", clockText(info.duration)); fact("ПАРАМЕТРЫ", "\(audio.sample_rate ?? "?") Гц · \(audio.channels ?? 0) кан.") }
            }
            VStack(alignment: .leading, spacing: 10) {
                if !job.primaryIsAudio && (job.settings.mode == .video || job.settings.audioSource == .russian) {
                    fileRow("RU звук", job.russianAudio, job.id, "audio")
                }
                if job.audioCandidates.count > 1 && !job.primaryIsAudio && (job.settings.mode == .video || job.settings.audioSource == .russian) {
                    Picker("Найденные варианты", selection: Binding(get: { job.russianAudio?.path ?? "" }, set: { path in
                        model.mutate(job.id) { $0.russianAudio = path.isEmpty ? nil : URL(fileURLWithPath: path) }; model.reanalyze(job.id)
                    })) {
                        Text("Выберите озвучку…").tag("")
                        ForEach(job.audioCandidates, id: \.path) { url in Text(url.lastPathComponent).tag(url.path) }
                    }
                }
                if job.settings.mode == .video {
                    fileRow("RU SRT", job.russianSRT, job.id, "ru")
                    fileRow("DE SRT", job.germanSRT, job.id, "de")
                }
                if let audio = job.info?.audio, job.settings.mode == .video || job.settings.audioSource == .original || job.primaryIsAudio {
                    Picker(job.settings.mode == .video ? "DE звук" : "Дорожка", selection: Binding(get: { job.germanIndex ?? -1 }, set: { index in model.mutate(job.id) { $0.germanIndex = index < 0 ? nil : index }; model.reanalyze(job.id) })) {
                        Text("Выберите аудиодорожку…").tag(-1)
                        ForEach(audio, id: \.index) { stream in Text(stream.audioLabel).tag(stream.index) }
                    }
                }
            }.disabled(model.locked)
            Divider()
            SettingsView(settings: model.settingsBinding(job.id), primaryIsAudio: job.primaryIsAudio).disabled(model.locked)
            if let plan = try? PlannedOutput(job, test: false) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(plan.summary).font(.callout.weight(.medium)).foregroundStyle(accent)
                    Text("Примерный размер: \(byteText(plan.estimatedBytes)) · Фактический размер зависит от видео.").font(.caption).foregroundStyle(.secondary)
                    if job.settings.mode == .video, (try? ExportPlan(job, test: false).copyVideo) == true { Text("Видеоряд сохранится без потерь; степень сжатия сейчас не применяется.").font(.caption).foregroundStyle(.secondary) }
                }
            } else if job.info != nil { Text("Проверьте выбранные файлы, дорожку и формат экспорта.").foregroundStyle(.orange).font(.caption) }
            Text(job.detail).font(.callout).foregroundStyle(statusColor(job.status)).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            HStack {
                if let output = job.output {
                    Button { model.show(output) } label: { Label("Результат в Finder", systemImage: "folder") }
                    Button("Воспроизвести") { NSWorkspace.shared.open(output) }
                }
            }
        }
    }
    func fact(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) { Text(title).font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary); Text(value).font(.callout.monospacedDigit()) }
    }
    func fileRow(_ label: String, _ file: URL?, _ id: UUID, _ kind: String) -> some View {
        HStack(spacing: 10) {
            Text(label).font(.caption.weight(.semibold)).frame(width: 55, alignment: .leading)
            Text(file?.lastPathComponent ?? "Не выбран").font(.callout).foregroundStyle(file == nil ? Color.orange : Color.primary).lineLimit(1).truncationMode(.middle).help(file?.path ?? "")
            Spacer(minLength: 0)
            Button("Выбрать…") { model.pickComponent(id, kind: kind) }
        }
    }
    var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "folder").foregroundStyle(accent)
                Text(model.destination?.path ?? "«Готовое» рядом с каждым исходным видео").lineLimit(1).truncationMode(.middle).help(model.destination?.path ?? "")
                Button("Изменить…") { model.chooseDestination() }
                if model.destination != nil { Button("По умолчанию") { model.destination = nil } }
                Spacer()
                Picker("Если файл есть", selection: $model.policy) { ForEach(ConflictPolicy.allCases) { Text($0.rawValue).tag($0) } }.frame(width: 270)
            }.disabled(model.locked)
            HStack {
                Picker("Параллельная обработка", selection: $model.parallelism) { ForEach(Parallelism.allCases) { Text($0.title).tag($0) } }.frame(width: 350).disabled(model.locked)
                Text("Потоки CPU распределяются автоматически. Видео кодирует медиаблок M4.").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.queueText).font(.callout).lineLimit(1)
                    if model.busy { ProgressView(value: model.queueProgress); Text(model.eta).font(.caption).foregroundStyle(.secondary) }
                    else { Text("Исходники сохраняются. Удаление и очистка меняют только очередь.").font(.caption).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 20)
                Button("Тест 30 секунд") { model.start(test: true) }.disabled(model.locked || model.current == nil || model.tools == nil)
                Button("Начать очередь") { model.start(test: false) }.buttonStyle(.borderedProminent).disabled(model.locked || model.jobs.isEmpty || model.tools == nil)
                Button("Остановить") { model.stop() }.disabled(!model.busy)
            }
        }.padding(18)
    }
}

struct SettingsView: View {
    @Binding var settings: ExportSettings
    var primaryIsAudio = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Сохранить", selection: $settings.mode) { ForEach(ExportMode.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented).disabled(primaryIsAudio)
            if settings.mode == .video {
            HStack {
                Picker("Разрешение", selection: $settings.resolution) { ForEach(Resolution.allCases) { Text($0.title).tag($0) } }
                Picker("Сжатие", selection: $settings.quality) { ForEach(Quality.allCases) { Text($0.rawValue).tag($0) } }.disabled(settings.resolution == .copy)
            }
            Toggle("Сжать заново даже при том же разрешении", isOn: $settings.recompress).disabled(settings.resolution == .copy)
            Toggle("Разрешить увеличение разрешения (деталей не добавляет)", isOn: $settings.upscale).disabled(settings.resolution == .copy || settings.resolution == .original)
            Toggle("Копировать готовый RU AAC-LC без перекодирования", isOn: $settings.copyRussianAAC)
                Text(settings.resolution == .copy ? "Видео копируется без потерь; сжатие не применяется." : settings.resolution == .original ? "Размер кадра сохраняется. Для повторного сжатия включите переключатель выше." : "Выше исходного разрешения — только с разрешённым увеличением.").font(.caption).foregroundStyle(.secondary)
            } else {
                if !primaryIsAudio { Picker("Источник звука", selection: $settings.audioSource) { ForEach(AudioSource.allCases) { Text($0.rawValue).tag($0) } } }
                Picker("Формат и качество", selection: $settings.audioProfile) { ForEach(AudioProfile.allCases) { Text($0.title).tag($0) } }
                if !settings.audioProfile.isMP3 {
                    Picker("Расширение файла", selection: $settings.aacContainer) { ForEach(AACContainer.allCases) { Text($0.rawValue).tag($0) } }
                    Text(settings.audioProfile.isCopy ? "Без потерь — только если выбранный исходный звук уже AAC." : "M4A содержит AAC и удобен для перемотки; .aac — чистый поток ADTS.").font(.caption).foregroundStyle(.secondary)
                } else { Text("MP3 320 кбит/с — максимальный предлагаемый битрейт. Качество ограничено исходной записью.").font(.caption).foregroundStyle(.secondary) }
            }
            if settings.mode == .video || (!settings.audioProfile.isMP3 && !settings.audioProfile.isCopy) {
                Picker("Кодировщик AAC", selection: $settings.aacEngine) { ForEach(AACEngine.allCases) { Text($0.rawValue).tag($0) } }
            }
        }.font(.callout)
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    let model = QueueModel()
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let menu = NSMenu(), appItem = NSMenuItem(), appMenu = NSMenu()
        appMenu.addItem(withTitle: "О программе «Сборка лекций»", action: #selector(about), keyEquivalent: "")
        appMenu.addItem(withTitle: "Показать журналы", action: #selector(logs), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Завершить «Сборка лекций»", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu; menu.addItem(appItem)
        let fileItem = NSMenuItem(), fileMenu = NSMenu(title: "Проект")
        fileMenu.addItem(withTitle: "Открыть проект…", action: #selector(openProject), keyEquivalent: "o")
        fileMenu.addItem(withTitle: "Сохранить проект", action: #selector(saveProject), keyEquivalent: "s")
        let saveAs = fileMenu.addItem(withTitle: "Сохранить проект как…", action: #selector(saveProjectAs), keyEquivalent: "s")
        saveAs.keyEquivalentModifierMask = [.command, .shift]
        for item in fileMenu.items { item.target = self }
        fileItem.submenu = fileMenu; menu.addItem(fileItem)
        let edit = NSMenuItem(), editMenu = NSMenu(title: "Правка")
        editMenu.addItem(withTitle: "Копировать", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Вставить", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Выбрать всё", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        edit.submenu = editMenu; menu.addItem(edit); NSApp.mainMenu = menu
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 830), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Сборка лекций 2"; window.delegate = self
        window.contentView = NSHostingView(rootView: MainView(model: model))
        window.center(); window.setFrameAutosaveName("OlyaAssembler2Main")
        window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        let args = CommandLine.arguments.dropFirst()
        if !args.isEmpty { model.add(args.map { URL(fileURLWithPath: $0) }) }
    }
    func application(_ application: NSApplication, open urls: [URL]) {
        if let project = urls.first(where: { $0.pathExtension == "olyalecture" }) { model.openProject(project) }
        else { model.add(urls) }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard model.busy else { return model.confirmDiscard() ? .terminateNow : .terminateCancel }
        let alert = NSAlert(); alert.messageText = "Остановить сборку и выйти?"
        alert.informativeText = "Текущий временный MP4 будет удалён. Готовые результаты сохранятся."
        alert.addButton(withTitle: "Остановить и выйти"); alert.addButton(withTitle: "Продолжить сборку")
        guard alert.runModal() == .alertFirstButtonReturn else { return .terminateCancel }
        model.stop()
        Task {
            while model.busy { try? await Task.sleep(nanoseconds: 200_000_000) }
            sender.reply(toApplicationShouldTerminate: model.confirmDiscard())
        }
        return .terminateLater
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApp.terminate(nil); return false
    }
    @objc func about() {
        let alert = NSAlert(); alert.messageText = "Сборка лекций · \(applicationVersion)"
        alert.informativeText = "Отдельное приложение для готовых лекций. Перевод и синтез речи не выполняются.\n\nFFmpeg / FFprobe 9.0.1 и LAME 4.0 для MP3, LGPL. Исходный код, лицензии и скрипт пересборки находятся в папке проекта vendor и в ресурсах приложения.\nhttps://ffmpeg.org · https://lame.sourceforge.io"
        alert.runModal()
    }
    @objc func logs() {
        if let logs = model.tools?.logs { try? FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true); NSWorkspace.shared.open(logs) }
    }
    @objc func openProject() { model.openProject() }
    @objc func saveProject() { model.saveProject() }
    @objc func saveProjectAs() { model.saveProject(asNew: true) }
}

@main struct Launcher {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate(); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
