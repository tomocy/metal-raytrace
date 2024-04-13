// tomocy

import Metal
import MetalKit

extension Engine {
    class View: MTKView {
        required init(coder: NSCoder) { super.init(coder: coder) }

        init(
            device: some MTLDevice,
            size: CGSize
        ) {
            super.init(
                frame: .init(
                    origin: .init(x: 0, y: 0),
                    size: size
                ),
                device: device
            )

            delegate = self

            colorPixelFormat = .rgba8Unorm_srgb
            shader = try! .init(device: device, resolution: drawableSize, format: colorPixelFormat)

            do {
                meshes = []

                do {
                    let raw = MDLMesh.init(
                        try! .load(
                            url: Bundle.main.url(forResource: "Spot", withExtension: "obj", subdirectory: "Farm/Spot")!,
                            with: device
                        ).first!,
                        indexType: .uint16
                    )

                    do {
                        var mesh = try! raw.toMesh(
                            with: device,
                            instances: [
                                .init(
                                    transform: .init(
                                        translate: .init(-0.5, 0, 0)
                                    )
                                ),
                            ]
                        )
                        mesh.pieces[0].material = .init(
                            albedo: mesh.pieces[0].material?.albedo,
                            metalRoughness: try! Raytrace.Texture.fill(
                                .init(red: 1, green: 0.5, blue: 0, alpha: 0),
                                with: device
                            )
                        )

                        meshes!.append(mesh)
                    }

                    do {
                        var mesh = try! raw.toMesh(
                            with: device,
                            instances: [
                                .init(
                                    transform: .init(
                                        translate: .init(0.5, 0, 0)
                                    )
                                ),
                            ]
                        )
                        mesh.pieces[0].material = .init(
                            albedo: mesh.pieces[0].material?.albedo,
                            metalRoughness: try! Raytrace.Texture.fill(
                                .init(red: 0, green: 1, blue: 0, alpha: 0),
                                with: device
                            )
                        )

                        meshes!.append(mesh)
                    }
                }

                do {
                    let raw = MDLMesh.init(
                        .init(
                            sphereWithExtent: .init(0.4, 0.4, 0.4),
                            segments: .init(24, 24),
                            inwardNormals: false,
                            geometryType: .triangles,
                            allocator: MTKMeshBufferAllocator.init(device: device)
                        ),
                        indexType: .uint16
                    )

                    var mesh = try! raw.toMesh(
                        with: device,
                        instances: [
                            .init(
                                transform: .init(
                                    translate: .init(0, 0.8, 0.8)
                                )
                            ),
                        ]
                    )
                    mesh.pieces[0].material = .init(
                        albedo: try! Raytrace.Texture.fill(
                            .init(red: 1, green: 0.75, blue: 0.25, alpha: 1),
                            with: device
                        ),
                        metalRoughness: try! Raytrace.Texture.fill(
                            .init(red: 1, green: 0.5, blue: 0, alpha: 0),
                            with: device
                        )
                    )

                    meshes!.append(mesh)
                }

                do {
                    let raw = MDLMesh.init(
                        .init(
                            planeWithExtent: .init(4, 0, 4),
                            segments: .init(1, 1),
                            geometryType: .triangles,
                            allocator: MTKMeshBufferAllocator.init(device: device)
                        ),
                        indexType: .uint16
                    )

                    var mesh = try! raw.toMesh(
                        with: device,
                        instances: [
                            .init(
                                transform: .init(
                                    translate: .init(0, 0, 0)
                                )
                            ),
                        ]
                    )
                    mesh.pieces[0].material = .init(
                        albedo: try! MTKTextureLoader.init(device: device).newTexture(
                            URL: Bundle.main.url(forResource: "Ground", withExtension: "png", subdirectory: "Farm/Ground")!
                        ),
                        metalRoughness: try! Raytrace.Texture.fill(
                            .init(red: 0, green: 1, blue: 0, alpha: 0),
                            with: device
                        )
                    )

                    meshes!.append(mesh)
                }
            }

            renderFrame = .init(id: 0)

            do {
                let command = shader!.commandQueue.makeCommandBuffer()!

                command.commit {
                    for i in 0..<meshes!.count {
                        shader!.accelerator.primitive.encode(&meshes![i], to: command)
                    }

                    shader!.accelerator.instanced.encode(meshes!, to: command)
                }

                command.waitUntilCompleted()
            }
        }

        var shader: Raytrace.Shader?
        var meshes: [Raytrace.Mesh]?

        var renderFrame: Raytrace.Frame?
    }
}

extension Engine.View: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let shader = shader else { return }

        let acceleration = Raytrace.Acceleration.init(
            structure: shader.accelerator.instanced.target!,
            meshes: meshes!,
            primitives: shader.accelerator.instanced.primitives!
        )

        do {
            let command = shader.commandQueue.makeCommandBuffer()!

            command.commit {
                let (heap, context) = shader.raytrace.buildContext(
                    to: command,
                    frame: renderFrame!,
                    seeds: shader.raytrace.seeds,
                    background: shader.raytrace.background,
                    env: shader.raytrace.env,
                    acceleration: acceleration
                )

                shader.raytrace.encode(
                    meshes!,
                    to: command,
                    heap: heap,
                    context: context,
                    frame: renderFrame!,
                    acceleration: acceleration
                )

                shader.echo.encode(
                    to: command,
                    as: currentRenderPassDescriptor!,
                    source: shader.raytrace.target.texture
                )

                command.present(currentDrawable!)
            }
        }

        renderFrame!.id += 1
    }
}
