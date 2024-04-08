// tomocy

import Metal
import MetalKit

let (args, error) = App.Args.parse(CommandLine.arguments)
guard let args = args else {
    print(error!)
    exit(1)
}

let device = MTLCreateSystemDefaultDevice()!

let app = try App.init(args: args, device: device)

try await MTLFrameCapture.capture(for: device, if: args.capturesFrame) {
    try await app.preLight()
}

try await app.save()
