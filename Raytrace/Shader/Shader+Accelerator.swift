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
    mutating func encode(_ mesh: MTKMesh, to buffer: some MTLCommandBuffer) {
        let encoder = buffer.makeAccelerationStructureCommandEncoder()!
        defer { encoder.endEncoding() }

        let desc = ({
            let desc = MTLPrimitiveAccelerationStructureDescriptor.init()

            desc.geometryDescriptors = describe(mesh, with: encoder.device)

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

    private func describe(_ mesh: MTKMesh, with device: some MTLDevice) -> [MTLAccelerationStructureGeometryDescriptor] {
        var descs: [MTLAccelerationStructureGeometryDescriptor] = []

        mesh.submeshes.forEach { submesh in
            assert(submesh.primitiveType == .triangle)

            let desc = MTLAccelerationStructureTriangleGeometryDescriptor.init()

            do {
                // We assume that
                // the vertices is laid out in MTKMesh.Vertex.OnlyPositions.
                MTKMesh.Vertex.OnlyPositions.describe(to: desc)

                desc.vertexBuffer = submesh.mesh!.vertexBuffers.first!.buffer
            }
            do {
                desc.indexType = submesh.indexType
                desc.indexBuffer = submesh.indexBuffer.buffer
                desc.triangleCount = submesh.indexCount / 3
            }

            descs.append(desc)
        }

        return descs
    }
}

