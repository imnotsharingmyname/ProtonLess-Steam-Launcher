import SwiftUI
import AppKit
import Metal
import Foundation

private enum Theme {
    static let bg = Color(red: 0.06, green: 0.07, blue: 0.105)
    static let panel = Color(red: 0.105, green: 0.12, blue: 0.175)
    static let accent = Color(red: 0.48, green: 0.37, blue: 0.98)
    static let muted = Color(red: 0.65, green: 0.69, blue: 0.78)
}

enum Engine: String, Codable, CaseIterable, Identifiable {
    case wine = "Wine", crossover = "CrossOver"
    var id: String { rawValue }
}

struct Game: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var path: String
    var engine: Engine = .wine
    var bottle = ""
    var prefix = ""
    var arguments = ""
    var lastPlayed: Date?
}

struct LibraryData: Codable {
    var games: [Game] = []
    var winePath = ""
    var crossoverPath = ""
}

@MainActor
final class Library: ObservableObject {
    @Published var data = LibraryData()
    @Published var message = "Ready"
    @Published var logURL: URL?
    private var processes: [UUID: Process] = [:]
    private var root: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NovaHub", isDirectory: true)
    }
    init() {
        let file = root.appendingPathComponent("library.json")
        if let bytes = try? Data(contentsOf: file),
           let saved = try? JSONDecoder().decode(LibraryData.self, from: bytes) {
            data = saved
        }
    }
    func save() {
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let bytes = try JSONEncoder().encode(data)
            try bytes.write(to: root.appendingPathComponent("library.json"), options: .atomic)
        } catch {
            message = "Library save failed: \(error.localizedDescription)"
        }
    }
    func addGame() -> Game? {
        let picker = NSOpenPanel()
        picker.title = "Choose a Windows game executable"
        picker.canChooseDirectories = false
        picker.allowsMultipleSelection = false
        picker.allowedFileTypes = ["exe"]
        guard picker.runModal() == .OK, let url = picker.url else { return nil }
        let g = Game(title: url.deletingPathExtension().lastPathComponent, path: url.path)
        data.games.append(g)
        save()
        message = "Imported \(g.title). Choose its runtime in game settings."
        return g
    }
    func update(_ game: Game) {
        if let index = data.games.firstIndex(where: { $0.id == game.id }) {
            data.games[index] = game
            save()
        }
    }
    func delete(_ game: Game) {
        data.games.removeAll { $0.id == game.id }
        save()
    }
    func available(_ engine: Engine) -> String? {
        let candidates: [String]
        switch engine {
        case .wine:
            candidates = [data.winePath, "/usr/local/bin/wine", "/opt/homebrew/bin/wine", "/opt/local/bin/wine"]
        case .crossover:
            candidates = [data.crossoverPath,
                "/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine",
                "~/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine"]
        }
        return candidates
            .map { ($0 as NSString).expandingTildeInPath }
            .first { !$0.isEmpty && FileManager.default.isExecutableFile(atPath: $0) }
    }
    func launch(_ game: Game) {
        guard processes[game.id] == nil else { message = "Already launching \(game.title)"; return }
        guard FileManager.default.fileExists(atPath: game.path) else {
            message = "Game not found: \(game.path)"; return
        }
        guard let enginePath = available(game.engine) else {
            message = "\(game.engine.rawValue) not found. Set the executable path in Settings."; return
        }
        do {
            let logDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Logs/NovaHub", isDirectory: true)
            try FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
            let logFile = logDir.appendingPathComponent("\(game.id.uuidString)-\(Int(Date().timeIntervalSince1970)).log")
            guard FileManager.default.createFile(atPath: logFile.path, contents: nil) else {
                throw NSError(domain: "NovaHub", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create log"])
            }
            let handle = try FileHandle(forWritingTo: logFile)
            let p = Process()
            p.executableURL = URL(fileURLWithPath: enginePath)
            p.currentDirectoryURL = URL(fileURLWithPath: game.path).deletingLastPathComponent()
            let extras = try parseArguments(game.arguments)
            if game.engine == .crossover {
                guard !game.bottle.trimmingCharacters(in: .whitespaces).isEmpty else {
                    try? handle.close()
                    message = "Set the existing CrossOver bottle name in Game Settings."
                    return
                }
                p.arguments = ["--bottle", game.bottle, "--cx-app", (game.path as NSString).lastPathComponent] + extras
            } else {
                p.arguments = [game.path] + extras
                let prefix = game.prefix.isEmpty
                    ? root.appendingPathComponent("Prefixes/\(game.id.uuidString)", isDirectory: true).path
                    : (game.prefix as NSString).expandingTildeInPath
                try FileManager.default.createDirectory(atPath: prefix, withIntermediateDirectories: true)
                p.environment = ProcessInfo.processInfo.environment.merging(["WINEPREFIX": prefix]) { _, new in new }
            }
            p.standardOutput = handle
            p.standardError = handle
            try p.run()
            processes[game.id] = p
            logURL = logFile
            message = "Started \(game.title) with \(game.engine.rawValue). Open Log for details."
            if let index = data.games.firstIndex(where: { $0.id == game.id }) {
                data.games[index].lastPlayed = Date()
                save()
            }
            p.terminationHandler = { [weak self] completed in
                try? handle.close()
                Task { @MainActor [weak self] in
                    self?.processes.removeValue(forKey: game.id)
                    self?.message = "\(game.title) launcher exited with code \(completed.terminationStatus)"
                }
            }
        } catch {
            message = "Launch error: \(error.localizedDescription)"
        }
    }
}

