// tomocy

#pragma once

#include <metal_stdlib>

namespace Texture {
template <typename T, metal::access Access>
struct Cube {
public:
    using Raw = metal::texturecube<T, Access>;

public:
    thread Raw& raw() { return raw_; }
    constant Raw& raw() constant { return raw_; }

private:
    Raw raw_;

public:
    uint size() constant { return raw().get_width(); }

public:
    uint faceFor(const thread uint2& coordinate) constant {
        return coordinate.y / size();
    }

    uint2 coordinateInFace(const thread uint2& coordinate) constant {
        return coordinate % size();
    }

public:
    metal::vec<T, 4> readInFace(const thread uint2& coordinate) constant {
        return raw().read(coordinateInFace(coordinate), faceFor(coordinate));
    }

    void writeInFace(const thread metal::vec<T, 4>& color, const thread uint2& coordinate, const uint lod = 0) constant {
        raw().write(color, coordinateInFace(coordinate), faceFor(coordinate), lod);
    }
};
}
