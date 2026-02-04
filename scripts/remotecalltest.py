#!/usr/bin/env python3
import requests

data = {
    "a_boolean": True,
    "freeflow_text": "This is a multiline example.\nOnce there is a line break in the example, it becomes a textarea in the UI.",
    "intensity": 3,
    "multi_options_example": ["first option", "eleventh option"],
    "options_example": "third option",
    "raster": "http://something-compatible.tiff",
    "species": ["Acer saccharum ", "Bubo scandiacus"]
}

## Update the link for target instance
url="http://localhost/script/helloWorld%3EhelloR.yml/run"
headers = {
    "accept": "text/plain",
    "Content-Type": "text/plain"
}

response=requests.post(url, json=data, headers=headers)
print(response)
print(response.text)