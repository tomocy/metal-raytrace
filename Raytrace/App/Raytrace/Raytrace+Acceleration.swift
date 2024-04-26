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
        label: String
    ) -> (any MTLBuffer)? {
        var forGPU = Raytrace.Acceleration.ForGPU.init(
            structure: .init(),
            meshes: .init(),
            primitives: .init()
        )

        do {
            encoder.useResource(structure, usage: .read)
            forGPU.structure = structure.gpuResourceID
        }
        do {
            let buffer = meshes.build(
                with: encoder,
                label: "\(label)/Meshes"
            )!

            encoder.useResource(buffer, usage: .read)
            forGPU.meshes = buffer.gpuAddress
        }
        do {
            let buffer = primitives.build(
                with: encoder.device,
                label: "\(label)/Primitives"
            )!

            encoder.useResource(buffer, usage: .read)
            forGPU.primitives = buffer.gpuAddress
        }

        return Raytrace.Metal.Buffer.buildable(forGPU).build(
            with: encoder.device,
            label: label
        )
    }
}

extension Raytrace.Acceleration {
    struct ForGPU {
        var structure: MTLResourceID
        var meshes: UInt64
        var primitives: UInt64
    }
}
