

function generate_cone(;radius=0.1, segments=12, head=0.5)
    vertices = Float32[]

    for i in 0:segments-1
        θ = 2π * i / segments
        push!(vertices, 0.0f0, 0.0f0, 0.0f0)
        push!(vertices, radius*cos(θ), radius*sin(θ), 0)
        θ = 2π * (i + 1) / segments
        push!(vertices, radius*cos(θ), radius*sin(θ), 0)
    end

    for i in 0:segments-1
        θ = 2π * i / segments
        push!(vertices, 0.0f0, 0.0f0, head)
        push!(vertices, radius*cos(θ), radius*sin(θ), 0)
        θ = 2π * (i + 1) / segments
        push!(vertices, radius*cos(θ), radius*sin(θ), 0)
    end
    
    return vertices
end


function compile_shader(source, shaderType)
    shader = glCreateShader(shaderType)
    glShaderSource(shader, 1, Ptr{GLchar}[pointer(source)], C_NULL)
    glCompileShader(shader)
    
    success = Ref{GLint}(0)
    glGetShaderiv(shader, GL_COMPILE_STATUS, success)
    if success[] != GL_TRUE
        infoLog = Vector{GLchar}(512)
        glGetShaderInfoLog(shader, 512, C_NULL, infoLog)
        error("Shader compilation failed: ", String(infoLog))
    end
    return shader
end