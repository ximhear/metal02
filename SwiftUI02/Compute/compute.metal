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

kernel void mandelbrot(texture2d<float, access::write> outputTexture [[texture(0)]],
                                uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }
    
    // Convert pixel coordinates to complex plane coordinates
    float2 a = (float2(gid) / float2(outputTexture.get_width(), outputTexture.get_height())) * 4.0 - 2.0;
    float2 c;
    float w = float(outputTexture.get_width());
    float h = float(outputTexture.get_height());
    if (w > h) {
        c = float2(a.x * w / h, a.y);
    }
    else {
        c = float2(a.x, a.y * h / w);
    }
    
    
    float2 z = 0.0;
    float iter = 0.0;
    float maxIter = 1000.0;
    
    // Perform Mandelbrot set calculations
    while (length(z) < 2.0 && iter < maxIter) {
        z = float2(z.x*z.x - z.y*z.y, 2.0*z.x*z.y) + c;
        iter++;
    }
    
    // Write the number of iterations to the texture
    if (iter < maxIter) {
        iter *= 200;
        float color = iter / maxIter;
        return outputTexture.write(float4(color, 8.0, 0.6, 1.0), gid);
    }
    outputTexture.write(float4(1.0, 0, 0, 1.0), gid);
}
