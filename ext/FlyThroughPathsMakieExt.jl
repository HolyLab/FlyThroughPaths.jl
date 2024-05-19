module FlyThroughPathsMakieExt

using FlyThroughPaths
using Makie

function FlyThroughPaths.capture_view(cam::Camera)
    view = ViewState(eyeposition = cam.eyeposition[], lookat = cam.lookat[])
    # TODO: extract fov and upvector from cam
    return view
end
FlyThroughPaths.capture_view(scene::Scene) = capture_view(scene.camera)
FlyThroughPaths.capture_view(fig::Figure) = capture_view(fig.scene)

function FlyThroughPaths.set_view!(cam::Camera, view::ViewState)
    cam.eyeposition[] = view.eyeposition
    cam.lookat[] = view.lookat
    return cam
end
FlyThroughPaths.set_view!(scene::Scene, view::ViewState) = set_view!(scene.camera, view)
FlyThroughPaths.set_view!(fig::Figure, view::ViewState) = set_view!(fig.scene, view)

end
