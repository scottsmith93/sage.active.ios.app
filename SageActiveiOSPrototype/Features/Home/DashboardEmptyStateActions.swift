import Foundation
import SwiftUI

struct DashboardEmptyStateButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(SageActiveTheme.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(SageActiveTheme.secondaryUtility10, in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }
}

struct DashboardReceiptNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

/// Prototype receipt uploads stay on this device; no purchase record is invented.
enum DashboardReceiptUpload {
    static func save(_ source: URL) throws -> String {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                    appropriateFor: nil, create: true)
            .appendingPathComponent("PurchaseReceipts", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = "\(UUID().uuidString).\(source.pathExtension)"
        try FileManager.default.copyItem(at: source, to: directory.appendingPathComponent(filename))
        return source.lastPathComponent
    }
}
