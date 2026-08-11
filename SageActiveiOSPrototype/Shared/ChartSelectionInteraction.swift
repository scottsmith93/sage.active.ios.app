import Charts
import SwiftUI

extension View {
    /// Supports a simple tap, a press-and-hold, or a drag across a chart. Tapping within the
    /// chart but outside its plot area clears the current selection.
    func interactiveChartXSelection<Value: Plottable>(_ selection: Binding<Value?>) -> some View {
        chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                updateSelection(
                                    at: gesture.location,
                                    proxy: proxy,
                                    geometry: geometry,
                                    selection: selection
                                )
                            }
                    )
                    .accessibilityHidden(true)
            }
        }
    }

    private func updateSelection<Value: Plottable>(
        at location: CGPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy,
        selection: Binding<Value?>
    ) {
        guard let plotFrameAnchor = proxy.plotFrame else {
            selection.wrappedValue = nil
            return
        }

        let plotFrame = geometry[plotFrameAnchor]
        guard plotFrame.contains(location) else {
            selection.wrappedValue = nil
            return
        }

        let xPosition = location.x - plotFrame.minX
        selection.wrappedValue = proxy.value(atX: xPosition, as: Value.self)
    }
}
