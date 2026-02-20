using JSON

outputFolder = ARGS[1]
cd(outputFolder)

# We can access the content of runner.env as regular env vars
println("Example accessing runner.env vars: GBIF_USER = ", get(ENV, "GBIF_USER", "not set"))

# Read the inputs from input.json
input_data = biab_inputs()

number = input_data["number"]
println("Input number: ", number)

# Sanitize the inputs
if number == 13
    biab_error_stop("Number cannot be 13.")
end

# Do the processing... (save the outputs along the way)
number += 1
biab_output("increment", number)

biab_output("crs_id", string(input_data["study_area_bbox"]["CRS"]["authority"],":",input_data["study_area_bbox"]["CRS"]["code"]))
