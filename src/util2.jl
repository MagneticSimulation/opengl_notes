 
using GLFW
using ModernGL
using LinearAlgebra

include(joinpath(@__DIR__, "util1.jl"))

# whenever the window size changed (by OS or user resize) this callback function executes
function framebuffer_size_callback(window::GLFW.Window, width::Cint, height::Cint)
    # make sure the viewport matches the new window dimensions; note that width and
    # height will be significantly larger than specified on retina displays.
	glViewport(0, 0, width, height)
end

# process all input: query GLFW whether relevant keys are pressed/released this frame and react accordingly
function processInput(window::GLFW.Window)
    GLFW.GetKey(window, GLFW.KEY_ESCAPE) == GLFW.PRESS && GLFW.SetWindowShouldClose(window, true)
end


function create_window(width, height, name="Hello")
    GLFW.DefaultWindowHints()

    GLFW.WindowHint(GLFW.CONTEXT_VERSION_MAJOR, 3)
    GLFW.WindowHint(GLFW.CONTEXT_VERSION_MINOR, 3)
    GLFW.WindowHint(GLFW.OPENGL_PROFILE, GLFW.OPENGL_CORE_PROFILE)
    GLFW.WindowHint(GLFW.OPENGL_FORWARD_COMPAT, GL_TRUE)
    
    # create window
    window = GLFW.CreateWindow(width, height, name)
    window == C_NULL && error("Failed to create GLFW window.")
    GLFW.MakeContextCurrent(window)
    GLFW.SetFramebufferSizeCallback(window, framebuffer_size_callback)

    return window
end


"""
    create_shader_program(vertex_shader_source::String, fragment_shader_source::String) -> GLuint

Compiles and links vertex and fragment shaders into a shader program.

# Arguments
- `vertex_shader_source`: GLSL source code for the vertex shader
- `fragment_shader_source`: GLSL source code for the fragment shader

# Returns
- Linked shader program ID (GLuint)

# Throws
- Error with compilation/linking log if any step fails
"""
function create_shader_program(vertex_shader_source::String, fragment_shader_source::String)
    # Compile both shaders using the provided compile_shader function
    vertex_shader = compile_shader(vertex_shader_source, GL_VERTEX_SHADER)
    fragment_shader = compile_shader(fragment_shader_source, GL_FRAGMENT_SHADER)

    # Create and link the shader program
    shader_program = glCreateProgram()
    glAttachShader(shader_program, vertex_shader)
    glAttachShader(shader_program, fragment_shader)
    glLinkProgram(shader_program)

    # Check linking status
    success = Ref{GLint}(0)
    glGetProgramiv(shader_program, GL_LINK_STATUS, success)
    if success[] != GL_TRUE
        # Get error log before cleanup
        info_log = Vector{GLchar}(512)
        glGetProgramInfoLog(shader_program, 512, C_NULL, info_log)
        
        # Clean up resources
        glDeleteShader(vertex_shader)
        glDeleteShader(fragment_shader)
        glDeleteProgram(shader_program)
        
        error("Shader program linking failed:\n", String(info_log))
    end

    # Clean up shader objects (they're now linked and no longer needed)
    glDeleteShader(vertex_shader)
    glDeleteShader(fragment_shader)

    return shader_program
end


function rotate_around_axis!(matrix::Matrix{Float32}, angle_radians, axis::Vector)
    # Normalize the axis vector
    n = normalize(axis)
    x, y, z = n

    # Compute rotation matrix components
    c = cos(angle_radians)
    s = sin(angle_radians)
    t = 1 - c

    # Create rotation matrix (column-major order for OpenGL)

    rotation = Float32[
        t*x*x + c      t*x*y - z*s    t*x*z + y*s;
        t*x*y + z*s    t*y*y + c      t*y*z - x*s; 
        t*x*z - y*s    t*y*z + x*s    t*z*z + c;
    ]

    matrix[1:3, 1:3] .= rotation
end