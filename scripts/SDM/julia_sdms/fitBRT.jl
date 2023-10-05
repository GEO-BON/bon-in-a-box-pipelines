using JSON
using CSV
using DataFrames
using EvoTrees
using StatsBase
using SpeciesDistributionToolkit

include("./shared.jl")

function get_features_and_labels(presences, absences, climate_layers)
    presences = mask(presences, climate_layers[begin])
    absences = mask(absences, climate_layers[begin])
    coord_presence = keys(replace(presences, false => nothing))
    coord_absence = keys(replace(absences, false => nothing))
    coord = vcat(coord_presence, coord_absence)

    X = hcat([layer[coord] for layer in climate_layers]...)
    y = vcat(fill(1.0, length(coord_presence)), fill(0.0, length(coord_absence)))
    return X, y, coord
end

function layers_to_matrix!(climate_layers, mat, land_idx)
    for (i, idx) in enumerate(land_idx)
        for l in eachindex(climate_layers)
            mat[l, i] = climate_layers[l].grid[idx]
        end
    end
end

function compute_fit_stats_and_cutoff(distribution, coords, y)
    cutoff = LinRange(extrema(distribution)..., 500)
    coords = convert(Vector{typeof(coords[begin])}, coords)
    idx = findall(!isnothing, coords)
    I = [SimpleSDMLayers._point_to_cartesian(distribution, c) for c in coords][idx]

    obs = y .> 0

    tp = zeros(Float64, length(cutoff))
    fp = zeros(Float64, length(cutoff))
    tn = zeros(Float64, length(cutoff))
    fn = zeros(Float64, length(cutoff))

    for (i, c) in enumerate(cutoff)
        prd = [distribution.grid[i] >= c for i in I]
        tp[i] = sum(prd .& obs)
        tn[i] = sum(.!(prd) .& (.!obs))
        fp[i] = sum(prd .& (.!obs))
        fn[i] = sum(.!(prd) .& obs)
    end

    tpr = tp ./ (tp .+ fn)
    fpr = fp ./ (fp .+ tn)
    J = (tp ./ (tp .+ fn)) + (tn ./ (tn .+ fp)) .- 1.0

    roc_dx = [reverse(fpr)[i] - reverse(fpr)[i - 1] for i in 2:length(fpr)]
    roc_dy = [reverse(tpr)[i] + reverse(tpr)[i - 1] for i in 2:length(tpr)]
    ROCAUC = sum(roc_dx .* (roc_dy ./ 2.0))

    thr_index = last(findmax(J))
    τ = cutoff[thr_index]

    return Dict(:rocauc => ROCAUC, :threshold => τ, :J => J[last(findmax(J))])
end


function test_train_split(X, y, proportion=0.7)
    train_size = floor(Int, proportion * length(y))
    Itrain = StatsBase.sample(1:length(y), train_size; replace=false)
    Itest = setdiff(1:length(y), Itrain)
    Xtrain, Xtest = X[Itrain, :], X[Itest, :]
    Ytrain, Ytest = y[Itrain], y[Itest]
    return Xtrain, Ytrain, Xtest, Ytest
end

function predict_single_sdm(model, layers)

    land_idx = findall(!isnothing, layers[begin].grid)

    mat = zeros(Float32, length(layers), length(land_idx))

    # Handle nothings here
    layers_to_matrix!(layers, mat, land_idx)

    pred = EvoTrees.predict(model, mat')

    distribution = SimpleSDMPredictor(
        zeros(Float32, size(layers[begin])); 
        SpeciesDistributionToolkit.boundingbox(layers[begin])...
    )
    distribution.grid[land_idx] = pred[:, 1]

    uncertainty = SimpleSDMPredictor(zeros(Float32, size(layers[begin])); SpeciesDistributionToolkit.boundingbox(layers[begin])...)
    uncertainty.grid[land_idx] = pred[:, 2]

    rescale(distribution, (0, 1)), rescale(uncertainty, (0, 1))
end 

function main()
    runtime_dir = ARGS[1]
    inputs = read_inputs_dict(runtime_dir)
    predictor_paths = inputs["predictors"]
    occurrence_path = inputs["occurrence"]
    pseudoabs_path = inputs["background"] 

    predictors = SimpleSDMPredictor.(predictor_paths)

    occurrence = CSV.read(occurrence_path, DataFrame, delim="\t")
    occurrence_layer = create_occurrence_layer(similar(predictors[1]), occurrence)

    pseudoabsences = CSV.read(pseudoabs_path, DataFrame, delim="\t")
    pseudoabs_layer = create_occurrence_layer(similar(predictors[1]), pseudoabsences)
    #pseudoabs_layer = create_occurrence_layer(similar(predictors[1]), pseudoabs_df)

    X, y, p_and_a_coords = get_features_and_labels(occurrence_layer, pseudoabs_layer, predictors)

    Xtrain, Ytrain, Xtest, Ytest = test_train_split(X, y)

    brt = EvoTreeGaussian(;
        loss = :gaussian,
        metric = :gaussian,
        nrounds = 100,
        nbins = 100,
        λ = 0.0,
        γ = 0.0,
        η = 0.1,
        max_depth = 7,
        min_weight = 1.0,
        rowsample = 0.5,
        colsample = 1.0,
    )


    model = fit_evotree(
        brt;
        x_train=Xtrain, 
        y_train=Ytrain, 
        x_eval=Xtest, 
        y_eval=Ytest
    )

    prediction, uncertainty = predict_single_sdm(model, predictors)

    fit_dict = compute_fit_stats_and_cutoff(prediction, p_and_a_coords, y)  
    τ = fit_dict[:threshold]

    # Set below threshold to 0
    prediction.grid[findall(x -> x < τ, prediction.grid)] .= 0

    sdm_path = joinpath(runtime_dir, "sdm.tif")
    SpeciesDistributionToolkit.save(sdm_path, prediction)
    uncertainty_path = joinpath(runtime_dir, "uncertainty.tif")
    SpeciesDistributionToolkit.save(uncertainty_path, uncertainty)


    fit_stats_path = joinpath(runtime_dir, "fit_stats.json")
    open(fit_stats_path, "w") do f 
        write(f, JSON.json(fit_dict))
    end

    output_json_path = joinpath(runtime_dir, "output.json")
    open(output_json_path, "w") do f
        write(f, JSON.json(Dict(
            :sdm => sdm_path,
            :uncertainty => uncertainty_path,
            :fit_stats => fit_stats_path
        )))
    end 

end

main()