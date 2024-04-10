// tomocy

import Metal
import MetalKit

extension Raytrace {
    struct Env {
        var diffuse: any MTLTexture
        var specular: any MTLTexture
        var lut: any MTLTexture
    }
}

extension Raytrace.Env {
    init(device: some MTLDevice) throws {
        // We know the textures for now.

        diffuse = try MTKTextureLoader.init(device: device).newTexture(
            URL: Bundle.main.url(forResource: "Env_Prelight_Diffuse", withExtension: "png", subdirectory: "Farm/Env")!,
            options: [
                .textureUsage: MTLTextureUsage.shaderRead.rawValue,
                .textureStorageMode: MTLStorageMode.private.rawValue,
                .cubeLayout: MTKTextureLoader.CubeLayout.vertical.rawValue,
                .generateMipmaps: false,
            ]
        )

        specular = try MTKTextureLoader.init(device: device).newTexture(
            URL: Bundle.main.url(forResource: "Env_Prelight_Specular", withExtension: "png", subdirectory: "Farm/Env")!,
            options: [
                .textureUsage: MTLTextureUsage.shaderRead.rawValue,
                .textureStorageMode: MTLStorageMode.private.rawValue,
                .cubeLayout: MTKTextureLoader.CubeLayout.vertical.rawValue,
                .generateMipmaps: true,
            ]
        )

        lut = try MTKTextureLoader.init(device: device).newTexture(
            URL: Bundle.main.url(forResource: "Env_Prelight_Env_GGX", withExtension: "png", subdirectory: "Farm/Env")!,
            options: [
                .textureUsage: MTLTextureUsage.shaderRead.rawValue,
                .textureStorageMode: MTLStorageMode.private.rawValue,
                .generateMipmaps: false,
            ]
        )
    }
}

extension Raytrace.Env {
    func encode(
        with encoder: MTLComputeArgumentEncoder,
        at index: Int,
        label: String? = nil,
        usage: MTLResourceUsage
    ) {
        let buffer: some MTLBuffer = ({
            let encoder = encoder.make(for: index)!

            let buffer: some MTLBuffer = encoder.make(label: label)!
            encoder.compute.useResource(buffer, usage: .read)

            encode(with: encoder, to: buffer, usage: .read)

            return buffer
        }) ()

        encoder.argument.setBuffer(buffer, offset: 0, index: index)
    }

    func encode(with encoder: MTLComputeArgumentEncoder, to buffer: some MTLBuffer, usage: MTLResourceUsage) {
        encoder.argument.setArgumentBuffer(buffer, offset: 0)

        diffuse.encode(with: encoder, at: 0, usage: usage)
        specular.encode(with: encoder, at: 1, usage: usage)
        lut.encode(with: encoder, at: 2, usage: usage)
    }
}
