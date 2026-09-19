import SwiftUI
import AppKit

/// 管理悬浮时的滚轮事件监听与数值步进
@MainActor
final class ScrollValueTracker: ObservableObject {
    private var monitor: Any?
    private var accumulatedDelta: CGFloat = 0

    func startMonitoring(onScroll: @escaping (Double) -> Void) {
        stopMonitoring()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else { return event }
            let isPrecise = event.hasPreciseScrollingDeltas
            let rawDelta = isPrecise ? event.scrollingDeltaY : event.deltaY

            // 步长倍率：按住 Shift 为 10 倍，按住 Option 为 0.1 倍微调
            let multiplier: Double = {
                if event.modifierFlags.contains(.shift) {
                    return 10.0
                } else if event.modifierFlags.contains(.option) {
                    return 0.1
                } else {
                    return 1.0
                }
            }()

            if isPrecise {
                self.accumulatedDelta += rawDelta
                let threshold: CGFloat = 5.0
                if abs(self.accumulatedDelta) >= threshold {
                    let dir = self.accumulatedDelta > 0 ? 1.0 : -1.0
                    self.accumulatedDelta = 0
                    onScroll(dir * multiplier)
                }
            } else {
                if abs(rawDelta) >= 0.1 {
                    let dir = rawDelta > 0 ? 1.0 : -1.0
                    onScroll(dir * multiplier)
                }
            }
            return nil // 消费该滚轮事件，防止外层 ScrollView 联动滚动
        }
    }

    func stopMonitoring() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        accumulatedDelta = 0
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

/// 滚轮数值调节 ViewModifier
struct ScrollableNumberModifier: ViewModifier {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let baseStep: Double
    var onChange: (() -> Void)?

    @StateObject private var tracker = ScrollValueTracker()
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    tracker.startMonitoring { deltaMultiplier in
                        let change = baseStep * deltaMultiplier
                        let newValue = min(range.upperBound, max(range.lowerBound, value + change))
                        if newValue != value {
                            value = (newValue * 10).rounded() / 10 // 保留最多1位小数
                            onChange?()
                        }
                    }
                } else {
                    tracker.stopMonitoring()
                }
            }
            .onDisappear {
                tracker.stopMonitoring()
            }
    }
}

extension View {
    /// 为数值输入框或控件赋予鼠标滚轮调节能力
    /// - Parameters:
    ///   - value: 数值绑定 (Double)
    ///   - range: 取值区间
    ///   - step: 基础步长（默认 1.0）
    ///   - onChange: 数值变更回调
    func scrollableNumber(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 1.0,
        onChange: (() -> Void)? = nil
    ) -> some View {
        modifier(ScrollableNumberModifier(value: value, range: range, baseStep: step, onChange: onChange))
    }

    /// 为 CGFloat 数值绑定提供滚轮调节能力
    func scrollableNumber(
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>,
        step: CGFloat = 1.0,
        onChange: (() -> Void)? = nil
    ) -> some View {
        let doubleBinding = Binding<Double>(
            get: { Double(value.wrappedValue) },
            set: { value.wrappedValue = CGFloat($0) }
        )
        let doubleRange = Double(range.lowerBound)...Double(range.upperBound)
        return scrollableNumber(value: doubleBinding, range: doubleRange, step: Double(step), onChange: onChange)
    }

    /// 为 Int 数值绑定提供滚轮调节能力
    func scrollableNumber(
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int = 1,
        onChange: (() -> Void)? = nil
    ) -> some View {
        let doubleBinding = Binding<Double>(
            get: { Double(value.wrappedValue) },
            set: { value.wrappedValue = Int($0.rounded()) }
        )
        let doubleRange = Double(range.lowerBound)...Double(range.upperBound)
        return scrollableNumber(value: doubleBinding, range: doubleRange, step: Double(step), onChange: onChange)
    }
}
