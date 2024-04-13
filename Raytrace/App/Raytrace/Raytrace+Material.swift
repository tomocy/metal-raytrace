// tomocy

import ModelIO
import Metal
import MetalKit

extension Raytrace {
    struct Material {
        var albedo: (any MTLTexture)?
        var metalRoughness: (any MTLTexture)?
    }
}

extension Raytrace.Material {
    init?(_ other: MDLMaterial?, device: some MTLDevice) throws {
        guard let other = other else { return nil }

        let textureLoader = MTKTextureLoader.init(device: device)

        if let url = other.property(with: .baseColor)?.urlValue {
            albedo = try textureLoader.newTexture(URL: url)
        }
    }
}

extension Raytrace.Material {
    struct ForGPU {
        var albedo: MTLResourceID = .init()
        var metalRoughness: MTLResourceID = .init()
    }
}
