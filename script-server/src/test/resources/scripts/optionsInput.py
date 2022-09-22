import sys, json;

# Reading json
inputFile = open(sys.argv[1] + '/input.json')
data = json.load(inputFile)
optIn = data['options_in']


dictionary = {
  "the_same": optIn
}

# Serializing json
json_object = json.dumps(dictionary, indent = 2)
with open(sys.argv[1] + '/' + "output.json", "w") as outfile:
    outfile.write(json_object)