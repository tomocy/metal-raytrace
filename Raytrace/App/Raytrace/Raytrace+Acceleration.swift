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
}

extension Raytrace.Acceleration {
    struct ForGPU {
        var structure: MTLResourceID
        var pieces: UInt64
    }
}
