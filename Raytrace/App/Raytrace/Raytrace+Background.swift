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
    func use(with encoder: some MTLComputeCommandEncoder, usage: MTLResourceUsage) -> ForGPU {
        return .init(
            source: source.use(with: encoder, usage: usage)
        )
    }

    func build(
        with encoder: some MTLComputeCommandEncoder,
        resourcePool: Raytrace.ResourcePool,
        label: String
    ) -> (any MTLBuffer)? {
        var forGPU = Raytrace.Background.ForGPU.init(
            source: .init()
        )

        do {
            encoder.useResource(source, usage: .read)
            forGPU.source = source.gpuResourceID
        }

        return resourcePool.buffers.take(at: label) {
            Raytrace.Metal.Buffer.buildable(forGPU).build(
                with: encoder.device,
                label: label
            )
        }
    }
}

extension Raytrace.Background {
    struct ForGPU {
        var source: MTLResourceID
    }
}
