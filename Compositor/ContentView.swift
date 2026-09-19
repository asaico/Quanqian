import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    /// The Layers/Right sidebar panel's width, remembered across launches.
    @AppStorage("layersPanelWidth") private var rightSidebarWidth = 252.0
    @AppStorage("leftSidebarWidth") private var leftSidebarWidth = 252.0
    @Bindable var session: EditorSession
    var applicationDelegate: CompositorApplicationDelegate? = nil
    @ObservedObject private var localization = LocalizationManager.shared
    @Environment(\.openWindow) private var openWindow
    @State private var canvasFrame: CGRect = .zero
    @State private var levelsPanel = FloatingPanelController(name: "levelsPanel")
    @State private var adjustmentPanel = FloatingPanelController(name: "adjustmentPanel")
    @State private var filterPanel = FloatingPanelController(name: "filterPanel")
    @State private var characterPanel = FloatingPanelController(name: "characterPanel")
    @State private var historyPanel = FloatingPanelController(name: "historyPanel")
    @State private var isDropTargeted = false
    /// The window's width, so the tab strip can use the toolbar's free space.
    @State private var windowWidth: CGFloat = 1180
    /// A layer dragged from this canvas's own tab has nowhere to go, so the canvas doesn't light up for it.
    private var acceptsDrop: Bool {
        guard let workspace = applicationDelegate?.workspace else { return true }
        return workspace.canReceiveDrag(into: workspace.current.id)
    }
    var body: some View {
        VStack(spacing: 0) {
            if session.tool == .move {
                TransformInspector(session: session).id(session.activeLayerID)
                Divider()
            }
            if session.tool.isBrushTool {
                BrushControls(session: session)
                Divider()
            }
            if session.tool.isSelectionTool {
                LassoControls(session: session)
                Divider()
            }
            if session.tool == .gradient {
                if session.gradientSubTool == .paintBucket {
                    PaintBucketControls(session: session)
                } else {
                    GradientControls(session: session)
                }
                Divider()
            }
            if session.tool == .text {
                TextToolControls(session: session)
                Divider()
            }
            if session.tool == .shape {
                ShapeControls(session: session)
                Divider()
            }
            if session.tool == .eyedropper {
                HStack(spacing: 16) {
                    Text("Eyedropper".localized).font(ToolHeaderStyle.titleFont)
                    Toggle("Sample Ring".localized, isOn: $session.showsSampleRing).toggleStyle(.checkbox)
                    Spacer()
                }.padding(.horizontal, 18).toolHeaderBar()
                Divider()
            }
            if session.tool == .hand || session.tool == .zoom {
                NavigationToolHeader(session: session)
                Divider()
            }
            if session.tool == .crop {
                CropControls(session: session)
                Divider()
            }
            // No tool (A) keeps the header, so the canvas doesn't jump.
            if session.tool == .idle {
                HStack(spacing: 16) {
                    Text("Select a tool".localized).font(ToolHeaderStyle.titleFont)
                    Spacer()
                }.padding(.horizontal, 18).toolHeaderBar()
                Divider()
            }
            HStack(spacing: 0) {
                toolRail
                Divider()
                if session.showsLeftSidebar {
                    DockableSidebarView(session: session, location: .leftSidebar, width: leftSidebarWidth)
                    PanelResizeEdge(width: $leftSidebarWidth, range: LayersPanel.widths, isLeading: false)
                }
                ZStack(alignment: .topLeading) {
                    EditorCanvas(session: session)
                    if session.document == nil { welcome }
                    if session.isEditingTextOnCanvas, let active = session.activeLayer, active.liveText != nil {
                        OnCanvasTextEditor(session: session, layer: active)
                    }
                }
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named("editor")) } action: { canvasFrame = $0 }
                if session.showsRightSidebar {
                    PanelResizeEdge(width: $rightSidebarWidth, range: LayersPanel.widths, isLeading: true)
                    DockableSidebarView(session: session, location: .rightSidebar, width: rightSidebarWidth)
                }
            }
            Divider()
            // Keeps its own height however short the window gets; the tools scroll instead.
            statusBar.fixedSize(horizontal: false, vertical: true)
                .modifier(WidthReader(width: $windowWidth))
        }
        .background(Color(white: 0.14))
        .background {
            if let applicationDelegate, applicationDelegate.projects.workspace == nil {
                ProjectWindowBridge(controller: applicationDelegate.projects).frame(width: 0, height: 0)
            }
        }
        .frame(minWidth: 800, minHeight: 520)
        .coordinateSpace(name: "editor")
        .onDrop(of: [UTType.fileURL.identifier, UTType.image.identifier, ProjectWorkspace.layerType], isTargeted: $isDropTargeted) { providers, location in
            handleDrop(providers: providers, location: location)
        }
        .overlay {
            if isDropTargeted, acceptsDrop {
                RoundedRectangle(cornerRadius: 8).strokeBorder(Color.accentColor, lineWidth: 3)
                    .frame(width: max(0, canvasFrame.width - 6), height: max(0, canvasFrame.height - 6))
                    .position(x: canvasFrame.midX, y: canvasFrame.midY)
                    .allowsHitTesting(false)
            }
        }
        .onAppear { applicationDelegate?.showEditor = { openWindow(id: "editor") } }
        .preferredColorScheme(.dark)
        .navigationTitle(session.projectURL?.deletingPathExtension().lastPathComponent ?? "Untitled".localized)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { requestNewCanvas() } label: { Label("New canvas".localized, systemImage: "plus") }
                    .help("New canvas (⌘N)".localized).accessibilityIdentifier("newCanvasToolbar")
                    .disabled(session.isImporting || session.showsBusy || session.levels != nil)
                    .modifier(NewProjectDropTarget(workspace: applicationDelegate?.workspace))
            }
            ToolbarSpacer(.fixed, placement: .navigation)
            if let workspace = applicationDelegate?.workspace {
                ToolbarItem(placement: .navigation) {
                    ProjectTabStrip(workspace: workspace, maxAvailableWidth: max(200, windowWidth - 352))
                }
                .sharedBackgroundVisibility(.hidden)
            }
            // Absorb all remaining navigation-toolbar width before the zoom controls.
            // Without this spacer, the growing tab strip pushes the primary actions left.
            ToolbarSpacer(.flexible, placement: .navigation)
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Fit".localized) { session.fit() }.help("Fit canvas in window (⌘0)".localized)
                    .accessibilityIdentifier("fitCanvas").disabled(session.document == nil)
                Button("100%".localized) { session.zoom(to: 1) }.help("Actual pixels (⌘1)".localized)
                    .accessibilityIdentifier("actualPixels").disabled(session.document == nil)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button { session.zoom(to: session.viewport.zoom * 1.25) } label: {
                    Image(systemName: "plus.magnifyingglass")
                }.help("Zoom in (⌘+)".localized).disabled(session.document == nil)
                Button { session.zoom(to: session.viewport.zoom / 1.25) } label: {
                    Image(systemName: "minus.magnifyingglass")
                }.help("Zoom out (⌘−)".localized).disabled(session.document == nil)
            }
        }
        .modifier(FloatingPanelsModifier(
            session: session,
            levelsPanel: levelsPanel,
            adjustmentPanel: adjustmentPanel,
            filterPanel: filterPanel,
            characterPanel: characterPanel,
            historyPanel: historyPanel
        ))
        .onChange(of: session.document == nil) { _, empty in
            if !empty { session.canvasFocusRequest += 1 }
        }
        .fileImporter(isPresented: $session.showsImporter,
                      allowedContentTypes: [.jpeg, .png, .heic, .tiff], allowsMultipleSelection: true) { result in
            handleImportResult(result)
        }
        .modifier(ErrorAlertsModifier(session: session))
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task { await session.importImages(urls) }
        case .failure(let error):
            if (error as NSError).code != NSUserCancelledError {
                session.importError = error.localizedDescription
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider], location: CGPoint) -> Bool {
        guard session.levels == nil, !session.isProjectBusy, !session.showsNewDocument, !session.showsImporter, session.renamingLayerID == nil else { return false }
        let point: CGPoint?
        if let document = session.document, canvasFrame.contains(location) {
            point = session.viewport.documentPoint(
                from: CGPoint(x: location.x - canvasFrame.minX, y: location.y - canvasFrame.minY),
                documentSize: document.size)
        } else { point = nil }
        if let workspace = applicationDelegate?.workspace {
            let destination = workspace.current.id
            guard workspace.canSwitch, workspace.canReceiveDrag(into: destination) else { return false }
            Task { await workspace.receiveProviders(providers, into: destination, at: point) }
        } else {
            Task { await ImageFileDrop.importProviders(providers, into: session, at: point) }
        }
        return true
    }

    private func requestNewCanvas() {
        if let applicationDelegate { Task { await applicationDelegate.projects.newCanvas() } }
        else { session.clearProject() }
    }
    private var toolRail: some View {
        // Scrolls when the window is too short for every tool, rather than pushing the bars above and below away.
        ScrollView(.vertical) {
        VStack(spacing: 10) {
            ForEach(NavigationTool.allCases.filter { $0 != .idle }, id: \.self) { tool in
                Button { session.selectTool(tool) } label: {
                    Group {
                        if tool == .gradient {
                            if session.gradientSubTool == .paintBucket {
                                Image(systemName: "drop.triangle.fill").font(.system(size: 16))
                            } else {
                                GradientToolIcon().frame(width: 18, height: 18)
                            }
                        }
                        else if tool == .cloneStamp { CloneStampToolIcon().frame(width: 18, height: 18) }
                        else if tool == .lasso, session.lassoKind == .polygonal { PolygonalLassoToolIcon().frame(width: 18, height: 18) }
                        else if tool == .text {
                            Image(systemName: session.textToolOrientation == .vertical ? "textformat.size" : "character.textbox").font(.system(size: 16))
                        }
                        else if tool == .brush && session.brushMode == .erase {
                            Image(systemName: "eraser").font(.system(size: 16))
                        }
                        // The Marquee's icon follows its shape: a dashed circle in Ellipse mode.
                        else { Image(systemName: tool == .marquee && session.marqueeKind == .ellipse ? "circle.dashed" : session.symbol(for: tool)).font(.system(size: 17)) }
                    }
                    .frame(width: 36, height: 36)
                        .background(session.tool == tool ? Color.white.opacity(0.12) : .clear,
                                    in: RoundedRectangle(cornerRadius: 7))
                        .overlay {
                            RoundedRectangle(cornerRadius: 7)
                                .strokeBorder(session.tool == tool ? Color.white.opacity(0.14) : .clear)
                        }
                        .overlay(alignment: .bottomTrailing) {
                            if hasSubTools(tool) {
                                ToolDisclosureTriangle().padding(3)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).help(toolHelpText(tool)).accessibilityLabel(tool.label)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(session.tool == tool ? .isSelected : [])
                .contextMenu {
                    subToolContextMenu(for: tool)
                }
            }
            VStack(spacing: 6) {
                Button {
                    session.togglePanel(.character)
                } label: {
                    Image(systemName: "character")
                        .font(.system(size: 15))
                        .frame(width: 32, height: 32)
                        .background(session.showsCharacterPanel ? Color.accentColor.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 6))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(session.showsCharacterPanel ? Color.accentColor.opacity(0.4) : .clear)
                        }
                }
                .buttonStyle(.plain)
                .help("Character & Paragraph".localized)

                Button {
                    session.togglePanel(.history)
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 15))
                        .frame(width: 32, height: 32)
                        .background(session.showsHistoryPanel ? Color.accentColor.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 6))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(session.showsHistoryPanel ? Color.accentColor.opacity(0.4) : .clear)
                        }
                }
                .buttonStyle(.plain)
                .help("History".localized)
            }
            .padding(.top, 4)

            ColorPaletteControls(session: session).padding(.top, 4)
        }
        .padding(.top, 16).padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
        // Only scrolls (and bounces) when the tools don't all fit.
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .frame(width: 56)
    }

    private func hasSubTools(_ tool: NavigationTool) -> Bool {
        switch tool {
        case .gradient, .marquee, .lasso, .brush, .text, .shape: return true
        default: return false
        }
    }

    private func toolHelpText(_ tool: NavigationTool) -> String {
        if tool == .gradient {
            return session.gradientSubTool == .paintBucket ? "Paint Bucket Tool (G)".localized : "Gradient Tool (G)".localized
        }
        if tool == .text {
            return session.textToolOrientation == .vertical ? "Vertical Type Tool (T)".localized : "Horizontal Type Tool (T)".localized
        }
        if tool == .brush && session.brushMode == .erase {
            return "Eraser Tool (E)".localized
        }
        return tool.label
    }

    @ViewBuilder
    private func subToolContextMenu(for tool: NavigationTool) -> some View {
        switch tool {
        case .gradient:
            Button {
                session.selectTool(.gradient)
                session.gradientSubTool = .gradient
            } label: {
                HStack {
                    Text("Gradient Tool (G)".localized)
                    if session.gradientSubTool == .gradient { Image(systemName: "checkmark") }
                }
            }
            Button {
                session.selectTool(.gradient)
                session.gradientSubTool = .paintBucket
            } label: {
                HStack {
                    Text("Paint Bucket Tool (G)".localized)
                    if session.gradientSubTool == .paintBucket { Image(systemName: "checkmark") }
                }
            }
        case .marquee:
            Button {
                session.selectTool(.marquee)
                session.marqueeKind = .rectangle
            } label: {
                HStack {
                    Text("Rectangular Marquee Tool (M)".localized)
                    if session.marqueeKind == .rectangle { Image(systemName: "checkmark") }
                }
            }
            Button {
                session.selectTool(.marquee)
                session.marqueeKind = .ellipse
            } label: {
                HStack {
                    Text("Elliptical Marquee Tool (M)".localized)
                    if session.marqueeKind == .ellipse { Image(systemName: "checkmark") }
                }
            }
        case .lasso:
            Button {
                session.selectTool(.lasso)
                session.lassoKind = .freehand
            } label: {
                HStack {
                    Text("Lasso Tool (L)".localized)
                    if session.lassoKind == .freehand { Image(systemName: "checkmark") }
                }
            }
            Button {
                session.selectTool(.lasso)
                session.lassoKind = .polygonal
            } label: {
                HStack {
                    Text("Polygonal Lasso Tool (L)".localized)
                    if session.lassoKind == .polygonal { Image(systemName: "checkmark") }
                }
            }
        case .brush:
            Button {
                session.selectTool(.brush)
                session.brushMode = .paint
            } label: {
                HStack {
                    Text("Brush Tool (B)".localized)
                    if session.brushMode == .paint { Image(systemName: "checkmark") }
                }
            }
            Button {
                session.selectTool(.brush)
                session.brushMode = .erase
            } label: {
                HStack {
                    Text("Eraser Tool (E)".localized)
                    if session.brushMode == .erase { Image(systemName: "checkmark") }
                }
            }
        case .text:
            Button {
                session.selectTool(.text)
                session.textToolOrientation = .horizontal
            } label: {
                HStack {
                    Text("Horizontal Type Tool (T)".localized)
                    if session.textToolOrientation == .horizontal { Image(systemName: "checkmark") }
                }
            }
            Button {
                session.selectTool(.text)
                session.textToolOrientation = .vertical
            } label: {
                HStack {
                    Text("Vertical Type Tool (T)".localized)
                    if session.textToolOrientation == .vertical { Image(systemName: "checkmark") }
                }
            }
        case .shape:
            Button {
                session.selectTool(.shape)
                session.shapeKind = .rectangle
            } label: {
                HStack {
                    Text("Rectangle Tool (U)".localized)
                    if session.shapeKind == .rectangle { Image(systemName: "checkmark") }
                }
            }
            Button {
                session.selectTool(.shape)
                session.shapeKind = .ellipse
            } label: {
                HStack {
                    Text("Ellipse Tool (U)".localized)
                    if session.shapeKind == .ellipse { Image(systemName: "checkmark") }
                }
            }
        default:
            EmptyView()
        }
    }
    private var welcome: some View {
        NewCanvasSheet(session: session,
            onCreate: { session.createNewProject(width: $0, height: $1) },
            onOpen: { Task { await applicationDelegate?.projects.open() } })
    }
    private var statusBar: some View {
        HStack(spacing: 16) {
            if let document = session.document {
                Text(session.viewport.zoom, format: .percent.precision(.fractionLength(0...1)))
                    .frame(width: 62, alignment: .leading).accessibilityIdentifier("zoomStatus")
                Text("\(document.width) × \(document.height) px").accessibilityIdentifier("canvasDimensions")
                Text("sRGB · Transparent".localized)
            } else { Text("Ready when you are".localized) }
            Spacer()
            if session.showsBusy {
                ProgressView().controlSize(.mini)
                Text("Working…".localized)
            } else if session.isImporting {
                ProgressView().controlSize(.mini)
                Text("Importing images…".localized)
            } else {
                Text(toolStatusHint)
            }
        }
        .font(.system(size: 11).monospacedDigit()).foregroundStyle(.secondary)
        .padding(.horizontal, 18).frame(height: 30)
        .accessibilityElement(children: .contain)
    }

    private var toolStatusHint: String {
        if LocalizationManager.shared.isChinese {
            switch session.tool {
            case .marquee:
                return session.marqueeKind == .ellipse
                    ? "拖动绘制椭圆 · Shift 添加 · Option 减去 · 拖动中按 Shift 绘制正圆 · 内部拖动移动 · Delete 清除 · ⌘D 取消选择"
                    : "拖动绘制矩形 · Shift 添加 · Option 减去 · 拖动中按 Shift 绘制正方形 · 内部拖动移动 · ⌘拖动移动像素 · Delete 清除 · ⌘D 取消选择"
            case .wand:
                return "单击选择相似颜色 · Shift 添加 · Option 减去 · 内部拖动移动 · ⌘拖动移动像素 · Delete 清除 · ⌘D 取消选择"
            case .lasso:
                return session.lassoKind == .freehand
                    ? "拖动绘制选区 · 内部拖动移动 · Shift 添加 · Option 减去 · Delete 清除 · ⌥⌫/⌘⌫ 填充 · ⌘D 取消选择"
                    : "单击定点 · 单击起点、双击或回车闭合 · Delete 移除定点 · Escape 取消"
            case .brush:
                let action = session.brushMode == .erase ? "拖动擦除" : "拖动绘制"
                return "\(action) · [ ] 粗细 · Shift-[ ] 硬度 · 1–0 不透明度 · Escape 取消 · 空格键平移"
            case .blur:
                let action = session.blurMode == .blur ? "拖动柔化" : session.blurMode == .smudge ? "拖动涂抹" : "拖动推移像素"
                return "\(action) · [ ] 粗细 · Shift-[ ] 硬度 · 1–0 强度 · 空格键平移"
            case .cloneStamp:
                return "按住 Option 单击拾取源 · 拖动仿制 · [ ] 粗细 · Shift-[ ] 硬度 · 1–0 不透明度 · 空格键平移"
            case .spotHealing:
                return "拖过污点以修复 · [ ] 粗细 · Shift-[ ] 硬度 · Escape 取消 · 空格键平移"
            case .text:
                return "单击画布新建文字图层 · 双击已有文字就地编辑 · ⇧T 切换横竖排 · 空格键平移"
            case .shape:
                let kind = session.shapeKind == .rectangle ? "正方形" : "正圆"
                let switchKind = session.shapeKind == .rectangle ? "椭圆" : "矩形"
                return "拖动在新建图层绘制形状 · Shift \(kind) · Option 从中心 · Shift-U \(switchKind) · Escape 取消 · 空格键平移"
            case .gradient:
                return "拖动绘制渐变 · 拖动端点调整 · Shift 45° · 1–0 不透明度 · 回车应用 · Escape 取消"
            case .crop:
                return "拖动裁剪框 · 回车应用 · Escape 取消 · 空格键平移"
            case .move:
                return "拖动移动 · 控点调整大小 · 圆圈旋转 · 1–0 图层不透明度 · 空格键平移"
            case .hand:
                return "拖动平移 · 双指捏合缩放"
            case .idle:
                return "未选择工具 · 按工具快捷键选取 · 空格键平移"
            case .eyedropper:
                return "单击吸管拾取颜色 · 空格键平移"
            case .zoom:
                return "单击放大 · Option 单击缩小 · 左右拖动平滑缩放 · 空格键平移"
            }
        } else {
            return session.tool == .marquee ? (session.marqueeKind == .ellipse ? "Drag an ellipse · Shift add · Option subtract · Shift again mid-drag circle · Drag inside to move · Delete clears · ⌘D deselect" : "Drag a rectangle · Shift add · Option subtract · Shift again mid-drag square · Drag inside to move · ⌘-drag moves pixels · Delete clears · ⌘D deselect") : session.tool == .wand ? "Click to select similar colors · Shift add · Option subtract · Drag inside to move · ⌘-drag moves pixels · Delete clears · ⌘D deselect" : session.tool == .lasso ? (session.lassoKind == .freehand ? "Drag to select · Drag inside to move · Shift add · Option subtract · Delete clears · ⌥⌫/⌘⌫ fill · ⌘D deselect" : "Click corners · Click start, double-click or Enter to close · Delete removes corner · Escape cancel") : session.tool == .brush ? (session.brushMode == .erase ? "Drag to erase" : "Drag to paint") + " · [ ] size · Shift-[ ] hardness · 1–0 opacity · Escape cancel · Space to pan" : session.tool == .blur ? (session.blurMode == .blur ? "Drag to soften" : session.blurMode == .smudge ? "Drag to smudge" : "Drag to push pixels") + " · [ ] size · Shift-[ ] hardness · 1–0 strength · Space to pan" : session.tool == .cloneStamp ? "Option-click to set the source · Drag to clone · [ ] size · Shift-[ ] hardness · 1–0 opacity · Space to pan" : session.tool == .spotHealing ? "Drag over blemishes to heal · [ ] size · Shift-[ ] hardness · Escape cancel · Space to pan" : session.tool == .text ? "Click canvas to add text · Double-click text to edit · Shift-T switches orientation · Space to pan" : session.tool == .shape ? "Drag to draw a shape on a new layer · Shift \(session.shapeKind == .rectangle ? "square" : "circle") · Option from center · Shift-U \(session.shapeKind == .rectangle ? "ellipse" : "rectangle") · Escape cancel · Space to pan" : session.tool == .gradient ? "Drag to draw · Drag ends to adjust · Shift 45° · 1–0 opacity · Enter apply · Escape cancel" : session.tool == .crop ? "Drag to crop · Enter apply · Escape cancel · Space to pan" : session.tool == .move ? "Drag to move · Handles to resize · Circle to rotate · 1–0 layer opacity · Space to pan" : session.tool == .hand ? "Drag to pan · Pinch to zoom" : session.tool == .idle ? "No tool selected · Press a tool's key to pick one · Space to pan" : "Click to zoom in · Option-click to zoom out · Drag right or left to zoom smoothly · Space to pan"
        }
    }
}

