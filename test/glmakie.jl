# These "tests" are not run as part of CI, because installing and compiling Makie would take much of the test time.
# It also adds overhead in terms of ensuring a display.
# But you can run them locally.

using GLMakie
using FlyThroughPaths
using LinearAlgebra

# From one of the examples on https://docs.makie.org/stable
r = LinRange(-1, 1, 100)
cube = [(x.^2 + y.^2 + z.^2) for x = r, y = r, z = r]
fig, ax, plt = contour(cube, alpha=0.5)
display(fig)

view0 = capture_view(ax)
# FIXME: workaround for not knowing how to get the upvector and fov from the camera
view0 = ViewState(eyeposition=view0.eyeposition, lookat=view0.lookat, upvector=[0, 0, 1], fov=45)
path = Path(view0)

path = path * ConstrainedMove(5, ViewState(eyeposition=[norm(view0.eyeposition), 0, 0]), :none, :constant)
path = path * Pause(1)
path = path * ConstrainedMove(5, ViewState(eyeposition=view0.eyeposition), :rotation, :constant)

tlist = range(0, stop=15, length=31)

record(fig, "fly_animation.mp4", tlist; framerate=round(Int, length(tlist)/last(tlist))) do t
    set_view!(ax, path(t))
end

# `record` also accepts a `Path` directly, sampling it at `framerate` frames per second
# and setting the view of the object it is given on each frame.  That object is the axis
# (or scene) being flown, not the figure, which would not say which axis to fly.
record(ax, "fly_animation_path.mp4", path; framerate=24)
