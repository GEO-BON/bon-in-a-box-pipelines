using SpeciesDistributionToolkit
using JSON
using CSV
using MultivariateStats         
using StatsBase
using DataFrames

include("./shared.jl")

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

function fill_layer!(empty_layer, vec, land_idx)
    for (i, idx) in enumerate(land_idx)
        empty_layer.grid[idx] = vec[i]
    end
end

function pca_data_matrix(data_matrix)
    pca = MultivariateStats.fit(PCA, data_matrix)
    MultivariateStats.transform(pca, data_matrix)
end 

function make_pca_layers(layers, land_idx)  
    pca_mat = pca_data_matrix(convert_layers_to_features_matrix(layers))
    pca_layers = [convert(Float32, similar(layers[begin])) for l in 1:size(pca_mat, 1)]

    for (i,pca_layer) in enumerate(pca_layers)
        fill_layer!(pca_layer, pca_mat[i,:], land_idx)
    end 
    pca_layers
end

function write_outputs(runtime_dir, layers)
    
    predictor_paths = []

    for (i,l) in enumerate(layers)
        outpath = joinpath(runtime_dir, "predictor$i.tif")
        push!(predictor_paths, outpath)
        SpeciesDistributionToolkit._write_geotiff(outpath, l; compress="COG")
    end

    output_json_path = joinpath(runtime_dir, "output.json")
    open(output_json_path, "w") do f
        write(f, JSON.json(Dict(:predictors=>predictor_paths)))
    end 
end

function main()
    runtime_dir = ARGS[1]
    inputs = read_inputs_dict(runtime_dir)

    layer_paths = inputs["layers"]
    landcover_path = inputs["mask"]

    lc = SimpleSDMPredictor(joinpath(runtime_dir, landcover_path))

    OPEN_WATER_LABEL = 210
    water_idx = findall(isequal(OPEN_WATER_LABEL), lc.grid)
    land_idx = findall(!isequal(OPEN_WATER_LABEL), lc.grid)


    layers = [SimpleSDMPredictor(joinpath(runtime_dir, layer_path)) for layer_path in layer_paths]
              
    for l in layers
        l.grid[water_idx] .= nothing
    end 

    write_outputs(runtime_dir, make_pca_layers(layers, land_idx))
end

main()