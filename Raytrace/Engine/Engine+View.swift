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

            shader = try! .init(device: device, resolution: drawableSize, format: .bgra8Unorm)

            primitives = []
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
                var primitive = raw.toPrimitive(
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
                primitive.pieces[0].material = .init(
                    albedo: try! MTKTextureLoader.init(device: device).newTexture(
                        URL: Bundle.main.url(forResource: "Spot", withExtension: "png", subdirectory: "Farm/Spot")!
                    )
                )

                primitives!.append(primitive)
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
                var primitive = raw.toPrimitive(
                    with: device,
                    instances: [
                        .init(
                            transform: .init(
                                translate: .init(0, 0, 0)
                            )
                        ),
                    ]
                )
                primitive.pieces[0].material = .init(
                    albedo: try! MTKTextureLoader.init(device: device).newTexture(
                        URL: Bundle.main.url(forResource: "Ground", withExtension: "png", subdirectory: "Farm/Ground")!
                    )
                )

                primitives!.append(primitive)
            }
        }

        var shader: Shader.Shader?
        var primitives: [Shader.Primitive]?
    }
}

extension Engine.View: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard var shader = shader else { return }

        do {
            let command = shader.commandQueue.makeCommandBuffer()!

            command.commit {
                for i in 0..<primitives!.count {
                    shader.accelerator.primitive.encode(&primitives![i], to: command)
                }

                shader.accelerator.instanced.encode(primitives!, to: command)
            }

            command.waitUntilCompleted()
        }

        do {
            let command = shader.commandQueue.makeCommandBuffer()!

            command.commit {
                shader.raytrace.encode(
                    primitives!,
                    to: command,
                    accelerator: shader.accelerator.instanced.target!
                )

                shader.echo.encode(
                    to: command,
                    as: currentRenderPassDescriptor!,
                    source: shader.raytrace.target.texture
                )

                shader.debug.encode(primitives!, to: command)

                command.present(currentDrawable!)
            }
        }
    }
}
