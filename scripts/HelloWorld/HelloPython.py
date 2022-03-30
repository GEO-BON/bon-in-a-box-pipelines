import sys, json;
import time;

# Reading input.json
inputFile = open(sys.argv[1] + '/input.json')
data = json.load(inputFile)
intIn = data['some_int']

# Do stuff.
print("Ready?", flush=True)
time.sleep(2)
print("Set", flush=True)
time.sleep(2)
print("Go!", flush=True)

if intIn == 13 :
  print("some_int == 13, you're not lucky! This causes failure.")
  sys.exit(1)

intIn += 1

# Serializing output.json
dictionary = {
  "increment": intIn
}
json_object = json.dumps(dictionary, indent = 2)
with open(sys.argv[1] + '/output.json', "w") as outfile:
    outfile.write(json_object)