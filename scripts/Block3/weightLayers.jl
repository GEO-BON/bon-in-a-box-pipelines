using JSON
using CSV
using DataFrames
using SpeciesDistributionToolkit



function write_outputs(runtime_dir, priority)
    outpath = joinpath(runtime_dir, "priority.tif")
    SpeciesDistributionToolkit._write_geotiff(outpath, priority; compress="COG")

    output_json_path = joinpath(runtime_dir, "output.json")
    open(output_json_path, "w") do f
        write(f, JSON.json(Dict(:priority_map=>outpath)))
    end 
end

function main()
    runtime_dir = ARGS[1]   
    inputs = read_inputs_dict(runtime_dir)

    β = inputs["weights"]

    uncert_path = inputs["uncertainty"]
    uniqueness_path = inputs["climate_uniqueness"]
    velocity_path = inputs["climate_velocity"]
    access_path = inputs["accessability"]
    
    layer_paths = [uncert_path, uniqueness_path, velocity_path, access_path]

    layers = [rescale(SimpleSDMPredictor(joinpath(runtime_dir, layer_path)), (0,1)) for layer_path in layer_paths]

    priority = sum([β[i] .* layers[i].grid for i in eachindex(β)])

    write_outputs(runtime_dir, priority)    
end 

main()