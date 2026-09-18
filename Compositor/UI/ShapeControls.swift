import SwiftUI

struct ShapeControls: View {
    @Bindable var session: EditorSession

    var body: some View {
        HStack(spacing: 12) {
            Text("Shape".localized).font(ToolHeaderStyle.titleFont)
            Picker("Shape".localized, selection: Binding(get: { session.shapeKind }, set: { kind in
                session.cancelShape()
                session.shapeKind = kind
            })) {
                ForEach(ShapeKind.allCases, id: \.self) { Text($0.rawValue.localized).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()
            .help("Shift-U switches between Rectangle and Ellipse".localized)
            if session.shapeKind == .rectangle {
                HStack(spacing: 6) {
                    Text("Radius".localized)
                    Slider(value: Binding(get: { min(200, session.shapeCornerRadius) },
                                          set: { session.shapeCornerRadius = $0.rounded() }), in: 0...200)
                        .frame(width: 100)
                    TextField("Radius".localized, value: Binding(get: { session.shapeCornerRadius },
                                                       set: { session.shapeCornerRadius = $0.isFinite ? min(5000, max(0, $0)) : 0 }),
                              format: .number.precision(.fractionLength(0)))
                        .frame(width: 48).textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing)
                        .arrowSteps(value: { Double(session.shapeCornerRadius) },
                                    change: { session.shapeCornerRadius = min(5000, max(0, CGFloat($0))) })
                        .unitSuffix("px".localized)
                }
                .help("Round the rectangle's corners by this many pixels; 0 keeps them square".localized)
            }
            HStack(spacing: 6) {
                Text("Fill".localized)
                Button { session.openColorPicker(background: false) } label: {
                    let swatch = RoundedRectangle(cornerRadius: 3, style: .continuous)
                    swatch.fill(Color(nsColor: session.foregroundColor.nsColor))
                        .overlay { swatch.strokeBorder(.black.opacity(0.5), lineWidth: 1) }
                        .frame(width: 36, height: 18)
                }
                .buttonStyle(.plain)
                .help("Shapes fill with the foreground color; click to change it".localized)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18).toolHeaderBar().releasesFocusOnCommit(session)
        .disabled(session.showsBusy || session.document == nil)
    }
}
