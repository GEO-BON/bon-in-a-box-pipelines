using JSON

outputFolder = ARGS[1]
cd(outputFolder)

# We can access the content of runner.env as regular env vars
println("Example accessing runner.env vars: GBIF_USER = ", get(ENV, "GBIF_USER", "not set"))

# Read the inputs from input.json
input_data = open("input.json", "r") do f
    JSON.parse(f)
end

number = input_data["number"]
println("Input number: ", number)

# Sanitize the inputs
if number == 13
    biab_error_stop("Number cannot be 13.")
end

# Do the processing... (save the outputs along the way)
number += 1
biab_output("increment", number)
