//
//  compute.metal
//  SwiftUI02
//
//  Created by we on 2023/05/17.
//

#include <metal_stdlib>
using namespace metal;

kernel void square_numbers(device int* in [[ buffer(0) ]],
                           device int* out [[ buffer(1) ]],
                           uint id [[ thread_position_in_grid ]]) {
    out[id] = in[id] * in[id];
}
