using BiodiversityObservationNetworks
using SimpleSDMLayers


# TODO 
# Read the input JSONs to get `layerpaths`, `layerweights`, and
# `targetbalance`
layerpaths = ["foo", "bar", "etc"]
layerweights = [(0.5,0.5), (0.3,0.7), (0.25,0.75)]
targetbalance = [0.3, 0.7] # this is the same as α

const numtargs = 2
W = zeros(length(layerpaths), numtargs)

for i in 1:length(layerpaths)
    W[:,i] .= layerweights[i]
end 

layers = stack([geotiff(lp) for lp in layerpaths])

priority = squish(layers, 𝐖, α);


# TODO
# write priority map and store path in output JSON
