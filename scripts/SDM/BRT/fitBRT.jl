using Pkg
Pkg.activate("/julia_depot")

using EvoTrees
using CSV
using DataFrames
using JSON
using SpeciesDistributionToolkit
using SpeciesDistributionToolkit.SimpleSDMLayers
using Statistics
using CairoMakie

const _PROJ = SpeciesDistributionToolkit.SimpleSDMLayers.Proj
const _ARCHGDAL = SpeciesDistributionToolkit.SimpleSDMLayers.ArchGDAL

include("io.jl")
include("pseudoabsences.jl")
include("confusion.jl")
include("diagnostics.jl")
include("util.jl")

function mask_water!(water, occurrence, predictor_layers)
    mask!(occurrence, water)
    map(l -> mask!(l, water), predictor_layers)
end

function process_inputs(RUNTIME_DIR)
    inputs = read_inputs_dict(RUNTIME_DIR)

    crs = inputs["crs"]
    transformer = _PROJ.Transformation(crs, "EPSG:4326", always_xy=true)
    bbox = _get_wgs84_bbox(transformer, inputs["bbox"]...)

    predictor_layers = SDMLayer.(inputs["predictors"]; bbox...)
    water = _get_water_mask(inputs["water_mask"])

    occurrence_df = CSV.read(joinpath(inputs["occurrence"]), DataFrame)
    occurrence_layer = _get_occurrence_layer(transformer, first(predictor_layers), occurrence_df)

    mask_water!(water, occurrence_layer, predictor_layers)

    return predictor_layers, occurrence_layer, transformer
end

function get_rangemap(predicted_sdm, threshold)
    rangemap = copy(predicted_sdm)
    rangemap.grid[rangemap.indices] .= 0
    rangemap.grid[findall(predicted_sdm .> threshold)] .= 1
    return rangemap
end


function predict_sdm(model, predictors)
    Xp = Float32.([predictors[i][k] for k in keys(predictors[1]), i in eachindex(predictors)])
    preds = EvoTrees.predict(model, Xp)

    predicted_sdm = similar(first(predictors), Float64)
    predicted_sdm.grid[predicted_sdm.indices] .= preds[:, 1]
    uncertainty = similar(first(predictors), Float64)
    uncertainty.grid[uncertainty.indices] .= preds[:, 2]

    return predicted_sdm, uncertainty
end


function main()
    RUNTIME_DIR = ARGS[1]

    @info "Loading inputs..."
    predictors, presence_layer, transformer = process_inputs(RUNTIME_DIR)

    @info "Generating pseudoabsences..."
    pseudoabsences, pseudoabsence_df = generate_pseudoabsences(presence_layer, transformer)

    features, labels = get_features_and_labels(predictors, presence_layer, pseudoabsences)
    train_idx, test_idx = crossvalidation_split(labels)

    @info "Fitting BRT..."
    brt_config = EvoTreeMLE(max_depth=6, nbins=16, eta=0.05, nrounds=120, loss=:gaussian_mle)
    model = fit_evotree(brt_config; x_train=features[train_idx, :], y_train=labels[train_idx])
    fit_stats, confusion_matrices = compute_fit_stats(model, features, labels, test_idx)

    @info "Predicting SDM..."
    predicted_sdm, sdm_uncertainty = predict_sdm(model, predictors)
    rangemap = get_rangemap(predicted_sdm, fit_stats[:threshold])

    @info "Creating diagnostic plots..."
    tuning, corners = create_diagnostics(model, predictors, presence_layer, pseudoabsences, confusion_matrices)

    @info "Writing outputs...."
    write_outputs(RUNTIME_DIR, fit_stats, sdm_uncertainty, rangemap, predicted_sdm, pseudoabsence_df, tuning, corners)
end

main()
