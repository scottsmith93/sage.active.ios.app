import CoreMotion
import Foundation

struct CardMotionSample: Equatable, Sendable {
    var x = 0.0
    var y = 0.0
    var z = 0.0
    var energy = 0.0
    static let neutral = CardMotionSample()
}

/// One sensor session shared by visible card instances; readings stay on device.
@MainActor
final class CardMotionSource {
    static let shared = CardMotionSource()
    private let manager = CMMotionManager()
    private var listeners: [UUID: AsyncStream<CardMotionSample>.Continuation] = [:]
    private var samplingTask: Task<Void, Never>?
    private var reference: CMAttitude?
    private var filtered = CardMotionSample.neutral
    private var lastTimestamp: TimeInterval = 0

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    func updates() -> AsyncStream<CardMotionSample> {
        let id = UUID()
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            listeners[id] = continuation
            continuation.yield(filtered)
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { @MainActor in self?.removeListener(id) }
            }
            if listeners.count == 1 { start() }
        }
    }

    func recenter() {
        reference = nil
        filtered = .neutral
        for listener in listeners.values { listener.yield(.neutral) }
    }

    private func start() {
        guard isAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        if CMMotionManager.availableAttitudeReferenceFrames().contains(.xArbitraryZVertical) {
            manager.startDeviceMotionUpdates(using: .xArbitraryZVertical)
        } else {
            manager.startDeviceMotionUpdates()
        }
        samplingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.sample()
                do { try await Task.sleep(for: .milliseconds(33)) } catch { return }
            }
        }
    }

    private func sample() {
        guard let motion = manager.deviceMotion, motion.timestamp != lastTimestamp else { return }
        lastTimestamp = motion.timestamp
        guard let attitude = motion.attitude.copy() as? CMAttitude else { return }
        guard let reference else { self.reference = attitude; return }
        attitude.multiply(byInverseOf: reference)
        // A rotation vector avoids Euler-angle jumps around the starting pose.
        let q = attitude.quaternion
        let sign = q.w < 0 ? -1.0 : 1.0
        let length = sqrt(q.x * q.x + q.y * q.y + q.z * q.z)
        let scale = length > 0.00001 ? 2 * atan2(length, abs(q.w)) / length : 0
        let rate = motion.rotationRate
        let energy = min(1, sqrt(rate.x * rate.x + rate.y * rate.y + rate.z * rate.z) / 0.8)
        let target = CardMotionSample(x: q.x * sign * scale, y: q.y * sign * scale,
                                      z: q.z * sign * scale, energy: energy)
        filtered.x += (target.x - filtered.x) * 0.14
        filtered.y += (target.y - filtered.y) * 0.14
        filtered.z += (target.z - filtered.z) * 0.14
        filtered.energy += (target.energy - filtered.energy) * 0.16
        for listener in listeners.values { listener.yield(filtered) }
    }

    private func removeListener(_ id: UUID) {
        listeners.removeValue(forKey: id)
        guard listeners.isEmpty else { return }
        samplingTask?.cancel()
        samplingTask = nil
        manager.stopDeviceMotionUpdates()
        reference = nil
        filtered = .neutral
        lastTimestamp = 0
    }
}
