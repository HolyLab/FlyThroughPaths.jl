"""
    struct Path{T}

A `Path` is a sequence of `PathChange`s, beginning from some `initialview::ViewState`.
It is callable with a single parameter `t`, which is the time since the start of the path at `t=0`.
It returns the `ViewState` at time `t`.

To add a new `PathChange` to a `Path`, use the `*` operator.  This is non-mutating and will construct a new path!
"""
struct Path{T}
    initialview::ViewState{T}
    changes::Vector{PathChange{T}}
end
Path{T}(initialview::ViewState) where T = Path{T}(initialview, PathChange{T}[])

"""
    Path(initialview::ViewState{T}) where T

Construct a `Path` that starts at `initialview`.
"""
Path(initialview::ViewState{T}) where T = Path{T}(initialview)

function Base.:*(path::Path{R}, change::PathChange{S}) where {R,S}
    T = promote_type(R, S)
    Path{T}(path.initialview, PathChange{T}[path.changes..., change])
end

duration(path::Path{T}) where T = sum(duration, path.changes; init = zero(T))

function (path::Path{T})(t) where T
    view = path.initialview
    tend = zero(T)
    t < tend && return view
    for change in path.changes
        tnext = tend + duration(change)
        if t <= tnext
            return change(view, t - tend)
        end
        tend, view = tnext, filldefaults(target(view, change), view)
    end
    return view
end
