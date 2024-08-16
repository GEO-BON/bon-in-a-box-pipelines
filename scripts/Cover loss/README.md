load_LC:
Loads tree cover/tree cover loss data from "https://stac.geobon.org/" STAC. On the STAC, data is saved in 10x10 degree cells so f.e bbox<-c(10,30,20,40). The script detects when the given bbox exceeds a cells bounds and loads all cells required to cover the whole bbox. It then fuses all loaded cells and crops it to the bounds of the given bbox. It then outputs it as a .geotif file

LC_from_computer: INCOPLETE
Loads tree cover/tree cover loss data from the /userdata folder. It cannot detect if the given bbox exceeds the boundaries of a TC cell. Also the directory and file names have to be manually adjusted in the script, since it is specific for my file paths and names. 

Points to poly:
Takes a cdv with point observations, draws a buffer circle with a given radius around each point, fuses them to a multi polygon, separates the multi polygon into individual polygons and outputs them as a geojson. 

Cover loss:
Crops Tree cover/Tree cover loss data to the extent of boundary box, extracts TC/TCL data from inside Polygons given by SDM and calculates Tree cover area for each timestep, given by the TC/TCL data.

Loss map: 
plots a map: Pixels with Tree cover above 30% are green, Pixels with tree cover loss are red. Adds the habitat areas given by the SDM file

relative loss with circles: 
Calculates procentual area loss for every year and displays it in a graph. 

Indicators: 
It takes a file of habitat area per year and calculates Ne>500 and PM indicators from given Ne/Nc ratio as well as population density. If no pop. Density is given, it estimates it from the point observations used to model habitat area.

country to bbox:
It uses the rnaturalearth package to load any country shapefile and outputs the extent of the country as a bbox.

Timelapse.py:INCOMPLETE
A python script using the geemap package to create timelapse GIFs from a given bbox. This Script works on my private device but not in Bon in a box. Since gee map is not installed on the bon in a box server one has to run the following code in the terminal to install it via a docker file: „docker exec biab-script-server pip3 install geemap“. But since Bon in a box will be able to run conda soon, it might change. Also geemap requires a google cloud project with approval for Google earth engine which I am not sure how to get in the Bon in a box environment. 
