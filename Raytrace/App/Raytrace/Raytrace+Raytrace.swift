// tomocy

import ModelIO
import Metal
import MetalKit

extension Raytrace {
    struct Raytrace {
        var pipelineStates: PipelineStates
        var args: Args

        var target: Target
        var seeds: any MTLTexture
        var background: Background
        var env: Env
    }
}

extension Raytrace.Raytrace {
    init(device: some MTLDevice, resolution: CGSize) throws {
        let lib = device.makeDefaultLibrary()!
        let fn = lib.makeFunction(name: "Raytrace::compute")!


        pipelineStates = .init(
            compute: try PipelineStates.make(with: device, for: fn)
        )

        args = .init()

        target = Self.make(with: device, resolution: resolution)!
        seeds = Self.makeSeeds(with: device, resolution: resolution)!

        background = try .init(device: device)
        env = try .init(device: device)
    }
}

extension Raytrace.Raytrace {
    static func make(
        with device: some MTLDevice,
        resolution: CGSize
    ) -> Target? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: .init(resolution.width), height: .init(resolution.height),
            mipmapped: false
        )

        desc.storageMode = .private
        desc.usage = [.shaderRead, .shaderWrite]

        guard let texture = device.makeTexture(descriptor: desc) else { return nil }

        texture.label = "Target"

        return .init(resolution: resolution, texture: texture)
    }
}

extension Raytrace.Raytrace {
    static func makeSeeds(
        with device: some MTLDevice,
        resolution: CGSize
    ) -> (any MTLTexture)? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r32Uint,
            width: .init(resolution.width), height: .init(resolution.height),
            mipmapped: false
        )

        desc.storageMode = .managed
        desc.usage = [.shaderRead, .shaderWrite]

        guard let texture = device.makeTexture(descriptor: desc) else { return nil }

        texture.label = "Seeds"

        let count = desc.width * desc.height

        var seeds: [UInt32] = []
        seeds.reserveCapacity(count)

        for _ in 0..<count {
            seeds.append(.random(in: 0...UInt32.max))
        }

        seeds.withUnsafeBytes { bytes in
            texture.replace(
                region: MTLRegionMake2D(0, 0, desc.width, desc.height),
                mipmapLevel: 0,
                withBytes: bytes.baseAddress!,
                bytesPerRow: MemoryLayout<UInt32>.stride * desc.width
            )
        }

        return texture
    }
}

extension Raytrace.Raytrace {
    static func makeBackground(with device: some MTLDevice) throws -> any MTLTexture {
        // We know the background texture for now.
        return try MTKTextureLoader.init(device: device).newTexture(
            URL: Bundle.main.url(forResource: "Env", withExtension: "png", subdirectory: "Farm/Env")!,
            options: [
                .textureUsage: MTLTextureUsage.shaderRead.rawValue,
                .textureStorageMode: MTLStorageMode.private.rawValue,
                .cubeLayout: MTKTextureLoader.CubeLayout.vertical.rawValue,
                .generateMipmaps: true,
            ]
        )
    }
}

