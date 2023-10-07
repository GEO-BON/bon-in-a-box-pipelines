using JSON
using CSV
using DataFrames
using SpeciesDistributionToolkit

include("shared.jl")

function write_outputs(runtime_dir, priority)
    outpath = joinpath(runtime_dir, "priority.tif")
    SpeciesDistributionToolkit._write_geotiff(outpath, priority; compress="COG")

    output_json_path = joinpath(runtime_dir, "output.json")
    open(output_json_path, "w") do f
        write(f, JSON.json(Dict(:priority_map=>outpath)))
    end 
end

function get_shared_indices(layers)
    land_idxs = []
    for l in layers
        push!(land_idxs, findall(!isnothing, l.grid))
    end

    ∩(land_idxs...)
end

function main()
    runtime_dir = ARGS[1]   
    inputs = read_inputs_dict(runtime_dir)

    β = inputs["weights"]

    uncert_path = inputs["uncertainty"]
    uniqueness_path = inputs["climate_uniqueness"]
    velocity_path = inputs["climate_velocity"]
    
    access_path = inputs["accessibility"]
    
    layer_paths = [uncert_path, uniqueness_path, velocity_path, access_path]

    layers = [rescale(SimpleSDMPredictor(joinpath(runtime_dir, layer_path)), (0,1)) for layer_path in layer_paths]
    shared_idxs = get_shared_indices(layers)

    access = similar(layers[begin])
    access.grid .= nothing
    # note accessability gets inverted becaused smaller = better 
    access.grid[shared_idxs] .= 1 .- layers[end].grid[shared_idxs]
    access = rescale(access, (0,1))
    layers[4] = access 

    priority = similar(layers[begin])
    priority.grid .= nothing
    priority.grid[shared_idxs] .= 0.

    for (i,l) in enumerate(layers)
        priority.grid[shared_idxs] .+= β[i] .* l.grid[shared_idxs]
    end 
   
    priority = rescale(priority, (0,1))

    write_outputs(runtime_dir, priority)    
end 

main()