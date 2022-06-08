import sys, json, os.path;

# Reading input.json
inputFile = open(sys.argv[1] + '/input.json')
data = json.load(inputFile)
pathIn = data['file']

# Do stuff.
print(pathIn)
present = os.path.isfile(pathIn)

# Serializing output.json
dictionary = {
  "presence":present
}
json_object = json.dumps(dictionary, indent = 2)
with open(sys.argv[1] + '/output.json', "w") as outfile:
    outfile.write(json_object)