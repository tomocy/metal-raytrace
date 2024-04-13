// tomocy

import Metal
import MetalKit

extension Raytrace {
    struct Background {
        var source: any MTLTexture
    }
}

extension Raytrace.Background {
    init(device: some MTLDevice) throws {
        // We know the background texture for now.
        source = try MTKTextureLoader.init(device: device).newTexture(
            URL: Bundle.main.url(forResource: "Env", withExtension: "png", subdirectory: "Farm/Env")!,
            options: [
                .textureUsage: MTLTextureUsage.shaderRead.rawValue,
                .textureStorageMode: MTLStorageMode.private.rawValue,
                .cubeLayout: MTKTextureLoader.CubeLayout.vertical.rawValue,
                .generateMipmaps: true,
            ]
        )
    }
}
