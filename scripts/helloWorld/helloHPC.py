import sys, json;
import time;

# Reading inputs
data = biab_inputs()
intIn = data['some_int']
fileIn = data['some_csv_file']

# Validations
if not os.path.exists(fileIn):
  biab_error_stop(f"File '{fileIn}' does not exist.")

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

with open(fileIn, 'r') as f:
  content = f.read()
  print("Contents of csv input:")
  print(content)

# Saving result
biab_output("increment", intIn)