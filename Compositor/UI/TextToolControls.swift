import SwiftUI
import AppKit

struct TextToolControls: View {
    @Bindable var session: EditorSession

    private let commonFonts: [(name: String, displayName: String)] = [
        ("PingFangSC-Regular", "苹方 (PingFang SC)"),
        ("SongtiSC-Regular", "宋体 (Songti SC)"),
        ("KaitiSC-Regular", "楷体 (Kaiti SC)"),
        ("YuantiSC-Regular", "圆体 (Yuanti SC)"),
        ("HelveticaNeue", "Helvetica Neue"),
        ("TimesNewRomanPSMT", "Times New Roman"),
        ("ArialMT", "Arial")
    ]

    var body: some View {
        HStack(spacing: 12) {
            Text("Type Tool".localized).font(ToolHeaderStyle.titleFont)

            // 横竖排切换
            Picker("Orientation".localized, selection: Binding(
                get: { session.textToolOrientation },
                set: { newOrientation in
                    session.textToolOrientation = newOrientation
                    let isVert = (newOrientation == .vertical)
                    if session.activeTextStyle.isVertical != isVert {
                        session.activeTextStyle.isVertical = isVert
                        swap(&session.activeTextStyle.leading, &session.activeTextStyle.tracking)
                        if session.activeLayer?.liveText != nil {
                            session.updateActiveLayerText(style: session.activeTextStyle)
                        }
                    }
                }
            )) {
                Image(systemName: "text.alignleft").tag(TextToolOrientation.horizontal)
                Image(systemName: "text.word.spacing").tag(TextToolOrientation.vertical)
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .help("Toggle Horizontal / Vertical Type (⇧T)".localized)

            // 字体选择
            Picker("Font".localized, selection: Binding(
                get: { session.activeTextStyle.fontName },
                set: { newFont in
                    session.activeTextStyle.fontName = newFont
                    if session.activeLayer?.liveText != nil {
                        session.updateActiveLayerText(style: session.activeTextStyle)
                    }
                }
            )) {
                ForEach(commonFonts, id: \.name) { font in
                    Text(font.displayName).tag(font.name)
                }
            }
            .labelsHidden()
            .frame(width: 140)

            // 字号调节
            HStack(spacing: 4) {
                Text("Size".localized).font(.caption).foregroundStyle(.secondary)
                TextField("", value: Binding<Double>(
                    get: { Double(session.activeTextStyle.fontSize) },
                    set: { newSize in
                        session.activeTextStyle.fontSize = CGFloat(max(8, min(400, newSize)))
                        if session.activeLayer?.liveText != nil {
                            session.updateActiveLayerText(style: session.activeTextStyle)
                        }
                    }
                ), format: .number.precision(.fractionLength(0)))
                .textFieldStyle(.roundedBorder)
                .frame(width: 46)
                .scrollableNumber(value: Binding(
                    get: { Double(session.activeTextStyle.fontSize) },
                    set: { newSize in
                        session.activeTextStyle.fontSize = CGFloat(max(8, min(400, newSize)))
                        if session.activeLayer?.liveText != nil {
                            session.updateActiveLayerText(style: session.activeTextStyle)
                        }
                    }
                ), range: 8...400, step: 1)
                .help("Font size in points; scroll wheel adjusts value".localized)
                Text("pt").font(.caption).foregroundStyle(.secondary)
            }

            // 颜色选择器
            ColorPicker("", selection: Binding(
                get: { session.activeTextStyle.color.swiftUI },
                set: { color in
                    if let nsColor = NSColor(color).usingColorSpace(.sRGB) {
                        session.activeTextStyle.red = nsColor.redComponent
                        session.activeTextStyle.green = nsColor.greenComponent
                        session.activeTextStyle.blue = nsColor.blueComponent
                        if session.activeLayer?.liveText != nil {
                            session.updateActiveLayerText(style: session.activeTextStyle)
                        }
                    }
                }
            ))
            .labelsHidden()
            .frame(width: 28, height: 24)
            .help("Text color".localized)

            // 对齐方式
            Picker("Alignment".localized, selection: Binding(
                get: { session.activeTextStyle.alignment },
                set: { newAlign in
                    session.activeTextStyle.alignment = newAlign
                    if session.activeLayer?.liveText != nil {
                        session.updateActiveLayerText(style: session.activeTextStyle)
                    }
                }
            )) {
                Image(systemName: "text.alignleft").tag(TextAlignmentOption.left)
                Image(systemName: "text.aligncenter").tag(TextAlignmentOption.center)
                Image(systemName: "text.alignright").tag(TextAlignmentOption.right)
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .help("Text Alignment".localized)

            Spacer()

            if session.isEditingTextOnCanvas {
                Button {
                    session.finishCanvasTextEditing()
                } label: {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                }
                .help("Commit current edits (Enter / ⌘⏎)".localized)

                Button {
                    session.cancelCanvasTextEditing()
                } label: {
                    Image(systemName: "xmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                .help("Cancel current edits (Esc)".localized)

                Divider().frame(height: 16)
            }

            // 打开字符与段落面板
            Button {
                session.togglePanel(.character)
            } label: {
                Label("Character & Paragraph".localized, systemImage: "character")
            }
            .help("Toggle Character & Paragraph panel".localized)
        }
        .padding(.horizontal, 18).toolHeaderBar().releasesFocusOnCommit(session)
        .disabled(session.showsBusy || session.document == nil)
    }
}
