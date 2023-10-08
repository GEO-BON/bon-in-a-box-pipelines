using SpeciesDistributionToolkit
using Clustering
using StatsBase
using CSV
using DataFrames
using MultivariateStats
using Dates 
using JSON

include("shared.jl")

function read_climate(runtime_dir, inputs, water_idx)
    baseline_paths = inputs["baseline_layers"]
    end_paths = inputs["end_layers"]

    layers = [map(SimpleSDMPredictor, joinpath.(runtime_dir, x)) for x in [baseline_paths, end_paths]]

    for ls in layers
        for l in ls
            l.grid[water_idx] .= nothing 
        end
    end

    layers
end

function get_baseline_standardization(baseline_layers, land_idx)
    [StatsBase.fit(ZScoreTransform, Float32.(vec(l.grid[land_idx]))) for l in baseline_layers]
end

function standardize_layers!(zs, layers, land_idx)
    for i in eachindex(zs)
        v = StatsBase.transform(zs[i], Float32.(vec(layers[i].grid[land_idx])))
        layers[i].grid[land_idx] .= v
    end 
end


function convert_layers_to_features_matrix(layer_set, data_matrix, land_idx)
    for (i,l) in enumerate(layer_set)
        x = Float32.(vec(l.grid[land_idx]))
        data_matrix[i,:] .= x
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
end 

function apply_pca_to_layers(pca, layers, land_idx)
    data_matrix = zeros(Float32, length(layers), length(land_idx))
    @info size(layers[1]), pca
    feat_mat = convert_layers_to_features_matrix(layers, data_matrix, land_idx)

    pca_mat = MultivariateStats.transform(pca, feat_mat)

    pca_layers = [similar(layers[begin]) for i in 1:size(pca_mat,1)]
    for (i,l) in enumerate(pca_layers)
        l.grid .= nothing
        l.grid[land_idx] = pca_mat[i,:]
    end
    pca_layers
end

function compute_velocity(climate_layers, land_idx)
    delta(a,b) = vec(abs.((a - b).grid[land_idx]))
    baseline, future = climate_layers[begin], climate_layers[end]

    velocity = similar(climate_layers[begin][begin])
    velocity.grid .= nothing
    velocity.grid[land_idx] .= 0.

    for i in eachindex(baseline)
        dl = delta(baseline[i], future[i])
        velocity.grid[land_idx] += dl
    end 
    velocity
end

function write_outputs(runtime_dir, velocity)
    outpath = joinpath(runtime_dir, "velocity.tif")
    SpeciesDistributionToolkit._write_geotiff(outpath, velocity; compress="COG")

    output_json_path = joinpath(runtime_dir, "output.json")
    open(output_json_path, "w") do f
        write(f, JSON.json(Dict(
            :climate_velocity => outpath
        )))
    end 
end

function main()
    runtime_dir = ARGS[1]
    inputs = read_inputs_dict(runtime_dir)
 
    lc_path = inputs["landcover"]
    OPEN_WATER_LABEL = 210
    lc = SimpleSDMPredictor(lc_path)
    land_idx = findall(x->!isnothing(x) && x != OPEN_WATER_LABEL, lc.grid)


    water_idx = findall(isequal(OPEN_WATER_LABEL), lc.grid)

    @info "about to read climate"
    climate_layers = read_climate(runtime_dir, inputs, water_idx)
    @info "about to standardize"
    zs = get_baseline_standardization(climate_layers[begin], land_idx)
    for layers in climate_layers
        standardize_layers!(zs, layers, land_idx)
    end

    data_matrix = zeros(Float32, length(climate_layers[begin]), length(land_idx))
    data_matrix = convert_layers_to_features_matrix(climate_layers[begin], data_matrix, land_idx)
    pca = pca_data_matrix(data_matrix)
    
    pca_layers = [apply_pca_to_layers(pca, layers, land_idx) for layers in climate_layers]


    @info "about to compute velocity"
    velocity = compute_velocity(pca_layers, land_idx)
    write_outputs(runtime_dir, velocity)
end

main()