/// A panel's divider that resizes the panel to its left or right: drag within `range`.
private struct PanelResizeEdge: View {
    @Binding var width: Double
    let range: ClosedRange<Double>
    var isLeading: Bool = true
    @State private var startWidth: Double?

    var body: some View {
        Divider().overlay {
            Color.clear.frame(width: 8).contentShape(Rectangle())
                .pointerStyle(.columnResize)
                .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        let start = startWidth ?? width
                        startWidth = start
                        let delta = isLeading ? -value.translation.width : value.translation.width
                        width = min(range.upperBound, max(range.lowerBound, (start + delta).rounded()))
                    }
                    .onEnded { _ in startWidth = nil })
                .help("Drag to resize the panel".localized)
        }
    }
}

extension View {
    /// Bordered buttons and pop-up menus drawn as capsules throughout the app. Borderless and plain buttons (the tool
    /// rail, the Layers panel footer) have no border to shape, so they're unaffected.
    func roundedControls() -> some View { buttonBorderShape(.capsule) }
}

extension View {
    /// Return or Escape in a property field gives up its focus and hands it back to the canvas, so a tool's key
    /// works straight away instead of typing into the field.
    func releasesFocusOnCommit(_ session: EditorSession) -> some View {
        onSubmit { session.canvasFocusRequest += 1 }
            .onExitCommand { session.canvasFocusRequest += 1 }
    }
}

