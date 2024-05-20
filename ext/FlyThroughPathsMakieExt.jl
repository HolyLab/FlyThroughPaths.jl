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
