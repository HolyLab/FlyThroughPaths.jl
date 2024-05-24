# Developer documentation

## Implementing support for FlyThroughPaths

FlyThroughPaths operates on the [`ViewState`](@ref) model.  In order to implement support for this in a plotting package, you must implement dispatches for the following two functions:
- `capture_view(obj)::ViewState`: extract the current `ViewState`, i.e., camera settings, from `obj`.
- `set_view!(obj, viewstate::ViewState)`: set the camera to the given `ViewState`.

Integration is already implemented for Makie; you can see that in `ext/FlyThroughPathsMakieExt.jl`.  The first ~20 lines are the most instructive, beyond which lie utility functions and visualization specializations.