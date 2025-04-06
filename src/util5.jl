using ModernGL
using StaticArrays
using LinearAlgebra
using GLFW

include(joinpath(@__DIR__, "util2.jl"))

#= Three.js style design pattern =#
mutable struct PerspectiveCamera
    position::SVector{3, Float32}
    target::SVector{3, Float32}
    up::SVector{3, Float32}
    fov::Float32
    aspect::Float32
    near::Float32
    far::Float32
end

mutable struct OrbitControls
    window::GLFW.Window
    camera::PerspectiveCamera
    # Orbital parameters
    radius::Float32      # Distance from camera to target
    min_radius::Float32
    max_radius::Float32
    theta::Float32       # Horizontal angle (radians)
    phi::Float32         # Vertical angle (radians)
    # Interaction state
    rotate_speed::Float32
    pan_speed::Float32
    zoom_speed::Float32
    # Mouse state
    mouse_down::Bool
    last_pos::Tuple{Float32, Float32}
end

# Initialization functions
function PerspectiveCamera(;
    fov=45.0f0,
    aspect=16/9,
    near=0.1f0,
    far=100.0f0,
    position=SA_F32[0, 0, 5],
    target=SA_F32[0, 0, 0],
    up=SA_F32[0, 1, 0]
)
    PerspectiveCamera(position, target, up, fov, Float32(aspect), near, far)
end

function OrbitControls(
    window::GLFW.Window,
    camera::PerspectiveCamera;
    rotate_speed=0.005f0,
    pan_speed=0.005f0,
    zoom_speed=0.1f0,
    min_radius=0.1f0,
    max_radius=100.0f0
)
    # Initialize spherical coordinates
    dir = camera.position - camera.target
    radius = norm(dir)
    theta = atan(dir[3], dir[1])
    phi = acos(dir[2]/radius)
    
    OrbitControls(
        window,
        camera,
        radius, min_radius, max_radius,
        theta, phi,
        rotate_speed, pan_speed, zoom_speed,
        false, (0.0f0, 0.0f0)
    )
end

#= Core control logic =#
function update_camera_position!(controls::OrbitControls)
    # Convert spherical coordinates to Cartesian
    controls.radius = clamp(controls.radius, controls.min_radius, controls.max_radius)
    controls.phi = clamp(controls.phi, 0.001f0, π - 0.001f0)  # Prevent flipping
    
    x = controls.radius * sin(controls.phi) * cos(controls.theta)
    y = controls.radius * cos(controls.phi)
    z = controls.radius * sin(controls.phi) * sin(controls.theta)
    
    controls.camera.position = controls.camera.target + SA_F32[x, y, z]
end

# View matrix generation
function view_matrix(camera::PerspectiveCamera)
    look_at(camera.position, camera.target, camera.up)
end

# Projection matrix generation
function projection_matrix(camera::PerspectiveCamera)
    fov_rad = deg2rad(camera.fov)
    tan_half_fov = tan(fov_rad / 2)
    
    sx = 1 / (camera.aspect * tan_half_fov)
    sy = 1 / tan_half_fov
    sz = -(camera.far + camera.near) / (camera.far - camera.near)
    pz = -(2 * camera.far * camera.near) / (camera.far - camera.near)
    
    GLfloat[
        sx   0     0     0
        0    sy    0     0
        0    0     sz    pz
        0    0    -1    0
    ]
end

#= Input handling =#
function handle_mouse_button!(controls::OrbitControls, button, action, mods)
    controls.mouse_down = (action == GLFW.PRESS)
end

function handle_cursor_pos!(controls::OrbitControls, xpos, ypos)
    if !controls.mouse_down
        controls.last_pos = (xpos, ypos)
        return
    end
    
    dx = xpos - controls.last_pos[1]
    dy = ypos - controls.last_pos[2]
    controls.last_pos = (xpos, ypos)
    
    # Shift for panning, else rotate
    if GLFW.GetKey(controls.window, GLFW.KEY_LEFT_SHIFT) == GLFW.PRESS
        pan!(controls, dx, dy)
    else
        rotate!(controls, dx, dy)
    end
end

function handle_scroll!(controls::OrbitControls, yoffset)
    zoom!(controls, yoffset)
end

# Rotation control
function rotate!(controls::OrbitControls, dx, dy)
    controls.theta -= dx * controls.rotate_speed
    controls.phi += dy * controls.rotate_speed
    update_camera_position!(controls)
end

function pan!(controls::OrbitControls, dx, dy)
    # Calculate camera-relative axes
    forward = normalize(controls.camera.target - controls.camera.position)
    right = normalize(cross(forward, controls.camera.up))
    up = normalize(cross(right, forward))
    
    # Reverse horizontal direction by multiplying dx by -1
    delta = right * (-dx * controls.pan_speed) + up * (dy * controls.pan_speed)
    
    # Update both target and position
    controls.camera.target += delta
    controls.camera.position += delta
end


# Zoom control
function zoom!(controls::OrbitControls, delta)
    controls.radius *= (1 - delta * controls.zoom_speed)
    update_camera_position!(controls)
end

#= Helper functions =#
function look_at(eye, target, up)
    forward = normalize(target - eye)
    right = normalize(cross(forward, up))
    new_up = cross(right, forward)
    
    rotation = GLfloat[
        right[1]  right[2]  right[3]  0
        new_up[1]  new_up[2]  new_up[3]  0
        -forward[1]  -forward[2]  -forward[3]  0
        0         0          0            1
    ]
    
    translation = GLfloat[
        1  0  0  -eye[1]
        0  1  0  -eye[2]
        0  0  1  -eye[3]
        0  0  0   1
    ]
    
    return rotation * translation
end