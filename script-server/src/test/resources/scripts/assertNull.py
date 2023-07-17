import sys, json;
print("start")
# Reading input.json
inputFile = open(sys.argv[1] + '/input.json')
data = json.load(inputFile)
print(data)
stringIn = data['input']

# Do stuff.
if stringIn is not None:
    print("This is not null")
    sys.exit("This is not null")

# Serializing output.json
dictionary = {
  "the_same": stringIn
}
json_object = json.dumps(dictionary, indent = 2)
with open(sys.argv[1] + '/output.json', "w") as outfile:
    outfile.write(json_object)
