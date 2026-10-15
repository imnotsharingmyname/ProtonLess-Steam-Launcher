import SwiftUI

/// A game-centric card gallery rather than the existing utility table.
struct LauncherLibraryView: View {
    @Environment(PrefixesModel.self) private var model
    @State private var query = ""
    @State private var deleting: WinePrefix?
    @State private var backingUp: WinePrefix?
    @State private var rebuilding: (prefix: WinePrefix, tool: InstalledTool)?

    private var shown: [WinePrefix] {
        model.prefixes.filter {
            query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)
                || $0.appID.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        LauncherPill(title: "YOUR COLLECTION", symbol: "square.stack.3d.up.fill")
                        Text("Game library")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                        Text("Everything installed through the Steam Play compatibility layer.")
                            .font(.system(size: 13))
                            .foregroundStyle(LauncherUI.secondary)
                    }
                    Spacer()
                    Text("\(model.prefixes.count) ENVIRONMENTS")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(LauncherUI.secondary)
                }
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(LauncherUI.secondary)
                    TextField("Search by game title or App ID", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain)
                    }
                }
                .padding(15)
                .background(LauncherUI.surface, in: RoundedRectangle(cornerRadius: 15))
                if model.isLoading && !model.hasLoaded {
                    ProgressView("Scanning game library…")
                        .frame(maxWidth: .infinity, minHeight: 230)
                } else if shown.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 285), spacing: 16)], spacing: 16) {
                        ForEach(shown) { item in gameCard(item) }
                    }
                }
                if let issue = model.failure { message(issue, warning: true) }
                else if let outcome = model.outcome { message(outcome, warning: false) }
            }
            .padding(30)
            .frame(maxWidth: 1250)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .task { if !model.hasLoaded { await model.load() } }
        .confirmationDialog("Delete this game environment?", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        ), titleVisibility: .visible) {
            Button("Delete prefix and its data", role: .destructive) {
                guard let selected = deleting else { return }
                deleting = nil
                Task { await model.delete([selected]) }
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: {
            Text("This deletes the Windows prefix, including any game saves stored inside it. This cannot be undone.")
        }
        .confirmationDialog("Backup game environment?", isPresented: Binding(
            get: { backingUp != nil }, set: { if !$0 { backingUp = nil } }
        ), titleVisibility: .visible) {
            Button("Create backup") {
                guard let selected = backingUp else { return }
                backingUp = nil
                Task { await model.backUp([selected]) }
            }
            Button("Cancel", role: .cancel) { backingUp = nil }
        } message: { Text("Save this Windows environment for recovery.") }
        .confirmationDialog("Rebuild compatibility files?", isPresented: Binding(
            get: { rebuilding != nil }, set: { if !$0 { rebuilding = nil } }
        ), titleVisibility: .visible) {
            Button("Rebuild and keep backup") {
                guard let choice = rebuilding else { return }
                rebuilding = nil
                Task { await model.recreate([choice.prefix], as: choice.tool, keepBackup: true) }
            }
            Button("Cancel", role: .cancel) { rebuilding = nil }
        } message: { Text("Rebuild the compatibility files and preserve a backup of the old prefix first.") }
    }

    private var emptyState: some View {
        LauncherPanel {
            VStack(spacing: 13) {
                Image(systemName: "gamecontroller")
                    .font(.system(size: 45, weight: .ultraLight))
                    .foregroundStyle(LauncherUI.coral)
                Text("No games to show")
                    .font(.system(size: 21, weight: .bold))
                Text("After a Windows game is launched through Steam Play, its environment appears here.")
                    .foregroundStyle(LauncherUI.secondary)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 12))
                Button("Scan again") { Task { await model.load() } }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 47)
        }
    }

    private func gameCard(_ prefix: WinePrefix) -> some View {
        let disabled = model.busy.contains(prefix.id)
        return LauncherPanel(padding: 17) {
            VStack(alignment: .leading, spacing: 17) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(LauncherUI.coral.opacity(0.15))
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 25))
                            .foregroundStyle(LauncherUI.coral)
                    }
                    .frame(width: 62, height: 62)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(prefix.title)
                            .font(.system(size: 16, weight: .bold))
                            .lineLimit(2)
                        Text("APP ID  /  \(prefix.appID)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(LauncherUI.secondary)
                    }
                    Spacer(minLength: 0)
                }
                HStack {
                    if model.isStale(prefix) {
                        LauncherPill(title: "Needs repair", symbol: "exclamationmark.triangle.fill", tint: LauncherUI.blush)
                    } else {
                        LauncherPill(title: "Available", symbol: "checkmark.circle.fill", tint: Color.green)
                    }
                    Spacer(minLength: 3)
                    if let size = model.usage[prefix.id]?.bytes {
                        Text(size.formatted(.byteCount(style: .file)))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(LauncherUI.secondary)
                    }
                }
                HStack(spacing: 8) {
                    Button {
                        model.selection = [prefix.id]
                        model.chooseExecutable(for: prefix)
                    } label: {
                        Label("Run .exe", systemImage: "play.fill")
                            .font(.system(size: 12, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(LauncherUI.coral, in: RoundedRectangle(cornerRadius: 11))
                    }
                    .buttonStyle(.plain)
                    .disabled(disabled)
                    Menu {
                        Button("Reveal prefix in Finder", systemImage: "folder") { model.reveal(prefix) }
                        Button("Create backup", systemImage: "externaldrive.badge.plus") { backingUp = prefix }
                        ForEach(WineTool.allCases, id: \.self) { tool in
                            Button(tool.label) { model.open(tool, for: prefix) }
                        }
                        if !model.tools.isEmpty {
                            Menu("Rebuild using") {
                                ForEach(model.tools) { tool in
                                    Button(tool.display) { rebuilding = (prefix, tool) }
                                }
                            }
                        }
                        Divider()
                        Button("Delete prefix", systemImage: "trash", role: .destructive) { deleting = prefix }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .bold))
                            .frame(width: 43, height: 39)
                            .background(LauncherUI.elevated, in: RoundedRectangle(cornerRadius: 11))
                    }
                    .menuStyle(.borderlessButton)
                    .disabled(disabled)
                }
            }
        }
    }

    private func message(_ text: String, warning: Bool) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(warning ? LauncherUI.blush : .green)
            .padding(14)
            .background(LauncherUI.surface, in: RoundedRectangle(cornerRadius: 13))
    }
}
