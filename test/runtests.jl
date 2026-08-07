using FlyThroughPaths
using LinearAlgebra
using StaticArrays
using Test

@testset "FlyThroughPaths.jl" begin
    @testset "ViewState" begin
        @testset "constructor" begin
            view = ViewState(eyeposition = [-10, 0, 0], lookat=[0, 0, 0], upvector=[0, 0, 1], fov=45)
            @test view.eyeposition == [-10, 0, 0]
            @test view.lookat == [0, 0, 0]
            @test view.upvector == [0, 0, 1]
            @test view.fov == 45
            view16 = ViewState{Float16}(eyeposition = [-10, 0, 0], lookat=[0, 0, 0], upvector=[0, 0, 1], fov=45)
            @test view16 isa ViewState{Float16}
            @test view16.eyeposition == [-10, 0, 0]

            str = sprint(show, view)
            @test str == "ViewState{Float32}(eyeposition=[-10.0, 0.0, 0.0], lookat=[0.0, 0.0, 0.0], upvector=[0.0, 0.0, 1.0], fov=45.0)"
            # Round-trippability with display
            @test eval(Meta.parse(str)) == view
        end
        @testset "element type" begin
            # The element type is promoted from the supplied values
            view64 = ViewState(eyeposition = SVector(1.0, 2.0, 3.0), lookat = SVector(0.0, 0.0, 0.0),
                               upvector = SVector(0.0, 0.0, 1.0), fov = 40.0)
            @test view64 isa ViewState{Float64}
            @test view64.eyeposition == [1, 2, 3]
            # Float32 input still yields a Float32 ViewState
            @test ViewState(eyeposition = SVector{3,Float32}(1, 2, 3), fov = 40f0) isa ViewState{Float32}
            @test ViewState(eyeposition = SVector{3,Float16}(1, 2, 3)) isa ViewState{Float16}
            # A single Float64 field is enough to promote the whole state
            @test ViewState(eyeposition = SVector{3,Float32}(1, 2, 3), fov = 40.0) isa ViewState{Float64}
            # Integers carry no precision preference, so they keep the Float32 default
            @test ViewState(eyeposition = [-10, 0, 0], fov = 45) isa ViewState{Float32}
            @test ViewState() isa ViewState{Float32}
            # Explicitly-typed construction is unaffected
            @test ViewState{Float32}(eyeposition = SVector(1.0, 2.0, 3.0), fov = 40.0) isa ViewState{Float32}
        end
    end
    @testset "Path" begin
        view = ViewState(eyeposition = [-10, 0, 0], lookat=[0, 0, 0], upvector=[0, 0, 1], fov=45)
        path = Path(view)
        @test path.initialview == view
        @test isempty(path.changes)

        @testset "Pause" begin
            newpath = path*Pause(1)
            @test newpath isa Path{Float32}
            @test newpath(0.5).eyeposition == view.eyeposition

            @test path*Pause(1.0) isa Path{Float64}

            @testset "action" begin
                ts = Float64[]
                pause = Pause(2.0, t -> push!(ts, t))
                @test pause isa Pause{Float64}
                newpath = path*pause
                # The action fires with the fraction of the pause that has elapsed
                @test newpath(1.0).eyeposition == view.eyeposition
                @test ts == [0.5]
                newpath(0.0)
                newpath(2.0)
                @test ts == [0.5, 0.0, 1.0]
            end
        end
        @testset "ConstrainedMove" begin
            move = ConstrainedMove(5, ViewState(eyeposition=[0, 10, 0]), :none, :constant)
            newpath = path*move
            @test newpath(0.0).eyeposition == view.eyeposition
            @test newpath(5.0).eyeposition == [0, 10, 0]
            @test newpath(2.5).eyeposition ≈ [-5, 5, 0]
            @test newpath(5).lookat == view.lookat
            @test newpath(5).upvector == view.upvector

            move = ConstrainedMove(5, ViewState(eyeposition=[0, 10, 0]), :rotation, :constant)
            newpath = path*move
            @test newpath(0.0).eyeposition == view.eyeposition
            @test newpath(5.0).eyeposition == [0, 10, 0]
            @test newpath(2.5).eyeposition ≈ [-10/sqrt(2), 10/sqrt(2), 0]

            move = ConstrainedMove(5, ViewState(eyeposition=[0, 10, 0]), :none, :sinusoidal)
            newpath = path*move
            @test newpath(0.0).eyeposition == view.eyeposition
            @test newpath(5.0).eyeposition == [0, 10, 0]
            @test newpath(2.5).eyeposition ≈ [-5, 5, 0]
            v = newpath(1.25)
            @test norm(v.eyeposition - view.eyeposition) < 0.9 * norm(v.eyeposition - [-5, 5, 0])
        end
        @testset ":rotation constraint" begin
            # A `cospi(f/2)*vold + sinpi(f/2)*vnew` blend has squared length
            # d²(1 + sinpi(f)*cos(θ)), which is d² only for θ = 90°. The distance to the
            # lookat point must instead stay between the two endpoint distances.
            for θ in (0, 45, 90, 179, 180), (dold, dnew) in ((10.0, 10.0), (10.0, 4.0), (4.0, 10.0))
                view0 = ViewState(eyeposition = SVector(dold, 0.0, 0.0), lookat = SVector(0.0, 0.0, 0.0),
                                  upvector = SVector(0.0, 0.0, 1.0), fov = 45.0)
                eyenew = SVector(dnew*cosd(θ), dnew*sind(θ), 0.0)
                rpath = Path(view0) * ConstrainedMove(1.0, ViewState(eyeposition = eyenew), :rotation, :constant)
                # The endpoints are exact
                @test rpath(0.0).eyeposition == view0.eyeposition
                @test rpath(1.0).eyeposition == eyenew
                radii = [norm(rpath(f).eyeposition - rpath(f).lookat) for f in range(0, 1; length = 101)]
                @test !any(isnan, radii)
                @test all(r -> min(dold, dnew) - 1e-8 <= r <= max(dold, dnew) + 1e-8, radii)
                # ...and it varies monotonically, so equal endpoint radii stay constant
                @test issorted(round.(radii; digits = 9); rev = dnew < dold)
            end
            # The interpolation is a rotation, not a chord: halfway through a 90° move at
            # constant radius the camera sits at 45°.
            view0 = ViewState(eyeposition = SVector(10.0, 0.0, 0.0), lookat = SVector(0.0, 0.0, 0.0),
                              upvector = SVector(0.0, 0.0, 1.0), fov = 45.0)
            rpath = Path(view0) * ConstrainedMove(1.0, ViewState(eyeposition = SVector(0.0, 10.0, 0.0)), :rotation, :constant)
            @test rpath(0.5).eyeposition ≈ [10/sqrt(2), 10/sqrt(2), 0]
            @test rpath(0.25).eyeposition ≈ 10 .* [cosd(22.5), sind(22.5), 0]
            # A move that only changes the distance still interpolates the distance smoothly
            rpath = Path(view0) * ConstrainedMove(1.0, ViewState(eyeposition = SVector(5.0, 0.0, 0.0)), :rotation, :constant)
            @test rpath(0.5).eyeposition ≈ [sqrt(50), 0, 0]   # geometric mean of 10 and 5
        end
        @testset "BezierMove" begin
            move = BezierMove(5, ViewState(eyeposition=[0, 10, 0]), [ViewState(eyeposition=[-20, 20, 0])])
            newpath = path*move
            @test newpath(0.0).eyeposition == view.eyeposition
            @test newpath(5.0).eyeposition == [0, 10, 0]
            mid = newpath(2.5)
            @test mid.eyeposition[1] ≈ - mid.eyeposition[2]
            @test norm(mid.eyeposition) > 12  # overshoots
            @test mid.lookat == view.lookat
            @test mid.upvector == view.upvector
        end
        @testset "segment boundaries" begin
            # `path(t)` accumulates the segment start times, so the local time handed to a
            # `PathChange` can exceed that change's duration by an ulp even though `t`
            # itself selected the segment.
            view0 = ViewState{Float64}(eyeposition=[10, 0, 0], lookat=[0, 0, 0], upvector=[0, 0, 1], fov=45)
            bpath = Path(view0)
            for i in 1:5
                bpath = bpath * ConstrainedMove(0.2, ViewState{Float64}(eyeposition=[10, i, 0]), :none, :constant)
            end
            for k in 0:5
                t = 0.2k
                @test bpath(t) isa ViewState{Float64}
                @test bpath(prevfloat(t)) isa ViewState{Float64}
                @test bpath(nextfloat(t)) isa ViewState{Float64}
            end
            # ...and the view is continuous across a boundary
            @test bpath(prevfloat(0.6)).eyeposition ≈ bpath(nextfloat(0.6)).eyeposition

            # `checkt` should still reject times that are genuinely out of range
            move = ConstrainedMove(1.0, ViewState{Float64}(eyeposition=[0, 10, 0]), :none, :constant)
            @test_throws ArgumentError move(view0, 1.5)
            @test_throws ArgumentError move(view0, -0.5)
        end
        @testset "long path" begin
            # A 122 s flight assembled from 750 short moves: in Float32 the segment start
            # times accumulated by `path(t)` drift away from the sampled frame times.
            view0 = ViewState(eyeposition = SVector(10.0, 0.0, 0.0), lookat = SVector(0.0, 0.0, 0.0),
                              upvector = SVector(0.0, 0.0, 1.0), fov = 45.0)
            n, tend = 750, 122.0
            longpath = Path(view0)
            for i in 1:n
                θ = 2π * i / n
                longpath = longpath * ConstrainedMove(tend/n, ViewState(eyeposition = SVector(10cos(θ), 10sin(θ), 0.0)), :none, :constant)
            end
            @test longpath isa Path{Float64}
            @test FlyThroughPaths.duration(longpath) ≈ tend
            @test all(t -> longpath(t) isa ViewState{Float64}, range(0, tend; length = 1001))
            @test all(k -> longpath(k*(tend/n)) isa ViewState{Float64}, 0:n)
        end
    end
end
