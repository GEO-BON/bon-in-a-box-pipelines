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

const SDT = SpeciesDistributionToolkit
const _PROJ = SpeciesDistributionToolkit.SimpleSDMLayers.Proj
const _ARCHGDAL = SpeciesDistributionToolkit.SimpleSDMLayers.ArchGDAL

include("io.jl")
include("pseudoabsences.jl")
include("diagnostics.jl")
include("util.jl")

"""
    _get_water_mask(layer_path; water_label=210)

Takes a path to a land cover layer `layer_path`, and creates a layer where all pixels
equal to `water_label` are 1, and all other pixels are 0.
"""
function _get_water_mask(layer_path; water_label=210)
    lc = SDMLayer(layer_path)

    water_mask = copy(lc)

    water_mask.grid .= 0 
    water_mask.grid[findall(isequal(water_label), lc.grid)] .= 1
    return water_mask
end

"""
    mask_water!(water, occurrence, predictor_layers)

Masks out all water values (given all locations in `water` which are true) from each of
the predictor layers.
"""
function mask_water!(water, occurrence, predictor_layers)
    mask!(occurrence, nodata(water, isone))
    map(l -> mask!(l, nodata(water, isone)), predictor_layers)
end

""" 
    mask_land!(water, occurrence, predictor_layers)

Masks out all land values (given all locations in `water` which are false) from each of
the predictor layers.
"""
function mask_land!(water, occurrence, predictor_layers)
    nodata(water, iszero)

    mask!(occurrence, nodata(water, iszero))
    map(l -> mask!(l, nodata(water, iszero)), predictor_layers)
end

"""
    process_inputs(RUNTIME_DIR)

Processes the input JSON file, and masks the environmental predictors and occurrences
based on whether the species is terrestrial or not. 

Returns a dictionary read from the input JSON, the masked predictor layers, and the masked occurrences.
"""
function process_inputs(RUNTIME_DIR)
    inputs = read_inputs_dict(RUNTIME_DIR)

    bounding_box = inputs["bbox_crs"]["bbox"]

    crs = string(inputs["bbox_crs"]["CRS"]["authority"],":", inputs["bbox_crs"]["CRS"]["code"])

    transformer = _PROJ.Transformation(crs, "EPSG:4326", always_xy=true)
    bbox = _get_wgs84_bbox(transformer, bounding_box...)

    predictor_layers = SDMLayer.(inputs["predictors"]; bbox...)
    water = _get_water_mask(inputs["water_mask"]; water_label=inputs["water_value"])

    occurrence_df = CSV.read(joinpath(inputs["occurrence"]), DataFrame)
    occurrence_layer = _get_occurrence_layer(transformer, first(predictor_layers), occurrence_df)

    is_terrestrial = inputs["terrestrial"]
    
    if is_terrestrial
        mask_water!(water, occurrence_layer, predictor_layers)
    else
        mask_land!(water, occurrence_layer, predictor_layers)
    end 

    return inputs, predictor_layers, occurrence_layer
end

"""
    get_rangemap(predicted_sdm, threshold)

Takes a continuous prediction layer (`predicted_sdm`) and thresholds it to create a 
range map by treating all values above `threshold` as range, and all values below as not range
"""
function get_rangemap(predicted_sdm, threshold)
    rangemap = copy(predicted_sdm)
    rangemap.grid[rangemap.indices] .= 0
    rangemap.grid[findall(predicted_sdm .> threshold)] .= 1
    return rangemap
end

