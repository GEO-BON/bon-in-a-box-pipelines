using SpeciesDistributionToolkit
using Clustering
using StatsBase
using CSV
using DataFrames
using MultivariateStats
using Dates 
using JSON

include("shared.jl")

function convert_layers_to_features_matrix(layers, data_matrix, land_idx)
    for (i,l) in enumerate(layers)
        x = Float32.(vec(l.grid[land_idx]))
        z = StatsBase.fit(ZScoreTransform, x)
        data_matrix[i,:] .= StatsBase.transform(z, x)
    end
    data_matrix
end 

function fill_layer!(empty_layer, vec, land_idx)
    empty_layer.grid .= nothing 
    for (i, idx) in enumerate(land_idx)
        empty_layer.grid[idx] = vec[i]
    end
end

function pca_data_matrix(data_matrix)
    pca = MultivariateStats.fit(PCA, data_matrix)
    MultivariateStats.transform(pca, data_matrix)
end 

function make_pca_matrix(layers, data_matrix, land_idx)  
    pca_mat = pca_data_matrix(convert_layers_to_features_matrix(layers, data_matrix, land_idx))
end

function fill_pca_layers(layers, pca_mat, land_idx)
    pca_layers = [convert(Float32, similar(layers[begin])) for l in 1:size(pca_mat, 1)]
    for (i,pca_layer) in enumerate(pca_layers)
        fill_layer!(pca_layer, pca_mat[i,:], land_idx)
    end 
    pca_layers
end 

function kmeans_and_pca(layers, data_matrix, land_idx, k)
    pca_mat = make_pca_matrix(layers, data_matrix, land_idx)
    pca_layers = fill_pca_layers(layers, pca_mat, land_idx)

    km = Clustering.kmeans(pca_mat, k)
    Λ = collect(eachcol(km.centers))

    pca_layers, Λ
end 

function make_climate_uniqueness(k, land_idx, layers)
    data_matrix = zeros(Float32, length(layers), length(land_idx))

    pca_layers, Λ = kmeans_and_pca(layers, data_matrix, land_idx, k)

    uniqueness = similar(layers[begin])
    uniqueness.grid .= nothing

    for i in land_idx
        env_vec = [pca_layer.grid[i] for pca_layer in pca_layers]
        _, m = findmin(x-> sum((env_vec .- x).^2), Λ)
        uniqueness.grid[i] = sum( (env_vec .- Λ[m]).^2 )
    end 
    return uniqueness 
end

function write_outputs(runtime_dir, uniqueness)
    outpath = joinpath(runtime_dir, "uniqueness.tif")
    SpeciesDistributionToolkit._write_geotiff(outpath, uniqueness; compress="COG")

    output_json_path = joinpath(runtime_dir, "output.json")
    open(output_json_path, "w") do f
        write(f, JSON.json(Dict(
            :climate_uniqueness => outpath
        )))
    end 
end


function main()
    runtime_dir = ARGS[1]
    inputs = read_inputs_dict(runtime_dir)

    mask_path = inputs["water_mask"]
    layer_paths = inputs["layers"]
    k = inputs["k"]

    
    OPEN_WATER_LABEL = 210
    lc = SimpleSDMPredictor(mask_path)
    land_idx = findall(!isequal(OPEN_WATER_LABEL), lc.grid)


    layers = SimpleSDMPredictor.(layer_paths)

    uniqueness = make_climate_uniqueness(k, land_idx, layers)
    
    write_outputs(runtime_dir, uniqueness)
end 

main()