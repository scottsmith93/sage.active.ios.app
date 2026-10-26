import MapKit
import PassKit
import SwiftUI

/// A subdued map hero that scrolls away with the transaction content.
struct CardTransactionMapBackground: View {
    let merchant: String
    let location: CardPurchaseLocation

    var body: some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: .init(latitude: location.latitude - 0.0005, longitude: location.longitude),
            span: .init(latitudeDelta: 0.006, longitudeDelta: 0.006)
        )), interactionModes: []) {
            Marker(merchant, coordinate: .init(latitude: location.latitude, longitude: location.longitude))
                .tint(SageActiveTheme.negativeVisual)
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        .overlay {
            LinearGradient(stops: [
                .init(color: SageActiveTheme.pageBackground.opacity(0.5), location: 0),
                .init(color: SageActiveTheme.pageBackground.opacity(0.5), location: 0.55),
                .init(color: SageActiveTheme.pageBackground, location: 1)
            ], startPoint: .top, endPoint: .bottom)
            .allowsHitTesting(false)
        }
        .accessibilityLabel("Fictional purchase location: \(location.area)")
    }
}

/// PassKit renders the Apple Pay identity at the device's native resolution.
/// It is a static payment-method indication here, with no payment-button action.
struct CardApplePayMark: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        let mark = PKPaymentButton(paymentButtonType: .plain, paymentButtonStyle: .whiteOutline)
        mark.isUserInteractionEnabled = false
        mark.isAccessibilityElement = false
        mark.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(mark)
        NSLayoutConstraint.activate([
            mark.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            mark.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            mark.topAnchor.constraint(equalTo: container.topAnchor),
            mark.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        container.isAccessibilityElement = true
        container.accessibilityLabel = "Paid with Apple Pay"
        container.accessibilityTraits = .image
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
