using BiodiversityObservationNetworks
using SimpleSDMLayers

# TODO 
# Get `priority_map_path`, `bias`, and `numpoints` from the input JSON

priority_map_path = "foo"
bias = 1.0 
numpoints = 50

priority_map = geotiff(priority_map_path)

selected_points = priority_map |> seed(BalancedAcceptance(numpoints=numpoints, α=bias)) |> first 

# TODO
# figure out how we want to output selected_points 


