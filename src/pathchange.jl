abstract type PathChange{T<:Real} end

struct Pause{T} <: PathChange{T}
    duration::T
    action

    function Pause{T}(t, action=nothing) where T
        t >= zero(T) || throw(ArgumentError("t must be non-negative"))
        new{T}(t, action)
    end
end
Pause(duration::T) where T = Pause{T}(duration)

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

# Compute the view from a PathChange at (relative) time t

function (pause::Pause{T})(view::ViewState{T}, t) where T
    checkt(t, pause)
    action = pause.action
    if action !== nothing
        tf = t / duration(move)
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
        eyeposition = cospi(f/2) * vold + sinpi(f/2) * vnew + lookatf
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
