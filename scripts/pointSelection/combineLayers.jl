using BiodiversityObservationNetworks
using SpeciesDistributionToolkit
using JSON
using DataFrames
using CSV

function read_inputs_dict(runtime_dir)
    input_path = joinpath(runtime_dir, "input.json")
    output_dir_path = joinpath(runtime_dir, "data/")
    isdir(output_dir_path) || mkdir(output_dir_path)
    return JSON.parsefile(input_path)
end 

function read_layers_and_weights(inputs)
    layer_table = CSV.read(IOBuffer(inputs["layerdata"][1]), DataFrame)
    layer_paths = layer_table[:, :layer]

    W = Matrix(layer_table[:, 2:end])
    layers = SimpleSDMPredictor.(layer_paths)
    ϕ = convert(Vector{Float64}, inputs["targetbalance"]) 
        
    mask_path = inputs["mask"][1]["map"]["layer"]
    mask = SimpleSDMPredictor(mask_path)

    check_validity(W) && check_validity(layers) && check_validity(ϕ)
    return layers, mask, W, ϕ
end

function check_validity(ϕ::Vector)
    sum(ϕ) != 1 && @info "Target balance doesn't sum to one. Aborting." && exit(-1) 
end

function check_validity(W::Matrix)
    !all([sum(x) ≈ 1 for x in eachcol(W)]) && @info "Not all columns in the weight matrix sum to one. Aborting." && exit(-1)
end

function check_validity(layers::Vector{T}) where T<:SimpleSDMLayer
    if length(unique(size.(layers))) == 1
        @info "Not all input layers are the same size. Aborting"
        exit(-1)
    end
    if length(unique(boundingbox.(layers))) == 1
        @info "Not all input layers have the same bounds. Aborting"
        exit(-1)
    end
end 

function mask_layers!(layers, mask_layer)
    I = findall(x->!isnothing(x), mask_layer.grid) 
    for l in layers
        l.grid[I] .= nothing 
    end
end

function make_priority_map(layers, mask_layer, W, ϕ)
    mask_layers!(layers, mask_layer)

    tensor = BiodiversityObservationNetworks.stack(layers)
    priority = similar(layers[begin])
    priority.grid .= squish(tensor, W, ϕ)
    
    return priority
end

function write_outputs(priority_map, output_dir)
    priority_path = joinpath(output_dir, "priority_map.tiff")
    SpeciesDistributionToolkit.save(priority_path, priority_map, driver="COG")
    outputDict = Dict("priority_map" => priority_path)
    output_path = joinpath(output_dir, "output.json")
    touch(output_path)
    open(output_path, "w") do f
        JSON.print(f, outputDict)
    end
end 

function main()
    runtime_dir = ARGS[1]
    inputs = read_inputs_dict(runtime_dir)
    layers, mask, W, ϕ = read_layers_and_weights(inputs)
    priority_map = make_priority_map(layers, mask, W, ϕ)
    write_outputs(priority_map, runtime_dir) 
end

main()
