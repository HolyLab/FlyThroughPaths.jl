struct ViewState{T}
    eyeposition::Union{SVector{3,T},Nothing}
    lookat::Union{SVector{3,T},Nothing}
    upvector::Union{SVector{3,T},Nothing}
    fov::Union{T,Nothing}
end

ViewState{T}(; eyeposition=nothing, lookat=nothing, upvector=nothing, fov=nothing) where T =
    ViewState{T}(eyeposition, lookat, upvector, fov)

_eltype(::Nothing) = Union{}     # contributes nothing to the promotion
_eltype(x::Number) = typeof(x)
_eltype(x) = eltype(x)

# `Union{}` (nothing was supplied) is a subtype of everything, hence the first test
_floattype(::Type{T}) where T = T !== Union{} && T <: AbstractFloat ? T : Float32

"""
    ViewState(; eyeposition, lookat, upvector, fov)

Construct a `ViewState` whose element type is promoted from the supplied arguments;
e.g. `Point3d` positions or a `Float64` `fov` give a `ViewState{Float64}`.

Integers express no preference about precision, so they (like omitting an argument
altogether) keep the `Float32` default, `Float32` being the space Makie cameras work in.
Use `ViewState{T}(; ...)` to choose the element type explicitly.
"""
function ViewState(; eyeposition=nothing, lookat=nothing, upvector=nothing, fov=nothing)
    T = promote_type(_eltype(eyeposition), _eltype(lookat), _eltype(upvector), _eltype(fov))
    return ViewState{_floattype(T)}(eyeposition, lookat, upvector, fov)
end

Base.convert(::Type{ViewState{T}}, v::ViewState) where T =
    ViewState{T}(v.eyeposition, v.lookat, v.upvector, v.fov)

function Base.show(io::IO, v::ViewState{T}) where T
    print(io, "ViewState{$T}(")
    ioctx = IOContext(io, :typeinfo=>T)
    delim, opn, cls = "", '[', ']'
    if v.eyeposition !== nothing
        print(ioctx, "eyeposition=")
        Base.show_delim_array(ioctx, v.eyeposition, opn, ",", cls, false)  # suppress the T in T[1, 2, 3]
        delim = ", "
    end
    if v.lookat !== nothing
        print(ioctx, delim, "lookat=")
        Base.show_delim_array(ioctx, v.lookat, opn, ",", cls, false)
        delim = ", "
    end
    if v.upvector !== nothing
        print(ioctx, delim, "upvector=")
        Base.show_delim_array(ioctx, v.upvector, opn, ",", cls, false)
        delim = ", "
    end
    if v.fov !== nothing
        print(ioctx, delim, "fov=")
        show(ioctx, v.fov)
    end
    print(ioctx, ")")
end

function Base.:+(view1::ViewState{T}, view2::ViewState{T}) where T
    ViewState{T}(eyeposition=view2.eyeposition === nothing ? view1.eyeposition : view1.eyeposition + view2.eyeposition,
                 lookat=view2.lookat === nothing ? view1.lookat : view1.lookat + view2.lookat,
                 upvector=view2.upvector === nothing ? view1.upvector : view1.upvector + view2.upvector,
                 fov=view2.fov === nothing ? view1.fov : view1.fov + view2.fov)
end

function Base.:*(r::Real, view::ViewState{T}) where T
    ViewState{T}(eyeposition=view.eyeposition === nothing ? nothing : r * view.eyeposition,
                 lookat=view.lookat === nothing ? nothing : r * view.lookat,
                 upvector=view.upvector === nothing ? nothing : r * view.upvector,
                 fov=view.fov === nothing ? nothing : r * view.fov)
end

function filldefaults(target::ViewState{T}, src::ViewState) where T
    (; eyeposition, lookat, upvector, fov) = target
    if eyeposition === nothing
        eyeposition = src.eyeposition
    end
    if lookat === nothing
        lookat = src.lookat
    end
    if upvector === nothing
        upvector = src.upvector
    end
    if fov === nothing
        fov = src.fov
    end
    return ViewState{T}(eyeposition, lookat, upvector, fov)
end
