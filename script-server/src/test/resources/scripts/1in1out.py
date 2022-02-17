import sys, json;

# Reading json
inputFile = open(sys.argv[1] + '/input.json')
data = json.load(inputFile)
print(data)
intIn = data['some_int']

#TODO can't do this since input is a string
#intIn += 1

dictionary = {
  "increment": intIn
}

# Serializing json
json_object = json.dumps(dictionary, indent = 2)
print(json_object)

with open(sys.argv[1] + '/' + "output.json", "w") as outfile:
    outfile.write(json_object)