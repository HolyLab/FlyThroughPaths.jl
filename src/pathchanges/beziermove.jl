#=
# BezierMove

This moves the camera along a Bezier path parametrized by control points.

## Example

## Implementation
=#

struct BezierMove{T} <: PathChange{T}
    duration::T
    target::ViewState{T}
    controls::Vector{ViewState{T}}
    action

    function BezierMove{T}(t, target, controls, action=nothing) where T
        t >= zero(T) || throw(ArgumentError("t must be non-negative"))
        new{T}(t, target, controls, action)
    end
end

function (move::BezierMove{T})(view::ViewState{T}, t) where T
    filldef(vs) = filldefaults(vs, view)
    checkt(t, move)
    tf = t / duration(move)
    act(move.action, tf)
    list = [view, filldef.(move.controls)..., filldef(move.target)]
    return evaluate(list, tf)
end

"""
    BezierMove(duration::T, target::ViewState{T}, controls::Vector{ViewState{T}}, [action]) where T <: Real

Create a `BezierMove` which represents a movement from the current 
[`ViewState`](@ref) to a `target` [`ViewState`](@ref) over a specified 
`duration`.  The movement is defined by a series of control points, which 
are interpolated between to form a smooth curve.  

See the [Wikipedia article on Bezier curves](https://en.wikipedia.org/wiki/B%C3%A9zier_curve) for more details.

# Arguments
- `duration::T`: The duration of the movement, where `T` is a subtype of `Real`.
- `target::ViewState{T}`: The target state to reach at the end of the movement.
- `controls::Vector{ViewState{T}}`: The control points of the movement.
- `action`: An optional callback to be called at each step of the movement.

# Examples
```julia
# Move to a new view state over 5 seconds with no rotation and constant speed
move = BezierMove(5.0, new_view_state, [new_view_state])
path *= move
```
"""
BezierMove(duration, target::ViewState{R}, controls::Vector{ViewState{S}}, args...) where {R,S} = BezierMove{promote_type(R,S)}(duration, target, controls, args...)

Base.convert(::Type{BezierMove{T}}, m::BezierMove) where T = BezierMove{T}(m.duration, m.target, m.controls, m.action)
Base.convert(::Type{PathChange{T}}, m::BezierMove) where T = convert(BezierMove{T}, m)
