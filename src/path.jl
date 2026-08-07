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

"""
    nframes(path, rate)

Return the number of samples needed to traverse `path` at `rate` samples per second,
e.g. the number of frames to render at a given framerate.

At least two samples are returned, so that a path shorter than one sampling interval
still yields a non-degenerate range.
"""
nframes(path::Path, rate) = max(2, round(Int, duration(path) * rate))

function (path::Path{T})(t) where T
    view = path.initialview
    tend = zero(T)
    t < tend && return view
    for change in path.changes
        tnext = tend + duration(change)
        if t <= tnext
            # `tend` is accumulated separately from `t`, so `t - tend` can land a few ulps
            # outside `[0, duration(change)]` even though `t` selected this change. Clamp
            # rather than let `checkt` reject a time we just decided belongs here.
            return change(view, clamp(t - tend, zero(T), duration(change)))
        end
        tend, view = tnext, filldefaults(target(view, change), view)
    end
    return view
end

"""
    (path::Path)(ts::AbstractVector)

Evaluate `path` at every time in `ts`, which must be sorted, and return the resulting
`Vector{ViewState}`.  The result is identical to `path.(ts)`, elementwise.

Prefer this to broadcasting when sampling a whole path, e.g. once per frame of a video.
The scalar method walks the path's changes from the beginning on every call, both to find
the change that owns `t` and to accumulate the `ViewState` that change starts from; this
method does that walk once and then locates each time by `searchsortedfirst` over the
segment end times.
"""
function (path::Path{T})(ts::AbstractVector) where T
    issorted(ts) || throw(ArgumentError("`ts` must be sorted; broadcast `path.(ts)` instead"))
    changes = path.changes
    nchanges = length(changes)
    # The start time of each change, the view it starts from, and its end time, all
    # accumulated exactly as the scalar method accumulates them
    tstarts = Vector{T}(undef, nchanges)
    tstops = Vector{T}(undef, nchanges)
    startviews = Vector{ViewState{T}}(undef, nchanges)
    tend = zero(T)
    endview = path.initialview
    for (i, change) in enumerate(changes)
        tstarts[i], startviews[i] = tend, endview
        tstops[i] = tend = tend + duration(change)
        endview = filldefaults(target(endview, change), endview)
    end
    result = Vector{ViewState{T}}(undef, length(ts))
    i = 1   # the changes are visited in order, since `ts` is sorted
    for (k, t) in enumerate(ts)
        if t < zero(T)
            result[k] = path.initialview
            continue
        end
        i <= nchanges && (i += searchsortedfirst(@view(tstops[i:nchanges]), t) - 1)
        result[k] = if i > nchanges
            endview
        else
            change = changes[i]
            change(startviews[i], clamp(t - tstarts[i], zero(T), duration(change)))
        end
    end
    return result
end
