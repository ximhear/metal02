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

kernel void mandelbrot(texture2d<float, access::read> inputTexture [[texture(0)]],
                                texture2d<float, access::write> outputTexture [[texture(1)]],
                                uint2 gid [[thread_position_in_grid]])
{
    // read from input texture
//    float4 input = inputTexture.read(gid);
    
    
    // write to output texture
    outputTexture.write(float4(1, 0, 0, 1), gid);
}
