// tomocy

import ModelIO
import Metal
import MetalKit

extension Shader {
    struct Accelerator {
        var target: (any MTLAccelerationStructure)?
    }
}

extension Shader.Accelerator {
    mutating func encode(_ primitive: Shader.Primitive, to buffer: some MTLCommandBuffer) {
        let encoder = buffer.makeAccelerationStructureCommandEncoder()!
        defer { encoder.endEncoding() }

        let desc = ({
            let desc = MTLPrimitiveAccelerationStructureDescriptor.init()

            desc.geometryDescriptors = describe(primitive, with: encoder.device)

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

    private func describe(
        _ primitive: Shader.Primitive,
        with device: some MTLDevice
    ) -> [MTLAccelerationStructureGeometryDescriptor] {
        var descs: [MTLAccelerationStructureGeometryDescriptor] = []

        primitive.pieces.forEach { piece in
            assert(piece.type == .triangle)

            let desc = MTLAccelerationStructureTriangleGeometryDescriptor.init()

            do {
                desc.vertexBuffer = primitive.positions.buffer
                desc.vertexFormat = primitive.positions.format
                desc.vertexStride = primitive.positions.stride
            }

            do {
                desc.indexBuffer = piece.indices.buffer
                desc.indexType = piece.indices.type
                desc.triangleCount = piece.indices.count / 3
            }

            do {
                desc.primitiveDataBuffer = piece.data.buffer
                desc.primitiveDataStride = piece.data.stride
                desc.primitiveDataElementSize = desc.primitiveDataStride
            }

            descs.append(desc)
        }

        return descs
    }
}
