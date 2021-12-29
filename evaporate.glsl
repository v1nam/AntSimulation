#version 430

// shader for evaporating pheromones

#define AS_WIDTH 400
#define AS_HEIGHT 300

struct Marker {
    float toHomeStrength;
    float toFoodStrength;
};

layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 4) restrict buffer markersLayout {
    Marker markers[];
};

uniform float dt;

void main()
{
    uint index = gl_GlobalInvocationID.x + gl_GlobalInvocationID.y * AS_WIDTH;
    markers[index].toHomeStrength = max(markers[index].toHomeStrength - sqrt(dt), 0.0);
    markers[index].toFoodStrength = max(markers[index].toFoodStrength - (pow(dt, dt) * 6.0), 0.0);
    if (distance(vec2(gl_GlobalInvocationID.xy), vec2(AS_WIDTH, AS_HEIGHT) / 2.0) <= 25.0)
        markers[index].toHomeStrength = 2000.0;
}