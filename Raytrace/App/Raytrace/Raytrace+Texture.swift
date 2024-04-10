// tomocy

import Foundation
import Metal
import MetalKit

extension Raytrace {
    struct Texture {}
}

extension Raytrace.Texture {
    private struct BGRA8UNormalized {
        init(_ color: CGColor) {
            let factor: CGFloat = 255

            blue = .init(color.blue * factor)
            green = .init(color.green * factor)
            red = .init(color.red * factor)
            alpha = .init(color.alpha * factor)
        }

        var blue: UInt8
        var green: UInt8
        var red: UInt8
        var alpha: UInt8
    }

    static func fill(_ color: CGColor, with device: some MTLDevice) throws -> (any MTLTexture)? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: 1, height: 1,
            mipmapped: false
        )

        guard let texture = device.makeTexture(descriptor: desc) else { return nil }

        let pixels = [BGRA8UNormalized].init(
            repeating: .init(color),
            count: desc.width * desc.height
        )

        pixels.withUnsafeBytes { bytes in
            texture.replace(
                region: MTLRegionMake2D(0, 0, desc.width, desc.height),
                mipmapLevel: 0,
                withBytes: bytes.baseAddress!,
                bytesPerRow: bytes.count / desc.width
            )
        }

        return texture
    }
}
