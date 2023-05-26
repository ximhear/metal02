//
//  Shaders.metal
//  Metal01
//
//  Created by gzonelee on 2023/04/21.
//

// File for Metal kernel and shader functions

#include <metal_stdlib>
#include <simd/simd.h>

// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "../renderer/ShaderTypes.h"

using namespace metal;

typedef struct
{
    float3 position [[attribute(VertexAttributePosition)]];
} VertexGraph;

typedef struct
{
    float4 position [[position]];
} ColorInOutGraph;

vertex ColorInOutGraph vertexGraph(VertexGraph in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(1) ]])
{
    ColorInOutGraph out;

    float4 position = float4(in.position.x, in.position.y, in.position.z, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * position;

    return out;
}

fragment float4 fragmentGraph(ColorInOutGraph in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(1) ]])
{
    // Convert pixel coordinates to complex plane coordinates
    return float4(1, 1, 1, 1);
}
