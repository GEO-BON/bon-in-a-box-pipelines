using SpeciesDistributionToolkit
using SpeciesDistributionToolkit.SimpleSDMLayers
using ArchGDAL

function read_inputs_dict(runtime_dir)
    filepath = joinpath(runtime_dir, "input.json")
    output_dir = joinpath(runtime_dir, "data/")
    isdir(output_dir) || mkdir(output_dir)
    return JSON.parsefile(filepath)
end

function _prepare_layer_for_burnin(layer::SDMLayer{T}, nodata::T) where {T<:Number}
    array = copy(layer.grid)
    array[findall(.!layer.indices)] .= nodata
    array_t = reverse(permutedims(array, [2, 1]); dims=2)
    return array_t
end

function _get_geotransform(layer)
    gt = zeros(Float64, 6)
    gt[1] = layer.x[1]
    gt[2] = 2stride(layer, 1)
    gt[3] = 0.0
    gt[4] = layer.y[2]
    gt[5] = 0.0
    gt[6] = -2stride(layer, 2)
    return gt
end

function _write_tif(layer::SDMLayer{T}, filename) where {T}
    array_t = _prepare_layer_for_burnin(layer, typemin(T))
    width, height = size(array_t)
    gt = _get_geotransform(layer)

    ArchGDAL.create(
        filename,
        width=width,
        height=height,
        nbands=1,
        dtype=Float64,
        options=["COMPRESS=COG"],
        driver=ArchGDAL.getdriver("GTiff")
    ) do dataset
        band = ArchGDAL.getband(dataset, 1)
        ArchGDAL.setnodatavalue!(band, typemin(T))
        ArchGDAL.setgeotransform!(dataset, gt)
        ArchGDAL.setproj!(dataset, layer.crs)
        ArchGDAL.write!(band, array_t)
    end
end

function write_outputs(
    runtime_dir,
    fit_stats,
    uncertainty,
    rangemap,
    predicted_sdm,
    pseudoabsences,
    tuning,
    corners
)

    sdm_path = joinpath(runtime_dir, "sdm.tif")
    range_path = joinpath(runtime_dir, "range.tif")
    uncert_path = joinpath(runtime_dir, "uncertainty.tif")
    pa_path = joinpath(runtime_dir, "pseudoabsences.tsv")

    corners_path = joinpath(runtime_dir, "corners.png")
    tuning_path = joinpath(runtime_dir, "tuning.png")

    fit_stats_path = joinpath(runtime_dir, "fit_stats.json")

    save(corners_path, corners)
    save(tuning_path, tuning)

    open(fit_stats_path, "w") do f
        # NaN is not valid JSON.
        write(f, JSON.json(Dict(k => isfinite(v) ? v : nothing for (k, v) in fit_stats)))
    end

    CSV.write(pa_path, pseudoabsences, delim="\t")
    _write_tif(predicted_sdm, sdm_path)
    _write_tif(uncertainty, uncert_path)
    _write_tif(rangemap, range_path)

    biab_output("fit_stats", fit_stats_path)
    biab_output("sdm_uncertainty", uncert_path)
    biab_output("range", range_path)
    biab_output("predicted_sdm", sdm_path)
    biab_output("pseudoabsences", pa_path)
    biab_output("env_corners", corners_path)
    biab_output("tuning", tuning_path)
end
