import subprocess
import sys, json;
#def install_package_from_github(repo_url):
  #  subprocess.check_call([sys.executable, "-m", "pip", "install", f"git+{repo_url}"])
#install_package_from_github("https://github.com/gee-community/geemap")
import ee
import geemap


#inputFile = open(sys.argv[1] + '/input.json')
#data = json.load(inputFile)

#roi= ee.Geometry.BBox(data["bbox"])
#start_year=data["start_year"]
#end_year=data["start_year"]
start_year=2017
end_year=2020
roi = ee.Geometry.BBox(35.985609,49.754911,36.043043,50.152521)

#outputpath=sys.argv[1] + '/sentinel2.gif'
outputpath="Users/simonrabenmeister/Downloads/landsat.gif"
print(outputpath)

geemap.landsat_timelapse(
    roi,
    out_gif=outputpath,
    start_year=1984,
    end_year=2020,
    start_date='01-01',
    end_date='12-31',
    bands=["Red", "Green", "Blue"],
    frames_per_second=5,
    title='Landsat Timelapse',
    progress_bar_color='blue'
)


geemap.sentinel2_timelapse(
    roi,
    out_gif=outputpath,
    start_year=start_year,
    end_year=end_year,
    start_date='01-01',
    end_date='12-31',
    frequency='year',
    bands=["Red", "Green", "Blue"],
    frames_per_second=3,
    title='Sentinel-2 Timelapse',
    progress_bar_color="blue"
)

# Serializing output.json
dictionary = {
  "timelapse": outputpath
}
json_object = json.dumps(dictionary, indent = 2)
with open(sys.argv[1] + '/output.json', "w") as outfile:
    outfile.write(json_object)