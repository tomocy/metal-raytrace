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
    func measureHeapSize(with device: some MTLDevice) -> Int {
        var size = 0

        size += diffuse.measureHeapSize(with: device)
        size += specular.measureHeapSize(with: device)
        size += lut.measureHeapSize(with: device)

        size += MemoryLayout<ForGPU>.stride

        return size
    }

    func build(
        with encoder: some MTLBlitCommandEncoder,
        on heap: some MTLHeap,
        label: String
    ) -> some MTLBuffer {
        let forGPU = ForGPU.init(
            diffuse: diffuse.copy(with: encoder, to: heap).gpuResourceID,

            specular: specular.copy(with: encoder, to: heap).gpuResourceID,

            lut: lut.copy(with: encoder, to: heap).gpuResourceID
        )

        return Raytrace.Metal.Buffer.buildable(forGPU).build(
            with: encoder,
            on: heap,
            label: label
        )!
    }
}

extension Raytrace.Env {
    struct ForGPU {
        var diffuse: MTLResourceID
        var specular: MTLResourceID
        var lut: MTLResourceID
    }
}
