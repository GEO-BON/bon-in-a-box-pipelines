using SpeciesDistributionToolkit
using JSON
using CSV
using MultivariateStats         
using StatsBase
using DataFrames

include("./shared.jl")

const PROVIDER = RasterData(CHELSA2, BioClim)

function convert_layers_to_features_matrix(layers)
    I = findall(!isnothing, layers[1].grid)
    data_matrix = zeros(Float32, length(layers), length(I))
    for (i,l) in enumerate(layers)
        x = Float32.(vec(l.grid[I]))
        z = StatsBase.fit(ZScoreTransform, x)
        data_matrix[i,:] .= StatsBase.transform(z, x)
    end
    data_matrix
end 

function fill_layer!(empty_layer, vec)
    m = reshape(vec, size(empty_layer))
    for j in eachindex(empty_layer.grid)
        empty_layer.grid[j] = m[j]
    end
end

function pca_data_matrix(data_matrix)
    pca = MultivariateStats.fit(PCA, data_matrix)
    MultivariateStats.transform(pca, data_matrix)
end 

function make_pca_layers(layers)  
    pca_mat = pca_data_matrix(convert_layers_to_features_matrix(layers))
    pca_layers = [convert(Float32, similar(layers[begin])) for l in 1:size(pca_mat, 1)]
    for (i,pca_layer) in enumerate(pca_layers)
        fill_layer!(pca_layer, pca_mat[i,:])
    end 
    pca_layers
end

function write_outputs(runtime_dir, layers)
    predictor_paths = []

    for (i,l) in enumerate(layers)
        outpath = joinpath(runtime_dir, "predictor$i.tif")
        push!(predictor_paths, outpath)
        SpeciesDistributionToolkit.save(outpath, l)
    end

    output_json_path = joinpath(runtime_dir, "output.json")
    open(output_json_path, "w") do f
        write(f, JSON.json(Dict(:predictors=>predictor_paths)))
    end 
end

function main()
    runtime_dir = ARGS[1]
    inputs = read_inputs_dict(runtime_dir)

    bbox = inputs["bbox"]
    pca_input = inputs["pca"]
    layer_nums = inputs["layer_numbers"]
    layer_names = ["BIO$i" for i in layer_nums]         

    bbox = (left=bbox[1], bottom=bbox[2], right=bbox[3], top=bbox[4])
    @info bbox

    layers = []
    for l in layer_names
        success = false
        ct = 1
        while !success     
            try  
                a = convert(Float32, SimpleSDMPredictor(PROVIDER; layer=l, bbox...)) 
                success = true
                push!(layers, a)
            catch
                @info "Errored on $l on attempt $ct. Almost certainly a network error on CHELSA's side. Trying again..."
                ct += 1
            end 
        end
    end

    layers = pca_input ? make_pca_layers(layers) : layers

    write_outputs(runtime_dir, layers)
end

main()