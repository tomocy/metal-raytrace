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

            meshes = []
            do {
                let raw = MDLMesh.init(
                    try! .load(
                        url: Bundle.main.url(
                            forResource: "Spot",
                            withExtension: "obj",
                            subdirectory: "Farm/Spot"
                        )!,
                        with: device
                    ).first!,
                    indexType: .uint16
                )
                let mesh = try! raw.toMesh(
                    with: device,
                    instances: [
                        .init(
                            transform: .init(
                                translate: .init(-0.5, 0, 0)
                            )
                        ),
                        .init(
                            transform: .init(
                                translate: .init(0.5, 0, 0)
                            )
                        ),
                    ]
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
                    )
                )

                meshes!.append(mesh)
            }

            renderFrame = .init(id: 0)
        }

        var shader: Shader.Shader?
        var meshes: [Shader.Mesh]?

        var renderFrame: Shader.Frame?
    }
}

extension Engine.View: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard var shader = shader else { return }

        do {
            let command = shader.commandQueue.makeCommandBuffer()!

            command.commit {
                for i in 0..<meshes!.count {
                    shader.accelerator.primitive.encode(&meshes![i], to: command)
                }

                shader.accelerator.instanced.encode(meshes!, to: command)
            }

            command.waitUntilCompleted()
        }

        do {
            let command = shader.commandQueue.makeCommandBuffer()!

            command.commit {
                shader.raytrace.encode(
                    meshes!,
                    to: command,
                    frame: renderFrame!,
                    accelerator: shader.accelerator.instanced.target!,
                    instances: shader.accelerator.instanced.instances!
                )

                shader.echo.encode(
                    to: command,
                    as: currentRenderPassDescriptor!,
                    source: shader.raytrace.target.texture
                )

                shader.debug.encode(meshes!, to: command)

                command.present(currentDrawable!)
            }
        }

        renderFrame!.id += 1
    }
}
