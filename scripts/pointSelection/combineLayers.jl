using BiodiversityObservationNetworks
using SimpleSDMLayers
using JSON

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
layerweights = input["layerweights"]
targetbalance = input["targetbalance"] # this is the same as α

### Computation ###
const numtargs = 2
W = zeros(length(layerpaths), numtargs)

for i in 1:length(layerpaths)
    W[:,i] .= layerweights[i]
end 

layers = stack([geotiff(lp) for lp in layerpaths])

priority = squish(layers, W, targetbalance);

priority_path = joinpath(outputFilepath, "priority_map.tiff")
###################

# write out the priority map
geotiff(priority_path, priority)

# write out json
outputDict = Dict("priority_map" => priority_path)
open(joinpath(outputFolder, "output.json"),"w") do f
    JSON.print(f, JSON.json(outputDict)) 
end