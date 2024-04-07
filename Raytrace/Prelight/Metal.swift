// tomocy

import CoreGraphics
import CoreImage
import Metal

extension MTLTexture {
    var resolution: CGSize {
        .init(
            width: .init(width),
            height: .init(height)
        )
    }
}

extension MTLTexture {
    func into(in colorSpace: CGColorSpace, mipmapLevel: Int) -> CGImage? {
        guard let image = CIImage.init(mtlTexture: self)?.oriented(.down) else { return nil }

        return CIContext.init(mtlDevice: device).createCGImage(
            image,
            from: image.extent,
            format: .RGBA8,
            colorSpace: colorSpace
        )
    }
}

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
