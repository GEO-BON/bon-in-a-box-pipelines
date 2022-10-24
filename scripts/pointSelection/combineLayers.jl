using GeoArrays: read 
using BiodiversityObservationNetworks
using SimpleSDMLayers
using JSON
using Downloads
using GeoArrays: read 

# Read in input arguments and json
outputFolder = ARGS[1]
filepath = joinpath(outputFolder,"input.json")
outputFilepath = joinpath(outputFolder,"data/")
mkdir(outputFilepath)

input = JSON.parsefile(filepath)

# Assign json objects to variables
layerdata = input["layerdata"]

#layerweights = input["layerweights"]
targetbalance = convert(Vector{Float64}, input["targetbalance"]) # this is the same as α

# hacky way to get the number of layers based on number of weights 
nlayers = trunc(Int, length(layerdata) / (1 + length(targetbalance)))
layermat = permutedims(reshape(layerdata, (1 + length(targetbalance)), nlayers), (2,1))

#read in layers
function get_simplesdmlayer(path)
    geoarray = read(path)
    SimpleSDMPredictor(geoarray.A[:,:,begin])
end

temppath = Downloads.download.(layermat[:, 1])
layers = stack(get_simplesdmlayer.(temppath))

# get weights with weights for a layer in columns 
W = map((x) -> parse(Float64, x), layermat[:, 2:end])

priority = SimpleSDMPredictor(squish(layers, convert(Array{Float64}, transpose(W)), targetbalance))

priority_path = joinpath(outputFilepath, "priority_map.tiff")
###################
print(priority_path)
# write out the priority map
geotiff(priority_path, priority)

print("pre_json save")

# write out json
outputDict = Dict("priority_map" => priority_path)
open(joinpath(outputFolder, "output.json"),"w") do f
    JSON.print(f, outputDict) 
end 