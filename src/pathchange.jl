"""
    abstract type PathChange{T <: Real} 

The supertype for all path changes.

## Interface

All subtypes of `PathChange` must be callable with the signature
`(::PathChange)(t::Real)::ViewState`.  Here `t` is the _relative_
time, that is, `t=0` corresponds to the absolute time point where
the particular `PathChange` that is being called begins.

All `PathChange` subtypes must implement the following functions:
- `duration(::PathChange{T})::T`
- `target(oldviewstate::ViewState, c::PathChange)::ViewState`, if applicable.

By convention, each `PathChange` subtype includes an `action` field.
This is a callback callable that takes a single argument `t`, which is 
the relative time within the `PathChange`, and performs some action, 
such as updating some state variable.  If absolute time is desired,
it's best to implment that in the outer animation loop, and not as 
an `action` callback.
"""
abstract type PathChange{T<:Real} end

struct Pause{T} <: PathChange{T}
    duration::T
    action

    function Pause{T}(t, action=nothing) where T
        t >= zero(T) || throw(ArgumentError("t must be non-negative"))
        new{T}(t, action)
    end
end

"""
    Pause(duration, [action])

Pause at the current position for `duration`.
"""
Pause(duration::T, action=nothing) where T = Pause{T}(duration, action)

Base.convert(::Type{Pause{T}}, p::Pause) where T = Pause{T}(p.duration, p.action)
Base.convert(::Type{PathChange{T}}, p::Pause) where T = convert(Pause{T}, p)

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

# Common API

duration(c::PathChange{T}) where T = c.duration::T

target(oldtarget::ViewState{T}, c::PathChange{T}) where T = c.target::ViewState{T}
target(oldtarget::ViewState{T},  ::Pause{T}) where T = oldtarget

Base.@nospecializeinfer function act(@nospecialize(action), t::Real)
    action === nothing && return nothing
    action(t)
    return nothing
end

"""
    slerp(vold, vnew, f)

Interpolate between the vectors `vold` and `vnew` at fraction `f`, rotating the direction
along the great circle joining them while interpolating the length geometrically. The
length therefore varies monotonically between `norm(vold)` and `norm(vnew)`, and is
constant when those are equal.

The naive blend `cospi(f/2) * vold + sinpi(f/2) * vnew` is not a rotation: writing
`d = norm(vold) = norm(vnew)` and `θ` for the angle between the two vectors, its squared
length is `d^2 * (1 + sinpi(f) * cos(θ))`, which is `d^2` only for `θ = 90°`. At `θ = 0` it
swells to `d^2*2` halfway through, and at `θ = 180°` it passes through zero, i.e. through
the point being looked at.

The rotation uses the tangent-vector form `cos(r)*a + sin(r)*dir`, where `a` is the unit
direction of `vold`, `r = f*θ`, and `dir = normalize((a × b) × a)` is the unit tangent at
`a` pointing towards the unit direction `b` of `vnew`. This is the formulation used by
[GeometryOps.jl's `UnitSpherical.slerp`](https://github.com/JuliaGeo/GeometryOps.jl/blob/main/src/utils/UnitSpherical/slerp.jl),
which adapts it from Google's S2 geometry library. It is preferred to the textbook
`(sin((1-f)θ)*a + sin(f*θ)*b) / sin(θ)` because that divisor collapses as `θ` approaches
0 or `π`, whereas the tangent form only has to special-case the two configurations where
the plane of rotation is genuinely undetermined.
"""
function slerp(vold::SVector{3,T}, vnew::SVector{3,T}, f) where T
    f <= 0 && return vold
    f >= 1 && return vnew
    dold, dnew = norm(vold), norm(vnew)
    # A vector of zero length has no direction to rotate, so interpolate linearly instead
    (iszero(dold) || iszero(dnew)) && return (1 - f) * vold + f * vnew
    a, b = vold / dold, vnew / dnew
    # Geometric interpolation of the length: a constant relative rate of approach reads
    # more evenly than a linear one when the camera dollies in or out.
    d = dold * (dnew / dold)^f
    # `n` is the normal of the plane of rotation and `norm(n)` is `sin(θ)`. `n` carries an
    # absolute error of a few `eps(T)` however close `a` and `b` are to each other or to
    # antipodal, so a norm at that level -- and only then -- means the inputs do not
    # determine a plane at all.
    n = cross(a, b)
    s, c = norm(n), dot(a, b)
    θ = atan(s, c)
    if s <= 8 * eps(T)
        # θ ≈ 0: `a` and `b` are the same direction, so only the length changes
        c > 0 && return d * a
        # θ ≈ 180°: every plane containing `a` also contains `b`, so the direction of
        # travel really is arbitrary. Rotate in the plane spanned by `a` and the
        # coordinate axis it is least aligned with: an arbitrary choice, but a
        # deterministic and well-conditioned one. (S2, and GeometryOps after it, resolve
        # this case with exact arithmetic and symbolic perturbation instead, because
        # their predicates must agree with each other from one call to the next. A camera
        # fly-through has no such requirement, so that machinery is not reproduced here.)
        i = argmin(abs.(a))
        n = cross(a, SVector(ntuple(j -> T(j == i), 3)))
    end
    dir = normalize(cross(n, a))
    r = f * θ
    return d * normalize(cos(r) * a + sin(r) * dir)
end

# Compute the view from a PathChange at (relative) time t

function (pause::Pause{T})(view::ViewState{T}, t) where T
    checkt(t, pause)
    action = pause.action
    if action !== nothing
        tf = t / duration(pause)
        act(action, tf)
    end
    return view
end

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
        eyeposition = slerp(vold, vnew, f) + lookatf
    end
    upvector = (1 - f) * upvector + f * upvector_new
    fov = (1 - f) * fov + f * fov_new
    lookat = lookatf
    act(action, f)
    return ViewState{T}(eyeposition, lookat, upvector, fov)
end

function (move::BezierMove{T})(view::ViewState{T}, t) where T
    filldef(vs) = filldefaults(vs, view)
    checkt(t, move)
    tf = t / duration(move)
    act(move.action, tf)
    list = [view, filldef.(move.controls)..., filldef(move.target)]
    return evaluate(list, tf)
end

# Recursive evaluation of bezier curves, https://en.wikipedia.org/wiki/B%C3%A9zier_curve#Recursive_definition
function evaluate(list, t)
    length(list) == 1 && return list[1]
    return (1 - t) * evaluate(list[1:end-1], t) + t * evaluate(list[2:end], t)
end

@noinline checkt(t, change::PathChange{T}) where T = zero(T) <= t <= duration(change) ||
    throw(ArgumentError("t=$t is not in [0, $(duration(change))]"))
