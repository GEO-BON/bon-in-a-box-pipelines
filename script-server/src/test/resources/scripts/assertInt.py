import sys, json;

# Reading input.json
inputFile = open(sys.argv[1] + '/input.json')
data = json.load(inputFile)
input = data['input']

# Do stuff.
if not isinstance(input, int) :
    sys.exit("This is not an int")

# Serializing output.json
dictionary = {
  "the_same": input
}
json_object = json.dumps(dictionary, indent = 2)
with open(sys.argv[1] + '/output.json', "w") as outfile:
    outfile.write(json_object)