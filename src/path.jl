struct Path{T}
    initialview::ViewState{T}
    changes::Vector{PathChange{T}}
end
Path{T}(initialview::ViewState) where T = Path{T}(initialview, PathChange{T}[])
Path(initialview::ViewState{T}) where T = Path{T}(initialview)

function Base.:*(path::Path{R}, change::PathChange{S}) where {R,S}
    T = promote_type(R, S)
    Path{T}(path.initialview, PathChange{T}[path.changes..., change])
end

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
