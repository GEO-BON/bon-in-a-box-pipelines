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

print(filepath)
print(outputFilepath)

input = JSON.parsefile(filepath)
print(keys(input))

# Assign json objects to variables
layerdata = input["layerdata"]
print(layerdata)


#layerweights = input["layerweights"]
targetbalance = convert(Vector{Float64}, input["targetbalance"]) # this is the same as α

# hacky way to get the number of layers based on number of weights 
nlayers = trunc(Int, length(layerdata) / (1 + length(targetbalance)))
layermat = permutedims(reshape(layerdata, (1 + length(targetbalance)), nlayers), (2,1))

print(layermat)
print(layermat[:, 1])


#read in layers
function get_simplesdmlayer(path)
    geoarray = read(path)
    SimpleSDMPredictor(geoarray.A[:,:,begin])
end

temppath = Downloads.download.(layermat[:, 1])
layers = stack(get_simplesdmlayer.(temppath))

#=
### Computation ###
const numtargs = length(targetbalance)
W = zeros(nlayers, numtargs)

for i in 1:nlayers
    print("in loop")
    W[:,i] .= layerweights[i]
    print("after loop")
end 
=#

# get weights with weights for a layer in columns 
W = convert(Array{Float64}, transpose(layermat[:, 2:end]))
print(W)
print(typeof(W))
print(targetbalance)

priority = SimpleSDMPredictor(squish(layers, W, targetbalance))

priority_path = joinpath(outputFilepath, "priority_map.tiff")
###################

# write out the priority map
geotiff(priority_path, priority)

print("pre_json save")

# write out json
outputDict = Dict("priority_map" => priority_path)
open(joinpath(outputFolder, "output.json"),"w") do f
    JSON.print(f, outputDict) 
end 