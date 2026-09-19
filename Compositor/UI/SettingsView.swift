import SwiftUI

struct SettingsView: View {
    @ObservedObject private var localization = LocalizationManager.shared

    var body: some View {
        TabView {
            Form {
                Section {
                    Picker("Language / 语言", selection: $localization.currentLanguage) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)

                    Text("Language changes take effect immediately across all windows.".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Interface Language".localized)
                        .font(.headline)
                }

                Divider().padding(.vertical, 8)

                Section {
                    LabeledContent("About".localized) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("泉嵌 (Quanqian)")
                                .font(.body.weight(.semibold))
                            Text(appVersionString)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Open-source image editor".localized)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("General".localized, systemImage: "gearshape")
            }
            .tag("general")
        }
        .frame(width: 480, height: 260)
        .padding()
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.4"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "5"
        return String(format: "Version %@ (%@)".localized, version, build)
    }
}
