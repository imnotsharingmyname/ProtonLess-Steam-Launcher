import SwiftUI

// An original interface kit for the launcher, independent of the Steam Play engine.
enum LauncherUI {
    static let background = Color(red: 0.055, green: 0.065, blue: 0.097)
    static let surface = Color(red: 0.105, green: 0.116, blue: 0.165)
    static let elevated = Color(red: 0.155, green: 0.164, blue: 0.216)
    static let coral = Color(red: 1.0, green: 0.43, blue: 0.40)
    static let blush = Color(red: 1.0, green: 0.70, blue: 0.51)
    static let secondary = Color(red: 0.63, green: 0.66, blue: 0.76)
    static let border = Color.white.opacity(0.08)
}

struct LauncherPanel<Content: View>: View {
    var padding: CGFloat = 23
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LauncherUI.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(LauncherUI.border, lineWidth: 1)
                    }
            )
    }
}

struct LauncherSectionTitle: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            Text(detail)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(LauncherUI.secondary)
        }
        .padding(.horizontal, 1)
    }
}

struct LauncherAction: View {
    let title: String
    let subtitle: String
    let symbol: String
    var tinted = false
    var disabled = false
    let perform: () -> Void

    var body: some View {
        Button(action: perform) {
            HStack(spacing: 13) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .medium))
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(tinted ? 0.16 : 0.06), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 13, weight: .bold))
                    Text(subtitle).font(.system(size: 11)).opacity(0.77)
                }
                Spacer(minLength: 3)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .bold))
                    .opacity(0.6)
            }
            .foregroundStyle(.white)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tinted ? LauncherUI.coral : LauncherUI.elevated, in: RoundedRectangle(cornerRadius: 17))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.43 : 1)
    }
}

struct LauncherPill: View {
    let title: String
    let symbol: String
    var tint: Color = LauncherUI.coral

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

struct LauncherBrand: View {
    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(LauncherUI.coral)
                    .frame(width: 43, height: 43)
                Image(systemName: "arrowtriangle.right.fill")
                    .font(.system(size: 21, weight: .bold))
                    .rotationEffect(.degrees(-12))
                    .foregroundStyle(LauncherUI.background)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("PROTONLESS")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .tracking(1.0)
                Text("STEAM  /  PLAY ANYWHERE")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(LauncherUI.secondary)
            }
        }
    }
}
