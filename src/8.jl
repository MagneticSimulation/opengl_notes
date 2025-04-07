using GLFW, ModernGL, LinearAlgebra, StaticArrays

include(joinpath(@__DIR__, "util5.jl")) 

const SCR_WIDTH = 800
const SCR_HEIGHT = 600

const vertexShaderSource = """
#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aNormal;
layout (location = 2) in vec3 iPos;
layout (location = 3) in vec3 iSpin;

out vec3 color;

uniform mat4 view;
uniform mat4 projection;
uniform vec3 lightDir;
uniform vec3 lightColor;

vec3 coolWarmColormap(float t) {
    vec3 cool = vec3(0.0, 0.0, 1.0);    
    vec3 warm = vec3(1.0, 0.0, 0.0);    
    return mix(cool, warm, smoothstep(-1.0, 1.0, t));
}

mat4 make_rotation(vec3 spin) {
    vec3 z = normalize(spin);
    vec3 x = normalize(cross(vec3(0,1,0), z));
    vec3 y = cross(z, x);
    return mat4(
        vec4(x,0), vec4(y,0), vec4(z,0), 
        vec4(iPos,1) 
    );
}

void main() {

    mat4 model = make_rotation(iSpin);
    gl_Position = projection * view * model * vec4(aPos, 1.0);
    
    mat3 normalMatrix = mat3(transpose(inverse(model)));
    vec3 normal = normalize(normalMatrix * aNormal);
    vec3 direction = normalize(mat3(model) * vec3(0.0, 0.0, 1.0)); 
    
    vec3 baseColor = coolWarmColormap(direction.z);
    
    float ambientStrength = 0.3;
    float diffStrength = 0.7;
    vec3 lightDirection = normalize(-lightDir);
    
    float diff = max(dot(normal, lightDirection), 0.0);
    vec3 diffuse = diffStrength * diff * lightColor;
    vec3 ambient = ambientStrength * lightColor;
    
    color = (ambient + diffuse) * baseColor;
}"""

const fragmentShaderSource = """
#version 330 core
in vec3 color;
out vec4 FragColor;
void main() { FragColor = vec4(color, 1.0); }"""


window = create_window(SCR_WIDTH, SCR_HEIGHT)
glEnable(GL_DEPTH_TEST)


camera = PerspectiveCamera(
    position=SA_F32[0, 0, 5],
    target=SA_F32[0, 0, 0],
    fov=45.0f0,
    aspect=SCR_WIDTH/SCR_HEIGHT
)
controls = OrbitControls(window, camera)

GLFW.SetMouseButtonCallback(window, (win, button, action, mods) -> 
    handle_mouse_button!(controls, button, action, mods))

GLFW.SetCursorPosCallback(window, (win, x, y) -> 
    handle_cursor_pos!(controls, x, y))

GLFW.SetScrollCallback(window, (win, dx, dy) -> 
    handle_scroll!(controls, dy))


program = create_shader_program(vertexShaderSource, fragmentShaderSource)

vertices = generate_cone_normals()

spins = rand(Float32, 3*40000)
positions = Float32[]
for i=1:200, j=1:200
    push!(positions, i)
    push!(positions, j)
    push!(positions, 0)
end

const num_instances = 40000


vao, vbo = Ref{GLuint}(0), Ref{GLuint}(0)
pos_vbo = Ref{GLuint}(0)  
spin_vbo = Ref{GLuint}(0)

glGenVertexArrays(1, vao)

glGenBuffers(1, vbo)
glGenBuffers(1, pos_vbo)
glGenBuffers(1, spin_vbo)

glBindVertexArray(vao[])
# positions + normal
glBindBuffer(GL_ARRAY_BUFFER, vbo[])
glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW)

glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6*sizeof(GLfloat), Ptr{Cvoid}(0))
glEnableVertexAttribArray(0)
glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6*sizeof(GLfloat), Ptr{Cvoid}(3*sizeof(GLfloat)))
glEnableVertexAttribArray(1)

# position vbo
glBindBuffer(GL_ARRAY_BUFFER, pos_vbo[])
glBufferData(GL_ARRAY_BUFFER, sizeof(positions), positions, GL_STATIC_DRAW)
glEnableVertexAttribArray(2)
glVertexAttribPointer(2, 3, GL_FLOAT, GL_FALSE, 0, C_NULL)
glVertexAttribDivisor(2, 1)

# spin_vbo
glBindBuffer(GL_ARRAY_BUFFER, spin_vbo[])
glBufferData(GL_ARRAY_BUFFER, num_instances*3*sizeof(GLfloat), spins, GL_STREAM_DRAW)
glEnableVertexAttribArray(3)
glVertexAttribPointer(3, 3, GL_FLOAT, GL_FALSE, 0, C_NULL)
glVertexAttribDivisor(3, 1)

glBindBuffer(GL_ARRAY_BUFFER, 0)
glBindVertexArray(0)


view_loc = glGetUniformLocation(program, "view")
proj_loc = glGetUniformLocation(program, "projection")
light_dir_loc = glGetUniformLocation(program, "lightDir")
light_color_loc = glGetUniformLocation(program, "lightColor")

light_dir = normalize(SA_F32[-0.2, -0.5, -1.0])
light_color = SA_F32[1.0, 1.0, 1.0]

t0 = time()
updatefps = FPSCounter()
while !GLFW.WindowShouldClose(window)
    processInput(window)
    updatefps(window)
    
    
    t = Float32(time() - t0)
   
    
    glClearColor(0.2, 0.3, 0.3, 1.0)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

    glUseProgram(program)
    glBindVertexArray(vao[])

    glUniformMatrix4fv(view_loc, 1, GL_FALSE, view_matrix(camera))
    glUniformMatrix4fv(proj_loc, 1, GL_FALSE, projection_matrix(camera))
    glUniform3f(light_dir_loc, light_dir...)
    glUniform3f(light_color_loc, light_color...)

    spins .+= 0.05*(rand(Float32, 3*40000) .- 0.5)

    glBindBuffer(GL_ARRAY_BUFFER, spin_vbo[])
    glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(spins), spins)
    
    glDrawArraysInstanced(GL_TRIANGLES, 0, length(vertices), num_instances)
    
    GLFW.SwapBuffers(window)
    GLFW.PollEvents()
end


glDeleteVertexArrays(1, vao)
glDeleteBuffers(1, vbo)
glDeleteBuffers(1, pos_vbo)
glDeleteBuffers(1, spin_vbo)
GLFW.DestroyWindow(window)


