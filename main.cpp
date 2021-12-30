#include "raylib.h"
#include "rlgl.h"
#include <cmath>
#include <vector>

#define AS_WIDTH 400
#define AS_HEIGHT 300
#define NUM_ANTS 500

// Maximum amount of queued draw commands (squares draw from mouse down events).
#define MAX_BUFFERED_TRANSFERTS 48

struct ASUpdateCmd {
    int x;
    int y;
    unsigned int w;         // width of the filled zone
    unsigned int value;
};

struct ASUpdateSSBO {
    unsigned int count;
    ASUpdateCmd commands[MAX_BUFFERED_TRANSFERTS];
};

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


int main() {
    float ratio = 2;
    InitWindow(AS_WIDTH * ratio, AS_HEIGHT * ratio, "ant simulation");
    SetTraceLogLevel(LOG_WARNING);
    SetTargetFPS(60);

    const Vector2 resolution = { AS_WIDTH, AS_HEIGHT };
    unsigned int brushSize = 1;

    // logic compute shader
    char *asLogicCode = LoadFileText("antsim.glsl");
    unsigned int asLogicShader = rlCompileShader(asLogicCode, RL_COMPUTE_SHADER);
    unsigned int asLogicProgram = rlLoadComputeShaderProgram(asLogicShader);
    UnloadFileText(asLogicCode);

    char *asInputCode = LoadFileText("input.glsl");
    unsigned int asInputShader = rlCompileShader(asInputCode, RL_COMPUTE_SHADER);
    unsigned int asInputProgram = rlLoadComputeShaderProgram(asInputShader);
    UnloadFileText(asInputCode);

    char *evaporateCode = LoadFileText("evaporate.glsl");
    unsigned int evaporateShader = rlCompileShader(evaporateCode, RL_COMPUTE_SHADER);
    unsigned int evaporateProgram = rlLoadComputeShaderProgram(evaporateShader);
    UnloadFileText(evaporateCode);

    Shader asRenderShader = LoadShader(nullptr, "render.glsl");
    int resUniformLoc = GetShaderLocation(asRenderShader, "resolution");

    Ant ants[NUM_ANTS];
    for (int i(0); i < NUM_ANTS; i++) {
        float angle = GetRandomValue(0, 360) * PI / 180.f;
        ants[i] = Ant{AS_WIDTH / 2, AS_HEIGHT / 2, (float)cos(angle), (float)sin(angle), 0.f, 0.f, 50.f, 0, -1.f, -1.f, 6, PI / 1.5f, 0.0f};
    }

    // SSBOs
    unsigned int markers = rlLoadShaderBuffer(AS_WIDTH*AS_HEIGHT*sizeof(struct Marker), nullptr, RL_DYNAMIC_COPY);

    int foodArr[AS_WIDTH * AS_HEIGHT];
    for (int k(0); k < 3; k++) {
        int posx = GetRandomValue(100, AS_WIDTH - 100);
        int posy = GetRandomValue(100, AS_HEIGHT - 100);
        for (int i(-GetRandomValue(15, 20)); i < GetRandomValue(15, 20); i++) {
            for (int j(-GetRandomValue(15, 20)); j < GetRandomValue(15, 20); j++) {
                if (GetRandomValue(0, 1) == 1)
                    foodArr[posx + i + ((posy + j) * AS_WIDTH)] = 1;
            }
        }
    }
    unsigned int plane = rlLoadShaderBuffer(AS_WIDTH*AS_HEIGHT*sizeof(int), foodArr, RL_DYNAMIC_COPY);
    unsigned int antPos = rlLoadShaderBuffer(NUM_ANTS*sizeof(struct Ant), ants, RL_DYNAMIC_COPY);

    struct ASUpdateSSBO inputBuffer;
    inputBuffer.count = 0;

    int inputSSBO = rlLoadShaderBuffer(sizeof(struct ASUpdateSSBO), nullptr, RL_DYNAMIC_COPY);

    // Create a white texture to show the SSBO
    RenderTexture2D whiteTex = LoadRenderTexture(AS_WIDTH, AS_HEIGHT);

    float counter = 0.0f;
    rlEnableColorBlend();
    BeginBlendMode(BLEND_ALPHA);

    while (!WindowShouldClose())
    {
        brushSize += (int)GetMouseWheelMove();
        counter += GetFrameTime() * 1000.f;

        if ((IsMouseButtonDown(MOUSE_BUTTON_LEFT) || IsMouseButtonDown(MOUSE_BUTTON_RIGHT))
            && (inputBuffer.count < MAX_BUFFERED_TRANSFERTS))
        {
            // Buffer a new command
            inputBuffer.commands[inputBuffer.count].x = (GetMouseX() - brushSize/2) / ratio;
            inputBuffer.commands[inputBuffer.count].y = (GetMouseY() - brushSize/2) / ratio;
            inputBuffer.commands[inputBuffer.count].w = brushSize;
            inputBuffer.commands[inputBuffer.count].value = (int)IsMouseButtonDown(MOUSE_BUTTON_RIGHT) + 1;
            inputBuffer.count++;
        }
        if (inputBuffer.count > 0)
        {
            // Send SSBO buffer to GPU
            rlUpdateShaderBufferElements(inputSSBO, &inputBuffer, sizeof(struct ASUpdateSSBO), 0);
            
            // Process ssbo command
            rlEnableShader(asInputProgram);
            rlBindShaderBuffer(plane, 1);
            rlBindShaderBuffer(inputSSBO, 2);
            rlComputeShaderDispatch(inputBuffer.count, 1, 1); // each GPU unit will process a command
            rlDisableShader();

            inputBuffer.count = 0;
        }
        else
        {
            float time = GetTime();
            float dt = GetFrameTime();

            rlEnableShader(evaporateProgram);
            rlSetUniform(rlGetLocationUniform(evaporateProgram, "dt"), &dt, RL_SHADER_UNIFORM_FLOAT, 1);
            rlBindShaderBuffer(markers, 4);
            rlComputeShaderDispatch(AS_WIDTH, AS_HEIGHT, 1);
            rlDisableShader();

            BeginTextureMode(whiteTex);
                // ClearBackground(Color{145, 74, 35, 255});
                ClearBackground(Color{13, 16, 23, 255});
                // DrawCircleLines(AS_WIDTH / 2, AS_HEIGHT / 2, 15, Color{48, 25, 21, 255});
                DrawCircleLines(AS_WIDTH / 2, AS_HEIGHT / 2, 15, Color{17, 21, 28, 255});
            EndTextureMode();
            rlBindImageTexture(whiteTex.texture.id, 0, whiteTex.texture.format, 0);
            rlEnableShader(asLogicProgram);
            rlSetUniform(rlGetLocationUniform(asLogicProgram, "time"), &time, RL_SHADER_UNIFORM_FLOAT, 1);
            rlSetUniform(rlGetLocationUniform(asLogicProgram, "dt"), &dt, RL_SHADER_UNIFORM_FLOAT, 1);
            rlBindShaderBuffer(plane, 1);
            rlBindShaderBuffer(antPos, 3);
            rlBindShaderBuffer(markers, 4);
            int val = 0;
            rlSetUniform(rlGetLocationUniform(asLogicProgram, "map"), &val, RL_SHADER_UNIFORM_INT, 1);
            rlComputeShaderDispatch(NUM_ANTS, 1, 1);
            rlDisableShader();
        }

        rlBindShaderBuffer(plane, 1);
        SetShaderValue(asRenderShader, resUniformLoc, &resolution, SHADER_UNIFORM_VEC2);
        SetShaderValueTexture(asRenderShader, GetShaderLocation(asRenderShader, "texture0"), whiteTex.texture);

        BeginDrawing();
            // ClearBackground(Color{145, 74, 35, 255});
            ClearBackground(Color{13, 16, 23, 255});
            BeginShaderMode(asRenderShader);
                DrawTexturePro(whiteTex.texture, Rectangle{0, 0, (float)AS_WIDTH, (float)AS_HEIGHT}, Rectangle{0, 0, AS_WIDTH * ratio, AS_HEIGHT * ratio}, Vector2{0, 0}, 0.f, WHITE);
            EndShaderMode();
            
            DrawRectangleLines(GetMouseX() - brushSize * ratio / 2, GetMouseY() - brushSize * ratio / 2, brushSize * ratio, brushSize * ratio, RED);
            DrawFPS(GetScreenWidth() - 100, 10);

        EndDrawing();
    }
    EndBlendMode();
    rlDisableColorBlend();

    // Unload shader buffers objects.
    rlUnloadShaderBuffer(markers);
    rlUnloadShaderBuffer(antPos);
    rlUnloadShaderBuffer(plane);
    rlUnloadShaderBuffer(inputSSBO);

    // Unload compute shader programs
    rlUnloadShaderProgram(asInputProgram);
    rlUnloadShaderProgram(asLogicProgram);

    UnloadRenderTexture(whiteTex);            // Unload white texture
    UnloadShader(asRenderShader);      // Unload rendering fragment shader

    CloseWindow();                      // Close window and OpenGL context
    return 0;
}