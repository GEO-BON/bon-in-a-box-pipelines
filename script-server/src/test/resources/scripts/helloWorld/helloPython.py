import sys, json;
import time;

# Reading input.json
inputFile = open(sys.argv[1] + '/input.json')
data = json.load(inputFile)
intIn = data['some_int']

# Do stuff.
print("Will start when counter reaches input value, so you see logs go by...")
counter = 0
for x in range(0, intIn + 1):
  print(x, flush=True)
  time.sleep(0.5)
print("Go!", flush=True)

if intIn == 13 :
  print("intIn == 13, you're not lucky! This causes failure.")
  sys.exit(1)

intIn += 1

# Serializing output.json
dictionary = {
  "increment": intIn
}
json_object = json.dumps(dictionary, indent = 2)
with open(sys.argv[1] + '/output.json', "w") as outfile:
    outfile.write(json_object)