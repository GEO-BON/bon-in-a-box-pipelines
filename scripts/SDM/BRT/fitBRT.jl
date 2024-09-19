using EvoTrees
using CSV
using DataFrames
using JSON
using SpeciesDistributionToolkit

include("io.jl")

function main()
    _crs = "EPSG:6622"

    RUNTIME_DIR = ARGS[1]
    inputs = read_inputs_dict(RUNTIME_DIR)
    bbox = (left=-2316297.0, right=-1971146.0, bottom=1015207.0, top=1511916.0)

    predictor_paths = inputs["predictors"]
    occurrence_path = inputs["occurrence"]

    occurrence_df = CSV.read(joinpath(RUNTIME_DIR, occurrence_path), DataFrame)

    predictors = SDMLayer.([joinpath(RUNTIME_DIR, p) for p in predictor_paths]; bbox...)

    trans = SpeciesDistributionToolkit.SimpleSDMLayers.Proj.Transformation(first(predictors).crs, "EPSG:4326", always_xy=true)

    presence_layer = similar(first(predictors), Bool)
    wgs84_presence_coords = [trans(r.lon, r.lat) for r in eachrow(occurrence_df)]
    for x in wgs84_presence_coords[1:1000]
        presence_layer[x...] = true
    end
    @info sum(presence_layer)
    @info "got pres"

    background = pseudoabsencemask(SurfaceRangeEnvelope, presence_layer)
    bgpoints = backgroundpoints(background, sum(presence_layer))

    @info "got pas"
    # Prepare data to go in a BRT
    nodata!(bgpoints, false)
    nodata!(presence_layer, false)
    ks = [keys(presence_layer)..., keys(bgpoints)...]
    X = Float32.([predictors[i][k] for k in ks, i in eachindex(predictors)])
    y = [ones(Bool, sum(presence_layer))..., zeros(Bool, sum(bgpoints))...]


    config = EvoTreeMLE(max_depth=6, nbins=32, eta=0.05, nrounds=120, L2=0.1, loss=:gaussian_mle)

    @info "Evotree constructed"

    Xp = Float32.([predictors[i][k] for k in keys(predictors[1]), i in eachindex(predictors)])
    @info "fitting evotee"
    model = fit_evotree(config; x_train=X, y_train=y)
    @info "evotree done"
    preds = EvoTrees.predict(model, Xp)

    pr = similar(predictors[1], Float64)
    pr.grid[findall(pr.indices)] .= preds[:, 1]

    unc = similar(predictors[1], Float64)
    unc.grid[findall(unc.indices)] .= preds[:, 2]

    fit_stats = Dict()

    write_outputs(RUNTIME_DIR, fit_stats, unc, zeros(pr, Bool), pr)
end

main()
