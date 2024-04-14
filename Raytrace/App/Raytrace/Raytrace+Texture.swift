// tomocy

import Foundation
import Metal
import MetalKit

extension Raytrace {
    struct Texture {}
}

extension Raytrace.Texture {
    static func make2D(
        with device: some MTLDevice,
        label: String? = nil,
        format: MTLPixelFormat,
        size: SIMD2<Int>,
        usage: MTLTextureUsage,
        storageMode: MTLStorageMode,
        mipmapped: Bool
    ) -> (any MTLTexture)? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: format,
            width: size.x,
            height: size.y,
            mipmapped: mipmapped
        )

        desc.usage = usage
        desc.storageMode = storageMode

        let texture = device.makeTexture(descriptor: desc)

        texture?.label = label

        return texture
    }
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

    static func fill(
        _ color: CGColor,
        with device: some MTLDevice,
        usage: MTLTextureUsage
    ) throws -> (any MTLTexture)? {
        guard let texture = make2D(
            with: device,
            format: .bgra8Unorm,
            size: .init(1, 1),
            usage: usage,
            storageMode: .managed,
            mipmapped: false
        ) else { return nil }

        let pixels = [BGRA8UNormalized].init(
            repeating: .init(color),
            count: texture.width * texture.height
        )

        pixels.withUnsafeBytes { bytes in
            texture.replace(
                region: MTLRegionMake2D(0, 0, texture.width, texture.height),
                mipmapLevel: 0,
                withBytes: bytes.baseAddress!,
                bytesPerRow: bytes.count / texture.width
            )
        }

        return texture
    }
}
