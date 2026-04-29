import sys, json;
import time;

# Reading inputs
data = biab_inputs()
seconds = data['seconds']
fileIn = data['some_csv_file']

# Validations
if not os.path.exists(fileIn):
  biab_error_stop(f"File '{fileIn}' does not exist.")

# Partial output
biab_output("target", seconds)


# Error simulation
if seconds == 13 :
  biab_error_stop("seconds == 13, you're not lucky! This causes failure.")

  # Processing simulation
print("Looping with some delay to simulate processing...")
counter = 0
for x in range(0, seconds + 1):
  print(x, flush=True)
  time.sleep(1)

print("Done!", flush=True)

# Read file contents
with open(fileIn, 'r') as f:
  content = f.read()
  print("Contents of csv input:")
  print(content)

# Final output
biab_output("length", len(content))
