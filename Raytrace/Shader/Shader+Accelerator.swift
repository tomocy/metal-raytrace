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
    mutating func encode(to buffer: some MTLCommandBuffer) {
        let encoder = buffer.makeAccelerationStructureCommandEncoder()!
        defer { encoder.endEncoding() }

        let desc = ({
            let desc = MTLPrimitiveAccelerationStructureDescriptor.init()

            desc.geometryDescriptors = describe(with: encoder.device)

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

    private func describe(with device: some MTLDevice) -> [MTLAccelerationStructureGeometryDescriptor] {
        let mesh = try! MTKMesh.useOnlyPositions(
            of: try! .init(
                mesh: .init(
                    planeWithExtent: .init(1, 1, 0),
                    segments: .init(1, 1),
                    geometryType: .triangles,
                    allocator: MTKMeshBufferAllocator.init(device: device)
                ),
                device: device
            ),
            with: device
        )

        var descs: [MTLAccelerationStructureGeometryDescriptor] = []

        mesh.submeshes.forEach { submesh in
            assert(submesh.primitiveType == .triangle)

            let desc = MTLAccelerationStructureTriangleGeometryDescriptor.init()

            do {
                desc.vertexFormat = .float3
                desc.vertexStride = MemoryLayout<SIMD3<Float>.Packed>.stride
                desc.vertexBuffer = mesh.vertexBuffers.first!.buffer
            }
            do {
                desc.indexType = .uint16
                desc.indexBuffer = mesh.submeshes.first!.indexBuffer.buffer
                desc.triangleCount = mesh.submeshes.first!.indexCount / 3
            }

            descs.append(desc)
        }

        return descs
    }
}

