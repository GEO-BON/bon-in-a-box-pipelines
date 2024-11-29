import sys, json;
import time;
import pandas as pd;
import csv

inputFile = open(sys.argv[1] + '/input.json')
data = json.load(inputFile)
df = data['csv']
df= eval(df)

df = pd.DataFrame(df[1:], columns=df[0])

path= open(sys.argv[1] + '/obs.csv', "w")
df.to_csv(path)

dictionary = {
"csv_out": sys.argv[1] + '/obs.csv'
}


json_object = json.dumps(dictionary, indent = 2)
with open(sys.argv[1] + '/output.json', "w") as outfile:
    outfile.write(json_object)
