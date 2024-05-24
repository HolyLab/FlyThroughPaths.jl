```@meta
CurrentModule = FlyThroughPaths
```

# FlyThroughPaths

Documentation for [FlyThroughPaths](https://github.com/HolyLab/FlyThroughPaths.jl).


All of the examples below assume you've loaded the package with `using FlyThroughPaths`.

# Quick start

## Generic tools

### Representation of paths and view state

Paths are parametrized by time `t`, represented in units of seconds. All paths implicitly start at `t=0`.

The representation of view state is independent of any particular plotting package, although our parametrization is inspired by [Makie's 3D camera](https://docs.makie.org/stable/explanations/cameras/#3d_camera):

- `eyeposition`: the 3d coordinates of the camera
- `lookat`: the 3d coordinates of the point of the camera's "focus" (center of gaze)
- `upvector`: the 3d direction that will correspond to the top of the view. Any component of this vector in the direction of `lookat - eyeposition` is ignored/discarded.
- `fov`: the angle (in degrees) of the cone centered on `lookat - eyeposition` that should be captured.

Set these as follows:

```@repl main
using FlyThroughPaths
state = ViewState(eyeposition=[-10, 0, 0], lookat=[0, 0, 0], upvector=[0, 0, 1], fov=45)
```

You can set just a subset of these:
```@repl main
newstate = ViewState(eyeposition=[-5, 0, 0])
```

This syntax is often used for updating a previous view; for the unspecified settings, the previous value is left intact.


### Initializing a path

```@repl main
path = Path(state)
```

The path starts at `state` at time `t=0`.

### Evaluating at a particular time

Once you have a path, you can get the current `ViewState` with `path(t)`:

```@repl main
path(0)

path(10)
```

So far, nothing much is happening. Things get more interesting when we add movements.

### Holding steady

The simplest thing you can do is insert a pause:

```@repl main
path2 = path * Pause(5)
```

The view will hold steady for 5 seconds. Typically you add `Pause` when you also plan to add other movements later.

### Moving the camera, option 1: constrained movements

This option is typically used for things like rotations around a center point.

```@repl main
path2 = path * ConstrainedMove(5, newstate; constraint=:none, speed=:constant)
```

This indicates that over a 5-second period, the camera state gradually adopts any values specified in `newstate`.

```@repl main
path2(0)
path2(5)
path2(2.5)
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

```@repl main
move = BezierMove(5, ViewState(eyeposition=[0, 10, 0]), [ViewState(eyeposition=[-20, 20, 0])])
path2 = path * move;
path2(2.5)
```

## Backend-specific tools

These require interaction with a plotting package supported by one of the extensions. Currently supported:

- [Makie](https://docs.makie.org/stable/)

You need to load the visualization package, e.g., `using GLMakie`, in your session before any of the commands below will work.

### Capturing the current view state

This can be handy for constructing a path, for example you can interactively set the approximate position and view parameters and then query them for use by the tools above.

```julia
state = capture_view(scenelike::Union{Scene, LScene})
```

`state` is a `ViewState` object.

### Setting the current view state

```julia
oldstate = set_view!(scenelike, path, t)
```

This updates the current `camera` settings from `path` at time `t`.

### Displaying the path

```julia
plot(path)
```
