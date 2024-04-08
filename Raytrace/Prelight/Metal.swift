// tomocy

import CoreGraphics
import CoreImage
import Metal

extension MTLCommandBuffer {
    func commit(_ code: () throws -> Void) throws {
        try code()
        commit()
    }

    func complete(_ code: () throws -> Void) async throws {
        try code()
        waitUntilCompleted()
    }
}

extension MTLComputeCommandEncoder {
    var defaultThreadsSizePerGroup: MTLSize { .init(width: 8, height: 8, depth: 1) }

    func threadsGroupSize(for size: SIMD2<Int>, as threadsSize: MTLSize) -> MTLSize {
        .init(
            width: size.x.align(by: threadsSize.width) / threadsSize.width,
            height: size.y.align(by: threadsSize.height) / threadsSize.height,
            depth: threadsSize.depth
        )
    }
}

struct MTLFrameCapture {}

extension MTLFrameCapture {
    static var manager: MTLCaptureManager { MTLCaptureManager.shared() }
}

extension MTLFrameCapture {
    static func capture(for device: some MTLDevice, if enabled: Bool, _ code: () async throws -> Void) async throws {
        if enabled {
            try await capture(for: device, code)
        } else {
            try await code()
        }
    }

    static func capture(for device: some MTLDevice, _ code: () async throws -> Void) async throws {
        let desc = MTLCaptureDescriptor.init()
        desc.captureObject = device

        try manager.startCapture(with: desc)

        try await code()

        manager.stopCapture()
    }
}
