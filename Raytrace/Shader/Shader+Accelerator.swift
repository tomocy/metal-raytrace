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
    mutating func encode(_ mesh: inout Shader.Mesh, to buffer: some MTLCommandBuffer) {
        let encoder = buffer.makeAccelerationStructureCommandEncoder()!
        defer { encoder.endEncoding() }

        let desc: MTLPrimitiveAccelerationStructureDescriptor = describe(
            mesh,
            with: encoder.device
        )
        let sizes = encoder.device.accelerationStructureSizes(descriptor: desc)

        mesh.accelerator = encoder.device.makeAccelerationStructure(size: sizes.accelerationStructureSize)

        encoder.build(
            accelerationStructure: mesh.accelerator!,
            descriptor: desc,
            scratchBuffer: encoder.device.makeBuffer(
                length: sizes.buildScratchBufferSize,
                options: .storageModePrivate
            )!,
            scratchBufferOffset: 0
        )
    }

    private func describe(
        _ mesh: Shader.Mesh,
        with device: some MTLDevice
    ) -> MTLPrimitiveAccelerationStructureDescriptor {
        let desc = MTLPrimitiveAccelerationStructureDescriptor.init()

        desc.geometryDescriptors = describe(mesh, with: device)

        return desc
    }

    private func describe(
        _ mesh: Shader.Mesh,
        with device: some MTLDevice
    ) -> [MTLAccelerationStructureGeometryDescriptor] {
        var descs: [MTLAccelerationStructureGeometryDescriptor] = []

        mesh.pieces.forEach { piece in
            assert(piece.type == .triangle)

            let desc = MTLAccelerationStructureTriangleGeometryDescriptor.init()

            do {
                desc.vertexBuffer = mesh.positions.buffer
                desc.vertexFormat = mesh.positions.format
                desc.vertexStride = mesh.positions.stride
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
        var instances: [Shader.Primitive.Instance]?
    }
}

extension Shader.Accelerator.Instanced {
    mutating func encode(
        _ meshes: [Shader.Mesh],
        to buffer: some MTLCommandBuffer
    ) {
        let encoder = buffer.makeAccelerationStructureCommandEncoder()!
        defer { encoder.endEncoding() }

        meshes.forEach { primitive in
            encoder.useResource(primitive.accelerator!, usage: .read)
        }

        let desc: MTLInstanceAccelerationStructureDescriptor = describe(
            meshes,
            with: encoder.device
        )
        let sizes = encoder.device.accelerationStructureSizes(descriptor: desc)

        target = encoder.device.makeAccelerationStructure(size: sizes.accelerationStructureSize)

        do {
            instances = []

            meshes.enumerated().forEach { i, mesh in
                mesh.instances.forEach { instance in
                    instances!.append(
                        .init(meshID: .init(i))
                    )
                }
            }
        }

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
        _ meshes: [Shader.Mesh],
        with device: some MTLDevice
    ) -> MTLInstanceAccelerationStructureDescriptor {
        let desc = MTLInstanceAccelerationStructureDescriptor.init()

        desc.instancedAccelerationStructures = meshes.map { $0.accelerator! }

        let instances = meshes.enumerated().reduce(
            into: []
        ) { result, mesh in
            result.append(
                contentsOf: describe(
                    mesh.element.instances,
                    of: .init(mesh.offset)
                )
            )
        }

        desc.instanceDescriptorBuffer = Shader.Metal.bufferBuildable(instances).build(
            with: device,
            options: .storageModeShared
        )

        desc.instanceCount = instances.count

        return desc
    }

    private func describe(
        _ instances: [Shader.Mesh.Instance],
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