private func parseArguments(_ input: String) throws -> [String] {
    var results: [String] = [], value = ""
    var quote: Character? = nil
    var escaping = false, started = false
    for c in input {
        if escaping { value.append(c); escaping = false; started = true }
        else if c == "\\" { escaping = true; started = true }
        else if let q = quote { if c == q { quote = nil } else { value.append(c) } }
        else if c == "\"" || c == "'" { quote = c; started = true }
        else if c.isWhitespace { if started { results.append(value); value = ""; started = false } }
        else { value.append(c); started = true }
    }
    if escaping || quote != nil {
        throw NSError(domain: "NovaHub", code: 2, userInfo: [NSLocalizedDescriptionKey: "Malformed launch arguments"])
    }
    if started { results.append(value) }
    return results
}

@main
struct NovaHubApp: App {
    @StateObject private var library = Library()
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(library)
                .frame(minWidth: 920, minHeight: 610)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1120, height: 760)
    }
}

struct MainView: View {
    @EnvironmentObject private var library: Library
    @State private var search = ""
    @State private var editor: Game?
    @State private var settings = false

    private var filtered: [Game] {
        library.data.games.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 230)
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your Library").font(.system(size: 31, weight: .bold))
                        Text("Windows games, one beautiful home.").foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Button { editor = library.addGame() } label: {
                        Label("Add Game", systemImage: "plus").font(.headline)
                    }.buttonStyle(.borderedProminent).tint(Theme.accent)
                }
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
                    TextField("Search games", text: $search).textFieldStyle(.plain)
                }
                .padding(14).background(Theme.panel, in: RoundedRectangle(cornerRadius: 12))

                if filtered.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 60)).foregroundStyle(Theme.accent)
                        Text(library.data.games.isEmpty ? "Add your first game" : "No matching games")
                            .font(.title2.bold())
                        Text("Import a Windows .exe and configure Wine or CrossOver.")
                            .foregroundStyle(Theme.muted)
                        Button("Import Windows Game") { editor = library.addGame() }
                            .buttonStyle(.borderedProminent)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 265), spacing: 17)], spacing: 17) {
                            ForEach(filtered) { game in
                                gameTile(game)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                HStack {
                    Image(systemName: "waveform.path.ecg").foregroundStyle(Theme.accent)
                    Text(library.message).font(.caption).lineLimit(2).foregroundStyle(Theme.muted)
                    Spacer()
                    if let logURL = library.logURL {
                        Button("Open Log") { NSWorkspace.shared.open(logURL) }
                    }
                }.padding(12).background(Theme.panel, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(25)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.bg)
        }
        .sheet(item: $editor) { g in
            Editor(game: g) { library.update($0) }
        }
        .sheet(isPresented: $settings) {
            SettingsView()
                .environmentObject(library)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 23) {
            HStack(spacing: 10) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 24))
                    .frame(width: 48, height: 48)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text("NovaHub").font(.title3.bold())
                    Text("MAC GAMING").font(.system(size: 10, weight: .semibold)).tracking(1.5)
                        .foregroundStyle(Theme.muted)
                }
            }.padding(.top, 17)
            Label("My Library", systemImage: "square.grid.2x2.fill")
                .padding(13).frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.accent.opacity(0.23), in: RoundedRectangle(cornerRadius: 11))
            Button { editor = library.addGame() } label: {
                Label("Add Windows Game", systemImage: "plus.app")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain).padding(.horizontal, 13)
            Spacer()
            VStack(alignment: .leading, spacing: 11) {
                Text("RUNTIMES").font(.caption.bold()).foregroundStyle(Theme.muted)
                runtimeRow(.wine)
                runtimeRow(.crossover)
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 12))
            Button { settings = true } label: {
                Label("Settings & Runtimes", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain).foregroundStyle(Theme.muted)
                .padding(.bottom, 18)
        }
        .padding(.horizontal, 18)
        .background(Theme.bg)
    }

    private func runtimeRow(_ engine: Engine) -> some View {
        HStack {
            Circle().fill(library.available(engine) == nil ? .orange : .green)
                .frame(width: 7, height: 7)
            Text(engine.rawValue)
            Spacer()
            Text(library.available(engine) == nil ? "Missing" : "Found")
                .font(.caption).foregroundStyle(Theme.muted)
        }.font(.caption)
    }

    private func gameTile(_ game: Game) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                LinearGradient(colors: [Theme.accent.opacity(0.85), .blue.opacity(0.4), Theme.panel],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 61, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(height: 145)
            VStack(alignment: .leading, spacing: 12) {
                Text(game.title).font(.headline).lineLimit(1)
                HStack {
                    Text(game.engine.rawValue).font(.caption).foregroundStyle(Theme.muted)
                    Spacer()
                    Button { editor = game } label: { Image(systemName: "slider.horizontal.3") }
                        .buttonStyle(.plain).help("Edit game")
                }
                Button { library.launch(game) } label: {
                    Label("Play", systemImage: "play.fill")
                        .frame(maxWidth: .infinity).padding(.vertical, 7)
                }.buttonStyle(.borderedProminent).tint(Theme.accent)
            }.padding(14)
        }
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 15))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .contextMenu {
            Button("Edit Game") { editor = game }
            Button("Remove from Library", role: .destructive) { library.delete(game) }
        }
    }
}

