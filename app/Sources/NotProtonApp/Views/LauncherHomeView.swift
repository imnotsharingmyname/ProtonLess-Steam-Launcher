import AppKit
import SwiftUI

/// The new landing page is its own composition. The original diagnostics
/// remain available under Setup for all original confirmations and tools.
struct LauncherHomeView: View {
    @Environment(SystemStatus.self) private var system
    @Environment(PrefixesModel.self) private var prefixes
    let openSetup: () -> Void
    let openLibrary: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                hero
                LauncherSectionTitle(title: "Your control deck", detail: "Everything in one place")
                HStack(alignment: .top, spacing: 20) {
                    actionColumn
                        .frame(maxWidth: .infinity)
                    healthColumn
                        .frame(maxWidth: .infinity)
                }
                LauncherSectionTitle(title: "Your library", detail: "Live environment overview")
                libraryStrip
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 25)
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .task {
            if system.snapshot == nil { await system.refresh() }
            if !prefixes.hasLoaded { await prefixes.load() }
        }
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: 26) {
            VStack(alignment: .leading, spacing: 16) {
                Text("WELCOME TO THE NEXT LEVEL")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(2.7)
                    .foregroundStyle(LauncherUI.blush)
                Text("Your games.\nNo boundaries.")
                    .font(.system(size: 43, weight: .black, design: .rounded))
                    .tracking(-1.8)
                    .lineSpacing(-3)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.white)
                Text("Bridge your Steam library to Windows games on Mac.")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.77))
                Button(action: openSetup) {
                    HStack(spacing: 12) {
                        Image(systemName: "bolt.horizontal.circle.fill")
                        Text("OPEN SETUP CENTER")
                            .tracking(0.8)
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(LauncherUI.background)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 15)
                    .background(.white, in: RoundedRectangle(cornerRadius: 13))
                }
                .buttonStyle(.plain)
                .padding(.top, 5)
            }
            Spacer(minLength: 0)
            ZStack {
                Circle().stroke(.white.opacity(0.10), lineWidth: 2).frame(width: 170, height: 170)
                Circle().stroke(.white.opacity(0.07), lineWidth: 2).frame(width: 126, height: 126)
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 73, weight: .ultraLight))
                    .rotationEffect(.degrees(-18))
                    .shadow(color: .black.opacity(0.2), radius: 14, y: 12)
            }
            .frame(width: 180, height: 180)
        }
        .padding(29)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [LauncherUI.coral, Color(red: 0.57, green: 0.29, blue: 0.50), LauncherUI.surface],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 25)
        )
    }

    private var actionColumn: some View {
        LauncherPanel {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("QUICK ACCESS")
                LauncherAction(title: "Set up Steam Play", subtitle: "Install, repair and configure", symbol: "bolt.fill", tinted: true, perform: openSetup)
                LauncherAction(title: "CrossOver trial & licence", subtitle: "Check activation and official trial status", symbol: "checkmark.shield.fill", perform: openSetup)
                LauncherAction(title: "Show application log", subtitle: "Inspect diagnostics in Finder", symbol: "doc.text.magnifyingglass") {
                    NSWorkspace.shared.activateFileViewerSelecting([AppLog.file])
                }
            }
        }
    }

    private var healthColumn: some View {
        LauncherPanel {
            VStack(alignment: .leading, spacing: 17) {
                sectionLabel("SYSTEM HEALTH")
                HStack {
                    Text("Compatibility status")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Spacer()
                    LauncherPill(title: system.isIdle ? "ONLINE" : "BUSY", symbol: "circle.fill")
                }
                healthLine("Steam integration", value: steamState, symbol: "desktopcomputer")
                Divider().overlay(LauncherUI.border)
                healthLine("CrossOver installs", value: "\(system.crossOverRows.count) found", symbol: "shippingbox.fill")
                Divider().overlay(LauncherUI.border)
                healthLine("Game prefixes", value: "\(prefixes.prefixes.count) detected", symbol: "square.stack.3d.up.fill")
                Divider().overlay(LauncherUI.border)
                healthLine("CrossOver access", value: crossOverState, symbol: "checkmark.shield.fill")
                if let issue = system.failure {
                    Text(issue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(LauncherUI.blush)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let activity = system.activity {
                    HStack(spacing: 9) {
                        ProgressView().controlSize(.small)
                        Text(activity).font(.system(size: 11))
                    }
                }
                Button("VIEW ALL SYSTEM DETAILS", action: openSetup)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.3)
                    .foregroundStyle(LauncherUI.blush)
                    .buttonStyle(.plain)
                    .padding(.top, 2)
            }
        }
    }

    private var libraryStrip: some View {
        Button(action: openLibrary) {
            HStack(spacing: 17) {
                Image(systemName: "rectangle.stack.badge.play.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(LauncherUI.coral)
                    .frame(width: 69, height: 69)
                    .background(LauncherUI.elevated, in: RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 6) {
                    Text("Windows game environments").font(.system(size: 17, weight: .bold))
                    Text("Manage prefixes, run programs and repair Windows runtimes.")
                        .font(.system(size: 12))
                        .foregroundStyle(LauncherUI.secondary)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 19, weight: .semibold))
            }
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .padding(18)
        .background(LauncherUI.surface, in: RoundedRectangle(cornerRadius: 22))
    }

    private func healthLine(_ label: String, value: String, symbol: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .foregroundStyle(LauncherUI.coral)
                .frame(width: 20)
            Text(label).font(.system(size: 12))
            Spacer(minLength: 5)
            Text(value).font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.82))
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy, design: .monospaced))
            .foregroundStyle(LauncherUI.secondary)
            .tracking(2.2)
            .padding(.bottom, 4)
    }

    private var steamState: String {
        guard let state = system.snapshot?.steam else { return "Checking…" }
        return switch state {
        case .installed: "Installed"
        case .outdated: "Update available"
        case .notInstalled: "Not installed"
        case .foreign: "Different library"
        case .steamMissing: "Steam not found"
        }
    }

    private var crossOverState: String {
        guard let snapshot = system.snapshot else { return "Checking…" }
        guard !snapshot.crossOver.isEmpty else { return "Not installed" }
        let licenses = snapshot.crossOverLicense.values
        if let trial = licenses.first(where: { $0.detail.localizedCaseInsensitiveContains("trial is active") }) {
            return trial.detail
        }
        if licenses.contains(where: { $0.licensed }) { return "Activated" }
        return "Not activated"
    }
}
