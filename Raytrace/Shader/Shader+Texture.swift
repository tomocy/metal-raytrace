// tomocy

import Foundation
import Metal
import MetalKit

extension Shader {
    struct Texture {}
}

extension Shader.Texture {
    static func load(from url: URL, with device: some MTLDevice) throws -> some MTLTexture {
        return try MTKTextureLoader.init(device: device).newTexture(
            URL: url
        )
    }
}
