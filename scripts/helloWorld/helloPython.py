import sys, json;
import time;

# Reading inputs
data = biab_inputs()
intIn = data['some_int']

# Do stuff.
print("Will start when counter reaches input value, so you see logs go by...")
counter = 0
for x in range(0, intIn + 1):
  print(x, flush=True)
  time.sleep(0.5)
print("Go!", flush=True)

if intIn == 13 :
  biab_error_stop("intIn == 13, you're not lucky! This causes failure.")
  print("You will never see this message")

intIn += 1

# Saving result
biab_output("increment", intIn)
biab_output("crs_id", data['study_area_bbox']['CRS']['authority']+':'+str(data['study_area_bbox']['CRS']['code']))