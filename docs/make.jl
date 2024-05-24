using FlyThroughPaths
using Documenter

DocMeta.setdocmeta!(FlyThroughPaths, :DocTestSetup, :(using FlyThroughPaths); recursive=true)

makedocs(;
    modules=[FlyThroughPaths],
    authors="Tim Holy <tim.holy@gmail.com> and contributors",
    sitename="FlyThroughPaths.jl",
    format=Documenter.HTML(;
        canonical="https://HolyLab.github.io/FlyThroughPaths.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
        "Makie integration" => "makie.md",
        "Developer documentation" => "devdocs.md"
    ],
)

deploydocs(;
    repo="github.com/HolyLab/FlyThroughPaths.jl",
    devbranch="main",
)
