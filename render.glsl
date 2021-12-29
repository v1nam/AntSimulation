#version 430

#define AS_WIDTH 400
#define AS_HEIGHT 300

struct Marker {
    float toHomeStrength;
    float toFoodStrength;
};

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;

// Output fragment color
out vec4 finalColor;

layout(std430, binding = 1) readonly buffer foodLayout
{
    int foodPos[];
};
layout(std430, binding = 4) restrict buffer markersLayout {
    Marker markers[];
};

// Output resolution
uniform vec2 resolution;
uniform sampler2D texture0;

void main()
{
    ivec2 coords = ivec2(fragTexCoord*resolution);
    uint ind = coords.x + coords.y*uvec2(resolution).x;
    int val = foodPos[ind];
    float toHome = markers[ind].toHomeStrength;
    float toFood = markers[ind].toFoodStrength;

    vec4 col = texture(texture0, fragTexCoord);
    if (ivec3(col.rgb * 255.0) == ivec3(145, 74, 35)) {
        if (toFood > 0.0 || toHome > 0.0) {
            float hv = toHome / 2000.0;
            float fv = toFood / 2000.0;
            vec3 col = vec3(0.0);
            vec3 col2 = vec3(0.0);
            if (hv > fv) {
                col = vec3(0.0941, 0.4274, 0.9137);
                col2 = vec3(1.0, 0.192, 0.192);
            } else {
                col = vec3(1.0, 0.192, 0.192);
                col2 = vec3(0.0941, 0.4274, 0.9137);
            }
            finalColor = mix(vec4(col, max(fv, hv)), vec4(col2, min(fv, hv)), min(fv, hv));
        }
        else finalColor = col;
    } else
        finalColor = col;
    if ((val) == 1) finalColor = vec4(0.0, 1.0, 0.0, 1.0);
    if ((val) == 2) finalColor = vec4(0.321, 0.152, 0.113, 1.0);
}