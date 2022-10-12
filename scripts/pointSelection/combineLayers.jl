using BiodiversityObservationNetworks
using SimpleSDMLayers
using JSON

outputFolder = ARGS[1]
filepath = joinpath(outputFolder,"input.json")
outputFilepath = joinpath(outputFolder,"data/")
mkdir(outputFilepath)

print(filepath)
print(outputFilepath)

input = JSON.parsefile(filepath)
print(keys(input))

layerpaths = input["layerpaths"]
layerweights = input["layerweights"]
targetbalance = input["targetbalance"] # this is the same as α
#= 
const numtargs = 2
W = zeros(length(layerpaths), numtargs)

for i in 1:length(layerpaths)
    W[:,i] .= layerweights[i]
end 

layers = stack([geotiff(lp) for lp in layerpaths])

priority = squish(layers, W, targetbalance);
 =#
priority_path = joinpath(outputFilepath, "priority_map.tiff")

# TODO
# write out the priority map as a tiff file

outputDict = Dict("priority_map" => priority_path)
open(joinpath(outputFolder, "output.json"),"w") do f
    JSON.print(f, JSON.json(outputDict)) 
end