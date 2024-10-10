#include<stdint.h>
#include "cuda_fp16.h"
#if __CUDA_ARCH__ >= 800
#include <cuda_bf16.h>
#endif

// Core repeat_kv function template for standard types
template<typename T>
__device__ void repeat_kv(
    const T* key_states, 
    const T* value_states,
    T* repeated_keys,
    T* repeated_values,
    const int n_local_heads,
    const int n_repeats,
    const int seqlen,
    const int head_dim
) {
    int seq_idx = blockIdx.x;
    int head_idx = blockIdx.y;
    int rep_idx = blockIdx.z;
    int dim_idx = threadIdx.x;

    int input_offset = head_idx * seqlen * head_dim + seq_idx * head_dim + dim_idx;
    int expanded_head_idx = head_idx * n_repeats + rep_idx;
    int output_offset = expanded_head_idx * seqlen * head_dim + seq_idx * head_dim + dim_idx;

    repeated_keys[output_offset] = key_states[input_offset];
    repeated_values[output_offset] = value_states[input_offset];
}

// Macro to define repeat_kv kernel for each type
#define REPEAT_KV_OP(TYPENAME, FN_NAME) \
extern "C" __global__ void FN_NAME( \
    const TYPENAME *key_states,      \
    const TYPENAME *value_states,    \
    TYPENAME *repeated_keys,         \
    TYPENAME *repeated_values,       \
    const int n_local_heads,         \
    const int n_repeats,             \
    const int seqlen,                \
    const int head_dim) {            \
    repeat_kv(key_states, value_states, repeated_keys, repeated_values, n_local_heads, n_repeats, seqlen, head_dim); \
}

REPEAT_KV_OP(float, repeat_kv_f32)
REPEAT_KV_OP(double, repeat_kv_f64)
REPEAT_KV_OP(uint8_t, repeat_kv_u8)
REPEAT_KV_OP(uint32_t, repeat_kv_u32)
REPEAT_KV_OP(int64_t, repeat_kv_i64)

#if __CUDA_ARCH__ >= 530
REPEAT_KV_OP(__half, repeat_kv_f16)
#endif

#if __CUDA_ARCH__ >= 800
REPEAT_KV_OP(__nv_bfloat16, repeat_kv_bf16)
#endif