/// What a field's key monitor reads. The monitor outlives the view value that installed it, so reading the value
/// and applying the step go through here, refreshed on every redraw.
@MainActor final class ArrowStepper {
    var editing = false
    var value: () -> Double = { 0 }
    var change: (Double) -> Void = { _ in }
    private var monitor: Any?

    /// Takes Up and Down while the field holds focus: one step, or ten with Shift.
    func listen(step: Double) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.editing, event.keyCode == 126 || event.keyCode == 125 else { return event }
            let amount = step * (event.modifierFlags.contains(.shift) ? 10 : 1)
            self.change(self.value() + (event.keyCode == 126 ? amount : -amount))
            return nil
        }
    }
    func stopListening() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        editing = false
    }
    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }
}

/// Up and Down nudge the value in a focused property field, Shift by ten times as much — a text field takes the
/// arrow keys for its insertion point, so they are caught while it holds focus.
private struct ArrowStepping: ViewModifier {
    let step: Double
    let value: () -> Double
    let change: (Double) -> Void
    @FocusState private var focused: Bool
    @State private var stepper = ArrowStepper()
    func body(content: Content) -> some View {
        content
            .focused($focused)
            .onChange(of: focused) { _, editing in
                stepper.editing = editing
                editing ? stepper.listen(step: step) : stepper.stopListening()
            }
            .onDisappear { stepper.stopListening() }
            .onAppear { refresh() }
            .onChange(of: value()) { _, _ in refresh() }
    }
    private func refresh() {
        stepper.value = value
        stepper.change = change
    }
}

