// tomocy

import CoreGraphics
import CoreImage
import Metal

enum Texture {}

extension Texture {
    static func make2D(
        with device: some MTLDevice,
        label: String,
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

        guard let texture = device.makeTexture(descriptor: desc) else { return nil }

        texture.label = label

        return texture
    }

    static func makeCube(
        with device: some MTLDevice,
        label: String,
        format: MTLPixelFormat,
        size: Int,
        usage: MTLTextureUsage,
        storageMode: MTLStorageMode,
        mipmapped: Bool
    ) -> (any MTLTexture)? {
        let desc = MTLTextureDescriptor.textureCubeDescriptor(
            pixelFormat: format,
            size: size,
            mipmapped: mipmapped
        )

        desc.usage = usage
        desc.storageMode = storageMode

        guard let texture = device.makeTexture(descriptor: desc) else { return nil }

        texture.label = label

        return texture
    }
}

extension MTLTexture {
    func into(in colorSpace: CGColorSpace, mipmapLevel: Int) -> CGImage? {
        guard let image = CIImage.init(mtlTexture: self)?.oriented(.downMirrored) else { return nil }

        return CIContext.init(mtlDevice: device).createCGImage(
            image,
            from: image.extent,
            format: .RGBA8,
            colorSpace: colorSpace
        )
    }
}

