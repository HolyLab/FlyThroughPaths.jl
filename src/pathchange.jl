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

# Common API

duration(c::PathChange{T}) where T = c.duration::T

target(oldtarget::ViewState{T}, c::PathChange{T}) where T = c.target::ViewState{T}

Base.@nospecializeinfer function act(@nospecialize(action), t::Real)
    action === nothing && return nothing
    action(t)
    return nothing
end

# Recursive evaluation of bezier curves, https://en.wikipedia.org/wiki/B%C3%A9zier_curve#Recursive_definition
function evaluate(list, t)
    length(list) == 1 && return list[1]
    return (1 - t) * evaluate(list[1:end-1], t) + t * evaluate(list[2:end], t)
end

@noinline checkt(t, change::PathChange{T}) where T = zero(T) <= t <= duration(change) ||
    throw(ArgumentError("t=$t is not in [0, $(duration(change))]"))
