
using GLFW, ModernGL, LinearAlgebra

# In this example, we rotate the cone by changing the model matrix

include(joinpath(@__DIR__, "util2.jl"))

# misc. config
const SCR_WIDTH = 800
const SCR_HEIGHT = 600

const vertexShaderSource = """
	#version 330 core
	layout (location = 0) in vec3 aPos;

	uniform mat4 model;
	void main(void)
	{
	    gl_Position = model * vec4(aPos.x, aPos.y, aPos.z, 1.0);
	}"""

const fragmentShaderSource = """
	#version 330 core
	out vec4 FragColor;
	void main(void)
	{
	    FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);
	}"""

window = create_window(SCR_WIDTH, SCR_HEIGHT)

program = create_shader_program(vertexShaderSource, fragmentShaderSource)

# set up vertex data (and buffer(s)) and configure vertex attributes
vertices = generate_cone()
vboRef = Ref{GLuint}(0)
vaoRef = Ref{GLuint}(0)
glGenVertexArrays(1, vaoRef)
glGenBuffers(1, vboRef)
vao = vaoRef[]
vbo = vboRef[]
glBindVertexArray(vao)
glBindBuffer(GL_ARRAY_BUFFER, vbo)
glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW)
glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(GLfloat), Ptr{Cvoid}(0))
glEnableVertexAttribArray(0)

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
model_mat = Matrix{GLfloat}(I, 4, 4)
glUniformMatrix4fv(model_loc, 1, GL_FALSE, model_mat)


t0 = time()
# render loop
while !GLFW.WindowShouldClose(window)
    processInput(window)

    # render
    glClearColor(0.2, 0.3, 0.3, 1.0)
    glClear(GL_COLOR_BUFFER_BIT)

	# draw
	glUseProgram(program)
    glBindVertexArray(vao)

	t = time() - t0
	rotate_around_axis!(model_mat, t, [1,2,3])

	glUniformMatrix4fv(model_loc, 1, GL_FALSE, model_mat)
	glDrawArrays(GL_TRIANGLES, 0, length(vertices))

    # swap buffers and poll IO events
    GLFW.SwapBuffers(window)
    GLFW.PollEvents()
end

# optional: de-allocate all resources once they've outlived their purpose
glDeleteVertexArrays(1, vaoRef)
glDeleteBuffers(1, vboRef)

GLFW.DestroyWindow(window)
