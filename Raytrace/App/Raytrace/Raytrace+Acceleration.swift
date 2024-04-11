// tomocy

import Metal

extension Raytrace {
    struct Acceleration {
        var structure: any MTLAccelerationStructure
        var meshes: [Mesh]
        var instances: [Primitive.Instance]
    }
}

extension Raytrace.Acceleration {
    func encode(
        with encoder: MTLComputeArgumentEncoder,
        at index: Int,
        label: String? = nil,
        usage: MTLResourceUsage
    ) {
        let buffer: some MTLBuffer = ({
            let encoder = encoder.make(for: index)!

            let buffer: some MTLBuffer = encoder.make(label: label)!
            encoder.compute.useResource(buffer, usage: .read)

            encode(with: encoder, to: buffer, usage: .read)

            return buffer
        }) ()

        encoder.argument.setBuffer(buffer, offset: 0, index: index)
    }

    func encode(with encoder: MTLComputeArgumentEncoder, to buffer: some MTLBuffer, usage: MTLResourceUsage) {
        encoder.argument.setArgumentBuffer(buffer, offset: 0)

        structure.encode(with: encoder, at: 0, usage: usage)

        do {
            let buffer = encode(
                with: encoder.make(for: 1)!,
                for: meshes,
                label: "Meshes?Count=\(meshes.count)"
            )!

            encoder.argument.setBuffer(buffer, offset: 0, index: 1)
        }

        do {
            let buffer = Raytrace.Metal.bufferBuildable(instances).build(
                with: encoder.compute.device,
                label: "Instances?Count=\(instances.count)",
                options: .storageModeShared
            )!

            buffer.encode(with: encoder, at: 2, usage: usage)
        }
    }

    private func encode(with encoder: MTLComputeArgumentEncoder, for meshes: [Raytrace.Mesh], label: String) -> (any MTLBuffer)? {
        guard let buffer = encoder.compute.device.makeBuffer(
            length: encoder.argument.encodedLength * meshes.count
        ) else { return nil }

        buffer.label = label

        encoder.compute.useResource(buffer, usage: .read)

        meshes.enumerated().forEach { i, mesh in
            encoder.argument.setArgumentBuffer(
                buffer,
                offset: encoder.argument.encodedLength * i
            )

            do {
                let buffer = encode(
                    with: .init(
                        compute: encoder.compute,
                        argument: encoder.argument.makeArgumentEncoderForBuffer(atIndex: 0)!
                    ),
                    for: mesh.pieces,
                    of: i,
                    label: "Pieces?Mesh=\(i)&Count=\(mesh.pieces.count)"
                )

                encoder.argument.setBuffer(buffer, offset: 0, index: 0)
            }
        }

        return buffer
    }

    private func encode(
        with encoder: MTLComputeArgumentEncoder,
        for pieces: [Raytrace.Mesh.Piece], of meshID: Int,
        label: String
    ) -> (any MTLBuffer)? {
        guard let buffer = encoder.compute.device.makeBuffer(
            length: encoder.argument.encodedLength * pieces.count
        ) else { return nil }

        buffer.label = label

        encoder.compute.useResource(buffer, usage: .read)

        pieces.enumerated().forEach { i, piece in
            encoder.argument.setArgumentBuffer(
                buffer,
                offset: encoder.argument.encodedLength * i
            )

            if let texture = piece.material?.albedo {
                texture.label = "Albedo?Mesh=\(meshID)&Piece=\(i)"

                encoder.compute.useResource(texture, usage: .read)
                encoder.argument.setTexture(texture, index: 0)
            }

            if let texture = piece.material?.metalRoughness {
                texture.label = "MetalRoughness?Mesh=\(meshID)&Piece=\(i)"

                encoder.compute.useResource(texture, usage: .read)
                encoder.argument.setTexture(texture, index: 1)
            }
        }

        return buffer
    }
}
