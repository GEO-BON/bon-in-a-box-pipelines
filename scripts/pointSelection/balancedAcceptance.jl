using BiodiversityObservationNetworks
using SpeciesDistributionToolkit
using JSON
using CSV

function read_inputs_dict(runtime_dir)
    @info "Reading inputs"
    filepath = joinpath(runtime_dir, "input.json")
    output_dir = joinpath(runtime_dir, "data/")
    isdir(output_dir) || mkdir(output_dir)
    return JSON.parsefile(filepath) 
end 

function read_priority_map(inputs)
    priority_map_path = inputs["priority_map"]
    priority_map =  SimpleSDMPredictor(priority_map_path)
    return priority_map
end 

function read_parameters(inputs)
    bias = inputs["bias_toward_high_priority"]
    num_points = parse(Int64, inputs["num_points"])
    bias < 0 && @info "Bias is below 0. Aborting" && exit(-1)
    num_points <= 1 && @info "Number of points must be greater than one. Aborting." && exit(-1)
    bias, num_points
end 

function run_bas(priority_map, bias, num_points)
    M = Float32.(priority_map.grid') # We transpose grid because the grid storage has lat on x on long on y, which needs to be flipped 
    selected_points = seed(BalancedAcceptance(numpoints=num_points, α=bias))(M) |> first
    return selected_points
end 

function cartesian_to_coord(priority_map, x, y)
        left, right, top, bottom = priority_map.left, priority_map.right, priority_map.top,
            priority_map.bottom
        Δx = (right - left) / size(priority_map)[2]   # The size in dim 2 is long
        Δy = (top - bottom) / size(priority_map)[1]   # The size in dim 1 in lat
        long = left + x * Δx + Δx / 2
        lat = bottom + y * Δy + Δy / 2
        return long, lat 
end 
function points_to_geojson(priority_map, points; EPSG="4326")
    points_string = Vector{String}(undef, size(points)[1])

    for i in eachindex(points)
        x, y = points[i][1], points[i][2]
        long, lat = cartesian_to_coord(priority_map, x, y)
        points_string[i] = "[$long, $lat]"
    end
    points_string_join = join(points_string, ",\n\t\t")

    json_string = ("{
        \"type\": \"MultiPoint\",
        \"coordinates\": [
            $points_string_join
        ],
        \"crs\": {
            \"type\": \"name\",
            \"properties\": {
                \"name\": \"EPSG:$EPSG\"
            }
        }
    }")
    return json_string
end

function write_results(output_dir, points_json)
    pointsOutputPath = joinpath(output_dir, "points.json")
    touch(pointsOutputPath)
    file = open(pointsOutputPath, "w")
    write(file, points_json)
    close(file)

    scriptOutputPath = joinpath(output_dir, "output.json")
    touch(scriptOutputPath)
    file = open(scriptOutputPath, "w")
    write(file, "{\"points\": \"$pointsOutputPath\"}")
    close(file)
end 
function main()
    runtime_dir = ARGS[1]
    inputs = read_inputs_dict(runtime_dir)
    priority_map = read_priority_map(inputs)
    bias, num_points = read_parameters(inputs)

    points = run_bas(priority_map, bias, num_points) 
    points_geojson = points_to_geojson(priority_map, points)

    write_results(runtime_dir, points_geojson)
end

main()
