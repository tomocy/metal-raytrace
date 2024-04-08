// tomocy

import Metal

struct Prelight {
    var diffuse: Diffuse
}

extension Prelight {
    struct Targets {
        var cube: any MTLTexture
        var d2: any MTLTexture
    }
}
