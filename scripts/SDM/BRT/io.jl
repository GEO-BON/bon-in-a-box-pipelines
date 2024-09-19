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

    mkpath(joinpath(runtime_dir, "output"))
    sdm_path = joinpath(runtime_dir, "output", "sdm.tif")
    uncert_path = joinpath(runtime_dir, "output", "uncertainty.tif")
    output_json_path = joinpath(runtime_dir, "output", "output.json")
    open(output_json_path, "w") do f
        write(f, JSON.json(Dict(
            :fit_stats => fit_stats,
            :sdm_uncertainty => uncert_path,
            :range => sdm_path,
            :predicted_sdm => sdm_path
        )))
    end

    SimpleSDMLayers.save(sdm_path, uncertainty; compress="COG")
    SimpleSDMLayers.save(uncert_path, predicted_sdm; compress="COG")

end
