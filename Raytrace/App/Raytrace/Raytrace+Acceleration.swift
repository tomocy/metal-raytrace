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
    func measureHeapSize(with device: some MTLDevice) -> Int {
        var size = 0

        size += meshes.reduce(0) { size, mesh in
            size + mesh.measureHeapSize(with: device)
        }

        size += MemoryLayout<Raytrace.Primitive.Instance>.stride * primitives.count

        size += MemoryLayout<ForGPU>.stride

        return size
    }

    func build(
        with encoder: some MTLBlitCommandEncoder,
        on heap: some MTLHeap,
        label: String
    ) -> some MTLBuffer {
        let forGPU = Raytrace.Acceleration.ForGPU.init(
            structure: structure.gpuResourceID,

            meshes: meshes.build(
                with: encoder,
                on: heap,
                label: "\(label)/Meshes"
            ).gpuAddress,

            primitives: primitives.build(
                with: encoder,
                on: heap,
                label: "\(label)/Primitives"
            ).gpuAddress
        )

        return Raytrace.Metal.Buffer.buildable(forGPU).build(
            with: encoder,
            on: heap,
            label: label
        )!
    }
}

extension Raytrace.Acceleration {
    struct ForGPU {
        var structure: MTLResourceID
        var meshes: UInt64
        var primitives: UInt64
    }
}
