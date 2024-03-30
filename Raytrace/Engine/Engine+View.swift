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

                primitives!.append(
                    raw.toPrimitive(
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
                )
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

                primitives!.append(
                    raw.toPrimitive(
                        with: device,
                        instances: [
                            .init(
                                transform: .init(
                                    translate: .init(0, 0, 0)
                                )
                            ),
                        ]
                    )
                )
            }

            albedoTexture = try! MTKTextureLoader.init(device: device).newTexture(
                URL: Bundle.main.url(forResource: "Spot", withExtension: "png", subdirectory: "Farm/Spot")!
            )
        }

        var shader: Shader.Shader?
        var primitives: [Shader.Primitive]?
        var albedoTexture: (any MTLTexture)?
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
                    to: command,
                    accelerator: shader.accelerator.instanced.target!,
                    albedoTexture: albedoTexture!
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
