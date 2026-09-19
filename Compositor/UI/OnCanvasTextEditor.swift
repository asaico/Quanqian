import SwiftUI
import AppKit

/// Photoshop 风格纯净画布原位直接编辑文字（无弹窗、无浮层药丸，直接在画面原位输入）
struct OnCanvasTextEditor: View {
    @Bindable var session: EditorSession
    let layer: ImageLayer

    @FocusState private var isFieldFocused: Bool
    @State private var originalText: String = ""

    private var documentSize: CGSize {
        session.document?.size ?? .zero
    }

    private var pointsPerPixel: CGFloat {
        session.viewport.pointsPerPixel
    }

    private var originPoint: CGPoint {
        session.viewport.viewPoint(from: layer.origin, documentSize: documentSize)
    }

    private var displayFontSize: CGFloat {
        max(12, session.activeTextStyle.fontSize * pointsPerPixel)
    }

    private var multilineAlignment: TextAlignment {
        switch session.activeTextStyle.alignment {
        case .left: return .leading
        case .center: return .center
        case .right: return .trailing
        }
    }

    private var textFont: Font {
        if NSFont(name: session.activeTextStyle.fontName, size: displayFontSize) != nil {
            return .custom(session.activeTextStyle.fontName, size: displayFontSize)
        }
        return .system(size: displayFontSize, weight: session.activeTextStyle.isBold ? .bold : .regular)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 点击外部画布区域自动完成提交并退出编辑
            Color.black.opacity(0.001)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    session.finishCanvasTextEditing()
                }

            // 原位透明输入框（直接位于文字物理坐标，无独立背景窗口，所见即所得）
            VStack(alignment: .leading, spacing: 0) {
                TextField("", text: Binding(
                    get: { session.activeTextStyle.text },
                    set: { newText in
                        session.activeTextStyle.text = newText
                        session.updateActiveLayerText(style: session.activeTextStyle)
                    }
                ), axis: .vertical)
                .font(textFont)
                .multilineTextAlignment(multilineAlignment)
                .foregroundStyle(session.activeTextStyle.color.swiftUI)
                .focused($isFieldFocused)
                .textFieldStyle(.plain)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.clear)
                .overlay {
                    // 仅显示极其微妙的细虚线编辑框与基线提示（Photoshop 风格，无任何黑色窗口）
                    Rectangle()
                        .strokeBorder(Color.accentColor.opacity(0.75), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
                .frame(minWidth: max(80, layer.size.width * pointsPerPixel + 8), minHeight: max(24, layer.size.height * pointsPerPixel + 4), alignment: .topLeading)
            }
            .offset(x: originPoint.x - 4, y: originPoint.y - 2)

            // 快捷键支持：Command+Return 快速提交
            Button("") {
                session.finishCanvasTextEditing()
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .opacity(0)
            .frame(width: 0, height: 0)
        }
        .onAppear {
            originalText = session.activeTextStyle.text
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isFieldFocused = true
            }
        }
        .onExitCommand {
            // 按 Escape 放弃修改并还原文本
            session.cancelCanvasTextEditing()
        }
    }
}
