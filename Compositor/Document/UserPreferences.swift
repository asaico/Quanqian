import SwiftUI
import Combine

/// 画布滚轮缩放触发方式
enum ScrollZoomTrigger: String, CaseIterable, Identifiable, Codable, Sendable {
    case command = "Command + Scroll Wheel"
    case option = "Option + Scroll Wheel"
    case direct = "Direct Scroll (No modifier keys)"
    case disabled = "Disabled"

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .command: return "Command + 滚轮缩放 (默认)".localized
        case .option: return "Option + 滚轮缩放".localized
        case .direct: return "直接滚轮缩放 (无需按键)".localized
        case .disabled: return "关闭滚轮缩放".localized
        }
    }
}

/// 侧边栏布局持久化配置
struct SidebarLayoutState: Codable, Equatable, Sendable {
    var layersLocation: PanelDockLocation = .rightSidebar
    var characterLocation: PanelDockLocation = .rightSidebar
    var historyLocation: PanelDockLocation = .rightSidebar

    var layersSection: SidebarSection = .bottom
    var characterSection: SidebarSection = .middle
    var historySection: SidebarSection = .top

    var showsLayersPanel: Bool = true
    var showsCharacterPanel: Bool = true
    var showsHistoryPanel: Bool = true

    var leftSidebarWidth: Double = 252.0
    var rightSidebarWidth: Double = 252.0
}

/// 非隔离底层偏好存储（线程安全，零 Actor 限制）
struct AppPreferencesStorage: Sendable {
    static let layoutKey = "quanqian.sidebar_layout"
    static let zoomTriggerKey = "quanqian.scroll_zoom_trigger"
    static let zoomSensitivityKey = "quanqian.scroll_zoom_sensitivity"
    static let zoomInvertedKey = "quanqian.scroll_zoom_inverted"

    static func loadLayout() -> SidebarLayoutState {
        if let data = UserDefaults.standard.data(forKey: layoutKey),
           let decoded = try? JSONDecoder().decode(SidebarLayoutState.self, from: data) {
            return decoded
        }
        return SidebarLayoutState()
    }

    static func saveLayout(_ layout: SidebarLayoutState) {
        if let data = try? JSONEncoder().encode(layout) {
            UserDefaults.standard.set(data, forKey: layoutKey)
        }
    }

    static func loadZoomTrigger() -> ScrollZoomTrigger {
        if let raw = UserDefaults.standard.string(forKey: zoomTriggerKey),
           let trigger = ScrollZoomTrigger(rawValue: raw) {
            return trigger
        }
        return .command
    }

    static func saveZoomTrigger(_ trigger: ScrollZoomTrigger) {
        UserDefaults.standard.set(trigger.rawValue, forKey: zoomTriggerKey)
    }

    static func loadZoomSensitivity() -> Double {
        let val = UserDefaults.standard.double(forKey: zoomSensitivityKey)
        return val > 0 ? val : 1.0
    }

    static func saveZoomSensitivity(_ val: Double) {
        UserDefaults.standard.set(val, forKey: zoomSensitivityKey)
    }

    static func loadZoomInverted() -> Bool {
        UserDefaults.standard.bool(forKey: zoomInvertedKey)
    }

    static func saveZoomInverted(_ val: Bool) {
        UserDefaults.standard.set(val, forKey: zoomInvertedKey)
    }
}

/// 用户偏好设置管理器（UI 层响应式，供 SettingsView 绑定使用）
@MainActor
final class UserPreferences: ObservableObject {
    static let shared = UserPreferences()

    @Published var scrollZoomTrigger: ScrollZoomTrigger {
        didSet {
            AppPreferencesStorage.saveZoomTrigger(scrollZoomTrigger)
        }
    }

    @Published var scrollZoomSensitivity: Double {
        didSet {
            AppPreferencesStorage.saveZoomSensitivity(scrollZoomSensitivity)
        }
    }

    @Published var scrollZoomInverted: Bool {
        didSet {
            AppPreferencesStorage.saveZoomInverted(scrollZoomInverted)
        }
    }

    @Published var layout: SidebarLayoutState {
        didSet {
            AppPreferencesStorage.saveLayout(layout)
        }
    }

    private init() {
        self.scrollZoomTrigger = AppPreferencesStorage.loadZoomTrigger()
        self.scrollZoomSensitivity = AppPreferencesStorage.loadZoomSensitivity()
        self.scrollZoomInverted = AppPreferencesStorage.loadZoomInverted()
        self.layout = AppPreferencesStorage.loadLayout()
    }

    func resetToDefaults() {
        scrollZoomTrigger = .command
        scrollZoomSensitivity = 1.0
        scrollZoomInverted = false
        layout = SidebarLayoutState()
    }
}
