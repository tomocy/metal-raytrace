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
    func measureHeapSize(with device: some MTLDevice) -> Int {
        var size = 0

        size += source.measureHeapSize(with: device)

        size += MemoryLayout<ForGPU>.stride

        return size
    }

    func build(
        with encoder: some MTLBlitCommandEncoder,
        on heap: some MTLHeap,
        label: String
    ) -> some MTLBuffer {
        let forGPU = Raytrace.Background.ForGPU.init(
            source: source.copy(
                with: encoder,
                to: heap
            ).gpuResourceID
        )

        let onDevice = Raytrace.Metal.bufferBuildable(forGPU).build(
            with: encoder.device,
            label: label,
            options: .storageModeShared
        )!

        let onHeap = onDevice.copy(with: encoder, to: heap)

        encoder.copy(from: onDevice, to: onHeap)

        return onHeap
    }
}

extension Raytrace.Background {
    struct ForGPU {
        var source: MTLResourceID
    }
}
