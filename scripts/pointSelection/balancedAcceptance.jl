using BiodiversityObservationNetworks
using SimpleSDMLayers
using JSON
using CSV

# Read in input arguments and json
outputFolder = ARGS[1]
filepath = joinpath(outputFolder,"input.json")
outputFilepath = joinpath(outputFolder,"data/")
mkdir(outputFilepath)

print(filepath)
print(outputFilepath)

input = JSON.parsefile(filepath)
print(keys(input))

# Assign json objects to variables
priority_map_path = input["priority_map"]
bias = input["bias_toward_high_priority"]
numpoints = parse(Int64, input["num_points"])

print(priority_map_path)
print(isfile(priority_map_path))

### Computation ###
priority_map = geotiff(SimpleSDMPredictor, priority_map_path)

selected_points = stack([priority_map])[:,:,1] |> seed(BalancedAcceptance(numpoints=numpoints, α=bias)) |> first
###################

# Write out points csv
selected_points_path = joinpath(outputFilepath, "selected_points.csv")
CSV.write(selected_points_path, selected_points)

# Write out json
outputDict = Dict("points" => selected_points_path)
open(joinpath(outputFolder, "output.json"),"w") do f
    JSON.print(f, outputDict)
end



