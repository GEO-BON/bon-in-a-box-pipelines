import sys, json;

# Reading json
inputFile = open(sys.argv[1] + '/input.json')
data = json.load(inputFile)
print(data)
intIn = data['some_int']

intIn += 1

dictionary = {
  "increment": intIn
}

# Serializing json
json_object = json.dumps(dictionary, indent = 2)
with open(sys.argv[1] + '/' + "output.json", "w") as outfile:
    outfile.write(json_object)