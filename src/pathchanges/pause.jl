#=
# Pause

[`Pause`](@ref) is a move that encodes a pause, i.e., no movement in the camera state at all.  
The pause lasts for `duration` time, and has an `action` callback.

The construction is very simple - simply `Pause(duration)`.
=#
struct Pause{T} <: PathChange{T}
    duration::T
    action

    function Pause{T}(t, action=nothing) where T
        t >= zero(T) || throw(ArgumentError("t must be non-negative"))
        new{T}(t, action)
    end
end

function (pause::Pause{T})(view::ViewState{T}, t) where T
    checkt(t, pause)
    action = pause.action
    if action !== nothing
        tf = t / duration(move)
        act(action, tf)
    end
    return view
end

target(oldtarget::ViewState{T},  ::Pause{T}) where T = oldtarget

"""
    Pause(duration, [action])

Pause at the current position for `duration`.
"""
Pause(duration::T) where T = Pause{T}(duration)

Base.convert(::Type{Pause{T}}, p::Pause) where T = Pause{T}(p.duration, p.action)
Base.convert(::Type{PathChange{T}}, p::Pause) where T = convert(Pause{T}, p)
