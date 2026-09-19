import Foundation
import CoreGraphics
import Observation

/// Value snapshots share immutable CGImages; no pixel copies for layer edits.
@Observable
final class DocumentHistory {
    struct Snapshot {
        let document: CanvasDocument?
        let activeLayerID: UUID?
        let revision: UUID
    }
    private struct Entry {
        let name: String
        let before: Snapshot
        let after: Snapshot
    }
    private var past: [Entry] = []
    private var future: [Entry] = []
    private var revision = UUID()
    private var savedRevision: UUID?
    private var pending: Snapshot?
    private var pendingName = "Edit"
    private var depth = 0
    let entryLimit: Int
    let retainedByteLimit: Int

    init(entryLimit: Int = 100, retainedByteLimit: Int = 256 * 1024 * 1024) {
        self.entryLimit = max(0, entryLimit)
        self.retainedByteLimit = max(0, retainedByteLimit)
        savedRevision = revision
    }

    var canUndo: Bool { depth == 0 && !past.isEmpty }
    var canRedo: Bool { depth == 0 && !future.isEmpty }
    var undoName: String { past.last?.name ?? "" }
    var redoName: String { future.last?.name ?? "" }
    var isModified: Bool { revision != savedRevision }
    var undoCount: Int { past.count }
    func markSaved() { savedRevision = revision }
    func reset() {
        past.removeAll()
        future.removeAll()
        pending = nil
        depth = 0
        revision = UUID()
        savedRevision = revision
    }

    struct HistoryStep: Identifiable, Equatable, Sendable {
        let id: UUID
        let name: String
        let isCurrent: Bool
        let isFuture: Bool
        let targetPastCount: Int
    }

    /// 返回当前所有可见历史步骤（初始状态 + 过去的步骤 + 未来的步骤）
    var allSteps: [HistoryStep] {
        var steps: [HistoryStep] = []
        let totalCount = past.count + future.count
        guard totalCount > 0 else { return [] }

        // 初始状态 (对应 targetPastCount = 0)
        let initialId = (past.first?.before.revision) ?? (future.last?.before.revision) ?? UUID()
        steps.append(HistoryStep(
            id: initialId,
            name: "Initial State".localized,
            isCurrent: past.isEmpty,
            isFuture: false,
            targetPastCount: 0
        ))

        // past 中的步骤 (index 从 0 到 past.count - 1)
        for (idx, entry) in past.enumerated() {
            let target = idx + 1
            steps.append(HistoryStep(
                id: entry.after.revision,
                name: entry.name.localized,
                isCurrent: idx == past.count - 1,
                isFuture: false,
                targetPastCount: target
            ))
        }

        // future 中的步骤 (future.reversed() 是按照时间推移从近到远)
        let reversedFuture = Array(future.reversed())
        for (idx, entry) in reversedFuture.enumerated() {
            let target = past.count + idx + 1
            steps.append(HistoryStep(
                id: entry.after.revision,
                name: entry.name.localized,
                isCurrent: false,
                isFuture: true,
                targetPastCount: target
            ))
        }

        return steps
    }

    /// 跳转到指定的历史步骤
    func jump(to step: HistoryStep) -> Snapshot? {
        guard depth == 0 else { return nil }
        let targetCount = step.targetPastCount
        var lastSnapshot: Snapshot? = nil
        while past.count > targetCount {
            lastSnapshot = undo()
        }
        while past.count < targetCount {
            lastSnapshot = redo()
        }
        return lastSnapshot
    }

    func begin(_ name: String, document: CanvasDocument?, selection: UUID?) {
        if depth == 0 {
            pending = Snapshot(document: document, activeLayerID: selection, revision: revision)
            pendingName = name
        }
        depth += 1
    }

    func end(document: CanvasDocument?, selection: UUID?) {
        guard depth > 0 else { return }
        depth -= 1
        guard depth == 0, let before = pending else { return }
        pending = nil
        // Selecting, navigating, and no-op edits must preserve redo history.
        guard before.document != document else { return }
        revision = UUID()
        past.append(Entry(name: pendingName, before: before,
            after: Snapshot(document: document, activeLayerID: selection, revision: revision)))
        future.removeAll()
        trim(current: document)
    }

    func undo() -> Snapshot? {
        guard canUndo, let entry = past.popLast() else { return nil }
        future.append(entry)
        revision = entry.before.revision
        trim(current: entry.before.document)
        return entry.before
    }

    func redo() -> Snapshot? {
        guard canRedo, let entry = future.popLast() else { return nil }
        past.append(entry)
        revision = entry.after.revision
        trim(current: entry.after.document)
        return entry.after
    }

    /// Bytes retained only by history, excluding images in the live document.
    func retainedBytes(current: CanvasDocument?) -> Int {
        var seen = Set<ObjectIdentifier>()
        for layer in current?.layers ?? [] {
            for asset in [layer.asset, layer.mask?.asset].compactMap({ $0 }) {
                seen.insert(ObjectIdentifier(asset.image))
                seen.insert(ObjectIdentifier(asset.thumbnail))
            }
        }
        var bytes = 0
        for entry in past + future {
            for snapshot in [entry.before, entry.after] {
                for layer in snapshot.document?.layers ?? [] {
                    for asset in [layer.asset, layer.mask?.asset].compactMap({ $0 }) {
                        for image in [asset.image, asset.thumbnail] where seen.insert(ObjectIdentifier(image)).inserted {
                            bytes += image.bytesPerRow * image.height
                        }
                    }
                }
            }
        }
        return bytes
    }

    private func trim(current: CanvasDocument?) {
        while past.count + future.count > entryLimit || retainedBytes(current: current) > retainedByteLimit {
            if !past.isEmpty { past.removeFirst() }
            else if !future.isEmpty { future.removeFirst() }
            else { break }
        }
    }
}
