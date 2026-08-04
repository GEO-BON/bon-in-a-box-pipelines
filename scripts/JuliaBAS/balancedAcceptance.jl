using BiodiversityObservationNetworks
using SpeciesDistributionToolkit
using CSV
using DataFrames

using Statistics
#using CairoMakie
using JSON 

const BONs = BiodiversityObservationNetworks
const SDT = SpeciesDistributionToolkit
const SB = BONs.StatsBase

"""
    read_inputs_dict

Reads the input JSON from the runtime directory.
"""
function read_inputs_dict(runtime_dir)
    filepath = joinpath(runtime_dir, "input.json")
    output_dir = joinpath(runtime_dir, "data/")
    isdir(output_dir) || mkdir(output_dir)
    return JSON.parsefile(filepath)
end

"""
    ecdf(layer)

Computes the empirical cumulative distribution function for an SDMLayer
"""
function ecdf(layer)
    ef = SB.ecdf(values(layer))
    ecdfed_layer = copy(layer)
    ecdfed_layer.grid = map(ef, layer.grid)
    ecdfed_layer.indices = layer.indices
    return ecdfed_layer
end

"""
    apply_weight_to_layer(layer, weight)

Applys the provided weight to input map by first computing the empirical cumulative 
distribution function for the input layer, and then applying exponential logistic tilting, 
where each cell in the ECDF layer is passed through exp(weight*x)/(1 + exp(x)), to make high values
of priority more extreme.
"""
function apply_weight_to_layer(layer, weight)
    return BONs.tilt(ecdf(layer), weight)
end 

function generate_priority(dims = (180, 120), H = 0.9)
    SDMLayer(rand(MidpointDisplacement(H), dims))
end

function write_outputs(RUNTIME_DIR, bon)
    lons, lats = [n[1] for n in bon], [n[2] for n in bon]

    df = DataFrame(lon=lons, lat=lats)
    df_path = joinpath(RUNTIME_DIR, "selected_sites.tsv")
    CSV.write(df_path, df, delim="\t")

    open(joinpath(RUNTIME_DIR, "output.json"), "w") do f
        write(f, JSON.json(
            Dict(
                "selected_sites" => df_path
            )
        ))
    end
end

function main()
    RUNTIME_DIR = ARGS[1]
    inputs = read_inputs_dict(RUNTIME_DIR)

    priority_weight = inputs["weight"]
    num_sites = inputs["num_sites"]
    priority_map = SDMLayer(inputs["priority_map"])
    
    
    mask_layer = nothing 
    if !isnothing(inputs["mask"]) 
        mask_layer = Bool.(SDMLayer(inputs["mask"]))
        # hack until fixed in public BONs version
        mask_layer.indices .= mask_layer.indices .& mask_layer.grid
    end 

    inclusion_probability = apply_weight_to_layer(priority_map, priority_weight)

    bon = sample(BalancedAcceptance(num_sites), priority_map, inclusion=inclusion_probability, mask=mask_layer)

    write_outputs(RUNTIME_DIR, bon)
end


main()

#=

# Practically cap weight at like 100 because it will get stuck in an inf loop if its too high
using NeutralLandscapes
weight = 3
num_nodes = 50

priority = generate_priority()
heatmap(priority)

inclusion_probability = apply_weight_to_layer(priority, weight)
bon = sample(BalancedAcceptance(num_nodes), priority, inclusion=inclusion_probability)

heatmap(priority)
scatter!([(n[1],n[2]) for n in bon], color=:white, strokecolor=:black, strokewidth=1)
current_figure()


# Using raster as mask
virginia = getpolygon(PolygonData(OpenStreetMap, Places), place="Virginia")
layer = SDMLayer(RasterData(WorldClim2, BioClim); resolution=2.5, SDT.boundingbox(virginia)...)
SDT.SimpleSDMLayers.save("output/JuliaBAS/balancedAcceptance/demo_data/demo_priority.tif", mask2, )

heatmap(layer)

mask_layer = deepcopy(layer)
mask_layer.grid .= 1
mask!(mask_layer, virginia)
heatmap(mask_layer)


mask2 = deepcopy(mask_layer)
mask2.indices .= 1
mask2.grid .= mask_layer.indices
heatmap(mask2)

mkpath("output/JuliaBAS/balancedAcceptance/demo_data")
SDT.SimpleSDMLayers.save("output/JuliaBAS/balancedAcceptance/demo_data/demo_mask.tif", mask2, )


priority = BONs.tilt(ecdf(layer), 10.0)

heatmap(priority)

bon = sample(BalancedAcceptance(num_nodes), copy(priority), inclusion=priority, mask=mask2)

heatmap(layer)
scatter!([(n[1],n[2]) for n in bon], color=:white, strokecolor=:black, strokewidth=1)
lines!(virginia, color=:grey10, linewidth=2)
current_figure()
=#




