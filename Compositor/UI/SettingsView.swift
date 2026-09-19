import SwiftUI

struct SettingsView: View {
    @ObservedObject private var localization = LocalizationManager.shared
    @ObservedObject private var preferences = UserPreferences.shared

    var body: some View {
        TabView {
            // 常规设置 (General)
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

            // 快捷键与操作习惯设置 (Shortcuts & Gestures)
            Form {
                Section {
                    Picker("Canvas Zoom Mode".localized, selection: $preferences.scrollZoomTrigger) {
                        ForEach(ScrollZoomTrigger.allCases) { mode in
                            Text(mode.localizedTitle).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)

                    HStack {
                        Text("Zoom Sensitivity".localized)
                        Slider(value: $preferences.scrollZoomSensitivity, in: 0.5...2.0, step: 0.1)
                        Text(String(format: "%.1fx", preferences.scrollZoomSensitivity))
                            .monospacedDigit()
                            .frame(width: 40)
                    }

                    Toggle("Invert Zoom Direction".localized, isOn: $preferences.scrollZoomInverted)

                    Text("Tip: In default mode, hold Command or Option while scrolling to zoom the canvas.".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Canvas Zoom & Gestures".localized)
                        .font(.headline)
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Tool / Action".localized).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Spacer()
                            Text("Shortcut".localized).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)

                        Divider()

                        shortcutRow(name: "Type Tool / Horizontal & Vertical".localized, shortcut: "T / ⇧T")
                        shortcutRow(name: "Move / Transform Tool".localized, shortcut: "V")
                        shortcutRow(name: "Brush / Eraser Tool".localized, shortcut: "B / E")
                        shortcutRow(name: "Gradient / Paint Bucket Tool".localized, shortcut: "G / ⇧G")
                        shortcutRow(name: "Rectangular / Elliptical Marquee".localized, shortcut: "M / ⇧M")
                        shortcutRow(name: "Freehand / Polygonal Lasso".localized, shortcut: "L / ⇧L")
                        shortcutRow(name: "Magic Wand Tool".localized, shortcut: "W")
                        shortcutRow(name: "Crop Tool".localized, shortcut: "C")
                        shortcutRow(name: "Spot Healing Brush".localized, shortcut: "J")
                        shortcutRow(name: "Clone Stamp Tool".localized, shortcut: "S")
                        shortcutRow(name: "Smear / Blur Tool".localized, shortcut: "R")
                        shortcutRow(name: "Shape Tool (Rect / Ellipse / Round)".localized, shortcut: "U / ⇧U")
                        shortcutRow(name: "Eyedropper Tool".localized, shortcut: "I")
                        shortcutRow(name: "Hand Tool / Pan Canvas".localized, shortcut: "H / Space")
                        shortcutRow(name: "Zoom Tool".localized, shortcut: "Z")
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Photoshop-Compatible Tool Shortcuts".localized)
                        .font(.headline)
                }

                Section {
                    Button("Reset Operations & Shortcuts to Defaults".localized) {
                        preferences.resetToDefaults()
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("Shortcuts & Operations".localized, systemImage: "keyboard")
            }
            .tag("shortcuts")
        }
        .frame(width: 520, height: 420)
        .padding()
    }

    private func shortcutRow(name: String, shortcut: String) -> some View {
        HStack {
            Text(name).font(.system(size: 11))
            Spacer()
            Text(shortcut)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.4"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "5"
        return String(format: "Version %@ (%@)".localized, version, build)
    }
}
