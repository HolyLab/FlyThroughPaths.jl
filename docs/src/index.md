```@meta
CurrentModule = FlyThroughPaths
```

# FlyThroughPaths

Documentation for [FlyThroughPaths](https://github.com/HolyLab/FlyThroughPaths.jl).


All of the examples below assume you've loaded the package with `using FlyThroughPaths`.

## Generic tools

### Representation of paths and view state

Paths are parametrized by time `t`, represented in units of seconds. All paths implicitly start at `t=0`.

The representation of view state is independent of any particular plotting package, although our parametrization is inspired by [Makie's 3D camera](https://docs.makie.org/stable/explanations/cameras/#3d_camera):

- `eyeposition`: the 3d coordinates of the camera
- `lookat`: the 3d coordinates of the point of the camera's "focus" (center of gaze)
- `upvector`: the 3d direction that will correspond to the top of the view. Any component of this vector in the direction of `lookat - eyeposition` is ignored/discarded.
- `fov`: the angle (in degrees) of the cone centered on `lookat - eyeposition` that should be captured.

Set these as follows:

```julia
julia> state = ViewState(eyeposition=[-10, 0, 0], lookat=[0, 0, 0], upvector=[0, 0, 1], fov=45)
ViewState{Float32}(eyeposition=[-10.0, 0.0, 0.0], lookat=[0.0, 0.0, 0.0], upvector=[0.0, 0.0, 1.0], fov=45.0)
```

You can set just a subset of these:
```julia
julia> newstate = ViewState(eyeposition=[-5, 0, 0])
ViewState{Float32}(eyeposition=[-5.0, 0.0, 0.0])
```

This syntax is often used for updating a previous view; for the unspecified settings, the previous value is left intact.


### Initializing a path

```julia
julia> path = Path(state)
Path{Float32}(ViewState{Float32}(eyeposition=[-10.0, 0.0, 0.0], lookat=[0.0, 0.0, 0.0], upvector=[0.0, 0.0, 1.0], fov=45.0), FlyThroughPaths.PathChange{Float32}[])
```

The path starts at `state` at time `t=0`.

### Evaluating at a particular time

Once you have a path, you can get the current `ViewState` with `path(t)`:

```julia
julia> path(0)
ViewState{Float32}(eyeposition=[-10.0, 0.0, 0.0], lookat=[0.0, 0.0, 0.0], upvector=[0.0, 0.0, 1.0], fov=45.0)

julia> path(10)
ViewState{Float32}(eyeposition=[-10.0, 0.0, 0.0], lookat=[0.0, 0.0, 0.0], upvector=[0.0, 0.0, 1.0], fov=45.0)
```

So far, nothing much is happening. Things get more interesting when we add movements.

### Holding steady

The simplest thing you can do is insert a pause:

```julia
julia> path2 = path * Pause(5)
Path{Float32}(ViewState{Float32}(eyeposition=[-10.0, 0.0, 0.0], lookat=[0.0, 0.0, 0.0], upvector=[0.0, 0.0, 1.0], fov=45.0), FlyThroughPaths.PathChange{Float32}[Pause{Float32}(5.0f0, nothing)])
```

The view will hold steady for 5 seconds. Typically you add `Pause` when you also plan to add other movements later.

### Moving the camera, option 1: constrained movements

This option is typically used for things like rotations around a center point.

```julia
julia> path2 = path * ConstrainedMove(5, newstate; constraint=:none, speed=:constant)
Path{Float32}(ViewState{Float32}(eyeposition=[-10.0, 0.0, 0.0], lookat=[0.0, 0.0, 0.0], upvector=[0.0, 0.0, 1.0], fov=45.0), FlyThroughPaths.PathChange{Float32}[ConstrainedMove{Float32}(5.0f0, ViewState{Float32}(eyeposition=[-5.0, 0.0, 0.0]), :none, :constant, nothing)])
```

This indicates that over a 5-second period, the camera state gradually adopts any values specified in `newstate`.

```julia
julia> path2(0)
ViewState{Float32}(eyeposition=[-10.0, 0.0, 0.0], lookat=[0.0, 0.0, 0.0], upvector=[0.0, 0.0, 1.0], fov=45.0)

julia> path2(5)
ViewState{Float32}(eyeposition=[-5.0, 0.0, 0.0], lookat=[0.0, 0.0, 0.0], upvector=[0.0, 0.0, 1.0], fov=45.0)

julia> path2(2.5)
ViewState{Float32}(eyeposition=[-7.5, 0.0, 0.0], lookat=[0.0, 0.0, 0.0], upvector=[0.0, 0.0, 1.0], fov=45.0)
```

Keyword options include:

- `constraint` (`:none` or `:rotation`): specify a value to keep constant during motion. `:rotation` performs a rotation around `lookat`. Note that if the separation between `eyeposition` and `lookat` is not constant, then the trajectory will be elliptical rather than circular.
- `speed` controls how the change is made across time:
  - `:constant`: speed is instantaneously set to a new constant value that will arrive at the endpoint at the specified time
  - `:sinusoidal`: speed will initially increase (starting at a speed of 0), achieve a maximum at the midpoint, and then decrease back to 0.


### Moving the camera, option 2: Bezier movements

With this option, you can approximately simulate the feeling of flight, preserving momentum:

```
path2 = path * BezierMove(Δt::Real, P1::ViewState, P2::ViewState...)
```

where a `bezier` path is specified as indicated in this diagram:

![bezier diagram](https://upload.wikimedia.org/wikipedia/commons/thumb/d/d0/Bezier_curve.svg/640px-Bezier_curve.svg.png)

The starting state, `P0` in the diagram, is taken from the endpoint of `path`. Over the next `Δt` seconds, one then moves towards the last `ViewState` argument of `bezier`, orienting successively towards any prior arguments. Probably the most robust option is to use `bezier(Δt, P1, P2, P3)`, which can be interpreted as "depart `P0` traveling towards `P1`, and arrive at `P3` as if you had come from `P2`." The view does not actually pass through `P1` and `P2`, but these set the initial and final tangents of the curve.

To see this in action, let's create a move that "rotates" around the origin but moves outward (to a more distant orbit) on its way there:

```julia
julia> move = BezierMove(5, ViewState(eyeposition=[0, 10, 0]), [ViewState(eyeposition=[-20, 20, 0])])
BezierMove{Float32}(5.0f0, ViewState{Float32}(eyeposition=[0.0, 10.0, 0.0]), ViewState{Float32}[ViewState{Float32}(eyeposition=[-20.0, 20.0, 0.0])], nothing)

julia> path2 = path * move;

julia> path2(2.5)
ViewState{Float32}(eyeposition=[-12.5, 12.5, 0.0], lookat=[0.0, 0.0, 0.0], upvector=[0.0, 0.0, 1.0], fov=45.0)
```

## Backend-specific tools

These require interaction with a plotting package supported by one of the extensions. Currently supported:

- [Makie](https://docs.makie.org/stable/)

You need to load the visualization package, e.g., `using GLMakie`, in your session before any of the commands below will work.

### Capturing the current view state

This can be handy for constructing a path, for example you can interactively set the approximate position and view parameters and then query them for use by the tools above.

```julia
state = capture_view(scene)
```

`state` is a `ViewState` object.

### Setting the current view state

```julia
oldstate = set_view!(camera, path, t)
```

This updates the current `camera` settings from `path` at time `t`.

### Displaying the path

```julia
plot(path)
```
