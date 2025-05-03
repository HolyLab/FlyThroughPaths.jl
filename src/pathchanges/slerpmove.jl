"""
    slerp(p1, p2, t01)

Spherical linear interpolation between two n-vectors.

t01 must be between 0 and 1 - 0 means the result equals p1, 1 means the result equals p2.
"""
function slerp(p1::AbstractVector, p2::AbstractVector, t01)
    # @show p1 p2
    np1, np2 = normalize(p1), normalize(p2)
    if _disqualified_for_slerp(np1, np2)
        return p1
    end
    p1n, p2n = norm(p1), norm(p2)
    Ω = acos(clamp(dot(np1, np2), -1, 1))
    sinΩ = sin(Ω)
    # Interpolate magnitudes and directions separately,
    # then combine the results.
    return slerp(p1n, p2n, t01) * (sin((1-t01)*Ω)/sinΩ * np1 + sin(t01*Ω)/sinΩ * np2)
end

# Slerp on scalars is just linear interpolation, 
# since there can't be a slerp on a scalar.
function slerp(p1::Number, p2::Number, t01)
    if _disqualified_for_slerp(p1, p2)
        return p1
    end
    return (1-t01)*p1 + t01*p2
end

function _disqualified_for_slerp(p1, p2)
    return iszero(p1) || iszero(p2) || any(isnan, p1) || any(isnan, p2) ||
    p1 == p2
end

slerp(p1::ViewState, p2::ViewState, t01) = ViewState(
    slerp(p1.eyeposition, p2.eyeposition, t01),
    slerp(p1.lookat, p2.lookat, t01),
    slerp(p1.upvector, p2.upvector, t01),
    slerp(p1.fov, p2.fov, t01)
)

slerp(p1::ViewState, p2::ViewState, center::ViewState, t01) = ViewState(;
    eyeposition =slerp(p1.eyeposition - center.eyeposition, p2.eyeposition - center.eyeposition, t01) + center.eyeposition,
    lookat =slerp(p1.lookat - center.lookat, p2.lookat - center.lookat, t01) + center.lookat,
    upvector =slerp(p1.upvector - center.upvector, p2.upvector - center.upvector, t01) + center.upvector,
    fov =slerp(p1.fov - center.fov, p2.fov - center.fov, t01) + center.fov
)

#=

function _showslerp(p1, p2)
    f, a, p = scatter(p1, label="p1")
    scatter!(a, p2, label="p2")
    lines!(a, slerp.((p1,), (p2,), 0:0.01:1); color = 0:0.01:1)
    f
end

=#


struct SlerpMove{T} <: PathChange{T}
    duration::T
    target::ViewState{T}
    center::ViewState{T}
    action
end

function SlerpMove(duration::T, target::ViewState{T}, action = nothing) where T
    center = ViewState{T}(; 
        eyeposition = zero(SVector{3, T}),
        lookat = zero(SVector{3, T}),
        fov = 0.0,
        upvector = zero(SVector{3, T})
    )
    SlerpMove{T}(duration, target, center, action)
end

function SlerpMove(duration::T1, target::ViewState{T2}) where {T1, T2}
    SlerpMove(T2(duration), target, nothing)
end

function SlerpMove(duration::T1, target::ViewState{T2}, center::ViewState{T2}, action = nothing) where {T1, T2}
    SlerpMove(T2(duration), target, filldefaults(center, ViewState{T2}(; 
    eyeposition = zero(SVector{3, T2}),
    lookat = zero(SVector{3, T2}),
    fov = 0.0,
    upvector = zero(SVector{3, T2})
)), action)
end

function (change::SlerpMove)(view, t)
    finalstate = filldefaults(change.target, view)
    # @show view finalstate
    return slerp(view, finalstate, change.center, t/change.duration)
end

function duration(change::SlerpMove)
    return change.duration
end