extension Raytrace.Raytrace {
    func buildContext(
        to buffer: some MTLCommandBuffer,
        frame: Raytrace.Frame,
        seeds: some MTLTexture,
        background: Raytrace.Background,
        env: Raytrace.Env,
        acceleration: Raytrace.Acceleration
    ) -> MTLOnHeap<some MTLBuffer> {
        let encoder = buffer.makeBlitCommandEncoder()!
        defer { encoder.endEncoding() }

        let heap = ({
            let desc = MTLHeapDescriptor.init()

            desc.storageMode = .private

            // Frame
            desc.size += MemoryLayout<Raytrace.Frame>.stride

            // Seeds
            do {
                let sizeAlign = encoder.device.heapTextureSizeAndAlign(descriptor: seeds.descriptor)
                desc.size += sizeAlign.aligned
            }

            // Background
            do {
                do {
                    let sizeAlign = encoder.device.heapTextureSizeAndAlign(descriptor: background.source.descriptor)
                    desc.size += sizeAlign.aligned
                }

                desc.size += MemoryLayout<Raytrace.Background.ForGPU>.stride
            }

            // Env
            do {
                do {
                    let sizeAlign = encoder.device.heapTextureSizeAndAlign(descriptor: env.diffuse.descriptor)
                    desc.size += sizeAlign.aligned
                }
                do {
                    let sizeAlign = encoder.device.heapTextureSizeAndAlign(descriptor: env.specular.descriptor)
                    desc.size += sizeAlign.aligned
                }
                do {
                    let sizeAlign = encoder.device.heapTextureSizeAndAlign(descriptor: env.lut.descriptor)
                    desc.size += sizeAlign.aligned
                }

                desc.size += MemoryLayout<Raytrace.Env.ForGPU>.stride
            }

            // Acceleration
            do {
                do {
                    acceleration.meshes.forEach { mesh in
                        do {
                            mesh.pieces.forEach { piece in
                                do {
                                    if let texture = piece.material?.albedo {
                                        let sizeAlign = encoder.device.heapTextureSizeAndAlign(descriptor: texture.descriptor)
                                        desc.size += sizeAlign.aligned
                                    }
                                    if let texture = piece.material?.metalRoughness {
                                        let sizeAlign = encoder.device.heapTextureSizeAndAlign(descriptor: texture.descriptor)
                                        desc.size += sizeAlign.aligned
                                    }

                                    desc.size += MemoryLayout<Raytrace.Material.ForGPU>.stride
                                }
                            }

                            desc.size += MemoryLayout<Raytrace.Mesh.Piece.ForGPU>.stride * mesh.pieces.count
                        }
                    }

                    desc.size += MemoryLayout<Raytrace.Mesh.ForGPU>.stride * acceleration.meshes.count
                }

                desc.size += MemoryLayout<Raytrace.Primitive.Instance>.stride * acceleration.primitives.count

                desc.size += MemoryLayout<Raytrace.Acceleration.ForGPU>.stride
            }

            desc.size += MemoryLayout<Args.Context.ForGPU>.stride

            return encoder.device.makeHeap(descriptor: desc)
        }) ()!

        var context = Args.Context.ForGPU.init(
            frame: 0,
            seeds: .init(),
            background: 0,
            env: .init(),
            acceleration: 0
        )

        // Frame
        do {
            let onDevice = Raytrace.Metal.bufferBuildable(frame).build(
                with: encoder.device,
                label: "Raytrace/Context/Frame",
                options: .storageModeShared
            )!

            let onHeap = withUnsafeBytes(of: frame) { bytes in
                heap.makeBuffer(
                    length: bytes.count,
                    options: .storageModePrivate
                )
            }!
            onHeap.label = onDevice.label

            context.frame = onHeap.gpuAddress

            encoder.copy(
                from: onDevice, sourceOffset: 0,
                to: onHeap, destinationOffset: 0,
                size: onHeap.length
            )
        }

        // Seeds
        do {
            let desc = seeds.descriptor
            desc.storageMode = .private

            let onHeap = heap.makeTexture(descriptor: desc)!
            onHeap.label = seeds.label

            context.seeds = onHeap.gpuResourceID

            encoder.copy(from: seeds, to: onHeap)
        }

        // Background
        do {
            let source = ({
                let desc = background.source.descriptor
                desc.storageMode = .private

                let onHeap = heap.makeTexture(descriptor: desc)!
                onHeap.label = background.source.label

                encoder.copy(from: background.source, to: onHeap)

                return onHeap
            }) ()

            let background = Raytrace.Background.ForGPU.init(
                source: source.gpuResourceID
            )

            let onDevice = Raytrace.Metal.bufferBuildable(background).build(
                with: encoder.device,
                label: "Raytrace/Context/Background",
                options: .storageModeShared
            )!

            let onHeap = withUnsafeBytes(of: background) { bytes in
                heap.makeBuffer(
                    length: bytes.count,
                    options: .storageModePrivate
                )
            }!
            onHeap.label = onDevice.label

            context.background = onHeap.gpuAddress

            encoder.copy(
                from: onDevice, sourceOffset: 0,
                to: onHeap, destinationOffset: 0,
                size: onHeap.length
            )
        }

        // Env
        do {
            let diffuse = ({
                let desc = env.diffuse.descriptor
                desc.storageMode = .private

                let onHeap = heap.makeTexture(descriptor: desc)!
                onHeap.label = env.diffuse.label

                encoder.copy(from: env.diffuse, to: onHeap)

                return onHeap
            }) ()

            let specular = ({
                let desc = env.specular.descriptor
                desc.storageMode = .private

                let onHeap = heap.makeTexture(descriptor: desc)!
                onHeap.label = env.specular.label

                encoder.copy(from: env.specular, to: onHeap)

                return onHeap
            }) ()

            let lut = ({
                let desc = env.lut.descriptor
                desc.storageMode = .private

                let onHeap = heap.makeTexture(descriptor: desc)!
                onHeap.label = env.lut.label

                encoder.copy(from: env.lut, to: onHeap)

                return onHeap
            }) ()

            let env = Raytrace.Env.ForGPU.init(
                diffuse: diffuse.gpuResourceID,
                specular: specular.gpuResourceID,
                lut: lut.gpuResourceID
            )

            let onDevice = Raytrace.Metal.bufferBuildable(env).build(
                with: encoder.device,
                label: "Raytrace/Context/Env",
                options: .storageModeShared
            )!

            let onHeap = withUnsafeBytes(of: env) { bytes in
                heap.makeBuffer(
                    length: bytes.count,
                    options: .storageModePrivate
                )
            }!
            onHeap.label = onDevice.label

            context.env = onHeap.gpuAddress

            encoder.copy(
                from: onDevice, sourceOffset: 0,
                to: onHeap, destinationOffset: 0,
                size: onHeap.length
            )
        }

        // Acceleration
        do {
            let meshes = ({
                let forGPU = acceleration.meshes.map { mesh in
                    let pieces = ({
                        let forGPU = mesh.pieces.map { piece in
                            let material = ({
                                var forGPU = Raytrace.Material.ForGPU.init()

                                if let texture = piece.material?.albedo {
                                    let desc = texture.descriptor
                                    desc.storageMode = .private

                                    let onHeap = heap.makeTexture(descriptor: desc)!
                                    onHeap.label = texture.label

                                    forGPU.albedo = onHeap.gpuResourceID

                                    encoder.copy(from: texture, to: onHeap)
                                }

                                if let texture = piece.material?.metalRoughness {
                                    let desc = texture.descriptor
                                    desc.storageMode = .private

                                    let onHeap = heap.makeTexture(descriptor: desc)!
                                    onHeap.label = texture.label

                                    forGPU.metalRoughness = onHeap.gpuResourceID

                                    encoder.copy(from: texture, to: onHeap)
                                }

                                let onDevice = Raytrace.Metal.bufferBuildable(forGPU).build(
                                    with: encoder.device,
                                    label: "Raytrace/Context/Acceleration/Mesh/Piece/Material",
                                    options: .storageModeShared
                                )!

                                let onHeap = withUnsafeBytes(of: forGPU) { bytes in
                                    heap.makeBuffer(
                                        length: bytes.count,
                                        options: .storageModePrivate
                                    )
                                }!
                                onHeap.label = onDevice.label

                                encoder.copy(
                                    from: onDevice, sourceOffset: 0,
                                    to: onHeap, destinationOffset: 0,
                                    size: onHeap.length
                                )

                                return onHeap
                            }) ()

                            return Raytrace.Mesh.Piece.ForGPU.init(
                                material: material.gpuAddress
                            )
                        }

                        let onDevice = Raytrace.Metal.bufferBuildable(forGPU).build(
                            with: encoder.device,
                            label: "Raytrace/Context/Acceleration/Mesh/Pieces",
                            options: .storageModeShared
                        )!

                        let onHeap = forGPU.withUnsafeBytes { bytes in
                            heap.makeBuffer(
                                length: bytes.count,
                                options: .storageModePrivate
                            )
                        }!
                        onHeap.label = onDevice.label

                        encoder.copy(
                            from: onDevice, sourceOffset: 0,
                            to: onHeap, destinationOffset: 0,
                            size: onHeap.length
                        )

                        return onHeap
                    }) ()

                    return Raytrace.Mesh.ForGPU.init(
                        pieces: pieces.gpuAddress
                    )
                }

                let onDevice = Raytrace.Metal.bufferBuildable(forGPU).build(
                    with: encoder.device,
                    label: "Raytrace/Context/Acceleration/Meshes",
                    options: .storageModeShared
                )!

                let onHeap = forGPU.withUnsafeBytes { bytes in
                    heap.makeBuffer(
                        length: bytes.count,
                        options: .storageModePrivate
                    )
                }!
                onHeap.label = onDevice.label

                encoder.copy(
                    from: onDevice, sourceOffset: 0,
                    to: onHeap, destinationOffset: 0,
                    size: onHeap.length
                )

                return onHeap
            }) ()

            let primitives = ({
                let onDevice = Raytrace.Metal.bufferBuildable(acceleration.primitives).build(
                    with: encoder.device,
                    label: "Raytrace/Context/Acceleration/Primitives",
                    options: .storageModeShared
                )!

                let onHeap = acceleration.primitives.withUnsafeBytes { bytes in
                    heap.makeBuffer(
                        length: bytes.count,
                        options: .storageModePrivate
                    )
                }!
                onHeap.label = onDevice.label

                encoder.copy(
                    from: onDevice, sourceOffset: 0,
                    to: onHeap, destinationOffset: 0,
                    size: onHeap.length
                )

                return onHeap
            }) ()

            let acceleration = Raytrace.Acceleration.ForGPU.init(
                structure: acceleration.structure.gpuResourceID,
                meshes: meshes.gpuAddress,
                primitives: primitives.gpuAddress
            )

            let onDevice = Raytrace.Metal.bufferBuildable(acceleration).build(
                with: encoder.device,
                label: "Raytrace/Context/Acceleration/Meshes",
                options: .storageModeShared
            )!

            let onHeap = withUnsafeBytes(of: acceleration) { bytes in
                heap.makeBuffer(
                    length: bytes.count,
                    options: .storageModePrivate
                )
            }!
            onHeap.label = onDevice.label

            context.acceleration = onHeap.gpuAddress

            encoder.copy(
                from: onDevice, sourceOffset: 0,
                to: onHeap, destinationOffset: 0,
                size: onHeap.length
            )
        }

        let onDevice = Raytrace.Metal.bufferBuildable(context).build(
            with: encoder.device,
            label: "Raytrace/Context",
            options: .storageModeShared
        )!

        let onHeap = withUnsafeBytes(of: context) { bytes in
            heap.makeBuffer(
                length: bytes.count,
                options: .storageModePrivate
            )
        }!
        onHeap.label = onDevice.label

        encoder.copy(
            from: onDevice, sourceOffset: 0,
            to: onHeap, destinationOffset: 0,
            size: onHeap.length
        )

        return .init(value: onHeap, heap: heap)
    }

