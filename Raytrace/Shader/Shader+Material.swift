// tomocy

import ModelIO
import Metal
import MetalKit

extension Shader {
    struct Material {
        var albedo: (any MTLTexture)?
        var metalness: (any MTLTexture)?
    }
}

extension Shader.Material {
    init?(_ other: MDLMaterial?, device: some MTLDevice) throws {
        guard let other = other else { return nil }

        let textureLoader = MTKTextureLoader.init(device: device)

        if let url = other.property(with: .baseColor)?.urlValue {
            albedo = try textureLoader.newTexture(URL: url)
        }
    }
}
