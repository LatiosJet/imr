#version 450
#extension GL_EXT_shader_image_load_formatted : require
#extension GL_EXT_scalar_block_layout : require

layout(set = 0, binding = 0)
uniform image2D renderTarget;

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

struct Tri { vec3 v0, v1, v2; vec3 color; };

layout(scalar, push_constant) uniform T {
	Tri triangle;
    mat4 m;
	float time;
} push_constants;

float cross_2(vec2 a, vec2 b) {
    return cross(vec3(a, 0), vec3(b, 0)).z;
}

float barCoord(vec2 a, vec2 b, vec2 point){
    vec2 PA = point - a;
    vec2 BA = b - a;
    return cross_2(PA, BA);
}

vec3 barycentricTri2(vec4 v0, vec4 v1, vec4 v2, vec2 point) {
    float scaling = barCoord(v0.xy, v1.xy, v2.xy);

    float u = barCoord(v0.xy, v1.xy, point) / scaling;
    float v = barCoord(v1.xy, v2.xy, point) / scaling;

    if (scaling > 0)
        return vec3(-1);

    return vec3(u, v, scaling);
}

void main() {
    ivec2 img_size = imageSize(renderTarget);
    if (gl_GlobalInvocationID.x >= img_size.x || gl_GlobalInvocationID.y >= img_size.y)
        return;

    vec2 point = vec2(gl_GlobalInvocationID.xy) / vec2(img_size);
    point = point * 2.0 - vec2(1.0);

    vec4 v0 = vec4(push_constants.triangle.v0, 1);
    vec4 v1 = vec4(push_constants.triangle.v1, 1);
    vec4 v2 = vec4(push_constants.triangle.v2, 1);
    v0 = push_constants.m * v0;
    v1 = push_constants.m * v1;
    v2 = push_constants.m * v2;
    v0.xyz /= v0.w;
    v1.xyz /= v1.w;
    v2.xyz /= v2.w;

    vec3 baryResults = barycentricTri2(v0, v1, v2, point);
    float u = baryResults.x;
    float v = baryResults.y;
    float w = 1 - u - v;

    if (!(u >= 0.0 && v >= 0.0 && w >= 0.0))
        return;

    // TODO: handle clipping properly
    if (v0.z <= 0 || v1.z <= 0 || v2.z <= 0)
        return;

    vec4 c = vec4(push_constants.triangle.color, 1);
    imageStore(renderTarget, ivec2(gl_GlobalInvocationID.xy), c);
}