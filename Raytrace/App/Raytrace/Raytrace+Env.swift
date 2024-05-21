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
    func use(with encoder: some MTLComputeCommandEncoder, usage: MTLResourceUsage) -> ForGPU {
        encoder.useResource(diffuse, usage: usage)
        encoder.useResource(specular, usage: usage)
        encoder.useResource(lut, usage: usage)

        return .init(
            diffuse: diffuse.gpuResourceID,
            specular: specular.gpuResourceID,
            lut: lut.gpuResourceID
        )
    }

    func build(
        with encoder: some MTLComputeCommandEncoder,
        resourcePool: Raytrace.ResourcePool,
        label: String
    ) -> (any MTLBuffer)? {
        encoder.useResource(diffuse, usage: .read)
        encoder.useResource(specular, usage: .read)
        encoder.useResource(lut, usage: .read)

        let forGPU = ForGPU.init(
            diffuse: diffuse.gpuResourceID,

            specular: specular.gpuResourceID,

            lut: lut.gpuResourceID
        )

        return resourcePool.buffers.take(at: label) {
            Raytrace.Metal.Buffer.buildable(forGPU).build(
                with: encoder.device,
                label: label
            )
        }
    }
}

extension Raytrace.Env {
    struct ForGPU {
        var diffuse: MTLResourceID
        var specular: MTLResourceID
        var lut: MTLResourceID
    }
}
