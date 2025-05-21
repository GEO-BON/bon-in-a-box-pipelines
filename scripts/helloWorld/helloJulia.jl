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
    error("Number cannot be 13.")
end

# Do the processing...
number += 1

# Write the outputs to output.json
data = Dict("increment" => number)
open("output.json","w") do f
    JSON.print(f, data)
end
