// tomocy

#pragma once

#include "../Coordinate.h"
#include <metal_stdlib>

namespace Shader {
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
    Coordinate::Face faceFor(const thread Coordinate::InScreen& coordinate) constant
    {
        return Coordinate::Face(coordinate.value().y / size());
    }

    Coordinate::InFace coordinateInFace(const thread Coordinate::InScreen& coordinate) constant
    {
        return Coordinate::InFace::from(coordinate, size());
    }

public:
    metal::vec<T, 4> readInFace(const thread Coordinate::InScreen& coordinate) constant
    {
        return raw().read(coordinateInFace(coordinate).value(), uint(faceFor(coordinate)));
    }

    void writeInFace(
        const thread metal::vec<T, 4>& color,
        const thread Coordinate::InScreen& coordinate,
        const uint lod = 0
    ) constant
    {
        raw().write(color, coordinateInFace(coordinate).value(), uint(faceFor(coordinate)), lod);
    }
};
}
}
