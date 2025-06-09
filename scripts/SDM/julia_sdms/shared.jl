function read_inputs_dict(runtime_dir)
    filepath = joinpath(runtime_dir, "input.json")
    output_dir = joinpath(runtime_dir, "data/")
    isdir(output_dir) || mkdir(output_dir)
    return JSON.parsefile(filepath) 
end 

function create_occurrence_layer(layer, occurrence)
    layer.grid .= 0
    for r in eachrow(occurrence)
        long, lat = r["lon"], r["lat"]
        layer[long,lat] = 1
    end
    convert(Bool, layer)
end