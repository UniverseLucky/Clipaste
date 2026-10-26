import SwiftUI

struct SettingsSidebar: View {
    @Binding var selectedTab: SettingsTab
    let accentColor: AppAccentColor
    let showsUpdateBadge: Bool

    var body: some View {
        List(selection: $selectedTab) {
            ForEach(SettingsTab.allCases) { tab in
                Label {
                    Text(tab.localizedTitle)
                        .lineLimit(1)
                        .foregroundStyle(selectedTab == tab ? accentColor.selectedContentColor : .primary)
                } icon: {
                    SettingsSidebarIcon(
                        tab: tab,
                        showsUpdateBadge: tab == .about && showsUpdateBadge
                    )
                }
                .tag(tab)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedTab == tab ? accentColor.color : .clear)
                        .padding(.horizontal, 10)
                )
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }
}
