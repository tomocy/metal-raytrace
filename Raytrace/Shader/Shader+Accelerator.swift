// tomocy

import Metal

extension Shader {
    struct Accelerator {
        var target: (any MTLAccelerationStructure)?
    }
}

extension Shader.Accelerator {
    mutating func encode(to buffer: some MTLCommandBuffer) {
        let encoder = buffer.makeAccelerationStructureCommandEncoder()!
        defer { encoder.endEncoding() }

        let desc = ({
            let desc = MTLPrimitiveAccelerationStructureDescriptor.init()

            desc.geometryDescriptors = [describe(with: encoder.device)]

            return desc
        }) ()

        let sizes = encoder.device.accelerationStructureSizes(descriptor: desc)
        target = encoder.device.makeAccelerationStructure(size: sizes.accelerationStructureSize)

        encoder.build(
            accelerationStructure: target!,
            descriptor: desc,
            scratchBuffer: encoder.device.makeBuffer(
                length: sizes.buildScratchBufferSize,
                options: .storageModePrivate
            )!,
            scratchBufferOffset: 0
        )
    }

    private func describe(with device: some MTLDevice) -> MTLAccelerationStructureGeometryDescriptor {
        typealias Vertex = SIMD3<Float>

        let desc = MTLAccelerationStructureTriangleGeometryDescriptor.init()

        desc.triangleCount = 1
        desc.vertexFormat = .float3
        desc.vertexStride = MemoryLayout<Vertex>.stride

        do {
            let vertices: [Vertex] = [
                .init(-0.3, -0.3, 0),
                .init(0, 0.3, 0),
                .init(0.3, -0.3, 0),
            ]

            vertices.withUnsafeBytes { bytes in
                desc.vertexBuffer = device.makeBuffer(
                    bytes: bytes.baseAddress!,
                    length: bytes.count,
                    options: .storageModeShared
                )
            }

        }

        return desc
    }
}