"""
    prepare_training_data(layers, presence_layer, absence_layer)

Creates a matrix of features (num layers x num_sites) and labels (presence or absence) for each site. 
"""
function prepare_training_data(layers, presence_layer, absence_layer)
    # Extract environmental values at presence and absence locations
    X = Matrix(hcat([
        vcat(layer[findall(presence_layer)], layer[findall(absence_layer)]) 
        for layer in layers
    ]...)')
    
    # Create binary labels (1 = presence, 0 = absence)
    y = Bool.(vcat(
        [1 for _ in findall(presence_layer)], 
        [0 for _ in findall(absence_layer)]
    ))
    
    return X, y
end

"""
    train_model(X_train, y_train)

Fits the BRT on the data.
"""
function train_model(X_train, y_train)
    return EvoTrees.fit(
        EvoTreeGaussian(),
        x_train = X_train',
        y_train = y_train,
    )
end


"""
    predict_sdm(model, environmental_layers)

Applies a trained model `model` to the environmental layers to generate a layer of both 
habitat suitability (`prediction_layer`) and uncertainty (`uncertainty layer`)
"""
function predict_sdm(model, environmental_layers)
    # Initialize output layers
    prediction_layer = deepcopy(environmental_layers[begin])
    uncertainty_layer = deepcopy(environmental_layers[begin])
    
    # Extract features for all cells
    feature_matrix = Matrix(hcat([
        [layer[i] for layer in environmental_layers] 
        for i in eachindex(environmental_layers[1])
    ]...))
    
    # Generate predictions
    predictions = EvoTrees.predict(model, feature_matrix')
    
    # Fill layers with predictions
    prediction_layer.grid[findall(prediction_layer.indices)] .= predictions[:, 1]
    uncertainty_layer.grid[findall(prediction_layer.indices)] .= predictions[:, 2]
    
    return prediction_layer, uncertainty_layer
end

"""
    calculate_evaluation_metrics(y_true, y_predicted, thresholds=0:0.001:1)

Takes the set of true occurrence values (`y_true`) and model predictions (`y_predicted`)
and generates evaluation metrics, including ROC-AUC, PR-AUC, the True Skill Statistic (TSS), 
Matthew's Correlation Coefficient (MCC), and the optimal threshold for generating a binary range 
map (chosen as the value that maximizes TSS).
""" 

function calculate_evaluation_metrics(y_true, y_predicted, thresholds=0:0.001:1)
    # Calculate confusion matrices across all thresholds
    confusion_matrices = [ConfusionMatrix(y_predicted .> t, y_true) for t in thresholds]
    false_positive_rates, true_positive_rates = fpr.(confusion_matrices), tpr.(confusion_matrices)
    
    # Calculate ROC-AUC using trapezoidal rule
    roc_dx = [reverse(false_positive_rates)[i] - reverse(false_positive_rates)[i-1] for i in 2:length(false_positive_rates)]
    roc_dy = [reverse(true_positive_rates)[i] + reverse(true_positive_rates)[i-1] for i in 2:length(true_positive_rates)]
    roc_auc = sum(roc_dx .* (roc_dy ./ 2.0))
    
    # Calculate PR-AUC using trapezoidal rule
    precisions = ppv.(confusion_matrices)
    pr_dx = [reverse(true_positive_rates)[i] - reverse(true_positive_rates)[i-1] for i in 2:length(true_positive_rates)]
    pr_dy = [reverse(precisions)[i] + reverse(precisions)[i-1] for i in 2:length(precisions)]
    pr_auc = sum(pr_dx .* (pr_dy ./ 2.0))
    
    # Find optimal threshold using TSS (aka Youden's J aka Informedness)
    # see:
    #
    # Chicco D, Tötsch N, Jurman G (2021) 
    # The Matthews Correlation Coefficient (MCC) Is More Reliable than Balanced Accuracy, Bookmaker Informedness, and Markedness in Two-Class Confusion Matrix Evaluation. 
    # BioData Mining 14:13. https://doi.org/10.1186/s13040-021-00244-z

    _, threshold_index = findmax(trueskill.(confusion_matrices))
    optimal_threshold = thresholds[threshold_index]

    return Dict(
        :prauc => pr_auc,
        :rocauc => roc_auc,
        :tss => trueskill(confusion_matrices[threshold_index]),
        :mcc => mcc(confusion_matrices[threshold_index]),
        :threshold => optimal_threshold
    )
end


"""
    The main function to build an SDM with a BRT. 
"""
function main()
    RUNTIME_DIR = ARGS[1]

    @info "Loading inputs..."
    inputs, predictors, presence_layer = process_inputs(RUNTIME_DIR)

    max_candidate_pseudoabsences = inputs["max_candidate_pseudoabsences"]
    num_folds = inputs["num_folds"]
    pa_buffer_distance = inputs["pseudoabsence_buffer"]
    pa_prop = inputs["pa_proportion"]
    

    @info "Generating pseudoabsences..."
    pseudoabsences, pseudoabsence_df = generate_pseudoabsences(presence_layer, min_distance=pa_buffer_distance, max_candidate_pas=max_candidate_pseudoabsences, pa_proportion=pa_prop)
    features, labels = prepare_training_data(predictors, presence_layer, pseudoabsences)

    @info "Fitting BRT with $num_folds-fold crossvalidation..."

    fold_indices = SDT.SDeMo.kfold(labels, features, k=num_folds)
    true_labels = Bool[]
    out_of_fold_predictions = Float32[]
        
    # Train and evaluate each fold
    for (train_idx, validation_idx) in fold_indices
        model = train_model(features[:, train_idx], labels[train_idx])
        
        validation_predictions = EvoTrees.predict(model, features[:, validation_idx]')[:, 1]

        true_labels = vcat(true_labels, labels[validation_idx])
        out_of_fold_predictions = vcat(out_of_fold_predictions, validation_predictions)
    end

    fit_stats = calculate_evaluation_metrics(true_labels, out_of_fold_predictions)
    optimal_threshold = fit_stats[:threshold]

    @info "Predicting SDM..."
    model = train_model(features, labels)
    predicted_sdm, sdm_uncertainty = predict_sdm(model, predictors)
    rangemap = get_rangemap(predicted_sdm, optimal_threshold)

    @info "Creating diagnostic plots..."
    corners = create_diagnostics(model, predictors, presence_layer, pseudoabsences)

    @info "Writing outputs...."
    write_outputs(RUNTIME_DIR, fit_stats, sdm_uncertainty, rangemap, predicted_sdm, pseudoabsence_df, corners)
end

main()
