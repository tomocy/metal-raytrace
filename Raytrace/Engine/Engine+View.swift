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

            mesh = try! MTKMesh.init(
                mesh: try! MDLMesh.load(
                    url: Bundle.main.url(
                        forResource: "Spot",
                        withExtension: "obj",
                        subdirectory: "Farm/Spot"
                    )!,
                    with: device
                ).first!.toP_N_T(
                    with: device,
                    indexType: .uInt16
                ),
                device: device
            )

            albedoTexture = try! MTKTextureLoader.init(device: device).newTexture(
                URL: Bundle.main.url(forResource: "Spot", withExtension: "png", subdirectory: "Farm/Spot")!
            )
        }

        var shader: Shader.Shader?
        var mesh: MTKMesh?
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
                shader.accelerator.encode(mesh!, to: command)
            }

            command.waitUntilCompleted()
        }

        do {
            let command = shader.commandQueue.makeCommandBuffer()!

            command.commit {
                shader.raytrace.encode(
                    mesh!,
                    to: command,
                    accelerator: shader.accelerator.target!,
                    albedoTexture: albedoTexture!
                )

                shader.echo.encode(
                    to: command,
                    as: currentRenderPassDescriptor!,
                    source: shader.raytrace.target.texture
                )

                shader.debug.encode(mesh!, to: command)

                command.present(currentDrawable!)
            }
        }
    }
}
