# Makie integration

FlyThroughPaths.jl is integrated with Makie.jl `LScene`s, which are 
the standard axis for 3-D plots.

## Orbiting a point

Here's a simple example:

```@example simple
using GLMakie, FlyThroughPaths

fig, ax, plt = surface(-8..8, -8..8, Makie.peaks())
```

Now, we can use FlyThroughPaths to orbit the camera around the 
current `lookat` point, by changing the eye position.

### Extracting the view

First, we extract the initial view state from the axis `ax`.

```@example simple
view0 = capture_view(ax)
```
Note that this `ViewState` is a Float32 object, since that's the space
Makie cameras work in.  If you want this to be Float64, you can 
simply `convert(ViewState{Float64}, view0)`.

### Creating a path

Next, we create a `Path` with this initial state.
```@example simple
path = Path(view0)
```
We've now created a `Path` object with an initial state `view0`.  
`Path`s contain instructions for how to move the camera in time, and 
you can add to a path by `path * new_component`.

```@example simple
path = path * ConstrainedMove(
    5,          # the amount of time the move should take
    ViewState(eyeposition = [0, 0, 46]), # the final state of the camera
    :rotation,  # the rotation constraint (can also be `:none`)
    :constant   # the type of interpolation (can also be `:sinusoidal`)
)
```
Here, we've added a `ConstrainedMove` to the path, which moves the 
camera to the point `[0, 0, 46]` in 5 seconds.

The reasons I chose these particular coordinates was to preserve the 
norm (`norm(view0.eyeposition) ≈ 46`, `norm(new) ≈ 46`), so that the 
rotation looks as elliptical as it can.

### Animating the camera

Now, we can use Makie's `record` function to record an animation with 
this:
```@example simple
record(fig, "path.mp4", LinRange(0, 5, 150); framerate = 30) do t
    set_view!(ax, path(t))
end
```
![A rotating view of a surface](path.mp4)

### Zooming

We can also zoom in by changing the field of view, `fov`:
```@example simple
path = path * ConstrainedMove(5, ViewState(; fov = 10), :none, :sinusoidal)
```
In this case, we chose sinusoidal interpolation to get a smooth zoom.
```@example simple
record(fig, "path_zoom.mp4", LinRange(5, 10, 150); framerate = 30) do t
    set_view!(ax, path(t))
end
```
![A zooming view of a surface](path_zoom.mp4)

## Visualizing the camera's path

```@example simple
f2, a2, p2 = surface(-8..8, -8..8, Makie.peaks())
pathplot = FlyThroughPaths.plotcamerapath!(a2, path, 7)
Makie.rotate_cam!(a2.scene, 0, pi/4, 0)
f2
```

We can also animate the path to understand it more:
```@example simple
record(f2, "camera_path.mp4", LinRange(0, 5, 150); framerate = 30, update = false) do t
    pathplot.time[] = t
end
```
![](camera_path.mp4)

## Visualizing the viewing frustum
```@example simple
using Makie.GeometryBasics
# Initialize a rectangle that covers all of clip space in the initial Scene
frustum_clip_rect = Rect3d(Point3d(-1), Point3d(2))
# Convert that rectangle to a mesh
frustum_clip_mesh = lift(ax.scene.camera.projectionview) do _
    fcm = normal_mesh(frustum_clip_rect)
    # Project the mesh to `ax.scene`'s data space (which is shared with `a2.scene)
    frustum_world_points = Makie.project.(ax.scene, :clip, :data, fcm.position)
    # Reassign the projected points to the mesh positions
    fcm.position .= frustum_world_points
    return fcm
end

mesh!(a2.scene, frustum_clip_mesh; color = (:blue, 0.3), shading = Makie.MultiLightShading, xautolimits = false, yautolimits = false, zautolimits = false, transparency = false,)

wireframe!(a2.scene, frustum_clip_mesh; color = (:blue, 0.3), linewidth = 1, xautolimits = false)
f2
```
Since the frustum mesh is an Observable linked to the first Scene's camera, we can animate it at no extra cost!
```@example simple
record(f2, "camera_path_frustum.mp4", LinRange(0, 10, 300); framerate = 30, update = false) do t
    set_view!(ax, path(t))
    pathplot.time[] = t
end
```
![A constant view of the previous surface and camera system](camera_path_frustum.mp4)

## Bézier paths

