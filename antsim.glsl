#version 430

// logic shader

#define AS_WIDTH 400
#define AS_HEIGHT 300
#define PI 3.141592653589793

struct Ant {
    float x;
    float y;
    float dirX;
    float dirY;
    float velX;
    float velY;
    float speed;
    int hasFood;
    float foodX;
    float foodY;
    int viewRad;
    float viewAngle;
    float clock;
};

struct Marker {
    float toHomeStrength;
    float toFoodStrength;
};

layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout(std430, binding = 1) restrict buffer foodLayout {
    int foodPos[];       // foodPos[x, y] = foodPos[x + gl_NumWorkGroups.x * y]
};

layout(std430, binding = 3) restrict buffer antLayout {
    Ant antPos[];
};

layout(std430, binding = 4) restrict buffer markersLayout {
    Marker markers[];
};

layout (rgba8) uniform image2D map;
uniform float time;
uniform float dt;

#define getFoodPos(x, y) foodPos[(x) + AS_WIDTH * (y)]

#define setFoodPos(x, y, value) atomicExchange(foodPos[(x) + AS_WIDTH*(y)], value)


// Hash function www.cs.ubc.ca/~rbridson/docs/schechter-sca08-turbulence.pdf
uint hash(uint state)
{
    state ^= 2747636419u;
    state *= 2654435769u;
    state ^= state >> 16;
    state *= 2654435769u;
    state ^= state >> 16;
    state *= 2654435769u;
    return state;
}

float random(uint state)
{
    return state / 4294967295.0;
}

vec2 clampMag(vec2 vec, float m)
{
    float l = length(vec);
    return l > 0 ? normalize(vec) * min(l, m) : vec;
}

float detectPheromone(vec2 cen, int rad, int type)
{
    float strength = 0;
    for (int i = -rad; i <= rad; i++) {
        for (int j = -rad; j <= rad; j++) {
            ivec2 p = ivec2(int(cen.x + i), int(cen.y + j));
            if (pow(i, 2) + pow(j, 2) <= pow(rad, 2))
                strength += type == 0 ? markers[p.x+p.y*AS_WIDTH].toFoodStrength : markers[p.x+p.y*AS_WIDTH].toHomeStrength;
        }
    }
    return strength;
}

