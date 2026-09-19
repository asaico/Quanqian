import SwiftUI

struct HistoryPanel: View {
    @Bindable var session: EditorSession
    var isFloating: Bool = false
    var showHeader: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶栏：标题与操作
            if showHeader {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath").font(.system(size: 11)).foregroundStyle(.secondary)
                    Text("History".localized)
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Button {
                        session.undo()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .disabled(!session.canUndo)
                    .help("Undo (⌘Z)".localized)

                    Button {
                        session.redo()
                    } label: {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .disabled(!session.canRedo)
                    .help("Redo (⇧⌘Z)".localized)

                    PanelHeaderOptionsMenu(session: session, panel: .history)
                }
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Color(white: 0.12))

                Divider()
            }

            // 步骤列表
            let steps = session.history.allSteps
            if steps.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("No history yet".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(steps) { step in
                                HistoryStepRow(step: step) {
                                    session.jumpToHistory(step: step)
                                }
                                .id(step.id)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onAppear {
                        if let current = steps.first(where: { $0.isCurrent }) {
                            proxy.scrollTo(current.id, anchor: .center)
                        }
                    }
                    .onChange(of: session.history.undoCount) { _, _ in
                        if let current = session.history.allSteps.first(where: { $0.isCurrent }) {
                            proxy.scrollTo(current.id, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(width: isFloating ? 260 : nil, height: isFloating ? 360 : nil)
        .frame(maxWidth: isFloating ? nil : .infinity, maxHeight: isFloating ? nil : .infinity)
        .background(Color(white: 0.14))
    }
}

private struct HistoryStepRow: View {
    let step: DocumentHistory.HistoryStep
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                // 图标
                Group {
                    if step.targetPastCount == 0 {
                        Image(systemName: "photo")
                            .foregroundStyle(Color.secondary)
                            .opacity(step.isFuture ? 0.4 : 1.0)
                    } else if step.isCurrent {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    } else if step.isFuture {
                        Image(systemName: "circle.dotted")
                            .foregroundStyle(Color.secondary.opacity(0.4))
                    } else {
                        Image(systemName: "arrow.right.circle")
                            .foregroundStyle(Color.secondary)
                    }
                }
                .font(.system(size: 11))
                .frame(width: 14)

                // 步骤名称
                Text(step.name)
                    .font(.system(size: 12, weight: step.isCurrent ? .semibold : .regular))
                    .foregroundStyle(Color.primary)
                    .opacity(step.isFuture ? 0.45 : 1.0)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(step.isCurrent ? Color.accentColor.opacity(0.18) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
    }
}
