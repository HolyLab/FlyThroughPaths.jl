module FlyThroughPathsMakieExt

using FlyThroughPaths
using Makie

function FlyThroughPaths.capture_view(cam::Camera3D)
    view = ViewState(eyeposition = cam.eyeposition[], lookat = cam.lookat[], fov = cam.fov[], upvector = cam.upvector[])
    return view
end
FlyThroughPaths.capture_view(scene::Scene) = capture_view(cameracontrols(scene))
FlyThroughPaths.capture_view(axis::Makie.AbstractAxis) = capture_view(axis.scene) # by convention, all axes have a `ax.scene` that holds the scene with content

function FlyThroughPaths.set_view!(scene::Scene, view::ViewState)
    # Extract the camera controls from the Scene
    cam = Makie.cameracontrols(scene)
    @assert cam isa Makie.Camera3D "`cameracontrols(scene)` must be a `Camera3D`, we don't support any other camera.  Got $(typeof(cam))."
    # Set the appropriate fields
    cam.eyeposition[] = view.eyeposition
    cam.lookat[] = view.lookat
    cam.upvector[] = view.upvector
    cam.fov[] = view.fov
    # Update the camera using the new controls
    Makie.update_cam!(scene, cam)
    return scene
end
FlyThroughPaths.set_view!(axis::Makie.AbstractAxis, view::ViewState) = set_view!(axis.scene, view)
# A `FigureAxisPlot` names its axis, so there is nothing to guess here
FlyThroughPaths.set_view!(figaxplot::Makie.FigureAxisPlot, view::ViewState) = set_view!(figaxplot.axis, view)

"""
    record(object, file, path::Path; framerate = 24, kwargs...)

Record a video of the camera of `object` flying along `path`, sampling the path
`framerate` times per second of path time.  Remaining keyword arguments are forwarded to
`Makie.record`.

`object` is whatever the path drives: a `Scene`, an axis, or a `FigureAxisPlot` (which
names its axis).  Recording an axis records the whole figure it belongs to.  A bare
`Figure` is not accepted, because it does not say which of its axes should be flown; use
`record(fig, file, trange) do t; set_view!(ax, path(t)); end` when you need one.
"""
function Makie.record(scene::Scene, file::String, path::Path; kwargs...)
    return _record_path(scene, scene, file, path; kwargs...)
end
function Makie.record(axis::Makie.AbstractAxis, file::String, path::Path; kwargs...)
    return _record_path(Makie.root(axis.scene), axis, file, path; kwargs...)
end
function Makie.record(figaxplot::Makie.FigureAxisPlot, file::String, path::Path; kwargs...)
    return Makie.record(figaxplot.axis, file, path; kwargs...)
end

function _record_path(figlike, viewtarget, file::String, path::Path; framerate = 24, kwargs...)
    trange = LinRange(0, FlyThroughPaths.duration(path), FlyThroughPaths.nframes(path, framerate))
    views = path(trange)  # one pass over the path, rather than a search per frame
    return Makie.record(figlike, file, views; framerate, kwargs...) do viewstate
        set_view!(viewtarget, viewstate)
    end
end

# Define the recipe
import FlyThroughPaths: plotcamerapath, plotcamerapath!
@recipe(PlotCameraPath, path, time) do scene
    Attributes(
        colormap = Makie.inherit(scene, :colormap, :plasma),
        color = Makie.inherit(scene, :color, :black),
        linewidth = Makie.inherit(scene, :linewidth, 1.0),
        linestyle = Makie.inherit(scene, :linestyle, :solid),
        camera_marker = Makie.inherit(scene, :marker, :none),
        camera_color = Makie.inherit(scene, :color, :black),
        camera_markersize = Vec3f(2, 2, 3),
        density = 30, # points per second
        cycle = [:color,],
    )
end

Makie.convert_arguments(::Type{<: PlotCameraPath}, path::Path, time::Number) = (path, Float64(time))
Makie.convert_arguments(::Type{<: PlotCameraPath}, path::Path) = (path, 0.0)

using Makie: Point3d
function Makie.plot!(plot::PlotCameraPath)
    eyepositions_obs = Observable{Vector{Point3d}}()
    trange_obs = Observable{LinRange{Float64}}()
    onany(plot, plot.path, plot.density; update = true) do path, density
        tend = FlyThroughPaths.duration(path)
        trange_obs.val = LinRange(0.0, Float64(tend), FlyThroughPaths.nframes(path, density))
        eyepositions_obs.val = Makie.Point3d.(getproperty.(path(trange_obs.val), :eyeposition))
        notify(eyepositions_obs)
        notify(trange_obs)
    end
    notify(plot.density) # run the `onany` once

    eyeposition_obs = Observable{Point3d}(plot.path[](0).eyeposition)
    lookat_obs = Observable{Point3d}(plot.path[](0).lookat)
    viewdir_obs = Observable{Point3d}(plot.path[](0).lookat)

    current_viewstate_obs = lift(plot, plot.path, plot.time) do path, time
        current_viewstate = path(time)
        eyeposition_obs.val = Point3d(current_viewstate.eyeposition)
        lookat_obs.val = Point3d(current_viewstate.lookat)
        viewdir = current_viewstate.lookat - current_viewstate.eyeposition
        viewdir_obs.val = Point3d(viewdir)
        notify(eyeposition_obs)
        notify(lookat_obs)
        notify(viewdir_obs)
        current_viewstate
    end

    # Now that we have the Observables defined, 
    # we can create the plots!
    lines!(
        plot, 
        eyepositions_obs;
        color = trange_obs,
        colormap = plot.colormap, 
        linewidth = plot.linewidth, 
        linestyle = plot.linestyle,
    )
    arrows!(
        plot, 
        @lift([$eyeposition_obs]), 
        @lift([$viewdir_obs]);
        color = plot.camera_color, 
        arrowsize = plot.camera_markersize, 
        normalize = true, 
        shading = Makie.MultiLightShading,
        align = :headstart,
    )


end

end