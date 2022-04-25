import sys, json;

# Reading input.json
inputFile = open(sys.argv[1] + '/input.json')
data = json.load(inputFile)
boolIn = data['input_bool']

# Do stuff.
if not isinstance(boolIn, bool) :
    sys.exit("This is not an array")

# Serializing output.json
dictionary = {
  "the_same": boolIn
}
json_object = json.dumps(dictionary, indent = 2)
with open(sys.argv[1] + '/output.json', "w") as outfile:
    outfile.write(json_object)