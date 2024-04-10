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

extension Raytrace.Background {
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

        encoder.argument.setTexture(source, index: 0)
    }
}
