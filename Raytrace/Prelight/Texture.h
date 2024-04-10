// tomocy

#pragma once

#include "../ShaderX/Coordinate.h"
#include <metal_stdlib>

namespace Texture {
template <typename T, metal::access Access>
struct Cube {
public:
    using Raw = metal::texturecube<T, Access>;

public:
    thread Raw& raw() { return raw_; }
    const thread Raw& raw() const { return raw_; }
    constant Raw& raw() constant { return raw_; }

private:
    Raw raw_;

public:
    uint size() constant { return raw().get_width(); }

public:
    ShaderX::Coordinate::Face faceFor(const thread ShaderX::Coordinate::InScreen& coordinate) constant
    {
        return ShaderX::Coordinate::Face(coordinate.value().y / size());
    }

    ShaderX::Coordinate::InFace coordinateInFace(const thread ShaderX::Coordinate::InScreen& coordinate) constant
    {
        return ShaderX::Coordinate::InFace::from(coordinate, size());
    }

public:
    metal::vec<T, 4> readInFace(const thread ShaderX::Coordinate::InScreen& coordinate) constant
    {
        return raw().read(coordinateInFace(coordinate).value(), uint(faceFor(coordinate)));
    }

    void writeInFace(
        const thread metal::vec<T, 4>& color,
        const thread ShaderX::Coordinate::InScreen& coordinate,
        const uint lod = 0
    ) constant
    {
        raw().write(color, coordinateInFace(coordinate).value(), uint(faceFor(coordinate)), lod);
    }
};
}
