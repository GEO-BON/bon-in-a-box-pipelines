print("Hello World from R!")

# Environment variables available
print(Sys.getenv("OUTPUT_LOCATION"))
print(Sys.getenv("SCRIPT_LOCATION"))

# Receiving args
args <- commandArgs(trailingOnly=TRUE)
cat(args, sep = "\n")

# Script body
example_file = file.path(Sys.getenv("OUTPUT_LOCATION"), "hello_world.txt")
file.create(example_file)

# Outputing result
cat(paste0('
{
    "example_file":"',example_file,'",
    "uncertainty":"map2.tiff"
}'))