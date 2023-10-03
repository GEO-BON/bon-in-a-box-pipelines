using JSON
using CSV
using DataFrames
using SpeciesDistributionToolkit

include("./shared.jl")

function main()
    runtime_dir = ARGS[1]
    inputs = read_inputs_dict(runtime_dir)

    predictor_paths = inputs["predictors"]
    occurrence_path = inputs["presence"]
    buffer_distance = inputs["buffer_distance"] / 1000 # div by 1000 to convert to km
    
    predictors = SimpleSDMPredictor.(predictor_paths)

    occurrence = CSV.read(occurrence_path, DataFrame, delim="\t")
    occurrence_layer = create_occurrence_layer(similar(predictors[1]), occurrence)

    buffer = pseudoabsencemask(WithinRadius, occurrence_layer; distance = buffer_distance)
    absences = SpeciesDistributionToolkit.sample(.!buffer, floor(Int, 0.5sum(occurrence_layer)))

    abs_coords = findall(absences)
    pseudoabs_df = DataFrame(lon=[c[1] for c in abs_coords], lat=[c[2] for c in abs_coords])
    CSV.write("$runtime_dir/background.tsv", pseudoabs_df, delim="\t")

    output_json_path = joinpath(runtime_dir, "output.json")
    open(output_json_path, "w") do f
        write(f, JSON.json(Dict(:background=>"$runtime_dir/background.tsv")))
    end 
end

main()

