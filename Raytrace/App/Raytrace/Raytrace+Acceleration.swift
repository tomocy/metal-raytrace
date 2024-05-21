// tomocy

import Metal

extension Raytrace {
    struct Acceleration {
        var structure: any MTLAccelerationStructure
        var meshes: [Mesh]
    }
}

extension Raytrace.Acceleration {
    func use(
        with encoder: some MTLComputeCommandEncoder,
        usage: MTLResourceUsage,
        resourcePool: Raytrace.ResourcePool,
        label: String
    ) -> ForGPU {
        return .init(
            structure: structure.use(with: encoder, usage: usage),
            pieces: meshes.pieces.build(
                with: encoder,
                resourcePool: resourcePool,
                label: "\(label)/Acceleration/Pieces"
            )!.use(with: encoder, usage: usage)
        )
    }

    func build(
        with encoder: some MTLComputeCommandEncoder,
        resourcePool: Raytrace.ResourcePool,
        label: String
    ) -> (any MTLBuffer)? {
        var forGPU = Raytrace.Acceleration.ForGPU.init(
            structure: .init(),
            pieces: .init()
        )

        do {
            encoder.useResource(structure, usage: .read)
            forGPU.structure = structure.gpuResourceID
        }
        do {
            let buffer = meshes.pieces.build(
                with: encoder,
                resourcePool: resourcePool,
                label: "\(label)/Pieces"
            )!

            encoder.useResource(buffer, usage: .read)
            forGPU.pieces = buffer.gpuAddress
        }

        return resourcePool.buffers.take(at: label) {
            Raytrace.Metal.Buffer.buildable(forGPU).build(
                with: encoder.device,
                label: label
            )
        }
    }
}

extension Raytrace.Acceleration {
    struct ForGPU {
        var structure: MTLResourceID
        var pieces: UInt64
    }
}
