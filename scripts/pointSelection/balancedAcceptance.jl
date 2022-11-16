using BiodiversityObservationNetworks
using SimpleSDMLayers
using JSON
using CSV

# Read in input arguments and json
outputFolder = ARGS[1]
filepath = joinpath(outputFolder,"input.json")
outputFilepath = joinpath(outputFolder,"data/")
isdir(outputFilepath) || mkdir(outputFilepath)

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

# Write out as a geoJSON multipoint object
points_string = Vector{String}(undef,size(selected_points)[1])
for i in eachindex(selected_points)
    x = selected_points[i][1]
    y = selected_points[i][2]
    points_string[i] = "[$x, $y]"
end

points_string_join = join(points_string, ",\n\t\t")

json_string = ("{
    \"type\": \"MultiPoint\",
    \"coordinates\": [
        $points_string_join
    ]
}")

JSONoutputPath = joinpath(outputFolder, "output.json")
touch(JSONoutputPath)
file = open(JSONoutputPath, "w")
write(file, json_string)
close(file)
