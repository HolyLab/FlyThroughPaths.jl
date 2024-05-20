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

end


# Define the recipe
import FlyThroughPaths: plotcamerapath, plotcamerapath!
@recipe(PlotCameraPath, path, time) do scene
    Attributes(
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

using Makie: Point3d
function Makie.plot!(plot::PlotCameraPath)
    # Main.@infiltrate

    eyepositions_obs = lift(plot, plot.path, plot.density) do path, density
        tend = FlyThroughPaths.duration(path)
        trange = LinRange(0, tend, round(Int, tend*density))
        Makie.Point3d.(getproperty.(path.(trange), :eyeposition))
    end
    notify(plot.density) # run the `onany` once

    eyeposition_obs = Observable{Point3d}(plot.path[](0).eyeposition)
    lookat_obs = Observable{Point3d}(plot.path[](0).lookat)
    viewdir_obs = Observable{Point3d}(plot.path[](0).lookat)

    current_viewstate_obs = lift(plot, plot.path, plot.time) do path, time
        current_viewstate = path(time)
        eyeposition_obs.val = current_viewstate.eyeposition |> Point3d
        lookat_obs.val = current_viewstate.lookat |> Point3d
        viewdir = (current_viewstate.lookat - current_viewstate.eyeposition)
        viewdir_obs.val = Point3d(viewdir)
        notify(eyeposition_obs)
        notify(lookat_obs)
        notify(viewdir_obs)
        current_viewstate
    end



    lines!(
        plot, 
        eyepositions_obs;
        color = plot.color, 
        linewidth = plot.linewidth, 
        linestyle = plot.linestyle
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