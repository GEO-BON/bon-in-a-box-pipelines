## Environment variables available
# Script location can be used to access other scripts
print(Sys.getenv("SCRIPT_LOCATION"))

## Install required packages that are not available on Anaconda
#packages <- c("someRarePackage")
#new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
#if(length(new.packages)) install.packages(new.packages)

# Reading inputs
input <- biab_inputs()
print("Inputs: ")
print(input)

## Script body
example_jpg = file.path(outputFolder, "example.jpg")
if(!file.exists(example_jpg)) {
    download.file("https://geobon.org/wp-content/uploads/2018/01/default-image.png", example_jpg, "auto")
}
biab_output("some_picture", example_jpg)

example_tiff = file.path(outputFolder, "utmsmall.tif")
if(!file.exists(example_tiff)) {
    download.file("https://github.com/yeesian/ArchGDALDatasets/raw/master/data/utmsmall.tif", example_tiff, "auto")
}
biab_output("heat_map", example_tiff)

example_gpkg = file.path(outputFolder, "example.gpkg")
if(!file.exists(example_gpkg)) {
    download.file("https://github.com/ngageoint/GeoPackage/raw/refs/heads/master/docs/examples/java/example.gpkg", example_gpkg, "auto")
}
biab_output("geopackage_example", example_gpkg)

# Uncomment this to stop the script here with an error message
#biab_error_stop("Some error")

example_json = file.path(outputFolder, "sample.json")
if(!file.exists(example_json)) {
    download.file("https://gist.githubusercontent.com/wavded/1200773/raw/e122cf709898c09758aecfef349964a8d73a83f3/sample.json", example_json, "auto")
}
biab_output("geo_json", example_json)

some_csv_data = file.path(outputFolder, "some_data.csv")
write("Model,mpg,cyl,disp,hp,drat,wt,qsec,vs,am,gear,carb
Mazda RX4,21,6,160,110,3.9,2.62,16.46,0,1,4,4
Mazda RX4 Wag,21,6,160,110,3.9,2.875,17.02,0,1,4,4
Datsun 710,22.8,4,108,93,3.85,2.32,18.61,1,1,4,1
Hornet 4 Drive,21.4,6,258,110,3.08,3.215,19.44,1,0,3,1
", some_csv_data)
biab_output("some_csv_data", some_csv_data)

# Example from https://en.wikipedia.org/wiki/Tab-separated_values
some_tsv_data = file.path(outputFolder, "some_data.tsv")
write("Sepal length	Sepal width	Petal length	Petal width	Species
5.1	3.5	1.4	0.2	I. setosa
4.9	3.0	1.4	0.2	I. setosa
4.7	3.2	1.3	0.2	I. setosa
4.6	3.1	1.5	0.2	I. setosa
5.0	3.6	1.4	0.2	I. setosa
", some_tsv_data)
biab_output("some_tsv_data", some_tsv_data)

# Example from https://en.wikipedia.org/wiki/Tab-separated_values
some_html_output = file.path(outputFolder, "some_page.html")
write(
    "<h1>This is a page</h1><p>With a fancy interactive graph or the like.</p>",
    some_html_output
)
biab_output("some_html_output", some_html_output)

biab_info("Some information message")
biab_warning("Some warning")

biab_output("crs_id",paste0(input$bbox$CRS$authority,':',input$bbox$CRS$code))

biab_output("text", "This is just an example. In case you have a very, very, very, very, very, very, very, very, very, very, very, very, very, very, very, very, very, very, very, very, very, very, very, very, very, very, very, very, very, very long text it will need to be unfolded to see it all.")
biab_output("number", input$intensity * 3)
biab_output("userdata_available", list.files(file.path(Sys.getenv("USERDATA_LOCATION"))))
biab_output("undocumented_output", "Some debug output")

# (If there is a problem with encoding, one could use utf-8 library to clean the output, since the server reads it as utf-8)