    func encode(
        to buffer: some MTLCommandBuffer,
        context: MTLOnHeap<some MTLBuffer>
    ) {
        let encoder = buffer.makeComputeCommandEncoder()!
        defer { encoder.endEncoding() }

        encoder.setComputePipelineState(pipelineStates.compute)

        do {
            encoder.useHeap(context.heap)

            let args = Args.ForGPU.init(
                target: target.texture.gpuResourceID,
                context: context.value.gpuAddress
            )

            let buffer = Raytrace.Metal.bufferBuildable(args).build(
                with: encoder.device,
                label: "Raytrace/Args",
                options: .storageModeShared
            )!

            encoder.setBuffer(buffer, offset: 0, index: 0)
        }

        do {
            let threadsSizePerGroup = MTLSize.init(width: 8, height: 8, depth: 1)
            let threadsGroupSize = MTLSize.init(
                width: Int(target.resolution.width).align(by: threadsSizePerGroup.width) / threadsSizePerGroup.width,
                height: Int(target.resolution.height).align(by: threadsSizePerGroup.height) / threadsSizePerGroup.height,
                depth: threadsSizePerGroup.depth
            )

            encoder.dispatchThreadgroups(
                threadsGroupSize,
                threadsPerThreadgroup: threadsSizePerGroup
            )
        }
    }
}

