import json, yaml, cerberus, os, glob

# Some utils
class bcolors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

def green(str):
    return bcolors.OKGREEN + str + bcolors.ENDC

def red(str):
    return bcolors.FAIL + str + bcolors.ENDC

# https://stackoverflow.com/a/58836461/3519951
def get_files(path, extension, recursive=False):
    """
    A generator of filepaths for each file into path with the target extension.
    If recursive, it will loop over subfolders as well.
    """
    if not recursive:
        for file_path in glob.iglob(path + "/*." + extension):
            yield file_path
    else:
        for root, dirs, files in os.walk(path):
            for file_path in glob.iglob(root + "/*." + extension):
                yield file_path

# Load validator
with open('cerberusValidationSchema.yaml') as f:
    schema = yaml.safe_load(f)

v = cerberus.Validator(schema)

# Perform validation
errorFlag = False

for filePath in get_files(os.getcwd(), 'json', recursive=True):
    with open(filePath) as f:
        document = json.load(f)

    if v.validate(document) :
        print(green("OK ") + filePath)
    else:
        print(red("ERROR ") + filePath)
        print(yaml.dump(v.errors))
        errorFlag = True
    
# Final assertion
if(errorFlag):
    print("\nErrors were found during validation.")
    exit(1)