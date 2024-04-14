// tomocy

import ModelIO
import Metal
import MetalKit

extension Raytrace {
    struct Material {
        var albedo: (any MTLTexture)?
        var metalRoughness: (any MTLTexture)?
    }
}

extension Raytrace.Material {
    init?(_ other: MDLMaterial?, device: some MTLDevice) throws {
        guard let other = other else { return nil }

        let textureLoader = MTKTextureLoader.init(device: device)

        if let url = other.property(with: .baseColor)?.urlValue {
            albedo = try textureLoader.newTexture(URL: url)
        }
    }
}

extension Raytrace.Material {
    func measureHeapSize(with device: some MTLDevice) -> Int {
        var size = 0

        size += albedo?.measureHeapSize(with: device) ?? 0
        size += metalRoughness?.measureHeapSize(with: device) ?? 0

        size += MemoryLayout<ForGPU>.stride

        return size
    }

    func build(
        with encoder: some MTLBlitCommandEncoder,
        on heap: some MTLHeap,
        label: String
    ) -> some MTLBuffer {
        let forGPU = ForGPU.init(
            albedo: albedo?.copy(
                with: encoder,
                to: heap
            ).gpuResourceID ?? .init(),

            metalRoughness: metalRoughness?.copy(
                with: encoder,
                to: heap
            ).gpuResourceID ?? .init()
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

extension Raytrace.Material {
    struct ForGPU {
        var albedo: MTLResourceID = .init()
        var metalRoughness: MTLResourceID = .init()
    }
}
