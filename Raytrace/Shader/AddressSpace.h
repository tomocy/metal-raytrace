// tomocy

#pragma once

namespace Shader {
namespace AddressSpace {
struct Thread {
public:
    template <typename T>
    static thread T from(const constant T& value) { return value; }
};
}
}
