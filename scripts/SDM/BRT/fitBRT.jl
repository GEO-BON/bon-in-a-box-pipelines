biab_ensure_package(["SpeciesDistributionToolkit", "CairoMakie", "ArchGDAL", "CSV", "DataFrames", "EvoTrees"])

using EvoTrees
using CSV
using DataFrames
using JSON
using ArchGDAL
using SpeciesDistributionToolkit
using SpeciesDistributionToolkit.SimpleSDMLayers
using Statistics
using CairoMakie

const _PROJ = SpeciesDistributionToolkit.SimpleSDMLayers.Proj

include("io.jl")
include("pseudoabsences.jl")
include("confusion.jl")
include("diagnostics.jl")
include("util.jl")

function mask_water!(water, occurrence, predictor_layers)
    if water.x != occurrence.x || water.y != occurrence.y
        biab_error_stop(
            "The water mask does not cover the same area and resolution as the predictors, so it cannot be applied. " *
            "The grids differ: water mask has $(size(water.grid)) cells with x = $(water.x), y = $(water.y); " *
            "predictors have $(size(occurrence.grid)) cells with x = $(occurrence.x), y = $(occurrence.y)."
        )
    end
    mask!(occurrence, water)
    map(l -> mask!(l, water), predictor_layers)
end

function process_inputs(RUNTIME_DIR)
    inputs = read_inputs_dict(RUNTIME_DIR)

    bounding_box = inputs["bbox_crs"]["bbox"]

    crs = string(inputs["bbox_crs"]["CRS"]["authority"],":", inputs["bbox_crs"]["CRS"]["code"])

    transformer = _PROJ.Transformation(crs, "EPSG:4326", always_xy=true)
    bbox = _get_wgs84_bbox(transformer, bounding_box...)

    predictor_layers = SDMLayer.(inputs["predictors"]; bbox...)
    water = _get_water_mask(inputs["water_mask"]; bbox...)

    occurrence_df = CSV.read(joinpath(inputs["occurrence"]), DataFrame)
    occurrence_layer = _get_occurrence_layer(transformer, first(predictor_layers), occurrence_df)

    mask_water!(water, occurrence_layer, predictor_layers)

    return inputs, predictor_layers, occurrence_layer
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
    inputs, predictors, presence_layer = process_inputs(RUNTIME_DIR)
    @info "Occurrences remaining after masking: $(sum(presence_layer)) (on $(sum(presence_layer.indices)) valid cells)"

    max_candidate_pseudoabsences = inputs["max_candidate_pseudoabsences"]
    pa_buffer_distance = inputs["pseudoabsence_buffer"]
    pa_prop = inputs["pa_proportion"]
    @info "Generating pseudoabsences..."
    pseudoabsences, pseudoabsence_df = generate_pseudoabsences(presence_layer, min_distance=pa_buffer_distance, max_candidate_pas=max_candidate_pseudoabsences, pa_proportion=pa_prop)

    features, labels = get_features_and_labels(predictors, presence_layer, pseudoabsences)
    train_idx, test_idx = crossvalidation_split(labels)
    n_test_presences = sum(labels[test_idx])
    @info "Test split: $n_test_presences presences, $(length(test_idx) - n_test_presences) absences (training: $(length(train_idx)) points)"

    @info "Fitting BRT..."
    brt_config = EvoTreeMLE(max_depth=6, nbins=16, eta=0.05, nrounds=120, loss=:gaussian_mle)
    model = EvoTrees.fit(brt_config; x_train=features[train_idx, :], y_train=labels[train_idx])
    fit_stats, confusion_matrices = compute_fit_stats(model, features, labels, test_idx)

    # biab_warning keeps a single message, so the warnings are joined.
    warnings = fit_stats_warnings(fit_stats, confusion_matrices)
    isempty(warnings) || biab_warning(join(warnings, "\n\n"))

    @info "Predicting SDM..."
    predicted_sdm, sdm_uncertainty = predict_sdm(model, predictors)
    rangemap = get_rangemap(predicted_sdm, fit_stats[:threshold])

    @info "Creating diagnostic plots..."
    tuning, corners = create_diagnostics(model, predictors, presence_layer, pseudoabsences, confusion_matrices)

    @info "Writing outputs...."
    write_outputs(RUNTIME_DIR, fit_stats, sdm_uncertainty, rangemap, predicted_sdm, pseudoabsence_df, tuning, corners)
end

main()