extension Raytrace.Raytrace {
    struct Target {
        var resolution: CGSize
        var texture: any MTLTexture
    }
}

extension Raytrace.Raytrace {
    struct PipelineStates {
        var compute: any MTLComputePipelineState
    }
}

extension Raytrace.Raytrace.PipelineStates {
    static func make(with device: some MTLDevice, for function: some MTLFunction) throws -> some MTLComputePipelineState {
        return try device.makeComputePipelineState(
            function: function
        )
    }
}

extension Raytrace.Raytrace {
    struct Args {}
}

extension Raytrace.Raytrace.Args {
    struct ForGPU {
        var target: MTLResourceID
        var context: UInt64
    }
}

extension Raytrace.Raytrace.Args.ForGPU {
    init(
        encoder: some MTLComputeCommandEncoder,
        target: some MTLTexture,
        context: Raytrace.Raytrace.Args.Context.ForGPU
    ) {
        self.target = target.gpuResourceID

        do {
            let buffer = Raytrace.Metal.bufferBuildable(context).build(
                with: encoder.device,
                label: "Raytrace/Args/Context",
                options: .storageModeShared
            )!

            self.context = buffer.gpuAddress
        }
    }
}

extension Raytrace.Raytrace.Args {
    struct Context {}
}

extension Raytrace.Raytrace.Args.Context {
    struct ForGPU {
        var frame: UInt64
        var seeds: MTLResourceID
        var background: UInt64
        var env: UInt64
        var acceleration: UInt64
    }
}
