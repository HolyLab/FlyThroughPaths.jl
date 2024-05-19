module FlyThroughPathsMakieExt

using FlyThroughPaths
using Makie

function FlyThroughPaths.capture_view(cam::Camera3D)
    view = ViewState(eyeposition = cam.eyeposition[], lookat = cam.lookat[], fov = cam.fov[], upvector = cam.upvector[])
    # TODO: extract fov and upvector from cam
    return view
end
FlyThroughPaths.capture_view(scene::Scene) = capture_view(cameracontrols(scene))
FlyThroughPaths.capture_view(axis::Makie.AbstractAxis) = capture_view(axis.scene) # by convention, all axes have a `ax.scene` that holds the scene with content

function FlyThroughPaths.set_view!(scene::Scene, view::ViewState)
    Makie.update_cam!(scene, view.eyeposition, view.lookat, view.upvector)
    cameracontrols(scene).fov[] = view.fov[]
    return scene
end
# FlyThroughPaths.set_view!(scene::Scene, view::ViewState) = set_view!(cameracontrols(scene), view)
FlyThroughPaths.set_view!(axis::Makie.AbstractAxis, view::ViewState) = set_view!(axis.scene, view)

end
