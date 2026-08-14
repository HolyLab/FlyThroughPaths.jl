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

# Define the recipe
import FlyThroughPaths: plotcamerapath, plotcamerapath!
"""
    plotcamerapath(path::Path, [time])

Plot the eye positions along `path` as a line coloured by time, with an arrow showing
where the camera is looking at `time` (0 by default).
"""
@recipe PlotCameraPath (path, time) begin
    "Colormap for the path, which is coloured by time."
    colormap = @inherit colormap :plasma
    color = @inherit color :black
    linewidth = @inherit linewidth 1.0
    linestyle = @inherit linestyle :solid
    camera_color = @inherit color :black
    """
    Scales the arrow marking the camera. `automatic` sizes it from the bounding box of
    the path, which is usually what you want, since a path can span any distance.
    """
    camera_markerscale = Makie.automatic
    "Sampling rate of the path, in points per second of path time."
    density = 30
    cycle = [:color]
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
    # The camera arrow has to be sized against the path, not against itself: `automatic`
    # would scale it by its own bounding box, which is a single unit-length arrow.
    arrowscale_obs = lift(plot, plot.camera_markerscale, eyepositions_obs) do scale, eyepositions
        scale isa Makie.Automatic || return Float64(scale)
        length(eyepositions) < 2 && return 1.0
        return 0.15 * maximum(Makie.widths(Rect3d(eyepositions)))
    end

    # `align = :tail` puts the arrow's base at the eye, so it points where the camera looks
    arrows3d!(
        plot,
        @lift([$eyeposition_obs]),
        @lift([$viewdir_obs]);
        color = plot.camera_color,
        lengthscale = arrowscale_obs,
        markerscale = arrowscale_obs,
        normalize = true,
        shading = true,
        align = :tail,
    )


end

end