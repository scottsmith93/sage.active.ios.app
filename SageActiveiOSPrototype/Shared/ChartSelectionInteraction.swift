import Charts
import SwiftUI

extension View {
    /// Supports a simple tap, a press-and-hold, or a drag across a chart. Tapping within the
    /// chart but outside its plot area clears the current selection.
    func interactiveChartXSelection<Value: Plottable & Equatable>(_ selection: Binding<Value?>) -> some View {
        modifier(InteractiveChartXSelectionModifier(selection: selection))
    }
}

private struct InteractiveChartXSelectionModifier<Value: Plottable & Equatable>: ViewModifier {
    @Binding var selection: Value?
    @State private var selectionAtGestureStart: Value?
    @State private var isGestureActive = false
    @State private var hasMoved = false

    func body(content: Content) -> some View {
        content.chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                if !isGestureActive {
                                    selectionAtGestureStart = selection
                                    isGestureActive = true
                                    hasMoved = false
                                }
                                if hypot(gesture.translation.width, gesture.translation.height) > 6 {
                                    hasMoved = true
                                }
                                selection = value(
                                    at: gesture.location,
                                    proxy: proxy,
                                    geometry: geometry
                                )
                            }
                            .onEnded { gesture in
                                let endingValue = value(
                                    at: gesture.location,
                                    proxy: proxy,
                                    geometry: geometry
                                )

                                if !hasMoved, endingValue == selectionAtGestureStart {
                                    selection = nil
                                } else {
                                    selection = endingValue
                                }

                                isGestureActive = false
                                hasMoved = false
                                selectionAtGestureStart = nil
                            }
                    )
                    .accessibilityHidden(true)
            }
        }
    }

    private func value(
        at location: CGPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy
    ) -> Value? {
        guard let plotFrameAnchor = proxy.plotFrame else { return nil }
        let plotFrame = geometry[plotFrameAnchor]
        guard plotFrame.contains(location) else { return nil }
        return proxy.value(atX: location.x - plotFrame.minX, as: Value.self)
    }
}
