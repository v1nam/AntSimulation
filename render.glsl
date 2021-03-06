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

    vec4 colSource = texture(texture0, fragTexCoord);
    if (ivec3(colSource.rgb * 255.0) == ivec3(13, 16, 23)) {
        if (toFood > 0.0 || toHome > 0.0) {
            float hv = toHome / 4000.0;
            float fv = toFood / 2000.0;
            vec3 col = vec3(0.0);
            vec3 col2 = vec3(0.0);
            if (hv > fv) {
                // col = vec3(0.0941, 0.4274, 0.9137);
                col = vec3(0.223, 0.729, 0.901);
                // col2 = vec3(1.0, 0.192, 0.192);
                col2 = vec3(0.941, 0.443, 0.466);
            } else {
                // col = vec3(1.0, 0.192, 0.192);
                col = vec3(0.941, 0.443, 0.466);
                // col2 = vec3(0.0941, 0.4274, 0.9137);
                col2 = vec3(0.223, 0.729, 0.901);
            }
            finalColor = mix(vec4(col, max(fv, hv)), vec4(col2, min(fv, hv)), min(fv, hv));
        }
        else finalColor = colSource;
    } else
        finalColor = colSource;
    if ((val) == 1) finalColor = vec4(0.666, 0.8509, 0.298, 1.0);
    if ((val) == 2) finalColor = vec4(0.4235, 0.4509, 0.5019, 1.0);
}