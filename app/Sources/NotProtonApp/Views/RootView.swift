import SwiftUI

// New right-rail shell: no NavigationSplitView, sidebar or inherited forms.
enum Pane: String, CaseIterable, Identifiable, Hashable {
    case status, prefixes, backups
    var id: String { rawValue }

    var label: String {
        switch self {
        case .status: "Discover"
        case .prefixes: "Game library"
        case .backups: "Vault"
        }
    }

    var symbol: String {
        switch self {
        case .status: "sparkles.rectangle.stack.fill"
        case .prefixes: "square.stack.3d.up.fill"
        case .backups: "archivebox.fill"
        }
    }
}

struct RootView: View {
    @Binding var pane: Pane
    @Environment(SystemStatus.self) private var system
    @Environment(PrefixesModel.self) private var prefixes
    @State private var showSetup = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                header
                Rectangle().fill(LauncherUI.border).frame(height: 1)
                Group {
                    switch pane {
                    case .status: LauncherHomeView(openSetup: { showSetup = true }, openLibrary: { pane = .prefixes })
                    case .prefixes: LauncherLibraryView()
                    case .backups: LauncherVaultView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                footer
            }
            .frame(maxWidth: .infinity)
            Rectangle().fill(LauncherUI.border).frame(width: 1)
            navigationRail
        }
        .background(LauncherUI.background)
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSetup) {
            NavigationStack {
                StatusView()
                    .frame(minWidth: 740, minHeight: 560)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showSetup = false }
                        }
                    }
            }
            .preferredColorScheme(.dark)
        }
    }

    private var header: some View {
        HStack(spacing: 22) {
            LauncherBrand()
            Spacer(minLength: 20)
            HStack(spacing: 7) {
                Circle()
                    .fill(system.isIdle ? Color.green : LauncherUI.blush)
                    .frame(width: 7, height: 7)
                Text(system.isIdle ? "READY" : "WORKING")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.2)
            }
            .foregroundStyle(LauncherUI.secondary)
            Button {
                Task {
                    if pane == .status { await system.refresh() }
                    else { await prefixes.load() }
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 35, height: 35)
                    .background(.white.opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain)
            .help("Refresh current data")
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 21)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Image(systemName: "apple.terminal")
                .foregroundStyle(LauncherUI.coral)
            Text("STEAM PLAY SYSTEM")
                .tracking(1.4)
            Spacer()
            Text("macOS 26+ / Apple Silicon")
        }
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
        .foregroundStyle(LauncherUI.secondary)
        .padding(.horizontal, 30)
        .padding(.vertical, 15)
        .background(LauncherUI.surface.opacity(0.55))
    }

    private var navigationRail: some View {
        VStack(spacing: 18) {
            Image(systemName: "circle.hexagongrid.fill")
                .foregroundStyle(LauncherUI.coral)
                .font(.system(size: 26))
                .padding(.top, 30)
                .padding(.bottom, 19)
            ForEach(Pane.allCases) { destination in
                Button {
                    pane = destination
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: destination.symbol)
                            .font(.system(size: 20, weight: .semibold))
                        Text(destination.label)
                            .font(.system(size: 9, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(pane == destination ? .white : LauncherUI.secondary)
                    .frame(width: 78, height: 70)
                    .background(pane == destination ? LauncherUI.coral.opacity(0.21) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 17))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(destination.label)
            }
            Spacer()
            Button { showSetup = true } label: {
                VStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 21, weight: .semibold))
                    Text("SETUP").font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(LauncherUI.secondary)
                .frame(width: 78, height: 70)
            }
            .buttonStyle(.plain)
            .help("Compatibility setup and advanced diagnostics")
            .padding(.bottom, 17)
        }
        .frame(width: 100)
        .background(LauncherUI.surface.opacity(0.7))
    }
}
