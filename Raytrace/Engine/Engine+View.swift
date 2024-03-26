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

            shader = try! .init(device: device)
        }

        var shader: Shader.Shader?
    }
}

extension Engine.View: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let shader = shader else { return }

        let command = shader.commandQueue.makeCommandBuffer()!

        command.commit {
            let count = 128
            let a = generate(for: count)
            let b = generate(for: count)
            let result = shader.add.encode(to: command, a: a, b: b)

            command.addCompletedHandler { [weak self] _ in
                guard let self = self else { return }
                self.print(result: result, a: a, b: b)
            }
        }
    }

    private func generate(for count: Int) -> [Float] {
        var values: [Float] = []
        values.reserveCapacity(count)

        for _ in 0..<count {
            values.append(
                .random(in: 0...10)
            )
        }

        return values
    }

    private func print(result: some MTLBuffer, a: [Float], b: [Float]) {
        assert(a.count == b.count)
        let count = a.count

        let x: [Float] = .init(
            UnsafeBufferPointer<Float>.init(
                start: result.contents().withMemoryRebound(to: Float.self, capacity: count) { $0 },
                count: count
            )
        )
        assert(x.count == count)

        NSLog("-----")
        for i in 0..<count {
            let (a, b, x) = (a[i], b[i], x[i])
            let passes = (a + b).isEqual(to: x)

            NSLog("\(passes ? "PASS" : "FAIL"): \(a) + \(b) == \(x)")
        }
    }
}
