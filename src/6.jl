
using GLFW, ModernGL, LinearAlgebra

# In this example, we rotate the cone by changing the model matrix

include(joinpath(@__DIR__, "util5.jl"))

# misc. config
const SCR_WIDTH = 800
const SCR_HEIGHT = 600

const vertexShaderSource = """
	#version 330 core
	layout (location = 0) in vec3 aPos;
	layout (location = 1) in vec3 aNormal;

	out vec3 Normal;

	uniform mat4 model;
	uniform mat4 view;
	uniform mat4 projection;
	void main(void)
	{
	    gl_Position = projection * view * model * vec4(aPos.x, aPos.y, aPos.z, 1.0);
    	Normal = mat3(transpose(inverse(model))) * aNormal;
	}"""

const fragmentShaderSource = """
#version 330 core
out vec4 FragColor;

in vec3 Normal;

uniform vec3 lightDir;
uniform vec3 lightColor;
uniform vec3 objectColor;

void main()
{
    float ambientStrength = 0.2;
	float diffStrength = 0.8;
    vec3 ambient = ambientStrength * lightColor;
    
    vec3 norm = normalize(Normal);
    vec3 lightDirection = normalize(-lightDir);
    float diff = max(dot(norm, lightDirection), 0.0);
    vec3 diffuse = diffStrength * diff * lightColor;
    
    vec3 result = (ambient + diffuse) * objectColor;
    FragColor = vec4(result, 1.0);
}"""

window = create_window(SCR_WIDTH, SCR_HEIGHT)

glEnable(GL_DEPTH_TEST)


camera = PerspectiveCamera(
    position=SA_F32[0, 0, 5],
    target=SA_F32[0, 0, 0],
    fov=45.0f0,
    aspect=800/600
)

controls = OrbitControls(window, camera)

GLFW.SetMouseButtonCallback(window, (win, button, action, mods) -> 
    handle_mouse_button!(controls, button, action, mods))

GLFW.SetCursorPosCallback(window, (win, x, y) -> 
    handle_cursor_pos!(controls, x, y))

GLFW.SetScrollCallback(window, (win, dx, dy) -> 
    handle_scroll!(controls, dy))


program = create_shader_program(vertexShaderSource, fragmentShaderSource)

# set up vertex data (and buffer(s)) and configure vertex attributes
vertices = generate_cone_normals()
vboRef = Ref{GLuint}(0)
vaoRef = Ref{GLuint}(0)
glGenVertexArrays(1, vaoRef)
glGenBuffers(1, vboRef)
vao = vaoRef[]
vbo = vboRef[]
glBindVertexArray(vao)
glBindBuffer(GL_ARRAY_BUFFER, vbo)
glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW)

glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE,  6 * sizeof(GLfloat), Ptr{Cvoid}(0))
glEnableVertexAttribArray(0)

# normal
glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(GLfloat), Ptr{Cvoid}(3 * sizeof(GLfloat)))
glEnableVertexAttribArray(1)

# note that this is allowed, the call to glVertexAttribPointer registered VBO as
# the vertex attribute's bound vertex buffer object so afterwards we can safely unbind
glBindBuffer(GL_ARRAY_BUFFER, 0);

# You can unbind the VAO afterwards so other VAO calls won't accidentally modify this VAO,
# but this rarely happens. Modifying other VAOs requires a call to glBindVertexArray anyways
# so we generally don't unbind VAOs (nor VBOs) when it's not directly necessary.
glBindVertexArray(0)

# uncomment this call to draw in wireframe polygons.
# glPolygonMode(GL_FRONT_AND_BACK, GL_LINE)


model_loc = glGetUniformLocation(program, "model")
view_loc = glGetUniformLocation(program, "view")
projection_loc = glGetUniformLocation(program, "projection")

lightDir_loc = glGetUniformLocation(program, "lightDir")
lightColor_loc = glGetUniformLocation(program, "lightColor")
objectColor_loc = glGetUniformLocation(program, "objectColor")

model_mat = Matrix{GLfloat}(I, 4, 4)

println(view_matrix(camera))

positions = [
	(i*1.0f0, j*1.0f0, 0.0f0) for i=0:8, j=0:4
]

aspect_ratio = SCR_WIDTH/SCR_HEIGHT

light_dir = [-0.0f0, -0.0f0, -1.0f0]  # 光照方向
light_color = [1.0f0, 1.0f0, 1.0f0]    # 白光
object_color = [1.0f0, 0.5f0, 0.31f0]  # 物体颜色

t0 = time()
# render loop
while !GLFW.WindowShouldClose(window)
    processInput(window)

    # render
    glClearColor(0.2, 0.3, 0.3, 1.0)
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    glViewport(0, 0, GLFW.GetFramebufferSize(window)...)

    # draw
	glUseProgram(program)
    glBindVertexArray(vao)

	glUniform3f(lightDir_loc, light_dir...)
    glUniform3f(lightColor_loc, light_color...)
    glUniform3f(objectColor_loc, object_color...)

	glUniformMatrix4fv(view_loc, 1, GL_FALSE, view_matrix(camera))
	glUniformMatrix4fv(projection_loc, 1, GL_FALSE, projection_matrix(camera))

	t = time() - t0
	for i = 1:length(positions)
		(x, y, z) = positions[i]
		mat = GLfloat[1 0 0 x;
					0 1 0 y;
					0 0 1 z;
					0 0 0 1];
		rotate_around_axis!(mat, t+i*pi/6, [1,2,3])
		glUniformMatrix4fv(model_loc, 1, GL_FALSE, mat)
		glDrawArrays(GL_TRIANGLES, 0, length(vertices))
	end

    # swap buffers and poll IO events
    GLFW.SwapBuffers(window)
    GLFW.PollEvents()
end

# optional: de-allocate all resources once they've outlived their purpose
glDeleteVertexArrays(1, vaoRef)
glDeleteBuffers(1, vboRef)

GLFW.DestroyWindow(window)
