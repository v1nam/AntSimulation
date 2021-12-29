#version 430

// Game of life transfert shader

#define AS_WIDTH 400
#define AS_HEIGHT 300

// NOTE: matches the structure defined on main program
struct ASUpdateCmd {
    int x;
    int y;
    uint w;         // width of the filled zone
    uint value;
};

// Local compute unit size
layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

// Output grid buffer
layout(std430, binding = 1) buffer foodLayout
{
    int foodPos[]; // foodPos[x, y] = foodPos[x + AS_WIDTH * y]
};

// Command buffer
layout(std430, binding = 2) readonly restrict buffer asUpdateLayout
{
    uint count;
    ASUpdateCmd commands[];
};

#define isInside(x, y) (((x) >= 0) && ((y) >= 0) && ((x) < AS_WIDTH) && ((y) < AS_HEIGHT))
#define getBufferIndex(x, y) ((x) + AS_WIDTH * (y))

void main()
{
    uint cmdIndex = gl_GlobalInvocationID.x;
    ASUpdateCmd cmd = commands[cmdIndex];

    for (int x = cmd.x; x < (cmd.x + cmd.w); x++)
    {
        for (int y = cmd.y; y < (cmd.y + cmd.w); y++)
        {
            if (isInside(x, y))
                foodPos[getBufferIndex(x, y)] = int(cmd.value);
        }
    }
}