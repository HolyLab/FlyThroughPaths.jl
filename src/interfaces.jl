########################################
#         PathChange interface         #
########################################
"""
    duration(p)

Return the duration of the path or path change as a `Number`.

For an object of type `Path{T}` or `PathChange{T}`, this function
will return a number of type `T`.
"""
function duration end

########################################
#      Plotting backend interface      #
########################################
"""
    capture_view(object)

Return a `ViewState` that captures the current camera settings
of the object.  

This is currently implemented for Makie.jl `Scene`s and `LScene`s, but
can be extended to arbitrary backends.
"""
function capture_view end

"""
    set_view!(object, viewstate)

Set the camera settings of the object to the given `ViewState`.

This is currently implemented for Makie.jl `Scene`s and `LScene`s, but
can be extended to arbitrary backends.
"""
function set_view! end

########################################
#       Diagnostic visualization       #
########################################
# The functions below are specific to Makie.
function plotcamerapath end
function plotcamerapath! end
# If creating a Plots recipe, use seriestype=:plotcamerapath