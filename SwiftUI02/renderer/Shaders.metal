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
#import "ShaderTypes.h"

using namespace metal;

typedef struct
{
    float3 position [[attribute(VertexAttributePosition)]];
    float2 texCoord [[attribute(VertexAttributeTexcoord)]];
} Vertex;

typedef struct
{
    float4 position [[position]];
    float2 texCoord;
} ColorInOut;

vertex ColorInOut vertexShader(Vertex in [[stage_in]],
                               constant UniformsPV & uniformsPV [[ buffer(BufferIndexUniformsPV) ]],
                               constant UniformsM & uniformsM [[ buffer(BufferIndexUniformsM) ]]
                               )
{
    ColorInOut out;

    float4 position = float4(in.position, 1.0);
    out.position = uniformsPV.projectionMatrix * uniformsPV.viewMatrix * uniformsM.modelMatrix * position;
    out.texCoord = in.texCoord;

    return out;
}

vertex ColorInOut vertexShader1(uint vertexID [[vertex_id]],
                               constant float3 *vertices [[buffer(0)]],
                               constant float2 *texCoords [[buffer(1)]],
                               constant UniformsPV & uniformsPV [[ buffer(BufferIndexUniformsPV) ]],
                               constant UniformsM & uniformsM [[ buffer(BufferIndexUniformsM) ]]
                                )
{
    ColorInOut out;

    float4 position = float4(vertices[vertexID], 1.0);
    out.position = uniformsPV.projectionMatrix * uniformsPV.viewMatrix * uniformsM.modelMatrix * position;
    out.texCoord = texCoords[vertexID];

    return out;
}

fragment float4 fragmentShader(ColorInOut in [[stage_in]],
                               constant UniformsPV & uniformsPV [[ buffer(BufferIndexUniformsPV) ]],
                               constant UniformsM & uniformsM [[ buffer(BufferIndexUniformsM) ]],
                               texture2d<half> colorMap     [[ texture(TextureIndexColor) ]])
{
    constexpr sampler colorSampler(mip_filter::linear,
                                   mag_filter::linear,
                                   min_filter::linear);

    half4 colorSample   = colorMap.sample(colorSampler, in.texCoord.xy);

    return float4(colorSample.r * colorSample.a, colorSample.g * colorSample.a, colorSample.b * colorSample.a, 1) + float4(1 * (1 - colorSample.a), 1 * (1 - colorSample.a), 0, 0);
}


fragment float4 fragmentShaderSolid(ColorInOut in [[stage_in]],
                               constant UniformsPV & uniformsPV [[ buffer(BufferIndexUniformsPV) ]],
                               constant UniformsM & uniformsM [[ buffer(BufferIndexUniformsM) ]],
                               texture2d<half> colorMap     [[ texture(TextureIndexColor) ]])
{
    return float4(1, 1, 1, 1);
}


typedef struct
{
    float4 position [[position]];
    float4 color;
    float2 coord;
} ColorInOut1;
typedef struct
{
    float2 position [[attribute(0)]];
    float4 color [[attribute(1)]];
} Vertex1;

vertex ColorInOut1 vertexManderbrot(Vertex1 in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(1) ]])
{
    ColorInOut1 out;

    float4 position = float4(in.position.x, in.position.y, 1.0, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * uniforms.modelMatrix * position;
    out.color = in.color;
    out.coord = in.position;

    return out;
}

fragment float4 fragmentMandelbrot(ColorInOut1 in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(1) ]])
{
    // Convert pixel coordinates to complex plane coordinates
    float2 a = in.coord / uniforms.scale + uniforms.dimension * uniforms.drag;
    float2 c = a * 2;
    
    float2 z = 0.0;
    float iter = 0.0;
    float maxIter = 1000.0;
    
    // Perform Mandelbrot set calculations
    while (length(z) < 2.0 && iter < maxIter) {
        z = float2(z.x*z.x - z.y*z.y, 2.0*z.x*z.y) + c;
        iter++;
    }
    
    // Write the number of iterations to the texture
//    if (iter < maxIter) {
//        iter *= 200;
//        float color = iter / maxIter;
//        return float4(color, 8.0, 0.6, 1.0);
//    }
    float color = iter / maxIter;
    return float4(color, 0, 0, 1.0);
}
