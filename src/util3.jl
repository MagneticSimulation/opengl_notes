 
using GLFW
using ModernGL
using LinearAlgebra

include(joinpath(@__DIR__, "util2.jl"))


struct PerspectiveCamera
    fov::Float32
    aspect::Float32
    near::Float32
    far::Float32
    position::Vector{Float32}
    target::Vector{Float32}
    up::Vector{Float32}
end

function PerspectiveCamera(fov=π/3, aspect=16/9, near=0.1f0, far=100.0f0)
    PerspectiveCamera(
        fov, aspect, near, far,
        [0f0, 0f0, 2f0],  # position
        [0f0, 0f0, 0f0],  # target
        [0f0, 1f0, 10f0]   # up
    )
end

function projection_matrix(cam::PerspectiveCamera)
    t = tan(cam.fov/2)
    inv_depth  = 1 / (cam.far - cam.near)

    Sx = 1/(cam.aspect*t)
    Sy = 1/t
    Sz = -(cam.far+cam.near)*inv_depth
    Pz = -2*cam.far*cam.near*inv_depth

    proj_mat = GLfloat[ Sx  0.0  0.0  0.0;
                      0.0   Sy  0.0  0.0;
                      0.0  0.0   Sz   Pz;
                      0.0  0.0 -1.0  0.0]
    
    return proj_mat
end


function view_matrix(cam::PerspectiveCamera)
    matrix = GLfloat[1.0 0.0 0.0 -cam.position[1];
                            0.0 1.0 0.0 -cam.position[2];
                            0.0 0.0 1.0 -cam.position[3];
                            0.0 0.0 0.0            1.0]
    return matrix
end


