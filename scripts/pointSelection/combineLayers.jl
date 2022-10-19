using BiodiversityObservationNetworks
using SimpleSDMLayers
using JSON
using Downloads

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
layerpaths = input["layerpaths"]
print(layerpaths)
layerweights = input["layerweights"]
targetbalance = input["targetbalance"] # this is the same as α

# read in layers
using GeoArrays: read
function get_simplesdmlayer(path)
    geoarray = read(path)
    SimpleSDMPredictor(geoarray.A[:,:,begin])
end

temppath = Downloads.download.(layerpaths)
layers = stack(get_simplesdmlayer.(temppath))

### Computation ###
const numtargs = length(targetbalance)
W = zeros(length(layerpaths), numtargs)

for i in 1:length(layerpaths)
    W[:,i] .= layerweights[i]
end 

#layers = stack([geotiff(SimpleSDMPredictor, lp) for lp in layerpaths])

priority = SimpleSDMPredictor(squish(layers, W, targetbalance))

priority_path = joinpath(outputFilepath, "priority_map.tiff")
###################

# write out the priority map
geotiff(priority_path, priority)

print("pre_json save")

# write out json
outputDict = Dict("priority_map" => priority_path)
open(joinpath(outputFolder, "output.json"),"w") do f
    JSON.print(f, JSON.json(outputDict)) 
end