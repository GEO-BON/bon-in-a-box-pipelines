print("Hello World from R!")
file.create("/output/hello_file.txt")
print(Sys.getenv("OUTPUT_LOCATION"))
print(Sys.getenv("SCRIPT_LOCATION"))

cat('
{
    "presence":"map1.tiff",
    "uncertainty":"map2.tiff"
}')