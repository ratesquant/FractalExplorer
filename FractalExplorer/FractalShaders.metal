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
    int iteration = 0;
    int max_iteration = (int)params.maxIterations;

    while ((x*x + y*y <= 4.0f) && (iteration < max_iteration)) {
        float xt = x*x - y*y + x0;
        y = 2.0*x*y + y0;
        x = xt;
        iteration += 1;
    }

    buffer[gid.y * params.width + gid.x] = iteration;
}

kernel void burningShipKernel(device int* buffer        [[buffer(0)]],
                             constant FractalParams& params [[buffer(1)]],
                             uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= params.width || gid.y >= params.height) return;

    float x0 = params.xmin + (float(gid.x) + 0.5) * params.dx;
    float y0 = params.ymin + (float(gid.y) + 0.5) * params.dy;

    float x = 0.0;
    float y = 0.0;
    float x2 = 0.0;
    float y2 = 0.0;
    int iteration = 0;
    int max_iteration = (int)params.maxIterations;

    while ((x2 + y2 <= 4.0f) && (iteration < max_iteration)) {
        float xt = x2 - y2 + x0;
        y = fast::fabs(2.0f * x * y) + y0;
        x = fast::fabs(xt);
        x2 = x * x;
        y2 = y * y;
        iteration++;
    }

    buffer[gid.y * params.width + gid.x] = iteration;
}

kernel void tricornKernel(device int* buffer        [[buffer(0)]],
                          constant FractalParams& params [[buffer(1)]],
                          uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= params.width || gid.y >= params.height) return;

    float x0 = params.xmin + (float(gid.x) + 0.5f) * params.dx;
    float y0 = params.ymin + (float(gid.y) + 0.5f) * params.dy;

    float x = 0.0f;
    float y = 0.0f;
    float x2 = 0.0f;
    float y2 = 0.0f;
    int iteration = 0;
    int maxIter = (int)params.maxIterations;

    while ((x2 + y2 <= 4.0f) && (iteration < maxIter)) {
        float xt = x2 - y2 + x0;
        y = -(2.0f * x * y) + y0;   // conjugate step
        x = xt;
        x2 = x * x;
        y2 = y * y;
        iteration++;
    }

    buffer[gid.y * params.width + gid.x] = iteration;
}



