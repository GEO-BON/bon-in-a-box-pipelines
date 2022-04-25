import sys, json;
import time;

# Reading input.json
inputFile = open(sys.argv[1] + '/input.json')
data = json.load(inputFile)
arrayIn = data['array']

# Do stuff.
if not isinstance(arrayIn, list) :
    sys.exit("This is not an array")

# Serializing output.json
dictionary = {
  "the_same": arrayIn
}
json_object = json.dumps(dictionary, indent = 2)
with open(sys.argv[1] + '/output.json', "w") as outfile:
    outfile.write(json_object)