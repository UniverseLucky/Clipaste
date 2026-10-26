import SwiftUI

/// A small, dimensional tile that keeps its identity on every selection color.
struct SettingsSidebarIcon: View {
    let tab: SettingsTab
    var showsUpdateBadge = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.sidebarRowSize) private var sidebarRowSize

    // Custom artwork follows the same size preference as the native sidebar label.
    private var tileSize: CGFloat {
        switch sidebarRowSize {
        case .small: 16
        case .medium: 20
        case .large: 24
        @unknown default: 20
        }
    }

    private var gradientColors: [Color] {
        switch tab {
        case .general:
            [Color(red: 0.66, green: 0.69, blue: 0.74), Color(red: 0.43, green: 0.47, blue: 0.53)]
        case .shortcuts:
            [Color(red: 0.20, green: 0.69, blue: 1.00), Color(red: 0.02, green: 0.39, blue: 0.91)]
        case .ignoredApps:
            [Color(red: 1.00, green: 0.47, blue: 0.42), Color(red: 0.87, green: 0.20, blue: 0.24)]
        case .advanced:
            [Color(red: 0.22, green: 0.79, blue: 0.72), Color(red: 0.02, green: 0.51, blue: 0.52)]
        case .ai:
            [Color(red: 0.79, green: 0.49, blue: 1.00), Color(red: 0.49, green: 0.24, blue: 0.88)]
        case .about:
            [Color(red: 0.28, green: 0.65, blue: 1.00), Color(red: 0.14, green: 0.36, blue: 0.88)]
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: tileSize / 4)
            .fill(LinearGradient(colors: gradientColors, startPoint: .top, endPoint: .bottom))
            .overlay {
                RoundedRectangle(cornerRadius: tileSize / 4)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.55), .white.opacity(0.08), .black.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            }
            .overlay {
                Image(systemName: tab.iconName)
                    .resizable()
                    .scaledToFit()
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.white)
                    .frame(width: tileSize * 0.7, height: tileSize * 0.7)
                    .shadow(color: .black.opacity(0.16), radius: 0.5, y: 0.5)
            }
            .frame(width: tileSize, height: tileSize)
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.30 : 0.18), radius: 1.5, y: 1)
            .overlay(alignment: .topTrailing) {
                if showsUpdateBadge {
                    Circle()
                        .fill(.red)
                        .frame(width: 6, height: 6)
                        .overlay {
                            Circle()
                                .stroke(Color(nsColor: .controlBackgroundColor), lineWidth: 1)
                        }
                        .offset(x: 2, y: -1)
                }
            }
            .accessibilityHidden(true)
    }
}
