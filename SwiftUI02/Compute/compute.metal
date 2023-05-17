//
//  compute.metal
//  SwiftUI02
//
//  Created by we on 2023/05/17.
//

#include <metal_stdlib>
using namespace metal;

kernel void square_numbers1(device int64_t* in [[ buffer(0) ]],
                           device int64_t* out [[ buffer(1) ]],
                           uint2 gid [[ thread_position_in_grid ]]) {
    uint index = gid.x;
    out[index] = in[index] * in[index];
}

kernel void square_numbers(device int64_t* in [[ buffer(0) ]],
                           device int64_t* out [[ buffer(1) ]],
                           uint gid [[ thread_position_in_grid ]]) {
    out[gid] = in[gid] * in[gid];
}
