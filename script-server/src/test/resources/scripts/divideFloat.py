import sys, json;

# Reading json
inputFile = open(sys.argv[1] + '/input.json')
data = json.load(inputFile)
value = data['float_value']
divider = data['divider']

output = {
  "result": (value / divider)
}

# Serializing json
json_object = json.dumps(output, indent = 2)
with open(sys.argv[1] + '/' + "output.json", "w") as outfile:
    outfile.write(json_object)