void main()
{
    uint antIndex = gl_GlobalInvocationID.x;
    Ant ant = antPos[antIndex];
    vec2 dir = vec2(ant.dirX, ant.dirY);
    vec2 pos = vec2(ant.x, ant.y);
    vec2 vel = vec2(ant.velX, ant.velY);
    vec2 targetFood = vec2(ant.foodX, ant.foodY);
    
    float t = random(hash(uint(pos.y * AS_WIDTH + pos.x + hash(uint(antIndex + time * 100000.0)))));
    float l = sqrt(random(hash(uint(pos.y * AS_WIDTH + pos.x + hash(uint(antIndex + time * 172942.0))))));
    vec2 pointInCircle = vec2(cos(t * PI * 2.0) * l, sin(t * PI * 2.0) * l);

    float frontAngle = atan(dir.y, dir.x);
    float leftAngle = frontAngle + ant.viewAngle / 2.0;
    float rightAngle = frontAngle - ant.viewAngle / 2.0;

    vec2 front = vec2(cos(frontAngle), sin(frontAngle)) * ant.viewRad / 2.0;
    vec2 left = vec2(cos(leftAngle), sin(leftAngle)) * ant.viewRad;
    vec2 right = vec2(cos(rightAngle), sin(rightAngle)) * ant.viewRad;

    int radius = int(ant.viewRad) / 2;

    float frontStrength = detectPheromone(front + pos, radius, ant.hasFood);
    float leftStrength = detectPheromone(left + pos, radius, ant.hasFood);
    float rightStrength = detectPheromone(right + pos, radius, ant.hasFood);

    if (frontStrength > 0 || leftStrength > 0 || rightStrength > 0) {
        if (frontStrength > leftStrength && frontStrength > rightStrength)
            dir = normalize(front);
        else if (leftStrength > rightStrength)
            dir = normalize(left);
        else if (rightStrength > leftStrength)
            dir = normalize(right);
    } else
        dir = normalize(dir + (pointInCircle * 2.0));

    if (ant.hasFood == 0) {
        if (targetFood.x < 0) {
            int flag = 1;
            for (int i = -ant.viewRad; i <= ant.viewRad; i++) {
                if (flag == 0)
                    break;
                for (int j = -ant.viewRad; j <= ant.viewRad; j++) {
                    if (pow(i, 2) + pow(j, 2) <= pow(ant.viewRad, 2)) {
                        ivec2 pv = ivec2(int(pos.x) + i, int(pos.y) + j);
                        if (foodPos[pv.x + pv.y * AS_WIDTH] == 1) {
                            targetFood = vec2(float(pv.x), float(pv.y));
                            foodPos[pv.x + pv.y * AS_WIDTH] = 0;
                            flag = 0;
                            break;
                        }
                    }
                }
            }
        } else {
            dir = normalize(targetFood - pos);
            if (distance(pos, targetFood) <= 0.5) {
                ant.hasFood = 1;
                ant.clock = 2.0;
                dir = -dir;
                vel = -vel;
                targetFood = vec2(-1, -1);
            }
        }
    }

    vec2 dv = dir * ant.speed * 2.0;
    vec2 dsf = (dv - vel) * 200.0;
    vec2 acc = clampMag(dsf, 200.0);
    vel = clampMag(acc * dt + vel, ant.speed);
    pos = pos + (vel * dt);
    pos.x = min(AS_WIDTH - 1, max(0, pos.x));
    pos.y = min(AS_HEIGHT - 1, max(0, pos.y));
    if ((pos.x <= 0) || (pos.x >= AS_WIDTH - 1)) {
        dir = vec2(-dir.x, dir.y);
        vel = vec2(-vel.x, vel.y);
    } if ((pos.y <= 0) || (pos.y >= AS_HEIGHT - 1)) {
        dir = vec2(dir.x, -dir.y);
        vel = vec2(vel.x, -vel.y);
    }

    float pheromoneStrength = 2000.0 * exp(-0.5 * ant.clock);
    ivec2 ipos = ivec2(int(pos.x), int(pos.y));
    if (ant.hasFood == 0) {
        float s = markers[ipos.x + (ipos.y * AS_WIDTH)].toHomeStrength;
        markers[ipos.x + (ipos.y * AS_WIDTH)].toHomeStrength = min(max(s + pheromoneStrength, 0.01), 2000.0);
    } else {
        float s = markers[ipos.x + (ipos.y * AS_WIDTH)].toFoodStrength;
        markers[ipos.x + (ipos.y * AS_WIDTH)].toFoodStrength = min(max(s + pheromoneStrength, 0.0), 2000.0);
    }
    imageStore(map, ipos, vec4(0.109, 0.0196, 0.0039, 1.0));
    if (foodPos[ipos.x + (ipos.y * AS_WIDTH)] == 2) {
        dir = -dir;
        vel = -vel;
    }
    if (ant.hasFood == 1) {
        vec2 antHead = pos + normalize(vel);
        imageStore(map, ivec2(int(antHead.x), int(antHead.y)), vec4(0.0, 1.0, 0.0, 1.0));
        if (distance((vec2(AS_WIDTH, AS_HEIGHT) / 2.0), pos) <= 16.0) {
            ant.hasFood = 0;
            ant.clock = 0.0;
            dir = -dir;
            vel = -vel;
        }
    }

    antPos[antIndex].x = pos.x;
    antPos[antIndex].y = pos.y;
    antPos[antIndex].dirX = dir.x;
    antPos[antIndex].dirY = dir.y;
    antPos[antIndex].velX = vel.x;
    antPos[antIndex].velY = vel.y;
    antPos[antIndex].speed = ant.speed;
    antPos[antIndex].hasFood = ant.hasFood;
    antPos[antIndex].foodX = targetFood.x;
    antPos[antIndex].foodY = targetFood.y;
    antPos[antIndex].viewRad = ant.viewRad;
    antPos[antIndex].viewAngle = ant.viewAngle;
    antPos[antIndex].clock = ant.clock + dt;
}