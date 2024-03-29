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

            do {
                let raw = MDLMesh.init(
                    try! MDLMesh.load(
                        url: Bundle.main.url(
                            forResource: "Spot",
                            withExtension: "obj",
                            subdirectory: "Farm/Spot"
                        )!,
                        with: device
                    ).first!,
                    indexType: .uint16
                )

                primitive = raw.toPrimitive(with: device)
            }

            albedoTexture = try! MTKTextureLoader.init(device: device).newTexture(
                URL: Bundle.main.url(forResource: "Spot", withExtension: "png", subdirectory: "Farm/Spot")!
            )
        }

        var shader: Shader.Shader?
        var primitive: Shader.Primitive?
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
                shader.accelerator.encode(primitive!, to: command)
            }

            command.waitUntilCompleted()
        }

        do {
            let command = shader.commandQueue.makeCommandBuffer()!

            command.commit {
                shader.raytrace.encode(
                    to: command,
                    accelerator: shader.accelerator.target!,
                    albedoTexture: albedoTexture!
                )

                shader.echo.encode(
                    to: command,
                    as: currentRenderPassDescriptor!,
                    source: shader.raytrace.target.texture
                )

                shader.debug.encode(primitive!, to: command)

                command.present(currentDrawable!)
            }
        }
    }
}
