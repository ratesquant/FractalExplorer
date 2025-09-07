//
//  FractalShaders.metal
//  FractalExplorer
//
//  Created by Alex Сhirokov on 9/7/25.
//
#include <metal_stdlib>
using namespace metal;

struct FractalParams {
    uint width;
    uint height;
    uint maxIterations;
    float xmin;
    float ymin;
    float dx;
    float dy;
};

kernel void mandelbrotKernel(device int* buffer        [[buffer(0)]],
                             constant FractalParams& params [[buffer(1)]],
                             uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= params.width || gid.y >= params.height) return;

    float x0 = params.xmin + (float(gid.x) + 0.5) * params.dx;
    float y0 = params.ymin + (float(gid.y) + 0.5) * params.dy;

    float x = 0.0;
    float y = 0.0;
    uint iteration = 0;

    while ((x*x + y*y <= 4.0) && (iteration < params.maxIterations)) {
        float xt = x*x - y*y + x0;
        y = 2.0*x*y + y0;
        x = xt;
        iteration += 1;
    }

    buffer[gid.y * params.width + gid.x] = iteration;
}

