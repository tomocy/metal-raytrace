// tomocy

import ModelIO
import Metal
import MetalKit

extension Shader {
    struct Accelerator {
        var primitive: Primitive = .init()
        var instanced: Instanced = .init()
    }
}

extension Shader.Accelerator {
    struct Primitive {}
}

extension Shader.Accelerator.Primitive {
    mutating func encode(_ primitive: inout Shader.Primitive, to buffer: some MTLCommandBuffer) {
        let encoder = buffer.makeAccelerationStructureCommandEncoder()!
        defer { encoder.endEncoding() }

        let desc: MTLPrimitiveAccelerationStructureDescriptor = describe(
            primitive,
            with: encoder.device
        )
        let sizes = encoder.device.accelerationStructureSizes(descriptor: desc)

        primitive.accelerator = encoder.device.makeAccelerationStructure(size: sizes.accelerationStructureSize)

        encoder.build(
            accelerationStructure: primitive.accelerator!,
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
    ) -> MTLPrimitiveAccelerationStructureDescriptor {
        let desc = MTLPrimitiveAccelerationStructureDescriptor.init()

        desc.geometryDescriptors = describe(primitive, with: device)

        return desc
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

extension Shader.Accelerator {
    struct Instanced {
        var target: (any MTLAccelerationStructure)?
    }
}

extension Shader.Accelerator.Instanced {
    mutating func encode(
        _ primitives: [Shader.Primitive],
        to buffer: some MTLCommandBuffer
    ) {
        let encoder = buffer.makeAccelerationStructureCommandEncoder()!
        defer { encoder.endEncoding() }

        primitives.forEach { primitive in
            encoder.useResource(primitive.accelerator!, usage: .read)
        }

        let desc: MTLInstanceAccelerationStructureDescriptor = describe(
            primitives,
            with: encoder.device
        )
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
        _ primitives: [Shader.Primitive],
        with device: some MTLDevice
    ) -> MTLInstanceAccelerationStructureDescriptor {
        let desc = MTLInstanceAccelerationStructureDescriptor.init()

        desc.instancedAccelerationStructures = primitives.map { $0.accelerator! }

        let instances = primitives.enumerated().reduce(
            into: []
        ) { result, primitive in
            result.append(
                contentsOf: describe(
                    primitive.element.instances,
                    of: .init(primitive.offset)
                )
            )
        }

        desc.instanceDescriptorBuffer = instances.toBuffer(with: device, options: .storageModeShared)

        desc.instanceCount = instances.count

        return desc
    }

    private func describe(
        _ instances: [Shader.Primitive.Instance],
        of accelerator: UInt32
    ) -> [MTLAccelerationStructureInstanceDescriptor] {
        return instances.map { instance in
            var desc = MTLAccelerationStructureInstanceDescriptor.init()

            desc.accelerationStructureIndex = accelerator

            desc.transformationMatrix = .init(instance.transform.resolve())

            desc.mask = 0xff;
            desc.options = .opaque

            return desc
        }
    }
}
