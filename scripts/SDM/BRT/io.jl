function read_inputs_dict(runtime_dir)
    filepath = joinpath(runtime_dir, "input.json")
    output_dir = joinpath(runtime_dir, "data/")
    isdir(output_dir) || mkdir(output_dir)
    return JSON.parsefile(filepath)
end


function write_outputs(
    runtime_dir,
    fit_stats,
    uncertainty,
    rangemap,
    predicted_sdm
)

    sdm_path = joinpath(runtime_dir, "sdm.tif")
    range_path = joinpath(runtime_dir, "range.tif")
    uncert_path = joinpath(runtime_dir, "uncertainty.tif")
    pa_path = joinpath(runtime_dir, "pseudoabsences.tsv")
    output_json_path = joinpath(runtime_dir, "output.json")

    corners_path = joinpath(runtime_dir, "corners.png")
    tuning_path = joinpath(runtime_dir, "tuning.png")

    fit_stats_path = joinpath(runtime_dir, "fit_stats.json")

    save(corners_path, corners)
    save(tuning_path, tuning)

    open(output_json_path, "w") do f
        write(f, JSON.json(Dict(
            :fit_stats => fit_stats,
            :sdm_uncertainty => uncert_path,
            :range => sdm_path,
            :predicted_sdm => sdm_path
        )))
    end

    open(fit_stats_path, "w") do f
        write(f, JSON.json(fit_stats))
    end

    CSV.write(pa_path, pseudoabsences, delim="\t")
    _write_tif(predicted_sdm, sdm_path)
    _write_tif(uncertainty, uncert_path)
    _write_tif(rangemap, range_path)
end
