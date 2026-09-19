import SwiftUI
import AppKit

struct CharacterParagraphPanel: View {
    @Bindable var session: EditorSession

    // 常用排版字体（优先中文友好字体）
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
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // 文本内容输入与快速添加
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Text Content".localized)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        if session.activeLayer?.liveText != nil {
                            Text("Editing Selected Layer".localized)
                                .font(.system(size: 10))
                                .foregroundStyle(Color.accentColor)
                        }
                    }

                    TextField("Type text here…".localized, text: Binding(
                        get: { session.activeTextStyle.text },
                        set: { newText in
                            session.activeTextStyle.text = newText
                            if session.activeLayer?.liveText != nil {
                                session.updateActiveLayerText(style: session.activeTextStyle)
                            }
                        }
                    ), axis: .vertical)
                    .lineLimit(3...5)
                    .textFieldStyle(.roundedBorder)

                    HStack {
                        Button {
                            session.addTextLayer()
                        } label: {
                            Label("New Text Layer".localized, systemImage: "plus.bubble")
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(!session.canEditLayers)

                        Spacer()
                    }
                }

                Divider()

                // 字符属性 (Character)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Character".localized)
                        .font(.system(size: 12, weight: .semibold))

                    // 字体选择
                    HStack {
                        Text("Font".localized)
                            .font(.system(size: 11))
                            .frame(width: 48, alignment: .leading)
                        Picker("", selection: Binding(
                            get: { session.activeTextStyle.fontName },
                            set: { font in
                                session.activeTextStyle.fontName = font
                                updateLayerIfText()
                            }
                        )) {
                            ForEach(commonFonts, id: \.name) { font in
                                Text(font.displayName).tag(font.name)
                            }
                        }
                        .labelsHidden()
                    }

                    // 字号与颜色
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Text("Font Size".localized)
                                .font(.system(size: 11))
                                .frame(width: 48, alignment: .leading)
                            TextField("", value: Binding<Double>(
                                get: { Double(session.activeTextStyle.fontSize) },
                                set: {
                                    session.activeTextStyle.fontSize = CGFloat(max(8, min(400, $0)))
                                    updateLayerIfText()
                                }
                            ), format: .number.precision(.fractionLength(0)))
                            .frame(width: 50)
                            .textFieldStyle(.roundedBorder)
                        }

                        Spacer()

                        // 文字颜色
                        HStack(spacing: 4) {
                            Text("Color".localized)
                                .font(.system(size: 11))
                            ColorPicker("", selection: Binding(
                                get: { session.activeTextStyle.color.swiftUI },
                                set: { color in
                                    if let nsColor = NSColor(color).usingColorSpace(.sRGB) {
                                        session.activeTextStyle.red = nsColor.redComponent
                                        session.activeTextStyle.green = nsColor.greenComponent
                                        session.activeTextStyle.blue = nsColor.blueComponent
                                        updateLayerIfText()
                                    }
                                }
                            ))
                            .labelsHidden()
                        }
                    }

                    // 样式修饰：加粗、倾斜、排版方向
                    HStack(spacing: 8) {
                        // 加粗
                        Toggle(isOn: Binding(
                            get: { session.activeTextStyle.isBold },
                            set: {
                                session.activeTextStyle.isBold = $0
                                updateLayerIfText()
                            }
                        )) {
                            Image(systemName: "bold")
                                .font(.system(size: 11))
                        }
                        .toggleStyle(.button)
                        .help("Bold".localized)

                        // 倾斜
                        Toggle(isOn: Binding(
                            get: { session.activeTextStyle.isItalic },
                            set: {
                                session.activeTextStyle.isItalic = $0
                                updateLayerIfText()
                            }
                        )) {
                            Image(systemName: "italic")
                                .font(.system(size: 11))
                        }
                        .toggleStyle(.button)
                        .help("Italic".localized)

                        Spacer()

                        // 竖排切换（漫画嵌字关键）
                        Picker("", selection: Binding(
                            get: { session.activeTextStyle.isVertical },
                            set: {
                                session.activeTextStyle.isVertical = $0
                                updateLayerIfText()
                            }
                        )) {
                            Text("Horizontal Text".localized).tag(false)
                            Text("Vertical Text".localized).tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 140)
                    }
                }

                Divider()

                // 段落属性 (Paragraph)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Paragraph".localized)
                        .font(.system(size: 12, weight: .semibold))

                    // 对齐方式
                    HStack {
                        Text("Alignment".localized)
                            .font(.system(size: 11))
                            .frame(width: 48, alignment: .leading)
                        Picker("", selection: Binding(
                            get: { session.activeTextStyle.alignment },
                            set: {
                                session.activeTextStyle.alignment = $0
                                updateLayerIfText()
                            }
                        )) {
                            Image(systemName: "text.alignleft").tag(TextAlignmentOption.left)
                            Image(systemName: "text.aligncenter").tag(TextAlignmentOption.center)
                            Image(systemName: "text.alignright").tag(TextAlignmentOption.right)
                        }
                        .pickerStyle(.segmented)
                    }

                    // 行距与字距
                    HStack(spacing: 12) {
                        HStack(spacing: 6) {
                            Text("Leading".localized)
                                .font(.system(size: 11))
                                .frame(width: 48, alignment: .leading)
                            TextField("", value: Binding<Double>(
                                get: { Double(session.activeTextStyle.leading) },
                                set: {
                                    session.activeTextStyle.leading = CGFloat(max(0, min(100, $0)))
                                    updateLayerIfText()
                                }
                            ), format: .number.precision(.fractionLength(0)))
                            .frame(width: 50)
                            .textFieldStyle(.roundedBorder)
                        }

                        Spacer()

                        HStack(spacing: 6) {
                            Text("Tracking".localized)
                                .font(.system(size: 11))
                            TextField("", value: Binding<Double>(
                                get: { Double(session.activeTextStyle.tracking) },
                                set: {
                                    session.activeTextStyle.tracking = CGFloat(max(-20, min(100, $0)))
                                    updateLayerIfText()
                                }
                            ), format: .number.precision(.fractionLength(0)))
                            .frame(width: 50)
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                }

                Divider()

                // 描边属性 (Stroke - 嵌字防透底)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Toggle("Stroke".localized, isOn: Binding(
                            get: { session.activeTextStyle.strokeEnabled },
                            set: {
                                session.activeTextStyle.strokeEnabled = $0
                                updateLayerIfText()
                            }
                        ))
                        .font(.system(size: 12, weight: .semibold))

                        Spacer()

                        if session.activeTextStyle.strokeEnabled {
                            ColorPicker("", selection: Binding(
                                get: { session.activeTextStyle.strokeColor.swiftUI },
                                set: { color in
                                    if let nsColor = NSColor(color).usingColorSpace(.sRGB) {
                                        session.activeTextStyle.strokeRed = nsColor.redComponent
                                        session.activeTextStyle.strokeGreen = nsColor.greenComponent
                                        session.activeTextStyle.strokeBlue = nsColor.blueComponent
                                        updateLayerIfText()
                                    }
                                }
                            ))
                            .labelsHidden()
                        }
                    }

                    if session.activeTextStyle.strokeEnabled {
                        HStack(spacing: 8) {
                            Text("Stroke Width".localized)
                                .font(.system(size: 11))
                                .frame(width: 58, alignment: .leading)
                            Slider(value: Binding<Double>(
                                get: { Double(session.activeTextStyle.strokeWidth) },
                                set: {
                                    session.activeTextStyle.strokeWidth = CGFloat($0)
                                    updateLayerIfText()
                                }
                            ), in: 1...20)
                            Text("\(Int(session.activeTextStyle.strokeWidth)) px")
                                .font(.system(size: 11).monospacedDigit())
                                .frame(width: 38, alignment: .trailing)
                        }
                    }
                }
            }
            .padding(14)
        }
        .frame(width: 280, height: 460)
    }

    private func updateLayerIfText() {
        if session.activeLayer?.liveText != nil {
            session.updateActiveLayerText(style: session.activeTextStyle)
        }
    }
}
