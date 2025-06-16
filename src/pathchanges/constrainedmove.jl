#=
# ConstrainedMove

A [`ConstrainedMove`](@ref) is a [`PathChange`](@ref) that moves the camera 
from the current [`ViewState`](@ref) to a `target` [`ViewState`](@ref) under 
a specified `constraint` and some interpolation / easing in `speed`.

## Example

TODO: add an example here.

## Implementation

First, we define the actual struct according to the contract for [`PathChange`](@ref).
=#


struct ConstrainedMove{T} <: PathChange{T}
    duration::T
    target::ViewState{T}
    constraint::Symbol
    speed::Symbol
    action
    function ConstrainedMove{T}(t, target, constraint, speed, action=nothing) where T
        t >= zero(T) || throw(ArgumentError("t must be non-negative"))
        constraint in (:none,:rotation) || throw(ArgumentError("Unknown constraint: $constraint"))
        speed in (:constant,:sinusoidal) || throw(ArgumentError("Unknown speed: $speed"))
        new{T}(t, target, constraint, speed, action)
    end
end

# This is the implementation of the constrained move.

function (move::ConstrainedMove{T})(view::ViewState{T}, t) where T
    checkt(t, move)
    (; target, constraint, speed, action) = move
    tf = t / duration(move)
    f = speed === :constant ? tf : (1 - cospi(tf))/2
    (; eyeposition, lookat, upvector, fov) = view
    eyeposition_new = something(target.eyeposition, eyeposition)
    lookat_new = something(target.lookat, lookat)
    upvector_new = something(target.upvector, upvector)
    fov_new = something(target.fov, fov)
    lookatf = (1 - f) * lookat + f * lookat_new
    if constraint === :none
        eyeposition = (1 - f) * eyeposition + f * eyeposition_new
    elseif constraint === :rotation
        vold = eyeposition - lookat
        vnew = eyeposition_new - lookat_new
        eyeposition = cospi(f/2) * vold + sinpi(f/2) * vnew + lookatf
    end
    upvector = (1 - f) * upvector + f * upvector_new
    fov = (1 - f) * fov + f * fov_new
    lookat = lookatf
    act(action, f)
    return ViewState{T}(eyeposition, lookat, upvector, fov)
end

# Then, we define more constructors, as well as the [`PathChange`](@ref) API.

"""
    ConstrainedMove(duration::T, target::ViewState{T}, [constraint, speed, action]) where T <: Real

Create a `ConstrainedMove` which represents a movement from the current 
[`ViewState`](@ref) to a `target` [`ViewState`](@ref) over a specified 
`duration`.  The movement can be constrained by `:rotation` or 
unconstrained by `:none`, and can proceed at a `:constant` or `:sinusoidal` 
speed.

# Arguments
- `duration::T`: The duration of the movement, where `T` is a subtype of `Real`.
- `target::ViewState{T}`: The target state to reach at the end of the movement.
- `constraint::Symbol`: The type of constraint on the movement (`:none` or `:rotation`).
- `speed::Symbol`: The speed pattern of the movement (`:constant` or `:sinusoidal`).
- `action`: An optional callback to be called at each step of the movement.


# Examples
```julia
# Move to a new view state over 5 seconds with no rotation and constant speed
move = ConstrainedMove(5.0, new_view_state, :none, :constant)
path *= move
```

This type of `PathChange` is useful for animations where the view needs to 
transition smoothly between two states under certain constraints.
"""
ConstrainedMove{T}(duration, target; constraint=:none, speed=:constant, action=nothing) where T =
    ConstrainedMove{T}(duration, target, constraint, speed, action)
ConstrainedMove(duration, target::ViewState{T}, args...) where T = ConstrainedMove{T}(duration, target, args...)
ConstrainedMove(duration, target::ViewState{T}; kwargs...) where T = ConstrainedMove{T}(duration, target; kwargs...)

Base.convert(::Type{ConstrainedMove{T}}, m::ConstrainedMove) where T = ConstrainedMove{T}(m.duration, m.target, m.constraint, m.speed, m.action)
Base.convert(::Type{PathChange{T}}, m::ConstrainedMove) where T = convert(ConstrainedMove{T}, m)
