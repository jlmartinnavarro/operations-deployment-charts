from os import listdir
import os
from os.path import isfile, join

mypath = "./charts"
onlyfolder = [f for f in listdir(mypath) if not isfile(join(mypath, f))]

for name in onlyfolder: 
    package = f"helm package charts/{name}/ -d docs/"
    os.system(package)

os.system("git add .; git commit -m 'add packages'; git push")

os.system("helm repo index ./docs --url https://jlmartinnavarro.github.io/wikimedia")