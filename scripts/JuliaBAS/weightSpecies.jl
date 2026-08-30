using JSON
using SpeciesDistributionToolkit

const SDT = SpeciesDistributionToolkit

"""
    read_inputs_dict

Reads the input JSON from the runtime directory.
"""
function read_inputs_dict(runtime_dir)
    filepath = joinpath(runtime_dir, "input.json")
    output_dir = joinpath(runtime_dir, "data/")
    isdir(output_dir) || mkdir(output_dir)
    return JSON.parsefile(filepath)
end

RUNTIME_DIR = ARGS[1]
inputs = read_inputs_dict(RUNTIME_DIR)

uncertainty_maps = [SDMLayer(p) for p in inputs["uncertainty_maps"]]
weights = inputs["species_weights"]

priority_map = sum([weights[i] * uncertainty_maps[i] for i in eachindex(uncertainty_maps)])

priority_path = joinpath(RUNTIME_DIR, "priority.tif")
SDT.SimpleSDMLayers.save(priority_path, priority_map)


open(joinpath(RUNTIME_DIR, "output.json"), "w") do f
    write(f, JSON.json(
        Dict(
            "priority_map" => priority_path
        )
    ))
end
