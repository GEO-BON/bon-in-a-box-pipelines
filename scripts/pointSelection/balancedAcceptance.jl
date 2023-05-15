using BiodiversityObservationNetworks
using SpeciesDistributionToolkit
using JSON
using CSV

# Read in input arguments and json
outputFolder = ARGS[1]
filepath = joinpath(outputFolder,"input.json")
outputFilepath = joinpath(outputFolder,"data/")
isdir(outputFilepath) || mkdir(outputFilepath)

println(filepath)
println(outputFilepath)

input = JSON.parsefile(filepath)
println(keys(input))

# Assign json objects to variables
priority_map_path = input["priority_map"]
bias = input["bias_toward_high_priority"]
numpoints = parse(Int64, input["num_points"])

println(priority_map_path)
println(isfile(priority_map_path))

### Computation ###
priority_map = SimpleSDMPredictor(priority_map_path)

selected_points = BiodiversityObservationNetworks.stack([priority_map])[:,:,1] |> seed(BalancedAcceptance(numpoints=numpoints, α=bias)) |> first
###################



# Write out as a geoJSON multipoint object
points_string = Vector{String}(undef,size(selected_points)[1])

for i in eachindex(selected_points)
    x, y = selected_points[i][1], selected_points[i][2]

    left, right, top, bottom = priority_map.left, priority_map.right, priority_map.top, priority_map.bottom
    
    Δx = (right - left)/size(priority_map)[1]
    Δy = (top - bottom)/size(priority_map)[2]

    long = left + x*Δx + Δx/2
    lat = bottom + y*Δy + Δy/2

    points_string[i] = "[$long, $lat]"
end

points_string_join = join(points_string, ",\n\t\t")

#SimpleSDMPredictor always converts to WGS84, so we can hard code the projection here
json_string = ("{
    \"type\": \"MultiPoint\",
    \"coordinates\": [
        $points_string_join
    ],
    \"crs\": {
        \"type\": \"name\",
        \"properties\": {
            \"name\": \"EPSG:4326\"
        }
    }
}")

pointsOutputPath = joinpath(outputFolder, "points.json")
touch(pointsOutputPath)
file = open(pointsOutputPath, "w")
write(file, json_string)
close(file)

scriptOutputPath = joinpath(outputFolder, "output.json")
touch(scriptOutputPath)
file = open(scriptOutputPath, "w")
write(file, "{\"points\": \"$pointsOutputPath\"}")
close(file)