private struct Editor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Game
    let save: (Game) -> Void
    init(game: Game, save: @escaping (Game) -> Void) {
        _draft = State(initialValue: game)
        self.save = save
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Game Settings").font(.title2.bold())
            Form {
                TextField("Game name", text: $draft.title)
                TextField("Windows executable", text: $draft.path)
                Picker("Compatibility engine", selection: $draft.engine) {
                    ForEach(Engine.allCases) { e in Text(e.rawValue).tag(e) }
                }
                if draft.engine == .crossover {
                    TextField("Existing bottle name", text: $draft.bottle)
                } else {
                    TextField("Wine prefix path (optional)", text: $draft.prefix)
                }
                TextField("Arguments (optional)", text: $draft.arguments)
            }.formStyle(.grouped)
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") { save(draft); dismiss() }.buttonStyle(.borderedProminent)
            }
        }.padding(22).frame(width: 560, height: 385)
    }
}

private struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var library: Library
    private var gpuName: String {
        MTLCreateSystemDefaultDevice()?.name ?? "No Metal device detected"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Runtimes & Diagnostics").font(.title2.bold())
            Text("NovaHub uses your existing Wine or CrossOver installation.")
                .foregroundStyle(Theme.muted)
            GroupBox("Graphics") {
                VStack(alignment: .leading) {
                    Text("Metal GPU: \(gpuName)")
                    #if arch(x86_64)
                    Text("Architecture: x86-64 (Intel / AMD)")
                    #elseif arch(arm64)
                    Text("Architecture: ARM64 (Apple Silicon)")
                    #endif
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            Form {
                HStack {
                    TextField("Wine executable", text: $library.data.winePath)
                    Button("Browse") { pickPath { library.data.winePath = $0 } }
                }
                HStack {
                    TextField("CrossOver wine executable", text: $library.data.crossoverPath)
                    Button("Browse") { pickPath { library.data.crossoverPath = $0 } }
                }
            }.formStyle(.grouped)
            HStack {
                Spacer()
                Button("Save & Close") { library.save(); dismiss() }
                    .buttonStyle(.borderedProminent)
            }
        }.padding(22).frame(width: 650, height: 445)
    }
    private func pickPath(_ complete: (String) -> Void) {
        let picker = NSOpenPanel()
        picker.canChooseDirectories = false
        picker.canChooseFiles = true
        picker.allowsOtherFileTypes = true
        if picker.runModal() == .OK, let url = picker.url { complete(url.path) }
    }
}
