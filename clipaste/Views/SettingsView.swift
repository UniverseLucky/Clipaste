import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable, Hashable {
    case general = "general"
    case shortcuts = "shortcuts"
    case ignoredApps = "ignoredApps"
    case advanced = "advanced"
    case ai = "ai"
    case about = "about"

    var id: String { self.rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .general: return "General"
        case .shortcuts: return "Shortcuts"
        case .ignoredApps: return "Ignored Apps"
        case .advanced: return "Advanced"
        case .ai: return "AI Magic"
        case .about: return "About"
        }
    }

    var localizedTitle: LocalizedStringResource {
        switch self {
        case .general: return LocalizedStringResource("General")
        case .shortcuts: return LocalizedStringResource("Shortcuts")
        case .ignoredApps: return LocalizedStringResource("Ignored Apps")
        case .advanced: return LocalizedStringResource("Advanced")
        case .ai: return LocalizedStringResource("AI Magic")
        case .about: return LocalizedStringResource("About")
        }
    }

    var navigationTitle: LocalizedStringKey { title }

    var iconName: String {
        switch self {
        case .general: return "gearshape"
        case .shortcuts: return "keyboard"
        case .ignoredApps: return "nosign"
        case .advanced: return "slider.horizontal.3"
        case .ai: return "sparkles"
        case .about: return "info.circle"
        }
    }

}

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    @State private var isSidebarVisible = true
    @Environment(AppUpdateViewModel.self) private var appUpdateViewModel
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appTheme") private var appTheme: AppTheme = .system
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    @AppStorage("appAccentColor") private var appAccentColor: AppAccentColor = .defaultValue

    var body: some View {
        let resolvedLocale = appLanguage.resolvedLocale

        HStack(spacing: 0) {
            if isSidebarVisible {
                SettingsSidebar(
                    selectedTab: $selectedTab,
                    accentColor: appAccentColor,
                    showsUpdateBadge: appUpdateViewModel.shouldShowUpdateBadge
                )
                .settingsScrollChromeHidden()
                .settingsTopEdgeEffectHidden()
                .frame(width: 198)
                .frame(maxHeight: .infinity, alignment: .top)
                .background {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.black.opacity(colorScheme == .dark ? 0.18 : 0.05), lineWidth: 1)
                        }
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.18 : 0.05), radius: 18, y: 8)
                .padding(.leading, 14)
                .padding(.top, 14)
                .padding(.bottom, 14)
                .padding(.trailing, 18)
            }

            settingsDetailView(for: selectedTab)
                .background(Color(nsColor: .windowBackgroundColor))
                .frame(minWidth: 620, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea())
        .tint(appAccentColor.color)
        .environment(\.locale, resolvedLocale)
        .animation(nil, value: appLanguage)
        .frame(minWidth: 820, idealWidth: 900, maxWidth: .infinity,
               minHeight: 620, idealHeight: 700, maxHeight: .infinity)
        .background(SettingsWindowObserver())
        .background(WindowAppearanceObserver(theme: appTheme))
        .onReceive(NotificationCenter.default.publisher(for: .toggleSettingsSidebarIntent)) { _ in
            if accessibilityReduceMotion {
                isSidebarVisible.toggle()
            } else {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isSidebarVisible.toggle()
                }
            }
        }
    }
}

private extension SettingsView {
    @ViewBuilder
    func settingsDetailView(for tab: SettingsTab) -> some View {
        switch tab {
        case .general:
            GeneralSettingsView()
        case .shortcuts:
            ShortcutsSettingsView()
        case .ignoredApps:
            IgnoredAppsSettingsView()
        case .advanced:
            AdvancedSettingsView()
        case .ai:
            AISettingsView()
        case .about:
            AboutSettingsView()
        }
    }
}
