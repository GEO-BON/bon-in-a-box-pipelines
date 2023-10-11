using JSON
using EvoTrees

println("Hello World")
outputFolder = ARGS[1]
cd(outputFolder)

data = Dict("number" => 9)

open("output.json","w") do f
    JSON.print(f, data)
end