extension View {
    /// Up and Down step this field's value; each field's own binding keeps it in range.
    func arrowSteps(_ step: Double = 1, value: @escaping () -> Double, change: @escaping (Double) -> Void) -> some View {
        modifier(ArrowStepping(step: step, value: value, change: change))
    }
    /// The same, for a field that already owns its focus: it says when it is being edited.
    func arrowSteps(_ step: Double = 1, editing: Bool, stepper: ArrowStepper,
                    value: @escaping () -> Double, change: @escaping (Double) -> Void) -> some View {
        onAppear { stepper.value = value; stepper.change = change }
            .onChange(of: value()) { _, _ in stepper.value = value; stepper.change = change }
            .onChange(of: editing) { _, active in
                stepper.editing = active
                stepper.value = value
                stepper.change = change
                active ? stepper.listen(step: step) : stepper.stopListening()
            }
            .onDisappear { stepper.stopListening() }
    }
}

/// Reports the width it is laid out at. Kept out of the editor's body, whose type-checking is already near its limit.
private struct WidthReader: ViewModifier {
    @Binding var width: CGFloat
    func body(content: Content) -> some View {
        content.onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}

private struct FloatingPanelsModifier: ViewModifier {
    @Bindable var session: EditorSession
    var levelsPanel: FloatingPanelController
    var adjustmentPanel: FloatingPanelController
    var filterPanel: FloatingPanelController
    var characterPanel: FloatingPanelController
    var historyPanel: FloatingPanelController

