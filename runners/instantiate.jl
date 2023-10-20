using Pkg

# A dictionary with keys that are the path to a script directory, 
# and the values are an array of PackageSpecs that fix each required 
# package's name and version.  
script_dict = Dict(
    # helloJulia.jl
    joinpath("scripts", "helloWorld", "helloJulia") =>
        [PackageSpec(; name="JSON", version=v"0.21.4")],
)

for (dir, packages) in script_dict
    Pkg.activate(joinpath("/root/",dir)); 
    Pkg.add.(packages)
    Pkg.instantiate();
end


