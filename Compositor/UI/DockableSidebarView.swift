import SwiftUI

/// 通用面板选项菜单（支持在左侧/右侧边栏、上中下分区、浮动窗口间自由切换与关闭）
struct PanelHeaderOptionsMenu: View {
    @Bindable var session: EditorSession
    let panel: DockablePanelKind

    var body: some View {
        Menu {
            let currentLoc: PanelDockLocation = {
                switch panel {
                case .layers: return session.layersDockLocation
                case .character: return session.characterDockLocation
                case .history: return session.historyDockLocation
                }
            }()
            let currentSection = session.section(for: panel)

            // 分区切换（上、中、下）
            if currentLoc != .floating {
                Section {
                    if currentSection != .top {
                        Button {
                            session.setDockLocation(currentLoc, section: .top, for: panel)
                        } label: {
                            Label("Move to Top Section".localized, systemImage: "arrow.up.to.line")
                        }
                    }
                    if currentSection != .middle {
                        Button {
                            session.setDockLocation(currentLoc, section: .middle, for: panel)
                        } label: {
                            Label("Move to Middle Section".localized, systemImage: "rectangle.split.3x1")
                        }
                    }
                    if currentSection != .bottom {
                        Button {
                            session.setDockLocation(currentLoc, section: .bottom, for: panel)
                        } label: {
                            Label("Move to Bottom Section".localized, systemImage: "arrow.down.to.line")
                        }
                    }
                }
            }

            // 侧栏与浮动窗口切换
            Section {
                if currentLoc != .rightSidebar {
                    Button {
                        session.setDockLocation(.rightSidebar, section: currentSection, for: panel)
                    } label: {
                        Label("Move to Right Sidebar".localized, systemImage: "sidebar.right")
                    }
                }

                if currentLoc != .leftSidebar {
                    Button {
                        session.setDockLocation(.leftSidebar, section: currentSection, for: panel)
                    } label: {
                        Label("Move to Left Sidebar".localized, systemImage: "sidebar.left")
                    }
                }

                if currentLoc != .floating {
                    Button {
                        session.setDockLocation(.floating, for: panel)
                    } label: {
                        Label("Pop out to Window".localized, systemImage: "macwindow.on.rectangle")
                    }
                }
            }

            Divider()

            Button(role: .destructive) {
                session.closePanel(panel)
            } label: {
                Label("Close Panel".localized, systemImage: "xmark")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Panel Options".localized)
    }
}

/// 侧边栏单个分区视图（支持该分区内的多面板 Tab 切换）
struct SidebarSectionView: View {
    @Bindable var session: EditorSession
    let location: PanelDockLocation
    let section: SidebarSection

    private var panels: [DockablePanelKind] {
        session.panels(in: location, section: section)
    }

    private var activeTab: DockablePanelKind {
        session.activeTab(for: location, section: section)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if panels.count > 1 {
                // 分区顶部的选项卡切换栏
                HStack(spacing: 2) {
                    ForEach(panels) { panel in
                        Button {
                            session.setActiveTab(panel, for: location, section: section)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: panel.iconName)
                                    .font(.system(size: 11))
                                Text(panel.shortTitle)
                                    .font(.system(size: 11, weight: activeTab == panel ? .semibold : .regular))
                            }
                            .padding(.horizontal, 8)
                            .frame(height: 22)
                            .background(activeTab == panel ? Color.white.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 4))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(activeTab == panel ? .primary : .secondary)
                    }

                    Spacer()

                    PanelHeaderOptionsMenu(session: session, panel: activeTab)
                }
                .padding(.horizontal, 8)
                .frame(height: 32)
                .background(Color(white: 0.12))

                Divider()

                renderPanel(activeTab, showHeader: false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if let single = panels.first {
                // 只有一个面板时直接渲染该面板
                renderPanel(single, showHeader: true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private func renderPanel(_ panel: DockablePanelKind, showHeader: Bool) -> some View {
        switch panel {
        case .layers:
            LayersPanel(session: session, width: nil, showHeader: showHeader)
        case .character:
            CharacterParagraphPanel(session: session, isFloating: false, showHeader: showHeader)
        case .history:
            HistoryPanel(session: session, isFloating: false, showHeader: showHeader)
        }
    }
}

/// 支持「上、中、下」三分区及多面板自由停靠的侧边栏容器
struct DockableSidebarView: View {
    @Bindable var session: EditorSession
    let location: PanelDockLocation
    let width: CGFloat

    private var activeSections: [SidebarSection] {
        session.activeSections(in: location)
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(activeSections.enumerated()), id: \.element) { index, section in
                SidebarSectionView(session: session, location: location, section: section)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if index < activeSections.count - 1 {
                    Divider()
                }
            }
        }
        .frame(width: width)
        .background(Color(white: 0.14))
    }
}
