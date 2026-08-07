using FlyThroughPaths
using LinearAlgebra
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
    end
end
