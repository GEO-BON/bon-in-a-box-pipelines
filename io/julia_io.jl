using JSON
using SpeciesDistributionToolkit 
using CSV
using DataFrames

function read_input_dict(runtime_dir)
    filepath = joinpath(runtime_dir, "input.json")
    output_dir = joinpath(runtime_dir, "data/")
    isdir(output_dir) || mkdir(output_dir)
    return JSON.parsefile(filepath) 
end 

function write(runtime_dir, output_dict::Dict)
    output_json_path = joinpath(runtime_dir,  "output.json")
    open(output_json_path, "w") do f
        write(f, JSON.json(output_dict))
    end 
end 

function write(runtime_dir, layer::S, name::String) where S<:SimpleSDMLayer
    outpath = joinpath(runtime_dir, "$name.tif")
    SpeciesDistributionToolkit._write_geotiff(outpath, layer; compress="COG")
end

function write(runtime_dir, dataframe::DataFrame, name::String; delim=",")
    @assert delin ∈ [",", "\t"] || @throw "saving dataframes using write only supports csvs and tsvs"
    tag = delim == "," ? "csv" : "tsv"

    outpath = joinpath(runtime_dir, "$name.$tag")
    CSV.write(outpath, dataframe; delim=delim)
end
