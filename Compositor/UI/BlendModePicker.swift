import SwiftUI
import AppKit

struct BlendModePicker: NSViewRepresentable {
    let session: EditorSession
    func makeCoordinator() -> Coordinator { Coordinator(session: session) }
    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: false)
        button.removeAllItems()
        for mode in LayerBlendMode.allCases {
            let item = NSMenuItem(title: mode.rawValue.localized, action: nil, keyEquivalent: "")
            item.representedObject = mode
            button.menu?.addItem(item)
        }
        button.menu?.delegate = context.coordinator
        button.target = context.coordinator
        button.action = #selector(Coordinator.choose(_:))
        button.setAccessibilityLabel("Blend mode".localized)
        // A capsule like the SwiftUI buttons and menus (`roundedControls`), which don't reach this AppKit pop-up.
        button.borderShape = .capsule
        return button
    }
    func updateNSView(_ button: NSPopUpButton, context: Context) {
        button.isEnabled = session.canEditAppearance
        for item in button.menu?.items ?? [] {
            if let mode = item.representedObject as? LayerBlendMode {
                item.title = mode.rawValue.localized
            }
        }
        if !context.coordinator.tracking {
            let targetMode = session.activeLayer?.blendMode ?? .normal
            if let item = button.menu?.items.first(where: { ($0.representedObject as? LayerBlendMode) == targetMode }) {
                button.select(item)
            }
        }
    }
    static func dismantleNSView(_ button: NSPopUpButton, coordinator: Coordinator) {
        if coordinator.tracking { coordinator.session.previewBlendMode(nil, for: nil) }
        button.menu?.delegate = nil
    }
    final class Coordinator: NSObject, NSMenuDelegate {
        let session: EditorSession
        var tracking = false
        private var layerID: UUID?
        private var highlightedMode: LayerBlendMode?
        init(session: EditorSession) { self.session = session }
        func menuWillOpen(_ menu: NSMenu) {
            tracking = true
            layerID = session.activeLayerID
            highlightedMode = nil
        }
        func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
            let mode = item?.representedObject as? LayerBlendMode ?? item.flatMap { LayerBlendMode(rawValue: $0.title) }
            if let mode { highlightedMode = mode }
            session.previewBlendMode(mode, for: layerID)
        }
        func menuDidClose(_ menu: NSMenu) {
            tracking = false
            session.previewBlendMode(nil, for: nil)
        }
        @objc func choose(_ button: NSPopUpButton) {
            guard session.activeLayerID == layerID,
                  let mode = highlightedMode ?? (button.selectedItem?.representedObject as? LayerBlendMode) ?? button.selectedItem.flatMap({ LayerBlendMode(rawValue: $0.title) }) else { return }
            session.setLayerBlendMode(mode)
            if let item = button.menu?.items.first(where: { ($0.representedObject as? LayerBlendMode) == mode }) {
                button.select(item)
            }
            highlightedMode = nil
            session.refreshCanvasPreview?()
        }
    }
}
