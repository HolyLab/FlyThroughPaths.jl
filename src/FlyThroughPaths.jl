module FlyThroughPaths

using StaticArrays

export ViewState, Path, Pause, ConstrainedMove, BezierMove
# exports for the extensions
export capture_view, set_view!

include("interfaces.jl")
include("viewstate.jl")
include("pathchange.jl")
include("path.jl")

function __init__()
    if isdefined(Base.Experimental, :register_error_hint)
        Base.Experimental.register_error_hint(MethodError) do io, exc, argtypes, kwargs
            if exc.f === capture_view || exc.f === set_view!
                print(io, '\n', exc.f, " requires that you first load a plotting backend (e.g., `using GLMakie`)")
            end
        end
    end
end

end