    func body(content: Content) -> some View {
        content
            .onChange(of: session.levels == nil) { _, closed in
                if closed { levelsPanel.close() }
                else {
                    levelsPanel.onClose = { session.cancelLevels() }
                    levelsPanel.show(title: "Levels".localized, content: LevelsSheet(session: session))
                }
            }
            .onChange(of: session.hueSaturation == nil) { _, closed in
                if closed { adjustmentPanel.close() }
                else {
                    adjustmentPanel.onClose = { session.cancelHueSaturation() }
                    adjustmentPanel.show(title: "Hue/Saturation".localized, content: HueSaturationSheet(session: session))
                }
            }
            .onChange(of: session.filterEdit == nil) { _, closed in
                if closed { filterPanel.close() }
                else {
                    filterPanel.onClose = { session.cancelFilter() }
                    filterPanel.show(title: session.filterEdit?.kind.rawValue.localized ?? "Filter".localized, content: FilterSheet(session: session))
                }
            }
            .onChange(of: session.showsCharacterPanel && session.characterDockLocation == .floating) { _, isFloating in
                if !isFloating { characterPanel.close() }
                else {
                    characterPanel.onClose = { session.showsCharacterPanel = false }
                    characterPanel.show(title: "Character & Paragraph".localized, content: CharacterParagraphPanel(session: session, isFloating: true))
                }
            }
            .onChange(of: session.characterDockLocation) { _, loc in
                if loc != .floating { characterPanel.close() }
                else if session.showsCharacterPanel {
                    characterPanel.onClose = { session.showsCharacterPanel = false }
                    characterPanel.show(title: "Character & Paragraph".localized, content: CharacterParagraphPanel(session: session, isFloating: true))
                }
            }
            .onChange(of: session.showsHistoryPanel && session.historyDockLocation == .floating) { _, isFloating in
                if !isFloating { historyPanel.close() }
                else {
                    historyPanel.onClose = { session.showsHistoryPanel = false }
                    historyPanel.show(title: "History".localized, content: HistoryPanel(session: session, isFloating: true))
                }
            }
            .onChange(of: session.historyDockLocation) { _, loc in
                if loc != .floating { historyPanel.close() }
                else if session.showsHistoryPanel {
                    historyPanel.onClose = { session.showsHistoryPanel = false }
                    historyPanel.show(title: "History".localized, content: HistoryPanel(session: session, isFloating: true))
                }
            }
    }
}

private struct ErrorAlertsModifier: ViewModifier {
    @Bindable var session: EditorSession

    func body(content: Content) -> some View {
        content
            .alert("Import couldn’t finish".localized, isPresented: Binding(
                get: { session.importError != nil },
                set: { if !$0 { session.importError = nil } }
            )) {
                Button("OK".localized, role: .cancel) { session.importError = nil }
            } message: {
                Text(session.importError ?? "")
            }
            .alert("Couldn’t paint".localized, isPresented: Binding(
                get: { session.brushError != nil },
                set: { if !$0 { session.brushError = nil } }
            )) {
                Button("OK".localized) { session.brushError = nil }
            } message: {
                Text(session.brushError ?? "")
            }
            .alert("Couldn’t crop".localized, isPresented: Binding(
                get: { session.cropError != nil },
                set: { if !$0 { session.cropError = nil } }
            )) {
                Button("OK".localized) { session.cropError = nil }
            } message: {
                Text(session.cropError ?? "")
            }
    }
}

struct ToolDisclosureTriangle: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: size.width, y: 0))
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()
            context.fill(path, with: .color(.white.opacity(0.55)))
        }
        .frame(width: 5, height: 5)
    }
}


