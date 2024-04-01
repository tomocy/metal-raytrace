// tomocy

template <typename T>
T interpolate(
    const T a, // origin
    const T b,
    const float position
) {
    return (1 - position) * a + position * b;
}

template <typename T>
T interpolate(
    const T a, // origin
    const T b,
    const T c,
    const float2 position
) {
    return (1 - position.x - position.y) * a + position.x * b + position.y * c;
}
