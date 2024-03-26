// tomocy

kernel void add(
    device float* const result,
    constant float* const a, constant float* const b,
    const uint index [[thread_position_in_grid]]
) {
    result[index] = a[index] + b[index];
}
