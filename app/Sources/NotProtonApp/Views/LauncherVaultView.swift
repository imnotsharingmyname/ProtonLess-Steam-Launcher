import SwiftUI

/// Backup vault with large date-and-storage tiles and safe deletion confirmation.
struct LauncherVaultView: View {
    @Environment(PrefixesModel.self) private var model
    @State private var deleting: PrefixBackup?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 9) {
                        LauncherPill(title: "RECOVERY SPACE", symbol: "archivebox.fill")
                        Text("Your vault")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                        Text("Saved Windows environments, organised by game.")
                            .font(.system(size: 13))
                            .foregroundStyle(LauncherUI.secondary)
                    }
                    Spacer()
                    Text(model.backupBytes.formatted(.byteCount(style: .file)))
                        .font(.system(size: 19, weight: .bold, design: .monospaced))
                        .foregroundStyle(LauncherUI.blush)
                }
                LauncherPanel {
                    HStack(spacing: 16) {
                        Image(systemName: "externaldrive.badge.timemachine")
                            .font(.system(size: 26))
                            .foregroundStyle(LauncherUI.coral)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(model.backups.count) saved snapshots")
                                .font(.system(size: 16, weight: .bold))
                            Text("Choose a snapshot to locate it in Finder. Deletion requires confirmation.")
                                .font(.system(size: 12))
                                .foregroundStyle(LauncherUI.secondary)
                        }
                        Spacer()
                        Button("Rescan") { Task { await model.load() } }
                            .buttonStyle(.bordered)
                    }
                }
                if model.isLoading && !model.hasLoaded {
                    ProgressView("Loading snapshots…")
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else if model.backups.isEmpty {
                    LauncherPanel {
                        VStack(spacing: 13) {
                            Image(systemName: "archivebox")
                                .font(.system(size: 44))
                                .foregroundStyle(LauncherUI.coral)
                            Text("Your vault is empty").font(.system(size: 21, weight: .bold))
                            Text("Backups you create from your library will be listed here.")
                                .font(.system(size: 12))
                                .foregroundStyle(LauncherUI.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                    }
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 305), spacing: 16)], spacing: 16) {
                        ForEach(model.backups) { backup in
                            LauncherPanel(padding: 18) {
                                VStack(alignment: .leading, spacing: 14) {
                                    Image(systemName: "archivebox.fill")
                                        .font(.system(size: 27))
                                        .foregroundStyle(LauncherUI.coral)
                                    Text(backup.title)
                                        .font(.system(size: 17, weight: .bold))
                                    Text(backup.taken?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown date")
                                        .font(.system(size: 11))
                                        .foregroundStyle(LauncherUI.secondary)
                                    Text(backup.bytes.formatted(.byteCount(style: .file)))
                                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    HStack(spacing: 10) {
                                        Button("Show in Finder") { model.reveal(backup) }
                                            .buttonStyle(.borderedProminent)
                                            .tint(LauncherUI.coral)
                                        Button(role: .destructive) { deleting = backup } label: {
                                            Image(systemName: "trash")
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                            }
                        }
                    }
                }
                if let failure = model.failure {
                    Text(failure).font(.system(size: 12)).foregroundStyle(LauncherUI.blush)
                } else if let result = model.outcome {
                    Text(result).font(.system(size: 12)).foregroundStyle(.green)
                }
            }
            .padding(30)
            .frame(maxWidth: 1250)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .task { if !model.hasLoaded { await model.load() } }
        .confirmationDialog("Permanently delete this backup?", isPresented: Binding(
            get: { deleting != nil }, set: { if !$0 { deleting = nil } }
        ), titleVisibility: .visible) {
            Button("Delete snapshot", role: .destructive) {
                guard let backup = deleting else { return }
                deleting = nil
                Task { await model.deleteBackups([backup]) }
            }
            Button("Cancel", role: .cancel) { deleting = nil }
        } message: {
            Text("Deleting a backup discards its saved data. This cannot be undone.")
        }
    }
}
