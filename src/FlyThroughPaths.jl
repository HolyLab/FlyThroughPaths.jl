module FlyThroughPaths

using StaticArrays
using Rotations 

export ViewState, Path
# exports for the extensions
export capture_view, set_view!

include("interfaces.jl")
include("viewstate.jl")
include("pathchange.jl")
include("path.jl")

# path changes
include("pathchanges/beziermove.jl")
include("pathchanges/constrainedmove.jl")
include("pathchanges/pause.jl")

export BezierMove, ConstrainedMove, Pause

function __init__()
    if isdefined(Base.Experimental, :register_error_hint)
        Base.Experimental.register_error_hint(MethodError) do io, exc, argtypes, kwargs
            if exc.f in (capture_view, set_view!, plotcamerapath, plotcamerapath!)
                print(io, '\n', exc.f, " requires that you first load a plotting backend (e.g., `using GLMakie`)")
            end
        end
    end
end

end
