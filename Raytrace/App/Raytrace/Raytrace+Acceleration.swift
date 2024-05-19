// tomocy

import Metal

extension Raytrace {
    struct Acceleration {
        var structure: any MTLAccelerationStructure
        var meshes: [Mesh]
        var primitives: [Primitive.Instance]
    }
}

extension Raytrace.Acceleration {
    func build(
        with encoder: some MTLComputeCommandEncoder,
        resourcePool: Raytrace.ResourcePool,
        label: String
    ) -> (any MTLBuffer)? {
        var forGPU = Raytrace.Acceleration.ForGPU.init(
            structure: .init(),
            pieces: .init(),
            primitives: .init()
        )

        do {
            encoder.useResource(structure, usage: .read)
            forGPU.structure = structure.gpuResourceID
        }
        do {
            let pieces = meshes.compactMap { $0.pieces }.flatMap { $0 }
            let buffer = pieces.build(
                with: encoder,
                resourcePool: resourcePool,
                label: "\(label)/Pieces"
            )!

            encoder.useResource(buffer, usage: .read)
            forGPU.pieces = buffer.gpuAddress
        }
        do {
            let label = "\(label)/Primitives"

            let buffer = resourcePool.buffers.take(at: label) {
                primitives.build(
                    with: encoder.device,
                    label: label
                )
            }!

            encoder.useResource(buffer, usage: .read)
            forGPU.primitives = buffer.gpuAddress
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
        var primitives: UInt64
    }
}
